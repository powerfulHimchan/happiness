class_name CombatLinksMenuMotion
extends RefCounted

## Menu-only clock: combat stays paused while these short transitions run.
const PAGE_DURATION := 0.20
const SELECT_DURATION := 0.26
var page_elapsed := PAGE_DURATION
var selected_elapsed := SELECT_DURATION

func reset() -> void:
	page_elapsed = PAGE_DURATION
	selected_elapsed = SELECT_DURATION

func page_changed() -> void:
	page_elapsed = 0.0
	selected_elapsed = SELECT_DURATION

func selected() -> void:
	selected_elapsed = 0.0

func tick(delta: float) -> void:
	page_elapsed = minf(PAGE_DURATION,page_elapsed+maxf(0.0,delta))
	selected_elapsed = minf(SELECT_DURATION,selected_elapsed+maxf(0.0,delta))

func is_animating() -> bool:
	return page_elapsed < PAGE_DURATION or selected_elapsed < SELECT_DURATION

func pose(index: int, highlighted: bool) -> Dictionary:
	var progress := clampf((page_elapsed-float(index)*0.018)/(PAGE_DURATION-0.036),0,1)
	var eased := 1.0-pow(1.0-progress,3.0)
	var pulse := sin(clampf(selected_elapsed/SELECT_DURATION,0,1)*PI) if highlighted else 0.0
	return {"offset":Vector2(0,(1.0-eased)*7.0),"alpha":0.55+eased*.45,"pulse":maxf(0,pulse)}
