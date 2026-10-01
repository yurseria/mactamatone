# 구현 설명

[README](../README_KO.md) · [English](IMPLEMENTATION.md) / 한국어

## 화면 각도 입력

`Sources/Mactamatone/LidSensor.swift`는 Apple의 `las` HID 화면 각도 장치에서 feature report 1을 별도 큐로 읽습니다. HID 호출이 UI 스레드를 막지 않도록 분리했습니다. 이 센서는 공개 Core Motion API로 제공되지 않으므로 맥 모델이나 macOS 버전에 따라 사용 가능 여부가 달라질 수 있습니다. 접근 방식과 보고서 형식은 [macTilt의 LidSensor.swift](https://github.com/lqSky7/iphone-duo-macos-animation/blob/main/Sources/LidSensor.swift)를 참고했습니다.

센서를 사용할 수 없으면 수동 입력으로 전환합니다.

## 음역과 입 모양

`InstrumentModel.pitchAngleRange`는 25°~130°입니다. 화면 각도를 이 구간으로 제한하고 MIDI 음 48~84(C3~C6)에 연속으로 대응시킨 뒤 주파수로 변환합니다. 화면 각도 모드에서는 25° 미만이거나 센서 연결이 끊기면 음소거합니다. 수동 입력도 같은 음역 구간을 사용합니다.

다섯 입 모양은 정규화된 음 높이에 따라 바뀝니다. 경계에 2도의 히스테리시스를 적용해 작은 센서 흔들림으로 이미지가 빠르게 전환되는 것을 막습니다. 입 음색 슬라이더는 화면의 입 모양과 별개로 합성음의 음색을 조절합니다.

## 오디오와 연주 후광

`OtamatoneSynth`는 `AVAudioEngine`으로 소리를 만듭니다. 오디오 콜백은 실제 출력의 RMS와 시퀀스 번호를 원자적 C 컨트롤로 전달합니다. UI는 이를 초당 30회 읽어 실제 소리와 멈춘 콜백을 감지하며, 오디오 스레드에서 UI 작업을 하지 않습니다.

위젯과 설정창은 후광 레이어에서만 공통 `AudioActivity` 상태를 관찰합니다. 소리가 나면 테마 색상의 일정한 강도로 후광이 나타나고, 시작과 종료 시 부드럽게 변합니다. 밝기는 출력 크기에 연동하지 않습니다. 회전 없이 2초 주기로 크기만 ±12% 변하며, 동작 줄이기를 켜면 크기를 고정합니다.

## 이미지 레이어

클래식 원본은 `Sources/Mactamatone/Resources/OtamatoneLevel0.png`부터 `OtamatoneLevel4.png`까지 보관합니다. 투명 악기 이미지는 `OtamatoneWidgetLevel0.png`부터 `OtamatoneWidgetLevel4.png`까지입니다. 초기 시안은 `design/Reference.png`에 있습니다.

추가 테마의 투명 이미지는 `OtamatonePinkLevel0.png`부터 `OtamatoneShibaLevel4.png`까지이며, 생성 원본과 프롬프트는 [design/Themes](../design/Themes/README.md)에 있습니다. 재생성 명령:

```sh
swift scripts/prepare-theme-art.swift
```

장식된 장면은 별도 배경 레이어입니다. 설정창은 배경 위에 후광을 놓고 투명 악기 이미지를 그 앞에 배치합니다. 클래식은 기존 배경과 바닥 그림자를 아래에 유지합니다.

## 언어와 네이티브 창

영어가 기본 언어입니다. 영어·한국어 문자열을 현지화 리소스로 포함하고, 테마와 언어의 고정 식별자를 `UserDefaults`에 저장합니다.

설정창은 밝은 색상에 맞는 네이티브 컨트롤을 사용해 macOS 다크 모드에서도 일치하는 색상으로 표시됩니다. 타이틀바는 투명하며 네이티브 신호등 버튼을 유지합니다. 위젯은 시스템 화면 모드를 따르고 macOS 26 이상에서는 Liquid Glass를 사용합니다.

## 앱 아이콘

제공된 일러스트 원본은 `design/AppIcon/Otamatone-source.png`에 보관합니다. 아이콘 생성 도구는 이미지를 투명 여백이 있는 둥근 타일에 맞춰 넣고, 16~1024px의 일반·Retina 크기를 생성합니다. 앱 기본 리소스는 Finder 아이콘에 사용하고, 시작 시 번들 아이콘을 Dock에도 적용합니다. [아이콘 가이드](../design/AppIcon/README.md)를 참고하세요.
