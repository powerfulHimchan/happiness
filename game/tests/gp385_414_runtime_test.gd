extends "res://tests/gp375_384_runtime_test.gd"

const EXTRA_SKILLS := ["polearm_cross", "shield_wave"]
var content_id: String
var content_type: String
var discoveries: AbilityDiscoveryStore
var prefix: String

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0]
	content_id = args[1]
	character = args[2]
	facing = int(args[3]) if args.size() > 3 else 1
	var definition := _definition(content_id)
	if not _check(not definition.is_empty(), "알려진 30개 콘텐츠"): return
	family = definition.family
	content_type = definition.type
	prefix = "user://gp414_%s_%s_%d" % [content_id,character,facing]
	store.save_path = prefix + "_checkpoint.json"
	legacy.save_path = prefix + "_meta.jsonl"
	journal.save_path = prefix + "_story.jsonl"
	if phase not in ["resume","finish"]:
		store.clear_checkpoint()
		for suffix in ["_meta.jsonl","_records.jsonl","_abilities.jsonl","_story.jsonl"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(prefix+suffix))
	sandbox = SANDBOX.instantiate()
	sandbox.checkpoint_store = store
	sandbox.boss_legacy_store = legacy
	sandbox.story_journal_store = journal
	discoveries = AbilityDiscoveryStore.new()
	discoveries.save_path = prefix+"_abilities.jsonl"
	sandbox.ability_discovery_store = discoveries
	sandbox.get_node("RecoveryOrbController").drop_chance = 0
	sandbox.get_node("LocalTestRecorder").record_path = prefix+"_records.jsonl"
	root.add_child(sandbox)
	current_scene = sandbox
	await process_frame
	controls = sandbox.get_node("CanvasLayer/GroundMovementControls")
	player = sandbox.get_node("Player")
	growth = sandbox.get_node("PrototypeGrowthController")
	runner = sandbox.get_node("StageRunner")
	weapons = sandbox.get_node("Player/PrototypeWeaponController")
	combat = weapons.combat_for(family)
	automatic_growth_card_id = family+"_power"
	growth.jobs_enabled = false
	for actor in [player,weapons,runner,sandbox.get_node("Player/UltimateController"),sandbox.get_node("ClockTrapController"),sandbox.get_node("RouteTerrain")]:
		actor.set_process(false)
		actor.set_physics_process(false)
	for id in PrototypeWeaponRewards.FAMILY_IDS:
		weapons.combat_for(id).set_process(false)
		weapons.combat_for(id).set_physics_process(false)
	sandbox.get_node("CombatFeedbackController").configure(0,false,false)
	if phase in ["resume","finish"]:
		if not _resume_content(): return
		if phase == "resume" and content_type == "design":
			if not _advance_standard() or not _finish_stage() or not await _pick_design(false): return
		if phase == "finish":
			if content_type == "design" and not _check(weapons.equipment[family] == 2," 영웅 등급 별도 프로세스 복원"): return
			controls.show_main_screen()
			if not _check(controls.begin_retry("sword",3,"standard",character,false,0,"bow") and player.weapon_training.is_empty() and player.relic_state.is_empty() and weapons.blueprints == {"sword":"","bow":""}, "새 도전 임시 효과 초기화"): return
	else:
		if not _check(controls.begin_retry(family,5,"standard",character,false,0,"sword"),"두 계열 새 도전"): return
		match phase:
			"catalog":
				if not _catalog(): return
			"combat":
				if not _extra_skill_combat() or not _cancellations(): return
			"render", "render_rare", "render_reward":
				if not await _render_content(phase): return
			"seed":
				match content_type:
					"design":
						if not _finish_stage() or not await _pick_design(true): return
					"relic":
						if not await _pick_relic(): return
					"training":
						if not _select_training(): return
						if not _finish_stage() or not sandbox._claim_weapon_reward(""): return
						if not _check(sandbox._save_checkpoint(runner.current_metrics()) == OK,"성장 저장"): return
					"skill":
						skill_id = content_id
						if not await _reward_save(): return
				if not _damage_and_guards() or not _save_guards(): return
			_:
				_check(false,"알 수 없는 단계")
				return
	paused = false
	sandbox.free()
	print("GP-385–414 runtime test: OK (%s %s %s %d)" % [phase,content_id,character,facing])
	quit(0)

