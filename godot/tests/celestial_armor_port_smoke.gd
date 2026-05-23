extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemCelestialArmorRuntime := preload("res://scripts/items/mythic_item_celestial_armor_runtime.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var celestial_armor_equipped := false
	var celestial_armor_active := false
	var celestial_armor_trigger_chance_pct := 0.0
	var celestial_armor_gauge_cost := 0.0
	var celestial_armor_context: Dictionary = {}
	var celestial_armor_wave_active := false

	func queue_redraw() -> void:
		pass


class FakeRegistry:
	func get_instance(_key: String) -> Object:
		return null


class FakeMovementState:
	var call_count := 0

	func start_knockback(
		_velocity: float,
		_frames: float = 18.0,
		_decay_per_frame: float = 0.92,
		_replace_current: bool = false,
		_cleansable: bool = true
	) -> bool:
		call_count += 1
		return true


func _init() -> void:
	_verify_runtime_constant_ownership()

	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("celestial_armor")
	_expect(not item_data.is_empty(), "celestial armor should build from catalog")
	_expect(str(item_data.get("slot", "")) == "top", "celestial armor should use top slot")
	_expect(str(item_data.get("display_name", "")) == "천구의 부동 갑주", "celestial armor should keep Korean display name")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "celestial armor should expose 32 smooth icon frames")
	_expect_original_icon_assets(item_data, "celestial armor")
	_expect(_catalog_has_field_spawn(catalog, "celestial_armor"), "celestial armor should be in field spawn pool")
	_expect_celestial_rolls(catalog)

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 100.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should equip"
	)
	_expect(owner.equipment_slots.has("top"), "celestial armor should sync to top slot")
	_expect(str(owner.equipment_slots["top"].get("name", "")) == "celestial_armor", "top slot should contain celestial armor")
	_expect(owner.celestial_armor_equipped, "owner should expose celestial armor equipped")
	_expect(owner.celestial_armor_active, "owner should expose celestial armor active")
	_expect(is_equal_approx(owner.celestial_armor_trigger_chance_pct, 100.0), "owner should sync trigger chance")
	_expect(is_equal_approx(owner.celestial_armor_gauge_cost, 20.0), "owner should sync gauge cost")

	var proc_deps := {"owner": owner, "registry": registry}
	_expect(
		not runtime.try_consume_celestial_armor_immunity("test_knockback", "knockback", proc_deps),
		"celestial armor should ignore pure knockback"
	)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "ignored knockback should not spend gauge")
	_expect(
		runtime.try_consume_celestial_armor_immunity("test_stun", "stun", proc_deps),
		"100 percent celestial armor should block stun"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "celestial armor should spend gauge on stun block")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("celestial_armor_wave_active", false)), "celestial armor should start wave VFX")
	_expect(str(snapshot.get("celestial_armor_last_blocked_effect_type", "")) == "stun", "snapshot should expose blocked effect type")
	_expect(
		not runtime.try_consume_celestial_armor_immunity("paired_knockback", "knockback", proc_deps),
		"paired knockback should still pass through celestial armor"
	)
	_expect(is_equal_approx(owner.special_gauge, 80.0), "paired knockback should not spend gauge")

	runtime.reset_round(registry)
	var context_only := {
		"special_gauge": 45.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	_expect(
		runtime.try_consume_celestial_armor_immunity("context_stun", "stun", {"context": context_only}),
		"context-only celestial armor proc should work for stun update routes"
	)
	_expect(is_equal_approx(float(context_only.get("special_gauge", -1.0)), 25.0), "context-only proc should mutate context gauge")

	runtime.reset_round(registry)
	var low_gauge_context := {"special_gauge": 10.0}
	_expect(
		not runtime.try_consume_celestial_armor_immunity("low_gauge", "stun", {"context": low_gauge_context}),
		"celestial armor should fail when gauge is insufficient"
	)
	_expect(is_equal_approx(float(low_gauge_context.get("special_gauge", -1.0)), 10.0), "failed proc should not spend gauge")

	runtime.reset_round(registry)
	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 0.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should update roll overrides"
	)
	owner.special_gauge = 100.0
	_expect(
		not runtime.try_consume_celestial_armor_immunity("zero_chance", "stun", {"owner": owner}),
		"0 percent celestial armor should not block"
	)
	_expect(is_equal_approx(owner.special_gauge, 100.0), "failed chance roll should not spend gauge")

	_expect(
		runtime.equip_item(
			"celestial_armor",
			owner,
			registry,
			{"trigger_chance_pct": 100.0, "gauge_cost": 20.0},
			false
		),
		"celestial armor should re-equip deterministic test rolls"
	)
	runtime.reset_round(registry)
	var movement := FakeMovementState.new()
	var bounce_router: Object = PaddleBounceEventRouter.new()
	var rally_result: Dictionary = bounce_router.register_rally_feedback(
		Vector2(380.0, 690.0),
		Vector2(16.0, -18.0),
		true,
		false,
		{
			"movement_state": movement,
			"mythic_item_runtime": runtime,
		},
		{
			"player_pos": Vector2(300.0, 700.0),
			"player_paddle_width": 155.0,
			"player_paddle_height": 50.0,
		},
		100.0
	)
	_expect(rally_result.is_empty(), "paddle-hit knockback should not trigger celestial armor")
	_expect(movement.call_count == 1, "paddle-hit knockback should pass through celestial armor")

	_expect(runtime.unequip_item("celestial_armor", owner, registry), "celestial armor should unequip")
	_expect(not owner.celestial_armor_equipped, "owner should clear celestial armor equipped state")

	print("celestial_armor_port_smoke: ok")
	quit(0)


