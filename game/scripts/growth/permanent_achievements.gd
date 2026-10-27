class_name PermanentAchievements
extends RefCounted

## GP-548–597 and GP-718–759: permanent goals backed by durable discoveries.
const PAGE_SIZE := 3
const FAMILY_NAMES := {"sword":"검", "bow":"활", "fist":"주먹", "staff":"지팡이", "polearm":"장봉", "shield":"방패"}
static var DEFINITIONS: Array[Dictionary] = _build_definitions()

static func _entry(id: String, name: String, category: String, target: int, hint: String, source: String, key: String = "") -> Dictionary:
	return {"id":id, "name":name, "category":category, "target":target, "hint":hint, "source":source, "key":key}

static func _build_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var routes := {"meadow":"풀숲", "wind":"바람꽃", "clockwork":"태엽 폐허", "forest":"거꾸로 숲", "ruins":"별시계", "festival":"축제장"}
	for id in routes:
		result.append(_entry("route_"+id, routes[id]+" 길잡이", "탐험", 1, routes[id]+" 경로를 실제 통과해 지도에 기록", "route", id))
	for job in PrototypeJobProgress.JOBS:
		result.append(_entry("job_"+String(job.id), String(job.name)+"의 첫걸음", "기본 직업", 1, String(job.name)+" 발현 후 영구 발견 기록", "job", job.id))
	for job in PrototypeJobProgress.ADVANCED_JOBS:
		result.append(_entry("job_"+String(job.id), String(job.name)+"의 길", "상위 직업", 1, String(job.name)+" 진화 후 영구 발견 기록", "job", job.id))
	for family in FAMILY_NAMES:
		result.append(_entry("study_"+family, FAMILY_NAMES[family]+"의 탐구자", "무기 탐구", 3, FAMILY_NAMES[family]+" 계열 능력 서로 다른 3종 발견", "family", family))
	var ability_names := ["성장 관찰자", "능력 탐구자", "성장 기록가", "지혜 수집가"]
	var ability_targets := [5, 15, 30, 50]
	for index in ability_targets.size():
		var target: int = ability_targets[index]
		result.append(_entry("abilities_"+str(target), ability_names[index], "능력 수집", target, "서로 다른 능력 %d종 영구 발견" % target, "abilities"))
	var endings := {ArrivalEnding.ID:"도착의 증인", "return":"귀환의 증인", "liberation":"해방의 증인", "dawn":"새벽의 증인"}
	for id in endings:
		result.append(_entry("ending_"+id, endings[id], "엔딩", 1, "도착 엔딩을 확인하고 기록" if id == ArrivalEnding.ID else {"return":"귀환", "liberation":"해방", "dawn":"새벽"}[id]+" 엔딩을 확인하고 기록", "ending", id))
	for level in range(1, 6):
		result.append(_entry("expedition_"+str(level), "원정 %d의 개척자" % level, "원정", 1, "원정 %d 엔딩 확인 후 영구 완주 기록" % level, "expedition", str(level)))
	var fragment_targets := [1, 5, PrototypeStory.FRAGMENTS.size()]
	var fragment_names := ["기억의 첫 조각", "기억을 잇는 사람", "온전한 기억"]
	for index in fragment_targets.size():
		result.append(_entry("fragments_"+str(fragment_targets[index]), fragment_names[index], "기억", fragment_targets[index], "서로 다른 기억 조각 %d개 수집" % fragment_targets[index], "fragments"))
	result.append(_entry("memory_clockwork_guard", "멈춘 기사의 벗", "인연", 1, "태엽 기사 구출로 태엽 수호 해금", "memory", "clockwork_guard"))
	result.append(_entry("memory_core_echo", "태엽핵의 계승자", "인연", 1, "태엽 기사 파괴로 핵의 잔향 해금", "memory", "core_echo"))
	result.append(_entry("guardian_companion", "성문 수호자의 벗", "인연", 1, "성문 수호기사 구출로 동행 해금", "guardian"))
	result.append(_entry("secret_archive", "시계탑의 비밀지기", "비밀", 1, "시계탑 기록보관소의 비밀 장면 기록", "secret", FinalRitual.SECRET_SCENE))
	for index in result.size(): result[index].ticket = 548 + index
	result.append_array(AchievementResearch.definitions())
	var first_dawn := _entry("first_dawn","첫 새벽","엔딩",1,"전체 여정 10스테이지와 필수 보스를 완주하고 엔딩 기록 · 비밀 공방 도전 해금","first_dawn")
	first_dawn.ticket = 901
	result.append(first_dawn)
	return result

static func definition(id: String) -> Dictionary:
	for item in DEFINITIONS:
		if item.id == id: return item.duplicate(true)
	return {}

static func observations(legacy: Dictionary, story: Dictionary, abilities: Dictionary) -> Dictionary:
	var known: Dictionary = {}
	var families := {}
	for family in FAMILY_NAMES: families[family] = 0
	for card in PrototypeAbilityCodex.definitions():
		if abilities.get(card.id) == true:
			known[card.id] = true
			if families.has(card.category): families[card.category] += 1
	var fragments := 0
	for id in PrototypeStory.FRAGMENTS:
		if story.get("fragments", {}).get(id) == true: fragments += 1
	var result := {}
	for item in DEFINITIONS:
		var value := 0
		match item.source:
			"route": value = int(legacy.get("routes", {}).get(item.key) == true)
			"job": value = int(legacy.get("jobs", {}).get(item.key) == true)
			"family": value = int(families[item.key])
			"research":
				for id in item.required:
					if known.has(id): value += 1
			"abilities": value = known.size()
			"first_dawn": value = int(not story.get("endings",{}).is_empty())
			"ending": value = int(story.get("endings", {}).has(item.key))
			"expedition": value = int(story.get("expedition_clears", {}).values().has(int(item.key)))
			"fragments": value = fragments
			"memory": value = int(legacy.get("unlocked", {}).get(item.key) == true)
			"guardian": value = int(legacy.get("guardian_companion") == true)
			"secret": value = int(story.get("secrets", {}).get(item.key) == true)
		result[item.id] = mini(value, item.target)
	return result

static func earned(state: Dictionary, id: String) -> bool:
	var item := definition(id)
	return not item.is_empty() and int(state.get("progress", {}).get(id, 0)) >= int(item.target)

static func earned_count(state: Dictionary) -> int:
	var count := 0
	for item in DEFINITIONS:
		if int(state.get("progress", {}).get(item.id, 0)) >= int(item.target): count += 1
	return count

static func title_name(state: Dictionary) -> String:
	var item := definition(String(state.get("title", "")))
	return String(item.get("name", "칭호 없음"))

static func cards(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in DEFINITIONS:
		var progress := clampi(int(state.get("progress", {}).get(item.id, 0)), 0, item.target)
		var complete := progress == int(item.target)
		var selected: bool = state.get("title", "") == item.id and complete
		result.append({"id":item.id, "name":item.name, "category":item.category, "open":complete, "progress":progress, "target":item.target, "selected":selected, "status":"장착 중 · 다시 누르면 해제" if selected else "영구 달성 · 누르면 칭호 장착" if complete else "미달성 · " + item.category, "lines":[item.hint, "진행 %d / %d" % [progress, item.target], "보상: " + item.name + " 칭호", "칭호는 외형 표시 · 전투 수치 유지"]})
	return result
