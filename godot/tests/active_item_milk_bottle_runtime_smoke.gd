extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldPickupFlow := preload("res://scripts/items/active_item_field_pickup_flow.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeLifecycleFacade := preload("res://scripts/items/active_item_runtime_lifecycle_facade.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const CharacterInfoOverlayActiveItemPresenter := preload("res://scripts/hud/character_info_overlay_active_item_presenter.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []
var _store_calls := 0
var _pickup_calls := 0
var _break_calls := 0


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos := Vector2(200.0, 700.0)
	var player_paddle_width := 80.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_paddle_scale := 1.0
	var dash_active := false
	var special_gauge := 0.0
	var special_gauge_max := 500.0


class FakeDashState:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return {"active": active}


class FakeActiveItemRuntime:
	extends RefCounted

	var spawn_calls: Array[Dictionary] = []

	func spawn_field_item(item_name: String, position: Variant = null) -> bool:
		spawn_calls.append({
			"name": item_name,
			"position": position,
		})
		return true

	func spawn_field_item_data(item_data: Dictionary, position: Variant = null) -> bool:
		spawn_calls.append({
			"name": str(item_data.get("name", "")),
			"item_data": item_data.duplicate(true),
			"position": position,
			"used_data_spawn": true,
		})
		return true


class FakeRegistry:
	extends RefCounted

	var dash_state: Object = null
	var active_item_runtime: Object = null

	func _init(p_dash_state: Object = null, p_active_item_runtime: Object = null) -> void:
		dash_state = p_dash_state
		active_item_runtime = p_active_item_runtime

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "smasher_dash_state":
			return dash_state
		if key == "active_item_runtime":
			return active_item_runtime
		return null


class FakeResettable:
	extends RefCounted

	func reset() -> void:
		pass


class FakeRuntime:
	extends RefCounted

	var field_spawn_controller: Object = FakeResettable.new()
	var throw_controller: Object = FakeResettable.new()
	var effect_controller: Object
	var debug_spawn_menu: Object = FakeResettable.new()
	var pending_throw_recovery: Object = FakeResettable.new()
	var slot_controller: Object = ActiveItemSlotController.new()

	func _init(p_effect_controller: Object) -> void:
		effect_controller = p_effect_controller


class FakeSkillState:
	extends RefCounted

	var windup_active := true
	var windup_elapsed := 1.0


func _init() -> void:
	_verify_catalog_and_assets()
	_verify_cheese_catalog_and_assets()
	_verify_milk_production_level_catalog()
	_verify_stationary_field_motion()
	_verify_runtime_spawn_entrypoint()
	_verify_pickup_and_dash_destruction()
	_verify_dash_break_effect_lifecycle()
	_verify_dash_break_render_wiring()
	_verify_milk_bottle_use_and_stage_reset()
	_verify_milk_bottle_stacking_and_collectable()
	_verify_cheese_gauge_restore()
	_verify_cheese_applies_size_buff()
	_verify_lingpet_skill_host_spawns_milk_bottle()

	if _failures.is_empty():
		print("active_item_milk_bottle_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_assets() -> void:
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("milk_bottle")
	_expect(not item_data.is_empty(), "milk bottle should build from the active item catalog")
	_expect(str(item_data.get("type", "")) == "active", "milk bottle should be an active item")
	_expect(str(item_data.get("effect", "")) == "milk_bottle", "milk bottle should route to the milk-bottle effect")
	_expect(bool(item_data.get("stationary_field_item", false)), "milk bottle should stand still on the field")
	_expect(bool(item_data.get("dash_destroy_on_player_contact", false)), "milk bottle should break on dash contact")
	_expect(not ActiveItemCatalog.FIELD_SPAWN_ORDER.has("milk_bottle"), "milk bottle should not enter the random field-spawn pool")
	_expect(is_equal_approx(float(item_data.get("paddle_scale_multiplier", 0.0)), 1.20), "milk bottle should scale the player paddle by 20 percent")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "milk bottle active-slot icon should load")
	_expect(ProjectResourceLoader.load_texture(str(item_data.get("field_icon_path", ""))) != null, "milk bottle field icon should load")


func _verify_cheese_catalog_and_assets() -> void:
	var catalog := ActiveItemCatalog.new()
	var expected_gain := {
		"cheddar_cheese": 300.0,
		"camembert_cheese": 400.0,
		"emmental_cheese": 500.0,
	}
	# Cheese now also carries the milk-bottle size buff at its bound level's scale
	# (cheddar=Lv.3=1.16, camembert=Lv.4=1.18, emmental=Lv.5=1.20).
	var expected_scale := {
		"cheddar_cheese": 1.16,
		"camembert_cheese": 1.18,
		"emmental_cheese": 1.20,
	}
	for item_name in expected_gain.keys():
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name))
		_expect(not item_data.is_empty(), "%s should build from the active item catalog" % item_name)
		_expect(str(item_data.get("type", "")) == "active", "%s should be an active item" % item_name)
		_expect(str(item_data.get("effect", "")) == "cheese", "%s should route to the cheese effect" % item_name)
		_expect(bool(item_data.get("stationary_field_item", false)), "%s should stand still on the field" % item_name)
		_expect(bool(item_data.get("dash_destroy_on_player_contact", false)), "%s should break on dash contact" % item_name)
		_expect(bool(item_data.get("lingpet_generated_only", false)), "%s should remain lingpet-generated only" % item_name)
		_expect(is_equal_approx(float(item_data.get("paddle_scale_multiplier", 0.0)), float(expected_scale[item_name])), "%s should carry its milk-bottle size multiplier" % item_name)
		_expect(is_equal_approx(float(item_data.get("gauge_gain", 0.0)), float(expected_gain[item_name])), "%s should carry its configured gauge restore amount" % item_name)
		_expect(not ActiveItemCatalog.FIELD_SPAWN_ORDER.has(item_name), "%s should not enter the random field-spawn pool" % item_name)
		_expect(ProjectResourceLoader.load_texture(str(item_data.get("icon_path", ""))) != null, "%s active-slot icon should load" % item_name)
		_expect(ProjectResourceLoader.load_texture(str(item_data.get("field_icon_path", ""))) != null, "%s field icon should load" % item_name)


