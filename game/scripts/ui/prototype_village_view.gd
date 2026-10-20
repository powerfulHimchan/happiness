class_name PrototypeVillageView
extends RefCounted

## GP-114: 기존 영구 해금과 로컬 기록을 읽는 마을. 방문으로 저장을 변경하지 않는다.
const FACILITIES := ["forge", "memories", "records", "jobs", "apothecary", "atlas"]
const HISTORY_PAGE_SIZE := 3
const RECORD_TABS := ["records", "record_lengths", "history"]
const TAB_LABELS := {"advanced_jobs": "상위 직업", "bonds": "세라의 인연", "record_lengths": "길이별 통계", "records": "전체 통계", "history": "최근 도전", "jobs": "직업 도감", "abilities": "능력 도감", "memories": "영구 기억", "relics": "유물 도감", "forge": "무기 설계도", "skills": "스킬 도감", "weapons": "무기 도감"}
const TITLES := {"advanced_jobs": "상위 직업 도감", "bonds": "기억의 쉼터 · 세라의 인연", "record_lengths": "광장 · 도전 길이별 통계", "history": "광장 · 최근 도전", "village": "시간의 닻 마을", "forge": "대장간 · 설계도", "skills": "대장간 · 스킬 도감", "weapons": "대장간 · 무기 도감", "memories": "기억의 쉼터 · 영구 기억", "relics": "기억의 쉼터 · 유물 도감", "records": "광장 · 도전 기록", "jobs": "직업 도감", "abilities": "능력 도감", "apothecary": "약방 · 회복약 조제", "atlas": "지도 제작소 · 경로 도감"}

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

