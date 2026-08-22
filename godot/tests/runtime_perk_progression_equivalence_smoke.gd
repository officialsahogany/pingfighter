extends SceneTree

# S2 behavior-preservation seal for the 37 five-level Mugong progression owner.
# The fixture below is deliberately independent of RuntimePerkProgression: it
# freezes the eb116e595 authored tables and their legacy Lv.6+ rules, then checks
# every lane at Lv.1-12. This is intentionally exhaustive, not representative.

const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")
const RuntimePerkEffectiveLevels := preload("res://scripts/characters/runtime_perk_effective_levels.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const ElixirOfMasteryRuntime := preload("res://scripts/items/elixir_of_mastery_runtime.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LINEAR := "linear"
const HOLD := "hold"
const STAIRCASE := "staircase"

# Fixture lane fields: v=authored Lv.1-5, s=legacy overflow step, m=mode,
# lo/hi=legacy clamp. Converted lanes omit s: their legacy step was
# (Lv.5-Lv.1)/4. Structural converted lanes explicitly hold.
const LEGACY_LANES := {
	"dash_acceleration": {
		"vertical_scale_bonus": {"v": [0.70, 1.40, 2.10, 2.80, 3.50], "s": 0.70},
		"horizontal_scale_bonus": {"v": [0.10, 0.20, 0.30, 0.40, 0.50], "s": 0.10},
	},
	"item_luck": {"spawn_wait_reduction": {"v": [0.12, 0.24, 0.36, 0.48, 0.60], "s": 0.12}},
	"item_gauge_mastery": {"gauge_gain": {"v": [15.0, 30.0, 45.0, 60.0, 75.0], "s": 15.0}},
	"item_caffeine": {"duration_bonus": {"v": [0.30, 0.60, 0.90, 1.20, 1.50], "s": 0.30}},
	"item_polish": {
		"general_amplify": {"v": [0.05, 0.10, 0.15, 0.20, 0.25], "s": 0.05},
		"mythic_roll_bonus": {"v": [0.12, 0.24, 0.36, 0.48, 0.60], "s": 0.12},
	},
	"item_recycle": {"retain_chance": {"v": [0.07, 0.14, 0.21, 0.28, 0.35], "s": 0.07, "hi": 0.90}},
	"downtown_treasure_map": {
		"mythic_offer_bonus": {"v": [1.5, 3.0, 4.5, 6.0, 7.5], "s": 1.5},
		"vision_box_chance_bonus": {"v": [0.03, 0.06, 0.09, 0.12, 0.15], "s": 0.03},
	},
	"training_mastery": {"training_amplify": {"v": [0.2, 0.4, 0.6, 0.8, 1.0], "s": 0.2}},
	"perk_boost_charge": {
		"trigger_chance_pct": {"v": [7.0, 14.0, 21.0, 28.0, 35.0], "s": 7.0, "hi": 100.0},
		"free_dash_count": {"v": [1.0, 1.0, 1.0, 1.0, 1.0], "m": HOLD},
		"recharge_reduction_pct": {"v": [90.0, 90.0, 90.0, 90.0, 90.0], "m": HOLD},
	},
	"perk_laurel_shield": {"leaf_count": {"v": [1.0, 2.0, 3.0, 4.0, 5.0], "s": 1.0}},
	"dash_spirit": {"laser_chance": {"v": [0.07, 0.14, 0.21, 0.28, 0.35], "s": 0.07}},
	"extension_gear": {"duration_bonus": {"v": [0.25, 0.50, 0.75, 1.00, 1.25], "s": 0.25}},
	"combo_amplifier_chip": {
		"drive_speed_bonus": {"v": [0.9, 1.8, 2.7, 3.6, 4.5], "s": 0.9},
		"drive_curve_bonus": {"v": [0.05, 0.10, 0.15, 0.15, 0.15], "m": HOLD},
		"smash_speed_bonus": {"v": [0.45, 0.90, 1.35, 1.80, 2.25], "s": 0.45},
		"initial_boost_decay_reduction": {"v": [0.1, 0.2, 0.3, 0.4, 0.5], "s": 0.1, "hi": 0.5},
	},
	"jetpack_enhance": {
		"max_gauge_bonus": {"v": [0.2, 0.4, 0.6, 0.8, 1.0], "s": 0.2},
		"airborne_gauge_gain_bonus": {"v": [0.0, 0.0, 0.1, 0.2, 0.3], "s": 0.1},
	},
	"kick_enhance": {
		"authored_precision_pct": {"v": [8.0, 16.0, 24.0, 32.0, 40.0], "s": 8.0},
		"authored_speed_pct": {"v": [12.0, 24.0, 36.0, 48.0, 60.0], "s": 12.0},
		"runtime_aim_gain": {"v": [0.09, 0.18, 0.27, 0.36, 0.45], "s": 0.09, "hi": 0.90},
		"runtime_aim_candidate_count": {"v": [4.0, 5.0, 6.0, 7.0, 8.0], "m": HOLD},
		"runtime_hit_speed_bonus": {"v": [0.04, 0.08, 0.12, 0.16, 0.20], "s": 0.04},
		"prep_reduction": {"v": [0.07, 0.14, 0.21, 0.28, 0.35], "s": 0.07, "hi": 0.90},
		"furnace_knockback_chance": {"v": [0.0, 0.0, 0.1, 0.2, 0.3], "s": 0.1, "hi": 1.0},
		"guard_fire_knockback_pct": {"v": [0.0, 0.0, 150.0, 150.0, 150.0], "m": HOLD},
	},
	"blade_amp": {
		"range_width_bonus": {"v": [0.1, 0.2, 0.3, 0.4, 0.5], "m": HOLD},
		"projectile_speed_bonus": {"v": [0.1, 0.2, 0.3, 0.4, 0.5], "s": 0.1},
		"hit_speed_bonus": {"v": [0.15, 0.30, 0.45, 0.60, 0.75], "s": 0.15},
		"gauge_cost_reduction": {"v": [10.0, 20.0, 30.0, 40.0, 50.0], "s": 10.0, "hi": 100.0},
		"homing_tier": {"v": [0.0, 0.0, 1.0, 1.0, 2.0], "m": HOLD},
		"followup_chance_pct": {"v": [0.0, 0.0, 10.0, 20.0, 30.0], "s": 10.0, "hi": 100.0},
	},
	"four_poisons": {
		"prep_reduction_pct": {"v": [8.0, 16.0, 25.0, 33.0, 40.0], "s": 4.0, "hi": 70.0},
		"sleep_pct": {"v": [5.0, 10.0, 15.0, 20.0, 25.0], "s": 5.0, "hi": 50.0},
		"confusion_pct": {"v": [12.0, 24.0, 36.0, 48.0, 70.0], "s": 10.0, "hi": 150.0},
		"dual_duration_pct": {"v": [7.0, 14.0, 20.0, 27.0, 33.0], "s": 5.0, "hi": 45.0},
		"cooldown_reduction_pct": {"v": [0.0, 0.0, 10.0, 15.0, 20.0], "s": 4.0, "hi": 40.0},
		"clone_hp": {"v": [2.0, 2.0, 3.0, 3.0, 4.0], "m": STAIRCASE, "s": 1.0, "every": 2, "origin": 4, "steps": 2, "hi": 6.0},
		"superarmor": {"v": [0.0, 0.0, 1.0, 1.0, 1.0], "m": HOLD},
		"clone_replication": {"v": [0.0, 0.0, 0.0, 0.0, 1.0], "m": HOLD},
	},
	"pistol_enhance": {
		"spread_degrees": {"v": [12.0, 9.0, 6.0, 3.0, 1.0], "m": HOLD},
		"speed_bonus_pct": {"v": [10.0, 20.0, 30.0, 40.0, 50.0], "m": HOLD},
		"knockback_bonus_pct": {"v": [30.0, 60.0, 90.0, 120.0, 150.0], "m": HOLD},
		"magazine_size": {"v": [5.0, 5.0, 6.0, 6.0, 7.0], "s": 1.0},
	},
	"star_detector": {"star_bonus_pct": {"v": [5.0, 10.0, 15.0, 20.0, 25.0]}},
	"adversity_armor": {
		"trigger_chance_pct": {"v": [20.0, 25.0, 30.0, 35.0, 40.0], "hi": 100.0},
		"invincible_duration_sec": {"v": [5.0, 8.0, 10.0, 13.0, 15.0]},
	},
	"reinforced_boomerang_gauntlet": {
		"boomerang_knockback_pct": {"v": [20.0, 28.0, 35.0, 43.0, 50.0]},
		"boomerang_stun_pct": {"v": [20.0, 35.0, 50.0, 65.0, 80.0]},
		"boomerang_launch_speed_pct": {"v": [15.0, 24.0, 33.0, 41.0, 50.0]},
		"boomerang_homing_pct": {"v": [10.0, 20.0, 30.0, 40.0, 50.0]},
		"boomerang_spawn_bonus_pct": {"v": [50.0, 88.0, 125.0, 163.0, 200.0]},
	},
	"sensor": {
		"auto_dash_token_count": {"v": [1.0, 1.0, 2.0, 2.0, 2.0]},
		"auto_dash_cooldown_sec": {"v": [30.0, 26.0, 23.0, 19.0, 15.0], "lo": 1.0},
	},
	"dowsing_pendulum": {"attraction_range": {"v": [120.0, 160.0, 200.0, 240.0, 280.0]}},
	"chargebag": {"chargebag_pct": {"v": [15.0, 25.0, 35.0, 45.0, 55.0]}},
	"battery": {"gauge_preserve_pct": {"v": [40.0, 55.0, 70.0, 85.0, 100.0], "hi": 100.0}},
	"master": {
		"wall_length_pct": {"v": [12.0, 20.0, 29.0, 37.0, 45.0]},
		"item_cooldown_pct": {"v": [3.0, 5.0, 8.0, 10.0, 12.0], "hi": 95.0},
		"wall_spawn_bonus_pct": {"v": [100.0, 158.0, 215.0, 273.0, 330.0]},
	},
	"gold_digger": {"gold_bonus_pct": {"v": [15.0, 25.0, 35.0, 45.0, 55.0]}},
	"lucky_coin": {"double_spawn_pct": {"v": [3.0, 7.0, 10.0, 14.0, 17.0], "hi": 100.0}},
	"shrapnel_armor": {
		"trigger_chance_pct": {"v": [6.0, 9.0, 12.0, 14.0, 17.0], "hi": 100.0},
		"shard_count": {"v": [4.0, 5.0, 6.0, 7.0, 8.0]},
		"knockback_level": {"v": [1.0, 2.0, 3.0, 3.0, 4.0]},
		"gauge_cost": {"v": [50.0, 44.0, 38.0, 31.0, 25.0], "lo": 0.0},
	},
	"foul_whistle": {"negate_chance_pct": {"v": [3.0, 5.0, 7.0, 9.0, 11.0], "hi": 100.0}},
	"neural_helmet": {
		"aipill_gauge_reduction": {"v": [10.0, 15.0, 20.0, 25.0, 30.0], "hi": 90.0},
		"aipill_ball_speed_bonus_pct": {"v": [2.0, 4.0, 6.0, 8.0, 10.0]},
		"aipill_spawn_bonus_pct": {"v": [100.0, 158.0, 215.0, 273.0, 330.0]},
	},
	"commando_arm": {
		"throw_speed_pct": {"v": [6.0, 11.0, 15.0, 20.0, 24.0]},
		"explosion_range_pct": {"v": [3.0, 7.0, 11.0, 14.0, 18.0]},
		"smoke_duration_pct": {"v": [12.0, 21.0, 30.0, 39.0, 48.0]},
		"prep_reduction_pct": {"v": [12.0, 21.0, 30.0, 39.0, 48.0], "hi": 95.0},
	},
	"rainbow_fur_glove": {
		"rainbow_glove_trigger_chance_pct": {"v": [3.0, 4.0, 5.0, 6.0, 7.0], "hi": 100.0},
		"rainbow_glove_cooldown_reduction_pct": {"v": [8.0, 11.0, 14.0, 17.0, 20.0], "hi": 95.0},
	},
	"knee_pads": {"knee_charge_pct": {"v": [20.0, 33.0, 45.0, 58.0, 70.0]}},
	"soul_burst": {"soul_burst_gauge_cost": {"v": [170.0, 153.0, 135.0, 118.0, 100.0], "lo": 0.0}},
	"venom_mist_gauntlet": {
		"mist_trigger_chance_pct": {"v": [20.0, 29.0, 38.0, 46.0, 55.0], "hi": 100.0},
		"mist_duration_sec": {"v": [1.5, 2.5, 3.5, 4.5, 5.5]},
	},
	"sage_ring": {
		"trigger_chance_pct": {"v": [5.0, 5.0, 5.0, 5.0, 5.0]},
		"perk_level_bonus": {"v": [1.0, 1.0, 2.0, 2.0, 3.0]},
		"duration_sec": {"v": [6.0, 7.0, 8.0, 9.0, 10.0]},
	},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_test_exact_target_and_lane_sets()
	_test_all_legacy_values()
	_test_primary_runtime_consumer()
	_test_catalog_descriptions()
	_test_known_distinct_lanes()
	_test_elixir_candidate_equivalence()
	_test_corrupted_fixture_goes_red()
	_test_real_snapshot_projection()
	LanguageSettings.set_test_locale_override("")
	if not _failures.is_empty():
		ProjectResourceLoader.clear_caches()
		quit(1)
		return
	print("runtime_perk_progression_equivalence_smoke: ok TARGETS=37 LEVELS=1-12 NEGATIVE=RED ELIXIR=47")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _test_exact_target_and_lane_sets() -> void:
	_expect(LEGACY_LANES.size() == 37, "frozen target fixture must contain exactly 37 ids")
	_expect(_string_set(RuntimePerkProgression.TARGET_PERK_IDS.keys()) == _string_set(LEGACY_LANES.keys()), "owner target ids must equal the frozen 37-id set")
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		var expected_lanes: Dictionary = LEGACY_LANES[perk_id]
		_expect(_string_set(RuntimePerkProgression.get_lane_ids(perk_id)) == _string_set(expected_lanes.keys()), "%s lane ids must match the frozen baseline" % perk_id)
		for lane_id_value in expected_lanes.keys():
			var lane_id := str(lane_id_value)
			var owner_lane: Dictionary = (RuntimePerkProgression.PROGRESSIONS[perk_id]["lanes"] as Dictionary)[lane_id]
			_expect(owner_lane.has("overflow"), "%s/%s must declare overflow" % [perk_id, lane_id])
			_expect(owner_lane.has("milestones"), "%s/%s must declare milestones" % [perk_id, lane_id])
			_expect(owner_lane.has("polarity"), "%s/%s must declare polarity" % [perk_id, lane_id])


func _test_all_legacy_values() -> void:
	var mismatch_count := _count_index_mismatches(RuntimePerkProgression.PROGRESSIONS)
	_expect(mismatch_count == 0, "canonical owner must equal the eb116e595 baseline for every 37xlane x Lv.1-12 value; mismatches=%d" % mismatch_count)


func _test_primary_runtime_consumer() -> void:
	var queries: Object = RuntimePerkEffectiveLevels.new()
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		if not RuntimePerkProgression.has_primary_runtime_bonus(perk_id):
			continue
		var progression: Dictionary = RuntimePerkProgression.PROGRESSIONS[perk_id]
		var lane_id := str(progression.get("primary_runtime_lane", ""))
		for level in range(1, 13):
			var actual: float = queries.get_runtime_skill_bonus({perk_id: level}, 0, false, perk_id)
			var expected := _legacy_value(perk_id, lane_id, level)
			_expect_close(actual, expected, "%s primary runtime Lv.%d" % [perk_id, level])
	for perk_id_value in LEGACY_LANES.keys():
		var converted_id := str(perk_id_value)
		if not RuntimePerkProgression.is_converted_perk(converted_id):
			continue
		for lane_id_value in (LEGACY_LANES[converted_id] as Dictionary).keys():
			var lane_id := str(lane_id_value)
			for level in range(1, 13):
				_expect_close(PerkConversionValues.get_value(converted_id, lane_id, level), _legacy_value(converted_id, lane_id, level), "%s/%s converted consumer Lv.%d" % [converted_id, lane_id, level])


func _test_catalog_descriptions() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var all_data: Dictionary = catalog.get_all_perk_data()
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		_expect(all_data.has(perk_id), "%s must remain registered" % perk_id)
		if not all_data.has(perk_id):
			continue
		var perk_data: Dictionary = all_data[perk_id]
		_expect(int(perk_data.get("max_level", 0)) == 5, "%s max_level must remain 5 in S2" % perk_id)
		var descriptions: Dictionary = perk_data.get("descriptions", {})
		for level in range(1, 6):
			var authored := str(descriptions.get(level, descriptions.get(str(level), "")))
			var generated := RuntimePerkOverflowDescriptions.generate_stats_text(perk_id, level)
			_expect(generated == authored and not generated.is_empty(), "%s Lv.%d catalog/runtime description drift: generated='%s' authored='%s'" % [perk_id, level, generated, authored])


func _test_known_distinct_lanes() -> void:
	for level in range(1, 13):
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "authored_precision_pct", level), _legacy_value("kick_enhance", "authored_precision_pct", level), "kick authored precision Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "authored_speed_pct", level), _legacy_value("kick_enhance", "authored_speed_pct", level), "kick authored speed Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "runtime_aim_gain", level), _legacy_value("kick_enhance", "runtime_aim_gain", level), "kick runtime aim Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("kick_enhance", "runtime_hit_speed_bonus", level), _legacy_value("kick_enhance", "runtime_hit_speed_bonus", level), "kick runtime hit speed Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("item_polish", "general_amplify", level), _legacy_value("item_polish", "general_amplify", level), "item_polish general Lv.%d" % level)
		_expect_close(RuntimePerkProgression.get_value("item_polish", "mythic_roll_bonus", level), _legacy_value("item_polish", "mythic_roll_bonus", level), "item_polish mythic Lv.%d" % level)
	_expect(not is_equal_approx(RuntimePerkProgression.get_value("kick_enhance", "authored_precision_pct", 5), RuntimePerkProgression.get_value("kick_enhance", "runtime_aim_gain", 5)), "kick authored/runtime lanes must remain explicitly distinct")
	_expect(not is_equal_approx(RuntimePerkProgression.get_value("item_polish", "general_amplify", 5), RuntimePerkProgression.get_value("item_polish", "mythic_roll_bonus", 5)), "item_polish general/mythic lanes must remain explicitly distinct")


