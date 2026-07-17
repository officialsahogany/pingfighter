extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")

var _failures: Array[String] = []
var _catalog := RuntimePerkCatalog.new()


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_converted_option_hooks_reach_item_runtime()
	_verify_integer_penalty_requantizes_after_effective_level_growth()
	_verify_central_penalties_reach_production_getters()
	_verify_polish_limit_break_and_penalty_reach_amplification()
	_verify_common_bonus_hook_and_limit_break_stack()
	_verify_live_hover_projection_tracks_effective_level_growth()
	_verify_golden_trajectory_caps_actual_modified_gold()
	_verify_laurel_limit_break_reaches_leaf_count()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_fusion_value_hooks_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_converted_option_hooks_reach_item_runtime() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"sensor": 5, "star_detector": 5}
	var created: Dictionary = state.commit_perk_fusion(
		["star_detector", "sensor"],
		{
			"outcome": "side_effect",
			"option_penalties": {
				"star_detector": {"star_bonus_pct": {"multiplier": 0.8}},
				"sensor": {
					"auto_dash_cooldown_sec": {
						"multiplier": 1.2,
						"adjusted_value": 18.0,
					},
				},
			},
			"deleted_options": {"sensor": ["auto_dash_token_count"]},
		},
		_catalog
	)
	_expect(not created.is_empty(), "converted fixture fusion should commit")
	_expect_close(
		PerkConversionValues.get_value("star_detector", "star_bonus_pct", 5),
		25.0,
		"three-argument conversion lookup must stay backward-compatible"
	)
	_expect_close(
		PerkConversionValues.get_value("star_detector", "star_bonus_pct", 5, state),
		20.0,
		"forward converted benefit should apply its fusion multiplier"
	)
	_expect_close(
		PerkConversionValues.get_value("sensor", "auto_dash_cooldown_sec", 5, state),
		18.0,
		"reverse cooldown should use the committed adverse adjusted value"
	)
	_expect_close(
		PerkConversionValues.get_value("sensor", "auto_dash_token_count", 5, state),
		0.0,
		"deleted converted option should resolve to zero"
	)

	# Exercise shipped item consumers, not only the table helper. All converted
	# item helpers route through MythicItemRuntime.get_converted_perk_value().
	var item_runtime := MythicItemRuntime.new()
	item_runtime.get_snapshot()
	item_runtime.runtime_perk_state_ref = state
	_expect_close(
		item_runtime.get_star_detector_star_bonus_pct(),
		20.0,
		"production star detector consumer should receive the lowered value"
	)
	_expect_close(
		item_runtime.get_sensor_cooldown_seconds(),
		18.0,
		"production sensor consumer should receive the higher adverse cooldown"
	)
	_expect(
		item_runtime.get_sensor_auto_dash_token_capacity() == 0,
		"production sensor consumer should honor a deleted option"
	)

	var snapshot: Dictionary = state.get_perk_fusion_snapshot()
	var snapshot_records: Array = snapshot.get("records", []) as Array
	((snapshot_records[0] as Dictionary).get("option_penalties", {}) as Dictionary).clear()
	_expect_close(
		state.apply_perk_fusion_option_value("star_detector", "star_bonus_pct", 25.0),
		20.0,
		"mutating a returned snapshot must not mutate live option overlays"
	)
	state.reset()
	_expect_close(
		PerkConversionValues.get_value("star_detector", "star_bonus_pct", 5, state),
		25.0,
		"full reset should remove converted option overlays"
	)


