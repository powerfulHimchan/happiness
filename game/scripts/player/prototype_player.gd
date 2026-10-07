class_name PrototypePlayer
extends CharacterBody2D

## CP-202 이동 액션 위 공통 피해·피격·사망 모델.
## 100 px를 1 m로 환산해 기획 수치를 물리 좌표에 적용한다.

signal movement_metrics_changed(metrics: Dictionary)
signal fall_recovery_started
signal player_died
signal evade_started
signal damage_received(event: DamageEvent)
signal phoenix_revived

enum MobilityAction {
	NONE,
	GROUND_EVADE,
	AIR_DASH,
}

const PIXELS_PER_METER := 100.0
const MAX_SPEED_MPS := 5.5
const ACCELERATION_MPS2 := 40.0
const DECELERATION_MPS2 := 45.0
const TURN_ACCELERATION_MPS2 := 60.0
const GRAVITY_MPS2 := 28.0
const MAX_JUMP_HEIGHT_M := 2.2
const JUMP_SPEED_MPS := 11.1
const JUMP_RELEASE_VELOCITY_MULTIPLIER := 0.48
const COYOTE_TIME_S := 0.10
const JUMP_BUFFER_S := 0.12
const GROUND_EVADE_SPEED_MPS := 9.0
const GROUND_EVADE_DURATION_S := 0.24
const GROUND_EVADE_INVINCIBLE_S := 0.18
const GROUND_EVADE_COOLDOWN_S := 0.45
const AIR_DASH_SPEED_MPS := 9.5
const AIR_DASH_DURATION_S := 0.18
const MAX_HEALTH := 100
const POTIONS_PER_RUN := 2
const POTION_HEAL_RATIO := 0.25
const FALL_DAMAGE_RATIO := 0.10
const FALL_BOUNDARY_Y := 1160.0
const FALL_RECOVERY_DELAY_S := 0.45
const RESPAWN_INPUT_LOCK_S := 0.20
const POST_HIT_FLASH_S := 0.12
const INPUT_DEAD_ZONE := 0.18
const STOP_EPSILON_MPS := 0.02

var memory_id: String = ""
var potions_remaining: int = POTIONS_PER_RUN
var potion_log: String = "회복약 · 최대 체력 25% 회복"
var potion_recipe: String = PrototypePotionRecipes.BASIC
var potion_pouch_unlocked: bool = false
var relic_state: Dictionary = {}
var relic_run_id: String = ""
var phoenix_allowed: Callable
var boss_legacy: Dictionary = {}
var boss_legacy_store := BossLegacyStore.new()

const BARRIER_CAPACITY := 20
var barrier_unlocked: bool = false

const LIFESTEAL_DAMAGE_PER_HEALTH := 20
var lifesteal_unlocked: bool = false
var lifesteal_branch: String = ""
var lifesteal_progress: int = 0
var lifesteal_allowed: Callable
var _lifesteal_flash_remaining_s: float = 0.0
var growth_common_bonus: float = 0.0
var growth_sword_bonus: float = 0.0
var growth_bow_bonus: float = 0.0
var weapon_equipment: Dictionary = {"sword": 0, "bow": 0}
var weapon_blueprints: Dictionary = {"sword": "", "bow": ""}
var job_emblem_id: String = ""
var job_emblem_color := Color.WHITE
var move_input: float = 0.0
var move_input_vector: Vector2 = Vector2.ZERO
var facing_direction: int = 1
var stop_test_passed: bool = false
var reversal_test_passed: bool = false
var last_stop_time_s: float = 0.0
var last_stop_distance_m: float = 0.0
var double_jump_unlocked: bool = false
var air_jump_available: bool = false
var double_jump_count: int = 0
var _air_jump_flash_remaining_s: float = 0.0
var _air_jump_flash_position := Vector2.ZERO
var jump_held: bool = false
var jump_count: int = 0
var last_jump_height_m: float = 0.0
var last_jump_assist: String = "대기"
var invincible: bool = false
var air_dash_available: bool = true
var nimble_evade_unlocked: bool = false
var ground_evade_count: int = 0
var air_dash_count: int = 0
var last_mobility_result: String = "대기"
var last_invincibility_log: String = "무적 로그 대기"
var fall_count: int = 0
var last_fall_damage: int = 0
var last_fall_log: String = "낙하 기록 대기"
var last_safe_position: Vector2 = Vector2(960.0, 780.0)
var last_safe_label: String = "시작 지점"
var last_damage_log: String = "피해 기록 대기"
var last_damage_summary: String = "없음"
var last_damage_tags: String = "없음"
var last_stagger_s: float = 0.0
var damage_cause_counts: Dictionary = {}
var combat_evade_allowed: bool = true
var _stop_test_active: bool = false
var _stop_elapsed_s: float = 0.0
var _stop_distance_px: float = 0.0
var _last_input_sign: int = 0
var _reversal_test_active: bool = false
var _reversal_target_sign: int = 0
var _last_position_x: float = 0.0
var _coyote_remaining_s: float = 0.0
var _jump_buffer_remaining_s: float = 0.0
var _jump_requested_airborne: bool = false
var _jump_in_progress: bool = false
var _jump_start_y: float = 0.0
var _jump_peak_height_m: float = 0.0
var _mobility_action: int = MobilityAction.NONE
var _mobility_direction: Vector2 = Vector2.RIGHT
var _mobility_remaining_s: float = 0.0
var _invincible_remaining_s: float = 0.0
var _evade_cooldown_remaining_s: float = 0.0
var _invincibility_start_frame: int = -1
var _invincibility_end_frame: int = -1
var _fall_recovery_active: bool = false
var _fall_recovery_remaining_s: float = 0.0
var _input_lock_remaining_s: float = 0.0
var _hit_flash_remaining_s: float = 0.0
var _combat_action_active: bool = false
var _combat_horizontal_velocity_px: float = 0.0
var _combat_move_allowed: bool = true
var _combat_turn_allowed: bool = true

