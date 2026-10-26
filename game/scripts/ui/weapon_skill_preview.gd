class_name WeaponSkillPreview
extends RefCounted

## Read-only starting-skill descriptions backed by the same SkillDefinition resources.
const DESCRIPTIONS := {
	"sword_dash":"전방의 적을 향해 빠르게 돌진해 한 번 벱니다.",
	"sword_spin":"주변을 회전하며 두 번 베어 가까운 적들을 공격합니다.",
	"bow_piercing":"일직선으로 날아가는 화살이 여러 적을 관통합니다.",
	"bow_arrow_rain":"대상 주변에 화살을 쏟아 여러 번 타격합니다.",
	"fist_dash":"앞으로 파고들며 주먹으로 적을 강하게 타격합니다.",
	"fist_flurry":"바라보는 방향으로 빠른 연속 주먹 공격을 펼칩니다.",
	"staff_fireball":"화염구를 날려 충돌 지점 주변에 폭발을 일으킵니다.",
	"staff_ice_lance":"날카로운 얼음창을 날려 전방의 적들을 관통합니다.",
	"polearm_sweep":"장봉을 크게 휘둘러 주변의 적을 공격하고 밀어냅니다.",
	"polearm_thrust":"장봉을 길게 찔러 정면의 적을 공격하고 밀어냅니다.",
	"shield_guard":"방패를 들어 전방의 피해를 줄이고 경직을 막습니다.",
	"shield_counter":"방어에 성공하면 더 강한 반격으로 적을 기절시킵니다.",
}
const TRAITS := {
	"sword_dash":"돌진 · 근접", "sword_spin":"주변 범위 · 2회 타격",
	"bow_piercing":"직선 · 관통", "bow_arrow_rain":"범위 · 연속 타격",
	"fist_dash":"전진 · 강타", "fist_flurry":"연속 공격",
	"staff_fireball":"화염 · 폭발", "staff_ice_lance":"얼음 · 관통",
	"polearm_sweep":"주변 · 밀침", "polearm_thrust":"직선 · 밀침",
	"shield_guard":"전방 · 방어", "shield_counter":"방어 성공 · 반격",
}

static func ids(family: String) -> Array:
	return PrototypeSkillRewards.defaults([family]).get(family, [])

static func profile(id: String) -> Dictionary:
	if not DESCRIPTIONS.has(id): return {}
	var definition: SkillDefinition = PrototypeSkillRewards.SKILLS[id]
	var total := 0
	for amount in definition.damage: total += amount
	var stats: Array = [["기본 피해", str(total)], ["재사용", "%s초" % str(definition.cooldown_s).trim_suffix(".0")], ["돌진 거리" if definition.movement_distance_m > 0 else "공격 범위", "%sm" % str(definition.movement_distance_m if definition.movement_distance_m > 0 else definition.hit_range_m).trim_suffix(".0")], ["타격 횟수", "%d회" % definition.damage.size()]]
	if id == "shield_guard":
		stats = [["기술 유형", "전방 방어"], ["재사용", "%s초" % str(definition.cooldown_s).trim_suffix(".0")], ["지속 시간", "%s초" % str(definition.duration_s).trim_suffix(".0")], ["타격", "없음"]]
	var details := PrototypeSkillRewards.lines(id)
	return {"id":id, "family":PrototypeSkillRewards.weapon_for(id), "name":definition.display_name, "traits":TRAITS[id], "description":DESCRIPTIONS[id], "effect":details.back(), "stats":stats}
