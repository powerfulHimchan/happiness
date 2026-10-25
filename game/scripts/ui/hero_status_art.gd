class_name HeroStatusArt
extends RefCounted

## GP-821–830: original SVG artwork. Drawing only; no gameplay or saved state.
const BACKGROUND := preload("res://assets/status/dawn_archive.svg")
const STAT_IDS := ["attack","defense","critical_chance","critical_damage","health"]
const ICONS := {
	"attack":preload("res://assets/status/attack.svg"),
	"defense":preload("res://assets/status/defense.svg"),
	"critical_chance":preload("res://assets/status/critical_chance.svg"),
	"critical_damage":preload("res://assets/status/critical_damage.svg"),
	"health":preload("res://assets/status/health.svg"),
	"roan":preload("res://assets/status/roan_counter.svg"),
	"lumi":preload("res://assets/status/lumi_starlight.svg"),
}
const MAIN_FRAME := preload("res://assets/status/main_weapon_frame.svg")
const BACKUP_FRAME := preload("res://assets/status/backup_weapon_frame.svg")

static func box(safe: Rect2,x: float,y: float,w: float,h: float) -> Rect2:
	return Rect2(safe.position+safe.size*Vector2(x,y),safe.size*Vector2(w,h))

static func background(ui: Control) -> void:
	ui.draw_texture_rect(BACKGROUND,Rect2(Vector2.ZERO,ui.size),false)

static func icon(ui: Control,id: String,area: Rect2) -> void:
	if ICONS.has(id): ui.draw_texture_rect(ICONS[id],SupplyShopArt.fitted(ICONS[id],area),false)

static func stat_regions(safe: Rect2,index: int) -> Dictionary:
	var y := .25+index*.058
	return {"icon":box(safe,.279,y,.028,.045),"label":box(safe,.315,y,.115,.045),"value":box(safe,.44,y,.13,.045)}

static func passive_regions(safe: Rect2) -> Dictionary:
	return {"icon":box(safe,.278,.715,.05,.09),"name":box(safe,.337,.715,.24,.035),"status":box(safe,.337,.763,.24,.033)}

static func selection_regions(panel: Rect2) -> Dictionary:
	return {"icon":Rect2(panel.position+panel.size*Vector2(.02,.14),panel.size*Vector2(.18,.74)),"name":Rect2(panel.position+panel.size*Vector2(.22,.04),panel.size*Vector2(.75,.305)),"effect":Rect2(panel.position+panel.size*Vector2(.22,.395),panel.size*Vector2(.75,.235)),"cooldown":Rect2(panel.position+panel.size*Vector2(.22,.71),panel.size*Vector2(.75,.205))}

static func gear_frame(ui: Control,area: Rect2,is_main: bool) -> void:
	ui.draw_texture_rect(MAIN_FRAME if is_main else BACKUP_FRAME,area,false)

static func detail_icon(id: String,character: String) -> String:
	return "attack" if id == "offense" else "defense" if id == "defense" else character if id == "passive" else ""
