#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
game_root="$project_root/game"

required_files=(
  "$game_root/project.godot"
  "$game_root/export_presets.cfg"
  "$game_root/scenes/movement/ground_movement_sandbox.tscn"
  "$game_root/scripts/movement/ground_movement_sandbox.gd"
  "$game_root/scripts/movement/ground_movement_controls.gd"
  "$game_root/scripts/player/prototype_player.gd"
  "$game_root/scripts/combat/damage_event.gd"
  "$game_root/scripts/combat/damage_receiver.gd"
  "$game_root/scripts/combat/weapon_definition.gd"
  "$game_root/scripts/combat/skill_definition.gd"
  "$game_root/scripts/combat/sword_combat_controller.gd"
  "$game_root/scripts/combat/bow_combat_controller.gd"
  "$game_root/scripts/combat/bow_projectile.gd"
  "$game_root/scripts/combat/prototype_weapon_controller.gd"
  "$game_root/scripts/combat/auto_target_selector.gd"
  "$game_root/scripts/combat/prototype_target.gd"
  "$game_root/data/weapons/sword_basic.tres"
  "$game_root/data/skills/sword_dash.tres"
  "$game_root/data/skills/sword_spin.tres"
  "$game_root/data/weapons/bow_basic.tres"
  "$game_root/data/skills/bow_piercing.tres"
  "$game_root/data/skills/bow_arrow_rain.tres"
  "$game_root/scenes/combat/bow_projectile.tscn"
  "$game_root/assets/prototype_player.svg"
  "$game_root/assets/prototype_target.svg"
  "$game_root/assets/prototype_target_selection.svg"
  "$game_root/assets/sword_slash.svg"
  "$game_root/assets/bow_arrow.svg"
  "$game_root/assets/bow_rain.svg"
  "$game_root/scripts/input/player_command.gd"
  "$game_root/scripts/input/player_command_buffer.gd"
  "$game_root/assets/icon.svg"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    echo "Missing required file: $required_file" >&2
    exit 1
  fi
done

if ! rg -q 'run/main_scene="res://scenes/movement/ground_movement_sandbox.tscn"' "$game_root/project.godot"; then
  echo "Main scene is not configured correctly." >&2
  exit 1
fi

if ! rg -q 'res://scripts/movement/ground_movement_sandbox.gd' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "Ground movement scene does not reference its controller." >&2
  exit 1
fi

if ! rg -q 'class_name PrototypePlayer' "$game_root/scripts/player/prototype_player.gd"; then
  echo "PrototypePlayer type is missing." >&2
  exit 1
fi

if ! rg -q 'avatar_sprite\.flip_h = facing_direction < 0' "$game_root/scripts/player/prototype_player.gd"; then
  echo "Player sprite facing flip is missing." >&2
  exit 1
fi

if ! rg -q 'return int\(signf\(value\)\)' "$game_root/scripts/player/prototype_player.gd"; then
  echo "Float-safe direction sign conversion is missing." >&2
  exit 1
fi

if rg -q 'signi\(' "$game_root/scripts/player/prototype_player.gd"; then
  echo "Integer sign conversion must not be used for float movement values." >&2
  exit 1
fi

if ! rg -q 'const COYOTE_TIME_S := 0\.10' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-103 coyote time is missing." >&2
  exit 1
fi

if ! rg -q 'const JUMP_BUFFER_S := 0\.12' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-103 jump buffer is missing." >&2
  exit 1
fi

if ! rg -q 'jump_pressed\.connect\(player\.request_jump\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "Jump input is not connected to the player." >&2
  exit 1
fi

if ! rg -q 'PracticePlatform' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-103 practice platform is missing." >&2
  exit 1
fi

if ! rg -q 'const GROUND_EVADE_INVINCIBLE_S := 0\.18' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-104 ground evade invincibility is missing." >&2
  exit 1
fi

if ! rg -q 'air_dash_available = false' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-104 air dash single-use gate is missing." >&2
  exit 1
fi

if ! rg -q 'evade_pressed\.connect\(player\.request_evade\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "Evade input is not connected to the player." >&2
  exit 1
fi

if ! rg -q 'const FALL_DAMAGE_RATIO := 0\.10' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-105 fall damage ratio is missing." >&2
  exit 1
fi

if ! rg -q 'fall_recovery_started\.connect\(controls\.release_all_inputs\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "Fall recovery input reset is not connected." >&2
  exit 1
fi

if ! rg -q 'LeftSafeZone' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'RightSafeZone' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-105 safe zones are missing." >&2
  exit 1
fi

if rg -q 'size = Vector2\(5000, 120\)' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "Continuous floor still blocks the CP-105 fall zone." >&2
  exit 1
fi

if ! rg -q 'class_name AutoTargetSelector' "$game_root/scripts/combat/auto_target_selector.gd"; then
  echo "CP-201 auto target selector is missing." >&2
  exit 1
fi

if ! rg -q 'const RETARGET_INTERVAL_S := 0\.10' "$game_root/scripts/combat/auto_target_selector.gd" \
  || ! rg -q 'const SWITCH_DISTANCE_RATIO := 0\.80' "$game_root/scripts/combat/auto_target_selector.gd" \
  || ! rg -q 'const DEFAULT_ATTACK_RANGE_M := 1\.6' "$game_root/scripts/combat/auto_target_selector.gd"; then
  echo "CP-201 targeting constants do not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'offset\.x \* float\(player\.facing_direction\) <= 0\.0' "$game_root/scripts/combat/auto_target_selector.gd"; then
  echo "CP-201 forward-facing target filter is missing." >&2
  exit 1
fi

if ! rg -q 'target_selector\.target_metrics_changed\.connect\(controls\.update_target_metrics\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "CP-201 target metrics are not connected to the HUD." >&2
  exit 1
fi

if ! rg -q 'CrossingTargetA' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'RearTarget' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-201 crossing and rear target fixtures are missing." >&2
  exit 1
fi

if ! rg -q 'BodySprite' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'SelectionSprite' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-201 explicit target sprites are missing." >&2
  exit 1
fi

if ! rg -q 'class_name DamageEvent' "$game_root/scripts/combat/damage_event.gd" \
  || ! rg -q 'attacker_id: StringName' "$game_root/scripts/combat/damage_event.gd" \
  || ! rg -q 'stagger_s: float' "$game_root/scripts/combat/damage_event.gd" \
  || ! rg -q 'tags: PackedStringArray' "$game_root/scripts/combat/damage_event.gd"; then
  echo "CP-202 common damage event fields are missing." >&2
  exit 1
fi

if ! rg -q 'class_name DamageReceiver' "$game_root/scripts/combat/damage_receiver.gd" \
  || ! rg -q 'post_hit_invulnerability_s: float = 0\.50' "$game_root/scripts/combat/damage_receiver.gd" \
  || ! rg -q '_processed_event_ids\.has\(event\.event_id\)' "$game_root/scripts/combat/damage_receiver.gd"; then
  echo "CP-202 damage receiver or duplicate prevention is missing." >&2
  exit 1
fi

if ! rg -q 'name="DamageReceiver"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'player\.receive_damage\(event\)' "$game_root/scripts/movement/ground_movement_sandbox.gd" \
  || ! rg -q 'damage_test_pressed' "$game_root/scripts/movement/ground_movement_controls.gd"; then
  echo "CP-202 scene integration and mobile damage tests are missing." >&2
  exit 1
fi

if ! rg -q 'class_name WeaponDefinition' "$game_root/scripts/combat/weapon_definition.gd" \
  || ! rg -q 'class_name SkillDefinition' "$game_root/scripts/combat/skill_definition.gd" \
  || ! rg -q 'class_name SwordCombatController' "$game_root/scripts/combat/sword_combat_controller.gd"; then
  echo "CP-203 sword combat data or controller types are missing." >&2
  exit 1
fi

if ! rg -q 'damage = PackedInt32Array\(12, 14, 20\)' "$game_root/data/weapons/sword_basic.tres" \
  || ! rg -q 'attack_interval_s = PackedFloat32Array\(0\.28, 0\.3, 0\.42\)' "$game_root/data/weapons/sword_basic.tres"; then
  echo "CP-203 sword combo data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'cooldown_s = 6\.0' "$game_root/data/skills/sword_dash.tres" \
  || ! rg -q 'movement_distance_m = 3\.5' "$game_root/data/skills/sword_dash.tres" \
  || ! rg -q 'damage = PackedInt32Array\(20, 20\)' "$game_root/data/skills/sword_spin.tres" \
  || ! rg -q 'cooldown_s = 9\.0' "$game_root/data/skills/sword_spin.tres"; then
  echo "CP-203 sword skill data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'name="SwordCombatController"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'skill_1_pressed\.connect\(weapon_controller\.request_skill_1\)' "$game_root/scripts/movement/ground_movement_sandbox.gd" \
  || ! rg -q 'player\.evade_started\.connect' "$game_root/scripts/combat/sword_combat_controller.gd"; then
  echo "CP-203 sword scene, input, or evade cancel integration is missing." >&2
  exit 1
fi

if ! rg -q 'class_name BowCombatController' "$game_root/scripts/combat/bow_combat_controller.gd" \
  || ! rg -q 'class_name BowProjectile' "$game_root/scripts/combat/bow_projectile.gd" \
  || ! rg -q 'class_name PrototypeWeaponController' "$game_root/scripts/combat/prototype_weapon_controller.gd"; then
  echo "CP-204 bow combat, projectile, or weapon test controller is missing." >&2
  exit 1
fi

if ! rg -q 'attack_range_m = 8\.0' "$game_root/data/weapons/bow_basic.tres" \
  || ! rg -q 'projectile_speed_mps = 14\.0' "$game_root/data/weapons/bow_basic.tres" \
  || ! rg -q 'damage = PackedInt32Array\(14\)' "$game_root/data/weapons/bow_basic.tres"; then
  echo "CP-204 bow basic attack data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'damage = PackedInt32Array\(36\)' "$game_root/data/skills/bow_piercing.tres" \
  || ! rg -q 'max_targets = 3' "$game_root/data/skills/bow_piercing.tres" \
  || ! rg -q 'cooldown_s = 7\.0' "$game_root/data/skills/bow_piercing.tres" \
  || ! rg -q 'damage = PackedInt32Array\(8, 8, 8, 8, 8, 8\)' "$game_root/data/skills/bow_arrow_rain.tres" \
  || ! rg -q 'cooldown_s = 11\.0' "$game_root/data/skills/bow_arrow_rain.tres"; then
  echo "CP-204 bow skill data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'screen_only and not is_target_on_screen' "$game_root/scripts/combat/auto_target_selector.gd" \
  || ! rg -q 'CLOSE_DAMAGE_MULTIPLIER := 0\.80' "$game_root/scripts/combat/bow_combat_controller.gd" \
  || ! rg -q 'weapon_swap_pressed\.connect\(weapon_controller\.toggle_test_weapon\)' "$game_root/scripts/movement/ground_movement_sandbox.gd" \
  || ! rg -q 'OffscreenTarget' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-204 screen filtering, close penalty, or mobile test integration is missing." >&2
  exit 1
fi

if ! rg -q 'class_name PlayerCommand' "$game_root/scripts/input/player_command.gd"; then
  echo "PlayerCommand type is missing." >&2
  exit 1
fi

if ! rg -q 'class_name PlayerCommandBuffer' "$game_root/scripts/input/player_command_buffer.gd"; then
  echo "PlayerCommandBuffer type is missing." >&2
  exit 1
fi

if ! rg -q 'name="Android Debug APK"' "$game_root/export_presets.cfg"; then
  echo "Android debug export preset is missing." >&2
  exit 1
fi

godot_command=""
if command -v godot >/dev/null 2>&1; then
  godot_command="godot"
elif command -v godot4 >/dev/null 2>&1; then
  godot_command="godot4"
fi

if [[ -n "$godot_command" ]]; then
  "$godot_command" --headless --path "$game_root" --editor --quit-after 1
  echo "Godot headless project check: OK"
else
  echo "Static project check: OK"
  echo "Godot executable not found; GDScript parse and runtime checks were skipped."
fi
