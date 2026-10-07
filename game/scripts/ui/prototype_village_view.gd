class_name PrototypeVillageView
extends RefCounted

## GP-114: 기존 영구 해금과 로컬 기록을 읽는 마을. 방문으로 저장을 변경하지 않는다.
const FACILITIES := ["forge", "memories", "records", "jobs", "apothecary", "atlas"]
const TAB_LABELS := {"jobs": "직업 도감", "abilities": "능력 도감", "memories": "영구 기억", "relics": "유물 도감", "forge": "무기 설계도", "skills": "스킬 도감", "weapons": "무기 도감"}
const TITLES := {"village": "시간의 닻 마을", "forge": "대장간 · 설계도", "skills": "대장간 · 스킬 도감", "weapons": "대장간 · 무기 도감", "memories": "기억의 쉼터 · 영구 기억", "relics": "기억의 쉼터 · 유물 도감", "records": "광장 · 도전 기록", "jobs": "직업 도감", "abilities": "능력 도감", "apothecary": "약방 · 회복약 조제", "atlas": "지도 제작소 · 경로 도감"}

static func layout(safe: Rect2, card_count: int, can_continue: bool) -> Dictionary:
	var cards: Array[Rect2] = []
	var gap := safe.size.x * 0.02
	var columns := 3 if card_count > 5 else card_count
	var rows := ceili(float(card_count) / columns)
	var width := (safe.size.x * 0.90 - gap * (columns - 1)) / columns
	var row_gap := safe.size.y * 0.025
	var height := (safe.size.y * 0.42 - row_gap * (rows - 1)) / rows
	for i in card_count:
		cards.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + (i % columns) * (width + gap), safe.size.y * 0.34 + int(i / columns) * (height + row_gap)), Vector2(width, height)))
	var count := 3 if can_continue else 2
	var button_width := (safe.size.x * 0.90 - gap * (count - 1)) / count
	var buttons: Array[Rect2] = []
	for i in count:
		buttons.append(Rect2(safe.position + Vector2(safe.size.x * 0.05 + i * (button_width + gap), safe.size.y * 0.85), Vector2(button_width, safe.size.y * 0.09)))
	return {"cards": cards, "back": buttons[0], "start": buttons[1], "continue": buttons[2] if can_continue else Rect2()}

static func cards(page: String, memories: Dictionary, blueprints: Dictionary, summary: Dictionary, discovered_jobs: Dictionary = {}, current_job: String = "", potion_recipe: String = PrototypePotionRecipes.BASIC, surveyed_routes: Dictionary = {}, current_relic: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match page:
		"relics":
			result = PrototypeRelic.codex_cards(current_relic)
		"atlas":
			result = PrototypeRouteAtlas.cards(surveyed_routes)
		"apothecary":
			for id in PrototypePotionRecipes.IDS:
				var recipe := PrototypePotionRecipes.profile(id)
				var unlocked := PrototypePotionRecipes.available(id, memories)
				var lines: Array[String] = ["최대 체력 %d%% 회복 · 정수 올림" % roundi(float(recipe.ratio) * 100), "도전당 %d개 · 스테이지 간 보존" % int(recipe.count), "두 번 나누어 회복" if id == PrototypePotionRecipes.BASIC else "한 번에 크게 회복", "다음 새 도전에 적용 · 이어하기 유지"]
				if not unlocked:
					lines[2] = "태엽 기사 구출로 약초사 정착"
				result.append({"id": id, "name": recipe.name, "open": unlocked, "status": "다음 도전 조제 · 선택됨" if id == potion_recipe else "눌러 조제 선택" if unlocked else "잠김 · 보스 구출 필요", "lines": lines})
		"jobs":
			for job in PrototypeJobProgress.JOBS:
				var discovered := bool(discovered_jobs.get(job.id, false))
				var abilities := PrototypeJobRewards.cards_for(job.id)
				var ultimates := PrototypeJobRewards.ultimates_for(job.id)
				var conditions := "%s %.0f · %s %.0f" % [PrototypeJobProgress.TAG_NAMES[job.primary], PrototypeJobProgress.PRIMARY_THRESHOLD, PrototypeJobProgress.TAG_NAMES[job.secondary], PrototypeJobProgress.SECONDARY_THRESHOLD]
				var lines: Array[String] = [conditions, job.passive, "능력: %s · %s" % [abilities[0].title, abilities[1].title], "필살기: " + String(ultimates[0].name), "필살기: " + String(ultimates[1].name), "능력 70% · 무기 20% · 특수 10%"]
				var status := "발견 · 현재 도전" if discovered and current_job == job.id else "영구 발견" if discovered else "미발견 · 성향을 채워 발현"
				result.append({"id": job.id, "name": job.name, "open": discovered, "status": status, "lines": lines})
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
			result.append({"name": "도전 이력", "open": true, "lines": ["총 도전 %d회" % int(summary.get("run_count", 0)), "완주 %d회" % int(summary.get("completed_run_count", 0)), "미완료 %d회" % int(summary.get("incomplete_run_count", 0)), "미완료에는 진행 중 도전도 포함"]})
			for key in ["best_completion_s", "average_completion_s"]:
				var seconds := float(summary.get(key, 0.0))
				result.append({"name": "최고 완주" if key == "best_completion_s" else "평균 완주", "open": true, "lines": ["%.1f초" % seconds if seconds > 0 else "아직 완주 기록 없음", "로컬에 저장한 모든 완주 기준"]})
		_:
			result.assign([
				{"name": "대장간", "open": not blueprints.is_empty(), "status": "무기·스킬 도감 언제든 조회", "lines": ["무기 설계도 %d/2" % blueprints.size(), "태엽 설계도 · 스킬 %d종" % PrototypeSkillRewards.SKILLS.size(), "등급 · 보조 효과 · 장착 상태"]},
				{"name": "기억의 쉼터", "open": not memories.is_empty(), "status": "기억 해금 · 유물 도감" if not memories.is_empty() else "유물 도감은 언제든 조회", "lines": ["영구 기억 %d/2" % memories.size(), "영구 기억 · 도전 중 유물", "효과 · 획득 조건 · 보유 상태"]},
				{"name": "광장 기록", "open": true, "lines": ["여행의 발자취", "완주 · 미완료 · 소요 시간", "이 기기에 저장된 도전 기록"]},
				{"name": "성장 도감", "open": true, "status": "직업 · 능력 조건 확인", "lines": ["발견한 직업 %d/2" % discovered_jobs.size(), "선봉대 · 추적자 · 능력 도감", "조건 · 강화 가지 · 효과"]},
				{"name": "약방", "open": bool(memories.get("clockwork_guard", false)), "status": "약초사 정착" if memories.get("clockwork_guard", false) else "보스 구출로 약초사 정착", "lines": ["기본 25% · 2개", "농축 40% · 1개", "다음 도전의 회복약 선택"]},
				{"name": "지도 제작소", "open": true, "status": "언제든 경로 비교", "lines": ["답사한 경로 %d/3" % surveyed_routes.size(), "풀숲 · 바람 · 태엽 폐허", "지형 · 보너스 · 통과 기록"]},
			])
	return result
