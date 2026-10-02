class_name PrototypeMemoryAbilities
extends RefCounted

## 영구 해금은 선택지를 열고, 도전마다 한 기억만 장착한다.
const IDS := ["", "clockwork_guard", "core_echo"]
const CHOICE_IDS := {"rescue": "clockwork_guard", "destroy": "core_echo"}


static func valid_id(value: Variant) -> bool:
	return value is String and value in IDS


static func available(id: String, unlocked: Dictionary) -> bool:
	return valid_id(id) and (id.is_empty() or unlocked.get(id, false) == true)


static func profile(id: String) -> Dictionary:
	match id:
		"clockwork_guard": return {"name": "태엽 수호", "effect": "최대 체력 +5", "condition": "기사 구출로 해금"}
		"core_echo": return {"name": "핵의 잔향", "effect": "스킬 피해 +10%", "condition": "기사 파괴로 해금"}
	return {"name": "기억 없음", "effect": "능력 없이 시작", "condition": "항상 선택 가능"}


static func health_bonus(id: String) -> int:
	return 5 if id == "clockwork_guard" else 0


static func damage_multiplier(id: String, kind: String) -> float:
	return 1.10 if id == "core_echo" and kind == "skill" else 1.0
