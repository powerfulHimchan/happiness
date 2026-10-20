class_name PrototypeEnemy
extends PrototypeTarget

## CP-301 일반 적 세 종류의 경고, 공격, 빈틈과 사망 상태를 관리한다.

enum EnemyType {
	LEAF_SLIME,
	SEED_SACK,
	WIND_SPIRIT,
}

enum State {
	IDLE,
	WARNING,
	ATTACK,
	RECOVERY,
	DEAD,
}

const SEED_PROJECTILE_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
const CLOCK_DOLL_TEXTURE := preload("res://assets/star_clock_doll.svg")
const FESTIVAL_SOLDIER_TEXTURE := preload("res://assets/festival_soldier.svg")
const FESTIVAL_TURRET_TEXTURE := preload("res://assets/festival_turret.svg")
const SOLDIER_WARNING_S := 0.65
const SOLDIER_RECOVERY_S := 1.10
const SOLDIER_DASH_PX := 240.0
const TURRET_WARNING_S := 1.10
const TURRET_RECOVERY_S := 1.40
const TURRET_ANGLES := [-20.0, -10.0, 0.0, 10.0, 20.0]
const SLIME_WARNING_S := 0.35
const SLIME_RECOVERY_S := 0.80
const SEED_WARNING_S := 1.00
const SEED_RECOVERY_S := 1.00
const WIND_WARNING_S := 0.60
const WIND_RECOVERY_S := 1.20
const SLIME_DAMAGE := 8
const SEED_DAMAGE := 7
const WIND_DAMAGE := 10
const CONTACT_RADIUS_PX := 68.0
const DANGER_RING_COLOR := Color("ff5f56")
const DANGER_LINE_COLOR := Color("ff7043")

@export_enum("풀잎 슬라임", "씨앗 포대", "바람 정령") var enemy_type: int = EnemyType.LEAF_SLIME
@export var player_path: NodePath

var expedition_patterns: bool = false
var forest_variant: bool = false
var ruins_variant: bool = false
var festival_variant: bool = false
var _original_body_texture: Texture2D
var _clock_aim := Vector2.LEFT
var _clock_second_warning: bool = false
var _combo_remaining: int = 0
var _original_body_color: Color
var state: int = State.IDLE
var attack_count: int = 0
var hit_count: int = 0
var warning_count: int = 0
var last_enemy_log: String = "행동 대기"
var last_event_msec: int = -1
var _state_elapsed_s: float = 0.0
var _attack_cooldown_s: float = 0.0
var _spawn_position: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _attack_direction: Vector2 = Vector2.LEFT
var _attack_distance_px: float = 0.0
var _attack_hit_consumed: bool = false
var _patrol_direction: float = -1.0
var _projectile_sequence: int = 0
var visual_animation := EnemyVisualAnimation.new()

@onready var player: PrototypePlayer = get_node(player_path) as PrototypePlayer
@onready var warning_ring: Sprite2D = $WarningRing
@onready var warning_line: Line2D = $WarningLine


func _ready() -> void:
	super._ready()
	_original_body_color = body_color
	_original_body_texture = body_sprite.texture
	visual_animation.bind(body_sprite)
	_spawn_position = position
	add_to_group("prototype_enemy")
	add_to_group("combat_enemy")
	warning_ring.visible = false
	warning_line.visible = false
	warning_ring.modulate = DANGER_RING_COLOR
	warning_line.default_color = DANGER_LINE_COLOR
	_set_state(State.IDLE, "%s 등장" % enemy_name())


func _process(delta: float) -> void:
	super._process(delta)
	if not is_targetable():
		if state != State.DEAD:
			_set_state(State.DEAD, "%s 처치" % enemy_name())
		_update_body_animation(delta * enemy_time_scale())
		return
	var scaled_delta := delta * enemy_time_scale()
	_attack_cooldown_s = maxf(0.0, _attack_cooldown_s - scaled_delta)
	_state_elapsed_s += scaled_delta
	_update_body_animation(scaled_delta)
	if festival_variant and enemy_type == EnemyType.LEAF_SLIME:
		_update_festival_soldier(scaled_delta)
	elif festival_variant and enemy_type == EnemyType.SEED_SACK:
		_update_festival_turret()
	else:
		_update_original_enemy(scaled_delta)
	_update_warning_visual()
	_update_body_animation(0.0)


