extends SceneTree

const SANDBOX_SCENE := preload("res://scenes/movement/ground_movement_sandbox.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/combat/enemy_seed_projectile.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	root.add_child(sandbox)
	await process_frame
	await physics_frame

	var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
	var sword := sandbox.get_node("Player/SwordCombatController") as SwordCombatController
	var player := sandbox.get_node("Player") as PrototypePlayer
	var target := sandbox.get_node("Targets/LeafSlime") as PrototypeEnemy
	var enemy_projectile := ENEMY_PROJECTILE_SCENE.instantiate() as EnemySeedProjectile
	enemy_projectile.configure("cp206:slowdown", Vector2.RIGHT)
	sandbox.add_child(enemy_projectile)
	enemy_projectile.global_position = Vector2(1400.0, 500.0)

	for _index in 25:
		sword.hit_registered.emit(false, target, 12)
	if not _assert_equal(ultimate.gauge, 100, "기본 공격 25회로 게이지 100"):
		return

	ultimate.request_ultimate()
	await physics_frame
	if not _assert_equal(ultimate.gauge, 0, "발동 시 게이지 소모"):
		return
	if not _assert_near(target.enemy_time_scale(), 0.15, "적 시간 15%"):
		return
	if not _assert_near(enemy_projectile.enemy_time_scale, 0.15, "적 투사체 시간 15%"):
		return
	if not _assert_near(Engine.time_scale, 1.0, "전역·플레이어 시간 100%"):
		return

	await create_timer(3.15).timeout
	await physics_frame
	if not _assert_near(target.enemy_time_scale(), 1.0, "적 시간 정상화"):
		return
	if not _assert_near(enemy_projectile.enemy_time_scale, 1.0, "적 투사체 시간 정상화"):
		return

	ultimate.reset_ultimate()
	player.invincible = true
	ultimate.register_precise_evade()
	if not _assert_equal(ultimate.gauge, 12, "정확한 회피 게이지 12"):
		return
	player.invincible = false

	print("CP-206 runtime test: OK")
	quit(0)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> bool:
	if actual == expected:
		return true
	push_error("%s 실패: actual=%s expected=%s" % [label, actual, expected])
	quit(1)
	return false


func _assert_near(actual: float, expected: float, label: String) -> bool:
	if is_equal_approx(actual, expected):
		return true
	push_error("%s 실패: actual=%.3f expected=%.3f" % [label, actual, expected])
	quit(1)
	return false
