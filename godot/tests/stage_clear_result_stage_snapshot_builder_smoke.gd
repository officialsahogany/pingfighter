extends SceneTree

const StageClearResultStageSnapshotBuilder := preload("res://scripts/core/stage_clear_result_stage_snapshot_builder.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var passive_item_inventory: Array = []
	var runtime_perk_levels: Dictionary = {}


class FakeRuntimePerkState:
	extends RefCounted

	var levels: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return {"runtime_skill_levels": levels.duplicate(true)}


class FakeMythicRuntime:
	extends RefCounted

	var inventory_items: Array = []

	func get_snapshot() -> Dictionary:
		return {"inventory_items": inventory_items.duplicate(true)}


class FakeRegistry:
	extends RefCounted

	var runtime_perk_state: Object
	var mythic_item_runtime: Object

	func _init(new_runtime_perk_state: Object = null, new_mythic_item_runtime: Object = null) -> void:
		runtime_perk_state = new_runtime_perk_state
		mythic_item_runtime = new_mythic_item_runtime

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_progress_snapshot_uses_runtime_owners()
	_verify_stage_reward_snapshot_diffs_stage_gains()
	_verify_stage_mismatch_baseline_does_not_hide_inventory()
	_verify_screen_delegates_snapshot_builder()

	if _failures.is_empty():
		print("stage_clear_result_stage_snapshot_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_progress_snapshot_uses_runtime_owners() -> void:
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "banana", "display_name": "Banana"}]
	owner.passive_item_inventory = [{"name": "owner_passive", "_inventory_id": 1}]
	owner.runtime_perk_levels = {"owner_perk": 1}

	var runtime_perk_state := FakeRuntimePerkState.new()
	runtime_perk_state.levels = {"runtime_perk": 3}
	var mythic_runtime := FakeMythicRuntime.new()
	mythic_runtime.inventory_items = [{"name": "runtime_passive", "_inventory_id": 2}]

	var builder := StageClearResultStageSnapshotBuilder.new()
	var snapshot: Dictionary = builder.build_progress_snapshot(
		owner,
		FakeRegistry.new(runtime_perk_state, mythic_runtime),
		2
	)
	_expect(int(snapshot.get("stage", 0)) == 2, "progress snapshot should preserve the stage id")
	_expect((snapshot.get("active_item_slots", []) as Array).size() == 1, "progress snapshot should include active item slots")
	_expect(str(((snapshot.get("passive_item_inventory", []) as Array)[0] as Dictionary).get("name", "")) == "runtime_passive", "progress snapshot should prefer mythic runtime inventory when present")
	_expect(int((snapshot.get("runtime_perk_levels", {}) as Dictionary).get("runtime_perk", 0)) == 3, "progress snapshot should prefer runtime perk state levels when present")

	var copied_slots: Array = snapshot.get("active_item_slots", [])
	copied_slots.append({"name": "mutated"})
	_expect(owner.active_item_slots.size() == 1, "progress snapshot should duplicate owner active slot arrays")


func _verify_stage_reward_snapshot_diffs_stage_gains() -> void:
	var owner := FakeOwner.new()
	owner.active_item_slots = [{"name": "banana", "display_name": "Banana"}]
	owner.passive_item_inventory = [
		{"name": "speedboots", "display_name": "Speed Boots", "_inventory_id": 1},
		{"name": "old_charm", "display_name": "Old Charm"},
		{"name": "megingjord", "display_name": "Megingjord", "type": "mythic", "rarity": "mythic", "_inventory_id": 2},
		{"name": "new_passive", "display_name": "New Passive", "_inventory_id": 3},
	]
	owner.runtime_perk_levels = {
		"dash": 1,
		"new_perk": 2,
	}
	var baseline := {
		"stage": 2,
		"active_item_slots": [],
		"passive_item_inventory": [
			{"name": "speedboots", "display_name": "Speed Boots", "_inventory_id": 1},
			{"name": "old_charm", "display_name": "Old Charm"},
		],
		"runtime_perk_levels": {"dash": 1},
	}

	var builder := StageClearResultStageSnapshotBuilder.new()
	var snapshot: Dictionary = builder.build_stage_reward_snapshot(owner, FakeRegistry.new(), 2, baseline)
	var active_items: Array = snapshot.get("active_items", [])
	var passive_items: Array = snapshot.get("passive_items", [])
	var perks: Array = snapshot.get("perks", [])
	_expect(active_items.size() == 1, "stage reward snapshot should include remaining active items")
	_expect(str((active_items[0] as Dictionary).get("source", "")) == "remaining_active", "remaining active item rewards should keep their source tag")
	_expect(passive_items.size() == 2, "stage reward snapshot should include only newly acquired passive/mythic items")
	_expect(_count_reward_type(passive_items, "mythic") == 1, "stage reward snapshot should classify newly acquired mythics")
	_expect(_count_reward_type(passive_items, "passive") == 1, "stage reward snapshot should classify newly acquired passives")
	_expect(perks.size() == 1, "stage reward snapshot should include only level gains")
	_expect(str((perks[0] as Dictionary).get("perk_id", "")) == "new_perk", "stage reward snapshot should preserve gained perk id")
	_expect(int((perks[0] as Dictionary).get("level_delta", 0)) == 2, "stage reward snapshot should expose perk level delta")


