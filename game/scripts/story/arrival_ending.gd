class_name ArrivalEnding
extends RefCounted

const ID := "arrival"
const SCENE_ID := "ending_arrival"
const LOCKED := "locked"
const PENDING := "pending"
const SEEN := "seen"
const PROFILES := {
	ID: {"name": "도착", "hint": "전체 여정에서 세라의 운명을 선택하고 도착 엔딩 확인", "lines": ["{hero}는 행복의 나라에 도착했다.", "주민들의 기록에는 주인공의 이름이 남아 있지 않았다.", "시계탑의 약속을 품고 새로운 진실을 찾기로 했다."]},
}

static func valid_record(id: Variant, run_id: Variant, character: Variant, choice: Variant) -> bool:
	return id is String and id == ID and run_id is String and not run_id.is_empty() and run_id.length() <= 256 and PrototypeCharacters.valid_id(character) and choice is String and choice in ["rescue", "destroy"]

static func valid_checkpoint(state: Dictionary) -> bool:
	var stage: Dictionary = state.stage
	if not stage.has("arrival_ending"): return true
	var phase: Variant = stage.arrival_ending
	if not phase is String or phase not in [LOCKED, PENDING, SEEN] or stage.get("run_mode") != JourneyRoutePlan.MODE or SeraEncounter.boss_id(stage) != SeraEncounter.ID: return false
	var choice := String(stage.get("boss_choice", ""))
	if choice.is_empty(): return phase == LOCKED
	if int(stage.number) != 10: return false
	if stage.get("heart_battle") in [HeartEncounter.PENDING, HeartEncounter.DEFEATED]: return phase == LOCKED
	if not state.has("story"): return phase == SEEN
	if stage.get("heart_threshold") == HeartThreshold.PENDING: return phase == LOCKED
	return stage.get("heart_threshold") == HeartThreshold.SEEN and phase in [PENDING, SEEN]

static func scene(character: String, choice: String, arrival_seen: bool = false) -> Dictionary:
	var hero := PrototypeCharacters.display_name(character)
	if arrival_seen:
		return {"id": SCENE_ID, "name": "도착 너머의 약속", "portrait": "heart", "speaker": "도착 엔딩 · 재여정", "confirm": "엔딩 기록", "skip": "건너뛰고 기록", "footer": "발견한 진실과 이번 선택을 기록합니다", "lines": [
			"%s는 다시 행복의 나라에 도착했다. 지난번과 같은 미소였지만 이제 그 미소를 움직이는 기계의 정체를 알고 있다." % hero,
			"이름을 잃은 누군가가 주민들의 슬픔을 대신 짊어지고 있었다. 지워진 이름을 찾는 일은 그 의식을 마주하는 일이기도 했다.",
			"세라와 주인공은 더는 한 사람에게 모든 슬픔을 맡기지 않겠다고 약속한다. 시계탑에서 나누었던 말이 이번에는 분명한 목표가 된다." if choice == "rescue" else "왕관과 함께 사라진 세라의 이름을 되뇌었다. %s는 잃어버린 친구의 선택까지 기억하며 의식을 멈출 방법을 찾기로 했다." % hero,
			"새벽시계의 금은 아직 남아 있다. 하지만 기계에 닿은 초침은 처음으로 앞으로 움직였다.",
			"지금은 새벽의 광장으로 돌아가 발견한 진실을 정리한다. 다음에는 문 너머에서 깨어난 행복의 심장과 마주해야 한다.",
			"도착을 넘어, 누구도 혼자 아프지 않은 행복을 찾기 위한 여정이 시작된다.",
		]}
	return {"id": SCENE_ID, "name": "도착 · 이름 없는 행복", "portrait": "heart", "speaker": "도착 엔딩", "confirm": "엔딩 기록", "skip": "건너뛰고 기록", "footer": "한 번 발견한 엔딩은 기억 수첩에 남습니다", "lines": [
		"긴 여행 끝에 %s는 행복의 나라에 도착했다. 성벽 너머의 햇살과 주민들의 미소는 어릴 적 들었던 이야기와 같았다." % hero,
		"하지만 어느 주민도 %s를 기억하지 못했다. 오래된 명부에도, 시계탑에 남은 이름들 사이에도 자신의 이름은 없었다." % hero,
		"세라는 친구의 손을 잡았다. '나는 기억해요. 우리가 함께 했던 약속까지.' 주민들의 빈 기억과 세라가 되찾은 기억 사이에 답이 남아 있었다." if choice == "rescue" else "세라와 왕관이 사라진 자리에는 대답이 남지 않았다. %s는 잃어버린 친구의 이름과 자신의 선택을 함께 기억하기로 했다." % hero,
		"행복한 나라에 닿았는데도 새벽시계의 금과 몸의 이상은 사라지지 않았다. 문 너머의 맥박은 시계와 함께 뛰었다.",
		"도착은 끝이 아니었다. %s는 자신을 기억하지 못하는 나라와 지워진 이름에 대해 더 알아보기로 했다." % hero,
		"새벽의 광장으로 돌아온 주인공은 다음 여정을 준비한다. 시계탑에서 진짜 행복을 찾자던 약속이 다시 길을 가리킨다.",
	]}