@onready var avatar: Node2D = $Avatar
@onready var avatar_sprite: Sprite2D = $Avatar/Sprite2D
@onready var damage_receiver: DamageReceiver = $DamageReceiver


func _ready() -> void:
	add_to_group("prototype_player")
	_last_position_x = global_position.x
	_emit_metrics()


func _physics_process(delta: float) -> void:
	if _lifesteal_flash_remaining_s > 0.0:
		_lifesteal_flash_remaining_s = maxf(0.0, _lifesteal_flash_remaining_s - delta)
		queue_redraw()
	if _air_jump_flash_remaining_s > 0.0:
		_air_jump_flash_remaining_s = maxf(0.0, _air_jump_flash_remaining_s - delta)
		queue_redraw()
	damage_receiver.tick(delta)
	_hit_flash_remaining_s = maxf(0.0, _hit_flash_remaining_s - delta)
	if damage_receiver.dead:
		velocity = Vector2.ZERO
		_update_avatar_action_visual()
		_emit_metrics()
		return

	if _fall_recovery_active:
		_update_fall_recovery(delta)
		_update_avatar_action_visual()
		_emit_metrics()
		return

	_input_lock_remaining_s = maxf(0.0, _input_lock_remaining_s - delta)
	if global_position.y >= FALL_BOUNDARY_Y:
		_begin_fall_recovery()
		_emit_metrics()
		return

	var grounded_at_start := is_on_floor()
	_update_mobility_timers(delta)
	if grounded_at_start:
		air_dash_available = true
		air_jump_available = double_jump_unlocked
	_update_jump_windows(delta, grounded_at_start)

	if _mobility_action == MobilityAction.NONE and not _combat_action_active:
		_try_execute_jump(grounded_at_start)
		_apply_standard_movement(delta, grounded_at_start)
	elif _mobility_action == MobilityAction.NONE:
		_apply_combat_action_movement(delta, grounded_at_start)
	else:
		_apply_mobility_velocity()

	move_and_slide()
	if global_position.y >= FALL_BOUNDARY_Y:
		_begin_fall_recovery()
		_emit_metrics()
		return
	if not grounded_at_start and is_on_floor():
		air_dash_available = true
		air_jump_available = double_jump_unlocked
		if _mobility_action == MobilityAction.AIR_DASH:
			_finish_mobility_action()
	_update_jump_metrics(grounded_at_start)
	_update_movement_tests(delta)
	_update_avatar_action_visual()
	_emit_metrics()


func set_move_vector(input_vector: Vector2) -> void:
	if _is_input_locked():
		move_input = 0.0
		move_input_vector = Vector2.ZERO
		return
	move_input_vector = _apply_vector_dead_zone(input_vector.limit_length(1.0))
	var new_input := move_input_vector.x
	var new_sign := _direction_sign(new_input)

	if new_sign != 0 and (not _combat_action_active or _combat_turn_allowed):
		if _last_input_sign != 0 and new_sign != _last_input_sign \
			and _direction_sign(velocity.x) == _last_input_sign:
			_reversal_test_active = true
			_reversal_target_sign = new_sign
		if facing_direction != new_sign:
			facing_direction = new_sign
			avatar_sprite.flip_h = facing_direction < 0
		_last_input_sign = new_sign

	if absf(new_input) <= 0.001 and absf(move_input) > 0.001 \
		and absf(velocity.x) >= PIXELS_PER_METER:
		_stop_test_active = true
		_stop_elapsed_s = 0.0
		_stop_distance_px = 0.0
	elif absf(new_input) > 0.001:
		_stop_test_active = false

	move_input = new_input


func request_jump() -> void:
	if _is_input_locked() or _combat_action_active:
		return
	jump_held = true
	_jump_buffer_remaining_s = JUMP_BUFFER_S
	_jump_requested_airborne = not is_on_floor()


func release_jump() -> void:
	jump_held = false
	if velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_VELOCITY_MULTIPLIER


func request_evade() -> void:
	if _is_input_locked():
		last_mobility_result = "복귀 중 입력 잠금"
		return
	if _mobility_action != MobilityAction.NONE:
		last_mobility_result = "동작 중 입력 무시"
		return
	if not combat_evade_allowed:
		last_mobility_result = "공격 취소 불가 구간"
		return

	if is_on_floor():
		if _evade_cooldown_remaining_s > 0.0:
			last_mobility_result = "지상 회피 재사용 대기"
			return
		_start_ground_evade()
		return

	if not air_dash_available:
		last_mobility_result = "공중 대시 사용 완료"
		return
	_start_air_dash()


func set_safe_spawn(spawn_position: Vector2, safe_label: String) -> void:
	if _fall_recovery_active or spawn_position.y >= FALL_BOUNDARY_Y:
		return
	last_safe_position = spawn_position
	last_safe_label = safe_label


func can_use_combat_action() -> bool:
	return not _is_input_locked() and _mobility_action == MobilityAction.NONE


func can_switch_weapon() -> bool:
	return not _is_input_locked() \
		and _mobility_action == MobilityAction.NONE \
		and not _combat_action_active


func can_continue_combat_action() -> bool:
	return not damage_receiver.dead \
		and not _fall_recovery_active \
		and _input_lock_remaining_s <= 0.0


func begin_combat_action(
	horizontal_velocity_px: float,
	can_move: bool,
	can_turn: bool
) -> void:
	_combat_action_active = true
	_combat_horizontal_velocity_px = horizontal_velocity_px
	_combat_move_allowed = can_move
	_combat_turn_allowed = can_turn


