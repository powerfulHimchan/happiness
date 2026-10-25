class_name PrototypeCombatStats
extends RefCounted

## Attack 100 is the existing weapon damage baseline. Health stays in DamageReceiver.
const BASE_ATTACK := 100
const BASE_DEFENSE := 0
const BASE_CRITICAL_CHANCE := 0.0
const BASE_CRITICAL_DAMAGE := 150.0
const CARDS: Array[Dictionary] = [
	{"id":"stat_defense", "title":"단단한 결의", "category":"common", "lines":["방어력 +10", "방어력 / (100 + 방어력)만큼 피해 감소"], "tags":{"determination":0.75,"nature":0.75}, "max_rank":5},
	{"id":"stat_critical_chance", "title":"예리한 감각", "category":"common", "lines":["치명타 확률 +5%p", "모든 무기 공격·스킬·공격형 필살기"], "tags":{"strength":0.75,"shooting":0.75}, "max_rank":10},
	{"id":"stat_critical_damage", "title":"결정적 일격", "category":"common", "lines":["치명타 피해 +25%p", "150% → 175% · 비치명타 피해 유지"], "tags":{"strength":0.75,"determination":0.75}, "max_rank":5},
]

static func selected(ranks: Dictionary) -> Dictionary:
	var result := {}
	for card in CARDS:
		if int(ranks.get(card.id,0)) > 0: result[card.id] = int(ranks[card.id])
	return result

static func defense(ranks: Dictionary) -> int:
	return BASE_DEFENSE + clampi(int(ranks.get("stat_defense",0)),0,5) * 10

static func critical_chance(ranks: Dictionary) -> float:
	return clampf(BASE_CRITICAL_CHANCE + clampi(int(ranks.get("stat_critical_chance",0)),0,10) * 5.0,0.0,100.0)

static func critical_damage(ranks: Dictionary) -> float:
	return BASE_CRITICAL_DAMAGE + clampi(int(ranks.get("stat_critical_damage",0)),0,5) * 25.0

static func defense_multiplier(value: int) -> float:
	return 100.0 / (100.0 + maxi(0,value))
