extends RefCounted

const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const StageClearResultImmediateRewardGrantData := preload("res://scripts/core/stage_clear_result_immediate_reward_grant_data.gd")
const StageClearResultRewardGrantState := preload("res://scripts/core/stage_clear_result_reward_grant_state.gd")
const StageClearResultBoxSceneHandler := preload("res://scripts/ui/stage_clear_result_box_scene_handler.gd")

var _reward_resolver: Object = StageClearRewardResolver.new()
var _grant_state: Object = StageClearResultRewardGrantState.new()


func reset() -> void:
	_grant_state.reset()


func set_reward_resolver_for_test(reward_resolver: Object) -> void:
	_reward_resolver = reward_resolver


func get_status() -> Dictionary:
	return _grant_state.get_status()


func roll_box_reward(box_kind: String, owner: Object, registry: Object) -> Dictionary:
	if _reward_resolver == null or not _reward_resolver.has_method("roll_reward"):
		return {}
	return _reward_resolver.roll_reward(box_kind, owner, registry)


func grant_pending_scene_rewards(scene: Object, owner: Object, registry: Object) -> Dictionary:
	var resolved_rewards: Array = []
	if scene != null and is_instance_valid(scene):
		resolved_rewards = StageClearResultBoxSceneHandler.get_resolved_rewards(scene)
	return grant_pending_rewards(resolved_rewards, owner, registry)


func grant_pending_rewards(resolved_rewards: Array, owner: Object, registry: Object) -> Dictionary:
	return _grant_state.grant_pending_rewards(resolved_rewards, owner, registry, _reward_resolver)


func grant_immediate_box_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	defer_starpoint_choice: bool
) -> Dictionary:
	var result: Dictionary = StageClearResultImmediateRewardGrantData.grant_immediate_box_reward(
		reward,
		owner,
		registry,
		defer_starpoint_choice,
		_reward_resolver
	)
	_grant_state.record_immediate_result(result)
	return result
