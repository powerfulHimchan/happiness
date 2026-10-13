class_name PrototypeStory
extends RefCounted

## GP-277~306: 현재 3/5단계 여행의 단서. 정식 행복의 나라/세라/네 엔딩은 후속 콘텐츠다.
const FRAGMENTS := {
	"dawn_watch": {"name": "금이 간 새벽시계", "hint": "이야기 여행의 첫 스테이지 통과", "lines": ["가족이 남긴 시계는 새벽 직전에 멈춰 있다.", "유리의 금은 오래된 흉터처럼 손바닥을 가른다.", "돌아오라는 말인지, 앞으로 가라는 말인지 아직 알 수 없다."]},
	"wind_ribbon": {"name": "바람 속 리본", "hint": "이야기 여행에서 바람 길 통과", "lines": ["꽃밭 위로 작은 리본 하나가 날아간다.", "누군가와 함께 달리던 발소리가 잠깐 들린다.", "기억 속 두 번째 얼굴은 바람에 지워져 있다."]},
	"forest_song": {"name": "거꾸로 들리는 자장가", "hint": "이야기 여행에서 거꾸로 자란 숲 통과", "lines": ["숲의 잎사귀가 가족의 자장가를 거꾸로 부른다.", "잊어야 할 노래라면 왜 몸이 먼저 기억할까.", "나무 아래에는 아이 한 명을 숨길 만큼 작은 자리가 있다."]},
	"ruins_shadow": {"name": "늦게 따라오는 그림자", "hint": "이야기 여행에서 별시계 유적 통과", "lines": ["멈춘 시계 앞에서 그림자가 한 박자 늦게 움직인다.", "몸의 이상과 새벽시계의 금이 함께 늘어난다.", "병과 시계는 서로 다른 문제가 아닐지도 모른다."]},
	"festival_smile": {"name": "반복되는 미소", "hint": "이야기 여행에서 태엽 축제장 통과", "lines": ["장난감 병정은 같은 순간에 같은 미소를 짓는다.", "즐거운 노래도 슬픈 표정이 나올 부분에서 처음으로 돌아간다.", "슬픔이 없다는 것과 행복하다는 것은 같은 뜻일까."]},
	"knight_order": {"name": "기사에게 남은 명령", "hint": "이야기 여행에서 태엽 기사 격파", "lines": ["기사의 태엽에는 사람을 지키라는 말이 새겨져 있다.", "그 아래 지워진 글자는 웃음을 멈추지 말라는 명령이다.", "누구를 위한 보호였는지 기사는 대답하지 못한다."]},
	"family_note": {"name": "빈 이름의 가족 편지", "hint": "한 이야기 여행에서 세 접근 지역 통과", "lines": ["흩어진 단서가 이름 없는 편지의 문장을 잇는다.", "아이를 잊으라는 명령에 따르지 않은 사람이 있었다.", "새벽시계를 쥐여 준 손은 마지막까지 놓기를 망설였다."]},
	"childhood_promise": {"name": "시계탑의 약속", "hint": "한 이야기 여행에서 네 접근 지역 통과", "lines": ["시계탑 위에서 두 아이가 진짜 행복을 함께 찾자고 약속했다.", "한 아이는 이름을 잃었고 다른 아이는 약속만 기억했다.", "행복의 나라에서 그 친구가 아직 기다리고 있을까."]},
}
const ROUTE_FRAGMENT := {"wind": "wind_ribbon", "forest": "forest_song", "ruins": "ruins_shadow", "festival": "festival_smile"}
const CHRONICLES := {
	"rescue": {"name": "멈출 수 있게 된 기사", "hint": "이야기 여행 완주 뒤 기사 구출", "lines": ["기사의 웃음이 처음으로 멈춘다.", "명령 대신 자신의 의지로 다음 여행에 힘을 보태기로 한다.", "{hero}는 남겨진 질문을 품고 행복의 나라로 향한다."]},
	"destroy": {"name": "부서진 태엽의 목소리", "hint": "이야기 여행 완주 뒤 기사 파괴", "lines": ["태엽핵이 남기고 간 힘은 강하지만 손끝을 아프게 한다.", "기사에게 질문할 기회는 이번 여행에서 사라졌다.", "{hero}는 다음번에는 다른 답을 선택할 수 있음을 기억한다."]},
	"regions_rescue": {"name": "네 갈래 길과 작은 동행", "hint": "한 이야기 여행에서 네 지역 통과·기사 구출", "lines": ["바람과 숲, 유적과 축제의 기억이 시계탑의 약속을 잇는다.", "기사는 행복의 나라를 향하는 길을 가리킨다.", "{hero}는 모두가 웃는 곳에서 잃어버린 친구를 찾으려 한다."]},
	"regions_destroy": {"name": "네 갈래 길과 태엽핵", "hint": "한 이야기 여행에서 네 지역 통과·기사 파괴", "lines": ["네 지역의 단서가 남겨진 약속을 되살린다.", "태엽핵은 행복의 나라로 가는 위험한 길에서 힘이 될 것이다.", "{hero}는 그곳의 미소 뒤에 남은 슬픔을 확인하려 한다."]},
}

