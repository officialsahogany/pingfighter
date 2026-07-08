extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeMythicRuntime:
	func get_sacred_laurel_leaf_bonus() -> int:
		return 3


class FakeRegistry:
	var mythic_item_runtime := FakeMythicRuntime.new()

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


class FakeRuntimeState:
	var viper_ignition_aura_active := false
	var viper_ignition_aura_owner_sync_dirty := false
	var item_perk_level_bonus := 0


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_helper_derived_stat_queries()
	_verify_helper_state_applications()
	_verify_state_wrappers_delegate_to_helper()
	_verify_source_contract()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("runtime_perk_effective_stat_queries_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_derived_stat_queries() -> void:
	var helper := RuntimePerkEffectiveLevels.new()
	var levels: Dictionary = _sample_levels()

	_expect_close(
		helper.get_dash_recharge_frames(levels, 0, false, 100.0),
		76.0,
		"helper should own dash lightweight recharge math"
	)
	_expect_close(
		helper.get_dash_recovery_frames(levels, 0, false, 100.0),
		82.0,
		"helper should own dash module recovery math"
	)
	_expect_close(
		helper.get_dash_duration_frames(levels, 0, false, 100.0),
		114.0,
		"helper should own dash jump duration math"
	)
	_expect(helper.get_item_spawn_delay_msec(levels, 0, false, 1000) == 880, "helper should own item spawn delay math")
	_expect(helper.get_active_item_cooldown_msec(levels, 0, false, 1000) == 870, "helper should own item cooldown math")
	_expect_close(helper.get_active_item_use_gauge_bonus(levels, 0, false), 30.0, "helper should own active item gauge bonus")
	_expect(helper.get_active_item_slot_capacity(levels, 0, false, 3) == 5, "helper should own item slot capacity")
	_expect_close(helper.get_active_item_duration_bonus(levels, 0, false), 0.60, "helper should own active item duration bonus")
	_expect_close(helper.get_active_item_duration_multiplier(levels, 0, false), 1.60, "helper should own active item duration multiplier")
	_expect_close(helper.get_active_item_duration_frames(levels, 0, false, 600.0), 960.0, "helper should own active item duration frames")
	_expect_close(helper.get_active_item_recycle_chance(levels, 0, false), 0.21, "helper should own active item recycle chance")
	_expect_close(helper.get_effective_polish_multiplier(levels, 0, false), 1.24, "helper should own effective polish multiplier")
	_expect_close(helper.get_downtown_treasure_map_field_mythic_multiplier(levels, 0, false), 4.0, "helper should own treasure-map mythic multiplier")
	_expect_close(helper.get_treasure_hunt_legendary_chance(levels, 0, false, 0.95), 1.0, "helper should own treasure-hunt chance clamp")
	_expect_close(helper.get_player_speed_multiplier(levels, 0, false), 1.06, "helper should own player speed multiplier")
	_expect_close(helper.get_player_paddle_size_multiplier(levels, 0, false), 1.12, "helper should own player paddle size multiplier")
	_expect(helper.get_accessory_slot_bonus(levels, 0, false) == 2, "helper should own accessory slot bonus")
	_expect_close(helper.get_player_skill_cooldown_multiplier(levels, 0, false), 0.92, "helper should own player skill cooldown multiplier")
	_expect_close(helper.get_player_skill_cooldown_seconds(levels, 0, false, 10.0), 9.2, "helper should own player skill cooldown seconds")
	_expect_close(helper.get_boost_charge_chance_pct(levels, 0, false), 14.0, "helper should own boost charge chance")
	_expect(helper.get_dash_acceleration_level(levels, 0, false) == 1, "helper should own dash acceleration level")
	_expect_close(helper.get_dash_acceleration_bonus(levels, 0, false), 0.70, "helper should own dash acceleration bonus")
	_expect_close(helper.get_dash_acceleration_height_bonus(levels, 0, false, 50.0), 35.0, "helper should own dash acceleration height bonus")
	_expect(helper.get_laurel_leaf_count(levels, 0, false, 3) == 5, "helper should own Laurel leaf total")
	_expect_close(
		helper.get_active_item_duration_frames({"item_caffeine": 3}, 1, true, 600.0),
		1680.0,
		"helper should keep Lv.6+ active-item duration scaling uncapped"
	)


func _verify_helper_state_applications() -> void:
	var helper := RuntimePerkEffectiveLevels.new()
	var state := FakeRuntimeState.new()

	var activation: Dictionary = helper.build_viper_ignition_aura_active_update(false, true)
	var activation_apply: Dictionary = helper.apply_viper_ignition_aura_active_update(state, activation)
	_expect(bool(activation_apply.get("accepted", false)), "helper should apply Viper Ignition Aura active state")
	_expect(state.viper_ignition_aura_active, "helper should set Viper Ignition Aura active flag")
	_expect(state.viper_ignition_aura_owner_sync_dirty, "helper should mark Viper Ignition Aura owner sync dirty")
	_expect(
		not bool(helper.apply_viper_ignition_aura_active_update(
			state,
			helper.build_viper_ignition_aura_active_update(true, true)
		).get("accepted", true)),
		"helper should reject unchanged Viper Ignition Aura active updates"
	)

	var refresh_apply: Dictionary = helper.apply_dynamic_effect_refresh_state_update(
		state,
		helper.build_dynamic_effect_refresh_plan(true, true)
	)
	_expect(bool(refresh_apply.get("accepted", false)), "helper should apply dynamic refresh state updates")
	_expect(not state.viper_ignition_aura_owner_sync_dirty, "helper should clear Viper Ignition Aura dirty sync")

	var bonus_update: Dictionary = helper.build_item_perk_level_bonus_update(0, 3)
	var bonus_apply: Dictionary = helper.apply_item_perk_level_bonus_update(state, bonus_update)
	_expect(bool(bonus_apply.get("accepted", false)), "helper should apply item perk-level bonus state")
	_expect(state.item_perk_level_bonus == 3, "helper should write item perk-level bonus")
	_expect(
		not bool(helper.apply_item_perk_level_bonus_update(
			state,
			helper.build_item_perk_level_bonus_update(3, 3)
		).get("accepted", true)),
		"helper should reject unchanged item perk-level bonus updates"
	)
	_expect(
		not bool(helper.apply_item_perk_level_bonus_update(null, bonus_update).get("accepted", true)),
		"helper should reject null runtime state applications"
	)


func _verify_state_wrappers_delegate_to_helper() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = _sample_levels()
	var registry := FakeRegistry.new()

	_expect_close(state.get_dash_recharge_frames(100.0), 76.0, "state dash recharge wrapper should preserve public behavior")
	_expect_close(state.get_dash_duration_frames(100.0), 114.0, "state dash duration wrapper should preserve public behavior")
	_expect(state.get_item_spawn_delay_msec(1000) == 880, "state item spawn wrapper should preserve public behavior")
	_expect_close(state.get_active_item_duration_frames(600.0), 960.0, "state item duration wrapper should preserve public behavior")
	_expect_close(state.get_active_item_recycle_chance(), 0.21, "state recycle wrapper should preserve public behavior")
	_expect_close(state.get_player_paddle_size_multiplier(), 1.12, "state paddle-size wrapper should preserve public behavior")
	_expect(state.get_accessory_slot_bonus() == 2, "state accessory wrapper should preserve public behavior")
	_expect_close(state.get_player_skill_cooldown_seconds(10.0), 9.2, "state cooldown wrapper should preserve public behavior")
	_expect_close(state.get_dash_acceleration_height_bonus(50.0), 35.0, "state dash acceleration wrapper should preserve public behavior")
	_expect(state.get_laurel_leaf_count(registry) == 5, "state Laurel wrapper should preserve Sacred Laurel stacking")
	state.runtime_skill_levels = {"item_caffeine": 3}
	state.set_item_perk_level_bonus(1)
	state.set_viper_ignition_aura_active(true)
	_expect_close(state.get_active_item_duration_frames(600.0), 1680.0, "state wrapper should keep effective Lv.6+ item duration scaling")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_effective_levels.gd")
	var query_surface_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_effective_stat_query_surface.gd")
	var dynamic_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_dynamic_effects.gd")
	_expect(helper_source.find("func get_dash_recharge_frames") >= 0, "effective-level helper should expose derived dash stat queries")
	_expect(helper_source.find("func get_active_item_duration_frames") >= 0, "effective-level helper should expose derived item stat queries")
	_expect(helper_source.find("func get_player_skill_cooldown_multiplier") >= 0, "effective-level helper should expose derived common stat queries")
	_expect(query_surface_source.find("func get_dash_recharge_frames") >= 0, "effective query surface should expose derived dash stat queries")
	_expect(query_surface_source.find("func get_active_item_duration_frames") >= 0, "effective query surface should expose derived item stat queries")
	_expect(query_surface_source.find("func get_player_skill_cooldown_multiplier") >= 0, "effective query surface should expose derived common stat queries")
	_expect(state_source.find("_effective_stat_queries.get_dash_recharge_frames") >= 0, "state should delegate dash recharge query to query surface")
	_expect(state_source.find("_effective_stat_queries.get_active_item_duration_frames") >= 0, "state should delegate item duration query to query surface")
	_expect(state_source.find("_effective_stat_queries.get_player_skill_cooldown_multiplier") >= 0, "state should delegate cooldown query to query surface")
	_expect(state_source.find("_effective_levels.get_dash_recharge_frames") < 0, "state should not project dash recharge query parameters inline")
	_expect(state_source.find("_effective_levels.get_active_item_duration_frames") < 0, "state should not project item duration query parameters inline")
	_expect(state_source.find("_effective_levels.get_player_skill_cooldown_multiplier") < 0, "state should not project cooldown query parameters inline")
	_expect(state_source.find("_dynamic_effects.set_viper_ignition_aura_active") >= 0, "state should delegate Viper Ignition Aura active writes to dynamic helper")
	_expect(state_source.find("_dynamic_effects.set_item_perk_level_bonus") >= 0, "state should delegate item perk-level bonus writes to dynamic helper")
	_expect(state_source.find("_dynamic_effects.refresh_viper_ignition_aura_dynamic_effects") >= 0, "state should delegate dynamic refresh orchestration to dynamic helper")
	_expect(dynamic_source.find("_apply_viper_ignition_aura_active_update") >= 0, "dynamic helper should call effective-level Viper Ignition state application")
	_expect(dynamic_source.find("_apply_item_perk_level_bonus_update") >= 0, "dynamic helper should call effective-level item bonus state application")
	_expect(dynamic_source.find("apply_dynamic_effect_refresh_state_update") >= 0, "dynamic helper should call effective-level dynamic refresh state application")
	_expect(state_source.find("float(max(0, base_delay_msec))") < 0, "state should not keep item spawn formula inline")
	_expect(state_source.find("base_duration_frames * get_active_item_duration_multiplier()") < 0, "state should not keep item duration formula inline")
	_expect(state_source.find("viper_ignition_aura_active = bool(update.get") < 0, "state should not assign Viper Ignition Aura active update inline")
	_expect(state_source.find("viper_ignition_aura_owner_sync_dirty = bool(update.get") < 0, "state should not assign Viper Ignition Aura dirty update inline")
	_expect(state_source.find("viper_ignition_aura_owner_sync_dirty = false") < 0, "state should not clear Viper Ignition Aura dirty state inline")
	_expect(state_source.find("item_perk_level_bonus = int(update.get") < 0, "state should not assign item perk-level bonus inline")


func _sample_levels() -> Dictionary:
	return {
		"dash_lightweight": 2,
		"dash_module_control": 1,
		"dash_jump": 2,
		"item_luck": 1,
		"item_cooldown_mastery": 1,
		"item_gauge_mastery": 2,
		"item_bag_expansion": 2,
		"item_caffeine": 2,
		"item_recycle": 3,
		"item_polish": 2,
		"downtown_treasure_map": 2,
		"common_swiftness": 1,
		"common_bulk_up": 2,
		"common_expansion": 2,
		"common_training": 1,
		"perk_boost_charge": 2,
		"dash_acceleration": 1,
		"perk_laurel_shield": 2,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.03:
		_failures.append("%s (actual %.3f, expected %.3f)" % [message, actual, expected])
