extends RefCounted

const ITEM_YACHAMAN_SOUL := "yachaman_soul"
const ROLL_ACTIVATION_CHANCE := "activation_chance_pct"
const MOVE_SPEED := 3.0
const PADDLE_SIZE_MULT := 0.70


func sync_equipment_state(runtime: Object) -> void:
	var state: Object = runtime.yachaman_soul_state
	if state == null:
		return
	state.set_equipped(is_equipped(runtime))


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_YACHAMAN_SOUL)


func is_transformed(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.is_transformed()


func is_event_playing(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.is_event_playing()


func is_skills_locked(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.is_skills_locked()


func is_control_locked(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.is_control_locked()


func get_activation_chance_pct(runtime: Object) -> float:
	if not is_equipped(runtime):
		return 0.0
	return clampf(
		runtime.roll_query.get_equipped_roll_sum(runtime, ITEM_YACHAMAN_SOUL, ROLL_ACTIVATION_CHANCE),
		0.0,
		95.0
	)


func get_move_speed(runtime: Object) -> Variant:
	if is_transformed(runtime):
		return MOVE_SPEED
	return null


func get_paddle_size_multiplier(runtime: Object) -> float:
	return PADDLE_SIZE_MULT if is_transformed(runtime) else 1.0


func get_context(runtime: Object) -> Dictionary:
	sync_equipment_state(runtime)
	var state: Object = runtime.yachaman_soul_state
	if state == null:
		return {"equipped": false, "active": false, "state": "idle"}
	var context: Dictionary = state.get_context()
	context["activation_chance_pct"] = get_activation_chance_pct(runtime)
	return context


func try_trigger_revival(runtime: Object, loss_type: String = "round", deps: Dictionary = {}) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.yachaman_soul_state
	if state == null or not state.equipped:
		return false
	if state.is_transformed():
		state.on_defeat_in_yachaman()
		_sync_owner(runtime, deps)
		return false
	var chance_pct: float = get_activation_chance_pct(runtime)
	var anchor: Vector2 = _get_player_anchor(deps)
	var triggered: bool = state.try_begin_revival(chance_pct, loss_type, anchor, randf() * 100.0)
	if triggered:
		_play_audio(runtime, deps)
		_sync_owner(runtime, deps)
	return triggered


func consume_reset_ready(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.consume_reset_ready()


func has_runtime_update_work(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.has_runtime_update_work()


func update(runtime: Object, owner: Object, registry: Object, fps_scale: float) -> void:
	sync_equipment_state(runtime)
	var state: Object = runtime.yachaman_soul_state
	if state == null:
		return
	if state.update(fps_scale):
		runtime._sync_owner(owner, registry)


func reset_round(runtime: Object) -> void:
	var state: Object = runtime.yachaman_soul_state
	if state != null:
		state.reset_round()
		state.set_equipped(is_equipped(runtime))


func clear_runtime(runtime: Object) -> void:
	var state: Object = runtime.yachaman_soul_state
	if state != null:
		state.clear_runtime(false)
		state.set_equipped(is_equipped(runtime))


func draw_effect(runtime: Object, canvas: CanvasItem, shake_offset: Vector2) -> void:
	if runtime.yachaman_soul_effect_renderer != null:
		runtime.yachaman_soul_effect_renderer.draw_revival_event(canvas, runtime.yachaman_soul_state, shake_offset)


func has_visible_effects(runtime: Object) -> bool:
	return is_event_playing(runtime)


func _get_player_anchor(deps: Dictionary) -> Vector2:
	var owner: Object = deps.get("owner", null)
	if owner == null:
		return Vector2(380.0, 690.0)
	var pos: Variant = owner.get("player_pos")
	var player_pos: Vector2 = pos if pos is Vector2 else Vector2(302.5, 690.0)
	var width := _get_owner_float(owner, "player_paddle_width", 155.0)
	var height := _get_owner_float(owner, "player_paddle_height", 50.0)
	return player_pos + Vector2(width * 0.5, height * 0.5)


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	return fallback if value == null else float(value)


func _play_audio(runtime: Object, deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_horn_strawberry_change"):
		audio.play_horn_strawberry_change()
	elif runtime.audio_router != null and runtime.audio_router.has_method("play_active_item_audio"):
		runtime.audio_router.play_active_item_audio(runtime, deps.get("registry", null))


func _sync_owner(runtime: Object, deps: Dictionary) -> void:
	runtime._sync_owner(deps.get("owner", null), deps.get("registry", null))
