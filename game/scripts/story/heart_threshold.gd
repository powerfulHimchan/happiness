class_name HeartThreshold
extends RefCounted

## GP-317: 새 이야기 전체 여정의 세라 선택과 심장 입구를 연결한다.
const SCENE_ID := "heart_threshold"
const UNREACHED := "unreached"
const PENDING := "pending"
const SEEN := "seen"

static func valid_checkpoint(state: Dictionary) -> bool:
	var stage: Dictionary = state.stage
	if not stage.has("heart_threshold"): return true # 이전 여정은 기존 완료 흐름을 유지한다.
	if stage.get("run_mode") != JourneyRoutePlan.MODE or SeraEncounter.boss_id(stage) != SeraEncounter.ID: return false
	if not stage.heart_threshold is String or stage.heart_threshold not in [UNREACHED, PENDING, SEEN]: return false
	if not state.has("story"): return false
	var choice := String(stage.get("boss_choice", ""))
	if choice.is_empty(): return stage.heart_threshold == UNREACHED
	return int(stage.number) == 10 and stage.heart_threshold in [PENDING, SEEN] and state.story.get("pending") == ""

static func scene(character: String, choice: String, guardian: String) -> Dictionary:
	var hero := PrototypeCharacters.display_name(character)
	var guardian_line := "성문에 남은 힘은 사라졌다. %s는 돌아갈 길을 확인하고 계단 너머의 낮은 울림에 귀를 기울인다." % hero
	if guardian == "rescue":
		guardian_line = "성문에서 풀려난 수호기사가 돌아갈 길을 지킨다. " + ("세라는 더는 명령을 따르지 않겠다고 말한다." if choice == "rescue" else "%s는 자신의 선택을 기억하며 계단을 내려다본다." % hero)
	var lines: Array[String] = [
		"왕관의 명령이 끊기자 궁전 아래로 내려가는 문이 열린다. %s의 새벽시계는 문 너머의 맥박과 같은 속도로 뛴다." % hero,
		"세라: '저 아래가 행복의 심장이 있는 곳이에요. 모두가 웃어야 한다는 목소리도 거기서 들려왔어요.' 세라는 왕관을 내려놓고 친구 곁에 선다." if choice == "rescue" else "부서진 왕관의 빛이 지하 계단을 비춘다. 세라의 목소리는 더 이상 들리지 않는다. %s는 되찾은 친구의 이름을 되뇌며 홀로 문을 연다." % hero,
		guardian_line,
		"심장의 문 앞에는 주민들의 똑같은 미소가 새겨져 있다. 새벽시계의 금 사이로 빛이 새어 나오자 문이 조금 열린다.",
		"문 너머에는 슬픔까지 지워 버리는 행복이 기다리고 있을까. %s는 시계탑의 약속을 붙잡는다." % hero,
		"지금까지의 여정을 기록하고 새벽의 광장에서 다음 걸음을 준비한다. 행복의 심장에 닿기 위한 길은 이제 시작이다.",
	]
	return {"id": SCENE_ID, "name": "행복의 심장 앞에서", "portrait": "heart", "speaker": "행복의 심장 입구", "lines": lines, "footer": "세라의 선택을 간직한 채 다음 여정을 준비합니다", "confirm": "여정 기록", "skip": "건너뛰고 기록"}
