package com.techbysh.fliptap

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.techbysh.fliptap/overlay"
    private val PREFS_NAME = "overlay_prefs"
    private val KEY_OVERLAY_SHOWING = "overlay_showing"

    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // App relaunched after kill — stop any leftover overlay
        stopOverlayService()
        markOverlayShowing(false)
    }

    override fun onDestroy() {
        super.onDestroy()
        stopOverlayService()
        markOverlayShowing(false)
    }

    override fun onStop() {
        super.onStop()
        // Fires when app goes to background OR is closed
        // isFinishing = true means the activity is actually closing
        if (isFinishing) {
            stopOverlayService()
            markOverlayShowing(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setOverlayShowing" -> {
                    val showing = call.argument<Boolean>("showing") ?: false
                    markOverlayShowing(showing)
                    result.success(null)
                }
                "isOverlayShowing" -> {
                    result.success(isOverlayShowing())
                }
                "wasOverlayShowingOnKill" -> {
                    val was = isOverlayShowing()
                    result.success(was)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun stopOverlayService() {
        try {
            val serviceIntent = Intent(
                this,
                Class.forName("flutter.overlay.window.flutter_overlay_window.OverlayService")
            )
            stopService(serviceIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getPrefs(): SharedPreferences =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun markOverlayShowing(showing: Boolean) {
        getPrefs().edit().putBoolean(KEY_OVERLAY_SHOWING, showing).apply()
    }

    private fun isOverlayShowing(): Boolean =
        getPrefs().getBoolean(KEY_OVERLAY_SHOWING, false)
}