class_name ControlLayoutStore
extends RefCounted

## CP-402 조작 프리셋을 버전이 있는 JSON으로 기기 내부에 저장한다.
## 요소별로 좌표와 크기를 검증해 손상된 항목만 프리셋 기본값으로 복구한다.

const SCHEMA_VERSION := 1
const DEFAULT_FILE_PATH := "user://control_layout.json"
const VALID_PRESETS: Array[String] = ["default", "left", "custom"]

var file_path: String


func _init(custom_file_path: String = DEFAULT_FILE_PATH) -> void:
	file_path = custom_file_path


func save_layout(
	active_preset: String,
	active_layout: Dictionary,
	custom_layout: Dictionary,
	control_ids: Array[StringName]
) -> Error:
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"active_preset": active_preset if active_preset in VALID_PRESETS else "default",
		"active_layout": _encode_layout(active_layout, control_ids),
		"custom_layout": (
			_encode_layout(custom_layout, control_ids)
			if not custom_layout.is_empty()
			else null
		),
	}
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	return OK


func load_layout(preset_layouts: Dictionary, control_ids: Array[StringName]) -> Dictionary:
	var default_layout: Dictionary = preset_layouts.get("default", {})
	var recovered_controls: Array[String] = []
	var recovered_fields: Array[String] = []
	var fallback := {
		"loaded": false,
		"active_preset": "default",
		"active_layout": default_layout.duplicate(true),
		"custom_layout": {},
		"recovered_controls": recovered_controls,
		"recovered_fields": recovered_fields,
	}
	if not FileAccess.file_exists(file_path):
		return fallback

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		recovered_fields.append("file")
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		recovered_fields.append("json")
		recovered_controls.append_array(_control_id_strings(control_ids))
		return fallback
	var payload := parsed as Dictionary
	if int(payload.get("schema_version", -1)) != SCHEMA_VERSION:
		recovered_fields.append("schema_version")
		recovered_controls.append_array(_control_id_strings(control_ids))
		return fallback

	var preset_id := String(payload.get("active_preset", "default"))
	if preset_id not in VALID_PRESETS:
		preset_id = "default"
		recovered_fields.append("active_preset")
	var preset_fallback: Dictionary = (
		preset_layouts.get(preset_id, default_layout)
		if preset_id != "custom"
		else default_layout
	)
	var active_result := _decode_layout(
		payload.get("active_layout", {}),
		preset_fallback,
		control_ids
	)
	var custom_layout: Dictionary = {}
	var raw_custom: Variant = payload.get("custom_layout", null)
	if typeof(raw_custom) == TYPE_DICTIONARY:
		var custom_result := _decode_layout(raw_custom, default_layout, control_ids)
		custom_layout = custom_result["layout"]
		for control_id in custom_result["recovered_controls"]:
			recovered_controls.append("custom:%s" % control_id)
		for field in custom_result["recovered_fields"]:
			recovered_fields.append("custom:%s" % field)

	fallback["loaded"] = true
	fallback["active_preset"] = preset_id
	fallback["active_layout"] = active_result["layout"]
	fallback["custom_layout"] = custom_layout
	recovered_controls.append_array(active_result["recovered_controls"])
	recovered_fields.append_array(active_result["recovered_fields"])
	return fallback


func _encode_layout(layout: Dictionary, control_ids: Array[StringName]) -> Dictionary:
	var centers: Dictionary = layout.get("centers", {})
	var scales: Dictionary = layout.get("scales", {})
	var elements := {}
	for control_id in control_ids:
		var center: Vector2 = centers.get(control_id, Vector2.ZERO)
		elements[String(control_id)] = {
			"center": [center.x, center.y],
			"scale": float(scales.get(control_id, 1.0)),
		}
	return {
		"opacity": float(layout.get("opacity", 0.82)),
		"elements": elements,
	}


func _decode_layout(raw_value: Variant, fallback: Dictionary, control_ids: Array[StringName]) -> Dictionary:
	var result := fallback.duplicate(true)
	var recovered_controls: Array[String] = []
	var recovered_fields: Array[String] = []
	if typeof(raw_value) != TYPE_DICTIONARY:
		return {
			"layout": result,
			"recovered_controls": _control_id_strings(control_ids),
			"recovered_fields": ["layout"],
		}
	var raw := raw_value as Dictionary
	var fallback_centers: Dictionary = fallback.get("centers", {})
	var fallback_scales: Dictionary = fallback.get("scales", {})
	var centers := fallback_centers.duplicate(true)
	var scales := fallback_scales.duplicate(true)
	var elements_value: Variant = raw.get("elements", {})
	var elements: Dictionary = elements_value if typeof(elements_value) == TYPE_DICTIONARY else {}
	if typeof(elements_value) != TYPE_DICTIONARY:
		recovered_fields.append("elements")

	for control_id in control_ids:
		var element_value: Variant = elements.get(String(control_id), null)
		if not _is_valid_element(element_value):
			recovered_controls.append(String(control_id))
			continue
		var element := element_value as Dictionary
		var center := element["center"] as Array
		centers[control_id] = Vector2(float(center[0]), float(center[1]))
		scales[control_id] = float(element["scale"])

	var opacity_value: Variant = raw.get("opacity", null)
	var opacity := float(fallback.get("opacity", 0.82))
	if _is_number(opacity_value) and float(opacity_value) >= 0.30 and float(opacity_value) <= 1.00:
		opacity = float(opacity_value)
	else:
		recovered_fields.append("opacity")
	result["centers"] = centers
	result["scales"] = scales
	result["opacity"] = opacity
	return {
		"layout": result,
		"recovered_controls": recovered_controls,
		"recovered_fields": recovered_fields,
	}


func _is_valid_element(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var element := value as Dictionary
	var center_value: Variant = element.get("center", null)
	var scale_value: Variant = element.get("scale", null)
	if typeof(center_value) != TYPE_ARRAY or (center_value as Array).size() != 2:
		return false
	var center := center_value as Array
	if not _is_number(center[0]) or not _is_number(center[1]) or not _is_number(scale_value):
		return false
	var x := float(center[0])
	var y := float(center[1])
	var scale := float(scale_value)
	return x >= 0.0 and x <= 1.0 \
		and y >= 0.0 and y <= 1.0 \
		and scale >= 0.70 and scale <= 1.40


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _control_id_strings(control_ids: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for control_id in control_ids:
		result.append(String(control_id))
	return result
