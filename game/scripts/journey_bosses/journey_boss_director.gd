class_name JourneyBossDirector
extends Node2D

const BOSS_SCENE := preload("res://scenes/combat/journey_boss.tscn")
const SIGIL := preload("res://assets/journey_bosses/sigil.svg")
var game: Node
var state: Dictionary = {}
var actor: JourneyBoss
var _busy := false
var _elapsed := .0
var _visual_s := 0.0
var _mark_hold := .0
var _mark_stage := 0
var _arena := ""
var _chime: AudioStreamPlayer

func setup(owner_game: Node) -> void:
	game = owner_game
	owner_game.add_child(self)
	game.controls.journey_boss_action.connect(action)
	_chime = AudioStreamPlayer.new()
	add_child(_chime)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(4410*2)
	for i in 4410: bytes.encode_s16(i*2,int(sin(i*TAU*880/22050.0)*6000*(1.0-i/4410.0)))
	sound.data = bytes
	_chime.stream = sound

func reset() -> void:
	cleanup()
	state = JourneyBossProgress.initial(PermanentAchievements.earned(game.achievement_store.snapshot(),JourneyBossProgress.ACHIEVEMENT)) if game.stage_runner.journey_bosses_enabled and game.stage_runner.run_mode == "journey" else {}
	game.stage_runner.extra_completion_ready = state.is_empty()
	game.stage_runner.journey_sigil_count=-1 if state.is_empty() else 0
	_mark_hold = 0
	_mark_stage = 0
	game.controls.relic_unlocked_ian = game.story_journal_store.snapshot().secrets.has(JourneyBossProgress.SECRET)

func snapshot() -> Dictionary:
	var value := state.duplicate(true)
	if value.get("flow") == "battle": value.flow = "intro"
	return value

func restore(value: Dictionary) -> void:
	cleanup()
	state = value.duplicate(true)
	game.stage_runner.journey_sigil_count=-1 if state.is_empty() else state.sigils.size()
	game.stage_runner.extra_completion_ready = state.is_empty() or state.aurel == "done"
	game.stage_runner.extra_elapsed_s=0 if state.is_empty() else state.elapsed.belo+state.elapsed.aurel+state.elapsed.ian
	game.controls.relic_unlocked_ian = game.story_journal_store.snapshot().secrets.has(JourneyBossProgress.SECRET)

func cleanup() -> void:
	if is_instance_valid(actor): actor.free()
	actor = null
	if game != null:
		game.stage_runner.extra_boss = null
		game.stage_runner.extra_boss_active = false
		game.stage_runner.route_terrain.journey_arena = ""
		game.stage_runner.route_terrain.queue_redraw()
	_arena = ""
	queue_redraw()

func _process(delta: float) -> void:
	if state.is_empty() or not game.growth.run_active or game.player.damage_receiver.dead or game._combat_environment_suspended: return
	_elapsed += maxf(0,delta)
	_visual_s=fposmod(_visual_s+maxf(0,delta),120.0)
	if state.flow == "battle":
		state.elapsed[state.boss] += maxf(0,delta)
		game.stage_runner.extra_elapsed_s=state.elapsed.belo+state.elapsed.aurel+state.elapsed.ian
		game.stage_runner.extra_stage_elapsed_s=state.elapsed[state.boss]
		if is_instance_valid(actor) and actor.damage_receiver.dead and actor.last_defeat_in_combat: _victory()
	else:
		var runner: PrototypeStageRunner = game.stage_runner
		if state.flow == "idle" and runner.stage_number in JourneyBossProgress.MARK_STAGES and not runner.stage_complete and game.controls.current_screen_mode() == 0:
			if _mark_stage != runner.stage_number: _mark_stage = runner.stage_number; _mark_hold = 0
			if _mark_stage not in state.sigils:
				var near: bool = absf(game.player.position.x-3130) < 85 and absf(game.player.position.y-780) < 145
				_mark_hold = _mark_hold+delta if near else 0.0
				if _mark_hold >= .55:
					state.sigils.append(_mark_stage)
					state.sigils.sort()
					game.stage_runner.journey_sigil_count=state.sigils.size()
					game.controls._append_action_log("시계 문양 %d/3 활성화" % state.sigils.size())
					_chime.volume_db = linear_to_db(maxf(.001,game.controls.feedback_sound_volume))
					if DisplayServer.get_name() != "headless" and game.controls.feedback_sound_volume > 0: _chime.play()
					runner.force_emit_metrics()
		if _elapsed >= .1:
			_elapsed = 0
			intercept(runner.current_metrics())
	queue_redraw()

