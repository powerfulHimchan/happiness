extends "res://tests/gp125_runtime_test.gd"

const GP126_SAVE := "user://gp126_checkpoint.json"
const GP126_META := "user://gp126_meta.jsonl"
const GP126_RECORD := "user://gp126_records.jsonl"
const GP126_BOOK := "user://gp126_abilities.jsonl"
var book := AbilityDiscoveryStore.new()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	store.save_path = GP126_SAVE
	legacy.save_path = GP126_META
	book.save_path = "user://gp126_missing/abilities.jsonl" if phase == "legacy-fail" else GP126_BOOK
	if phase == "seed":
		store.clear_checkpoint()
		for path in [GP126_META, GP126_RECORD, GP126_BOOK]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sandbox = SANDBOX.instantiate()
	sandbox.get_node("RecoveryOrbController").drop_chance = 0.0
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.ability_discovery_store = book
	sandbox.get_node("LocalTestRecorder").record_path = GP126_RECORD
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	recorder = sandbox.get_node("LocalTestRecorder")
	sandbox.get_node("CombatFeedbackController").configure(0.0, false, false)
	for controller in [weapons.sword_combat, weapons.bow_combat]:
		controller.set_process(false)
		controller.set_physics_process(false)
	player.set_physics_process(false)
	runner.set_process(false)
	match phase:
		"seed":
			if not _check(book.snapshot().is_empty() and controls.discovered_abilities.is_empty(), "처음은 13능력 모두 미발견"): return
			controls.show_village()
			if not await _test_book_layout(): return
			if not _check(book.snapshot().is_empty() and not FileAccess.file_exists(GP126_BOOK) and player.growth_damage(20, "sword") == 20, "도감 방문·모든 페이지·미발견 조회는 발견·능력 지급 없음"): return
			controls.begin_retry()
			if not await _choose_base_with_failure(): return
			if not await _choose_branch("lifesteal_depth"): return
			if not _check(book.snapshot() == {"lifesteal": true, "lifesteal_depth": true}, "실제 기본·강화 선택만 영구 발견"): return
			var journal := FileAccess.get_file_as_string(GP126_BOOK)
			if not _reject_card("lifesteal_crisis") or not _check(FileAccess.get_file_as_string(GP126_BOOK) == journal, "배타 조건으로 거부한 선택은 발견 없음"): return
			if not _finish_stage(): return
			var saved := store.load_checkpoint()
			book.save_path = "user://gp126_missing/abilities.jsonl"
			if not _check(not sandbox._claim_weapon_reward("") and not runner.reward_claimed and store.load_checkpoint() == saved, "능력 기록 실패는 중간 저장·보상 확정 보류·기존 저장 보호"): return
			book.save_path = GP126_BOOK
			if not _check(sandbox._claim_weapon_reward(""), "중간 저장 재시도 성공"): return
			controls.show_main_screen()
			controls.show_village()
			var before := growth.checkpoint_snapshot()
			saved = store.load_checkpoint()
			var metadata := legacy.progress_snapshot()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 2
			var cards: Array = controls.village_snapshot().cards
			if not _check(cards[0].id == "lifesteal" and cards[0].status == "이번 도전 1등급" and cards[1].id == "lifesteal_depth" and cards[1].open and not cards[2].open, "현재 기본·강화 등급·반대 가지 미발견 표시"): return
			if not _check(growth.checkpoint_snapshot() == before and store.load_checkpoint() == saved and legacy.progress_snapshot() == metadata and FileAccess.get_file_as_string(GP126_BOOK) == journal, "능력 도감은 성장·중간 저장·보스 메타·발견 파일 변경 없음"): return
		"resume":
			if not _check(controls.discovered_abilities == {"lifesteal": true, "lifesteal_depth": true} and not player.lifesteal_unlocked, "별도 프로세스 영구 발견은 시작 능력을 지급하지 않음"): return
			if not _check(sandbox.continue_saved_run() and player.lifesteal_branch == "lifesteal_depth", "도감과 기존 강화 이어하기 독립 복원"): return
			var journal := FileAccess.get_file_as_string(GP126_BOOK)
			if not _check(book.discover(["lifesteal", "lifesteal_depth", "lifesteal"]) == OK and FileAccess.get_file_as_string(GP126_BOOK) == journal, "반복 발견·중복 ID는 추가 쓰기 없음"): return
			for invalid in [null, true, "lifesteal", {}, [7], ["unknown"], ["air_jump", "unknown"]]:
				if not _check(book.discover(invalid) == ERR_INVALID_DATA and FileAccess.get_file_as_string(GP126_BOOK) == journal, "잘못된 ID·혼합 목록은 부분 발견 없음"): return
			_tap(controls.stage_route_rects[1].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "강화 이어하기 두 번째 스테이지 저장"): return
		"finish":
			if not _check(sandbox.continue_saved_run(), "두 번째 통과 복원"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("rescue"), "도감 포함 실제 보스 완주"): return
			var found := book.snapshot()
			player.player_died.emit()
			recorder.clear_records()
			controls.begin_retry()
			if not _check(book.snapshot() == found and growth.ranks.is_empty() and not player.lifesteal_unlocked and controls.test_record_summary.run_count == 1, "사망·기록 삭제·새 도전 뒤 발견 유지·능력 초기화"): return
			book._append({"event": "abilities", "ids": ["unknown"]})
			book._append({"event": "abilities", "ids": ["air_jump", "unknown"]})
			book._append({"event": "abilities", "ids": [true]})
			var file := FileAccess.open(GP126_BOOK, FileAccess.READ_WRITE)
			file.seek_end()
			file.store_line(JSON.stringify({"version": 1, "payload": JSON.stringify({"event": "abilities", "ids": ["lifesteal_crisis"]}), "sha256": "bad"}))
			file.store_string("{truncated")
			file.close()
			if not _check(book.snapshot() == found, "손상 줄·알 수 없는 ID·혼합·잘못된 체크섬은 정상 발견 보존"): return
			if not _gain_ability("air_jump"): return
			if not _check(book.snapshot().has("air_jump") and not book.snapshot().has("lifesteal_crisis"), "실제 선택으로 손상 끝줄 뒤 재기록·잘못된 반대 가지 미발견"): return
			for ignored in 3:
				if not _gain_ability("sword_power"): return
			if not _resolve_growth() or not _check(growth.jobs.job_id == "vanguard", "실제 카드 성향 직업 발현"): return
			if not _gain_ability("vanguard_edge") or not _check(book.snapshot().has("vanguard_edge"), "실제 직업 전용 능력 선택도 영구 발견"): return
			controls.show_main_screen()
			controls.show_village()
			if not await _test_book_layout(): return
			controls.ability_codex_page = 3
			if not _check(controls.village_snapshot().cards[0].id == "vanguard_edge" and controls.village_snapshot().cards[0].status == "이번 도전 1등급", "직업 카드의 현재 도전 등급"): return
			controls.begin_retry()
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 도전 저장의 실제 검 능력 준비"): return
			DirAccess.remove_absolute(ProjectSettings.globalize_path(GP126_BOOK))
		"legacy-fail":
			var saved := store.load_checkpoint()
			if not _check(not saved.is_empty() and controls.discovered_abilities.is_empty() and controls.checkpoint_available and not sandbox.continue_saved_run() and controls.current_screen_mode() == 2 and store.load_checkpoint() == saved, "이전 저장 복구 실패는 이어하기·정상 저장 보호"): return
			controls.begin_retry()
			if not _check(controls.current_screen_mode() == 2 and store.load_checkpoint() == saved and growth.ranks.is_empty(), "복구 실패 중 새 도전도 기존 저장 보호"): return
		"legacy-resume":
			if not _check(controls.discovered_abilities == {"sword_power": true} and not player.double_jump_unlocked and not player.lifesteal_unlocked, "이전 저장의 실제 보유 능력만 영구 복구"): return
			var journal := FileAccess.get_file_as_string(GP126_BOOK)
			sandbox._refresh_checkpoint()
			if not _check(FileAccess.get_file_as_string(GP126_BOOK) == journal and sandbox.continue_saved_run(), "복구 반복 조회 쓰기 없음·이어하기 성공"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._claim_weapon_reward(""), "이전 저장 두 번째 통과"): return
			_tap(controls.stage_route_rects[0].get_center())
			if not _finish_stage() or not _check(sandbox._resolve_boss_choice("destroy"), "이전 저장 실제 보스 완주"): return
		_:
			_check(false, "잘못된 검사 단계")
			return
	paused = false
	sandbox.free()
	print("GP-126 runtime test: OK (" + phase + ")")
	quit(0)

