extends RefCounted


func is_throw_windup_active(runtime: Object) -> bool:
	if runtime.throw_controller == null or not runtime.throw_controller.has_method("is_throw_windup_active"):
		return false
	return bool(runtime.throw_controller.is_throw_windup_active())


func is_player_control_locked(runtime: Object) -> bool:
	var throw_locked := false
	if runtime.throw_controller != null and runtime.throw_controller.has_method("is_player_control_locked"):
		throw_locked = bool(runtime.throw_controller.is_player_control_locked())
	var wall_installing := false
	if runtime.effect_controller != null and runtime.effect_controller.has_method("is_wall_installing"):
		wall_installing = bool(runtime.effect_controller.is_wall_installing())
	return throw_locked or wall_installing


func get_player_paddle_scale(runtime: Object) -> float:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("get_player_paddle_scale"):
		return 1.0
	return float(runtime.effect_controller.get_player_paddle_scale())


func get_player_paddle_width(runtime: Object, base_width: float) -> float:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("get_player_paddle_width"):
		return base_width
	return float(runtime.effect_controller.get_player_paddle_width(base_width))


func get_player_paddle_height(runtime: Object, base_height: float) -> float:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("get_player_paddle_height"):
		return base_height
	return float(runtime.effect_controller.get_player_paddle_height(base_height))


func get_player_speed_multiplier(runtime: Object) -> float:
	if runtime.effect_controller != null and runtime.effect_controller.has_method("get_player_speed_multiplier"):
		return float(runtime.effect_controller.get_player_speed_multiplier())
	return 1.0


func get_actor_draw_context(runtime: Object) -> Dictionary:
	var context: Dictionary = {}
	if _has_throw_actor_draw_context(runtime):
		context = runtime.throw_controller.get_actor_draw_context()
	if _is_aipill_actor_draw_active(runtime) and runtime.effect_controller.has_method("get_aipill_context"):
		var aipill_context: Dictionary = runtime.effect_controller.get_aipill_context()
		context["active_item_aipill_active"] = true
		context["active_item_aipill_phase"] = float(aipill_context.get("phase", 0.0))
		context["active_item_aipill_flash_timer_frames"] = float(aipill_context.get("flash_timer_frames", 0.0))
		context["active_item_aipill_flash_initial_frames"] = float(aipill_context.get("flash_initial_frames", 1.0))
	if _is_doping_potion_actor_draw_active(runtime):
		var doping_context: Dictionary = runtime.effect_controller.get_doping_potion_context()
		context["active_item_doping_potion_active"] = true
		context["active_item_doping_potion_timer_frames"] = float(doping_context.get("timer_frames", 0.0))
		context["active_item_doping_potion_initial_timer_frames"] = float(doping_context.get("initial_timer_frames", 0.0))
		context["active_item_doping_potion_phase"] = float(doping_context.get("phase", 0.0))
		context["active_item_doping_potion_flash_timer_frames"] = float(doping_context.get("flash_timer_frames", 0.0))
		context["active_item_doping_potion_flash_initial_frames"] = float(doping_context.get("flash_initial_frames", 1.0))
		context["active_item_doping_potion_use_count"] = int(doping_context.get("use_count", 0))
		context["active_item_doping_potion_head_leg_multiplier"] = float(doping_context.get("head_leg_multiplier", 1.0))
		context["active_item_doping_potion_fire_rate_multiplier"] = float(doping_context.get("fire_rate_multiplier", 1.0))
		context["active_item_doping_potion_pistol_cooldown_frames"] = float(doping_context.get("pistol_cooldown_frames", 30.0))
		context["active_item_doping_potion_pistol_control_lock_frames"] = float(doping_context.get("pistol_control_lock_frames", 9.0))
		context["active_item_doping_potion_pistol_speed_multiplier"] = float(doping_context.get("pistol_speed_multiplier", 1.0))
		context["active_item_doping_potion_beretta_cooldown_frames"] = float(doping_context.get("beretta_cooldown_frames", 15.0))
		context["active_item_doping_potion_ak47_fire_interval_frames"] = float(doping_context.get("ak47_fire_interval_frames", 3.0))
		context["active_item_doping_potion_bazooka_cooldown_frames"] = float(doping_context.get("bazooka_cooldown_frames", 60.0))
		context["active_item_doping_potion_bazooka_control_lock_frames"] = float(doping_context.get("bazooka_control_lock_frames", 15.0))
	return context


func has_actor_draw_context(runtime: Object) -> bool:
	return (
		_has_throw_actor_draw_context(runtime)
		or _is_aipill_actor_draw_active(runtime)
		or _is_doping_potion_actor_draw_active(runtime)
	)


func is_aipill_active(runtime: Object) -> bool:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("is_aipill_active"):
		return false
	return bool(runtime.effect_controller.is_aipill_active())


func is_stopwatch_active(runtime: Object) -> bool:
	return (
		runtime.effect_controller.has_method("is_stopwatch_active")
		and bool(runtime.effect_controller.is_stopwatch_active())
	)


