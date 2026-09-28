# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-403` 10초 조작 배치 테스트 검증판
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 저장 전 10초 멀티터치 테스트와 전투 복귀 3초 카운트다운 구현 완료

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

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 `CP-403` 빌드는 배치 편집 화면의 `10초 테스트`로 저장 전 위치·크기·불투명도를 실제 멀티터치로 확인할 수 있습니다. 눌린 터치 영역과 겹침 상태를 표시하며, 전투 중 배치를 바꾸면 적과 피해를 정지한 뒤 3초 카운트다운으로 복귀합니다.

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

1. 저장하지 않은 배치에서 `10초 테스트`가 시작되는지 확인
2. 이동 패드와 액션 버튼을 동시에 눌렀을 때 실제 터치 영역이 강조되는지 확인
3. 겹친 조작 요소가 테스트 중에도 붉게 표시되는지 확인
4. 10초 종료 또는 `테스트 종료` 후 편집 화면으로 돌아오며 자동 저장되지 않는지 확인
5. 전투 화면의 `배치`에서 적용·취소 후 3초 카운트다운으로 복귀하는지 확인
6. `CP-403` 실기기 검증 후 `CP-404` 타격 피드백 구현
