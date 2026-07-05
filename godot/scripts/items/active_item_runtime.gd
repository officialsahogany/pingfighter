extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const HELPER_INIT_ORDER := [
	"slot_controller",
	"field_spawn_controller",
	"throw_controller",
	"effect_controller",
	"effect_router",
	"pickup_feedback",
	"pickup_router",
	"boomerang_return_handler",
	"pending_throw_recovery",
	"smartphone_auto_use",
	"debug_spawn_menu",
	"debug_inventory",
	"item_catalog",
	"context_facade",
	"debug_facade",
	"lifecycle_facade",
	"render_facade",
	"update_driver",
	"use_facade",
	"elixir_cinematic_draw",
]
const HELPER_SCRIPT_PATHS := {
	"slot_controller": "res://scripts/items/active_item_slot_controller.gd",
	"field_spawn_controller": "res://scripts/items/active_item_field_spawn_controller.gd",
	"throw_controller": "res://scripts/items/active_item_throw_controller.gd",
	"effect_controller": "res://scripts/items/active_item_effect_controller.gd",
	"effect_router": "res://scripts/items/active_item_effect_router.gd",
	"pickup_feedback": "res://scripts/items/active_item_pickup_feedback.gd",
	"pickup_router": "res://scripts/items/active_item_pickup_router.gd",
	"boomerang_return_handler": "res://scripts/items/active_item_boomerang_return_handler.gd",
	"pending_throw_recovery": "res://scripts/items/active_item_pending_throw_recovery.gd",
	"smartphone_auto_use": "res://scripts/items/active_item_smartphone_auto_use.gd",
	"debug_spawn_menu": "res://scripts/items/active_item_debug_spawn_menu.gd",
	"debug_inventory": "res://scripts/items/active_item_debug_inventory.gd",
	"item_catalog": "res://scripts/items/active_item_catalog.gd",
	"context_facade": "res://scripts/items/active_item_runtime_context_facade.gd",
	"debug_facade": "res://scripts/items/active_item_runtime_debug_facade.gd",
	"lifecycle_facade": "res://scripts/items/active_item_runtime_lifecycle_facade.gd",
	"render_facade": "res://scripts/items/active_item_runtime_render_facade.gd",
	"update_driver": "res://scripts/items/active_item_runtime_update_driver.gd",
	"use_facade": "res://scripts/items/active_item_runtime_use_facade.gd",
	"elixir_cinematic_draw": "res://scripts/items/elixir_of_mastery_cinematic_draw.gd",
}
var slot_controller: Object = null
var field_spawn_controller: Object = null
var throw_controller: Object = null
var effect_controller: Object = null
var effect_router: Object = null
var pickup_feedback: Object = null
var pickup_router: Object = null
var boomerang_return_handler: Object = null
var pending_throw_recovery: Object = null
var smartphone_auto_use: Object = null
var debug_spawn_menu: Object = null
var debug_inventory: Object = null
var item_catalog: Object = null
var context_facade: Object = null
var debug_facade: Object = null
var lifecycle_facade: Object = null
var render_facade: Object = null
var update_driver: Object = null
var use_facade: Object = null
var elixir_cinematic_draw: Object = null
var _helper_init_step_index := 0
var _helpers_initialized := false
var _asset_prewarm_step_index := 0
var _method_argument_count_cache: Dictionary = {}


func _init() -> void:
	pass


func prewarm_initialization_step(perform_reset: bool = true) -> bool:
	if _helpers_initialized:
		return true
	if _helper_init_step_index < HELPER_INIT_ORDER.size():
		_init_helper(str(HELPER_INIT_ORDER[_helper_init_step_index]))
		_helper_init_step_index += 1
		return false
	_helpers_initialized = true
	_helper_init_step_index = 0
	if perform_reset and lifecycle_facade != null and lifecycle_facade.has_method("reset"):
		lifecycle_facade.reset(self)
	return true


func reset() -> void:
	_ensure_helpers_ready(false)
	lifecycle_facade.reset(self)
	_deactivate_render_hosts()


func reset_round() -> void:
	_ensure_helpers_ready()
	if throw_controller != null and throw_controller.has_method("clear_round_boss_status_effects"):
		throw_controller.clear_round_boss_status_effects()
	_deactivate_render_hosts()


func reset_for_stage_transition(owner: Object = null, _registry: Object = null) -> void:
	_ensure_helpers_ready(false)
	if lifecycle_facade != null and lifecycle_facade.has_method("reset_for_stage_transition"):
		lifecycle_facade.reset_for_stage_transition(self, owner, _registry)
	_deactivate_render_hosts()


