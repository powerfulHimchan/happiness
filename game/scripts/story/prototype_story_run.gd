class_name PrototypeStoryRun
extends RefCounted

var enabled: bool = false
var known: Array[String] = []
var rewinds: int = 0
var seen: Array[String] = []
var pending: String = ""
# 새 도전 시작 시 확정한다. 이전 저장에는 소급 적용하지 않는다.
var arrival_seen: bool = false

func reset(active: bool, progress: Dictionary) -> void:
	enabled = active
	arrival_seen = active and progress.get("endings", {}).has(ArrivalEnding.ID)
	known.assign(progress.get("fragments", {}).keys() if active else [])
	rewinds = int(progress.get("rewind_count", 0)) if active else 0
	seen.clear()
	pending = "prologue" if active else ""

func prepare_stage(number: int) -> void:
	if enabled and "stage:%d" % number not in seen: pending = "stage:%d" % number

func acknowledge() -> void:
	if not pending.is_empty() and pending not in seen: seen.append(pending)
	pending = ""

func snapshot() -> Dictionary:
	return {"enabled": true, "arrival_seen": arrival_seen, "known": known.duplicate(), "rewinds": rewinds, "seen": seen.duplicate(), "pending": pending} if enabled else {}

func restore(state: Dictionary) -> void:
	enabled = not state.is_empty()
	arrival_seen = bool(state.get("arrival_seen", false))
	known.assign(state.get("known", []))
	rewinds = int(state.get("rewinds", 0))
	seen.assign(state.get("seen", []))
	pending = String(state.get("pending", ""))

static func valid_checkpoint(state: Variant, stage: Dictionary) -> bool:
	if not state is Dictionary or not state.get("enabled") is bool or state.enabled != true: return false
	if not PrototypeStory.valid_ids(state.get("known")) or not state.get("seen") is Array or not state.get("pending") is String: return false
	if not RunCheckpointStore._number(state.get("rewinds"), 0, 1000000, true): return false
	if state.has("arrival_seen") and not state.arrival_seen is bool: return false
	var expected: Array[String] = ["prologue"]
	for i in range(1, int(stage.number)): expected.append("stage:%d" % i)
	if state.pending.is_empty(): expected.append("stage:%d" % int(stage.number))
	elif state.pending != "stage:%d" % int(stage.number): return false
	if state.seen != expected: return false
	if int(stage.number) == 9 and stage.get("guardian_choice") in ["rescue", "destroy"] and not state.pending.is_empty(): return false
	return String(stage.get("boss_choice", "")).is_empty() or state.pending.is_empty()
