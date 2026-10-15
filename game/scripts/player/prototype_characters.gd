class_name PrototypeCharacters
extends RefCounted

## GP-267: 외형만 선택한다. 이동·전투·성장과 이야기는 같은 경로를 사용한다.
const IDS := ["roan", "lumi"]
const ROAN_TEXTURE: Texture2D = preload("res://assets/characters/roan_idle.tres")
const LUMI_TEXTURE: Texture2D = preload("res://assets/characters/lumi_idle.tres")
const SHARED_STORY := "남은 시간을 걸어 행복의 나라로 향합니다"

static func valid_id(id: Variant) -> bool:
	return id is String and id in IDS

static func display_name(id: String) -> String:
	return "루미" if id == "lumi" else "로안"

static func texture(id: String) -> Texture2D:
	return LUMI_TEXTURE if id == "lumi" else ROAN_TEXTURE

static func appearance(id: String) -> String:
	return "금발 묶음머리 · 코랄빛 망토" if id == "lumi" else "은발 짧은 머리 · 청록빛 망토"
