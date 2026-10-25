class_name DamageEvent
extends RefCounted

## 공격 한 번의 특정 타격 시점을 표현하는 공통 피해 데이터.
## event_id가 같으면 같은 타격으로 간주해 한 대상에 중복 적용하지 않는다.

var event_id: StringName = &""
var attacker_id: StringName = &""
var attack_id: StringName = &""
var damage: int = 0
# Final outgoing value for per-hit telemetry; never changes a projectile's next hit.
var resolved_damage: int = -1
var resolved_event_id: StringName = &""
var resolved_base_damage: int = -1
var critical: bool = false
var stagger_s: float = 0.0
var tags: PackedStringArray = PackedStringArray()
var source_position: Vector2 = Vector2.ZERO


func resolution_is_current() -> bool:
	return resolved_damage >= 0 and resolved_event_id == event_id and resolved_base_damage == damage


func outgoing_damage() -> int:
	return resolved_damage if resolution_is_current() else damage


func copy_with_damage(amount: int) -> DamageEvent:
	var result := DamageEvent.new()
	result.event_id = event_id
	result.attacker_id = attacker_id
	result.attack_id = attack_id
	result.damage = amount
	result.stagger_s = stagger_s
	result.tags = tags.duplicate()
	result.source_position = source_position
	return result


func summary() -> String:
	return "%s/%s · 피해 %d · 경직 %.2fs · [%s]" % [
		String(attacker_id),
		String(attack_id),
		damage,
		stagger_s,
		", ".join(tags),
	]
