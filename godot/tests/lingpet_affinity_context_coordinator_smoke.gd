extends SceneTree

const LingpetAffinityContextCoordinator := preload("res://scripts/lingpet/lingpet_affinity_context_coordinator.gd")
const LingpetAffinityState := preload("res://scripts/lingpet/lingpet_affinity_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

var _failures: Array[String] = []


class FakeLoadoutState:
	extends RefCounted

	var loadouts: Dictionary = {
		"maribo": {
			"active_skill_level": 5,
			"passive_skill_level": 4,
		},
		"rabi": {
			"active_skill_level": 4,
			"passive_skill_level": 2,
		},
	}

	func get_loadout(pet_id: String) -> Dictionary:
		return (loadouts.get(pet_id, {}) as Dictionary).duplicate(true)


class CaptureAffinityState:
	extends RefCounted

	var run_ring_core_cap := 5
	var level := 3
	var configured: Array[Dictionary] = []
	var forced_seed_pet_id := ""
	var forced_seed := 0
	var rewards: Dictionary = LingpetAffinityState.get_empty_reward_counts()

	func _init() -> void:
		rewards["active_skill_bonus"] = 2
		rewards["signature"] = "2|0|0|0|0|0"

	func get_run_ring_core_cap() -> int:
		return run_ring_core_cap

	func configure_reward_context(
		pet_id: String,
		motion_style: String,
		active_base_level: int,
		passive_base_level: int,
		reward_seed: int,
		force_rebuild: bool,
		ring_core_cap: int,
		active_present_id: String = "",
		passive_present_id: String = ""
	) -> void:
		configured.append({
			"pet_id": pet_id,
			"motion_style": motion_style,
			"active_base_level": active_base_level,
			"passive_base_level": passive_base_level,
			"active_present_id": active_present_id,
			"passive_present_id": passive_present_id,
			"reward_seed": reward_seed,
			"force_rebuild": force_rebuild,
			"ring_core_cap": ring_core_cap,
		})

	func set_reward_seed_for_tests(pet_id: String, reward_seed: int) -> void:
		forced_seed_pet_id = pet_id
		forced_seed = reward_seed

	func get_level(_pet_id: String) -> int:
		return level

	func get_cumulative_rewards(_pet_id: String) -> Dictionary:
		return rewards.duplicate(true)


func _init() -> void:
	_run()


func _run() -> void:
	_verify_context_composition_and_sticky_seed()
	_verify_current_profile_projection_and_reset()

	if _failures.is_empty():
		print("lingpet_affinity_context_coordinator_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_composition_and_sticky_seed() -> void:
	var coordinator := LingpetAffinityContextCoordinator.new()
	var current_profile := LingpetCurrentProfile.new()
	var loadout_state := FakeLoadoutState.new()
	var affinity_state := CaptureAffinityState.new()
	current_profile.set_pet_id("maribo")

	var changed_current := coordinator.set_reward_seed_for_tests(
		"rabi",
		777,
		"maribo",
		current_profile,
		loadout_state,
		affinity_state
	)
	_expect(not changed_current, "setting an inactive pet seed should not rewrite the current profile")
	_expect_eq(affinity_state.configured.size(), 1, "seed injection should configure the reward context before forcing the deck seed")
	var inactive_context: Dictionary = affinity_state.configured[0]
	_expect_str(str(inactive_context.get("pet_id", "")), "rabi", "context should preserve the normalized inactive pet id")
	_expect_str(str(inactive_context.get("motion_style", "")), LingpetAffinityState.MOTION_STYLE_FLIGHT, "inactive Rabi should resolve through the catalog-backed flight profile")
	_expect_eq(int(inactive_context.get("active_base_level", 0)), 4, "empty context loadout should read the stored active base level")
	_expect_eq(int(inactive_context.get("passive_base_level", 0)), 2, "empty context loadout should read the stored passive base level")
	_expect_eq(int(inactive_context.get("reward_seed", 0)), 777, "context should use the injected run-local reward seed")
	_expect_eq(int(inactive_context.get("ring_core_cap", 0)), 5, "context should apply the this-run ring-core cap")
	_expect(not bool(inactive_context.get("force_rebuild", true)), "ordinary context configuration should not force a deck rebuild")
	_expect_str(affinity_state.forced_seed_pet_id, "rabi", "seed injection should force the requested pet deck")
	_expect_eq(affinity_state.forced_seed, 777, "seed injection should preserve the caller seed for affinity_state normalization")

	var explicit_context := coordinator.configure(
		"rabi",
		"maribo",
		current_profile,
		loadout_state,
		affinity_state,
		{
			"active_skill_id": "rabi_ghost_summon",
			"active_skill_level": 3,
			"passive_skill_id": "lingpet_resonance_boost",
			"passive_skill_level": 1,
		}
	)
	_expect_eq(int(explicit_context.get("active_base_level", 0)), 3, "explicit loadout should override the stored active base level")
	_expect_eq(int(explicit_context.get("passive_base_level", 0)), 1, "explicit loadout should override the stored passive base level")
	_expect_str(str(explicit_context.get("active_present_id", "")), "rabi_ghost_summon", "explicit loadout should pass the present active id for conditional unlocks")
	_expect_str(str(explicit_context.get("passive_present_id", "")), "lingpet_resonance_boost", "explicit loadout should pass the present passive id for conditional unlocks")
	_expect_eq(int(explicit_context.get("reward_seed", 0)), 777, "repeated configuration should retain the pet's sticky run-local seed")

	affinity_state.run_ring_core_cap = 99
	var clamped_context := coordinator.configure("rabi", "maribo", current_profile, loadout_state, affinity_state)
	_expect_eq(int(clamped_context.get("ring_core_cap", 0)), LingpetAffinityState.MAX_LEVEL, "context should clamp fail-open ring-core caps to affinity max level")


func _verify_current_profile_projection_and_reset() -> void:
	var coordinator := LingpetAffinityContextCoordinator.new()
	var current_profile := LingpetCurrentProfile.new()
	var loadout_state := FakeLoadoutState.new()
	var affinity_state := CaptureAffinityState.new()
	current_profile.set_pet_id("maribo")

	var changed_current := coordinator.set_reward_seed_for_tests(
		"maribo",
		991,
		"maribo",
		current_profile,
		loadout_state,
		affinity_state
	)
	_expect(changed_current, "setting the active pet seed should report a current-profile projection")
	_expect_eq(current_profile.affinity_level, 3, "current-profile projection should copy the affinity level")
	_expect_str(current_profile.affinity_reward_signature, "2|0|0|0|0|0", "current-profile projection should copy cumulative reward state")
	var current_context: Dictionary = affinity_state.configured[affinity_state.configured.size() - 1]
	_expect_str(str(current_context.get("motion_style", "")), LingpetAffinityState.MOTION_STYLE_PATROL, "active Maribo should use the current profile's patrol affinity style")

	_expect_eq(coordinator.get_reward_seed_for_tests("maribo", current_profile), 991, "coordinator should expose the sticky seed to focused tests")
	coordinator.reset_for_new_run()
	_expect_eq(coordinator.get_reward_seed_for_tests("maribo", current_profile), 0, "new-run reset should clear all run-local reward seeds")
	var rebuilt_context := coordinator.configure("maribo", "maribo", current_profile, loadout_state, affinity_state)
	_expect(int(rebuilt_context.get("reward_seed", 0)) > 0, "first configure after reset should generate a fresh nonzero seed")




func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %d, got %d)" % [message, expected, actual])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
