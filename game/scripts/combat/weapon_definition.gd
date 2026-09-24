class_name WeaponDefinition
extends Resource

## 프로토타입과 정식 전투가 함께 사용하는 무기 수치 데이터다.

@export var weapon_id: StringName = &""
@export var display_name: String = ""
@export var attack_range_m: float = 0.0
@export var attack_interval_s: PackedFloat32Array = PackedFloat32Array()
@export var damage: PackedInt32Array = PackedInt32Array()
@export var projectile_speed_mps: float = 0.0
@export var skill_ids: PackedStringArray = PackedStringArray()
