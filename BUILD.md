# PinDrift 빌드 가이드

## 모의 위치 테스트용 빌드

PinDrift에서 Android 모의 위치 기능을 테스트하려면 debug APK로 빌드해야 합니다.

기본 빌드 명령:

```powershell
flutter build apk --debug --dart-define-from-file=.env
```

또는 프로젝트에 포함된 스크립트를 사용할 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-debug.ps1
```

빌드된 debug APK는 아래 경로에 생성됩니다.

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## 기기에 설치

빌드 후 연결된 Android 기기에 바로 설치하려면 다음 스크립트를 사용합니다.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-debug.ps1
```

설치 후 Android 개발자 옵션에서 `모의 위치 앱 선택` 항목을 열고 `PinDrift`를 선택해야 합니다.

## 네이버 지도 Client ID 설정

로컬 빌드에서는 `.env` 파일을 사용합니다.

```powershell
copy .env.example .env
```

`.env` 파일에는 실제 네이버 지도 Client ID만 입력합니다.

```env
NAVER_MAPS_CLIENT_ID=your_naver_client_id
```

네이버 Client Secret은 앱 빌드에 넣지 마세요. PinDrift의 지도 표시는 Client ID만 사용합니다.

## 모의 위치 완전 해제

PinDrift에서 중지 버튼을 눌렀는데도 Android 또는 지도 앱이 마지막 모의 위치를 계속 보여주는 경우가 있습니다. Android가 아직 이 앱을 모의 위치 앱으로 허용한 상태이거나, 다른 앱이 위치를 캐시하고 있을 수 있습니다.

테스트 중 모의 위치 권한을 ADB로 완전히 해제하려면 다음 스크립트를 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File scripts\disable-mock-location.ps1
```

이 스크립트는 내부적으로 아래 명령과 같은 작업을 합니다.

```powershell
adb shell appops set com.fakegps.fake_gps_app android:mock_location ignore
```

이 명령을 실행하면 Android가 더 이상 PinDrift를 모의 위치 앱으로 취급하지 않습니다. 다시 PinDrift를 사용하려면 개발자 옵션에서 `PinDrift`를 모의 위치 앱으로 다시 선택해야 합니다.

## Debug 빌드가 필요한 이유

Android는 `android.permission.ACCESS_MOCK_LOCATION` 권한을 debug 또는 test 전용 manifest에서만 허용합니다. release manifest에 이 권한이 있으면 release 빌드 중 lint 오류가 발생합니다.

이 프로젝트의 구성은 다음과 같습니다.

- debug APK: `ACCESS_MOCK_LOCATION` 권한 포함
- release APK: `ACCESS_MOCK_LOCATION` 권한 미포함

따라서 release APK 빌드는 가능하지만, 모의 위치 앱으로 선택해서 테스트하는 용도에는 적합하지 않습니다. 모의 위치 테스트는 debug APK로 진행하세요.
