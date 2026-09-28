class_name CombatFeedbackController
extends Node2D

## CP-404 타격 피드백을 게임 판정과 분리해 재생한다.
## 타격 정지는 시각 효과만 멈춘 것처럼 표현하며 물리 시간과 피해 판정은 건드리지 않는다.

const BASIC_HIT_STOP_S := 0.04
const STRONG_HIT_STOP_S := 0.07
const IMPACT_FLASH_S := 0.12
const PLAYER_HIT_FLASH_S := 0.12
const AUDIO_MIX_RATE := 22050

var sound_volume: float = 0.80
var vibration_enabled: bool = true
var screen_shake_enabled: bool = true
var hit_feedback_count: int = 0
var strong_hit_count: int = 0
var player_hit_count: int = 0
var precise_evade_feedback_count: int = 0
var ultimate_feedback_count: int = 0
var sound_play_count: int = 0
var vibration_request_count: int = 0
var last_hit_stop_s: float = 0.0
var last_feedback_label: String = "피드백 대기"
var _visual_hit_stop_remaining_s: float = 0.0
var _impact_remaining_s: float = 0.0
var _impact_position: Vector2 = Vector2.ZERO
var _impact_color: Color = Color.WHITE
var _shake_remaining_s: float = 0.0
var _shake_duration_s: float = 0.0
var _shake_strength_px: float = 0.0
var _shake_elapsed_s: float = 0.0
var _audio_player: AudioStreamPlayer
var _hit_stream: AudioStreamWAV

@onready var player: PrototypePlayer = $"../Player"
@onready var camera: Camera2D = $"../Player/Camera2D"
@onready var sword_combat: SwordCombatController = $"../Player/SwordCombatController"
@onready var bow_combat: BowCombatController = $"../Player/BowCombatController"
@onready var ultimate_controller: UltimateController = $"../Player/UltimateController"


func _ready() -> void:
	z_index = 90
	sword_combat.hit_registered.connect(_on_weapon_hit.bind("sword"))
	bow_combat.hit_registered.connect(_on_weapon_hit.bind("bow"))
	player.damage_received.connect(_on_player_damage_received)
	ultimate_controller.precise_evade_registered.connect(_on_precise_evade)
	ultimate_controller.ultimate_activated.connect(_on_ultimate_activated)
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_hit_stream = _build_tone_stream()
	_audio_player.stream = _hit_stream


func _process(delta: float) -> void:
	_visual_hit_stop_remaining_s = maxf(0.0, _visual_hit_stop_remaining_s - delta)
	_impact_remaining_s = maxf(0.0, _impact_remaining_s - delta)
	_update_camera_shake(delta)
	queue_redraw()


func _draw() -> void:
	if _impact_remaining_s <= 0.0:
		return
	var ratio := _impact_remaining_s / IMPACT_FLASH_S
	var radius := lerpf(62.0, 18.0, ratio)
	var color := Color(_impact_color, clampf(ratio, 0.0, 1.0))
	draw_circle(_impact_position, radius * 0.48, Color(color, 0.16), true)
	draw_arc(_impact_position, radius, 0.0, TAU, 28, color, 7.0, true)
	for index in 8:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
		draw_line(
			_impact_position + direction * radius * 0.42,
			_impact_position + direction * radius * 1.18,
			color,
			4.0
		)


func configure(
	new_sound_volume: float,
	new_vibration_enabled: bool,
	new_screen_shake_enabled: bool
) -> void:
	sound_volume = clampf(new_sound_volume, 0.0, 1.0)
	vibration_enabled = new_vibration_enabled
	screen_shake_enabled = new_screen_shake_enabled
	if not screen_shake_enabled:
		_stop_camera_shake()


func feedback_snapshot() -> Dictionary:
	return {
		"sound_volume": sound_volume,
		"vibration_enabled": vibration_enabled,
		"screen_shake_enabled": screen_shake_enabled,
		"hit_feedback_count": hit_feedback_count,
		"strong_hit_count": strong_hit_count,
		"player_hit_count": player_hit_count,
		"precise_evade_feedback_count": precise_evade_feedback_count,
		"ultimate_feedback_count": ultimate_feedback_count,
		"sound_play_count": sound_play_count,
		"vibration_request_count": vibration_request_count,
		"last_hit_stop_s": last_hit_stop_s,
		"visual_hit_stop_remaining_s": _visual_hit_stop_remaining_s,
		"shake_remaining_s": _shake_remaining_s,
		"last_feedback_label": last_feedback_label,
	}