func _definition(id: String) -> Dictionary:
	if id in PrototypeWeaponRewards.EXPANSION_DESIGNS: return {"type":"design","family":PrototypeWeaponRewards.DESIGNS[id].weapon}
	var relic := PrototypeRelic.family_profile(id)
	if not relic.is_empty(): return {"type":"relic","family":relic.weapon}
	for card in PrototypeWeaponTraining.CARDS:
		if card.id == id: return {"type":"training","family":card.category}
	if id in EXTRA_SKILLS: return {"type":"skill","family":PrototypeSkillRewards.weapon_for(id)}
	return {}

func _catalog() -> bool:
	var cards := PrototypeWeaponRewards.codex_cards({})
	if not _check(cards.size() == 74 and PrototypeWeaponRewards.EXPANSION_DESIGNS.size() == 12 and PrototypeRelic.OFFERS.size() == 33 and PrototypeWeaponTraining.CARDS.size() == 8 and PrototypeSkillRewards.CODEX_ORDER.size() == 88,"장비74·유물33·성장8추가·스킬88"): return false
	var old_tail: Array[String] = []
	for id in ["fist","staff","polearm","shield"]:
		for grade in 3: old_tail.append(id+"_"+str(grade))
	if not _check(cards.slice(38,50).map(func(card: Dictionary) -> String: return card.id) == old_tail and PrototypeSkillRewards.CODEX_ORDER.slice(56,58) == EXTRA_SKILLS,"이전50장비·56스킬 도감 순서 보존"): return false
	for id in PrototypeWeaponRewards.EXPANSION_DESIGNS:
		var profile: Dictionary = PrototypeWeaponRewards.DESIGNS[id]
		var expected_kind: String = "basic" if id.begins_with("striker") else "skill" if id.begins_with("weaver") else "skill" if profile.weapon in ["staff","shield"] else "basic"
		if not _check(PrototypeWeaponRewards.profile(profile.weapon,0,id).is_empty() and PrototypeWeaponRewards.profile("sword",1,id).is_empty(),"설계 일반 등급·다른 무기 거부"): return false
		for grade in [1,2]:
			var item := PrototypeWeaponRewards.profile(profile.weapon,grade,id)
			if not _check(item.kind == expected_kind and is_equal_approx(item.damage, (.25 if grade == 1 else .45) if id.begins_with("balanced") else (.05 if grade == 1 else .10)) and is_equal_approx(item.unique,(0.0 if grade == 1 else .05) if id.begins_with("balanced") else (.20 if grade == 1 else .35)),"12설계 희귀·영웅 실제 성능"): return false
	return _backup_combinations()

func _pick_design(failure: bool) -> bool:
	var before := weapons.checkpoint_snapshot()
	var saved := store.load_checkpoint()
	var seen: Array[String] = []
	for dimensions in [Vector2(1280,720),Vector2(1600,720)]:
		controls.size = dimensions
		controls._refresh_layout()
		while controls.weapon_reward_page > 0: _tap(controls.weapon_reward_previous_rect.get_center())
		seen.clear()
		for page in controls.weapon_reward_pages():
			controls._refresh_weapon_reward_layout()
			for i in controls.weapon_reward_cards.size():
				var item: Dictionary = controls.weapon_reward_cards[i]
				if not _check(item.id not in seen and controls.layout_snapshot().safe.encloses(controls.weapon_reward_rects[i]),"장비 모든 후보 중복 없이 안전 영역"): return false
				seen.append(item.id)
			_tap(controls.weapon_reward_next_rect.get_center())
		if not _check(content_id in seen and weapons.checkpoint_snapshot() == before and store.load_checkpoint() == saved,"비교·페이지는 장비·저장 무변경"): return false
	while controls.weapon_reward_page > 0: _tap(controls.weapon_reward_previous_rect.get_center())
	var selected := false
	for page in controls.weapon_reward_pages():
		for i in controls.weapon_reward_cards.size():
			if controls.weapon_reward_cards[i].id == content_id:
				_tap(controls.weapon_reward_rects[i].get_center())
				selected = true
				break
		if selected: break
		_tap(controls.weapon_reward_next_rect.get_center())
	if not _check(selected,"실제 장비 카드 선택"): return false
	if failure:
		store.save_path = "user://gp414_missing/checkpoint.json"
		_tap(controls.weapon_reward_confirm_rect.get_center())
		store.save_path = prefix+"_checkpoint.json"
		if not _check(weapons.checkpoint_snapshot() == before and not runner.reward_claimed and store.load_checkpoint() == saved,"장비 저장 실패는 두 계열·대기·파일 되돌림"): return false
	_tap(controls.weapon_reward_confirm_rect.get_center())
	return _check(weapons.blueprints[family] == content_id and weapons.equipment[family] == mini(runner.stage_number,2) and runner.reward_claimed,"실제 설계 장착·정예 단계별 승급")