static func valid_ids(ids: Variant) -> bool:
	if not ids is Array or ids.size() > FRAGMENTS.size(): return false
	var seen: Array = []
	for id in ids:
		if not id is String or not FRAGMENTS.has(id) or id in seen: return false
		seen.append(id)
	return true

static func regions(history: Array, paired: bool = false) -> Array[String]:
	var result: Array[String] = []
	for entry in history:
		if paired and int(entry.stage) % 2 == 1: continue
		if entry.route in ROUTE_FRAGMENT and entry.route not in result: result.append(String(entry.route))
	return result

static func earned(history: Array, boss_stage: int) -> Array[String]:
	var result: Array[String] = []
	for entry in history:
		if int(entry.stage) == 1: result.append("dawn_watch")
		var id: String = ROUTE_FRAGMENT.get(entry.route, "")
		if not id.is_empty() and id not in result and (boss_stage != 10 or int(entry.stage) % 2 == 0): result.append(id)
		if int(entry.stage) == boss_stage: result.append("knight_order")
	var count := regions(history, boss_stage == 10).size()
	if count >= 3: result.append("family_note")
	if count == 4: result.append("childhood_promise")
	return result

static func chronicle_id(history: Array, choice: String) -> String:
	return ("regions_" if regions(history).size() == 4 else "") + choice

static func scene(id: String, history: Array, character: String, known: Array, rewinds: int, boss_stage: int = 0) -> Dictionary:
	var title := "시계가 가리키는 길"
	var lines: Array[String] = []
	if id == "prologue":
		lines.assign(["{hero}에게 남은 시간은 길지 않다.", "가족의 새벽시계를 들고, 어린 시절 들었던 행복의 나라를 찾아 떠난다.", "이 길에서 배우는 싸움과 선택이 자신의 직업이 될 것이다."])
		if rewinds >= 3: lines.append("시계가 돌 때마다 지워졌던 목소리가 조금 더 선명해진다.")
		if rewinds > 0: lines.append("새벽으로 돌아온 횟수는 %d번. 잃어버린 시간을 다시 살펴본다." % rewinds)
	else:
		var entry: Dictionary = history[-1]
		if entry.route in [JourneyRoutePlan.GATE, JourneyRoutePlan.CORE] and int(entry.stage) != boss_stage:
			return {"id": id, "name": "행복의 나라 성문", "lines": ["{hero}는 네 갈래 길을 지나 성문 앞에 섰다.".replace("{hero}", PrototypeCharacters.display_name(character)), "이곳의 진실은 아직 시계 너머에 남아 있다.", "다음 관문에서는 태엽 기사가 마지막 길을 지킨다."]}
		var fragment: String = "knight_order" if int(entry.stage) == boss_stage else ROUTE_FRAGMENT.get(entry.route, "dawn_watch")
		title = String(FRAGMENTS[fragment].name)
		lines.assign(FRAGMENTS[fragment].lines)
		if int(entry.stage) != boss_stage and history.slice(0, -1).any(func(previous: Dictionary) -> bool: return previous.route == entry.route):
			lines.assign(["같은 길로 돌아왔지만 새벽시계의 금은 조금 달라 보인다.", "되풀이되는 풍경보다 이번 여행에서 바뀐 선택을 살펴본다.", "이미 찾은 기억을 다음 단서와 이어 보려 한다."])
		var visited := regions(history, boss_stage == 10)
		if visited.size() >= 3: lines.append("흩어진 기억 %d곳이 이름 없는 가족의 편지를 잇는다." % visited.size())
		elif visited.size() > 0: lines.append("서로 다른 길 %d곳에서 단서를 찾았다. 길의 순서보다 남은 기억이 중요하다." % visited.size())
		else: lines.append("시계의 금을 어루만지고 첫 길을 떠날 준비를 한다.")
		if fragment in known: lines[-1] = "지난 여행에서 본 기억이다. 이번에는 다음 단서와 이어 보려 한다."
	for i in lines.size(): lines[i] = lines[i].replace("{hero}", PrototypeCharacters.display_name(character))
	return {"id": id, "name": title, "lines": lines}

static func journal_cards(tab: int, progress: Dictionary, character: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var profiles: Dictionary = FRAGMENTS if tab == 0 else CHRONICLES
	var collected: Dictionary = progress.get("fragments", {}) if tab == 0 else progress.get("chronicles", {})
	for id in profiles:
		var open: bool = collected.get(id, false) if tab == 0 else collected.has(id)
		var profile: Dictionary = profiles[id]
		var lines: Array[String] = []
		if open:
			for line in profile.lines: lines.append(String(line).replace("{hero}", PrototypeCharacters.display_name(String(collected[id].character) if tab == 1 else character)))
		else: lines.assign([String(profile.hint), "아직 발견하지 않은 내용입니다"])
		result.append({"id": id, "name": profile.name if open else "기억 조각 %d" % (result.size() + 1) if tab == 0 else "여행 기록 %d" % (result.size() + 1), "open": open, "status": "발견함" if open else "미발견", "lines": lines})
	return result
