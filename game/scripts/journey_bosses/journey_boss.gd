class_name JourneyBoss
extends EliteArmoredBoar

const ART := {"belo":preload("res://assets/journey_bosses/belo.svg"),"aurel":preload("res://assets/journey_bosses/aurel.svg"),"ian":preload("res://assets/journey_bosses/ian.svg")}
const NAMES := {"belo":"가면극장 단장 벨로","aurel":"시계룡 아우렐","ian":"잊힌 시계공 이안"}
const HP := {"belo":1200,"aurel":2400,"ian":1800}
const PATTERNS := {"belo":["실 내려찍기","인형 행진","가면 바꾸기"],"aurel":["시계바늘 꼬리","멈춘 시간의 구슬","새벽의 숨결"],"ian":["순간이동 렌치","바닥 태엽 장치","기억의 잔상"]}
const SHOT := preload("res://scenes/combat/enemy_seed_projectile.tscn")
var boss_id := "belo"
var hazards: Array[Rect2] = []
var attack_serial := 0
var echo_family := "sword"
var _chain_active := false
var _fired := false
var _fired_count := 0
var _animation_s := 0.0
var _entrance_s := 0.0
var _aim := Vector2.LEFT

func _ready() -> void:
	super._ready()
	add_to_group("boss_enemy")
	body_sprite.texture = ART[boss_id]
	body_sprite.scale = Vector2.ONE * (.82 if boss_id == "aurel" else .70)
	body_sprite.position = Vector2(0,-55 if boss_id == "aurel" else -38)
	armor_marker.visible = false
	warning_ring.visible = false
	warning_line.visible = false
	attacker_id = StringName(boss_id)
	target_key = NAMES[boss_id]
	arena_bounds=Vector2(3920,4800)
	damage_receiver.max_health = HP[boss_id]
	reset_target()

func _process(delta: float) -> void:
	if enemy_time_scale() <= 0: return
	_animation_s += delta * enemy_time_scale()
	_entrance_s = minf(.35,_entrance_s+delta*enemy_time_scale())
	modulate.a = smoothstep(0,.35,_entrance_s)
	super._process(delta)
	body_sprite.position.y = (-38 if boss_id == "aurel" and state == State.RECOVERY else -55 if boss_id == "aurel" else -38) + sin(_animation_s*2.0)*3.0
	body_sprite.rotation = sin(_animation_s*1.7)*.022
	queue_redraw()

func _update_idle(_delta: float) -> void:
	if _attack_cooldown_s <= 0: _begin_next_pattern()

func _begin_next_pattern() -> void:
	current_pattern = (attack_serial + (1 if phase == 2 and boss_id == "belo" else 0)) % 3
	attack_serial += 1
	pattern_history.append(current_pattern)
	if pattern_history.size() > 8: pattern_history.pop_front()
	warning_count += 1
	hazards.clear()
	_fired = false
	_fired_count = 0
	if boss_id == "ian" and current_pattern == 0:
		position.x = 4670 if player.position.x < 4350 else 4060
	_aim = (player.global_position + Vector2(0,-42) - (global_position + Vector2(0,-65))).normalized()
	if boss_id == "aurel" and current_pattern == 0:
		hazards.append(Rect2(3830,720,1050,120))
	elif boss_id == "aurel" and current_pattern == 2:
		for x in [3830,4180,4530]: hazards.append(Rect2(x,680,350,160))
	elif boss_id == "ian" and current_pattern == 1:
		for x in [3950,4310,4670]: hazards.append(Rect2(x,710,120,130))
	elif boss_id == "ian" and current_pattern == 2:
		echo_family = player.active_weapon_family
		hazards.append(Rect2(player.position.x-110,630,220,210))
	elif boss_id == "belo" and current_pattern == 2:
		hazards.append(Rect2(3830,650,250,190))
		hazards.append(Rect2(4630,650,250,190))
	elif boss_id == "belo" and current_pattern == 1:
		hazards.append(Rect2(3830,730,1050,110))
	else:
		var x := clampf(player.position.x,3930,4770)
		hazards.append(Rect2(x-85,560 if boss_id == "belo" else 680,170,280 if boss_id == "belo" else 160))
		if boss_id == "belo" and phase == 2: hazards.append(Rect2(4760 if x < 4350 else 3830,560,120,280))
	_set_state(State.WARNING,pattern_name(current_pattern)+" · 표시를 보고 피하세요")

func _update_warning() -> void:
	warning_ring.visible = false
	warning_line.visible = false
	if _state_elapsed_s < (.80 if phase == 2 else 1.05): return
	attack_count += 1
	_set_state(State.CHARGING,pattern_name(current_pattern))

func _update_charge(_delta: float) -> void:
	if boss_id == "aurel" and current_pattern == 1:
		var count := 5 if phase == 2 else 3
		while _fired_count < count and _state_elapsed_s >= _fired_count*.18:
			_fire_shot((_fired_count-(count-1)*.5)*.22)
			_fired_count += 1
	elif boss_id == "ian" and current_pattern == 2 and echo_family in ["bow","staff"]:
		if not _fired:
			for angle in [-.22,0,.22]: _fire_shot(angle)
			_fired = true
	elif boss_id == "aurel" and current_pattern == 2:
		for i in hazards.size():
			if _state_elapsed_s >= i*.45 and _state_elapsed_s < i*.45+.25: _damage_area(hazards[i],i)
	elif boss_id == "belo" and current_pattern == 1:
		var x := 3830+minf(_state_elapsed_s/1.15,1.0)*1050
		_damage_area(Rect2(x-65,715,130,125),0)
	else:
		if _state_elapsed_s < .28:
			for i in hazards.size(): _damage_area(hazards[i],i)
	var duration := 1.35 if (boss_id == "aurel" and current_pattern == 2) or (boss_id == "belo" and current_pattern == 1) else .95
	if _state_elapsed_s >= duration: _begin_recovery("빈틈 · 모든 무기 피해 +25%")

