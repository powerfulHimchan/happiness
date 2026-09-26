class_name EliteArmoredBoar
extends PrototypeTarget

## CP-302 갑옷 멧돼지 정예의 돌진, 충격파, 페이즈와 무기 약점을 관리한다.

enum State {
	IDLE,
	WARNING,
	CHARGING,
	SHOCKWAVE,
	STUNNED,
	RECOVERY,
	PHASE_TRANSITION,
	DEAD,
}

enum Pattern {
	NONE,
	CHARGE,
	SHOCKWAVE,
}

const SHOCKWAVE_SCENE := preload("res://scenes/combat/elite_shockwave.tscn")
const MAX_HEALTH := 180
const PHASE_TWO_HEALTH_RATIO := 0.50
const CHARGE_WARNING_PHASE_ONE_S := 0.75
const CHARGE_WARNING_PHASE_TWO_S := 0.50
const SHOCKWAVE_WARNING_PHASE_ONE_S := 0.90
const SHOCKWAVE_WARNING_PHASE_TWO_S := 0.65
const CHARGE_SPEED_PHASE_ONE_MPS := 8.5
const CHARGE_SPEED_PHASE_TWO_MPS := 11.0
const CHARGE_DAMAGE_PHASE_ONE := 18
const CHARGE_DAMAGE_PHASE_TWO := 22
const SHOCKWAVE_DAMAGE_PHASE_ONE := 12
const SHOCKWAVE_DAMAGE_PHASE_TWO := 14
const WALL_STUN_PHASE_ONE_S := 2.0
const WALL_STUN_PHASE_TWO_S := 1.5
const SWORD_ARMOR_MULTIPLIER := 0.60
const BOW_ARMOR_MULTIPLIER := 1.25
const SWORD_STUN_MULTIPLIER := 1.75
const LEFT_WALL_X := 120.0
const RIGHT_WALL_X := 4880.0
const CONTACT_RADIUS_PX := 86.0

@export var player_path: NodePath

var state: int = State.IDLE
var phase: int = 1
var current_pattern: int = Pattern.NONE
var last_pattern: int = Pattern.NONE
var pattern_history: Array[int] = []
var attack_count: int = 0
var charge_count: int = 0
var shockwave_count: int = 0
var hit_count: int = 0
var warning_count: int = 0
var last_damage_multiplier: float = 1.0
var last_adjusted_damage: int = 0
var last_enemy_log: String = "정예 행동 대기"
var last_event_msec: int = -1
var _state_elapsed_s: float = 0.0
var _attack_cooldown_s: float = 0.45
var _charge_direction: float = -1.0
var _charge_hit_consumed: bool = false
var _shockwave_sequence: int = 0
var _phase_two_second_wave_pending: bool = false

@onready var player: PrototypePlayer = get_node(player_path) as PrototypePlayer
@onready var warning_ring: Sprite2D = $WarningRing
@onready var warning_line: Line2D = $WarningLine
@onready var armor_marker: Polygon2D = $ArmorMarker


func _ready() -> void:
	super._ready()
	add_to_group("combat_enemy")
	add_to_group("elite_enemy")
	warning_ring.visible = false
	warning_line.visible = false
	_set_state(State.IDLE, "갑옷 멧돼지 등장 · 활 약점")


func _process(delta: float) -> void:
	super._process(delta)
	if not is_targetable():
		if state != State.DEAD:
			_set_state(State.DEAD, "갑옷 멧돼지 처치")
		return
	var scaled_delta := delta * enemy_time_scale()
	_state_elapsed_s += scaled_delta
	_attack_cooldown_s = maxf(0.0, _attack_cooldown_s - scaled_delta)
	match state:
		State.IDLE:
			_update_idle(scaled_delta)
		State.WARNING:
			_update_warning()
		State.CHARGING:
			_update_charge(scaled_delta)
		State.SHOCKWAVE:
			_update_shockwave()
		State.STUNNED:
			if _state_elapsed_s >= _wall_stun_duration():
				_begin_recovery("기절 종료 · 갑옷 복구")
		State.RECOVERY:
			if _state_elapsed_s >= (0.55 if phase == 2 else 0.75):
				_attack_cooldown_s = 0.25 if phase == 2 else 0.45
				_set_state(State.IDLE, "다음 패턴 준비")
		State.PHASE_TRANSITION:
			if _state_elapsed_s >= 0.75:
				_attack_cooldown_s = 0.20
				_set_state(State.IDLE, "2페이즈 · 패턴 가속")
	_update_warning_visual()
	_update_phase_visual()


func receive_damage(event: DamageEvent) -> int:
	if event == null:
		return DamageReceiver.Result.INVALID_EVENT
	var adjusted_event := _adjust_damage_event(event)
	var result := super.receive_damage(adjusted_event)
	if result != DamageReceiver.Result.APPLIED:
		return result
	if not is_targetable():
		_set_state(State.DEAD, "갑옷 멧돼지 처치")
		return result
	if phase == 1 and float(damage_receiver.health) / float(damage_receiver.max_health) <= PHASE_TWO_HEALTH_RATIO:
		phase = 2
		_phase_two_second_wave_pending = false
		_set_state(State.PHASE_TRANSITION, "체력 50% · 분노 2페이즈")
	return result


