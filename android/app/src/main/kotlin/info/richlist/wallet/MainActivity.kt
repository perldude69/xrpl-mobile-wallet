package info.richlist.wallet

import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val screenSecurityChannel = "xrpl_mobile_wallet/screen_security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyObscuredTouchFilter()
    }

    override fun onResume() {
        super.onResume()
        // FlutterView is attached after first frame; re-apply so PIN / send
        // taps are dropped when another window overlays this one.
        applyObscuredTouchFilter()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenSecurityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        runOnUiThread {
                            if (secure) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Drop touches when a foreign window covers this activity (tapjacking). */
    private fun applyObscuredTouchFilter() {
        window.decorView.filterTouchesWhenObscured = true
        val content = findViewById<View>(android.R.id.content) ?: return
        content.filterTouchesWhenObscured = true
        if (content is ViewGroup) {
            for (i in 0 until content.childCount) {
                content.getChildAt(i).filterTouchesWhenObscured = true
            }
        }
    }
}
