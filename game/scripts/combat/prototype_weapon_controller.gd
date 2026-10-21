class_name PrototypeWeaponController
extends Node

## CP-205 두 휴대 무기의 전환 제한과 계열별 대기시간 보존을 관리한다.

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
@onready var fist_combat: FistCombatController = $"../FistCombatController"
@onready var bow_combat: BowCombatController = $"../BowCombatController"


@onready var staff_combat: StaffCombatController = $"../StaffCombatController"
@onready var polearm_combat: PolearmCombatController = $"../PolearmCombatController"
@onready var shield_combat: ShieldCombatController = $"../ShieldCombatController"


func _ready() -> void:
	sword_combat.combat_metrics_changed.connect(_on_child_metrics.bind(SWORD_ID))
	bow_combat.combat_metrics_changed.connect(_on_child_metrics.bind(BOW_ID))
	fist_combat.combat_metrics_changed.connect(_on_child_metrics.bind("fist"))
	staff_combat.combat_metrics_changed.connect(_on_child_metrics.bind("staff"))
	polearm_combat.combat_metrics_changed.connect(_on_child_metrics.bind("polearm"))
	shield_combat.combat_metrics_changed.connect(_on_child_metrics.bind("shield"))
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
	combat_for(active_weapon_id).request_skill_1()

func request_skill_2() -> void:
	combat_for(active_weapon_id).request_skill_2()

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
	fist_combat.prepare_next_stage()
	staff_combat.prepare_next_stage()
	polearm_combat.prepare_next_stage()
	shield_combat.prepare_next_stage()
	_emit_active_metrics()


func checkpoint_snapshot() -> Dictionary:
	var state := {"active": active_weapon_id, "equipment": equipment.duplicate(), "blueprints": blueprints.duplicate(), "skills": skills.duplicate(true)}
	for weapon_id in equipment:
		var combat: Node = combat_for(weapon_id)
		var values := {}
		for field in CHECKPOINT_FIELDS:
			values[field] = combat.get(field)
		state[weapon_id] = values
	return state


func restore_checkpoint(state: Dictionary) -> void:
	var saved_equipment: Dictionary = state.get("equipment", {"sword": 0, "bow": 0})
	var other: String = saved_equipment.keys().filter(func(id: String) -> bool: return id != state.active)[0]
	reset_combat(String(state.active), other)
	set_loadout(saved_equipment, state.get("blueprints", {"sword": "", "bow": ""}))
	set_skill_loadout(state.get("skills", PrototypeSkillRewards.defaults(equipment.keys())))
	active_weapon_id = String(state.active)
	for weapon_id in equipment:
		var combat: Node = combat_for(weapon_id)
		for field in CHECKPOINT_FIELDS:
			combat.set(field, state[weapon_id][field])
	_apply_active_weapon()


func reset_combat(starting_weapon: String = SWORD_ID, backup: String = "") -> bool:
	if backup.is_empty(): backup = BOW_ID if starting_weapon != BOW_ID else SWORD_ID
	if starting_weapon not in PrototypeWeaponRewards.FAMILY_IDS or backup not in PrototypeWeaponRewards.FAMILY_IDS or backup == starting_weapon: return false
	active_weapon_id = starting_weapon
	equipment = {}
	blueprints = {}
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		if family in [starting_weapon, backup]:
			equipment[family] = 0
			blueprints[family] = ""
	player.weapon_equipment = equipment.duplicate()
	player.weapon_blueprints = blueprints.duplicate()
	switch_count = 0
	blocked_switch_count = 0
	reserved_switch_count = 0
	last_switch_log = "전환 대기"
	_switch_cooldown_remaining_s = 0.0
	_switch_buffer_remaining_s = 0.0
	_switch_buffered = false
	set_skill_loadout(PrototypeSkillRewards.defaults(equipment.keys()))
	for family in PrototypeWeaponRewards.FAMILY_IDS: combat_for(family).reset_combat()
	_apply_active_weapon()
	return true


func combat_for(id: String) -> Node:
	return sword_combat if id == SWORD_ID else bow_combat if id == BOW_ID else fist_combat if id == "fist" else staff_combat if id == "staff" else polearm_combat if id == "polearm" else shield_combat


func backup_weapon() -> String:
	for id in equipment:
		if id != active_weapon_id: return String(id)
	return ""


func force_emit_metrics() -> void:
	_emit_active_metrics()


func set_equipment(value: Dictionary) -> bool:
	if not PrototypeWeaponRewards.valid_equipment(value) or value.keys().any(func(id: String) -> bool: return id not in equipment):
		return false
	var designs := blueprints.duplicate()
	for id in designs:
		if int(value[id]) == 0:
			designs[id] = ""
	return set_loadout(value, designs)


func set_loadout(value: Dictionary, designs: Dictionary) -> bool:
	if not PrototypeWeaponRewards.valid_equipment(value) or not PrototypeWeaponRewards.valid_blueprints(designs, value) or value.keys().any(func(id: String) -> bool: return id not in equipment):
		return false
	equipment = {}
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		if value.has(family): equipment[family] = int(value[family])
	blueprints = designs.duplicate()
	player.weapon_equipment = equipment.duplicate()
	player.weapon_blueprints = blueprints.duplicate()
	_emit_active_metrics()
	return true


