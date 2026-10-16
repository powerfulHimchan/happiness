class_name HeartEncounter
extends RefCounted

const LOCKED := "locked"
const AVAILABLE := "available"
const PENDING := "pending"
const ACTIVE := "active"
const DEFEATED := "defeated"
const SEEN := "seen"
const VICTORY_SCENE := "heart_victory"

static func blocks_completion(phase: String) -> bool:
	return phase in [AVAILABLE, PENDING, ACTIVE, DEFEATED]

static func valid_checkpoint(state: Dictionary) -> bool:
	var stage: Dictionary = state.stage
	if not stage.has("heart_battle"): return not stage.history[-1].has("heart_cleared")
	if not stage.heart_battle is String or stage.heart_battle not in [LOCKED, AVAILABLE, PENDING, DEFEATED, SEEN]: return false
	if stage.get("run_mode") != JourneyRoutePlan.MODE or SeraEncounter.boss_id(stage) != SeraEncounter.ID: return false
	var phase: String = stage.heart_battle
	for entry in stage.history.slice(0, -1):
		if entry.has("heart_cleared"): return false
	if stage.history[-1].has("heart_cleared") and (not stage.history[-1].heart_cleared is bool or stage.history[-1].heart_cleared != (phase == SEEN)): return false
	if phase == SEEN and stage.history[-1].get("heart_cleared") != true: return false
	if phase in [LOCKED, AVAILABLE]: return not stage.history[-1].has("heart_cleared")
	if int(stage.number) != 10 or stage.get("boss_choice") not in ["rescue", "destroy"]: return false
	if state.has("story") and (stage.get("heart_threshold") != HeartThreshold.SEEN or state.story.get("pending") != ""): return false
	return stage.get("arrival_ending") == (ArrivalEnding.SEEN if phase == SEEN else ArrivalEnding.LOCKED)

static func victory(character: String, choice: String) -> Dictionary:
	return {"id": VICTORY_SCENE, "name": "멈춘 심장의 명령", "portrait": "heart", "speaker": "행복의 심장", "confirm": "승리 기록", "skip": "건너뛰고 기록", "footer": "이번 선택과 심장 제압을 여행 기록에 남깁니다", "lines": [
		"%s의 마지막 공격에 행복의 심장을 감싸던 고리가 멈췄다. 주민들의 슬픔을 옮기던 명령도 잠시 끊긴다." % PrototypeCharacters.display_name(character),
		"기계가 사라진 것은 아니다. 하지만 이제 더는 손댈 수 없는 신도, 바꿀 수 없는 운명도 아니다.",
		"세라는 친구 곁에서 멎은 기계를 바라본다. '이제부터는 누구도 혼자 짊어지지 않는 답을 찾아요.' 두 사람은 시계탑의 약속을 다시 확인한다." if choice == "rescue" else "부서진 왕관의 빛이 잦아든다. 주인공은 세라의 이름을 기억하며, 이 힘을 어떻게 끝낼지 스스로 답을 찾기로 한다.",
		"새벽시계에 남은 금과 기계의 마지막 문양을 기록한다. 모두의 행복을 어떻게 바꿀지는 다음 선택에 달려 있다.",
	]}

static func draw_arena(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(-1000, -1000, 7000, 1840), Color("18283e"))
	for x in [3860, 4070, 4700, 4880]:
		canvas.draw_rect(Rect2(x, 80, 35, 760), Color("3e586c"))
		canvas.draw_line(Vector2(x + 17, 160), Vector2(x + 17, 750), Color("72bdc3"), 6)
	var center := Vector2(4450, 420)
	for radius in [150, 210]: canvas.draw_arc(center, radius, 0, TAU, 64, Color("9c8054"), 10)
	for i in 12:
		var axis := Vector2.UP.rotated(i * TAU / 12)
		canvas.draw_line(center + axis * 155, center + axis * 202, Color("d1af64"), 12)
	canvas.draw_rect(Rect2(-1000, 840, 7000, 1500), Color("3e586c"))
	canvas.draw_rect(Rect2(-1000, 840, 7000, 12), Color("72bdc3"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(4150, 155), "행복의 심장 · 의식의 방", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("ffdc91"))
