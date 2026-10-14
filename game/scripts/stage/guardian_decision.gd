class_name GuardianDecision
extends RefCounted

## GP-312: 성문 선택은 현재 여정에만 적용하며 이전 완료 저장은 그대로 통과한다.
const FIELD := "guardian_choice"
const LEGACY := "passed"
const PROFILE := {
	"name": "행복의 수호기사",
	"intro": "성문을 지키라는 명령에서 기사의 운명을 선택하세요.",
	"confirm": "선택 확정 · 다음 보상",
	"cards": [
		{"title": "구출", "lines": ["수호기사를 명령에서 풀어줍니다.", "추가 회복 · 최대 체력의 20%", "해금한 방벽 +20 · 상한까지", "필살기 +25 · 이번 여정에 적용"]},
		{"title": "파괴", "lines": ["수호기사의 명령핵을 가져갑니다.", "이후 검·활·공격 필살기 피해 +10%", "이후 받는 전투 피해 +10%", "이번 여정 종료 시 효과 해제"]},
	],
}

static func label(choice: String) -> String:
	return "구출" if choice == "rescue" else "파괴" if choice == "destroy" else "성문 통과" if choice == LEGACY else "미선택"

static func lines(choice: String) -> Array[String]:
	if choice == "rescue": return ["선택 즉시 체력20%·방벽20·필살기25 보충", "현재 잔량은 생존 상태와 필살기에서 확인", "장면 확인·이어하기로 다시 지급하지 않습니다"]
	if choice == "destroy": return ["검·활·공격 필살기 피해 +10%", "받는 전투 피해 +10%", "현재 여정에만 적용 · 최종 반올림"]
	return ["성문을 통과했습니다. 추가 효과는 없습니다."]

static func valid_checkpoint(stage: Dictionary) -> bool:
	var history: Array = stage.get("history", [])
	if not stage.has(FIELD):
		return history.all(func(entry: Dictionary) -> bool: return not entry.has(FIELD))
	if stage.get("run_mode") != "journey" or stage.get("limit") != 10 or int(stage.get("number", 0)) < 9:
		return false
	var choice: Variant = stage[FIELD]
	if not choice is String or choice not in ["", "rescue", "destroy", LEGACY]: return false
	if history.size() < 9 or history[8].get(FIELD) != choice: return false
	for i in history.size():
		if i != 8 and history[i].has(FIELD): return false
	if choice.is_empty() and (int(stage.number) != 9 or stage.get("reward_claimed") != false): return false
	return true