func end_combat_action() -> void:
	_combat_action_active = false
	_combat_horizontal_velocity_px = 0.0
	_combat_move_allowed = true
	_combat_turn_allowed = true


func set_combat_evade_allowed(allowed: bool) -> void:
	combat_evade_allowed = allowed


func ground_evade_cooldown_s() -> float:
	return GROUND_EVADE_COOLDOWN_S * (0.8 if nimble_evade_unlocked else 1.0)


func set_nimble_evade_unlocked(enabled: bool) -> void:
	# 선택 전에 시작한 회피의 남은 대기시간은 바꾸지 않는다.
	nimble_evade_unlocked = enabled
	_emit_metrics()


func set_barrier_unlocked(enabled: bool) -> void:
	barrier_unlocked = enabled
	damage_receiver.barrier_health = BARRIER_CAPACITY if enabled else 0
	queue_redraw()
	_emit_metrics()


func recharge_barrier() -> void:
	if barrier_unlocked and not damage_receiver.dead:
		damage_receiver.barrier_health = BARRIER_CAPACITY
		queue_redraw()
		_emit_metrics()


func receive_damage(event: DamageEvent) -> int:
	# 원본 이벤트는 공유될 수 있으므로 핵의 위험 보상은 복사본에만 적용한다.
	if event != null and boss_legacy.get("choice") == "destroy":
		var incoming := DamageEvent.new()
		incoming.event_id = event.event_id
		incoming.attacker_id = event.attacker_id
		incoming.attack_id = event.attack_id
		incoming.damage = roundi(event.damage * 1.10)
		incoming.stagger_s = event.stagger_s
		incoming.tags = event.tags.duplicate()
		incoming.source_position = event.source_position
		event = incoming
	var result := damage_receiver.try_receive(event, invincible or _fall_recovery_active)
	if result == DamageReceiver.Result.APPLIED and damage_receiver.dead:
		_try_phoenix_revival()
	if result == DamageReceiver.Result.APPLIED and damage_receiver.last_health_damage > 0 and not damage_receiver.dead and damage_receiver.health <= floori(damage_receiver.max_health * 0.25) and boss_legacy_store.spend_rescue(boss_legacy):
		apply_growth_health(0, ceili(damage_receiver.max_health * 0.30))
	last_damage_summary = event.summary() if event != null else "잘못된 이벤트"
	last_damage_tags = ", ".join(event.tags) if event != null else "없음"
	last_stagger_s = event.stagger_s if event != null else 0.0
	last_damage_log = "%s · %s · HP %d/%d" % [
		DamageReceiver.result_name(result),
		String(event.event_id) if event != null else "ID 없음",
		damage_receiver.health,
		damage_receiver.max_health,
	]

	if result == DamageReceiver.Result.APPLIED:
		var cause := _damage_cause_label(event)
		damage_cause_counts[cause] = int(damage_cause_counts.get(cause, 0)) + 1
		_hit_flash_remaining_s = POST_HIT_FLASH_S
		_input_lock_remaining_s = maxf(_input_lock_remaining_s, event.stagger_s)
		move_input = 0.0
		move_input_vector = Vector2.ZERO
		damage_received.emit(event)
		if damage_receiver.dead:
			_cancel_actions_for_recovery()
			velocity = Vector2.ZERO
			player_died.emit()
	queue_redraw()
	_emit_metrics()
	return result


func skill_recharge_multiplier() -> float:
	return PrototypeRelic.CLOCK_RECHARGE_MULTIPLIER if relic_state.get("id", "") == PrototypeRelic.CLOCK_ID and relic_state.get("used", false) == false else 1.0


func _try_phoenix_revival() -> bool:
	if not damage_receiver.dead or relic_state.get("id", "") != PrototypeRelic.PHOENIX_ID or relic_state.used or relic_run_id.is_empty() \
	or not phoenix_allowed.is_valid() or not phoenix_allowed.call():
		return false
	if boss_legacy_store.phoenix_used(relic_run_id):
		relic_state.used = true
		return false
	if boss_legacy_store.spend_phoenix(relic_run_id) != OK:
		return false
	relic_state.used = true
	damage_receiver.revive_with_health(ceili(damage_receiver.max_health * PrototypeRelic.HEAL_RATIO), PrototypeRelic.INVULNERABLE_S)
	_cancel_actions_for_recovery()
	velocity = Vector2.ZERO
	_input_lock_remaining_s = 0.20
	phoenix_revived.emit()
	return true


func set_job_emblem(job_id: String, color: Color) -> void:
	job_emblem_id = job_id
	job_emblem_color = color
	queue_redraw()


