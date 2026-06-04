extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeRenderFacade := preload("res://scripts/items/active_item_runtime_render_facade.gd")

var _failures: Array[String] = []


class FakeTimerStack:
	extends RefCounted

	var claim_count := 0

	func claim(_key: String, _active: bool) -> int:
		claim_count += 1
		return claim_count - 1


class FakeRegistry:
	extends RefCounted

	var timer_stack := FakeTimerStack.new()

	func get_instance(key: String) -> Object:
		if key == "horizontal_timer_gauge_stack":
			return timer_stack
		return null


class FakeFieldSpawnController:
	extends RefCounted

	var visible := true

	func has_visible_field_items() -> bool:
		return visible

	func get_item_spawn_portals() -> Array:
		return [{"portal": true}]

	func get_spawned_items() -> Array:
		return [{"item": true}]


class FakeThrowController:
	extends RefCounted

	var visible := true

	func has_visible_effects() -> bool:
		return visible

	func get_pending_throws() -> Array:
		return [{"pending": true}]

	func get_grenades() -> Array:
		return []

	func get_flares() -> Array:
		return []

	func get_tear_gas_projectiles() -> Array:
		return []

	func get_tear_gas_zones() -> Array:
		return []

	func get_dynamites() -> Array:
		return []

	func get_placed_dynamites() -> Array:
		return []

	func get_molotovs() -> Array:
		return []

	func get_molotov_fire_zones() -> Array:
		return []

	func get_boomerangs() -> Array:
		return []

	func get_banana_projectiles() -> Array:
		return []

	func get_landed_bananas() -> Array:
		return []

	func get_soap_projectiles() -> Array:
		return []

	func get_landed_soaps() -> Array:
		return []

	func get_boomerang_particles() -> Array:
		return []

	func get_banana_particles() -> Array:
		return []

	func get_soap_particles() -> Array:
		return []

	func get_soap_foam_trails() -> Array:
		return []

	func get_spider_mines() -> Array:
		return []

	func get_spider_mine_particles() -> Array:
		return []

	func get_dynamite_explosions() -> Array:
		return []

	func get_explosion_zones() -> Array:
		return []

	func get_flare_zones() -> Array:
		return []


class FakeEffectController:
	extends RefCounted

	var field_visible := true
	var pickup_visible := false

	func has_field_effects() -> bool:
		return field_visible

	func has_pickup_effect() -> bool:
		return pickup_visible

	func get_pickup_effect() -> Dictionary:
		return {"pickup": true}

	func get_pickup_particles() -> Array:
		return [{"particle": true}]

	func get_regeneration_potion_rings() -> Array:
		return []

	func get_regeneration_potion_particles() -> Array:
		return []

	func get_stopwatch_context() -> Dictionary:
		return {}

	func get_magnet_field_context() -> Dictionary:
		return {"active": true}

	func get_magnet_field_particles() -> Array:
		return []

	func get_holy_barrier_context() -> Dictionary:
		return {}

	func get_holy_barrier_particles() -> Array:
		return []

	func get_brick_wall_context() -> Dictionary:
		return {}

	func get_long_boost_timer_context() -> Dictionary:
		return {}

	func get_vitamin_pill_timer_context() -> Dictionary:
		return {}

	func get_strange_vial_timer_context() -> Dictionary:
		return {}

	func get_doping_potion_context() -> Dictionary:
		return {
			"active": true,
			"timer_frames": 240.0,
			"initial_timer_frames": 480.0,
		}

	func get_dash_boost_context() -> Dictionary:
		return {}

	func get_dash_boost_particles() -> Array:
		return []


class FakeFieldRenderer:
	extends RefCounted

	var draw_count := 0
	var last_portals: Array = []
	var last_items: Array = []
	var last_shake_offset := Vector2.ZERO

	func draw(_canvas: CanvasItem, portals: Array, field_items: Array, shake_offset: Vector2) -> void:
		draw_count += 1
		last_portals = portals
		last_items = field_items
		last_shake_offset = shake_offset


