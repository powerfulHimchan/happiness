# Godot 전투 프로토타입

`CP-001`과 `CP-002`를 검증하기 위한 첫 실행 프로젝트다. 현재 메인 화면은 게임 전투가 아니라 Android 가로 화면, 안전 영역, 프레임 제한과 멀티터치 입력을 확인하는 진단 화면이다.

## 기준 환경

- Godot 4.7.2 stable, Standard 버전
- GDScript
- GL Compatibility 렌더러
- Android 가로 화면
- OpenJDK 17

Godot 4.7.2는 프로젝트 작성 시점의 최신 안정 버전이다. 개발 버전인 4.8이 아니라 안정 버전을 사용한다.

## 데스크톱 실행

1. Godot 4.7.2에서 이 `game` 폴더의 `project.godot`를 연다.
2. 프로젝트 가져오기가 끝나면 `F6`이 아니라 `F5`로 메인 장면을 실행한다.
3. 마우스 클릭은 터치 한 개로 변환된다.
4. 화면 우측 상단에서 60 FPS와 30 FPS 제한을 전환한다.

Godot 실행 파일이 PATH에 있다면 저장소 루트에서 다음 명령으로 검사할 수 있다.

```bash
./scripts/check_godot_project.sh
godot --path game --editor
```

## Android 확인

1. Godot Editor의 `Editor Settings → Export → Android`에서 Java SDK Path를 JDK 17로 설정한다.
2. Android SDK Path를 `platform-tools/adb`가 포함된 SDK 디렉터리로 설정한다.
3. Godot 4.7.2용 Export Templates를 설치한다.
4. 프로젝트에 포함된 `Android Debug APK` 프리셋을 확인한다.
5. 패키지 이름은 테스트 앱 분리를 위해 `com.powerfulhimchan.happinesstale.diagnostics`를 사용한다.
6. USB 디버깅이 활성화된 기기를 연결하고 Runnable 프리셋으로 원클릭 배포한다.

## GitHub Actions APK

`.github/workflows/build-android-apk.yml`은 `game` 변경이 `main`에 반영될 때 ARM64 디버그 APK를 생성한다. 결과물 이름은 `happiness-tale-diagnostics-apk`이며 APK와 SHA-256 파일을 14일간 보관한다.

이 APK는 개인 기기 테스트용 임시 디버그 키로 서명된다. 다음 빌드에서는 키가 달라질 수 있으므로 설치 충돌이 발생하면 기존 진단 앱을 삭제한 뒤 다시 설치한다. Google Play 배포에는 사용할 수 없다.

첫 기기 테스트에서는 아래를 확인한다.

- 화면이 가로 방향으로 고정되는가?
- 카메라 홀과 둥근 모서리가 녹색 안전 영역 밖에 있는가?
- 세 개 이상의 영역을 동시에 눌렀을 때 터치 ID가 모두 표시되는가?
- 60/30 FPS 전환 후 게임 시간이 달라지지 않는가?
- 앱을 백그라운드로 보냈다가 돌아와도 입력이 고정된 채 남지 않는가?

## 현재 파일

```text
game/
├── assets/icon.svg
├── export_presets.cfg
├── project.godot
├── scenes/diagnostics/touch_diagnostics.tscn
└── scripts/diagnostics/touch_diagnostics.gd
```

## 아직 포함하지 않은 것

- Android Export 프리셋: 로컬 SDK와 Export Templates 확인 후 Godot Editor에서 생성
- 플레이어 이동과 점프
- 실제 전투 UI와 버튼 배치 편집
- 검·활과 적

다음 구현 티켓은 `CP-101 입력 명령 계층`이다.
