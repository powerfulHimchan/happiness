class_name PrototypeAbilityCodex
extends RefCounted

const PAGE_SIZE := 3

static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = PrototypeGrowthController.CARDS.duplicate(true)
	result.append_array(PrototypeJobRewards.CARDS.duplicate(true))
	return result

static func profile(id: String) -> Dictionary:
	for card in definitions():
		if card.id == id: return card
	return {}

static func valid_ids(value: Variant) -> bool:
	if not value is Array or value.size() > definitions().size(): return false
	for id in value:
		if not id is String or profile(id).is_empty(): return false
	return true

static func cards(discovered: Dictionary, ranks: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in definitions():
		var lines: Array[String] = []
		for line in card.lines: lines.append(String(line))
		var condition := "검 관련·무작위 후보" if card.category == "sword" else "활 관련·무작위 후보" if card.category == "bow" else "공용·무작위 후보"
		if card.has("job"):
			condition = String(PrototypeJobProgress.profile(card.job).name) + " 발현 후"
		elif card.has("requires"):
			condition = String(profile(card.requires[0]).title) + " 획득 후"
		lines.append("조건: " + condition)
		lines.append("도전당 1회 선택" if card.get("max_rank", 99) == 1 else "선택할 때마다 효과 누적")
		var tags: Array[String] = []
		for tag in card.tags:
			tags.append("%s +%.2f" % [PrototypeJobProgress.TAG_NAMES[tag], float(card.tags[tag]) * 0.70])
		lines.append(" · ".join(tags))
		var found := bool(discovered.get(card.id, false))
		var rank := int(ranks.get(card.id, 0))
		result.append({"id": card.id, "name": card.title, "open": found, "status": "이번 도전 %d등급" % rank if rank > 0 else "영구 발견" if found else "미발견 · 효과 미리 보기", "lines": lines})
	return result
