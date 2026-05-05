$ErrorActionPreference = 'Stop'

adb shell appops set com.fakegps.fake_gps_app android:mock_location ignore
adb shell cmd appops get com.fakegps.fake_gps_app android:mock_location

Write-Host "PinDrift mock location app-op has been disabled."
Write-Host "To use PinDrift again, select it again in Android Developer options > mock location app."
