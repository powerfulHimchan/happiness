class_name JourneyBossProgress
extends RefCounted

const ACHIEVEMENT := "first_dawn"
const SECRET := "ian_workshop"
const MARK_STAGES := [2,4,6]
const BOSS_IDS := ["belo","aurel","ian"]
const ARENAS := {"belo":preload("res://assets/journey_bosses/belo_arena.svg"),"aurel":preload("res://assets/journey_bosses/aurel_arena.svg"),"ian":preload("res://assets/journey_bosses/ian_arena.svg")}

static func initial(unlocked: bool) -> Dictionary:
	return {"elapsed":{"belo":0.0,"aurel":0.0,"ian":0.0},"version":1,"flow":"idle","boss":"","belo":"pending","aurel":"pending","ian":"pending","sigils":[],"unlocked":unlocked,"return":""}

static func marks_complete(marks: Array) -> bool:
	if marks.size() != MARK_STAGES.size(): return false
	for i in MARK_STAGES.size():
		if not RunCheckpointStore._number(marks[i],2,6,true) or int(marks[i]) != MARK_STAGES[i]: return false
	return true

static func can_enter(state: Dictionary) -> bool:
	return not state.is_empty() and state.unlocked and marks_complete(state.sigils) and state.ian == "pending"

static func valid(value: Variant, stage: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 10 or not RunCheckpointStore._number(value.get("version"),1,1,true): return false
	if stage.get("run_mode") != "journey" or stage.get("limit") != 10: return false
	if not value.get("elapsed") is Dictionary or value.elapsed.size() != 3: return false
	for id in BOSS_IDS:
		if not RunCheckpointStore._number(value.elapsed.get(id),0,1000000): return false
	if not value.get("unlocked") is bool or not value.get("sigils") is Array or not value.get("return") is String: return false
	if value.get("flow") not in ["idle","intro","reward","portal","victory"] or value.get("boss") not in ["","belo","aurel","ian"]: return false
	if value["return"] not in ["","arrival","ritual","complete"]: return false
	for id in BOSS_IDS:
		if value.get(id) not in (["pending","cleared","done","skipped"] if id == "ian" else ["pending","cleared","done"]): return false
	var prior := 0
	for mark in value.sigils:
		if not RunCheckpointStore._number(mark,2,6,true) or int(mark) not in MARK_STAGES or mark <= prior or mark > stage.number: return false
		prior = int(mark)
	if stage.number < 5 and value.belo != "pending": return false
	if stage.number > 5 and value.belo != "done": return false
	if stage.number < 6 and value.ian != "pending": return false
	if stage.number > 6 and value.ian not in ["done","skipped"]: return false
	if stage.number < 10 and value.aurel != "pending": return false
	if value.ian in ["cleared","done"] and (not value.unlocked or not marks_complete(value.sigils)): return false
	if value.flow == "idle": return value.boss == "" and value.belo != "cleared" and value.aurel != "cleared" and value.ian != "cleared"
	if value.boss.is_empty(): return false
	if value.boss == "aurel" and value["return"].is_empty(): return false
	if value.boss == "belo" and stage.number != 5 or value.boss == "ian" and stage.number != 6 or value.boss == "aurel" and (stage.number != 10 or stage.get("boss_choice","").is_empty()): return false
	if value.flow == "portal": return value.boss == "ian" and value.ian == "pending"
	if value.flow == "intro": return value[value.boss] == "pending" and (value.boss != "ian" or can_enter(value))
	return value[value.boss] == "cleared" and ((value.flow == "victory") == (value.boss == "aurel"))