func _verify_milk_production_level_catalog() -> void:
	var expected_cooldowns := [50.0, 47.0, 44.0, 41.0, 37.0]
	var expected_scales := [1.12, 1.14, 1.16, 1.18, 1.20]
	var expected_cheese_chances := [0.0, 0.0, 0.30, 0.30, 0.30]
	for index in range(expected_cooldowns.size()):
		var level := index + 1
		var skill_data: Dictionary = LingpetCatalog.get_active_skill("milkring", "milkring_milk_production", level)
		_expect(is_equal_approx(float(skill_data.get("cooldown", -1.0)), float(expected_cooldowns[index])), "milk production Lv.%d cooldown should use the explicit user value" % level)
		_expect(is_equal_approx(float(skill_data.get("paddle_scale_multiplier", -1.0)), float(expected_scales[index])), "milk production Lv.%d should expose the milk-bottle scale multiplier" % level)
		_expect(is_equal_approx(float(skill_data.get("cheese_chance", -1.0)), float(expected_cheese_chances[index])), "milk production Lv.%d should expose the cheese chance" % level)
		_expect(is_equal_approx(float(skill_data.get("active_skill_level_cooldown_reduction_pct", -1.0)), 0.0), "milk production Lv.%d should not double-apply the universal cooldown tax" % level)
		_expect(bool(skill_data.get("cooldown_by_level_authoritative", false)), "milk production Lv.%d should mark cooldown_by_level authoritative" % level)


func _verify_stationary_field_motion() -> void:
	var motion: Object = ActiveItemFieldItemMotion.new()
	var item_data: Dictionary = ActiveItemCatalog.new().build_item_by_name("milk_bottle")
	var spawn_pos := Vector2(240.0, 725.0)
	var field_item: Dictionary = motion.build_field_item(item_data, spawn_pos)
	var player_rect := Rect2(Vector2(20.0, 20.0), Vector2(80.0, 50.0))

	var skipped_state: int = motion.advance_field_item_in_place(field_item, player_rect, {}, 1.0 / 60.0)
	_expect(skipped_state == ActiveItemFieldItemMotion.ADVANCE_SKIPPED_ALIVE, "fresh milk bottle should still skip the first field update")
	var alive_state: int = motion.advance_field_item_in_place(field_item, player_rect, {}, 1.0 / 60.0)
	_expect(alive_state == ActiveItemFieldItemMotion.ADVANCE_ALIVE, "stationary milk bottle should stay alive after the first update")
	_expect(_get_vector2(field_item, "position") == spawn_pos, "stationary milk bottle should not drift after spawning")
	_expect(_get_vector2(field_item, "velocity") == Vector2.ZERO, "stationary milk bottle should keep zero velocity")


