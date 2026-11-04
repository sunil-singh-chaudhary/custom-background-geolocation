package com.custom.bglocation.http

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.util.Log
import com.custom.bglocation.db.LocationDatabaseHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class HttpSyncManager(private val context: Context) {

    companion object {
        private const val TAG = "HttpSyncManager"
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

        @Volatile
        var syncUrl: String? = null
        var syncHeaders: Map<String, String>? = null
        var batchSize: Int = 25
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()

    private val dbHelper = LocationDatabaseHelper.getInstance(context)
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    /**
     * Actively listens to Android OS network transitions.
     * The exact millisecond the device exits an elevator/tunnel/airplane mode and regains
     * mobile data or Wi-Fi, this callback triggers and flushes the entire offline SQLite queue.
     */
    fun registerConnectivityListener() {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        try {
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.i(TAG, "📡 Connectivity RESTORED! Auto-flushing offline SQLite locations queue...")
                    syncPendingLocations()
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                cm.registerDefaultNetworkCallback(callback)
            } else {
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build()
                cm.registerNetworkCallback(request, callback)
            }
            networkCallback = callback
            Log.d(TAG, "Registered active network connectivity listener.")
        } catch (e: Exception) {
            Log.w(TAG, "Could not register network callback: ${e.message}")
        }
    }

    fun unregisterConnectivityListener() {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
        networkCallback?.let {
            try {
                cm.unregisterNetworkCallback(it)
                networkCallback = null
            } catch (_: Exception) {}
        }
    }

    fun isNetworkAvailable(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return false
            val capabilities = cm.getNetworkCapabilities(network) ?: return false
            return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                   capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = cm.activeNetworkInfo
            @Suppress("DEPRECATION")
            return networkInfo != null && networkInfo.isConnected
        }
    }

    /**
     * Flushes unsynced points from the native SQLite database to the backend.
     * If the phone is unreachable (airplane mode, offline, timeout), coordinates
     * remain safely written in SQLite on disk with is_synced=0 until connectivity returns.
     */
    fun syncPendingLocations(onComplete: ((Boolean, Int) -> Unit)? = null) {
        val targetUrl = syncUrl
        if (targetUrl.isNullOrEmpty()) {
            if (isNetworkAvailable()) {
                val count = dbHelper.markAllAsSynced()
                Log.d(TAG, "No syncUrl configured. Marked $count pending locations as synced because network is active.")
                onComplete?.invoke(true, count)
            } else {
                Log.d(TAG, "No syncUrl configured and network offline. Leaving locations queued in SQLite.")
                onComplete?.invoke(false, 0)
            }
            return
        }

        if (!isNetworkAvailable()) {
            Log.w(TAG, "Device currently UNREACHABLE (offline). Leaving locations queued in SQLite.")
            onComplete?.invoke(false, 0)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val pending = dbHelper.getUnsyncedLocations(batchSize)
                if (pending.isEmpty()) {
                    Log.d(TAG, "No pending locations to sync.")
                    onComplete?.invoke(true, 0)
                    return@launch
                }

                Log.i(TAG, "Syncing batch of ${pending.size} locations to: $targetUrl")

                val jsonArray = JSONArray()
                val uuids = mutableListOf<String>()
                for (loc in pending) {
                    jsonArray.put(loc.toJsonObject())
                    uuids.add(loc.uuid)
                }

                val bodyObj = JSONObject()
                bodyObj.put("locations", jsonArray)
                bodyObj.put("batchSize", pending.size)
                bodyObj.put("syncedAt", System.currentTimeMillis())

                val requestBuilder = Request.Builder()
                    .url(targetUrl)
                    .post(bodyObj.toString().toRequestBody(JSON_MEDIA_TYPE))

                syncHeaders?.forEach { (k, v) ->
                    requestBuilder.addHeader(k, v)
                }

                val response = httpClient.newCall(requestBuilder.build()).execute()
                if (response.isSuccessful) {
                    dbHelper.markAsSynced(uuids)
                    Log.i(TAG, "Successfully synced ${uuids.size} offline locations! Response code: ${response.code}")
                    response.close()
                    onComplete?.invoke(true, uuids.size)
                } else {
                    Log.e(TAG, "HTTP sync failed with server response ${response.code}. Locations preserved in SQLite.")
                    response.close()
                    onComplete?.invoke(false, 0)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception during HTTP sync: ${e.message}. Will retry when reachable.", e)
                onComplete?.invoke(false, 0)
            }
        }
    }
}
