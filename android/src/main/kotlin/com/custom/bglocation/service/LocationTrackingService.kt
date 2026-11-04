package com.custom.bglocation.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.custom.bglocation.CustomBackgroundGeolocationPlugin
import com.custom.bglocation.db.LocationDatabaseHelper
import com.custom.bglocation.db.LocationEntity
import com.custom.bglocation.geofence.StationaryGeofenceManager
import com.custom.bglocation.http.HttpSyncManager
import com.custom.bglocation.motion.ActivityTransitionManager
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.UUID

class LocationTrackingService : Service() {

    companion object {
        private const val TAG = "LocationTrackingSvc"
        private const val NOTIFICATION_ID = 9021
        private const val CHANNEL_ID = "custom_bg_tracking_channel"

        const val ACTION_START = "ACTION_START_TRACKING"
        const val ACTION_STOP = "ACTION_STOP_TRACKING"
        const val ACTION_ENTER_STATIONARY = "ACTION_ENTER_STATIONARY"
        const val ACTION_EXIT_STATIONARY = "ACTION_EXIT_STATIONARY"

        @Volatile
        var isRunning = false
            private set

        @Volatile
        var isStationary = false
            private set

        var distanceFilter: Float = 20.0f
        var stationaryRadius: Float = 25.0f
        var heartbeatInterval: Int = 60
        var notificationTitle = "Location Service Active"
        var notificationText = "Monitoring location in background"
        var extrasJson: String? = null

        fun enterStationaryMode(context: Context) {
            val intent = Intent(context, LocationTrackingService::class.java).apply {
                action = ACTION_ENTER_STATIONARY
            }
            context.startService(intent)
        }

        fun exitStationaryMode(context: Context) {
            val intent = Intent(context, LocationTrackingService::class.java).apply {
                action = ACTION_EXIT_STATIONARY
            }
            context.startService(intent)
        }
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var dbHelper: LocationDatabaseHelper
    private lateinit var stationaryGeofenceMgr: StationaryGeofenceManager
    private lateinit var activityTransitionMgr: ActivityTransitionManager
    private lateinit var httpSyncMgr: HttpSyncManager

    private var lastValidLocation: Location? = null
    private var totalOdometer: Double = 0.0
    private val heartbeatHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            if (isRunning && heartbeatInterval > 0) {
                val (batteryLevel, isCharging) = getBatteryInfo()
                val last = lastValidLocation
                CustomBackgroundGeolocationPlugin.sendHeartbeatEvent(
                    latitude = last?.latitude ?: 0.0,
                    longitude = last?.longitude ?: 0.0,
                    batteryLevel = batteryLevel,
                    isCharging = isCharging
                )
                dbHelper.insertLog("INFO", "Heartbeat tick [lat=${last?.latitude}, lng=${last?.longitude}, batt=${(batteryLevel * 100).toInt()}%]")
                heartbeatHandler.postDelayed(this, heartbeatInterval * 1000L)
            }
        }
    }

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            processLocation(location)
        }
    }

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        dbHelper = LocationDatabaseHelper.getInstance(this)
        stationaryGeofenceMgr = StationaryGeofenceManager(this)
        activityTransitionMgr = ActivityTransitionManager(this)
        httpSyncMgr = HttpSyncManager(this)
        httpSyncMgr.registerConnectivityListener()
        createNotificationChannel()
    }

    override fun onDestroy() {
        super.onDestroy()
        heartbeatHandler.removeCallbacks(heartbeatRunnable)
        httpSyncMgr.unregisterConnectivityListener()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                startTracking()
            }
            ACTION_STOP -> {
                stopTracking()
                stopSelf()
            }
            ACTION_ENTER_STATIONARY -> {
                handleEnterStationary()
            }
            ACTION_EXIT_STATIONARY -> {
                handleExitStationary()
            }
        }
        return START_STICKY
    }

    private fun startTracking() {
        if (isRunning) return
        isRunning = true
        isStationary = false

        startForeground(NOTIFICATION_ID, buildNotification(notificationTitle, notificationText))
        activityTransitionMgr.startMonitoring()
        requestLocationUpdates()

        if (heartbeatInterval > 0) {
            heartbeatHandler.removeCallbacks(heartbeatRunnable)
            heartbeatHandler.postDelayed(heartbeatRunnable, heartbeatInterval * 1000L)
        }

        dbHelper.insertLog("INFO", "Started native background tracking service (START_STICKY).")
        Log.i(TAG, "Started native background tracking service (START_STICKY).")
    }

    private fun stopTracking() {
        isRunning = false
        isStationary = false
        totalOdometer = 0.0
        lastValidLocation = null
        heartbeatHandler.removeCallbacks(heartbeatRunnable)
        fusedLocationClient.removeLocationUpdates(locationCallback)
        stationaryGeofenceMgr.disarmStationaryGeofence()
        activityTransitionMgr.stopMonitoring()
        stopForeground(STOP_FOREGROUND_REMOVE)
        dbHelper.insertLog("INFO", "Stopped native background tracking service.")
        Log.i(TAG, "Stopped native background tracking service.")
    }

    @SuppressLint("MissingPermission")
    private fun requestLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        val intervalMs = if (distanceFilter <= 0.0f) 10000L else 10000L
        val minIntervalMs = if (distanceFilter <= 0.0f) 5000L else 5000L
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateDistanceMeters(distanceFilter)
            .setMinUpdateIntervalMillis(minIntervalMs)
            .setMaxUpdateDelayMillis(0)
            .build()

        fusedLocationClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
            .addOnSuccessListener {
                Log.i(TAG, "Fused location updates active with distanceFilter = ${distanceFilter}m (interval=${intervalMs}ms).")
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Failed to request location updates: ${e.message}", e)
            }
    }

    private fun handleEnterStationary() {
        if (stationaryRadius <= 0.0f) {
            Log.i(TAG, "stationaryRadius is 0.0m (Desk / Continuous mode enabled). Keeping GPS active.")
            return
        }
        if (isStationary) return
        isStationary = true

        // Power off high-accuracy GPS
        fusedLocationClient.removeLocationUpdates(locationCallback)

        // Drop stationary geofence at last known fix
        val last = lastValidLocation
        if (last != null) {
            stationaryGeofenceMgr.armStationaryGeofence(last.latitude, last.longitude, stationaryRadius)
        }
        updateNotification("Device Stationary", "GPS powered off to conserve battery.")
        Log.i(TAG, "Entered STATIONARY mode. GPS power is OFF.")
    }

    private fun handleExitStationary() {
        if (!isStationary) return
        isStationary = false

        stationaryGeofenceMgr.disarmStationaryGeofence()
        requestLocationUpdates()
        updateNotification(notificationTitle, notificationText)
        Log.i(TAG, "Exited STATIONARY mode. GPS power is ON.")
    }

    private fun processLocation(location: Location) {
        // Quality Gate: filter multipath spikes and very low accuracy
        if (location.accuracy > 40.0f) {
            Log.d(TAG, "Skipping low accuracy fix (${location.accuracy}m).")
            return
        }

        // Deduplication: Guard against duplicate fixes with identical timestamp or identical coordinates within 1s window
        val prev = lastValidLocation
        if (prev != null) {
            if (location.time > 0 && location.time == prev.time) {
                Log.d(TAG, "Skipping duplicate location with identical timestamp: ${location.time}")
                return
            }
            if (location.latitude == prev.latitude && location.longitude == prev.longitude &&
                Math.abs(location.time - prev.time) < 1000) {
                Log.d(TAG, "Skipping identical coordinate fix within 1s window.")
                return
            }
        }

        // Accumulate odometer
        if (prev != null) {
            val dist = prev.distanceTo(location)
            if (dist > 1.0f) {
                totalOdometer += dist
            }
        }
        lastValidLocation = location

        val (batteryLevel, isCharging) = getBatteryInfo()
        val activity = if (isStationary) "still" else if (location.speed > 5.0f) "in_vehicle" else if (location.speed > 1.5f) "running" else if (location.speed > 0.5f) "walking" else "still"

        val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }

        if (isMock) {
            Log.w(TAG, "Mock location detected! Lat=${location.latitude}, Lng=${location.longitude}")
            dbHelper.insertLog("WARN", "Mock location spoof detected! [lat=${location.latitude}, lng=${location.longitude}]")
        }

        val isNetworkOnline = httpSyncMgr.isNetworkAvailable()
        val isAppAttached = CustomBackgroundGeolocationPlugin.isEngineAttached
        val isSynced = if (HttpSyncManager.syncUrl.isNullOrEmpty()) {
            isNetworkOnline && isAppAttached
        } else {
            false
        }

        val entity = LocationEntity(
            uuid = UUID.randomUUID().toString(),
            latitude = location.latitude,
            longitude = location.longitude,
            accuracy = location.accuracy,
            altitude = location.altitude,
            speed = location.speed,
            heading = location.bearing,
            odometer = totalOdometer,
            activityType = activity,
            activityConfidence = 100,
            batteryLevel = batteryLevel,
            batteryIsCharging = isCharging,
            timestamp = location.time.takeIf { it > 0 } ?: System.currentTimeMillis(),
            isSynced = isSynced,
            isMock = isMock,
            extrasJson = extrasJson
        )

        // ALWAYS SAVE TO SQLITE FIRST (offline survival)
        dbHelper.insertLocation(entity)

        // Stream to Flutter UI if active
        CustomBackgroundGeolocationPlugin.sendLocationEvent(entity)

        // Auto-sync batch to backend if reachable
        httpSyncMgr.syncPendingLocations()
    }

    private fun getBatteryInfo(): Pair<Float, Boolean> {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val level = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 100
        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val status = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
            status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        } else false
        return Pair(level / 100.0f, isCharging)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps geolocation tracking alive in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(title: String, text: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(NOTIFICATION_ID, buildNotification(title, text))
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
