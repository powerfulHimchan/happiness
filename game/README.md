# Godot 전투 프로토타입

`CP-001`, `CP-002` 기술 확인을 거쳐 `CP-101 입력 명령 계층`을 검증하는 프로젝트다. 현재 메인 화면은 전투 구현 전 단계의 입력 샌드박스로, 동적 이동 패드와 액션 버튼 멀티터치, 포인터 소유권, 명령 우선순위와 입력 버퍼를 확인한다.

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

`.github/workflows/build-android-apk.yml`은 `game` 변경이 `main`에 반영될 때 ARM64 디버그 APK를 생성한다. 현재 결과물 이름은 `happiness-tale-cp101-apk`이며 APK와 SHA-256 파일을 14일간 보관한다.

이 APK는 개인 기기 테스트용 임시 디버그 키로 서명된다. 다음 빌드에서는 키가 달라질 수 있으므로 설치 충돌이 발생하면 기존 진단 앱을 삭제한 뒤 다시 설치한다. Google Play 배포에는 사용할 수 없다.

`CP-101` 기기 테스트에서는 아래를 확인한다.

- 화면이 가로 방향으로 고정되는가?
- 카메라 홀과 둥근 모서리가 녹색 안전 영역 밖에 있는가?
- 이동 패드를 유지한 채 점프·회피·스킬을 각각 누를 수 있는가?
- 버튼을 누른 손가락이 영역 밖으로 움직여도 다른 버튼으로 바뀌지 않는가?
- 스킬 2와 점프 또는 무기 전환을 동시에 누르면 잠금 해제 후 버퍼된 명령이 실행되는가?
- 같은 프레임의 명령이 회피, 필살기, 스킬, 점프, 전환 순서로 실행되는가?
- 60/30 FPS 전환 후 게임 시간이 달라지지 않는가?
- 앱을 백그라운드로 보냈다가 돌아와도 입력이 고정된 채 남지 않는가?

## 현재 파일

```text
game/
├── assets/icon.svg
├── export_presets.cfg
├── project.godot
├── scenes/input/input_command_sandbox.tscn
├── scenes/diagnostics/touch_diagnostics.tscn
├── scripts/input/input_command_sandbox.gd
├── scripts/input/player_command.gd
├── scripts/input/player_command_buffer.gd
└── scripts/diagnostics/touch_diagnostics.gd
```

## 아직 포함하지 않은 것

- 플레이어 이동과 점프
- 실제 전투 UI와 버튼 배치 편집
- 검·활과 적

다음 구현 티켓은 `CP-102 캐릭터 지상 이동`이다.
