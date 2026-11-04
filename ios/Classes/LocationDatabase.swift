import Foundation
import SQLite3

public struct LocationRecord {
    public let uuid: String
    public let latitude: Double
    public let longitude: Double
    public let accuracy: Double
    public let altitude: Double
    public let speed: Double
    public let heading: Double
    public let odometer: Double
    public let activityType: String
    public let activityConfidence: Int
    public let batteryLevel: Double
    public let batteryIsCharging: Bool
    public let timestamp: Int64
    public let isSynced: Bool
    public let isMock: Bool
    public let extrasJson: String?

    public init(
        uuid: String,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        altitude: Double,
        speed: Double,
        heading: Double,
        odometer: Double,
        activityType: String,
        activityConfidence: Int,
        batteryLevel: Double,
        batteryIsCharging: Bool,
        timestamp: Int64,
        isSynced: Bool,
        isMock: Bool = false,
        extrasJson: String? = nil
    ) {
        self.uuid = uuid
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.altitude = altitude
        self.speed = speed
        self.heading = heading
        self.odometer = odometer
        self.activityType = activityType
        self.activityConfidence = activityConfidence
        self.batteryLevel = batteryLevel
        self.batteryIsCharging = batteryIsCharging
        self.timestamp = timestamp
        self.isSynced = isSynced
        self.isMock = isMock
        self.extrasJson = extrasJson
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "uuid": uuid,
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy,
            "altitude": altitude,
            "speed": speed,
            "heading": heading,
            "odometer": odometer,
            "activityType": activityType,
            "activityConfidence": activityConfidence,
            "batteryLevel": batteryLevel,
            "batteryIsCharging": batteryIsCharging,
            "timestamp": timestamp,
            "isSynced": isSynced,
            "isMock": isMock
        ]
        if let extras = extrasJson,
           let data = extras.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict["extras"] = json
        }
        return dict
    }

    public func toJsonObject() -> [String: Any] {
        var dict = toDictionary()
        if let extras = extrasJson,
           let data = extras.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (k, v) in json {
                dict[k] = v
            }
        }
        return dict
    }
}

public class LocationDatabase {
    public static let shared = LocationDatabase()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        let fileManager = FileManager.default
        guard let docUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dbPath = docUrl.appendingPathComponent("custom_bg_locations.sqlite").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[LocationDB] Error opening iOS SQLite database at \(dbPath)")
        } else {
            print("[LocationDB] Successfully opened iOS SQLite database at \(dbPath)")
        }
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL NOT NULL,
            altitude REAL DEFAULT 0.0,
            speed REAL DEFAULT 0.0,
            heading REAL DEFAULT 0.0,
            odometer REAL DEFAULT 0.0,
            activity_type TEXT DEFAULT 'still',
            activity_confidence INTEGER DEFAULT 100,
            battery_level REAL DEFAULT 1.0,
            battery_is_charging INTEGER DEFAULT 0,
            timestamp INTEGER NOT NULL,
            is_synced INTEGER DEFAULT 0,
            extras TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_is_synced ON locations (is_synced);
        CREATE INDEX IF NOT EXISTS idx_timestamp ON locations (timestamp);
        """
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            print("[LocationDB] Error creating locations table")
        }
    }

    public func insert(location: LocationRecord) {
        let sql = """
        INSERT OR REPLACE INTO locations
        (uuid, latitude, longitude, accuracy, altitude, speed, heading, odometer,
         activity_type, activity_confidence, battery_level, battery_is_charging,
         timestamp, is_synced, extras)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (location.uuid as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, location.latitude)
            sqlite3_bind_double(stmt, 3, location.longitude)
            sqlite3_bind_double(stmt, 4, location.accuracy)
            sqlite3_bind_double(stmt, 5, location.altitude)
            sqlite3_bind_double(stmt, 6, location.speed)
            sqlite3_bind_double(stmt, 7, location.heading)
            sqlite3_bind_double(stmt, 8, location.odometer)
            sqlite3_bind_text(stmt, 9, (location.activityType as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 10, Int32(location.activityConfidence))
            sqlite3_bind_double(stmt, 11, location.batteryLevel)
            sqlite3_bind_int(stmt, 12, location.batteryIsCharging ? 1 : 0)
            sqlite3_bind_int64(stmt, 13, location.timestamp)
            sqlite3_bind_int(stmt, 14, location.isSynced ? 1 : 0)
            if let extras = location.extrasJson {
                sqlite3_bind_text(stmt, 15, (extras as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 15)
            }

            if sqlite3_step(stmt) != SQLITE_DONE {
                print("[LocationDB] Failed to insert location into SQLite")
            }
        }
        sqlite3_finalize(stmt)
    }

    public func getUnsyncedLocations(limit: Int = 50) -> [LocationRecord] {
        var list: [LocationRecord] = []
        let sql = "SELECT * FROM locations WHERE is_synced = 0 ORDER BY timestamp ASC LIMIT ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(parseRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }

    public func getAllLocations(limit: Int = 100) -> [LocationRecord] {
        var list: [LocationRecord] = []
        let sql = "SELECT * FROM locations ORDER BY timestamp DESC LIMIT ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                list.append(parseRow(stmt))
            }
        }
        sqlite3_finalize(stmt)
        return list
    }

    public func getUnsyncedCount() -> Int {
        let sql = "SELECT COUNT(*) FROM locations WHERE is_synced = 0;"
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    public func markAsSynced(uuids: [String]) {
        guard !uuids.isEmpty else { return }
        let sql = "UPDATE locations SET is_synced = 1 WHERE uuid = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for uuid in uuids {
                sqlite3_bind_text(stmt, 1, (uuid as NSString).utf8String, -1, nil)
                _ = sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
        }
        sqlite3_finalize(stmt)
    }

    public func clearAll() {
        let sql = "DELETE FROM locations;"
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func parseRow(_ stmt: OpaquePointer?) -> LocationRecord {
        let uuid = String(cString: sqlite3_column_text(stmt, 1))
        let lat = sqlite3_column_double(stmt, 2)
        let lng = sqlite3_column_double(stmt, 3)
        let acc = sqlite3_column_double(stmt, 4)
        let alt = sqlite3_column_double(stmt, 5)
        let spd = sqlite3_column_double(stmt, 6)
        let hdg = sqlite3_column_double(stmt, 7)
        let odo = sqlite3_column_double(stmt, 8)
        let act = String(cString: sqlite3_column_text(stmt, 9))
        let conf = Int(sqlite3_column_int(stmt, 10))
        let batt = sqlite3_column_double(stmt, 11)
        let chg = sqlite3_column_int(stmt, 12) == 1
        let ts = sqlite3_column_int64(stmt, 13)
        let synced = sqlite3_column_int(stmt, 14) == 1
        var extras: String? = nil
        if let cExtras = sqlite3_column_text(stmt, 15) {
            extras = String(cString: cExtras)
        }

        return LocationRecord(
            uuid: uuid,
            latitude: lat,
            longitude: lng,
            accuracy: acc,
            altitude: alt,
            speed: spd,
            heading: hdg,
            odometer: odo,
            activityType: act,
            activityConfidence: conf,
            batteryLevel: batt,
            batteryIsCharging: chg,
            timestamp: ts,
            isSynced: synced,
            extrasJson: extras
        )
    }
}
