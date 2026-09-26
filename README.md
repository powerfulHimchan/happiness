# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: `CP-301` 일반 적 세 종류 실기기 검증판
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 검·활·필살기와 풀잎 슬라임·씨앗 포대·바람 정령의 경고·공격·빈틈 구현 완료

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

Godot 4.7.2 stable에서 [`game/project.godot`](game/project.godot)를 엽니다. 현재 빌드는 풀잎 슬라임의 점프, 씨앗 포대의 3연발, 바람 정령의 직선 돌진을 각기 다른 시각 경고 뒤에 대응하는 `CP-301` 전투 샌드박스입니다. 기존 검·활 전투와 `새벽의 틈` 필살기도 함께 사용할 수 있습니다.

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

1. 풀잎 슬라임이 3m 이내에서 0.35초 경고 후 점프하고 착지 뒤 0.8초 빈틈을 주는지 확인
2. 씨앗 포대가 4–7m 거리를 유지하며 1초 조준 뒤 피해 7의 씨앗탄 세 발을 쏘는지 확인
3. 씨앗 포대를 검으로 때리면 뒤로 밀리고 1초 동안 사격하지 않는지 확인
4. 바람 정령이 흰 직선 경고를 0.6초 표시한 뒤 돌진하고 빗나가면 1.2초 멈추는지 확인
5. 세 적과 씨앗탄이 `새벽의 틈` 동안 15퍼센트 속도로 느려지는지 확인
6. `CP-301` 실기기 검증 후 `CP-302` 갑옷 멧돼지 정예 구현
