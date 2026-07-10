extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkAngelBlessingState := preload("res://scripts/characters/runtime_perk_angel_blessing_state.gd")
const RuntimePerkAngelBlessingProjection := preload("res://scripts/characters/runtime_perk_angel_blessing_projection.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_each_pure_lane_and_neutrality()
	_verify_cooldown_lanes_do_not_cross_apply()
	_verify_stage_replacement_and_read_purity()
	_verify_runtime_query_surface_composition()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("angel_blessing_buff_lanes_smoke: ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _verify_each_pure_lane_and_neutrality() -> void:
	var neutral_state: Object = RuntimePerkAngelBlessingState.new()
	var neutral_values: Dictionary = _project_all_lanes(neutral_state)
	var expected_neutral: Dictionary = {
		RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE: 1.20,
		RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX: 640.0,
		RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN: 8000.0,
		RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN: 0.92,
		RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN: 120.0,
		RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED: 1.06,
	}
	_expect_lane_values(neutral_values, expected_neutral, "neutral projection")

	var expected_active: Dictionary = {
		RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE: 1.56,
		RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX: 832.0,
		RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN: 5600.0,
		RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN: 0.644,
		RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN: 84.0,
		RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED: 1.378,
	}
	for buff_id: String in RuntimePerkAngelBlessingState.BUFF_IDS:
		var blessing_state: Object = _rolled_state([buff_id])
		var actual: Dictionary = _project_all_lanes(blessing_state)
		for lane_id: String in RuntimePerkAngelBlessingState.BUFF_IDS:
			var expected: float = float(expected_active[lane_id]) if lane_id == buff_id else float(expected_neutral[lane_id])
			_expect_close(
				float(actual.get(lane_id, -1.0)),
				expected,
				"%s should only change its own %s lane" % [buff_id, lane_id]
			)

	var item_state: Object = _rolled_state([RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN])
	_expect(
		RuntimePerkAngelBlessingProjection.apply_active_item_cooldown_msec(item_state, 1001) == 701,
		"item cooldown projection should round once after the Angel multiplier"
	)
	var dash_state: Object = _rolled_state([RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN])
	_expect_close(
		RuntimePerkAngelBlessingProjection.apply_dash_recharge_frames(dash_state, 8.0),
		6.0,
		"dash cooldown projection should preserve the shared six-frame minimum"
	)


func _verify_cooldown_lanes_do_not_cross_apply() -> void:
	var blessing_state: Object = _rolled_state([
		RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN,
		RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN,
		RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN,
	])
	_expect(
		RuntimePerkAngelBlessingProjection.apply_active_item_cooldown_msec(blessing_state, 8000) == 5600,
		"three cooldown blessings must not multiply the item cooldown lane more than once"
	)
	_expect_close(
		RuntimePerkAngelBlessingProjection.apply_player_skill_cooldown_multiplier(blessing_state, 0.92),
		0.644,
		"three cooldown blessings must not multiply the active-skill lane more than once"
	)
	_expect_close(
		RuntimePerkAngelBlessingProjection.apply_dash_recharge_frames(blessing_state, 120.0),
		84.0,
		"three cooldown blessings must not multiply the dash lane more than once"
	)


func _verify_stage_replacement_and_read_purity() -> void:
	var blessing_state: Object = RuntimePerkAngelBlessingState.new()
	blessing_state.roll_for_stage(
		1,
		blessing_state.get_all_buff_ids(),
		3,
		[
			RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE,
			RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX,
			RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED,
		]
	)
	var revision_before_reads: int = blessing_state.get_revision()
	_project_all_lanes(blessing_state)
	_expect(
		blessing_state.get_revision() == revision_before_reads,
		"stat projection reads must not mutate Angel state revision"
	)
	blessing_state.roll_for_stage(
		2,
		blessing_state.get_all_buff_ids(),
		3,
		[
			RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN,
			RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN,
			RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN,
		]
	)
	var values: Dictionary = _project_all_lanes(blessing_state)
	_expect_close(float(values[RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE]), 1.20, "next stage should neutralize old paddle blessing")
	_expect_close(float(values[RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX]), 640.0, "next stage should neutralize old gauge blessing")
	_expect_close(float(values[RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED]), 1.06, "next stage should neutralize old speed blessing")
	_expect_close(float(values[RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN]), 5600.0, "next stage should activate new item cooldown blessing")
	_expect_close(float(values[RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN]), 0.644, "next stage should activate new skill cooldown blessing")
	_expect_close(float(values[RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN]), 84.0, "next stage should activate new dash blessing")


func _verify_runtime_query_surface_composition() -> void:
	var positive_runtime: Object = RuntimePerkState.new()
	positive_runtime.runtime_skill_levels = _sample_levels()
	positive_runtime.roll_angel_blessing_for_stage(
		1,
		positive_runtime.get_angel_blessing_state().get_all_buff_ids(),
		3,
		[
			RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE,
			RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX,
			RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN,
		]
	)
	_expect_close(positive_runtime.get_player_paddle_size_multiplier(), 1.456, "runtime query should compose Bulk Up then Angel paddle size")
	_expect_close(positive_runtime.get_angel_blessing_special_gauge_max(640.0), 832.0, "runtime query should compose Fuel Pouch total then Angel gauge max")
	_expect(positive_runtime.get_active_item_cooldown_msec(1000) == 609, "runtime query should compose item mastery then Angel cooldown")
	_expect_close(positive_runtime.get_player_skill_cooldown_multiplier(), 0.92, "unselected runtime skill cooldown lane should stay neutral")
	_expect_close(positive_runtime.get_dash_recharge_frames(100.0), 76.0, "unselected runtime dash lane should stay neutral")
	_expect_close(positive_runtime.get_player_speed_multiplier(), 1.06, "unselected runtime speed lane should stay neutral")

	var multipliers: Dictionary = positive_runtime.get_angel_blessing_snapshot().get("multipliers", {})
	_expect(multipliers.size() == 6, "HUD-facing Angel snapshot should expose all six multipliers")
	_expect_close(float(multipliers.get(RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE, 0.0)), 1.30, "snapshot should expose active positive multiplier")
	_expect_close(float(multipliers.get(RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN, 0.0)), 1.0, "snapshot should keep unselected lane neutral")

	var cooldown_runtime: Object = RuntimePerkState.new()
	cooldown_runtime.runtime_skill_levels = _sample_levels()
	cooldown_runtime.roll_angel_blessing_for_stage(
		1,
		cooldown_runtime.get_angel_blessing_state().get_all_buff_ids(),
		3,
		[
			RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN,
			RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN,
			RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN,
		]
	)
	_expect(cooldown_runtime.get_active_item_cooldown_msec(1000) == 609, "runtime item cooldown should receive exactly one Angel reduction")
	_expect_close(cooldown_runtime.get_player_skill_cooldown_multiplier(), 0.644, "runtime skill cooldown multiplier should receive exactly one Angel reduction")
	_expect_close(cooldown_runtime.get_player_skill_cooldown_seconds(10.0), 6.44, "runtime skill cooldown seconds should not apply Angel twice")
	_expect_close(cooldown_runtime.get_dash_recharge_frames(100.0), 53.2, "runtime dash query should compose lightweight then Angel")
	_expect_close(cooldown_runtime.get_dash_recharge_frames(8.0), 6.0, "runtime dash query should keep the six-frame minimum")
	_expect_close(cooldown_runtime.get_player_paddle_size_multiplier(), 1.12, "unselected runtime paddle lane should stay neutral")
	_expect_close(cooldown_runtime.get_player_speed_multiplier(), 1.06, "unselected runtime speed lane should stay neutral")

	cooldown_runtime.roll_angel_blessing_for_stage(
		2,
		cooldown_runtime.get_angel_blessing_state().get_all_buff_ids(),
		1,
		[RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED]
	)
	_expect(cooldown_runtime.get_active_item_cooldown_msec(1000) == 870, "stage replacement should neutralize old item cooldown lane")
	_expect_close(cooldown_runtime.get_player_skill_cooldown_multiplier(), 0.92, "stage replacement should neutralize old skill cooldown lane")
	_expect_close(cooldown_runtime.get_dash_recharge_frames(100.0), 76.0, "stage replacement should neutralize old dash lane")
	_expect_close(cooldown_runtime.get_player_speed_multiplier(), 1.378, "stage replacement should activate the new speed lane")


func _rolled_state(buff_ids: Array) -> Object:
	var blessing_state: Object = RuntimePerkAngelBlessingState.new()
	var result: Dictionary = blessing_state.roll_for_stage(
		1,
		blessing_state.get_all_buff_ids(),
		buff_ids.size(),
		buff_ids
	)
	_expect(bool(result.get("rolled", false)), "forced Angel lane state should roll successfully")
	return blessing_state


func _project_all_lanes(blessing_state: Object) -> Dictionary:
	return {
		RuntimePerkAngelBlessingState.BUFF_PADDLE_SIZE: RuntimePerkAngelBlessingProjection.apply_player_paddle_size_multiplier(blessing_state, 1.20),
		RuntimePerkAngelBlessingState.BUFF_GAUGE_MAX: RuntimePerkAngelBlessingProjection.apply_special_gauge_max(blessing_state, 640.0),
		RuntimePerkAngelBlessingState.BUFF_ITEM_COOLDOWN: float(RuntimePerkAngelBlessingProjection.apply_active_item_cooldown_msec(blessing_state, 8000)),
		RuntimePerkAngelBlessingState.BUFF_ACTIVE_COOLDOWN: RuntimePerkAngelBlessingProjection.apply_player_skill_cooldown_multiplier(blessing_state, 0.92),
		RuntimePerkAngelBlessingState.BUFF_DASH_COOLDOWN: RuntimePerkAngelBlessingProjection.apply_dash_recharge_frames(blessing_state, 120.0),
		RuntimePerkAngelBlessingState.BUFF_MOVE_SPEED: RuntimePerkAngelBlessingProjection.apply_player_speed_multiplier(blessing_state, 1.06),
	}


func _sample_levels() -> Dictionary:
	return {
		"dash_lightweight": 2,
		"item_cooldown_mastery": 1,
		"common_swiftness": 1,
		"common_bulk_up": 2,
		"common_training": 1,
	}


func _expect_lane_values(actual: Dictionary, expected: Dictionary, message: String) -> void:
	for buff_id: String in RuntimePerkAngelBlessingState.BUFF_IDS:
		_expect_close(
			float(actual.get(buff_id, -1.0)),
			float(expected.get(buff_id, -2.0)),
			"%s: %s" % [message, buff_id]
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) > 0.003:
		_failures.append("%s (actual %.4f, expected %.4f)" % [message, actual, expected])
