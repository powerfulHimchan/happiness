# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-401` 조작 배치 편집 화면 검증판
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 드래그 배치, 요소별 크기, 전체 불투명도와 겹침 검증 구현 완료

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

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 `CP-401` 빌드는 메인 화면의 `조작 배치`에서 이동 패드와 여섯 액션 버튼을 직접 옮길 수 있습니다. 선택 요소 크기는 70~140퍼센트, 전체 불투명도는 30~100퍼센트로 조절되며 터치 영역이 30퍼센트 이상 겹치면 적용할 수 없습니다.

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

1. 메인 화면의 `조작 배치`에서 이동 패드와 액션 버튼 여섯 개를 모두 선택·이동할 수 있는지 확인
2. 드래그한 조작 요소가 화면 안전 영역 밖으로 나가지 않는지 확인
3. 선택 요소 크기가 70~140퍼센트, 전체 불투명도가 30~100퍼센트에서 제한되는지 확인
4. 실제 터치 영역이 30퍼센트 이상 겹치면 붉게 표시되고 `적용`이 차단되는지 확인
5. `취소`가 편집 전 배치를 복구하고 유효한 `적용`이 전투 조작에 반영되는지 확인
6. `CP-401` 실기기 검증 후 `CP-402` 프리셋과 로컬 저장 구현