func _draw() -> void:
	if barrier_unlocked and damage_receiver.barrier_health > 0 and not damage_receiver.dead:
		draw_arc(Vector2(0, -38), 58.0, -PI * 0.5, -PI * 0.5 + TAU * float(damage_receiver.barrier_health) / BARRIER_CAPACITY, 48, Color("82dcec", 0.75), 4.0, true)
	if _lifesteal_flash_remaining_s > 0.0:
		draw_arc(Vector2(0, -30), 65.0, 0.0, TAU, 32, Color(0.4, 1.0, 0.65, _lifesteal_flash_remaining_s / 0.20), 5.0, true)
	if _air_jump_flash_remaining_s > 0.0:
		var progress := 1.0 - _air_jump_flash_remaining_s / 0.18
		var center := to_local(_air_jump_flash_position)
		draw_arc(center, 22.0 + progress * 25.0, 0.0, TAU, 24, Color(0.56, 0.92, 1.0, 1.0 - progress), 4.0, true)
		draw_line(center + Vector2(-20, 8), center + Vector2(-8, 16), Color("9be8f2"), 3.0, true)
		draw_line(center + Vector2(20, 8), center + Vector2(8, 16), Color("9be8f2"), 3.0, true)
	if job_emblem_id.is_empty():
		return
	# 색뿐 아니라 선봉대의 마름모와 추적자의 원형 표식으로 구분한다.
	var center := Vector2(0.0, -160.0)
	if job_emblem_id == "vanguard":
		var points := PackedVector2Array([center + Vector2(0, -18), center + Vector2(16, 0), center + Vector2(0, 18), center + Vector2(-16, 0), center + Vector2(0, -18)])
		draw_polyline(points, job_emblem_color, 4.0, true)
	else:
		draw_arc(center, 17.0, 0.0, TAU, 24, job_emblem_color, 4.0, true)
		draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), job_emblem_color, 3.0)
		draw_line(center + Vector2(0, -8), center + Vector2(0, 8), job_emblem_color, 3.0)


func growth_damage(base_damage: int, weapon_id: String, kind: String = "basic") -> int:
	var weapon_bonus := growth_sword_bonus if weapon_id == "sword" else growth_bow_bonus
	return roundi(float(base_damage) * (1.0 + growth_common_bonus + weapon_bonus) * PrototypeWeaponRewards.damage_multiplier(weapon_equipment, weapon_id, kind, weapon_blueprints) * (1.10 if boss_legacy.get("choice") == "destroy" else 1.0) * PrototypeMemoryAbilities.damage_multiplier(memory_id, kind))


func apply_growth_health(maximum_bonus: int, healing: int) -> void:
	if damage_receiver.dead:
		return
	damage_receiver.max_health += maximum_bonus
	damage_receiver.health = mini(damage_receiver.max_health, damage_receiver.health + healing)
	_emit_metrics()


func use_recovery_potion() -> bool:
	if _is_input_locked() or potions_remaining <= 0 or damage_receiver.health >= damage_receiver.max_health:
		return false
	var before := damage_receiver.health
	potions_remaining -= 1
	var recipe := PrototypePotionRecipes.profile(potion_recipe)
	apply_growth_health(0, ceili(damage_receiver.max_health * float(recipe.ratio)))
	potion_log = "%s +%d · 남은 %d회" % [recipe.name, damage_receiver.health - before, potions_remaining]
	_emit_metrics()
	return true


func prepare_potions(id: String, remaining: int = -1) -> void:
	potion_recipe = id if PrototypePotionRecipes.valid_id(id) else PrototypePotionRecipes.BASIC
	var recipe := PrototypePotionRecipes.profile(potion_recipe)
	potions_remaining = potions_capacity() if remaining < 0 else clampi(remaining, 0, potions_capacity())
	potion_log = "%s · 최대 %d개 · 체력 %d%% · 남은 %d회" % [recipe.name, potions_capacity(), roundi(float(recipe.ratio) * 100), potions_remaining]
	_emit_metrics()


func potions_capacity() -> int:
	return int(PrototypePotionRecipes.profile(potion_recipe).count) + (1 if potion_pouch_unlocked else 0)


func set_potion_pouch_unlocked(enabled: bool, refill: bool = false) -> void:
	var newly_unlocked: bool = enabled and not potion_pouch_unlocked
	potion_pouch_unlocked = enabled
	potions_remaining = mini(potions_remaining, potions_capacity())
	if newly_unlocked and refill and not damage_receiver.dead:
		potions_remaining = mini(potions_capacity(), potions_remaining + 1)
		potion_log = "회복약 주머니 · 1개 보충 · 남은 %d/%d" % [potions_remaining, potions_capacity()]
	_emit_metrics()


func collect_recovery_orb() -> bool:
	if _is_input_locked() or damage_receiver.health >= damage_receiver.max_health:
		return false
	apply_growth_health(0, ceili(damage_receiver.max_health * RecoveryOrbController.HEAL_RATIO))
	return true


func feedback_snapshot() -> Dictionary:
	return {
		"hit_flash_remaining_s": _hit_flash_remaining_s,
		"post_hit_invulnerable": damage_receiver.is_post_hit_invulnerable(),
		"health": damage_receiver.health,
	}


func prepare_next_stage(spawn_position: Vector2) -> void:
	# 런 성장·체력·피격 집계는 보존하고 이동·낙하·행동 상태만 정리한다.
	_cancel_actions_for_recovery()
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing_direction = 1
	avatar_sprite.flip_h = false
	air_dash_available = true
	air_jump_available = double_jump_unlocked
	_coyote_remaining_s = 0.0
	_jump_start_y = spawn_position.y
	_jump_peak_height_m = 0.0
	_last_position_x = spawn_position.x
	_last_input_sign = 0
	_stop_test_active = false
	_reversal_test_active = false
	_fall_recovery_active = false
	_fall_recovery_remaining_s = 0.0
	_input_lock_remaining_s = 0.0
	last_safe_position = spawn_position
	last_safe_label = "시작 평지"
	(get_node("Camera2D") as Camera2D).reset_smoothing()
	_emit_metrics()


