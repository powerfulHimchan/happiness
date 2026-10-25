class_name PrototypeRunBuildView
extends RefCounted

## GP-141: 실제 도전 스냅샷을 조회용 카드로 표시한다. 저장·장착·능력 선택은 하지 않는다.
const TABS := ["보유 능력", "장비·스킬", "도전 정보"]
const PAGE_SIZE := 3
const ABILITY_FILTERS := ["전체", "공용", "검", "활", "주먹", "지팡이", "장봉", "방패", "직업"]
const ABILITY_ORDERS := ["목록순", "이름순", "등급순"]
const EQUIPMENT_FILTERS := ["전체", "주 무기", "보조 무기"]
const EQUIPMENT_ORDERS := ["목록순", "재사용 대기순", "자세별 피해", "전술 상태"]

static func filter_labels(tab: int) -> Array:
	return ABILITY_FILTERS if tab == 0 else EQUIPMENT_FILTERS if tab == 1 else []

static func order_labels(tab: int) -> Array:
	return ABILITY_ORDERS if tab == 0 else EQUIPMENT_ORDERS if tab == 1 else []

static func browse(tab: int, state: Dictionary, filter_index: int = 0, order_index: int = 0) -> Array[Dictionary]:
	var result := cards(tab,state)
	if state.is_empty(): return result
	if tab == 2:
		# Keep catalog order stable; pin the five-stat card in the information browser.
		for index in result.size():
			if result[index].id == "combat_stats":
				var stats: Dictionary = result[index]
				result.remove_at(index)
				result.insert(mini(1,result.size()),stats)
				break
		for index in result.size():
			if result[index].id == "hero_trait":
				var passive: Dictionary = result[index]
				result.remove_at(index)
				result.insert(mini(2,result.size()),passive)
				break
		return result
	if tab == 0:
		if filter_index > 0:
			var category: String = (["common"]+PrototypeWeaponRewards.FAMILY_IDS+["job"])[clampi(filter_index-1,0,7)]
			result = result.filter(func(card: Dictionary) -> bool:
				var profile := PrototypeAbilityCodex.profile(String(card.id))
				return not profile.is_empty() and (profile.has("job") if category == "job" else profile.category == category and not profile.has("job")))
		if order_index == 1:
			result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.name < b.name if a.name != b.name else a.id < b.id)
		elif order_index == 2:
			var ranks: Dictionary = state.growth.growth_ranks
			result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(ranks.get(a.id,0)) > int(ranks.get(b.id,0)) if ranks.get(a.id,0) != ranks.get(b.id,0) else a.id < b.id)
	else:
		if order_index in [2,3]:
			result.clear()
			for family in state.equipment:
				var lines: Array[String] = []
				if order_index == 2:
					var values: Dictionary = state.get("damage_stances",{}).get(family,{})
					lines.assign(["기본 피해100 기준 · 현재 체력/방벽", "지상 기본 %d · 공중 기본 %d" % [int(values.get("ground_basic",0)),int(values.get("air_basic",0))], "지상 스킬 %d · 공중 스킬 %d" % [int(values.get("ground_skill",0)),int(values.get("air_skill",0))], "거리·적 방어 보정 전 · 최종 반올림", "현재 장비·유물·성장 조건을 반영"])
				else:
					for line in state.get("tactic_conditions",{}).get(family,[]): lines.append(String(line))
					if lines.is_empty(): lines.append("선택한 무기 전술 없음")
					lines.append("체력 %d/%d · 방벽 %d" % [state.health.current,state.health.maximum,state.health.barrier])
					lines.append("열기 직전 상태 · 조회 중 조건 정지")
				result.append({"id":family,"weapon":family,"name":PrototypeWeaponRewards.family_name(family),"status":"주 무기" if family == state.active else "보조 무기","lines":lines,"open":true})
		elif order_index == 1:
			result = result.filter(func(card: Dictionary) -> bool: return card.has("remaining"))
			result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.remaining < b.remaining if a.remaining != b.remaining else a.id < b.id)
		if filter_index in [1,2]:
			result = result.filter(func(card: Dictionary) -> bool: return (card.get("weapon","") == state.active) == (filter_index == 1))
	if result.is_empty():
		result.append({"id":"empty","name":"해당 항목 없음","status":"다른 분류를 선택하세요","lines":["선택한 조건에 맞는 보유 항목이 없습니다","조회는 장착·성장·저장을 바꾸지 않습니다"],"open":false})
	return result