func _verify_common_bonus_hook_and_limit_break_stack() -> void:
	var penalty_state := RuntimePerkState.new()
	penalty_state.runtime_skill_levels = {"common_bulk_up": 5, "item_luck": 5}
	var penalty_record: Dictionary = penalty_state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{
			"outcome": "side_effect",
			"option_penalties": {
				"item_luck": {"runtime_skill_bonus": {"multiplier": 0.5}},
			},
		},
		_catalog
	)
	_expect(not penalty_record.is_empty(), "common bonus fixture fusion should commit")
	_expect_close(
		penalty_state.get_runtime_skill_bonus("item_luck"),
		0.30,
		"common item_luck bonus should be adjusted after central bonus resolution"
	)

	var untouched_state := RuntimePerkState.new()
	untouched_state.runtime_skill_levels = {"item_luck": 5}
	_expect_close(
		untouched_state.get_runtime_skill_bonus("item_luck"),
		0.60,
		"a perk without a fusion record should remain unchanged"
	)

	var level_state := RuntimePerkState.new()
	level_state.runtime_skill_levels = {"sensor": 5, "star_detector": 5}
	level_state.set_item_perk_level_bonus(2)
	var level_record: Dictionary = level_state.commit_perk_fusion(
		["sensor", "star_detector"],
		{
			"outcome": "byproduct",
			"byproducts": ["limit_break"],
			"byproduct_payloads": {
				"limit_break": {"eligible_sources": ["sensor", "star_detector"]},
			},
		},
		_catalog
	)
	_expect(not level_record.is_empty(), "limit-break fixture fusion should commit")
	_expect(
		level_state.get_converted_perk_effect_level("star_detector") == 8,
		"limit break +1 should stack with the existing +2 effective-level bonus"
	)
	_expect(
		level_state.get_runtime_skill_level("star_detector") == 8,
		"ordinary effective-level query should include the same explicit +1"
	)
	var effective_levels: Dictionary = level_state.get_effective_runtime_skill_levels()
	_expect(
		int(effective_levels.get("star_detector", 0)) == 8,
		"effective-level projection should include limit break"
	)
	level_state.reset()
	_expect(
		level_state.get_perk_fusion_effective_level_bonus("star_detector") == 0,
		"full reset should remove limit-break overlays"
	)


func _verify_live_hover_projection_tracks_effective_level_growth() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
	var record: Dictionary = state.commit_perk_fusion(
		["item_luck", "common_bulk_up"],
		{
			"outcome": "side_effect",
			"commit_value_snapshots": {
				"item_luck": {"runtime_skill_bonus": {"value": 0.60, "polarity": "forward", "value_kind": "float"}},
			},
			"option_penalties": {
				"item_luck": {"runtime_skill_bonus": _float_central_penalty(0.60, 0.48)},
			},
		},
		_catalog
	)
	_expect(not record.is_empty(), "live-hover fixture fusion should commit")
	var before_projection: Dictionary = state.get_perk_fusion_display_projection(_catalog)
	var before_entry := _find_projection_entry(before_projection, "fusion_0")
	var before_live := _live_option(before_entry, "item_luck", "runtime_skill_bonus")
	_expect_close(float(before_live.get("adjusted_value", 0.0)), state.get_runtime_skill_bonus("item_luck"), "live hover adjusted value should equal the production central getter")
	var immutable_before := (before_entry.get("record_payload", {}) as Dictionary).duplicate(true)

	state.set_item_perk_level_bonus(2)
	var after_projection: Dictionary = state.get_perk_fusion_display_projection(_catalog)
	var after_entry := _find_projection_entry(after_projection, "fusion_0")
	var after_live := _live_option(after_entry, "item_luck", "runtime_skill_bonus")
	_expect(float(after_live.get("value", 0.0)) > float(before_live.get("value", 0.0)), "live hover base value should grow after an effective-level bonus")
	_expect_close(float(after_live.get("adjusted_value", 0.0)), state.get_runtime_skill_bonus("item_luck"), "grown live hover value should still match the production central getter without double penalty")
	_expect((after_entry.get("record_payload", {}) as Dictionary) == immutable_before, "effective-level growth must not mutate the immutable commit result record")
	var presented := CharacterInfoOverlayPerkPresenter.build_acquired_perks_from_projection(
		after_projection.get("entries", []) as Array,
		_catalog,
		{},
		Color.CORNFLOWER_BLUE,
		Color.GOLD
	)
	var fusion_presented: Dictionary = {}
	for entry_value: Variant in presented:
		if entry_value is Dictionary and str((entry_value as Dictionary).get("id", "")) == "fusion_0":
			fusion_presented = entry_value as Dictionary
			break
	_expect(str(fusion_presented.get("description", "")).contains(PerkFusionLocalization.option_value_text("runtime_skill_bonus", after_live.get("adjusted_value", 0.0))), "TAB tooltip should consume the live adjusted option payload")