func _begin_recovery(message: String) -> void:
	if boss_id == "aurel" and phase == 2 and not _chain_active:
		_chain_active = true
		_begin_next_pattern()
		return
	_chain_active = false
	hazards.clear()
	super._begin_recovery(message)

func _damage_area(area: Rect2, index: int) -> void:
	if not player.can_continue_combat_action() or not area.has_point(player.global_position+Vector2(0,-42)): return
	var event := DamageEvent.new()
	event.event_id = StringName("%s:pattern:%d:%d" % [attack_life_key(),attack_serial,index])
	event.attacker_id = attacker_id
	event.attack_id = StringName(boss_id+"_pattern")
	event.damage = (18 if phase == 2 else 14) + (3 if boss_id == "aurel" else 0)
	event.tags = PackedStringArray(["enemy","boss",boss_id])
	event.source_position = global_position
	var evading := player.invincible
	var result := player.receive_damage(event)
	if result == DamageReceiver.Result.APPLIED: hit_count += 1
	elif evading and result == DamageReceiver.Result.INVULNERABLE_BLOCKED:
		var ultimate := get_tree().get_first_node_in_group("ultimate_controller") as UltimateController
		if ultimate != null: ultimate.register_precise_evade()

func _fire_shot(angle: float) -> void:
	var shot := SHOT.instantiate() as EnemySeedProjectile
	shot.configure("%s:orb:%d:%d:%s" % [attack_life_key(),attack_serial,_fired_count,str(angle)],_aim.rotated(angle),12 if phase == 2 else 9,5.5,12.0)
	shot.attacker_id = attacker_id
	shot.attack_id = StringName(boss_id+"_orb")
	shot.damage_tags = PackedStringArray(["enemy","boss","projectile",boss_id])
	get_tree().current_scene.add_child(shot)
	shot.global_position = global_position+Vector2(0,-65)
	shot.projectile_sprite.texture = preload("res://assets/journey_bosses/sigil.svg")
	shot.projectile_sprite.scale *= .32

func _adjust_damage_event(event: DamageEvent) -> DamageEvent:
	var adjusted := event.copy_with_damage(event.damage)
	last_damage_multiplier = 1.25 if state == State.RECOVERY or boss_id == "belo" and current_pattern == 2 and state == State.CHARGING else 1.0
	last_adjusted_damage = maxi(1,roundi(event.damage*last_damage_multiplier))
	adjusted.damage = last_adjusted_damage
	return adjusted

func pattern_name(pattern: int) -> String:
	return String(PATTERNS[boss_id][clampi(pattern,0,2)])

func _set_state(new_state: int, message: String) -> void:
	super._set_state(new_state,message.replace("갑옷 멧돼지",NAMES[boss_id]))
	# Ground/fan telegraphs belong to this boss; the generic elite ring is redundant.
	if warning_ring != null: warning_ring.visible=false
	if warning_line != null: warning_line.visible=false

func _refresh_status() -> void:
	super._refresh_status()
	if status_label != null and damage_receiver != null:
		status_label.text = "%s · %d페이즈\n%d/%d · %s" % [NAMES[boss_id],phase,damage_receiver.health,damage_receiver.max_health,state_name()]

func current_metrics() -> Dictionary:
	var result := super.current_metrics()
	result.enemy_name = NAMES[boss_id]
	result.elite_weakness = "빈틈 · 모든 무기125%" if state == State.RECOVERY else "모든 무기 정상"
	return result

func _draw() -> void:
	if state not in [State.WARNING,State.CHARGING]: return
	for i in hazards.size():
		var rect := Rect2(hazards[i].position-global_position,hazards[i].size)
		var firing := state == State.CHARGING and (boss_id != "aurel" or current_pattern != 2 or _state_elapsed_s >= i*.45 and _state_elapsed_s < i*.45+.25)
		draw_rect(rect,Color(1,.45,.30,.48 if firing else .12))
		draw_rect(rect,Color("ffd88b"),false,3)
		for x in range(int(rect.position.x)+12,int(rect.end.x),38): draw_line(Vector2(x,rect.end.y-12),Vector2(x+16,rect.end.y-29),Color("ffd88b"),3)
		if boss_id == "belo" and current_pattern == 1:
			for x in [0,90,180]:
				var march := minf(_state_elapsed_s/1.15,1.0)*1050 if state == State.CHARGING else 0.0
				draw_texture_rect(ART.belo,Rect2(Vector2(3830+march-x-global_position.x,-64),Vector2(65,60)),false,Color(1,1,1,.7))
	if boss_id == "aurel" and current_pattern == 1 or boss_id == "ian" and current_pattern == 2 and echo_family in ["bow","staff"]:
		var count := 5 if phase == 2 and boss_id == "aurel" else 3
		for i in count:
			var direction := _aim.rotated((i-(count-1)*.5)*.22)
			draw_line(Vector2(0,-65),Vector2(0,-65)+direction*500,Color(.65,.95,.9,.45),3)
			draw_circle(Vector2(0,-65)+direction*180,10,Color("b7f3e9"))

	if boss_id == "ian" and current_pattern == 2:
		draw_texture_rect(WeaponPreparationArt.WEAPONS[echo_family],Rect2(-120,-110,80,80),false,Color(1,1,1,.7))

func region_enemy_name() -> String:
	return String(NAMES[boss_id])
