class_name FinalRitual
extends RefCounted

const LOCKED := "locked"
const CHOOSING := "choosing"
const ENDING := "ending"
const SEEN := "seen"
const CHOICE_SCENE := "final_ritual"
const SECRET_SCENE := "clocktower_archive"
const ENDING_SCENE := "final_ending"
const IDS := ["return", "liberation", "dawn"]
const CORE_MEMORIES := ["dawn_watch", "family_note", "heart_machine"]
const RETURN_REWINDS := 3

static func initial(rewinds: int) -> Dictionary:
	return {"phase": LOCKED, "choice": "", "memories": [], "rewinds": rewinds, "secret": false}

static func prepare(state: Dictionary, progress: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	result.phase = CHOOSING
	result.memories = progress.get("fragments", {}).keys()
	for id in CORE_MEMORIES:
		if id not in result.memories: result.memories.append(id)
	result.secret = result.memories.size() == PrototypeStory.FRAGMENTS.size() and progress.get("secrets", {}).get(SECRET_SCENE, false) == true
	return result

static func blocks_completion(state: Dictionary) -> bool:
	return state.get("phase") in [CHOOSING, ENDING]

static func can_choose(state: Dictionary, id: String) -> bool:
	if id not in IDS: return false
	match id:
		"return": return int(state.get("rewinds", 0)) >= RETURN_REWINDS
		"liberation": return CORE_MEMORIES.all(func(key: String) -> bool: return key in state.get("memories", []))
		"dawn": return state.get("memories", []).size() == PrototypeStory.FRAGMENTS.size() and state.get("secret") == true
	return false

static func can_visit_secret(state: Dictionary) -> bool:
	return state.get("phase") == CHOOSING and state.get("memories", []).size() == PrototypeStory.FRAGMENTS.size()

static func valid_checkpoint(stage: Dictionary) -> bool:
	for entry in stage.history.slice(0, -1):
		if entry.has("ending_id"): return false
	if not stage.has("final_ritual"): return not stage.history[-1].has("ending_id")
	var state: Variant = stage.final_ritual
	if not state is Dictionary or state.size() != 5: return false
	if stage.get("run_mode") != JourneyRoutePlan.MODE or SeraEncounter.boss_id(stage) != SeraEncounter.ID: return false
	if not state.get("phase") is String or state.phase not in [LOCKED, CHOOSING, ENDING, SEEN] or not state.get("choice") is String: return false
	if not PrototypeStory.valid_ids(state.get("memories")) or not RunCheckpointStore._number(state.get("rewinds"), 0, 1000000, true) or not state.get("secret") is bool: return false
	if state.phase == LOCKED:
		return state.choice == "" and state.memories.is_empty() and not state.secret and stage.get("heart_battle") != HeartEncounter.SEEN and not stage.history[-1].has("ending_id")
	if int(stage.number) != 10 or stage.get("heart_battle") != HeartEncounter.SEEN or stage.get("arrival_ending") != ArrivalEnding.SEEN or not can_choose(state, "liberation"): return false
	if state.secret and state.memories.size() != PrototypeStory.FRAGMENTS.size(): return false
	if state.phase == CHOOSING: return state.choice == "" and not stage.history[-1].has("ending_id")
	if not can_choose(state, state.choice): return false
	return stage.history[-1].get("ending_id") == state.choice if state.phase == SEEN else not stage.history[-1].has("ending_id")

static func choice_scene(state: Dictionary) -> Dictionary:
	return {"id": CHOICE_SCENE, "name": "이 나라의 행복을 어떻게 바꿀까", "ritual": state.duplicate(true)}

static func secret_scene(character: String, choice: String) -> Dictionary:
	var hero := PrototypeCharacters.display_name(character)
	var subject := hero + ("은" if character == "roan" else "는")
	return {"id": SECRET_SCENE, "name": "시계탑의 비밀 기록실", "portrait": "heart", "speaker": "가족이 남긴 마지막 설계", "confirm": "기록을 품고 돌아가기", "skip": "기록하고 돌아가기", "footer": "기억 10종을 이으면 기계 안에 숨긴 시계탑 기록실이 열립니다", "lines": [
		"멈춘 심장의 문양에 열 개의 기억을 겹치자 시계탑 아래 숨겨 둔 기록실의 문이 열린다. %s 가족이 남긴 시계의 설계도를 발견한다." % subject,
		"새벽시계는 누군가를 다시 의식의 제물로 삼기 위한 장치가 아니었다. 슬픔을 혼자 떠맡은 아이를 가족에게 돌려보내기 위해 만들어졌다.",
		"설계도 뒤에는 다른 연결이 남아 있다. 누구에게도 강요하지 않고, 각자가 동의한 만큼 고통을 나눈다면 한 사람을 추방하지 않아도 된다.",
		"세라는 친구와 함께 주민들에게 진실을 알리기로 한다. 선택할 권리는 왕관도 시계도 아닌 각자의 손에 있다." if choice == "rescue" else "세라가 남긴 약속을 떠올린다. 친구를 잃은 슬픔까지 지우지 않고, 주민들과 함께 살아갈 답을 찾을 수 있다.",
		"%s 기록실의 설계를 마음에 새긴다. 이제 의식을 끝내는 것 너머, 누구도 혼자 아프지 않은 새벽을 선택할 수 있다." % subject,
		"문을 나서도 설계의 기억은 이번 선택에 남는다. 새벽시계의 초침이 앞으로 한 번 움직인다.",
	]}

static func ending_scene(state: Dictionary, character: String, sera_choice: String, brief: bool) -> Dictionary:
	var id := String(state.choice)
	var profile: Dictionary = ArrivalEnding.PROFILES[id]
	var lines: Array[String] = []
	var hero := PrototypeCharacters.display_name(character)
	for line in profile.lines: lines.append(String(line).replace("{hero}는", hero + ("은" if character == "roan" else "는")).replace("{hero}", hero))
	if not brief:
		if id == "return":
			lines.append("세라는 친구가 잊은 약속을 자신의 기억에 간직한다. 언젠가 새로운 약속을 나눌 수 있기를 바라며 광장으로 걸어간다." if sera_choice == "rescue" else "왕관 없는 시계탑은 조용했다. 주인공에게는 설명할 수 없는 그리움이 남아 있지만, 그 이름은 더 이상 떠오르지 않는다.")
		else: lines.append("세라는 친구의 선택을 지켜보며 시계탑에서 나눈 약속을 기억한다." if sera_choice == "rescue" else "주인공은 사라진 세라의 이름을 기록한다. 어떤 결말도 친구와 함께했던 시간을 없애지는 못한다.")
		lines.append("이 결말은 기억 수첩에 남는다. 다음 도전에서는 다른 답을 찾을 수 있다.")
	else: lines.assign([lines[0], lines[-1]])
	return {"id": ENDING_SCENE, "name": "%s · 마지막 선택" % profile.name, "portrait": "heart", "speaker": "엔딩 · " + String(profile.name), "confirm": "이 엔딩 기록", "skip": "기록 저장 재시도" if state.phase == SEEN else "선택 다시 하기", "final_locked": state.phase == SEEN, "footer": "기록하면 이번 여정을 마칩니다 · 다른 엔딩은 다음 도전에서 선택할 수 있습니다", "lines": lines}

static func layout(safe: Rect2) -> Dictionary:
	var cards: Array[Rect2] = []
	for i in 3: cards.append(Rect2(safe.position + safe.size * Vector2(0.05 + i * 0.31, 0.27), safe.size * Vector2(0.28, 0.43)))
	return {"cards": cards, "secret": Rect2(safe.position + safe.size * Vector2(0.05, 0.86), safe.size * Vector2(0.43, 0.09)), "confirm": Rect2(safe.position + safe.size * Vector2(0.52, 0.86), safe.size * Vector2(0.43, 0.09))}

static func draw(canvas, safe: Rect2, state: Dictionary, selected: String, message: String) -> void:
	var bounds := layout(safe)
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), canvas.BACKGROUND_COLOR)
	canvas._draw_village_text("이 나라의 행복을 어떻게 바꿀까", Rect2(safe.position + safe.size * Vector2(0.05, 0.05), safe.size * Vector2(0.90, 0.09)), 30, canvas.ACTIVE_COLOR)
	canvas._draw_village_text("심장 제압 · 기억 %d/10 · 되감기 %d회 · 시계탑 기록 %s" % [state.memories.size(), int(state.rewinds), "확인함" if state.secret else "미확인"], Rect2(safe.position + safe.size * Vector2(0.05, 0.17), safe.size * Vector2(0.90, 0.05)), 20, canvas.MUTED_TEXT_COLOR)
	var descriptions := [["기억을 놓고 국민으로 돌아간다", "바깥에서 보낸 시간을 포기한다", "조건: 되감기 3회"], ["슬픔을 떠넘기는 의식을 부순다", "사람들은 슬픔을 다시 느낀다", "조건: 시계·가족·심장의 기억"], ["동의한 이들과 고통을 나눈다", "누구도 제물로 내몰지 않는다", "조건: 기억 10종 + 비밀 기록"]]
	for i in IDS.size():
		var id: String = IDS[i]
		var rect: Rect2 = bounds.cards[i]
		var available := can_choose(state, id)
		canvas.draw_rect(rect, Color("284c47") if selected == id else canvas.PANEL_COLOR)
		canvas.draw_rect(rect, canvas.ACTIVE_COLOR if selected == id else canvas.MUTED_TEXT_COLOR, false, 2)
		canvas._draw_village_text(String(ArrivalEnding.PROFILES[id].name), Rect2(rect.position + Vector2(14, 14), Vector2(rect.size.x - 28, 36)), 28, canvas.ACTIVE_COLOR if available else canvas.MUTED_TEXT_COLOR)
		for j in 3: canvas._draw_village_text(descriptions[i][j], Rect2(rect.position + Vector2(14, 65 + j * 42), Vector2(rect.size.x - 28, 38)), 17, canvas.TEXT_COLOR if available else canvas.MUTED_TEXT_COLOR)
		canvas._draw_village_text("선택함" if selected == id else "선택 가능" if available else "조건 미충족", Rect2(rect.position + Vector2(14, rect.size.y - 45), Vector2(rect.size.x - 28, 32)), 19, canvas.ACTIVE_COLOR if available else canvas.MUTED_TEXT_COLOR)
	canvas._draw_village_text(message if not message.is_empty() else "결말을 고른 뒤 확인하세요 · 확인 전에는 다시 선택할 수 있습니다", Rect2(safe.position + safe.size * Vector2(0.05, 0.75), safe.size * Vector2(0.90, 0.07)), 18, canvas.WAIT_COLOR if not message.is_empty() else canvas.MUTED_TEXT_COLOR)
	canvas._draw_button(bounds.secret, "시계탑 비밀 기록 확인" if can_visit_secret(state) else "비밀 기록 · 기억 10종 필요", can_visit_secret(state))
	canvas._draw_button(bounds.confirm, "선택한 결말 확인" if selected.is_empty() else String(ArrivalEnding.PROFILES[selected].name) + " 선택 확인", not selected.is_empty())
