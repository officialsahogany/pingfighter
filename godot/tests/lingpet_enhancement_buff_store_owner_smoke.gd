extends SceneTree

const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const LingpetCurrentProfile := preload(
	"res://scripts/lingpet/lingpet_current_profile.gd"
)

const LABELS := {
	LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL: "액티브 스킬 +1",
	LingpetEnhancementBuffStore.REWARD_TYPE_PASSIVE_SKILL: "패시브 스킬 +1",
	LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY: "기동 강화",
	LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE: "방어 강화",
	LingpetEnhancementBuffStore.REWARD_TYPE_GAUGE: "기력 강화",
	LingpetEnhancementBuffStore.REWARD_TYPE_NO_REWARD: "보상 없음",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_stack_caps_saturate()
	_verify_replacement_and_no_reward_fallback()
	_verify_effective_skill_level_channel()
	_verify_serialization_owner()
	_verify_owner_wiring()

	if _failures.is_empty():
		print("lingpet_enhancement_buff_store_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_stack_caps_saturate() -> void:
	var pet_data := _make_pet_data()
	for _index in range(9):
		LingpetEnhancementBuffStore.apply_reward_to_pet_counts(
			pet_data,
			{"type": LingpetEnhancementBuffStore.REWARD_TYPE_MOBILITY}
		)
	for _index in range(5):
		LingpetEnhancementBuffStore.apply_reward_to_pet_counts(
			pet_data,
			{"type": LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE}
		)
	for _index in range(7):
		LingpetEnhancementBuffStore.apply_reward_to_pet_counts(
			pet_data,
			{"type": LingpetEnhancementBuffStore.REWARD_TYPE_GAUGE}
		)
	var counts := LingpetEnhancementBuffStore.reward_counts_snapshot(pet_data)
	_expect_eq(
		int(counts.get("mobility_stacks", 0)),
		6,
		"mobility stacks should saturate at the preserved cap"
	)
	_expect_eq(
		int(counts.get("defense_stacks", 0)),
		2,
		"defense stacks should saturate at the preserved cap"
	)
	_expect_eq(
		int(counts.get("gauge_stacks", 0)),
		4,
		"gauge stacks should saturate at the preserved cap"
	)
	_expect_eq(
		int(counts.get("support_stacks", 0)),
		6,
		"derived support stacks should remain defense plus gauge"
	)


func _verify_replacement_and_no_reward_fallback() -> void:
	var recoverable := _make_pet_data()
	var recoverable_counts := _fully_maxed_counts()
	recoverable_counts["active_skill_bonus"] = 0
	recoverable_counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(
		recoverable_counts
	)
	recoverable[LingpetEnhancementBuffStore.REWARD_COUNTS_KEY] = recoverable_counts
	var replacement := LingpetEnhancementBuffStore.resolve_effective_reward_card(
		recoverable,
		{"type": LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE, "label": "방어 강화"},
		LABELS
	)
	_expect_str(
		str(replacement.get("type", "")),
		LingpetEnhancementBuffStore.REWARD_TYPE_ACTIVE_SKILL,
		"an inapplicable capped stat card should recover into open skill capacity"
	)
	_expect_str(
		str(replacement.get("replaced_type", "")),
		LingpetEnhancementBuffStore.REWARD_TYPE_DEFENSE,
		"replacement should retain the rejected card type"
	)

	var maxed := _make_pet_data()
	maxed[LingpetEnhancementBuffStore.REWARD_COUNTS_KEY] = _fully_maxed_counts()
	var no_reward := LingpetEnhancementBuffStore.resolve_effective_reward_card(
		maxed,
		{"type": LingpetEnhancementBuffStore.REWARD_TYPE_GAUGE, "label": "기력 강화"},
		LABELS
	)
	_expect_str(
		str(no_reward.get("type", "")),
		LingpetEnhancementBuffStore.REWARD_TYPE_NO_REWARD,
		"a genuinely full store should resolve to NO_REWARD"
	)
	_expect(bool(no_reward.get("no_reward", false)), "NO_REWARD result should keep its terminal marker")


func _verify_effective_skill_level_channel() -> void:
	var rewards := LingpetEnhancementBuffStore.get_empty_reward_counts()
	rewards["active_skill_bonus"] = 2
	rewards["passive_skill_bonus"] = 1
	rewards["signature"] = LingpetEnhancementBuffStore.build_reward_signature(rewards)
	_expect_eq(
		LingpetEnhancementBuffStore.get_effective_skill_level(1, rewards, "active_skill_bonus"),
		3,
		"buff-store effective active level should add base and bonus"
	)
	var profile := LingpetCurrentProfile.new()
	profile.set_pet_id("maribo")
	profile.set_affinity_rewards(rewards)
	var active_base := profile.get_active_skill_level_for_slot(0)
	var active_effective := int(profile.call("_get_effective_active_skill_level", 0))
	_expect_eq(active_base, 1, "profile fixture should keep the catalog base active level")
	_expect_eq(active_effective, 3, "profile should read the divergent base-plus-bonus level from the buff store")
	_expect(active_effective != active_base, "effective level seal must diverge from base-only behavior")


func _verify_serialization_owner() -> void:
	var pet_data := _make_pet_data()
	pet_data[LingpetEnhancementBuffStore.REWARD_COUNTS_KEY] = {
		"defense_stacks": 1,
		"gauge_stacks": 2,
	}
	var serialized := LingpetEnhancementBuffStore.sanitize_pet_run_state(pet_data)
	var counts: Dictionary = serialized.get(
		LingpetEnhancementBuffStore.REWARD_COUNTS_KEY,
		{}
	) as Dictionary
	_expect_eq(int(counts.get("support_stacks", 0)), 3, "serialized counts should rebuild derived support stacks")
	_expect(
		str(counts.get("signature", "")) == LingpetEnhancementBuffStore.build_reward_signature(counts),
		"serialized counts should carry the store-owned signature"
	)


func _verify_owner_wiring() -> void:
	var affinity_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_affinity_state.gd"
	)
	var profile_source := FileAccess.get_file_as_string(
		"res://scripts/lingpet/lingpet_current_profile.gd"
	)
	_expect(
		affinity_source.find("LingpetEnhancementBuffStore.resolve_effective_reward_card(") >= 0,
		"affinity facade should delegate reward applicability and replacement"
	)
	_expect(
		affinity_source.find("func _can_apply_skill_bonus(") < 0,
		"affinity facade should not retain buff applicability internals"
	)
	_expect(
		profile_source.find("LingpetEnhancementBuffStore.get_effective_skill_level(") >= 0,
		"current profile should read effective levels from the buff store"
	)


func _make_pet_data() -> Dictionary:
	return {
		"pet_id": "maribo",
		"reward_motion_style": LingpetEnhancementBuffStore.MOTION_STYLE_PATROL,
		"active_skill_base_level": 1,
		"passive_skill_base_level": 1,
		LingpetEnhancementBuffStore.REWARD_COUNTS_KEY:
			LingpetEnhancementBuffStore.get_empty_reward_counts(),
	}


func _fully_maxed_counts() -> Dictionary:
	var counts := LingpetEnhancementBuffStore.get_empty_reward_counts()
	counts["active_unlocked"] = true
	counts["passive_unlocked"] = true
	counts["second_active_unlocked"] = true
	counts["second_passive_unlocked"] = true
	counts["active_skill_bonus"] = 4
	counts["passive_skill_bonus"] = 4
	counts["second_active_skill_bonus"] = 4
	counts["second_passive_skill_bonus"] = 4
	counts["mobility_stacks"] = 6
	counts["defense_stacks"] = 2
	counts["gauge_stacks"] = 4
	counts["support_stacks"] = 6
	counts["signature"] = LingpetEnhancementBuffStore.build_reward_signature(counts)
	return counts


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