class FakeThrowRenderer:
	extends RefCounted

	var draw_count := 0
	var last_pending_throws: Array = []
	var last_shake_offset := Vector2.ZERO

	func draw(
		_canvas: CanvasItem,
		pending_throws: Array,
		_grenades: Array,
		_flares: Array,
		_tear_gas_projectiles: Array,
		_tear_gas_zones: Array,
		_dynamites: Array,
		_placed_dynamites: Array,
		_molotovs: Array,
		_molotov_fire_zones: Array,
		_boomerangs: Array,
		_banana_projectiles: Array,
		_landed_bananas: Array,
		_soap_projectiles: Array,
		_landed_soaps: Array,
		_boomerang_particles: Array,
		_banana_particles: Array,
		_soap_particles: Array,
		_soap_foam_trails: Array,
		_spider_mines: Array,
		_spider_mine_particles: Array,
		_dynamite_explosions: Array,
		_explosion_zones: Array,
		_flare_zones: Array,
		shake_offset: Vector2
	) -> void:
		draw_count += 1
		last_pending_throws = pending_throws
		last_shake_offset = shake_offset


class FakeEffectRenderer:
	extends RefCounted

	var field_draw_count := 0
	var pickup_draw_count := 0
	var last_timer_stack: Object
	var last_pickup_effect: Dictionary = {}
	var last_shake_offset := Vector2.ZERO
	var last_doping_potion_context: Dictionary = {}

	func draw_field_effects(
		_canvas: CanvasItem,
		_pickup_particles: Array,
		_regeneration_potion_rings: Array,
		_regeneration_potion_particles: Array,
		_stopwatch_context: Dictionary,
		_magnet_field_context: Dictionary,
		_magnet_field_particles: Array,
		_holy_barrier_context: Dictionary,
		_holy_barrier_particles: Array,
		_brick_wall_context: Dictionary,
		_long_boost_timer_context: Dictionary,
		_vitamin_pill_timer_context: Dictionary,
		_strange_vial_timer_context: Dictionary,
		_dash_boost_context: Dictionary = {},
		_dash_boost_particles: Array = [],
		shake_offset: Vector2 = Vector2.ZERO,
		timer_stack: Object = null,
		_perf_logger: Object = null,
		doping_potion_context: Dictionary = {}
	) -> void:
		field_draw_count += 1
		last_shake_offset = shake_offset
		last_timer_stack = timer_stack
		last_doping_potion_context = doping_potion_context

	func draw_pickup_effect(_canvas: CanvasItem, _registry: Object, pickup_effect: Dictionary) -> void:
		pickup_draw_count += 1
		last_pickup_effect = pickup_effect


class FakeRuntimeRenderFacade:
	extends RefCounted

	var field_draw_count := 0
	var pickup_draw_count := 0
	var prewarm_count := 0
	var last_prewarm_visuals: Object
	var last_shake_offset := Vector2.ZERO

	func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
		prewarm_count += 1
		last_prewarm_visuals = active_item_hud_visuals

	func draw_field_items(
		_canvas: CanvasItem,
		_registry: Object,
		_field_spawn_controller: Object,
		_throw_controller: Object,
		_effect_controller: Object,
		shake_offset: Vector2 = Vector2.ZERO
	) -> void:
		field_draw_count += 1
		last_shake_offset = shake_offset

	func draw_pickup_effect(_canvas: CanvasItem, _registry: Object, _effect_controller: Object) -> void:
		pickup_draw_count += 1


