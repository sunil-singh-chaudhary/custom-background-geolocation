package com.custom.bglocation.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.custom.bglocation.CustomBackgroundGeolocationPlugin
import com.custom.bglocation.service.LocationTrackingService
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

class GeofenceBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GeofenceReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return

        if (event.hasError()) {
            Log.e(TAG, "GeofencingEvent error code: ${event.errorCode}")
            return
        }

        val transition = event.geofenceTransition
        val triggeringGeofences = event.triggeringGeofences ?: emptyList()

        for (geofence in triggeringGeofences) {
            val id = geofence.requestId
            Log.i(TAG, "Geofence transition: $id -> transitionType=$transition")

            // Send to Flutter EventChannel
            CustomBackgroundGeolocationPlugin.sendGeofenceEvent(id, transition)

            // If stationary geofence was exited -> user is moving again!
            if (id == StationaryGeofenceManager.STATIONARY_GEOFENCE_ID &&
                transition == Geofence.GEOFENCE_TRANSITION_EXIT) {
                Log.i(TAG, "User stepped outside 25m stationary radius! Reactivating high-accuracy GPS.")
                LocationTrackingService.exitStationaryMode(context)
            }
        }
    }
}
