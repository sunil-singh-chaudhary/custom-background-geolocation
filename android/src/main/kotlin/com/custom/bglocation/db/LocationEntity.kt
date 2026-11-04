package com.custom.bglocation.db

import org.json.JSONObject

data class LocationEntity(
    val id: Long = 0,
    val uuid: String,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Float,
    val altitude: Double = 0.0,
    val speed: Float = 0f,
    val heading: Float = 0f,
    val odometer: Double = 0.0,
    val activityType: String = "still",
    val activityConfidence: Int = 100,
    val batteryLevel: Float = 1.0f,
    val batteryIsCharging: Boolean = false,
    val timestamp: Long,
    val isSynced: Boolean = false,
    val isMock: Boolean = false,
    val extrasJson: String? = null
) {
    fun toMap(): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>(
            "uuid" to uuid,
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy.toDouble(),
            "altitude" to altitude,
            "speed" to speed.toDouble(),
            "heading" to heading.toDouble(),
            "odometer" to odometer,
            "activityType" to activityType,
            "activityConfidence" to activityConfidence,
            "batteryLevel" to batteryLevel.toDouble(),
            "batteryIsCharging" to batteryIsCharging,
            "timestamp" to timestamp,
            "isSynced" to isSynced,
            "isMock" to isMock
        )
        if (!extrasJson.isNullOrEmpty()) {
            try {
                val jsonObj = JSONObject(extrasJson)
                val extrasMap = mutableMapOf<String, Any>()
                val keys = jsonObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    extrasMap[key] = jsonObj.get(key)
                }
                map["extras"] = extrasMap
            } catch (_: Exception) {}
        }
        return map
    }

    fun toJsonObject(): JSONObject {
        val json = JSONObject()
        json.put("uuid", uuid)
        json.put("latitude", latitude)
        json.put("longitude", longitude)
        json.put("accuracy", accuracy)
        json.put("altitude", altitude)
        json.put("speed", speed)
        json.put("heading", heading)
        json.put("odometer", odometer)
        json.put("activity", activityType)
        json.put("confidence", activityConfidence)
        json.put("battery", batteryLevel)
        json.put("charging", batteryIsCharging)
        json.put("timestamp", timestamp)
        json.put("isMock", isMock)
        if (!extrasJson.isNullOrEmpty()) {
            try {
                val extrasObj = JSONObject(extrasJson)
                json.put("extras", extrasObj)
                val keys = extrasObj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    json.put(key, extrasObj.get(key))
                }
            } catch (_: Exception) {}
        }
        return json
    }
}
