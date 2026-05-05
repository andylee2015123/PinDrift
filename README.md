# PinDrift

PinDrift는 Android에서 모의 위치(mock location)를 테스트하기 위한 Flutter 앱입니다. 네이버 지도를 기반으로 원하는 위치를 선택하고, Android 시스템이 그 위치를 현재 위치로 인식하도록 모의 위치를 주입합니다.

이 앱은 일반 사용자를 속이기 위한 목적이 아니라, 개발자 옵션에서 모의 위치 사용을 명시적으로 켠 개발/QA 환경을 대상으로 합니다.

## 주요 기능

- Android 전용 Flutter 앱
- 네이버 지도 기반 위치 선택 화면
- 지도를 탭해서 모의 위치 포인트 지정
- 지도 드래그와 두 손가락 줌 지원
- 지도 이동 중에는 선택된 포인트가 자동으로 바뀌지 않음
- 마지막으로 선택한 위치를 저장하고, 다음 실행 시 해당 위치를 지도 중심에 표시
- 화면이 꺼져도 동작할 수 있는 Android Foreground Service
- Android 개발자 옵션의 모의 위치 앱 설정 화면 열기
- `.env`를 이용한 로컬 빌드용 네이버 지도 Client ID 주입

## 중요한 Android 설정

Android에서 모의 위치가 시스템 위치로 인식되려면 사용자가 직접 개발자 옵션에서 이 앱을 모의 위치 앱으로 선택해야 합니다.

1. Android 설정에서 개발자 옵션을 활성화합니다.
2. `개발자 옵션` 화면을 엽니다.
3. `모의 위치 앱 선택` 또는 `Mock location app` 항목을 찾습니다.
4. 목록에서 `PinDrift`를 선택합니다.

앱이 이 설정을 직접 변경할 수는 없습니다. PinDrift는 개발자 옵션 화면을 열어줄 수 있지만, 최종 선택은 사용자가 직접 해야 합니다.

## 네이버 지도 API 설정

PinDrift는 WebView 안에서 네이버 지도 JavaScript SDK를 사용합니다. 따라서 네이버 클라우드 플랫폼의 Maps API 중 `Dynamic Map` 사용 설정이 필요합니다.

네이버 클라우드 플랫폼에서 다음처럼 등록합니다.

1. Application을 새로 만들거나 기존 Application을 엽니다.
2. 이용 API에서 `Dynamic Map`을 선택합니다.
3. 서비스 환경의 `Web 서비스 URL`에 아래 값을 등록합니다.

```text
https://pindrift.local
```

4. 현재 구현은 WebView 방식이므로 `Android 앱 패키지 이름`과 `iOS Bundle ID`는 비워둬도 됩니다.
5. `Client ID`, 즉 `X-NCP-APIGW-API-KEY-ID` 값을 복사합니다.

`Client Secret`은 앱에 넣지 마세요. PinDrift에서 지도 표시를 위해 필요한 값은 `Client ID`뿐입니다.

## 로컬 API 키 설정

예제 환경 파일을 복사합니다.

```powershell
copy .env.example .env
```

`.env` 파일에 네이버 지도 Client ID를 입력합니다.

```env
NAVER_MAPS_CLIENT_ID=your_naver_client_id
```

`.env`는 Git에 포함되지 않도록 ignore 처리되어 있습니다. 실제 API 키나 Secret 값은 커밋하지 마세요.

## 빌드와 설치

모의 위치 테스트에는 debug APK를 사용해야 합니다. Android는 `ACCESS_MOCK_LOCATION` 권한을 release manifest에 넣는 것을 허용하지 않기 때문에, 이 프로젝트는 debug manifest에만 해당 권한을 선언합니다.

Debug APK 빌드:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-debug.ps1
```

빌드 후 설치:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install-debug.ps1
```

빌드된 APK 위치:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

자세한 내용은 [BUILD.md](BUILD.md)를 참고하세요.

## 개발

의존성 설치:

```powershell
flutter pub get
```

기본 검사:

```powershell
dart format lib test android\app\src\main\kotlin
flutter analyze
flutter test
```

`.env` 값을 포함한 debug APK 직접 빌드:

```powershell
flutter build apk --debug --dart-define-from-file=.env
```

## 프로젝트 구조

```text
lib/main.dart                                      Flutter UI, 네이버 지도 WebView, 앱 설정 화면
android/app/src/main/kotlin/.../MainActivity.kt    Flutter MethodChannel과 Android 기능 연결
android/app/src/main/kotlin/.../MockLocationService.kt
                                                   Android Foreground 모의 위치 서비스
scripts/                                          로컬 빌드/설치/개발 보조 스크립트
assets/brand/                                     앱 아이콘 원본 리소스
```

## 제한 사항

- 앱이 Android의 모의 위치 앱 선택을 자동으로 변경하거나 해제할 수는 없습니다.
- 일부 지도 앱이나 런처는 모의 위치 중지 직후 마지막 위치를 잠시 캐시할 수 있습니다.
- 네이버 지도는 WebView에서 로드되므로 네이버 클라우드 플랫폼 서비스 환경에 `https://pindrift.local` 등록이 필요합니다.
- release APK에는 `ACCESS_MOCK_LOCATION` 권한이 포함되지 않습니다. 모의 위치 테스트에는 debug APK를 사용하세요.

## 보안 주의사항

- `.env` 파일은 개인 로컬 환경에만 보관하세요.
- API 키, 네이버 Client Secret, 개인 계정 정보는 커밋하지 마세요.
- 네이버 지도 Client ID는 클라이언트 지도 SDK 로딩에 쓰이므로 빌드된 APK 안에 포함될 수 있습니다.
- 가능하면 네이버 클라우드 플랫폼에서 API 사용 환경과 호출량을 제한하세요.

## 라이선스

이 프로젝트는 MIT License로 배포됩니다.

누구나 이 소스를 사용, 복사, 수정, 병합, 배포할 수 있습니다. 단, 배포 시 원 저작권 고지와 라이선스 고지를 함께 포함해야 하며, 소프트웨어는 어떠한 보증 없이 제공됩니다.

자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
