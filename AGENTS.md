# AGENTS.md

This file gives coding agents the project-specific context needed to safely modify PinDrift.

## Project Summary

PinDrift is an Android-only Flutter app for mock-location testing. It uses Naver Maps inside a WebView and an Android foreground service to push test GPS/network locations through Android mock-location APIs.

## Tech Stack

- Flutter / Dart
- Android Kotlin
- Naver Maps JavaScript SDK in WebView
- `shared_preferences`
- `webview_flutter`

## Important Files

- `lib/main.dart`: Flutter UI, settings, WebView map HTML, MethodChannel calls.
- `android/app/src/main/kotlin/com/fakegps/fake_gps_app/MainActivity.kt`: MethodChannel bridge and Android settings/location helpers.
- `android/app/src/main/kotlin/com/fakegps/fake_gps_app/MockLocationService.kt`: Foreground service and mock provider lifecycle.
- `android/app/src/debug/AndroidManifest.xml`: Debug-only `ACCESS_MOCK_LOCATION`.
- `android/app/src/main/AndroidManifest.xml`: Main app permissions and service declaration.
- `.env.example`: Public template for local build defines.
- `.env`: Local-only secrets/config; must not be committed.
- `scripts/`: PowerShell helper scripts for local Windows development.

## Product Constraints

- Android only. Do not add iOS, web, desktop, or backend functionality unless explicitly requested.
- Naver Maps only. Do not reintroduce Google Maps or a map provider selector unless explicitly requested.
- Mock-location behavior requires debug builds. Release builds must not include `ACCESS_MOCK_LOCATION`.
- The app cannot programmatically select or deselect itself as the Android mock-location app.
- Do not put Naver Client Secret or any private API key into source code.

## Map Behavior

Current expected behavior:

- Map loads centered on the last selected point.
- Tapping the map changes the selected mock-location point.
- Dragging or pinch-zooming the map must not change the selected point.
- Current-location button moves the map and selected point to the real device location.
- Starting mock location uses the selected point.
- Stopping mock location removes test providers and requests a real-location refresh.

Preserve this behavior unless the user explicitly asks to change it.

## Build Configuration

Use `.env` for local build-time values:

```env
NAVER_MAPS_CLIENT_ID=your_naver_client_id
```

Build debug APK:

```powershell
flutter build apk --debug --dart-define-from-file=.env
```

Preferred helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-debug.ps1
```

Install helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-debug.ps1
```

## Verification Commands

Run these before finishing code changes:

```powershell
dart format lib test android\app\src\main\kotlin
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=.env
```

If `.env` is unavailable, use:

```powershell
flutter build apk --debug
```

and clearly report that map loading was not verified with a real Naver Client ID.

## Git Hygiene

Never commit:

- `.env`
- build outputs
- `.dart_tool`
- `.idea`
- local Android SDK files such as `android/local.properties`
- generated APKs

Before committing, check:

```powershell
git status --short --ignored
git diff --cached --name-only
```

## Coding Guidelines

- Keep UI simple and utilitarian.
- Prefer existing app patterns over new abstractions.
- Keep Android mock-location code explicit and defensive.
- Preserve debug-only mock permission placement.
- Avoid adding dependencies unless they materially simplify the requested change.
- Do not change package id `com.fakegps.fake_gps_app` unless explicitly requested; Android mock-location app selection and appops scripts depend on it.

## Known Android Notes

- `ACCESS_MOCK_LOCATION` belongs in `android/app/src/debug/AndroidManifest.xml`.
- `android.permission.FOREGROUND_SERVICE_LOCATION` is required for the foreground location service on modern Android.
- Stopping mock location removes test providers, but some devices/apps cache last locations briefly.
- `scripts/disable-mock-location.ps1` disables PinDrift's mock-location app-op through ADB for development recovery.
