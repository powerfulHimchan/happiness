class_name PrototypeSkillRewards
extends RefCounted

## 무기별 스킬 중 미보유 두 후보를 순환 조회한다. 조회는 보상을 소비하지 않는다.
const SKILLS := {
	"fist_dash": preload("res://data/skills/fist_dash.tres"),
	"fist_flurry": preload("res://data/skills/fist_flurry.tres"),
	"fist_wave": preload("res://data/skills/fist_wave.tres"),
	"sword_flurry": preload("res://data/skills/sword_flurry.tres"),
	"sword_cleave": preload("res://data/skills/sword_cleave.tres"),
	"sword_twin_wave": preload("res://data/skills/sword_twin_wave.tres"),
	"sword_sweep": preload("res://data/skills/sword_sweep.tres"),
	"sword_backstep": preload("res://data/skills/sword_backstep.tres"),
	"sword_alternating": preload("res://data/skills/sword_alternating.tres"),
	"bow_needle": preload("res://data/skills/bow_needle.tres"),
	"bow_heavy": preload("res://data/skills/bow_heavy.tres"),
	"bow_wide_fan": preload("res://data/skills/bow_wide_fan.tres"),
	"bow_storm": preload("res://data/skills/bow_storm.tres"),
	"bow_echo": preload("res://data/skills/bow_echo.tres"),
	"bow_seeking_volley": preload("res://data/skills/bow_seeking_volley.tres"),

	"sword_revolve": preload("res://data/skills/sword_revolve.tres"),
	"bow_fan_piercing": preload("res://data/skills/bow_fan_piercing.tres"),
	"sword_rising": preload("res://data/skills/sword_rising.tres"),
	"bow_chain": preload("res://data/skills/bow_chain.tres"),
	"sword_dash": preload("res://data/skills/sword_dash.tres"),
	"sword_spin": preload("res://data/skills/sword_spin.tres"),
	"sword_crescent": preload("res://data/skills/sword_crescent.tres"),
	"sword_line": preload("res://data/skills/sword_line.tres"),
	"sword_triple": preload("res://data/skills/sword_triple.tres"),
	"bow_piercing": preload("res://data/skills/bow_piercing.tres"),
	"bow_arrow_rain": preload("res://data/skills/bow_arrow_rain.tres"),
	"bow_volley": preload("res://data/skills/bow_volley.tres"),
	"bow_spread": preload("res://data/skills/bow_spread.tres"),
	"bow_focus": preload("res://data/skills/bow_focus.tres"),
	"sword_thrust": preload("res://data/skills/sword_thrust.tres"),
	"bow_double_piercing": preload("res://data/skills/bow_double_piercing.tres"),
	"sword_charge": preload("res://data/skills/sword_charge.tres"),
	"bow_retreat": preload("res://data/skills/bow_retreat.tres"),
	"bow_homing": preload("res://data/skills/bow_homing.tres"),
	"sword_wave": preload("res://data/skills/sword_wave.tres"),
	"bow_ricochet": preload("res://data/skills/bow_ricochet.tres"),
	"sword_cross": preload("res://data/skills/sword_cross.tres"),
}
const POOLS := {"sword": ["sword_dash", "sword_spin", "sword_crescent", "sword_line", "sword_triple", "sword_thrust", "sword_charge", "sword_wave", "sword_cross", "sword_rising", "sword_revolve", "sword_flurry", "sword_cleave", "sword_twin_wave", "sword_sweep", "sword_backstep", "sword_alternating"], "bow": ["bow_piercing", "bow_arrow_rain", "bow_volley", "bow_spread", "bow_focus", "bow_double_piercing", "bow_retreat", "bow_homing", "bow_ricochet", "bow_chain", "bow_fan_piercing", "bow_needle", "bow_heavy", "bow_wide_fan", "bow_storm", "bow_echo", "bow_seeking_volley"]}
const FIST_POOL := ["fist_dash", "fist_flurry", "fist_wave"]
const LABELS := {"fist_dash": "쇄도", "fist_flurry": "연환", "fist_wave": "파동", "sword_flurry": "질풍", "sword_cleave": "대지", "sword_twin_wave": "쌍월", "sword_sweep": "삼중", "sword_backstep": "물러", "sword_alternating": "사방", "bow_needle": "바늘", "bow_heavy": "중압", "bow_wide_fan": "부채", "bow_storm": "폭풍", "bow_echo": "메아리", "bow_seeking_volley": "추적연", "sword_revolve": "선회", "bow_fan_piercing": "확산", "sword_rising": "올려", "bow_chain": "연쇄", "sword_dash": "돌진", "sword_spin": "회전", "sword_crescent": "반달", "sword_line": "일섬", "bow_piercing": "관통", "bow_arrow_rain": "화살비", "bow_volley": "연사", "bow_spread": "산개", "sword_triple": "삼연", "bow_focus": "집중", "sword_thrust": "찌르기", "bow_double_piercing": "이중", "sword_charge": "돌파", "bow_retreat": "후퇴", "bow_homing": "추적", "sword_wave": "검기", "bow_ricochet": "도탄", "sword_cross": "교차"}
const CODEX_PAGE_SIZE := 3
# 새 기술을 뒤에 붙여 이전 도감의 페이지 순서를 보존한다.
const CODEX_ORDER := ["sword_dash", "bow_piercing", "sword_spin", "bow_arrow_rain", "sword_crescent", "bow_volley", "sword_line", "bow_spread", "sword_triple", "bow_focus", "sword_thrust", "bow_double_piercing", "sword_charge", "bow_retreat", "bow_homing", "sword_wave", "bow_ricochet", "sword_cross", "sword_rising", "bow_chain", "sword_revolve", "bow_fan_piercing", "sword_flurry", "sword_cleave", "sword_twin_wave", "sword_sweep", "sword_backstep", "sword_alternating", "bow_needle", "bow_heavy", "bow_wide_fan", "bow_storm", "bow_echo", "bow_seeking_volley", "fist_dash", "fist_flurry", "fist_wave"]

