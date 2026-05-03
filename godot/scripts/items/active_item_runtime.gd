extends RefCounted

const ActiveItemSlotController := preload("res://scripts/items/active_item_slot_controller.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const ActiveItemBoomerangReturnHandler := preload("res://scripts/items/active_item_boomerang_return_handler.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")

const PLAYER_BASE_PADDLE_WIDTH := 155.0

var slot_controller: Object = ActiveItemSlotController.new()
var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
var throw_controller: Object = ActiveItemThrowController.new()
var effect_controller: Object = ActiveItemEffectController.new()
var effect_router: Object = ActiveItemEffectRouter.new()
var pickup_feedback: Object = ActiveItemPickupFeedback.new()
var boomerang_return_handler: Object = ActiveItemBoomerangReturnHandler.new()
var debug_spawn_menu: Object = ActiveItemDebugSpawnMenu.new()
var field_renderer: Object = ActiveItemFieldRenderer.new()
var throw_renderer: Object = ActiveItemThrowRenderer.new()
var effect_renderer: Object = ActiveItemEffectRenderer.new()


func _init() -> void:
	reset()


func reset() -> void:
	slot_controller.reset()
	field_spawn_controller.reset()
	throw_controller.reset()
	effect_controller.reset()
	debug_spawn_menu.reset()


func build_starting_slots() -> Array:
	return slot_controller.build_starting_slots()


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
	debug_spawn_menu.toggle()


func is_debug_spawn_menu_open() -> bool:
	return debug_spawn_menu.is_open()


func is_throw_windup_active() -> bool:
	return throw_controller.is_throw_windup_active()


func is_player_control_locked() -> bool:
	return throw_controller.is_player_control_locked()


func get_player_paddle_scale() -> float:
	return effect_controller.get_player_paddle_scale()


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return effect_controller.get_player_paddle_width(base_width)


func get_actor_draw_context() -> Dictionary:
	var context: Dictionary = throw_controller.get_actor_draw_context()
	context["player_paddle_scale"] = effect_controller.get_player_paddle_scale()
	return context


func handle_debug_spawn_menu_click(mouse_position: Vector2, view_size: Vector2) -> bool:
	var result: Dictionary = debug_spawn_menu.handle_click(mouse_position, view_size)
	var item_name: String = str(result.get("item_name", ""))
	if item_name != "":
		debug_spawn_item(item_name)
	return bool(result.get("handled", false))


func debug_spawn_item(item_name: String) -> bool:
	return field_spawn_controller.debug_spawn_item(item_name)


func draw_debug_spawn_menu(canvas: CanvasItem, view_size: Vector2) -> void:
	debug_spawn_menu.draw(canvas, view_size)


func _apply_item_effect(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	return effect_router.apply_item_effect(
		item_data,
		owner,
		registry,
		effect_controller,
		throw_controller
	)


func get_boss_ai_context() -> Dictionary:
	return throw_controller.get_boss_ai_context()


func _store_active_item(field_item: Dictionary, active_item_slots: Array, registry: Object) -> bool:
	return slot_controller.store_active_item(
		field_item,
		active_item_slots,
		registry,
		Callable(effect_controller, "can_store_item")
	)


func _trigger_pickup_effect(field_item: Dictionary, registry: Object) -> void:
	pickup_feedback.trigger_pickup_effect(field_item, effect_controller, registry)
