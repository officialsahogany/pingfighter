extends RefCounted

const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")

var field_renderer: Object = ActiveItemFieldRenderer.new()
var throw_renderer: Object = ActiveItemThrowRenderer.new()
var effect_renderer: Object = ActiveItemEffectRenderer.new()


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
		throw_renderer.draw(
			canvas,
			throw_controller.get_pending_throws(),
			throw_controller.get_grenades(),
			throw_controller.get_flares(),
			throw_controller.get_tear_gas_projectiles(),
			throw_controller.get_tear_gas_zones(),
			throw_controller.get_dynamites(),
			throw_controller.get_placed_dynamites(),
			throw_controller.get_molotovs(),
			throw_controller.get_molotov_fire_zones(),
			throw_controller.get_boomerangs(),
			throw_controller.get_banana_projectiles(),
			throw_controller.get_landed_bananas(),
			throw_controller.get_soap_projectiles(),
			throw_controller.get_landed_soaps(),
			throw_controller.get_boomerang_particles(),
			throw_controller.get_banana_particles(),
			throw_controller.get_soap_particles(),
			throw_controller.get_soap_foam_trails(),
			throw_controller.get_spider_mines(),
			throw_controller.get_spider_mine_particles(),
			throw_controller.get_dynamite_explosions(),
			throw_controller.get_explosion_zones(),
			throw_controller.get_flare_zones(),
			shake_offset
		)

	if _has_field_effects(effect_controller):
		effect_renderer.draw_field_effects(
			canvas,
			effect_controller.get_pickup_particles(),
			effect_controller.get_regeneration_potion_rings(),
			effect_controller.get_regeneration_potion_particles(),
			effect_controller.get_stopwatch_context(),
			effect_controller.get_magnet_field_context(),
			effect_controller.get_magnet_field_particles(),
			effect_controller.get_holy_barrier_context(),
			effect_controller.get_holy_barrier_particles(),
			effect_controller.get_brick_wall_context(),
			effect_controller.get_long_boost_timer_context(),
			effect_controller.get_vitamin_pill_timer_context(),
			effect_controller.get_strange_vial_timer_context(),
			effect_controller.get_dash_boost_context(),
			effect_controller.get_dash_boost_particles(),
			shake_offset,
			_get_instance(registry, "horizontal_timer_gauge_stack")
		)


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
	return (
		throw_controller != null
		and throw_controller.has_method("has_visible_effects")
		and bool(throw_controller.has_visible_effects())
	)


func _has_field_effects(effect_controller: Object) -> bool:
	return (
		effect_controller != null
		and effect_controller.has_method("has_field_effects")
		and bool(effect_controller.has_field_effects())
	)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
