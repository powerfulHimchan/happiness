# 주인공 기본 그래픽

2026-10-15 사용자가 승인한 카툰형 기본 외형을 게임에 적용한다.

- 로안: 은발 짧은 머리, 청록색 망토.
- 루미: 금발 묶음머리, 코랄색 망토.
- 같은 여행자 복장과 유품 장식, 같은 능력·스토리·충돌 판정.
- 기본 오른쪽 대기 자세 1장씩이다. 이동·점프·공격의 개별 애니메이션 프레임은 아직 포함하지 않는다. 기존 좌우 반전·피격/회피 색상 피드백을 그대로 사용한다.

## 리소스와 정렬

`roan_lumi_idle.png`는 이미지 생성 도구로 만든 RGBA 원본이다. 두 `.tres` AtlasTexture가 원본의 각 캐릭터 영역을 참조하며, 전투·선택·이야기 화면에서 같은 리소스를 사용한다. 선택·이야기 화면은 텍스처의 가로세로 비율을 유지한다.

| 리소스 | 원본 영역 x, y, w, h | 여백 x, y, w, h |
| --- | --- | --- |
| roan_idle.tres | 128, 16, 640, 992 | 0, 0, 80, 0 |
| lumi_idle.tres | 816, 16, 640, 992 | 0, 0, 80, 0 |

오른쪽 투명 여백 80px는 몸 중심을 프레임 중심에 맞추며, 좌우 반전에서도 중심이 유지된다. 전투 Sprite2D는 0.16배, 위치 (0, -16.64), 선형 필터링을 사용한다. 두 캐릭터 모두 부츠 하단을 기존 충돌체 하단 y=60에 맞춘다. 원본에서 완전 투명 픽셀의 RGB에 색상이 남아 있을 수 있으므로 반드시 알파 채널과 함께 렌더링한다.

## 검증

`game/tests/character_art_runtime_test.gd`를 기존 전체 검사 스크립트에 포함했다. 가져온 아틀라스 로드, 투명 배경과 캐릭터 사이 간격, 내부 불투명도, 발 정렬, 반전 시 크기 유지, 기존 체력·충돌체 유지 및 외형 안내를 확인한다. 기존 GP-267~276 검사는 캐릭터 선택, 저장·복원, 방향 전환과 두 캐릭터 능력 동일성을 검증한다. Android 리소스 팩 내보내기/부팅 검사에도 PNG와 AtlasTexture가 포함된다. 실기기 시각 확인은 별도로 필요하다.

## 제작 기록

Built-in image generation으로 직전 게임 스프라이트 시안을 편집했다. 핵심 지시: “Change ONLY Roan's hair (left male character) to SILVER WHITE with cool light gray shadows, and Lumi's hair (right female character) to GOLDEN BLONDE with warm honey shadows. Preserve the existing hairstyles, faces, poses, clothing, outlines, proportions, teal/coral capes, and all other character details. Remove all background, glow and haze; keep transparent empty margins and gap.”