func intercept(metrics: Dictionary) -> bool:
	if state.is_empty() or _busy or not game.growth.run_active or game.player.damage_receiver.dead: return false
	if state.flow != "idle": return true
	if not metrics.get("stage_complete",false): return false
	if game.growth.choosing or game.growth.awaiting_job_confirmation: return false
	var n: int = game.stage_runner.stage_number
	if n == 5 and state.belo != "done":
		_open("belo","intro")
		return true
	if n == 6 and state.ian == "pending":
		_open("ian","portal")
		return true
	if n == 10 and not game.stage_runner.boss_choice.is_empty() and game.story_run.pending.is_empty() and state.aurel != "done":
		var r: PrototypeStageRunner = game.stage_runner
		if r.heart_threshold != HeartThreshold.PENDING and r.heart_battle not in [HeartEncounter.AVAILABLE,HeartEncounter.PENDING,HeartEncounter.ACTIVE,HeartEncounter.DEFEATED]:
			return request_final("ritual" if not r.final_ritual.is_empty() and r.final_ritual.phase != FinalRitual.LOCKED else "arrival" if r.arrival_ending == ArrivalEnding.PENDING else "complete")
	return false

func request_final(destination: String) -> bool:
	if state.is_empty() or state.aurel == "done": return false
	if state.flow == "idle":
		state["return"] = destination
		_open("aurel","intro")
	return true

func _open(id: String, flow: String) -> void:
	state.boss = id
	state.flow = flow
	if id != "aurel":
		game.story_run.prepare_stage(game.stage_runner.stage_number)
		RunSupplyShop.grant(game.run_shop,game.stage_runner.checkpoint_snapshot(),game.weapon_controller.skills)
		game._sync_supply_shop()
	game._begin_growth_pause()
	_show()
	if _persist() != OK: game.controls.story_message = "중간 저장 실패 · 버튼을 눌러 다시 저장하세요"

func _persist() -> Error:
	return game._save_checkpoint(game.stage_runner.current_metrics(),false)

func resume() -> bool:
	if state.is_empty(): return false
	if state.flow == "idle": return intercept(game.stage_runner.current_metrics())
	game._begin_growth_pause()
	_show()
	return true

func _show() -> void:
	var id: String = state.boss
	var title: String = JourneyBoss.NAMES[id]
	var lines: Array[String] = []
	var actions: Array[Dictionary] = []
	var footer := "보스 진입 전·처치 후 중간 저장 · 목표 시간은 제한 시간이 아닙니다"
	match state.flow:
		"portal":
			title = "시계탑 아래 비밀 공방"
			lines.assign(["첫 새벽 업적: "+("달성" if state.unlocked else "미달성 · 전체 여정을 먼저 완주하세요"),"이번 도전 시계 문양 %d/3 · 2·4·6스테이지의 빛나는 문양을 찾으세요" % state.sigils.size(),"공방은 선택 경로입니다. 일반 경로로 진행해도 엔딩을 볼 수 있습니다."])
			actions.assign([{"id":"enter","name":"비밀 공방에 도전","enabled":JourneyBossProgress.can_enter(state)},{"id":"leave","name":"일반 경로로 진행"}])
		"intro":
			lines.assign({"belo":["웃는 가면 뒤에서 단장이 실을 당깁니다. 모두에게 웃음을 강요하던 무대를 멈춰 주세요.","실의 표시에서는 옆으로, 인형 행진은 점프로 피하세요. 체력 절반부터 순서가 바뀝니다."],"aurel":["새벽시계에 남은 되감기의 흔적이 시계룡으로 뭉쳤습니다. 앞으로 나아가는 마지막 문을 지킵니다.","꼬리는 점프로, 구슬은 틈으로, 숨결은 순서를 보고 피하세요. 공격 뒤 낮아지는 머리를 노리세요."],"ian":["기억을 잃은 시계공 이안이 멈춘 공방을 지킵니다. 그를 이기면 회중시계와 그의 기록을 되찾습니다.","렌치의 예고를 피하고 태엽 장치 사이로 이동하세요. 잔상은 방금 든 무기의 공격을 흉내 냅니다."]}[id])
			actions.append({"id":"start","name":"보스 전투 시작"})
		"reward":
			if id == "belo":
				lines.assign(["가면이 떨어지고 실이 풀렸습니다. 추가 보상 하나를 고르면 최대 체력의 20%를 회복합니다.","보유 무기를 영웅 등급으로 올리거나 주 무기의 다른 스킬을 선택하세요."])
				for family in game.weapon_controller.equipment:
					actions.append({"id":"weapon:"+family,"name":PrototypeWeaponRewards.family_name(family)+" · 영웅 등급 강화","enabled":int(game.weapon_controller.equipment[family])<2})
				var skill := reward_skill()
				if not skill.is_empty(): actions.append({"id":"skill:"+skill,"name":String(PrototypeSkillRewards.SKILLS[skill].display_name)+" · 첫 스킬 교체"})
				if not actions.any(func(item: Dictionary): return item.get("enabled",true)): actions.append({"id":"rest","name":"보상 대신 휴식"})
			else:
				lines.assign(["이안: '이 시계는 시간을 가두려고 만든 것이 아니었어. 누군가 돌아갈 아침을 기억하려고 만들었지.'","공방의 기록과 전용 유물 ‘시계공의 회중시계’를 영구 해금합니다. 공격 속도 +10%와 스킬 대기시간 -15%를 제공합니다."])
				actions.assign([{"id":"ian_equip","name":"회중시계 장착하고 계속"},{"id":"ian_keep","name":"현재 유물을 유지하고 계속"}])
		"victory":
			lines.assign(["시계룡의 날개에서 오래된 새벽이 흩어집니다. 되감기의 흔적 너머로 한 번도 보지 못한 아침이 열립니다.","이제 이 여정의 마지막 이야기를 선택할 수 있습니다."])
			actions.append({"id":"continue","name":"마지막 이야기로"})
	game.controls.show_story({"id":"journey_boss","boss":id,"name":title,"lines":lines,"actions":actions,"footer":footer})

