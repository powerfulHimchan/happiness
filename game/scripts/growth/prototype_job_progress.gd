class_name PrototypeJobProgress
extends RefCounted

## GP-102: 성향의 출처별 가중치·상한과 두 기본 직업의 판정.
const WEIGHTS := {"ability": 0.70, "weapon": 0.20, "special": 0.10}
const PRIMARY_TAGS := ["strength", "shooting"]
const TAG_NAMES := {"strength": "근력", "determination": "투지", "shooting": "사격", "nature": "자연"}
const JOBS: Array[Dictionary] = [
	{"id": "vanguard", "name": "선봉대", "primary": "strength", "secondary": "determination", "weapon": "sword", "passive": "검 기본 공격·스킬 피해 +10%", "color": Color("ffd166")},
	{"id": "tracker", "name": "추적자", "primary": "shooting", "secondary": "nature", "weapon": "bow", "passive": "활 기본 공격·스킬 피해 +10%", "color": Color("65e6ae")},
]
const PRIMARY_THRESHOLD := 5.0
const SECONDARY_THRESHOLD := 3.0
const DRAGON_ID := "dragon_knight"
const BREAKER_ID := "breaker"
const STORM_ID := "storm_archer"
const WARDEN_ID := "forest_warden"
const EVOLUTION_PRIMARY := 8.0
const EVOLUTION_SECONDARY := 5.0
const EVOLUTION_STAGE := 7
const ADVANCED_JOBS: Array[Dictionary] = [
	{"id": DRAGON_ID, "parent": "vanguard", "name": "용염기사", "primary": "strength", "secondary": "determination", "weapon": "sword", "passive": "선봉대 계승 · 검 피해 추가 +15% · 최대 체력 +20", "damage_bonus": 0.15, "health_bonus": 20, "condition": "여명의 칼날 미보유 시 진화", "color": Color("ff9559")},
	{"id": BREAKER_ID, "parent": "vanguard", "name": "파쇄자", "primary": "strength", "secondary": "determination", "weapon": "sword", "passive": "선봉대 계승 · 검 피해 추가 +25%", "damage_bonus": 0.25, "health_bonus": 0, "requires": ["vanguard_dawn_edge"], "condition": "여명의 칼날 보유 시 우선 진화", "color": Color("ef839f")},
	{"id": STORM_ID, "parent": "tracker", "name": "폭풍사수", "primary": "shooting", "secondary": "nature", "weapon": "bow", "passive": "추적자 계승 · 활 피해 추가 +20% · 최대 체력 +10", "damage_bonus": 0.20, "health_bonus": 10, "condition": "숲의 명중 미보유 시 진화", "color": Color("83cfff")},
	{"id": WARDEN_ID, "parent": "tracker", "name": "숲의 파수꾼", "primary": "shooting", "secondary": "nature", "weapon": "bow", "passive": "추적자 계승 · 활 피해 추가 +10% · 최대 체력 +40", "damage_bonus": 0.10, "health_bonus": 40, "requires": ["tracker_forest_aim"], "condition": "숲의 명중 보유 시 우선 진화", "color": Color("b5e585")},
]

var job_id: String = ""
var contributions: Dictionary = {}
var recent_ability: Dictionary = {}


func reset(starting_weapon: String) -> void:
	job_id = ""
	recent_ability.clear()
	contributions = {"ability": {}, "weapon": {}, "special": {}}
	_add("weapon", _weapon_tags(starting_weapon), 1.0)


func add_ability(tags: Dictionary) -> void:
	recent_ability = tags.duplicate()
	_add("ability", tags, 1.0)


func add_weapon_hit(weapon: String) -> void:
	_add("weapon", _weapon_tags(weapon), 0.1)


func add_special(weapon: String) -> void:
	_add("special", _weapon_tags(weapon), 0.5)


