# CLAUDE.md

Follow these instructions when working on PinDrift with Claude Code or another code agent.

## Repository Context

PinDrift is a Flutter Android app for mock-location testing. The app is intentionally Android-only and currently uses only Naver Maps.

Main implementation files:

- `lib/main.dart`
- `android/app/src/main/kotlin/com/fakegps/fake_gps_app/MainActivity.kt`
- `android/app/src/main/kotlin/com/fakegps/fake_gps_app/MockLocationService.kt`

Read `AGENTS.md` first for the full project guidance.

## Non-Negotiable Rules

- Do not commit `.env` or any private API key.
- Do not add Naver Client Secret to code, assets, docs examples, logs, or tests.
- Do not move `ACCESS_MOCK_LOCATION` into the main manifest.
- Do not add Google Maps back unless the user explicitly requests it.
- Do not add backend services; this is an app-only project.
- Do not change the package id without updating scripts and documenting migration steps.

## Expected Workflow

1. Inspect the relevant files before editing.
2. Keep changes narrowly scoped to the requested behavior.
3. Format code.
4. Run analysis and tests.
5. Build a debug APK when Android/Kotlin/map behavior changes.
6. Summarize what changed and what was verified.

Recommended commands:

```powershell
dart format lib test android\app\src\main\kotlin
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=.env
```

If `.env` is missing, create it from `.env.example` locally. Do not ask users to paste secrets into chat.

## Current UX Contract

The map screen should remain simple:

- Naver map
- current-location button
- zoom controls
- mock start/stop button
- no direct latitude/longitude entry
- no location search

Point behavior:

- Tap map: selected point changes.
- Drag map: selected point does not change.
- Pinch zoom: selected point does not change.
- Reopen app: map centers on last selected point.

## Android Mock-Location Behavior

`MockLocationService` is responsible for:

- registering GPS and network test providers,
- pushing selected location updates,
- running as a foreground service,
- stopping updates,
- disabling/removing test providers,
- requesting a real-location refresh after stop.

Be careful with `START_STICKY`: stopping must not allow the service to restart and resume mock updates from a null intent.

## Public Repository Readiness

Before preparing a public commit:

```powershell
git status --short --ignored
git diff --cached --name-only
```

Confirm `.env`, APKs, build folders, and local IDE files are not staged.

## Documentation

Update `README.md` when user-visible setup, build, or product behavior changes.
Update `BUILD.md` when build/install/debug steps change.
Update `AGENTS.md` or this file when conventions change for future agents.
