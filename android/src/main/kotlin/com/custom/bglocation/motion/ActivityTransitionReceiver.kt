package com.custom.bglocation.motion

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.custom.bglocation.CustomBackgroundGeolocationPlugin
import com.custom.bglocation.service.LocationTrackingService
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

class ActivityTransitionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ActivityTransReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (!ActivityTransitionResult.hasResult(intent)) return

        val result = ActivityTransitionResult.extractResult(intent) ?: return

        for (event in result.transitionEvents) {
            val activityName = getActivityName(event.activityType)
            val transitionType = if (event.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER) "ENTER" else "EXIT"

            Log.i(TAG, "Hardware Activity Transition: $activityName -> $transitionType")

            // Notify Flutter EventChannel
            CustomBackgroundGeolocationPlugin.sendMotionEvent(activityName, 100)

            // State Machine Switching
            if (event.activityType == DetectedActivity.STILL && event.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER) {
                // User is motionless -> Switch to Stationary (Power off GPS, drop 25m Geofence)
                LocationTrackingService.enterStationaryMode(context)
            } else if (event.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER &&
                (event.activityType == DetectedActivity.WALKING ||
                 event.activityType == DetectedActivity.RUNNING ||
                 event.activityType == DetectedActivity.IN_VEHICLE ||
                 event.activityType == DetectedActivity.ON_BICYCLE)) {
                // User started moving -> Switch to Moving (Remove geofence, power on high-accuracy GPS)
                LocationTrackingService.exitStationaryMode(context)
            }
        }
    }

    private fun getActivityName(type: Int): String {
        return when (type) {
            DetectedActivity.STILL -> "still"
            DetectedActivity.WALKING -> "walking"
            DetectedActivity.RUNNING -> "running"
            DetectedActivity.IN_VEHICLE -> "in_vehicle"
            DetectedActivity.ON_BICYCLE -> "on_bicycle"
            else -> "unknown"
        }
    }
}
