extends SceneTree

const SANDBOX := preload("res://scenes/movement/ground_movement_sandbox.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sandbox := SANDBOX.instantiate()
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	var controls := sandbox.get_node("CanvasLayer/GroundMovementControls") as Control
	var growth := sandbox.get_node("PrototypeGrowthController") as PrototypeGrowthController
	var player := sandbox.get_node("Player") as PrototypePlayer
	var ultimate := sandbox.get_node("Player/UltimateController") as UltimateController
	var weapons := sandbox.get_node("Player/PrototypeWeaponController") as PrototypeWeaponController
	var runner := sandbox.get_node("StageRunner") as PrototypeStageRunner
	(sandbox.get_node("CombatFeedbackController") as CombatFeedbackController).configure(0.0, false, false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	for job_index in 2:
		for choice_index in 2:
			controls.begin_retry()
			runner.set_stage_enabled(false)
			for ignored in 24:
				if not _check(_valid_pool(growth._draw_cards(), ""), "발현 전 직업 카드 제외·세 후보 고유성"):
					return
			var job_id := "vanguard" if job_index == 0 else "tracker"
			for ignored in 3:
				growth.offered_cards.assign([PrototypeGrowthController.CARDS[job_index].duplicate(true)])
				growth.choosing = true
				sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
				growth.choose_card(0)
			ultimate.gauge = 76
			_tap(controls, controls.job_confirm_rect.get_center())
			if not _check(paused and growth.awaiting_job_confirmation and not growth.acknowledge_job() and not growth.choose_job_ultimate(-1) and not growth.choose_job_ultimate(2), "선택 전 확인·범위 밖 선택 차단"):
				return
			for viewport_size in [Vector2(1280, 720), Vector2(2400, 1080)]:
				controls.size = viewport_size
				controls._refresh_job_layout()
				var layout: Dictionary = controls.layout_snapshot()
				var safe: Rect2 = layout["safe"]
				var panel: Rect2 = layout["job_panel"]
				if not _check(safe.encloses(panel) and panel.encloses(layout["job_confirm"]) and panel.encloses(controls.job_ultimate_rects[0]) and panel.encloses(controls.job_ultimate_rects[1]) and not controls.job_ultimate_rects[0].intersects(controls.job_ultimate_rects[1]), "두 화면 비율 필살기 후보 안전 영역·비중첩"):
					return
			_tap(controls, controls.job_ultimate_rects[1 - choice_index].get_center())
			_tap(controls, controls.job_ultimate_rects[choice_index].get_center())
			controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
			controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
			if not _check(paused and controls.selected_job_ultimate == choice_index and ultimate.selected_profile.is_empty(), "확정 전 변경·앱 복귀 선택 보존"):
				return
			_tap(controls, controls.job_confirm_rect.get_center())
			var expected := PrototypeJobRewards.ultimates_for(job_id)[choice_index]
			if not _check(not paused and ultimate.selected_profile["id"] == expected["id"] and ultimate.gauge == 76 and not growth.choose_job_ultimate(1 - choice_index) and not ultimate.select_job_ultimate(job_id, String(expected["id"])), "확정 터치·게이지 보존·도전 중 재선택 차단"):
				return
			# 직업은 고정되어 반대 무기로 바꾸어도 관련 슬롯은 직업 카드다.
			weapons.active_weapon_id = "bow" if job_index == 0 else "sword"
			for ignored in 48:
				if not _check(_valid_pool(growth._draw_cards(), job_id), "발현 후 직업 보장·공용 보장·다른 직업 제외"):
					return
			growth.experience = 20
			growth._offer_next_level()
			var previous := growth.offered_cards.duplicate(true)
			if not _check(growth.reroll() and growth.offered_cards != previous and _valid_pool(growth.offered_cards, job_id), "직업 풀 재추첨·후보 변경"):
				return
			growth.choose_card(0)
			# 각 전용 카드의 실제 피해·체력·랭크 누적을 확인한다.
			for card in PrototypeJobRewards.cards_for(job_id):
				var before_damage := player.growth_damage(100, "sword" if job_index == 0 else "bow")
				var before_max := player.damage_receiver.max_health
				player.damage_receiver.health = 20
				growth.offered_cards.assign([card])
				growth.choosing = true
				sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
				growth.choose_card(0)
				if String(card["id"]) in ["vanguard_edge", "tracker_focus"]:
					if not _check(player.growth_damage(100, "sword" if job_index == 0 else "bow") == before_damage + 20, "전용 공격 카드 실제 피해 증가"):
						return
				elif not _check(player.damage_receiver.max_health == before_max + (30 if job_index == 0 else 20) and player.damage_receiver.health == (50 if job_index == 0 else 55), "전용 체력 카드 최대·현재 체력 증가"):
					return
				if not _check(int(growth.ranks.get(card["id"], 0)) >= 1, "전용 카드 랭크 기록"):
					return
			# 실제 전투 적을 배치하여 공격형/회복형의 범위·피해·회복을 검증한다.
			player.global_position = Vector2(900, 870)
			player.facing_direction = -1
			var front := sandbox.get_node("Targets/LeafSlime") as PrototypeTarget
			var rear := sandbox.get_node("Targets/SeedSack") as PrototypeTarget
			var far := sandbox.get_node("Targets/WindSpirit") as PrototypeTarget
			var dummy := sandbox.get_node("Targets/RearTarget") as PrototypeTarget
			var camera := player.get_node("Camera2D") as Camera2D
			camera.reset_smoothing()
			camera.force_update_scroll()
			for target in [front, rear, far]:
				target.visible = true
				target.reset_target()
				target.set_process(false)
				target.set_physics_process(false)
				target.damage_receiver.max_health = 1000
				target.damage_receiver.reset()
			front.global_position = player.global_position + Vector2(-120, 0)
			rear.global_position = player.global_position + Vector2(120, 0)
			far.global_position = player.global_position + Vector2(-2000, 0)
			dummy.visible = true
			dummy.global_position = front.global_position
			var dummy_health := dummy.damage_receiver.health
			player.damage_receiver.health = 30
			ultimate.gauge = 100
			ultimate.request_ultimate()
			var duration := float(expected["duration"])
			if not _check(ultimate.gauge == 0 and is_equal_approx(ultimate._remaining_s, duration) and is_equal_approx(front.enemy_time_scale(), float(expected["slow"])) and ultimate.activation_count == 1, "네 후보의 시간·게이지 소비·적 감속"):
				return
			if choice_index == 0:
				var damage := player.growth_damage(int(expected["damage"]), String(expected["weapon"]))
				if not _check(front.damage_receiver.health == 1000 - damage and rear.damage_receiver.health == (1000 - damage if job_index == 0 else 1000) and far.damage_receiver.health == 1000 and dummy.damage_receiver.health == dummy_health and ultimate.last_burst_hits == (2 if job_index == 0 else 1), "실제 피해·방향·사거리·연습 표적 제외"):
					return
			elif not _check(player.damage_receiver.health == 30 + int(expected["heal"]) and front.damage_receiver.health == 1000 and ultimate.last_burst_hits == 0, "회복형 체력 회복·공격 없음"):
				return
			var remaining := ultimate._remaining_s
			growth.experience = growth.next_level_experience()
			growth._offer_next_level()
			await create_timer(0.10, true).timeout
			if not _check(paused and is_equal_approx(remaining, ultimate._remaining_s), "성장 선택 중 직업 필살기 타이머 정지"):
				return
			growth.choose_card(0)
			ultimate.request_ultimate()
			if not _check(ultimate.activation_count == 1, "사용 중 중복 발동 차단"):
				return
			ultimate._physics_process(duration + 0.1)
			if not _check(not ultimate._active and is_equal_approx(front.enemy_time_scale(), 1.0), "시간 종료 후 적 감속 해제"):
				return
			player.damage_receiver.health = player.damage_receiver.max_health - 1
			ultimate.gauge = 100
			ultimate.request_ultimate()
			if not _check(player.damage_receiver.health <= player.damage_receiver.max_health, "회복 최대 체력 상한"):
				return
			ultimate.reset_ultimate()
			if not _check(ultimate.selected_profile.is_empty() and not ultimate._active and ultimate.gauge == 0 and is_equal_approx(front.enemy_time_scale(), 1.0), "직업 필살기 초기화·감속 복구"):
				return
	# 공용 필살기 사용 중 발현해도 진행 중 효과는 원래 3초/15%로 유지된다.
	controls.begin_retry()
	runner.set_stage_enabled(false)
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(ultimate.select_job_ultimate("vanguard", "vanguard_resolve") and ultimate._active_profile.is_empty() and is_equal_approx(ultimate._remaining_s, 3.0), "발현 전 공용 효과 도중 새 프로필 선택 격리"):
		return
	ultimate._finish_ultimate()
	ultimate.gauge = 100
	ultimate.request_ultimate()
	if not _check(is_equal_approx(ultimate._remaining_s, 5.0), "다음 발동부터 선택 프로필 적용"):
		return
	controls.begin_retry()
	if not _check(growth.jobs.job_id.is_empty() and growth.ranks.is_empty() and ultimate.selected_profile.is_empty() and player.growth_damage(100, "sword") == 100 and player.damage_receiver.max_health == 100, "재도전 직업 카드·필살기·체력 초기화"):
		return
	sandbox.free()
	await process_frame
	print("GP-103 runtime test: OK")
	quit(0)


func _valid_pool(cards: Array[Dictionary], job_id: String) -> bool:
	if cards.size() != 3 or cards[1]["category"] != "common":
		return false
	var ids: Array[String] = []
	for card in cards:
		if String(card["id"]) in ids or (card.has("job") and card["job"] != job_id):
			return false
		ids.append(String(card["id"]))
	return cards[0].get("job", "") == job_id if not job_id.is_empty() else cards[0]["category"] != "job"


func _tap(controls: Control, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.pressed = true
	event.position = position
	controls._input(event)


func _check(condition: bool, label: String) -> bool:
	if condition:
		return true
	push_error("GP-103 실패: %s" % label)
	paused = false
	quit(1)
	return false
