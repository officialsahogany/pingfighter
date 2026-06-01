extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var player_pos := Vector2(302.5, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var ball_pos := Vector2(380.0, 375.0)
	var ball_active := false

	func queue_redraw() -> void:
		pass


class FakeAudio:
	var throw_count := 0
	var loop_count := 0
	var hit_count := 0

	func play_throw_before() -> void:
		pass

	func play_active_item() -> void:
		pass

	func play_throw() -> void:
		throw_count += 1

	func play_boomerang_loop() -> void:
		loop_count += 1

	func stop_boomerang_loop() -> void:
		pass

	func play_boomerang_hit() -> void:
		hit_count += 1

	func play_boomerang_break() -> void:
		pass


class FakeRegistry:
	var mythic_runtime: Object
	var game_audio: Object
	var active_item_runtime: Object

	func _init(runtime: Object, audio: Object = null, active_runtime: Object = null) -> void:
		mythic_runtime = runtime
		game_audio = audio
		active_item_runtime = active_runtime

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_runtime
		if key == "active_item_runtime":
			return active_item_runtime
		if key == "game_audio":
			return game_audio
		return null


func _init() -> void:
	var mythic_catalog: Object = MythicItemCatalog.new()
	var active_catalog: Object = ActiveItemCatalog.new()
	var runtime: Object = MythicItemRuntime.new()
	var active_runtime: Object = ActiveItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, audio, active_runtime)

	var gauntlet_item: Dictionary = mythic_catalog.build_item_by_name("reinforced_boomerang_gauntlet")
	_expect(not gauntlet_item.is_empty(), "Reinforced Boomerang Gauntlet should build from the passive catalog")
	_expect(str(gauntlet_item.get("slot", "")) == "arm", "Reinforced Boomerang Gauntlet should use the shared arm slot")
	_expect(str(gauntlet_item.get("effect", "")) == "reinforced_boomerang_gauntlet", "gauntlet effect id should be stable")
	_expect(abs(float(gauntlet_item.get("chance", 0.0)) - 0.005) <= 0.000001, "gauntlet field chance should match Python")
	_expect(str(gauntlet_item.get("icon_path", "")) == MythicItemCatalog.REINFORCED_BOOMERANG_GAUNTLET_ICON_PATH, "gauntlet passive item should use its glove icon")
	_expect(ProjectResourceLoader.load_texture(str(gauntlet_item.get("icon_path", ""))) != null, "gauntlet glove icon should load")
	_expect(_array_has_item(mythic_catalog.get_field_spawn_items(), "reinforced_boomerang_gauntlet"), "gauntlet should spawn as a passive field item")
	_expect(_roll_option_has_range(mythic_catalog, "boomerang_launch_speed_pct", 30.0, 60.0), "launch speed roll should match Python")
	_expect(_roll_option_has_range(mythic_catalog, "boomerang_homing_pct", 20.0, 50.0), "homing roll should match Python")
	_expect(_roll_option_has_values(mythic_catalog, "boomerang_spawn_bonus_pct", 150.0, 250.0, 200.0), "spawn roll should match current tuning")

	_expect(runtime.equip_item("reinforced_boomerang_gauntlet", owner, registry, {
		"boomerang_launch_speed_pct": 60.0,
		"boomerang_homing_pct": 50.0,
		"boomerang_spawn_bonus_pct": 250.0,
	}, false), "first gauntlet should equip into an arm slot")
	_expect(runtime.acquire_item("reinforced_boomerang_gauntlet", owner, registry, {
		"boomerang_launch_speed_pct": 60.0,
		"boomerang_homing_pct": 50.0,
		"boomerang_spawn_bonus_pct": 250.0,
	}, true, false) >= 0, "second gauntlet duplicate should equip into the other arm slot")

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("reinforced_boomerang_gauntlet_equipped", false)), "runtime snapshot should expose gauntlet equipped")
	_expect(int(snapshot.get("reinforced_boomerang_gauntlet_count", 0)) == 2, "two gauntlets should stack across both arm slots")
	_expect_close(float(snapshot.get("reinforced_boomerang_gauntlet_launch_speed_pct", 0.0)), 120.0, "launch speed should stack")
	_expect_close(float(snapshot.get("reinforced_boomerang_gauntlet_homing_pct", 0.0)), 100.0, "homing should stack")
	_expect_close(float(snapshot.get("reinforced_boomerang_gauntlet_spawn_bonus_pct", 0.0)), 500.0, "boomerang spawn bonus should stack")
	_expect_close(float(snapshot.get("boomerang_launch_speed_multiplier", 0.0)), 2.2, "launch speed multiplier should use stacked rolls")
	_expect_close(float(snapshot.get("boomerang_homing_multiplier", 0.0)), 2.0, "homing multiplier should use stacked rolls")
	_expect_close(float(snapshot.get("boomerang_knockback_multiplier", 0.0)), 1.4, "fixed knockback multiplier should be active")
	_expect_close(float(snapshot.get("boomerang_stun_multiplier", 0.0)), 1.6, "fixed stun multiplier should be active")
	_expect(owner.equipment_slots.has("left_arm") and owner.equipment_slots.has("right_arm"), "duplicate gauntlets should occupy left/right arms")
	_expect(owner.active_item_slots.size() == 2, "each gauntlet acquisition should grant one bonus boomerang")
	_expect(str(owner.active_item_slots[0].get("name", "")) == "boomerang", "first bonus active item should be a boomerang")
	_expect(str(owner.active_item_slots[1].get("name", "")) == "boomerang", "second bonus active item should be a boomerang")
	_expect(str(owner.active_item_slots[0].get("icon_path", "")) == ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH, "bonus boomerang should use the metal icon once the gauntlet is equipped")

	var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
	var candidates: Array[Dictionary] = field_spawn_controller._build_spawn_candidates(registry)
	var boomerang_candidate: Dictionary = _find_item(candidates, "boomerang")
	_expect(not boomerang_candidate.is_empty(), "boomerang should remain in active field candidates")
	_expect_close(float(boomerang_candidate.get("chance", 0.0)), 0.015 * 6.0, "boomerang field chance should receive gauntlet spawn multiplier")

	var active_slots: Array = []
	var boomerang_item: Dictionary = active_catalog.build_item_by_name("boomerang")
	_expect(active_runtime._store_active_item({"item_data": boomerang_item}, active_slots, registry, owner), "boomerang should store into active slots")
	_expect(str(active_slots[0].get("icon_path", "")) == ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH, "stored boomerang slot should show the metal icon while gauntlet is equipped")

	var throw_controller: Object = ActiveItemThrowController.new()
	_expect(throw_controller.activate_boomerang(owner, registry), "boomerang activation should start with gauntlet equipped")
	var pending: Array[Dictionary] = throw_controller.get_pending_throws()
	_expect(pending.size() == 1 and bool(pending[0].get("gauntlet_equipped", false)), "windup should remember the gauntlet visual variant")
	throw_controller._throw_boomerang(owner, pending[0], registry)
	var boomerangs: Array[Dictionary] = throw_controller.get_boomerangs()
	_expect(boomerangs.size() == 1, "boomerang throw should create one projectile")
	var thrown: Dictionary = boomerangs[0]
	_expect(bool(thrown.get("gauntlet_equipped", false)), "projectile should carry gauntlet state")
	_expect(float(thrown.get("speed_jitter", 0.0)) > 2.0, "projectile launch speed should include stacked gauntlet roll")
	_expect_close(float(thrown.get("homing_multiplier", 0.0)), 2.0, "projectile homing multiplier should be captured")
	_expect_close(float(thrown.get("knockback_multiplier", 0.0)), 1.4, "projectile knockback multiplier should be captured")
	_expect_close(float(thrown.get("stun_multiplier", 0.0)), 1.6, "projectile stun multiplier should be captured")

	thrown["position"] = Vector2(owner.boss_pos.x + 50.0, owner.boss_pos.y + 20.0)
	throw_controller._try_apply_boomerang_boss_hit(thrown, Rect2(owner.boss_pos, Vector2(100.0, 40.0)), registry)
	_expect(bool(thrown.get("hit_boss", false)), "gauntlet boomerang should still hit the boss")
	_expect_close(float(throw_controller.grenade_boss_stun_timer_frames), 36.0 * 1.6, "boss stun should be boosted by the gauntlet")
	_expect_close(abs(float(throw_controller.grenade_boss_knockback_vel)), 28.0 * 1.4, "boss knockback should be boosted by the gauntlet")
	_expect(audio.hit_count == 1, "boomerang hit audio should still fire")

	print("reinforced_boomerang_gauntlet_port_smoke: ok")
	quit(0)


func _array_has_item(items: Array, item_name: String) -> bool:
	return not _find_item(items, item_name).is_empty()


func _find_item(items: Array, item_name: String) -> Dictionary:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return item_value
	return {}


func _roll_option_has_range(catalog: Object, option_key: String, minimum: float, maximum: float) -> bool:
	for option_value in catalog.get_roll_options("reinforced_boomerang_gauntlet"):
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		if str(option.get("key", "")) != option_key:
			continue
		return (
			abs(float(option.get("min", 0.0)) - minimum) <= 0.000001
			and abs(float(option.get("max", 0.0)) - maximum) <= 0.000001
		)
	return false


func _roll_option_has_values(catalog: Object, option_key: String, minimum: float, maximum: float, default_value: float) -> bool:
	for option_value in catalog.get_roll_options("reinforced_boomerang_gauntlet"):
		if not (option_value is Dictionary):
			continue
		var option: Dictionary = option_value
		if str(option.get("key", "")) != option_key:
			continue
		return (
			abs(float(option.get("min", 0.0)) - minimum) <= 0.000001
			and abs(float(option.get("max", 0.0)) - maximum) <= 0.000001
			and abs(float(option.get("default", 0.0)) - default_value) <= 0.000001
		)
	return false


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
