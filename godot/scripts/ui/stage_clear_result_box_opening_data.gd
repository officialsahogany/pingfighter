extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const BOX_KIND_NORMAL := "normal"
const BOX_KIND_ADVANCED := "advanced"
const BOX_KIND_GUARANTEED_MYTHIC := "guaranteed_mythic"
const LEGACY_BOX_KIND_MYTHIC := "mythic"
const BOX_OPEN_DURATION := 0.6
const BOX_REWARD_EMERGE_DURATION := 0.45
const BOX_LID_OPEN_PROGRESS := 0.55
const FALLBACK_STARPOINT_SINGLE_CHANCE := 0.70
const FALLBACK_STARPOINT_SINGLE_AMOUNT := 1
const FALLBACK_STARPOINT_DOUBLE_AMOUNT := 2


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
	return {"type": "starpoint", "label": "★%d" % amount, "amount": amount}


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


static func is_advanced_box_kind(kind: String) -> bool:
	return kind == BOX_KIND_ADVANCED or kind == LEGACY_BOX_KIND_MYTHIC


static func is_guaranteed_mythic_box_kind(kind: String) -> bool:
	return kind == BOX_KIND_GUARANTEED_MYTHIC
