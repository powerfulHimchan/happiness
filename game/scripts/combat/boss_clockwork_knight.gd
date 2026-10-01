class_name BossClockworkKnight
extends EliteArmoredBoar

## GP-109: 웃는 태엽 기사. 좁은 평지에서 돌진·충격파·탄막을 순환한다.
const BOSS_NAME := "웃는 태엽 기사"
const BOSS_HEALTH := 480
const VOLLEY_PATTERN := 3
const ARENA_LEFT_X := 3920.0
const ARENA_RIGHT_X := 4880.0
const SEED_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
var volley_count: int = 0
var _volley_aim := Vector2.LEFT

func _ready() -> void:
	super._ready()
	add_to_group("boss_enemy")

func reset_target() -> void:
	super.reset_target()
	volley_count = 0
	_volley_aim = Vector2.LEFT

func _set_state(new_state: int, message: String) -> void:
	super._set_state(new_state, message.replace("갑옷 멧돼지", BOSS_NAME))
	_refresh_status()

func _refresh_status() -> void:
	super._refresh_status()
	if status_label != null and damage_receiver != null:
		status_label.text = "%s · %d페이즈\n%d/%d · %s" % [BOSS_NAME, phase, damage_receiver.health, damage_receiver.max_health, state_name()]


func current_metrics() -> Dictionary:
	var metrics := super.current_metrics()
	metrics["enemy_name"] = BOSS_NAME
	metrics["boss_volley_count"] = volley_count
	return metrics

func pattern_name(pattern: int) -> String:
	return "태엽 탄막" if pattern == VOLLEY_PATTERN else super.pattern_name(pattern)

func warning_feedback_snapshot() -> Dictionary:
	if current_pattern == VOLLEY_PATTERN:
		return {"color": Color("ffd166"), "shape": "부채꼴", "uses_color_and_shape": true}
	return super.warning_feedback_snapshot()

func _update_idle(delta: float) -> void:
	super._update_idle(delta)
	position.x = clampf(position.x, ARENA_LEFT_X, ARENA_RIGHT_X)

func _begin_next_pattern() -> void:
	current_pattern = Pattern.CHARGE if last_pattern in [Pattern.NONE, VOLLEY_PATTERN] else (Pattern.SHOCKWAVE if last_pattern == Pattern.CHARGE else VOLLEY_PATTERN)
	last_pattern = current_pattern
	pattern_history.append(current_pattern)
	if pattern_history.size() > 8:
		pattern_history.pop_front()
	warning_count += 1
	_charge_direction = signf(player.global_position.x - global_position.x)
	if is_zero_approx(_charge_direction):
		_charge_direction = -1.0
	if current_pattern == VOLLEY_PATTERN:
		_volley_aim = (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -48))).normalized()
		_set_state(State.WARNING, "태엽 탄막 경고 · 부채꼴 방향 확인")
	else:
		_set_state(State.WARNING, "%s 경고" % pattern_name(current_pattern))

func _update_warning() -> void:
	if current_pattern != VOLLEY_PATTERN:
		super._update_warning()
		return
	var duration := 0.75 if phase == 2 else 1.0
	var points := PackedVector2Array()
	for angle in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		points.append(Vector2(0, -48))
		points.append(Vector2(0, -48) + _volley_aim.rotated(angle) * 600)
	warning_line.points = points
	warning_line.visible = true
	warning_line.default_color = Color("ffd166")
	warning_ring.modulate = Color("ffd166")
	if _state_elapsed_s >= duration:
		attack_count += 1
		volley_count += 1
		_fire_volley()
		_begin_recovery("태엽 탄막 후 빈틈")

func _fire_volley() -> void:
	var count := 5 if phase == 2 else 3
	for index in count:
		var angle := (index - (count - 1) * 0.5) * 0.2
		var projectile := SEED_SCENE.instantiate() as EnemySeedProjectile
		projectile.configure("%s:volley:%d:%d" % [attack_life_key(), volley_count, index], _volley_aim.rotated(angle), 10 if phase == 2 else 8, 6.0 if phase == 2 else 5.0, 10.0)
		projectile.attacker_id = &"clockwork_knight"
		projectile.attack_id = &"clockwork_volley"
		projectile.damage_tags = PackedStringArray(["enemy", "boss", "projectile", "clockwork"])
		projectile.base_color = Color("ffd166")
		var container := get_tree().current_scene
		if container == null:
			container = get_tree().root
		container.add_child(projectile)
		projectile.global_position = global_position + Vector2(0, -48)

func _update_charge(delta: float) -> void:
	position.x += _charge_direction * _charge_speed_mps() * PrototypePlayer.PIXELS_PER_METER * delta
	_try_charge_damage()
	if position.x <= ARENA_LEFT_X or position.x >= ARENA_RIGHT_X:
		position.x = clampf(position.x, ARENA_LEFT_X, ARENA_RIGHT_X)
		_set_state(State.STUNNED, "벽 충돌 · %.1f초 검 약점" % _wall_stun_duration())

func _charge_warning_duration() -> float:
	return 0.45 if phase == 2 else 0.65

func _shockwave_warning_duration() -> float:
	return 0.60 if phase == 2 else 0.85

func _charge_speed_mps() -> float:
	return 9.0 if phase == 2 else 7.5