func _verify_runtime_spawn_entrypoint() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	_expect(runtime.spawn_field_item("milk_bottle", Vector2(240.0, 725.0)), "active item runtime should spawn a lingpet-created milk bottle by item id")
	var spawned_items: Array[Dictionary] = runtime.get_field_spawned_items()
	_expect(spawned_items.size() == 1, "active item runtime should keep the spawned milk bottle in field items")
	if spawned_items.is_empty():
		return
	var field_item: Dictionary = spawned_items[0]
	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	_expect(str(item_data.get("name", "")) == "milk_bottle", "runtime-spawned field item should preserve milk bottle item data")
	_expect(bool(field_item.get("stationary_field_item", false)), "runtime-spawned milk bottle should use stationary field item motion")


func _verify_pickup_and_dash_destruction() -> void:
	var normal_owner := FakeOwner.new()
	var normal_survivors: Array[Dictionary] = _run_pickup_update(normal_owner, FakeRegistry.new())
	_expect(normal_survivors.is_empty(), "normal contact should remove the collected milk bottle from the field")
	_expect(normal_owner.active_item_slots.size() == 1, "normal contact should store milk bottle in an active item slot")
	_expect(str(_get_dictionary(normal_owner.active_item_slots[0], "item_data").get("name", "")) == "milk_bottle", "stored slot should preserve milk bottle item data")
	_expect(_pickup_calls == 1, "normal milk bottle pickup should trigger pickup feedback")

	var dash_state := FakeDashState.new()
	dash_state.active = true
	var dash_owner := FakeOwner.new()
	var previous_store_calls := _store_calls
	var previous_pickup_calls := _pickup_calls
	var previous_break_calls := _break_calls
	var dash_survivors: Array[Dictionary] = _run_pickup_update(dash_owner, FakeRegistry.new(dash_state), true)
	_expect(dash_survivors.is_empty(), "dash contact should remove the broken milk bottle from the field")
	_expect(dash_owner.active_item_slots.is_empty(), "dash contact should not store a broken milk bottle")
	_expect(_store_calls == previous_store_calls, "dash contact should skip the active-slot store path")
	_expect(_pickup_calls == previous_pickup_calls, "dash contact should skip pickup feedback")
	_expect(_break_calls == previous_break_calls + 1, "dash contact should trigger the milk-bottle break effect hook")


func _verify_dash_break_effect_lifecycle() -> void:
	var controller: Object = ActiveItemFieldSpawnController.new()
	var item_data: Dictionary = ActiveItemCatalog.new().build_item_by_name("milk_bottle")
	_expect(controller.debug_spawn_item_data(item_data, Vector2(240.0, 725.0)), "field spawn controller should spawn a test milk bottle for break VFX")
	var spawned_items: Array[Dictionary] = controller.get_spawned_items()
	_expect(spawned_items.size() == 1, "test milk bottle should exist before dash break VFX")
	if not spawned_items.is_empty():
		spawned_items[0]["spawn_skip_update_once"] = false

	var dash_state := FakeDashState.new()
	dash_state.active = true
	controller.update(
		FakeOwner.new(),
		FakeRegistry.new(dash_state),
		1.0 / 60.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_pickup_feedback")
	)
	_expect(controller.get_spawned_items().is_empty(), "dash-broken milk bottle should leave the spawned-item list")
	_expect(controller.get_field_item_break_effect_count_for_tests() == 1, "dash-broken milk bottle should leave one break VFX")
	_expect(controller.has_visible_field_items(), "break VFX should keep the field render pass visible after the bottle is removed")
	var break_effects: Array[Dictionary] = controller.get_field_item_break_effects()
	if not break_effects.is_empty():
		var effect: Dictionary = break_effects[0]
		_expect(str(effect.get("kind", "")) == "milk_bottle_break", "milk bottle dash VFX should publish the milk-bottle break kind")
		_expect(_get_array(effect, "shards").size() >= 6, "milk bottle break VFX should include visible glass shards")
		_expect(_get_array(effect, "droplets").size() >= 6, "milk bottle break VFX should include milk droplets")

	controller.update(
		FakeOwner.new(),
		FakeRegistry.new(),
		0.20,
		Callable(self, "_store_field_item"),
		Callable(self, "_pickup_feedback")
	)
	_expect(controller.get_field_item_break_effect_count_for_tests() == 1, "milk bottle break VFX should persist briefly after impact")
	controller.update(
		FakeOwner.new(),
		FakeRegistry.new(),
		1.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_pickup_feedback")
	)
	_expect(controller.get_field_item_break_effect_count_for_tests() == 0, "milk bottle break VFX should expire after its one-shot duration")


