# iOS 및 Android 통합 배포 가이드라인 및 체크리스트

이 문서는 현재 Windows 환경에서 개발 중인 TEMAN Flutter 앱을 향후 **iOS (Apple App Store)**와 **Android (Google Play Store)** 양대 마켓에 모두 문제없이 배포하기 위해 필요한 설정과 작업들을 기록한 가이드라인입니다.

---

## 1. ⚠️ 기본 전제 조건 (Windows 개발 환경의 한계)
*   **Android 배포**: 현재 Windows 환경에서 완벽히 빌드 및 배포가 가능합니다. (`build/app/outputs/bundle/release/app-release.aab` 생성 후 Play Console 업로드)
*   **iOS 배포**: iOS 앱 빌드(Archive) 및 App Store Connect 업로드를 위해서는 **반드시 macOS 환경(Xcode)**이 필요합니다.
    *   **해결책**: 향후 Mac 기기를 준비하거나, **Codemagic, GitHub Actions, Bitrise** 같은 CI/CD 클라우드 서비스를 구축하여 Windows 환경에서도 원격으로 iOS 빌드/배포를 자동화해야 합니다.

---

## 2. 📝 지금 당장 프로젝트 코드에 적용해야 할 설정 (`ios/Runner/Info.plist`)
나중에 Mac 환경에서 빌드할 때 권한 누락이나 크래시(튕김) 현상이 발생하지 않도록, 지금 Windows 환경에서도 `Info.plist`를 미리 수정해 둘 수 있습니다. 

`ios/Runner/Info.plist` 파일의 `<dict>` 태그 내부에 다음 사항들을 반드시 추가하세요:

### 2.1 앱 이름 변경
사용자에게 보여질 실제 앱 이름으로 설정해야 합니다.
```xml
<key>CFBundleDisplayName</key>
<string>TEMAN: Universities In Seoul</string>
```

### 2.2 필수 권한(Privacy) 요청 메시지 추가 (반려 사유 1순위)
카메라, 사진첩, 위치 등의 권한을 왜 사용하는지 명확히 기재하지 않으면 Apple 심사에서 100% 반려(Reject)됩니다.
```xml
<key>NSCameraUsageDescription</key>
<string>게시글에 첨부할 사진을 찍거나 프로필 사진을 변경하기 위해 카메라 권한이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>게시글 첨부 및 프로필 사진 등록을 위해 사진첩 접근 권한이 필요합니다.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>내 주변의 친구나 모임을 지도에서 확인하기 위해 위치 권한이 필요합니다.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>내 주변의 친구나 모임을 지도에서 확인하기 위해 위치 권한이 필요합니다.</string>
```

### 2.3 구글 로그인(Google Sign-In) URL Scheme 추가
Firebase에서 발급받은 iOS 클라이언트 ID를 뒤집은 값(`REVERSED_CLIENT_ID`)을 등록해야 iOS에서 구글 로그인이 정상 작동합니다.
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.1065473302917-79u22o8qi0rutmhlvc8qmhj4g94s9cgd</string>
        </array>
    </dict>
</array>
```

---

## 3. 🚀 향후 본격적인 iOS 배포 시 진행해야 할 설정 (Mac & Apple Developer)

이 작업들은 나중에 Mac 환경이 준비되거나 실제 iOS 배포를 시작할 때 순차적으로 진행해야 하는 필수 항목들입니다.

### [ ] 3.1 Apple 로그인 (Sign in with Apple) 기능 UI 적용
*   **이유**: Apple 가이드라인에 따라 구글, 카카오 등 **서드파티 소셜 로그인이 있는 앱은 무조건 'Apple로 로그인' 버튼을 제공**해야 합니다.
*   **작업**: 현재 `pubspec.yaml`에 `sign_in_with_apple` 패키지가 있으므로, 로그인 화면 UI에 Apple 로그인 버튼을 추가하고 로직을 연결해야 합니다.

### [ ] 3.2 Apple Developer 인증서 및 프로비저닝 프로파일 세팅
*   **이유**: 실기기 테스트 및 App Store 업로드를 위한 서명(Signing) 작업.
*   **작업**: Apple Developer 포털에서 **App ID**를 생성합니다. 이때 `firebase_options.dart`에 등록된 번들 ID인 `com.teman.app`과 **정확히 일치**해야 합니다.

### [ ] 3.3 APNs 인증 키(.p8) 발급 및 Firebase 등록 (푸시/전화번호 인증)
*   **이유**: iOS 기기에서 Firebase 클라우드 메시징(푸시 알림)을 받거나, 전화번호 인증(Phone Auth)을 수행하려면 필요합니다.
*   **작업**: 
    1. Apple Developer 계정의 [Keys] 탭에서 **APNs Auth Key**를 생성하여 `.p8` 파일을 다운로드합니다.
    2. Firebase Console > 프로젝트 설정 > 클라우드 메시징 > iOS 앱 구성 섹션에 해당 `.p8` 키를 업로드합니다.

### [ ] 3.4 Xcode Project Configuration (Capabilities 켜기)
*   **작업**: Mac에서 `ios/Runner.xcworkspace`를 열고 다음 설정들을 켜야 합니다.
    *   **Signing & Capabilities** 탭에서 추가할 항목:
        *   `Push Notifications` (푸시 알림용)
        *   `Background Modes` -> `Remote notifications` 체크 (백그라운드 푸시용)
        *   `Sign in with Apple` (애플 로그인용)

### [ ] 3.5 GoogleService-Info.plist 연결
*   **작업**: Firebase에서 다운로드 받은 `GoogleService-Info.plist` 파일을 단순히 윈도우 폴더 복사로 넣으면 안 됩니다. **반드시 Xcode를 통해 `Runner` 디렉토리 하위로 드래그 앤 드롭**하여 프로젝트 내 Reference가 연결되도록 해야 합니다.

---

## 💡 결론 및 배포 파이프라인 제안
현재는 **Android Play Store 배포에 집중**하여 프로덕션 안정성을 확보하는 것이 최우선입니다. 위 `Info.plist` 수정 사항 정도만 코드에 미리 반영해 두십시오. 

향후 iOS 배포 타이밍이 오면, 이 문서를 열고 **3번 항목의 체크리스트**를 하나씩 지워가며 세팅을 진행하시면 헤매지 않고 부드럽게 양대 마켓 배포를 완료하실 수 있습니다.
