class_name WeaponPreparationView
extends RefCounted

const INK := Color("493420")
const TEAL := Color("17666b")
const GOLD := Color("b47a28")
const PAPER := Color("fff8e6")

static func box(safe: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(safe.position + safe.size * Vector2(x, y), safe.size * Vector2(w, h))

static func skill_regions(safe: Rect2) -> Array[Rect2]:
	return [box(safe, .642, .530, .142, .160), box(safe, .806, .530, .142, .160)]

static func popup_layout(safe: Rect2) -> Dictionary:
	return {"panel":box(safe,.30,.14,.43,.75),"close":box(safe,.445,.80,.14,.065),"x":box(safe,.68,.16,.035,.055)}

static func draw(ui: Control, view: Dictionary, book: Texture2D) -> void:
	var safe: Rect2 = ui._safe_area_in_viewport()
	var unit := safe.size.y / 1080.0
	WeaponPreparationArt.word(ui, "heading", box(safe,.30,.03,.43,.105), INK)
	WeaponPreparationArt.text(ui,"주무기와 보조무기를 선택하세요",box(safe,.32,.145,.40,.05),int(27*unit),INK)
	var hero_area: Rect2 = ui.character_open_rect
	var name_texture: Texture2D = HeroSelectionView.ART[ui.selected_character_id]
	ui.draw_texture_rect(name_texture, SupplyShopArt.fitted(name_texture, Rect2(hero_area.position,hero_area.size*Vector2(.42,1))),false,INK)
	WeaponPreparationArt.word(ui,"hero",Rect2(hero_area.position+Vector2(hero_area.size.x*.42,0),hero_area.size*Vector2(.58,1)),INK)
	WeaponPreparationArt.word(ui,"settings",view.settings.grow(-8*unit),INK)
	ui.draw_texture_rect(book,view.book,false)
	ui.equipped_preview.draw(ui,ui.selected_character_id,ui.preview_weapon_id,ui.preview_elapsed_s,view.preview)
	WeaponPreparationArt.text(ui,"장착 미리보기 · "+PrototypeWeaponRewards.family_name(ui.preview_weapon_id),box(safe,.015,.835,.255,.045),int(22*unit),INK)
	for index in PrototypeWeaponRewards.FAMILY_IDS.size():
		var family: String = PrototypeWeaponRewards.FAMILY_IDS[index]
		var rect: Rect2 = view.cards[index]
		var primary: bool = ui.selected_starting_weapon == family
		var backup: bool = ui.selected_backup_weapon == family
		WeaponPreparationArt.weapon(ui,family,Rect2(rect.position+rect.size*Vector2(.08,.015),rect.size*Vector2(.84,.55)))
		WeaponPreparationArt.word(ui,family,Rect2(rect.position+rect.size*Vector2(.12,.565),rect.size*Vector2(.76,.19)),TEAL if backup else INK)
		if primary:
			var center := rect.position + rect.size * Vector2(.13,.12)
			ui.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-7*unit),center+Vector2(7*unit,0),center+Vector2(0,7*unit),center-Vector2(7*unit,0)]),GOLD)
			WeaponPreparationArt.word(ui,"primary",Rect2(rect.position+rect.size*Vector2(.22,.035),rect.size*Vector2(.32,.14)),GOLD)
		WeaponPreparationArt.word(ui,"backup-selected" if backup else "backup",ui.start_backup_rects[index].grow(-3*unit),TEAL if backup else INK)
		if backup:
			var mark: Vector2 = ui.start_backup_rects[index].position+ui.start_backup_rects[index].size*Vector2(.76,.44)
			ui.draw_polyline(PackedVector2Array([mark+Vector2(-6,0)*unit,mark+Vector2(-1,5)*unit,mark+Vector2(8,-7)*unit]),TEAL,2*unit,true)
	var family: String = ui.preview_weapon_id
	WeaponPreparationArt.text(ui,"선택한 무기 · "+("주무기" if family==ui.selected_starting_weapon else "보조무기"),box(safe,.645,.273,.30,.042),int(26*unit),TEAL)
	WeaponPreparationArt.weapon(ui,family,box(safe,.675,.315,.24,.155))
	WeaponPreparationArt.word(ui,family,box(safe,.70,.478,.19,.042),INK)
	var skills := WeaponSkillPreview.ids(family)
	var regions := skill_regions(safe)
	for index in skills.size():
		var id: String = skills[index]
		var area: Rect2 = regions[index]
		var image_area := Rect2(area.position+area.size*Vector2(.13,0),area.size*Vector2(.74,.60))
		ui.draw_texture_rect(WeaponPreparationArt.SKILLS[id],SupplyShopArt.fitted(WeaponPreparationArt.SKILLS[id],image_area),false)
		WeaponPreparationArt.word(ui,id,Rect2(area.position+area.size*Vector2(.04,.62),area.size*Vector2(.92,.22)),INK)
		WeaponPreparationArt.text(ui,WeaponSkillPreview.TRAITS[id],Rect2(area.position+area.size*Vector2(.01,.85),area.size*Vector2(.98,.15)),int(20*unit),TEAL)
	WeaponPreparationArt.text(ui,"스킬을 누르면 설명을 확인합니다",box(safe,.645,.703,.30,.025),int(18*unit),Color("8c795b"))
	ui.draw_line(box(safe,.645,.738,.30,.001).position,box(safe,.645,.738,.30,.001).end,Color("c8a56c"),unit)
	WeaponPreparationArt.text(ui,"주무기  "+PrototypeWeaponRewards.family_name(ui.selected_starting_weapon),box(safe,.645,.746,.30,.030),int(24*unit),INK)
	WeaponPreparationArt.text(ui,"보조무기  "+PrototypeWeaponRewards.family_name(ui.selected_backup_weapon),box(safe,.645,.787,.30,.030),int(24*unit),TEAL)
	WeaponPreparationArt.word(ui,"back" if ui.preparation_flow else "return",ui.start_weapon_cancel_rect.grow(-5*unit),PAPER,true)
	WeaponPreparationArt.word(ui,"start",ui.start_weapon_confirm_rect.grow(-5*unit),Color("ffe1a0"),true)

