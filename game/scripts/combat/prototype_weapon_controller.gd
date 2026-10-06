class_name PrototypeWeaponController
extends Node

## CP-205 검·활 전환 제한과 무기별 대기시간 보존을 관리한다.

signal combat_metrics_changed(metrics: Dictionary)

const SWORD_ID := "sword"
const BOW_ID := "bow"
const SWITCH_COOLDOWN_S := 0.50
const SWITCH_BUFFER_S := 0.20
const CHECKPOINT_FIELDS := ["_basic_remaining_s", "_skill_1_cooldown_s", "_skill_2_cooldown_s", "basic_attack_count", "skill_hit_count", "total_damage"]

var active_weapon_id: String = SWORD_ID
var skills: Dictionary = PrototypeSkillRewards.defaults()
var equipment: Dictionary = {"sword": 0, "bow": 0}
var blueprints: Dictionary = {"sword": "", "bow": ""}
var unlocked_blueprints: Dictionary = {}
var switch_count: int = 0
var blocked_switch_count: int = 0
var reserved_switch_count: int = 0
var last_switch_log: String = "전환 대기"
var _switch_cooldown_remaining_s: float = 0.0
var _switch_buffer_remaining_s: float = 0.0
var _switch_buffered: bool = false

@onready var player: PrototypePlayer = get_parent() as PrototypePlayer
@onready var target_selector: AutoTargetSelector = $"../AutoTargetSelector"
@onready var sword_combat: SwordCombatController = $"../SwordCombatController"
@onready var bow_combat: BowCombatController = $"../BowCombatController"


func _ready() -> void:
	sword_combat.combat_metrics_changed.connect(_on_child_metrics.bind(SWORD_ID))
	bow_combat.combat_metrics_changed.connect(_on_child_metrics.bind(BOW_ID))
	_apply_active_weapon()


func _physics_process(delta: float) -> void:
	_switch_cooldown_remaining_s = maxf(0.0, _switch_cooldown_remaining_s - delta)
	if _switch_buffered:
		_switch_buffer_remaining_s = maxf(0.0, _switch_buffer_remaining_s - delta)
		if _switch_cooldown_remaining_s <= 0.0 and player.can_switch_weapon():
			_perform_switch("예약 실행")
		elif _switch_buffer_remaining_s <= 0.0:
			_switch_buffered = false
			last_switch_log = "전환 예약 만료"
	_emit_active_metrics()


func request_skill_1() -> void:
	if active_weapon_id == SWORD_ID:
		sword_combat.request_skill_1()
	else:
		bow_combat.request_skill_1()


func request_skill_2() -> void:
	if active_weapon_id == SWORD_ID:
		sword_combat.request_skill_2()
	else:
		bow_combat.request_skill_2()


func request_weapon_switch() -> void:
	if _switch_cooldown_remaining_s > 0.0:
		blocked_switch_count += 1
		last_switch_log = "연속 전환 차단 · %.2fs 남음" % _switch_cooldown_remaining_s
		_emit_active_metrics()
		return
	if player.can_switch_weapon():
		_perform_switch("즉시 실행")
		return
	_switch_buffered = true
	_switch_buffer_remaining_s = SWITCH_BUFFER_S
	reserved_switch_count += 1
	last_switch_log = "행동 종료까지 전환 예약 · %.2fs" % SWITCH_BUFFER_S
	_emit_active_metrics()


func prepare_next_stage() -> void:
	_switch_buffered = false
	_switch_buffer_remaining_s = 0.0
	sword_combat.prepare_next_stage()
	bow_combat.prepare_next_stage()
	_emit_active_metrics()


func checkpoint_snapshot() -> Dictionary:
	var state := {"active": active_weapon_id, "equipment": equipment.duplicate(), "blueprints": blueprints.duplicate(), "skills": skills.duplicate(true)}
	for weapon_id in [SWORD_ID, BOW_ID]:
		var combat: Node = sword_combat if weapon_id == SWORD_ID else bow_combat
		var values := {}
		for field in CHECKPOINT_FIELDS:
			values[field] = combat.get(field)
		state[weapon_id] = values
	return state


func restore_checkpoint(state: Dictionary) -> void:
	reset_combat()
	set_loadout(state.get("equipment", {"sword": 0, "bow": 0}), state.get("blueprints", {"sword": "", "bow": ""}))
	set_skill_loadout(state.get("skills", PrototypeSkillRewards.defaults()))
	active_weapon_id = String(state.active)
	for weapon_id in [SWORD_ID, BOW_ID]:
		var combat: Node = sword_combat if weapon_id == SWORD_ID else bow_combat
		for field in CHECKPOINT_FIELDS:
			combat.set(field, state[weapon_id][field])
	_apply_active_weapon()


