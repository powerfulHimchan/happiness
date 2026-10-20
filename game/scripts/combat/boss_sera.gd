class_name BossSera
extends ExpeditionBoss

const BOSS_NAME := "미소의 여왕 세라"
const BOSS_HEALTH := 960
const RING_PATTERN := 3
const ARENA_LEFT_X := 3920.0
const ARENA_RIGHT_X := 4880.0
const SPARK_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
const SPARK_TEXTURE := preload("res://assets/sera_spark.svg")
const CALM_TEXTURE := preload("res://assets/prototype_sera.svg")
const AWAKENED_TEXTURE := preload("res://assets/prototype_sera_awakened.svg")
var ring_count: int = 0
var _ring_second_pending: bool = false
var _ring_follow_up_s: float = 0.0

func _ready() -> void:
	attacker_id = &"sera"
	charge_attack_id = &"sera_clock_dash"
	shockwave_attack_id = &"sera_smile_wave"
	super._ready()
	warning_line.width = 4.0
	armor_marker.visible = false
	add_to_group("boss_enemy")

func reset_target() -> void:
	super.reset_target()
	ring_count = 0
	_ring_second_pending = false
	_ring_follow_up_s = 0.0
	_refresh_status()

func _process(delta: float) -> void:
	if enemy_time_scale() <= 0.0: return
	var follow_up_was_pending := _ring_second_pending
	super._process(delta)
	if follow_up_was_pending and _ring_second_pending and is_targetable():
		_ring_follow_up_s -= delta * enemy_time_scale()
		if _ring_follow_up_s <= 0.0:
			_ring_second_pending = false
			_fire_ring(PI / 8.0)

func _set_state(new_state: int, message: String) -> void:
	if new_state in [State.DEAD, State.PHASE_TRANSITION]: _ring_second_pending = false
	super._set_state(new_state, message.replace("갑옷 멧돼지", BOSS_NAME).replace("분노", "흔들리는 기억").replace("활 약점", "왕관의 명령"))
	_refresh_status()

func _refresh_status() -> void:
	super._refresh_status()
	if body_sprite != null: body_sprite.texture = AWAKENED_TEXTURE if phase == 2 else CALM_TEXTURE
	if status_label != null and damage_receiver != null:
		status_label.text = "%s · %d페이즈\n%d/%d · %s" % [BOSS_NAME, phase, damage_receiver.health, damage_receiver.max_health, state_name()]

func current_metrics() -> Dictionary:
	var metrics := super.current_metrics()
	metrics.enemy_name = BOSS_NAME
	metrics.elite_weakness = "왕관 빈틈 · 무기125%" if state == State.RECOVERY else "무기 정상"
	metrics.sera_ring_count = ring_count
	return metrics

func pattern_name(pattern: int) -> String:
	return "왕관의 빛살" if pattern == RING_PATTERN else "시계바늘 돌진" if pattern == Pattern.CHARGE else "미소의 파문" if pattern == Pattern.SHOCKWAVE else "없음"

func warning_feedback_snapshot() -> Dictionary:
	return {"color": Color("ffd166") if current_pattern == RING_PATTERN else Color("65ddd1"), "shape": "여덟 빛살" if current_pattern == RING_PATTERN else "직선" if current_pattern == Pattern.CHARGE else "지면 원형", "uses_color_and_shape": true}

func _update_idle(delta: float) -> void:
	super._update_idle(delta)
	position.x = clampf(position.x, ARENA_LEFT_X, ARENA_RIGHT_X)

func _begin_next_pattern() -> void:
	current_pattern = Pattern.CHARGE if last_pattern in [Pattern.NONE, RING_PATTERN] else Pattern.SHOCKWAVE if last_pattern == Pattern.CHARGE else RING_PATTERN
	last_pattern = current_pattern
	pattern_history.append(current_pattern)
	if pattern_history.size() > 8: pattern_history.pop_front()
	_begin_pattern_warning()

func _begin_pattern_warning() -> void:
	warning_count += 1
	_charge_direction = signf(player.global_position.x - global_position.x)
	if is_zero_approx(_charge_direction): _charge_direction = -1.0
	body_sprite.flip_h = _charge_direction > 0
	var message := "빛살 두 번 경고 · 두 번째 틈 회전" if current_pattern == RING_PATTERN and phase == 2 else "%s 경고 · 공격 뒤 왕관 빈틈" % pattern_name(current_pattern)
	_set_state(State.WARNING, message)
	_update_warning()

func _update_warning() -> void:
	if current_pattern != RING_PATTERN:
		super._update_warning()
		return
	var points := PackedVector2Array()
	for index in 8:
		points.append(Vector2(0, -56))
		points.append(Vector2(0, -56) + Vector2.RIGHT.rotated(index * TAU / 8.0) * 500)
	warning_line.points = points
	warning_line.visible = true
	warning_line.default_color = Color("ffd166")
	warning_ring.modulate = Color("ffd166")
	if _state_elapsed_s >= (0.80 if phase == 2 else 1.10):
		attack_count += 1
		_fire_ring(0.0)
		_ring_second_pending = phase == 2
		_ring_follow_up_s = 0.28
		_begin_recovery("빛살 후 왕관 빈틈")

func _fire_ring(rotation_offset: float) -> void:
	ring_count += 1
	for index in 8:
		var projectile := SPARK_SCENE.instantiate() as EnemySeedProjectile
		projectile.configure("%s:ring:%d:%d" % [attack_life_key(), ring_count, index], Vector2.RIGHT.rotated(index * TAU / 8.0 + rotation_offset), 10 if phase == 2 else 8, 5.5 if phase == 2 else 4.5, 10.0)
		projectile.attacker_id = attacker_id
		projectile.attack_id = &"sera_crown_spark"
		projectile.damage_tags = PackedStringArray(["enemy", "boss", "sera", "projectile"])
		var container := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		container.add_child(projectile)
		projectile.projectile_sprite.texture = SPARK_TEXTURE
		projectile.global_position = global_position + Vector2(0, -56)

func _update_charge(delta: float) -> void:
	position.x = clampf(position.x + _charge_direction * _charge_speed_mps() * PrototypePlayer.PIXELS_PER_METER * delta, ARENA_LEFT_X, ARENA_RIGHT_X)
	_try_charge_damage()
	if _state_elapsed_s >= (0.48 if phase == 2 else 0.55) or position.x in [ARENA_LEFT_X, ARENA_RIGHT_X]:
		_begin_recovery("시계바늘 돌진 후 왕관 빈틈")

func _adjust_damage_event(event: DamageEvent) -> DamageEvent:
	last_damage_multiplier = 1.25 if state == State.RECOVERY and (event.tags.has("sword") or event.tags.has("bow") or event.tags.has("fist")) else 1.0
	last_adjusted_damage = maxi(1, roundi(event.damage * last_damage_multiplier))
	var adjusted := DamageEvent.new()
	adjusted.event_id = event.event_id
	adjusted.attacker_id = event.attacker_id
	adjusted.attack_id = event.attack_id
	adjusted.damage = last_adjusted_damage
	adjusted.stagger_s = event.stagger_s
	adjusted.tags = event.tags.duplicate()
	adjusted.source_position = event.source_position
	return adjusted

func _charge_warning_duration() -> float:
	return 0.60 if phase == 2 else 0.85

func _shockwave_warning_duration() -> float:
	return 0.70 if phase == 2 else 1.00

func _charge_speed_mps() -> float:
	return 8.0 if phase == 2 else 6.5
