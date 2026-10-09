# DiveLog iOS — 빌드 및 App Store 배포 안내

이 폴더는 **앱 껍데기(셸)** 입니다. 화면 내용은 들어 있지 않고,
GitHub Pages에 올라간 웹앱을 전체화면 WebView로 띄우기만 합니다.

- 띄우는 주소: `https://konu-94.github.io/Freedive_log-beta1/`
- 번들 ID: `com.konu94.divelog` (Android 패키지명과 동일)
- 최소 지원: iOS 15.0 / iPhone 전용 / 세로 고정
- 원본: [PWABuilder](https://docs.pwabuilder.com) iOS 템플릿 (public domain)

---

## ⚠️ 가장 먼저 알아둘 것

**화면이나 기능을 고칠 때는 이 폴더를 건드리지 않습니다.**

저장소 루트의 `index.html` 등을 고쳐 `main`에 푸시하면
GitHub Pages가 갱신되고, **이미 설치된 앱에도 즉시 반영**됩니다.
Xcode 재빌드도, 재심사도 필요 없습니다.

| 고치는 것 | 해야 할 일 |
|---|---|
| 화면, 기능, 버그 (`index.html` 등) | `main` 에 푸시 → 끝 |
| 앱 이름, 아이콘, 권한, WebView 동작 | 이 폴더 수정 → Archive → 재심사 |

---

## 준비물

- **Mac** (Archive는 macOS에서만 가능합니다)
- **Xcode** 15 이상
- **Apple Developer Program 계정** (연 $99, 유료 계정이어야 App Store 업로드 가능)

---

## 1. Xcode에 계정 추가

1. Xcode → **Settings** (`⌘,`) → **Accounts** 탭
2. 왼쪽 아래 **+** → Apple ID → 로그인

## 2. 프로젝트 열고 서명 설정

1. `DiveLog.xcodeproj` 를 엽니다 (`.xcworkspace` 는 없습니다 — CocoaPods를 쓰지 않습니다)
2. 왼쪽 파일 목록 맨 위의 파란 **DiveLog** 아이콘 클릭
3. 가운데 **TARGETS → DiveLog** 선택
4. 위쪽 탭에서 **Signing & Capabilities**
5. **Automatically manage signing** 체크
6. **Team** 선택

### 팀이 다른 경우

현재 프로젝트에는 `DEVELOPMENT_TEAM = 4DASTJAH9B` 가 저장돼 있습니다.

- **같은 계정으로 올리는 경우** → 그대로 두면 됩니다.
- **다른 계정/팀으로 올리는 경우** → Team 드롭다운에서 그 팀을 고르면 됩니다.
  이때 번들 ID `com.konu94.divelog` 가 **그 팀 아래에 등록**돼 있어야 합니다.
  Automatic signing 이 켜져 있으면 Xcode가 자동으로 등록합니다.
  수동 등록은 [developer.apple.com](https://developer.apple.com/account) →
  Certificates, IDs & Profiles → Identifiers → **+** → App IDs → Explicit.

> 서명 인증서는 이 저장소에 없습니다. 각자 Mac의 키체인에 있는 인증서로 서명되므로,
> 계정만 추가하면 바로 빌드됩니다.

## 3. 실기기에서 확인 (권장)

아이폰을 케이블로 연결하고 상단 기기 선택에서 고른 뒤 ▶︎ 를 누릅니다.
처음 실행하면 아이폰에서
**설정 → 일반 → VPN 및 기기 관리** 에서 개발자를 신뢰로 바꿔야 합니다.

확인할 것: 로그인 / 기록 입력 / 자격증 사진 업로드 / 회원 탈퇴

> 탈퇴 테스트는 반드시 데모 계정(`divelog` / `010-0000-0000`)으로 하세요.
> 실제 계정으로 하면 기록이 영구 삭제됩니다.

## 4. Archive 후 업로드

1. 상단 기기 선택을 **Any iOS Device (arm64)** 로 변경
2. **Product → Archive**
3. Organizer 창이 열리면 **Distribute App**
4. **App Store Connect → Upload** 선택 후 진행

## 5. App Store Connect

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) 에서
앱을 만들고 등록 정보를 입력한 뒤 심사를 제출합니다.

문구·스크린샷·심사 메모는 저장소 루트의
**`store-listing-appstore.md`** 에 모두 정리돼 있습니다.
스크린샷과 1024 아이콘은 **`store-assets/appstore/`** 에 있습니다.

---

## 버전 올리기

업로드할 때마다 **빌드 번호는 반드시 올려야** 합니다. 같은 번호는 거부됩니다.

`DiveLog.xcodeproj/project.pbxproj` 또는 Xcode의 General 탭에서:

| 항목 | 현재 | 의미 |
|---|---|---|
| `MARKETING_VERSION` | `1.0.0` | 사용자에게 보이는 버전. 기능이 바뀔 때 올립니다 |
| `CURRENT_PROJECT_VERSION` | `1` | 빌드 번호. **업로드할 때마다** 올립니다 |

---

## 이 셸에서 바꿀 수 있는 것

`DiveLog/Settings.swift`

```swift
let rootUrl = URL(string: "https://konu-94.github.io/Freedive_log-beta1")!
let displayMode = "standalone"  // standalone / fullscreen
let adaptiveUIStyle = true      // 웹 배경색에 맞춰 앱 테마 자동 전환
let statusBarTheme = "dark"
let pullToRefresh = false       // 당겨서 새로고침 (기록 일괄 입력 보호를 위해 끔)
```

## PWABuilder 기본 템플릿에서 변경한 것

심사 리스크와 불필요한 의존성을 줄이기 위해 아래를 정리했습니다.

- **Firebase / CocoaPods 제거** — 푸시 알림을 쓰지 않습니다. `pod install` 이 필요 없습니다
- **백그라운드 모드, 마이크·위치 권한 제거** — 쓰지 않는 권한은 심사 지적 사유가 됩니다
- **ATS 예외(`NSAllowsArbitraryLoads`) 제거** — 전 구간 HTTPS 입니다
- **카메라 권한 설명을 한국어로** — 자격증 사진 촬영용
- **iPhone 전용 / 세로 고정**, Mac Catalyst 비활성
- **카테고리를 스포츠로**, `ITSAppUsesNonExemptEncryption = NO` (수출 규정 문항 자동 처리)
- **앱 아이콘 1024** — `icon-source.html` 을 브라우저에서 열어 1024×1024 로 캡처하면 재생성됩니다
- **당겨서 새로고침 끔**

---

## 함께 보관해야 하는 것 (이 저장소에 없음)

**Android 서명 키스토어** (`signing.keystore`, `signing-key-info.txt`)

Play 스토어 앱을 업데이트하려면 반드시 필요합니다.
**잃어버리면 기존 앱을 영영 업데이트할 수 없고**, 새 패키지명으로
새 앱을 올리는 수밖에 없습니다.

이 저장소는 공개이므로 키스토어를 여기에 두면 안 됩니다.
비공개 저장소나 안전한 보관소에 따로 백업하세요.
