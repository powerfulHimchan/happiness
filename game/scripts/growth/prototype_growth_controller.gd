class_name PrototypeGrowthController
extends Node

## GP-102: 런 단위 능력 선택과 기본 직업 성향·발현.
signal metrics_changed(metrics: Dictionary)
signal choices_requested(cards: Array[Dictionary], level: int, rerolls: int)
signal selection_finished
signal job_manifested(job: Dictionary)

@export var jobs_enabled: bool = true

const ORDINARY_XP := 10
const ELITE_XP := 30
const CARDS: Array[Dictionary] = [
	{"id": "sword_power", "title": "예리한 검", "category": "sword", "lines": ["검 기본 공격·스킬", "피해 +15%"], "tags": {"strength": 2.5, "determination": 1.5}},
	{"id": "bow_power", "title": "힘찬 시위", "category": "bow", "lines": ["활 기본 공격·스킬", "피해 +15%"], "tags": {"shooting": 2.5, "nature": 1.5}},
	{"id": "power", "title": "새벽의 힘", "category": "common", "lines": ["검·활 기본 공격·스킬", "피해 +10%"], "tags": {"strength": 1.25, "shooting": 1.25}},
	{"id": "vitality", "title": "튼튼한 심장", "category": "common", "lines": ["최대 체력 +20", "현재 체력 +20"], "tags": {"strength": 1.25, "nature": 0.75}},
	{"id": "recovery", "title": "다시 일어서기", "category": "common", "lines": ["최대 체력 +10", "체력 40 회복"], "tags": {"nature": 0.75, "determination": 0.75}},
]

var level: int = 1
var experience: int = 0
var total_experience: int = 0
var rerolls_remaining: int = 1
var choosing: bool = false
var run_active: bool = false
var offered_cards: Array[Dictionary] = []
var ranks: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _rewarded_lives: Dictionary = {}
var jobs := PrototypeJobProgress.new()
var awaiting_job_confirmation: bool = false
var _job_passive_applied: bool = false
var _evade_sequence: int = 0
var _last_scored_evade: int = -1

@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer
@onready var weapons: PrototypeWeaponController = get_node("../Player/PrototypeWeaponController") as PrototypeWeaponController


func _ready() -> void:
	rng.randomize()
	jobs.reset(weapons.active_weapon_id)
	weapons.sword_combat.hit_registered.connect(_on_weapon_hit.bind("sword"))
	weapons.bow_combat.hit_registered.connect(_on_weapon_hit.bind("bow"))
	(get_node("../Player/UltimateController") as UltimateController).precise_evade_registered.connect(_on_precise_evade)
	player.evade_started.connect(_on_evade_started)
	for node in get_tree().get_nodes_in_group("combat_enemy"):
		(node as PrototypeTarget).defeated.connect(_on_enemy_defeated)
	player.player_died.connect(stop_run)
	_emit_metrics()


func reset_run() -> void:
	var was_choosing := choosing or awaiting_job_confirmation
	level = 1
	experience = 0
	total_experience = 0
	rerolls_remaining = 1
	choosing = false
	run_active = true
	offered_cards.clear()
	ranks.clear()
	_rewarded_lives.clear()
	jobs.reset("sword")
	awaiting_job_confirmation = false
	_job_passive_applied = false
	_evade_sequence = 0
	_last_scored_evade = -1
	if was_choosing:
		selection_finished.emit()
	_emit_metrics()


func stop_run() -> void:
	run_active = false
	if choosing or awaiting_job_confirmation:
		choosing = false
		awaiting_job_confirmation = false
		offered_cards.clear()
		selection_finished.emit()


func next_level_experience() -> int:
	return 20 + (level - 1) * 5


func _on_enemy_defeated(target: PrototypeTarget) -> void:
	if not run_active or player.damage_receiver.dead \
	or not target.is_in_group("combat_enemy") or not target.is_visible_in_tree() \
	or not target.damage_receiver.dead:
		return
	var instance_id := target.get_instance_id()
	if int(_rewarded_lives.get(instance_id, -1)) == target.spawn_generation:
		return
	_rewarded_lives[instance_id] = target.spawn_generation
	var reward := ELITE_XP if target.is_in_group("elite_enemy") else ORDINARY_XP
	experience += reward
	total_experience += reward
	_offer_next_level()
	_emit_metrics()


func _offer_next_level() -> void:
	if choosing or awaiting_job_confirmation or not run_active or experience < next_level_experience():
		return
	experience -= next_level_experience()
	level += 1
	choosing = true
	offered_cards = _draw_cards()
	choices_requested.emit(offered_cards.duplicate(true), level, rerolls_remaining)


