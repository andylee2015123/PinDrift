package com.fakegps.fake_gps_app

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var pendingLocationResult: MethodChannel.Result? = null
    private var pendingLocationListener: LocationListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMockLocationEnabled" -> result.success(isMockLocationEnabled())
                    "openDeveloperSettings" -> {
                        openDeveloperSettings()
                        result.success(null)
                    }
                    "getCurrentLocation" -> getCurrentLocation(result)
                    "startMockLocation" -> startMockLocation(
                        call.argument<Double>("latitude"),
                        call.argument<Double>("longitude"),
                        result,
                    )
                    "stopMockLocation" -> {
                        val intent = Intent(this, MockLocationService::class.java).apply {
                            action = MockLocationService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startMockLocation(latitude: Double?, longitude: Double?, result: MethodChannel.Result) {
        if (latitude == null || longitude == null) {
            result.error("INVALID_LOCATION", "좌표가 올바르지 않습니다.", null)
            return
        }
        if (!hasRequiredPermissions()) {
            requestRuntimePermissions()
            result.error("PERMISSION_REQUIRED", "위치와 알림 권한을 허용한 뒤 다시 시작하세요.", null)
            return
        }
        if (!isMockLocationEnabled()) {
            result.error("MOCK_LOCATION_DISABLED", "개발자 옵션에서 PinDrift를 모의 위치 앱으로 선택하세요.", null)
            return
        }

        val intent = Intent(this, MockLocationService::class.java).apply {
            action = MockLocationService.ACTION_START
            putExtra(MockLocationService.EXTRA_LATITUDE, latitude)
            putExtra(MockLocationService.EXTRA_LONGITUDE, longitude)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(null)
        } catch (error: SecurityException) {
            result.error(
                "MOCK_LOCATION_DISABLED",
                "개발자 옵션에서 PinDrift를 모의 위치 앱으로 선택하세요.",
                error.localizedMessage,
            )
        }
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestRuntimePermissions()
            result.error("PERMISSION_REQUIRED", "위치 권한을 허용한 뒤 다시 시도하세요.", null)
            return
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val lastLocation = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
        ).mapNotNull { provider ->
            try {
                locationManager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            }
        }.maxByOrNull { it.time }

        if (lastLocation != null) {
            result.success(lastLocation.toMap())
            return
        }

        if (pendingLocationResult != null) {
            result.error("LOCATION_PENDING", "현재 위치를 찾는 중입니다.", null)
            return
        }

        val provider = when {
            locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> null
        }

        if (provider == null) {
            result.error("LOCATION_DISABLED", "휴대폰 위치 서비스를 켜고 다시 시도하세요.", null)
            return
        }

        pendingLocationResult = result
        val listener = LocationListener { location ->
            finishCurrentLocation(location)
        }
        pendingLocationListener = listener

        try {
            @Suppress("DEPRECATION")
            locationManager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
            handler.postDelayed({
                if (pendingLocationResult != null) {
                    clearPendingLocation(locationManager)
                    result.error("LOCATION_TIMEOUT", "현재 위치를 찾지 못했습니다.", null)
                }
            }, LOCATION_TIMEOUT_MS)
        } catch (error: SecurityException) {
            clearPendingLocation(locationManager)
            result.error("PERMISSION_REQUIRED", "위치 권한을 허용한 뒤 다시 시도하세요.", error.localizedMessage)
        }
    }

    private fun finishCurrentLocation(location: Location) {
        val result = pendingLocationResult ?: return
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        clearPendingLocation(locationManager)
        result.success(location.toMap())
    }

    private fun clearPendingLocation(locationManager: LocationManager) {
        pendingLocationListener?.let { listener ->
            try {
                locationManager.removeUpdates(listener)
            } catch (_: SecurityException) {
                // Ignore cleanup failures.
            }
        }
        pendingLocationListener = null
        pendingLocationResult = null
    }

    private fun Location.toMap(): Map<String, Double> {
        return mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
        )
    }

    private fun isMockLocationEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val appOps = getSystemService(AppOpsManager::class.java)
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_MOCK_LOCATION,
                    android.os.Process.myUid(),
                    packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_MOCK_LOCATION,
                    android.os.Process.myUid(),
                    packageName,
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getString(contentResolver, Settings.Secure.ALLOW_MOCK_LOCATION) == "1"
        }
    }

    private fun openDeveloperSettings() {
        val highlightArgs = Bundle().apply {
            putString(EXTRA_FRAGMENT_ARG_KEY, MOCK_LOCATION_APP_KEY)
        }
        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(EXTRA_FRAGMENT_ARG_KEY, MOCK_LOCATION_APP_KEY)
            putExtra(EXTRA_SHOW_FRAGMENT_ARGUMENTS, highlightArgs)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(
                Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        }
    }

    private fun hasRequiredPermissions(): Boolean {
        val fineLocationGranted = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val notificationGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return fineLocationGranted && notificationGranted
    }

    private fun requestRuntimePermissions() {
        val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions += Manifest.permission.POST_NOTIFICATIONS
        }
        requestPermissions(permissions.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    private companion object {
        const val CHANNEL = "fake_gps/location"
        const val PERMISSION_REQUEST_CODE = 7001
        const val LOCATION_TIMEOUT_MS = 10000L
        const val EXTRA_SHOW_FRAGMENT_ARGUMENTS = ":settings:show_fragment_args"
        const val EXTRA_FRAGMENT_ARG_KEY = ":settings:fragment_args_key"
        const val MOCK_LOCATION_APP_KEY = "mock_location_app"
    }
}
