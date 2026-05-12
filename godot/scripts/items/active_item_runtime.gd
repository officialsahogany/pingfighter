extends RefCounted

const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const ActiveItemBoomerangReturnHandler := preload("res://scripts/items/active_item_boomerang_return_handler.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemDebugInventory := preload("res://scripts/items/active_item_debug_inventory.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemRuntimeContextFacade := preload("res://scripts/items/active_item_runtime_context_facade.gd")
const ActiveItemRuntimeDebugFacade := preload("res://scripts/items/active_item_runtime_debug_facade.gd")
const ActiveItemRuntimeLifecycleFacade := preload("res://scripts/items/active_item_runtime_lifecycle_facade.gd")
const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")

const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0

var slot_controller: Object = ActiveItemSlotController.new()
var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
var throw_controller: Object = ActiveItemThrowController.new()
var effect_controller: Object = ActiveItemEffectController.new()
var effect_router: Object = ActiveItemEffectRouter.new()
var pickup_feedback: Object = ActiveItemPickupFeedback.new()
var boomerang_return_handler: Object = ActiveItemBoomerangReturnHandler.new()
var debug_spawn_menu: Object = ActiveItemDebugSpawnMenu.new()
var debug_inventory: Object = ActiveItemDebugInventory.new()
var item_catalog: Object = ActiveItemCatalog.new()
var context_facade: Object = ActiveItemRuntimeContextFacade.new()
var debug_facade: Object = ActiveItemRuntimeDebugFacade.new()
var lifecycle_facade: Object = ActiveItemRuntimeLifecycleFacade.new()
var field_renderer: Object = ActiveItemFieldRenderer.new()
var throw_renderer: Object = ActiveItemThrowRenderer.new()
var effect_renderer: Object = ActiveItemEffectRenderer.new()


func _init() -> void:
	reset()


func reset() -> void:
	lifecycle_facade.reset(self)


func build_starting_slots() -> Array:
	return lifecycle_facade.build_starting_slots(self)


func update(owner: Object, registry: Object, delta: float) -> Dictionary:
	if owner == null:
		return {}

	var throw_locked_at_update_start: bool = is_player_control_locked()

	effect_controller.update(owner, delta)
	field_spawn_controller.update(
		owner,
		registry,
		delta,
		Callable(self, "_store_active_item"),
		Callable(self, "_trigger_pickup_effect")
	)
	throw_controller.update(
		owner,
		registry,
		delta,
		Callable(field_spawn_controller, "collect_items_near"),
		Callable(boomerang_return_handler, "handle_return").bind(
			slot_controller,
			effect_controller,
			Callable(self, "_trigger_pickup_effect")
		)
	)

	var input_locked: bool = throw_locked_at_update_start or is_player_control_locked()
	var slot_result: Dictionary = slot_controller.update(owner, registry, input_locked, Callable(self, "_apply_item_effect"))
	effect_controller.sync_long_boost_owner_state(owner)
	return slot_result


func draw_field_items(canvas: CanvasItem, registry: Object, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return

	field_renderer.draw(
		canvas,
		field_spawn_controller.get_item_spawn_portals(),
		field_spawn_controller.get_spawned_items(),
		shake_offset
	)

	throw_renderer.draw(
		canvas,
		throw_controller.get_pending_throws(),
		throw_controller.get_grenades(),
		throw_controller.get_flares(),
		throw_controller.get_boomerangs(),
		throw_controller.get_boomerang_particles(),
		throw_controller.get_explosion_zones(),
		throw_controller.get_flare_zones(),
		shake_offset
	)
	effect_renderer.draw_field_effects(
		canvas,
		effect_controller.get_pickup_particles(),
		effect_controller.get_regeneration_potion_rings(),
		effect_controller.get_regeneration_potion_particles(),
		effect_controller.get_long_boost_timer_context(),
		shake_offset
	)


func draw_pickup_effect(canvas: CanvasItem, registry: Object) -> void:
	effect_renderer.draw_pickup_effect(canvas, registry, effect_controller.get_pickup_effect())


func toggle_debug_spawn_menu() -> void:
	debug_facade.toggle_debug_spawn_menu(self)


func close_debug_spawn_menu() -> void:
	debug_facade.close_debug_spawn_menu(self)


func is_debug_spawn_menu_open() -> bool:
	return debug_facade.is_debug_spawn_menu_open(self)


func is_throw_windup_active() -> bool:
	return context_facade.is_throw_windup_active(self)


func is_player_control_locked() -> bool:
	return context_facade.is_player_control_locked(self)


func get_player_paddle_scale() -> float:
	return context_facade.get_player_paddle_scale(self)


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return context_facade.get_player_paddle_width(self, base_width)


func get_player_paddle_height(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	return context_facade.get_player_paddle_height(self, base_height)


func get_player_speed_multiplier() -> float:
	return context_facade.get_player_speed_multiplier(self)


func has_actor_draw_context() -> bool:
	if context_facade.has_method("has_actor_draw_context"):
		return context_facade.has_actor_draw_context(self)
	return context_facade.has_method("get_actor_draw_context")


func get_actor_draw_context() -> Dictionary:
	return context_facade.get_actor_draw_context(self)


func handle_debug_spawn_menu_click(
	mouse_position: Vector2,
	view_size: Vector2,
	owner: Object = null,
	registry: Object = null
) -> bool:
	return debug_facade.handle_debug_spawn_menu_click(self, mouse_position, view_size, owner, registry)


func handle_debug_spawn_menu_input(
	event: InputEvent,
	view_size: Vector2,
	owner: Object = null,
	registry: Object = null
) -> bool:
	return debug_facade.handle_debug_spawn_menu_input(self, event, view_size, owner, registry)


func _apply_debug_spawn_menu_result(result: Dictionary, owner: Object, registry: Object) -> bool:
	return debug_facade.apply_debug_spawn_menu_result(self, result, owner, registry)


func debug_add_item_to_slot(item_name: String, owner: Object, registry: Object) -> bool:
	return debug_facade.debug_add_item_to_slot(self, item_name, owner, registry)


func debug_remove_item_from_slot(item_name: String, owner: Object, registry: Object) -> bool:
	return debug_facade.debug_remove_item_from_slot(self, item_name, owner, registry)


func _adjust_debug_item_quantity(item_name: String, delta: int, owner: Object, registry: Object) -> int:
	return debug_facade.adjust_debug_item_quantity(self, item_name, delta, owner, registry)


func get_debug_item_counts(owner: Object) -> Dictionary:
	return debug_facade.get_debug_item_counts(self, owner)


func grant_item_to_slot(item_name: String, owner: Object, registry: Object, allow_overflow: bool = false) -> bool:
	return debug_facade.grant_item_to_slot(self, item_name, owner, registry, allow_overflow)


func fill_empty_slots_with_item(item_name: String, owner: Object, registry: Object, fill_limit: int = 9) -> int:
	return debug_facade.fill_empty_slots_with_item(self, item_name, owner, registry, fill_limit)


func debug_spawn_item(item_name: String, owner: Object = null, registry: Object = null) -> bool:
	if owner != null:
		return debug_facade.debug_spawn_item(self, item_name, owner, registry)
	return spawn_field_item(item_name)


func spawn_field_item(item_name: String, position: Variant = null) -> bool:
	if position is Vector2 and field_spawn_controller.has_method("debug_spawn_item_at"):
		return field_spawn_controller.debug_spawn_item_at(item_name, position)
	return field_spawn_controller.debug_spawn_item(item_name)


func draw_debug_spawn_menu(canvas: CanvasItem, view_size: Vector2, owner: Object = null) -> void:
	debug_facade.draw_debug_spawn_menu(self, canvas, view_size, owner)


func _apply_item_effect(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return effect_router.apply_item_effect(
		item_data,
		owner,
		registry,
		effect_controller,
		throw_controller
	)


func get_boss_ai_context() -> Dictionary:
	return context_facade.get_boss_ai_context(self)


func get_ball_collision_context() -> Dictionary:
	return context_facade.get_ball_collision_context(self)


func is_aipill_active() -> bool:
	return context_facade.is_aipill_active(self)


func is_stopwatch_active() -> bool:
	return context_facade.is_stopwatch_active(self)


func is_doping_potion_active() -> bool:
	return context_facade.is_doping_potion_active(self)


func get_doping_potion_context() -> Dictionary:
	return context_facade.get_doping_potion_context(self)


func is_holy_barrier_active() -> bool:
	return context_facade.is_holy_barrier_active(self)


func is_magnet_field_active() -> bool:
	return context_facade.is_magnet_field_active(self)


func apply_aipill_player_control(player_pos: Vector2, player_speed: float, config: Dictionary, delta: float) -> Dictionary:
	return context_facade.apply_aipill_player_control(self, player_pos, player_speed, config, delta)


func apply_aipill_guard_drain(special_gauge: float, context: Dictionary, deps: Dictionary) -> float:
	return context_facade.apply_aipill_guard_drain(self, special_gauge, context, deps)


func apply_magnet_field_ball_pull(fps_scale: float, context: Dictionary) -> Dictionary:
	return context_facade.apply_magnet_field_ball_pull(self, fps_scale, context)


func notify_holy_barrier_hit(impact_pos: Vector2) -> void:
	context_facade.notify_holy_barrier_hit(self, impact_pos)


func notify_brick_wall_hit(wall_index: int, impact_pos: Vector2) -> Dictionary:
	return context_facade.notify_brick_wall_hit(self, wall_index, impact_pos)


func _store_active_item(field_item: Dictionary, active_item_slots: Array, registry: Object) -> bool:
	return slot_controller.store_active_item(
		field_item,
		active_item_slots,
		registry,
		Callable(effect_controller, "can_store_item")
	)


func _trigger_pickup_effect(field_item: Dictionary, registry: Object) -> void:
	pickup_feedback.trigger_pickup_effect(field_item, effect_controller, registry)