func _weapon_tags(weapon: String) -> Dictionary:
	return {"strength": 1.0, "determination": 0.6} if weapon == "sword" else {"shooting": 1.0, "nature": 0.6}


func _add(source: String, tags: Dictionary, scale: float) -> void:
	for tag in tags:
		if tag not in TAG_NAMES:
			continue
		var weight := float(WEIGHTS[source])
		# 각 출처의 최대 점수도 70/20/10 비율로 제한한다. 무기·회피만으로는 발현 불가.
		var cap := (10.0 if tag in PRIMARY_TAGS else 6.0) * weight
		var bucket: Dictionary = contributions[source]
		bucket[tag] = minf(cap, float(bucket.get(tag, 0.0)) + maxf(0.0, float(tags[tag])) * scale * weight)


func score(tag: String) -> float:
	var total := 0.0
	for bucket in contributions.values():
		total += float(bucket.get(tag, 0.0))
	return total


func evaluate() -> Dictionary:
	if not job_id.is_empty():
		return current_job()
	var best: Dictionary = {}
	for job in JOBS:
		if score(job["primary"]) + 0.00001 < PRIMARY_THRESHOLD or score(job["secondary"]) + 0.00001 < SECONDARY_THRESHOLD:
			continue
		if best.is_empty() or _prefer(job, best):
			best = job
	if not best.is_empty():
		job_id = String(best["id"])
	return best.duplicate()


func _prefer(candidate: Dictionary, previous: Dictionary) -> bool:
	var candidate_score := score(candidate["primary"]) + score(candidate["secondary"])
	var previous_score := score(previous["primary"]) + score(previous["secondary"])
	if not is_equal_approx(candidate_score, previous_score):
		return candidate_score > previous_score
	var candidate_recent := float(recent_ability.get(candidate["primary"], 0.0)) + float(recent_ability.get(candidate["secondary"], 0.0))
	var previous_recent := float(recent_ability.get(previous["primary"], 0.0)) + float(recent_ability.get(previous["secondary"], 0.0))
	return candidate_recent > previous_recent


func current_job() -> Dictionary:
	return profile(job_id)


static func profile(id: String) -> Dictionary:
	for job in JOBS + ADVANCED_JOBS:
		if job["id"] == id:
			return job.duplicate()
	return {}


static func base_job(id: String) -> String:
	return String(profile(id).get("parent", id))


func can_evolve() -> bool:
	var job := current_job()
	return job_id in ["vanguard", "tracker"] and score(String(job.primary)) + 0.00001 >= EVOLUTION_PRIMARY and score(String(job.secondary)) + 0.00001 >= EVOLUTION_SECONDARY


func evolution_profile(ranks: Dictionary) -> Dictionary:
	if not can_evolve(): return {}
	if job_id == "tracker": return profile(WARDEN_ID if int(ranks.get("tracker_forest_aim", 0)) > 0 else STORM_ID)
	return profile(BREAKER_ID if int(ranks.get("vanguard_dawn_edge", 0)) > 0 else DRAGON_ID)