func _verify_dash_break_render_wiring() -> void:
	var render_facade_source: String = FileAccess.get_file_as_string("res://scripts/items/active_item_runtime_render_facade.gd")
	var field_renderer_source: String = FileAccess.get_file_as_string("res://scripts/items/active_item_field_renderer.gd")
	_expect(render_facade_source.find("get_field_item_break_effects") >= 0 and render_facade_source.find("draw_field_item_break_effects") >= 0, "active item render facade should forward field-item break VFX to the field renderer")
	_expect(field_renderer_source.find("_draw_milk_bottle_break_shards") >= 0 and field_renderer_source.find("_draw_milk_bottle_break_droplets") >= 0, "field renderer should draw milk bottle shards and milk droplets for dash break VFX")


func _verify_milk_bottle_use_and_stage_reset() -> void:
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("milk_bottle")
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(200.0, 700.0)
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0

	var effect_controller: Object = ActiveItemEffectController.new()
	_expect(effect_controller.activate_milk_bottle(item_data, owner, FakeRegistry.new()), "milk bottle should activate through the active item effect controller")
	_expect(effect_controller.is_milk_bottle_active(), "milk bottle state should become active after use")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.20), "milk bottle effect should report a 1.2 active item paddle scale")
	_expect(is_equal_approx(owner.player_paddle_width, 186.0), "milk bottle use should enlarge the owner paddle width by 20 percent")
	_expect(is_equal_approx(owner.player_paddle_height, 60.0), "milk bottle use should enlarge the owner paddle height by 20 percent")
	_expect(is_equal_approx(owner.player_pos.y + owner.player_paddle_height, 750.0), "milk bottle resize should keep the paddle bottom-aligned")

	var lifecycle := ActiveItemRuntimeLifecycleFacade.new()
	lifecycle.reset_for_stage_transition(FakeRuntime.new(effect_controller), owner, FakeRegistry.new())
	_expect(not effect_controller.is_milk_bottle_active(), "stage transition reset should clear milk bottle active state")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.0), "stage transition reset should clear milk bottle scale")
	_expect(is_equal_approx(owner.player_paddle_width, 155.0), "stage transition reset should restore owner paddle width after milk bottle")
	_expect(is_equal_approx(owner.player_paddle_height, 50.0), "stage transition reset should restore owner paddle height after milk bottle")


