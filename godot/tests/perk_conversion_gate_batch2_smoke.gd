extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemHudState := preload("res://scripts/hud/active_item_hud_state.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const DIRECT_VALUE_CASES := [
	{"id": "master", "key": "wall_length_pct", "fixture": 50.0, "getter": "get_master_wall_length_bonus_pct"},
	{"id": "master", "key": "item_cooldown_pct", "fixture": 20.0, "getter": "get_master_item_cooldown_reduction_pct"},
	{"id": "master", "key": "wall_spawn_bonus_pct", "fixture": 100.0, "getter": "get_master_wall_spawn_bonus_pct"},
	{"id": "neural_helmet", "key": "aipill_gauge_reduction", "fixture": 40.0, "getter": "get_neural_helmet_aipill_gauge_reduction"},
	{"id": "neural_helmet", "key": "aipill_spawn_bonus_pct", "fixture": 200.0, "getter": "get_neural_helmet_aipill_spawn_bonus_pct"},
	{"id": "commando_arm", "key": "throw_speed_pct", "fixture": 35.0, "getter": "get_commando_arm_throw_speed_pct"},
	{"id": "commando_arm", "key": "explosion_range_pct", "fixture": 25.0, "getter": "get_commando_arm_explosion_range_pct"},
	{"id": "commando_arm", "key": "smoke_duration_pct", "fixture": 70.0, "getter": "get_commando_arm_smoke_duration_pct"},
	{"id": "commando_arm", "key": "prep_reduction_pct", "fixture": 70.0, "getter": "get_commando_arm_prep_reduction_pct"},
	{"id": "reinforced_boomerang_gauntlet", "key": "boomerang_launch_speed_pct", "fixture": 120.0, "getter": "get_boomerang_launch_speed_pct"},
	{"id": "reinforced_boomerang_gauntlet", "key": "boomerang_homing_pct", "fixture": 100.0, "getter": "get_boomerang_homing_pct"},
	{"id": "reinforced_boomerang_gauntlet", "key": "boomerang_spawn_bonus_pct", "fixture": 450.0, "getter": "get_boomerang_spawn_bonus_pct"},
]

