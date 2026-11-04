package com.custom.bglocation.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.custom.bglocation.service.LocationTrackingService

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CustomBgBootReceiver"
        const val PREFS_NAME = "custom_bg_geo_prefs"
        const val KEY_ENABLED = "tracking_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "Received system broadcast: $action")

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_ENABLED, false)

        if (isEnabled) {
            val serviceIntent = Intent(context, LocationTrackingService::class.java).apply {
                this.action = LocationTrackingService.ACTION_START
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                Log.i(TAG, "Successfully auto-restarted background location service on device boot.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to auto-restart service on boot: ${e.message}", e)
            }
        }
    }
}
