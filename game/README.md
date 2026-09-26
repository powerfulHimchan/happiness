# Godot 전투 프로토타입

`CP-001`, `CP-002` 기술 확인과 `CP-101~105` 이동 샌드박스, `CP-201~206` 전투·필살기를 거쳐 `CP-301 일반 적 세 종류`를 검증하는 프로젝트다. 현재 메인 화면에서는 풀잎 슬라임, 씨앗 포대와 바람 정령의 서로 다른 경고·공격·빈틈을 확인한다.

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

`.github/workflows/build-android-apk.yml`은 `game` 변경이 `main`에 반영될 때 ARM64 디버그 APK를 생성한다. 현재 결과물 이름은 `happiness-tale-cp301-common-enemies-apk`이며 APK와 SHA-256 파일을 14일간 보관한다.

이 APK는 개인 기기 테스트용 임시 디버그 키로 서명된다. 다음 빌드에서는 키가 달라질 수 있으므로 설치 충돌이 발생하면 기존 진단 앱을 삭제한 뒤 다시 설치한다. Google Play 배포에는 사용할 수 없다.

`CP-301` 기기 테스트에서는 기존 이동·대상·피해·검·활·필살기 항목과 함께 아래를 확인한다.

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
- 씨앗탄과 접촉하면 HP가 정확히 7 감소하고 0.50초 피격 무적이 적용되는가?
- 지상 회피 또는 공중 대시 중 씨앗탄과 접촉하면 HP가 감소하지 않는가?
- `초기화`를 누르면 HP, 사망 상태와 피해 카운터가 모두 복구되는가?
- 전방 표적의 HP가 자동 공격으로 12, 14, 20 순서대로 감소하는가?
- 전방 대상이 없어진 뒤 0.90초가 지나면 콤보가 1타로 초기화되는가?
- `돌진` 버튼이 3.5m 전진, 피해 35와 6초 재사용 대기시간을 적용하는가?
- `회전` 버튼이 주변 표적마다 피해 20을 두 번 주고 9초 재사용 대기시간을 적용하는가?
- 스킬 시작 직후에는 회피가 잠기고 HUD에 취소 가능이 표시된 뒤에는 회피로 중단되는가?
- 기본 공격 중 회피해도 이동과 무적이 즉시 적용되는가?
- `활 전환`을 누르면 스킬 버튼이 `관통`, `화살비`로 바뀌고 대상 사거리가 8m가 되는가?
- 화면 밖 표적은 자동 대상에서 제외되고 HUD의 `화면 밖 제외`가 증가하는가?
- 활 기본 사격이 실제 화살 투사체로 이동해 0.75초마다 적중하는가?
- 1.6m 이내 기본 사격은 피해 14가 아닌 11이 적용되고 `근접감소`가 증가하는가?
- 관통 화살이 피해 36을 주되 한 발당 최대 세 표적까지만 적중하는가?
- 화살비가 범위 안 각 표적에 피해 8을 여섯 번, 최대 48 적용하는가?
- 활 스킬도 HUD의 취소 가능 시점 이후 회피로 중단되는가?
- 전환 버튼을 한 번 누르면 주 무기, 자동 공격 프로필과 스킬 버튼 두 개가 함께 바뀌는가?
- 전환 직후 버튼을 반복해도 0.50초 동안 추가 전환이 차단되고 HUD 차단 횟수가 증가하는가?
- 검 스킬 사용 후 활을 거쳐 돌아와도 검 스킬 쿨다운이 초기화되지 않는가?
- 활 스킬 사용 후 검을 거쳐 돌아와도 활 스킬 쿨다운이 초기화되지 않는가?
- 검·활 기본 공격 직후 전환해도 각 무기의 공격 대기시간이 0으로 초기화되지 않는가?
- 스킬이나 회피 종료 직전 전환을 누르면 0.20초 안에 행동이 끝날 때 예약 전환되는가?
- 기본 공격 적중마다 필살기 게이지가 4, 스킬 적중마다 8 증가하는가?
- 씨앗탄을 지상 회피 또는 공중 대시 무적으로 통과하면 게이지가 12 증가하는가?
- 게이지가 100일 때 버튼이 `새벽 준비`로 강조되고 발동 후 0으로 소모되는가?
- `새벽의 틈`이 정확히 3초 동안 유지되고 일반 적과 씨앗탄이 15퍼센트 속도로 움직이는가?
- 발동 중에도 플레이어의 이동, 점프와 활 투사체 속도는 바뀌지 않는가?
- 종료 후 적과 적 투사체 속도가 즉시 100퍼센트로 돌아오는가?
- 풀잎 슬라임이 3m 이내에서 0.35초 붉은 경고 뒤 점프해 피해 8을 주는가?
- 풀잎 슬라임이 착지한 뒤 0.8초 동안 공격하지 않는가?
- 씨앗 포대가 4–7m 거리를 유지하고 1초 조준선 뒤 피해 7의 씨앗탄 세 발을 부채꼴로 발사하는가?
- 씨앗 포대를 검으로 공격하면 뒤로 밀리고 1초 동안 사격하지 않는가?
- 바람 정령이 머리 높이를 유지하고 0.6초 흰 경고선 뒤 피해 10의 직선 돌진을 하는가?
- 바람 정령이 벽에 닿거나 빗나간 뒤 1.2초 동안 멈추는가?
- 적이 사망하면 대상에서 제외되고 남아 있던 경고 표시가 즉시 사라지는가?

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
├── scripts/combat/bow_combat_controller.gd
├── scripts/combat/bow_projectile.gd
├── scripts/combat/prototype_weapon_controller.gd
├── scripts/combat/ultimate_controller.gd
├── scripts/combat/prototype_enemy.gd
├── scripts/combat/enemy_seed_projectile.gd
├── scripts/combat/auto_target_selector.gd
├── scripts/combat/prototype_target.gd
├── scripts/input/input_command_sandbox.gd
├── scripts/input/player_command.gd
├── scripts/input/player_command_buffer.gd
└── scripts/diagnostics/touch_diagnostics.gd
```

## 아직 포함하지 않은 것

- 실제 전투 UI와 버튼 배치 편집
- 주먹·지팡이·봉·방패 공격과 스킬

다음 구현 티켓은 `CP-302 갑옷 멧돼지 정예`다.
