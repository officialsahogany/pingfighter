extends RefCounted

const StageClearResultImmediateRewardFlowData := preload("res://scripts/core/stage_clear_result_immediate_reward_flow_data.gd")


func grant_immediate_box_reward(
	reward: Dictionary,
	box_index: int,
	owner: Object,
	registry: Object,
	scene: Control,
	reward_grant_handler: Object,
	starpoint_choice_handler: Object,
	mythic_acquisition_handler: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	return StageClearResultImmediateRewardFlowData.grant_immediate_box_reward(
		reward,
		box_index,
		owner,
		registry,
		scene,
		reward_grant_handler,
		starpoint_choice_handler,
		mythic_acquisition_handler,
		starpoint_choice_reward_delay
	)


func grant_immediate_box_reward_from_screen(
	reward: Dictionary,
	box_index: int,
	screen: Object,
	owner: Object,
	registry: Object,
	reward_grant_handler: Object,
	starpoint_choice_handler: Object,
	mythic_acquisition_handler: Object,
	starpoint_choice_reward_delay: float
) -> bool:
	return StageClearResultImmediateRewardFlowData.grant_immediate_box_reward_from_screen(
		reward,
		box_index,
		screen,
		owner,
		registry,
		reward_grant_handler,
		starpoint_choice_handler,
		mythic_acquisition_handler,
		starpoint_choice_reward_delay
	)