func _verify_golden_trajectory_caps_actual_modified_gold() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"common_bulk_up": 5, "common_swiftness": 5}
	var record: Dictionary = state.commit_perk_fusion(
		["common_bulk_up", "common_swiftness"],
		{"outcome": "byproduct", "byproducts": ["golden_trajectory"]},
		_catalog
	)
	_expect(not record.is_empty(), "golden-trajectory cap fixture should commit")
	state.set_item_gold_gain_multiplier(10.0)
	state.set_viper_ignition_aura_active(true)
	var first_award := state.award_perk_fusion_wall_bounce_gold({}, {})
	_expect(first_award == 40, "gold modifiers should be applied before clamping Golden Trajectory to the remaining actual-gold budget")
	_expect(state.gold_from_perks == 40, "Golden Trajectory must award at most 40 actual gold in the round")
	_expect(state.get_perk_fusion_round_golden_trajectory_gold() == 40, "Golden Trajectory cap counter should track actual stored gold")
	_expect(state.award_perk_fusion_wall_bounce_gold({}, {}) == 0, "wall bounces after the actual-gold cap must award nothing")
	_expect(state.gold_from_perks == 40, "post-cap bounces must not exceed 40 actual gold")


func _verify_laurel_limit_break_reaches_leaf_count() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"perk_laurel_shield": 5, "common_bulk_up": 5}
	var context: Dictionary = state._build_perk_fusion_result_context(
		["perk_laurel_shield", "common_bulk_up"],
		_catalog
	)
	_expect((context.get("limit_break_eligible_sources", []) as Array).has("perk_laurel_shield"), "Laurel Leaf should enter the contextual Limit Break payload pool")
	var record: Dictionary = state.commit_perk_fusion(
		["perk_laurel_shield", "common_bulk_up"],
		{
			"outcome": "byproduct",
			"byproducts": ["limit_break"],
			"byproduct_payloads": {"limit_break": {"eligible_sources": ["perk_laurel_shield"]}},
		},
		_catalog
	)
	_expect(not record.is_empty(), "Laurel Limit Break production fixture should commit")
	_expect(state.get_laurel_leaf_count() == 6, "Laurel Limit Break should reach the production leaf-count getter as effective Lv.6")


func _verify_integer_penalty_requantizes_after_effective_level_growth() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels = {"shrapnel_armor": 5, "sensor": 5}
	var record: Dictionary = state.commit_perk_fusion(
		["shrapnel_armor", "sensor"],
		{
			"outcome": "side_effect",
			"option_penalties": {
				"shrapnel_armor": {
					"shard_count": {
						"original_value": 8,
						"adjusted_value": 6,
						"nominal_pct": 25.0,
						"multiplier": 0.75,
						"polarity": "forward",
						"value_kind": "int",
					},
				},
			},
		},
		_catalog
	)
	_expect(not record.is_empty(), "integer live-requantization fixture fusion should commit")
	_expect_close(
		PerkConversionValues.get_value("shrapnel_armor", "shard_count", 5, state),
		6.0,
		"commit-level integer value should match its immutable S4 preview"
	)
	state.set_item_perk_level_bonus(2)
	var grown_base := PerkConversionValues.get_value("shrapnel_armor", "shard_count", 7)
	var grown_adjusted := PerkConversionValues.get_value("shrapnel_armor", "shard_count", 7, state)
	var realized_penalty := (grown_base - grown_adjusted) / grown_base
	_expect_close(grown_base, 10.0, "fixture should exercise real Lv.7 overflow growth")
	_expect_close(grown_adjusted, 8.0, "live integer lane should requantize against the grown value")
	_expect(
		realized_penalty >= 0.10 and realized_penalty <= 0.30,
		"live integer penalty must remain strictly inside the promised 10-30 percent band"
	)
	var stored_record: Dictionary = (state.get_perk_fusion_snapshot().get("records", []) as Array)[0]
	var stored_penalty: Dictionary = (((stored_record.get("option_penalties", {}) as Dictionary).get("shrapnel_armor", {}) as Dictionary).get("shard_count", {}) as Dictionary)
	_expect(
		int(stored_penalty.get("adjusted_value", 0)) == 6,
		"live requantization must not rewrite the immutable S4 commit log"
	)


