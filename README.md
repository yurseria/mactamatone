# 맥타마톤

<p align="center">
  <img src="WidgetPreview.png" alt="맥타마톤 플로팅 위젯" width="360">
</p>

맥북 화면의 기울기로 음 높이를 바꾸는 macOS 오타마톤 앱입니다. 앱을 실행하면 플로팅 위젯이 열립니다.

## 실행

macOS 14 이상과 Xcode Command Line Tools가 필요합니다.

```sh
./build.sh
open dist/Mactamatone.app
```

개발 중에는 `swift run Mactamatone`으로도 실행할 수 있습니다.

## 연주 방법

1. 위젯의 재생 버튼을 누르고 맥북 화면을 움직입니다. 약 55°~145° 범위에서 음 높이가 세 옥타브에 걸쳐 변합니다.
2. 현재 음 높이에 따라 오타마톤의 입이 다섯 단계로 열리고, 음 이름 옆 막대도 같은 단계를 표시합니다.
3. 위젯의 입 아이콘으로 입 움직임을 켜거나 끌 수 있습니다. 입 움직임을 꺼도 음 높이와 소리는 계속 바뀝니다.
4. 설정 창에서는 입력 방식을 화면 각도 또는 수동 연주로 바꾸고, `입 음색` 슬라이더로 소리의 배음을 조절할 수 있습니다.

연속 각도 센서가 없는 맥에서는 수동 연주로 전환됩니다. 이때 음 높이 슬라이더로 소리와 입 움직임을 시험할 수 있습니다. 화면이 거의 닫히면 소리를 멈춥니다.

## 위젯과 설정

오타마톤 그림을 드래그해 위젯을 옮길 수 있습니다. 톱니바퀴로 설정 창을 열고, 오른쪽 위 X 버튼으로 앱을 종료합니다. 설정 창을 닫아도 위젯과 연주는 계속됩니다. macOS 26 이상에서는 위젯 배경과 컨트롤에 Liquid Glass를 사용합니다.

제공된 오타마톤 이미지 다섯 장은 `Sources/Mactamatone/Resources/OtamatoneLevel0.png`부터 `OtamatoneLevel4.png`까지 보관했습니다. 위젯에는 각 이미지에서 배경을 제거한 `OtamatoneWidgetLevel0.png`부터 `OtamatoneWidgetLevel4.png`까지 사용합니다. 처음 제공된 화면 시안은 `design/Reference.png`에 있습니다.

## 센서와 구현

화면 각도는 Apple의 `las` HID 장치에서 feature report 1의 1~2번 바이트로 읽습니다. HID 읽기는 별도 큐에서 이뤄지며, 소리는 `AVAudioEngine`의 실시간 콜백에서 합성합니다. 이 센서는 공개 Core Motion API가 아니므로 맥 모델이나 macOS 버전에 따라 동작이 달라질 수 있습니다.

힌지 센서 접근 방식과 보고서 형식은 [macTilt의 LidSensor.swift](https://github.com/lqSky7/iphone-duo-macos-animation/blob/main/Sources/LidSensor.swift)를 참고했습니다.
