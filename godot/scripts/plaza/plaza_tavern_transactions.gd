extends RefCounted

const QUEST_CATALOG := [
	{
		"id": "supply_route",
		"name": "보급로 점검",
		"description": "다음 전투를 마친 뒤 선술집에 보고합니다.",
		"reward_gold": 180,
	},
	{
		"id": "neon_trace",
		"name": "네온 흔적 조사",
		"description": "거리의 이상 신호를 기록하고 다음 광장에서 보고합니다.",
		"reward_gold": 220,
	},
	{
		"id": "scroll_delivery",
		"name": "의뢰서 배달",
		"description": "다음 스테이지를 지나 돌아온 뒤 배달 완료를 보고합니다.",
		"reward_gold": 200,
	},
]


static func get_menu_action_labels() -> Array[String]:
	return ["의뢰 받기", "의뢰 보고"]


static func get_stage_offer(stage_id: int) -> Dictionary:
	var normalized_stage := maxi(1, stage_id)
	var template: Dictionary = QUEST_CATALOG[(normalized_stage - 1) % QUEST_CATALOG.size()]
	var result := template.duplicate(true)
	result["id"] = "%s_stage_%d" % [str(template.get("id", "quest")), normalized_stage]
	result["accepted_stage"] = normalized_stage
	return result


func perform_action(action_index: int, save_store: Object, stage_id: int, consume_ap: bool) -> Dictionary:
	if action_index == 0:
		return _accept_quest(save_store, stage_id, consume_ap)
	if action_index == 1:
		return _complete_quest(save_store, stage_id, consume_ap)
	return _build_summary("", {}, false, "unknown_tavern_action")


func _accept_quest(save_store: Object, stage_id: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_tavern_accept_quest"):
		return _build_summary("accept", {}, false, "missing_plaza_save_store")
	var offer := get_stage_offer(stage_id)
	var result: Variant = save_store.perform_tavern_accept_quest(stage_id, offer, consume_ap)
	if result is Dictionary:
		return result
	return _build_summary("accept", offer, false, "invalid_tavern_result")


func _complete_quest(save_store: Object, stage_id: int, consume_ap: bool) -> Dictionary:
	if save_store == null or not save_store.has_method("perform_tavern_complete_quest"):
		return _build_summary("complete", {}, false, "missing_plaza_save_store")
	var result: Variant = save_store.perform_tavern_complete_quest(stage_id, consume_ap)
	if result is Dictionary:
		return result
	return _build_summary("complete", {}, false, "invalid_tavern_result")


func _build_summary(action_id: String, quest: Dictionary, changed: bool, reason: String) -> Dictionary:
	return {
		"action": action_id,
		"handled": ["accept", "complete"].has(action_id),
		"changed": changed,
		"reason": reason,
		"quest": quest.duplicate(true),
		"quest_id": str(quest.get("id", "")),
		"quest_name": str(quest.get("name", "")),
		"accepted_stage": int(quest.get("accepted_stage", 0)),
		"reward_gold": int(quest.get("reward_gold", 0)),
		"delta_gold": 0,
		"ap_spent": 0,
	}
