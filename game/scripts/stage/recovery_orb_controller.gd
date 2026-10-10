class_name RecoveryOrbController
extends Node2D

## GP-118: 일반 적의 생명당 한 번 드롭을 추첨하고 안전한 지면에 회복 구슬을 놓는다.
const MAX_DROPS_PER_STAGE := 2
const HEAL_RATIO := 0.10
const PICKUP_RADIUS_PX := 76.0
@export_range(0.0, 1.0) var drop_chance: float = 0.20

var rng := RandomNumberGenerator.new()
var orbs: Array[Vector2] = []
var drops: int = 0
var collected: int = 0
var healed: int = 0
var _rolled_lives: Dictionary = {}
var _pulse_s: float = 0.0
var _popup_s: float = 0.0
var _popup_position := Vector2.ZERO
var _popup_amount: int = 0

@onready var sandbox: Node2D = get_parent()
@onready var player: PrototypePlayer = get_node("../Player")
@onready var runner: PrototypeStageRunner = get_node("../StageRunner")

func _ready() -> void:
	rng.randomize()
	runner.stage_reset.connect(reset_stage)
	player.player_died.connect(clear_orbs)
	for enemy in [runner.leaf_slime, runner.seed_sack, runner.wind_spirit]:
		enemy.defeated.connect(_on_enemy_defeated)
	z_index = 5

func reset_stage() -> void:
	clear_orbs()
	drops = 0
	collected = 0
	healed = 0
	_rolled_lives.clear()

func clear_orbs() -> void:
	orbs.clear()
	_popup_s = 0.0
	queue_redraw()

func _on_enemy_defeated(enemy: PrototypeTarget) -> void:
	if not runner.stage_enabled or runner.stage_complete or player.damage_receiver.dead \
	or not sandbox.growth.run_active or sandbox.is_combat_environment_suspended() \
	or enemy not in runner._active_enemies or not enemy.damage_receiver.dead:
		return
	var life := enemy.attack_life_key()
	if _rolled_lives.has(life):
		return
	_rolled_lives[life] = true
	if drops >= MAX_DROPS_PER_STAGE or rng.randf() >= drop_chance:
		return
	orbs.append(drop_position(enemy.global_position))
	drops += 1
	queue_redraw()

func drop_position(origin: Vector2) -> Vector2:
	# 실제 지형 사각형에서 아래쪽 지면을 찾는다. 구덩이 위 처치는 가까운 발판 가장자리로 옮긴다.
	var surfaces: Array[Rect2] = [sandbox.LEFT_FLOOR_RECT, sandbox.RIGHT_FLOOR_RECT, sandbox.PRACTICE_PLATFORM_RECT]
	surfaces.append_array(runner.route_terrain.platforms)
	var best := Vector2.ZERO
	var best_score := INF
	for surface in surfaces:
		if surface.position.y < origin.y - 38.0:
			continue
		var x := clampf(origin.x, surface.position.x + 36.0, surface.end.x - 36.0)
		var point := Vector2(x, surface.position.y - 32.0)
		var score := absf(x - origin.x) * 4.0 + absf(point.y - origin.y)
		if score < best_score:
			best = point
			best_score = score
	return best if is_finite(best_score) else Vector2(clampf(origin.x, 104.0, 3264.0), 808.0)

func _physics_process(delta: float) -> void:
	if not sandbox._can_collect_recovery_orb():
		return
	_pulse_s += delta
	_popup_s = maxf(0.0, _popup_s - delta)
	for index in range(orbs.size() - 1, -1, -1):
		if player.global_position.distance_to(orbs[index]) > player.recovery_orb_pickup_radius():
			continue
		var before := player.damage_receiver.health
		if not player.collect_recovery_orb():
			continue
		_popup_amount = player.damage_receiver.health - before
		_popup_position = player.global_position + Vector2(-48.0, -130.0)
		_popup_s = 1.2
		healed += _popup_amount
		collected += 1
		orbs.remove_at(index)
	queue_redraw()

func _draw() -> void:
	for point in orbs:
		var center := point + Vector2(0, sin(_pulse_s * 4.0) * 4.0)
		if player.orb_magnet_unlocked:
			draw_arc(point, player.recovery_orb_pickup_radius(), 0.0, TAU, 64, Color(0.25, 0.75, 0.45, 0.18), 1.5, true)
		draw_circle(center, 28.0, Color(0.15, 0.65, 0.35, 0.18))
		draw_circle(center, 19.0, Color("28b46b"))
		draw_arc(center, 20.0, 0.0, TAU, 32, Color("f3fff1"), 2.5, true)
		draw_line(center + Vector2(-9, 0), center + Vector2(9, 0), Color.WHITE, 5.0)
		draw_line(center + Vector2(0, -9), center + Vector2(0, 9), Color.WHITE, 5.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-55, -34), pickup_hint(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("174e34"))
	if _popup_s > 0.0:
		var color := Color("176744")
		color.a = minf(1.0, _popup_s * 3.0)
		draw_string(ThemeDB.fallback_font, _popup_position + Vector2(0, -24 * (1.2 - _popup_s)), "체력 +%d" % _popup_amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, color)


func pickup_hint() -> String:
	return "회복 +10%% · 자석 %.2fm" % (player.recovery_orb_pickup_radius() / PrototypePlayer.PIXELS_PER_METER) if player.orb_magnet_unlocked else "회복 +10%"