func build_starting_slots() -> Array:
	_ensure_helpers_ready()
	return lifecycle_facade.build_starting_slots(self)


func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
	while not prewarm_assets_step(active_item_hud_visuals):
		pass


func prewarm_assets_step(active_item_hud_visuals: Object = null) -> bool:
	match _asset_prewarm_step_index:
		0:
			if not prewarm_initialization_step(true):
				return false
		1:
			if render_facade != null and render_facade.has_method("prewarm_assets_step"):
				if not bool(render_facade.prewarm_assets_step(active_item_hud_visuals)):
					return false
			elif render_facade != null and render_facade.has_method("prewarm_assets"):
				render_facade.prewarm_assets(active_item_hud_visuals)
		2:
			if field_spawn_controller != null and field_spawn_controller.has_method("prewarm_spawn_candidate_templates_step"):
				if not bool(field_spawn_controller.prewarm_spawn_candidate_templates_step()):
					return false
			elif field_spawn_controller != null and field_spawn_controller.has_method("prewarm_spawn_candidate_templates"):
				field_spawn_controller.prewarm_spawn_candidate_templates()
		_:
			_asset_prewarm_step_index = 0
			return true
	_asset_prewarm_step_index += 1
	return false


func update(owner: Object, registry: Object, delta: float, perf_logger: Object = null) -> Dictionary:
	_ensure_helpers_ready()
	var result: Variant
	if _get_method_argument_count(update_driver, "apply_update") >= 9:
		result = update_driver.apply_update(
			self,
			owner,
			registry,
			delta,
			Callable(self, "_store_active_item"),
			Callable(self, "_trigger_pickup_effect"),
			Callable(self, "_apply_item_effect"),
			Callable(self, "_backup_pending_throw_item"),
			perf_logger
		)
	else:
		result = update_driver.apply_update(
			self,
			owner,
			registry,
			delta,
			Callable(self, "_store_active_item"),
			Callable(self, "_trigger_pickup_effect"),
			Callable(self, "_apply_item_effect"),
			Callable(self, "_backup_pending_throw_item")
		)
	if result is Dictionary:
		return result
	return {}


func pause_cooldowns(_owner: Object = null, _registry: Object = null) -> void:
	_ensure_helpers_ready()
	if slot_controller != null and slot_controller.has_method("pause_cooldowns"):
		slot_controller.pause_cooldowns(Time.get_ticks_msec())


func resume_cooldowns(owner: Object = null, _registry: Object = null) -> void:
	_ensure_helpers_ready()
	if slot_controller == null or not slot_controller.has_method("resume_cooldowns"):
		return
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var resumed_slots: Array = slot_controller.resume_cooldowns(Time.get_ticks_msec(), active_item_slots)
	if owner != null:
		owner.set("active_item_slots", resumed_slots)


func get_active_item_cooldown_time_msec(current_time_msec: int) -> int:
	if slot_controller != null and slot_controller.has_method("get_cooldown_time_msec"):
		return int(slot_controller.get_cooldown_time_msec(current_time_msec))
	return current_time_msec


func reorder_active_slots(src_index: int, dst_index: int, owner: Object, _registry: Object = null) -> bool:
	# Character-info drag reorder parity: swap two occupied active-item slots.
	# Mirrors the original `active_item_slot[src], active_item_slot[dst]` swap;
	# a drop on an out-of-range (empty) slot is a no-op.
	if owner == null or src_index == dst_index:
		return false
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if src_index < 0 or src_index >= active_item_slots.size():
		return false
	if dst_index < 0 or dst_index >= active_item_slots.size():
		return false
	var moved: Variant = active_item_slots[src_index]
	active_item_slots[src_index] = active_item_slots[dst_index]
	active_item_slots[dst_index] = moved
	owner.set("active_item_slots", active_item_slots)
	_request_owner_redraw(owner)
	return true


func discard_active_slot(slot_index: int, owner: Object, registry: Object = null) -> bool:
	# Character-info trash drop parity: remove one active item from its slot and
	# shift the HUD selection so it tracks the same item / stays in bounds
	# (original decrements selected_item_index, pingfighter.py:195600-195610).
	if owner == null:
		return false
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if slot_index < 0 or slot_index >= active_item_slots.size():
		return false
	active_item_slots.remove_at(slot_index)
	owner.set("active_item_slots", active_item_slots)
	_adjust_selected_slot_after_discard(registry, slot_index, active_item_slots.size())
	_request_owner_redraw(owner)
	return true