func _verify_milk_bottle_stacking_and_collectable() -> void:
	var catalog := ActiveItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("milk_bottle")
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(200.0, 700.0)
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0
	var effect_controller: Object = ActiveItemEffectController.new()
	var registry := FakeRegistry.new()

	# First use: base 1.0 + 0.20 increment = 1.20.
	_expect(effect_controller.activate_milk_bottle(item_data, owner, registry), "first milk bottle use should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.20), "first milk use should set paddle scale to 1.20")

	# Regression: a second milk bottle must remain collectable while the buff is active.
	# The old can_store gate returned false here, breaking Milku's continuous production.
	_expect(effect_controller.can_store_item("milk_bottle"), "milk bottle must stay collectable while milk_bottle_active is true")

	# Second use stacks: 1.20 + 0.20 = 1.40.
	_expect(effect_controller.activate_milk_bottle(item_data, owner, registry), "second milk bottle use should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.40), "second milk use should stack paddle scale to 1.40")

	# Third use reaches the +60% cap: 1.40 + 0.20 clamped to 1.60.
	_expect(effect_controller.activate_milk_bottle(item_data, owner, registry), "third milk bottle use should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.60), "third milk use should reach the +60% cap (1.60)")

	# Fourth use stays capped (no overflow past +60%).
	_expect(effect_controller.activate_milk_bottle(item_data, owner, registry), "fourth milk bottle use should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.60), "milk paddle scale must not exceed the +60% cap")


func _verify_cheese_gauge_restore() -> void:
	var catalog := ActiveItemCatalog.new()
	var effect_controller: Object = ActiveItemEffectController.new()
	var registry := FakeRegistry.new()
	var cases := [
		{"name": "cheddar_cheese", "start": 20.0, "expected": 320.0},
		{"name": "camembert_cheese", "start": 50.0, "expected": 450.0},
		{"name": "emmental_cheese", "start": 0.0, "expected": 500.0},
		{"name": "cheddar_cheese", "start": 450.0, "expected": 500.0},
	]
	for spec in cases:
		var owner := FakeOwner.new()
		owner.special_gauge = float(spec.get("start", 0.0))
		var item_data: Dictionary = catalog.build_item_by_name(str(spec.get("name", "")))
		_expect(effect_controller.activate_cheese(item_data, owner, registry), "%s should activate through the cheese effect controller path" % str(spec.get("name", "")))
		_expect(is_equal_approx(owner.special_gauge, float(spec.get("expected", 0.0))), "%s should restore gauge to the expected clamped value" % str(spec.get("name", "")))
		_expect(effect_controller.is_milk_bottle_active(), "%s should also activate the milk-bottle size state" % str(spec.get("name", "")))


func _verify_cheese_applies_size_buff() -> void:
	# Cheese must grant BOTH the gauge restore AND the milk-bottle size buff in a single
	# activation, stacking into the same shared scale pool (and +60% cap) as milk bottles.
	# Reverse check: on the pre-change code cheese carried no size, so every scale
	# assertion below would report 1.0 and fail.
	var catalog := ActiveItemCatalog.new()
	var effect_controller: Object = ActiveItemEffectController.new()
	var registry := FakeRegistry.new()

	var owner := FakeOwner.new()
	owner.player_pos = Vector2(200.0, 700.0)
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0
	owner.special_gauge = 20.0

	# Cheddar (Lv.3): +16% size and +300 gauge from one pickup.
	_expect(effect_controller.activate_cheese(catalog.build_item_by_name("cheddar_cheese"), owner, registry), "cheddar cheese should activate")
	_expect(effect_controller.is_milk_bottle_active(), "cheddar cheese should turn on the milk-bottle size state")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.16), "cheddar cheese should apply the Lv.3 +16% size step")
	_expect(is_equal_approx(owner.special_gauge, 320.0), "cheddar cheese should restore gauge in the same activation as the size buff")
	_expect(is_equal_approx(owner.player_paddle_width, 179.8), "cheddar cheese should resize the owner paddle width by 16 percent")

	# Camembert (Lv.4): stacks +18% onto the shared pool -> 1.16 + 0.18 = 1.34.
	_expect(effect_controller.activate_cheese(catalog.build_item_by_name("camembert_cheese"), owner, registry), "camembert cheese should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.34), "cheese size should stack into the shared milk pool (1.16 + 0.18)")

	# Emmental (Lv.5) twice: 1.34 + 0.20 = 1.54, then +0.20 clamps to the +60% cap 1.60.
	_expect(effect_controller.activate_cheese(catalog.build_item_by_name("emmental_cheese"), owner, registry), "first emmental cheese should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.54), "cheese size should keep stacking (1.34 + 0.20)")
	_expect(effect_controller.activate_cheese(catalog.build_item_by_name("emmental_cheese"), owner, registry), "second emmental cheese should activate")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.60), "stacked cheese size must clamp to the +60% cap shared with milk bottles")

	# A milk bottle picked up afterward shares the same capped pool (no double buff system).
	_expect(effect_controller.activate_milk_bottle(catalog.build_item_by_name("milk_bottle"), owner, FakeRegistry.new()), "milk bottle should still activate after cheese")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.60), "milk bottle after cheese must stay on the shared +60% cap")


