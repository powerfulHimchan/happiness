class_name BossHappinessGuardian
extends ExpeditionBoss

## GP-311: 성문을 지키는 기사. 경고 방향을 고정하고 공격 뒤 방패를 내린다.
const BOSS_NAME := "행복의 수호기사"
const BOSS_HEALTH := 720
const LANCE_PATTERN := 3
const ARENA_LEFT_X := 3920.0
const ARENA_RIGHT_X := 4880.0
const LANCE_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
const LANCE_TEXTURE := preload("res://assets/guardian_lance.svg")
const LANCE_COLOR := Color("65ddd1")
var lance_count := 0
var _lance_aim := Vector2.LEFT

func _ready() -> void:
	attacker_id = &"happiness_guardian"
	charge_attack_id = &"guardian_charge"
	shockwave_attack_id = &"guardian_shockwave"
	super._ready()
	add_to_group("boss_enemy")

func reset_target() -> void:
	super.reset_target()
	lance_count = 0
	_lance_aim = Vector2.LEFT
	_refresh_status()

func _set_state(new_state: int, message: String) -> void:
	super._set_state(new_state, message.replace("갑옷 멧돼지", BOSS_NAME).replace("활 약점", "성문을 지켜라").replace("분노", "반복 명령"))
	_refresh_status()

func _refresh_status() -> void:
	super._refresh_status()
	if status_label != null and damage_receiver != null:
		status_label.text = "%s · %d페이즈\n%d/%d · %s" % [BOSS_NAME, phase, damage_receiver.health, damage_receiver.max_health, state_name()]

func current_metrics() -> Dictionary:
	var metrics := super.current_metrics()
	metrics.enemy_name = BOSS_NAME
	metrics.elite_weakness = "무기 150%" if state == State.STUNNED else "무기 125%" if state == State.RECOVERY else "방패 정면 감소 · 뒤쪽 정상" if _shield_raised() else "무기 정상"
	metrics.guardian_lance_count = lance_count
	return metrics

func pattern_name(pattern: int) -> String:
	return "빛의 창" if pattern == LANCE_PATTERN else "방패 돌진" if pattern == Pattern.CHARGE else super.pattern_name(pattern)

func warning_feedback_snapshot() -> Dictionary:
	if current_pattern == LANCE_PATTERN:
		return {"color": LANCE_COLOR, "shape": "창 궤적", "uses_color_and_shape": true}
	return super.warning_feedback_snapshot()

func _update_idle(delta: float) -> void:
	super._update_idle(delta)
	position.x = clampf(position.x, ARENA_LEFT_X, ARENA_RIGHT_X)

func _begin_next_pattern() -> void:
	current_pattern = Pattern.CHARGE if last_pattern in [Pattern.NONE, LANCE_PATTERN] else Pattern.SHOCKWAVE if last_pattern == Pattern.CHARGE else LANCE_PATTERN
	last_pattern = current_pattern
	pattern_history.append(current_pattern)
	if pattern_history.size() > 8: pattern_history.pop_front()
	_begin_pattern_warning()

func _begin_pattern_warning() -> void:
	warning_count += 1
	_charge_direction = signf(player.global_position.x - global_position.x)
	if is_zero_approx(_charge_direction): _charge_direction = -1.0
	body_sprite.flip_h = _charge_direction > 0
	_lance_aim = (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -48))).normalized()
	_set_state(State.WARNING, "%s 경고 · 경고 방향 고정" % pattern_name(current_pattern))
	_update_warning()

func _update_warning() -> void:
	if current_pattern != LANCE_PATTERN:
		super._update_warning()
		return
	var points := PackedVector2Array()
	for angle in ([-0.16, 0.0, 0.16] if phase == 2 else [0.0]):
		points.append(Vector2(0, -48))
		points.append(Vector2(0, -48) + _lance_aim.rotated(angle) * 900)
	warning_line.points = points
	warning_line.visible = true
	warning_line.default_color = LANCE_COLOR
	warning_ring.modulate = LANCE_COLOR
	if _state_elapsed_s >= (0.80 if phase == 2 else 1.10):
		attack_count += 1
		lance_count += 1
		for index in (3 if phase == 2 else 1):
			var angle := (index - (1 if phase == 2 else 0)) * 0.16
			var projectile := LANCE_SCENE.instantiate() as EnemySeedProjectile
			projectile.configure("%s:lance:%d:%d" % [attack_life_key(), lance_count, index], _lance_aim.rotated(angle), 14 if phase == 2 else 11, 7.0 if phase == 2 else 6.0, 11.0)
			projectile.attacker_id = attacker_id
			projectile.attack_id = &"guardian_lance"
			projectile.damage_tags = PackedStringArray(["enemy", "boss", "guardian", "projectile"])
			var container := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
			container.add_child(projectile)
			projectile.projectile_sprite.texture = LANCE_TEXTURE
			projectile.global_position = global_position + Vector2(0, -48)
		_begin_recovery("빛의 창 후 빈틈 · 방패 내림")

func _update_charge(delta: float) -> void:
	super._update_charge(delta)
	if position.x <= ARENA_LEFT_X or position.x >= ARENA_RIGHT_X:
		position.x = clampf(position.x, ARENA_LEFT_X, ARENA_RIGHT_X)
		_set_state(State.STUNNED, "벽 충돌 · 무기 약점")

func _shield_raised() -> bool:
	return state in [State.WARNING, State.CHARGING]

func _adjust_damage_event(event: DamageEvent) -> DamageEvent:
	var multiplier := 1.0
	if event.tags.has("sword") or event.tags.has("bow") or event.tags.has("fist"):
		if state == State.STUNNED: multiplier = 1.50
		elif state == State.RECOVERY: multiplier = 1.25
		elif _shield_raised() and (event.source_position.x - global_position.x) * _charge_direction >= 0:
			multiplier = 0.80 if event.tags.has("bow") else 0.65
	last_damage_multiplier = multiplier
	last_adjusted_damage = maxi(1, roundi(event.damage * multiplier))
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
	return 0.65 if phase == 2 else 0.90

func _shockwave_warning_duration() -> float:
	return 0.70 if phase == 2 else 1.00

func _charge_speed_mps() -> float:
	return 8.2 if phase == 2 else 6.8
