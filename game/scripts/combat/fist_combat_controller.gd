class_name FistCombatController
extends SwordCombatController

## 공유 근접 판정·취소 규칙을 사용하는 짧은 사거리 4연타와 권법.
func _update_basic_attack(delta: float) -> void:
	var target := target_selector.current_target
	if not is_instance_valid(target) or target.global_position.distance_to(player.global_position) > weapon.attack_range_m * PrototypePlayer.PIXELS_PER_METER or (target.global_position.x - player.global_position.x) * player.facing_direction < 0:
		_update_combo_timeout(delta)
		return
	super._update_basic_attack(delta)

func _execute_skill_hit(definition: SkillDefinition, hit_index: int) -> void:
	if _action == Action.DASH_SLASH and is_instance_valid(_captured_target) and _captured_target.global_position.distance_to(player.global_position) > definition.hit_range_m * PrototypePlayer.PIXELS_PER_METER:
		return
	super._execute_skill_hit(definition, hit_index)

func _draw() -> void:
	if not active or player.damage_receiver.dead: return
	var direction := _line_visual_direction if _action == Action.LINE_SLASH else player.facing_direction
	WeaponFamilyPresentation.draw_equipment(self, "fist", direction, _slash_remaining_s > 0, _action_elapsed_s)
	var definition := _current_skill()
	var rising := definition != null and (definition.skill_id == &"fist_rising" or definition.hit_below_m >= 0.0)
	var circular := definition != null and definition.execution_style == &"spin"
	WeaponFamilyPresentation.draw_impact(self, "fist", direction, definition.hit_range_m * PrototypePlayer.PIXELS_PER_METER if circular else 94.0, circular, _slash_remaining_s, rising)

func _update_slash_visual() -> void:
	slash_sprite.visible = false

func _animation_clip(_definition: SkillDefinition) -> String:
	return "sword_thrust"

func _show_slash(duration_s: float, _variant: int) -> void:
	_slash_remaining_s = duration_s
	queue_redraw()