func _choose_base_with_failure() -> bool:
	var chosen_seed := -1
	for candidate in 128:
		growth.rng.seed = candidate
		for card in growth._draw_cards():
			if card.id == "lifesteal": chosen_seed = candidate
		if chosen_seed >= 0: break
	if not _check(chosen_seed >= 0, "실제 흡수 후보 등장"): return false
	growth.rng.seed = chosen_seed
	player.global_position.x = 1240
	runner._process(0.1)
	for enemy in runner._active_enemies.duplicate(): _defeat(enemy)
	var index := -1
	for i in growth.offered_cards.size():
		if growth.offered_cards[i].id == "lifesteal": index = i
	if not _check(index >= 0 and paused and growth.choosing, "실제 처치 첫 레벨업"): return false
	var before := growth.checkpoint_snapshot()
	book.save_path = "user://gp126_missing/abilities.jsonl"
	_tap(controls.growth_card_rects[index].get_center())
	if not _check(paused and growth.choosing and growth.checkpoint_snapshot() == before and not player.lifesteal_unlocked and book.snapshot().is_empty() and not growth.selection_message.is_empty() and not controls.ability_codex_message.is_empty(), "실제 카드 터치 저장 실패는 효과·성향·등급·발견 미적용·재시도 안내"): return false
	controls.queue_redraw()
	await process_frame
	book.save_path = GP126_BOOK
	_tap(controls.growth_card_rects[index].get_center())
	return _check(not paused and not growth.choosing and player.lifesteal_unlocked and growth.selection_message.is_empty() and book.snapshot() == {"lifesteal": true}, "같은 카드 재선택으로 저장·능력 적용·전투 재개")