func _update_original_enemy(delta: float) -> void:
	match enemy_type:
		EnemyType.LEAF_SLIME:
			_update_leaf_slime(delta)
		EnemyType.SEED_SACK:
			_update_seed_sack(delta)
		EnemyType.WIND_SPIRIT:
			_update_wind_spirit(delta)


func receive_damage(event: DamageEvent) -> int:
	var result := super.receive_damage(event)
	if result != DamageReceiver.Result.APPLIED:
		return result
	if not is_targetable():
		_set_state(State.DEAD, "%s 처치" % enemy_name())
		return result
	if enemy_type == EnemyType.SEED_SACK and (event.tags.has("sword") or event.tags.has("fist")):
		var away_sign := signf(global_position.x - event.source_position.x)
		if is_zero_approx(away_sign):
			away_sign = 1.0
		global_position.x += away_sign * 70.0
		_combo_remaining = 0
		_attack_cooldown_s = maxf(_attack_cooldown_s, SEED_RECOVERY_S)
		_set_state(State.RECOVERY, "%s 근접 피격 · 사격 중단" % enemy_name())
	elif festival_variant and enemy_type == EnemyType.LEAF_SLIME and (event.tags.has("sword") or event.tags.has("fist")):
		_combo_remaining = 0
		_attack_cooldown_s = SOLDIER_RECOVERY_S
		_set_state(State.RECOVERY, "장난감 병정 피격 · 행진 중단")
	_update_body_animation(0.0)
	return result


func configure_route(route: String) -> void:
	forest_variant = route == "forest"
	ruins_variant = route == "ruins"
	festival_variant = route == "festival"
	body_sprite.texture = CLOCK_DOLL_TEXTURE if ruins_variant and enemy_type == EnemyType.SEED_SACK else _original_body_texture
	if festival_variant:
		if enemy_type == EnemyType.LEAF_SLIME: body_sprite.texture = FESTIVAL_SOLDIER_TEXTURE
		elif enemy_type == EnemyType.SEED_SACK: body_sprite.texture = FESTIVAL_TURRET_TEXTURE
	_combo_remaining = 0
	queue_redraw()
	body_color = Color("b8e38b") if forest_variant else Color.WHITE if ruins_variant or festival_variant else _original_body_color
	visual_animation.reset(body_sprite)
	_update_body_animation(0.0)


func reset_target() -> void:
	super.reset_target()
	state = State.IDLE
	_clock_aim = Vector2.LEFT
	_clock_second_warning = false
	_combo_remaining = 0
	attack_count = 0
	hit_count = 0
	warning_count = 0
	last_enemy_log = "행동 대기"
	last_event_msec = Time.get_ticks_msec()
	_state_elapsed_s = 0.0
	_attack_cooldown_s = 0.0
	_velocity = Vector2.ZERO
	_attack_distance_px = 0.0
	_attack_hit_consumed = false
	_patrol_direction = -1.0
	_projectile_sequence = 0
	if warning_ring != null:
		warning_ring.visible = false
	if warning_line != null:
		warning_line.visible = false
	if body_sprite != null:
		visual_animation.reset(body_sprite)
		_update_visual()
		_update_body_animation(0.0)


func set_stage_spawn(spawn_position: Vector2) -> void:
	super.set_stage_spawn(spawn_position)
	_spawn_position = spawn_position


func current_metrics() -> Dictionary:
	return {
		"enemy_key": target_key,
		"enemy_name": enemy_name(),
		"enemy_type": enemy_type,
		"enemy_expedition_patterns": expedition_patterns,
		"enemy_forest_variant": forest_variant,
		"enemy_ruins_variant": ruins_variant,
		"enemy_festival_variant": festival_variant,
		"enemy_combo_remaining": _combo_remaining,
		"enemy_state": state_name(),
		"enemy_warning": state == State.WARNING,
		"enemy_alive": is_targetable(),
		"enemy_attack_count": attack_count,
		"enemy_hit_count": hit_count,
		"enemy_warning_count": warning_count,
		"enemy_last_log": last_enemy_log,
		"enemy_event_msec": last_event_msec,
	}


func warning_feedback_snapshot() -> Dictionary:
	return {
		"color": DANGER_LINE_COLOR if enemy_type == EnemyType.WIND_SPIRIT else DANGER_RING_COLOR,
		"shape": "부채" if (forest_variant or festival_variant) and enemy_type == EnemyType.SEED_SACK else "직선" if enemy_type == EnemyType.WIND_SPIRIT or (festival_variant and enemy_type == EnemyType.LEAF_SLIME) else "원형",
		"uses_color_and_shape": true,
	}


