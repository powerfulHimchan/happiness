class_name DamageReceiver
extends Node

## 피해 적용, 동일 타격 중복 차단, 피격 후 무적과 사망을 한곳에서 관리한다.

enum Result {
	APPLIED,
	DUPLICATE_BLOCKED,
	INVULNERABLE_BLOCKED,
	DEAD_BLOCKED,
	INVALID_EVENT,
}

@export var max_health: int = 100
@export var post_hit_invulnerability_s: float = 0.50

var health: int = 100
var dead: bool = false
var applied_count: int = 0
var duplicate_blocked_count: int = 0
var invulnerable_blocked_count: int = 0
var dead_blocked_count: int = 0
var last_result: int = Result.INVALID_EVENT
var last_event_id: String = "없음"
var _post_hit_remaining_s: float = 0.0
var _processed_event_ids: Dictionary = {}


func _ready() -> void:
	reset()


func tick(delta: float) -> void:
	_post_hit_remaining_s = maxf(0.0, _post_hit_remaining_s - delta)


func try_receive(event: DamageEvent, external_invulnerable: bool = false) -> int:
	if event == null or String(event.event_id).is_empty() or event.damage <= 0:
		last_result = Result.INVALID_EVENT
		return last_result

	last_event_id = String(event.event_id)
	if _processed_event_ids.has(event.event_id):
		duplicate_blocked_count += 1
		last_result = Result.DUPLICATE_BLOCKED
		return last_result

	# 회피나 피격 무적으로 막힌 공격도 같은 타격 시점에 다시 들어오지 않게 소비한다.
	_processed_event_ids[event.event_id] = true
	if dead:
		dead_blocked_count += 1
		last_result = Result.DEAD_BLOCKED
		return last_result
	if external_invulnerable or is_post_hit_invulnerable():
		invulnerable_blocked_count += 1
		last_result = Result.INVULNERABLE_BLOCKED
		return last_result

	health = maxi(0, health - event.damage)
	applied_count += 1
	dead = health <= 0
	if not dead:
		_post_hit_remaining_s = post_hit_invulnerability_s
	last_result = Result.APPLIED
	return last_result


func apply_environmental_damage(amount: int, minimum_health: int = 0) -> int:
	if dead or amount <= 0:
		return 0
	var previous_health := health
	health = maxi(minimum_health, health - amount)
	dead = health <= 0
	return previous_health - health


func is_post_hit_invulnerable() -> bool:
	return _post_hit_remaining_s > 0.0


func post_hit_remaining_s() -> float:
	return _post_hit_remaining_s


func reset() -> void:
	health = max_health
	dead = false
	applied_count = 0
	duplicate_blocked_count = 0
	invulnerable_blocked_count = 0
	dead_blocked_count = 0
	last_result = Result.INVALID_EVENT
	last_event_id = "없음"
	_post_hit_remaining_s = 0.0
	_processed_event_ids.clear()


static func result_name(result: int) -> String:
	match result:
		Result.APPLIED:
			return "적용"
		Result.DUPLICATE_BLOCKED:
			return "중복 차단"
		Result.INVULNERABLE_BLOCKED:
			return "무적 차단"
		Result.DEAD_BLOCKED:
			return "사망 후 차단"
	return "잘못된 이벤트"
