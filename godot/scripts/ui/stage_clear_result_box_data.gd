extends RefCounted

const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BOX_KIND_NORMAL := "normal"
const BOX_KIND_ADVANCED := "advanced"
const BOX_KIND_GUARANTEED_MYTHIC := "guaranteed_mythic"
const LEGACY_BOX_KIND_MYTHIC := "mythic"
const BOX_LABEL_NORMAL := "일반상자"
const BOX_LABEL_ADVANCED := "고급상자"
const BOX_LABEL_GUARANTEED_MYTHIC := "신화 확정상자"
const BOX_BASE_SIZE := Vector2(65.0, 56.0)
const BOX_FLOAT_AMPLITUDE := 5.0
const BOX_FLOAT_SPEED := 1.4
const BOX_HOVER_GROW := 1.06
const BOX_SHADOW_OFFSET_Y := 9.0
const BOX_OPEN_DURATION := 0.6
const BOX_REWARD_EMERGE_DURATION := 0.45
const BOX_REWARD_HOVER_OFFSET := 70.0
const BOX_OPENING_SHAKE_AMPLITUDE := 4.0
const BOX_LID_OPEN_PROGRESS := 0.55
const FALLBACK_STARPOINT_SINGLE_CHANCE := 0.70
const FALLBACK_STARPOINT_SINGLE_AMOUNT := 1
const FALLBACK_STARPOINT_DOUBLE_AMOUNT := 2


static func build_standalone_preview_defaults(reward_count: int) -> Dictionary:
	var safe_count: int = max(0, reward_count)
	var boxes: Array = []
	for _i in range(safe_count):
		boxes.append({"kind": BOX_KIND_NORMAL})
	return {
		"player_score": safe_count,
		"boss_score": 0,
		"current_stage": 1,
		"reward_plan": {
			"summary": LanguageSettings.format_item_box_summary(safe_count),
			"boxes": boxes,
			"reward_count": safe_count,
		},
	}


static func build_boxes_from_plan(
	plan: Dictionary,
	default_amplitude: float = BOX_FLOAT_AMPLITUDE,
	default_speed: float = BOX_FLOAT_SPEED
) -> Array:
	var box_list: Array = []
	var boxes_value: Variant = plan.get("boxes", [])
	var source_boxes: Array = boxes_value if boxes_value is Array else []
	if source_boxes.is_empty():
		return box_list
	var layout: Array = StageClearResultLayoutHelper.get_box_layout(source_boxes.size())
	if layout.is_empty():
		return box_list
	var count: int = min(source_boxes.size(), layout.size())
	for i in range(count):
		var source_box: Dictionary = source_boxes[i] if source_boxes[i] is Dictionary else {}
		var slot: Dictionary = layout[i]
		var original_kind: String = str(source_box.get("kind", BOX_KIND_NORMAL))
		var kind: String = normalize_box_kind(original_kind)
		box_list.append({
			"kind": kind,
			"roll_kind": original_kind,
			"label": str(source_box.get("label", get_box_display_label(kind))),
			"base_pos": Vector2(slot.get("pos", Vector2.ZERO)),
			"rotation_base": float(slot.get("rot", 0.0)),
			"rotation_jitter": float(slot.get("jitter", 0.05)),
			"phase": float(slot.get("phase", 0.0)),
			"amplitude": float(slot.get("amp", default_amplitude)),
			"speed": float(slot.get("speed", default_speed)),
			"state": "idle",
			"open_progress": 0.0,
			"reward": {},
			"reward_emerge": 0.0,
		})
	return box_list


static func normalize_box_kind(kind: String) -> String:
	if kind == BOX_KIND_GUARANTEED_MYTHIC:
		return BOX_KIND_GUARANTEED_MYTHIC
	if kind == LEGACY_BOX_KIND_MYTHIC:
		return BOX_KIND_ADVANCED
	if kind == BOX_KIND_ADVANCED:
		return BOX_KIND_ADVANCED
	return BOX_KIND_NORMAL


static func is_advanced_box_kind(kind: String) -> bool:
	return kind == BOX_KIND_ADVANCED or kind == LEGACY_BOX_KIND_MYTHIC


static func is_guaranteed_mythic_box_kind(kind: String) -> bool:
	return kind == BOX_KIND_GUARANTEED_MYTHIC


static func is_mythic_visual_box_kind(kind: String) -> bool:
	return is_advanced_box_kind(kind) or is_guaranteed_mythic_box_kind(kind)


static func get_box_display_label(kind: String) -> String:
	if is_guaranteed_mythic_box_kind(kind):
		return LanguageSettings.translate_text(BOX_LABEL_GUARANTEED_MYTHIC)
	return LanguageSettings.translate_text(BOX_LABEL_ADVANCED if is_advanced_box_kind(kind) else BOX_LABEL_NORMAL)