func reset_movement_test(spawn_position: Vector2) -> void:
	nimble_evade_unlocked = false
	barrier_unlocked = false
	damage_receiver.barrier_health = 0
	lifesteal_unlocked = false
	lifesteal_branch = ""
	lifesteal_progress = 0
	_lifesteal_flash_remaining_s = 0.0
	double_jump_unlocked = false
	air_jump_available = false
	double_jump_count = 0
	_air_jump_flash_remaining_s = 0.0
	queue_redraw()
	relic_state = {}
	relic_run_id = ""
	potions_remaining = POTIONS_PER_RUN
	potion_log = "회복약 · 최대 체력 25% 회복"
	potion_recipe = PrototypePotionRecipes.BASIC
	potion_pouch_unlocked = false
	memory_id = ""
	boss_legacy = {}
	set_job_emblem("", Color.WHITE)
	growth_common_bonus = 0.0
	growth_sword_bonus = 0.0
	growth_bow_bonus = 0.0
	weapon_equipment = {"sword": 0, "bow": 0}
	weapon_blueprints = {"sword": "", "bow": ""}
	damage_receiver.max_health = MAX_HEALTH
	global_position = spawn_position
	velocity = Vector2.ZERO
	move_input = 0.0
	move_input_vector = Vector2.ZERO
	facing_direction = 1
	avatar_sprite.flip_h = false
	jump_held = false
	jump_count = 0
	last_jump_height_m = 0.0
	last_jump_assist = "대기"
	invincible = false
	air_dash_available = true
	ground_evade_count = 0
	air_dash_count = 0
	last_mobility_result = "대기"
	last_invincibility_log = "무적 로그 대기"
	damage_receiver.reset()
	fall_count = 0
	last_fall_damage = 0
	last_fall_log = "낙하 기록 대기"
	last_safe_position = spawn_position
	last_safe_label = "시작 지점"
	last_damage_log = "피해 기록 대기"
	last_damage_summary = "없음"
	last_damage_tags = "없음"
	last_stagger_s = 0.0
	damage_cause_counts.clear()
	stop_test_passed = false
	reversal_test_passed = false
	last_stop_time_s = 0.0
	last_stop_distance_m = 0.0
	_stop_test_active = false
	_stop_elapsed_s = 0.0
	_stop_distance_px = 0.0
	_last_input_sign = 0
	_reversal_test_active = false
	_reversal_target_sign = 0
	_last_position_x = global_position.x
	_coyote_remaining_s = 0.0
	_jump_buffer_remaining_s = 0.0
	_jump_requested_airborne = false
	_jump_in_progress = false
	_jump_start_y = global_position.y
	_jump_peak_height_m = 0.0
	_mobility_action = MobilityAction.NONE
	_mobility_direction = Vector2.RIGHT
	_mobility_remaining_s = 0.0
	_invincible_remaining_s = 0.0
	_evade_cooldown_remaining_s = 0.0
	_invincibility_start_frame = -1
	_invincibility_end_frame = -1
	_fall_recovery_active = false
	_fall_recovery_remaining_s = 0.0
	_input_lock_remaining_s = 0.0
	_hit_flash_remaining_s = 0.0
	combat_evade_allowed = true
	end_combat_action()
	avatar.visible = true
	avatar_sprite.modulate = Color.WHITE
	_emit_metrics()


func _apply_standard_movement(delta: float, grounded: bool) -> void:
	var target_speed_px := move_input * MAX_SPEED_MPS * PIXELS_PER_METER
	var rate_mps2 := _movement_rate_mps2(target_speed_px)
	velocity.x = move_toward(
		velocity.x,
		target_speed_px,
		rate_mps2 * PIXELS_PER_METER * delta
	)

	if absf(move_input) <= 0.001 \
		and absf(velocity.x) < STOP_EPSILON_MPS * PIXELS_PER_METER:
		velocity.x = 0.0

	if not grounded or velocity.y < 0.0:
		velocity.y += GRAVITY_MPS2 * PIXELS_PER_METER * delta
	else:
		velocity.y = minf(velocity.y, 0.0)


func _apply_combat_action_movement(delta: float, grounded: bool) -> void:
	if not _combat_move_allowed or not is_zero_approx(_combat_horizontal_velocity_px):
		velocity.x = _combat_horizontal_velocity_px
	else:
		var target_speed_px := move_input * MAX_SPEED_MPS * PIXELS_PER_METER
		velocity.x = move_toward(
			velocity.x,
			target_speed_px,
			ACCELERATION_MPS2 * PIXELS_PER_METER * delta
		)
	if not grounded or velocity.y < 0.0:
		velocity.y += GRAVITY_MPS2 * PIXELS_PER_METER * delta
	else:
		velocity.y = minf(velocity.y, 0.0)


func _movement_rate_mps2(target_speed_px: float) -> float:
	if absf(move_input) <= 0.001:
		return DECELERATION_MPS2
	if absf(velocity.x) > STOP_EPSILON_MPS * PIXELS_PER_METER \
		and _direction_sign(velocity.x) != _direction_sign(target_speed_px):
		return TURN_ACCELERATION_MPS2
	return ACCELERATION_MPS2


func _apply_dead_zone(axis: float) -> float:
	var magnitude := absf(axis)
	if magnitude <= INPUT_DEAD_ZONE:
		return 0.0
	var normalized := (magnitude - INPUT_DEAD_ZONE) / (1.0 - INPUT_DEAD_ZONE)
	return signf(axis) * clampf(normalized, 0.0, 1.0)


func _apply_vector_dead_zone(input_vector: Vector2) -> Vector2:
	var magnitude := input_vector.length()
	if magnitude <= INPUT_DEAD_ZONE:
		return Vector2.ZERO
	var normalized_magnitude := (magnitude - INPUT_DEAD_ZONE) / (1.0 - INPUT_DEAD_ZONE)
	return input_vector.normalized() * clampf(normalized_magnitude, 0.0, 1.0)


func _direction_sign(value: float) -> int:
	return int(signf(value))