func _verify_lingpet_skill_host_spawns_milk_bottle() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var registry := FakeRegistry.new(null, active_runtime)
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(40.0, 700.0)
	owner.player_paddle_width = 155.0
	var skill_state := FakeSkillState.new()

	host.update(
		0.5,
		owner,
		registry,
		"milkring_milk_production",
		{
			"skill_state": skill_state,
			"windup_seconds": 3.0,
			"companion_pos": Vector2(320.0, 620.0),
		}
	)
	var windup_snapshot: Dictionary = host.get_snapshot()
	_expect(bool(windup_snapshot.get("milk_production_active", false)), "Milkring milk-production windup should mark production active")
	_expect(is_equal_approx(float(windup_snapshot.get("milk_production_progress", 0.0)), 0.5), "Milkring milk-production gauge should track windup progress")
	_expect(host.is_launch_blocked("milkring_milk_production"), "Milkring milk-production should block relaunch while producing")

	var launched: bool = host.launch(
		"milkring_milk_production",
		Vector2(320.0, 620.0),
		owner,
		{
			"registry": registry,
			"companion_pos": Vector2(320.0, 620.0),
			"active_skill_level": 2,
			"paddle_scale_multiplier": 1.14,
			"milk_production_cheese_roll": 0.95,
		}
	)
	_expect(launched, "Milkring milk-production launch should spawn a milk bottle through active item runtime")
	_expect(active_runtime.spawn_calls.size() == 1, "Milkring milk-production should request exactly one field milk bottle")
	var spawn_call: Dictionary = active_runtime.spawn_calls[0]
	_expect(str(spawn_call.get("name", "")) == "milk_bottle", "Milkring milk-production should spawn the milk bottle item id")
	_expect(bool(spawn_call.get("used_data_spawn", false)), "Milkring milk-production should use item-data spawn for level-specific milk bottle data")
	_expect(is_equal_approx(float(_get_dictionary(spawn_call, "item_data").get("paddle_scale_multiplier", 0.0)), 1.14), "Milkring milk-production should inject the level-specific milk-bottle scale")
	_expect(is_equal_approx(_get_vector2(spawn_call, "position").y, 725.0), "Milkring milk-production should stand the bottle on the player floor")
	_expect(host.get_milk_production_spawn_count_for_tests() == 1, "Milkring skill host should expose milk production spawn count for tests")
	_verify_level_milk_bottle_slot_tooltip_and_use(spawn_call)

	var cheese_runtime := FakeActiveItemRuntime.new()
	var cheese_registry := FakeRegistry.new(null, cheese_runtime)
	var cheese_launched: bool = host.launch(
		"milkring_milk_production",
		Vector2(300.0, 620.0),
		owner,
		{
			"registry": cheese_registry,
			"companion_pos": Vector2(300.0, 620.0),
			"active_skill_level": 3,
			"cheese_chance": 0.30,
			"milk_production_cheese_roll": 0.10,
		}
	)
	_expect(cheese_launched, "Milkring milk-production Lv.3 should launch when the forced cheese roll succeeds")
	_expect(cheese_runtime.spawn_calls.size() == 1, "Milkring milk-production should request exactly one cheese field item")
	if not cheese_runtime.spawn_calls.is_empty():
		_expect(str(cheese_runtime.spawn_calls[0].get("name", "")) == "cheddar_cheese", "Milkring milk-production Lv.3 should spawn Cheddar Cheese on a successful cheese roll")

	var failed_roll_runtime := FakeActiveItemRuntime.new()
	var failed_roll_registry := FakeRegistry.new(null, failed_roll_runtime)
	var failed_roll_launched: bool = host.launch(
		"milkring_milk_production",
		Vector2(300.0, 620.0),
		owner,
		{
			"registry": failed_roll_registry,
			"companion_pos": Vector2(300.0, 620.0),
			"active_skill_level": 5,
			"cheese_chance": 0.30,
			"milk_production_cheese_roll": 0.90,
		}
	)
	_expect(failed_roll_launched, "Milkring milk-production Lv.5 should launch when the forced cheese roll fails")
	_expect(failed_roll_runtime.spawn_calls.size() == 1, "Milkring milk-production failed cheese roll should still request one field item")
	if not failed_roll_runtime.spawn_calls.is_empty():
		_expect(str(failed_roll_runtime.spawn_calls[0].get("name", "")) == "milk_bottle", "Milkring milk-production failed cheese roll should spawn a milk bottle instead")