func _test_elixir_candidate_equivalence() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var all_data: Dictionary = catalog.get_all_perk_data()
	var held_levels: Dictionary = {}
	var legacy_ids: Dictionary = {}
	for perk_id_value in all_data.keys():
		var perk_id := str(perk_id_value)
		var data: Dictionary = all_data[perk_id]
		if int(data.get("max_level", 0)) >= 5:
			held_levels[perk_id] = 1
			legacy_ids[perk_id] = true
	var runtime: Object = ElixirOfMasteryRuntime.new()
	var current_ids := _candidate_id_set(runtime.get_eligible_perks(held_levels, [all_data]))
	var intended_ids := RuntimePerkProgression.TARGET_PERK_IDS.duplicate()
	intended_ids.merge(RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS, true)
	_expect(legacy_ids == intended_ids and legacy_ids.size() == 47, "eb116e595 literal policy must resolve to exactly 37 Mugong + 10 training ids")
	_expect(current_ids == legacy_ids, "catalog-derived Elixir candidates must be identical in S2")

	# Forward negative leg: lowering only the 37 fixture caps to 3 must retain
	# those candidates, while the retired literal >=5 predicate loses all 37.
	var future_data: Dictionary = all_data.duplicate(true)
	for perk_id_value in RuntimePerkProgression.TARGET_PERK_IDS.keys():
		(future_data[perk_id_value] as Dictionary)["max_level"] = 3
	var future_ids := _candidate_id_set(runtime.get_eligible_perks(held_levels, [future_data]))
	var retired_literal_ids: Dictionary = {}
	for perk_id_value in future_data.keys():
		if int((future_data[perk_id_value] as Dictionary).get("max_level", 0)) >= 5 and int(held_levels.get(perk_id_value, 0)) < 5:
			retired_literal_ids[str(perk_id_value)] = true
	_expect(future_ids == intended_ids, "catalog-derived Elixir policy must retain all 47 ids after the 37 caps become 3")
	_expect(retired_literal_ids.size() == 10, "negative literal fixture must demonstrate the silent 37-candidate loss")


