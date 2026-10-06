extends "res://tests/gp130_runtime_test.gd"

const GP132_SAVE := "user://gp132_checkpoint.json"
const GP132_META := "user://gp132_meta.jsonl"
const GP132_RECORD := "user://gp132_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP132_SAVE
	legacy.save_path = GP132_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP132_META, GP132_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = "user://gp132_abilities.jsonl"
	if phase == "seed": DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP132_RECORD
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
	weapons.sword_combat.set_physics_process(false)
	weapons.bow_combat.set_physics_process(false)
	weapons.sword_combat.set_process(false)
	weapons.bow_combat.set_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			if not await _test_skill_codex(false, 1.0): return
			if not _check(not FileAccess.file_exists(GP132_SAVE) and not FileAccess.file_exists(GP132_META), "첫 도감 방문은 저장 생성 없음"): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.skill_reward_open_rect.get_center())
			_tap(controls.skill_reward_cycle_rect.get_center())
			_select_offer("sword_triple", 1)
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.sword[1] == "sword_triple" and runner.skills_claimed, "실제 첫 정예 보상 삼연 슬롯2 교체"): return
			if not await _test_skill_codex(true, 1.0): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.relic_reward_open_rect.get_center())
			_tap(controls.relic_reward_card_rects[1].get_center())
			_tap(controls.relic_reward_confirm_rect.get_center())
			if not _check(player.relic_state.id == PrototypeRelic.CLOCK_ID, "실제 시계추 보상 선택"): return
			_tap(controls.skill_reward_open_rect.get_center())
			_tap(controls.skill_reward_cycle_rect.get_center())
			_select_offer("bow_focus", 0)
			var saved := store.load_checkpoint()
			var before := weapons.checkpoint_snapshot()
			store.save_path = "user://gp132_missing/checkpoint.json"
			_tap(controls.skill_reward_confirm_rect.get_center())
			store.save_path = GP132_SAVE
			if not _check(weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved and not runner.skills_claimed, "도감 추가 후 스킬 교체 실패 롤백 유지"): return
			if not _check(controls.movement_metrics.weapon_skills == before.skills, "실패 후 도감용 장착 상태도 이전 구성"): return
			_tap(controls.skill_reward_confirm_rect.get_center())
			if not _check(weapons.skills.bow[0] == "bow_focus" and controls.movement_metrics.weapon_skills == weapons.skills, "교체 성공 후 양 무기 장착 정보 즉시 갱신"): return
			if not await _test_skill_codex(true, 1.25): return
		"resume":
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and player.relic_state.is_empty(), "이어하기 전 저장 스킬·유물 자동 적용 없음"): return
			if not await _test_skill_codex(false, 1.0): return
			for ignored in 2:
				_tap(controls.village_snapshot().layout["continue"].get_center())
				if not _check(controls.current_screen_mode() == 9 and weapons.skills.sword[1] == "sword_triple" and weapons.skills.bow[0] == "bow_focus" and player.skill_recharge_multiplier() == 1.25, "도감 이어하기 버튼으로 실제 두 슬롯·시계추 복원"): return
				if not await _test_skill_codex(true, 1.25): return
		"finish":
			if not _check(sandbox.continue_saved_run(), "스킬 도감 보스 도전 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "교체·유물 적용 구성 실제 완주"): return
			if not await _test_skill_codex(false, 1.0): return
			controls.begin_retry()
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and player.relic_state.is_empty(), "새 도전 기본 슬롯·유물 초기화"): return
			if not await _test_skill_codex(true, 1.0): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			var old := store.load_checkpoint()
			old.weapons.erase("skills")
			old.stage.erase("skills_claimed")
			old.erase("relic")
			if not _check(store.save_checkpoint(old) == OK, "스킬·유물 필드 없는 이전 저장 준비"): return
		"legacy":
			if not await _test_skill_codex(false, 1.0): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(weapons.skills == PrototypeSkillRewards.defaults() and runner.skills_claimed and player.relic_state.is_empty(), "이전 저장 기본 구성·보상 소급 지급 없음"): return
			if not await _test_skill_codex(true, 1.0): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 보스 완주"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-132 runtime test: OK (" + phase + ")")
	quit(0)