func reset_combat(starting_weapon: String = SWORD_ID) -> bool:
	if starting_weapon not in [SWORD_ID, BOW_ID]:
		return false
	active_weapon_id = starting_weapon
	blueprints = {"sword": "", "bow": ""}
	set_equipment({"sword": 0, "bow": 0})
	switch_count = 0
	blocked_switch_count = 0
	reserved_switch_count = 0
	last_switch_log = "전환 대기"
	_switch_cooldown_remaining_s = 0.0
	_switch_buffer_remaining_s = 0.0
	_switch_buffered = false
	set_skill_loadout(PrototypeSkillRewards.defaults())
	sword_combat.reset_combat()
	bow_combat.reset_combat()
	_apply_active_weapon()
	return true


func force_emit_metrics() -> void:
	_emit_active_metrics()


func set_equipment(value: Dictionary) -> bool:
	if not PrototypeWeaponRewards.valid_equipment(value):
		return false
	var designs := blueprints.duplicate()
	for id in designs:
		if int(value[id]) == 0:
			designs[id] = ""
	return set_loadout(value, designs)


func set_loadout(value: Dictionary, designs: Dictionary) -> bool:
	if not PrototypeWeaponRewards.valid_equipment(value) or not PrototypeWeaponRewards.valid_blueprints(designs, value):
		return false
	equipment = {"sword": int(value.sword), "bow": int(value.bow)}
	blueprints = designs.duplicate()
	player.weapon_equipment = equipment.duplicate()
	player.weapon_blueprints = blueprints.duplicate()
	_emit_active_metrics()
	return true


func equip_reward(id: String, grade: int) -> bool:
	var design := id if PrototypeWeaponRewards.BLUEPRINTS.has(id) else ""
	if not design.is_empty() and unlocked_blueprints.get(design, false) != true:
		return false
	var weapon: String = PrototypeWeaponRewards.BLUEPRINTS[design].weapon if not design.is_empty() else id
	if weapon not in equipment or grade < 1 or grade > 2 or grade < int(equipment[weapon]) or (grade == int(equipment[weapon]) and design == blueprints[weapon]):
		return false
	var next := equipment.duplicate()
	var designs := blueprints.duplicate()
	next[weapon] = grade
	designs[weapon] = design
	return set_loadout(next, designs)


func _perform_switch(reason: String) -> void:
	var previous_weapon := active_weapon_id
	active_weapon_id = BOW_ID if active_weapon_id == SWORD_ID else SWORD_ID
	_switch_cooldown_remaining_s = SWITCH_COOLDOWN_S
	_switch_buffer_remaining_s = 0.0
	_switch_buffered = false
	switch_count += 1
	last_switch_log = "%s → %s · %s" % [
		_weapon_name(previous_weapon),
		_weapon_name(active_weapon_id),
		reason,
	]
	_apply_active_weapon()


func _apply_active_weapon() -> void:
	var sword_active := active_weapon_id == SWORD_ID
	sword_combat.set_active(sword_active)
	bow_combat.set_active(not sword_active)
	if sword_active:
		target_selector.set_target_profile("검", sword_combat.weapon.attack_range_m, false)
	else:
		target_selector.set_target_profile("활", bow_combat.weapon.attack_range_m, true)
	_emit_active_metrics()


func _on_child_metrics(metrics: Dictionary, weapon_id: String) -> void:
	if weapon_id != active_weapon_id:
		return
	var enriched := metrics.duplicate()
	_enrich_metrics(enriched)
	combat_metrics_changed.emit(enriched)


func _emit_active_metrics() -> void:
	var metrics := (
		sword_combat.current_metrics()
		if active_weapon_id == SWORD_ID
		else bow_combat.current_metrics()
	)
	_enrich_metrics(metrics)
	combat_metrics_changed.emit(metrics)


