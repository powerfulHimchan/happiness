# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `GP-111` 영구 기억 해금·선택·다음 도전 보상·이어하기 개발용 시제품
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 3스테이지 연속 진행·두 경로 선택·중간 회복, 성장·직업·필살기를 중간 저장하고 재실행 후 이어하기
- 검증 상태: 2026-09-30 사용자 보고로 실기기 20분 안정성 통과 확인, CP-406 나머지 개별 항목은 확인 대기

## 문서

- [게임 기획서 PDF](docs/Happiness_Tale_GDD_v0.1_KR.pdf)
- [게임 기획서 Markdown](docs/GAME_DESIGN.md)
- [첫 전투 프로토타입 명세](docs/prototype/COMBAT_PROTOTYPE_SPEC.md)
- [전투 화면 와이어프레임](docs/prototype/combat-screen-wireframe.svg)
- [입력 상태도와 전투 데이터 설계](docs/prototype/INPUT_AND_DATA_DESIGN.md)
- [첫 프로토타입 구현 작업 목록](docs/prototype/IMPLEMENTATION_BACKLOG.md)
- [프로토타입 화면 흐름과 UI 명세](docs/prototype/PROTOTYPE_UI_FLOW.md)
- [조작 배치 편집 화면 와이어프레임](docs/prototype/control-layout-editor-wireframe.svg)
- [프로토타입 테스트 계획](docs/prototype/PROTOTYPE_TEST_PLAN.md)
- [CP-406 Android 실기기 검증표](docs/prototype/CP406_DEVICE_VALIDATION.md)
- [GP-101 성장 구현·검증 범위](docs/prototype/GP101_GROWTH_STATUS.md)
- [GP-102 직업 구현·검증 범위](docs/prototype/GP102_JOB_STATUS.md)
- [GP-103 직업 보상 구현·검증 범위](docs/prototype/GP103_JOB_REWARDS_STATUS.md)
- [GP-104 연속 진행 구현·검증 범위](docs/prototype/GP104_RUN_STATUS.md)
- [GP-105 중간 저장 구현·검증 범위](docs/prototype/GP105_CHECKPOINT_STATUS.md)
- [GP-106 시작 무기 선택 구현·검증 범위](docs/prototype/GP106_START_WEAPON_STATUS.md)
- [GP-107 경로별 지형·전투 구현·검증 범위](docs/prototype/GP107_ROUTE_TERRAIN_STATUS.md)
- [GP-108 무기 보상·등급 구현·검증 범위](docs/prototype/GP108_WEAPON_REWARDS_STATUS.md)
- [GP-109 보스전·구출/파괴 구현·검증 범위](docs/prototype/GP109_BOSS_CHOICE_STATUS.md)
- [CP-001/002 구현 상태](docs/prototype/CP001_CP002_STATUS.md)

## 프로토타입 실행

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 `GP-111` 빌드는 기존 전투 구역을 재사용한 3개 스테이지를 이어서 진행합니다. 새 도전과 결과 화면의 재도전에서 검·활 시작 무기를 선택하고, 중간 완료 시 체력을 일부 회복하고 희귀·영웅 검·활 중 하나를 교체한 뒤 풀숲 길·바람 길 중 하나를 선택합니다. 현재 무기를 유지할 수도 있습니다. 등급은 무기 피해를, 검의 고유 효과는 스킬을, 활의 고유 효과는 기본 공격을 강화합니다. 보조 무기 고유 효과는 절반 적용합니다. 보상 선택 전후 상태를 저장하여 앱 재시작 후 같은 화면으로 복귀합니다. 다음 스테이지에서 풀숲 길은 평지 다리와 가까운 적 배치, 바람 길은 징검 발판과 흩어진 적 배치를 제공합니다. 현재 경로·지형은 HUD에 표시합니다. 레벨·카드 강화·직업·필살기를 유지해 다음 전투에서 활용하고, 마지막 관문에서 웃는 태엽 기사의 돌진·충격파·탄막을 상대합니다. 보스 승리 후 구출·파괴를 선택·확정해야 전체 결과를 표시하며, 선택 대기 상태도 저장합니다. 선택은 결과와 로컬 이력에 남습니다. 재도전은 새 도전으로 초기화합니다. 기존 빌드의 20분 안정성 통과 기록과 CP-406 진단·로컬 기록·조작 설정 기능을 유지합니다.

