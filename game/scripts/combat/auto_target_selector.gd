class_name AutoTargetSelector
extends Node2D

## 검과 활이 공유하는 자동 기본 공격 대상 선택기.
## 활 프로필에서는 사거리와 함께 화면 안 대상만 허용한다.

signal target_metrics_changed(metrics: Dictionary)

const RETARGET_INTERVAL_S := 0.10
const SWITCH_DISTANCE_RATIO := 0.80
const DEFAULT_ATTACK_RANGE_M := 1.6
const ATTACK_ORIGIN_LOCAL := Vector2(0.0, -38.0)

var current_target: PrototypeTarget
var attack_range_m: float = DEFAULT_ATTACK_RANGE_M
var screen_only: bool = false
var profile_name: String = "검"
var _retarget_remaining_s: float = 0.0
var _switch_count: int = 0
var _scan_count: int = 0
var _candidate_count: int = 0
var _rear_filtered_count: int = 0
var _range_filtered_count: int = 0
var _screen_filtered_count: int = 0
var _current_distance_m: float = 0.0
var _last_decision: String = "대상 탐색 대기"
var _last_facing: int = 1

@onready var player: PrototypePlayer = get_parent() as PrototypePlayer


func _ready() -> void:
	_retarget_remaining_s = 0.0
	_last_facing = player.facing_direction
	queue_redraw()


func _physics_process(delta: float) -> void:
	_retarget_remaining_s = maxf(0.0, _retarget_remaining_s - delta)
	var facing_changed := player.facing_direction != _last_facing
	_last_facing = player.facing_direction
	if facing_changed or not _is_current_target_valid():
		_scan_targets("즉시 재탐색")
		_retarget_remaining_s = RETARGET_INTERVAL_S
	elif _retarget_remaining_s <= 0.0:
		_scan_targets("주기 재탐색")
		_retarget_remaining_s = RETARGET_INTERVAL_S
	queue_redraw()


func force_scan() -> void:
	_scan_targets("초기 탐색")
	_retarget_remaining_s = RETARGET_INTERVAL_S


func set_target_profile(
	new_profile_name: String,
	new_attack_range_m: float,
	new_screen_only: bool
) -> void:
	profile_name = new_profile_name
	attack_range_m = maxf(0.1, new_attack_range_m)
	screen_only = new_screen_only
	_set_current_target(null, "%s 프로필 전환" % profile_name, false)
	force_scan()
	queue_redraw()


func reset_selection() -> void:
	_set_current_target(null, "초기화", false)
	_switch_count = 0
	_scan_count = 0
	_last_facing = player.facing_direction
	force_scan()


func _scan_targets(scan_reason: String) -> void:
	_scan_count += 1
	var origin := _attack_origin_global()
	var range_px := attack_range_m * PrototypePlayer.PIXELS_PER_METER
	var candidates: Array[PrototypeTarget] = []
	var candidate_distances: Dictionary = {}
	_rear_filtered_count = 0
	_range_filtered_count = 0
	_screen_filtered_count = 0

	for node in get_tree().get_nodes_in_group("targetable"):
		var target := node as PrototypeTarget
		if target == null or not target.is_targetable():
			continue
		if screen_only and not is_target_on_screen(target):
			_screen_filtered_count += 1
			continue
		var hit_point := target.closest_hit_point(origin)
		var offset := hit_point - origin
		if offset.x * float(player.facing_direction) <= 0.0:
			_rear_filtered_count += 1
			continue
		var distance_px := offset.length()
		if distance_px > range_px:
			_range_filtered_count += 1
			continue
		candidates.append(target)
		candidate_distances[target] = distance_px

	_candidate_count = candidates.size()
	var nearest: PrototypeTarget = null
	var nearest_distance_px := INF
	for candidate in candidates:
		var distance_px: float = float(candidate_distances[candidate])
		if distance_px < nearest_distance_px:
			nearest = candidate
			nearest_distance_px = distance_px

	if nearest == null:
		_set_current_target(null, "%s · 후보 없음" % scan_reason)
		_emit_metrics()
		return

	if current_target == null or not candidate_distances.has(current_target):
		_set_current_target(nearest, "%s · 최근접 지정" % scan_reason)
	elif nearest == current_target:
		_last_decision = "%s · 현재 대상 유지" % scan_reason
	else:
		var current_distance_px: float = float(candidate_distances[current_target])
		if nearest_distance_px <= current_distance_px * SWITCH_DISTANCE_RATIO:
			_set_current_target(nearest, "%s · 20%% 근접 전환" % scan_reason)
		else:
			_last_decision = "%s · 20%% 기준 유지" % scan_reason

	_update_current_distance()
	_emit_metrics()


