# 개발 가이드

[README](../README_KO.md) · [English](DEVELOPMENT.md) / 한국어

## 빌드와 실행

Xcode Command Line Tools를 설치하고 저장소 루트에서 실행합니다.

```sh
./build.sh
open dist/Mactamatone.app
```

개발 중에는 `swift run Mactamatone`으로도 실행할 수 있습니다. 빌드 스크립트는 앱 번들을 만들고 리소스와 아이콘을 복사한 뒤 임시 서명을 적용합니다.

## 설치와 서명

배포 DMG는 Apple Silicon용이며 macOS 14 이상이 필요합니다. 앱은 임시 서명되어 있으며 Apple 공증을 받지 않았습니다. [Homebrew Cask](https://github.com/yurseria/homebrew-tap)는 기존 tap 설정에 따라 설치된 앱의 격리 속성을 제거합니다. 프로젝트와 소스를 신뢰하는 경우에만 설치하세요.

화면 각도 센서를 사용할 수 없으면 수동 연주로 전환합니다. 호환성에 관한 내용은 [구현 설명](IMPLEMENTATION_KO.md)을 참고하세요.

## 검증

앱을 빌드한 다음 실행합니다.

```sh
./scripts/verify-themes.sh
```

언어 저장과 번역, 여섯 테마와 다섯 입 모양, 다크 모드에서 설정창 컨트롤 색상, 25°~130° 음역 매핑과 음소거 경계, 오프라인 오디오 측정과 후광 동작을 검증합니다. UI 미리보기는 `dist/theme-previews/`에 저장합니다. 오디오 검증은 스피커 출력 없이 오프라인으로 실행합니다.

## README 스크린샷

```sh
./scripts/capture-readme-screenshots.sh
```

캡처 도구는 별도 환경설정을 사용해 앱의 실제 위젯과 설정창 UI를 엽니다. 갤럭시 테마의 수동 연주 화면을 영어와 한국어로 각각 저장하며, 위젯은 글자와 후광이 잘 보이도록 어두운 바탕에 표시합니다. 네 개의 PNG를 `docs/images/`에 생성합니다. 후광은 오프라인으로 합성한 오디오에 따라 표시하므로 소리가 나거나 사용자의 저장된 설정이 바뀌지 않습니다.

먼저 `screencapture`로 네이티브 창 촬영을 시도합니다. 화면 캡처를 사용할 수 없으면 AppKit/SwiftUI의 네이티브 뷰 이미지를 저장합니다. 현재 문서 이미지는 이 대체 방식으로 생성했으며, Liquid Glass 같은 WindowServer 효과는 빠질 수 있습니다. 화면 캡처가 가능한 데스크톱에서 다시 실행하면 해당 효과까지 촬영할 수 있습니다.

## 이미지와 앱 아이콘

- [앱 아이콘](../design/AppIcon/README.md): 제공된 로고, ICNS 생성과 이전 대안.
- [테마](../design/Themes/README.md): 원본 이미지와 투명 악기 리소스 생성.
- [배경](../design/Backgrounds/README.md): 별도 장면 리소스.

## 릴리스

`Info.plist`의 `CFBundleShortVersionString`과 `CFBundleVersion`을 변경합니다. 푸시하는 `vX.Y.Z` 태그는 short version 값과 일치해야 합니다. 릴리스 워크플로는 Apple Silicon DMG를 빌드해 [GitHub Releases](https://github.com/yurseria/mactamatone/releases)에 게시합니다.

로컬 DMG 생성:

```sh
./scripts/package-dmg.sh
```

[Homebrew tap](https://github.com/yurseria/homebrew-tap)은 정식 릴리스를 확인하고 Cask 버전과 체크섬을 자동으로 갱신합니다.
