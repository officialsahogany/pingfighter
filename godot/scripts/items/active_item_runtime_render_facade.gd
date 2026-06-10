extends RefCounted

const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")

var field_renderer: Object = ActiveItemFieldRenderer.new()
var throw_renderer: Object = ActiveItemThrowRenderer.new()
var effect_renderer: Object = ActiveItemEffectRenderer.new()
var _cached_field_renderer: Object
var _cached_field_draw_argument_count := -1
var _cached_field_accepts_perf_logger := false
var _cached_throw_renderer: Object
var _cached_throw_draw_argument_count := -1
var _cached_throw_accepts_perf_logger := false
var _cached_effect_renderer: Object
var _cached_effect_draw_argument_count := -1
var _cached_effect_accepts_perf_logger := false
var _asset_prewarm_step_index := 0
var _method_argument_count_cache: Dictionary = {}


func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
	while not prewarm_assets_step(active_item_hud_visuals):
		pass


func prewarm_assets_step(active_item_hud_visuals: Object = null) -> bool:
	match _asset_prewarm_step_index:
		0:
			if not _call_prewarm_assets_step(field_renderer):
				return false
		1:
			if not _call_prewarm_assets_step(throw_renderer):
				return false
		2:
			if not _call_prewarm_assets_step(effect_renderer, [active_item_hud_visuals]):
				return false
		_:
			_asset_prewarm_step_index = 0
			return true
	_asset_prewarm_step_index += 1
	return false


