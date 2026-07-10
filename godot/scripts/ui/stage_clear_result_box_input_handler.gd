extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultInteractionState := preload("res://scripts/ui/stage_clear_result_interaction_state.gd")

const PHASE_HIDDEN := "hidden"


static func open_next_idle_box(boxes: Array, reward_roll_callback: Callable) -> Dictionary:
	var next_idle_index: int = StageClearResultBoxData.get_next_idle_box_index(boxes)
	return open_box_at_index(boxes, next_idle_index, reward_roll_callback)


static func open_box_at_index(boxes: Array, index: int, reward_roll_callback: Callable) -> Dictionary:
	if index < 0 or index >= boxes.size():
		# 유휴 상자가 없으면 보상 롤 콜백을 호출하지 않는다. start_opening_box_with_roll 는
		# 인자 평가 단계에서 roll_reward 를 항상 부르므로, 여기서 막지 않으면 순차 오픈이 남은
		# 상자를 다 열고 난 뒤의 진행 입력이나 빗맞은 클릭이 유령 롤을 유발한다.
		return {"started": false, "boxes": boxes, "opened_index": index, "consumed": false}
	if StageClearResultBoxData.has_opening_box(boxes):
		# 스타포인트/신화퍽 게이트는 상자가 완전히 열리는 순간에야 동기 무장된다. 열리는 중인
		# 상자가 있을 때 새 오픈을 허용하면 두 그랜트가 연달아 발사되어 두 번째
		# open_mythic_perk_choice 가 첫 선택지(current_choices)를 덮어쓰거나, 지연 스타포인트
		# 슬롯의 박스 귀속이 어긋난다. 순차 오픈 경로가 이미 지키는 완료 대기를 수동
		# 클릭/키 입력에도 강제한다 (roll_reward 호출 전에 막아 유령 롤도 방지).
		return {"started": false, "boxes": boxes, "opened_index": index, "consumed": true}
	var result: Dictionary = StageClearResultBoxData.start_opening_box_with_roll(
		boxes,
		index,
		reward_roll_callback
	)
	result["opened_index"] = index
	result["consumed"] = bool(result.get("started", false))
	return result


static func get_box_click_result(
	boxes: Array,
	mouse_position: Vector2,
	scroll_phase: String,
	blocked: bool,
	draw_scale: float,
	timer: float,
	reward_roll_callback: Callable
) -> Dictionary:
	if boxes.is_empty():
		return _empty_result(boxes)
	if blocked:
		var blocked_result: Dictionary = _empty_result(boxes)
		blocked_result["consumed"] = true
		blocked_result["blocked"] = true
		return blocked_result
	if scroll_phase != PHASE_HIDDEN:
		return _empty_result(boxes)
	var clicked_index: int = StageClearResultInteractionState.get_clicked_idle_box_index(
		boxes,
		mouse_position,
		draw_scale,
		timer
	)
	return open_box_at_index(boxes, clicked_index, reward_roll_callback)


static func get_hovered_box_result(
	boxes: Array,
	mouse_position: Vector2,
	draw_scale: float,
	timer: float,
	previous_hovered_index: int
) -> Dictionary:
	if boxes.is_empty():
		return {
			"hovered_box_index": -1,
			"changed": previous_hovered_index != -1,
		}
	var hovered_index: int = StageClearResultInteractionState.get_hovered_box_index(
		boxes,
		mouse_position,
		draw_scale,
		timer
	)
	return {
		"hovered_box_index": hovered_index,
		"changed": hovered_index != previous_hovered_index,
	}


static func get_hovered_box_apply_result(
	hover_result: Dictionary,
	current_hovered_box_index: int
) -> Dictionary:
	return {
		"hovered_box_index": int(hover_result.get("hovered_box_index", current_hovered_box_index)),
		"redraw": bool(hover_result.get("changed", false)),
	}


static func get_box_open_apply_result(
	open_result: Dictionary,
	current_boxes: Array,
	current_hovered_box_index: int
) -> Dictionary:
	if not bool(open_result.get("started", false)):
		return {
			"started": false,
			"consumed": bool(open_result.get("consumed", false)),
			"boxes": current_boxes,
			"hovered_box_index": current_hovered_box_index,
			"play_open_audio": false,
			"redraw": false,
		}
	var opened_index: int = int(open_result.get("opened_index", -1))
	return {
		"started": true,
		"consumed": bool(open_result.get("consumed", true)),
		"boxes": open_result.get("boxes", current_boxes),
		"hovered_box_index": -1 if current_hovered_box_index == opened_index else current_hovered_box_index,
		"play_open_audio": true,
		"redraw": true,
	}


static func get_box_state_apply_result(
	box_state_result: Dictionary,
	current_boxes: Array,
	current_hovered_box_index: int
) -> Dictionary:
	var boxes_value: Variant = box_state_result.get("boxes", current_boxes)
	return {
		"started": bool(box_state_result.get("started", false)),
		"consumed": bool(box_state_result.get("consumed", false)),
		"boxes": boxes_value if boxes_value is Array else current_boxes,
		"hovered_box_index": int(box_state_result.get("hovered_box_index", current_hovered_box_index)),
		"play_open_audio": bool(box_state_result.get("play_open_audio", false)),
		"redraw": bool(box_state_result.get("redraw", false)),
	}


static func get_box_state_scene_apply_result(
	box_state_result: Dictionary,
	current_boxes: Array,
	current_hovered_box_index: int
) -> Dictionary:
	var apply_result: Dictionary = get_box_state_apply_result(
		box_state_result,
		current_boxes,
		current_hovered_box_index
	)
	apply_result["field_payload"] = {
		"_boxes": apply_result.get("boxes", current_boxes),
		"_hovered_box_index": int(apply_result.get("hovered_box_index", current_hovered_box_index)),
	}
	return apply_result


static func _empty_result(boxes: Array) -> Dictionary:
	return {
		"started": false,
		"consumed": false,
		"boxes": boxes,
		"opened_index": -1,
	}
