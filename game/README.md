# Godot 전투 프로토타입

`CP-001`, `CP-002` 기술 확인과 `CP-101~105` 이동 샌드박스, `CP-201~202` 대상·피해 처리를 거쳐 `CP-203 검 기본 공격과 스킬`을 검증하는 프로젝트다. 현재 메인 화면에서는 자동 3연격, 돌진 베기, 회전 베기, 재사용 대기시간과 회피 취소를 확인한다.

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

`.github/workflows/build-android-apk.yml`은 `game` 변경이 `main`에 반영될 때 ARM64 디버그 APK를 생성한다. 현재 결과물 이름은 `happiness-tale-cp203-sword-apk`이며 APK와 SHA-256 파일을 14일간 보관한다.

이 APK는 개인 기기 테스트용 임시 디버그 키로 서명된다. 다음 빌드에서는 키가 달라질 수 있으므로 설치 충돌이 발생하면 기존 진단 앱을 삭제한 뒤 다시 설치한다. Google Play 배포에는 사용할 수 없다.

`CP-203` 기기 테스트에서는 기존 이동·대상·피해 처리 항목과 함께 아래를 확인한다.

- 화면이 가로 방향으로 고정되는가?
- 카메라 홀과 둥근 모서리가 녹색 안전 영역 밖에 있는가?
- 오른쪽으로 가속한 뒤 패드를 놓으면 흔들림 없이 멈추고 `감속 PASS`가 표시되는가?
- 오른쪽 이동 중 곧바로 왼쪽으로 전환하면 캐릭터가 한 번만 방향을 바꾸고 `방향 전환 PASS`가 표시되는가?
- 패드 입력 세기에 따라 목표 속도가 0–5.5 m/s 범위에서 달라지는가?
- 이동 패드를 유지한 채 점프·회피·스킬을 각각 누를 수 있는가?
- 60/30 FPS 전환 후 게임 시간이 달라지지 않는가?
- 앱을 백그라운드로 보냈다가 돌아와도 입력이 고정된 채 남지 않는가?
- 점프 버튼을 짧게 눌렀을 때와 길게 눌렀을 때 높이가 확실히 다른가?
- 연습 발판 끝을 벗어난 직후 점프하면 `최근 코요테`가 표시되는가?
- 바닥에 닿기 직전 점프 버튼을 누르면 착지 즉시 점프하며 `최근 착지 버퍼`가 표시되는가?
- 지상 회피 중 캐릭터가 청록색으로 표시되고 HUD에 무적 시작·종료 프레임이 남는가?
- 공중 대시가 이동 패드 방향으로 실행되고, 무입력일 때는 시선 방향으로 실행되는가?
- 공중 대시는 착지 전 한 번만 실행되며 착지 후 다시 준비되는가?
- 트랙 중간 낙하 구간에서 떨어지면 HP가 10 감소하는가?
- 약 0.45초 후 마지막 안전 지점으로 복귀하고 잠시 입력이 잠기는가?
- 연습 발판이나 오른쪽 평지를 지난 뒤 낙하하면 해당 안전 지점으로 복귀하는가?
- 낙하 구역 자체가 안전 지점으로 저장되어 연속 낙하하지 않는가?
- 오른쪽을 볼 때 플레이어 왼쪽의 표적은 대상에서 제외되는가?
- 전방의 두 표적이 교차해도 흰 외곽선과 표식이 빠르게 번갈아 바뀌지 않는가?
- 다른 표적이 현재 대상보다 20퍼센트 이상 가까워질 때만 대상이 전환되는가?
- 방향을 바꾸거나 대상이 1.6m 사거리 밖으로 나가면 즉시 다시 탐색하는가?
- 대상이 없을 때 HUD에 `대상 없음`이 표시되는가?
- 상태가 정상일 때 `피격 12`를 누르면 HP가 정확히 12 감소하는가?
- 피격 직후 0.50초 동안 캐릭터 색이 바뀌고 추가 피해가 `무적 차단`되는가?
- 무적이 끝난 뒤 `중복 ×2`를 누르면 HP가 14만 감소하고 `중복 차단`이 1 증가하는가?
- 지상 회피 중 `피격 12`를 누르면 HP가 감소하지 않는가?
- `치명타`를 누르면 HP가 0이 되고 캐릭터가 회색으로 바뀌며 이동할 수 없는가?
- `초기화`를 누르면 HP, 사망 상태와 피해 카운터가 모두 복구되는가?
- 전방 표적의 HP가 자동 공격으로 12, 14, 20 순서대로 감소하는가?
- 전방 대상이 없어진 뒤 0.90초가 지나면 콤보가 1타로 초기화되는가?
- `돌진` 버튼이 3.5m 전진, 피해 35와 6초 재사용 대기시간을 적용하는가?
- `회전` 버튼이 주변 표적마다 피해 20을 두 번 주고 9초 재사용 대기시간을 적용하는가?
- 스킬 시작 직후에는 회피가 잠기고 HUD에 취소 가능이 표시된 뒤에는 회피로 중단되는가?
- 기본 공격 중 회피해도 이동과 무적이 즉시 적용되는가?

## 현재 파일

```text
game/
├── assets/icon.svg
├── export_presets.cfg
├── project.godot
├── scenes/movement/ground_movement_sandbox.tscn
├── scenes/input/input_command_sandbox.tscn
├── scenes/diagnostics/touch_diagnostics.tscn
├── scripts/movement/ground_movement_sandbox.gd
├── scripts/movement/ground_movement_controls.gd
├── scripts/player/prototype_player.gd
├── scripts/player/prototype_avatar.gd
├── scripts/combat/damage_event.gd
├── scripts/combat/damage_receiver.gd
├── scripts/combat/weapon_definition.gd
├── scripts/combat/skill_definition.gd
├── scripts/combat/sword_combat_controller.gd
├── scripts/combat/auto_target_selector.gd
├── scripts/combat/prototype_target.gd
├── scripts/input/input_command_sandbox.gd
├── scripts/input/player_command.gd
├── scripts/input/player_command_buffer.gd
└── scripts/diagnostics/touch_diagnostics.gd
```

## 아직 포함하지 않은 것

- 활 공격과 투사체
- 실제 전투 UI와 버튼 배치 편집
- 검·활 공격과 스킬

다음 구현 티켓은 `CP-204 활 기본 공격과 스킬`이다.