func enemy_name() -> String:
	if ruins_variant and enemy_type == EnemyType.SEED_SACK: return "별시계 인형"
	if festival_variant and enemy_type == EnemyType.LEAF_SLIME: return "장난감 병정"
	if festival_variant and enemy_type == EnemyType.SEED_SACK: return "축제 포탑"
	match enemy_type:
		EnemyType.LEAF_SLIME:
			return "풀잎 슬라임"
		EnemyType.SEED_SACK:
			return "씨앗 포대"
		EnemyType.WIND_SPIRIT:
			return "바람 정령"
	return "일반 적"


func state_name() -> String:
	match state:
		State.IDLE:
			return "대기"
		State.WARNING:
			return "경고"
		State.ATTACK:
			return "공격"
		State.RECOVERY:
			return "빈틈"
		State.DEAD:
			return "처치"
	return "알 수 없음"


func _update_festival_soldier(delta: float) -> void:
	match state:
		State.IDLE:
			position.x += _patrol_direction * 65.0 * delta
			if absf(position.x - _spawn_position.x) >= 70.0: _patrol_direction *= -1.0
			if _attack_cooldown_s <= 0.0 and _distance_to_player_m() <= 3.8:
				var side := signf(player.global_position.x - global_position.x)
				_attack_direction = Vector2(side if not is_zero_approx(side) else -1.0, 0)
				_combo_remaining = 1 if expedition_patterns else 0
				_begin_warning("원정 병정 연속 행진 · 각0.65초 경고" if expedition_patterns else "병정 행진 돌진 · 0.65초 경고")
				warning_line.points = PackedVector2Array([Vector2(0, -38), Vector2(0, -38) + _attack_direction * SOLDIER_DASH_PX])
		State.WARNING:
			if _state_elapsed_s >= SOLDIER_WARNING_S: _begin_attack("병정 행진 돌진")
		State.ATTACK:
			var distance := minf(400.0 * delta, SOLDIER_DASH_PX - _attack_distance_px)
			position.x = clampf(position.x + _attack_direction.x * distance, 100.0, 4900.0)
			_attack_distance_px += distance
			_try_contact_damage(9, &"soldier_march")
			if _attack_distance_px >= SOLDIER_DASH_PX: _begin_recovery("병정 태엽 재감기 · 1.1초 빈틈")
		State.RECOVERY:
			if _combo_remaining > 0 and _state_elapsed_s >= 0.35:
				_combo_remaining -= 1
				var side := signf(player.global_position.x - global_position.x)
				_attack_direction = Vector2(side if not is_zero_approx(side) else -1.0, 0)
				_begin_warning("원정 병정 재돌진 · 0.65초 경고")
				warning_line.points = PackedVector2Array([Vector2(0, -38), Vector2(0, -38) + _attack_direction * SOLDIER_DASH_PX])
			elif _state_elapsed_s >= SOLDIER_RECOVERY_S:
				_attack_cooldown_s = 0.45
				_set_state(State.IDLE, "병정 순찰 재개")


func _update_festival_turret() -> void:
	match state:
		State.IDLE:
			if _attack_cooldown_s <= 0.0 and _distance_to_player_m() <= 8.5:
				_clock_aim = (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -54))).normalized()
				_combo_remaining = 1 if expedition_patterns else 0
				_begin_warning("원정 포탑 연속 부채탄 · 각1.1초 고정 조준" if expedition_patterns else "포탑 부채탄 · 1.1초 고정 조준")
				warning_line.points = PackedVector2Array([Vector2(0, -54), Vector2(0, -54) + _clock_aim * 600.0])
		State.WARNING:
			warning_line.points = PackedVector2Array([Vector2(0, -54), Vector2(0, -54) + _clock_aim * 600.0])
			if _state_elapsed_s >= TURRET_WARNING_S:
				_fire_seed_volley()
				_begin_recovery("포탑 다섯 발 · 1.4초 재장전")
		State.RECOVERY:
			if _combo_remaining > 0 and _state_elapsed_s >= 0.35:
				_combo_remaining -= 1
				_clock_aim = (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -54))).normalized()
				_begin_warning("원정 포탑 재조준 · 1.1초 경고")
				warning_line.points = PackedVector2Array([Vector2(0, -54), Vector2(0, -54) + _clock_aim * 600.0])
			elif _state_elapsed_s >= TURRET_RECOVERY_S:
				_attack_cooldown_s = 0.6
				_set_state(State.IDLE, "포탑 조준 대기")