func _start_ground_evade() -> void:
	var direction := _direction_sign(move_input)
	if direction == 0:
		direction = facing_direction
	facing_direction = direction
	avatar_sprite.flip_h = facing_direction < 0
	_mobility_action = MobilityAction.GROUND_EVADE
	_mobility_direction = Vector2(float(direction), 0.0)
	_mobility_remaining_s = GROUND_EVADE_DURATION_S
	_evade_cooldown_remaining_s = ground_evade_cooldown_s()
	ground_evade_count += 1
	last_mobility_result = "지상 회피"
	_begin_invincibility()
	evade_started.emit()


func _start_air_dash() -> void:
	var direction := move_input_vector
	if direction.length_squared() <= 0.001:
		direction = Vector2(float(facing_direction), 0.0)
	else:
		direction = direction.normalized()
	if absf(direction.x) > 0.05:
		facing_direction = _direction_sign(direction.x)
		avatar_sprite.flip_h = facing_direction < 0
	_mobility_action = MobilityAction.AIR_DASH
	_mobility_direction = direction
	_mobility_remaining_s = AIR_DASH_DURATION_S
	air_dash_available = false
	air_dash_count += 1
	last_mobility_result = "공중 대시"
	evade_started.emit()


func _apply_mobility_velocity() -> void:
	var speed_mps: float = AIR_DASH_SPEED_MPS
	if _mobility_action == MobilityAction.GROUND_EVADE:
		speed_mps = GROUND_EVADE_SPEED_MPS
	velocity = _mobility_direction * speed_mps * PIXELS_PER_METER


func _update_mobility_timers(delta: float) -> void:
	_evade_cooldown_remaining_s = maxf(0.0, _evade_cooldown_remaining_s - delta)
	if _mobility_remaining_s > 0.0:
		_mobility_remaining_s = maxf(0.0, _mobility_remaining_s - delta)
		if _mobility_remaining_s <= 0.0:
			_finish_mobility_action()

	if _invincible_remaining_s > 0.0:
		_invincible_remaining_s = maxf(0.0, _invincible_remaining_s - delta)
		if _invincible_remaining_s <= 0.0:
			_end_invincibility()


func _finish_mobility_action() -> void:
	if _mobility_action == MobilityAction.AIR_DASH:
		velocity.y = 0.0
	_mobility_action = MobilityAction.NONE
	_mobility_remaining_s = 0.0


func _begin_invincibility() -> void:
	invincible = true
	_invincible_remaining_s = GROUND_EVADE_INVINCIBLE_S
	_invincibility_start_frame = int(Engine.get_physics_frames())
	last_invincibility_log = "무적 시작 F%d" % _invincibility_start_frame


func _end_invincibility() -> void:
	invincible = false
	_invincibility_end_frame = int(Engine.get_physics_frames())
	last_invincibility_log = "무적 종료 F%d · %d프레임" % [
		_invincibility_end_frame,
		maxi(0, _invincibility_end_frame - _invincibility_start_frame),
	]


func _update_avatar_action_visual() -> void:
	if damage_receiver.dead:
		avatar_sprite.modulate = Color("647986")
	elif _hit_flash_remaining_s > 0.0:
		avatar_sprite.modulate = (
			Color.WHITE
			if int(Engine.get_physics_frames()) % 4 < 2
			else Color("ff6b6b")
		)
	elif damage_receiver.is_post_hit_invulnerable():
		avatar_sprite.modulate = Color("ffb4a9")
	elif _input_lock_remaining_s > 0.0:
		avatar_sprite.modulate = Color("ff9f8f")
	elif invincible:
		avatar_sprite.modulate = Color("76f4ff")
	elif _mobility_action == MobilityAction.AIR_DASH:
		avatar_sprite.modulate = Color("ffd166")
	else:
		avatar_sprite.modulate = Color.WHITE


func _mobility_action_name() -> String:
	match _mobility_action:
		MobilityAction.GROUND_EVADE:
			return "지상 회피"
		MobilityAction.AIR_DASH:
			return "공중 대시"
	return "일반"


func _begin_fall_recovery() -> void:
	if _fall_recovery_active:
		return
	fall_count += 1
	last_fall_damage = ceili(damage_receiver.max_health * FALL_DAMAGE_RATIO)
	last_fall_damage = damage_receiver.apply_environmental_damage(last_fall_damage, 1)
	last_fall_log = "낙하 %d회 · HP -%d" % [fall_count, last_fall_damage]
	_fall_recovery_active = true
	_fall_recovery_remaining_s = FALL_RECOVERY_DELAY_S
	_input_lock_remaining_s = FALL_RECOVERY_DELAY_S + RESPAWN_INPUT_LOCK_S
	_cancel_actions_for_recovery()
	end_combat_action()
	combat_evade_allowed = true
	velocity = Vector2.ZERO
	avatar.visible = false
	fall_recovery_started.emit()


func _update_fall_recovery(delta: float) -> void:
	_fall_recovery_remaining_s = maxf(0.0, _fall_recovery_remaining_s - delta)
	_input_lock_remaining_s = maxf(0.0, _input_lock_remaining_s - delta)
	if _fall_recovery_remaining_s > 0.0:
		return
	global_position = last_safe_position
	velocity = Vector2.ZERO
	_last_position_x = global_position.x
	_fall_recovery_active = false
	air_dash_available = true
	air_jump_available = double_jump_unlocked
	avatar.visible = true
	last_fall_log = "복귀 %s · HP %d/%d" % [
		last_safe_label,
		damage_receiver.health,
		damage_receiver.max_health,
	]


func _cancel_actions_for_recovery() -> void:
	_lifesteal_flash_remaining_s = 0.0
	_air_jump_flash_remaining_s = 0.0
	queue_redraw()
	move_input = 0.0
	move_input_vector = Vector2.ZERO
	jump_held = false
	_jump_buffer_remaining_s = 0.0
	_jump_requested_airborne = false
	_jump_in_progress = false
	_mobility_action = MobilityAction.NONE
	_mobility_remaining_s = 0.0
	_invincible_remaining_s = 0.0
	invincible = false
	end_combat_action()
	combat_evade_allowed = true