func _gain_ability(id: String) -> bool:
	var needed := growth.next_level_experience()
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards = [PrototypeAbilityCodex.profile(id)]
	sandbox._on_growth_choices_requested(growth.offered_cards, growth.level, growth.rerolls_remaining)
	_tap(controls.growth_card_rects[0].get_center())
	return _check(book.snapshot().has(id) and growth.ranks.has(id), "능력 선택 실제 UI·기록·효과 경로")

func _test_book_layout() -> bool:
	for dimensions in [Vector2(1280, 720), Vector2(2400, 1080)]:
		controls.size = dimensions
		controls._refresh_layout()
		controls.village_page = "village"
		_tap(controls.village_snapshot().layout.cards[3].get_center())
		if not _check(controls.village_page == "jobs", "기존 네 번째 시설로 성장 도감 진입"): return false
		_tap(controls.village_snapshot().tabs.abilities.get_center())
		if not _check(controls.village_page == "abilities" and controls.ability_codex_page == 0, "실제 능력 탭 터치"): return false
		var seen: Array[String] = []
		for page in 5:
			var snapshot: Dictionary = controls.village_snapshot()
			if not _check(snapshot.ability_page == page and snapshot.ability_pages == 5 and snapshot.cards.size() == (1 if page == 4 else 3), "13능력 다섯 페이지·마지막 한 장"): return false
			var safe: Rect2 = controls.layout_snapshot().safe
			var rects: Array = snapshot.layout.cards.duplicate()
			rects.append_array([snapshot.layout.back, snapshot.layout.start])
			if controls.checkpoint_available: rects.append(snapshot.layout["continue"])
			rects.append_array(snapshot.tabs.values())
			rects.append_array(snapshot.pager.values())
			for i in rects.size():
				if not _check(safe.encloses(rects[i]), "두 화면비 카드·탭·페이지·준비·이어하기 안전 영역"): return false
				for j in range(i + 1, rects.size()):
					if not _check(not rects[i].intersects(rects[j]), "모든 입력 영역 비중첩"): return false
			for card in snapshot.cards:
				var source := PrototypeAbilityCodex.profile(card.id)
				seen.append(String(card.id))
				if not _check(card.name == source.title and card.lines[0] == source.lines[0] and card.lines[1] == source.lines[1] and card.lines.size() == 5 and card.open == controls.discovered_abilities.has(card.id), "기본·강화·직업 카드 실제 원본 데이터·발견 상태"): return false
				if source.has("requires") and not _check("생명 흡수" in card.lines[2], "강화 가지 선행 조건"): return false
				if source.has("job") and not _check(String(PrototypeJobProgress.profile(source.job).name) in card.lines[2], "직업 카드 발현 조건"): return false
			controls.queue_redraw()
			await process_frame
			_tap(snapshot.pager.next.get_center())
		if not _check(seen.size() == 13 and controls.ability_codex_page == 4, "모든 능력 조회·마지막 페이지 범위 제한"): return false
		for ignored in 6: _tap(controls.village_snapshot().pager.previous.get_center())
		if not _check(controls.ability_codex_page == 0, "이전 페이지 범위 제한"): return false
		_tap(controls.village_snapshot().tabs.jobs.get_center())
		if not _check(controls.village_page == "jobs" and controls.village_snapshot().cards.size() == 2, "직업 탭으로 기존 도감 유지"): return false
		_tap(controls.village_snapshot().tabs.abilities.get_center())
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("GP-126 failed: " + message)
		paused = false
		quit(1)
	return condition