func _update_leaf_slime(delta: float) -> void:
	match state:
		State.IDLE:
			position.x += _patrol_direction * 70.0 * delta
			if absf(position.x - _spawn_position.x) >= 70.0:
				_patrol_direction *= -1.0
			if _attack_cooldown_s <= 0.0 and _distance_to_player_m() <= 3.0:
				_combo_remaining = (1 if forest_variant else 0) + (1 if expedition_patterns else 0)
				_begin_warning("원정 슬라임 연속 도약 · 각0.35초 경고" if expedition_patterns else "숲 슬라임 연속 도약 · 각0.35초 경고" if forest_variant else "풀잎 슬라임 점프 경고 · 0.35초")
		State.WARNING:
			if _state_elapsed_s >= SLIME_WARNING_S:
				var direction_sign := signf(player.global_position.x - global_position.x)
				_attack_direction = Vector2(direction_sign if not is_zero_approx(direction_sign) else -1.0, 0.0)
				_velocity = Vector2(_attack_direction.x * 320.0, -650.0)
				_begin_attack("풀잎 슬라임 점프 공격")
		State.ATTACK:
			_velocity.y += 1900.0 * delta
			position += _velocity * delta
			if expedition_patterns: position.x = clampf(position.x, 100.0, 4900.0)
			_try_contact_damage(SLIME_DAMAGE, &"slime_jump")
			if position.y >= _spawn_position.y:
				position.y = _spawn_position.y
				_velocity = Vector2.ZERO
				_begin_recovery("풀잎 슬라임 착지 · 0.8초 빈틈")
		State.RECOVERY:
			if _combo_remaining > 0 and _state_elapsed_s >= 0.30:
				_combo_remaining -= 1
				_begin_warning("원정 슬라임 재도약 · 0.35초 경고" if expedition_patterns else "숲 슬라임 두 번째 도약 · 0.35초 경고")
			elif _state_elapsed_s >= SLIME_RECOVERY_S:
				_attack_cooldown_s = 0.35
				_set_state(State.IDLE, "풀잎 슬라임 이동 재개")


func _update_seed_sack(delta: float) -> void:
	match state:
		State.IDLE:
			var horizontal_distance_m := absf(player.global_position.x - global_position.x) / PrototypePlayer.PIXELS_PER_METER
			if horizontal_distance_m < 4.0:
				var away := signf(global_position.x - player.global_position.x)
				position.x += (away if not is_zero_approx(away) else 1.0) * 160.0 * delta
			elif horizontal_distance_m > 7.0:
				position.x += signf(player.global_position.x - global_position.x) * 120.0 * delta
			elif _attack_cooldown_s <= 0.0:
				_combo_remaining = (1 if ruins_variant else 0) + (1 if expedition_patterns else 0)
				if ruins_variant:
					_clock_second_warning = false
					_clock_aim = (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -54))).normalized()
				_begin_warning("원정 연속 사격 · 각 발사 전 경고" if expedition_patterns else "별시계 인형 사격 · 1.0초 경고" if ruins_variant else "숲 씨앗 다섯 갈래 · 1.0초 경고" if forest_variant else "씨앗 포대 조준 경고 · 1.0초")
		State.WARNING:
			if ruins_variant:
				warning_line.points = PackedVector2Array([Vector2(0, -54), Vector2(0, -54) + _clock_aim * 520.0])
			else:
				_update_aim_line(520.0, DANGER_LINE_COLOR)
			if _state_elapsed_s >= (0.70 if ruins_variant and _clock_second_warning else SEED_WARNING_S):
				_fire_seed_volley()
				_begin_recovery("씨앗탄 %d발 발사 · 반격 1.0초" % (5 if forest_variant else 3))
		State.RECOVERY:
			if _combo_remaining > 0 and _state_elapsed_s >= 0.35:
				_combo_remaining -= 1
				_clock_second_warning = true
				_begin_warning("기억된 방향 재사격 · 0.7초 경고" if ruins_variant else "원정 재사격 · 1.0초 경고")
			elif _state_elapsed_s >= SEED_RECOVERY_S:
				_attack_cooldown_s = 1.25
				_set_state(State.IDLE, "씨앗 포대 거리 유지 재개")