## GP-132: 실제 스킬 원본을 읽는다. 도감 조회는 장착이나 보상을 변경하지 않는다.
static func codex_cards(loadout: Dictionary = {}, recharge_multiplier: float = 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active := valid_loadout(loadout)
	var starting := defaults(PrototypeWeaponRewards.FAMILY_IDS)
	for id in CODEX_ORDER:
		var weapon := weapon_for(id)
		var slot: int = loadout.get(weapon, []).find(id) if active else starting.get(weapon, []).find(id)
		var status := "이번 도전 · 슬롯 %d" % (slot + 1) if active and slot >= 0 else "미장착 · 효과 미리 보기" if active else "시작 스킬 · 슬롯 %d" % (slot + 1) if slot >= 0 else "보상 교체 스킬"
		var effect := lines(id, recharge_multiplier if active else 1.0)
		effect.append("시작 장착 · 새 도전마다 초기화" if id in starting.get(weapon, []) else "정예 후 스킬 보상에서 슬롯 교체")
		effect.append("표기 피해는 강화 전 기본값")
		effect.append("시계추 적용 · 재사용 -20%" if active and recharge_multiplier > 1.0 else "첫·두 번째 정예 후 교체 가능")
		result.append({"id": id, "weapon": weapon, "name": (PrototypeWeaponRewards.family_name(weapon) + " · ") + String(SKILLS[id].display_name), "open": slot >= 0, "status": status, "lines": effect})
	return result

static func defaults(families: Array = ["sword", "bow"]) -> Dictionary:
	var result := {}
	for family in families:
		var pool: Array = FIST_POOL if family == "fist" else POOLS.get(family, [])
		if pool.size() >= 2: result[family] = pool.slice(0, 2)
	return result

static func valid_loadout(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	for weapon in value:
		var pool: Array = FIST_POOL if weapon == "fist" else POOLS.get(weapon, [])
		if pool.is_empty() or not value[weapon] is Array or value[weapon].size() != 2: return false
		if value[weapon][0] == value[weapon][1]: return false
		for id in value[weapon]:
			if not id is String or id not in pool: return false
	return true

static func weapon_for(id: String) -> String:
	if id in FIST_POOL: return "fist"
	for weapon in POOLS:
		if id in POOLS[weapon]: return weapon
	return ""

static func lines(id: String, recharge_multiplier: float = 1.0) -> Array[String]:
	var definition: SkillDefinition = SKILLS[id]
	var result: Array[String] = ["재사용 %.1f초 · 동작 %.2f초" % [definition.cooldown_s / recharge_multiplier, definition.duration_s]]
	result.append("타격 %d회 · 기본 피해 %d" % [definition.damage.size(), _total_damage(definition)])
	if id in ["bow_spread", "bow_fan_piercing"] or definition.execution_style == &"spread":
		result[1] = "화살 %d발 · 각 기본 피해 %d" % [definition.spread_angles_deg.size(), int(definition.damage[0])]
	if id == "bow_ricochet":
		result[1] = "첫 피해%d · 도탄 피해%d" % [definition.damage[0], definition.ricochet_damage]
	if id == "sword_cross":
		result[1] = "정면 피해%d · 후방 피해%d" % [definition.damage[0], definition.damage[1]]
	if not definition.effect_summary.is_empty():
		result.append(definition.effect_summary)
		return result
	match id:
		"sword_revolve": result.append("각2.2m · 앞/뒤/앞 3타 · 방향 고정")
		"bow_fan_piercing": result.append("정면30도 · 각 최대2개체 관통")
		"sword_rising": result.append("정면1.8m · 위로1.8m · 아래0.4m")
		"bow_chain": result.append("화살3발 · 각 최대2개체 관통")
		"sword_dash": result.append("전방 대상 돌진 · 이동 3.5m")
		"sword_spin": result.append("주변 2m · 두 번 베기")
		"sword_crescent": result.append("주변 3m · 한 번 크게 베기")
		"sword_line": result.append("정면 4m · 상하 0.9m · 1타")
		"sword_thrust": result.append("정면 %.1fm · 상하 %.2fm · 1타" % [definition.hit_range_m, definition.hit_half_height_m])
		"bow_double_piercing": result.append("화살 2발 · 각 최대 %d개체 관통" % definition.max_targets)
		"sword_triple": result.append("정면 2.4m · 상하 0.9m · 3타")
		"sword_wave": result.append("검기 6m · 상하 0.6m · 최대3개체 관통")
		"sword_cross": result.append("각 2.4m · 상하 0.9m · 시전 방향 고정")
		"sword_charge": result.append("전진 2.4m · 정면 2m · 2타")
		"bow_retreat": result.append("후퇴 1.8m · 방향 고정 · 2발")
		"bow_homing": result.append("정면 표적 고정 · 최대 1초 추적")
		"bow_ricochet": result.append("주변 %.1fm · 다른 적에 한 번 도탄" % definition.ricochet_range_m)
		"bow_focus": result.append("0.7초 준비 · 정면 1발 · 이동 불가")
		"bow_piercing": result.append("화살 1발 · 최대 3개체 관통")
		"bow_arrow_rain": result.append("대상 주변 2.4m · 범위 6타")
		"bow_volley": result.append("화살 3발 · 각 1개체 타격")
		"bow_spread": result.append("정면 30도 산개 · 각 1개체")
	return result

static func _total_damage(definition: SkillDefinition) -> int:
	var total := 0
	for damage in definition.damage:
		total += damage
	return total

static func offer_page_count(loadout: Dictionary) -> int:
	var count := 1
	for weapon in PrototypeWeaponRewards.FAMILY_IDS:
		if not loadout.has(weapon): continue
		var candidates := 0
		for id in (FIST_POOL if weapon == "fist" else POOLS[weapon]):
			if id not in loadout[weapon]: candidates += 1
		count = maxi(count, candidates)
	return count

static func offers(loadout: Dictionary, offset: int = 0, recharge_multiplier: float = 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidates := {}
	for weapon in PrototypeWeaponRewards.FAMILY_IDS:
		if not loadout.has(weapon): continue
		candidates[weapon] = []
		for id in (FIST_POOL if weapon == "fist" else POOLS[weapon]):
			if id not in loadout[weapon]:
				candidates[weapon].append(id)
	# 무기를 번갈아 제안해 기존 후보와 새 후보를 같은 화면에서 비교한다.
	for index in 2:
		for weapon in PrototypeWeaponRewards.FAMILY_IDS:
			if not loadout.has(weapon): continue
			var id: String = candidates[weapon][posmod(offset + index, candidates[weapon].size())]
			if not result.any(func(card: Dictionary) -> bool: return card.id == id):
				result.append({"id": id, "weapon": weapon, "name": SKILLS[id].display_name, "lines": lines(id, recharge_multiplier)})
	return result
