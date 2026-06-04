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


static func build_boxes_from_plan(plan: Dictionary, default_amplitude: float, default_speed: float) -> Array:
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