static func cards(tab: int, state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.is_empty(): return result
	var ranks: Dictionary = state.growth.growth_ranks
	match tab:
		0:
			for card in PrototypeAbilityCodex.cards(ranks, ranks):
				if int(ranks.get(card.id, 0)) > 0: result.append(card)
			if result.is_empty():
				result.append({"id": "empty", "name": "보유 능력 없음", "status": "레벨업 카드로 획득", "lines": ["선택한 능력만 여기에 표시합니다", "능력 도감에서는 모든 효과를 미리 봅니다"], "open": false})
		1:
			for weapon in state.equipment:
				var item := PrototypeWeaponRewards.profile(weapon, int(state.equipment[weapon]), String(state.blueprints[weapon]))
				var lines: Array[String] = []
				for line in item.lines: lines.append(String(line))
				lines.append("기본 피해100 기준 %d" % int(state.damage[weapon].basic))
				lines.append("스킬 피해100 기준 %d" % int(state.damage[weapon].skill))
				lines.append("성장·기억·장비·유물 반영 · 거리 보정 전")
				result.append({"id": weapon, "weapon":weapon, "name": item.name, "status": "주 무기" if state.active == weapon else "보조 무기", "lines": lines, "open": true})
			for weapon in state.equipment:
				for slot in 2:
					var id: String = state.skills[weapon][slot]
					var lines := PrototypeSkillRewards.lines(id, float(state.get("family_recharge", {}).get(weapon, state.recharge)))
					lines.append("남은 대기 %.1f초" % float(state.cooldowns[weapon][slot]))
					lines.append("표기 피해는 강화 전 기본값")
					result.append({"id": id, "weapon":weapon, "remaining":float(state.cooldowns[weapon][slot]), "name": PrototypeSkillRewards.SKILLS[id].display_name, "status": "%s · 슬롯 %d" % [PrototypeWeaponRewards.family_name(String(weapon)), slot + 1], "lines": lines, "open": true})
		2:
			var stage: Dictionary = state.stage
			result.append({"id": "progress", "name": "이번 도전", "status": "%d / %d 스테이지" % [int(stage.run_stage_number), int(stage.run_stage_count)], "lines": ["주인공 · " + PrototypeCharacters.display_name(String(state.get("character_id", "roan"))) + (" · 원정 %d" % int(stage.expedition) if stage.get("expedition", 0) > 0 else ""), String(stage.stage_section_name), String(stage.run_route_name), "현재 스테이지 %.1f초" % float(stage.stage_elapsed_s), "레벨 %d · 경험치 %d/%d" % [int(state.growth.growth_level), int(state.growth.growth_xp), int(state.growth.growth_next_xp)], "조회 중 전투와 대기시간 정지"], "open": true})
			if stage.get("expedition", 0) >= 2:
				result.append({"id": "expedition", "name": "원정 %d 규칙" % int(stage.expedition), "status": "체력 회복75%", "lines": ["웨이브 2마다 추가 정예", "체력 회복량 75% · 정수 올림", "회복약·구슬·흡수·성장·스킬에 적용", "방벽·부활 체력은 기존 효과"], "open": true})
				if stage.get("expedition", 0) >= 3:
					result[-1].lines.append("일반 적 연속 공격 +1 · 매번 재경고")
				if stage.get("expedition", 0) >= 4:
					result[-1].lines.append("보스 탄막·절단 +1 · 빈틈 뒤 재경고")
			if stage.get("expedition", 0) >= 5:
				result.append({"id": "stage_constraints", "name": "원정 5 · 웨이브2 제약", "status": String(stage.get("stage_constraint_hint", "")) if not String(stage.get("stage_constraint_hint", "")).is_empty() else "현재 스테이지 제약 없음", "lines": ["2·6스테이지 · 웨이브2 회복약 봉인", "4·8스테이지 · 웨이브2 새 필살기 봉인", "해당 웨이브 통과 즉시 해제", "잔량·게이지 보존 · 사용 중 필살기 유지"], "open": true})
			var story: Dictionary = state.get("story", {})
			if not story.is_empty():
				result.append({"id": "story", "name": "이번 여행의 기억", "status": "기억 조각 %d/%d" % [story.fragments.size(), PrototypeStory.FRAGMENTS.size()], "lines": ["이야기 장면 확인 %d개" % story.seen.size(), "시작 때까지 되감기 %d번" % story.rewinds, "이름과 외형은 실제 주인공 선택", "조각은 전투 능력을 바꾸지 않습니다"], "open": true})
			var companion: Dictionary = state.get("guardian_companion", {})
			if not companion.is_empty():
				result.append({"id": "guardian_companion", "name": "수호기사 동행", "status": "정예 지원 · 영구 해금", "lines": ["이후 새 도전에 자동 동행", "스테이지마다 정예에게 30피해", "지원한 스테이지 %d개" % companion.assisted_stages.size(), "이어하기로 지원을 중복하지 않습니다"], "open": true})
			var sera: Dictionary = state.get("sera_companion", {})
			if not sera.is_empty():
				result.append({"id": "sera_companion", "name": "세라 동행", "status": "정예 지원 · 영구 해금", "lines": ["이후 새 도전에 자동 동행", "스테이지마다 정예에게 40피해", "지원한 스테이지 %d개" % sera.assisted_stages.size(), "이어하기로 지원을 중복하지 않습니다"], "open": true})
			var health: Dictionary = state.health
			if stage.get("guardian_choice", "") != "":
				result.append({"id": "guardian", "name": "성문 수호기사", "status": GuardianDecision.label(String(stage.guardian_choice)), "lines": GuardianDecision.lines(String(stage.guardian_choice)), "open": true})
			if stage.get("run_mode") in ["regions", JourneyRoutePlan.MODE]:
				var regions: Array = stage.get("run_visited_regions", [])
				var names: Array[String] = []
				for id in regions:
					names.append("바람꽃 평원" if id == "wind" else String(PrototypeStageRunner.route_profile(String(id)).name))
				result.append({"id": "regions", "name": "전체 여정 · 10스테이지" if stage.get("run_mode") == JourneyRoutePlan.MODE else "네 지역 순회", "status": "통과 %d/4 · 남은 %d곳" % [regions.size(), int(stage.run_remaining_regions)], "lines": names if not names.is_empty() else ["각 지역을 두 구간씩 진행", "두 구간 완료 후 다음 지역 선택", "네 지역 완료 후 성문과 중심부"] if stage.get("run_mode") == JourneyRoutePlan.MODE else ["첫 연습 구간 이후 지역 선택", "미방문 두 지역 중 다음 목적지 선택", "네 지역을 한 번씩 통과합니다"], "open": true})
			result.append({"id": "health", "name": "생존 상태", "status": "체력 %d / %d" % [int(health.current), int(health.maximum)], "lines": ["방벽 %d / %d" % [int(health.barrier), int(health.barrier_max)], "%s %d / %d개" % [PrototypePotionRecipes.profile(state.recipe).name, int(health.potions), int(health.potion_max)], "회복약 · 최대 체력 %d%% 회복" % int(health.potion_percent), "생명 흡수 · 현재 %d%%" % int(health.lifesteal_percent), "공중 도약 해금" if bool(health.air_jump) else "공중 도약 미해금"], "open": true})
			result[-1].lines.append("처치 회복 · 적마다 체력 +%d" % int(health.get("victory_recovery", 0)) if int(health.get("victory_recovery", 0)) > 0 else "처치 회복 미해금")
			if int(health.get("evasive_barrier", 0)) > 0:
				result[-1].lines[0] += " · 정확 회피 +%d" % int(health.evasive_barrier)
			if int(health.get("potion_barrier", 0)) > 0:
				result[-1].lines[2] += " · 방벽 +%d" % int(health.potion_barrier)
			result[-1].lines.append("회복 구슬 획득 거리 %.2fm" % float(health.get("orb_radius_m", 0.76)))
			result[-1].lines.append("회복 구슬 · 체력 %d%% (+%d)" % [int(health.get("orb_percent", 10)), int(health.get("orb_heal", ceili(float(health.maximum) / 10.0)))])
			result[-1].lines.append("지상 회피 대기 %.3f초 · 받는 피해 %d%%" % [float(health.get("evade_cooldown", 0.45)), roundi(float(health.get("incoming_multiplier", 1.0)) * 100)])
			var job := PrototypeJobProgress.profile(String(state.growth.growth_job_id))
			var ultimate: Dictionary = state.ultimate
			var lines: Array[String] = [String(job.passive) if not job.is_empty() else "성향을 쌓아 직업 발현", String(ultimate.name), "게이지 %d / 100" % int(ultimate.gauge), "발동 중 · 남은 %.1f초" % float(ultimate.remaining) if bool(ultimate.active) else "발동 대기", "시간 수집 · 처치 게이지 +%d" % int(ultimate.get("defeat_gain", 5)) if int(ranks.get("time_collector", 0)) == 1 else "공격·회피로 게이지 충전"]
			if state.relic.get("id", "") == PrototypeRelic.COIN_ID and int(ranks.get("time_collector", 0)) == 0:
				lines[4] = "수집가의 동전 · 처치 게이지 +3"
			lines.append("다음 필살기 감속 %.1f초" % float(ultimate.get("next_duration", UltimateController.DURATION_S)))
			lines.append("게이지 기본%d · 스킬%d · 회피%d" % [int(ultimate.get("basic_gain", 4)), int(ultimate.get("skill_gain", 8)), int(ultimate.get("evade_gain", 12))])
			result.append({"id": "job", "name": "직업·필살기", "status": String(job.name) if not job.is_empty() else "직업 미발현", "lines": lines, "open": not job.is_empty()})
			var memory := PrototypeMemoryAbilities.profile(String(state.memory))
			lines = [PrototypeRelic.hud(state.relic), String(memory.name), String(memory.effect), "구출 조력 적용 중" if state.legacy == "rescue" else "파괴 핵 적용 중" if state.legacy == "destroy" else "일회 보상 미적용", "조회로 장비나 보상을 변경하지 않습니다"]
			result.append({"id": "relic", "name": "유물·기억", "status": "불사조 깃털 사용 완료" if state.relic.get("used", false) else "현재 도전에 적용된 효과", "lines": lines, "open": true})
			var stats: Dictionary = state.get("combat_stats",{})
			if not stats.is_empty():
				result.append({"id":"combat_stats", "name":"주인공 능력치", "status":PrototypeCharacters.display_name(String(state.get("character_id","roan"))), "lines":["공격력 %d · 방어력 %d" % [int(stats.attack),int(stats.defense)], "치명타 확률 %.1f%%" % float(stats.critical_chance), "치명타 피해 %.1f%% (총 피해 배율)" % float(stats.critical_damage), "체력 %d / %d" % [int(stats.health),int(stats.max_health)], "방어력에 의한 피해 감소 %.1f%%" % float(stats.damage_reduction), "공격력100 = 무기 기본값 · 무기별 강화 별도"], "open":true})
			var passive: Dictionary = state.get("hero_trait",{})
			if not passive.is_empty(): result.append({"id":"hero_trait","name":String(passive.name),"status":String(passive.status),"lines":passive.lines,"open":true})
	return result

static func layout(safe: Rect2, count: int) -> Dictionary:
	var base := PrototypeVillageView.layout(safe, maxi(1, count), false)
	for index in base.cards.size():
		base.cards[index].position.y = safe.position.y+safe.size.y*0.39
		base.cards[index].size.y = safe.size.y*0.37
	var tabs: Array[Rect2] = []
	var width := safe.size.x * 0.28
	for index in 3:
		tabs.append(Rect2(safe.position + Vector2(safe.size.x * (0.06 + index * 0.30), safe.size.y * 0.23), Vector2(width, safe.size.y * 0.07)))
	return {"cards": base.cards, "tabs": tabs, "filter":Rect2(safe.position+Vector2(safe.size.x*.05,safe.size.y*.315),Vector2(safe.size.x*.44,safe.size.y*.06)), "order":Rect2(safe.position+Vector2(safe.size.x*.51,safe.size.y*.315),Vector2(safe.size.x*.44,safe.size.y*.06)), "back": Rect2(safe.position + Vector2(safe.size.x * 0.30, safe.size.y * 0.86), Vector2(safe.size.x * 0.40, safe.size.y * 0.09)), "previous": Rect2(safe.position + Vector2(safe.size.x * 0.05, safe.size.y * 0.78), Vector2(safe.size.x * 0.23, safe.size.y * 0.055)), "next": Rect2(safe.position + Vector2(safe.size.x * 0.72, safe.size.y * 0.78), Vector2(safe.size.x * 0.23, safe.size.y * 0.055))}
