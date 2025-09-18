package com.varplayer.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.varplayer.app/links"
    private var channel: MethodChannel? = null
    private var initialLink: String? = null

    /** يستخرج الرابط (إن وُجد) من الـ Intent الحالي */
    private fun extractLink(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return data.toString()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // نخزن أول رابط (launch)
        initialLink = extractLink(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter يطلب الرابط الأول عند الإقلاع
                "getInitialLink" -> result.success(initialLink)

                // خيار لتصفير الرابط الأول بعد ما يستهلكه Flutter
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
        // مهم إذا activity بــ singleTask: يحدّث getIntent()
        setIntent(intent)

        // استخرج الرابط الجديد وادفعه مباشرة للـ Flutter
        val link = extractLink(intent)
        if (link != null) {
            // لو الـ channel لسه ما تهيّأ، لا تفجّر كراش
            channel?.invokeMethod("onNewIntent", link)
        }
        // ملاحظة: ما نغيّر initialLink هنا—هذا خاص بالإقلاع الأول فقط
    }
}