static func cards(page: String, memories: Dictionary, blueprints: Dictionary, summary: Dictionary, discovered_jobs: Dictionary = {}, current_job: String = "", potion_recipe: String = PrototypePotionRecipes.BASIC, surveyed_routes: Dictionary = {}, current_relic: Dictionary = {}, sera_choices: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match page:
		"advanced_jobs":
			for job in PrototypeJobProgress.ADVANCED_JOBS:
				var found := bool(discovered_jobs.get(job.id, false))
				result.append({"id": job.id, "name": job.name, "open": found, "status": "진화 · 현재 도전" if current_job == job.id else "영구 발견" if found else "미발견 · 조건을 채워 자동 진화", "lines": ["전체 여정 7스테이지 이후 · 선봉대", "근력 8 · 투지 5 (70/20/10 성향)", job.passive, "능력: 용염의 칼날 · 용의 심장", "필살기: 용염 폭발 / 불꽃의 수호", "선봉대 능력 계승 · 필살기는 하나 교체", "새 도전에서는 다시 조건을 채웁니다"]})
		"bonds":
			for choice in ["rescue", "destroy"]:
				var unlocked: bool = sera_choices.get(choice, false) == true
				result.append({"id": "sera_" + choice, "name": "세라 " + GuardianDecision.label(choice), "open": unlocked, "status": "영구 기록 · 해금 완료" if unlocked else "미발견 · 전체 여정에서 선택", "lines": ["왕관의 명령에서 친구를 구출" if choice == "rescue" else "세라와 왕관의 힘을 끝낸 선택", "다음 새 도전 정예마다 40피해 지원" if choice == "rescue" else "약속의 검·왕관의 활 설계도 해금", "다른 여정에서 두 선택 모두 기록 가능", "도전 기록 초기화와 별도로 유지"]})
		"relics":
			result = PrototypeRelic.codex_cards(current_relic)
		"atlas":
			result = PrototypeRouteAtlas.cards(surveyed_routes)
		"apothecary":
			for id in PrototypePotionRecipes.IDS:
				var recipe := PrototypePotionRecipes.profile(id)
				var unlocked := PrototypePotionRecipes.available(id, memories)
				var lines: Array[String] = ["최대 체력 %d%% 회복 · 정수 올림" % roundi(float(recipe.ratio) * 100), "도전당 %d개 · 스테이지 간 보존" % int(recipe.count), PrototypePotionRecipes.strategy(id), "다음 새 도전에 적용 · 이어하기 유지"]
				if not unlocked:
					lines[2] = PrototypePotionRecipes.unlock_condition(id)
				result.append({"id": id, "name": recipe.name, "open": unlocked, "status": "다음 도전 조제 · 선택됨" if id == potion_recipe else "눌러 조제 선택" if unlocked else "잠김 · 보스 파괴 필요" if id == PrototypePotionRecipes.PORTIONED else "잠김 · 보스 구출 필요", "lines": lines})
		"jobs":
			for job in PrototypeJobProgress.JOBS:
				var discovered := bool(discovered_jobs.get(job.id, false))
				var abilities := PrototypeJobRewards.cards_for(job.id)
				var ultimates := PrototypeJobRewards.ultimates_for(job.id)
				var conditions := "%s %.0f · %s %.0f" % [PrototypeJobProgress.TAG_NAMES[job.primary], PrototypeJobProgress.PRIMARY_THRESHOLD, PrototypeJobProgress.TAG_NAMES[job.secondary], PrototypeJobProgress.SECONDARY_THRESHOLD]
				var lines: Array[String] = [conditions, job.passive, "능력: %s · %s" % [abilities[0].title, abilities[1].title], "필살기: " + String(ultimates[0].name), "필살기: " + String(ultimates[1].name), "능력 70% · 무기 20% · 특수 10%"]
				for extra in ultimates.slice(2):
					lines.append("필살기: " + String(extra.name))
				lines.append("전용 강화: " + String(abilities[2].title))
				var status := "발견 · 현재 도전" if discovered and current_job == job.id else "영구 발견" if discovered else "미발견 · 성향을 채워 발현"
				result.append({"id": job.id, "name": job.name, "open": discovered, "status": status, "lines": lines})
		"forge":
			for id in PrototypeWeaponRewards.PERMANENT_DESIGNS:
				var design := PrototypeWeaponRewards.design_profile(id)
				var unlocked := bool(blueprints.get(id, false))
				var lines: Array[String] = []
				if unlocked:
					for grade in [1, 2]:
						var profile := PrototypeWeaponRewards.profile(String(design.weapon), grade, id)
						lines.append("%s · 피해 +%d%%" % [PrototypeWeaponRewards.GRADE_NAMES[grade], int(round(float(profile.damage) * 100))])
						lines.append("고유 효과 +%d%%" % int(round(float(profile.unique) * 100)))
					lines.append(("검: " if design.weapon == "sword" else "활: ") + ("스킬 강화" if design.get("kind", "skill" if design.weapon == "sword" else "basic") == "skill" else "기본 공격 강화"))
					lines.append("보조 고유 효과는 절반 적용")
				else:
					lines.assign(["세라 파괴로 영구 해금" if id in PrototypeWeaponRewards.SERA_DESIGNS else "성문 수호기사 파괴로 영구 해금" if id in PrototypeWeaponRewards.GUARDIAN_DESIGNS else "보스 파괴로 영구 해금", "해금 후 정예 무기 보상에 등장"])
				result.append({"id": id, "name": String(design.name), "open": unlocked, "lines": lines})
		"memories":
			for id in ["clockwork_guard", "core_echo"]:
				var profile := PrototypeMemoryAbilities.profile(id)
				result.append({"name": profile.name, "open": bool(memories.get(id, false)), "lines": [profile.effect, profile.condition, "새 도전 준비에서 하나를 선택"]})
		"history":
			for run in summary.get("recent_runs", []):
				var complete := bool(run.get("completed", false))
				var choice := String(run.get("boss_choice", ""))
				var lines: Array[String] = []
				if complete:
					lines.assign(["%d스테이지 완주" % int(run.stage_number), "완주 시간 %.1f초" % float(run.completion_s), "보스 구출" if choice == "rescue" else "보스 파괴" if choice == "destroy" else "보스 선택 기록 없음"])
				else:
					lines.assign(["마지막 기록: %d스테이지" % int(run.stage_number), "완료한 스테이지 %d개" % int(run.completed_stages), "진행 중인 도전도 포함", "완주 시간은 완료 후 표시"])
				if run.get("story_enabled", false) == true:
					lines.append("이야기 여행" + (" · " + PrototypeStory.CHRONICLES[String(run.chronicle)].name if PrototypeStory.CHRONICLES.has(String(run.get("chronicle", ""))) else ""))
				lines.append("주인공 · " + PrototypeCharacters.display_name(String(run.get("character_id", "roan"))))
				if run.get("run_mode") == JourneyRoutePlan.MODE: lines.append("전체 여정 · 10스테이지" + (" · 원정 %d" % int(run.expedition) if run.get("expedition", 0) > 0 else ""))
				if complete and run.get("guardian_choice") in ["rescue", "destroy"]: lines[2] += " · 성문 수호기사 " + GuardianDecision.label(String(run.guardian_choice))
				if complete and run.get("final_boss") == SeraEncounter.ID: lines[2] = "세라 " + GuardianDecision.label(choice) + (" · 성문 수호기사 " + GuardianDecision.label(String(run.guardian_choice)) if run.get("guardian_choice") in ["rescue", "destroy"] else "")
				if run.get("run_mode") == "regions": lines.append("네 지역 순회 · 5스테이지")
				if complete and run.get("ending_id", "") in FinalRitual.IDS: lines[0] = String(ArrivalEnding.PROFILES[String(run.ending_id)].name) + " 엔딩 · 10스테이지"
				result.append({"id": run.id, "name": "전체 여정 %d" % (result.size() + 1) if run.get("run_mode") == JourneyRoutePlan.MODE else "지역 순회 %d" % (result.size() + 1) if run.get("run_mode") == "regions" else "최근 도전 %d" % (result.size() + 1), "open": true, "status": "심장 제압" if complete and run.get("heart_cleared", false) else "완주" if complete else "미완료", "lines": lines})
			if result.is_empty():
				result.append({"name": "아직 도전 기록 없음", "open": true, "status": "새 여행을 시작해 보세요", "lines": ["이 기기의 최근 도전 12개", "이어하기는 같은 도전으로 표시", "열람은 저장 상태를 바꾸지 않아요"]})
		"record_lengths":
			var by_length: Dictionary = summary.get("completion_by_stage_count", {})
			for count in [3, 5, 10]:
				var stats: Dictionary = by_length.get(str(count), {})
				var completed := int(stats.get("completed_run_count", 0))
				var lines: Array[String] = []
				for metric in [["best_completion_s", "최고"], ["average_completion_s", "평균"], ["total_completion_s", "누적"]]:
					lines.append("%s 완주 시간 %.1f초" % [metric[1], float(stats.get(metric[0], 0.0))] if completed > 0 else "%s 시간 · 아직 기록 없음" % metric[1])
				lines.append("같은 길이의 완주만 집계")
				result.append({"id": str(count), "name": "%d스테이지 도전" % count, "open": true, "status": "완주 %d회" % completed, "lines": lines})
		"records":
			result.append({"name": "도전 이력", "open": true, "lines": ["총 도전 %d회" % int(summary.get("run_count", 0)), "완주 %d회" % int(summary.get("completed_run_count", 0)), "미완료 %d회" % int(summary.get("incomplete_run_count", 0)), "미완료에는 진행 중 도전도 포함"]})
			for key in ["best_completion_s", "average_completion_s"]:
				var seconds := float(summary.get(key, 0.0))
				result.append({"name": "최고 완주" if key == "best_completion_s" else "평균 완주", "open": true, "lines": ["%.1f초" % seconds if seconds > 0 else "아직 완주 기록 없음", "모든 길이의 완주 기록 기준"]})
		_:
			result.assign([
				{"name": "대장간", "open": not blueprints.is_empty(), "status": "무기·스킬 도감 언제든 조회", "lines": ["무기 설계도 %d/%d" % [blueprints.size(), PrototypeWeaponRewards.PERMANENT_DESIGNS.size()], "태엽·수호·세라 무기 · 스킬 %d종" % PrototypeSkillRewards.SKILLS.size(), "등급 · 보조 효과 · 장착 상태"]},
				{"name": "기억의 쉼터", "open": not memories.is_empty() or not sera_choices.is_empty(), "status": "기억 · 유물 · 세라의 인연", "lines": ["영구 기억 %d/2 · 세라 인연 %d/2" % [memories.size(), sera_choices.size()], "영구 기억 · 유물 · 세라 지원", "효과 · 획득 조건 · 보유 상태"]},
				{"name": "광장 기록", "open": true, "lines": ["여행의 발자취", "완주 · 미완료 · 소요 시간", "이 기기에 저장된 도전 기록"]},
				{"name": "성장 도감", "open": true, "status": "직업 · 능력 조건 확인", "lines": ["발견한 직업 %d/2" % discovered_jobs.size(), "선봉대 · 추적자 · 능력 도감", "조건 · 강화 가지 · 효과"]},
				{"name": "약방", "open": bool(memories.get("clockwork_guard", false)) or bool(memories.get("core_echo", false)), "status": "약초사 정착" if memories.get("clockwork_guard", false) else "소분 조제 해금" if memories.get("core_echo", false) else "구출: 농축 · 파괴: 소분", "lines": ["기본 25% · 2개", "농축 40%·1개 / 소분 20%·3개", "다음 도전의 회복약 선택"]},
				{"name": "지도 제작소", "open": true, "status": "언제든 경로 비교", "lines": ["답사한 경로 %d/%d" % [surveyed_routes.size(), PrototypeRouteAtlas.IDS.size()], "풀숲 · 바람 · 태엽 · 숲 · 유적", "지형 · 보너스 · 통과 기록"]},
			])
	return result