func _test_corrupted_fixture_goes_red() -> void:
	var corrupted: Dictionary = RuntimePerkProgression.PROGRESSIONS.duplicate(true)
	var values: Array = (((corrupted["dash_acceleration"] as Dictionary)["lanes"] as Dictionary)["vertical_scale_bonus"] as Dictionary)["values"]
	values[4] = 999.0
	var red_count := _count_index_mismatches(corrupted)
	_expect(red_count > 0, "deliberately corrupted in-memory ceiling fixture must go RED")


func _test_real_snapshot_projection() -> void:
	var state: Object = load("res://scripts/characters/runtime_perk_state.gd").new()
	state.runtime_skill_levels["item_luck"] = 5
	state.item_perk_level_bonus = 1
	var snapshot: Dictionary = state.get_snapshot()
	var projection: Dictionary = snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	_expect(not (projection.get("entries", []) as Array).is_empty(), "real get_snapshot must carry fusion display projection for owned perks")
	_expect(int((snapshot.get("effective_runtime_skill_levels", {}) as Dictionary).get("item_luck", 0)) == 6, "real snapshot must carry item_luck effective Lv.6")
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(state.runtime_skill_levels, RuntimePerkCatalog.new(), state, snapshot)
	var projected_description := ""
	for entry_value in acquired:
		var entry: Dictionary = entry_value as Dictionary
		if str(entry.get("_draw_id", entry.get("id", ""))) == "item_luck":
			projected_description = str(entry.get("description", ""))
			break
	_expect(projected_description == RuntimePerkOverflowDescriptions.generate_stats_text("item_luck", 6), "real projection branch must consume canonical Lv.6 description, got: %s" % projected_description)