func _request_owner_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()
	elif owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _adjust_selected_slot_after_discard(registry: Object, removed_index: int, remaining_count: int) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var hud_state: Object = registry.get_instance("active_item_hud_state")
	if hud_state == null or not hud_state.has_method("get_selected_index") or not hud_state.has_method("set_selected_index"):
		return
	var selected: int = int(hud_state.get_selected_index())
	if selected > removed_index:
		selected -= 1
	selected = clampi(selected, 0, max(0, remaining_count - 1))
	hud_state.set_selected_index(selected)


func use_slot(slot_index: int, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return use_facade.use_slot(self, slot_index, owner, registry)


func try_smartphone_auto_recovery(owner: Object, registry: Object, gauge_threshold: float = 120.0) -> String:
	_ensure_helpers_ready()
	return use_facade.try_smartphone_auto_recovery(self, owner, registry, gauge_threshold)


func try_smartphone_auto_defense(owner: Object, registry: Object) -> String:
	_ensure_helpers_ready()
	return use_facade.try_smartphone_auto_defense(self, owner, registry)


func restore_pending_throw_item_on_round_end(owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return use_facade.restore_pending_throw_item_on_round_end(self, owner, registry)


func draw_field_items(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2 = Vector2.ZERO,
	perf_logger: Object = null
) -> void:
	_ensure_helpers_ready()
	if _get_method_argument_count(render_facade, "draw_field_items") >= 7:
		render_facade.draw_field_items(
			canvas,
			registry,
			field_spawn_controller,
			throw_controller,
			effect_controller,
			shake_offset,
			perf_logger
		)
	else:
		render_facade.draw_field_items(
			canvas,
			registry,
			field_spawn_controller,
			throw_controller,
			effect_controller,
			shake_offset
		)


func draw_pickup_effect(canvas: CanvasItem, registry: Object, perf_logger: Object = null) -> void:
	_ensure_helpers_ready()
	if _get_method_argument_count(render_facade, "draw_pickup_effect") >= 4:
		render_facade.draw_pickup_effect(canvas, registry, effect_controller, perf_logger)
	else:
		render_facade.draw_pickup_effect(canvas, registry, effect_controller)


func toggle_debug_spawn_menu() -> void:
	_ensure_helpers_ready()
	debug_facade.toggle_debug_spawn_menu(self)


func close_debug_spawn_menu() -> void:
	_ensure_helpers_ready()
	debug_facade.close_debug_spawn_menu(self)


func is_debug_spawn_menu_open() -> bool:
	_ensure_helpers_ready()
	return debug_facade.is_debug_spawn_menu_open(self)


func is_throw_windup_active() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_throw_windup_active(self)


func is_player_control_locked() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_player_control_locked(self)


func get_player_paddle_scale() -> float:
	_ensure_helpers_ready()
	return context_facade.get_player_paddle_scale(self)


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	_ensure_helpers_ready()
	return context_facade.get_player_paddle_width(self, base_width)


func get_player_paddle_height(base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	_ensure_helpers_ready()
	return context_facade.get_player_paddle_height(self, base_height)


func get_player_speed_multiplier() -> float:
	_ensure_helpers_ready()
	return context_facade.get_player_speed_multiplier(self)


func has_actor_draw_context() -> bool:
	_ensure_helpers_ready()
	if context_facade.has_method("has_actor_draw_context"):
		return context_facade.has_actor_draw_context(self)
	return context_facade.has_method("get_actor_draw_context")


func get_actor_draw_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.get_actor_draw_context(self)


func trigger_molotov_fire_zone(
	center: Vector2,
	owner: Object = null,
	registry: Object = null,
	play_feedback_audio: bool = true
) -> void:
	_ensure_helpers_ready()
	if throw_controller != null and throw_controller.has_method("trigger_molotov_fire_zone"):
		throw_controller.trigger_molotov_fire_zone(owner, registry, center, play_feedback_audio)


func handle_debug_spawn_menu_click(
	mouse_position: Vector2,
	view_size: Vector2,
	owner: Object = null,
	registry: Object = null
) -> bool:
	_ensure_helpers_ready()
	return debug_facade.handle_debug_spawn_menu_click(self, mouse_position, view_size, owner, registry)


func handle_debug_spawn_menu_input(
	event: InputEvent,
	view_size: Vector2,
	owner: Object = null,
	registry: Object = null
) -> bool:
	_ensure_helpers_ready()
	return debug_facade.handle_debug_spawn_menu_input(self, event, view_size, owner, registry)


func _apply_debug_spawn_menu_result(result: Dictionary, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return debug_facade.apply_debug_spawn_menu_result(self, result, owner, registry)


func debug_add_item_to_slot(item_name: String, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return debug_facade.debug_add_item_to_slot(self, item_name, owner, registry)


func debug_remove_item_from_slot(item_name: String, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return debug_facade.debug_remove_item_from_slot(self, item_name, owner, registry)


func _adjust_debug_item_quantity(item_name: String, delta: int, owner: Object, registry: Object) -> int:
	_ensure_helpers_ready()
	return debug_facade.adjust_debug_item_quantity(self, item_name, delta, owner, registry)


func get_debug_item_counts(owner: Object) -> Dictionary:
	_ensure_helpers_ready()
	return debug_facade.get_debug_item_counts(self, owner)


func grant_item_to_slot(item_name: String, owner: Object, registry: Object, allow_overflow: bool = false) -> bool:
	_ensure_helpers_ready()
	return debug_facade.grant_item_to_slot(self, item_name, owner, registry, allow_overflow)


func fill_empty_slots_with_item(item_name: String, owner: Object, registry: Object, fill_limit: int = 9) -> int:
	_ensure_helpers_ready()
	return debug_facade.fill_empty_slots_with_item(self, item_name, owner, registry, fill_limit)


func debug_spawn_item(item_name: String, owner: Object = null, registry: Object = null) -> bool:
	_ensure_helpers_ready()
	if owner == null:
		return spawn_field_item(item_name)
	return debug_facade.debug_spawn_item(self, item_name, owner, registry)


func spawn_field_item(item_name: String, position: Variant = null) -> bool:
	_ensure_helpers_ready()
	if position is Vector2 and field_spawn_controller.has_method("debug_spawn_item_at"):
		return field_spawn_controller.debug_spawn_item_at(item_name, position)
	return field_spawn_controller.debug_spawn_item(item_name)


func spawn_field_item_data(item_data: Dictionary, position: Variant = null) -> bool:
	_ensure_helpers_ready()
	if field_spawn_controller.has_method("debug_spawn_item_data"):
		return field_spawn_controller.debug_spawn_item_data(item_data, position)
	var item_name: String = str(item_data.get("name", ""))
	if item_name == "":
		return false
	return spawn_field_item(item_name, position)


func collect_item_by_name(item_name: String, position: Vector2, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return false
	var field_item := {
		"item_data": item_data,
		"position": position,
		"velocity": Vector2.ZERO,
		"bounce_count": 0,
		"max_bounces": 0,
		"angle_degrees": 0.0,
		"spawn_spark_timer": 0.0,
	}
	return pickup_router.collect_field_item_to_owner_slots(
		field_item,
		owner,
		registry,
		slot_controller,
		effect_controller,
		Callable(self, "_trigger_pickup_effect")
	)


func get_field_spawned_items() -> Array[Dictionary]:
	_ensure_helpers_ready()
	return field_spawn_controller.get_spawned_items()


func activate_dimension_gate(registry: Object = null) -> bool:
	_ensure_helpers_ready()
	return use_facade.activate_dimension_gate(self, registry)


func is_dimension_gate_active() -> bool:
	_ensure_helpers_ready()
	return use_facade.is_dimension_gate_active(self)


func draw_debug_spawn_menu(canvas: CanvasItem, view_size: Vector2, owner: Object = null) -> void:
	_ensure_helpers_ready()
	debug_facade.draw_debug_spawn_menu(self, canvas, view_size, owner)


func _apply_item_effect(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	_ensure_helpers_ready()
	return use_facade.apply_item_effect(self, item_data, owner, registry)


func _backup_pending_throw_item(item_data: Dictionary, slot_index: int, _owner: Object, _registry: Object) -> void:
	_ensure_helpers_ready()
	use_facade.backup_pending_throw_item(self, item_data, slot_index, _owner, _registry)


func is_aipill_active() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_aipill_active(self)


func is_stopwatch_active() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_stopwatch_active(self)


func is_doping_potion_active() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_doping_potion_active(self)


func get_doping_potion_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.get_doping_potion_context(self)


func is_holy_barrier_active() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_holy_barrier_active(self)


func is_dash_boost_active() -> bool:
	_ensure_helpers_ready()
	if effect_controller == null:
		return false
	return bool(effect_controller.is_dash_boost_active())


func get_dash_cost_multiplier() -> float:
	_ensure_helpers_ready()
	if effect_controller == null:
		return 1.0
	return float(effect_controller.get_dash_cost_multiplier())


func get_dash_cooldown_multiplier() -> float:
	_ensure_helpers_ready()
	if effect_controller == null:
		return 1.0
	return float(effect_controller.get_dash_cooldown_multiplier())


func get_dash_boost_remaining_ratio() -> float:
	_ensure_helpers_ready()
	if effect_controller == null:
		return 0.0
	return float(effect_controller.get_dash_boost_remaining_ratio())


func get_dash_boost_remaining_time() -> float:
	_ensure_helpers_ready()
	if effect_controller == null:
		return 0.0
	return float(effect_controller.get_dash_boost_remaining_time())


func apply_aipill_player_control(player_pos: Vector2, player_speed: float, config: Dictionary, delta: float) -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.apply_aipill_player_control(self, player_pos, player_speed, config, delta)


func apply_aipill_guard_drain(special_gauge: float, context: Dictionary, deps: Dictionary) -> float:
	_ensure_helpers_ready()
	return context_facade.apply_aipill_guard_drain(self, special_gauge, context, deps)


func get_boss_ai_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.get_boss_ai_context(self)


func get_ball_collision_context() -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.get_ball_collision_context(self)


func is_magnet_field_active() -> bool:
	_ensure_helpers_ready()
	return context_facade.is_magnet_field_active(self)


func apply_magnet_field_ball_pull(fps_scale: float, context: Dictionary) -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.apply_magnet_field_ball_pull(self, fps_scale, context)


func notify_holy_barrier_hit(impact_pos: Vector2) -> void:
	_ensure_helpers_ready()
	context_facade.notify_holy_barrier_hit(self, impact_pos)


func notify_brick_wall_hit(wall_index: int, impact_pos: Vector2) -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.notify_brick_wall_hit(self, wall_index, impact_pos)


func notify_trampoline_hit(trampoline_index: int, ball_pos: Vector2, ball_vel: Vector2) -> Dictionary:
	_ensure_helpers_ready()
	return context_facade.notify_trampoline_hit(self, trampoline_index, ball_pos, ball_vel)


func _store_active_item(field_item: Dictionary, active_item_slots: Array, registry: Object, owner: Object) -> bool:
	_ensure_helpers_ready()
	return pickup_router.store_field_item(
		field_item,
		active_item_slots,
		registry,
		owner,
		slot_controller,
		effect_controller
	)


func _trigger_pickup_effect(field_item: Dictionary, registry: Object) -> void:
	_ensure_helpers_ready()
	pickup_router.trigger_pickup_effect(field_item, registry, pickup_feedback, effect_controller)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


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


func is_elixir_cinematic_active() -> bool:
	_ensure_helpers_ready()
	if effect_controller == null or not effect_controller.has_method("is_elixir_cinematic_active"):
		return false
	return bool(effect_controller.is_elixir_cinematic_active())


func update_elixir_cinematic(delta: float) -> void:
	_ensure_helpers_ready()
	if effect_controller == null or not effect_controller.has_method("update_elixir_cinematic"):
		return
	effect_controller.update_elixir_cinematic(delta)


func handle_elixir_confirm() -> bool:
	_ensure_helpers_ready()
	if effect_controller == null or not effect_controller.has_method("handle_elixir_confirm"):
		return false
	return bool(effect_controller.handle_elixir_confirm())


func draw_elixir_cinematic(canvas: CanvasItem, view_size: Vector2) -> void:
	_ensure_helpers_ready()
	if effect_controller == null or not effect_controller.has_method("get_elixir_of_mastery_runtime"):
		return
	if elixir_cinematic_draw == null or not elixir_cinematic_draw.has_method("draw_cinematic"):
		return
	var elixir_runtime: Object = effect_controller.get_elixir_of_mastery_runtime()
	if elixir_runtime == null or not elixir_runtime.has_method("get_draw_context"):
		return
	var ctx: Dictionary = elixir_runtime.get_draw_context()
	elixir_cinematic_draw.draw_cinematic(canvas, ctx, view_size)


func _ensure_helpers_ready(perform_reset: bool = true) -> void:
	while not prewarm_initialization_step(perform_reset):
		pass


func _deactivate_render_hosts() -> void:
	if render_facade != null and render_facade.has_method("deactivate_all_hosts"):
		render_facade.deactivate_all_hosts()


func _init_helper(member_name: String) -> void:
	if get(member_name) is Object:
		return
	var path := str(HELPER_SCRIPT_PATHS.get(member_name, ""))
	if path == "":
		return
	var script: Variant = load(path)
	if script == null:
		return
	set(member_name, script.new())
