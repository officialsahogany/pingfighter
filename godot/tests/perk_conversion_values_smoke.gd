extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const REVERSE_VALUE_KEYS := {
	"auto_dash_cooldown_sec": true,
	"gauge_cost": true,
	"soul_burst_gauge_cost": true,
}

const DELETED_ITEM_EXPECTED := {
	"dashholder": ["dash_amplification"],
	"speedboots": ["common_swiftness"],
	"bulkup": ["common_bulk_up"],
	"spikeboots": ["dash_module_control", "dash_lightweight"],
	"dashgear": ["dash_jump", "perk_boost_charge"],
	"cooltime": ["item_cooldown_mastery"],
	"timer_belt": ["common_training"],
	"slot_add": ["item_bag_expansion"],
}


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var player_pos := Vector2(302.5, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var special_gauge := 100.0
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true


class FakeRegistry:
	extends RefCounted

	var runtime: Object

	func _init(runtime_ref: Object) -> void:
		runtime = runtime_ref

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return runtime
		return null


var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	_verify_regular_tables()
	_verify_star_endpoints()
	_verify_mythic_values_and_exempt()
	_verify_non_exempt_effective_level_parity()
	_verify_flags()
	_verify_conversion_maps()
	_verify_flag_toggle_does_not_change_existing_runtime()

	PerkConversionFlags.debug_set_enabled(false)
	if _failures.is_empty():
		print("perk_conversion_values_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_regular_tables() -> void:
	_expect(RuntimePerkCatalog.CONVERTED_PERKS.size() == 28, "converted regular perk count should include the R1 redesign perks")
	for id_value in RuntimePerkCatalog.CONVERTED_PERKS.keys():
		var id := str(id_value)
		_expect(PerkConversionValues.has_perk(id), "value helper should know regular converted perk %s" % id)
		_expect(PerkConversionValues.CONVERTED_PERK_VALUES.has(id), "regular converted perk %s should have a value table" % id)
		var max_level := int(RuntimePerkCatalog.CONVERTED_PERKS[id].get("max_level", 0))
		var table: Dictionary = PerkConversionValues.CONVERTED_PERK_VALUES.get(id, {})
		_expect(not table.is_empty(), "regular converted perk %s should expose at least one value key" % id)
		for key_value in table.keys():
			var key := str(key_value)
			var values: Array = table[key]
			_expect(values.size() == max_level, "%s.%s should have one value per max level" % [id, key])
			_expect(_is_monotonic(values, bool(REVERSE_VALUE_KEYS.get(key, false))), "%s.%s should be monotonic in the expected direction" % [id, key])


func _verify_star_endpoints() -> void:
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 1), 5.0, "star_detector Lv1 endpoint")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 5), 25.0, "star_detector Lv5 endpoint")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 0), 5.0, "get_value should clamp low levels")
	_expect_close(PerkConversionValues.get_value("star_detector", "star_bonus_pct", 99), 25.0, "get_value should clamp high levels")

	_expect_close(PerkConversionValues.get_value("adversity_armor", "trigger_chance_pct", 1), 20.0, "adversity_armor trigger Lv1")
	_expect_close(PerkConversionValues.get_value("adversity_armor", "trigger_chance_pct", 5), 40.0, "adversity_armor trigger Lv5")
	_expect_close(PerkConversionValues.get_value("adversity_armor", "invincible_duration_sec", 1), 5.0, "adversity_armor duration Lv1")
	_expect_close(PerkConversionValues.get_value("adversity_armor", "invincible_duration_sec", 5), 15.0, "adversity_armor duration Lv5")

	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_knockback_pct", 1), 20.0, "boomerang knockback Lv1")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_knockback_pct", 5), 50.0, "boomerang knockback Lv5")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_stun_pct", 1), 20.0, "boomerang stun Lv1")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_stun_pct", 5), 80.0, "boomerang stun Lv5")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_launch_speed_pct", 1), 15.0, "boomerang launch Lv1")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_launch_speed_pct", 5), 50.0, "boomerang launch Lv5")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_homing_pct", 1), 10.0, "boomerang homing Lv1")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_homing_pct", 5), 50.0, "boomerang homing Lv5")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_spawn_bonus_pct", 1), 50.0, "boomerang spawn Lv1")
	_expect_close(PerkConversionValues.get_value("reinforced_boomerang_gauntlet", "boomerang_spawn_bonus_pct", 5), 200.0, "boomerang spawn Lv5")

	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_token_count", 1), 1.0, "sensor token Lv1")
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_token_count", 5), 2.0, "sensor token Lv5")
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_cooldown_sec", 1), 30.0, "sensor cooldown Lv1")
	_expect_close(PerkConversionValues.get_value("sensor", "auto_dash_cooldown_sec", 5), 15.0, "sensor cooldown Lv5")

	_expect_close(PerkConversionValues.get_value("dowsing_goggles", "bonus_perk_chance", 1), 40.0, "dowsing_goggles chance Lv1")
	_expect_close(PerkConversionValues.get_value("dowsing_goggles", "bonus_perk_chance", 3), 100.0, "dowsing_goggles chance Lv3")

	_expect_close(PerkConversionValues.get_value("sage_ring", "perk_level_bonus", 1), 1.0, "sage_ring level bonus Lv1")
	_expect_close(PerkConversionValues.get_value("sage_ring", "perk_level_bonus", 3), 3.0, "sage_ring level bonus Lv3")
	_expect_close(PerkConversionValues.get_value("sage_ring", "sage_speed_penalty_pct", 3), 24.0, "sage_ring speed penalty Lv3")
	_expect_close(PerkConversionValues.get_value("sage_ring", "sage_body_penalty_pct", 3), 18.0, "sage_ring body penalty Lv3")


