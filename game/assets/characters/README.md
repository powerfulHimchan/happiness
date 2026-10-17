# 주인공 기본 그래픽

2026-10-15 사용자가 승인한 카툰형 기본 외형을 게임에 적용한다.

- 로안: 은발 짧은 머리, 청록색 망토.
- 루미: 금발 묶음머리, 코랄색 망토.
- 같은 여행자 복장과 유품 장식, 같은 능력·스토리·충돌 판정.
- 선택·이야기 화면에는 기본 오른쪽 자세를 사용한다. 전투에서는 아래 이동 애니메이션을 재생하며 기존 좌우 반전·피격/회피 색상 피드백도 유지한다. 검·활 공격에는 아래 전투 애니메이션을 사용한다.

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

## 이동 애니메이션 (2026-10-16)

`roan_movement.png`, `lumi_movement.png`: Built-in image generation으로 제작한 투명 RGBA 시트, 각 1536×1024 / 24개 자세. 은발·청록 망토 로안, 금발 포니테일·코랄 망토 루미의 기존 복장과 장식을 유지한다. 원본 PNG는 수정하지 않고 게임에서 AtlasTexture로 각 자세를 참조한다.

| 동작 | 프레임 인덱스 (0부터) | 재생 |
| --- | --- | --- |
| 대기 | 0–1 | 2.5fps 반복 |
| 달리기 | 2–7 | 기본 12fps, 실제 수평 속도에 맞춰 조절 |
| 점프 | 8–9 | 7fps, 마지막 자세 유지 |
| 낙하 | 10–11 | 6fps, 마지막 자세 유지 |
| 착지 | 12–13 | 약 0.143초; 새 점프·회피·공격 즉시 우선 |
| 지상 회피 | 14–16 | 기존 회피 0.24초에 맞춤 |
| 공중 대시 | 17–18 | 기존 대시 0.18초에 맞춤 |
| 피격 | 19–20 | 기존 피격 플래시 0.12초에 맞춤 |
| 사망 | 21–23 | 5fps, 쓰러진 마지막 자세 유지 |

`hero_movement_animation.gd`는 시각 표현만 담당한다. 물리 이동, 충돌체, 피해, 무적 시간, 입력과 저장 형식은 변경하지 않는다. 사망 → 피격 → 회피/대시 → 공중 → 착지 → 이동/대기 순서로 우선한다. 전투 애니메이션이 없는 동안에는 이동 상태를 재생하며, 공격 중에는 아래 공격 자세가 우선한다. 기존 검격/화살 효과는 유지한다. 일시정지하면 플레이어 물리 처리와 함께 재생도 멈춘다. 재시작·다음 스테이지·캐릭터 변경 시 이전 동작과 시간을 초기화한다.

생성 이미지의 자세가 정확한 격자에 들어맞지 않으므로 `REGIONS`에 실제 알파 경계, `PIVOTS`에 몸통 기준 x를 기록했다. 각 AtlasTexture는 384×288 투명 여백 프레임으로 정렬하며 발 기준 y=272, 화면상의 바닥 y=60을 유지한다. 동일 캐릭터의 모든 동작에 하나의 배율을 적용해 웅크리거나 쓰러질 때 몸 크기를 늘리지 않는다. 공중 대시는 수평 자세를 위해 시각 위치만 30px 올린다. `filter_clip`과 1px 여유 영역으로 이웃 자세가 섞이지 않게 한다.

### 검증

`hero_movement_animation_runtime_test.gd`는 두 캐릭터의 48개 자세 로드·투명 배경·프레임 분리·발 정렬·좌우 반전, 동작 우선순위, 실제 물리 이동/점프/낙하/착지/회피/대시, 실제 피격/사망, 재시작·스테이지 초기화를 검증한다. 기존 캐릭터 검사 중 피격 검증은 정지 초상화 대신 선택한 캐릭터의 피격 시트를 확인하도록 갱신했다. 기존 전체 검사 및 Android 리소스 팩 내보내기/부팅 검사에 포함한다. 실제 Android 기기 플레이는 별도 확인 대상이다.

### 제작 프롬프트

Built-in image generation을 사용했다. 기존 `roan_lumi_idle.png`를 외형 참조로, 로안 시트를 루미의 자세 참조로 사용했다. 두 프롬프트의 공통 지시:

