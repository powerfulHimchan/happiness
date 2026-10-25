class_name EquippedHeroPreview
extends RefCounted

## A separate presentation clock; no Player/weapon controller, combat signal or save access.
var movement := HeroMovementAnimation.new()

func snapshot(character: String, family: String, time_s: float, area: Rect2) -> Dictionary:
	var phase := fposmod(maxf(0,time_s),TAU)
	var frame := int(maxf(0,time_s)*2.5)%2
	var scale_factor := minf(area.size.y*.96/255.0,area.size.x*.98/190.0)
	var foot := Vector2(area.get_center().x,area.end.y-area.size.y*.045)
	var breath := sin(phase*2.0)*.012
	var stretch := Vector2(1.0-breath*.4,1.0+breath)
	var body := Rect2(foot-Vector2(192,272)*scale_factor*stretch,Vector2(384,288)*scale_factor*stretch)
	var hand := foot+Vector2(([41,40] if character == "roan" else [60,53])[frame],-65)*scale_factor*stretch
	var left_hand := foot+Vector2(-44,-65)*scale_factor*stretch
	var sway: float = {"sword":.028,"bow":.018,"fist":.04,"staff":.035,"polearm":.016,"shield":.012}.get(family,.02)
	var angle := sin(phase*2.0)*sway
	var size_factor := scale_factor
	var local := Rect2()
	var texture: Texture2D = SupplyShopArt.ICONS.get(family,WeaponFamilyPresentation.TEXTURES.get(family))
	match family:
		"sword": local = Rect2(-18,-108,128,128); angle -= .60
		"bow": local = Rect2(-65,-69,105,138); angle += .08
		"fist": local = Rect2(-18,-21,37,37)
		"staff": local = Rect2(-17,-108,35,160); angle += .09
		"polearm": local = Rect2(-125,-20,256,40); angle -= 1.17
		"shield": local = Rect2(-37,-52,74,94); angle -= .06
	return {"character":character,"family":family,"frame":frame,"texture":movement.frame_texture(character,frame),"body":body,"hand":hand,"left_hand":left_hand,"weapon_texture":texture,"weapon_rect":local,"rotation":angle,"scale":size_factor,"foot":foot}

func draw(ui: Control, character: String, family: String, time_s: float, area: Rect2) -> void:
	var state := snapshot(character,family,time_s,area)
	var foot: Vector2 = state.foot
	ui.draw_set_transform(foot+Vector2(0,8),0,Vector2(1,.20))
	ui.draw_circle(Vector2.ZERO,area.size.x*.30,Color(0.08,.20,.17,.23))
	ui.draw_set_transform(Vector2.ZERO)
	ui.draw_texture_rect(state.texture,state.body,false)
	ui.draw_set_transform(state.hand,state.rotation,Vector2.ONE*float(state.scale))
	ui.draw_texture_rect(state.weapon_texture,state.weapon_rect,false)
	ui.draw_set_transform(Vector2.ZERO)
	if family == "fist":
		ui.draw_set_transform(state.left_hand,-state.rotation,Vector2.ONE*float(state.scale))
		ui.draw_texture_rect(state.weapon_texture,Rect2(-18,-20,34,34),false)
		ui.draw_set_transform(Vector2.ZERO)
