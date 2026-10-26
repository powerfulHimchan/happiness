# 주인공 선택 이미지

- 두 인물의 기존 `characters/*_idle.tres` 전신 이미지를 재사용한다.
- `lettering/`은 주인공 선택 제목, 이전, 다시 선택, 다음, 이야기 켜짐/꺼짐, 로안/루미 이름의 8개 투명 이미지다. 글리프가 SVG 경로로 저장되므로 런타임 폰트 없이 텍스처로 그린다. 기억 수첩은 시작 화면의 이미지 글자를 공유한다.
- NAVER NanumMyeongjoBold(SIL OFL 1.1)를 이용한 그래픽이며 폰트 프로그램 자체는 앱에 포함하지 않는다.
- 재생성: 저장소 루트에서 `python3 scripts/build_hero_lettering.py --font-dir <NanumMyeongjoBold.ttf가 있는 디렉터리>`. FontTools가 필요하다.
- `hero-detail-shade.svg`는 이야기와 능력치의 가독성을 위한 반투명 정보 바탕이다. 클릭 가능한 버튼이 아니다.
- 기존 `storybook.svg`는 무기 선택 화면에서 계속 사용한다.
