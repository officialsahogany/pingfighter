extends RefCounted

const StageClearResultBoxImmediateRewardData := preload("res://scripts/ui/stage_clear_result_box_immediate_reward_data.gd")
const StageClearResultBoxOpeningData := preload("res://scripts/ui/stage_clear_result_box_opening_data.gd")
const StageClearResultBoxPlanData := preload("res://scripts/ui/stage_clear_result_box_plan_data.gd")
const StageClearResultBoxResolvedRewardData := preload("res://scripts/ui/stage_clear_result_box_resolved_reward_data.gd")

const BOX_KIND_NORMAL := "normal"
const BOX_KIND_GUARANTEED_MYTHIC := "guaranteed_mythic"
const BOX_LABEL_NORMAL := "일반 상자"
const BOX_LABEL_GUARANTEED_MYTHIC := "신화 확정 상자"
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
	return StageClearResultBoxPlanData.build_standalone_preview_defaults(reward_count)


static func build_boxes_from_plan(
	plan: Dictionary,
	default_amplitude: float = BOX_FLOAT_AMPLITUDE,
	default_speed: float = BOX_FLOAT_SPEED
) -> Array:
	return StageClearResultBoxPlanData.build_boxes_from_plan(
		plan,
		default_amplitude,
		default_speed
	)


static func normalize_box_kind(kind: String) -> String:
	return StageClearResultBoxPlanData.normalize_box_kind(kind)


static func is_advanced_box_kind(kind: String) -> bool:
	return StageClearResultBoxPlanData.is_advanced_box_kind(kind)


static func is_guaranteed_mythic_box_kind(kind: String) -> bool:
	return StageClearResultBoxPlanData.is_guaranteed_mythic_box_kind(kind)


static func is_mythic_visual_box_kind(kind: String) -> bool:
	return StageClearResultBoxPlanData.is_mythic_visual_box_kind(kind)


static func get_box_display_label(kind: String) -> String:
	return StageClearResultBoxPlanData.get_box_display_label(kind)


static func get_box_display_labels(boxes: Array) -> Array:
	return StageClearResultBoxPlanData.get_box_display_labels(boxes)


static func roll_reward(
	kind: String,
	reward_roll_callback: Callable,
	fallback_starpoint_single_chance: float,
	fallback_starpoint_single_amount: int,
	fallback_starpoint_double_amount: int
) -> Dictionary:
	return StageClearResultBoxOpeningData.roll_reward(
		kind,
		reward_roll_callback,
		fallback_starpoint_single_chance,
		fallback_starpoint_single_amount,
		fallback_starpoint_double_amount
	)


static func start_opening_box(boxes: Array, index: int, reward: Dictionary) -> Dictionary:
	return StageClearResultBoxOpeningData.start_opening_box(boxes, index, reward)


static func start_opening_box_with_roll(
	boxes: Array,
	index: int,
	reward_roll_callback: Callable,
	fallback_starpoint_single_chance: float = FALLBACK_STARPOINT_SINGLE_CHANCE,
	fallback_starpoint_single_amount: int = FALLBACK_STARPOINT_SINGLE_AMOUNT,
	fallback_starpoint_double_amount: int = FALLBACK_STARPOINT_DOUBLE_AMOUNT
) -> Dictionary:
	return StageClearResultBoxOpeningData.start_opening_box_with_roll(
		boxes,
		index,
		reward_roll_callback,
		fallback_starpoint_single_chance,
		fallback_starpoint_single_amount,
		fallback_starpoint_double_amount
	)


static func get_next_idle_box_index(boxes: Array) -> int:
	return StageClearResultBoxOpeningData.get_next_idle_box_index(boxes)


static func has_opening_box(boxes: Array) -> bool:
	return StageClearResultBoxOpeningData.has_opening_box(boxes)


static func update_box_opening_state(
	boxes: Array,
	delta: float,
	lid_open_counter: int,
	box_open_duration: float = BOX_OPEN_DURATION,
	box_reward_emerge_duration: float = BOX_REWARD_EMERGE_DURATION,
	box_lid_open_progress: float = BOX_LID_OPEN_PROGRESS
) -> Dictionary:
	return StageClearResultBoxOpeningData.update_box_opening_state(
		boxes,
		delta,
		lid_open_counter,
		box_open_duration,
		box_reward_emerge_duration,
		box_lid_open_progress
	)


static func append_resolved_perk_reward(boxes: Array, index: int, perk_reward: Dictionary) -> Dictionary:
	return StageClearResultBoxResolvedRewardData.append_resolved_perk_reward(
		boxes,
		index,
		perk_reward
	)


static func get_append_resolved_perk_reward_apply_result(
	append_result: Dictionary,
	current_boxes: Array
) -> Dictionary:
	return StageClearResultBoxResolvedRewardData.get_append_resolved_perk_reward_apply_result(
		append_result,
		current_boxes
	)


static func get_append_resolved_perk_reward_scene_apply_result(
	append_result: Dictionary,
	current_boxes: Array
) -> Dictionary:
	return StageClearResultBoxResolvedRewardData.get_append_resolved_perk_reward_scene_apply_result(
		append_result,
		current_boxes
	)


static func build_immediate_reward_payload(box: Dictionary, cinematic_positions: Dictionary) -> Dictionary:
	return StageClearResultBoxImmediateRewardData.build_immediate_reward_payload(
		box,
		cinematic_positions
	)


static func mark_immediate_reward_granted(boxes: Array, index: int) -> Array:
	return StageClearResultBoxImmediateRewardData.mark_immediate_reward_granted(
		boxes,
		index
	)


static func try_grant_immediate_reward(
	boxes: Array,
	index: int,
	immediate_reward_callback: Callable,
	cinematic_positions: Dictionary
) -> Dictionary:
	return StageClearResultBoxImmediateRewardData.try_grant_immediate_reward(
		boxes,
		index,
		immediate_reward_callback,
		cinematic_positions
	)


static func get_resolved_rewards(boxes: Array) -> Array:
	return StageClearResultBoxResolvedRewardData.get_resolved_rewards(boxes)
