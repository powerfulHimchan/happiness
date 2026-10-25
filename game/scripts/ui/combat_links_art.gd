class_name CombatLinksArt
extends RefCounted

const BACKGROUND := preload("res://assets/links/archive.svg")
const ICONS := {
	"switch":preload("res://assets/links/switch.svg"),
	"evade":preload("res://assets/links/evade.svg"),
	"critical":preload("res://assets/links/critical.svg"),
	"hurt":preload("res://assets/links/hurt.svg"),
	"potion":preload("res://assets/links/potion.svg"),
	"skill":preload("res://assets/links/skill.svg"),
}
const FRAMES := {
	"active":preload("res://assets/links/frame_active.svg"),
	"dormant":preload("res://assets/links/frame_dormant.svg"),
	"locked":preload("res://assets/links/frame_locked.svg"),
}
const COLORS := {"switch":Color("88dfea"),"evade":Color("9de6bf"),"critical":Color("f8d382"),"hurt":Color("a2bded"),"potion":Color("b3e07e"),"skill":Color("d1b2ef")}

static func icon(canvas: CanvasItem, style: String, area: Rect2, alpha: float = 1.0) -> void:
	if ICONS.has(style): canvas.draw_texture_rect(ICONS[style],SupplyShopArt.fitted(ICONS[style],area),false,Color(1,1,1,alpha))

static func card_regions(rect: Rect2) -> Dictionary:
	return {"icon":Rect2(rect.position+rect.size*Vector2(.055,.14),rect.size*Vector2(.18,.27)),"title":Rect2(rect.position+rect.size*Vector2(.26,.14),rect.size*Vector2(.68,.13)),"status":Rect2(rect.position+rect.size*Vector2(.26,.31),rect.size*Vector2(.68,.10)),"first":Rect2(rect.position+rect.size*Vector2(.055,.51),rect.size*Vector2(.89,.15)),"second":Rect2(rect.position+rect.size*Vector2(.055,.73),rect.size*Vector2(.89,.15)),"bar":Rect2(rect.position+rect.size*Vector2(.055,.93),rect.size*Vector2(.89,.02))}

static func frame_key(card: Dictionary) -> String:
	return "locked" if not card.learned else "active" if card.live else "dormant"

static func frame(canvas: CanvasItem, card: Dictionary, rect: Rect2, alpha: float = 1.0) -> void:
	canvas.draw_texture_rect(FRAMES[frame_key(card)],rect,false,Color(1,1,1,alpha))