func _verify_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemCelestialArmorRuntime.MAX_TRIGGER_CHANCE_PCT, 100.0), "celestial armor helper should own trigger chance cap")
	_expect(is_equal_approx(MythicItemCelestialArmorRuntime.WAVE_LIFE_FRAMES, 33.0), "celestial armor helper should own wave lifetime")
	_expect(MythicItemCelestialArmorRuntime.SHARD_COUNT == 10, "celestial armor helper should own shard count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_celestial_armor_runtime.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "celestial armor helper source should be readable")
	_expect(not runtime_source.contains("CELESTIAL_ARMOR_CONSTANTS"), "runtime facade should not regain CELESTIAL_ARMOR_CONSTANTS")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_MAX"), "runtime facade should not regain celestial cap constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_WAVE"), "runtime facade should not regain celestial wave constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_PAIRED"), "runtime facade should not regain celestial paired-proc constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_SHARD"), "runtime facade should not regain celestial shard constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_ARC"), "runtime facade should not regain celestial arc constants")
	_expect(not runtime_source.contains("const CELESTIAL_ARMOR_FEEDBACK"), "runtime facade should not regain celestial feedback constants")
	_expect(helper_source.contains("const FEEDBACK_SHAKE_INTENSITY"), "celestial armor helper should keep feedback constants")


func _expect_celestial_rolls(catalog: Object) -> void:
	var rolls: Array = catalog.get_roll_options("celestial_armor")
	_expect(rolls.size() == 2, "celestial armor should expose two roll options")
	var trigger_roll: Dictionary = _find_roll(rolls, "trigger_chance_pct")
	_expect(not trigger_roll.is_empty(), "celestial armor should expose trigger chance roll")
	_expect(is_equal_approx(float(trigger_roll.get("min", 0.0)), 50.0), "trigger chance min should match Python")
	_expect(is_equal_approx(float(trigger_roll.get("max", 0.0)), 80.0), "trigger chance max should match Python")
	var gauge_roll: Dictionary = _find_roll(rolls, "gauge_cost")
	_expect(not gauge_roll.is_empty(), "celestial armor should expose gauge cost roll")
	_expect(is_equal_approx(float(gauge_roll.get("min", 0.0)), 20.0), "gauge cost min should match Python")
	_expect(is_equal_approx(float(gauge_roll.get("max", 0.0)), 40.0), "gauge cost max should match Python")
	_expect(bool(gauge_roll.get("reverse", false)), "gauge cost should be a reverse roll")


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		var roll_data: Dictionary = roll_value if roll_value is Dictionary else {}
		if str(roll_data.get("key", "")) == key:
			return roll_data
	return {}


func _catalog_has_field_spawn(catalog: Object, item_name: String) -> bool:
	for item_value in catalog.get_field_spawn_items():
		var field_item: Dictionary = item_value if item_value is Dictionary else {}
		if str(field_item.get("name", "")) == item_name:
			return true
	return false


func _expect_original_icon_assets(item_data: Dictionary, item_label: String) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "%s static icon should load" % item_label)
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "%s static icon should be the original 32px render" % item_label)

	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null, "%s animated icon sheet should load" % item_label)
	if sheet != null:
		_expect(sheet.get_width() == 1024 and sheet.get_height() == 32, "%s animated icon sheet should be the smooth 32-frame render" % item_label)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
