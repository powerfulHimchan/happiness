class_name PrototypeWeaponController
extends Node

## CP-204에서 검과 활을 즉시 바꿔 두 무기의 전투를 비교한다.
## 0.50초 전환 제한과 정식 전환 상태는 CP-205에서 추가한다.

signal combat_metrics_changed(metrics: Dictionary)

const SWORD_ID := "sword"
const BOW_ID := "bow"

var active_weapon_id: String = SWORD_ID

@onready var target_selector: AutoTargetSelector = $"../AutoTargetSelector"
@onready var sword_combat: SwordCombatController = $"../SwordCombatController"
@onready var bow_combat: BowCombatController = $"../BowCombatController"


func _ready() -> void:
	sword_combat.combat_metrics_changed.connect(_on_child_metrics.bind(SWORD_ID))
	bow_combat.combat_metrics_changed.connect(_on_child_metrics.bind(BOW_ID))
	_apply_active_weapon()


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


func toggle_test_weapon() -> void:
	active_weapon_id = BOW_ID if active_weapon_id == SWORD_ID else SWORD_ID
	_apply_active_weapon()


func reset_combat() -> void:
	active_weapon_id = SWORD_ID
	sword_combat.reset_combat()
	bow_combat.reset_combat()
	_apply_active_weapon()


func force_emit_metrics() -> void:
	_emit_active_metrics()


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
	metrics["active_weapon_id"] = active_weapon_id
	metrics["weapon_switch_label"] = "활 전환" if active_weapon_id == SWORD_ID else "검 전환"
	metrics["skill_1_button_label"] = "돌진" if active_weapon_id == SWORD_ID else "관통"
	metrics["skill_2_button_label"] = "회전" if active_weapon_id == SWORD_ID else "화살비"
	metrics["weapon_switch_mode"] = "즉시 테스트 전환"