func _verify_central_penalties_reach_production_getters() -> void:
	var item_speed_state: Object = _central_penalty_state(
		["item_luck", "common_swiftness"],
		{
			"item_luck": _float_central_penalty(0.60, 0.30),
			"common_swiftness": _float_central_penalty(0.30, 0.15),
		}
	)
	_expect(item_speed_state != null, "item/speed production fixture should commit")
	_expect(item_speed_state.get_item_spawn_delay_msec(10000) == 7000, "item_luck fusion penalty must reach the real spawn-delay getter")
	_expect_close(item_speed_state.get_player_speed_multiplier(), 1.15, "common_swiftness fusion penalty must reach the real movement getter")

	var body_training_state: Object = _central_penalty_state(
		["common_bulk_up", "common_training"],
		{
			"common_bulk_up": _float_central_penalty(0.30, 0.15),
			"common_training": _float_central_penalty(0.40, 0.20),
		}
	)
	_expect_close(body_training_state.get_player_paddle_size_multiplier(), 1.15, "common_bulk_up penalty must reach the real paddle-size getter")
	_expect_close(body_training_state.get_player_skill_cooldown_seconds(10.0), 8.0, "common_training penalty must reach the real skill cooldown getter")

	var cooldown_duration_state: Object = _central_penalty_state(
		["item_cooldown_mastery", "item_caffeine"],
		{
			"item_cooldown_mastery": _float_central_penalty(0.65, 0.325),
			"item_caffeine": _float_central_penalty(1.50, 0.75),
		}
	)
	_expect(cooldown_duration_state.get_active_item_cooldown_msec(10000) == 6750, "item cooldown penalty must reach the real cooldown getter")
	_expect_close(cooldown_duration_state.get_active_item_duration_multiplier(), 1.75, "Caffeine penalty must reach the real duration getter")
	_expect_close(cooldown_duration_state.get_active_item_duration_frames(100.0), 175.0, "Caffeine penalty must reach duration-frame consumers")

	var gauge_slot_state: Object = _central_penalty_state(
		["item_gauge_mastery", "item_bag_expansion"],
		{
			"item_gauge_mastery": _float_central_penalty(75.0, 60.0),
			"item_bag_expansion": _integer_central_penalty(5, 4, 20.0),
		}
	)
	_expect_close(gauge_slot_state.get_active_item_use_gauge_bonus(), 60.0, "item gauge penalty must reach the real use-gauge getter")
	_expect(gauge_slot_state.get_active_item_slot_capacity(3) == 7, "bag expansion integer penalty must preserve its quantized four-slot bonus")
	gauge_slot_state.set_item_perk_level_bonus(2)
	var grown_slot_bonus: int = int(gauge_slot_state.get_active_item_slot_capacity(3)) - 3
	var grown_slot_penalty := float(7 - grown_slot_bonus) / 7.0
	_expect(grown_slot_bonus == 6, "Lv.7 bag expansion should requantize to a six-slot bonus")
	_expect(grown_slot_penalty >= 0.10 and grown_slot_penalty <= 0.30, "Lv.6+ bag expansion must stay in the actual 10-30 percent penalty band")

	var recycle_laurel_state: Object = _central_penalty_state(
		["item_recycle", "perk_laurel_shield"],
		{
			"item_recycle": _float_central_penalty(0.35, 0.28),
			"perk_laurel_shield": _integer_central_penalty(5, 4, 20.0),
		}
	)
	_expect_close(recycle_laurel_state.get_active_item_recycle_chance(), 0.28, "recycle penalty must reach the real chance getter")
	_expect(recycle_laurel_state.get_laurel_leaf_count() == 4, "laurel integer penalty must reach the real leaf-count getter")


