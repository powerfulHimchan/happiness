class_name HeroCombatAnimation
extends RefCounted

## Presentation only. Hits/projectiles drive the strike pose; animation never deals damage.
const SHEETS := {
	"roan": preload("res://assets/characters/roan_combat.png"),
	"lumi": preload("res://assets/characters/lumi_combat.png"),
}
const CLIPS := {"sword_slash": 0, "sword_thrust": 4, "bow_shot": 8, "bow_rain": 12}
const FRAME_SIZE := Vector2(512, 288)
const FOOT_Y := 268.0
const RECOVERY_S := 0.24
# Measured body height excludes the raised weapon. One scale for all poses per hero.
const BODY_HEIGHT := {"roan": 183.0, "lumi": 190.0}
const REGIONS := {
	"roan": [
		Rect2(89,54,177,193), Rect2(443,70,305,177), Rect2(835,91,288,156), Rect2(1234,65,240,183),
		Rect2(70,310,248,176), Rect2(445,310,314,177), Rect2(842,311,293,176), Rect2(1235,300,233,187),
		Rect2(82,542,232,188), Rect2(446,536,251,195), Rect2(832,538,232,195), Rect2(1226,545,225,187),
		Rect2(67,776,231,195), Rect2(448,772,212,199), Rect2(827,769,226,202), Rect2(1235,788,234,183),
	],
	"lumi": [
		Rect2(85,43,165,184), Rect2(454,52,283,172), Rect2(845,73,256,151), Rect2(1250,46,176,179),
		Rect2(80,311,182,165), Rect2(437,308,312,166), Rect2(848,306,311,168), Rect2(1260,296,189,182),
		Rect2(79,526,222,199), Rect2(461,527,237,199), Rect2(866,530,204,196), Rect2(1259,536,211,191),
		Rect2(90,767,192,207), Rect2(471,770,222,206), Rect2(863,761,210,214), Rect2(1261,782,212,196),
	],
}
# Waist pivots keep extended blades/capes from shifting the body when facing left.
const PIVOTS := {
	"roan": [200,562,955,1337,190,568,964,1353,187,566,951,1337,186,561,953,1346],
	"lumi": [178,552,953,1335,193,556,962,1355,176,579,980,1372,182,589,988,1385],
}

var clip: String = ""
var direction: int = 1
var frame_index: int = -1
var elapsed_s: float = 0.0
var _released: bool = false
var _skill: bool = false
var _frames: Dictionary = {}


func begin(next_clip: String, facing: int) -> void:
	clip = next_clip
	direction = facing
	elapsed_s = 0.0
	_released = false
	_skill = true


func strike(next_clip: String, facing: int, is_skill: bool) -> void:
	begin(next_clip, facing)
	_released = true
	_skill = is_skill


func clear(weapon: String = "") -> void:
	if not weapon.is_empty() and not clip.begins_with(weapon + "_"): return
	clip = ""
	frame_index = -1
	elapsed_s = 0.0
	_released = false
	_skill = false


func advance(delta: float, interrupted: bool) -> void:
	if interrupted:
		clear()
		return
	if clip.is_empty(): return
	elapsed_s += maxf(0.0, delta)
	if _released and not _skill and elapsed_s >= RECOVERY_S: clear()


func apply(sprite: Sprite2D, character: String) -> void:
	if clip.is_empty(): return
	var bow := clip.begins_with("bow_")
	var pose := (1 if bow and elapsed_s >= 0.07 else 0)
	if _released:
		pose = (2 if elapsed_s < 0.10 else 3) if bow else (1 if elapsed_s < 0.07 else 2 if elapsed_s < 0.15 else 3)
		# Re-nock during a continuing volley, but only release on a real shot event.
		if bow and _skill and elapsed_s >= 0.18: pose = 1
	apply_frame(sprite, character, int(CLIPS[clip]) + pose)
	sprite.flip_h = direction < 0


func apply_frame(sprite: Sprite2D, character: String, index: int) -> void:
	frame_index = index
	sprite.texture = frame_texture(character, index)
	var scale_factor := 154.0 / float(BODY_HEIGHT[character])
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0, 60.0 - (FOOT_Y - FRAME_SIZE.y * 0.5) * scale_factor)


func frame_texture(character: String, index: int) -> AtlasTexture:
	var key := "%s:%d" % [character, index]
	if not _frames.has(key):
		var bounds: Rect2 = REGIONS[character][index]
		var region := bounds.grow(2.0)
		var texture := AtlasTexture.new()
		texture.atlas = SHEETS[character]
		texture.region = region
		texture.filter_clip = true
		texture.margin = Rect2(Vector2(
			FRAME_SIZE.x * 0.5 - (float(PIVOTS[character][index]) - region.position.x),
			FOOT_Y - bounds.size.y - 2.0), FRAME_SIZE - region.size)
		_frames[key] = texture
	return _frames[key]