func _pick_relic() -> bool:
	if not _finish_stage() or not sandbox._claim_weapon_reward("") or not _advance_standard() or not _finish_stage() or not sandbox._claim_weapon_reward(""): return false
	_tap(controls.relic_reward_open_rect.get_center())
	var selected := false
	for page in controls.relic_reward_pages():
		controls._refresh_relic_reward_layout()
		for i in controls.relic_reward_card_rects.size():
			var index: int = page*PrototypeRelic.REWARD_PAGE_SIZE+i
			if index < PrototypeRelic.OFFERS.size() and PrototypeRelic.OFFERS[index].id == content_id:
				_tap(controls.relic_reward_card_rects[i].get_center())
				selected = true
				break
		if selected: break
		_tap(controls.relic_reward_next_rect.get_center())
	if not _check(selected and player.relic_state.is_empty(),"실제 유물 페이지 선택·획득 전 효과 없음"): return false
	var saved := store.load_checkpoint()
	var health := player.damage_receiver.health
	var gauge: int = sandbox.get_node("Player/UltimateController").gauge
	var before := weapons.checkpoint_snapshot()
	store.save_path = "user://gp414_missing/checkpoint.json"
	_tap(controls.relic_reward_confirm_rect.get_center())
	store.save_path = prefix+"_checkpoint.json"
	if not _check(player.relic_state.is_empty() and store.load_checkpoint() == saved and weapons.checkpoint_snapshot() == before,"유물 기록 실패·스냅샷 무변경"): return false
	_tap(controls.relic_reward_confirm_rect.get_center())
	return _check(player.relic_state == {"id":content_id,"used":false} and player.damage_receiver.health == health and sandbox.get_node("Player/UltimateController").gauge == gauge and not sandbox._claim_relic_reward(content_id),"한 유물 실제 확정·즉시 체력/게이지 변화 없음·중복 금지")

func _select_training() -> bool:
	var card := PrototypeAbilityCodex.profile(content_id)
	if not _check(not growth._card_available(card),"선행 계열 능력 전 선택 금지"): return false
	if not _earn_card(family+"_power"): return false
	if not _check(growth._card_available(card),"선행 능력 후 훈련 후보"): return false
	var needed := growth.next_level_experience()-growth.experience
	growth.experience += needed
	growth.total_experience += needed
	growth._offer_next_level()
	growth.offered_cards.assign([card])
	sandbox._on_growth_choices_requested(growth.offered_cards,growth.level,growth.rerolls_remaining)
	var path := discoveries.save_path
	var before := player.weapon_training.duplicate()
	discoveries.save_path = "user://gp414_missing/abilities.jsonl"
	if not _check(not growth.choose_card(0) and not growth.ranks.has(content_id) and player.weapon_training == before and growth.choosing,"영구 능력 기록 실패·피해 강화 미적용"): return false
	discoveries.save_path = path
	if not _check(growth.choose_card(0) and player.weapon_training.has(content_id) and not growth._card_available(card) and discoveries.snapshot().has(content_id),"능력 재시도·한 번 선택·영구 도감 발견"): return false
	if not _resolve_growth(): return false
	for other in PrototypeWeaponTraining.CARDS:
		if other.category not in weapons.equipment and not _check(not growth._card_available(other),"미휴대 계열 훈련 차단"): return false
	return true

func _resume_content() -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty(),"별도 프로세스 저장 존재"): return false
	for ignored in 2:
		controls.show_main_screen()
		if not _check(sandbox.continue_saved_run() and _weapons_restored(saved.weapons) and player.damage_receiver.health == saved.player.health and player.character_id == character and player.weapon_training == PrototypeWeaponTraining.selected(saved.growth.ranks) and player.relic_state == saved.get("relic",{}),"반복 이어하기·유물/훈련 재구성·보너스 중복 없음"): return false
	return _damage_and_guards()