func _test_skill_codex(active: bool, multiplier: float) -> bool:
	var saved := store.load_checkpoint()
	var equipment := weapons.checkpoint_snapshot()
	var growth_state := growth.checkpoint_snapshot()
	var relic := player.relic_state.duplicate()
	var metadata := legacy.progress_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var gauge := ultimate.gauge
	var found: Dictionary = sandbox.ability_discovery_store.snapshot()
	controls.show_main_screen()
	controls.show_village()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[0].get_center())
		if not _check(controls.village_page == "forge", "기존 첫 번째 시설 대장간 진입"): return false
		_tap(controls.village_snapshot().tabs.skills.get_center())
		if not _check(controls.village_page == "skills" and controls.skill_codex_page == 0, "실제 스킬 도감 탭 진입·첫 페이지"): return false
		var seen: Array[String] = []
		for page in 4:
			var snapshot: Dictionary = controls.village_snapshot()
			if not _check(snapshot.skill_page == page and snapshot.skill_pages == 4 and snapshot.cards.size() == mini(3, 10 - page * 3), "10스킬 네 페이지·마지막 한 카드"): return false
			var safe: Rect2 = controls.layout_snapshot().safe
			var rects: Array = snapshot.layout.cards.duplicate()
			rects.append_array(snapshot.tabs.values())
			rects.append_array(snapshot.pager.values())
			rects.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "두 화면비 모든 카드·탭·페이지·하단 버튼 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "전체 입력 영역 비중첩"): return false
			for i in snapshot.cards.size():
				var card: Dictionary = snapshot.cards[i]
				seen.append(String(card.id))
				var weapon := PrototypeSkillRewards.weapon_for(card.id)
				var definition: SkillDefinition = PrototypeSkillRewards.SKILLS[card.id]
				var equipped: Array = weapons.skills[weapon] if active else PrototypeSkillRewards.defaults()[weapon]
				var slot := equipped.find(card.id)
				var status := "이번 도전 · 슬롯 %d" % (slot + 1) if active and slot >= 0 else "미장착 · 효과 미리 보기" if active else "시작 스킬 · 슬롯 %d" % (slot + 1) if slot >= 0 else "보상 교체 스킬"
				if not _check(card.name.ends_with(definition.display_name) and card.weapon == weapon and card.status == status and card.open == (slot >= 0), "실제 양 무기 원본 이름·현재 슬롯·시작/보상 표시"): return false
				if not _check(card.lines.slice(0, 3) == PrototypeSkillRewards.lines(card.id, multiplier) and card.lines.size() == 6 and card.lines[4].contains("강화 전") and card.lines[5].contains("시계추") == (multiplier == 1.25), "원본 피해·타격·범위·실시간 재사용과 강화 전 안내"): return false
				if card.id == "bow_focus" and not _check(card.lines[0].begins_with("재사용 8.0초" if multiplier == 1.25 else "재사용 10.0초"), "집중 실제 10초→8초 표시"): return false
				if card.id == "sword_triple" and not _check(card.lines[0].begins_with("재사용 7.2초" if multiplier == 1.25 else "재사용 9.0초"), "보조 검 삼연 실제 9초→7.2초 표시"): return false
				var rect: Rect2 = snapshot.layout.cards[i]
				for j in card.lines.size():
					var line_rect := Rect2(rect.position + Vector2(12, rect.size.y * (0.44 + j * 0.08)), Vector2(rect.size.x - 24, rect.size.y * 0.08))
					var font_size := mini(18, maxi(12, int(line_rect.size.y * 0.8)))
					while font_size > 10 and ThemeDB.fallback_font.get_string_size(String(card.lines[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > line_rect.size.x: font_size -= 1
					if not _check(rect.encloses(line_rect) and ThemeDB.fallback_font.get_string_size(String(card.lines[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= line_rect.size.x, "실제 글자 축소 규칙·줄 높이·너비 확인"): return false
				_tap(rect.get_center())
			controls.queue_redraw()
			await process_frame
			_tap(snapshot.pager.next.get_center())
		if not _check(seen.size() == 10 and seen.all(func(id: String) -> bool: return seen.count(id) == 1) and controls.skill_codex_page == 3, "모든 기술 중복 없이 조회·마지막 페이지 상한"): return false
		for ignored in 6: _tap(controls.village_snapshot().pager.previous.get_center())
		if not _check(controls.skill_codex_page == 0, "이전 페이지 하한"): return false
		_tap(controls.village_snapshot().tabs.forge.get_center())
		if not _check(controls.village_page == "forge" and controls.village_snapshot().cards.size() == 2, "기존 설계도 두 카드 보존"): return false
		controls.queue_redraw()
		await process_frame
		_tap(controls.village_snapshot().layout.back.get_center())
		if not _check(controls.village_page == "village", "대장간 뒤로 마을 복귀"): return false
		_tap(controls.village_snapshot().layout.cards[0].get_center())
		_tap(controls.village_snapshot().tabs.skills.get_center())
	return _check(store.load_checkpoint() == saved and weapons.checkpoint_snapshot() == equipment and growth.checkpoint_snapshot() == growth_state and player.relic_state == relic and legacy.progress_snapshot() == metadata and sandbox.ability_discovery_store.snapshot() == found and player.damage_receiver.health == health and player.potions_remaining == potions and ultimate.gauge == gauge, "도감 조회·모든 터치·전환은 저장/슬롯/대기시간/유물/성장/발견/체력/회복약/필살기 변경 없음")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-132 failed: " + message)
		paused = false
		quit(1)
	return condition
