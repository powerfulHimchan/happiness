class_name DamageEvent
extends RefCounted

## 공격 한 번의 특정 타격 시점을 표현하는 공통 피해 데이터.
## event_id가 같으면 같은 타격으로 간주해 한 대상에 중복 적용하지 않는다.

var event_id: StringName = &""
var attacker_id: StringName = &""
var attack_id: StringName = &""
var damage: int = 0
var stagger_s: float = 0.0
var tags: PackedStringArray = PackedStringArray()
var source_position: Vector2 = Vector2.ZERO


func summary() -> String:
	return "%s/%s · 피해 %d · 경직 %.2fs · [%s]" % [
		String(attacker_id),
		String(attack_id),
		damage,
		stagger_s,
		", ".join(tags),
	]
