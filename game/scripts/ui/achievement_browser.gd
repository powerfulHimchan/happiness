class_name AchievementBrowser
extends RefCounted

## GP-760–767: read-only achievement browsing. Never persists view state.
const FILTERS := ["전체", "달성", "미달성", "장착 중"]
const SORTS := ["목록순", "진행률순", "이름순", "추천순"]

static func categories() -> Array[String]:
	var result: Array[String] = ["전체 분류"]
	for item in PermanentAchievements.DEFINITIONS:
		if item.category not in result: result.append(item.category)
	return result

static func _ratio(card: Dictionary) -> float:
	return float(card.progress) / float(card.target)

static func _group(card: Dictionary) -> int:
	return 0 if card.selected else 2 if card.open else 1

static func query(state: Dictionary, filter_index: int = 0, category_index: int = 0, sort_index: int = 0) -> Dictionary:
	var choices := categories()
	var filter := clampi(filter_index, 0, FILTERS.size()-1)
	var category := choices[clampi(category_index, 0, choices.size()-1)]
	var order := clampi(sort_index, 0, SORTS.size()-1)
	var cards: Array[Dictionary] = []
	var earned := 0
	for card in PermanentAchievements.cards(state):
		if card.open: earned += 1
		if (filter == 1 and not card.open) or (filter == 2 and card.open) or (filter == 3 and not card.selected): continue
		if category != choices[0] and card.category != category: continue
		cards.append(card)
	if order != 0:
		cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if order == 3 and _group(a) != _group(b): return _group(a) < _group(b)
			if order in [1, 3] and not is_equal_approx(_ratio(a), _ratio(b)): return _ratio(a) > _ratio(b)
			if order == 2 and a.name != b.name: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
			return String(a.id) < String(b.id))
	return {"cards":cards, "earned":earned, "locked":PermanentAchievements.DEFINITIONS.size()-earned, "total":PermanentAchievements.DEFINITIONS.size(), "visible":cards.size(), "filter":FILTERS[filter], "category":category, "sort":SORTS[order]}

static func toolbar(safe: Rect2) -> Dictionary:
	var result := {}
	for index in 3:
		result[["filter", "category", "sort"][index]] = Rect2(safe.position + safe.size*Vector2(0.05+index*0.31,0.34), safe.size*Vector2(0.28,0.07))
	return result

static func empty_card() -> Dictionary:
	return {"id":"", "name":"표시할 업적 없음", "category":"", "open":false, "selected":false, "progress":0, "target":1, "status":"필터나 분류를 바꿔 보세요", "lines":["이 조건에 맞는 업적이 없어요", "달성 업적은 영구 보존됩니다", "전체에서 모든 목표를 확인하세요", "칭호 변경은 달성 카드에서"]}