func _verify_mythic_values_and_exempt() -> void:
	_expect(RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size() == 12, "converted mythic perk count should include Great Laurel")
	for id_value in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		var id := str(id_value)
		_expect(PerkConversionValues.has_perk(id), "value helper should know mythic converted perk %s" % id)
		var keys: Array = PerkConversionValues.get_value_keys(id)
		_expect(not keys.is_empty(), "mythic converted perk %s should expose fixed value keys" % id)
		for key_value in keys:
			_expect(PerkConversionValues.get_mythic_value(id, str(key_value)) > 0.0, "mythic converted perk %s.%s should have a fixed value" % [id, str(key_value)])
		_expect(
			PerkConversionValues.get_effective_converted_perk_level(id, 1, 2) == 1,
			"mythic converted perk %s should ignore effective-level bonus sources" % id
		)


func _verify_non_exempt_effective_level_parity() -> void:
	var state := RuntimePerkState.new()
	state.runtime_skill_levels["star_detector"] = 2
	state.set_item_perk_level_bonus(2)
	_expect(
		PerkConversionValues.get_effective_converted_perk_level("star_detector", 2, 2) == state.get_runtime_skill_level("star_detector"),
		"regular converted perks should sum bonus levels like the existing runtime chain"
	)
	_expect(
		PerkConversionValues.get_effective_converted_perk_level("star_detector", 0, 2) == state.get_runtime_skill_level("missing_star_detector"),
		"base level 0 should stay 0 even when bonus sources exist"
	)


func _verify_flags() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_expect(not PerkConversionFlags.is_enabled(), "conversion flag should default/remain OFF")
	PerkConversionFlags.debug_set_enabled(true)
	_expect(PerkConversionFlags.is_enabled(), "debug_set_enabled(true) should turn the conversion flag ON")
	PerkConversionFlags.debug_set_enabled(false)
	_expect(not PerkConversionFlags.is_enabled(), "debug_set_enabled(false) should turn the conversion flag back OFF")


