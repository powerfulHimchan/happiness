class_name PrototypeWeaponController
extends Node

## CP-205 검·활 전환 제한과 무기별 대기시간 보존을 관리한다.

signal combat_metrics_changed(metrics: Dictionary)

const SWORD_ID := "sword"
const BOW_ID := "bow"
const SWITCH_COOLDOWN_S := 0.50
const SWITCH_BUFFER_S := 0.20

var active_weapon_id: String = SWORD_ID
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


func reset_combat() -> void:
	active_weapon_id = SWORD_ID
	switch_count = 0
	blocked_switch_count = 0
	reserved_switch_count = 0
	last_switch_log = "전환 대기"
	_switch_cooldown_remaining_s = 0.0
	_switch_buffer_remaining_s = 0.0
	_switch_buffered = false
	sword_combat.reset_combat()
	bow_combat.reset_combat()
	_apply_active_weapon()


func force_emit_metrics() -> void:
	_emit_active_metrics()


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
	metrics["weapon_switch_label"] = (
		"전환 %.1f" % _switch_cooldown_remaining_s
		if _switch_cooldown_remaining_s > 0.0
		else "%s 전환" % _weapon_name(BOW_ID if active_weapon_id == SWORD_ID else SWORD_ID)
	)
	metrics["skill_1_button_label"] = "돌진" if active_weapon_id == SWORD_ID else "관통"
	metrics["skill_2_button_label"] = "회전" if active_weapon_id == SWORD_ID else "화살비"
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


func _weapon_name(weapon_id: String) -> String:
	return "검" if weapon_id == SWORD_ID else "활"
