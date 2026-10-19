class_name ExpeditionStageConstraint
extends RefCounted

const POTION := "recovery_potion"
const ULTIMATE := "ultimate"


static func for_stage(mode: String, expedition: int, stage: int) -> String:
	if mode != JourneyRoutePlan.MODE or expedition < 5: return ""
	if stage in [2, 6]: return POTION
	if stage in [4, 8]: return ULTIMATE
	return ""


static func blocks(constraint: String, action: String) -> bool:
	return not constraint.is_empty() and constraint == action


static func label(constraint: String) -> String:
	return "회복약 봉인" if constraint == POTION else "새 필살기 봉인" if constraint == ULTIMATE else "제약 없음"


static func hint(constraint: String, active: bool, passed: bool) -> String:
	if constraint.is_empty(): return ""
	if passed: return "원정 5 · 제약 해제"
	return ("원정 5 · " if active else "예고 · 웨이브2 ") + label(constraint) + (" · 통과 후 해제" if active else "")
