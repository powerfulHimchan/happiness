#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
game_root="$project_root/game"

required_files=(
  "$game_root/project.godot"
  "$game_root/export_presets.cfg"
  "$game_root/scenes/input/input_command_sandbox.tscn"
  "$game_root/scripts/input/input_command_sandbox.gd"
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

if ! rg -q 'run/main_scene="res://scenes/input/input_command_sandbox.tscn"' "$game_root/project.godot"; then
  echo "Main scene is not configured correctly." >&2
  exit 1
fi

if ! rg -q 'res://scripts/input/input_command_sandbox.gd' "$game_root/scenes/input/input_command_sandbox.tscn"; then
  echo "Input sandbox scene does not reference its script." >&2
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
