import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  MediaKit.ensureInitialized();
  runApp(const VarPlayerApp());
}

class VarPlayerApp extends StatelessWidget {
  const VarPlayerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('com.varplayer.app/links');

  late final Player _player;
  late final VideoController _controller;

  late final AnimationController _bgController;
  late final Animation<Color?> _bgColor;

  String? _streamUrl;

  @override
  void initState() {
    super.initState();

    _player = Player();
    _controller = VideoController(_player);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _bgColor = ColorTween(
      begin: Colors.deepPurple,
      end: Colors.black,
    ).animate(_bgController);

    _initLinks();
  }

  Future<void> _initLinks() async {
    // الرابط الأول عند فتح التطبيق
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null) _handleIncomingLink(initial);
    } catch (_) {}

    // أي Intent جديد يصير للتطبيق وهو مفتوح
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final link = call.arguments as String?;
        if (link != null) _handleIncomingLink(link);
      }
    });
  }

  void _handleIncomingLink(String link) {
    try {
      String? resolved;
      if (link.startsWith('varplayer://')) {
        final uri = Uri.parse(link);
        if (uri.host == 'play') {
          final t = uri.queryParameters['t'];
          if (t != null && t.isNotEmpty) {
            final bytes = base64Url.decode(t);
            resolved = utf8.decode(bytes);
          }
        }
      } else if (link.startsWith('http://') || link.startsWith('https://')) {
        resolved = link;
      }

      if (resolved == null || resolved.isEmpty) return;
      setState(() => _streamUrl = resolved);
      _openAuto(resolved);
    } catch (e) {
      debugPrint('Link parse error: $e');
    }
  }

  Future<void> _openAuto(String url) async {
    await _player.open(
      Media(
        url,
        extras: {
          'live_start_index': '-5',
          'reconnect': '1',
          'reconnect_delay_max': '8',
          'min_buffer': '1200',
          'buffer_for_rebuffer': '800',
          'max_buffer': '20000',
          'cache_secs': '20',
          'readahead': '16000000',
          'demuxer_max_bytes': '20000000',
          'demuxer_max_back_bytes': '5000000',
        },
      ),
      play: false,
    );

    bool started = false;

    final sub = _player.stream.buffering.listen((isBuf) async {
      if (!started && !isBuf) {
        started = true;
        await _player.play();
      }
    });

    Future.delayed(const Duration(milliseconds: 1800), () async {
      if (!started) {
        started = true;
        await _player.play();
      }
    }).whenComplete(() => sub.cancel());
  }

  @override
  void dispose() {
    _player.dispose();
    _bgController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgColor,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _bgColor.value,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: _streamUrl == null
                        ? const Text(
                      'No stream loaded',
                      style: TextStyle(color: Colors.white70),
                    )
                        : Video(
                      controller: _controller,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (_streamUrl != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: StreamBuilder<bool>(
                      stream: _player.stream.buffering,
                      builder: (_, snap) {
                        final buffering = snap.data ?? false;
                        return AnimatedOpacity(
                          opacity: buffering ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 120),
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