static func evolution_progress(id: String, run: Dictionary) -> Dictionary:
	var job := profile(id)
	if not job.has("parent"): return {}
	var model := PrototypeJobProgress.new()
	model.contributions = run.get("growth_job_contributions", {})
	var active := bool(run.get("growth_run_active", false))
	var current := String(run.get("growth_job_id", "")) if active else ""
	var ranks: Dictionary = run.get("growth_ranks", {}) if active else {}
	var required := "vanguard_dawn_edge" if job.parent == "vanguard" else "tracker_forest_aim"
	var has_required := int(ranks.get(required, 0)) > 0
	var branch_ok := has_required if job.has("requires") else not has_required
	var hint := "새 전체 여정에서 조건을 채우세요"
	if active:
		if profile(current).has("parent"):
			hint = "이번 도전에서 진화 완료" if current == id else "이번 도전은 다른 진화로 확정"
		elif run.get("run_mode", "standard") != JourneyRoutePlan.MODE:
			hint = "전체 여정에서만 진화합니다"
		elif current.is_empty():
			hint = "먼저 %s를 발현하세요" % String(profile(String(job.parent)).name)
		elif current != job.parent:
			hint = "현재 기본 직업이 다릅니다"
		elif not branch_ok:
			hint = "선행 강화를 선택하세요" if job.has("requires") else "선행 강화 보유로 다른 분기 예정"
		elif model.score(String(job.primary)) + 0.00001 < EVOLUTION_PRIMARY or model.score(String(job.secondary)) + 0.00001 < EVOLUTION_SECONDARY:
			hint = "성향 점수를 더 모으세요"
		elif int(run.get("run_stage_number", 1)) < EVOLUTION_STAGE:
			hint = "성향 충족 · 7단계 진입 대기"
		else:
			hint = "조건 충족 · 다음 전투에서 진화 판정"
	return {"stage": "전체 여정 7단계+ · " + String(profile(String(job.parent)).name) + (" · 현재%d단계" % int(run.get("run_stage_number", 1)) if active else ""), "scores": "%s %.2f/8 · %s %.2f/5" % [TAG_NAMES[job.primary], model.score(String(job.primary)) if active else 0.0, TAG_NAMES[job.secondary], model.score(String(job.secondary)) if active else 0.0], "branch": String(job.condition) + (" · 현재 보유" if has_required else " · 현재 미보유"), "hint": hint, "ready": active and current == job.parent and run.get("run_mode") == JourneyRoutePlan.MODE and branch_ok and model.score(String(job.primary)) + 0.00001 >= EVOLUTION_PRIMARY and model.score(String(job.secondary)) + 0.00001 >= EVOLUTION_SECONDARY and int(run.get("run_stage_number", 1)) >= EVOLUTION_STAGE}


func closest_job() -> Dictionary:
	if not job_id.is_empty():
		return current_job()
	var closest: Dictionary = JOBS[0]
	for job in JOBS.slice(1):
		var deficit := _deficit(job)
		var closest_deficit := _deficit(closest)
		if deficit < closest_deficit and not is_equal_approx(deficit, closest_deficit) or is_equal_approx(deficit, closest_deficit) and _prefer(job, closest):
			closest = job
	return closest.duplicate()


func _deficit(job: Dictionary) -> float:
	return maxf(0.0, PRIMARY_THRESHOLD - score(job["primary"])) / PRIMARY_THRESHOLD + maxf(0.0, SECONDARY_THRESHOLD - score(job["secondary"])) / SECONDARY_THRESHOLD


func hud_text() -> String:
	var job := closest_job()
	if not job_id.is_empty():
		if job_id == "vanguard":
			return "선봉대 · 진화7+ · 근력%.1f/투지%.1f 남음" % [_remaining(EVOLUTION_PRIMARY, score("strength")), _remaining(EVOLUTION_SECONDARY, score("determination"))]
		if job_id == "tracker":
			return "추적자 · 진화7+ · 사격%.1f/자연%.1f 남음" % [_remaining(EVOLUTION_PRIMARY, score("shooting")), _remaining(EVOLUTION_SECONDARY, score("nature"))]
		return "%s · %s" % [job["name"], "진화" if job.has("parent") else "발현"]
	return "%s · %s %.1f / %s %.1f 남음" % [job["name"], TAG_NAMES[job["primary"]], _remaining(PRIMARY_THRESHOLD, score(job["primary"])), TAG_NAMES[job["secondary"]], _remaining(SECONDARY_THRESHOLD, score(job["secondary"]))]


func _remaining(threshold: float, current: float) -> float:
	# 미충족 점수가 반올림으로 0.0처럼 보이지 않게 소수 첫째 자리 올림.
	return ceilf(maxf(0.0, threshold - current - 0.00001) * 10.0) / 10.0
