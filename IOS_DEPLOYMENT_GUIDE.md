# iOS 및 Android 통합 배포 가이드라인 및 체크리스트

이 문서는 현재 Windows 환경에서 개발 중인 TEMAN Flutter 앱을 향후 **iOS (Apple App Store)**와 **Android (Google Play Store)** 양대 마켓에 모두 문제없이 배포하기 위해 필요한 설정과 작업들을 기록한 가이드라인입니다.

---

## 1. 기본 전제 조건 (Windows 개발 환경의 한계)
*   **Android 배포**: 현재 Windows 환경에서 완벽히 빌드 및 배포가 가능합니다. (`build/app/outputs/bundle/release/app-release.aab` 생성 후 Play Console 업로드)
*   **iOS 배포**: iOS 앱 빌드(Archive) 및 App Store Connect 업로드를 위해서는 **반드시 macOS 환경(Xcode)**이 필요합니다.
    *   **해결책**: 향후 Mac 기기를 준비하거나, **Codemagic, GitHub Actions, Bitrise** 같은 CI/CD 클라우드 서비스를 구축하여 Windows 환경에서도 원격으로 iOS 빌드/배포를 자동화해야 합니다.

---

## 2. Windows에서 미리 적용 완료된 설정

### [x] 2.1 앱 이름 변경 (`Info.plist`)
```xml
<key>CFBundleDisplayName</key>
<string>TEMAN: Universities In Seoul</string>
```

### [x] 2.2 필수 권한(Privacy) 요청 메시지 (`Info.plist`)
카메라, 사진첩, 위치 권한 사용 설명이 모두 등록되어 있음.
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

### [x] 2.3 구글 로그인(Google Sign-In) URL Scheme (`Info.plist`)
Firebase iOS 클라이언트 ID의 REVERSED_CLIENT_ID가 등록됨.
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

### [x] 2.4 Apple 로그인 (Sign in with Apple) 코드 구현
*   `login_screen.dart` — iOS 플랫폼에서 "Continue with Apple" 버튼이 자동으로 표시됨
*   `auth_service.dart` — `signInWithApple()` 로직 구현 완료
*   `Runner.entitlements` — `com.apple.developer.applesignin` 권한 설정 완료

### [x] 2.5 GoogleService-Info.plist 번들 ID 수정 (2026-05-14)
*   **수정 전**: `BUNDLE_ID = com.example.temanFlutterAppCode` (기본값, 잘못된 값)
*   **수정 후**: `BUNDLE_ID = com.teman.app` (Xcode 프로젝트 및 firebase_options.dart와 일치)
*   이 불일치 상태로 빌드하면 iOS에서 Firebase 초기화가 실패합니다.

### [x] 2.6 Xcode 프로젝트 Bundle Identifier 설정
*   `project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER = com.teman.app` 으로 올바르게 설정됨
*   `firebase_options.dart` — `iosBundleId: 'com.teman.app'`과 일치

---

## 3. 향후 Mac 환경에서 진행해야 할 필수 설정

이 작업들은 **Mac 환경**이 준비되거나 실제 iOS 배포를 시작할 때 순차적으로 진행해야 하는 필수 항목들입니다.

### [ ] 3.1 Apple Developer 계정에서 App ID 생성
*   **작업**: Apple Developer 포털에서 Identifier > App IDs를 생성합니다.
*   번들 ID는 반드시 `com.teman.app`으로 설정해야 합니다.
*   Capabilities에서 **Sign In with Apple**, **Push Notifications** 활성화 필요.

### [ ] 3.2 인증서 및 프로비저닝 프로파일 세팅
*   **이유**: 실기기 테스트 및 App Store 업로드를 위한 서명(Signing) 작업.
*   **작업**:
    1. Apple Developer 포털에서 **iOS Distribution Certificate** 생성
    2. **Provisioning Profile** 생성 (App Store 배포용)
    3. Xcode에서 자동 서명(Automatic Signing)을 사용하면 이 과정이 간소화됩니다

### [ ] 3.3 APNs 인증 키(.p8) 발급 및 Firebase 등록
*   **이유**: iOS 기기에서 Firebase 클라우드 메시징(푸시 알림)을 받거나, 전화번호 인증(Phone Auth)을 수행하려면 필요합니다.
*   **작업**: 
    1. Apple Developer 계정의 [Keys] 탭에서 **APNs Auth Key**를 생성하여 `.p8` 파일을 다운로드합니다.
    2. Firebase Console > 프로젝트 설정 > 클라우드 메시징 > iOS 앱 구성 섹션에 해당 `.p8` 키를 업로드합니다.