func _verify_conversion_maps() -> void:
	_expect(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.size() == 40, "conversion source map should include S1 replacements plus R1 redesign perks")
	for id_value in RuntimePerkCatalog.CONVERTED_PERKS.keys():
		var id := str(id_value)
		_expect(str(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get(id, "")) == id, "regular conversion source %s should map to itself" % id)
	for id_value in RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.keys():
		var id := str(id_value)
		_expect(str(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get(id, "")) == id, "mythic conversion source %s should map to itself" % id)
	for deleted_id in DELETED_ITEM_EXPECTED.keys():
		_expect(
			_arrays_equal(PerkConversionValues.DELETED_ITEM_COMPENSATION.get(deleted_id, []), DELETED_ITEM_EXPECTED[deleted_id]),
			"deleted item compensation for %s should match the migration plan" % str(deleted_id)
		)
	_expect(not PerkConversionValues.CONVERSION_SOURCE_TO_PERK.has("gold_bar"), "gold_bar should stay deleted without a replacement mapping")
	for redesign_id in ["gold_bar", "sage_ring", "sacred_laurel", "dowsing_goggles"]:
		_expect(not PerkConversionValues.DELETED_ITEM_COMPENSATION.has(redesign_id), "%s should not enter deleted compensation" % redesign_id)
	for redesign_id in ["sage_ring", "sacred_laurel", "dowsing_goggles"]:
		_expect(str(PerkConversionValues.CONVERSION_SOURCE_TO_PERK.get(redesign_id, "")) == redesign_id, "%s should map to its redesign perk id" % redesign_id)


func _verify_flag_toggle_does_not_change_existing_runtime() -> void:
	var off_snapshot: Dictionary = _capture_existing_runtime_snapshot(false)
	var on_snapshot: Dictionary = _capture_existing_runtime_snapshot(true)
	PerkConversionFlags.debug_set_enabled(false)
	_expect(_snapshots_equal(off_snapshot, on_snapshot), "conversion flag ON/OFF should not change non-replacement item runtime results")


func _capture_existing_runtime_snapshot(flag_enabled: bool) -> Dictionary:
	PerkConversionFlags.debug_set_enabled(flag_enabled)
	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	_expect(
		int(runtime.acquire_item(
			"gold_bar",
			owner,
			registry,
			{},
			false,
			false
		)) >= 0,
		"fixture Gold Bar should acquire"
	)
	_expect(
		runtime.equip_item(
			"dashgear",
			owner,
			registry,
			{
				"dash_distance_pct": 28.0,
				"boost_charge_pct": 44.0,
			},
			false
		),
		"fixture Dash Gear should equip"
	)
	return {
		"flag_enabled": PerkConversionFlags.is_enabled(),
		"gold_bar_count": runtime.get_gold_bar_count(),
		"gold_bar_sell_price": runtime.get_gold_bar_total_sell_price(),
		"gold_bar_speed_penalty_pct": runtime.get_gold_bar_speed_penalty_pct(),
		"gold_bar_speed_multiplier": runtime.get_gold_bar_speed_multiplier(),
		"dashgear_dash_distance_bonus_pct": runtime.get_dashgear_dash_distance_bonus_pct(),
		"dashgear_boost_charge_chance_pct": runtime.get_dashgear_boost_charge_chance_pct(),
	}


func _is_monotonic(values: Array, reverse: bool) -> bool:
	for index in range(1, values.size()):
		var previous := float(values[index - 1])
		var current := float(values[index])
		if reverse:
			if current > previous + 0.0001:
				return false
		elif current + 0.0001 < previous:
			return false
	return true


func _snapshots_equal(a: Dictionary, b: Dictionary) -> bool:
	for key_value in a.keys():
		var key := str(key_value)
		if key == "flag_enabled":
			continue
		if not b.has(key):
			return false
		if abs(float(a[key]) - float(b[key])) > 0.0001:
			return false
	return true


func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if str(a[index]) != str(b[index]):
			return false
	return true


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