func reset_target() -> void:
	super.reset_target()
	state = State.IDLE
	phase = 1
	current_pattern = Pattern.NONE
	last_pattern = Pattern.NONE
	pattern_history.clear()
	attack_count = 0
	charge_count = 0
	shockwave_count = 0
	hit_count = 0
	warning_count = 0
	last_damage_multiplier = 1.0
	last_adjusted_damage = 0
	last_enemy_log = "정예 행동 대기"
	last_event_msec = Time.get_ticks_msec()
	_state_elapsed_s = 0.0
	_attack_cooldown_s = 0.45
	_charge_direction = -1.0
	_charge_hit_consumed = false
	_shockwave_sequence = 0
	_phase_two_second_wave_pending = false
	if warning_ring != null:
		warning_ring.visible = false
	if warning_line != null:
		warning_line.visible = false


func current_metrics() -> Dictionary:
	return {
		"enemy_key": target_key,
		"enemy_name": "갑옷 멧돼지",
		"enemy_state": state_name(),
		"enemy_warning": state == State.WARNING,
		"enemy_alive": is_targetable(),
		"enemy_attack_count": attack_count,
		"enemy_hit_count": hit_count,
		"enemy_warning_count": warning_count,
		"enemy_last_log": last_enemy_log,
		"enemy_event_msec": last_event_msec,
		"elite_phase": phase,
		"elite_pattern": pattern_name(current_pattern),
		"elite_last_pattern": pattern_name(last_pattern),
		"elite_weakness": "검 175%" if state == State.STUNNED else "활 125%",
		"elite_health": damage_receiver.health,
		"elite_max_health": damage_receiver.max_health,
		"elite_last_multiplier": last_damage_multiplier,
		"elite_last_adjusted_damage": last_adjusted_damage,
	}


func state_name() -> String:
	match state:
		State.IDLE:
			return "대기"
		State.WARNING:
			return "%s 경고" % pattern_name(current_pattern)
		State.CHARGING:
			return "돌진"
		State.SHOCKWAVE:
			return "충격파"
		State.STUNNED:
			return "벽 충돌 기절"
		State.RECOVERY:
			return "빈틈"
		State.PHASE_TRANSITION:
			return "분노 전환"
		State.DEAD:
			return "처치"
	return "알 수 없음"


func pattern_name(pattern: int) -> String:
	if pattern == Pattern.CHARGE:
		return "돌진"
	if pattern == Pattern.SHOCKWAVE:
		return "충격파"
	return "없음"


func _update_idle(delta: float) -> void:
	var horizontal_distance_m := absf(player.global_position.x - global_position.x) / PrototypePlayer.PIXELS_PER_METER
	if horizontal_distance_m > 6.0:
		position.x += signf(player.global_position.x - global_position.x) * (185.0 if phase == 2 else 140.0) * delta
	if _attack_cooldown_s <= 0.0 and horizontal_distance_m <= 14.0:
		_begin_next_pattern()


func _begin_next_pattern() -> void:
	current_pattern = Pattern.SHOCKWAVE if last_pattern == Pattern.CHARGE else Pattern.CHARGE
	last_pattern = current_pattern
	pattern_history.append(current_pattern)
	if pattern_history.size() > 8:
		pattern_history.pop_front()
	warning_count += 1
	if current_pattern == Pattern.CHARGE:
		_charge_direction = signf(player.global_position.x - global_position.x)
		if is_zero_approx(_charge_direction):
			_charge_direction = -1.0
		_set_state(State.WARNING, "돌진 경고 · %.2f초" % _charge_warning_duration())
	else:
		_set_state(State.WARNING, "충격파 경고 · %.2f초" % _shockwave_warning_duration())


func _update_warning() -> void:
	if current_pattern == Pattern.CHARGE:
		warning_line.points = PackedVector2Array([
			Vector2(0.0, -42.0),
			Vector2(_charge_direction * 1100.0, -42.0),
		])
		if _state_elapsed_s >= _charge_warning_duration():
			attack_count += 1
			charge_count += 1
			_charge_hit_consumed = false
			_set_state(State.CHARGING, "갑옷 멧돼지 돌진")
	else:
		if _state_elapsed_s >= _shockwave_warning_duration():
			attack_count += 1
			shockwave_count += 1
			_spawn_shockwaves()
			_phase_two_second_wave_pending = phase == 2
			_set_state(State.SHOCKWAVE, "지면 충격파 발동")


func _update_charge(delta: float) -> void:
	position.x += _charge_direction * _charge_speed_mps() * PrototypePlayer.PIXELS_PER_METER * delta
	_try_charge_damage()
	if position.x <= LEFT_WALL_X or position.x >= RIGHT_WALL_X:
		position.x = clampf(position.x, LEFT_WALL_X, RIGHT_WALL_X)
		_set_state(State.STUNNED, "벽 충돌 · %.1f초 검 약점" % _wall_stun_duration())