func _count_index_mismatches(index: Dictionary) -> int:
	var count := 0
	for perk_id_value in LEGACY_LANES.keys():
		var perk_id := str(perk_id_value)
		for lane_id_value in (LEGACY_LANES[perk_id] as Dictionary).keys():
			var lane_id := str(lane_id_value)
			for level in range(1, 13):
				var actual := RuntimePerkProgression.get_value_from_index(index, perk_id, lane_id, level)
				if not is_equal_approx(actual, _legacy_value(perk_id, lane_id, level)):
					count += 1
	return count


func _legacy_value(perk_id: String, lane_id: String, level: int) -> float:
	var spec: Dictionary = (LEGACY_LANES[perk_id] as Dictionary)[lane_id]
	var values: Array = spec["v"]
	if level <= values.size():
		return float(values[level - 1])
	var mode := str(spec.get("m", LINEAR))
	var value := float(values[values.size() - 1])
	if mode == STAIRCASE:
		var every := int(spec.get("every", 1))
		var origin := int(spec.get("origin", values.size()))
		var steps := maxi(0, int(floor(float(level - origin) / float(every))))
		steps = mini(steps, int(spec.get("steps", steps)))
		value += float(spec.get("s", 0.0)) * float(steps)
	elif mode != HOLD:
		var step := float(spec.get("s", (float(values[-1]) - float(values[0])) / float(values.size() - 1)))
		value += step * float(level - values.size())
	if spec.has("lo"):
		value = maxf(value, float(spec["lo"]))
	if spec.has("hi"):
		value = minf(value, float(spec["hi"]))
	return value


func _candidate_id_set(candidates: Array) -> Dictionary:
	var result: Dictionary = {}
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		result[str(candidate.get("id", ""))] = true
	return result


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[str(value)] = true
	return result


func _expect_close(actual: float, expected: float, context: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s expected=%s actual=%s" % [context, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("runtime_perk_progression_equivalence_smoke FAIL: " + message)
