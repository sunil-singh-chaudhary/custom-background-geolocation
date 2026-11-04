package com.custom.bglocation.db

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class LocationDatabaseHelper private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "LocationDbHelper"
        private const val DATABASE_NAME = "custom_bg_locations.db"
        private const val DATABASE_VERSION = 1

        const val TABLE_NAME = "locations"
        const val COL_ID = "id"
        const val COL_UUID = "uuid"
        const val COL_LAT = "latitude"
        const val COL_LNG = "longitude"
        const val COL_ACCURACY = "accuracy"
        const val COL_ALTITUDE = "altitude"
        const val COL_SPEED = "speed"
        const val COL_HEADING = "heading"
        const val COL_ODOMETER = "odometer"
        const val COL_ACTIVITY = "activity_type"
        const val COL_CONFIDENCE = "activity_confidence"
        const val COL_BATTERY_LEVEL = "battery_level"
        const val COL_BATTERY_CHARGING = "battery_is_charging"
        const val COL_TIMESTAMP = "timestamp"
        const val COL_IS_SYNCED = "is_synced"
        const val COL_IS_MOCK = "is_mock"
        const val COL_EXTRAS = "extras"

        const val TABLE_LOGS = "logs"
        const val COL_LOG_ID = "id"
        const val COL_LOG_LEVEL = "level"
        const val COL_LOG_MESSAGE = "message"
        const val COL_LOG_TIMESTAMP = "timestamp"

        @Volatile
        private var instance: LocationDatabaseHelper? = null

        fun getInstance(context: Context): LocationDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: LocationDatabaseHelper(context).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createQuery = """
            CREATE TABLE $TABLE_NAME (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_UUID TEXT NOT NULL UNIQUE,
                $COL_LAT REAL NOT NULL,
                $COL_LNG REAL NOT NULL,
                $COL_ACCURACY REAL NOT NULL,
                $COL_ALTITUDE REAL DEFAULT 0.0,
                $COL_SPEED REAL DEFAULT 0.0,
                $COL_HEADING REAL DEFAULT 0.0,
                $COL_ODOMETER REAL DEFAULT 0.0,
                $COL_ACTIVITY TEXT DEFAULT 'still',
                $COL_CONFIDENCE INTEGER DEFAULT 100,
                $COL_BATTERY_LEVEL REAL DEFAULT 1.0,
                $COL_BATTERY_CHARGING INTEGER DEFAULT 0,
                $COL_TIMESTAMP INTEGER NOT NULL,
                $COL_IS_SYNCED INTEGER DEFAULT 0,
                $COL_IS_MOCK INTEGER DEFAULT 0,
                $COL_EXTRAS TEXT
            )
        """.trimIndent()
        db.execSQL(createQuery)
        db.execSQL("CREATE INDEX idx_is_synced ON $TABLE_NAME ($COL_IS_SYNCED)")
        db.execSQL("CREATE INDEX idx_timestamp ON $TABLE_NAME ($COL_TIMESTAMP)")

        val createLogsQuery = """
            CREATE TABLE $TABLE_LOGS (
                $COL_LOG_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_LOG_LEVEL TEXT NOT NULL,
                $COL_LOG_MESSAGE TEXT NOT NULL,
                $COL_LOG_TIMESTAMP INTEGER NOT NULL
            )
        """.trimIndent()
        db.execSQL(createLogsQuery)
        db.execSQL("CREATE INDEX idx_log_timestamp ON $TABLE_LOGS ($COL_LOG_TIMESTAMP)")

        Log.i(TAG, "Created locations and logs tables with indexes.")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_NAME")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_LOGS")
        onCreate(db)
    }

    @Synchronized
    fun insertLocation(loc: LocationEntity): Long {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put(COL_UUID, loc.uuid)
            put(COL_LAT, loc.latitude)
            put(COL_LNG, loc.longitude)
            put(COL_ACCURACY, loc.accuracy)
            put(COL_ALTITUDE, loc.altitude)
            put(COL_SPEED, loc.speed)
            put(COL_HEADING, loc.heading)
            put(COL_ODOMETER, loc.odometer)
            put(COL_ACTIVITY, loc.activityType)
            put(COL_CONFIDENCE, loc.activityConfidence)
            put(COL_BATTERY_LEVEL, loc.batteryLevel)
            put(COL_BATTERY_CHARGING, if (loc.batteryIsCharging) 1 else 0)
            put(COL_TIMESTAMP, loc.timestamp)
            put(COL_IS_SYNCED, if (loc.isSynced) 1 else 0)
            put(COL_IS_MOCK, if (loc.isMock) 1 else 0)
            put(COL_EXTRAS, loc.extrasJson)
        }
        val id = db.insertWithOnConflict(TABLE_NAME, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        Log.d(TAG, "Saved location to local SQLite: ${loc.latitude}, ${loc.longitude} [synced=${loc.isSynced}, isMock=${loc.isMock}] id=$id")
        return id
    }

    @Synchronized
    fun insertLog(level: String, message: String) {
        try {
            val db = writableDatabase
            val cv = ContentValues().apply {
                put(COL_LOG_LEVEL, level)
                put(COL_LOG_MESSAGE, message)
                put(COL_LOG_TIMESTAMP, System.currentTimeMillis())
            }
            db.insert(TABLE_LOGS, null, cv)
        } catch (e: Exception) {
            Log.e(TAG, "Error inserting persistent log: ${e.message}")
        }
    }

    @Synchronized
    fun getLogs(limit: Int = 500): String {
        val sb = StringBuilder()
        try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_LOGS,
                null,
                null,
                null,
                null,
                null,
                "$COL_LOG_TIMESTAMP ASC",
                limit.toString()
            )
            cursor.use {
                val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", java.util.Locale.US)
                while (it.moveToNext()) {
                    val ts = it.getLong(it.getColumnIndexOrThrow(COL_LOG_TIMESTAMP))
                    val level = it.getString(it.getColumnIndexOrThrow(COL_LOG_LEVEL))
                    val msg = it.getString(it.getColumnIndexOrThrow(COL_LOG_MESSAGE))
                    sb.append("[${sdf.format(java.util.Date(ts))}] [${level.uppercase()}] $msg\n")
                }
            }
        } catch (e: Exception) {
            sb.append("Error retrieving logs: ${e.message}")
        }
        return sb.toString()
    }

    @Synchronized
    fun clearLogs() {
        val db = writableDatabase
        db.delete(TABLE_LOGS, null, null)
        Log.i(TAG, "Cleared all diagnostic logs from local SQLite.")
    }

    @Synchronized
    fun getUnsyncedLocations(limit: Int = 50): List<LocationEntity> {
        val list = mutableListOf<LocationEntity>()
        val db = readableDatabase
        val cursor = db.query(
            TABLE_NAME,
            null,
            "$COL_IS_SYNCED = 0",
            null,
            null,
            null,
            "$COL_TIMESTAMP ASC",
            limit.toString()
        )
        cursor.use {
            while (it.moveToNext()) {
                list.add(cursorToEntity(it))
            }
        }
        return list
    }

    @Synchronized
    fun getAllLocations(limit: Int = 100): List<LocationEntity> {
        val list = mutableListOf<LocationEntity>()
        val db = readableDatabase
        val cursor = db.query(
            TABLE_NAME,
            null,
            null,
            null,
            null,
            null,
            "$COL_TIMESTAMP DESC",
            limit.toString()
        )
        cursor.use {
            while (it.moveToNext()) {
                list.add(cursorToEntity(it))
            }
        }
        return list
    }

    @Synchronized
    fun getUnsyncedCount(): Int {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT COUNT(*) FROM $TABLE_NAME WHERE $COL_IS_SYNCED = 0", null)
        cursor.use {
            if (it.moveToFirst()) {
                return it.getInt(0)
            }
        }
        return 0
    }

    @Synchronized
    fun markAsSynced(uuids: List<String>) {
        if (uuids.isEmpty()) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            val cv = ContentValues().apply { put(COL_IS_SYNCED, 1) }
            for (uuid in uuids) {
                db.update(TABLE_NAME, cv, "$COL_UUID = ?", arrayOf(uuid))
            }
            db.setTransactionSuccessful()
            Log.d(TAG, "Marked ${uuids.size} locations as synced in SQLite.")
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun markAllAsSynced(): Int {
        val db = writableDatabase
        val cv = ContentValues().apply { put(COL_IS_SYNCED, 1) }
        val count = db.update(TABLE_NAME, cv, "$COL_IS_SYNCED = 0", null)
        Log.d(TAG, "Marked all $count pending locations as synced in SQLite.")
        return count
    }

    @Synchronized
    fun clearAll() {
        val db = writableDatabase
        db.delete(TABLE_NAME, null, null)
        Log.i(TAG, "Cleared all locations from local SQLite.")
    }

    private fun cursorToEntity(c: Cursor): LocationEntity {
        val mockIndex = c.getColumnIndex(COL_IS_MOCK)
        val isMock = if (mockIndex >= 0) c.getInt(mockIndex) == 1 else false

        return LocationEntity(
            id = c.getLong(c.getColumnIndexOrThrow(COL_ID)),
            uuid = c.getString(c.getColumnIndexOrThrow(COL_UUID)),
            latitude = c.getDouble(c.getColumnIndexOrThrow(COL_LAT)),
            longitude = c.getDouble(c.getColumnIndexOrThrow(COL_LNG)),
            accuracy = c.getFloat(c.getColumnIndexOrThrow(COL_ACCURACY)),
            altitude = c.getDouble(c.getColumnIndexOrThrow(COL_ALTITUDE)),
            speed = c.getFloat(c.getColumnIndexOrThrow(COL_SPEED)),
            heading = c.getFloat(c.getColumnIndexOrThrow(COL_HEADING)),
            odometer = c.getDouble(c.getColumnIndexOrThrow(COL_ODOMETER)),
            activityType = c.getString(c.getColumnIndexOrThrow(COL_ACTIVITY)),
            activityConfidence = c.getInt(c.getColumnIndexOrThrow(COL_CONFIDENCE)),
            batteryLevel = c.getFloat(c.getColumnIndexOrThrow(COL_BATTERY_LEVEL)),
            batteryIsCharging = c.getInt(c.getColumnIndexOrThrow(COL_BATTERY_CHARGING)) == 1,
            timestamp = c.getLong(c.getColumnIndexOrThrow(COL_TIMESTAMP)),
            isSynced = c.getInt(c.getColumnIndexOrThrow(COL_IS_SYNCED)) == 1,
            isMock = isMock,
            extrasJson = c.getString(c.getColumnIndexOrThrow(COL_EXTRAS))
        )
    }
}
