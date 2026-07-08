extends SceneTree

const RuntimePerkOwnerEffectSync := preload("res://scripts/characters/runtime_perk_owner_effect_sync.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const BASE_WIDTH := 155.0
const BASE_HEIGHT := 50.0
const FIELD_HEIGHT := 750.0

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := BASE_WIDTH
	var runtime_paddle_base_height := BASE_HEIGHT
	var player_pos := Vector2(302.5, FIELD_HEIGHT - BASE_HEIGHT)
	var player_paddle_width := BASE_WIDTH
	var player_paddle_height := BASE_HEIGHT
	var player_paddle_scale := 1.0
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var selected_character_type := "smasher"


class FakeScaledRuntime:
	extends RefCounted

	var scale := 1.0
	var refresh_calls := 0

	func get_player_paddle_scale() -> float:
		return scale

	func refresh_runtime_perk_scaling(_owner: Object, _registry: Object) -> void:
		refresh_calls += 1


class FakeSkillConfig:
	extends RefCounted

	var last_multiplier := -1.0

	func set_runtime_cooldown_multiplier(multiplier: float) -> void:
		last_multiplier = multiplier


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_run()


func _run() -> void:
	_verify_sync_context_builder()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["common_expansion"] = 2
	state.runtime_skill_levels["common_training"] = 2
	state.runtime_skill_levels["perk_laurel_shield"] = 3
	var owner := FakeOwner.new()
	var active_runtime := FakeScaledRuntime.new()
	active_runtime.scale = 1.2
	var mythic_runtime := FakeScaledRuntime.new()
	mythic_runtime.scale = 0.75
	var smasher_config := FakeSkillConfig.new()
	var viper_config := FakeSkillConfig.new()
	var commando_config := FakeSkillConfig.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": mythic_runtime,
		"smasher_skill_config": smasher_config,
		"viper_skill_config": viper_config,
		"commando_skill_config": commando_config,
	}

	var applied: bool = state.apply_choice({"id": "common_bulk_up", "name": "Bulk", "max_level": 5}, owner, registry)
	_expect(applied, "bulk-up level choice should apply")
	_expect(owner.runtime_accessory_slot_bonus == 2, "owner should sync accessory slot bonus")
	_expect(owner.runtime_laurel_leaf_count == 3, "owner should sync laurel leaf count")
	_expect_close(owner.runtime_paddle_scale, 1.06, "owner should cache raw perk paddle scale")
	_expect_close(owner.player_paddle_width, BASE_WIDTH * 1.06 * 1.2 * 0.75, "owner width should combine perk, active-item, and mythic scales")
	_expect_close(owner.player_paddle_height, BASE_HEIGHT * 1.06 * 1.2 * 0.75, "owner height should combine perk, active-item, and mythic scales")
	_expect_close(owner.player_pos.y + owner.player_paddle_height, FIELD_HEIGHT, "grounded paddle bottom should remain aligned")
	_expect(owner.runtime_perk_effective_levels.get("common_bulk_up", 0) == 1, "owner should receive effective runtime levels")
	_expect_close(smasher_config.last_multiplier, 0.84, "smasher cooldown multiplier should sync from Common Training")
	_expect_close(viper_config.last_multiplier, 0.84, "viper cooldown multiplier should sync from Common Training")
	_expect_close(commando_config.last_multiplier, 0.84, "commando cooldown multiplier should sync from Common Training")
	_expect(mythic_runtime.refresh_calls == 1, "mythic runtime should refresh after a level side effect")

	if _failures.is_empty():
		print("runtime_perk_owner_effect_sync_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_sync_context_builder() -> void:
	var helper := RuntimePerkOwnerEffectSync.new()
	var source_levels := {"common_bulk_up": 2}
	var context: Dictionary = helper.build_sync_context(
		source_levels,
		3,
		4,
		1.25,
		0.75
	)
	_expect(int(context.get("accessory_slot_bonus", 0)) == 3, "sync context should expose accessory slot bonus")
	_expect(int(context.get("laurel_leaf_count", 0)) == 4, "sync context should expose laurel leaf count")
	_expect_close(float(context.get("player_paddle_size_multiplier", 0.0)), 1.25, "sync context should expose paddle multiplier")
	_expect_close(float(context.get("player_skill_cooldown_multiplier", 0.0)), 0.75, "sync context should expose cooldown multiplier")
	var built_levels: Dictionary = context.get("effective_levels", {}) as Dictionary
	built_levels["common_bulk_up"] = 99
	_expect(int(source_levels.get("common_bulk_up", 0)) == 2, "sync context should deep-copy effective levels")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_owner_sync_flow.gd")
	_expect(flow_source.find("owner_effect_sync.build_sync_context") >= 0, "owner-sync flow should use helper-owned owner-effect sync context")
	_expect(state_source.find("build_sync_context") < 0, "state should not assemble owner-effect sync context inline")
	_expect(state_source.find("\"effective_levels\": get_effective_runtime_skill_levels()") < 0, "state should not inline owner-effect context keys")


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.0001:
		_failures.append("%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