func reroll() -> bool:
	if not choosing or awaiting_job_confirmation or not run_active or rerolls_remaining <= 0:
		return false
	rerolls_remaining -= 1
	var previous := offered_cards.duplicate(true)
	for attempt in 12:
		offered_cards = _draw_cards()
		if offered_cards != previous:
			break
	if offered_cards == previous:
		for card in CARDS:
			if card["category"] == "common" and card not in offered_cards:
				offered_cards[1] = card.duplicate(true)
				break
	choices_requested.emit(offered_cards.duplicate(true), level, rerolls_remaining)
	_emit_metrics()
	return true


func choose_card(index: int) -> bool:
	if not choosing or awaiting_job_confirmation or not run_active or index < 0 or index >= offered_cards.size():
		return false
	var selected_tags: Dictionary = offered_cards[index].get("tags", {})
	var card_id := String(offered_cards[index]["id"])
	ranks[card_id] = int(ranks.get(card_id, 0)) + 1
	match card_id:
		"sword_power": player.growth_sword_bonus += 0.15
		"bow_power": player.growth_bow_bonus += 0.15
		"power": player.growth_common_bonus += 0.10
		"vitality": player.apply_growth_health(20, 20)
		"recovery": player.apply_growth_health(10, 40)
	choosing = false
	offered_cards.clear()
	if jobs_enabled:
		jobs.add_ability(selected_tags)
	if not _try_manifest_job():
		selection_finished.emit()
		_offer_next_level()
	_emit_metrics()
	return true


func _on_weapon_hit(_is_skill: bool, target: PrototypeTarget, damage: int, weapon: String) -> void:
	if not jobs_enabled or not run_active or player.damage_receiver.dead or damage <= 0 or not is_instance_valid(target) or not target.is_in_group("combat_enemy") or not target.is_visible_in_tree():
		return
	jobs.add_weapon_hit(weapon)
	_try_manifest_job()
	_emit_metrics()


func _on_evade_started() -> void:
	_evade_sequence += 1


func _on_precise_evade() -> void:
	if not jobs_enabled or not run_active or player.damage_receiver.dead or not player.invincible or _evade_sequence <= 0 or _last_scored_evade == _evade_sequence:
		return
	_last_scored_evade = _evade_sequence
	jobs.add_special(weapons.active_weapon_id)
	_try_manifest_job()
	_emit_metrics()


func _try_manifest_job() -> bool:
	if not jobs_enabled or not run_active or _job_passive_applied:
		return false
	var job := jobs.evaluate()
	if job.is_empty():
		return false
	_job_passive_applied = true
	awaiting_job_confirmation = true
	if job["weapon"] == "sword":
		player.growth_sword_bonus += 0.10
	else:
		player.growth_bow_bonus += 0.10
	player.set_job_emblem(String(job["id"]), job["color"])
	job_manifested.emit(job)
	return true


func acknowledge_job() -> bool:
	if not awaiting_job_confirmation or not run_active:
		return false
	awaiting_job_confirmation = false
	if choosing:
		choices_requested.emit(offered_cards.duplicate(true), level, rerolls_remaining)
	else:
		selection_finished.emit()
		_offer_next_level()
	_emit_metrics()
	return true


func _draw_cards() -> Array[Dictionary]:
	var related: Array[Dictionary] = []
	var common: Array[Dictionary] = []
	for card in CARDS:
		if card["category"] == weapons.active_weapon_id:
			related.append(card)
		elif card["category"] == "common":
			common.append(card)
	var result: Array[Dictionary] = [related[rng.randi_range(0, related.size() - 1)], common[rng.randi_range(0, common.size() - 1)]]
	var random_pool: Array[Dictionary] = []
	for card in CARDS:
		if card not in result:
			random_pool.append(card)
	result.append(random_pool[rng.randi_range(0, random_pool.size() - 1)])
	return result.duplicate(true)


func metrics_snapshot() -> Dictionary:
	return {"growth_level": level, "growth_xp": experience, "growth_next_xp": next_level_experience(), "growth_total_xp": total_experience, "growth_rerolls": rerolls_remaining, "growth_ranks": ranks.duplicate(), "growth_job_id": jobs.job_id, "growth_job_hud": jobs.hud_text(), "growth_job_contributions": jobs.contributions.duplicate(true)}


func _emit_metrics() -> void:
	metrics_changed.emit(metrics_snapshot())