func _update_wind_spirit(delta: float) -> void:
	match state:
		State.IDLE:
			var target_y := player.global_position.y - 165.0
			position.y = move_toward(position.y, target_y, 130.0 * delta)
			if absf(player.global_position.x - global_position.x) > 780.0:
				position.x += signf(player.global_position.x - global_position.x) * 145.0 * delta
			if _attack_cooldown_s <= 0.0 and _distance_to_player_m() <= 9.0:
				_attack_direction = (
					player.global_position + Vector2(0.0, -42.0) - global_position
				).normalized()
				_combo_remaining = (1 if forest_variant else 0) + (1 if expedition_patterns else 0)
				_begin_warning("원정 정령 연속 돌진 · 각0.6초 경고" if expedition_patterns else "숲 정령 재돌진 · 각0.6초 경고" if forest_variant else "바람 정령 직선 경고 · 0.6초")
		State.WARNING:
			_update_fixed_warning_line(_attack_direction * 850.0, DANGER_LINE_COLOR)
			if _state_elapsed_s >= WIND_WARNING_S:
				_begin_attack("바람 정령 돌진")
		State.ATTACK:
			var displacement := _attack_direction * 900.0 * delta
			position += displacement
			_attack_distance_px += displacement.length()
			_try_contact_damage(WIND_DAMAGE, &"wind_dash")
			if _attack_distance_px >= 850.0 or position.x <= 100.0 or position.x >= 4900.0:
				if forest_variant or expedition_patterns:
					position.x = clampf(position.x, 100.0, 4900.0)
				_begin_recovery("바람 정령 빗나감 · 1.2초 빈틈")
		State.RECOVERY:
			if _combo_remaining > 0 and _state_elapsed_s >= 0.30:
				_combo_remaining -= 1
				_attack_direction = (player.global_position + Vector2(0.0, -42.0) - global_position).normalized()
				_begin_warning("원정 정령 재돌진 · 0.6초 경고" if expedition_patterns else "숲 정령 두 번째 돌진 · 0.6초 경고")
			elif _state_elapsed_s >= WIND_RECOVERY_S:
				_attack_cooldown_s = 0.55
				_set_state(State.IDLE, "바람 정령 부유 재개")


func _begin_warning(message: String) -> void:
	warning_count += 1
	_set_state(State.WARNING, message)


func _begin_attack(message: String) -> void:
	attack_count += 1
	_attack_distance_px = 0.0
	_attack_hit_consumed = false
	_set_state(State.ATTACK, message)


func _begin_recovery(message: String) -> void:
	_set_state(State.RECOVERY, message)


func _set_state(new_state: int, message: String) -> void:
	state = new_state
	if new_state == State.DEAD: _combo_remaining = 0
	_state_elapsed_s = 0.0
	last_enemy_log = message
	last_event_msec = Time.get_ticks_msec()
	queue_redraw()
	if warning_ring != null:
		warning_ring.visible = new_state == State.WARNING and enemy_type != EnemyType.WIND_SPIRIT
		warning_ring.modulate = DANGER_RING_COLOR
	if warning_line != null:
		warning_line.visible = new_state == State.WARNING
		warning_line.default_color = DANGER_LINE_COLOR
		if new_state == State.WARNING and enemy_type == EnemyType.WIND_SPIRIT:
			_update_fixed_warning_line(_attack_direction * 850.0, DANGER_LINE_COLOR)
	_update_body_animation(0.0)


func _fire_seed_volley() -> void:
	attack_count += 1
	visual_animation.shot()
	var origin := global_position + Vector2(0.0, -54.0)
	var base_direction := _clock_aim if ruins_variant or festival_variant else (player.global_position + Vector2(0.0, -42.0) - origin).normalized()
	var angles := TURRET_ANGLES if festival_variant else [-24.0, -12.0, 0.0, 12.0, 24.0] if forest_variant else [-12.0, 0.0, 12.0]
	for angle_degrees in angles:
		_projectile_sequence += 1
		var projectile := SEED_PROJECTILE_SCENE.instantiate() as EnemySeedProjectile
		projectile.configure(
			"%s:volley:%d:%d" % [attack_life_key(), attack_count, _projectile_sequence],
			base_direction.rotated(deg_to_rad(angle_degrees)),
			SEED_DAMAGE
		)
		if ruins_variant:
			projectile.attack_id = &"clock_doll_volley"
			projectile.damage_tags = PackedStringArray(["enemy", "projectile", "clock", "doll"])
			projectile.base_color = Color("9be2ff")
		if festival_variant:
			projectile.attacker_id = &"festival_turret"
			projectile.attack_id = &"turret_fan"
			projectile.damage_tags = PackedStringArray(["enemy", "projectile", "festival", "turret"])
			projectile.base_color = Color("ffe2a3")
		var projectile_parent := get_tree().current_scene
		if projectile_parent == null:
			projectile_parent = get_tree().root
		projectile_parent.add_child(projectile)
		projectile.global_position = origin
	_update_body_animation(0.0)


