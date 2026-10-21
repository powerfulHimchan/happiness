class_name PrototypeWeaponTraining
extends RefCounted

## One source of truth for family-specific basic/skill growth. Rebuilt from saved ranks.
const CARDS: Array[Dictionary] = [
	{"id": "fist_basic_training", "title": "권격 단련", "category": "fist", "lines": ["권갑 기본 공격 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"technique": 2.5, "chain": 1.5}, "max_rank": 1, "requires": ["fist_power"], "training_kind": "basic", "training_bonus": 0.2},
	{"id": "fist_skill_training", "title": "권법 숙련", "category": "fist", "lines": ["권갑 스킬 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"technique": 2.5, "chain": 1.5}, "max_rank": 1, "requires": ["fist_power"], "training_kind": "skill", "training_bonus": 0.2},
	{"id": "staff_basic_training", "title": "마법탄 단련", "category": "staff", "lines": ["지팡이 기본 공격 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"magic": 2.5, "element": 1.5}, "max_rank": 1, "requires": ["staff_power"], "training_kind": "basic", "training_bonus": 0.2},
	{"id": "staff_skill_training", "title": "원소 숙련", "category": "staff", "lines": ["지팡이 스킬 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"magic": 2.5, "element": 1.5}, "max_rank": 1, "requires": ["staff_power"], "training_kind": "skill", "training_bonus": 0.2},
	{"id": "polearm_basic_training", "title": "봉술 단련", "category": "polearm", "lines": ["장봉 기본 공격 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"focus": 2.5, "harmony": 1.5}, "max_rank": 1, "requires": ["polearm_power"], "training_kind": "basic", "training_bonus": 0.2},
	{"id": "polearm_skill_training", "title": "윤회 숙련", "category": "polearm", "lines": ["장봉 스킬 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"focus": 2.5, "harmony": 1.5}, "max_rank": 1, "requires": ["polearm_power"], "training_kind": "skill", "training_bonus": 0.2},
	{"id": "shield_basic_training", "title": "방패격 단련", "category": "shield", "lines": ["방패 기본 공격 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"defense": 2.5, "faith": 1.5}, "max_rank": 1, "requires": ["shield_power"], "training_kind": "basic", "training_bonus": 0.2},
	{"id": "shield_skill_training", "title": "서약 숙련", "category": "shield", "lines": ["방패 스킬 피해 +20%p", "같은 무기 강화와 합산"], "tags": {"defense": 2.5, "faith": 1.5}, "max_rank": 1, "requires": ["shield_power"], "training_kind": "skill", "training_bonus": 0.2},
]

static func selected(ranks: Dictionary) -> Dictionary:
	var result := {}
	for card in CARDS:
		if int(ranks.get(card.id, 0)) == 1: result[card.id] = 1
	return result

static func damage_bonus(ranks: Dictionary, family: String, kind: String) -> float:
	var result := 0.0
	for card in CARDS:
		if card.category == family and card.training_kind == kind and int(ranks.get(card.id, 0)) == 1:
			result += float(card.training_bonus)
	return result
