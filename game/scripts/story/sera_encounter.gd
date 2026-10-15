class_name SeraEncounter
extends RefCounted

const ID := "sera"
const LEGACY := "clockwork_knight"
const PROFILE := {
	"name": "미소의 여왕 세라",
	"intro": "왕관의 명령과 시계탑의 약속 사이에서 세라의 미소가 흔들립니다.",
	"confirm": "선택 확정 · 영구 해금",
	"prompt": "세라와 왕관의 운명을 선택하세요.",
	"cards": [
		{"title": "세라 구출", "lines": ["왕관의 명령을 풀어 줍니다", "잊었던 친구와 약속을 기억합니다", "다음 새 도전 정예마다 40피해 지원"]},
		{"title": "세라 파괴", "lines": ["세라와 왕관의 힘을 끝냅니다", "궁전의 멈춘 시계가 다시 움직입니다", "약속의 검·왕관의 활 설계도 영구 해금"]},
	],
}

static func boss_id(stage: Dictionary) -> String:
	return String(stage.get("final_boss", LEGACY))

static func valid_checkpoint(stage: Dictionary) -> bool:
	var journey: bool = stage.get("run_mode") == JourneyRoutePlan.MODE
	if stage.has("final_boss") and (not journey or not stage.final_boss is String or stage.final_boss not in [ID, LEGACY]): return false
	for entry in stage.history:
		if entry.has("final_boss") and (not journey or int(entry.stage) != 10 or entry.final_boss != boss_id(stage)): return false
	if journey and int(stage.number) == 10 and boss_id(stage) == ID and stage.history[-1].get("final_boss") != ID: return false
	return true

static func intro(character: String, guardian: String, known: Array) -> Dictionary:
	return {"id": "sera_intro", "name": "시계탑 아래의 재회", "portrait": ID, "speaker": "미소의 여왕 세라", "lines": [
		"%s가 궁전 앞 광장에 도착하자 미소의 여왕 세라가 길을 막는다. 어린 시절 가장 친했던 친구의 목소리다." % PrototypeCharacters.display_name(character),
		"세라: '시계탑에서 진짜 행복을 찾자고 약속했어요. 하지만 누구와 한 약속인지 기억나지 않아요.'",
		"지난 여행에서 보았던 같은 시계 문양이다. 이번에는 세라의 목소리에 귀를 기울인다." if "queen_pendant" in known else "세라의 장식과 새벽시계에 같은 문양이 있다. 두 시계가 가까워지자 멈춘 초침이 한 번 움직인다.",
		"성문 수호기사는 명령에서 풀려났다. 세라도 자신의 뜻으로 미소 지을 수 있을까." if guardian == "rescue" else "성문의 힘은 사라졌지만 왕관의 명령은 남아 있다. 세라는 나라의 행복을 지켜야 한다며 손을 든다.",
		"세라: '잊어버린 것이 두려워요. 그래도 이 나라를 지켜야 해요.' 왕관에서 빛이 퍼진다.",
		"시계바늘 돌진은 경고 방향으로만 움직인다. 파문은 점프하고 빛살은 틈으로 피한다. 공격 뒤 왕관의 빈틈을 노린다.",
	]}

static func victory(id: String, character: String) -> Dictionary:
	return {"id": id, "name": "돌아온 친구의 이름", "portrait": ID, "speaker": "미소의 여왕 세라", "lines": [
		"세라의 왕관이 기울자 고정된 미소가 사라진다. 새벽시계와 장식의 초침이 같은 순간에 움직인다.",
		"세라: '%s… 이제 기억나요. 시계탑에서 함께 진짜 행복을 찾자고 약속한 친구였어요.'" % PrototypeCharacters.display_name(character),
		"두 사람은 서로가 약속의 상대였음을 확인한다. 오래된 우정은 되살아났지만 왕관의 명령은 아직 남아 있다.",
		"세라를 왕관의 명령에서 구출할지, 세라와 왕관의 힘을 함께 끝낼지 결정한다. 선택은 영구 기록되며 다음 새 도전의 지원 또는 무기 설계도를 해금한다.",
	]}