func _is_input_locked() -> bool:
	return damage_receiver.dead or _fall_recovery_active or _input_lock_remaining_s > 0.0


func _recovery_state_name() -> String:
	if _fall_recovery_active:
		return "복귀 대기"
	if _input_lock_remaining_s > 0.0:
		return "입력 잠금"
	return "정상"


func _update_jump_windows(delta: float, grounded: bool) -> void:
	if grounded:
		_coyote_remaining_s = COYOTE_TIME_S
	else:
		_coyote_remaining_s = maxf(0.0, _coyote_remaining_s - delta)
	_jump_buffer_remaining_s = maxf(0.0, _jump_buffer_remaining_s - delta)


func _try_execute_jump(grounded: bool) -> void:
	if _jump_buffer_remaining_s <= 0.0 or _is_input_locked():
		return

	var air_jump := not grounded and _coyote_remaining_s <= 0.0
	if air_jump:
		if not double_jump_unlocked or not air_jump_available:
			return
		air_jump_available = false
		double_jump_count += 1
		_air_jump_flash_remaining_s = 0.18
		_air_jump_flash_position = global_position + Vector2(0, 50)
		queue_redraw()
		last_jump_assist = "공중 도약"
	elif _jump_requested_airborne and grounded:
		last_jump_assist = "착지 버퍼"
	elif not grounded:
		last_jump_assist = "코요테"
	else:
		last_jump_assist = "일반"

	var launch_multiplier := 1.0 if jump_held else JUMP_RELEASE_VELOCITY_MULTIPLIER
	velocity.y = -JUMP_SPEED_MPS * PIXELS_PER_METER * launch_multiplier
	jump_count += 1
	_jump_in_progress = true
	_jump_start_y = global_position.y
	_jump_peak_height_m = 0.0
	_jump_buffer_remaining_s = 0.0
	_coyote_remaining_s = 0.0
	_jump_requested_airborne = false


func _update_jump_metrics(grounded_before_move: bool) -> void:
	if _jump_in_progress and not is_on_floor():
		_jump_peak_height_m = maxf(
			_jump_peak_height_m,
			(_jump_start_y - global_position.y) / PIXELS_PER_METER
		)
	if _jump_in_progress and not grounded_before_move and is_on_floor():
		last_jump_height_m = _jump_peak_height_m
		_jump_in_progress = false


func _jump_state_name() -> String:
	if is_on_floor():
		return "지상"
	if velocity.y < 0.0:
		return "상승"
	return "하강"


func _update_movement_tests(delta: float) -> void:
	var moved_px := absf(global_position.x - _last_position_x)
	_last_position_x = global_position.x

	if _stop_test_active:
		_stop_elapsed_s += delta
		_stop_distance_px += moved_px
		if is_zero_approx(velocity.x):
			_stop_test_active = false
			stop_test_passed = true
			last_stop_time_s = _stop_elapsed_s
			last_stop_distance_m = _stop_distance_px / PIXELS_PER_METER

	if _reversal_test_active and _direction_sign(velocity.x) == _reversal_target_sign:
		_reversal_test_active = false
		reversal_test_passed = true


func _emit_metrics() -> void:
	movement_metrics_changed.emit({
		"speed_mps": velocity.x / PIXELS_PER_METER,
		"target_speed_mps": move_input * MAX_SPEED_MPS,
		"input_axis": move_input,
		"facing": facing_direction,
		"position_m": global_position.x / PIXELS_PER_METER,
		"stop_passed": stop_test_passed,
		"reversal_passed": reversal_test_passed,
		"stop_time_s": last_stop_time_s,
		"stop_distance_m": last_stop_distance_m,
		"jump_state": _jump_state_name(),
		"jump_held": jump_held,
		"double_jump_unlocked": double_jump_unlocked,
		"barrier_unlocked": barrier_unlocked,
		"barrier_health": damage_receiver.barrier_health,
		"barrier_capacity": BARRIER_CAPACITY,
		"barrier_absorbed": damage_receiver.last_absorbed_damage,
		"lifesteal_unlocked": lifesteal_unlocked,
		"lifesteal_branch": lifesteal_branch,
		"lifesteal_rate_percent": lifesteal_multiplier() * 5 if lifesteal_unlocked else 0,
		"lifesteal_progress": lifesteal_progress,
		"air_jump_available": air_jump_available,
		"double_jump_count": double_jump_count,
		"jump_count": jump_count,
		"jump_height_m": _jump_peak_height_m if _jump_in_progress else last_jump_height_m,
		"last_jump_height_m": last_jump_height_m,
		"last_jump_assist": last_jump_assist,
		"coyote_remaining_s": _coyote_remaining_s,
		"jump_buffer_remaining_s": _jump_buffer_remaining_s,
		"mobility_action": _mobility_action_name(),
		"invincible": invincible,
		"invincible_remaining_s": _invincible_remaining_s,
		"evade_cooldown_remaining_s": _evade_cooldown_remaining_s,
		"nimble_evade_unlocked": nimble_evade_unlocked,
		"ground_evade_cooldown_s": ground_evade_cooldown_s(),
		"air_dash_available": air_dash_available,
		"ground_evade_count": ground_evade_count,
		"air_dash_count": air_dash_count,
		"last_mobility_result": last_mobility_result,
		"last_invincibility_log": last_invincibility_log,
		"invincibility_start_frame": _invincibility_start_frame,
		"invincibility_end_frame": _invincibility_end_frame,
		"health": damage_receiver.health,
		"max_health": damage_receiver.max_health,
		"potions_remaining": potions_remaining,
		"potions_capacity": potions_capacity(),
		"potion_heal_percent": roundi(float(PrototypePotionRecipes.profile(potion_recipe).ratio) * 100),
		"potion_recipe": potion_recipe,
		"potion_log": potion_log,
		"skill_recharge_multiplier": skill_recharge_multiplier(),
		"relic_hud": PrototypeRelic.hud(relic_state),
		"relic": relic_state.duplicate(),
		"fall_count": fall_count,
		"last_fall_damage": last_fall_damage,
		"last_fall_log": last_fall_log,
		"last_safe_position": last_safe_position,
		"last_safe_label": last_safe_label,
		"recovery_state": _recovery_state_name(),
		"input_locked": _is_input_locked(),
		"fall_recovery_remaining_s": _fall_recovery_remaining_s,
		"damage_dead": damage_receiver.dead,
		"damage_post_hit_invulnerable": damage_receiver.is_post_hit_invulnerable(),
		"damage_post_hit_remaining_s": damage_receiver.post_hit_remaining_s(),
		"damage_applied_count": damage_receiver.applied_count,
		"damage_duplicate_blocked_count": damage_receiver.duplicate_blocked_count,
		"damage_invulnerable_blocked_count": damage_receiver.invulnerable_blocked_count,
		"damage_dead_blocked_count": damage_receiver.dead_blocked_count,
		"damage_last_result": DamageReceiver.result_name(damage_receiver.last_result),
		"damage_last_event_id": damage_receiver.last_event_id,
		"last_damage_log": last_damage_log,
		"last_damage_summary": last_damage_summary,
		"last_damage_tags": last_damage_tags,
		"last_stagger_s": last_stagger_s,
		"damage_cause_counts": damage_cause_counts.duplicate(),
		"damage_cause_summary": _damage_cause_summary(),
		"combat_action_active": _combat_action_active,
		"combat_evade_allowed": combat_evade_allowed,
	})


