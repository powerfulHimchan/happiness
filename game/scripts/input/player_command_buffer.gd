class_name PlayerCommandBuffer
extends RefCounted

## 액션 입력을 짧게 보관하고 우선순위 순서로 꺼낸다.
## 점프와 무기 전환의 누름 요청은 각각 가장 최근 한 개만 유지한다.

var _commands: Array[PlayerCommand] = []
var _next_sequence: int = 0


func submit(
	command_type: int,
	phase: int = PlayerCommand.Phase.PRESSED,
	pointer_id: int = -1,
	now_msec: int = -1
) -> PlayerCommand:
	var created_at := now_msec if now_msec >= 0 else Time.get_ticks_msec()
	if phase == PlayerCommand.Phase.PRESSED and _uses_single_buffer_slot(command_type):
		_remove_matching_pressed(command_type)

	var command := PlayerCommand.new(
		command_type,
		phase,
		created_at,
		pointer_id,
		_next_sequence
	)
	_next_sequence += 1
	_commands.append(command)
	return command


func pop_next(now_msec: int, blocked_types: Array[int] = []) -> PlayerCommand:
	purge_expired(now_msec)
	var best_index := -1
	for index in _commands.size():
		var candidate := _commands[index]
		if candidate.command_type in blocked_types:
			continue
		if best_index < 0 or _comes_before(candidate, _commands[best_index]):
			best_index = index

	if best_index < 0:
		return null
	return _commands.pop_at(best_index)


func purge_expired(now_msec: int) -> int:
	var removed := 0
	for index in range(_commands.size() - 1, -1, -1):
		if _commands[index].is_expired(now_msec):
			_commands.remove_at(index)
			removed += 1
	return removed


func pending_count() -> int:
	return _commands.size()


func clear() -> void:
	_commands.clear()


func _uses_single_buffer_slot(command_type: int) -> bool:
	return command_type == PlayerCommand.Type.JUMP \
		or command_type == PlayerCommand.Type.WEAPON_SWAP


func _remove_matching_pressed(command_type: int) -> void:
	for index in range(_commands.size() - 1, -1, -1):
		var command := _commands[index]
		if command.command_type == command_type \
			and command.phase == PlayerCommand.Phase.PRESSED:
			_commands.remove_at(index)


func _comes_before(left: PlayerCommand, right: PlayerCommand) -> bool:
	if left.priority() != right.priority():
		return left.priority() > right.priority()
	return left.sequence < right.sequence
