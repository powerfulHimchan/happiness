extends "res://tests/gp448_477_runtime_test.gd"

func _render_tasks() -> bool:
	controls.size = controls.get_viewport_rect().size
	controls.task_page = int(OS.get_environment("TASK_RENDER_PAGE"))
	controls.task_filter = OS.get_environment("TASK_RENDER_FILTER") if not OS.get_environment("TASK_RENDER_FILTER").is_empty() else "all"
	var view := RunTaskView.snapshot(controls)
	if OS.get_environment("TASK_RENDER_STATE") == "unavailable":
		var selected := false
		for index in view.items.size():
			var card: Dictionary = view.items[index]
			if card.get("unavailable",false):
				_tap(view.cards[index].get_center())
				selected = controls.task_selected_id == card.id
				break
		if not _check(selected,"진행 불가 과제 실제 선택·하단 상세 사유 표시"): return false
	for rect in view.cards:
		var areas := TaskBoardArt.regions(rect)
		for area in areas.values():
			if not _check(rect.encloses(area),"과제 카드 문양·텍스트·진행률·수령 도장 안전 영역"): return false
		if not _check(not areas.icon.intersects(areas.title) and not areas.title.intersects(areas.seal) and not areas.status.intersects(areas.reward),"문양·제목·도장·보상 겹침 없음"): return false
	for card in controls.task_data.cards:
		var icon := TaskBoardArt.symbol(card)
		if not _check(TaskBoardArt.ICONS.has(icon) or PrototypeWeaponRewards.FAMILY_IDS.has(icon),"30과제 모두 실제 문양에 연결"): return false
	return await super._render_tasks()
