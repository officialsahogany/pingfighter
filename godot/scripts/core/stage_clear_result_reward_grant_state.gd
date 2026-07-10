extends RefCounted

var _rewards_granted: bool = false
var _last_grant_summary: Dictionary = {}
var _immediate_reward_summaries: Array = []


func reset() -> void:
	_rewards_granted = false
	_last_grant_summary = {}
	_immediate_reward_summaries.clear()


func get_status() -> Dictionary:
	return {
		"rewards_granted": _rewards_granted,
		"last_grant_summary": _last_grant_summary.duplicate(true),
		"immediate_reward_summaries": _immediate_reward_summaries.duplicate(true),
	}


func grant_pending_rewards(
	resolved_rewards: Array,
	owner: Object,
	registry: Object,
	reward_resolver: Object
) -> Dictionary:
	if _rewards_granted:
		return _last_grant_summary.duplicate(true)
	_rewards_granted = true
	var pending_rewards: Array = _build_pending_rewards(resolved_rewards)
	if pending_rewards.is_empty():
		if _last_grant_summary.is_empty():
			_last_grant_summary = empty_grant_summary(0)
		return _last_grant_summary.duplicate(true)
	if reward_resolver != null and reward_resolver.has_method("grant_rewards"):
		merge_grant_summary(reward_resolver.grant_rewards(pending_rewards, owner, registry))
	else:
		merge_grant_summary({
			"attempted": pending_rewards.size(),
			"granted": 0,
			"failed": pending_rewards.duplicate(true),
		})
	return _last_grant_summary.duplicate(true)


func record_immediate_result(result: Dictionary) -> void:
	if not bool(result.get("granted", false)):
		return
	var summary_value: Variant = result.get("summary", {})
	if not (summary_value is Dictionary):
		return
	var summary: Dictionary = (summary_value as Dictionary).duplicate(true)
	_immediate_reward_summaries.append(summary)
	merge_grant_summary(summary)


func empty_grant_summary(attempted: int) -> Dictionary:
	return {
		"attempted": attempted,
		"granted": 0,
		"active_granted": 0,
		"passive_granted": 0,
		"mythic_granted": 0,
		"mythic_perk_granted": 0,
		"mythic_perk_choice_opened": 0,
		"starpoint_granted": 0,
		"failed": [],
	}


func merge_grant_summary(summary: Dictionary) -> void:
	if _last_grant_summary.is_empty():
		_last_grant_summary = empty_grant_summary(0)
	for key in ["attempted", "granted", "active_granted", "passive_granted", "mythic_granted", "mythic_perk_granted", "mythic_perk_choice_opened", "starpoint_granted"]:
		_last_grant_summary[key] = int(_last_grant_summary.get(key, 0)) + int(summary.get(key, 0))
	var failed: Array = _get_array(_last_grant_summary.get("failed", []))
	for failed_value in _get_array(summary.get("failed", [])):
		if failed_value is Dictionary:
			failed.append((failed_value as Dictionary).duplicate(true))
		else:
			failed.append(failed_value)
	_last_grant_summary["failed"] = failed


func _build_pending_rewards(resolved_rewards: Array) -> Array:
	var pending_rewards: Array = []
	for reward_value in resolved_rewards:
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		if bool(reward.get("immediate_granted", false)):
			continue
		pending_rewards.append(reward.duplicate(true))
	return pending_rewards


func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