func _verify_polish_limit_break_and_penalty_reach_amplification() -> void:
	var penalized: Object = _central_penalty_state(
		["item_polish", "item_luck"],
		{"item_polish": _float_central_penalty(0.60, 0.48)}
	)
	_expect_close(penalized.get_base_polish_multiplier(), 1.48, "Polish fusion scar should reach the base item-roll multiplier")
	_expect_close(penalized.get_effective_polish_multiplier(), 1.48, "Polish fusion scar should reach the effective item-roll multiplier")
	_expect_close(penalized._get_perk_amplify_multiplier("common_swiftness"), 1.20, "Polish fusion scar should proportionally reduce its perk amplifier")

	var limit_break_state := RuntimePerkState.new()
	limit_break_state.runtime_skill_levels = {"item_polish": 5, "common_bulk_up": 5}
	var record: Dictionary = limit_break_state.commit_perk_fusion(
		["item_polish", "common_bulk_up"],
		{
			"outcome": "byproduct",
			"byproducts": ["limit_break"],
			"byproduct_payloads": {"limit_break": {"eligible_sources": ["item_polish"]}},
		},
		_catalog
	)
	_expect(not record.is_empty(), "Polish limit-break production fixture should commit")
	_expect_close(limit_break_state._get_perk_amplify_multiplier("common_swiftness"), 1.30, "Polish Lv.6 should amplify eligible perks by 30 percent")
	_expect_close(limit_break_state.get_effective_polish_multiplier(), 1.72, "Polish Lv.6 should extend the item-roll multiplier past the authored table")


func _central_penalty_state(source_ids: Array, penalties_by_perk: Dictionary) -> Object:
	var state := RuntimePerkState.new()
	for source_value: Variant in source_ids:
		state.runtime_skill_levels[str(source_value)] = 5
	var option_penalties: Dictionary = {}
	for perk_id_value: Variant in penalties_by_perk.keys():
		option_penalties[str(perk_id_value)] = {
			"runtime_skill_bonus": (penalties_by_perk.get(perk_id_value, {}) as Dictionary).duplicate(true),
		}
	var record: Dictionary = state.commit_perk_fusion(
		source_ids,
		{"outcome": "side_effect", "option_penalties": option_penalties},
		_catalog
	)
	return state if not record.is_empty() else null


func _float_central_penalty(before: float, after: float) -> Dictionary:
	return {
		"original_value": before,
		"adjusted_value": after,
		"multiplier": after / before,
		"polarity": "forward",
		"value_kind": "float",
	}


func _integer_central_penalty(before: int, after: int, nominal_pct: float) -> Dictionary:
	return {
		"original_value": before,
		"adjusted_value": after,
		"nominal_pct": nominal_pct,
		"multiplier": float(after) / float(before),
		"polarity": "forward",
		"value_kind": "int",
	}


func _find_projection_entry(projection: Dictionary, fusion_id: String) -> Dictionary:
	for entry_value: Variant in projection.get("entries", []):
		if entry_value is Dictionary and str((entry_value as Dictionary).get("fusion_id", "")) == fusion_id:
			return entry_value as Dictionary
	return {}


func _live_option(entry: Dictionary, perk_id: String, option_key: String) -> Dictionary:
	var live_options: Dictionary = entry.get("live_source_options", {}) as Dictionary
	var perk_options: Dictionary = live_options.get(perk_id, {}) as Dictionary
	return perk_options.get(option_key, {}) as Dictionary


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (actual=%s expected=%s)" % [message, actual, expected])
