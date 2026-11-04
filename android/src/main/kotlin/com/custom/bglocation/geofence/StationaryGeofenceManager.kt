package com.custom.bglocation.geofence

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

class StationaryGeofenceManager(private val context: Context) {

    companion object {
        private const val TAG = "StationaryGeofenceMgr"
        const val STATIONARY_GEOFENCE_ID = "STATIONARY_GEOFENCE_ANCHOR"
        const val ACTION_GEOFENCE_EVENT = "com.custom.bglocation.ACTION_GEOFENCE_EVENT"
        private const val REQUEST_CODE = 4002
    }

    private val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)

    private val pendingIntent: PendingIntent by lazy {
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java).apply {
            action = ACTION_GEOFENCE_EVENT
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }

    @SuppressLint("MissingPermission")
    fun armStationaryGeofence(latitude: Double, longitude: Double, radiusMeters: Float = 25f) {
        val geofence = Geofence.Builder()
            .setRequestId(STATIONARY_GEOFENCE_ID)
            .setCircularRegion(latitude, longitude, radiusMeters)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_EXIT)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0) // Do NOT trigger entry immediately
            .addGeofence(geofence)
            .build()

        geofencingClient.addGeofences(request, pendingIntent)
            .addOnSuccessListener {
                Log.i(TAG, "Successfully armed 25m Stationary Geofence at ($latitude, $longitude). GPS radio powered OFF.")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to arm stationary geofence: ${e.message}", e)
            }
    }

    fun disarmStationaryGeofence() {
        geofencingClient.removeGeofences(listOf(STATIONARY_GEOFENCE_ID))
            .addOnSuccessListener {
                Log.i(TAG, "Stationary geofence removed. Resuming active GPS tracking.")
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "Could not remove stationary geofence: ${e.message}")
            }
    }
}
