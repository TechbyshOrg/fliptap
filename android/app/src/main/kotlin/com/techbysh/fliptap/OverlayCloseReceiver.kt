package com.techbysh.fliptap

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class OverlayCloseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("OverlayCloseReceiver", "App task removed — stopping overlay service")

        // Stop the flutter_overlay_window service directly
        val serviceIntent = Intent(context, Class.forName("net.christianbeier.flutteroverlay.FlutterOverlayWindowService"))
        context.stopService(serviceIntent)
    }
}