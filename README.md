# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-001/002` Godot·Android 기술 검증 진행 중
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: Godot 멀티터치 진단 프로젝트 작성 완료

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

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 빌드는 전투 구현 전 Android 가로 화면, 안전 영역, 30/60 FPS와 멀티터치를 확인하는 진단 화면입니다.

```bash
./scripts/check_godot_project.sh
godot --path game --editor
```

자세한 실행과 Android 연결 방법은 [Godot 프로토타입 안내](game/README.md)를 참고하세요.

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

1. Godot 4.7.2와 Android Export Templates 설치
2. Android SDK 경로 설정 후 실제 기기 원클릭 배포
3. `CP-001/002` 실기기 체크리스트 완료
4. `CP-101` 입력 명령 계층 구현
