extends "res://tests/gp132_runtime_test.gd"

const GP137_SAVE := "user://gp137_checkpoint.json"
const GP137_META := "user://gp137_meta.jsonl"
const GP137_RECORD := "user://gp137_records.jsonl"

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP137_SAVE
	legacy.save_path = GP137_META
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP137_META, GP137_RECORD]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	var discoveries := AbilityDiscoveryStore.new()
	discoveries.save_path = "user://gp137_abilities.jsonl"
	if phase == "seed": DirAccess.remove_absolute(ProjectSettings.globalize_path(discoveries.save_path))
	sandbox.ability_discovery_store = discoveries
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.get_node("LocalTestRecorder").record_path = GP137_RECORD
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
			if not await _test_weapon_codex(false): return
			if not _check(not FileAccess.file_exists(GP137_SAVE) and not FileAccess.file_exists(GP137_META), "최초 무기 도감 방문은 저장/해금 생성 없음"): return
			controls.begin_retry()
			if not _finish_stage(): return
			_tap(controls.weapon_reward_rects[0].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.equipment.sword == 1, "미해금 기본 희귀 검 실제 획득"): return
			if not await _test_weapon_codex(true): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "실제 보스 파괴로 태엽 설계도 해금"): return
			if not await _test_weapon_codex(false): return
			controls.begin_retry()
			if not _finish_stage(): return
			weapons.sword_combat._skill_1_cooldown_s = 3.25
			weapons.bow_combat._skill_2_cooldown_s = 4.5
			_tap(controls.weapon_reward_rects[2].get_center())
			var saved := store.load_checkpoint()
			var previous := weapons.checkpoint_snapshot()
			store.save_path = "user://gp137_missing/checkpoint.json"
			_tap(controls.weapon_reward_confirm_rect.get_center())
			store.save_path = GP137_SAVE
			if not _check(not runner.reward_claimed and weapons.checkpoint_snapshot() == previous and store.load_checkpoint() == saved, "태엽 장착 저장 실패 상태/대기시간 롤백"): return
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.equipment.sword == 1 and weapons.blueprints.sword == "clockwork_sword", "재선택 희귀 태엽 검 장착 성공"): return
			if not await _test_weapon_codex(true): return
		"resume":
			if not await _test_weapon_codex(false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(weapons.blueprints.sword == "clockwork_sword" and weapons.equipment.sword == 1 and is_equal_approx(weapons.sword_combat._skill_1_cooldown_s, 3.25), "도감 이어하기 희귀 태엽 검/대기시간 복원"): return
			if not await _test_weapon_codex(true): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_rects[3].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			if not _check(weapons.equipment.bow == 2 and weapons.blueprints.bow == "clockwork_bow", "영웅 태엽 활 실제 추가 보상"): return
			if not await _test_weapon_codex(true): return
		"finish":
			if not _check(sandbox.continue_saved_run(), "두 태엽 무기 저장 재시작 복원"): return
			if not await _test_weapon_codex(true): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "도감 조회 후 기존 보스 구출 완주"): return
			if not await _test_weapon_codex(false): return
			controls.begin_retry()
			if not _check(weapons.equipment == {"sword": 0, "bow": 0} and weapons.blueprints == {"sword": "", "bow": ""} and weapons.unlocked_blueprints.size() == 2, "새 도전 기본 장비/설계 초기화·해금 유지"): return
			if not await _test_weapon_codex(true): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_rects[0].get_center())
			_tap(controls.weapon_reward_confirm_rect.get_center())
			var old := store.load_checkpoint()
			old.weapons.erase("blueprints")
			if not _check(store.save_checkpoint(old) == OK, "설계도 필드 없는 이전 저장 준비"): return
		"legacy":
			if not await _test_weapon_codex(false): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			if not _check(weapons.equipment.sword == 1 and weapons.blueprints == {"sword": "", "bow": ""}, "이전 저장 기본 희귀 검 복원·해금만으로 태엽 지급 없음"): return
			if not await _test_weapon_codex(true): return
			_tap(controls.village_snapshot().layout["continue"].get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage(): return
			_tap(controls.weapon_reward_skip_rect.get_center())
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 보스 완주"): return
		"combinations":
			controls.begin_retry()
			if not _test_weapon_combinations(): return
			if not await _test_weapon_codex(true): return
			weapons._perform_switch("도감 주/보조 전환 검사")
			if not await _test_weapon_codex(true): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-137 runtime test: OK (" + phase + ")")
	quit(0)

func _test_weapon_combinations() -> bool:
	var all := PrototypeWeaponRewards.codex_cards({})
	var swords := all.filter(func(card: Dictionary) -> bool: return card.weapon == "sword")
	var bows := all.filter(func(card: Dictionary) -> bool: return card.weapon == "bow")
	for sword in swords:
		for bow in bows:
			if not _check(weapons.set_loadout({"sword": sword.grade, "bow": bow.grade}, {"sword": sword.blueprint, "bow": bow.blueprint}), "25개 유효 장비 조합 적용"): return false
			var cards := PrototypeWeaponRewards.codex_cards({}, weapons.equipment, weapons.blueprints, weapons.active_weapon_id)
			if not _check(cards.filter(func(card: Dictionary) -> bool: return card.equipped).size() == 2, "미해금 저널에서도 실제 장착 두 카드 표시"): return false
			for card in cards:
				if not card.equipped: continue
				var expected := "장비 합산: 기본 +%.1f%% · 스킬 +%.1f%%" % [(PrototypeWeaponRewards.damage_multiplier(weapons.equipment, card.weapon, "basic", weapons.blueprints) - 1) * 100, (PrototypeWeaponRewards.damage_multiplier(weapons.equipment, card.weapon, "skill", weapons.blueprints) - 1) * 100]
				if not _check(card.lines[4] == expected and card.open, "실제 장착 조합 원본 피해 계산 일치"): return false
	weapons.set_loadout({"sword": 2, "bow": 2}, {"sword": "clockwork_sword", "bow": "clockwork_bow"})
	player.growth_common_bonus = 0
	player.growth_sword_bonus = 0
	player.growth_bow_bonus = 0
	var cards := PrototypeWeaponRewards.codex_cards({}, weapons.equipment, weapons.blueprints, weapons.active_weapon_id)
	for card in cards:
		if not card.equipped: continue
		if not _check(card.lines[2].ends_with("17.5%") and card.lines[4] == ("장비 합산: 기본 +37.5% · 스킬 +55.0%" if card.weapon == "sword" else "장비 합산: 기본 +55.0% · 스킬 +37.5%"), "영웅 태엽 양 무기 17.5% 보조·실제 합산 값"): return false
	return _check(player.growth_damage(100, "sword", "basic") == 138 and player.growth_damage(100, "sword", "skill") == 155 and player.growth_damage(100, "bow", "basic") == 155 and player.growth_damage(100, "bow", "skill") == 138 and player.growth_damage(100, "sword", "ultimate") == 100, "실제 피해 정수 반올림·필살기 제외와 안내 일치")

func _test_weapon_codex(active: bool) -> bool:
	var saved := store.load_checkpoint()
	var equipment := weapons.checkpoint_snapshot()
	var growth_state := growth.checkpoint_snapshot()
	var relic := player.relic_state.duplicate()
	var metadata := legacy.progress_snapshot()
	var health := player.damage_receiver.health
	var potions := player.potions_remaining
	var gauge := ultimate.gauge
	var found: Dictionary = sandbox.ability_discovery_store.snapshot()
	var old_active := weapons.active_weapon_id
	controls.show_main_screen()
	controls.show_village()
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[0].get_center())
		if not _check(controls.village_page == "forge", "대장간 진입"): return false
		_tap(controls.village_snapshot().tabs.weapons.get_center())
		if not _check(controls.village_page == "weapons" and controls.weapon_codex_page == 0, "실제 무기 도감 탭·첫 페이지"): return false
		var seen: Array[String] = []
		var equipped_count := 0
		for page in 4:
			var snapshot: Dictionary = controls.village_snapshot()
			if not _check(snapshot.weapon_page == page and snapshot.weapon_pages == 4 and snapshot.cards.size() == (1 if page == 3 else 3), "10무기 네 페이지·마지막1개"): return false
			var safe: Rect2 = controls.layout_snapshot().safe
			var rects: Array = snapshot.layout.cards.duplicate()
			rects.append_array(snapshot.tabs.values())
			rects.append_array(snapshot.pager.values())
			rects.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "16:9/20:9 모든 입력 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "세 탭/페이지/카드/하단 입력 비중첩"): return false
			for key in snapshot.tabs:
				if not _check(ThemeDB.fallback_font.get_string_size(PrototypeVillageView.TAB_LABELS[key], HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x < snapshot.tabs[key].size.x, "세 탭 제목 너비"): return false
			for i in snapshot.cards.size():
				var card: Dictionary = snapshot.cards[i]
				seen.append(String(card.id))
				var source := PrototypeWeaponRewards.profile(card.weapon, card.grade, card.blueprint)
				var equipped: bool = active and int(weapons.equipment[card.weapon]) == card.grade and weapons.blueprints[card.weapon] == card.blueprint
				var available: bool = card.blueprint.is_empty() or controls.unlocked_weapon_blueprints.get(card.blueprint, false) == true
				var status := "이번 도전 · 주 무기" if equipped and old_active == card.weapon else "이번 도전 · 보조 무기" if equipped else "획득 가능 · 효과 미리 보기" if available else "미해금 · 효과 미리 보기"
				if not _check(card.name == source.name and card.lines.slice(0, 3) == source.lines and card.lines.size() == 6 and card.equipped == equipped and card.status == status and card.open == (available or equipped), "등급/이름/고유/보조 원본·해금·주/보조 장비 상태"): return false
				if equipped: equipped_count += 1
				if not _check(card.lines[3].contains("보스 파괴") == (not card.blueprint.is_empty()) and card.lines[5].contains("필살기 제외"), "해금 조건·피해 보정 범위 안내"): return false
				var rect: Rect2 = snapshot.layout.cards[i]
				var texts: Array = [card.name, card.status]
				texts.append_array(card.lines)
				for j in texts.size():
					var text_rect := Rect2(rect.position + Vector2(12, rect.size.y * (0.16 if j == 0 else 0.31 if j == 1 else 0.44 + (j - 2) * 0.08)), Vector2(rect.size.x - 24, rect.size.y * (0.13 if j == 0 else 0.08)))
					var font_size := mini(26 if j == 0 else 17 if j == 1 else 18, maxi(12, int(text_rect.size.y * 0.8)))
					while font_size > 10 and ThemeDB.fallback_font.get_string_size(String(texts[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > text_rect.size.x: font_size -= 1
					if not _check(rect.encloses(text_rect) and ThemeDB.fallback_font.get_string_size(String(texts[j]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= text_rect.size.x, "제목/상태/6줄 실제 글자 축소·범위 포함"): return false
				_tap(rect.get_center())
			controls.queue_redraw()
			await process_frame
			_tap(snapshot.pager.next.get_center())
		if not _check(seen.size() == 10 and seen.all(func(id: String) -> bool: return seen.count(id) == 1) and equipped_count == (2 if active else 0) and controls.weapon_codex_page == 3, "10무기 중복 없음·장착2개/비활성0개·페이지 상한"): return false
		for ignored in 5: _tap(controls.village_snapshot().pager.previous.get_center())
		if not _check(controls.weapon_codex_page == 0, "페이지 하한"): return false
		_tap(controls.village_snapshot().tabs.skills.get_center())
		if not _check(controls.village_page == "skills" and controls.skill_codex_page == 0, "기존 스킬 도감 탭 동작"): return false
		_tap(controls.village_snapshot().tabs.forge.get_center())
		if not _check(controls.village_page == "forge" and controls.village_snapshot().cards.size() == 2, "설계도 카드 보존"): return false
		_tap(controls.village_snapshot().layout.back.get_center())
		if not _check(controls.village_page == "village", "마을 뒤로 복귀"): return false
		_tap(controls.village_snapshot().layout.cards[0].get_center())
		_tap(controls.village_snapshot().tabs.weapons.get_center())
	return _check(store.load_checkpoint() == saved and weapons.checkpoint_snapshot() == equipment and growth.checkpoint_snapshot() == growth_state and player.relic_state == relic and legacy.progress_snapshot() == metadata and sandbox.ability_discovery_store.snapshot() == found and player.damage_receiver.health == health and player.potions_remaining == potions and ultimate.gauge == gauge, "도감 모든 터치·탭·조회는 장비/저장/대기시간/성장/유물/영구 해금/체력/회복약/필살기 변경 없음")

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-137 failed: " + message)
		paused = false
		quit(1)
	return condition
