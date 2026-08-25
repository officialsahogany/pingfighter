extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const BATCH1_CASES := [
	{"id": "star_detector", "key": "star_bonus_pct", "fixture": 20.0, "getter": "get_star_detector_star_bonus_pct"},
	{"id": "dowsing_pendulum", "key": "attraction_range", "fixture": 248.0, "getter": "get_dowsing_pendulum_range"},
	{"id": "chargebag", "key": "chargebag_pct", "fixture": 200.0, "getter": "get_chargebag_wall_bounce_gauge_pct"},
	{"id": "battery", "key": "gauge_preserve_pct", "fixture": 40.0, "getter": "get_battery_gauge_preserve_pct"},
	{"id": "gold_digger", "key": "gold_bonus_pct", "fixture": 25.0, "getter": "get_gold_digger_gold_bonus_pct"},
	{"id": "lucky_coin", "key": "double_spawn_pct", "fixture": 17.0, "getter": "get_lucky_coin_double_spawn_pct"},
	{"id": "fuel_pouch", "key": "fuel_bonus_flat", "fixture": 100.0, "getter": "get_fuel_pouch_gauge_bonus"},
	{"id": "bluetooth_ring", "key": "gauge_gain_pct", "fixture": 25.0, "getter": "get_bluetooth_ring_gauge_gain_pct"},
	{"id": "knee_pads", "key": "knee_charge_pct", "fixture": 100.0, "getter": "get_knee_pads_charge_pct"},
	{"id": "bulletproof_hat", "converted_id": "bulletproof_hat", "converted_key": "posture_correction_pct", "key": "stun_resist_pct", "fixture": 20.0, "getter": "get_bulletproof_hat_stun_resist_pct"},
	{"id": "spiked_helmet", "converted_id": "bulletproof_hat", "converted_key": "posture_correction_pct", "key": "knockback_resist_pct", "fixture": 20.0, "getter": "get_spiked_helmet_knockback_resist_pct"},
]


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(302.5, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
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

	var mythic_runtime: Object
	var runtime_perk_state: Object
	var audio: Object

	func _init(runtime_ref: Object, state_ref: Object, audio_ref: Object = null) -> void:
		mythic_runtime = runtime_ref
		runtime_perk_state = state_ref
		audio = audio_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"game_audio":
				return audio
		return null


class FakeActiveItemRuntime:
	extends RefCounted

	func is_aipill_active() -> bool:
		return false


class FakeDashState:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeFeedback:
	extends RefCounted

	var gauge_flash_count := 0
	var shake_count := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_count += 1


class FakeOrbHudState:
	extends RefCounted

	var gauge_spin_count := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		gauge_spin_count += 1


class FakeAudio:
	extends RefCounted

	var active_item_calls := 0

	func play_active_item() -> void:
		active_item_calls += 1


var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_off_flag_keeps_item_rolls()
	_verify_on_flag_uses_perk_levels()
	_verify_on_flag_level_zero_is_inactive()
	_verify_on_flag_item_only_is_inactive()
	_verify_on_flag_perk_replaces_item_without_max()
	_verify_effective_level_bonus_uses_shared_bridge()
	_verify_runtime_consumers_use_batch1_getters()
	_verify_fuel_pouch_choice_syncs_owner_gauge_max_immediately()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_gate_batch1_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_off_flag_keeps_item_rolls() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect(_equip_fixture(runtime, case_data), "OFF fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			float(case_data["fixture"]),
			"OFF should keep item roll for %s" % str(case_data["id"])
		)


func _verify_on_flag_uses_perk_levels() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		for level in [1, 5]:
			var converted_id := _converted_id(case_data)
			var converted_key := _converted_key(case_data)
			var runtime: Object = _make_runtime({converted_id: level})
			_expect_close(
				_read_case_value(runtime, case_data),
				PerkConversionValues.get_value(converted_id, converted_key, level),
				"ON should use Lv%d perk value for %s" % [level, str(case_data["id"])]
			)


func _verify_on_flag_level_zero_is_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect_close(
			_read_case_value(runtime, case_data),
			0.0,
			"ON level 0 should be inactive for %s" % str(case_data["id"])
		)


func _verify_on_flag_item_only_is_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect(_equip_fixture(runtime, case_data), "ON item-only fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			0.0,
			"ON item-only should not leak old item roll for %s" % str(case_data["id"])
		)


func _verify_on_flag_perk_replaces_item_without_max() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		var converted_id := _converted_id(case_data)
		var converted_key := _converted_key(case_data)
		var runtime: Object = _make_runtime({converted_id: 1})
		var high_item_roll := 500.0 if str(case_data["id"]) == "dowsing_pendulum" else 100.0
		_expect(_equip_case_roll(runtime, case_data, high_item_roll), "ON replacement fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			PerkConversionValues.get_value(converted_id, converted_key, 1),
			"ON should replace item roll instead of max/add for %s" % str(case_data["id"])
		)


func _verify_effective_level_bonus_uses_shared_bridge() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		var converted_id := _converted_id(case_data)
		var converted_key := _converted_key(case_data)
		var runtime: Object = _make_runtime({converted_id: 3}, 2)
		_expect(runtime.get_converted_perk_effect_level(converted_id) == 5, "bridge should expose base+bonus effective level for %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			PerkConversionValues.get_value(converted_id, converted_key, 5),
			"base 3 + bonus 2 should use Lv5 value for %s" % str(case_data["id"])
		)


func _verify_runtime_consumers_use_batch1_getters() -> void:
	PerkConversionFlags.debug_set_enabled(true)

	var chargebag_runtime: Object = _make_runtime({"chargebag": 5})
	var feedback := FakeFeedback.new()
	_expect_close(
		chargebag_runtime.apply_chargebag_wall_bounce_gauge(
			100.0,
			{"selected_character_type": "smasher", "gauge_max": 500.0},
			{"feedback": feedback, "active_item_runtime": FakeActiveItemRuntime.new()}
		),
		127.0,
		"ON Charge Bag perk should apply without the old item equipped gate"
	)
	_expect(feedback.gauge_flash_count == 1, "ON Charge Bag perk should trigger gauge feedback when it gains gauge")

	var bluetooth_runtime: Object = _make_runtime({"bluetooth_ring": 5})
	_expect_close(bluetooth_runtime.calculate_bluetooth_ring_gauge_charge(40.0), 49.6, "ON Bluetooth Ring perk should preserve fractional gauge without the old equipped gate")

	var gold_runtime: Object = _make_runtime({"gold_digger": 5})
	_expect(not gold_runtime.has_method("apply_gold_digger_gauge_bonus"), "ON Gold Digger perk should stay gold-only")
	_expect(gold_runtime.apply_gold_digger_gold_bonus(100) == 155, "ON Gold Digger perk should multiply direct gold without old equipped gate")

	var fuel_runtime: Object = _make_runtime({"fuel_pouch": 5})
	_expect_close(fuel_runtime.get_effective_special_gauge_max(500.0), 640.0, "ON Fuel Pouch perk should raise gauge max through the shared getter")

	var battery_runtime: Object = _make_runtime({"battery": 5})
	_expect_close(battery_runtime.get_stage_transition_gauge(250.0, 500.0, false), 250.0, "ON Battery Pack perk should preserve gauge through the shared getter")

	var knee_audio := FakeAudio.new()
	var knee_runtime: Object = _make_runtime({"knee_pads": 5}, 0, knee_audio)
	var knee_dash := FakeDashState.new()
	knee_dash.snapshot = {"is_half": true, "active": true, "timer": 4.0}
	var knee_feedback := FakeFeedback.new()
	var knee_orb := FakeOrbHudState.new()
	var knee_registry := FakeRegistry.new(knee_runtime, knee_runtime.runtime_perk_state_ref, knee_audio)
	var knee_result: Dictionary = knee_runtime.try_apply_knee_pads_player_hit(
		Vector2(360.0, 650.0),
		40.0,
		{"selected_character_type": "soldier", "gauge_max": 500.0},
		{
			"dash_state": knee_dash,
			"feedback": knee_feedback,
			"orb_hud_state": knee_orb,
			"registry": knee_registry,
		}
	)
	_expect(bool(knee_result.get("activated", false)), "ON Kick Charger perk should activate without old equipped gate")
	_expect_close(float(knee_result.get("charge_amount", 0.0)), 42.0, "ON Kick Charger Lv5 should charge 70% of Soldier base gauge")
	_expect(knee_audio.active_item_calls == 1, "ON Kick Charger activation should still use routed audio")

	var bulletproof_runtime: Object = _make_runtime({"bulletproof_hat": 5})
	_expect_close(bulletproof_runtime.get_player_stun_duration_seconds(1.5), 1.14, "ON Bulletproof Hat perk should feed stun duration math")
	_expect_close(bulletproof_runtime.get_player_knockback_resist_scale(), 0.76, "ON Iron Heart Art should feed the same posture correction into knockback math")

	var item_only_chargebag: Object = _make_runtime({})
	_expect(_equip_fixture(item_only_chargebag, _case_by_id("chargebag")), "item-only Charge Bag should equip")
	_expect_close(
		item_only_chargebag.apply_chargebag_wall_bounce_gauge(100.0, {"selected_character_type": "smasher", "gauge_max": 500.0}, {}),
		100.0,
		"ON item-only Charge Bag should stay inactive"
	)

	var item_only_bluetooth: Object = _make_runtime({})
	_expect(_equip_fixture(item_only_bluetooth, _case_by_id("bluetooth_ring")), "item-only Bluetooth Ring should equip")
	_expect_close(item_only_bluetooth.calculate_bluetooth_ring_gauge_charge(40.0), 40.0, "ON item-only Bluetooth Ring should stay inactive")

	var item_only_gold: Object = _make_runtime({})
	_expect(_equip_fixture(item_only_gold, _case_by_id("gold_digger")), "item-only Gold Digger should equip")
	_expect(not item_only_gold.has_method("apply_gold_digger_gauge_bonus"), "ON item-only Gold Digger should expose no gauge multiplier")

	var item_only_knee: Object = _make_runtime({})
	_expect(_equip_fixture(item_only_knee, _case_by_id("knee_pads")), "item-only Kick Charger should equip")
	var item_only_dash := FakeDashState.new()
	item_only_dash.snapshot = {"is_half": true, "active": true, "timer": 4.0}
	_expect(
		item_only_knee.try_apply_knee_pads_player_hit(
			Vector2(360.0, 650.0),
			40.0,
			{"selected_character_type": "soldier", "gauge_max": 500.0},
			{"dash_state": item_only_dash}
		).is_empty(),
		"ON item-only Kick Charger should stay inactive"
	)


func _verify_fuel_pouch_choice_syncs_owner_gauge_max_immediately() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var runtime: Object = MythicItemRuntime.new()
	runtime.get_snapshot()
	var state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	owner.special_gauge = 250.0
	owner.special_gauge_max = 500.0
	var registry := FakeRegistry.new(runtime, state)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)

	_expect(
		state.apply_choice({"id": "fuel_pouch", "name": "연료탱크", "max_level": 5}, owner, registry),
		"Fuel Pouch perk choice should apply"
	)
	_expect_close(
		owner.special_gauge_max,
		540.0,
		"Fuel Pouch choice should sync owner max gauge immediately"
	)
	_expect_close(
		owner.special_gauge,
		270.0,
		"Fuel Pouch immediate sync should preserve the current gauge ratio"
	)


