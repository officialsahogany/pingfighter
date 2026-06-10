extends SceneTree

const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemVenomMistRuntime := preload("res://scripts/items/mythic_item_venom_mist_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ViperSkillCoreFlipRuntime := preload("res://scripts/characters/viper_skill_core_flip_runtime.gd")
const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var selected_character_type := "viper"
	var current_stage := 1
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(4.0, -9.0)
	var ball_active := true

	func queue_redraw() -> void:
		pass


class FakeBossGauge:
	var boss_special_gauge := 100.0

	func drain_boss_special_gauge(amount: float) -> void:
		boss_special_gauge = max(0.0, boss_special_gauge - max(0.0, amount))


class FakeAudio:
	var active_count := 0

	func play_active_item() -> void:
		active_count += 1

	func play_item_get() -> void:
		pass


class FakeRegistry:
	var mythic_runtime: Object
	var stage1_gauge: Object
	var game_audio: Object

	func _init(runtime: Object, gauge: Object = null, audio: Object = null) -> void:
		mythic_runtime = runtime
		stage1_gauge = gauge
		game_audio = audio

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_runtime
			"stage1_dalji_whip_skill_state":
				return stage1_gauge
			"game_audio":
				return game_audio
		return null


func _init() -> void:
	_test_runtime_constant_ownership()
	_test_catalog_and_arm_slots()
	_test_runtime_poison_mist_slow_and_round_clear()
	_test_viper_only_spawn_filter()
	_test_core_flip_hook_poisons_ball()
	print("venom_mist_gauntlet_port_smoke: ok")
	quit(0)


func _test_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemVenomMistRuntime.RADIUS, 120.0), "Venom Mist helper should own field radius")
	_expect(MythicItemVenomMistRuntime.PARTICLE_COUNT == 46, "Venom Mist helper should own particle count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_venom_mist_runtime.gd")
	_expect(not runtime_source.contains("VENOM_MIST_CONSTANTS"), "runtime facade should not regain VENOM_MIST_CONSTANTS")
	_expect(not runtime_source.contains("const VENOM_MIST_"), "runtime facade should not regain Venom Mist runtime constants")
	_expect(runtime_source.find("return venom_mist_runtime.is_equipped(self)") >= 0, "runtime facade should delegate Venom Mist equipped checks")
	_expect(runtime_source.find("return venom_mist_runtime.get_trigger_chance_pct(self)") >= 0, "runtime facade should delegate Venom Mist chance rolls")
	_expect(runtime_source.find("roll_query.get_equipped_roll_sum(self, ITEM_VENOM_MIST_GAUNTLET") < 0, "runtime facade should not keep Venom Mist roll math inline")
	_expect(helper_source.contains("const GAUGE_DRAIN_PER_FRAME"), "Venom Mist helper should keep gauge drain constants")
	_expect(helper_source.find("func get_trigger_chance_pct(") >= 0, "Venom Mist helper should own trigger roll math")
	_expect(helper_source.find("func get_duration_sec(") >= 0, "Venom Mist helper should own duration roll math")


func _test_catalog_and_arm_slots() -> void:
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("venom_mist_gauntlet")
	_expect(not item_data.is_empty(), "Venom Mist Gauntlet should build from catalog")
	_expect(str(item_data.get("slot", "")) == "arm", "Venom Mist Gauntlet should use the shared arm slot")
	_expect(str(item_data.get("character_restriction", "")) == "viper", "Venom Mist Gauntlet should be marked Viper-only")
	_expect(is_equal_approx(float(item_data.get("chance", 0.0)), 0.004), "field chance should match Python")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "Venom Mist Gauntlet icon should load")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "venom_mist_gauntlet"), "Venom Mist Gauntlet should be in passive field-spawn items")
	var roll_options: Array = catalog.get_roll_options("venom_mist_gauntlet")
	_expect(_has_roll_option(roll_options, "mist_trigger_chance_pct", 30.0, 50.0, 40.0), "trigger chance roll should match Python")
	_expect(_has_roll_option(roll_options, "mist_duration_sec", 2.0, 5.0, 3.0), "mist duration roll should match Python")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(runtime)
	_expect(runtime.acquire_item("venom_mist_gauntlet", owner, registry, {
		"mist_trigger_chance_pct": 50.0,
		"mist_duration_sec": 4.0,
	}, true, false) >= 0, "first gauntlet should equip")
	_expect(runtime.acquire_item("venom_mist_gauntlet", owner, registry, {
		"mist_trigger_chance_pct": 50.0,
		"mist_duration_sec": 5.0,
	}, true, false) >= 0, "second gauntlet should equip")
	_expect(owner.equipment_slots.has("left_arm") and owner.equipment_slots.has("right_arm"), "duplicate gauntlets should fill left/right arms")
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(int(snapshot.get("venom_mist_gauntlet_count", 0)) == 2, "two gauntlets should stack by count")
	_expect(is_equal_approx(float(snapshot.get("venom_mist_trigger_chance_pct", 0.0)), 100.0), "trigger chance should stack and cap at 100%")
	_expect(is_equal_approx(float(snapshot.get("venom_mist_duration_sec", 0.0)), 5.0), "mist duration should use the best equipped roll")


