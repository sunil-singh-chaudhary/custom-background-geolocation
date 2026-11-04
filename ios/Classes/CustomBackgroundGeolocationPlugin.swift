//
//  CustomBackgroundGeolocationPlugin.swift
//  Custom Background Geolocation Plugin for Flutter.
//

import Flutter
import UIKit
import CoreLocation
import CoreMotion
import Network

public class CustomBackgroundGeolocationPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

    private static var instance: CustomBackgroundGeolocationPlugin?

    private var locationManager: CLLocationManager?
    private let motionActivityManager = CMMotionActivityManager()
    private let motionQueue = OperationQueue()
    private let db = LocationDatabase.shared

    private var locationEventSink: FlutterEventSink?
    private var motionEventSink: FlutterEventSink?
    private var geofenceEventSink: FlutterEventSink?

    private var isTracking = false
    private var isStationary = false
    private var distanceFilter: Double = 20.0
    private var stationaryRadius: Double = 25.0
    private var syncUrl: String?
    private var syncHeaders: [String: String]?
    private var syncBatchSize: Int = 25
    private var extrasJson: String?

    private var lastLocation: CLLocation?
    private var totalOdometer: Double = 0.0

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.custom.bglocation.networkMonitor")

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CustomBackgroundGeolocationPlugin()
        CustomBackgroundGeolocationPlugin.instance = instance

        let methodChannel = FlutterMethodChannel(name: "com.custom.bglocation/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let locationEventChannel = FlutterEventChannel(name: "com.custom.bglocation/events/location", binaryMessenger: registrar.messenger())
        locationEventChannel.setStreamHandler(LocationStreamHandler(instance: instance))

        let motionEventChannel = FlutterEventChannel(name: "com.custom.bglocation/events/motion", binaryMessenger: registrar.messenger())
        motionEventChannel.setStreamHandler(MotionStreamHandler(instance: instance))

        let geofenceEventChannel = FlutterEventChannel(name: "com.custom.bglocation/events/geofence", binaryMessenger: registrar.messenger())
        geofenceEventChannel.setStreamHandler(GeofenceStreamHandler(instance: instance))

        instance.setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("[CustomBgGeo iOS] Network connection satisfied. Triggering auto-sync of offline SQLite queue.")
                self?.performHttpSync()
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "ready":
            handleReady(call: call, result: result)
        case "start":
            handleStart(result: result)
        case "stop":
            handleStop(result: result)
        case "isRunning":
            result(isTracking)
        case "requestPermission":
            handleRequestPermission(result: result)
        case "getCurrentPosition":
            handleGetCurrentPosition(result: result)
        case "getLocations":
            handleGetLocations(call: call, result: result)
        case "getUnsyncedCount":
            result(db.getUnsyncedCount())
        case "sync":
            performHttpSync { success, _ in
                result(success)
            }
        case "checkPermissionStatus":
            let auth = CLLocationManager.authorizationStatus()
            let bgGranted = (auth == .authorizedAlways)
            let fineGranted = (auth == .authorizedAlways || auth == .authorizedWhenInUse)
            result([
                "fineLocation": fineGranted,
                "coarseLocation": fineGranted,
                "backgroundLocation": bgGranted,
                "activityRecognition": true,
                "postNotifications": true,
                "batteryOptimizationIgnored": true,
                "allGranted": bgGranted
            ])
        case "requestBatteryExemption":
            result(true)
        case "isIgnoringBatteryOptimizations":
            result(true)
        case "openAppSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    result(true)
                    return
                }
            }
            result(false)
        case "destroyLocations":
            db.clearAll()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func ensureLocationManager() {
        if locationManager == nil {
            let lm = CLLocationManager()
            lm.delegate = self
            lm.desiredAccuracy = kCLLocationAccuracyBest
            lm.distanceFilter = distanceFilter
            lm.allowsBackgroundLocationUpdates = true
            lm.pausesLocationUpdatesAutomatically = false
            if #available(iOS 11.0, *) {
                lm.showsBackgroundLocationIndicator = true
            }
            locationManager = lm
        }
    }

    private func handleReady(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }

        if let df = args["distanceFilter"] as? NSNumber {
            distanceFilter = df.doubleValue
        }
        if let sr = args["stationaryRadius"] as? NSNumber {
            stationaryRadius = sr.doubleValue
        }
        if let url = args["syncUrl"] as? String {
            syncUrl = url
        }
        if let headers = args["syncHeaders"] as? [String: String] {
            syncHeaders = headers
        }
        if let batch = args["syncBatchSize"] as? Int {
            syncBatchSize = batch
        }
        if let extras = args["extras"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: extras),
           let str = String(data: data, encoding: .utf8) {
            extrasJson = str
        }

        ensureLocationManager()
        locationManager?.distanceFilter = distanceFilter
        result(true)
    }

    private func handleRequestPermission(result: @escaping FlutterResult) {
        ensureLocationManager()
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            result(true)
        } else {
            locationManager?.requestAlwaysAuthorization()
            result(true)
        }
    }

    private func handleStart(result: @escaping FlutterResult) {
        ensureLocationManager()
        let status = CLLocationManager.authorizationStatus()
        if status != .authorizedAlways && status != .authorizedWhenInUse {
            locationManager?.requestAlwaysAuthorization()
        }

        isTracking = true
        isStationary = false

        locationManager?.startUpdatingLocation()
        locationManager?.startMonitoringSignificantLocationChanges()
        startMotionActivityMonitoring()

        print("[CustomBgGeo iOS] Native iOS background tracking started.")
        result(true)
    }

    private func handleStop(result: @escaping FlutterResult) {
        isTracking = false
        isStationary = false

        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
        motionActivityManager.stopActivityUpdates()

        print("[CustomBgGeo iOS] Native iOS background tracking stopped.")
        result(true)
    }

    private func handleGetCurrentPosition(result: @escaping FlutterResult) {
        ensureLocationManager()
        if let loc = locationManager?.location {
            let record = buildRecord(location: loc, activityType: "still")
            result(record.toDictionary())
        } else {
            result(FlutterError(code: "NO_LOCATION", message: "Location currently unavailable", details: nil))
        }
    }

    private func handleGetLocations(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let unsyncedOnly = args?["unsyncedOnly"] as? Bool ?? false
        let list = unsyncedOnly ? db.getUnsyncedLocations(limit: 100) : db.getAllLocations(limit: 100)
        result(list.map { $0.toDictionary() })
    }

    // MARK: - Motion Coprocessor (CMMotionActivityManager)

    private func startMotionActivityMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        motionActivityManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let self = self, let act = activity else { return }

            let actName: String
            let conf: Int = act.confidence == .high ? 100 : (act.confidence == .medium ? 75 : 50)

            if act.automotive {
                actName = "in_vehicle"
            } else if act.running {
                actName = "running"
            } else if act.walking {
                actName = "walking"
            } else if act.cycling {
                actName = "on_bicycle"
            } else if act.stationary {
                actName = "still"
            } else {
                actName = "unknown"
            }

            DispatchQueue.main.async {
                self.motionEventSink?([
                    "activity": actName,
                    "confidence": conf,
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                ])

                // Stationary state management: power down high-accuracy GPS if resting
                if act.stationary && !self.isStationary {
                    self.isStationary = true
                    self.locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
                    self.locationManager?.distanceFilter = 99999
                    print("[CustomBgGeo iOS] Entered STATIONARY state. High accuracy GPS paused to conserve battery.")
                } else if !act.stationary && self.isStationary {
                    self.isStationary = false
                    self.locationManager?.desiredAccuracy = kCLLocationAccuracyBest
                    self.locationManager?.distanceFilter = self.distanceFilter
                    print("[CustomBgGeo iOS] Exited STATIONARY state. Resuming high-accuracy GPS.")
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            // Quality gate: skip fixes with inaccurate horizontal radius (> 40m)
            if loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 40.0 {
                continue
            }

            if let prev = lastLocation {
                let dist = loc.distance(from: prev)
                if dist > 1.0 {
                    totalOdometer += dist
                }
            }
            lastLocation = loc

            let activity = isStationary ? "still" : (loc.speed > 5.0 ? "in_vehicle" : (loc.speed > 1.5 ? "running" : (loc.speed > 0.5 ? "walking" : "still")))
            let record = buildRecord(location: loc, activityType: activity)

            // ALWAYS INSERT TO NATIVE SQLITE FIRST (offline survival)
            db.insert(location: record)

            // Emit to Flutter EventChannel if app is active
            DispatchQueue.main.async {
                self.locationEventSink?(record.toDictionary())
            }

            // Attempt batch HTTP sync if network is available
            performHttpSync()
        }
    }

    private func buildRecord(location: CLLocation, activityType: String) -> LocationRecord {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battLevel = Double(max(0, UIDevice.current.batteryLevel))
        let isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full

        return LocationRecord(
            uuid: UUID().uuidString,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            altitude: location.altitude,
            speed: max(0, location.speed),
            heading: location.course,
            odometer: totalOdometer,
            activityType: activityType,
            activityConfidence: 100,
            batteryLevel: battLevel,
            batteryIsCharging: isCharging,
            timestamp: Int64(location.timestamp.timeIntervalSince1970 * 1000),
            isSynced: false,
            extrasJson: extrasJson
        )
    }

    // MARK: - HTTP Sync Engine

    private func performHttpSync(completion: ((Bool, Int) -> Void)? = nil) {
        guard let urlStr = syncUrl, let url = URL(string: urlStr) else {
            completion?(false, 0)
            return
        }

        let pending = db.getUnsyncedLocations(limit: syncBatchSize)
        guard !pending.isEmpty else {
            completion?(true, 0)
            return
        }

        let jsonArray = pending.map { $0.toJsonObject() }
        let bodyObj: [String: Any] = [
            "locations": jsonArray,
            "batchSize": pending.count,
            "syncedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: bodyObj) else {
            completion?(false, 0)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        syncHeaders?.forEach { k, v in
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = httpBody
        request.timeoutInterval = 15

        let uuids = pending.map { $0.uuid }

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                self?.db.markAsSynced(uuids: uuids)
                print("[CustomBgGeo iOS] Successfully synced \(uuids.count) offline locations to server.")
                completion?(true, uuids.count)
            } else {
                print("[CustomBgGeo iOS] HTTP sync failed or offline. Coordinates remain safely preserved in SQLite.")
                completion?(false, 0)
            }
        }
        task.resume()
    }

    // MARK: - Internal Stream Handlers

    class LocationStreamHandler: NSObject, FlutterStreamHandler {
        weak var instance: CustomBackgroundGeolocationPlugin?
        init(instance: CustomBackgroundGeolocationPlugin) { self.instance = instance }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            instance?.locationEventSink = events
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            instance?.locationEventSink = nil
            return nil
        }
    }

    class MotionStreamHandler: NSObject, FlutterStreamHandler {
        weak var instance: CustomBackgroundGeolocationPlugin?
        init(instance: CustomBackgroundGeolocationPlugin) { self.instance = instance }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            instance?.motionEventSink = events
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            instance?.motionEventSink = nil
            return nil
        }
    }

    class GeofenceStreamHandler: NSObject, FlutterStreamHandler {
        weak var instance: CustomBackgroundGeolocationPlugin?
        init(instance: CustomBackgroundGeolocationPlugin) { self.instance = instance }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            instance?.geofenceEventSink = events
            return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            instance?.geofenceEventSink = nil
            return nil
        }
    }
}
