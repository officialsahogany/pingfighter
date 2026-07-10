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
		StageClearRewardResolver.REWARD_MYTHIC_PERK:
			return _grant_immediate_mythic_perk_box_reward(reward, owner, registry, defer_starpoint_choice, reward_resolver)
		StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE:
			return _grant_immediate_mythic_perk_choice_box_reward(reward, owner, registry, defer_starpoint_choice, reward_resolver)
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


static func _grant_immediate_mythic_perk_box_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	defer_starpoint_choice: bool,
	reward_resolver: Object
) -> Dictionary:
	if reward_resolver == null or not reward_resolver.has_method("grant_rewards"):
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_MYTHIC_PERK}
	var reward_copy: Dictionary = reward.duplicate(true)
	if defer_starpoint_choice:
		# 그랜트 시점에 스타포인트로 폴백되는 경우에만 소비되는 키. 폴백 선택 모달이
		# 결과화면의 지연 게이트 / 박스별 보상 추적을 우회해 즉시 열리는 것을 막는다.
		reward_copy["defer_choice_open"] = true
	var summary: Dictionary = _grant_single_reward(reward_copy, owner, registry, reward_resolver)
	if summary.is_empty() or int(summary.get("granted", 0)) <= 0:
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_MYTHIC_PERK}
	return {
		"granted": true,
		"reward_type": StageClearRewardResolver.REWARD_MYTHIC_PERK,
		"summary": summary.duplicate(true),
		"defer_starpoint_choice": defer_starpoint_choice and int(summary.get("starpoint_granted", 0)) > 0,
	}


static func _grant_immediate_mythic_perk_choice_box_reward(
	reward: Dictionary,
	owner: Object,
	registry: Object,
	defer_starpoint_choice: bool,
	reward_resolver: Object
) -> Dictionary:
	if reward_resolver == null or not reward_resolver.has_method("grant_rewards"):
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE}
	var reward_copy: Dictionary = reward.duplicate(true)
	if defer_starpoint_choice:
		# 위 mythic_perk 브랜치와 같은 폴백-지연 계약 (초이스 오픈 성공 경로는 이 키를
		# 읽지 않으므로 무해).
		reward_copy["defer_choice_open"] = true
	var summary: Dictionary = _grant_single_reward(reward_copy, owner, registry, reward_resolver)
	if summary.is_empty() or int(summary.get("granted", 0)) <= 0:
		return {"granted": false, "reward_type": StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE}
	var choice_opened: bool = int(summary.get("mythic_perk_choice_opened", 0)) > 0
	return {
		"granted": true,
		"reward_type": StageClearRewardResolver.REWARD_MYTHIC_PERK_CHOICE,
		"summary": summary.duplicate(true),
		"mythic_perk_choice_opened": choice_opened,
		"defer_starpoint_choice": (
			defer_starpoint_choice
			and not choice_opened
			and int(summary.get("starpoint_granted", 0)) > 0
		),
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
