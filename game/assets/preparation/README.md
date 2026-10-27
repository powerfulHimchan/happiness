# 주인공 선택 이미지

- 두 인물의 기존 `characters/*_idle.tres` 전신 이미지를 재사용한다.
- `lettering/`은 주인공 선택 제목, 이전, 다시 선택, 다음, 로안/루미 이름의 6개 투명 이미지다. 글리프가 SVG 경로로 저장되므로 런타임 폰트 없이 텍스처로 그린다. 기억 수첩은 시작 화면의 이미지 글자를 공유한다.
- NAVER NanumMyeongjoBold(SIL OFL 1.1)를 이용한 그래픽이며 폰트 프로그램 자체는 앱에 포함하지 않는다.
- 재생성: 저장소 루트에서 `python3 scripts/build_hero_lettering.py --font-dir <NanumMyeongjoBold.ttf가 있는 디렉터리>`. FontTools가 필요하다.
- `hero-detail-shade.svg`는 이야기와 능력치의 가독성을 위한 반투명 정보 바탕이다. 클릭 가능한 버튼이 아니다.
- 기존 `storybook.svg`는 무기 선택 화면에서 계속 사용한다.

## 무기 선택

- `weapons/`: 여섯 무기의 디테일을 개선한 투명 SVG 7종. 권갑은 장착용 한 손 이미지와 목록용 한 쌍을 구분한다. `EquippedHeroPreview`는 실제 전투 장비를 변경하지 않고 이 이미지를 손 위치에 합성한다.
- `skills/`: 여섯 무기의 기본 스킬 12종. 기술의 동작/방향/범위/속성/방어를 그린 원본 SVG다.
- `weapon-lettering/`: 메뉴·무기·스킬 이름의 이미지 글자 28종. NAVER NanumMyeongjoBold(SIL OFL 1.1)의 글리프 경로를 사용하며 폰트 파일은 포함하지 않는다.
- 원화 재생성: `python3 scripts/build_weapon_art.py`. 글자 재생성: `python3 scripts/build_weapon_lettering.py --font-dir <NanumMyeongjoBold.ttf가 있는 디렉터리>`.
- 스킬 설명의 수치와 원본 효과는 `WeaponSkillPreview`가 현재 게임 스킬 정의에서 읽는다. SVG에 수치를 고정하지 않는다.

- `HeroSelectionMotion`은 선택 초상화만 부드럽게 변형한다. 로안은 호흡과 감사 인사, 루미는 몸 흔들기와 두 번의 작은 점프로 구분된다. 이야기 켜기/끄기 이미지는 제거했고 새 도전은 이야기 켜짐으로 준비한다. 공격 속도 아이콘은 `assets/status/attack_speed.svg`를 공유한다.
