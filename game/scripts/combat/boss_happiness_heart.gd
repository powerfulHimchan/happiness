class_name BossHappinessHeart
extends ExpeditionBoss

const BOSS_NAME := "행복의 심장"
const BOSS_HEALTH := 1200
const BEAM := 3
const NEEDLES := 4
const ARENA_LEFT := 3830.0
const ARENA_RIGHT := 4880.0
const PROJECTILE := preload("res://scenes/combat/enemy_seed_projectile.tscn")
const NEEDLE_TEXTURE := preload("res://assets/sera_spark.svg")
var beam_count: int = 0
var needle_count: int = 0
var _beam_y: float = 738.0
var _aim := Vector2.LEFT
var _beam_flash_s: float = 0.0

func _ready() -> void:
	attacker_id = &"happiness_heart"
	shockwave_attack_id = &"heart_pulse"
	super._ready()
	armor_marker.visible = false
	warning_line.width = 6.0
	add_to_group("boss_enemy")

func reset_target() -> void:
	super.reset_target()
	beam_count = 0
	needle_count = 0
	_beam_flash_s = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if enemy_time_scale() <= 0.0: return
	_beam_flash_s = maxf(0, _beam_flash_s - delta * enemy_time_scale())
	super._process(delta)
	queue_redraw()

func _draw() -> void:
	if _beam_flash_s > 0:
		draw_line(Vector2(ARENA_LEFT - position.x, _beam_y - position.y), Vector2(ARENA_RIGHT - position.x, _beam_y - position.y), Color("ffdb88"), 28)

func _update_idle(_delta: float) -> void:
	if _attack_cooldown_s <= 0: _begin_next_pattern()

func _begin_next_pattern() -> void:
	current_pattern = NEEDLES if last_pattern == Pattern.SHOCKWAVE else BEAM if last_pattern == NEEDLES else Pattern.SHOCKWAVE
	last_pattern = current_pattern
	pattern_history.append(current_pattern)
	if pattern_history.size() > 8: pattern_history.pop_front()
	_begin_pattern_warning()

func _begin_pattern_warning() -> void:
	warning_count += 1
	_beam_y = player.global_position.y - 42.0
	_aim = (player.global_position + Vector2(0, -42) - (global_position + Vector2(0, -56))).normalized()
	_set_state(State.WARNING, pattern_name(current_pattern) + (" 두 번 경고" if phase == 2 and current_pattern == Pattern.SHOCKWAVE else " 경고") + " · 공격 뒤 핵 노출")
	_draw_warning()

func _update_warning() -> void:
	_draw_warning()
	if _state_elapsed_s < (0.72 if phase == 2 else 1.05): return
	attack_count += 1
	match current_pattern:
		Pattern.SHOCKWAVE:
			shockwave_count += 1
			_spawn_shockwaves()
			_phase_two_second_wave_pending = phase == 2
			_set_state(State.SHOCKWAVE, "심장 맥박 · 지면 파문")
		NEEDLES:
			_fire_needles()
			_begin_recovery("바늘 부채탄 뒤 핵 노출")
		BEAM:
			_fire_beam()
			_begin_recovery("기억 절단 뒤 핵 노출")

func _draw_warning() -> void:
	warning_line.visible = true
	warning_line.default_color = Color("ffd166") if current_pattern == NEEDLES else Color("f78984")
	if current_pattern == BEAM:
		warning_line.points = PackedVector2Array([Vector2(ARENA_LEFT - position.x, _beam_y - position.y), Vector2(ARENA_RIGHT - position.x, _beam_y - position.y)])
	elif current_pattern == NEEDLES:
		var points := PackedVector2Array()
		for i in range(-2, 3) if phase == 2 else range(-1, 2):
			points.append(Vector2(0, -56))
			points.append(Vector2(0, -56) + _aim.rotated(i * 0.24) * 550)
		warning_line.points = points
	else:
		warning_line.points = PackedVector2Array([Vector2(-450, 54), Vector2(450, 54)])

func _fire_needles() -> void:
	needle_count += 1
	for i in range(-2, 3) if phase == 2 else range(-1, 2):
		var shot := PROJECTILE.instantiate() as EnemySeedProjectile
		shot.configure("%s:needles:%d:%d" % [attack_life_key(), needle_count, i], _aim.rotated(i * 0.24), 12 if phase == 2 else 9, 6.0 if phase == 2 else 4.8, 12.0)
		shot.attacker_id = attacker_id
		shot.attack_id = &"heart_needles"
		shot.damage_tags = PackedStringArray(["enemy", "boss", "heart", "projectile"])
		get_tree().current_scene.add_child(shot)
		shot.projectile_sprite.texture = NEEDLE_TEXTURE
		shot.global_position = global_position + Vector2(0, -56)

func _fire_beam() -> void:
	beam_count += 1
	_beam_flash_s = 0.15
	if player == null or not player.can_continue_combat_action() or player.global_position.x < ARENA_LEFT or player.global_position.x > ARENA_RIGHT or absf(player.global_position.y - 42 - _beam_y) > 30: return
	var event := DamageEvent.new()
	event.event_id = StringName("%s:beam:%d" % [attack_life_key(), beam_count])
	event.attacker_id = attacker_id
	event.attack_id = &"heart_memory_beam"
	event.damage = 20 if phase == 2 else 16
	event.tags = PackedStringArray(["enemy", "boss", "heart", "beam"])
	event.source_position = global_position
	var evading := player.invincible
	var result := player.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED: hit_count += 1
	elif evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
		if ultimate != null: ultimate.register_precise_evade()

func _adjust_damage_event(event: DamageEvent) -> DamageEvent:
	var adjusted := super._adjust_damage_event(event)
	last_damage_multiplier = 1.5 if state == State.RECOVERY and (event.tags.has("sword") or event.tags.has("bow")) else 1.0
	last_adjusted_damage = maxi(1, roundi(event.damage * last_damage_multiplier))
	adjusted.damage = last_adjusted_damage
	return adjusted

func pattern_name(pattern: int) -> String:
	return "지면 맥박" if pattern == Pattern.SHOCKWAVE else "슬픔의 바늘" if pattern == NEEDLES else "기억 절단" if pattern == BEAM else "없음"

func warning_feedback_snapshot() -> Dictionary:
	return {"color": Color("ffd166") if current_pattern == NEEDLES else Color("f78984"), "shape": "부채" if current_pattern == NEEDLES else "수평선" if current_pattern == BEAM else "지면 파문", "uses_color_and_shape": true}

func _set_state(new_state: int, message: String) -> void:
	if new_state in [State.DEAD, State.PHASE_TRANSITION]: _beam_flash_s = 0
	super._set_state(new_state, message.replace("갑옷 멧돼지", BOSS_NAME).replace("분노", "과부하"))
	_refresh_status()

func _refresh_status() -> void:
	super._refresh_status()
	if status_label != null and damage_receiver != null:
		status_label.text = "%s · %d페이즈\n%d/%d · %s" % [BOSS_NAME, phase, damage_receiver.health, damage_receiver.max_health, state_name()]

func _update_visual() -> void:
	super._update_visual()
	if phase == 2 and not damage_receiver.dead and _hit_flash_remaining_s <= 0: body_sprite.modulate = Color("ffb7a7")

func current_metrics() -> Dictionary:
	var result := super.current_metrics()
	result.enemy_name = BOSS_NAME
	result.elite_weakness = "핵 노출 · 검·활150%" if state == State.RECOVERY else "검·활 정상"
	result.heart_beam_count = beam_count
	result.heart_needle_count = needle_count
	return result