static func get_box_display_labels(boxes: Array) -> Array:
	var labels: Array = []
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		labels.append(str(box.get("label", get_box_display_label(str(box.get("kind", BOX_KIND_NORMAL))))))
	return labels


static func roll_reward(
	kind: String,
	reward_roll_callback: Callable,
	fallback_starpoint_single_chance: float,
	fallback_starpoint_single_amount: int,
	fallback_starpoint_double_amount: int
) -> Dictionary:
	if reward_roll_callback.is_valid():
		var rolled_value: Variant = reward_roll_callback.call(kind)
		if rolled_value is Dictionary:
			var rolled: Dictionary = rolled_value
			if not rolled.is_empty():
				return rolled
	if is_guaranteed_mythic_box_kind(kind) or is_advanced_box_kind(kind):
		return {"type": "mythic", "label": LanguageSettings.translate_text("신화 아이템")}
	var roll: float = randf()
	if roll < 0.60:
		return {"type": "active", "label": LanguageSettings.translate_text("액티브 아이템")}
	if roll < 0.80:
		return {"type": "passive", "label": LanguageSettings.translate_text("패시브 아이템")}
	var amount: int = (
		fallback_starpoint_single_amount
		if randf() < fallback_starpoint_single_chance
		else fallback_starpoint_double_amount
	)
	return {"type": "starpoint", "label": "★ %d" % amount, "amount": amount}


static func start_opening_box(boxes: Array, index: int, reward: Dictionary) -> Dictionary:
	if index < 0 or index >= boxes.size():
		return {"started": false, "boxes": boxes}
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	if str(box.get("state", "idle")) != "idle":
		return {"started": false, "boxes": boxes}
	var updated_boxes: Array = boxes.duplicate(false)
	var updated_box: Dictionary = box.duplicate(true)
	updated_box["state"] = "opening"
	updated_box["open_progress"] = 0.0
	updated_box["reward_emerge"] = 0.0
	updated_box["reward"] = reward.duplicate(true)
	updated_box["lid_open_fired"] = false
	updated_box["lid_open_id"] = -1
	updated_boxes[index] = updated_box
	return {"started": true, "boxes": updated_boxes}


static func start_opening_box_with_roll(
	boxes: Array,
	index: int,
	reward_roll_callback: Callable,
	fallback_starpoint_single_chance: float = FALLBACK_STARPOINT_SINGLE_CHANCE,
	fallback_starpoint_single_amount: int = FALLBACK_STARPOINT_SINGLE_AMOUNT,
	fallback_starpoint_double_amount: int = FALLBACK_STARPOINT_DOUBLE_AMOUNT
) -> Dictionary:
	var box: Dictionary = boxes[index] if index >= 0 and index < boxes.size() and boxes[index] is Dictionary else {}
	var roll_kind: String = str(box.get("roll_kind", box.get("kind", BOX_KIND_NORMAL)))
	return start_opening_box(
		boxes,
		index,
		roll_reward(
			roll_kind,
			reward_roll_callback,
			fallback_starpoint_single_chance,
			fallback_starpoint_single_amount,
			fallback_starpoint_double_amount
		)
	)


static func get_next_idle_box_index(boxes: Array) -> int:
	for i in range(boxes.size()):
		var box: Dictionary = boxes[i] if boxes[i] is Dictionary else {}
		if str(box.get("state", "idle")) == "idle":
			return i
	return -1


static func update_box_opening_state(
	boxes: Array,
	delta: float,
	lid_open_counter: int,
	box_open_duration: float = BOX_OPEN_DURATION,
	box_reward_emerge_duration: float = BOX_REWARD_EMERGE_DURATION,
	box_lid_open_progress: float = BOX_LID_OPEN_PROGRESS
) -> Dictionary:
	if boxes.is_empty() or delta <= 0.0:
		return {
			"boxes": boxes,
			"lid_open_counter": lid_open_counter,
			"opened_indices": [],
		}
	var updated_boxes: Array = boxes.duplicate(false)
	var opened_indices: Array[int] = []
	var next_lid_open_counter: int = lid_open_counter
	for i in range(updated_boxes.size()):
		var box: Dictionary = updated_boxes[i] if updated_boxes[i] is Dictionary else {}
		var state: String = str(box.get("state", "idle"))
		if state == "opening":
			var updated_box: Dictionary = box.duplicate(true)
			var dur: float = max(0.0001, box_open_duration)
			var p: float = float(updated_box.get("open_progress", 0.0)) + delta / dur
			if p >= 1.0:
				p = 1.0
				updated_box["state"] = "opened"
				updated_box["reward_emerge"] = 0.0
				opened_indices.append(i)
			updated_box["open_progress"] = p
			if not bool(updated_box.get("lid_open_fired", false)) and p >= box_lid_open_progress:
				next_lid_open_counter += 1
				updated_box["lid_open_fired"] = true
				updated_box["lid_open_id"] = next_lid_open_counter
			updated_boxes[i] = updated_box
		elif state == "opened":
			var updated_opened_box: Dictionary = box.duplicate(true)
			var emerge_dur: float = max(0.0001, box_reward_emerge_duration)
			var ep: float = float(updated_opened_box.get("reward_emerge", 0.0)) + delta / emerge_dur
			updated_opened_box["reward_emerge"] = clamp(ep, 0.0, 1.0)
			updated_boxes[i] = updated_opened_box
	return {
		"boxes": updated_boxes,
		"lid_open_counter": next_lid_open_counter,
		"opened_indices": opened_indices,
	}