func _update_body_animation(delta: float) -> void:
	if body_sprite == null: return
	var enabled := not ((ruins_variant and enemy_type == EnemyType.SEED_SACK) or (festival_variant and enemy_type != EnemyType.WIND_SPIRIT))
	var facing := 1
	var moving := false
	if is_instance_valid(player):
		facing = -1 if player.global_position.x < global_position.x else 1
		moving = state == State.IDLE and (enemy_type == EnemyType.LEAF_SLIME or absf(player.global_position.x - global_position.x) < 400.0 or absf(player.global_position.x - global_position.x) > 700.0)
	if enemy_type == EnemyType.LEAF_SLIME and state == State.IDLE:
		facing = -1 if _patrol_direction < 0 else 1
	elif state == State.ATTACK or (enemy_type == EnemyType.WIND_SPIRIT and state == State.WARNING):
		facing = -1 if _attack_direction.x < 0 else 1
	var warning_s := SLIME_WARNING_S if enemy_type == EnemyType.LEAF_SLIME else SEED_WARNING_S if enemy_type == EnemyType.SEED_SACK else WIND_WARNING_S
	visual_animation.animate(body_sprite, enemy_type, state, delta, facing, moving,
		_hit_flash_remaining_s > 0.0, enabled, _state_elapsed_s / warning_s)


func _try_contact_damage(amount: int, attack_id: StringName) -> void:
	if _attack_hit_consumed or player == null or not player.can_continue_combat_action():
		return
	if global_position.distance_to(player.global_position + Vector2(0.0, -38.0)) > CONTACT_RADIUS_PX:
		return
	_attack_hit_consumed = true
	var was_evading := player.invincible
	var event := DamageEvent.new()
	event.event_id = StringName("%s:%d:player" % [attack_life_key(), attack_count])
	event.attacker_id = StringName(target_key)
	event.attack_id = attack_id
	event.damage = amount
	event.stagger_s = 0.14
	event.tags = PackedStringArray(["enemy", "contact", enemy_name()])
	event.source_position = global_position
	var result := player.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED:
		hit_count += 1
		last_enemy_log = "%s 적중 · 피해 %d" % [enemy_name(), amount]
	elif was_evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		_register_precise_evade()
		last_enemy_log = "%s 정확한 회피" % enemy_name()


func _register_precise_evade() -> void:
	var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
	if ultimate != null:
		ultimate.register_precise_evade()


func _distance_to_player_m() -> float:
	return global_position.distance_to(player.global_position) / PrototypePlayer.PIXELS_PER_METER


func _update_aim_line(length_px: float, color: Color) -> void:
	var direction := (player.global_position + Vector2(0.0, -42.0) - global_position).normalized()
	_update_fixed_warning_line(direction * length_px, color)


func _update_fixed_warning_line(endpoint: Vector2, color: Color) -> void:
	warning_line.default_color = color
	warning_line.points = PackedVector2Array([Vector2(0.0, -42.0), endpoint])


func _update_warning_visual() -> void:
	if state != State.WARNING:
		return
	if (forest_variant or festival_variant) and enemy_type == EnemyType.SEED_SACK:
		queue_redraw()
	var pulse := 0.58 + sin(_state_elapsed_s * 22.0) * 0.28
	if warning_ring.visible:
		warning_ring.modulate.a = pulse
	if warning_line.visible:
		warning_line.modulate.a = pulse


func _draw() -> void:
	if not (forest_variant or festival_variant) or enemy_type != EnemyType.SEED_SACK or state != State.WARNING:
		return
	var origin := Vector2(0.0, -54.0)
	var direction := _clock_aim if festival_variant else (player.global_position + Vector2(0.0, -42.0) - global_position - origin).normalized()
	var angles := [-20.0, -10.0, 10.0, 20.0] if festival_variant else [-24.0, -12.0, 12.0, 24.0]
	for angle in angles:
		draw_line(origin, origin + direction.rotated(deg_to_rad(angle)) * (600.0 if festival_variant else 520.0), Color(DANGER_LINE_COLOR, 0.75), 3.0)
