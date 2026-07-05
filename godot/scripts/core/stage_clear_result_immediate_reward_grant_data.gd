extends RefCounted

const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")


static func grant_immediate_box_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	defer_starpoint_choice: bool,
	reward_resolver: Object
) -> Dictionary:
	var reward_type: String = str(reward.get("type", ""))
	match reward_type:
		StageClearRewardResolver.REWARD_MYTHIC:
			return _grant_immediate_mythic_box_reward(reward, owner, registry, reward_resolver)
		StageClearRewardResolver.REWARD_STARPOINT:
			return _grant_immediate_starpoint_box_reward(
				reward,
				owner,
				registry,
				defer_starpoint_choice,
				reward_resolver
			)
		_:
			return {"granted": false, "reward_type": reward_type}


static func _grant_immediate_starpoint_box_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	defer_starpoint_choice: bool,
	reward_resolver: Object
) -> Dictionary:
	if reward_resolver == null or not reward_resolver.has_method("grant_rewards"):
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_STARPOINT}
	var reward_copy: Dictionary = reward.duplicate(true)
	if defer_starpoint_choice:
		reward_copy["defer_choice_open"] = true
	var summary: Dictionary = _grant_single_reward(reward_copy, owner, registry, reward_resolver)
	if summary.is_empty() or int(summary.get("granted", 0)) <= 0:
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_STARPOINT}
	return {
		"granted": true,
		"reward_type": StageClearRewardResolver.REWARD_STARPOINT,
		"summary": summary.duplicate(true),
		"defer_starpoint_choice": defer_starpoint_choice,
	}


static func _grant_immediate_mythic_box_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	reward_resolver: Object
) -> Dictionary:
	if reward_resolver == null or not reward_resolver.has_method("grant_rewards"):
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_MYTHIC}
	var reward_copy: Dictionary = reward.duplicate(true)
	reward_copy["show_acquisition_cinematic"] = true
	var summary: Dictionary = _grant_single_reward(reward_copy, owner, registry, reward_resolver)
	if summary.is_empty() or int(summary.get("granted", 0)) <= 0:
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_MYTHIC}
	return {
		"granted": true,
		"reward_type": StageClearRewardResolver.REWARD_MYTHIC,
		"summary": summary.duplicate(true),
		"raise_mythic_acquisition_cinematic": true,
	}


static func _grant_single_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	reward_resolver: Object
) -> Dictionary:
	var summary_value: Variant = reward_resolver.grant_rewards([reward], owner, registry)
	if summary_value is Dictionary:
		return (summary_value as Dictionary).duplicate(true)
	return {}