### [ ] 3.4 Xcode Capabilities 켜기
*   **작업**: Mac에서 `ios/Runner.xcworkspace`를 열고 다음 설정들을 켜야 합니다.
    *   **Signing & Capabilities** 탭에서 추가할 항목:
        *   `Push Notifications` (푸시 알림용)
        *   `Background Modes` -> `Remote notifications` 체크 (백그라운드 푸시용)
        *   `Sign in with Apple` (애플 로그인용) — entitlements 파일은 이미 존재함

### [ ] 3.5 GoogleService-Info.plist Xcode 연결
*   **현재 상태**: 파일이 `ios/Runner/` 폴더에 존재하며 BUNDLE_ID도 수정 완료됨
*   **남은 작업**: **반드시 Xcode를 통해 `Runner` 디렉토리 하위로 드래그 앤 드롭**하여 프로젝트 내 Reference가 연결되도록 해야 합니다. (단순 폴더 복사만으로는 인식 안 됨)

### [ ] 3.6 빌드 및 업로드
*   **작업**:
    1. Xcode에서 `Product > Archive` 실행
    2. Archive 완료 후 `Distribute App` > `App Store Connect` 선택
    3. 업로드 완료 후 App Store Connect 웹에서 빌드 선택 가능 (처리 시간 약 10~30분)

---

## 4. 현재 ID/번들 정리

| 항목 | 값 |
|---|---|
| Android Package Name | `com.teman.community` |
| iOS Bundle ID | `com.teman.app` |
| Firebase Project ID | `teman-flutter-2` |
| Firebase iOS App ID | `1:1065473302917:ios:c78cfff7dff278894f64ec` |
| Firebase Android App ID | `1:1065473302917:android:f9a195995a0e265b4f64ec` |

> **참고**: Android(`com.teman.community`)와 iOS(`com.teman.app`)의 번들 ID가 다르지만, 이것은 Firebase에서 각각 별도의 앱으로 등록되어 있으므로 정상입니다. 변경하지 마세요.

---

## 5. 결론 및 배포 파이프라인

**현재 상태 요약 (2026-05-14 기준)**:
- Android: Google Play Store 비공개 테스트 버전 1.1.1 (빌드 4) 제출 완료, 심사 중
- iOS: 코드 레벨 준비 완료 (Info.plist, Apple 로그인 UI/로직, Firebase 설정)
- iOS 남은 작업: **Mac 환경에서 3번 체크리스트 진행** → Xcode Archive → App Store Connect 업로드

향후 iOS 배포 타이밍이 오면, 이 문서를 열고 **3번 항목의 체크리스트**를 하나씩 지워가며 세팅을 진행하시면 헤매지 않고 부드럽게 양대 마켓 배포를 완료하실 수 있습니다.

---

## 6. Windows에서 iOS 배포하기 (Codemagic 활용) ← 지금 당장 가능한 방법

> **핵심 원리**: Mac이 없어도 **Codemagic**이라는 클라우드 CI/CD 서비스가 자신들의 Mac 서버에서 대신 빌드하고, App Store Connect에 자동 업로드해줍니다. Windows에서 코드만 GitHub에 push하면 됩니다.

### 사전 준비 (한 번만 하면 됨)

| # | 항목 | 위치 |
|---|---|---|
| 1 | **Apple Developer 계정** (연 $99) | developer.apple.com |
| 2 | **App Store Connect에서 앱 생성** | appstoreconnect.apple.com |
| 3 | **GitHub에 이 repo를 push** | github.com |
| 4 | **Codemagic 계정 생성** | codemagic.io (GitHub 계정으로 가입) |

---

### Step 1: Apple Developer 포털에서 사전 설정

