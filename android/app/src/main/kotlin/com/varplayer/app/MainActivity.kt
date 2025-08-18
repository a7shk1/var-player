package com.varplayer.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.varplayer.app/links"
    private lateinit var channel: MethodChannel
    private var initialLink: String? = null

    private fun extractLink(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return data.toString()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialLink = extractLink(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(initialLink)
                "clearInitialLink" -> {
                    initialLink = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractLink(intent)?.let { link ->
            // دفع الرابط الجديد للفلتر
            channel.invokeMethod("onNewIntent", link)
        }
    }
}