func equip_reward(id: String, grade: int) -> bool:
	var design := id if not PrototypeWeaponRewards.design_profile(id).is_empty() else ""
	if not PrototypeWeaponRewards.design_available(design, unlocked_blueprints):
		return false
	var weapon: String = PrototypeWeaponRewards.design_profile(design).weapon if not design.is_empty() else id
	if weapon not in equipment or grade < 1 or grade > 2 or grade < int(equipment[weapon]) or (grade == int(equipment[weapon]) and design == blueprints[weapon]):
		return false
	var next := equipment.duplicate()
	var designs := blueprints.duplicate()
	next[weapon] = grade
	designs[weapon] = design
	return set_loadout(next, designs)


func _perform_switch(reason: String) -> void:
	var previous_weapon := active_weapon_id
	active_weapon_id = backup_weapon()
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
	for family in PrototypeWeaponRewards.FAMILY_IDS: combat_for(family).set_active(family == active_weapon_id)
	var combat: Node = combat_for(active_weapon_id)
	target_selector.set_target_profile(_weapon_name(active_weapon_id), combat.weapon.attack_range_m, active_weapon_id in [BOW_ID, "staff"])
	_emit_active_metrics()


func _on_child_metrics(metrics: Dictionary, weapon_id: String) -> void:
	if weapon_id != active_weapon_id:
		return
	var enriched := metrics.duplicate()
	_enrich_metrics(enriched)
	combat_metrics_changed.emit(enriched)


func _emit_active_metrics() -> void:
	var metrics: Dictionary = combat_for(active_weapon_id).current_metrics()
	_enrich_metrics(metrics)
	combat_metrics_changed.emit(metrics)


func _enrich_metrics(metrics: Dictionary) -> void:
	metrics["active_weapon_id"] = active_weapon_id
	var own := PrototypeWeaponRewards.profile(active_weapon_id, int(equipment[active_weapon_id]), String(blueprints[active_weapon_id]))
	var other := backup_weapon()
	var backup := PrototypeWeaponRewards.profile(other, int(equipment[other]), String(blueprints[other]))
	metrics["weapon_name"] = own.name
	metrics["weapon_equipment"] = equipment.duplicate()
	metrics["weapon_blueprints"] = blueprints.duplicate()
	metrics["weapon_skills"] = skills.duplicate(true)
	metrics["weapon_backup_name"] = backup.name
	metrics["weapon_equipment_summary"] = "%s · %s" % [own.name, backup.name]
	var effect_percent := float(backup.unique) * PrototypeWeaponRewards.BACKUP_RATIO * 100
	metrics["weapon_backup_effect"] = "보조: %s 피해 +%s%%" % ["스킬" if backup.kind == "skill" else "기본", str(roundi(effect_percent)) if blueprints[other].is_empty() else "%.1f" % effect_percent]
	metrics["weapon_switch_label"] = (
		"전환 %.1f" % _switch_cooldown_remaining_s
		if _switch_cooldown_remaining_s > 0.0
		else "%s 전환" % _weapon_name(backup_weapon())
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
	var total_hits := 0
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		var source: Dictionary = combat_for(family).current_metrics()
		var hits := int(source.get("basic_attack_count",0)) + int(source.get("skill_hit_count",0))
		total_hits += hits
		metrics[family + "_total_hits"] = hits
		metrics[family + "_total_damage"] = int(source.get("combat_total_damage",0))
		metrics[family + "_basic_attack_count"] = int(source.get("basic_attack_count",0))
		metrics[family + "_skill_hit_count"] = int(source.get("skill_hit_count",0))
		for field in ["basic_remaining_s", "skill_1_cooldown_s", "skill_2_cooldown_s"]:
			metrics[family + "_" + field] = source.get("basic_attack_remaining_s" if field == "basic_remaining_s" else field,0.0)
	metrics["weapon_usage_total_hits"] = total_hits
	for family in PrototypeWeaponRewards.FAMILY_IDS:
		metrics[family + "_usage_ratio"] = float(metrics[family + "_total_hits"]) / total_hits if total_hits > 0 else 0.0



func _weapon_name(weapon_id: String) -> String:
	return PrototypeWeaponRewards.family_name(weapon_id)


func set_skill_loadout(value: Dictionary) -> bool:
	if not PrototypeSkillRewards.valid_loadout(value) or value.keys().any(func(id: String) -> bool: return id not in equipment):
		return false
	skills = value.duplicate(true)
	for weapon_id in equipment:
		var combat: Node = combat_for(weapon_id)
		combat.set("skill_1", PrototypeSkillRewards.SKILLS[skills[weapon_id][0]])
		combat.set("skill_2", PrototypeSkillRewards.SKILLS[skills[weapon_id][1]])
	_emit_active_metrics()
	return true


func replace_skill(id: String, slot: int) -> bool:
	var weapon := PrototypeSkillRewards.weapon_for(id)
	if weapon.is_empty() or weapon not in skills or slot not in [0, 1] or id in skills[weapon]:
		return false
	var next := skills.duplicate(true)
	next[weapon][slot] = id
	if not set_skill_loadout(next):
		return false
	var combat: Node = combat_for(weapon)
	var field := "_skill_%d_cooldown_s" % (slot + 1)
	combat.set(field, maxf(float(combat.get(field)), PrototypeSkillRewards.SKILLS[id].cooldown_s))
	_emit_active_metrics()
	return true
