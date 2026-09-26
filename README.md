# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-303` 3분 스테이지 진행기 검증판
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 전진 2개·웨이브 2개·정예 1개 구간, 관문 개폐, 목표·실제 시간 기록 구현 완료

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
- [CP-001/002 구현 상태](docs/prototype/CP001_CP002_STATUS.md)

## 프로토타입 실행

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 빌드는 `전진 40초 → 1차 웨이브 35초 → 전진 35초 → 혼합 웨이브 40초 → 정예 30초`를 목표로 삼는 `CP-303` 스테이지입니다. 관문과 적 처치 조건으로 순서를 고정하되 3분을 넘겨도 강제 실패하지 않으며, 목표 시간과 실제 구간 시간을 함께 기록합니다.

```bash
./scripts/check_godot_project.sh
godot --path game --editor
```

자세한 실행과 Android 연결 방법은 [Godot 프로토타입 안내](game/README.md)를 참고하세요.

`main`의 `game` 파일이 변경되면 GitHub Actions가 ARM64 테스트 APK를 자동으로 생성합니다. 이 APK는 개인 기기 설치용 디버그 빌드이며 Google Play 제출용이 아닙니다.

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

1. 첫 전진 도달 전 네 관문이 닫혀 있고 도달 뒤 첫 관문만 열리는지 확인
2. 1차·혼합 웨이브의 적을 모두 처치하기 전 다음 관문을 통과할 수 없는지 확인
3. 각 구간 목표 시간과 실제 시간이 HUD에 계속 기록되는지 확인
4. 전체 시간이 3분을 넘어도 실패하지 않고 현재 구간을 계속 진행하는지 확인
5. 갑옷 멧돼지를 처치하면 마지막 관문이 열리고 완료 시간이 남는지 확인
6. `CP-303` 실기기 검증 후 `CP-304` 전투 HUD와 결과 화면 구현