“Production 2D platformer animation sprite sheet, exactly 24 full-body sprites in 6 columns by 4 rows, landscape 1536×1024, transparent RGBA, facing right, consistent body proportions, preserve reference costume and pendant, no text/grid/weapons/particles. Row1 idle neutral, idle breathe, run extended stride, run passing, opposite extended stride, opposite passing. Row2 run push-off, run flight, jump rising, jump apex, falling, prepare landing. Row3 land deep crouch, land recover, evade low lean, evade tuck roll, evade rise, air dash reaching right. Row4 air dash recovery, hit recoil, hit recover, defeat kneel, defeat falling, defeated lying on side.”

캐릭터별 지시: 로안은 “silver short hair, brown eyes, teal cape, white tunic, dark pants, brown boots, turquoise pendant”; 루미는 “golden blonde ponytail, brown eyes, coral red cape, white tunic, dark pants, brown boots, turquoise gold pendant; replace male with Lumi in every frame, never silver hair or blue cape”.


## 전투 애니메이션 (2026-10-17)

`roan_combat.png`, `lumi_combat.png`: Built-in image generation으로 만든 투명 RGBA 1536×1024 시트다. 각 캐릭터에 베기·찌르기·정면 사격·상향 사격을 4자세씩, 총 16자세를 추가했다. `hero_combat_animation.gd`에서 원본을 AtlasTexture로 읽으며 원본 PNG는 편집하지 않는다. 여백이 겹치지 않도록 시트를 재생성했고 루미의 상향 발사 후 활 잡는 손을 수정했다.

| 동작 | 프레임 | 사용 |
| --- | --- | --- |
| 검 베기 | 0–3 | 기본 1·2타와 베기 계열 스킬 |
| 검 찌르기 | 4–7 | 기본 3타, 정밀 찌르기·돌파 베기 |
| 정면 사격 | 8–11 | 활 기본 공격과 정면·부채·추적·관통 스킬 |
| 상향 사격 | 12–15 | 화살비와 폭풍 화살비 |

스킬 시작은 준비 자세, 실제 타격/투사체 생성 이벤트는 타격·발사 자세를 재생한다. 기본 공격은 기존 즉시 타격을 유지하며 바로 타격 자세에서 시작해 0.24초 동안 마무리한다. 스킬의 준비 시간·다단 히트·취소 시점은 기존 데이터를 사용한다. 교차/선회/교대 베기는 실제 타격 방향으로 외형만 반전하고 플레이어의 조작 방향은 바꾸지 않는다. 사망·피격·회피·대시·낙하 복귀가 우선하며 무기 교체·재시작·스테이지 전환·캐릭터 변경 시 남은 공격 자세를 지운다. 일시정지는 물리 처리와 함께 정지한다.

무기 종류별 공통 4개 동작이며 모든 스킬마다 별도 원화를 만든 것은 아니다. 필살기 전용 동작과 무기 등급별 외형은 후속 범위다. 피해·사거리·투사체·물리·충돌·입력·저장 형식은 변경하지 않는다. 실제 alpha 경계와 몸통 중심을 측정해 512×288 여백 프레임에 정렬하며 부츠 하단은 기존 바닥 y=60, 배율은 캐릭터별 하나를 사용한다.

검증: `hero_combat_animation_runtime_test.gd`에서 32자세의 리소스·투명 배경·프레임 간섭·실제 발 정렬, 실제 검 기본 3연격/활 발사와 모든 34스킬의 시작·타격·종료 연결, 입력 거부·좌우 전환·취소·무기 전환·일시정지·상태 초기화·저장 불변을 확인한다. 기존 외형·이동 애니메이션 검사 및 Android 리소스 팩 내보내기·부팅을 함께 확인한다. Android 실기기 플레이는 별도다.

### 제작 프롬프트

기존 이동 시트를 외형 참조로 Built-in image generation을 사용했다. 핵심 지시: “Production 2D side scrolling game COMBAT ANIMATION sprite sheet, exactly SIXTEEN full-body poses, 4 columns x 4 rows, 1536×1024 transparent RGBA. Preserve silver-haired Roan with teal cape / golden-blonde ponytailed Lumi with coral cape, costume and pendant. Row1 sword slash anticipation, impact, follow-through, guard. Row2 sword thrust anticipation, lunge, follow-through, guard. Row3 horizontal bow nock, draw, release without arrow, recover. Row4 up-right bow nock, draw, release without arrow, recover. Face RIGHT. No text, grid, floor, haze, glow or particles.”

최종 배치 지시: “Shrink every individual complete sprite to 72 percent and recenter within its own cell. Preserve all 16 poses and appearance. Wide transparent gutters; no weapon, cape, boots or hair may cross into another sprite. Uniform scale, never stretch.” 루미 수정: “Row4 column3 forward hand firmly grips the bow handle after release; no detached bow.”
