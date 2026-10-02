class_name PrototypeVillageView
extends RefCounted

## GP-114: 기존 영구 해금과 로컬 기록을 읽는 마을. 방문으로 저장을 변경하지 않는다.
const FACILITIES := ["forge", "memories", "records"]
const TITLES := {"village": "시간의 닻 마을", "forge": "대장간 · 설계도", "memories": "기억의 쉼터", "records": "광장 · 도전 기록"}

static func layout(safe: Rect2, card_count: int, can_continue: bool) -> Dictionary:
	var cards: Array[Rect2] = []
	var gap := safe.size.x * 0.02
	var width := (safe.size.x * 0.90 - gap * (card_count - 1)) / card_count
	for i in card_count:
		cards.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (width + gap), safe.size.y * 0.34), Vector2(width, safe.size.y * 0.42)))
	var count := 3 if can_continue else 2
	var button_width := (safe.size.x * 0.90 - gap * (count - 1)) / count
	var buttons: Array[Rect2] = []
	for i in count:
		buttons.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (button_width + gap), safe.size.y * 0.85), Vector2(button_width, safe.size.y * 0.09)))
	return {"cards": cards, "back": buttons[0], "start": buttons[1], "continue": buttons[2] if can_continue else Rect2()}

static func cards(page: String, memories: Dictionary, blueprints: Dictionary, summary: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match page:
		"forge":
			for id in ["clockwork_sword", "clockwork_bow"]:
				var unlocked := bool(blueprints.get(id, false))
				var lines: Array[String] = []
				if unlocked:
					for grade in [1, 2]:
						var profile := PrototypeWeaponRewards.profile(String(PrototypeWeaponRewards.BLUEPRINTS[id].weapon), grade, id)
						lines.append("%s · 피해 +%d%%" % [PrototypeWeaponRewards.GRADE_NAMES[grade], int(round(float(profile.damage) * 100))])
						lines.append("고유 효과 +%d%%" % int(round(float(profile.unique) * 100)))
					lines.append("검: 스킬 강화" if id == "clockwork_sword" else "활: 기본 공격 강화")
					lines.append("보조 고유 효과는 절반 적용")
				else:
					lines.assign(["보스 파괴로 영구 해금", "해금 후 정예 무기 보상에 등장"])
				result.append({"name": String(PrototypeWeaponRewards.BLUEPRINTS[id].name), "open": unlocked, "lines": lines})
		"memories":
			for id in ["clockwork_guard", "core_echo"]:
				var profile := PrototypeMemoryAbilities.profile(id)
				result.append({"name": profile.name, "open": bool(memories.get(id, false)), "lines": [profile.effect, profile.condition, "새 도전 준비에서 하나를 선택"]})
		"records":
			result.append({"name": "도전 이력", "open": true, "lines": ["총 도전 %d회" % int(summary.get("run_count", 0)), "완주 %d회" % int(summary.get("completed_run_count", 0)), "중단 %d회" % int(summary.get("incomplete_run_count", 0)), "진행 중 도전은 집계 전"]})
			for key in ["best_completion_s", "average_completion_s"]:
				var seconds := float(summary.get(key, 0.0))
				result.append({"name": "최고 완주" if key == "best_completion_s" else "평균 완주", "open": true, "lines": ["%.1f초" % seconds if seconds > 0 else "아직 완주 기록 없음", "로컬에 저장한 모든 완주 기준"]})
		_:
			result.assign([
				{"name": "대장간", "open": not blueprints.is_empty(), "lines": ["무기 설계도 %d/2" % blueprints.size(), "태엽 검 · 태엽 활", "설계와 등급별 효과 살펴보기"]},
				{"name": "기억의 쉼터", "open": not memories.is_empty(), "lines": ["영구 기억 %d/2" % memories.size(), "태엽 수호 · 핵의 잔향", "기억의 능력과 해금 조건"]},
				{"name": "광장 기록", "open": true, "lines": ["여행의 발자취", "완주 · 중단 · 소요 시간", "이 기기에 저장된 도전 기록"]},
			])
	return result