func _init() -> void:
	_verify_facade_draw_dispatch()
	_verify_facade_pickup_draw_gate()
	_verify_runtime_public_draw_methods_delegate()
	_verify_runtime_public_prewarm_delegates()

	if _failures.is_empty():
		print("active_item_runtime_render_facade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_draw_dispatch() -> void:
	var facade: Object = ActiveItemRuntimeRenderFacade.new()
	var field_renderer := FakeFieldRenderer.new()
	var throw_renderer := FakeThrowRenderer.new()
	var effect_renderer := FakeEffectRenderer.new()
	facade.field_renderer = field_renderer
	facade.throw_renderer = throw_renderer
	facade.effect_renderer = effect_renderer
	var field_spawn := FakeFieldSpawnController.new()
	var throw_controller := FakeThrowController.new()
	var effect_controller := FakeEffectController.new()
	var registry := FakeRegistry.new()
	var canvas := Node2D.new()
	var shake_offset := Vector2(3.0, 4.0)

	facade.draw_field_items(canvas, registry, field_spawn, throw_controller, effect_controller, shake_offset)
	_expect(field_renderer.draw_count == 1, "render facade should draw visible field items")
	_expect(field_renderer.last_portals.size() == 1 and field_renderer.last_items.size() == 1, "render facade should pass field portals and items")
	_expect(throw_renderer.draw_count == 1, "render facade should draw visible throw effects")
	_expect(throw_renderer.last_pending_throws.size() == 1, "render facade should pass pending throws")
	_expect(effect_renderer.field_draw_count == 1, "render facade should draw visible field effects")
	_expect(effect_renderer.last_timer_stack == registry.timer_stack, "render facade should pass shared timer stack")
	_expect(effect_renderer.last_shake_offset == shake_offset, "render facade should preserve shake offset")
	_expect(bool(effect_renderer.last_doping_potion_context.get("active", false)), "render facade should pass doping timer context")

	field_spawn.visible = false
	throw_controller.visible = false
	effect_controller.field_visible = false
	facade.draw_field_items(canvas, registry, field_spawn, throw_controller, effect_controller, shake_offset)
	_expect(field_renderer.draw_count == 1, "hidden field items should not draw")
	_expect(throw_renderer.draw_count == 1, "hidden throw effects should not draw")
	_expect(effect_renderer.field_draw_count == 1, "hidden field effects should not draw")
	canvas.free()


func _verify_facade_pickup_draw_gate() -> void:
	var facade: Object = ActiveItemRuntimeRenderFacade.new()
	var effect_renderer := FakeEffectRenderer.new()
	facade.effect_renderer = effect_renderer
	var effect_controller := FakeEffectController.new()
	var registry := FakeRegistry.new()
	var canvas := Node2D.new()

	facade.draw_pickup_effect(canvas, registry, effect_controller)
	_expect(effect_renderer.pickup_draw_count == 0, "hidden pickup effect should not draw")

	effect_controller.pickup_visible = true
	facade.draw_pickup_effect(canvas, registry, effect_controller)
	_expect(effect_renderer.pickup_draw_count == 1, "visible pickup effect should draw")
	_expect(bool(effect_renderer.last_pickup_effect.get("pickup", false)), "pickup draw should receive effect payload")
	canvas.free()


func _verify_runtime_public_draw_methods_delegate() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var fake_facade := FakeRuntimeRenderFacade.new()
	runtime.render_facade = fake_facade
	var registry := FakeRegistry.new()
	var canvas := Node2D.new()
	var shake_offset := Vector2(7.0, 8.0)

	runtime.draw_field_items(canvas, registry, shake_offset)
	runtime.draw_pickup_effect(canvas, registry)
	_expect(fake_facade.field_draw_count == 1, "runtime draw_field_items should delegate to render facade")
	_expect(fake_facade.last_shake_offset == shake_offset, "runtime should preserve public draw shake offset")
	_expect(fake_facade.pickup_draw_count == 1, "runtime draw_pickup_effect should delegate to render facade")
	var arity_cache: Dictionary = runtime.get("_method_argument_count_cache")
	_expect(arity_cache.size() == 2, "runtime draw methods should cache render facade arities after first dispatch")
	runtime.draw_field_items(canvas, registry, shake_offset)
	runtime.draw_pickup_effect(canvas, registry)
	_expect(fake_facade.field_draw_count == 2, "runtime draw_field_items should keep delegating after arity caching")
	_expect(fake_facade.pickup_draw_count == 2, "runtime draw_pickup_effect should keep delegating after arity caching")
	_expect(arity_cache.size() == 2, "runtime draw methods should reuse cached render facade arities")
	canvas.free()


func _verify_runtime_public_prewarm_delegates() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	var fake_facade := FakeRuntimeRenderFacade.new()
	var visuals := RefCounted.new()
	runtime.render_facade = fake_facade

	runtime.prewarm_assets(visuals)
	_expect(fake_facade.prewarm_count == 1, "runtime prewarm_assets should delegate to render facade")
	_expect(fake_facade.last_prewarm_visuals == visuals, "runtime prewarm_assets should pass HUD visuals")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
