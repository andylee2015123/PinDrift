package com.fakegps.fake_gps_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Criteria
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock

class MockLocationService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var locationManager: LocationManager
    private var latitude = 37.5665
    private var longitude = 126.9780
    private var active = false
    private var foregroundStarted = false
    private var realLocationListener: LocationListener? = null

    private val updateRunnable = object : Runnable {
        override fun run() {
            if (!active) return
            pushLocation(LocationManager.GPS_PROVIDER)
            pushLocation(LocationManager.NETWORK_PROVIDER)
            handler.postDelayed(this, UPDATE_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START -> {
                latitude = intent.getDoubleExtra(EXTRA_LATITUDE, latitude)
                longitude = intent.getDoubleExtra(EXTRA_LONGITUDE, longitude)
                startMocking()
                START_STICKY
            }
            ACTION_STOP -> {
                stopMocking(refreshRealLocation = true)
                START_NOT_STICKY
            }
            else -> {
                stopSelf()
                START_NOT_STICKY
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopMocking(refreshRealLocation = false)
        super.onDestroy()
    }

    private fun startMocking() {
        startForeground(NOTIFICATION_ID, notification())
        foregroundStarted = true
        cancelRealLocationRefresh()
        ensureProvider(LocationManager.GPS_PROVIDER)
        ensureProvider(LocationManager.NETWORK_PROVIDER)
        active = true
        handler.removeCallbacks(updateRunnable)
        updateRunnable.run()
    }

    private fun stopMocking(refreshRealLocation: Boolean) {
        active = false
        handler.removeCallbacks(updateRunnable)
        disableAndRemoveProvider(LocationManager.GPS_PROVIDER)
        disableAndRemoveProvider(LocationManager.NETWORK_PROVIDER)

        if (refreshRealLocation && requestRealLocationRefresh()) {
            handler.postDelayed({
                finishStoppedService()
            }, REAL_LOCATION_REFRESH_TIMEOUT_MS)
            return
        }

        finishStoppedService()
    }

    private fun finishStoppedService() {
        cancelRealLocationRefresh()
        if (foregroundStarted) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            foregroundStarted = false
        }
        stopSelf()
    }

    private fun requestRealLocationRefresh(): Boolean {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val provider = when {
            isProviderUsable(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            isProviderUsable(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> return false
        }

        val listener = LocationListener {
            finishStoppedService()
        }
        realLocationListener = listener

        return try {
            @Suppress("DEPRECATION")
            locationManager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            true
        } catch (_: SecurityException) {
            cancelRealLocationRefresh()
            false
        } catch (_: IllegalArgumentException) {
            cancelRealLocationRefresh()
            false
        }
    }

    private fun cancelRealLocationRefresh() {
        handler.removeCallbacksAndMessages(null)
        realLocationListener?.let { listener ->
            try {
                locationManager.removeUpdates(listener)
            } catch (_: SecurityException) {
                // Ignore cleanup failures.
            }
        }
        realLocationListener = null
    }

    private fun isProviderUsable(provider: String): Boolean {
        return try {
            locationManager.isProviderEnabled(provider)
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private fun ensureProvider(provider: String) {
        try {
            locationManager.addTestProvider(
                provider,
                false,
                false,
                false,
                false,
                true,
                true,
                true,
                Criteria.POWER_LOW,
                Criteria.ACCURACY_FINE,
            )
        } catch (_: IllegalArgumentException) {
            // Provider already exists.
        }
        locationManager.setTestProviderEnabled(provider, true)
    }

    private fun disableAndRemoveProvider(provider: String) {
        try {
            locationManager.setTestProviderEnabled(provider, false)
        } catch (_: IllegalArgumentException) {
            // Provider was not registered by this service.
        } catch (_: SecurityException) {
            // App is no longer selected as the mock location app.
        }

        try {
            locationManager.removeTestProvider(provider)
        } catch (_: IllegalArgumentException) {
            // Provider was not registered by this service.
        } catch (_: SecurityException) {
            // App is no longer selected as the mock location app.
        }
    }

    private fun pushLocation(provider: String) {
        val location = Location(provider).apply {
            latitude = this@MockLocationService.latitude
            longitude = this@MockLocationService.longitude
            accuracy = 3.0f
            altitude = 0.0
            bearing = 0.0f
            speed = 0.0f
            time = System.currentTimeMillis()
            elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
        }
        locationManager.setTestProviderLocation(provider, location)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "PinDrift",
            NotificationManager.IMPORTANCE_LOW,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun notification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("PinDrift 동작 중")
            .setContentText("%.6f, %.6f".format(latitude, longitude))
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val ACTION_START = "com.fakegps.fake_gps_app.START"
        const val ACTION_STOP = "com.fakegps.fake_gps_app.STOP"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"

        private const val CHANNEL_ID = "fake_gps_location"
        private const val NOTIFICATION_ID = 1001
        private const val UPDATE_INTERVAL_MS = 1000L
        private const val REAL_LOCATION_REFRESH_TIMEOUT_MS = 10000L
    }
}
