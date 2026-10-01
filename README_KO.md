# 맥타마톤

[English](README.md) / 한국어

<p align="center">
  <img src="WidgetPreview.png" alt="맥타마톤 플로팅 위젯" width="360">
</p>

맥북 화면의 기울기로 연주하는 macOS 오타마톤 앱입니다. 실행하면 이동 가능한 플로팅 위젯이 열리고, 화면 각도에 따라 세 옥타브 범위의 음 높이와 다섯 단계의 입 모양이 변합니다.

## 설치

### Homebrew

Apple Silicon 맥과 macOS 14 이상이 필요합니다.

```sh
brew install --cask yurseria/tap/mactamatone
```

앱은 임시 서명되어 있으며 Apple 공증을 받지 않았습니다. [Yurseria Homebrew tap](https://github.com/yurseria/homebrew-tap)의 다른 앱과 마찬가지로 Cask가 설치된 앱의 격리 속성을 제거합니다. 프로젝트와 소스를 신뢰하는 경우에만 설치하세요.

### 소스에서 빌드

Xcode Command Line Tools를 설치한 다음 실행합니다.

```sh
./build.sh
open dist/Mactamatone.app
```

개발 중에는 `swift run Mactamatone`으로도 실행할 수 있습니다.

## 연주 방법

1. 위젯의 ♫ 버튼을 누르고 맥북 화면을 움직입니다. 약 55°~145° 범위에서 음 높이가 연속적으로 변합니다.
2. 오타마톤의 입과 음 이름 옆의 다섯 막대가 음 높이에 따라 변합니다. 입 움직임은 항상 켜져 있으며, ♫ 아이콘에 대각선이 그어져 있으면 소리가 꺼진 상태입니다.
3. 톱니바퀴로 설정 창을 열어 화면 각도 또는 수동 연주를 선택할 수 있습니다. **입 음색** 슬라이더는 소리의 배음을 조절합니다.

기본 언어는 영어입니다. 위젯의 지구본 버튼이나 설정의 **Language / 언어**에서 **English** 또는 **한국어**를 선택할 수 있습니다. 선택한 언어는 다음 실행에도 유지됩니다.

설정의 **테마**에서 클래식, 핑크(벚꽃), 블랙(고양이), 옐로우(병아리), 갤럭시(우주), 시바견을 선택할 수 있습니다. 위젯과 설정 미리보기에 즉시 적용되며, 모든 테마에서 입 모양 5단계를 지원합니다. 선택한 테마는 다음 실행에도 유지됩니다. 설정 미리보기에는 테마별로 벚꽃, 달빛 라운지, 햇살과 꽃밭, 우주, 따뜻한 정원 배경을 표시합니다. 배경은 기존 악기 이미지 뒤에 별도 레이어로 배치합니다.

오타마톤 그림을 드래그하면 위젯을 옮길 수 있습니다. 설정 창을 닫아도 위젯과 연주는 계속됩니다. X 버튼은 앱을 종료합니다. macOS 26 이상에서는 위젯에 Liquid Glass를 사용합니다.

화면 각도 센서가 없으면 수동 연주로 전환됩니다. 수동 음 높이 슬라이더로 소리와 입 움직임을 시험할 수 있습니다. 화면 각도 모드에서는 화면이 거의 닫히면 소리가 멈춥니다.

## 구현

화면 각도는 Apple의 `las` HID 장치에서 feature report 1을 별도 큐로 읽습니다. 소리는 `AVAudioEngine`으로 합성합니다. 이 센서는 공개 Core Motion API가 아니므로 맥 모델이나 macOS 버전에 따라 사용 가능 여부가 달라질 수 있습니다. 센서 접근 방식과 보고서 형식은 [macTilt의 LidSensor.swift](https://github.com/lqSky7/iphone-duo-macos-animation/blob/main/Sources/LidSensor.swift)를 참고했습니다.

제공된 다섯 이미지는 `Sources/Mactamatone/Resources/OtamatoneLevel0.png`부터 `OtamatoneLevel4.png`까지 보관했습니다. 위젯은 배경을 제거한 `OtamatoneWidgetLevel0.png`부터 `OtamatoneWidgetLevel4.png`까지 사용합니다. 처음 제공된 화면 시안은 `design/Reference.png`에 있습니다. 추가 테마 이미지는 `OtamatonePinkLevel0.png`부터 `OtamatoneShibaLevel4.png`까지 보관합니다. 생성 원본과 프롬프트 기록은 `design/Themes/`에 있으며, `swift scripts/prepare-theme-art.swift`로 위젯 리소스를 재생성할 수 있습니다.

앱 기본 아이콘은 `design/AppIcon/Music.png`의 음표 로고입니다. 오타마톤 얼굴 버전은 `design/AppIcon/Face.png`에 있으며, `design/AppIcon/`에 두 버전의 PNG와 ICNS를 함께 보관합니다. `./scripts/prepare-app-icon.sh`로 기본 앱 아이콘을 재생성할 수 있으며, `build.sh`가 Finder와 Dock에서 사용하는 아이콘을 앱에 포함합니다. 두 버전의 빌드 방법은 `design/AppIcon/README.md`에 있습니다.

## 릴리스

`Info.plist`의 `CFBundleShortVersionString`과 일치하는 `vX.Y.Z` 태그를 푸시하면 Apple Silicon DMG를 빌드해 GitHub Releases에 게시합니다. [Homebrew tap](https://github.com/yurseria/homebrew-tap)은 정식 릴리스를 확인하고 Cask 체크섬을 자동으로 갱신합니다.