func _verify_level_milk_bottle_slot_tooltip_and_use(spawn_call: Dictionary) -> void:
	var spawned_item_data: Dictionary = _get_dictionary(spawn_call, "item_data")
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(200.0, 700.0)
	owner.player_paddle_width = 155.0
	owner.player_paddle_height = 50.0
	var slot_controller: Object = ActiveItemSlotController.new()
	var field_item := {
		"item_data": spawned_item_data.duplicate(true),
		"position": _get_vector2(spawn_call, "position"),
	}
	_expect(slot_controller.store_active_item(field_item, owner.active_item_slots, FakeRegistry.new(), Callable(), owner), "level-scaled milk bottle should store through the real active-slot controller")
	_expect(owner.active_item_slots.size() == 1, "level-scaled milk bottle should occupy one active slot")
	if owner.active_item_slots.is_empty():
		return
	var stored_item: Dictionary = owner.active_item_slots[0]
	_expect(str(stored_item.get("name", "")) == "milk_bottle", "level-scaled slot item should keep the milk bottle id")
	_expect(is_equal_approx(float(stored_item.get("paddle_scale_multiplier", 0.0)), 1.14), "level-scaled slot item should preserve the Lv.2 scale multiplier")
	var tooltip_body: String = CharacterInfoOverlayActiveItemPresenter.build_body(stored_item, int(stored_item.get("cooldown_msec", ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC)))
	_expect(tooltip_body.find("14%") >= 0, "level-scaled slot tooltip should keep the Lv.2 milk-bottle percent")
	_expect(tooltip_body.find("20%") < 0, "level-scaled slot tooltip should not fall back to the catalog Lv.5 milk-bottle percent")
	var effect_controller: Object = ActiveItemEffectController.new()
	_expect(effect_controller.activate_milk_bottle(stored_item, owner, FakeRegistry.new()), "stored level-scaled milk bottle should activate through the normal effect controller")
	_expect(is_equal_approx(effect_controller.get_player_paddle_scale(), 1.14), "stored level-scaled milk bottle should apply its preserved scale")
	_expect(is_equal_approx(owner.player_paddle_width, 176.7), "stored level-scaled milk bottle should resize paddle width by 14 percent")
	_expect(is_equal_approx(owner.player_paddle_height, 57.0), "stored level-scaled milk bottle should resize paddle height by 14 percent")


func _run_pickup_update(owner: Object, registry: Object, include_break_callback: bool = false) -> Array[Dictionary]:
	var motion: Object = ActiveItemFieldItemMotion.new()
	var pickup_flow: Object = ActiveItemFieldPickupFlow.new()
	var item_data: Dictionary = ActiveItemCatalog.new().build_item_by_name("milk_bottle")
	var field_item: Dictionary = motion.build_field_item(item_data, Vector2(240.0, 725.0))
	field_item["spawn_skip_update_once"] = false
	var spawned_items: Array[Dictionary] = [field_item]
	if include_break_callback:
		return pickup_flow.update_field_items(
			owner,
			registry,
			spawned_items,
			motion,
			1.0 / 60.0,
			Callable(self, "_store_field_item"),
			Callable(self, "_pickup_feedback"),
			null,
			Callable(self, "_dash_break_feedback")
		)
	return pickup_flow.update_field_items(
		owner,
		registry,
		spawned_items,
		motion,
		1.0 / 60.0,
		Callable(self, "_store_field_item"),
		Callable(self, "_pickup_feedback")
	)


func _store_field_item(field_item: Dictionary, active_item_slots: Array, _registry: Object, _owner: Object) -> bool:
	_store_calls += 1
	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	active_item_slots.append({"item_data": item_data.duplicate(true)})
	return true


func _pickup_feedback(_field_item: Dictionary, _registry: Object) -> void:
	_pickup_calls += 1


func _dash_break_feedback(field_item: Dictionary, _registry: Object) -> void:
	_break_calls += 1
	_expect(bool(field_item.get("destroyed_by_dash", false)), "dash break callback should receive the destroyed-by-dash marker")
	_expect(_get_vector2(field_item, "position").y >= 700.0, "dash break callback should receive the milk bottle floor position")


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
