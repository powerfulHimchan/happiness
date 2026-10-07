extends "res://tests/gp140_runtime_test.gd"

const GP141_SAVE := "user://gp141_checkpoint.json"
const GP141_META := "user://gp141_meta.jsonl"
const GP141_RECORD := "user://gp141_records.jsonl"
const GP141_BOOK := "user://gp141_abilities.jsonl"

func _run() -> void:
	var phase := OS.get_cmdline_user_args()[0]
	store.save_path = GP141_SAVE
	legacy.save_path = GP141_META
	book.save_path = GP141_BOOK
	if phase in ["seed", "flows"]:
		store.clear_checkpoint()
		for path in [GP141_META, GP141_RECORD, GP141_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP141_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	ultimate = sandbox.get_node("Player/UltimateController")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	_disable_live()
	match phase:
		"seed":
			controls.begin_retry("sword", 5)
			if not await _test_empty_view(): return
			for ignored in 3:
				if not await _choose_earned("sword_power"): return
			if not _finish_stage() or not _check(not controls.open_run_build() and sandbox._claim_weapon_reward(""), "정예 보상/경로 화면에서 진입 차단"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _choose_earned(base_id) or not await _choose_earned(mastery_id): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward("bow"), "두 번째 정예 영웅 보조 활"): return
			_tap(controls.relic_reward_open_rect.get_center())
			if not _check(sandbox._claim_relic_reward(PrototypeRelic.CLOCK_ID), "시계추 실제 선택"): return
			_tap(controls.skill_reward_open_rect.get_center())
			var skill_id: String = controls.skill_reward_offers[0].id
			if not _check(sandbox._claim_skill_reward(skill_id, 0), "실제 스킬 슬롯 교체"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _choose_earned("magic_barrier") or not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "세 번째 정예 실제 방벽 획득"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _choose_earned("lifesteal") or not await _choose_earned("air_jump"): return
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "네 번째 정예 실제 여섯 능력 준비"): return
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 5.5
			ultimate.gauge = 73
			player.damage_receiver.barrier_health = 7
			if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK, "실제 등급/양 스킬 대기/게이지/방벽 저장"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_populated_view(): return
			if not await _test_freeze_and_resume(): return
		"resume":
			if not _check(sandbox.continue_saved_run() and runner.stage_number == 4 and not controls.open_run_build(), "별도 프로세스 이어하기·경로 화면 조회 진입 차단"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not await _test_populated_view(): return
			if not await _test_freeze_and_resume(): return
			if not _finish_stage(): return
			if not _check(runner.awaiting_boss_choice() and not controls.open_run_build(), "실제 보스 승리 대기에서는 진입 차단"): return
		"finish":
			if not _check(sandbox.continue_saved_run() and sandbox._resolve_boss_choice("rescue") and not controls.open_run_build(), "최종 선택 복원·완주·결과 진입 차단"): return
			controls.begin_retry("bow", 3)
			if not await _test_empty_view(): return
			if not _check(growth.ranks.is_empty() and book.snapshot().has(mastery_id), "새 도전 보유 능력은 비움·발견 유지"): return
		"flows":
			if not _check(not controls.open_run_build(), "메인 진입 차단"): return
			controls.begin_retry()
			if not _test_entry_layout(): return
			if not await _test_empty_view(): return
			controls.open_layout_editor()
			if not _check(not controls.open_run_build(), "배치 편집·환경 정지 중 진입 차단"): return
			controls.cancel_layout_editor()
			controls.advance_mode_timer_for_test(3.1)
			growth.experience = growth.next_level_experience()
			growth.total_experience = growth.experience
			growth._offer_next_level()
			if not _check(paused and not controls.open_run_build(), "능력 선택의 기존 일시정지 소유권 보호"): return
			if not _resolve_growth(): return
			player.damage_receiver.dead = true
			if not _check(not controls.open_run_build(), "사망 뒤 조회 진입 차단"): return
			player.damage_receiver.dead = false
			if not _check(controls.open_run_build(), "화면 전환 정지 소유권 준비"): return
			var needed := growth.next_level_experience() - growth.experience
			growth.experience += needed
			growth.total_experience += needed
			growth._offer_next_level()
			if not _check(paused and not controls.run_build_owned and not sandbox._run_build_pause_owned and sandbox._growth_pause_owned and controls.current_screen_mode() == 7, "성장 화면 전환은 조회 정지 종료 후 성장 소유권 획득"): return
			if not _resolve_growth() or not _check(not paused, "새 성장 확인 후 정상 정지 해제"): return
			if not _check(controls.open_run_build(), "결과 전환 정리 준비"): return
			growth.stop_run()
			controls._show_result_screen()
			if not _check(not paused and not controls.run_build_owned and controls.current_screen_mode() == 1, "강제 결과 전환에도 정지 누수 없음"): return
			controls.begin_retry()
			controls.process_mode = Node.PROCESS_MODE_ALWAYS
			paused = true
			if not _check(controls.open_run_build(), "기존 외부 정지 상태에서 조회"): return
			_tap(controls.run_build_snapshot().layout.back.get_center())
			controls.advance_mode_timer_for_test(3.1)
			if not _check(paused and controls.process_mode == Node.PROCESS_MODE_ALWAYS and not controls.run_build_owned, "복귀 후 기존 외부 정지/처리 모드 보존"): return
			paused = false
			if not _check(controls.open_run_build(), "강제 메인 전환 정리 준비"): return
			controls.show_main_screen()
			if not _check(not paused and not controls.run_build_owned and not sandbox._run_build_pause_owned, "메인 전환 정지 소유권 해제"): return
			controls.begin_retry()
			if not _check(controls.open_run_build(), "중복 진입 검사 준비"): return
			if not _check(not controls.open_run_build() and controls.close_run_build() and not controls.close_run_build(), "중복 열기/닫기 차단"): return
			sandbox.free()
			if not _check(not paused, "카운트다운 도중 씬 종료 정지 누수 없음"): return
			print("GP-141 runtime test: OK (" + phase + ")")
			quit(0)
			return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-141 runtime test: OK (" + phase + ")")
	quit(0)

func _disable_live() -> void:
	for controller in [weapons.sword_combat, weapons.bow_combat, ultimate, player]:
		controller.set_process(false)
		controller.set_physics_process(false)
	runner.set_process(false)

func _files() -> Dictionary:
	var result := {}
	for path in [GP141_SAVE, GP141_SAVE + ".bak", GP141_META, GP141_RECORD, GP141_BOOK]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return result

func _test_empty_view() -> bool:
	var before: Dictionary = sandbox._capture_run_build()
	var files := _files()
	if not _check(controls.open_run_build() and paused and controls.current_screen_mode() == 16, "실제 초기 도전 조회·트리 정지"): return false
	var snapshot: Dictionary = controls.run_build_snapshot()
	if not _check(snapshot.count == 1 and snapshot.cards[0].id == "empty" and snapshot.pages == 1, "미획득 능력 자동 지급/표시 없음"): return false
	for ignored in 4: _tap(snapshot.layout.next.get_center())
	if not _check(controls.run_build_snapshot().page == 0, "빈 페이지 범위 제한"): return false
	if not await _test_layout(): return false
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	controls._input(key)
	if not _check(controls.current_screen_mode() == 5 and paused, "닫기 키도3초 정지 카운트다운"): return false
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and sandbox._capture_run_build() == before and _files() == files, "빈 도전 조회/복귀는 실제 도전/저장/기록 무변경")

func _test_populated_view() -> bool:
	var before: Dictionary = sandbox._capture_run_build()
	var files := _files()
	if not _check(controls.open_run_build() and paused, "실제 장비/능력 도전 조회"): return false
	var all_abilities := PrototypeRunBuildView.cards(0, controls.run_build_state)
	if not _check(all_abilities.size() == 6 and all_abilities[0].id == "sword_power" and all_abilities[0].status == "이번 도전 3등급", "여섯 보유 능력·원본 순서·누적3등급 표시"): return false
	var mastery: Dictionary = all_abilities.filter(func(card: Dictionary) -> bool: return card.id == mastery_id)[0]
	if not _check(mastery.status == "이번 도전 1등급" and "선봉대" in mastery.lines[2] and "선봉의 칼날" in mastery.lines[2], "직업 전용 강화 원본·선행 두 조건"): return false
	var equipment := PrototypeRunBuildView.cards(1, controls.run_build_state)
	if not _check(equipment.size() == 6 and equipment[0].status == "주 무기" and equipment[1].status == "보조 무기" and equipment[1].name == "영웅 바람 활" and equipment[0].lines[3] == "기본 피해100 기준 226" and equipment[0].lines[4] == "스킬 피해100 기준 205", "실제 장비·성장·보조 합산 피해226/205"): return false
	if not _check(equipment[2].id == weapons.skills.sword[0] and equipment[2].lines[0].contains("재사용") and equipment[2].lines[3] == "남은 대기 2.6초" and equipment[5].lines[3] == "남은 대기 4.4초", "실제 교체 슬롯·시계추 재사용/양 무기 남은 대기"): return false
	var overview := PrototypeRunBuildView.cards(2, controls.run_build_state)
	if not _check(overview[0].status == "5 / 5 스테이지" and overview[1].lines[0] == "방벽 20 / 20" and overview[1].lines[3] == "생명 흡수 · 현재 5%" and overview[1].lines[4] == "공중 도약 해금" and overview[2].status == "선봉대" and overview[2].lines[2] == "게이지 73 / 100" and overview[3].lines[0] == PrototypeRelic.hud(player.relic_state), "실제 단계·방벽 충전·흡수·도약·직업·73게이지·유물"): return false
	if not await _test_layout(): return false
	var snapshot: Dictionary = controls.run_build_snapshot()
	var leaked: Dictionary = snapshot.cards[0]
	leaked.lines[0] = "변경"
	if not _check(controls.run_build_snapshot().cards[0].lines[0] != "변경" and sandbox._capture_run_build() == before and _files() == files, "조회 스냅샷 복사·탭/페이지/카드 터치는 도전/모든 저장 무변경"): return false
	_tap(controls.run_build_snapshot().layout.back.get_center())
	controls.advance_mode_timer_for_test(3.1)
	return _check(not paused and sandbox._capture_run_build() == before and _files() == files, "복귀도 장비·선택·유물·게이지·저장 무변경")

func _test_layout() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		for tab in 3:
			_tap(controls.run_build_snapshot().layout.tabs[tab].get_center())
			var seen: Array[String] = []
			var pages: int = controls.run_build_snapshot().pages
			for page in pages:
				var snapshot: Dictionary = controls.run_build_snapshot()
				if not _check(snapshot.tab == tab and snapshot.page == page, "실제 탭·페이지 터치"): return false
				var safe: Rect2 = controls.layout_snapshot().safe
				var rects: Array = snapshot.layout.cards.duplicate()
				rects.append_array(snapshot.layout.tabs)
				rects.append_array([snapshot.layout.back, snapshot.layout.previous, snapshot.layout.next])
				for i in rects.size():
					if not _check(safe.encloses(rects[i]), "두 화면비 모든 입력 영역 안전 영역"): return false
					for j in range(i + 1, rects.size()):
						if not _check(not rects[i].intersects(rects[j]), "조회 탭/페이지/복귀/카드 비중첩"): return false
				for i in snapshot.cards.size():
					var card: Dictionary = snapshot.cards[i]
					seen.append(card.id)
					var rect: Rect2 = snapshot.layout.cards[i]
					var height := 0.50 / maxi(6, card.lines.size())
					for line in card.lines.size():
						var area := Rect2(rect.position + Vector2(12, rect.size.y * (0.42 + line * height)), Vector2(rect.size.x - 24, rect.size.y * height))
						var font_size := mini(18, maxi(12, int(area.size.y * 0.8)))
						while font_size > 10 and ThemeDB.fallback_font.get_string_size(card.lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > area.size.x: font_size -= 1
						if not _check(rect.encloses(area) and ThemeDB.fallback_font.get_string_size(card.lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= area.size.x, "각 원본/설명 줄 카드 내부·글자 너비"): return false
					_tap(rect.get_center())
				controls.queue_redraw()
				await process_frame
				_tap(snapshot.layout.next.get_center())
			var final: Dictionary = controls.run_build_snapshot()
			if not _check(seen.size() == final.count and final.page == pages - 1, "모든 보유 카드 조회·마지막 페이지 제한"): return false
			for ignored in pages + 1: _tap(final.layout.previous.get_center())
			if not _check(controls.run_build_snapshot().page == 0, "이전 페이지 범위 제한"): return false
	return true

func _test_entry_layout() -> bool:
	var original: Dictionary = controls._capture_control_layout()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		for preset in ["default", "left"]:
			controls._restore_control_layout(controls._preset_layout(preset))
			var safe: Rect2 = controls.layout_snapshot().safe
			if not _check(controls.combat_build_rect.has_area() and safe.encloses(controls.combat_build_rect), "기본/왼손 두 화면비 조회 버튼 표시·안전 영역"): return false
			for rect: Rect2 in controls._control_touch_rects().values():
				if not _check(not rect.intersects(controls.combat_build_rect), "조회 버튼은 이동 패드와 모든 조작을 피함"): return false
		controls._restore_control_layout(controls._preset_layout("default"))
		var old_entry: Vector2 = controls.combat_build_rect.get_center()
		var safe: Rect2 = controls.layout_snapshot().safe
		controls.control_centers[&"jump"] = (old_entry - safe.position) / safe.size
		controls._refresh_layout()
		if not _check(controls.combat_build_rect.has_area(), "사용자 점프 배치에서도 빈 공간으로 조회 버튼 이동"): return false
		for rect: Rect2 in controls._control_touch_rects().values():
			if not _check(not rect.intersects(controls.combat_build_rect), "사용자 배치의 조작 입력 영역 비중첩"): return false
		_tap(old_entry)
		if not _check(controls.current_screen_mode() == 0 and controls.command_buffer.pending_count() > 0 and not paused, "사용자 점프 터치는 조회로 가로채지 않음"): return false
		_tap(controls.combat_build_rect.get_center())
		if not _check(controls.current_screen_mode() == 16 and paused, "이동한 조회 버튼의 실제 진입"): return false
		controls.close_run_build()
		controls.advance_mode_timer_for_test(3.1)
	controls._restore_control_layout(original)
	controls.size = Vector2(1280, 720)
	controls._refresh_layout()
	return true

func _test_freeze_and_resume() -> bool:
	controls.size = Vector2(1280, 720)
	controls._refresh_layout()
	if not _check(controls.layout_snapshot().safe.encloses(controls.combat_build_rect), "도전 상태 버튼 안전 영역"): return false
	for rect in controls.action_rects.values():
		if not _check(not rect.intersects(controls.combat_build_rect), "기본 전투 버튼과 조회 버튼 비중첩"): return false
	ultimate.gauge = 100
	ultimate.request_ultimate()
	weapons.bow_combat._spawn_projectile("gp141:freeze", &"bow_basic", 1, 1, Vector2.RIGHT, PackedStringArray(["bow", "basic"]))
	var shot: BowProjectile = get_nodes_in_group("bow_projectile").back()
	for actor in [player, runner, weapons.sword_combat, weapons.bow_combat, ultimate]:
		actor.set_process(true)
		actor.set_physics_process(true)
	var move: Rect2 = controls.move_zone
	var touch := InputEventScreenTouch.new()
	touch.index = 21
	touch.pressed = true
	touch.position = move.get_center()
	controls._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 21
	drag.position = move.get_center() + Vector2(80, 0)
	controls._input(drag)
	touch.index = 22
	touch.position = controls.action_rects[&"jump"].get_center()
	controls._input(touch)
	if not _check(not controls.pointer_controls.is_empty() and controls.command_buffer.pending_count() > 0, "실제 이동/점프 입력과 예약 명령 준비"): return false
	_tap(controls.combat_build_rect.get_center())
	if not _check(paused and controls.current_screen_mode() == 16 and controls.pointer_controls.is_empty() and controls.control_pointers.is_empty() and controls.command_buffer.pending_count() == 0 and player.move_input == 0 and not player.jump_held, "실제 HUD 터치 진입·멀티터치/점프/이동/예약 입력 모두 해제"): return false
	var before: Dictionary = sandbox._capture_run_build()
	var position := player.global_position
	var shot_position := shot.global_position
	var files := _files()
	var enemy_positions := {}
	for enemy in get_nodes_in_group("combat_enemy"): enemy_positions[enemy.get_instance_id()] = enemy.global_position
	await create_timer(0.16, true).timeout
	for enemy in get_nodes_in_group("combat_enemy"):
		if not _check(enemy_positions[enemy.get_instance_id()] == enemy.global_position, "일반/정예 적 물리 이동 정지"): return false
	if not _check(player.global_position == position and shot.global_position == shot_position and sandbox._capture_run_build() == before and _files() == files, "실제 프레임 동안 플레이어/투사체/시간/양 무기 대기/필살기/도전 기록 정지"): return false
	controls.notification(Control.NOTIFICATION_APPLICATION_PAUSED)
	controls.notification(Control.NOTIFICATION_APPLICATION_RESUMED)
	if not _check(controls.current_screen_mode() == 16 and paused and sandbox._capture_run_build() == before, "조회 중 앱 비활성/복귀 정지·화면 보존"): return false
	_tap(controls.run_build_snapshot().layout.back.get_center())
	if not _check(controls.current_screen_mode() == 5 and paused and not controls.open_run_build(), "복귀3초 동안 트리 정지·중복 진입 차단"): return false
	_tap(controls.action_rects[&"skill_1"].get_center())
	await create_timer(0.12, true).timeout
	if not _check(paused and sandbox._capture_run_build() == before, "복귀 카운트다운 중에도 스킬·시간·피해 진행 없음"): return false
	controls.advance_mode_timer_for_test(1.0)
	if not _check(paused and controls.current_screen_mode() == 5, "3초 미만 복귀 차단"): return false
	controls.advance_mode_timer_for_test(2.1)
	_disable_live()
	shot.free()
	return _check(not paused and controls.current_screen_mode() == 0 and controls.process_mode == Node.PROCESS_MODE_INHERIT and not controls.run_build_owned and not controls.run_build_resume_pending and sandbox._capture_run_build() == before and _files() == files, "3초 후 정확한 시점 복귀·정지 소유권/처리 모드 해제·무료 재충전 없음")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-141 failed: " + message)
		paused = false
		quit(1)
	return condition