func draw_field_items(
	canvas: CanvasItem,
	registry: Object,
	field_spawn_controller: Object,
	throw_controller: Object,
	effect_controller: Object,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> void:
	if canvas == null:
		return

	if _has_visible_field_items(field_spawn_controller):
		var sample_start: int = _perf_begin(perf_logger)
		_call_field_renderer_draw(
			canvas,
			field_spawn_controller.get_item_spawn_portals(),
			field_spawn_controller.get_spawned_items(),
			shake_offset,
			perf_logger
		)
		_call_field_renderer_break_effects_draw(
			canvas,
			_get_array_method(field_spawn_controller, "get_field_item_break_effects"),
			shake_offset,
			perf_logger
		)
		_perf_end(perf_logger, "active_item.field_items", sample_start)

	if _has_visible_throw_effects(throw_controller):
		var sample_start: int = _perf_begin(perf_logger)
		_call_throw_renderer_draw(canvas, throw_controller, shake_offset, perf_logger)
		_perf_end(perf_logger, "active_item.throw_effects", sample_start)

	if _has_field_effects(effect_controller):
		var sample_start: int = _perf_begin(perf_logger)
		_call_effect_renderer_draw_field_effects(canvas, registry, effect_controller, shake_offset, perf_logger)
		_perf_end(perf_logger, "active_item.field_effects", sample_start)


func draw_pickup_effect(
	canvas: CanvasItem,
	registry: Object,
	effect_controller: Object,
	perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	if effect_controller.has_method("has_pickup_effect") and not bool(effect_controller.has_pickup_effect()):
		return
	var pickup_effect: Dictionary = effect_controller.get_pickup_effect()
	if _get_method_argument_count(effect_renderer, "draw_pickup_effect") >= 4:
		effect_renderer.draw_pickup_effect(canvas, registry, pickup_effect, perf_logger)
	else:
		effect_renderer.draw_pickup_effect(canvas, registry, pickup_effect)


func _has_visible_field_items(field_spawn_controller: Object) -> bool:
	return (
		field_spawn_controller != null
		and field_spawn_controller.has_method("has_visible_field_items")
		and bool(field_spawn_controller.has_visible_field_items())
	)


func _has_visible_throw_effects(throw_controller: Object) -> bool:
	if throw_controller == null:
		return false
	if throw_controller.has_method("has_visible_effects"):
		return bool(throw_controller.has_visible_effects())
	return (
		not _get_array_method(throw_controller, "get_pending_throws").is_empty()
		or not _get_array_method(throw_controller, "get_grenades").is_empty()
		or not _get_array_method(throw_controller, "get_flares").is_empty()
		or not _get_array_method(throw_controller, "get_boomerangs").is_empty()
		or not _get_array_method(throw_controller, "get_boomerang_particles").is_empty()
		or not _get_array_method(throw_controller, "get_explosion_zones").is_empty()
		or not _get_array_method(throw_controller, "get_flare_zones").is_empty()
	)


func _has_field_effects(effect_controller: Object) -> bool:
	if effect_controller == null:
		return false
	if effect_controller.has_method("has_field_effects"):
		return bool(effect_controller.has_field_effects())
	var doping_potion_context: Dictionary = _get_dictionary_method(effect_controller, "get_doping_potion_context")
	return (
		not _get_array_method(effect_controller, "get_pickup_particles").is_empty()
		or not _get_array_method(effect_controller, "get_regeneration_potion_rings").is_empty()
		or not _get_array_method(effect_controller, "get_regeneration_potion_particles").is_empty()
		or not _get_dictionary_method(effect_controller, "get_long_boost_timer_context").is_empty()
		or bool(doping_potion_context.get("active", false))
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _call_field_renderer_draw(
	canvas: CanvasItem,
	portals: Array,
	field_items: Array,
	shake_offset: Vector2,
	perf_logger: Object
) -> void:
	_refresh_field_renderer_cache()
	if _cached_field_accepts_perf_logger and _cached_field_draw_argument_count >= 5:
		field_renderer.draw(canvas, portals, field_items, shake_offset, perf_logger)
		return
	field_renderer.draw(canvas, portals, field_items, shake_offset)


func _call_field_renderer_break_effects_draw(
	canvas: CanvasItem,
	break_effects: Array,
	shake_offset: Vector2,
	perf_logger: Object
) -> void:
	if break_effects.is_empty() or field_renderer == null or not field_renderer.has_method("draw_field_item_break_effects"):
		return
	if _get_method_argument_count(field_renderer, "draw_field_item_break_effects") >= 4:
		field_renderer.draw_field_item_break_effects(canvas, break_effects, shake_offset, perf_logger)
		return
	field_renderer.draw_field_item_break_effects(canvas, break_effects, shake_offset)


func _call_throw_renderer_draw(
	canvas: CanvasItem,
	throw_controller: Object,
	shake_offset: Vector2,
	perf_logger: Object
) -> void:
	_refresh_throw_renderer_cache()
	var argument_count: int = _cached_throw_draw_argument_count
	if argument_count <= 9:
		throw_renderer.draw(
			canvas,
			_get_array_method(throw_controller, "get_pending_throws"),
			_get_array_method(throw_controller, "get_grenades"),
			_get_array_method(throw_controller, "get_flares"),
			_get_array_method(throw_controller, "get_boomerangs"),
			_get_array_method(throw_controller, "get_boomerang_particles"),
			_get_array_method(throw_controller, "get_explosion_zones"),
			_get_array_method(throw_controller, "get_flare_zones"),
			shake_offset
		)
		return
	if _cached_throw_accepts_perf_logger:
		throw_renderer.draw(
			canvas,
			_get_array_method(throw_controller, "get_pending_throws"),
			_get_array_method(throw_controller, "get_grenades"),
			_get_array_method(throw_controller, "get_flares"),
			_get_array_method(throw_controller, "get_tear_gas_projectiles"),
			_get_array_method(throw_controller, "get_tear_gas_zones"),
			_get_array_method(throw_controller, "get_dynamites"),
			_get_array_method(throw_controller, "get_placed_dynamites"),
			_get_array_method(throw_controller, "get_molotovs"),
			_get_array_method(throw_controller, "get_molotov_fire_zones"),
			_get_array_method(throw_controller, "get_boomerangs"),
			_get_array_method(throw_controller, "get_banana_projectiles"),
			_get_array_method(throw_controller, "get_landed_bananas"),
			_get_array_method(throw_controller, "get_soap_projectiles"),
			_get_array_method(throw_controller, "get_landed_soaps"),
			_get_array_method(throw_controller, "get_boomerang_particles"),
			_get_array_method(throw_controller, "get_banana_particles"),
			_get_array_method(throw_controller, "get_soap_particles"),
			_get_array_method(throw_controller, "get_soap_foam_trails"),
			_get_array_method(throw_controller, "get_spider_mines"),
			_get_array_method(throw_controller, "get_spider_mine_particles"),
			_get_array_method(throw_controller, "get_dynamite_explosions"),
			_get_array_method(throw_controller, "get_explosion_zones"),
			_get_array_method(throw_controller, "get_flare_zones"),
			shake_offset,
			perf_logger
		)
		return
	throw_renderer.draw(
		canvas,
		_get_array_method(throw_controller, "get_pending_throws"),
		_get_array_method(throw_controller, "get_grenades"),
		_get_array_method(throw_controller, "get_flares"),
		_get_array_method(throw_controller, "get_tear_gas_projectiles"),
		_get_array_method(throw_controller, "get_tear_gas_zones"),
		_get_array_method(throw_controller, "get_dynamites"),
		_get_array_method(throw_controller, "get_placed_dynamites"),
		_get_array_method(throw_controller, "get_molotovs"),
		_get_array_method(throw_controller, "get_molotov_fire_zones"),
		_get_array_method(throw_controller, "get_boomerangs"),
		_get_array_method(throw_controller, "get_banana_projectiles"),
		_get_array_method(throw_controller, "get_landed_bananas"),
		_get_array_method(throw_controller, "get_soap_projectiles"),
		_get_array_method(throw_controller, "get_landed_soaps"),
		_get_array_method(throw_controller, "get_boomerang_particles"),
		_get_array_method(throw_controller, "get_banana_particles"),
		_get_array_method(throw_controller, "get_soap_particles"),
		_get_array_method(throw_controller, "get_soap_foam_trails"),
		_get_array_method(throw_controller, "get_spider_mines"),
		_get_array_method(throw_controller, "get_spider_mine_particles"),
		_get_array_method(throw_controller, "get_dynamite_explosions"),
		_get_array_method(throw_controller, "get_explosion_zones"),
		_get_array_method(throw_controller, "get_flare_zones"),
		shake_offset
	)


func _call_effect_renderer_draw_field_effects(
	canvas: CanvasItem,
	registry: Object,
	effect_controller: Object,
	shake_offset: Vector2,
	perf_logger: Object
) -> void:
	_refresh_effect_renderer_cache()
	var argument_count: int = _cached_effect_draw_argument_count
	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "active_item.field") else null
	var context_start: int = _perf_begin(detail_perf_logger)
	var draw_context: Dictionary = _get_field_effect_draw_context(effect_controller)
	_perf_end(detail_perf_logger, "active_item.field.context", context_start)
	_draw_trampoline_effect(canvas, draw_context, shake_offset, detail_perf_logger)
	var doping_potion_context: Dictionary = _get_context_dictionary(draw_context, "doping_potion_timer_context")
	if argument_count <= 6:
		effect_renderer.draw_field_effects(
			canvas,
			_get_context_array(draw_context, "pickup_particles"),
			_get_context_array(draw_context, "regeneration_potion_rings"),
			_get_context_array(draw_context, "regeneration_potion_particles"),
			_get_context_dictionary(draw_context, "long_boost_timer_context"),
			shake_offset
		)
		return
	if _cached_effect_accepts_perf_logger:
		if argument_count >= 19:
			effect_renderer.draw_field_effects(
				canvas,
				_get_context_array(draw_context, "pickup_particles"),
				_get_context_array(draw_context, "regeneration_potion_rings"),
				_get_context_array(draw_context, "regeneration_potion_particles"),
				_get_context_dictionary(draw_context, "stopwatch_context"),
				_get_context_dictionary(draw_context, "magnet_field_context"),
				_get_context_array(draw_context, "magnet_field_particles"),
				_get_context_dictionary(draw_context, "holy_barrier_context"),
				_get_context_array(draw_context, "holy_barrier_particles"),
				_get_context_dictionary(draw_context, "brick_wall_context"),
				_get_context_dictionary(draw_context, "long_boost_timer_context"),
				_get_context_dictionary(draw_context, "vitamin_pill_timer_context"),
				_get_context_dictionary(draw_context, "strange_vial_timer_context"),
				_get_context_dictionary(draw_context, "dash_boost_context"),
				_get_context_array(draw_context, "dash_boost_particles"),
				shake_offset,
				_get_instance(registry, "horizontal_timer_gauge_stack"),
				perf_logger,
				doping_potion_context
			)
			return
		effect_renderer.draw_field_effects(
			canvas,
			_get_context_array(draw_context, "pickup_particles"),
			_get_context_array(draw_context, "regeneration_potion_rings"),
			_get_context_array(draw_context, "regeneration_potion_particles"),
			_get_context_dictionary(draw_context, "stopwatch_context"),
			_get_context_dictionary(draw_context, "magnet_field_context"),
			_get_context_array(draw_context, "magnet_field_particles"),
			_get_context_dictionary(draw_context, "holy_barrier_context"),
			_get_context_array(draw_context, "holy_barrier_particles"),
			_get_context_dictionary(draw_context, "brick_wall_context"),
			_get_context_dictionary(draw_context, "long_boost_timer_context"),
			_get_context_dictionary(draw_context, "vitamin_pill_timer_context"),
			_get_context_dictionary(draw_context, "strange_vial_timer_context"),
			_get_context_dictionary(draw_context, "dash_boost_context"),
			_get_context_array(draw_context, "dash_boost_particles"),
			shake_offset,
			_get_instance(registry, "horizontal_timer_gauge_stack"),
			perf_logger
		)
		return
	if argument_count >= 19:
		effect_renderer.draw_field_effects(
			canvas,
			_get_context_array(draw_context, "pickup_particles"),
			_get_context_array(draw_context, "regeneration_potion_rings"),
			_get_context_array(draw_context, "regeneration_potion_particles"),
			_get_context_dictionary(draw_context, "stopwatch_context"),
			_get_context_dictionary(draw_context, "magnet_field_context"),
			_get_context_array(draw_context, "magnet_field_particles"),
			_get_context_dictionary(draw_context, "holy_barrier_context"),
			_get_context_array(draw_context, "holy_barrier_particles"),
			_get_context_dictionary(draw_context, "brick_wall_context"),
			_get_context_dictionary(draw_context, "long_boost_timer_context"),
			_get_context_dictionary(draw_context, "vitamin_pill_timer_context"),
			_get_context_dictionary(draw_context, "strange_vial_timer_context"),
			_get_context_dictionary(draw_context, "dash_boost_context"),
			_get_context_array(draw_context, "dash_boost_particles"),
			shake_offset,
			_get_instance(registry, "horizontal_timer_gauge_stack"),
			null,
			doping_potion_context
		)
		return
	effect_renderer.draw_field_effects(
		canvas,
		_get_context_array(draw_context, "pickup_particles"),
		_get_context_array(draw_context, "regeneration_potion_rings"),
		_get_context_array(draw_context, "regeneration_potion_particles"),
		_get_context_dictionary(draw_context, "stopwatch_context"),
		_get_context_dictionary(draw_context, "magnet_field_context"),
		_get_context_array(draw_context, "magnet_field_particles"),
		_get_context_dictionary(draw_context, "holy_barrier_context"),
		_get_context_array(draw_context, "holy_barrier_particles"),
		_get_context_dictionary(draw_context, "brick_wall_context"),
		_get_context_dictionary(draw_context, "long_boost_timer_context"),
		_get_context_dictionary(draw_context, "vitamin_pill_timer_context"),
		_get_context_dictionary(draw_context, "strange_vial_timer_context"),
		_get_context_dictionary(draw_context, "dash_boost_context"),
		_get_context_array(draw_context, "dash_boost_particles"),
		shake_offset,
		_get_instance(registry, "horizontal_timer_gauge_stack")
	)


func _draw_trampoline_effect(
	canvas: CanvasItem,
	draw_context: Dictionary,
	shake_offset: Vector2,
	detail_perf_logger: Object
) -> void:
	if effect_renderer == null or not effect_renderer.has_method("draw_trampoline_effect"):
		return
	var trampoline_context: Dictionary = _get_context_dictionary(draw_context, "trampoline_context")
	if trampoline_context.is_empty():
		return
	var sample_start: int = _perf_begin(detail_perf_logger)
	effect_renderer.draw_trampoline_effect(canvas, trampoline_context, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.trampoline", sample_start)


func _refresh_field_renderer_cache() -> void:
	if field_renderer == _cached_field_renderer:
		return
	_cached_field_renderer = field_renderer
	_cached_field_draw_argument_count = _get_method_argument_count(field_renderer, "draw")
	_cached_field_accepts_perf_logger = _renderer_accepts_perf_logger(field_renderer)


func _refresh_throw_renderer_cache() -> void:
	if throw_renderer == _cached_throw_renderer:
		return
	_cached_throw_renderer = throw_renderer
	_cached_throw_draw_argument_count = _get_method_argument_count(throw_renderer, "draw")
	_cached_throw_accepts_perf_logger = _renderer_accepts_perf_logger(throw_renderer)


func _refresh_effect_renderer_cache() -> void:
	if effect_renderer == _cached_effect_renderer:
		return
	_cached_effect_renderer = effect_renderer
	_cached_effect_draw_argument_count = _get_method_argument_count(effect_renderer, "draw_field_effects")
	_cached_effect_accepts_perf_logger = _renderer_accepts_perf_logger(effect_renderer)


func _get_array_method(target: Object, method_name: String) -> Array:
	if target == null or not target.has_method(method_name):
		return []
	var value: Variant = target.call(method_name)
	if value is Array:
		return value
	return []


func _get_dictionary_method(target: Object, method_name: String) -> Dictionary:
	if target == null or not target.has_method(method_name):
		return {}
	var value: Variant = target.call(method_name)
	if value is Dictionary:
		return value
	return {}


func _get_field_effect_draw_context(effect_controller: Object) -> Dictionary:
	if effect_controller != null and effect_controller.has_method("get_field_effect_draw_context"):
		var value: Variant = effect_controller.call("get_field_effect_draw_context")
		if value is Dictionary:
			return value
	return {
		"pickup_particles": _get_array_method(effect_controller, "get_pickup_particles"),
		"regeneration_potion_rings": _get_array_method(effect_controller, "get_regeneration_potion_rings"),
		"regeneration_potion_particles": _get_array_method(effect_controller, "get_regeneration_potion_particles"),
		"stopwatch_context": _get_dictionary_method(effect_controller, "get_stopwatch_context"),
		"magnet_field_context": _get_dictionary_method(effect_controller, "get_magnet_field_context"),
		"magnet_field_particles": _get_array_method(effect_controller, "get_magnet_field_particles"),
		"holy_barrier_context": _get_dictionary_method(effect_controller, "get_holy_barrier_context"),
		"holy_barrier_particles": _get_array_method(effect_controller, "get_holy_barrier_particles"),
		"brick_wall_context": _get_dictionary_method(effect_controller, "get_brick_wall_context"),
		"long_boost_timer_context": _get_dictionary_method(effect_controller, "get_long_boost_timer_context"),
		"vitamin_pill_timer_context": _get_dictionary_method(effect_controller, "get_vitamin_pill_timer_context"),
		"strange_vial_timer_context": _get_dictionary_method(effect_controller, "get_strange_vial_timer_context"),
		"doping_potion_timer_context": _get_dictionary_method(effect_controller, "get_doping_potion_context"),
		"dash_boost_context": _get_dictionary_method(effect_controller, "get_dash_boost_context"),
		"dash_boost_particles": _get_array_method(effect_controller, "get_dash_boost_particles"),
	}


func _get_context_array(context: Dictionary, key: String) -> Array:
	var value: Variant = context.get(key, [])
	if value is Array:
		return value
	return []


func _get_context_dictionary(context: Dictionary, key: String) -> Dictionary:
	var value: Variant = context.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	var cache_key := "%d:%s" % [target.get_instance_id(), method_name]
	if _method_argument_count_cache.has(cache_key):
		return int(_method_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			var args_count: int = args_value.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0


func _renderer_accepts_perf_logger(target: Object) -> bool:
	return target != null and target.has_method("_perf_begin")


func _call_prewarm_assets(target: Object, args: Array = []) -> void:
	if target == null or not target.has_method("prewarm_assets"):
		return
	var argument_count: int = _get_method_argument_count(target, "prewarm_assets")
	if argument_count <= 0:
		target.prewarm_assets()
		return
	target.callv("prewarm_assets", args.slice(0, argument_count))


func _call_prewarm_assets_step(target: Object, args: Array = []) -> bool:
	if target == null:
		return true
	if target.has_method("prewarm_assets_step"):
		var argument_count: int = _get_method_argument_count(target, "prewarm_assets_step")
		var result: Variant
		if argument_count <= 0:
			result = target.prewarm_assets_step()
		else:
			result = target.callv("prewarm_assets_step", args.slice(0, argument_count))
		if result is bool:
			return bool(result)
		return true
	_call_prewarm_assets(target, args)
	return true


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _should_sample_detail(perf_logger: Object, label: String) -> bool:
	if perf_logger == null or not perf_logger.has_method("should_sample_detail"):
		return false
	return bool(perf_logger.should_sample_detail(label))
