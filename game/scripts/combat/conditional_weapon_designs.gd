class_name ConditionalWeaponDesigns
extends RefCounted

const FAMILIES := ["sword","bow","fist","staff","polearm","shield"]
const NAMES := ["검","활","권갑","지팡이","장봉","방패"]
const STYLES := ["calm","crisis","barrier","ground","air"]
const TITLES := ["평정","역전","결계","대지","창공"]
const CONDITIONS := ["체력80% 이상","체력30% 이하","방벽 잔량","지상","공중"]
const KINDS := ["basic","skill","skill","basic","skill"]
static var DESIGNS: Dictionary = definitions()

static func definitions() -> Dictionary:
	var result := {}
	for family in FAMILIES.size():
		for style in STYLES.size():
			result["stance_"+STYLES[style]+"_"+FAMILIES[family]] = {"weapon":FAMILIES[family],"name":TITLES[style]+" "+NAMES[family],"kind":KINDS[style],"damage":[0.0,.10,.20],"unique":[0.0,.25,.40],"condition":STYLES[style],"condition_label":CONDITIONS[style],"ticket":911+result.size()}
	return result

static func active(style: String, context: Dictionary) -> bool:
	if style.is_empty(): return true
	var hp := int(context.get("health",0))
	var maximum := int(context.get("maximum",0))
	if hp <= 0 or maximum <= 0: return false
	match style:
		"calm": return hp*5 >= maximum*4
		"crisis": return hp*10 <= maximum*3
		"barrier": return int(context.get("barrier",0)) > 0
		"ground": return context.get("grounded",null) == true
		"air": return context.get("grounded",null) == false
	return false