func _verify_stage_mismatch_baseline_does_not_hide_inventory() -> void:
	var owner := FakeOwner.new()
	owner.passive_item_inventory = [
		{"name": "same_item", "display_name": "Same Item", "_inventory_id": 7},
	]
	var baseline := {
		"stage": 1,
		"passive_item_inventory": [
			{"name": "same_item", "display_name": "Same Item", "_inventory_id": 7},
		],
	}
	var builder := StageClearResultStageSnapshotBuilder.new()
	var snapshot: Dictionary = builder.build_stage_reward_snapshot(owner, FakeRegistry.new(), 2, baseline)
	_expect((snapshot.get("passive_items", []) as Array).size() == 1, "stage mismatch should ignore an old baseline snapshot")


func _verify_screen_delegates_snapshot_builder() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var show_flow_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_show_flow_handler.gd")
	var show_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_show_state_data.gd")
	var builder_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_stage_snapshot_builder.gd")
	var diff_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_stage_reward_diff_data.gd")
	var item_reward_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_stage_item_reward_data.gd")
	var perk_reward_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_stage_perk_reward_data.gd")
	_expect(registry_source.find("StageClearResultStageSnapshotBuilder.new()") >= 0, "handler registry should own the stage snapshot builder instance")
	_expect(screen_source.find(".build_progress_snapshot(") >= 0, "result screen should delegate progress snapshots")
	_expect(screen_source.find(".build_stage_reward_snapshot(") < 0, "result screen should not build show-time stage reward snapshots directly")
	_expect(show_flow_source.find("StageClearResultShowStateData.build_show_state") >= 0, "show flow handler should delegate show-time stage reward snapshot flow")
	_expect(show_state_source.find(".build_stage_reward_snapshot(") >= 0, "show state data should delegate stage reward snapshots")
	_expect(screen_source.find("func _build_stage_reward_snapshot") < 0, "result screen should not keep stage reward snapshot assembly")
	_expect(screen_source.find("func _get_passive_item_inventory") < 0, "result screen should not keep stage inventory reads")
	_expect(builder_source.find("func build_stage_reward_snapshot") >= 0, "stage snapshot builder should expose stage reward assembly")
	_expect(builder_source.find("StageClearResultStageRewardDiffData.build_stage_reward_snapshot") >= 0, "stage snapshot builder should delegate stage reward diff calculation")
	_expect(builder_source.find("func _build_item_reward") < 0, "stage snapshot builder should not keep item reward assembly")
	_expect(builder_source.find("func _build_perk_reward") < 0, "stage snapshot builder should not keep perk reward assembly")
	_expect(builder_source.find("func _build_item_identity_counts") < 0, "stage snapshot builder should not keep item identity diff counting")
	_expect(diff_source.find("static func build_stage_reward_snapshot") >= 0, "stage reward diff data should own stage reward diff assembly")
	_expect(diff_source.find("StageClearResultStageItemRewardData.build_active_item_rewards") >= 0, "stage reward diff data should delegate active item reward rows")
	_expect(diff_source.find("StageClearResultStageItemRewardData.build_new_passive_item_rewards") >= 0, "stage reward diff data should delegate passive/mythic reward rows")
	_expect(diff_source.find("StageClearResultStagePerkRewardData.build_perk_rewards") >= 0, "stage reward diff data should delegate perk reward rows")
	_expect(diff_source.find("static func _build_item_reward") < 0, "stage reward diff data should not keep item reward row assembly")
	_expect(diff_source.find("static func _build_perk_reward") < 0, "stage reward diff data should not keep perk reward row assembly")
	_expect(diff_source.find("static func _build_item_identity_counts") < 0, "stage reward diff data should not keep inventory identity counting")
	_expect(item_reward_source.find("static func build_active_item_rewards") >= 0, "stage item reward data should own active item reward rows")
	_expect(item_reward_source.find("static func build_new_passive_item_rewards") >= 0, "stage item reward data should own passive/mythic reward rows")
	_expect(item_reward_source.find("static func build_item_identity_counts") >= 0, "stage item reward data should own inventory identity counting")
	_expect(item_reward_source.find("static func build_item_reward") >= 0, "stage item reward data should own item reward row assembly")
	_expect(perk_reward_source.find("static func build_perk_rewards") >= 0, "stage perk reward data should own perk reward row lists")
	_expect(perk_reward_source.find("static func build_perk_reward") >= 0, "stage perk reward data should own perk reward row assembly")


func _count_reward_type(rewards: Array, reward_type: String) -> int:
	var count := 0
	for reward_value in rewards:
		if reward_value is Dictionary and str((reward_value as Dictionary).get("type", "")) == reward_type:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