func _test_runtime_poison_mist_slow_and_round_clear() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var gauge := FakeBossGauge.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, gauge, audio)
	_expect(runtime.equip_item("venom_mist_gauntlet", owner, registry, {
		"mist_trigger_chance_pct": 100.0,
		"mist_duration_sec": 3.0,
	}, false), "gauntlet should equip for runtime test")

	_expect(runtime.try_venom_mist_poison_ball({"registry": registry}), "100% trigger should poison the ball")
	_expect(runtime.is_venom_mist_ball_poisoned(), "poisoned state should persist until boss guard")
	_expect(runtime.try_venom_mist_poison_ball({"registry": registry}), "already-poisoned ball should not reroll")

	var boss_center := Vector2(owner.boss_pos.x + 50.0, owner.boss_pos.y + 20.0)
	_expect(runtime.consume_venom_mist_ball_poison(boss_center, {"registry": registry}), "boss guard should consume poison into a mist field")
	_expect(not runtime.is_venom_mist_ball_poisoned(), "consuming poison should clear the ball overlay state")
	_expect(runtime.is_venom_mist_field_active(), "mist field should be active after consume")
	_expect(audio.active_count >= 2, "poison and mist spawn should route an audio cue")

	runtime.update(owner, registry, 1.0 / 60.0)
	runtime.update(owner, registry, 1.0 / 60.0)
	var ai_context: Dictionary = runtime.get_boss_ai_context()
	_expect(bool(ai_context.get("venom_mist_boss_slow_active", false)), "boss should be slowed while inside the mist")
	_expect(is_equal_approx(float(ai_context.get("venom_mist_boss_slow_multiplier", 0.0)), 0.3), "mist slow should match Python's 70% reduction")
	_expect(gauge.boss_special_gauge < 100.0, "mist should drain boss special gauge over time")

	runtime.clear_venom_mist_round_state()
	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(not bool(snapshot.get("venom_mist_field_active", true)), "round clear should remove active mist")
	_expect(not bool(snapshot.get("venom_mist_ball_poisoned", true)), "round clear should remove poisoned ball")
	_expect(bool(snapshot.get("venom_mist_gauntlet_equipped", false)), "round clear should preserve equipped gauntlet")
	_expect(is_equal_approx(float(snapshot.get("venom_mist_trigger_chance_pct", 0.0)), 100.0), "round clear should preserve roll-derived chance")


func _test_viper_only_spawn_filter() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var registry := FakeRegistry.new(runtime)
	var controller: Object = ActiveItemFieldSpawnController.new()
	var smasher_owner := FakeOwner.new()
	smasher_owner.selected_character_type = "smasher"
	var viper_owner := FakeOwner.new()
	viper_owner.selected_character_type = "viper"
	_expect(not _array_has_item(controller._build_spawn_candidates(registry, smasher_owner), "venom_mist_gauntlet"), "non-Viper field pool should exclude Venom Mist Gauntlet")
	_expect(_array_has_item(controller._build_spawn_candidates(registry, viper_owner), "venom_mist_gauntlet"), "Viper field pool should include Venom Mist Gauntlet")


func _test_core_flip_hook_poisons_ball() -> void:
	var item_runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(item_runtime)
	_expect(item_runtime.equip_item("venom_mist_gauntlet", owner, registry, {
		"mist_trigger_chance_pct": 100.0,
		"mist_duration_sec": 3.0,
	}, false), "gauntlet should equip before Core Flip hook test")
	var viper_runtime: Object = ViperSkillRuntime.new()
	var core_flip_source := FileAccess.get_file_as_string("res://scripts/characters/viper_skill_core_flip_runtime.gd")
	_expect(core_flip_source.find("_apply_core_flip_mythic_hit(runtime, deps)") >= 0, "Core Flip kick hit should keep the mythic item hook")
	ViperSkillCoreFlipRuntime._apply_core_flip_mythic_hit(viper_runtime, {
		"registry": registry,
		"mythic_item_runtime": item_runtime,
	})
	_expect(item_runtime.is_venom_mist_ball_poisoned(), "Core Flip hit should poison the ball through Venom Mist Gauntlet")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		var item: Dictionary = item_value if item_value is Dictionary else {}
		if str(item.get("name", "")) == item_name:
			return true
	return false


func _has_roll_option(options: Array, key: String, min_value: float, max_value: float, default_value: float) -> bool:
	for option_value in options:
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if str(option.get("key", "")) != key:
			continue
		return (
			is_equal_approx(float(option.get("min", 0.0)), min_value)
			and is_equal_approx(float(option.get("max", 0.0)), max_value)
			and is_equal_approx(float(option.get("default", 0.0)), default_value)
		)
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