func is_doping_potion_active(runtime: Object) -> bool:
	return (
		runtime.effect_controller.has_method("is_doping_potion_active")
		and bool(runtime.effect_controller.is_doping_potion_active())
	)


func get_doping_potion_context(runtime: Object) -> Dictionary:
	if runtime.effect_controller != null and runtime.effect_controller.has_method("get_doping_potion_context"):
		return runtime.effect_controller.get_doping_potion_context()
	return {}


func _has_throw_actor_draw_context(runtime: Object) -> bool:
	if runtime.throw_controller == null:
		return false
	if runtime.throw_controller.has_method("has_actor_draw_context"):
		return bool(runtime.throw_controller.has_actor_draw_context())
	return runtime.throw_controller.has_method("get_actor_draw_context")


func _is_aipill_actor_draw_active(runtime: Object) -> bool:
	if runtime.effect_controller == null:
		return false
	if runtime.effect_controller.has_method("is_aipill_active"):
		return bool(runtime.effect_controller.is_aipill_active())
	if runtime.effect_controller.has_method("get_aipill_context"):
		return bool(runtime.effect_controller.get_aipill_context().get("active", false))
	return false


func _is_doping_potion_actor_draw_active(runtime: Object) -> bool:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("get_doping_potion_context"):
		return false
	if runtime.effect_controller.has_method("is_doping_potion_active"):
		return bool(runtime.effect_controller.is_doping_potion_active())
	return bool(runtime.effect_controller.get_doping_potion_context().get("active", false))


func is_holy_barrier_active(runtime: Object) -> bool:
	return (
		runtime.effect_controller.has_method("is_holy_barrier_active")
		and bool(runtime.effect_controller.is_holy_barrier_active())
	)


func is_magnet_field_active(runtime: Object) -> bool:
	return (
		runtime.effect_controller.has_method("is_magnet_field_active")
		and bool(runtime.effect_controller.is_magnet_field_active())
	)


func apply_aipill_player_control(
	runtime: Object,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	delta: float
) -> Dictionary:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("apply_aipill_player_control"):
		return {"player_pos": player_pos}
	return runtime.effect_controller.apply_aipill_player_control(player_pos, player_speed, config, delta)


func apply_aipill_guard_drain(runtime: Object, special_gauge: float, context: Dictionary, deps: Dictionary) -> float:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("apply_aipill_guard_drain"):
		return special_gauge
	return float(runtime.effect_controller.apply_aipill_guard_drain(special_gauge, context, deps))


func get_boss_ai_context(runtime: Object) -> Dictionary:
	var context: Dictionary = {}
	if runtime.throw_controller != null and runtime.throw_controller.has_method("get_boss_ai_context"):
		context = runtime.throw_controller.get_boss_ai_context()
	context["active_item_stopwatch_freeze_active"] = _is_time_frozen(runtime)
	return context


func get_ball_collision_context(runtime: Object) -> Dictionary:
	var context: Dictionary = {}
	if runtime.effect_controller == null:
		return context
	if runtime.effect_controller.has_method("get_holy_barrier_collision_context"):
		context.merge(runtime.effect_controller.get_holy_barrier_collision_context(), true)
	if runtime.effect_controller.has_method("get_brick_wall_collision_context"):
		context.merge(runtime.effect_controller.get_brick_wall_collision_context(), true)
	if runtime.effect_controller.has_method("get_trampoline_collision_context"):
		context.merge(runtime.effect_controller.get_trampoline_collision_context(), true)
	if runtime.effect_controller.has_method("get_stopwatch_ball_context"):
		context.merge(runtime.effect_controller.get_stopwatch_ball_context(), true)
	return context


func apply_magnet_field_ball_pull(runtime: Object, fps_scale: float, context: Dictionary) -> Dictionary:
	if runtime.effect_controller == null:
		return {}
	if _is_time_frozen(runtime):
		return {}
	if not runtime.effect_controller.has_method("apply_magnet_field_ball_pull"):
		return {}
	return runtime.effect_controller.apply_magnet_field_ball_pull(fps_scale, context)


func notify_holy_barrier_hit(runtime: Object, impact_pos: Vector2) -> void:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("notify_holy_barrier_hit"):
		return
	runtime.effect_controller.notify_holy_barrier_hit(impact_pos)


func notify_brick_wall_hit(runtime: Object, wall_index: int, impact_pos: Vector2) -> Dictionary:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("notify_brick_wall_hit"):
		return {}
	return runtime.effect_controller.notify_brick_wall_hit(wall_index, impact_pos)


func notify_trampoline_hit(runtime: Object, trampoline_index: int, ball_pos: Vector2, ball_vel: Vector2) -> Dictionary:
	if runtime.effect_controller == null or not runtime.effect_controller.has_method("notify_trampoline_hit"):
		return {}
	return runtime.effect_controller.notify_trampoline_hit(trampoline_index, ball_pos, ball_vel)


func _is_time_frozen(runtime: Object) -> bool:
	return (
		runtime.effect_controller != null
		and runtime.effect_controller.has_method("is_time_frozen")
		and bool(runtime.effect_controller.is_time_frozen())
	)
