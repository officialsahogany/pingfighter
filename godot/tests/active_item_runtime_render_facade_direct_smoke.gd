extends SceneTree

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
	var field_context_build_count := 0

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

	func get_field_effect_draw_context() -> Dictionary:
		field_context_build_count += 1
		return {
			"pickup_particles": get_pickup_particles(),
			"regeneration_potion_rings": get_regeneration_potion_rings(),
			"regeneration_potion_particles": get_regeneration_potion_particles(),
			"stopwatch_context": get_stopwatch_context(),
			"magnet_field_context": get_magnet_field_context(),
			"magnet_field_particles": get_magnet_field_particles(),
			"holy_barrier_context": get_holy_barrier_context(),
			"holy_barrier_particles": get_holy_barrier_particles(),
			"brick_wall_context": get_brick_wall_context(),
			"long_boost_timer_context": get_long_boost_timer_context(),
			"vitamin_pill_timer_context": get_vitamin_pill_timer_context(),
			"strange_vial_timer_context": get_strange_vial_timer_context(),
			"doping_potion_timer_context": get_doping_potion_context(),
			"dash_boost_context": get_dash_boost_context(),
			"dash_boost_particles": get_dash_boost_particles(),
		}


class FakeFieldRenderer:
	extends RefCounted

	var draw_count := 0
	var prewarm_count := 0
	var last_portals: Array = []
	var last_items: Array = []
	var last_shake_offset := Vector2.ZERO

	func prewarm_assets() -> void:
		prewarm_count += 1

	func draw(_canvas: CanvasItem, portals: Array, field_items: Array, shake_offset: Vector2) -> void:
		draw_count += 1
		last_portals = portals
		last_items = field_items
		last_shake_offset = shake_offset


class FakeStagedFieldRenderer:
	extends RefCounted

	var step_calls := 0
	var prewarm_count := 0
	var complete_after := 3

	func prewarm_assets_step() -> bool:
		step_calls += 1
		return step_calls >= complete_after

	func prewarm_assets() -> void:
		prewarm_count += 1


class FakeThrowRenderer:
	extends RefCounted

	var draw_count := 0
	var prewarm_count := 0
	var last_pending_throws: Array = []
	var last_shake_offset := Vector2.ZERO

	func prewarm_assets() -> void:
		prewarm_count += 1

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
	var prewarm_count := 0
	var last_prewarm_visuals: Object
	var last_timer_stack: Object
	var last_pickup_effect: Dictionary = {}
	var last_shake_offset := Vector2.ZERO
	var last_doping_potion_context: Dictionary = {}

	func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
		prewarm_count += 1
		last_prewarm_visuals = active_item_hud_visuals

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


class FakeLegacyThrowRenderer:
	extends RefCounted

	var draw_count := 0
	var last_pending_throws: Array = []
	var last_boomerangs: Array = []

	func draw(
		_canvas: CanvasItem,
		pending_throws: Array,
		_grenades: Array,
		_flares: Array,
		boomerangs: Array,
		_boomerang_particles: Array,
		_explosion_zones: Array,
		_flare_zones: Array,
		_shake_offset: Vector2 = Vector2.ZERO
	) -> void:
		draw_count += 1
		last_pending_throws = pending_throws
		last_boomerangs = boomerangs


class FakeLegacyEffectRenderer:
	extends RefCounted

	var field_draw_count := 0
	var last_long_boost_timer_context: Dictionary = {}

	func draw_field_effects(
		_canvas: CanvasItem,
		_pickup_particles: Array,
		_regeneration_potion_rings: Array,
		_regeneration_potion_particles: Array,
		long_boost_timer_context: Dictionary,
		_shake_offset: Vector2 = Vector2.ZERO
	) -> void:
		field_draw_count += 1
		last_long_boost_timer_context = long_boost_timer_context

	func draw_pickup_effect(_canvas: CanvasItem, _registry: Object, _pickup_effect: Dictionary) -> void:
		pass


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)

	func should_sample_detail(label: String) -> bool:
		return label == "active_item.field"


class FakePerfThrowRenderer:
	extends RefCounted

	var draw_count := 0
	var last_perf_logger: Object

	func draw(
		_canvas: CanvasItem,
		_pending_throws: Array,
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
		_shake_offset: Vector2 = Vector2.ZERO,
		perf_logger: Object = null
	) -> void:
		draw_count += 1
		last_perf_logger = perf_logger

	func _perf_begin(_perf_logger: Object) -> int:
		return 0


class FakePerfEffectRenderer:
	extends RefCounted

	var field_draw_count := 0
	var last_perf_logger: Object
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
		_shake_offset: Vector2 = Vector2.ZERO,
		_timer_stack: Object = null,
		perf_logger: Object = null,
		doping_potion_context: Dictionary = {}
	) -> void:
		field_draw_count += 1
		last_perf_logger = perf_logger
		last_doping_potion_context = doping_potion_context

	func draw_pickup_effect(_canvas: CanvasItem, _registry: Object, _pickup_effect: Dictionary) -> void:
		pass

	func _perf_begin(_perf_logger: Object) -> int:
		return 0


