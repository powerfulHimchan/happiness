# Happiness Tale: Rewind to Dawn

밝은 캐주얼 판타지 분위기의 안드로이드용 2D 횡스크롤 로그라이트 액션 게임 프로젝트입니다.

## 현재 상태

- 게임 기획서 버전: `0.1`
- 전투 프로토타입 명세 버전: `0.1`
- 단계: 첫 전투 프로토타입 구현 준비 완료
- 주인공: 로안 / 루미
- 미소의 여왕: 세라
- 구현 소스: 아직 작성 전

## 문서

- [게임 기획서 PDF](docs/Happiness_Tale_GDD_v0.1_KR.pdf)
- [게임 기획서 Markdown](docs/GAME_DESIGN.md)
- [첫 전투 프로토타입 명세](docs/prototype/COMBAT_PROTOTYPE_SPEC.md)
- [전투 화면 와이어프레임](docs/prototype/combat-screen-wireframe.svg)

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

1. Godot 4.x 빈 프로젝트로 Android 실제 기기 설치와 입력 지연 확인
2. 입력 상태도와 전투 데이터 스키마 작성
3. 프로토타입 작업 티켓 분해
4. 약 3분 분량의 첫 전투 스테이지 구현
