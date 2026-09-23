class_name PlayerCommand
extends RefCounted

## UI와 게임 로직 사이에서 사용하는 단일 입력 요청이다.
## 이동은 연속 값이므로 별도로 전달하고, 액션만 명령 큐에 넣는다.

enum Type {
	EVADE,
	ULTIMATE,
	SKILL_1,
	SKILL_2,
	JUMP,
	WEAPON_SWAP,
	BASIC_ATTACK,
}

enum Phase {
	PRESSED,
	HELD,
	RELEASED,
}

const PRIORITY_BY_TYPE := {
	Type.EVADE: 700,
	Type.ULTIMATE: 600,
	Type.SKILL_1: 500,
	Type.SKILL_2: 500,
	Type.JUMP: 400,
	Type.WEAPON_SWAP: 300,
	Type.BASIC_ATTACK: 200,
}

const BUFFER_MSEC_BY_TYPE := {
	Type.EVADE: 100,
	Type.ULTIMATE: 100,
	Type.SKILL_1: 100,
	Type.SKILL_2: 100,
	Type.JUMP: 120,
	Type.WEAPON_SWAP: 200,
	Type.BASIC_ATTACK: 50,
}

var command_type: int
var phase: int
var created_at_msec: int
var expires_at_msec: int
var source_pointer_id: int
var sequence: int


func _init(
	type_value: int,
	phase_value: int,
	created_at_value: int,
	pointer_id: int,
	sequence_value: int
) -> void:
	command_type = type_value
	phase = phase_value
	created_at_msec = created_at_value
	source_pointer_id = pointer_id
	sequence = sequence_value
	expires_at_msec = created_at_value + int(BUFFER_MSEC_BY_TYPE.get(type_value, 80))


func priority() -> int:
	return int(PRIORITY_BY_TYPE.get(command_type, 0))


func is_expired(now_msec: int) -> bool:
	return now_msec > expires_at_msec


func display_name() -> String:
	match command_type:
		Type.EVADE:
			return "회피"
		Type.ULTIMATE:
			return "필살기"
		Type.SKILL_1:
			return "스킬 1"
		Type.SKILL_2:
			return "스킬 2"
		Type.JUMP:
			return "점프"
		Type.WEAPON_SWAP:
			return "무기 전환"
		Type.BASIC_ATTACK:
			return "자동 공격"
	return "알 수 없음"


func phase_name() -> String:
	match phase:
		Phase.PRESSED:
			return "누름"
		Phase.HELD:
			return "유지"
		Phase.RELEASED:
			return "뗌"
	return "알 수 없음"
