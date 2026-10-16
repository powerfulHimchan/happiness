class_name HeroMovementAnimation
extends RefCounted

## Rendering only: never changes movement, collision, damage, or action timing.
const SHEETS := {
	"roan": preload("res://assets/characters/roan_movement.png"),
	"lumi": preload("res://assets/characters/lumi_movement.png"),
}
const FRAME_SIZE := Vector2(384, 288)
const FOOT_Y := 272.0
const CLIPS := {
	"idle": {"frames": [0, 1], "fps": 2.5, "loop": true},
	"run": {"frames": [2, 3, 4, 5, 6, 7], "fps": 12.0, "loop": true},
	"jump": {"frames": [8, 9], "fps": 7.0, "loop": false},
	"fall": {"frames": [10, 11], "fps": 6.0, "loop": false},
	"land": {"frames": [12, 13], "fps": 14.0, "loop": false},
	"evade": {"frames": [14, 15, 16], "fps": 12.5, "loop": false},
	"air_dash": {"frames": [17, 18], "fps": 11.12, "loop": false},
	"hit": {"frames": [19, 20], "fps": 17.0, "loop": false},
	"death": {"frames": [21, 22, 23], "fps": 5.0, "loop": false},
}

# Each generated pose is individually bounded (the source is not a perfect grid).
# Keep these regions intact instead of slicing through boots, hair, or capes.
const REGIONS := {
	"roan": [
		Rect2(49,13,161,255), Rect2(297,13,169,255), Rect2(521,24,220,244),
		Rect2(781,25,200,244), Rect2(1029,28,241,240), Rect2(1291,25,217,243),
		Rect2(25,302,224,230), Rect2(270,291,226,227), Rect2(532,271,197,266),
		Rect2(771,276,228,222), Rect2(1034,284,226,252), Rect2(1296,314,211,221),
		Rect2(10,582,223,162), Rect2(280,564,201,181), Rect2(515,594,259,147),
		Rect2(811,607,187,139), Rect2(1025,583,193,166), Rect2(1263,572,265,129),
		Rect2(16,767,215,226), Rect2(282,771,230,227), Rect2(528,764,181,230),
		Rect2(757,819,221,175), Rect2(1004,854,261,133), Rect2(1279,890,253,97),
	],
	"lumi": [
		Rect2(44,17,182,257), Rect2(301,16,187,258), Rect2(528,21,237,247),
		Rect2(796,21,221,250), Rect2(1041,22,256,242), Rect2(1314,27,215,244),
		Rect2(26,310,240,225), Rect2(288,300,227,224), Rect2(531,282,218,253),
		Rect2(782,281,237,220), Rect2(1045,283,246,260), Rect2(1304,320,225,223),
		Rect2(11,570,223,176), Rect2(271,561,223,185), Rect2(513,566,269,175),
		Rect2(800,600,198,141), Rect2(1028,578,213,174), Rect2(1261,568,271,135),
		Rect2(12,770,250,218), Rect2(287,767,240,227), Rect2(533,763,198,230),
		Rect2(751,812,229,180), Rect2(999,845,267,142), Rect2(1271,880,258,98),
	],
}
# Absolute source x of the body pivot. Cape extent must not move the torso.
const PIVOTS := {
	"roan": [146,398,657,918,1168,1435,153,403,657,921,1176,1439,
		147,402,669,905,1154,1414,145,409,642,892,1133,1405],
	"lumi": [155,414,677,939,1197,1464,169,430,680,943,1199,1460,
		148,410,681,905,1168,1417,157,422,647,893,1136,1400],
}

var state: String = "idle"
var frame_index: int = 0
var elapsed_s: float = 0.0
var _landing_remaining_s: float = 0.0
var _was_airborne: bool = false
var _character: String = ""
var _frames: Dictionary = {}


func reset(sprite: Sprite2D, character: String) -> void:
	state = "idle"
	frame_index = 0
	elapsed_s = 0.0
	_landing_remaining_s = 0.0
	_was_airborne = false
	_character = character
	# The selection/story portrait remains available synchronously, before physics.
	sprite.texture = PrototypeCharacters.texture(character)
	sprite.scale = Vector2(0.16, 0.16)
	sprite.position = Vector2(0, -16.64)


func update(sprite: Sprite2D, character: String, delta: float, grounded: bool,
		motion: Vector2, mobility: int, hurt: bool, dead: bool,
		combat_active: bool = false, recovering: bool = false) -> void:
	if character != _character:
		reset(sprite, character)
	_landing_remaining_s = maxf(0.0, _landing_remaining_s - delta)
	if grounded and _was_airborne:
		_landing_remaining_s = 2.0 / float(CLIPS.land.fps)
	_was_airborne = not grounded
	var next := "idle"
	if dead:
		next = "death"
	elif recovering:
		_landing_remaining_s = 0.0
		_was_airborne = false
	elif hurt:
		next = "hit"
	elif mobility == 1:
		next = "evade"
	elif mobility == 2:
		next = "air_dash"
	elif not grounded:
		next = "jump" if motion.y < -5.0 else "fall"
	elif _landing_remaining_s > 0.0 and not combat_active:
		next = "land"
	elif absf(motion.x) > 10.0 and not combat_active:
		next = "run"
	if next != state:
		state = next
		elapsed_s = 0.0
	else:
		# Accumulate phase at current speed; changing speed never rewinds a stride.
		var rate := clampf(absf(motion.x) / 550.0, 0.55, 1.4) if state == "run" else 1.0
		elapsed_s += delta * rate
	apply_frame(sprite, character, state, maxf(0.0, elapsed_s))


func apply_frame(sprite: Sprite2D, character: String, clip_name: String, time_s: float) -> void:
	var clip: Dictionary = CLIPS[clip_name]
	var index := int(maxf(0.0, time_s) * float(clip.fps))
	index = index % clip.frames.size() if clip.loop else mini(index, clip.frames.size() - 1)
	frame_index = int(clip.frames[index])
	sprite.texture = frame_texture(character, frame_index)
	var scale_factor := 154.0 / float(REGIONS[character][0].size.y)
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(0, 60.0 - (FOOT_Y - FRAME_SIZE.y * 0.5) * scale_factor)
	if clip_name == "air_dash":
		sprite.position.y -= 30.0


func frame_texture(character: String, index: int) -> AtlasTexture:
	var key := "%s:%d" % [character, index]
	if not _frames.has(key):
		var bounds: Rect2 = REGIONS[character][index]
		var region := bounds.grow(1.0)
		var texture := AtlasTexture.new()
		texture.atlas = SHEETS[character]
		texture.region = region
		texture.filter_clip = true
		texture.margin = Rect2(
			Vector2(FRAME_SIZE.x * 0.5 - (float(PIVOTS[character][index]) - region.position.x),
				FOOT_Y - bounds.size.y),
			FRAME_SIZE - region.size
		)
		_frames[key] = texture
	return _frames[key]
