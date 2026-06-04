extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldPickupFlow := preload("res://scripts/items/active_item_field_pickup_flow.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeLifecycleFacade := preload("res://scripts/items/active_item_runtime_lifecycle_facade.gd")
const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
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
	_verify_stationary_field_motion()
	_verify_runtime_spawn_entrypoint()
	_verify_pickup_and_dash_destruction()
	_verify_dash_break_effect_lifecycle()
	_verify_dash_break_render_wiring()
	_verify_milk_bottle_use_and_stage_reset()
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
		}
	)
	_expect(launched, "Milkring milk-production launch should spawn a milk bottle through active item runtime")
	_expect(active_runtime.spawn_calls.size() == 1, "Milkring milk-production should request exactly one field milk bottle")
	var spawn_call: Dictionary = active_runtime.spawn_calls[0]
	_expect(str(spawn_call.get("name", "")) == "milk_bottle", "Milkring milk-production should spawn the milk bottle item id")
	_expect(is_equal_approx(_get_vector2(spawn_call, "position").y, 725.0), "Milkring milk-production should stand the bottle on the player floor")
	_expect(host.get_milk_production_spawn_count_for_tests() == 1, "Milkring skill host should expose milk production spawn count for tests")


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
