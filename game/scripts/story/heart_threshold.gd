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

static func scene(character: String, choice: String, guardian: String, arrival: bool = false, arrival_seen: bool = false) -> Dictionary:
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
	if arrival: lines[-1] = "문 앞에서 발걸음을 멈춘 주인공은 행복의 나라를 돌아본다. 긴 여행 끝에 도착한 나라에는 어떤 답이 기다리고 있을까."
	if arrival_seen:
		lines[0] = "지난 여정에서는 문 앞에서 돌아섰다. 이번에는 %s가 새벽시계를 문양에 맞춘다. 잠겨 있던 문 안쪽에서 거대한 기계가 모습을 드러낸다." % hero
		lines[3] = "행복의 심장은 고대 마법 기계였다. 주민들에게서 거둔 슬픔을 이름이 지워진 누군가에게 옮겨, 나라의 미소를 유지하고 있었다."
		lines[4] = "세라: '당신의 이름이 지워진 이유가 여기 있었어요. 이제 혼자 짊어지게 두지 않을게요.' 친구는 기계에 새겨진 의식의 문장을 함께 읽는다." if choice == "rescue" else "부서진 왕관의 빛이 의식의 문장을 드러낸다. %s는 지워진 이름과 몸의 이상이 이 기계에 이어져 있음을 깨닫는다." % hero
		lines[5] = "새벽시계가 울리자 기계가 눈을 뜬다. 되찾은 진실을 기록하고 돌아가, 모두의 슬픔을 떠넘기는 의식에 맞설 다음 여정을 준비한다."
	return {"id": SCENE_ID, "name": "행복의 심장 · 미소의 대가" if arrival_seen else "행복의 심장 앞에서", "portrait": "heart", "speaker": "행복의 심장 입구", "lines": lines, "footer": "새 기억은 수첩에 남습니다 · 심장 전투를 준비합니다" if arrival_seen else "세라의 선택을 간직한 채 다음 여정을 준비합니다", "confirm": "도착 이야기" if arrival else "여정 기록", "skip": "건너뛰고 계속" if arrival else "건너뛰고 기록"}