static func draw_skill_popup(ui: Control) -> void:
	var safe: Rect2 = ui._safe_area_in_viewport()
	var unit := safe.size.y / 1080.0
	var profile := WeaponSkillPreview.profile(ui.preparation_skill_id)
	if profile.is_empty(): return
	var layout := popup_layout(safe)
	var panel: Rect2 = layout.panel
	ui.draw_rect(Rect2(Vector2.ZERO,ui.size),Color(.025,.10,.14,.77))
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("c5a05b")
	style.set_border_width_all(maxi(1,int(2*unit)))
	style.set_corner_radius_all(int(16*unit))
	ui.draw_style_box(style,panel)
	var inner := Rect2(panel.position+panel.size*Vector2(.08,.07),panel.size*Vector2(.84,.85))
	var icon := Rect2(inner.position,Vector2.ONE*panel.size.y*.18)
	ui.draw_texture_rect(WeaponPreparationArt.SKILLS[profile.id],SupplyShopArt.fitted(WeaponPreparationArt.SKILLS[profile.id],icon),false)
	WeaponPreparationArt.word(ui,profile.id,Rect2(inner.position+Vector2(icon.size.x+20*unit,0),Vector2(inner.size.x-icon.size.x-20*unit,icon.size.y*.55)),INK)
	WeaponPreparationArt.text(ui,PrototypeWeaponRewards.family_name(profile.family)+" · 시작 스킬",Rect2(inner.position+Vector2(icon.size.x+20*unit,icon.size.y*.55),Vector2(inner.size.x-icon.size.x-20*unit,icon.size.y*.25)),int(24*unit),INK,false)
	WeaponPreparationArt.text(ui,profile.traits,Rect2(inner.position+Vector2(0,panel.size.y*.21),Vector2(inner.size.x,panel.size.y*.04)),int(25*unit),TEAL,false)
	var y := panel.position.y+panel.size.y*.36
	var font := ThemeDB.fallback_font
	var font_size := int(26*unit)
	for line in PrototypeStoryView.wrap(profile.description,font,font_size,inner.size.x):
		ui._draw_text(line,Vector2(inner.position.x,y),font_size,INK)
		y += font.get_height(font_size)+3*unit
	WeaponPreparationArt.text(ui,profile.effect,Rect2(Vector2(inner.position.x,panel.position.y+panel.size.y*.455),Vector2(inner.size.x,panel.size.y*.05)),int(21*unit),TEAL,false)
	for index in 4:
		var cell := Rect2(inner.position+Vector2((index%2)*inner.size.x*.52,panel.size.y*.49+int(index/2)*panel.size.y*.135),Vector2(inner.size.x*.47,panel.size.y*.12))
		WeaponPreparationArt.text(ui,String(profile.stats[index][0]),Rect2(cell.position,cell.size*Vector2(1,.38)),int(21*unit),Color("8a7150"),false)
		WeaponPreparationArt.text(ui,String(profile.stats[index][1]),Rect2(cell.position+Vector2(0,cell.size.y*.38),cell.size*Vector2(1,.62)),int(36*unit),TEAL,false)
	WeaponPreparationArt.text(ui,"최종 피해는 성장과 장비에 따라 달라집니다.",Rect2(Vector2(inner.position.x,panel.position.y+panel.size.y*.835),Vector2(inner.size.x,panel.size.y*.04)),int(19*unit),Color("8c795b"))
	WeaponPreparationArt.word(ui,"close",layout.close.grow(-7*unit),TEAL)
	ui.draw_line(layout.x.position+layout.x.size*.25,layout.x.end-layout.x.size*.25,GOLD,2*unit,true)
	ui.draw_line(layout.x.position+layout.x.size*Vector2(.75,.25),layout.x.position+layout.x.size*Vector2(.25,.75),GOLD,2*unit,true)