func _damage_and_guards() -> bool:
	var relic: Dictionary = PrototypeRelic.family_profile(String(player.relic_state.get("id","")))
	for id in weapons.equipment:
		for kind in ["basic","skill","ultimate"]:
			var own := PrototypeWeaponRewards.profile(id,int(weapons.equipment[id]),String(weapons.blueprints[id]))
			var other: String = weapons.equipment.keys().filter(func(key: String) -> bool: return key != id)[0]
			var backup := PrototypeWeaponRewards.profile(other,int(weapons.equipment[other]),String(weapons.blueprints[other]))
			var gear := 1.0 if kind == "ultimate" else 1.0+float(own.damage)+(float(own.unique) if own.kind == kind else 0.0)+(float(backup.unique)*.5 if backup.kind == kind else 0.0)
			var training := .2 if player.weapon_training.has(id+"_"+kind+"_training") else 0.0
			var multiplier := 1.0
			if not relic.is_empty() and relic.weapon == id and (relic.damage_kind == "all" or relic.damage_kind == kind): multiplier = 1.15 if relic.damage_kind == "all" else 1.30
			var bonus := player.growth_common_bonus+float(player.get("growth_"+id+"_bonus"))+training
			for base in [100,101]:
				var expected := roundi(snappedf(base*(1.0+bonus)*gear*multiplier,.000000001))
				if not _check(player.growth_damage(base,id,kind) == expected,"실제 피해·종류/다른 계열/보조50%/필살기 제외·최종 반올림: "+id+" "+kind): return false
	# Also check a real damage event without changing the surrounding UI pause state.
	var was_paused := paused
	paused = false
	for target in get_nodes_in_group("targetable"):
		target.visible = false
		target.set_process(false)
		target.set_physics_process(false)
	player.prepare_next_stage(sandbox.TRACK_START)
	var victim := _target_at("effect",Vector2(100,0))
	var before := victim.damage_receiver.health
	var expected := player.growth_damage(100,family,"basic")
	combat._action_sequence += 1
	if not _check(combat._damage_target(victim,StringName(family+"_basic"),100,0,PackedStringArray([family,"basic"]),0) == DamageReceiver.Result.APPLIED and victim.damage_receiver.health == before-expected,"실제 이벤트의 강화 피해 적용"): return false
	victim.free()
	paused = was_paused
	return true

func _save_guards() -> bool:
	var saved := store.load_checkpoint()
	if not _check(not saved.is_empty() and RunCheckpointStore.valid_state(saved),"정상 새 콘텐츠 저장 검증"): return false
	var bad := saved.duplicate(true)
	match content_type:
		"design": bad.weapons.blueprints.sword = content_id
		"relic": bad.relic.used = true
		"training":
			bad.growth.ranks.erase(family+"_power")
		"skill": bad.weapons.skills.sword[0] = content_id
	if not _check(store.save_checkpoint(bad) == ERR_INVALID_DATA and store.load_checkpoint() == saved,"다른 계열/소비 유물/선행 없는 성장/스킬 변조 거부"): return false
	return true

func _extra_skill_combat() -> bool:
	skill_id = content_id
	_setup_cast()
	var front := _target_at("front",Vector2(100,0))
	var rear := _target_at("rear",Vector2(-100,0))
	var second := _target_at("second",Vector2(200,0))
	var third := _target_at("third",Vector2(321 if content_id == "polearm_cross" else 300,0))
	weapons.target_selector.current_target = front
	weapons.request_skill_1()
	combat._update_skill_action(.7)
	if content_id == "polearm_cross":
		if not _check(front.damage_receiver.health == 9976 and rear.damage_receiver.health == 9976 and second.damage_receiver.health == 9976 and third.damage_receiver.health == 10000 and player.facing_direction == facing,"양면봉 앞/뒤 고정2타·범위/방향 유지"): return false
	else:
		var wave := get_nodes_in_group("sword_wave")[-1] as SwordWave
		wave.set_physics_process(false)
		wave._physics_process(1.0)
		if not _check(front.damage_receiver.health == 9964 and second.damage_receiver.health == 9964 and third.damage_receiver.health == 10000 and rear.damage_receiver.health == 10000 and wave.weapon_family == "shield" and combat.skill_hit_count == 2,"서약 파동 가까운2개체 관통·후방 제외·방패 집계"): return false
		wave.free()
	return true