func _make_runtime(levels: Dictionary, bonus: int = 0, audio: Object = null) -> Object:
	var runtime: Object = MythicItemRuntime.new()
	var state: Object = RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	state.set_item_perk_level_bonus(bonus)
	runtime.get_snapshot()
	var registry := FakeRegistry.new(runtime, state, audio)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return runtime


func _equip_fixture(runtime: Object, case_data: Dictionary) -> bool:
	return _equip_case_roll(runtime, case_data, float(case_data["fixture"]))


func _equip_case_roll(runtime: Object, case_data: Dictionary, roll_value: float) -> bool:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref)
	return bool(runtime.equip_item(
		str(case_data["id"]),
		owner,
		registry,
		{str(case_data["key"]): roll_value},
		false
	))


func _read_case_value(runtime: Object, case_data: Dictionary) -> float:
	return float(runtime.call(str(case_data["getter"])))


func _converted_id(case_data: Dictionary) -> String:
	return str(case_data.get("converted_id", case_data.get("id", "")))


func _converted_key(case_data: Dictionary) -> String:
	return str(case_data.get("converted_key", case_data.get("key", "")))


func _case_by_id(item_id: String) -> Dictionary:
	for case_value in BATCH1_CASES:
		var case_data: Dictionary = case_value
		if str(case_data["id"]) == item_id:
			return case_data
	return {}


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