func _is_current_target_valid() -> bool:
	if current_target == null:
		return true
	if not is_instance_valid(current_target) or not current_target.is_targetable():
		return false
	var origin := _attack_origin_global()
	var offset := current_target.closest_hit_point(origin) - origin
	if offset.x * float(player.facing_direction) <= 0.0:
		return false
	if screen_only and not is_target_on_screen(current_target):
		return false
	return offset.length() <= attack_range_m * PrototypePlayer.PIXELS_PER_METER


func is_target_on_screen(target: PrototypeTarget, margin_px: float = 20.0) -> bool:
	if not is_instance_valid(target):
		return false
	var screen_position := target.get_global_transform_with_canvas() * Vector2.ZERO
	var visible_rect := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-margin_px)
	return visible_rect.has_point(screen_position)


func _set_current_target(
	new_target: PrototypeTarget,
	reason: String,
	count_switch: bool = true
) -> void:
	if current_target == new_target:
		_last_decision = reason
		_update_current_distance()
		return
	if is_instance_valid(current_target):
		current_target.set_selected(false)
	current_target = new_target
	if is_instance_valid(current_target):
		current_target.set_selected(true)
	if count_switch:
		_switch_count += 1
	_last_decision = reason
	_update_current_distance()


func _update_current_distance() -> void:
	if not is_instance_valid(current_target):
		_current_distance_m = 0.0
		return
	_current_distance_m = (
		current_target.closest_hit_point(_attack_origin_global()).distance_to(_attack_origin_global())
		/ PrototypePlayer.PIXELS_PER_METER
	)


func _attack_origin_global() -> Vector2:
	return player.global_position + Vector2(
		ATTACK_ORIGIN_LOCAL.x * float(player.facing_direction),
		ATTACK_ORIGIN_LOCAL.y
	)


func _emit_metrics() -> void:
	target_metrics_changed.emit({
		"target_key": current_target.target_key if is_instance_valid(current_target) else "없음",
		"target_distance_m": _current_distance_m,
		"target_candidate_count": _candidate_count,
		"target_rear_filtered": _rear_filtered_count,
		"target_range_filtered": _range_filtered_count,
		"target_screen_filtered": _screen_filtered_count,
		"target_switch_count": _switch_count,
		"target_scan_count": _scan_count,
		"target_last_decision": _last_decision,
		"target_scan_remaining_s": _retarget_remaining_s,
		"target_attack_range_m": attack_range_m,
		"target_profile_name": profile_name,
		"target_screen_only": screen_only,
	})


func _draw() -> void:
	var center := ATTACK_ORIGIN_LOCAL
	var radius := attack_range_m * PrototypePlayer.PIXELS_PER_METER
	var start_angle := -PI * 0.5 if player.facing_direction > 0 else PI * 0.5
	var end_angle := PI * 0.5 if player.facing_direction > 0 else PI * 1.5
	draw_arc(center, radius, start_angle, end_angle, 40, Color("fff3b0", 0.34), 3.0, true)
	draw_circle(center, 6.0, Color("ffd166", 0.72))