static func append_resolved_perk_reward(boxes: Array, index: int, perk_reward: Dictionary) -> Dictionary:
	if index < 0 or index >= boxes.size() or perk_reward.is_empty():
		return {"updated": false, "boxes": boxes}
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	var reward_value: Variant = box.get("reward", {})
	if not (reward_value is Dictionary):
		return {"updated": false, "boxes": boxes}
	var reward: Dictionary = reward_value
	if reward.is_empty() or str(reward.get("type", "")) != "starpoint":
		return {"updated": false, "boxes": boxes}
	var updated_boxes: Array = boxes.duplicate(false)
	var updated_box: Dictionary = box.duplicate(true)
	var updated_reward: Dictionary = updated_box.get("reward", {}) if updated_box.get("reward", {}) is Dictionary else {}
	var resolved_value: Variant = updated_reward.get("resolved_perk_rewards", [])
	var resolved: Array = resolved_value.duplicate(false) if resolved_value is Array else []
	var reward_copy: Dictionary = perk_reward.duplicate(true)
	reward_copy["source"] = "box_starpoint_choice"
	resolved.append(reward_copy)
	updated_reward["resolved_perk_rewards"] = resolved
	updated_reward["resolved_perk_count"] = resolved.size()
	updated_box["reward"] = updated_reward
	updated_boxes[index] = updated_box
	return {"updated": true, "boxes": updated_boxes}


static func build_immediate_reward_payload(box: Dictionary, cinematic_positions: Dictionary) -> Dictionary:
	var reward_value: Variant = box.get("reward", {})
	if not (reward_value is Dictionary):
		return {}
	var reward: Dictionary = (reward_value as Dictionary).duplicate(true)
	if reward.is_empty():
		return {}
	reward["box_kind"] = str(box.get("kind", BOX_KIND_NORMAL))
	reward["box_state"] = str(box.get("state", "opened"))
	reward["pickup_position"] = cinematic_positions.get("pickup_position", Vector2.ZERO)
	reward["target_player_center"] = cinematic_positions.get("target_player_center", Vector2.ZERO)
	return reward


static func mark_immediate_reward_granted(boxes: Array, index: int) -> Array:
	if index < 0 or index >= boxes.size():
		return boxes
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	var updated_boxes: Array = boxes.duplicate(false)
	var updated_box: Dictionary = box.duplicate(true)
	updated_box["reward_immediate_granted"] = true
	var reward_value: Variant = updated_box.get("reward", {})
	if reward_value is Dictionary:
		var stored_reward: Dictionary = (reward_value as Dictionary).duplicate(true)
		stored_reward["immediate_granted"] = true
		updated_box["reward"] = stored_reward
	updated_boxes[index] = updated_box
	return updated_boxes


static func try_grant_immediate_reward(
	boxes: Array,
	index: int,
	immediate_reward_callback: Callable,
	cinematic_positions: Dictionary
) -> Dictionary:
	if index < 0 or index >= boxes.size():
		return {"granted": false, "boxes": boxes, "reward": {}}
	var box: Dictionary = boxes[index] if boxes[index] is Dictionary else {}
	if bool(box.get("reward_immediate_granted", false)):
		return {"granted": false, "boxes": boxes, "reward": {}}
	if not immediate_reward_callback.is_valid():
		return {"granted": false, "boxes": boxes, "reward": {}}
	var reward: Dictionary = build_immediate_reward_payload(box, cinematic_positions)
	if reward.is_empty():
		return {"granted": false, "boxes": boxes, "reward": {}}
	if not bool(immediate_reward_callback.call(reward, index)):
		return {"granted": false, "boxes": boxes, "reward": reward}
	return {
		"granted": true,
		"boxes": mark_immediate_reward_granted(boxes, index),
		"reward": reward,
	}


static func get_resolved_rewards(boxes: Array) -> Array:
	var rewards: Array = []
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var reward_value: Variant = box.get("reward", {})
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		if reward.is_empty():
			continue
		var reward_copy: Dictionary = reward.duplicate(true)
		reward_copy["box_kind"] = str(box.get("kind", BOX_KIND_NORMAL))
		reward_copy["box_state"] = str(box.get("state", "idle"))
		rewards.append(reward_copy)
	return rewards
