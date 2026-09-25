# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-204` 활 기본 공격과 스킬 실기기 검증판
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 검 전투 위에 활 자동 사격, 투사체, 관통 화살, 화살비와 화면 제한 구현 완료

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

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 빌드는 기존 검 전투를 유지하면서 활의 화면 안 자동 조준, 실제 투사체, 근접 피해 감소, 최대 3개체 관통 화살과 6회 화살비를 확인하는 `CP-204` 전투 샌드박스입니다. `전환` 버튼은 CP-204 비교 테스트를 위한 즉시 전환이며 정식 0.50초 제한은 CP-205에서 적용합니다.

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

1. `활 전환`을 누른 뒤 화면 안 전방 표적에만 자동 사격하는지 확인
2. 활 기본 사격이 0.75초 간격이며 근거리에서는 피해 14가 11로 감소하는지 확인
3. `관통`이 직선상의 표적을 최대 3개까지만 피해 36으로 맞히는지 확인
4. `화살비`가 지정 범위의 각 표적에 피해 8을 여섯 번 적용하는지 확인
5. 화면 밖 표적은 HUD의 제외 횟수에 포함되고 자동 사격하지 않는지 확인
6. `CP-205` 두 무기 전환 구현