func trigger_hit_feedback_for_test(
	is_strong: bool,
	damage: int,
	position: Vector2
) -> void:
	_play_weapon_hit(is_strong, damage, position, "테스트")


func _on_weapon_hit(
	is_skill: bool,
	target: PrototypeTarget,
	damage: int,
	weapon_id: String
) -> void:
	var is_strong := is_skill or damage >= 20
	var position := target.global_position + PrototypeTarget.BODY_CENTER
	_play_weapon_hit(is_strong, damage, position, weapon_id)


func _play_weapon_hit(
	is_strong: bool,
	damage: int,
	position: Vector2,
	source_label: String
) -> void:
	hit_feedback_count += 1
	if is_strong:
		strong_hit_count += 1
	last_hit_stop_s = STRONG_HIT_STOP_S if is_strong else BASIC_HIT_STOP_S
	_visual_hit_stop_remaining_s = last_hit_stop_s
	_impact_remaining_s = IMPACT_FLASH_S
	_impact_position = position
	_impact_color = Color("ffd166") if is_strong else Color("eef8fa")
	last_feedback_label = "%s %s 타격 · 피해 %d" % [
		source_label,
		"강" if is_strong else "기본",
		damage,
	]
	_play_tone(1.18 if is_strong else 0.92)
	if screen_shake_enabled:
		_start_camera_shake(7.0 if is_strong else 2.5, 0.13 if is_strong else 0.07)
	if is_strong:
		_request_vibration(45)


func _on_player_damage_received(event: DamageEvent) -> void:
	player_hit_count += 1
	_impact_remaining_s = PLAYER_HIT_FLASH_S
	_impact_position = player.global_position + Vector2(0.0, -42.0)
	_impact_color = Color("ff6b6b")
	last_feedback_label = "플레이어 피격 · 피해 %d" % (event.damage if event != null else 0)
	_play_tone(0.62)
	if screen_shake_enabled:
		_start_camera_shake(8.0, 0.16)


func _on_precise_evade() -> void:
	precise_evade_feedback_count += 1
	last_feedback_label = "정확한 회피"
	_play_tone(1.42)
	_request_vibration(32)


func _on_ultimate_activated() -> void:
	ultimate_feedback_count += 1
	last_feedback_label = "필살기 발동"
	_play_tone(0.78)
	if screen_shake_enabled:
		_start_camera_shake(12.0, 0.24)
	_request_vibration(70)


func _play_tone(pitch_scale: float) -> void:
	if sound_volume <= 0.0 or _audio_player == null:
		return
	_audio_player.volume_db = linear_to_db(maxf(sound_volume, 0.001))
	_audio_player.pitch_scale = pitch_scale
	_audio_player.play()
	sound_play_count += 1


func _request_vibration(duration_ms: int) -> void:
	if not vibration_enabled:
		return
	vibration_request_count += 1
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func _start_camera_shake(strength_px: float, duration_s: float) -> void:
	_shake_strength_px = maxf(_shake_strength_px, strength_px)
	_shake_duration_s = maxf(_shake_duration_s, duration_s)
	_shake_remaining_s = maxf(_shake_remaining_s, duration_s)
	_shake_elapsed_s = 0.0


func _update_camera_shake(delta: float) -> void:
	if not screen_shake_enabled or _shake_remaining_s <= 0.0:
		_stop_camera_shake()
		return
	_shake_remaining_s = maxf(0.0, _shake_remaining_s - delta)
	_shake_elapsed_s += delta
	var ratio := _shake_remaining_s / maxf(_shake_duration_s, 0.001)
	camera.offset = Vector2(
		sin(_shake_elapsed_s * 117.0),
		cos(_shake_elapsed_s * 91.0)
	) * _shake_strength_px * ratio
	if _shake_remaining_s <= 0.0:
		_stop_camera_shake()


func _stop_camera_shake() -> void:
	_shake_remaining_s = 0.0
	_shake_duration_s = 0.0
	_shake_strength_px = 0.0
	_shake_elapsed_s = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO


func _build_tone_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_MIX_RATE
	stream.stereo = false
	var duration_s := 0.07
	var sample_count := int(float(AUDIO_MIX_RATE) * duration_s)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var elapsed := float(index) / float(AUDIO_MIX_RATE)
		var envelope := 1.0 - float(index) / float(sample_count)
		var sample := int(sin(TAU * 520.0 * elapsed) * envelope * 15000.0)
		data.encode_s16(index * 2, sample)
	stream.data = data
	return stream
