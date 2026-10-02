# 업데이트 배포

[README](../README_KO.md) · [English](UPDATES.md) / 한국어

## 사용자 흐름

설정창에 `Info.plist`의 앱 버전과 빌드 번호를 표시합니다. 업데이트 확인은 저장소 GitHub API의 최신 정식 릴리스를 조회합니다. 초안, 사전 배포, 유효하지 않은 버전 태그, Apple Silicon DMG가 없는 릴리스와 다른 저장소의 다운로드 주소는 거부합니다. 버전을 숫자로 비교해 0.10.0을 0.9.0보다 오래된 것으로 판단하지 않습니다.

업데이트 확인은 버튼을 눌렀을 때만 실행합니다. 네트워크 오류가 나면 다시 시도할 수 있습니다. 새 버전이 있으면 **업데이트 및 재시작**과 릴리스 링크를 표시합니다. 개발용 실행 파일에서도 조회는 가능하지만 자체 교체는 하지 않으며, 설치 기능은 빌드한 `.app`에서 사용합니다.

## 설치 방식 구분

- **Homebrew 설치:** 실행 중인 앱의 심볼릭 링크와 `Caskroom/mactamatone` 설치 정보를 확인합니다. 앱이 `/Applications`로 이동한 뒤 Caskroom에 역방향 링크가 남는 경우도 감지합니다. 셸을 거치지 않고 `brew update`, `brew upgrade --cask yurseria/tap/mactamatone`을 실행합니다. 설치된 버전 확인 후 `/Applications/Mactamatone.app`을 다시 엽니다. Homebrew의 설치 정보와 관리 방식을 유지하며, tap 갱신이 아직 반영되지 않았으면 나중에 다시 시도할 수 있습니다.
- **직접 설치:** [Sparkle 2](https://sparkle-project.org/documentation/)의 네이티브 업데이트 화면에서 서명된 DMG를 다운로드·검증하고 설치 후 앱을 다시 실행합니다. 앱 교체와 필요한 권한 처리는 설치기가 담당합니다.

사용자가 설치 버튼을 눌러야 업데이트가 시작됩니다. 자동 확인과 자동 설치는 `Info.plist`에서 끄도록 설정했습니다.

## 서명과 릴리스 피드

Sparkle 버전은 `Package.swift`와 `Package.resolved`에 고정합니다. `build.sh`는 심볼릭 링크와 보조 프로그램 권한을 유지해 프레임워크를 포함합니다. `SUPublicEDKey`는 공개 Ed25519 키이며, `SUFeedURL`은 최신 정식 릴리스의 `appcast.xml` 파일을 가리킵니다.

앱 전용 개인키는 로그인 Keychain의 `app.mactamatone.updates` 계정에 보관합니다. 키가 바뀌거나 없어지면 기존 앱에서 새 업데이트를 신뢰하지 못할 수 있으므로 안전하게 백업해야 합니다. 저장소에는 공개 키만 포함합니다.

릴리스 워크플로는 GitHub Actions Secret `SPARKLE_PRIVATE_KEY`가 필요합니다. 이 설정은 개인키를 프로젝트 저장소의 Secret 보관소로 전송하는 작업이므로 명시적인 승인이 필요합니다. 로컬 빌드나 피드 생성 스크립트가 자동으로 설정하지 않습니다.

승인된 CI 실행에서 `generate-update-feed.sh`는 개인키를 표준 입력으로 Sparkle에 전달하고, DMG에 대한 서명이 포함된 피드를 생성해 `appcast.xml`을 DMG와 함께 게시합니다. 개인키나 개인키 파일은 릴리스에 포함하지 않습니다. 피드 주소는 GitHub의 최신 정식 릴리스를 따르므로 이후 정식 릴리스마다 피드 파일이 필요합니다.

로컬 Keychain 키를 이용한 패키징:

```sh
./scripts/package-dmg.sh
./scripts/generate-update-feed.sh
```

`dist/appcast.xml`을 생성하며, 릴리스를 게시하지는 않습니다. 기존 0.4.0 이하 배포본에는 업데이트 기능이 없으므로 이 기능이 포함된 버전으로 처음 전환할 때는 Homebrew 또는 DMG로 설치해야 합니다.

## 검증

```sh
./scripts/verify-updates.sh
# 선택적으로 실제 GitHub 조회:
./scripts/verify-updates.sh --live
```

가상 릴리스 응답과 임시 파일로 버전 비교, 릴리스 검증, 업데이트 상태, 중복 확인 방지, Homebrew 심볼릭 링크, 대량 출력 시 외부 프로세스 성공·실패 처리를 확인합니다. 실제 Homebrew 업데이트나 설치된 앱 교체는 실행하지 않습니다.
