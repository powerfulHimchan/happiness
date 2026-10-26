class_name RunPreparationView
extends RefCounted

## Approved hero detail / open-book compositions with shared input geometry.
const BOOK := preload("res://assets/preparation/storybook.svg")
const INK := Color("493420")
const TEAL := Color("17666b")
const GOLD := Color("edbc56")
const PAPER := Color("fff4d9")
static var portraits: Dictionary = {}

static func box(safe: Rect2, x: float,y: float,w: float,h: float) -> Rect2:
	return Rect2(safe.position+safe.size*Vector2(x,y),safe.size*Vector2(w,h))

static func hero_layout(safe: Rect2, detail: bool = false) -> Dictionary:
	return HeroSelectionView.layout(safe, detail)

static func weapon_layout(safe: Rect2, _options: bool) -> Dictionary:
	var cards: Array[Rect2] = []
	var backup: Array[Rect2] = []
	for index in 6:
		var rect := box(safe,.302+(index%2)*.145,.305+int(index/2)*.175,.132,.16)
		cards.append(rect)
		backup.append(Rect2(rect.position+Vector2(rect.size.x*.06,rect.size.y*.74),rect.size*Vector2(.88,.23)))
	var lengths: Array[Rect2] = []
	var memories: Array[Rect2] = []
	for index in 4: lengths.append(box(safe,.09+index*.2075,.24,.1925,.075))
	for index in 3: memories.append(box(safe,.09+index*.277,.46,.26,.14))
	return {"cards":cards,"backup":backup,"lengths":lengths,"memories":memories,"expedition":box(safe,.09,.34,.815,.075),"legacy":box(safe,.09,.65,.815,.075),"character":box(safe,.025,.115,.18,.075),"settings":box(safe,.815,.125,.16,.065),"close":box(safe,.36,.835,.28,.075),"back":box(safe,.025,.895,.19,.075),"confirm":box(safe,.76,.895,.215,.075),"book":box(safe,.245,.215,.74,.675),"preview":box(safe,.02,.255,.25,.58)}

static func background(ui: Control) -> void:
	var texture := StartScreenView.BACKGROUND
	var factor := maxf(ui.size.x/texture.get_width(),ui.size.y/texture.get_height())
	var source_size := ui.size/factor
	ui.draw_texture_rect_region(texture,Rect2(Vector2.ZERO,ui.size),Rect2((texture.get_size()-source_size)*.5,source_size))
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(1,.95,.80,.07))

static func panel(ui: Control, rect: Rect2, fill: Color, border: Color = GOLD, radius: int = 16) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	ui.draw_style_box(style,rect)

static func button(ui: Control, rect: Rect2, label: String, primary: bool = false, selected: bool = false) -> void:
	panel(ui,rect,GOLD.lightened(.20) if primary else TEAL if selected else PAPER,GOLD if primary or selected else Color("b99a63"),int(rect.size.y*.36))
	ui._draw_village_text(label,rect.grow(-8),int(31*minf(ui.size.y/1080.0,ui.size.x/1800.0)),PAPER if selected else INK)

static func portrait(id: String) -> Texture2D:
	if not portraits.has(id):
		var original := PrototypeCharacters.texture(id) as AtlasTexture
		var crop := AtlasTexture.new()
		crop.atlas = original.atlas
		crop.region = Rect2(original.region.position,Vector2(original.region.size.x,original.region.size.y*.69))
		crop.filter_clip = true
		portraits[id] = crop
	return portraits[id]

static func draw_hero(ui: Control) -> void:
	HeroSelectionView.draw(ui)

static func draw_weapon(ui: Control) -> void:
	var safe: Rect2 = ui._safe_area_in_viewport()
	var unit := safe.size.y/1080.0
	var view := weapon_layout(safe,ui.start_options_open)
	background(ui)
	WeaponPreparationView.draw(ui,view,BOOK)
	if ui.start_options_open: draw_options(ui,safe,unit,view)
	elif not ui.preparation_skill_id.is_empty(): WeaponPreparationView.draw_skill_popup(ui)

static func draw_options(ui: Control, safe: Rect2, unit: float, view: Dictionary) -> void:
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(0.04,.12,.14,.78))
	panel(ui,box(safe,.055,.10,.89,.83),PAPER,GOLD,int(24*unit))
	ui._draw_village_text("도전 설정",box(safe,.15,.135,.70,.075),int(47*unit),INK)
	for index in 4:
		var selected: bool = ui.selected_run_mode == JourneyRoutePlan.MODE if index == 3 else ui.selected_run_mode == "regions" if index == 2 else ui.selected_run_mode == "standard" and ui.selected_stage_limit == (3 if index == 0 else 5)
		button(ui,ui.start_length_rects[index],["3스테이지","5스테이지","지역 순회","전체 여정"][index],false,selected)
	button(ui,ui.expedition_rect,ui.expedition_label(),false,ui.selected_expedition>0)
	ui._draw_village_text("영구 기억 · 하나만 장착",box(safe,.09,.417,.815,.035),int(22*unit),INK)
	for index in ui.memory_card_rects.size():
		var id: String = PrototypeMemoryAbilities.IDS[index]
		var profile := PrototypeMemoryAbilities.profile(id)
		var available := PrototypeMemoryAbilities.available(id,ui.unlocked_memories)
		var rect: Rect2 = ui.memory_card_rects[index]
		panel(ui,rect,Color("ffebbf") if available and ui.selected_memory_id == id else Color("f4e4c5"),GOLD if available and ui.selected_memory_id == id else Color("c4b28d"),int(12*unit))
		ui._draw_village_text(String(profile.name)+( " · 잠김" if not available else ""),Rect2(rect.position+rect.size*Vector2(.04,.12),rect.size*Vector2(.92,.31)),int(27*unit),INK)
		ui._draw_village_text(String(profile.effect if available else profile.condition),Rect2(rect.position+rect.size*Vector2(.04,.54),rect.size*Vector2(.92,.33)),int(21*unit),INK if available else Color("8a795d"))
	if not ui.pending_boss_legacy.is_empty():
		panel(ui,ui.boss_legacy_toggle_rect,Color("f3e0b9"))
		ui._draw_village_text("다음 도전 보상 · "+("켜짐" if ui.use_boss_legacy else "꺼짐"),Rect2(ui.boss_legacy_toggle_rect.position,Vector2(ui.boss_legacy_toggle_rect.size.x,ui.boss_legacy_toggle_rect.size.y*.46)),int(23*unit),INK)
		ui._draw_village_text(ui.start_legacy_description(),Rect2(ui.boss_legacy_toggle_rect.position+Vector2(0,ui.boss_legacy_toggle_rect.size.y*.46),ui.boss_legacy_toggle_rect.size*Vector2(1,.54)),int(21*unit),INK)
	else: ui._draw_village_text("영구 기억은 도전마다 하나만 장착합니다",ui.boss_legacy_toggle_rect,int(23*unit),INK)
	ui._draw_village_text("조제 · "+PrototypePotionRecipes.summary(ui.preferred_potion_recipe)+(" · 수호기사 지원30" if ui.guardian_companion_unlocked else "")+(" · 세라 지원40" if ui.sera_companion_unlocked else ""),box(safe,.09,.755,.815,.04),int(23*unit),INK)
	button(ui,view.close,"선택 완료",true)
