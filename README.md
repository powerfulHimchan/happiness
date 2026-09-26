# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-302` 갑옷 멧돼지 정예 실기기 검증판
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 일반 적 3종에 이어 갑옷 멧돼지의 돌진·벽 기절·충격파·2페이즈·무기 약점 구현 완료

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

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 빌드는 갑옷 멧돼지의 돌진을 벽으로 유도해 검 약점을 만들고, 평상시에는 활 약점을 공략하는 `CP-302` 전투 샌드박스입니다. 체력 50퍼센트 아래에서는 경고 시간이 짧아지고 충격파가 두 번 발생합니다.

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

1. 붉은 직선 경고 뒤 돌진하며 벽 충돌 시 2초 기절하는지 확인
2. 평상시 검 피해는 60퍼센트, 활 피해는 125퍼센트로 보정되는지 확인
3. 벽 충돌 기절 중 검 피해가 175퍼센트로 바뀌는지 확인
4. 충격파가 지면 양쪽으로 이동하고 회피로 통과할 수 있는지 확인
5. 체력 50퍼센트 아래에서 경고·기절 시간이 짧아지고 충격파가 두 번 발생하는지 확인
6. `CP-302` 실기기 검증 후 `CP-303` 3분 스테이지 진행기 구현
