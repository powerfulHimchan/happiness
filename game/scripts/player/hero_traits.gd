class_name HeroTraits
extends RefCounted

const ROAN_DURATION := 3.0
const ROAN_COOLDOWN := 6.0
const ROAN_ATTACK := 1.25
const LUMI_COOLDOWN := 8.0
var roan_remaining := 0.0
var roan_cooldown := 0.0
var lumi_cooldown := 0.0
var lumi_weapon := ""

static func profile(character: String) -> Dictionary:
	return {"id":"starlight_response", "name":"별빛의 응답", "lines":["무기 전환 후 전환한 무기의 다음 1타", "유효 적중 시 확정 치명타 · 재발동 8초", "빗나감·무적 차단은 소비하지 않음"]} if character == "lumi" else {"id":"counter_moment", "name":"반격의 순간", "lines":["정확한 회피 성공 후 3초간 공격력 +25%", "재발동 6초 · 모든 무기 적용", "기본 공격·스킬·공격형 필살기에 적용"]}

func reset() -> void:
	roan_remaining = 0.0
	roan_cooldown = 0.0
	lumi_cooldown = 0.0
	lumi_weapon = ""

func tick(delta: float) -> void:
	roan_remaining = maxf(0.0,roan_remaining-maxf(0.0,delta))
	roan_cooldown = maxf(0.0,roan_cooldown-maxf(0.0,delta))
	lumi_cooldown = maxf(0.0,lumi_cooldown-maxf(0.0,delta))

func precise_evade(character: String) -> bool:
	if character != "roan" or roan_cooldown > 0.0: return false
	roan_remaining = ROAN_DURATION
	roan_cooldown = ROAN_COOLDOWN
	return true

func weapon_switched(character: String, family: String) -> bool:
	if character != "lumi" or lumi_cooldown > 0.0 or not lumi_weapon.is_empty() or family not in PrototypeWeaponRewards.FAMILY_IDS: return false
	lumi_weapon = family
	lumi_cooldown = LUMI_COOLDOWN
	return true

func attack_multiplier(character: String) -> float:
	return ROAN_ATTACK if character == "roan" and roan_remaining > 0.0 else 1.0

func guarantees_critical(character: String, tags: PackedStringArray) -> bool:
	return character == "lumi" and not lumi_weapon.is_empty() and tags.has(lumi_weapon)

func snapshot() -> Dictionary:
	return {"roan_remaining":roan_remaining,"roan_cooldown":roan_cooldown,"lumi_cooldown":lumi_cooldown,"lumi_weapon":lumi_weapon}

func restore(state: Dictionary) -> void:
	reset()
	if state.is_empty(): return
	roan_remaining = float(state.roan_remaining)
	roan_cooldown = float(state.roan_cooldown)
	lumi_cooldown = float(state.lumi_cooldown)
	lumi_weapon = String(state.lumi_weapon)

func view(character: String) -> Dictionary:
	var result := profile(character)
	result["status"] = ("강화 중 %.1f초 · 재발동 %.1f초" % [roan_remaining,roan_cooldown] if roan_remaining > 0.0 else "재발동 %.1f초" % roan_cooldown if roan_cooldown > 0.0 else "정확한 회피로 발동") if character == "roan" else (PrototypeWeaponRewards.family_name(lumi_weapon)+" · 확정 치명타 대기" if not lumi_weapon.is_empty() else "재발동 %.1f초" % lumi_cooldown if lumi_cooldown > 0.0 else "무기 전환으로 발동")
	result.lines = result.lines.duplicate()
	if character == "lumi": result.lines.append("다음 발동까지 %.1f초 · 효과 중첩 없음" % lumi_cooldown)
	return result

static func valid_state(state: Variant, character: String) -> bool:
	if not state is Dictionary: return false
	if state.is_empty(): return true
	if state.size() != 4 or not state.get("lumi_weapon") is String: return false
	for key in ["roan_remaining","roan_cooldown","lumi_cooldown"]:
		var value: Variant = state.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0: return false
	if float(state.roan_remaining) > ROAN_DURATION or float(state.roan_cooldown) > ROAN_COOLDOWN or float(state.lumi_cooldown) > LUMI_COOLDOWN or float(state.roan_remaining) > float(state.roan_cooldown): return false
	if character == "roan": return state.lumi_weapon == "" and float(state.lumi_cooldown) == 0.0
	return float(state.roan_remaining) == 0.0 and float(state.roan_cooldown) == 0.0 and (state.lumi_weapon == "" or state.lumi_weapon in PrototypeWeaponRewards.FAMILY_IDS)