func _update_shockwave() -> void:
	if _phase_two_second_wave_pending and _state_elapsed_s >= 0.22:
		_phase_two_second_wave_pending = false
		_spawn_shockwaves()
		last_enemy_log = "2페이즈 추가 충격파"
		last_event_msec = Time.get_ticks_msec()
	if _state_elapsed_s >= (0.52 if phase == 2 else 0.34):
		_begin_recovery("충격파 후 빈틈")


func _begin_recovery(message: String) -> void:
	current_pattern = Pattern.NONE
	_set_state(State.RECOVERY, message)


func _set_state(new_state: int, message: String) -> void:
	state = new_state
	_state_elapsed_s = 0.0
	last_enemy_log = message
	last_event_msec = Time.get_ticks_msec()
	if warning_ring != null:
		warning_ring.visible = new_state == State.WARNING or new_state == State.PHASE_TRANSITION
	if warning_line != null:
		warning_line.visible = new_state == State.WARNING and current_pattern == Pattern.CHARGE


func _spawn_shockwaves() -> void:
	for direction in [-1.0, 1.0]:
		_shockwave_sequence += 1
		var wave := SHOCKWAVE_SCENE.instantiate() as EliteShockwave
		wave.configure(
			"armored_boar:%d:%d" % [attack_count, _shockwave_sequence],
			direction,
			_shockwave_damage(),
			7.8 if phase == 2 else 6.5
		)
		var wave_parent := get_tree().current_scene
		if wave_parent == null:
			wave_parent = get_tree().root
		wave_parent.add_child(wave)
		wave.global_position = global_position + Vector2(0.0, 2.0)


func _try_charge_damage() -> void:
	if _charge_hit_consumed or player == null or not player.can_continue_combat_action():
		return
	if global_position.distance_to(player.global_position + Vector2(0.0, -28.0)) > CONTACT_RADIUS_PX:
		return
	_charge_hit_consumed = true
	var was_evading := player.invincible
	var event := DamageEvent.new()
	event.event_id = StringName("armored_boar:%d:charge" % attack_count)
	event.attacker_id = &"armored_boar"
	event.attack_id = &"boar_charge"
	event.damage = _charge_damage()
	event.stagger_s = 0.24
	event.tags = PackedStringArray(["enemy", "elite", "charge"])
	event.source_position = global_position
	var result := player.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED:
		hit_count += 1
		last_enemy_log = "돌진 적중 · 피해 %d" % event.damage
	elif was_evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
		if ultimate != null:
			ultimate.register_precise_evade()
		last_enemy_log = "돌진 정확한 회피"


func _adjust_damage_event(event: DamageEvent) -> DamageEvent:
	var multiplier := 1.0
	if event.tags.has("sword"):
		multiplier = SWORD_STUN_MULTIPLIER if state == State.STUNNED else SWORD_ARMOR_MULTIPLIER
	elif event.tags.has("bow"):
		multiplier = 1.0 if state == State.STUNNED else BOW_ARMOR_MULTIPLIER
	last_damage_multiplier = multiplier
	last_adjusted_damage = maxi(1, int(round(float(event.damage) * multiplier)))
	var adjusted := DamageEvent.new()
	adjusted.event_id = event.event_id
	adjusted.attacker_id = event.attacker_id
	adjusted.attack_id = event.attack_id
	adjusted.damage = last_adjusted_damage
	adjusted.stagger_s = event.stagger_s
	adjusted.tags = event.tags.duplicate()
	adjusted.source_position = event.source_position
	return adjusted


func _update_warning_visual() -> void:
	if state != State.WARNING and state != State.PHASE_TRANSITION:
		return
	var pulse := 0.55 + sin(_state_elapsed_s * 20.0) * 0.30
	warning_ring.modulate.a = pulse
	if warning_line.visible:
		warning_line.modulate.a = pulse


func _update_phase_visual() -> void:
	if state == State.DEAD:
		armor_marker.color = Color("52636d")
	elif state == State.STUNNED:
		armor_marker.color = Color("ffd166")
	elif phase == 2:
		armor_marker.color = Color("f26b5e")
	else:
		armor_marker.color = Color("91b7c7")


func _charge_warning_duration() -> float:
	return CHARGE_WARNING_PHASE_TWO_S if phase == 2 else CHARGE_WARNING_PHASE_ONE_S


func _shockwave_warning_duration() -> float:
	return SHOCKWAVE_WARNING_PHASE_TWO_S if phase == 2 else SHOCKWAVE_WARNING_PHASE_ONE_S


func _charge_speed_mps() -> float:
	return CHARGE_SPEED_PHASE_TWO_MPS if phase == 2 else CHARGE_SPEED_PHASE_ONE_MPS


func _charge_damage() -> int:
	return CHARGE_DAMAGE_PHASE_TWO if phase == 2 else CHARGE_DAMAGE_PHASE_ONE


func _shockwave_damage() -> int:
	return SHOCKWAVE_DAMAGE_PHASE_TWO if phase == 2 else SHOCKWAVE_DAMAGE_PHASE_ONE


func _wall_stun_duration() -> float:
	return WALL_STUN_PHASE_TWO_S if phase == 2 else WALL_STUN_PHASE_ONE_S
