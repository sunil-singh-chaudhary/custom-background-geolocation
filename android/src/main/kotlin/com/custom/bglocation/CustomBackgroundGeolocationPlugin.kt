package com.custom.bglocation

/**
 * CustomBackgroundGeolocationPlugin
 * Production-grade background geolocation engine for Flutter.
 */

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.custom.bglocation.db.LocationDatabaseHelper
import com.custom.bglocation.db.LocationEntity
import com.custom.bglocation.http.HttpSyncManager
import com.custom.bglocation.receiver.BootReceiver
import com.custom.bglocation.service.LocationTrackingService
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject

class CustomBackgroundGeolocationPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "CustomBgGeoPlugin"
        private const val PERMISSION_REQUEST_CODE_FOREGROUND = 9081
        private const val PERMISSION_REQUEST_CODE_BACKGROUND = 9082
        private const val BATTERY_OPTIMIZATION_REQUEST_CODE = 9083

        private const val METHOD_CHANNEL_NAME = "com.custom.bglocation/methods"
        private const val LOCATION_EVENT_CHANNEL_NAME = "com.custom.bglocation/events/location"
        private const val MOTION_EVENT_CHANNEL_NAME = "com.custom.bglocation/events/motion"
        private const val GEOFENCE_EVENT_CHANNEL_NAME = "com.custom.bglocation/events/geofence"
        private const val HEARTBEAT_EVENT_CHANNEL_NAME = "com.custom.bglocation/events/heartbeat"

        @Volatile
        var isEngineAttached = false
        private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

        private var locationEventSink: EventChannel.EventSink? = null
        private var motionEventSink: EventChannel.EventSink? = null
        private var geofenceEventSink: EventChannel.EventSink? = null
        private var heartbeatEventSink: EventChannel.EventSink? = null

        fun sendLocationEvent(entity: LocationEntity) {
            if (!isEngineAttached || locationEventSink == null) return
            val map = entity.toMap()
            mainHandler.post {
                if (!isEngineAttached) return@post
                try {
                    locationEventSink?.success(map)
                } catch (t: Throwable) {
                    Log.w(TAG, "Unable to send location event (engine detached): ${t.message}")
                }
            }
        }

        fun sendMotionEvent(activity: String, confidence: Int) {
            if (!isEngineAttached || motionEventSink == null) return
            val map = mapOf(
                "activity" to activity,
                "confidence" to confidence,
                "timestamp" to System.currentTimeMillis()
            )
            mainHandler.post {
                if (!isEngineAttached) return@post
                try {
                    motionEventSink?.success(map)
                } catch (t: Throwable) {
                    Log.w(TAG, "Unable to send motion event (engine detached): ${t.message}")
                }
            }
        }

        fun sendGeofenceEvent(identifier: String, action: Int) {
            if (!isEngineAttached || geofenceEventSink == null) return
            val map = mapOf(
                "identifier" to identifier,
                "action" to action,
                "timestamp" to System.currentTimeMillis()
            )
            mainHandler.post {
                if (!isEngineAttached) return@post
                try {
                    geofenceEventSink?.success(map)
                } catch (t: Throwable) {
                    Log.w(TAG, "Unable to send geofence event (engine detached): ${t.message}")
                }
            }
        }

        fun sendHeartbeatEvent(latitude: Double, longitude: Double, batteryLevel: Float, isCharging: Boolean) {
            if (!isEngineAttached || heartbeatEventSink == null) return
            val map = mapOf(
                "latitude" to latitude,
                "longitude" to longitude,
                "batteryLevel" to batteryLevel.toDouble(),
                "isCharging" to isCharging,
                "timestamp" to System.currentTimeMillis()
            )
            mainHandler.post {
                if (!isEngineAttached) return@post
                try {
                    heartbeatEventSink?.success(map)
                } catch (t: Throwable) {
                    Log.w(TAG, "Unable to send heartbeat event (engine detached): ${t.message}")
                }
            }
        }
    }

    private lateinit var context: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var methodChannel: MethodChannel? = null
    private var locationEventChannel: EventChannel? = null
    private var motionEventChannel: EventChannel? = null
    private var geofenceEventChannel: EventChannel? = null
    private var heartbeatEventChannel: EventChannel? = null

    private lateinit var dbHelper: LocationDatabaseHelper
    private lateinit var httpSyncMgr: HttpSyncManager

    private var pendingResult: MethodChannel.Result? = null
    private var shouldStartAfterPermissions: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        dbHelper = LocationDatabaseHelper.getInstance(context)
        httpSyncMgr = HttpSyncManager(context)
        isEngineAttached = true

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }

        locationEventChannel = EventChannel(binding.binaryMessenger, LOCATION_EVENT_CHANNEL_NAME).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    locationEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    locationEventSink = null
                }
            })
        }

        motionEventChannel = EventChannel(binding.binaryMessenger, MOTION_EVENT_CHANNEL_NAME).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    motionEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    motionEventSink = null
                }
            })
        }

        geofenceEventChannel = EventChannel(binding.binaryMessenger, GEOFENCE_EVENT_CHANNEL_NAME).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    geofenceEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    geofenceEventSink = null
                }
            })
        }

        heartbeatEventChannel = EventChannel(binding.binaryMessenger, HEARTBEAT_EVENT_CHANNEL_NAME).also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    heartbeatEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    heartbeatEventSink = null
                }
            })
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        isEngineAttached = false
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        locationEventChannel?.setStreamHandler(null)
        locationEventChannel = null

        motionEventChannel?.setStreamHandler(null)
        motionEventChannel = null

        geofenceEventChannel?.setStreamHandler(null)
        geofenceEventChannel = null

        heartbeatEventChannel?.setStreamHandler(null)
        heartbeatEventChannel = null

        locationEventSink = null
        motionEventSink = null
        geofenceEventSink = null
        heartbeatEventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> {
                handleReady(call, result)
            }
            "start" -> {
                handleStart(result)
            }
            "stop" -> {
                handleStop(result)
            }
            "isRunning" -> {
                result.success(LocationTrackingService.isRunning)
            }
            "requestPermission" -> {
                handleRequestPermission(result)
            }
            "getCurrentPosition" -> {
                handleGetCurrentPosition(result)
            }
            "getLocations" -> {
                handleGetLocations(call, result)
            }
            "getUnsyncedCount" -> {
                result.success(dbHelper.getUnsyncedCount())
            }
            "sync" -> {
                httpSyncMgr.syncPendingLocations { success, _ ->
                    result.success(success)
                }
            }
            "checkPermissionStatus" -> {
                handleCheckPermissionStatus(result)
            }
            "requestBatteryExemption" -> {
                handleRequestBatteryExemption(result)
            }
            "isIgnoringBatteryOptimizations" -> {
                result.success(isIgnoringBatteryOptimizations())
            }
            "openAppSettings" -> {
                handleOpenAppSettings(result)
            }
            "destroyLocations" -> {
                dbHelper.clearAll()
                result.success(true)
            }
            "showPowerManager" -> {
                handleShowPowerManager(result)
            }
            "getLog" -> {
                result.success(dbHelper.getLogs())
            }
            "destroyLog" -> {
                dbHelper.clearLogs()
                result.success(true)
            }
            "log" -> {
                val level = call.argument<String>("level") ?: "INFO"
                val message = call.argument<String>("message") ?: ""
                dbHelper.insertLog(level, message)
                result.success(true)
            }
            "emailLog" -> {
                handleEmailLog(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleReady(call: MethodCall, result: MethodChannel.Result) {
        val distanceFilter = (call.argument<Number>("distanceFilter"))?.toFloat() ?: 20.0f
        val stationaryRadius = (call.argument<Number>("stationaryRadius"))?.toFloat() ?: 25.0f
        val notifTitle = call.argument<String>("notificationTitle") ?: "Location Service Active"
        val notifText = call.argument<String>("notificationText") ?: "Monitoring location in background"
        val syncUrl = call.argument<String>("syncUrl")
        val syncHeaders = call.argument<Map<String, String>>("syncHeaders")
        val syncBatchSize = call.argument<Int>("syncBatchSize") ?: 25
        val heartbeatInterval = call.argument<Int>("heartbeatInterval") ?: 60
        val extras = call.argument<Map<String, Any>>("extras")

        LocationTrackingService.distanceFilter = distanceFilter
        LocationTrackingService.stationaryRadius = stationaryRadius
        LocationTrackingService.heartbeatInterval = heartbeatInterval
        LocationTrackingService.notificationTitle = notifTitle
        LocationTrackingService.notificationText = notifText
        if (extras != null) {
            LocationTrackingService.extrasJson = JSONObject(extras).toString()
        }

        HttpSyncManager.syncUrl = syncUrl
        HttpSyncManager.syncHeaders = syncHeaders
        HttpSyncManager.batchSize = syncBatchSize

        result.success(true)
    }

    private fun hasForegroundLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine && coarse
    }

    private fun isBackgroundLocationGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun isActivityRecognitionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun isPostNotificationsGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            pm?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
            true
        }
    }

    private fun requestBatteryOptimizationExemption(act: Activity?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isIgnoringBatteryOptimizations()) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    if (act != null) {
                        act.startActivity(intent)
                    } else {
                        context.startActivity(intent)
                    }
                    return true
                } catch (e: Exception) {
                    Log.w(TAG, "ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS failed, trying fallback: ${e.message}")
                    try {
                        val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        if (act != null) act.startActivity(fallback) else context.startActivity(fallback)
                        return true
                    } catch (e2: Exception) {
                        Log.e(TAG, "Failed to open battery settings: ${e2.message}")
                    }
                }
            }
        }
        return false
    }

    private fun handleCheckPermissionStatus(result: MethodChannel.Result) {
        val map = mapOf(
            "fineLocation" to (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED),
            "coarseLocation" to (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED),
            "backgroundLocation" to isBackgroundLocationGranted(),
            "activityRecognition" to isActivityRecognitionGranted(),
            "postNotifications" to isPostNotificationsGranted(),
            "batteryOptimizationIgnored" to isIgnoringBatteryOptimizations(),
            "allGranted" to (hasForegroundLocationPermission() && isBackgroundLocationGranted() && isIgnoringBatteryOptimizations())
        )
        result.success(map)
    }

    private fun handleRequestBatteryExemption(result: MethodChannel.Result) {
        if (isIgnoringBatteryOptimizations()) {
            result.success(true)
            return
        }
        val act = activity
        val launched = requestBatteryOptimizationExemption(act)
        result.success(launched)
    }

    private fun handleOpenAppSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (activity != null) activity?.startActivity(intent) else context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_SETTINGS_FAILED", e.message, null)
        }
    }

    private fun handleShowPowerManager(result: MethodChannel.Result) {
        val oemIntents = listOf(
            // Xiaomi / MIUI / HyperOS AutoStart & Battery
            Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(android.content.ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")),
            // Huawei / HarmonyOS Protected Apps
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")),
            // Samsung Device Care
            Intent().setComponent(android.content.ComponentName("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(android.content.ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            // Oppo / Realme Startup Manager
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity")),
            // Vivo iManager AddWhiteListActivity
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.PurviewTabActivity")),
            // Standard Android Doze Settings Fallback
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        )

        for (intent in oemIntents) {
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                if (activity != null) {
                    activity?.startActivity(intent)
                } else {
                    context.startActivity(intent)
                }
                result.success(true)
                return
            } catch (_: Exception) {
                // Try next OEM intent in cascade
            }
        }

        // Fallback to application settings
        handleOpenAppSettings(result)
    }

    private fun handleEmailLog(call: MethodCall, result: MethodChannel.Result) {
        val email = call.argument<String>("email") ?: ""
        val logs = dbHelper.getLogs()
        try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:$email")
                putExtra(Intent.EXTRA_SUBJECT, "Diagnostic Tracking Logs (${context.packageName})")
                putExtra(Intent.EXTRA_TEXT, logs)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (activity != null) activity?.startActivity(intent) else context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("EMAIL_LOG_FAILED", e.message, null)
        }
    }

    private fun processPermissionFlow(result: MethodChannel.Result, startOnSuccess: Boolean) {
        val act = activity
        if (act == null) {
            if (hasForegroundLocationPermission()) {
                if (startOnSuccess) {
                    executeStartService(result)
                } else {
                    result.success(true)
                }
            } else {
                result.error("NO_ACTIVITY", "Cannot request permissions without an active foreground window", null)
            }
            return
        }

        pendingResult = result
        shouldStartAfterPermissions = startOnSuccess

        val missingForeground = mutableListOf<String>()
        if (!hasForegroundLocationPermission()) {
            missingForeground.add(Manifest.permission.ACCESS_FINE_LOCATION)
            missingForeground.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (!isActivityRecognitionGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            missingForeground.add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        if (!isPostNotificationsGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            missingForeground.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        // Step 1: Prompt missing foreground permissions first
        if (missingForeground.isNotEmpty()) {
            ActivityCompat.requestPermissions(act, missingForeground.toTypedArray(), PERMISSION_REQUEST_CODE_FOREGROUND)
            return
        }

        // Step 2: Foreground already granted. Check background location on Q+
        if (!isBackgroundLocationGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), PERMISSION_REQUEST_CODE_BACKGROUND)
            return
        }

        // Step 3: Foreground and Background location granted. Prompt battery saver exemption
        if (!isIgnoringBatteryOptimizations()) {
            requestBatteryOptimizationExemption(act)
        }

        completePermissionFlow(true)
    }

    private fun completePermissionFlow(success: Boolean, errorMessage: String? = null) {
        val res = pendingResult
        val startService = shouldStartAfterPermissions
        pendingResult = null
        shouldStartAfterPermissions = false

        if (!success) {
            res?.error("PERMISSION_DENIED", errorMessage ?: "Permissions denied", null)
            return
        }

        if (startService) {
            executeStartService(res)
        } else {
            res?.success(true)
        }
    }

    private fun handleRequestPermission(result: MethodChannel.Result) {
        processPermissionFlow(result, startOnSuccess = false)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        val act = activity
        when (requestCode) {
            PERMISSION_REQUEST_CODE_FOREGROUND -> {
                val fineIndex = permissions.indexOf(Manifest.permission.ACCESS_FINE_LOCATION)
                val fineGranted = if (fineIndex >= 0 && fineIndex < grantResults.size) {
                    grantResults[fineIndex] == PackageManager.PERMISSION_GRANTED
                } else {
                    hasForegroundLocationPermission()
                }

                if (!fineGranted) {
                    completePermissionFlow(false, "User denied fine location permission")
                    return true
                }

                // Check background location on Q+
                if (!isBackgroundLocationGranted() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && act != null) {
                    ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), PERMISSION_REQUEST_CODE_BACKGROUND)
                    return true
                }

                // Prompt battery optimization exemption if not ignored
                if (!isIgnoringBatteryOptimizations()) {
                    requestBatteryOptimizationExemption(act)
                }

                completePermissionFlow(true)
                return true
            }

            PERMISSION_REQUEST_CODE_BACKGROUND -> {
                if (!isIgnoringBatteryOptimizations()) {
                    requestBatteryOptimizationExemption(act)
                }

                completePermissionFlow(true)
                return true
            }
        }
        return false
    }

    private fun handleStart(result: MethodChannel.Result) {
        processPermissionFlow(result, startOnSuccess = true)
    }

    private fun executeStartService(result: MethodChannel.Result?) {
        val prefs = context.getSharedPreferences(BootReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(BootReceiver.KEY_ENABLED, true).apply()

        val intent = Intent(context, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_START
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            result?.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting service: ${e.message}", e)
            result?.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStop(result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences(BootReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(BootReceiver.KEY_ENABLED, false).apply()

        val intent = Intent(context, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_STOP
        }
        context.startService(intent)
        result.success(true)
    }

    @SuppressLint("MissingPermission")
    private fun handleGetCurrentPosition(result: MethodChannel.Result) {
        val fused = LocationServices.getFusedLocationProviderClient(context)
        fused.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
            .addOnSuccessListener { loc ->
                if (loc != null) {
                    val entity = LocationEntity(
                        uuid = java.util.UUID.randomUUID().toString(),
                        latitude = loc.latitude,
                        longitude = loc.longitude,
                        accuracy = loc.accuracy,
                        altitude = loc.altitude,
                        speed = loc.speed,
                        heading = loc.bearing,
                        timestamp = loc.time.takeIf { it > 0 } ?: System.currentTimeMillis()
                    )
                    result.success(entity.toMap())
                } else {
                    fused.lastLocation.addOnSuccessListener { last ->
                        if (last != null) {
                            val entity = LocationEntity(
                                uuid = java.util.UUID.randomUUID().toString(),
                                latitude = last.latitude,
                                longitude = last.longitude,
                                accuracy = last.accuracy,
                                altitude = last.altitude,
                                speed = last.speed,
                                heading = last.bearing,
                                timestamp = last.time.takeIf { it > 0 } ?: System.currentTimeMillis()
                            )
                            result.success(entity.toMap())
                        } else {
                            result.error("NO_LOCATION", "Unable to obtain location fix", null)
                        }
                    }
                }
            }
            .addOnFailureListener { e ->
                result.error("LOCATION_ERROR", e.message, null)
            }
    }

    private fun handleGetLocations(call: MethodCall, result: MethodChannel.Result) {
        val unsyncedOnly = call.argument<Boolean>("unsyncedOnly") ?: false
        val limit = call.argument<Int>("limit") ?: 250
        val list = if (unsyncedOnly) {
            dbHelper.getUnsyncedLocations(limit)
        } else {
            dbHelper.getAllLocations(limit)
        }
        result.success(list.map { it.toMap() })
    }
}
