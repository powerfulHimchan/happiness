class_name PrototypeCombatLinks
extends RefCounted

## Learned ranks live in the growth ledger; only active, bounded windows are checkpointed here.
const STYLES := ["switch","evade","critical","hurt","potion","skill"]
const LABELS := ["전환 선봉","회피 집중","치명 여세","반격 결의","회복 결의","연속 호흡"]
const TRIGGERS := ["이 무기로 전환 성공","지상 회피 / 공중 대시 시작","이 무기의 기본·스킬 치명타 적중","적의 전투 피해 적용 (방벽 포함)","회복약 실제 소비","이 무기의 스킬 실제 적중"]
const DURATIONS := [3.0,3.0,2.0,3.0,4.0,2.0]
const BONUSES := [0.15,0.20,0.15,0.18,0.18,0.18]
const KINDS := ["basic","skill","basic","all","skill","basic"]
const SUPPORT_NAMES := ["전환의 여운","회피의 여운","치명의 여운","반격의 여운","회복의 여운","연속의 여운"]
static var CARDS: Array[Dictionary] = definitions()
var ranks: Dictionary = {}
var windows: Dictionary = {}

static func id_for(family: String, style: String) -> String:
	return family+"_link_"+style

static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		for index in STYLES.size():
			var kind: String = KINDS[index]
			var effect := "기본·스킬" if kind == "all" else "기본 공격" if kind == "basic" else "스킬"
			result.append({"id":id_for(family,STYLES[index]),"title":PrototypeWeaponRewards.family_name(family)+" · "+LABELS[index],"category":family,"lines":[TRIGGERS[index],"%.0f초간 %s 피해 +%d%%" % [DURATIONS[index],effect,roundi(BONUSES[index]*100)]],"requires":[family+"_power"],"max_rank":1,"tags":PrototypeWeaponMastery.TAGS[family].duplicate(),"link_style":STYLES[index],"ticket":841+result.size()})
	for index in STYLES.size():
		var alternatives: Array[String] = []
		for family in PrototypeWeaponRewards.FAMILY_IDS: alternatives.append(id_for(family,STYLES[index]))
		result.append({"id":"link_extend_"+STYLES[index],"title":SUPPORT_NAMES[index],"category":"common","lines":[LABELS[index]+" 지속시간 +1초","배운 무기 모두 · 다음 발동부터 적용"],"requires_any":alternatives,"max_rank":1,"tags":{"nature":0.75,"determination":0.75},"ticket":841+result.size()})
	return result

static func selected(source: Dictionary) -> Dictionary:
	var result := {}
	for card in CARDS:
		if int(source.get(card.id,0)) == 1: result[card.id] = 1
	return result

static func duration(style: String, learned: Dictionary) -> float:
	var index := STYLES.find(style)
	if index < 0: return 0.0
	return float(DURATIONS[index]) + (1.0 if learned.has("link_extend_"+style) else 0.0)

func reset() -> void:
	ranks.clear()
	windows.clear()

func learn(source: Dictionary) -> void:
	ranks = selected(source)
	for id in windows.keys():
		if not ranks.has(id): windows.erase(id)

func tick(delta: float) -> void:
	for id in windows.keys():
		var remaining := maxf(0.0,float(windows[id])-maxf(0.0,delta))
		if remaining <= 0.000001: windows.erase(id)
		else: windows[id] = remaining

func trigger(style: String, held: Dictionary, family: String = "") -> void:
	if style not in STYLES: return
	for weapon in held:
		if not family.is_empty() and weapon != family: continue
		var id := id_for(String(weapon),style)
		if ranks.has(id): windows[id] = duration(style,ranks)

func hit(tags: PackedStringArray, held: Dictionary) -> void:
	if tags.has("ultimate") or not (tags.has("basic") or tags.has("skill")): return
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		if not tags.has(family): continue
		if tags.has("critical"): trigger("critical",held,family)
		if tags.has("skill"): trigger("skill",held,family)
		return

static func bonus(learned: Dictionary, active: Dictionary, family: String, kind: String) -> float:
	if family not in PrototypeWeaponRewards.FAMILY_IDS or kind not in ["basic","skill"]: return 0.0
	var result := 0.0
	for index in STYLES.size():
		var id := id_for(family,STYLES[index])
		if learned.has(id) and float(active.get(id,0.0)) > 0.0 and (KINDS[index] == "all" or KINDS[index] == kind): result += float(BONUSES[index])
	return result

func multiplier(family: String, kind: String) -> float:
	# Concurrent links add with each other, then multiply existing attack/growth once.
	return 1.0 + bonus(ranks,windows,family,kind)

func snapshot() -> Dictionary:
	return windows.duplicate()

func restore(state: Dictionary, source: Dictionary) -> void:
	learn(source)
	windows = state.duplicate()

static func valid_state(state: Variant, source: Dictionary, held: Array) -> bool:
	if not state is Dictionary or state.size() > 12: return false
	var learned := selected(source)
	for id in state:
		if not id is String or not learned.has(id): return false
		var parts: PackedStringArray = id.split("_link_")
		if parts.size() != 2 or parts[0] not in held or parts[1] not in STYLES: return false
		var value: Variant = state[id]
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0 or float(value) > duration(parts[1],learned): return false
	return true

static func prerequisites(card: Dictionary, source: Dictionary) -> bool:
	for required in card.get("requires",[]):
		if not source.has(required): return false
	var alternatives: Array = card.get("requires_any",[])
	return alternatives.is_empty() or alternatives.any(func(id: String) -> bool: return source.has(id))
