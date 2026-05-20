extends SceneTree

const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)
	var ball_pos := Vector2.ZERO
	var ball_active := false
	var commando_arm_equipped := false
	var commando_arm_count := 0
	var commando_arm_context: Dictionary = {}

	func queue_redraw() -> void:
		pass


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw_before() -> void:
		calls.append("play_throw_before")

	func play_active_item() -> void:
		calls.append("play_active_item")

	func play_throw() -> void:
		calls.append("play_throw")

	func play_grenade_explosion() -> void:
		calls.append("play_grenade_explosion")

	func play_flashbomb() -> void:
		calls.append("play_flashbomb")

	func play_molotov_explosion() -> void:
		calls.append("play_molotov_explosion")

	func play_smokebomb() -> void:
		calls.append("play_smokebomb")


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var runtime: Object
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()

	func _init(runtime_ref: Object) -> void:
		runtime = runtime_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return runtime
			"game_audio":
				return audio
			"battle_feedback_state":
				return feedback
		return null


func _init() -> void:
	var catalog: Object = MythicItemCatalog.new()
	_verify_catalog(catalog)

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	_verify_runtime_stack(runtime, owner, registry)
	_verify_throw_controller_hooks(runtime, owner, registry)

	print("commando_arm_port_smoke: ok")
	quit(0)


func _verify_catalog(catalog: Object) -> void:
	var item_data: Dictionary = catalog.build_item_by_name("commando_arm")
	_expect(not item_data.is_empty(), "Commando Arm should build from the passive catalog")
	_expect(str(item_data.get("display_name", "")) == "코만도암", "Commando Arm should keep the Korean display name")
	_expect(str(item_data.get("type", "")) == "passive", "Commando Arm should be passive")
	_expect(str(item_data.get("slot", "")) == "arm", "Commando Arm should use the arm slot")
	_expect_close(float(item_data.get("chance", 0.0)), 0.006, "Commando Arm field chance should match Python")
	_expect(str(item_data.get("icon_path", "")) == MythicItemCatalog.COMMANDO_ARM_ICON_PATH, "Commando Arm should use its PNG icon")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Commando Arm icon should load")
	_expect(_roll_option_has_range(item_data, "throw_speed_pct", 10.0, 20.0, 15.0), "throw-speed roll should match Python")
	_expect(_roll_option_has_range(item_data, "explosion_range_pct", 5.0, 15.0, 10.0), "explosion-range roll should match Python")
	_expect(_roll_option_has_range(item_data, "smoke_duration_pct", 20.0, 40.0, 30.0), "smoke-duration roll should match Python")
	_expect(_roll_option_has_range(item_data, "prep_reduction_pct", 20.0, 40.0, 30.0), "prep-reduction roll should match Python")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "commando_arm"), "Commando Arm should be in the passive field-spawn list")
	_expect(_array_has_item(catalog.get_debug_items(), "commando_arm"), "Commando Arm should be in the passive debug item list")
	var spawn_pool: Object = ActiveItemFieldSpawnPool.new()
	_expect(spawn_pool.get_field_spawn_candidate_names().has("commando_arm"), "shared field-spawn pool should expose Commando Arm")
	_expect(not spawn_pool.build_catalog_item("commando_arm").is_empty(), "shared field-spawn catalog lookup should build Commando Arm")