func _render_content(phase: String) -> bool:
	if content_type == "design":
		if phase == "render_reward":
			if not _finish_stage(): return false
			while not controls.weapon_reward_cards.any(func(item: Dictionary) -> bool: return item.id == content_id):
				_tap(controls.weapon_reward_next_rect.get_center())
		else:
			weapons.equip_reward(content_id,1 if phase == "render_rare" else 2)
			player.facing_direction = facing
			player._update_avatar_action_visual()
	elif content_type == "relic":
		if not await _pick_relic(): return false
		var index: int = PrototypeRelic.OFFERS.find(PrototypeRelic.family_profile(content_id))
		controls.screen_mode = 15
		controls.relic_reward_page = index / PrototypeRelic.REWARD_PAGE_SIZE
		controls.selected_relic_offer = index
		controls._refresh_relic_reward_layout()
	elif content_type == "training":
		if not _earn_card(family+"_power"): return false
		growth.offered_cards.assign([PrototypeAbilityCodex.profile(content_id)])
		sandbox._on_growth_choices_requested(growth.offered_cards,growth.level,growth.rerolls_remaining)
	else:
		skill_id = content_id
		_setup_cast()
		player._update_avatar_action_visual()
		weapons.request_skill_1()
		combat._update_skill_action(.25)
	combat.queue_redraw()
	controls.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("HAPPINESS_RENDER_DIR")
	if not output.is_empty():
		if not _check(root.get_texture().get_image().save_png(output+"/"+phase+"_"+content_id+"_"+character+"_"+str(facing)+".png") == OK,"콘텐츠 실제 렌더"): return false
	return true

func _advance_standard() -> bool:
	if not _check(not controls.stage_route_options.is_empty(),"표시된 다음 경로 존재"): return false
	var wanted: String = controls.stage_route_options[0].id
	var before := runner.stage_number
	_tap(controls.stage_route_rects[0].get_center())
	return _check(not paused and runner.stage_number == before+1 and runner.route_id == wanted,"표시된 실제 다음 경로 입력")

func _backup_combinations() -> bool:
	for design in PrototypeWeaponRewards.EXPANSION_DESIGNS:
		var own: String = PrototypeWeaponRewards.DESIGNS[design].weapon
		var own_kind: String = PrototypeWeaponRewards.DESIGNS[design].kind
		for backup in PrototypeWeaponRewards.FAMILY_IDS:
			if backup == own: continue
			var backup_design: String = "runic_sword" if backup == "sword" else "hunter_bow" if backup == "bow" else "weaver_"+backup
			var backup_kind := "basic" if backup == "bow" else "skill"
			for kind in ["basic","skill","ultimate"]:
				var expected := 1.0
				if kind != "ultimate":
					expected += .45 if design.begins_with("balanced") else .10
					if kind == own_kind: expected += .05 if design.begins_with("balanced") else .35
					if kind == backup_kind: expected += .175
				if not _check(is_equal_approx(PrototypeWeaponRewards.damage_multiplier({own:2,backup:2},own,kind,{own:design,backup:backup_design}),expected),"12설계×5보조의 고유50%·기본/스킬/필살기 계산"): return false
	# Confirm that two new families can carry and restore those same designs together.
	for own in ["fist","staff","polearm","shield"]:
		var backup := "staff" if own == "fist" else "shield" if own == "staff" else "fist" if own == "polearm" else "polearm"
		if not _check(controls.begin_retry(own,5,"standard",character,false,0,backup) and weapons.equip_reward("striker_"+own,2) and weapons.equip_reward("weaver_"+backup,2),"새 두 계열 동시 설계 장착"): return false
		if not _check(player.growth_damage(100,own,"basic") == 145 and player.growth_damage(100,own,"skill") == 128 and player.growth_damage(100,own,"ultimate") == 100,"실제 두 새 계열 장착의 주/보조 종류·0.5 반올림"): return false
		var snapshot := weapons.checkpoint_snapshot()
		weapons.restore_checkpoint(snapshot)
		if not _check(player.growth_damage(100,own,"skill") == 128,"복원 후 보조 설계 중복 없음"): return false
	return true
