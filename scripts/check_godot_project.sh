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
  "$game_root/assets/prototype_player.svg"
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