func _verify_runtime_stack(runtime: Object, owner: Object, registry: Object) -> void:
	_expect(runtime.equip_item("commando_arm", owner, registry, {
		"throw_speed_pct": 15.0,
		"explosion_range_pct": 10.0,
		"smoke_duration_pct": 30.0,
		"prep_reduction_pct": 30.0,
	}, false), "first Commando Arm should equip")
	_expect(runtime.acquire_item("commando_arm", owner, registry, {
		"throw_speed_pct": 20.0,
		"explosion_range_pct": 15.0,
		"smoke_duration_pct": 40.0,
		"prep_reduction_pct": 40.0,
	}, true, false) >= 0, "second Commando Arm should equip into the other arm slot")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("commando_arm_equipped", false)), "runtime snapshot should expose Commando Arm equipped")
	_expect(int(snapshot.get("commando_arm_count", 0)) == 2, "two Commando Arms should stack across both arm slots")
	_expect(owner.commando_arm_equipped, "owner should expose Commando Arm equipped state")
	_expect(owner.commando_arm_count == 2, "owner should expose Commando Arm stack count")
	_expect(owner.equipment_slots.has("left_arm") and owner.equipment_slots.has("right_arm"), "duplicate Commando Arms should occupy left/right arms")
	_expect_close(float(snapshot.get("commando_arm_throw_speed_pct", 0.0)), 35.0, "boomerang throw speed roll should stack")
	_expect_close(float(snapshot.get("commando_arm_explosion_range_pct", 0.0)), 25.0, "explosion range roll should stack")
	_expect_close(float(snapshot.get("commando_arm_smoke_duration_pct", 0.0)), 70.0, "smoke duration roll should stack")
	_expect_close(float(snapshot.get("commando_arm_prep_reduction_pct", 0.0)), 70.0, "prep reduction display sum should stack")
	_expect_close(float(snapshot.get("commando_arm_prep_multiplier", 0.0)), 0.42, "prep reduction should compound per stack")
	_expect_close(float(snapshot.get("commando_arm_generic_throw_speed_multiplier", 0.0)), 2.0, "generic throw speed should use Python's fixed 50 percent per stack")
	_expect_close(float(snapshot.get("commando_arm_boomerang_throw_speed_multiplier", 0.0)), 1.35, "boomerang throw speed should use the rolled Commando Arm speed")
	_expect_close(float(snapshot.get("commando_arm_range_multiplier", 0.0)), 1.25, "range multiplier should use stacked range rolls")
	_expect_close(float(snapshot.get("commando_arm_smoke_duration_multiplier", 0.0)), 1.70, "smoke duration multiplier should use stacked duration rolls")
	_expect_close(float(runtime.get_commando_arm_windup_msec(600)), 252.0, "runtime windup helper should match Python-style floor timing")
	_expect_close(float(runtime.get_commando_arm_range_value(190.0)), 237.5, "runtime range helper should scale explosion radii")
	_expect_close(float(runtime.get_commando_arm_duration_frames(960.0)), 1632.0, "runtime duration helper should scale smoke duration")