func _init() -> void:
	_verify_facade_prewarm_dispatch()
	_verify_facade_draw_dispatch()
	_verify_facade_legacy_renderer_dispatch()
	_verify_facade_perf_renderer_dispatch()
	_verify_facade_pickup_draw_gate()

	if _failures.is_empty():
		print("active_item_runtime_render_facade_direct_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_prewarm_dispatch() -> void:
	var facade: Object = ActiveItemRuntimeRenderFacade.new()
	var field_renderer := FakeStagedFieldRenderer.new()
	var throw_renderer := FakeThrowRenderer.new()
	var effect_renderer := FakeEffectRenderer.new()
	var visuals := RefCounted.new()
	facade.field_renderer = field_renderer
	facade.throw_renderer = throw_renderer
	facade.effect_renderer = effect_renderer

	facade.prewarm_assets(visuals)
	_expect(field_renderer.step_calls == field_renderer.complete_after, "render facade should stage field renderer prewarm chunks")
	_expect(field_renderer.prewarm_count == 0, "render facade should not use monolithic field renderer prewarm when step API exists")
	_expect(throw_renderer.prewarm_count == 1, "render facade should prewarm throw renderer")
	_expect(effect_renderer.prewarm_count == 1, "render facade should prewarm effect renderer")
	_expect(effect_renderer.last_prewarm_visuals == visuals, "effect renderer prewarm should receive HUD visuals")


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
	_expect(effect_controller.field_context_build_count == 1, "render facade should build field-effect draw context once")
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
	_expect(effect_controller.field_context_build_count == 1, "hidden field effects should not build draw context")
	canvas.free()


func _verify_facade_legacy_renderer_dispatch() -> void:
	var facade: Object = ActiveItemRuntimeRenderFacade.new()
	var legacy_throw_renderer := FakeLegacyThrowRenderer.new()
	var legacy_effect_renderer := FakeLegacyEffectRenderer.new()
	facade.field_renderer = FakeFieldRenderer.new()
	facade.throw_renderer = legacy_throw_renderer
	facade.effect_renderer = legacy_effect_renderer
	var field_spawn := FakeFieldSpawnController.new()
	field_spawn.visible = false
	var throw_controller := FakeThrowController.new()
	var effect_controller := FakeEffectController.new()
	var registry := FakeRegistry.new()
	var canvas := Node2D.new()

	facade.draw_field_items(canvas, registry, field_spawn, throw_controller, effect_controller)
	_expect(legacy_throw_renderer.draw_count == 1, "render facade should support legacy throw renderer draw arity")
	_expect(legacy_throw_renderer.last_pending_throws.size() == 1, "legacy throw renderer should receive pending throws")
	_expect(legacy_effect_renderer.field_draw_count == 1, "render facade should support legacy effect renderer draw arity")
	canvas.free()


func _verify_facade_perf_renderer_dispatch() -> void:
	var facade: Object = ActiveItemRuntimeRenderFacade.new()
	var perf_throw_renderer := FakePerfThrowRenderer.new()
	var perf_effect_renderer := FakePerfEffectRenderer.new()
	facade.field_renderer = FakeFieldRenderer.new()
	facade.throw_renderer = perf_throw_renderer
	facade.effect_renderer = perf_effect_renderer
	var field_spawn := FakeFieldSpawnController.new()
	field_spawn.visible = false
	var throw_controller := FakeThrowController.new()
	var effect_controller := FakeEffectController.new()
	var registry := FakeRegistry.new()
	var perf_logger := FakePerfLogger.new()
	var canvas := Node2D.new()

	facade.draw_field_items(canvas, registry, field_spawn, throw_controller, effect_controller, Vector2.ZERO, perf_logger)
	_expect(perf_throw_renderer.draw_count == 1, "perf-aware throw renderer should draw through full signature")
	_expect(perf_throw_renderer.last_perf_logger == perf_logger, "perf-aware throw renderer should receive perf logger")
	_expect(perf_effect_renderer.field_draw_count == 1, "perf-aware effect renderer should draw through full signature")
	_expect(perf_effect_renderer.last_perf_logger == perf_logger, "perf-aware effect renderer should receive perf logger")
	_expect(bool(perf_effect_renderer.last_doping_potion_context.get("active", false)), "perf-aware effect renderer should receive doping timer context")
	_expect(perf_logger.labels.has("active_item.throw_effects"), "facade should time throw effects")
	_expect(perf_logger.labels.has("active_item.field.context"), "facade should time field-effect context prep")
	_expect(perf_logger.labels.has("active_item.field_effects"), "facade should time field effects")
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