#### 1-1. App ID 등록
1. [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → **Identifiers**
2. `+` 버튼 → App IDs → App 선택
3. Bundle ID: `com.teman.app` (Explicit 선택)
4. Capabilities에서 반드시 체크:
   - ✅ **Sign In with Apple**
   - ✅ **Push Notifications**
5. Register 클릭

#### 1-2. APNs 키(.p8) 발급
1. 왼쪽 메뉴 → **Keys** → `+` 클릭
2. 이름: `TEMAN APNs Key`
3. **Apple Push Notifications service (APNs)** 체크
4. Continue → Register → **Download** (⚠️ 단 한 번만 다운로드 가능, 잘 보관)
5. Key ID를 메모해 둠

#### 1-3. Firebase에 APNs 키 등록
1. [Firebase Console](https://console.firebase.google.com) → 프로젝트 설정 → 클라우드 메시징
2. iOS 앱(`com.teman.app`) 선택 → APNs 인증 키 업로드
3. `.p8` 파일 업로드, Key ID, Team ID 입력 → 저장

---

### Step 2: App Store Connect에서 앱 등록

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 나의 앱 → `+` → 새 앱
2. 플랫폼: iOS
3. 이름: `TEMAN: Universities In Seoul`
4. 번들 ID: `com.teman.app` (드롭다운에 1-1에서 만든 것이 뜸)
5. SKU: `teman-app-ios-001` (임의 고유값)
6. 기본 언어: 한국어 → 생성

---

### Step 3: Codemagic 설정

#### 3-1. 프로젝트 연결
1. [codemagic.io](https://codemagic.io) 접속 → GitHub으로 로그인
2. `Add application` → Flutter App 선택
3. `flutter_TEMAN` repo 선택

#### 3-2. codemagic.yaml 생성
프로젝트 루트에 아래 파일을 생성합니다:

```yaml
# codemagic.yaml (프로젝트 루트에 저장)
workflows:
  ios-release:
    name: iOS Release
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.teman.app
      vars:
        APP_STORE_CONNECT_ISSUER_ID: Encrypted(...)   # Step 3-3에서 채움
        APP_STORE_CONNECT_KEY_IDENTIFIER: Encrypted(...)
        APP_STORE_CONNECT_PRIVATE_KEY: Encrypted(...)
    scripts:
      - name: Get Flutter packages
        script: flutter pub get
      - name: Install pods
        script: find . -name "Podfile" -execdir pod install \;
      - name: Flutter build ipa
        script: |
          flutter build ipa \
            --release \
            --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

#### 3-3. App Store Connect API 키 발급 (Codemagic ↔ Apple 연결)
1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 사용자 및 액세스 → **통합** → App Store Connect API
2. `+` 클릭 → 이름: `Codemagic`, 역할: `App Manager`
3. **다운로드** (`.p8` 파일) — Key ID와 Issuer ID를 메모
4. Codemagic → 해당 앱 설정 → **Integrations** → App Store Connect → 키 정보 입력

---

### Step 4: 빌드 및 업로드 실행

#### 방법 A: 자동 트리거 (권장)
```
# Windows PowerShell에서
git add .
git commit -m "chore: trigger iOS release build"
git push origin main
```
→ Codemagic이 push를 감지하고 자동으로 Mac 서버에서 빌드 시작  
→ 빌드 완료 (약 15~30분) 후 App Store Connect에 자동 업로드  
→ 이메일로 결과 알림이 옴

#### 방법 B: 수동 트리거
1. Codemagic 대시보드 → `ios-release` 워크플로 → **Start new build**

---

### Step 5: App Store Connect에서 심사 제출

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 나의 앱 → TEMAN
2. TestFlight 탭에서 빌드가 처리됨을 확인 (약 10~30분 소요)
3. App Store 탭 → 버전 정보 작성 (스크린샷, 설명, 키워드 등)
4. **심사를 위해 제출** 클릭

---

### 비용 안내

| 서비스 | 무료 플랜 | 유료 플랜 |
|---|---|---|
| **Codemagic** | 월 500 빌드 분 무료 (첫 달) | $29/월 (무제한) |
| **Apple Developer** | — | $99/년 (필수) |

> 💡 **팁**: 첫 iOS 배포는 무료 플랜으로도 충분합니다. 빌드 한 번에 약 20~25분이므로 한 달에 약 20회 빌드 가능.

---

### 현재 상태 체크리스트 (Windows → App Store)

- [ ] Apple Developer 계정 가입 ($99/년)
- [ ] App Store Connect에서 앱 등록 (`com.teman.app`)
- [ ] Apple Developer 포털에서 App ID 생성 및 Capabilities 활성화
- [ ] APNs 키 발급 + Firebase에 등록
- [ ] GitHub에 코드 push 완료
- [ ] Codemagic 계정 생성 및 repo 연결
- [ ] `codemagic.yaml` 작성 및 push
- [ ] App Store Connect API 키 발급 → Codemagic에 연결
- [ ] Codemagic에서 빌드 트리거 → IPA 생성 확인
- [ ] App Store Connect에서 빌드 선택 및 심사 제출