func _verify_throw_controller_hooks(_runtime: Object, owner: Object, registry: Object) -> void:
	var throw_controller: Object = ActiveItemThrowController.new()
	_expect(throw_controller.activate_grenade(owner, registry), "grenade activation should start with Commando Arm equipped")
	var pending: Array[Dictionary] = throw_controller.get_pending_throws()
	_expect(pending.size() == 1, "grenade activation should queue one pending throw")
	_expect_close(float(pending[0].get("base_windup_msec", 0.0)), 600.0, "grenade pending should remember base windup")
	_expect_close(float(pending[0].get("windup_msec", 0.0)), 252.0, "grenade windup should be reduced by Commando Arm")

	throw_controller._throw_grenade(owner, pending[0], registry)
	var grenades: Array[Dictionary] = throw_controller.get_grenades()
	_expect(grenades.size() == 1, "grenade throw should create one projectile")
	var grenade: Dictionary = grenades[0]
	var start_position: Vector2 = _get_vector2(pending[0], "start_position")
	_expect_close(_get_vector2(grenade, "velocity").length(), 24.0, "grenade velocity should use fixed Commando Arm throw speed")
	_expect_close(_get_vector2(grenade, "position").distance_to(start_position), 24.0, "grenade should apply the first-frame Commando Arm launch step")
	_expect(_get_array(grenade, "trail").size() == 2, "grenade trail should preserve the boosted first-frame step")

	throw_controller._trigger_grenade_explosion(owner, registry, Vector2(380.0, 75.0))
	_expect_close(float(throw_controller.get_explosion_zones()[0].get("radius", 0.0)), 237.5, "grenade explosion radius should be boosted")

	throw_controller.cancel_pending_throw_windups()
	_expect(throw_controller.activate_flare(owner, registry), "flare activation should start with Commando Arm equipped")
	pending = throw_controller.get_pending_throws()
	_expect_close(float(pending[0].get("windup_msec", 0.0)), 252.0, "flare windup should be reduced by Commando Arm")
	throw_controller._trigger_flare_flash(owner, registry, Vector2(380.0, 95.0))
	_expect_close(float(throw_controller.get_flare_zones()[0].get("radius", 0.0)), 225.0, "flare radius should be boosted")

	throw_controller.cancel_pending_throw_windups()
	_expect(throw_controller.activate_molotov(owner, registry), "molotov activation should start with Commando Arm equipped")
	pending = throw_controller.get_pending_throws()
	_expect_close(float(pending[0].get("windup_msec", 0.0)), 252.0, "molotov windup should be reduced by Commando Arm")
	throw_controller._trigger_molotov_fire_zone(owner, registry, Vector2(380.0, 45.0))
	var fire_zone: Dictionary = throw_controller.get_molotov_fire_zones()[0]
	_expect_close(float(fire_zone.get("width", 0.0)), 187.5, "molotov fire width should be boosted")
	_expect_close(float(fire_zone.get("height", 0.0)), 75.0, "molotov fire height should be boosted")

	throw_controller.cancel_pending_throw_windups()
	_expect(throw_controller.activate_boomerang(owner, registry), "boomerang activation should start with Commando Arm equipped")
	pending = throw_controller.get_pending_throws()
	_expect_close(float(pending[0].get("windup_msec", 0.0)), 168.0, "boomerang windup should be reduced by Commando Arm")
	throw_controller._throw_boomerang(owner, pending[0], registry)
	var boomerang: Dictionary = throw_controller.get_boomerangs()[0]
	_expect_close(float(boomerang.get("speed_jitter", 0.0)), 1.35, "boomerang launch speed should use the rolled Commando Arm speed")

	throw_controller.cancel_pending_throw_windups()
	_expect(throw_controller.activate_dynamite(owner, registry), "dynamite activation should start with Commando Arm equipped")
	pending = throw_controller.get_pending_throws()
	_expect_close(float(pending[0].get("windup_msec", 0.0)), 210.0, "dynamite windup should be reduced by Commando Arm")

	throw_controller.cancel_pending_throw_windups()
	_expect(throw_controller.activate_tear_gas(owner, registry), "tear gas activation should still start")
	pending = throw_controller.get_pending_throws()
	_expect_close(float(pending[0].get("windup_msec", 0.0)), 600.0, "tear gas windup should stay unmodified like Python smoke grenade")
	throw_controller._trigger_tear_gas_zone(owner, registry, Vector2(380.0, 150.0))
	var gas_zone: Dictionary = throw_controller.get_tear_gas_zones()[0]
	_expect_close(float(gas_zone.get("duration_frames", 0.0)), 1632.0, "tear gas duration should be boosted as smoke duration")
	_expect_close(float(gas_zone.get("max_radius", 0.0)), 180.0, "tear gas radius should not be range-boosted")


func _roll_option_has_range(item_data: Dictionary, option_key: String, minimum: float, maximum: float, default_value: float) -> bool:
	for option_value in item_data.get("roll_options", []):
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		if str(option.get("key", "")) != option_key:
			continue
		return (
			abs(float(option.get("min", 0.0)) - minimum) <= 0.0001
			and abs(float(option.get("max", 0.0)) - maximum) <= 0.0001
			and abs(float(option.get("default", 0.0)) - default_value) <= 0.0001
		)
	return false


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