func reward_skill() -> String:
	var family: String = game.weapon_controller.active_weapon_id
	for id in PrototypeSkillRewards.SKILLS:
		if String(id).begins_with(family+"_") and id not in game.weapon_controller.skills[family]: return id
	return ""

func action(id: String) -> bool:
	if state.is_empty() or _busy or game.controls.current_screen_mode()!=18 or game.controls.story_scene.get("id")!="journey_boss": return false
	if not game.controls.story_scene.actions.any(func(item: Dictionary): return item.id == id and item.get("enabled",true)): return false
	if _persist()!=OK: game.controls.story_message="저장 실패 · 현재 화면에서 다시 시도하세요"; return false
	if state.flow == "portal":
		if id == "enter":
			if not JourneyBossProgress.can_enter(state): return false
			_open("ian","intro")
			return true
		var previous := state.duplicate(true)
		state.ian = "skipped"; state.flow = "idle"; state.boss = ""
		if _persist()!=OK: state=previous; game.controls.story_message="경로 저장 실패 · 다시 시도하세요"; return false
		_resume_regular()
		return true
	if state.flow == "intro": return _start_battle()
	if state.flow == "reward": return _reward(id)
	if state.flow == "victory":
		var previous := state.duplicate(true)
		state.aurel="done";state.flow="idle";state.boss=""
		game.stage_runner.extra_completion_ready=true
		if _persist()!=OK: state=previous;game.stage_runner.extra_completion_ready=false;game.controls.story_message="승리 저장 실패 · 다시 시도하세요";return false
		var destination: String = state["return"]
		cleanup()
		if destination=="arrival": game._open_arrival_ending()
		elif destination=="ritual": game._open_final_ritual()
		else: _resume_regular()
		return true
	return false