func _enrich_metrics(metrics: Dictionary) -> void:
	var sword_metrics := sword_combat.current_metrics()
	var bow_metrics := bow_combat.current_metrics()
	metrics["active_weapon_id"] = active_weapon_id
	var own := PrototypeWeaponRewards.profile(active_weapon_id, int(equipment[active_weapon_id]), String(blueprints[active_weapon_id]))
	var other := BOW_ID if active_weapon_id == SWORD_ID else SWORD_ID
	var backup := PrototypeWeaponRewards.profile(other, int(equipment[other]), String(blueprints[other]))
	metrics["weapon_name"] = own.name
	metrics["weapon_equipment"] = equipment.duplicate()
	metrics["weapon_blueprints"] = blueprints.duplicate()
	metrics["weapon_skills"] = skills.duplicate(true)
	metrics["weapon_backup_name"] = backup.name
	metrics["weapon_equipment_summary"] = "%s · %s" % [PrototypeWeaponRewards.profile(SWORD_ID, int(equipment.sword), blueprints.sword).name, PrototypeWeaponRewards.profile(BOW_ID, int(equipment.bow), blueprints.bow).name]
	var effect_percent := float(backup.unique) * PrototypeWeaponRewards.BACKUP_RATIO * 100
	metrics["weapon_backup_effect"] = "보조: %s 피해 +%s%%" % ["스킬" if other == SWORD_ID else "기본", str(roundi(effect_percent)) if blueprints[other].is_empty() else "%.1f" % effect_percent]
	metrics["weapon_switch_label"] = (
		"전환 %.1f" % _switch_cooldown_remaining_s
		if _switch_cooldown_remaining_s > 0.0
		else "%s 전환" % _weapon_name(BOW_ID if active_weapon_id == SWORD_ID else SWORD_ID)
	)
	metrics["skill_1_button_label"] = PrototypeSkillRewards.LABELS[skills[active_weapon_id][0]]
	metrics["skill_2_button_label"] = PrototypeSkillRewards.LABELS[skills[active_weapon_id][1]]
	metrics["weapon_switch_mode"] = "0.50초 연속 제한"
	metrics["weapon_switch_remaining_s"] = _switch_cooldown_remaining_s
	metrics["weapon_switch_buffered"] = _switch_buffered
	metrics["weapon_switch_buffer_remaining_s"] = _switch_buffer_remaining_s
	metrics["weapon_switch_count"] = switch_count
	metrics["weapon_switch_blocked_count"] = blocked_switch_count
	metrics["weapon_switch_reserved_count"] = reserved_switch_count
	metrics["weapon_switch_last_log"] = last_switch_log
	metrics["sword_basic_remaining_s"] = sword_metrics.get("basic_attack_remaining_s", 0.0)
	metrics["bow_basic_remaining_s"] = bow_metrics.get("basic_attack_remaining_s", 0.0)
	metrics["sword_skill_1_cooldown_s"] = sword_metrics.get("skill_1_cooldown_s", 0.0)
	metrics["sword_skill_2_cooldown_s"] = sword_metrics.get("skill_2_cooldown_s", 0.0)
	metrics["bow_skill_1_cooldown_s"] = bow_metrics.get("skill_1_cooldown_s", 0.0)
	metrics["bow_skill_2_cooldown_s"] = bow_metrics.get("skill_2_cooldown_s", 0.0)
	var sword_hits := int(sword_metrics.get("basic_attack_count", 0)) \
		+ int(sword_metrics.get("skill_hit_count", 0))
	var bow_hits := int(bow_metrics.get("basic_attack_count", 0)) \
		+ int(bow_metrics.get("skill_hit_count", 0))
	var total_hits := sword_hits + bow_hits
	metrics["sword_basic_attack_count"] = int(sword_metrics.get("basic_attack_count", 0))
	metrics["sword_skill_hit_count"] = int(sword_metrics.get("skill_hit_count", 0))
	metrics["sword_total_hits"] = sword_hits
	metrics["sword_total_damage"] = int(sword_metrics.get("combat_total_damage", 0))
	metrics["bow_basic_attack_count"] = int(bow_metrics.get("basic_attack_count", 0))
	metrics["bow_skill_hit_count"] = int(bow_metrics.get("skill_hit_count", 0))
	metrics["bow_total_hits"] = bow_hits
	metrics["bow_total_damage"] = int(bow_metrics.get("combat_total_damage", 0))
	metrics["weapon_usage_total_hits"] = total_hits
	metrics["sword_usage_ratio"] = float(sword_hits) / float(total_hits) if total_hits > 0 else 0.0
	metrics["bow_usage_ratio"] = float(bow_hits) / float(total_hits) if total_hits > 0 else 0.0


func _weapon_name(weapon_id: String) -> String:
	return "검" if weapon_id == SWORD_ID else "활"


func set_skill_loadout(value: Dictionary) -> bool:
	if not PrototypeSkillRewards.valid_loadout(value):
		return false
	skills = value.duplicate(true)
	for weapon_id in [SWORD_ID, BOW_ID]:
		var combat: Node = sword_combat if weapon_id == SWORD_ID else bow_combat
		combat.set("skill_1", PrototypeSkillRewards.SKILLS[skills[weapon_id][0]])
		combat.set("skill_2", PrototypeSkillRewards.SKILLS[skills[weapon_id][1]])
	_emit_active_metrics()
	return true


func replace_skill(id: String, slot: int) -> bool:
	var weapon := PrototypeSkillRewards.weapon_for(id)
	if weapon.is_empty() or slot not in [0, 1] or id in skills[weapon]:
		return false
	var next := skills.duplicate(true)
	next[weapon][slot] = id
	if not set_skill_loadout(next):
		return false
	var combat: Node = sword_combat if weapon == SWORD_ID else bow_combat
	var field := "_skill_%d_cooldown_s" % (slot + 1)
	combat.set(field, maxf(float(combat.get(field)), PrototypeSkillRewards.SKILLS[id].cooldown_s))
	_emit_active_metrics()
	return true
