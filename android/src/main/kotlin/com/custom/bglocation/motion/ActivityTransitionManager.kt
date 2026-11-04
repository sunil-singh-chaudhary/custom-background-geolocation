package com.custom.bglocation.motion

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity

class ActivityTransitionManager(private val context: Context) {

    companion object {
        private const val TAG = "ActivityTransitionMgr"
        const val ACTION_ACTIVITY_TRANSITION = "com.custom.bglocation.ACTION_ACTIVITY_TRANSITION"
        private const val REQUEST_CODE = 4001
    }

    private val activityClient = ActivityRecognition.getClient(context)

    private val pendingIntent: PendingIntent by lazy {
        val intent = Intent(context, ActivityTransitionReceiver::class.java).apply {
            action = ACTION_ACTIVITY_TRANSITION
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }

    fun startMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val permission = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACTIVITY_RECOGNITION
            )
            if (permission != PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "ACTIVITY_RECOGNITION permission not granted. Skipping transitions.")
                return
            }
        }

        val transitions = listOf(
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.STILL)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build(),
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.STILL)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                .build(),
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.WALKING)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build(),
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.RUNNING)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build(),
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.IN_VEHICLE)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build(),
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.ON_BICYCLE)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build()
        )

        val request = ActivityTransitionRequest(transitions)

        activityClient.requestActivityTransitionUpdates(request, pendingIntent)
            .addOnSuccessListener {
                Log.i(TAG, "Successfully registered Activity Transition updates (Hardware Coprocessor).")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to register Activity Transition updates: ${e.message}", e)
            }
    }

    fun stopMonitoring() {
        try {
            activityClient.removeActivityTransitionUpdates(pendingIntent)
                .addOnSuccessListener {
                    Log.i(TAG, "Stopped Activity Transition updates.")
                }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping activity transitions: ${e.message}")
        }
    }
}
