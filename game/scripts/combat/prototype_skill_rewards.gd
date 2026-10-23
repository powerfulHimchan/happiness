class_name PrototypeSkillRewards
extends RefCounted

## 무기별 스킬 중 미보유 두 후보를 순환 조회한다. 조회는 보상을 소비하지 않는다.
const SKILLS := {
	"sword_dawn_chain": preload("res://data/skills/sword_dawn_chain.tres"),
	"sword_retreat_wave": preload("res://data/skills/sword_retreat_wave.tres"),
	"sword_orbit": preload("res://data/skills/sword_orbit.tres"),
	"sword_high_arc": preload("res://data/skills/sword_high_arc.tres"),
	"sword_returning_edge": preload("res://data/skills/sword_returning_edge.tres"),
	"bow_prism_fan": preload("res://data/skills/bow_prism_fan.tres"),
	"bow_starlit_rain": preload("res://data/skills/bow_starlit_rain.tres"),
	"bow_swallow_trio": preload("res://data/skills/bow_swallow_trio.tres"),
	"bow_drill": preload("res://data/skills/bow_drill.tres"),
	"bow_retreat_fan": preload("res://data/skills/bow_retreat_fan.tres"),
	"fist_dawn_barrage": preload("res://data/skills/fist_dawn_barrage.tres"),
	"fist_retreat_palm": preload("res://data/skills/fist_retreat_palm.tres"),
	"fist_spiral": preload("res://data/skills/fist_spiral.tres"),
	"fist_sky_chain": preload("res://data/skills/fist_sky_chain.tres"),
	"fist_twin_pulse": preload("res://data/skills/fist_twin_pulse.tres"),
	"staff_crystal_fan": preload("res://data/skills/staff_crystal_fan.tres"),
	"staff_meteor_pair": preload("res://data/skills/staff_meteor_pair.tres"),
	"staff_dawn_pulse": preload("res://data/skills/staff_dawn_pulse.tres"),
	"staff_storm_seal": preload("res://data/skills/staff_storm_seal.tres"),
	"staff_retreat_lance": preload("res://data/skills/staff_retreat_lance.tres"),
	"polearm_horizon": preload("res://data/skills/polearm_horizon.tres"),
	"polearm_dawn_orbit": preload("res://data/skills/polearm_dawn_orbit.tres"),
	"polearm_skyward": preload("res://data/skills/polearm_skyward.tres"),
	"polearm_back_cross": preload("res://data/skills/polearm_back_cross.tres"),
	"polearm_comet": preload("res://data/skills/polearm_comet.tres"),
	"shield_dawn_chain": preload("res://data/skills/shield_dawn_chain.tres"),
	"shield_retreat_bash": preload("res://data/skills/shield_retreat_bash.tres"),
	"shield_orbit": preload("res://data/skills/shield_orbit.tres"),
	"shield_twin_wave": preload("res://data/skills/shield_twin_wave.tres"),
	"shield_cross_march": preload("res://data/skills/shield_cross_march.tres"),
	"polearm_cross": preload("res://data/skills/polearm_cross.tres"),
	"shield_wave": preload("res://data/skills/shield_wave.tres"),

	"fist_rising": preload("res://data/skills/fist_rising.tres"),
	"fist_cross": preload("res://data/skills/fist_cross.tres"),
	"fist_advancing": preload("res://data/skills/fist_advancing.tres"),
	"staff_ember_volley": preload("res://data/skills/staff_ember_volley.tres"),
	"staff_frost_ring": preload("res://data/skills/staff_frost_ring.tres"),
	"staff_thunder_echo": preload("res://data/skills/staff_thunder_echo.tres"),
	"polearm_windwheel": preload("res://data/skills/polearm_windwheel.tres"),
	"polearm_retreat": preload("res://data/skills/polearm_retreat.tres"),
	"shield_rush": preload("res://data/skills/shield_rush.tres"),
	"shield_ring": preload("res://data/skills/shield_ring.tres"),

	"staff_fireball": preload("res://data/skills/staff_fireball.tres"),
	"staff_ice_lance": preload("res://data/skills/staff_ice_lance.tres"),
	"staff_lightning": preload("res://data/skills/staff_lightning.tres"),
	"polearm_sweep": preload("res://data/skills/polearm_sweep.tres"),
	"polearm_thrust": preload("res://data/skills/polearm_thrust.tres"),
	"polearm_cycle": preload("res://data/skills/polearm_cycle.tres"),
	"shield_guard": preload("res://data/skills/shield_guard.tres"),
	"shield_counter": preload("res://data/skills/shield_counter.tres"),
	"shield_slam": preload("res://data/skills/shield_slam.tres"),

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
const POOLS := {"sword": ["sword_dash", "sword_spin", "sword_crescent", "sword_line", "sword_triple", "sword_thrust", "sword_charge", "sword_wave", "sword_cross", "sword_rising", "sword_revolve", "sword_flurry", "sword_cleave", "sword_twin_wave", "sword_sweep", "sword_backstep", "sword_alternating", "sword_dawn_chain", "sword_retreat_wave", "sword_orbit", "sword_high_arc", "sword_returning_edge"], "bow": ["bow_piercing", "bow_arrow_rain", "bow_volley", "bow_spread", "bow_focus", "bow_double_piercing", "bow_retreat", "bow_homing", "bow_ricochet", "bow_chain", "bow_fan_piercing", "bow_needle", "bow_heavy", "bow_wide_fan", "bow_storm", "bow_echo", "bow_seeking_volley", "bow_prism_fan", "bow_starlit_rain", "bow_swallow_trio", "bow_drill", "bow_retreat_fan"]}
const STAFF_POOL := ["staff_fireball", "staff_ice_lance", "staff_lightning", "staff_ember_volley", "staff_frost_ring", "staff_thunder_echo", "staff_crystal_fan", "staff_meteor_pair", "staff_dawn_pulse", "staff_storm_seal", "staff_retreat_lance"]
const POLEARM_POOL := ["polearm_sweep", "polearm_thrust", "polearm_cycle", "polearm_windwheel", "polearm_retreat", "polearm_cross", "polearm_horizon", "polearm_dawn_orbit", "polearm_skyward", "polearm_back_cross", "polearm_comet"]
const SHIELD_POOL := ["shield_guard", "shield_counter", "shield_slam", "shield_rush", "shield_ring", "shield_wave", "shield_dawn_chain", "shield_retreat_bash", "shield_orbit", "shield_twin_wave", "shield_cross_march"]
const FIST_POOL := ["fist_dash", "fist_flurry", "fist_wave", "fist_rising", "fist_cross", "fist_advancing", "fist_dawn_barrage", "fist_retreat_palm", "fist_spiral", "fist_sky_chain", "fist_twin_pulse"]
const LABELS := {"sword_dawn_chain": "오연", "sword_retreat_wave": "퇴월", "sword_orbit": "나선", "sword_high_arc": "천공", "sword_returning_edge": "왕복", "bow_prism_fan": "오색", "bow_starlit_rain": "별비", "bow_swallow_trio": "제비", "bow_drill": "나선시", "bow_retreat_fan": "퇴산", "fist_dawn_barrage": "육연", "fist_retreat_palm": "퇴장", "fist_spiral": "회권", "fist_sky_chain": "천련", "fist_twin_pulse": "쌍파", "staff_crystal_fan": "수정", "staff_meteor_pair": "쌍별", "staff_dawn_pulse": "맥동", "staff_storm_seal": "폭풍인", "staff_retreat_lance": "퇴빙", "polearm_horizon": "지평", "polearm_dawn_orbit": "회천", "polearm_skyward": "천봉", "polearm_back_cross": "퇴교", "polearm_comet": "유성", "shield_dawn_chain": "서련", "shield_retreat_bash": "퇴격", "shield_orbit": "삼환", "shield_twin_wave": "쌍서", "shield_cross_march": "진교", "polearm_cross": "양면", "shield_wave": "서약파", "fist_rising": "승천", "fist_cross": "교차권", "fist_advancing": "진격권", "staff_ember_volley": "불씨", "staff_frost_ring": "서리", "staff_thunder_echo": "뇌광", "polearm_windwheel": "풍륜", "polearm_retreat": "퇴보", "shield_rush": "수호진", "shield_ring": "원형격", "staff_fireball": "화염", "staff_ice_lance": "얼음", "staff_lightning": "낙뢰", "polearm_sweep": "횡소", "polearm_thrust": "관통", "polearm_cycle": "윤회", "shield_guard": "방어", "shield_counter": "응수", "shield_slam": "강타", "fist_dash": "쇄도", "fist_flurry": "연환", "fist_wave": "파동", "sword_flurry": "질풍", "sword_cleave": "대지", "sword_twin_wave": "쌍월", "sword_sweep": "삼중", "sword_backstep": "물러", "sword_alternating": "사방", "bow_needle": "바늘", "bow_heavy": "중압", "bow_wide_fan": "부채", "bow_storm": "폭풍", "bow_echo": "메아리", "bow_seeking_volley": "추적연", "sword_revolve": "선회", "bow_fan_piercing": "확산", "sword_rising": "올려", "bow_chain": "연쇄", "sword_dash": "돌진", "sword_spin": "회전", "sword_crescent": "반달", "sword_line": "일섬", "bow_piercing": "관통", "bow_arrow_rain": "화살비", "bow_volley": "연사", "bow_spread": "산개", "sword_triple": "삼연", "bow_focus": "집중", "sword_thrust": "찌르기", "bow_double_piercing": "이중", "sword_charge": "돌파", "bow_retreat": "후퇴", "bow_homing": "추적", "sword_wave": "검기", "bow_ricochet": "도탄", "sword_cross": "교차"}
const DAWN_SKILLS := ["sword_dawn_chain", "sword_retreat_wave", "sword_orbit", "sword_high_arc", "sword_returning_edge", "bow_prism_fan", "bow_starlit_rain", "bow_swallow_trio", "bow_drill", "bow_retreat_fan", "fist_dawn_barrage", "fist_retreat_palm", "fist_spiral", "fist_sky_chain", "fist_twin_pulse", "staff_crystal_fan", "staff_meteor_pair", "staff_dawn_pulse", "staff_storm_seal", "staff_retreat_lance", "polearm_horizon", "polearm_dawn_orbit", "polearm_skyward", "polearm_back_cross", "polearm_comet", "shield_dawn_chain", "shield_retreat_bash", "shield_orbit", "shield_twin_wave", "shield_cross_march"]
const CODEX_PAGE_SIZE := 3
# 새 기술을 뒤에 붙여 이전 도감의 페이지 순서를 보존한다.
const CODEX_ORDER := ["sword_dash", "bow_piercing", "sword_spin", "bow_arrow_rain", "sword_crescent", "bow_volley", "sword_line", "bow_spread", "sword_triple", "bow_focus", "sword_thrust", "bow_double_piercing", "sword_charge", "bow_retreat", "bow_homing", "sword_wave", "bow_ricochet", "sword_cross", "sword_rising", "bow_chain", "sword_revolve", "bow_fan_piercing", "sword_flurry", "sword_cleave", "sword_twin_wave", "sword_sweep", "sword_backstep", "sword_alternating", "bow_needle", "bow_heavy", "bow_wide_fan", "bow_storm", "bow_echo", "bow_seeking_volley", "fist_dash", "fist_flurry", "fist_wave", "staff_fireball", "staff_ice_lance", "staff_lightning", "polearm_sweep", "polearm_thrust", "polearm_cycle", "shield_guard", "shield_counter", "shield_slam", "fist_rising", "fist_cross", "fist_advancing", "staff_ember_volley", "staff_frost_ring", "staff_thunder_echo", "polearm_windwheel", "polearm_retreat", "shield_rush", "shield_ring", "polearm_cross", "shield_wave", "sword_dawn_chain", "sword_retreat_wave", "sword_orbit", "sword_high_arc", "sword_returning_edge", "bow_prism_fan", "bow_starlit_rain", "bow_swallow_trio", "bow_drill", "bow_retreat_fan", "fist_dawn_barrage", "fist_retreat_palm", "fist_spiral", "fist_sky_chain", "fist_twin_pulse", "staff_crystal_fan", "staff_meteor_pair", "staff_dawn_pulse", "staff_storm_seal", "staff_retreat_lance", "polearm_horizon", "polearm_dawn_orbit", "polearm_skyward", "polearm_back_cross", "polearm_comet", "shield_dawn_chain", "shield_retreat_bash", "shield_orbit", "shield_twin_wave", "shield_cross_march"]

## GP-132: 실제 스킬 원본을 읽는다. 도감 조회는 장착이나 보상을 변경하지 않는다.
static func codex_cards(loadout: Dictionary = {}, recharge_multiplier: float = 1.0, family_recharge: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var active := valid_loadout(loadout)
	var starting := defaults(PrototypeWeaponRewards.FAMILY_IDS)
	for id in CODEX_ORDER:
		var weapon := weapon_for(id)
		var slot: int = loadout.get(weapon, []).find(id) if active else starting.get(weapon, []).find(id)
		var status := "이번 도전 · 슬롯 %d" % (slot + 1) if active and slot >= 0 else "미장착 · 효과 미리 보기" if active else "시작 스킬 · 슬롯 %d" % (slot + 1) if slot >= 0 else "보상 교체 스킬"
		var rate := float(family_recharge.get(weapon, recharge_multiplier)) if active else 1.0
		var effect := lines(id, rate)
		effect.append("시작 장착 · 새 도전마다 초기화" if id in starting.get(weapon, []) else "정예 후 스킬 보상에서 슬롯 교체")
		effect.append("표기 피해는 강화 전 기본값")
		var recharge_note := "시계추 적용 · 재사용 -20%" if active and recharge_multiplier > 1.0 else "첫·두 번째 정예 후 교체 가능"
		if active and rate > recharge_multiplier:
			recharge_note = ("시계추·숙련" if recharge_multiplier > 1.0 else "숙련")+" · 재충전 ×%.2f" % rate
		effect.append(recharge_note)
		result.append({"id": id, "weapon": weapon, "name": (PrototypeWeaponRewards.family_name(weapon) + " · ") + String(SKILLS[id].display_name), "open": slot >= 0, "status": status, "lines": effect})
	return result

static func defaults(families: Array = ["sword", "bow"]) -> Dictionary:
	var result := {}
	for family in families:
		var pool: Array = pool_for(String(family))
		if pool.size() >= 2: result[family] = pool.slice(0, 2)
	return result

static func valid_loadout(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 2: return false
	for weapon in value:
		var pool: Array = pool_for(String(weapon))
		if pool.is_empty() or not value[weapon] is Array or value[weapon].size() != 2: return false
		if value[weapon][0] == value[weapon][1]: return false
		for id in value[weapon]:
			if not id is String or id not in pool: return false
	return true

static func pool_for(family: String) -> Array:
	if family == "staff": return STAFF_POOL
	if family == "polearm": return POLEARM_POOL
	if family == "shield": return SHIELD_POOL
	return FIST_POOL if family == "fist" else POOLS.get(family, [])

static func weapon_for(id: String) -> String:
	if id in STAFF_POOL: return "staff"
	if id in POLEARM_POOL: return "polearm"
	if id in SHIELD_POOL: return "shield"

	if id in FIST_POOL: return "fist"
	for weapon in POOLS:
		if id in POOLS[weapon]: return weapon
	return ""

static func lines(id: String, recharge_multiplier: float = 1.0) -> Array[String]:
	var definition: SkillDefinition = SKILLS[id]
	var result: Array[String] = ["재사용 %.1f초 · 동작 %.2f초" % [definition.cooldown_s / recharge_multiplier, definition.duration_s]]
	result.append("타격 %d회 · 기본 피해 %d" % [definition.damage.size(), _total_damage(definition)])
	if id in ["bow_spread", "bow_fan_piercing"] or definition.execution_style in [&"spread", &"staff_fan"]:
		result[1] = "%s %d발 · 각 기본 피해 %d" % ["마법탄" if definition.execution_style == &"staff_fan" else "화살", definition.spread_angles_deg.size() * definition.hit_times_s.size(), int(definition.damage[0])]
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
		for id in pool_for(String(weapon)):
			if id not in loadout[weapon]: candidates += 1
		count = maxi(count, candidates)
	return count

static func offers(loadout: Dictionary, offset: int = 0, recharge_multiplier: float = 1.0, family_recharge: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var candidates := {}
	for weapon in PrototypeWeaponRewards.FAMILY_IDS:
		if not loadout.has(weapon): continue
		candidates[weapon] = []
		for id in pool_for(String(weapon)):
			if id not in loadout[weapon]:
				candidates[weapon].append(id)
	# 무기를 번갈아 제안해 기존 후보와 새 후보를 같은 화면에서 비교한다.
	for index in 2:
		for weapon in PrototypeWeaponRewards.FAMILY_IDS:
			if not loadout.has(weapon): continue
			var id: String = candidates[weapon][posmod(offset + index, candidates[weapon].size())]
			if not result.any(func(card: Dictionary) -> bool: return card.id == id):
				result.append({"id": id, "weapon": weapon, "name": SKILLS[id].display_name, "lines": lines(id, float(family_recharge.get(weapon, recharge_multiplier)))})
	return result