스테이지 1·2 완료 후 회복된 상태를 자동 저장합니다. 앱 재실행 후 메인의 **이어하기**를 누르면 완료한 스테이지의 경로 선택 화면으로 복귀합니다. 전투 중 종료한 경우 마지막 완료 지점부터 다시 시작합니다. 사망·3스테이지 완주·새 도전은 중간 저장을 삭제합니다. 손상된 최신 저장은 이전 정상 저장으로 복구하고, 복구할 수 없으면 새 도전을 안내합니다. 10개 스테이지와 새 지역은 후속 범위입니다.

```bash
./scripts/check_godot_project.sh
godot --path game --editor
```

자세한 실행과 Android 연결 방법은 [Godot 프로토타입 안내](game/README.md)를 참고하세요.

`main` 반영 전 PR에서 전체 자동 검증과 APK 빌드를 수행하고, 병합 후에도 GitHub Actions가 ARM64 테스트 APK를 자동으로 생성합니다. 이 APK는 개인 기기 설치용 디버그 빌드이며 Google Play 제출용이 아닙니다.

PDF에는 Noto Sans KR 글꼴이 포함되어 있어 한글이 깨지지 않습니다. GitHub에서 내용을 빠르게 확인할 때는 Markdown 문서를 사용할 수 있습니다.

## 기획서 생성

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r planning/requirements.txt
python planning/build_gdd.py
```

`planning/build_gdd.py`는 편집 가능한 DOCX 원본을 생성합니다. 배포·열람용 문서는 글꼴이 포함된 PDF를 기준으로 관리합니다.

## 다음 작업

1. 서로 다른 화면 비율의 Android 기기에서 HUD와 조작 버튼의 안전 영역 확인
2. 검·활 각각으로 도전을 시작하고 두 경로의 다리·발판 및 후반 적 배치 확인
3. 1스테이지 완료 후 앱을 완전히 종료하고 **이어하기**로 체력·직업·필살기 보존 확인
4. 백그라운드 복귀를 세 번 수행하고 전투 재개 확인
5. 총 10회 완주 뒤 조작 설정과 최고 기록의 재실행 보존 확인
6. 실기기 검증표를 작성해 첫 전투 프로토타입 통과 여부 결정

GP-110에서는 구출·파괴 완료 후 다음 새 도전 1회에 보상을 적용할 수 있다. 시작 무기 화면에서 켜거나 건너뛴다. 구출은 체력 +10, 정예마다 지원 피해 20, 비치명타 뒤 체력 25% 이하에서 최대 체력 30% 회복 1회다. 파괴는 주는 피해와 받는 전투 피해 각각 +10%다. 보상 소비와 지원·회복 사용 기록은 중간 저장과 테스트 기록 초기화에서 독립적으로 보존한다. 자세한 범위는 [GP-110 구현 상태](docs/prototype/GP110_NEXT_RUN_LEGACY_STATUS.md)를 참고한다.

GP-111에서는 보스 구출로 태엽 수호(최대 체력 +5), 파괴로 핵의 잔향(스킬 피해 +10%)을 영구 해금한다. 새 도전 준비 화면에서 하나만 장착하거나 기억 없이 시작한다. 같은 선택을 반복해도 수치가 누적되지 않으며 기존 일회 보상과 독립적이다. 이전 GP-110 저널의 소비된 선택도 해금으로 복원한다. 상세 범위는 [GP-111 구현 상태](docs/prototype/GP111_PERMANENT_MEMORIES_STATUS.md)를 참고한다.
