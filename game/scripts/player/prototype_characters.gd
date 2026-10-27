class_name PrototypeCharacters
extends RefCounted

## 두 주인공의 공통 능력치·무기와 캐릭터별 고유 특성 카탈로그.
const IDS := ["roan", "lumi"]
const ROAN_TEXTURE: Texture2D = preload("res://assets/characters/roan_idle.tres")
const LUMI_TEXTURE: Texture2D = preload("res://assets/characters/lumi_idle.tres")
const SHARED_STORY := "남은 시간을 걸어 행복의 나라로 향합니다"
const STORIES := {
	"roan": "로안은 작은 마을의 시계 수리점에서 자랐다. 멈춘 시계에도 다시 움직일 순간이 있다고 믿던 그는, 몸에 남은 시간이 얼마 없다는 사실을 알게 된다. 유품 속 새벽시계가 가리킨 곳은 모든 소원을 이뤄 준다는 행복의 나라. 어린 시절 세라와 나눈 약속을 떠올린 로안은 청록빛 망토를 두르고 길을 나선다. 적의 움직임을 살피고, 물러선 한 걸음을 반격의 기회로 바꾸는 것이 그의 방식이다. 시간을 되돌릴 때마다 마을의 아침은 다시 찾아오지만, 지나온 마음까지 사라지지는 않는다. 로안은 자신이 살아갈 내일과 소중한 이들이 함께 웃을 새벽을 찾으려 한다.",
	"lumi": "루미는 언덕에서 별을 바라보며 이야기를 모으던 아이였다. 낯선 길에서도 먼저 웃고 손을 내밀지만, 몸의 이상을 홀로 견뎌 왔다. 어느 밤 유품 속 새벽시계가 별빛에 반응하자, 루미는 어린 시절 세라와 꿈꾸었던 행복의 나라를 떠올린다. 코랄빛 망토를 두르고 떠난 여행에서 그녀는 서로 다른 무기의 리듬을 이어 자신만의 빈틈을 만든다. 길을 잃거나 다시 출발하게 되어도 만난 사람들의 작은 친절은 마음에 남는다. 루미가 바라는 것은 아픔을 잊게 하는 완벽한 행복이 아니다. 슬픈 날에도 소중한 이들과 나란히 걸으며, 내일을 기대할 수 있는 평범한 아침이다.",
}

static func valid_id(id: Variant) -> bool:
	return id is String and id in IDS

static func display_name(id: String) -> String:
	return "루미" if id == "lumi" else "로안"

static func texture(id: String) -> Texture2D:
	return LUMI_TEXTURE if id == "lumi" else ROAN_TEXTURE

static func appearance(id: String) -> String:
	return "금발 묶음머리 · 코랄빛 망토" if id == "lumi" else "은발 짧은 머리 · 청록빛 망토"

static func trait_profile(id: String) -> Dictionary:
	return HeroTraits.profile(id)

static func biography(id: String) -> String:
	return String(STORIES.get(id, ""))

## Base values, before equipment/memories/legacy/expedition modifiers.
static func initial_combat_stats() -> Dictionary:
	return {"attack_speed": PrototypeCombatStats.BASE_ATTACK_SPEED, "health": PrototypeCombatStats.BASE_HEALTH, "attack": PrototypeCombatStats.BASE_ATTACK, "defense": PrototypeCombatStats.BASE_DEFENSE, "critical_chance": PrototypeCombatStats.BASE_CRITICAL_CHANCE, "critical_damage": PrototypeCombatStats.BASE_CRITICAL_DAMAGE}
