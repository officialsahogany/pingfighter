extends SceneTree

const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")

var _failures: Array[String] = []


class FakeRuntimePerkState:
	extends RefCounted

	var collect_calls := 0
	var last_character_type := ""
	var last_catalog: Object = null
	var last_owner: Object = null
	var last_registry: Object = null
	var opens_choice := true

	func collect_star_points(
		_amount: int,
		character_type: String,
		catalog: Object,
		owner: Object = null,
		registry: Object = null,
		_defer_choice_open: bool = false
	) -> bool:
		collect_calls += 1
		last_character_type = character_type
		last_catalog = catalog
		last_owner = owner
		last_registry = registry
		return opens_choice


class FakeOwner:
	extends RefCounted

	var redraw_calls := 0

	func queue_redraw() -> void:
		redraw_calls += 1


func _init() -> void:
	_verify_reward_collection_payload()
	_verify_registry_fallback_modes()
	_verify_missing_runtime_and_redraw()
	_verify_stage_sources_delegate_reward_policy()

	if _failures.is_empty():
		print("starpoint_collection_reward_policy_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_reward_collection_payload() -> void:
	var runtime := FakeRuntimePerkState.new()
	var catalog := RefCounted.new()
	var owner := FakeOwner.new()
	var registry := RefCounted.new()
	var opened: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward({
		"owner": owner,
		"registry": registry,
		"selected_character_type": "viper",
	}, {
		"runtime_perk_state": runtime,
		"runtime_perk_catalog": catalog,
	})
	_expect(opened, "reward policy should return whether the perk choice opened")
	_expect(runtime.collect_calls == 1, "reward policy should collect one starpoint")
	_expect(runtime.last_character_type == "viper", "reward policy should pass selected character type")
	_expect(runtime.last_catalog == catalog, "reward policy should pass runtime perk catalog")
	_expect(runtime.last_owner == owner, "reward policy should pass owner")
	_expect(runtime.last_registry == registry, "reward policy should prefer context registry")


func _verify_registry_fallback_modes() -> void:
	var runtime := FakeRuntimePerkState.new()
	var deps_registry := RefCounted.new()
	StarpointCollectionRewardPolicy.collect_starpoint_reward({}, {
		"runtime_perk_state": runtime,
		"registry": deps_registry,
	})
	_expect(runtime.last_registry == deps_registry, "reward policy should use deps registry fallback by default")

	var stage1_runtime := FakeRuntimePerkState.new()
	StarpointCollectionRewardPolicy.collect_starpoint_reward({}, {
		"runtime_perk_state": stage1_runtime,
		"registry": deps_registry,
	}, false)
	_expect(stage1_runtime.last_registry == null, "reward policy should preserve Stage 1 no-deps-registry behavior when requested")


func _verify_missing_runtime_and_redraw() -> void:
	_expect(not StarpointCollectionRewardPolicy.collect_starpoint_reward({}, {}), "reward policy should ignore missing runtime")
	var owner := FakeOwner.new()
	StarpointCollectionRewardPolicy.request_owner_redraw({"owner": owner})
	_expect(owner.redraw_calls == 1, "reward policy should request owner redraw")
	StarpointCollectionRewardPolicy.request_owner_redraw({})


func _verify_stage_sources_delegate_reward_policy() -> void:
	var paths := [
		"res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd",
		"res://scripts/stages/stage2/stage2_starpoint_coordinator.gd",
		"res://scripts/stages/stage3/stage3_starpoint_state.gd",
		"res://scripts/stages/stage4/stage4_bird_starpoint_state.gd",
	]
	for path in paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.find("StarpointCollectionRewardPolicy.collect_starpoint_reward") >= 0, "%s should delegate starpoint reward collection" % path)
		_expect(source.find("StarpointCollectionRewardPolicy.request_owner_redraw") >= 0, "%s should delegate starpoint redraw requests" % path)
		_expect(source.find("collect_star_points(") < 0, "%s should not keep private collect_star_points calls" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
