extends RefCounted

const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")

var field_renderer: Object = ActiveItemFieldRenderer.new()
var throw_renderer: Object = ActiveItemThrowRenderer.new()
var effect_renderer: Object = ActiveItemEffectRenderer.new()


func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
	_call_prewarm_assets(field_renderer)
	_call_prewarm_assets(throw_renderer)
	_call_prewarm_assets(effect_renderer, [active_item_hud_visuals])


func draw_field_items(
	canvas: CanvasItem,
	registry: Object,
	field_spawn_controller: Object,
	throw_controller: Object,
	effect_controller: Object,
	shake_offset: Vector2 = Vector2.ZERO
) -> void:
	if canvas == null:
		return

	if _has_visible_field_items(field_spawn_controller):
		field_renderer.draw(
			canvas,
			field_spawn_controller.get_item_spawn_portals(),
			field_spawn_controller.get_spawned_items(),
			shake_offset
		)

	if _has_visible_throw_effects(throw_controller):
		_call_throw_renderer_draw(canvas, throw_controller, shake_offset)

	if _has_field_effects(effect_controller):
		_call_effect_renderer_draw_field_effects(canvas, registry, effect_controller, shake_offset)


func draw_pickup_effect(canvas: CanvasItem, registry: Object, effect_controller: Object) -> void:
	if canvas == null:
		return
	if effect_controller.has_method("has_pickup_effect") and not bool(effect_controller.has_pickup_effect()):
		return
	effect_renderer.draw_pickup_effect(canvas, registry, effect_controller.get_pickup_effect())


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
	return (
		not _get_array_method(effect_controller, "get_pickup_particles").is_empty()
		or not _get_array_method(effect_controller, "get_regeneration_potion_rings").is_empty()
		or not _get_array_method(effect_controller, "get_regeneration_potion_particles").is_empty()
		or not _get_dictionary_method(effect_controller, "get_long_boost_timer_context").is_empty()
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _call_throw_renderer_draw(canvas: CanvasItem, throw_controller: Object, shake_offset: Vector2) -> void:
	var argument_count: int = _get_method_argument_count(throw_renderer, "draw")
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
	shake_offset: Vector2
) -> void:
	var argument_count: int = _get_method_argument_count(effect_renderer, "draw_field_effects")
	if argument_count <= 6:
		effect_renderer.draw_field_effects(
			canvas,
			_get_array_method(effect_controller, "get_pickup_particles"),
			_get_array_method(effect_controller, "get_regeneration_potion_rings"),
			_get_array_method(effect_controller, "get_regeneration_potion_particles"),
			_get_dictionary_method(effect_controller, "get_long_boost_timer_context"),
			shake_offset
		)
		return
	effect_renderer.draw_field_effects(
		canvas,
		_get_array_method(effect_controller, "get_pickup_particles"),
		_get_array_method(effect_controller, "get_regeneration_potion_rings"),
		_get_array_method(effect_controller, "get_regeneration_potion_particles"),
		_get_dictionary_method(effect_controller, "get_stopwatch_context"),
		_get_dictionary_method(effect_controller, "get_magnet_field_context"),
		_get_array_method(effect_controller, "get_magnet_field_particles"),
		_get_dictionary_method(effect_controller, "get_holy_barrier_context"),
		_get_array_method(effect_controller, "get_holy_barrier_particles"),
		_get_dictionary_method(effect_controller, "get_brick_wall_context"),
		_get_dictionary_method(effect_controller, "get_long_boost_timer_context"),
		_get_dictionary_method(effect_controller, "get_vitamin_pill_timer_context"),
		_get_dictionary_method(effect_controller, "get_strange_vial_timer_context"),
		_get_dictionary_method(effect_controller, "get_dash_boost_context"),
		_get_array_method(effect_controller, "get_dash_boost_particles"),
		shake_offset,
		_get_instance(registry, "horizontal_timer_gauge_stack")
	)


func _call_prewarm_assets(target: Object, args: Array = []) -> void:
	if target == null or not target.has_method("prewarm_assets"):
		return
	var argument_count: int = _get_method_argument_count(target, "prewarm_assets")
	if argument_count <= 0:
		target.prewarm_assets()
		return
	target.callv("prewarm_assets", args.slice(0, argument_count))


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


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			return args_value.size()
	return 0