func _start_battle() -> bool:
	_busy=true
	game.controls.finish_story(0)
	game._finish_growth_selection()
	game.controls.screen_mode=0
	var runner: PrototypeStageRunner = game.stage_runner
	runner._deactivate_all_combat_enemies()
	runner.clock_traps.configure(runner.stage_number,"meadow",false)
	for shot in get_tree().get_nodes_in_group("enemy_projectile"): shot.queue_free()
	runner.route_terrain.configure(runner.stage_number,runner.route_id,false)
	runner.route_terrain.journey_arena=state.boss
	runner.route_terrain.queue_redraw()
	_arena=state.boss
	if is_instance_valid(actor): actor.free()
	actor=BOSS_SCENE.instantiate()
	actor.boss_id=state.boss
	game.get_node("Targets").add_child(actor)
	actor.set_stage_spawn(Vector2(4520,780))
	actor.reset_target()
	actor.visible=true
	runner.extra_boss=actor
	runner.extra_boss_active=true
	runner.stage_complete=false
	runner.current_section=PrototypeStageRunner.Section.ELITE
	state.flow="battle"
	runner._set_gate_closed(2,true);runner._set_gate_closed(3,true)
	for index in [2,3]: runner.gates[index].get_node("GateVisual").visible=false
	game.player.prepare_next_stage(Vector2(4050,780))
	game.player.set_safe_spawn(Vector2(4050,780),JourneyBoss.NAMES[state.boss])
	game.weapon_controller.prepare_next_stage()
	game.target_selector.reset_selection();game.target_selector.force_scan()
	_busy=false
	runner.force_emit_metrics()
	return true

func _victory() -> void:
	_busy=true
	actor.visible=false;actor.set_process(false)
	game.stage_runner.extra_boss_active=false
	game.stage_runner.stage_complete=true
	game.stage_runner.current_section=PrototypeStageRunner.Section.COMPLETE
	game.stage_runner._set_gate_closed(2,false);game.stage_runner._set_gate_closed(3,false)
	for shot in get_tree().get_nodes_in_group("enemy_projectile"): shot.queue_free()
	state[state.boss]="cleared"
	state.flow="victory" if state.boss=="aurel" else "reward"
	game._begin_growth_pause()
	_show()
	if _persist()!=OK: game.controls.story_message="승리 저장 실패 · 보상 버튼으로 다시 시도하세요"
	_busy=false

func _reward(id: String) -> bool:
	var previous := state.duplicate(true)
	var gear: Dictionary = game.weapon_controller.checkpoint_snapshot()
	var old_health: int = game.player.damage_receiver.health
	var relic: Dictionary = game.player.relic_state.duplicate(true)
	if state.boss=="belo":
		if id.begins_with("weapon:") and not game.weapon_controller.equip_reward(id.trim_prefix("weapon:"),2): return false
		if id.begins_with("skill:") and not game.weapon_controller.replace_skill(id.trim_prefix("skill:"),0): return false
		game.player.apply_growth_health(0,ceili(game.player.damage_receiver.max_health*.20))
	else:
		if game.story_journal_store.record_secret(JourneyBossProgress.SECRET)!=OK:
			game.controls.story_message="공방 기록 저장 실패 · 다시 시도하세요";return false
		game.controls.relic_unlocked_ian=true
		if id=="ian_equip": game.player.relic_state={"id":PrototypeRelic.IAN_ID,"used":false}
	state[state.boss]="done";state.flow="idle";state.boss=""
	if _persist()!=OK:
		state=previous;game.weapon_controller.restore_checkpoint(gear);game.player.damage_receiver.health=old_health;game.player.relic_state=relic
		game.controls.story_message="보상 저장 실패 · 보상은 적용되지 않았습니다. 다시 시도하세요";return false
	_resume_regular()
	return true

func _resume_regular() -> void:
	_busy=true
	cleanup()
	var runner: PrototypeStageRunner = game.stage_runner
	runner.route_terrain.configure(runner.stage_number,runner.route_id,true,runner.run_mode=="journey",runner.region_section())
	game.controls.finish_story(0)
	game._finish_growth_selection()
	game.controls.screen_mode=0
	_busy=false
	game._intermission_stage=0
	runner.force_emit_metrics()

func _draw() -> void:
	if game==null or state.is_empty() or not game.growth.run_active or game.stage_runner.extra_boss_active: return
	var n: int = game.stage_runner.stage_number
	if n not in JourneyBossProgress.MARK_STAGES or game.stage_runner.stage_complete: return
	var collected: bool = n in state.sigils
	var rect := Rect2(3080,680,100,100)
	draw_texture_rect(SIGIL,rect,false,Color(.55,1,.86,.35 if collected else .85+.15*sin(_visual_s*4)))
	if not collected:
		draw_arc(rect.get_center(),62,0,TAU,40,Color("ffe2a1"),3)
		draw_string(ThemeDB.fallback_font,Vector2(2990,655),"시계 문양 · 잠시 머무르기",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("fff1ba"))

func _exit_tree() -> void:
	if is_instance_valid(_chime):
		_chime.stop()
		_chime.stream=null
