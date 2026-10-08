class_name PrototypeRunBuildView
extends RefCounted

## GP-141: 실제 도전 스냅샷을 조회용 카드로 표시한다. 저장·장착·능력 선택은 하지 않는다.
const TABS := ["보유 능력", "장비·스킬", "도전 정보"]
const PAGE_SIZE := 3

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
			for weapon in ["sword", "bow"]:
				var item := PrototypeWeaponRewards.profile(weapon, int(state.equipment[weapon]), String(state.blueprints[weapon]))
				var lines: Array[String] = []
				for line in item.lines: lines.append(String(line))
				lines.append("기본 피해100 기준 %d" % int(state.damage[weapon].basic))
				lines.append("스킬 피해100 기준 %d" % int(state.damage[weapon].skill))
				lines.append("성장·기억·장비 반영 · 거리 보정 전")
				result.append({"id": weapon, "name": item.name, "status": "주 무기" if state.active == weapon else "보조 무기", "lines": lines, "open": true})
			for weapon in ["sword", "bow"]:
				for slot in 2:
					var id: String = state.skills[weapon][slot]
					var lines := PrototypeSkillRewards.lines(id, float(state.recharge))
					lines.append("남은 대기 %.1f초" % float(state.cooldowns[weapon][slot]))
					lines.append("표기 피해는 강화 전 기본값")
					result.append({"id": id, "name": PrototypeSkillRewards.SKILLS[id].display_name, "status": "%s · 슬롯 %d" % ["검" if weapon == "sword" else "활", slot + 1], "lines": lines, "open": true})
		2:
			var stage: Dictionary = state.stage
			result.append({"id": "progress", "name": "이번 도전", "status": "%d / %d 스테이지" % [int(stage.run_stage_number), int(stage.run_stage_count)], "lines": [String(stage.stage_section_name), String(stage.run_route_name), "현재 스테이지 %.1f초" % float(stage.stage_elapsed_s), "레벨 %d · 경험치 %d/%d" % [int(state.growth.growth_level), int(state.growth.growth_xp), int(state.growth.growth_next_xp)], "조회 중 전투와 대기시간 정지"], "open": true})
			var health: Dictionary = state.health
			result.append({"id": "health", "name": "생존 상태", "status": "체력 %d / %d" % [int(health.current), int(health.maximum)], "lines": ["방벽 %d / %d" % [int(health.barrier), int(health.barrier_max)], "%s %d / %d개" % [PrototypePotionRecipes.profile(state.recipe).name, int(health.potions), int(health.potion_max)], "회복약 · 최대 체력 %d%% 회복" % int(health.potion_percent), "생명 흡수 · 현재 %d%%" % int(health.lifesteal_percent), "공중 도약 해금" if bool(health.air_jump) else "공중 도약 미해금"], "open": true})
			result[-1].lines.append("처치 회복 · 적마다 체력 +%d" % int(health.get("victory_recovery", 0)) if int(health.get("victory_recovery", 0)) > 0 else "처치 회복 미해금")
			var job := PrototypeJobProgress.profile(String(state.growth.growth_job_id))
			var ultimate: Dictionary = state.ultimate
			var lines: Array[String] = [String(job.passive) if not job.is_empty() else "성향을 쌓아 직업 발현", String(ultimate.name), "게이지 %d / 100" % int(ultimate.gauge), "발동 중 · 남은 %.1f초" % float(ultimate.remaining) if bool(ultimate.active) else "발동 대기", "시간 수집 · 처치 게이지 +5" if int(ranks.get("time_collector", 0)) == 1 else "공격·회피로 게이지 충전"]
			lines.append("다음 필살기 감속 %.1f초" % float(ultimate.get("next_duration", UltimateController.DURATION_S)))
			result.append({"id": "job", "name": "직업·필살기", "status": String(job.name) if not job.is_empty() else "직업 미발현", "lines": lines, "open": not job.is_empty()})
			var memory := PrototypeMemoryAbilities.profile(String(state.memory))
			lines = [PrototypeRelic.hud(state.relic), String(memory.name), String(memory.effect), "구출 조력 적용 중" if state.legacy == "rescue" else "파괴 핵 적용 중" if state.legacy == "destroy" else "일회 보상 미적용", "조회로 장비나 보상을 변경하지 않습니다"]
			result.append({"id": "relic", "name": "유물·기억", "status": "불사조 깃털 사용 완료" if state.relic.get("used", false) else "현재 도전에 적용된 효과", "lines": lines, "open": true})
	return result

static func layout(safe: Rect2, count: int) -> Dictionary:
	var base := PrototypeVillageView.layout(safe, maxi(1, count), false)
	var tabs: Array[Rect2] = []
	var width := safe.size.x * 0.28
	for index in 3:
		tabs.append(Rect2(safe.position + Vector2(safe.size.x * (0.06 + index * 0.30), safe.size.y * 0.23), Vector2(width, safe.size.y * 0.07)))
	return {"cards": base.cards, "tabs": tabs, "back": Rect2(safe.position + Vector2(safe.size.x * 0.30, safe.size.y * 0.86), Vector2(safe.size.x * 0.40, safe.size.y * 0.09)), "previous": Rect2(safe.position + Vector2(safe.size.x * 0.05, safe.size.y * 0.78), Vector2(safe.size.x * 0.23, safe.size.y * 0.055)), "next": Rect2(safe.position + Vector2(safe.size.x * 0.72, safe.size.y * 0.78), Vector2(safe.size.x * 0.23, safe.size.y * 0.055))}
