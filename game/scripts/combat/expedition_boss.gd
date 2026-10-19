class_name ExpeditionBoss
extends EliteArmoredBoar

## GP-325: 원정 4의 보스 전용 추격 공격. 기존 빈틈 뒤 새 경고를 전부 기다린다.
var expedition_patterns: bool = false:
	set(value):
		expedition_patterns = value
		if not value:
			_follow_up_pending = false
			_follow_up_active = false
var _follow_up_pending := false
var _follow_up_active := false


func reset_target() -> void:
	_follow_up_pending = false
	_follow_up_active = false
	super.reset_target()


func _process(delta: float) -> void:
	if enemy_time_scale() <= 0.0: return
	var was_recovering := state == State.RECOVERY
	super._process(delta)
	if was_recovering and state == State.IDLE:
		if expedition_patterns and _follow_up_pending and is_targetable():
			_follow_up_pending = false
			_follow_up_active = true
			current_pattern = last_pattern
			_begin_pattern_warning()
		else:
			_follow_up_active = false


func _set_state(new_state: int, message: String) -> void:
	if new_state in [State.DEAD, State.PHASE_TRANSITION]:
		_follow_up_pending = false
		_follow_up_active = false
	if new_state == State.WARNING:
		# Only projectile/beam patterns (3+) repeat, once per attack group.
		if not _follow_up_active: _follow_up_pending = expedition_patterns and current_pattern >= 3
		if _follow_up_active: message = "원정 4 재공격 · " + message
	super._set_state(new_state, message)


func _begin_pattern_warning() -> void:
	pass # Each boss captures its own aim and draws its actual attack trajectories.


func current_metrics() -> Dictionary:
	var metrics := super.current_metrics()
	metrics.boss_expedition_patterns = expedition_patterns
	metrics.boss_follow_up = _follow_up_active
	return metrics