func _damage_cause_label(event: DamageEvent) -> String:
	if event == null:
		return "알 수 없는 공격"
	if event.attack_id == &"seed_volley":
		return "씨앗탄"
	if event.attack_id == &"boar_charge":
		return "갑옷 멧돼지 돌진"
	if event.attack_id == &"boar_shockwave":
		return "갑옷 멧돼지 충격파"
	for tag in event.tags:
		if tag not in ["enemy", "contact", "projectile", "elite", "charge", "shockwave", "seed"]:
			return tag
	return String(event.attack_id) if not String(event.attack_id).is_empty() else "알 수 없는 공격"


func _damage_cause_summary() -> String:
	var parts: Array[String] = []
	var keys := damage_cause_counts.keys()
	keys.sort()
	for cause in keys:
		parts.append("%s %d회" % [String(cause), int(damage_cause_counts[cause])])
	if fall_count > 0:
		parts.append("낙하 %d회" % fall_count)
	return "피격 없음" if parts.is_empty() else " · ".join(parts)


func set_double_jump_unlocked(enabled: bool) -> void:
	double_jump_unlocked = enabled
	air_jump_available = enabled
	_emit_metrics()


func set_lifesteal_unlocked(enabled: bool) -> void:
	lifesteal_unlocked = enabled
	if not enabled:
		lifesteal_branch = ""
		lifesteal_progress = 0
		_lifesteal_flash_remaining_s = 0.0
		queue_redraw()
	_emit_metrics()


func set_lifesteal_branch(branch: String) -> void:
	if not lifesteal_unlocked or branch not in ["lifesteal_depth", "lifesteal_crisis"]:
		return
	if not lifesteal_branch.is_empty() and lifesteal_branch != branch:
		return
	lifesteal_branch = branch
	_emit_metrics()


func lifesteal_multiplier() -> int:
	if lifesteal_branch == "lifesteal_depth": return 2
	if lifesteal_branch == "lifesteal_crisis" and damage_receiver.health * 10 <= damage_receiver.max_health * 3: return 3
	return 1


func deal_weapon_damage(target: PrototypeTarget, event: DamageEvent) -> int:
	if not is_instance_valid(target):
		return DamageReceiver.Result.INVALID_EVENT
	# 처치가 레벨업 화면을 열기 전에 공격 순간의 자격을 확보한다.
	var can_absorb: bool = lifesteal_unlocked and not damage_receiver.dead \
		and lifesteal_allowed.is_valid() and lifesteal_allowed.call() \
		and target.is_in_group("combat_enemy") and target.is_visible_in_tree() \
		and event != null and event.attacker_id == &"player" \
		and (event.tags.has("sword") or event.tags.has("bow")) \
		and (event.tags.has("basic") or event.tags.has("skill")) \
		and damage_receiver.health < damage_receiver.max_health
	# 회복으로 문턱을 넘는 타격도 공격 시점의 배율을 한 번만 사용한다.
	var multiplier := lifesteal_multiplier()
	var before := target.damage_receiver.health
	var result := target.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED and can_absorb and not damage_receiver.dead:
		var actual := maxi(0, before - target.damage_receiver.health)
		# 1단위는 체력 1/20이다. 강화 전후와 체력 문턱을 넘을 때 기존 소수를 보존한다.
		lifesteal_progress += actual * multiplier
		var healing := lifesteal_progress / LIFESTEAL_DAMAGE_PER_HEALTH
		lifesteal_progress %= LIFESTEAL_DAMAGE_PER_HEALTH
		var old_health := damage_receiver.health
		apply_growth_health(0, healing)
		if damage_receiver.health > old_health:
			_lifesteal_flash_remaining_s = 0.20
			queue_redraw()
	return result
