class_name SkillDefinition
extends Resource

## 액티브 스킬의 실행 시간, 타격 시점과 취소 규칙을 담는다.

@export var skill_id: StringName = &""
@export var display_name: String = ""
@export var cooldown_s: float = 0.0
@export var duration_s: float = 0.0
@export var hit_times_s: PackedFloat32Array = PackedFloat32Array()
@export var damage: PackedInt32Array = PackedInt32Array()
@export var hit_range_m: float = 0.0
@export var movement_distance_m: float = 0.0
@export var max_targets: int = 0
@export var can_move: bool = false
@export var can_turn: bool = false
@export var evade_cancel_start_s: float = 0.0
@export var ultimate_gain: int = 0
