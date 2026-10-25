class_name PrototypeGrowthController
extends Node

## GP-103: 직업 전용 카드와 필살기 발현 보상을 포함하는 런 성장.
signal metrics_changed(metrics: Dictionary)
signal choices_requested(cards: Array[Dictionary], level: int, rerolls: int)
signal selection_finished
signal job_manifested(job: Dictionary)

@export var jobs_enabled: bool = true

const ORDINARY_XP := 10
const ELITE_XP := 30
const EVASIVE_BARRIER_RECOVERY := 5
const BASE_CARDS: Array[Dictionary] = [
	{"id": "sword_power", "title": "예리한 검", "category": "sword", "lines": ["검 기본 공격·스킬", "피해 +15%"], "tags": {"strength": 2.5, "determination": 1.5}},
	{"id": "bow_power", "title": "힘찬 시위", "category": "bow", "lines": ["활 기본 공격·스킬", "피해 +15%"], "tags": {"shooting": 2.5, "nature": 1.5}},
	{"id": "power", "title": "새벽의 힘", "category": "common", "lines": ["공격력 +10 · 모든 무기", "기본 공격·스킬·공격형 필살기 적용"], "tags": {"strength": 1.25, "shooting": 1.25}},
	{"id": "vitality", "title": "튼튼한 심장", "category": "common", "lines": ["최대 체력 +20", "현재 체력 +20"], "tags": {"strength": 1.25, "nature": 0.75}},
	{"id": "recovery", "title": "다시 일어서기", "category": "common", "lines": ["최대 체력 +10", "체력 40 회복"], "tags": {"nature": 0.75, "determination": 0.75}},
	{"id": "air_jump", "title": "공중 도약", "category": "common", "lines": ["공중에서 한 번 더 점프", "착지 시 충전 · 도전 중 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "lifesteal", "title": "생명 흡수", "category": "common", "lines": ["모든 무기 실제 피해의 5% 회복", "소수 회복 누적 · 도전 중 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "lifesteal_depth", "title": "깊은 흡수", "category": "common", "lines": ["생명 흡수: 항상 10% 회복", "위기의 흡수와 하나만 선택"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["lifesteal"], "excludes": ["lifesteal_crisis"]},
	{"id": "lifesteal_crisis", "title": "위기의 흡수", "category": "common", "lines": ["체력 30% 이하: 15% 회복", "평소 5% · 깊은 흡수와 하나만"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["lifesteal"], "excludes": ["lifesteal_depth"]},
	{"id": "magic_barrier", "title": "마력 방벽", "category": "common", "lines": ["피해 20을 먼저 흡수", "다음 스테이지 진입 시 충전"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "potion_pouch", "title": "회복약 주머니", "category": "common", "lines": ["회복약 1개 보충 · 최대 소지 +1", "기본·농축 적용 · 스테이지 간 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "nimble_evade", "title": "민첩한 회피", "category": "common", "lines": ["지상 회피 재사용 대기 -20%", "0.45초 → 0.36초 · 무적 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "fortified_barrier", "title": "견고한 방벽", "category": "common", "lines": ["방벽 최대 20→30 · 잔량 +10", "다음 스테이지에서 30 충전"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["magic_barrier"]},
	{"id": "time_collector", "title": "시간 수집", "category": "common", "lines": ["적 처치마다 필살기 게이지 +5", "선택 이후 적용 · 최대 100"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "time_echo", "title": "시간의 여운", "category": "common", "lines": ["다음 필살기부터 감속 시간 +1초", "공용·직업 적용 · 감속 비율 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["time_collector"]},
	{"id": "victory_recovery", "title": "처치 회복", "category": "common", "lines": ["적 처치마다 최대 체력 2% 회복", "선택 이후 적용 · 소수 올림"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "evasive_barrier", "title": "회피 방벽", "category": "common", "lines": ["정확한 회피마다 방벽 5 회복", "회피당 한 번 · 방벽 최대치까지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["magic_barrier"]},
	{"id": "restorative_barrier", "title": "회복 방벽", "category": "common", "lines": ["회복약 사용 시 방벽 10 회복", "실제 소비 시 · 방벽 최대치까지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["magic_barrier"]},
	{"id": "orb_magnet", "title": "구슬 자석", "category": "common", "lines": ["회복 구슬 획득 거리 2배", "0.76m → 1.52m · 회복량 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1},
	{"id": "orb_vitality", "title": "회복 구슬 강화", "category": "common", "lines": ["회복 구슬: 최대 체력 20% 회복", "10% → 20% · 소수 올림"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["orb_magnet"]},
	{"id": "time_collector_boost", "title": "시간 수집 강화", "category": "common", "lines": ["처치 필살기 게이지 5→8", "모래시계와 함께라면 10"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["time_collector"]},
	{"id": "evasive_barrier_boost", "title": "회피 방벽 강화", "category": "common", "lines": ["정확 회피 방벽 회복 5→8", "회피당 한 번 · 방벽 최대치까지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["evasive_barrier"]},
	{"id": "restorative_barrier_boost", "title": "회복 방벽 강화", "category": "common", "lines": ["회복약 소비 시 방벽 회복 10→15", "체력 회복량·회복약 개수 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["restorative_barrier"]},
	{"id": "victory_recovery_boost", "title": "처치 회복 강화", "category": "common", "lines": ["처치 체력 회복 2%→3%", "최대 체력 기준 · 소수 올림"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["victory_recovery"]},
	{"id": "potion_pouch_boost", "title": "확장 주머니", "category": "common", "lines": ["회복약 최대 소지 +1 · 1개 보충", "주머니와 합산 · 도전당 한 번"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["potion_pouch"]},
	{"id": "orb_magnet_boost", "title": "넓은 자석", "category": "common", "lines": ["회복 구슬 획득 거리 2배→3배", "1.52m → 2.28m · 회복량 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["orb_magnet"]},
	{"id": "time_echo_boost", "title": "깊은 여운", "category": "common", "lines": ["필살기 감속 시간 추가 +1초", "다음 발동부터 · 감속 비율 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["time_echo"]},
	{"id": "potion_mastery", "title": "회복약 숙련", "category": "common", "lines": ["회복약 최대 체력 회복 +5%p", "모든 조제 · 구슬/휴식 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["potion_pouch"]},
	{"id": "survival_instinct", "title": "생존 본능", "category": "common", "lines": ["체력30% 이하: 전투 피해 -10%", "방벽 흡수 전 · 현재 체력 기준"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["fortified_barrier"]},
	{"id": "calm_focus", "title": "차분한 집중", "category": "common", "lines": ["체력80% 이상: 스킬 피해1.15배", "모든 무기 적용 · 기본/필살기 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["power"]},
	{"id": "healing_flow", "title": "치유의 흐름", "category": "common", "lines": ["깊은 흡수10% → 15% 회복", "실제 피해 기준 · 누적 소수 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["lifesteal_depth"]},
	{"id": "victory_resilience", "title": "회복 탄력성", "category": "common", "lines": ["강화 처치 회복3% → 4%", "현재 최대 체력 기준 · 소수 올림"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["victory_recovery_boost"]},
	{"id": "barrier_focus", "title": "방벽 집중", "category": "common", "lines": ["방벽 잔량: 스킬1.15배", "모든 무기 · 타격 시 잔량 기준"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["magic_barrier"]},
	{"id": "crisis_power", "title": "위기의 힘", "category": "common", "lines": ["체력30% 이하: 기본1.2배", "모든 무기 기본만 적용"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["power"]},
	{"id": "nimble_mastery", "title": "회피 숙련", "category": "common", "lines": ["지상 회피 대기 추가 -10%", "민첩과 곱연산 · 무적 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["nimble_evade"]},
	{"id": "orb_bloom", "title": "구슬 개화", "category": "common", "lines": ["회복 구슬 회복20% → 25%", "최대 체력 기준 · 소수 올림"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["orb_vitality"]},
	{"id": "potion_efficiency", "title": "회복약 정통", "category": "common", "lines": ["숙련 회복약 회복 추가 +5%p", "모든 조제 · 개수 유지"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["potion_mastery"]},
	{"id": "time_attunement", "title": "시간 조율", "category": "common", "lines": ["적중 게이지 기본5/스킬10", "유물과 합산 · 최대100"], "tags": {"nature": 0.75, "determination": 0.75}, "max_rank": 1, "requires": ["time_collector"]},
	{"id": "staff_power", "title": "맑은 마력", "category": "staff", "lines": ["지팡이 공격·스킬·필살기", "피해 +15%"], "tags": {"magic": 2.5, "element": 1.5}},
	{"id": "polearm_power", "title": "흔들림 없는 봉", "category": "polearm", "lines": ["장봉 공격·스킬·필살기", "피해 +15%"], "tags": {"focus": 2.5, "harmony": 1.5}},
	{"id": "shield_power", "title": "굳센 방패", "category": "shield", "lines": ["방패 공격·스킬·필살기", "피해 +15%"], "tags": {"defense": 2.5, "faith": 1.5}},
	{"id": "fist_power", "title": "날쌘 주먹", "category": "fist", "lines": ["주먹 기본 공격·스킬", "피해 +15%"], "tags": {"technique": 2.5, "chain": 1.5}},
]

static var CARDS: Array[Dictionary] = _build_cards()

static func _build_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = BASE_CARDS.duplicate(true)
	result.append_array(PrototypeCombatStats.CARDS)
	result.append_array(PrototypeStatSpecializations.CARDS)
	result.append_array(PrototypeCombatLinks.CARDS)
	result.append_array(PrototypeWeaponTraining.CARDS)
	result.append_array(PrototypeWeaponMastery.CARDS)
	result.append_array(PrototypeCombatTactics.CARDS)
	return result

var level: int = 1
var experience: int = 0
var total_experience: int = 0
var rerolls_remaining: int = 1
var choosing: bool = false
var run_active: bool = false
var offered_cards: Array[Dictionary] = []
var ranks: Dictionary = {}
var record_ability: Callable
var defeat_recovery_allowed: Callable
var precise_evade_reward_allowed: Callable
var evolution_allowed: Callable
var selection_message: String = ""
var rng := RandomNumberGenerator.new()
var _rewarded_lives: Dictionary = {}
var jobs := PrototypeJobProgress.new()
var awaiting_job_confirmation: bool = false
var _job_passive_applied: bool = false
var _evade_sequence: int = 0
var _last_scored_evade: int = -1
var _last_barrier_evade: int = -1

@onready var player: PrototypePlayer = get_node("../Player") as PrototypePlayer
@onready var weapons: PrototypeWeaponController = get_node("../Player/PrototypeWeaponController") as PrototypeWeaponController
@onready var ultimate: UltimateController = get_node("../Player/UltimateController") as UltimateController


func _ready() -> void:
	rng.randomize()
	jobs.reset(weapons.active_weapon_id)
	weapons.sword_combat.hit_registered.connect(_on_weapon_hit.bind("sword"))
	weapons.bow_combat.hit_registered.connect(_on_weapon_hit.bind("bow"))
	weapons.fist_combat.hit_registered.connect(_on_weapon_hit.bind("fist"))
	weapons.staff_combat.hit_registered.connect(_on_weapon_hit.bind("staff"))
	weapons.polearm_combat.hit_registered.connect(_on_weapon_hit.bind("polearm"))
	weapons.shield_combat.hit_registered.connect(_on_weapon_hit.bind("shield"))
	(get_node("../Player/UltimateController") as UltimateController).precise_evade_registered.connect(_on_precise_evade)
	player.evade_started.connect(_on_evade_started)
	for node in get_tree().get_nodes_in_group("combat_enemy"):
		(node as PrototypeTarget).defeated.connect(_on_enemy_defeated)
	player.player_died.connect(stop_run)
	_emit_metrics()


func reset_run(starting_weapon: String = "sword") -> void:
	player.barrier_focus_unlocked = false
	player.crisis_power_unlocked = false
	player.nimble_mastery_unlocked = false
	player.orb_bloom_unlocked = false
	player.potion_efficiency_unlocked = false
	player.time_attunement_unlocked = false
	player.survival_instinct_unlocked = false
	player.calm_focus_unlocked = false
	player.healing_flow_unlocked = false
	ultimate.time_echo_boost_unlocked = false
	player.set_potion_pouch_boost_unlocked(false)
	player.set_potion_mastery_unlocked(false)
	player.set_orb_magnet_boost_unlocked(false)
	ultimate.set_time_collector_boost_unlocked(false)
	player.set_orb_magnet_unlocked(false)
	player.set_restorative_barrier_unlocked(false)
	ultimate.time_echo_unlocked = false
	player.set_nimble_evade_unlocked(false)
	player.set_potion_pouch_unlocked(false)
	player.set_barrier_unlocked(false)
	player.set_double_jump_unlocked(false)
	player.set_lifesteal_unlocked(false)
	var was_choosing := choosing or awaiting_job_confirmation
	level = 1
	experience = 0
	total_experience = 0
	rerolls_remaining = 1
	choosing = false
	run_active = true
	offered_cards.clear()
	ranks.clear()
	player.weapon_training.clear()
	player.weapon_mastery.clear()
	player.combat_tactics.clear()
	player.stat_ranks.clear()
	player.stat_specializations.clear()
	player.combat_links.reset()
	selection_message = ""
	_rewarded_lives.clear()
	jobs.reset(starting_weapon)
	awaiting_job_confirmation = false
	_job_passive_applied = false
	_evade_sequence = 0
	_last_scored_evade = -1
	_last_barrier_evade = -1
	if was_choosing:
		selection_finished.emit()
	_emit_metrics()


func begin_next_stage() -> void:
	player.recharge_barrier()
	rerolls_remaining = 1
	_emit_metrics()


func checkpoint_snapshot() -> Dictionary:
	return {"level": level, "xp": experience, "total_xp": total_experience, "rerolls": rerolls_remaining, "ranks": ranks.duplicate(true), "job": jobs.job_id, "contributions": jobs.contributions.duplicate(true), "recent": jobs.recent_ability.duplicate(true)}


func restore_checkpoint(state: Dictionary) -> void:
	reset_run()
	level = int(state.level)
	experience = int(state.xp)
	total_experience = int(state.total_xp)
	rerolls_remaining = int(state.rerolls)
	ranks = state.ranks.duplicate(true)
	player.weapon_training = PrototypeWeaponTraining.selected(ranks)
	player.weapon_mastery = PrototypeWeaponMastery.selected(ranks)
	player.combat_tactics = PrototypeCombatTactics.selected(ranks)
	player.stat_ranks = PrototypeCombatStats.selected(ranks)
	player.stat_specializations = PrototypeStatSpecializations.selected(ranks)
	player.combat_links.learn(ranks)
	ultimate.set_time_collector_boost_unlocked(int(ranks.get("time_collector_boost", 0)) == 1)
	player.set_orb_magnet_unlocked(int(ranks.get("orb_magnet", 0)) == 1)
	player.set_orb_vitality_unlocked(int(ranks.get("orb_vitality", 0)) == 1)
	ultimate.time_echo_unlocked = int(ranks.get("time_echo", 0)) == 1
	player.set_nimble_evade_unlocked(int(ranks.get("nimble_evade", 0)) == 1)
	player.set_potion_pouch_unlocked(int(ranks.get("potion_pouch", 0)) == 1)
	player.set_barrier_unlocked(int(ranks.get("magic_barrier", 0)) == 1)
	player.set_fortified_barrier_unlocked(int(ranks.get("fortified_barrier", 0)) == 1)
	player.set_restorative_barrier_unlocked(int(ranks.get("restorative_barrier", 0)) == 1)
	player.set_restorative_barrier_boost_unlocked(int(ranks.get("restorative_barrier_boost", 0)) == 1)
	player.set_double_jump_unlocked(int(ranks.get("air_jump", 0)) == 1)
	player.set_lifesteal_unlocked(int(ranks.get("lifesteal", 0)) == 1)
	for branch in ["lifesteal_depth", "lifesteal_crisis"]:
		if ranks.has(branch): player.set_lifesteal_branch(branch)
	player.set_potion_pouch_boost_unlocked(int(ranks.get("potion_pouch_boost", 0)) == 1)
	player.set_potion_mastery_unlocked(int(ranks.get("potion_mastery", 0)) == 1)
	player.set_orb_magnet_boost_unlocked(int(ranks.get("orb_magnet_boost", 0)) == 1)
	ultimate.time_echo_boost_unlocked = int(ranks.get("time_echo_boost", 0)) == 1
	player.survival_instinct_unlocked = int(ranks.get("survival_instinct", 0)) == 1
	player.calm_focus_unlocked = int(ranks.get("calm_focus", 0)) == 1
	player.healing_flow_unlocked = int(ranks.get("healing_flow", 0)) == 1
	player.barrier_focus_unlocked = int(ranks.get("barrier_focus", 0)) == 1
	player.crisis_power_unlocked = int(ranks.get("crisis_power", 0)) == 1
	player.nimble_mastery_unlocked = int(ranks.get("nimble_mastery", 0)) == 1
	player.orb_bloom_unlocked = int(ranks.get("orb_bloom", 0)) == 1
	player.potion_efficiency_unlocked = int(ranks.get("potion_efficiency", 0)) == 1
	player.time_attunement_unlocked = int(ranks.get("time_attunement", 0)) == 1
	jobs.job_id = String(state.job)
	jobs.contributions = state.contributions.duplicate(true)
	jobs.recent_ability = state.recent.duplicate(true)
	_job_passive_applied = not jobs.job_id.is_empty()
	# 이미 저장된 피해 보너스를 사용한다. 발현 보상을 다시 더하지 않는다.
	var job := jobs.current_job()
	if not job.is_empty():
		player.set_job_emblem(jobs.job_id, job.color)
	_emit_metrics()


func stop_run() -> void:
	run_active = false
	if choosing or awaiting_job_confirmation:
		choosing = false
		awaiting_job_confirmation = false
		offered_cards.clear()
		selection_finished.emit()
	_emit_metrics()


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
	# 이 처치로 열린 카드에서 얻은 능력은 다음 처치부터 적용한다.
	if target.last_defeat_in_combat and victory_recovery_amount() > 0 and defeat_recovery_allowed.is_valid() and defeat_recovery_allowed.call():
		player.apply_growth_health(0, victory_recovery_amount())
	var collected := int(ranks.get("time_collector", 0)) == 1
	var coin_reward: bool = player.has_active_relic(PrototypeRelic.COIN_ID) and target.last_defeat_in_combat and defeat_recovery_allowed.is_valid() and defeat_recovery_allowed.call()
	if collected or coin_reward:
		ultimate.grant_defeat_gauge(collected, coin_reward)
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
			if card["category"] == "common" and card not in offered_cards and _card_available(card):
				offered_cards[1] = card.duplicate(true)
				break
	choices_requested.emit(offered_cards.duplicate(true), level, rerolls_remaining)
	_emit_metrics()
	return true


func choose_card(index: int) -> bool:
	if not choosing or awaiting_job_confirmation or not run_active or index < 0 or index >= offered_cards.size():
		return false
	if not _card_available(offered_cards[index]):
		return false
	# 기록에 성공한 실제 선택만 효과를 적용한다. 실패 시 같은 카드를 다시 누른다.
	if record_ability.is_valid() and record_ability.call([String(offered_cards[index].id)]) != OK:
		selection_message = "능력 기록 저장 실패 · 카드를 다시 선택하세요"
		_emit_metrics()
		return false
	selection_message = ""
	var selected_tags: Dictionary = offered_cards[index].get("tags", {})
	var card_id := String(offered_cards[index]["id"])
	ranks[card_id] = int(ranks.get(card_id, 0)) + 1
	player.weapon_training = PrototypeWeaponTraining.selected(ranks)
	player.weapon_mastery = PrototypeWeaponMastery.selected(ranks)
	player.combat_tactics = PrototypeCombatTactics.selected(ranks)
	player.stat_ranks = PrototypeCombatStats.selected(ranks)
	player.stat_specializations = PrototypeStatSpecializations.selected(ranks)
	player.combat_links.learn(ranks)
	match card_id:
		"barrier_focus": player.barrier_focus_unlocked = true
		"crisis_power": player.crisis_power_unlocked = true
		"nimble_mastery": player.nimble_mastery_unlocked = true
		"orb_bloom": player.orb_bloom_unlocked = true
		"potion_efficiency": player.potion_efficiency_unlocked = true
		"time_attunement": player.time_attunement_unlocked = true
		"survival_instinct": player.survival_instinct_unlocked = true
		"calm_focus": player.calm_focus_unlocked = true
		"healing_flow": player.healing_flow_unlocked = true
		"potion_pouch_boost": player.set_potion_pouch_boost_unlocked(true, true)
		"potion_mastery": player.set_potion_mastery_unlocked(true)
		"orb_magnet_boost": player.set_orb_magnet_boost_unlocked(true)
		"time_echo_boost": ultimate.time_echo_boost_unlocked = true
		"time_collector_boost": ultimate.set_time_collector_boost_unlocked(true)
		"orb_magnet": player.set_orb_magnet_unlocked(true)
		"orb_vitality": player.set_orb_vitality_unlocked(true)
		"restorative_barrier": player.set_restorative_barrier_unlocked(true)
		"restorative_barrier_boost": player.set_restorative_barrier_boost_unlocked(true)
		"time_echo": ultimate.time_echo_unlocked = true
		"nimble_evade": player.set_nimble_evade_unlocked(true)
		"potion_pouch": player.set_potion_pouch_unlocked(true, true)
		"lifesteal_depth", "lifesteal_crisis": player.set_lifesteal_branch(card_id)
		"magic_barrier": player.set_barrier_unlocked(true)
		"fortified_barrier": player.set_fortified_barrier_unlocked(true, true)
		"lifesteal": player.set_lifesteal_unlocked(true)
		"air_jump": player.set_double_jump_unlocked(true)
		"sword_power": player.growth_sword_bonus += 0.15
		"bow_power": player.growth_bow_bonus += 0.15
		"fist_power": player.growth_fist_bonus += 0.15
		"staff_power": player.growth_staff_bonus += 0.15
		"polearm_power": player.growth_polearm_bonus += 0.15
		"shield_power": player.growth_shield_bonus += 0.15
		"power": player.growth_common_bonus += 0.10
		"vitality": player.apply_growth_health(20, 20)
		"recovery": player.apply_growth_health(10, 40)
		"vanguard_edge": player.growth_sword_bonus += 0.20
		"vanguard_vigor": player.apply_growth_health(30, 30)
		"tracker_focus": player.growth_bow_bonus += 0.20
		"tracker_breath": player.apply_growth_health(20, 35)
		"vanguard_dawn_edge": player.growth_sword_bonus += 0.30
		"tracker_forest_aim": player.growth_bow_bonus += 0.30
		"dragon_flame": player.growth_sword_bonus += 0.20
		"dragon_heart": player.apply_growth_health(30, 30)
		"breaker_edge": player.growth_sword_bonus += 0.30
		"breaker_vigor", "storm_breath": player.apply_growth_health(20, 40)
		"storm_arrow": player.growth_bow_bonus += 0.25
	var effect: Dictionary = offered_cards[index].get("job_effect", {})
	if not effect.is_empty():
		var job := PrototypeJobProgress.profile(String(offered_cards[index].job))
		if job.weapon == "sword": player.growth_sword_bonus += float(effect.get("damage", 0.0))
		elif job.weapon == "bow": player.growth_bow_bonus += float(effect.get("damage", 0.0))
		else: player.set("growth_" + String(job.weapon) + "_bonus",float(player.get("growth_" + String(job.weapon) + "_bonus")) + float(effect.get("damage",0.0)))
		player.apply_growth_health(int(effect.get("health", 0)), int(effect.get("heal", 0)))
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
	if not run_active or player.damage_receiver.dead or not player.invincible or _evade_sequence <= 0:
		return
	if evasive_barrier_amount() > 0 and _last_barrier_evade != _evade_sequence \
	and player.is_ground_evading() \
	and precise_evade_reward_allowed.is_valid() and precise_evade_reward_allowed.call():
		# 가득 찬 방벽에서도 이 회피의 기회를 소비한다. 같은 회피로 재충전하지 않는다.
		_last_barrier_evade = _evade_sequence
		player.recover_barrier(evasive_barrier_amount())
	if not jobs_enabled or _last_scored_evade == _evade_sequence:
		return
	_last_scored_evade = _evade_sequence
	jobs.add_special(weapons.active_weapon_id)
	_try_manifest_job()
	_emit_metrics()


func _try_manifest_job() -> bool:
	if not jobs_enabled or not run_active or awaiting_job_confirmation:
		return false
	if _job_passive_applied:
		return try_evolve_job()
	var job := jobs.evaluate()
	if job.is_empty():
		return false
	_job_passive_applied = true
	awaiting_job_confirmation = true
	if job["weapon"] == "sword":
		player.growth_sword_bonus += 0.10
	elif job["weapon"] == "bow":
		player.growth_bow_bonus += 0.10
	else:
		player.set("growth_" + String(job.weapon) + "_bonus",float(player.get("growth_" + String(job.weapon) + "_bonus")) + 0.10)
	player.set_job_emblem(String(job["id"]), job["color"])
	job_manifested.emit(job)
	return true


func try_evolve_job() -> bool:
	if not jobs_enabled or not run_active or player.damage_receiver.dead or awaiting_job_confirmation or choosing or not jobs.can_evolve() or not evolution_allowed.is_valid() or not evolution_allowed.call():
		return false
	var job := jobs.evolution_profile(ranks)
	jobs.job_id = String(job.id)
	if job.weapon == "sword":
		player.growth_sword_bonus += float(job.damage_bonus)
	elif job.weapon == "bow":
		player.growth_bow_bonus += float(job.damage_bonus)
	else:
		player.set("growth_" + String(job.weapon) + "_bonus",float(player.get("growth_" + String(job.weapon) + "_bonus")) + float(job.damage_bonus))
	# 최대 체력 증가는 회복75% 규칙과 분리하고 실제 회복만 기존 경로로 처리한다.
	player.apply_growth_health(int(job.health_bonus), int(job.health_bonus))
	awaiting_job_confirmation = true
	player.set_job_emblem(jobs.job_id, job.color)
	job_manifested.emit(job)
	_emit_metrics()
	return true


func acknowledge_job() -> bool:
	if not awaiting_job_confirmation or not run_active or ultimate.selected_profile.get("job", "") != jobs.job_id:
		return false
	awaiting_job_confirmation = false
	if choosing:
		choices_requested.emit(offered_cards.duplicate(true), level, rerolls_remaining)
	else:
		selection_finished.emit()
		_offer_next_level()
	_emit_metrics()
	return true


func choose_job_ultimate(index: int) -> bool:
	if not awaiting_job_confirmation or not run_active:
		return false
	var candidates := PrototypeJobRewards.ultimates_for(jobs.job_id)
	if index < 0 or index >= candidates.size():
		return false
	if not ultimate.select_job_ultimate(jobs.job_id, String(candidates[index]["id"])):
		return false
	return acknowledge_job()


func _draw_cards() -> Array[Dictionary]:
	var related: Array[Dictionary] = []
	var common: Array[Dictionary] = []
	var pool: Array[Dictionary] = []
	for card in CARDS:
		if _card_available(card):
			pool.append(card)
	var job_cards := PrototypeJobRewards.cards_for(jobs.job_id).filter(_card_available)
	pool.append_array(job_cards)
	for card in pool:
		if card["category"] == weapons.active_weapon_id:
			related.append(card)
		elif card["category"] == "common":
			common.append(card)
	if not job_cards.is_empty():
		related = job_cards
	var result: Array[Dictionary] = [related[rng.randi_range(0, related.size() - 1)], common[rng.randi_range(0, common.size() - 1)]]
	var random_pool: Array[Dictionary] = []
	for card in pool:
		if card not in result:
			random_pool.append(card)
	result.append(random_pool[rng.randi_range(0, random_pool.size() - 1)])
	return result.duplicate(true)


func victory_recovery_amount() -> int:
	if not run_active or int(ranks.get("victory_recovery", 0)) != 1: return 0
	var percent := 5 if int(ranks.get("victory_resilience_master", 0)) == 1 else 4 if int(ranks.get("victory_resilience", 0)) == 1 else 3 if int(ranks.get("victory_recovery_boost", 0)) == 1 else 2
	return ceili(player.damage_receiver.max_health * percent / 100.0)


func evasive_barrier_amount() -> int:
	if not run_active or int(ranks.get("evasive_barrier", 0)) != 1 or not player.barrier_unlocked: return 0
	return 11 if int(ranks.get("evasive_barrier_master", 0)) == 1 else 8 if int(ranks.get("evasive_barrier_boost", 0)) == 1 else EVASIVE_BARRIER_RECOVERY


func metrics_snapshot() -> Dictionary:
	return {"growth_selection_message": selection_message, "growth_level": level, "growth_xp": experience, "growth_next_xp": next_level_experience(), "growth_total_xp": total_experience, "growth_rerolls": rerolls_remaining, "growth_ranks": ranks.duplicate(), "growth_job_id": jobs.job_id, "growth_run_active": run_active, "growth_job_hud": jobs.hud_text(), "growth_job_contributions": jobs.contributions.duplicate(true)}


func _emit_metrics() -> void:
	metrics_changed.emit(metrics_snapshot())


func _card_available(card: Dictionary) -> bool:
	if not PrototypeCombatLinks.prerequisites(card,ranks): return false
	if card.get("category", "") in PrototypeWeaponRewards.FAMILY_IDS and not weapons.equipment.has(card.category): return false
	if card.has("job") and card.job != jobs.job_id and card.job != PrototypeJobProgress.base_job(jobs.job_id): return false
	for required in card.get("requires", []):
		if int(ranks.get(required, 0)) <= 0: return false
	for excluded in card.get("excludes", []):
		if ranks.has(excluded): return false
	return not card.has("max_rank") or int(ranks.get(card.id, 0)) < int(card.max_rank)
