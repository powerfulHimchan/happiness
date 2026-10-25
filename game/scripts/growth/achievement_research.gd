class_name AchievementResearch
extends RefCounted

## GP-718–759: research spans durable discoveries across different runs.
const FAMILY_NAMES := {"sword":"검", "bow":"활", "fist":"주먹", "staff":"지팡이", "polearm":"장봉", "shield":"방패"}
const STYLES := ["study_5", "study_10", "mastery", "tactics", "ground", "air"]
const NAMES := ["연구 입문", "연구 심화", "숙련 기록가", "전술 기록가", "대지의 연구자", "하늘의 연구자"]

static func definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family in FAMILY_NAMES:
		for index in STYLES.size():
			var style: String = STYLES[index]
			var required: Array[String] = []
			match style:
				"mastery":
					for kind in PrototypeWeaponMastery.STYLES: required.append(family+"_mastery_"+kind)
				"tactics":
					for kind in PrototypeCombatTactics.STYLES: required.append(family+"_tactic_"+kind)
				"ground": required.assign([family+"_mastery_ground", family+"_tactic_ground_skill"])
				"air": required.assign([family+"_mastery_air", family+"_tactic_air_basic"])
			var target := 5 if style == "study_5" else 10 if style == "study_10" else required.size()
			var hint := "%s 능력 서로 다른 %d종 발견" % [FAMILY_NAMES[family], target] if required.is_empty() else "지상 숙련과 지상 스킬 전술 발견" if style == "ground" else "공중 숙련과 공중 기본 전술 발견" if style == "air" else "%s %s %d종 · 여러 도전 누적" % [FAMILY_NAMES[family], "숙련" if style == "mastery" else "전술", target]
			result.append({"id":"research_"+family+"_"+style, "name":FAMILY_NAMES[family]+" · "+NAMES[index], "category":"무기 연구" if required.is_empty() else "전술 연구", "target":target, "hint":hint, "source":"family" if required.is_empty() else "research", "key":family, "required":required, "ticket":718+result.size()})
	for support in PrototypeCombatTactics.SUPPORT:
		result.append({"id":"research_"+support.id, "name":support.title+"의 증인", "category":"공용 연구", "target":1, "hint":support.title+" 능력을 직접 선택해 발견", "source":"research", "key":"common", "required":[support.id], "ticket":718+result.size()})
	return result