const MULTIPLIER_CASES := [
	{
		"id": "reinforced_boomerang_gauntlet",
		"key": "boomerang_knockback_pct",
		"fixture": 1.4,
		"getter": "get_boomerang_knockback_multiplier",
	},
	{
		"id": "reinforced_boomerang_gauntlet",
		"key": "boomerang_stun_pct",
		"fixture": 1.6,
		"getter": "get_boomerang_stun_multiplier",
	},
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
	var ball_pos := Vector2.ZERO
	var ball_active := false
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

	func _init(runtime_ref: Object, state_ref: Object = null) -> void:
		mythic_runtime = runtime_ref
		runtime_perk_state = state_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_runtime
			"runtime_perk_state":
				return runtime_perk_state
		return null


var _failures: Array[String] = []


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	_verify_off_flag_keeps_item_rolls()
	_verify_on_flag_uses_perk_levels()
	_verify_on_flag_level_zero_is_inactive()
	_verify_on_flag_item_only_is_inactive()
	_verify_on_flag_perk_replaces_item_without_max()
	_verify_boolean_effect_gates()
	_verify_runtime_consumers_use_batch2_getters()
	_verify_overflow_saturates_at_consumer_limits()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_gate_batch2_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_off_flag_keeps_item_rolls() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var master_runtime: Object = _make_runtime({})
	_expect(_equip_item(master_runtime, "master", {
		"wall_length_pct": 50.0,
		"item_cooldown_pct": 20.0,
		"wall_spawn_bonus_pct": 100.0,
	}), "OFF fixture should equip master")
	var neural_runtime: Object = _make_runtime({})
	_expect(_equip_item(neural_runtime, "neural_helmet", {
		"aipill_gauge_reduction": 40.0,
		"aipill_spawn_bonus_pct": 200.0,
	}), "OFF fixture should equip neural_helmet")
	var commando_runtime: Object = _make_runtime({})
	_expect(_equip_item(commando_runtime, "commando_arm", {
		"throw_speed_pct": 20.0,
		"explosion_range_pct": 15.0,
		"smoke_duration_pct": 30.0,
		"prep_reduction_pct": 30.0,
	}), "OFF first Commando Arm fixture should equip")
	_expect(_acquire_item(commando_runtime, "commando_arm", {
		"throw_speed_pct": 15.0,
		"explosion_range_pct": 10.0,
		"smoke_duration_pct": 40.0,
		"prep_reduction_pct": 40.0,
	}), "OFF second Commando Arm fixture should equip")
	var boomerang_runtime: Object = _make_runtime({})
	_expect(_equip_item(boomerang_runtime, "reinforced_boomerang_gauntlet", {
		"boomerang_launch_speed_pct": 60.0,
		"boomerang_homing_pct": 40.0,
		"boomerang_spawn_bonus_pct": 200.0,
	}), "OFF first Boomerang Gauntlet fixture should equip")
	_expect(_acquire_item(boomerang_runtime, "reinforced_boomerang_gauntlet", {
		"boomerang_launch_speed_pct": 60.0,
		"boomerang_homing_pct": 60.0,
		"boomerang_spawn_bonus_pct": 250.0,
	}), "OFF second Boomerang Gauntlet fixture should equip")

	for case_value in DIRECT_VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _runtime_for_id(str(case_data["id"]), master_runtime, neural_runtime, commando_runtime, boomerang_runtime)
		_expect_close(
			_read_case_value(runtime, case_data),
			float(case_data["fixture"]),
			"OFF should keep item roll for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	for case_value in MULTIPLIER_CASES:
		var case_data: Dictionary = case_value
		_expect_close(
			_read_case_value(boomerang_runtime, case_data),
			float(case_data["fixture"]),
			"OFF should keep legacy multiplier for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	_expect_close(float(commando_runtime.get_commando_arm_windup_msec(600)), 252.0, "OFF should keep compounded Commando Arm prep")
	_expect_close(commando_runtime.get_commando_arm_throw_speed_multiplier(false), 2.0, "OFF should keep fixed per-stack generic throw speed")
	_expect_close(commando_runtime.get_commando_arm_throw_speed_multiplier(true), 1.35, "OFF should keep rolled boomerang throw speed")
	_expect_close(master_runtime.get_active_item_cooldown_msec(10000), 8000.0, "OFF should keep Master item cooldown roll")
	_expect_close(master_runtime.get_wall_item_spawn_chance(0.25), 0.5, "OFF should keep Master wall spawn roll")
	_expect_close(neural_runtime.get_aipill_item_spawn_chance(0.006), 0.018, "OFF should keep Neural Helmet AI Pill spawn roll")
	_expect_close(boomerang_runtime.get_boomerang_item_spawn_chance(0.006), 0.033, "OFF should keep Boomerang Gauntlet spawn roll")


func _verify_on_flag_uses_perk_levels() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in DIRECT_VALUE_CASES:
		var case_data: Dictionary = case_value
		for level in [1, 5]:
			var runtime: Object = _make_runtime({str(case_data["id"]): level})
			_expect_close(
				_read_case_value(runtime, case_data),
				PerkConversionValues.get_value(str(case_data["id"]), str(case_data["key"]), level),
				"ON should use Lv%d perk value for %s.%s" % [level, str(case_data["id"]), str(case_data["key"])]
			)
	for case_value in MULTIPLIER_CASES:
		var case_data: Dictionary = case_value
		for level in [1, 5]:
			var runtime: Object = _make_runtime({str(case_data["id"]): level})
			_expect_close(
				_read_case_value(runtime, case_data),
				1.0 + PerkConversionValues.get_value(str(case_data["id"]), str(case_data["key"]), level) / 100.0,
				"ON should use Lv%d perk multiplier for %s.%s" % [level, str(case_data["id"]), str(case_data["key"])]
			)
	var bonus_runtime: Object = _make_runtime({"master": 3}, 2)
	_expect(bonus_runtime.get_converted_perk_effect_level("master") == 5, "Batch2 bridge should expose base+bonus effective level")
	_expect_close(bonus_runtime.get_master_wall_length_bonus_pct(), 45.0, "base 3 + bonus 2 should use Master Lv5 wall length")


func _verify_on_flag_level_zero_is_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in DIRECT_VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect_close(
			_read_case_value(runtime, case_data),
			0.0,
			"ON level 0 should be inactive for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	for case_value in MULTIPLIER_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect_close(
			_read_case_value(runtime, case_data),
			1.0,
			"ON level 0 should use neutral multiplier for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	var runtime: Object = _make_runtime({})
	_expect_close(runtime.get_aipill_gauge_drain(90.0), 90.0, "ON level 0 should keep base AI Pill drain")
	_expect_close(runtime.get_commando_arm_throw_speed_multiplier(false), 1.0, "ON level 0 should keep neutral Commando speed")
	_expect_close(runtime.get_commando_arm_prep_multiplier(), 1.0, "ON level 0 should keep neutral Commando prep")
	_expect(not runtime.is_neural_helmet_effect_active(), "ON level 0 Neural Helmet effect gate should be inactive")
	_expect(not runtime.is_reinforced_boomerang_gauntlet_effect_active(), "ON level 0 Boomerang Gauntlet effect gate should be inactive")
	_expect(not runtime.is_commando_arm_effect_active(), "ON level 0 Commando Arm effect gate should be inactive")


func _verify_on_flag_item_only_is_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in DIRECT_VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect(_equip_case_roll(runtime, case_data, 500.0), "ON item-only fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			0.0,
			"ON item-only should not leak old item roll for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	for case_value in MULTIPLIER_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({})
		_expect(_equip_item(runtime, str(case_data["id"]), {
			"boomerang_launch_speed_pct": 500.0,
			"boomerang_homing_pct": 500.0,
			"boomerang_spawn_bonus_pct": 500.0,
		}), "ON item-only multiplier fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			1.0,
			"ON item-only should not leak old multiplier for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	var neural_runtime: Object = _make_runtime({})
	_expect(_equip_item(neural_runtime, "neural_helmet", {}), "ON item-only Neural Helmet should equip")
	_expect(not neural_runtime.is_neural_helmet_effect_active(), "ON item-only Neural Helmet effect gate should be inactive")
	_expect(not neural_runtime.should_cancel_aipill_on_direction_key(), "ON item-only Neural Helmet should not cancel AI Pill")
	var boomerang_runtime: Object = _make_runtime({})
	_expect(_equip_item(boomerang_runtime, "reinforced_boomerang_gauntlet", {}), "ON item-only Boomerang Gauntlet should equip")
	_expect(not boomerang_runtime.is_reinforced_boomerang_gauntlet_effect_active(), "ON item-only Boomerang Gauntlet effect gate should be inactive")
	var commando_runtime: Object = _make_runtime({})
	_expect(_equip_item(commando_runtime, "commando_arm", {}), "ON item-only Commando Arm should equip")
	_expect(not commando_runtime.is_commando_arm_effect_active(), "ON item-only Commando Arm effect gate should be inactive")
	var master_runtime: Object = _make_runtime({})
	_expect(_equip_item(master_runtime, "master", {}), "ON item-only Master should equip")
	_expect_close(master_runtime.get_active_item_cooldown_msec(10000), 10000.0, "ON item-only Master should not reduce cooldown")
	_expect_close(master_runtime.get_wall_item_spawn_chance(0.25), 0.25, "ON item-only Master should not raise wall spawn chance")
	_expect_close(neural_runtime.get_aipill_item_spawn_chance(0.006), 0.006, "ON item-only Neural Helmet should not raise AI Pill spawn chance")
	_expect_close(boomerang_runtime.get_boomerang_item_spawn_chance(0.006), 0.006, "ON item-only Boomerang Gauntlet should not raise boomerang spawn chance")


func _verify_on_flag_perk_replaces_item_without_max() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for case_value in DIRECT_VALUE_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({str(case_data["id"]): 1})
		_expect(_equip_case_roll(runtime, case_data, 500.0), "ON replacement fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			PerkConversionValues.get_value(str(case_data["id"]), str(case_data["key"]), 1),
			"ON should replace item roll instead of max/add for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	for case_value in MULTIPLIER_CASES:
		var case_data: Dictionary = case_value
		var runtime: Object = _make_runtime({str(case_data["id"]): 1})
		_expect(_equip_item(runtime, str(case_data["id"]), {
			"boomerang_launch_speed_pct": 500.0,
			"boomerang_homing_pct": 500.0,
			"boomerang_spawn_bonus_pct": 500.0,
		}), "ON multiplier replacement fixture should equip %s" % str(case_data["id"]))
		_expect_close(
			_read_case_value(runtime, case_data),
			1.0 + PerkConversionValues.get_value(str(case_data["id"]), str(case_data["key"]), 1) / 100.0,
			"ON should replace legacy fixed multiplier for %s.%s" % [str(case_data["id"]), str(case_data["key"])]
		)
	var runtime: Object = _make_runtime({"master": 1, "commando_arm": 1})
	_expect(_equip_item(runtime, "master", {"item_cooldown_pct": 90.0}), "ON high-roll Master should equip")
	_expect(_equip_item(runtime, "commando_arm", {
		"throw_speed_pct": 200.0,
		"prep_reduction_pct": 95.0,
	}), "ON high-roll Commando Arm should equip")
	_expect_close(runtime.get_active_item_cooldown_msec(10000), 9700.0, "ON Master cooldown should use Lv1 perk value, not high item roll")
	_expect_close(runtime.get_commando_arm_throw_speed_multiplier(false), 1.06, "ON Commando generic speed should use Lv1 perk table, not stack count")
	_expect_close(runtime.get_commando_arm_prep_multiplier(), 0.88, "ON Commando prep should use Lv1 perk table, not high item roll")


func _verify_boolean_effect_gates() -> void:
	PerkConversionFlags.debug_set_enabled(false)
	var off_runtime: Object = _make_runtime({})
	_expect(_equip_item(off_runtime, "neural_helmet", {}), "OFF Neural Helmet should equip")
	_expect(_equip_item(off_runtime, "reinforced_boomerang_gauntlet", {}), "OFF Boomerang Gauntlet should equip")
	_expect(_equip_item(off_runtime, "commando_arm", {}), "OFF Commando Arm should equip")
	_expect(off_runtime.is_neural_helmet_effect_active(), "OFF Neural Helmet effect gate should follow equipped state")
	_expect(off_runtime.should_cancel_aipill_on_direction_key(), "OFF Neural Helmet should cancel AI Pill by equipped state")
	_expect(off_runtime.is_reinforced_boomerang_gauntlet_effect_active(), "OFF Boomerang Gauntlet effect gate should follow equipped state")
	_expect(off_runtime.is_commando_arm_effect_active(), "OFF Commando Arm effect gate should follow equipped state")

	PerkConversionFlags.debug_set_enabled(true)
	var on_runtime: Object = _make_runtime({
		"neural_helmet": 1,
		"reinforced_boomerang_gauntlet": 1,
		"commando_arm": 1,
	})
	_expect(on_runtime.is_neural_helmet_effect_active(), "ON perk-only Neural Helmet effect gate should be active")
	_expect(on_runtime.should_cancel_aipill_on_direction_key(), "ON perk-only Neural Helmet should cancel AI Pill")
	_expect(on_runtime.is_reinforced_boomerang_gauntlet_effect_active(), "ON perk-only Boomerang Gauntlet effect gate should be active")
	_expect(on_runtime.is_commando_arm_effect_active(), "ON perk-only Commando Arm effect gate should be active")


func _verify_runtime_consumers_use_batch2_getters() -> void:
	PerkConversionFlags.debug_set_enabled(true)

	var master_runtime: Object = _make_runtime({"master": 5})
	var master_registry := FakeRegistry.new(master_runtime, master_runtime.runtime_perk_state_ref)
	var spawn_pool: Object = ActiveItemFieldSpawnPool.new()
	var wall_item: Dictionary = spawn_pool._apply_passive_spawn_weight({"name": "wall", "chance": 0.02}, master_registry)
	_expect_close(float(wall_item.get("chance", 0.0)), 0.086, "ON Master perk should feed wall field-spawn weighting")
	var hud_state: Object = ActiveItemHudState.new()
	_expect_close(
		float(hud_state.get_active_item_cooldown_msec({"cooldown_msec": 10000}, master_registry, null)),
		8800.0,
		"ON Master perk should feed active-item cooldown consumers"
	)

	var neural_runtime: Object = _make_runtime({"neural_helmet": 5})
	var neural_registry := FakeRegistry.new(neural_runtime, neural_runtime.runtime_perk_state_ref)
	var aipill_item: Dictionary = spawn_pool._apply_passive_spawn_weight({"name": "aipill", "chance": 0.006}, neural_registry)
	_expect_close(float(aipill_item.get("chance", 0.0)), 0.0258, "ON Neural Helmet perk should feed AI Pill field-spawn weighting")
	_expect_close(neural_runtime.get_aipill_gauge_drain(90.0), 20.0, "ON Neural Helmet perk should feed AI Pill gauge drain")

	var commando_runtime: Object = _make_runtime({"commando_arm": 5})
	var commando_registry := FakeRegistry.new(commando_runtime, commando_runtime.runtime_perk_state_ref)
	var throw_controller: Object = ActiveItemThrowController.new()
	_expect_close(float(throw_controller.get_commando_adjusted_windup_msec("grenade", 600, commando_registry)), 312.0, "ON Commando perk should feed throw windup")
	_expect_close(throw_controller.get_commando_arm_throw_speed_multiplier(commando_registry, false), 1.24, "ON Commando perk should feed generic throw speed")
	_expect_close(throw_controller.get_commando_arm_throw_speed_multiplier(commando_registry, true), 1.24, "ON Commando perk should feed boomerang throw speed")
	_expect_close(throw_controller.get_commando_arm_range_value(200.0, commando_registry), 236.0, "ON Commando perk should feed explosion range helpers")
	_expect_close(throw_controller.get_commando_arm_duration_frames(100.0, commando_registry), 148.0, "ON Commando perk should feed smoke duration helpers")
	var owner := FakeOwner.new()
	throw_controller._throw_grenade(owner, {"target_position": Vector2(377.5, 120.0)}, commando_registry)
	var grenades: Array[Dictionary] = throw_controller.get_grenades()
	_expect(grenades.size() == 1, "ON Commando perk should allow grenade helper to spawn")
	_expect(_get_array(grenades[0], "trail").size() == 2, "ON Commando perk should feed the grenade helper's immediate launch branch")

	var boomerang_runtime: Object = _make_runtime({"reinforced_boomerang_gauntlet": 5})
	var boomerang_registry := FakeRegistry.new(boomerang_runtime, boomerang_runtime.runtime_perk_state_ref)
	var boomerang_item: Dictionary = spawn_pool._apply_passive_spawn_weight({"name": "boomerang", "chance": 0.015}, boomerang_registry)
	_expect_close(float(boomerang_item.get("chance", 0.0)), 0.045, "ON Boomerang Gauntlet perk should feed boomerang field-spawn weighting")
	var slot_controller: Object = ActiveItemSlotController.new()
	var visual_item: Dictionary = slot_controller._apply_item_runtime_visual_overrides({
		"name": "boomerang",
		"effect": "boomerang",
		"icon_path": ActiveItemCatalog.BOOMERANG_ICON_PATH,
	}, boomerang_registry)
	_expect(str(visual_item.get("icon_path", "")) == ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH, "ON perk-only Boomerang Gauntlet should make stored boomerang metal")
	_expect(str(visual_item.get("visual_variant", "")) == "metal", "ON perk-only Boomerang Gauntlet should stamp metal visual variant")
	var boomerang_throw: Object = ActiveItemThrowController.new()
	_expect(boomerang_throw.activate_boomerang(owner, boomerang_registry), "ON perk-only Boomerang Gauntlet should activate boomerang")
	var pending: Array[Dictionary] = boomerang_throw.get_pending_throws()
	_expect(pending.size() == 1 and bool(pending[0].get("gauntlet_equipped", false)), "ON perk-only Boomerang Gauntlet should mark windup as metal")
	boomerang_throw._throw_boomerang(owner, pending[0], boomerang_registry)
	var boomerangs: Array[Dictionary] = boomerang_throw.get_boomerangs()
	_expect(boomerangs.size() == 1, "ON Boomerang Gauntlet perk should spawn a projectile")
	var thrown: Dictionary = boomerangs[0]
	_expect(bool(thrown.get("gauntlet_equipped", false)), "ON Boomerang Gauntlet perk should carry metal projectile state")
	_expect(float(thrown.get("speed_jitter", 0.0)) > 1.4, "ON Boomerang Gauntlet perk should feed launch speed into projectile")
	_expect_close(float(thrown.get("homing_multiplier", 0.0)), 1.5, "ON Boomerang Gauntlet perk should feed homing into projectile")
	_expect_close(float(thrown.get("knockback_multiplier", 0.0)), 1.5, "ON Boomerang Gauntlet perk should feed knockback into projectile")
	_expect_close(float(thrown.get("stun_multiplier", 0.0)), 1.8, "ON Boomerang Gauntlet perk should feed stun into projectile")

	var item_only_boomerang: Object = _make_runtime({})
	_expect(_equip_item(item_only_boomerang, "reinforced_boomerang_gauntlet", {}), "ON item-only Boomerang Gauntlet should equip for visual negative")
	var item_only_registry := FakeRegistry.new(item_only_boomerang, item_only_boomerang.runtime_perk_state_ref)
	var normal_visual: Dictionary = slot_controller._apply_item_runtime_visual_overrides({
		"name": "boomerang",
		"effect": "boomerang",
		"icon_path": ActiveItemCatalog.BOOMERANG_ICON_PATH,
	}, item_only_registry)
	_expect(str(normal_visual.get("icon_path", "")) == ActiveItemCatalog.BOOMERANG_ICON_PATH, "ON item-only Boomerang Gauntlet should not make stored boomerang metal")


func _verify_overflow_saturates_at_consumer_limits() -> void:
	# 감소 계열 오버플로우가 소비 코드의 실효 한도에 정확히 포화한다
	# (레거시 패리티 — OVERFLOW_VALUE_BOUNDS와 공개 소비 함수의 관통 씰:
	# 100 캡이었다면 neural은 실효 무증가·master는 실제 쿨다운 0이 된다).
	PerkConversionFlags.debug_set_enabled(true)
	var neural_runtime: Object = _make_runtime({"neural_helmet": 9})
	_expect_close(neural_runtime.get_neural_helmet_aipill_gauge_reduction(), 90.0, "overflow neural gauge reduction must saturate at the 90 base-gauge limit")
	_expect_close(neural_runtime.get_aipill_gauge_drain(90.0), 0.0, "overflow neural drain must land exactly on 0, never negative")
	var master_runtime: Object = _make_runtime({"master": 60})
	_expect_close(master_runtime.get_master_item_cooldown_reduction_pct(), 95.0, "overflow master cooldown reduction must saturate at the legacy 95 limit")
	var commando_runtime: Object = _make_runtime({"commando_arm": 20})
	_expect_close(commando_runtime.get_commando_arm_prep_reduction_pct(), 95.0, "overflow commando prep reduction must saturate at the legacy 95 limit")
	_expect_close(commando_runtime.get_commando_arm_prep_multiplier(), 0.05, "overflow commando prep multiplier must floor at 0.05, not the 0.01 emergency floor")


func _make_runtime(levels: Dictionary, bonus: int = 0) -> Object:
	var runtime: Object = MythicItemRuntime.new()
	var state: Object = RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	state.set_item_perk_level_bonus(bonus)
	runtime.get_snapshot()
	var registry := FakeRegistry.new(runtime, state)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return runtime


func _runtime_for_id(
	item_id: String,
	master_runtime: Object,
	neural_runtime: Object,
	commando_runtime: Object,
	boomerang_runtime: Object
) -> Object:
	match item_id:
		"master":
			return master_runtime
		"neural_helmet":
			return neural_runtime
		"commando_arm":
			return commando_runtime
		"reinforced_boomerang_gauntlet":
			return boomerang_runtime
	return null


func _equip_case_roll(runtime: Object, case_data: Dictionary, roll_value: float) -> bool:
	return _equip_item(runtime, str(case_data["id"]), {str(case_data["key"]): roll_value})


func _equip_item(runtime: Object, item_id: String, rolls: Dictionary) -> bool:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref)
	return bool(runtime.equip_item(item_id, owner, registry, rolls, false))


func _acquire_item(runtime: Object, item_id: String, rolls: Dictionary) -> bool:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime, runtime.runtime_perk_state_ref)
	return int(runtime.acquire_item(item_id, owner, registry, rolls, true, false)) >= 0


func _read_case_value(runtime: Object, case_data: Dictionary) -> float:
	return float(runtime.call(str(case_data["getter"])))


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
