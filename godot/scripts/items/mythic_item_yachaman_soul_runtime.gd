extends RefCounted

const ITEM_YACHAMAN_SOUL := "yachaman_soul"
const ROLL_ACTIVATION_CHANCE := "activation_chance_pct"
const MOVE_SPEED := 3.0
const PADDLE_SIZE_MULT := 0.70
const FIELD_WIDTH := 760.0
const DEFAULT_BALL_SIZE := 28.6
const BOMB_SPIN_HELMET_R := 14.0
const BOMB_BALL_MIN_SPEED := 10.0
const BOMB_BALL_SPEED_MULT := 1.2
const BOMB_BALL_X_RATIO := 0.3


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
	var changed := false
	if state.update(fps_scale):
		changed = true
	var player_center: Vector2 = _get_player_anchor({"owner": owner})
	if state.is_transformed():
		var input_snapshot: Dictionary = _get_input_snapshot(runtime, owner, registry)
		if _consume_bomb_spin_input(state, input_snapshot):
			_play_bomb_spin_audio(runtime, registry)
			changed = true
		var spin_result: Dictionary = state.update_bomb_spin(player_center, fps_scale)
		if _apply_bomb_spin_result(runtime, owner, registry, state, spin_result):
			changed = true
	state.update_lingering(player_center, fps_scale)
	if changed or state.has_bomb_visible_effects() or state.has_ball_draw_context():
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
		runtime.yachaman_soul_effect_renderer.draw_bomb_kit(canvas, runtime.yachaman_soul_state, shake_offset)


func has_visible_effects(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return is_event_playing(runtime) or (state != null and state.has_bomb_visible_effects())


func has_ball_draw_context(runtime: Object) -> bool:
	var state: Object = runtime.yachaman_soul_state
	return state != null and state.has_ball_draw_context()


func merge_ball_draw_context(runtime: Object, context: Dictionary) -> void:
	var state: Object = runtime.yachaman_soul_state
	if state != null and state.has_ball_draw_context():
		context["bomb_ball_loaded"] = true
		context["bomb_ball_source"] = ITEM_YACHAMAN_SOUL


func consume_bomb_boss_hit(
	runtime: Object,
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var state: Object = runtime.yachaman_soul_state
	if state == null:
		return {}
	var explosion_result: Dictionary = state.trigger_bomb_explosion(_get_boss_center(context, ball_pos))
	if explosion_result.is_empty():
		return {}
	var knockback_dir := 1.0 if ball_vel.x >= 0.0 else -1.0
	var knockback_power: float = float(explosion_result.get("knockback", 0.0))
	var boss_vel := knockback_dir * knockback_power
	_apply_bomb_stun(deps, float(explosion_result.get("stun_frames", 0.0)), boss_vel)
	_apply_bomb_feedback(runtime, deps)
	_play_bomb_explosion_audio(runtime, deps.get("registry", null))
	_sync_owner(runtime, deps)
	return {
		"boss_vel": boss_vel,
		"yachaman_bomb_hit": true,
		"yachaman_bomb_consumed": true,
		"suppress_paddle_hit_knockback": true,
	}


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


func _get_input_snapshot(runtime: Object, owner: Object, registry: Object) -> Dictionary:
	var reader: Object = _get_input_reader(runtime, owner, registry)
	if reader == null or not reader.has_method("get_snapshot"):
		return {}
	var value: Variant = reader.get_snapshot()
	return value if value is Dictionary else {}


func _get_input_reader(runtime: Object, owner: Object, registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var character_type: String = str(runtime._safe_owner_get(owner, "selected_character_type", "smasher")).strip_edges().to_lower()
	var key := "smasher_input_reader"
	if character_type == "soldier" or character_type == "commando":
		key = "commando_input_reader"
	elif character_type == "viper":
		key = "viper_input_reader"
	return registry.get_instance(key)


func _consume_bomb_spin_input(state: Object, input_snapshot: Dictionary) -> bool:
	if not bool(input_snapshot.get("action_just_pressed", false)):
		return false
	var direction := 0
	if bool(input_snapshot.get("left_pressed", false)):
		direction -= 1
	if bool(input_snapshot.get("right_pressed", false)):
		direction += 1
	if direction == 0 and input_snapshot.has("move_direction"):
		direction = _sign_int(int(input_snapshot.get("move_direction", 0)))
	if direction == 0 and input_snapshot.has("direction"):
		direction = _sign_int(int(input_snapshot.get("direction", 0)))
	return state.try_bomb_spin(direction)


func _apply_bomb_spin_result(
	runtime: Object,
	owner: Object,
	registry: Object,
	state: Object,
	spin_result: Dictionary
) -> bool:
	if owner == null:
		return false
	var changed := false
	var dx: float = float(spin_result.get("dx", 0.0))
	if abs(dx) > 0.001:
		_move_owner_by_dx(runtime, owner, dx)
		changed = true
	if _try_load_bomb_on_ball(runtime, owner, registry, state):
		changed = true
	return changed


func _move_owner_by_dx(runtime: Object, owner: Object, dx: float) -> void:
	var pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var paddle_width: float = _get_owner_float(owner, "player_paddle_width", 155.0)
	pos.x = clampf(pos.x + dx, 0.0, max(0.0, FIELD_WIDTH - paddle_width))
	owner.set("player_pos", pos)


func _try_load_bomb_on_ball(runtime: Object, owner: Object, registry: Object, state: Object) -> bool:
	var ball_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_pos", Vector2.ZERO))
	var ball_vel: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	var ball_size: float = _get_owner_float(owner, "ball_size", DEFAULT_BALL_SIZE)
	if ball_pos == Vector2.ZERO:
		return false
	if not state.check_bomb_spin_ball_collision(ball_pos, ball_vel, ball_size):
		return false
	var direction := 1.0 if int(state.get("bomb_spin_direction")) >= 0 else -1.0
	var speed: float = max(BOMB_BALL_MIN_SPEED, ball_vel.length() * BOMB_BALL_SPEED_MULT)
	var next_vel := Vector2(direction * abs(speed) * BOMB_BALL_X_RATIO, -abs(speed))
	var helmet_pos: Vector2 = state.get("bomb_spin_helmet_pos") if state.get("bomb_spin_helmet_pos") is Vector2 else ball_pos
	owner.set("ball_vel", next_vel)
	owner.set("ball_pos", Vector2(ball_pos.x, helmet_pos.y - BOMB_SPIN_HELMET_R - 2.0 - ball_size * 0.5))
	var ball_intensity: Object = runtime._get_instance(registry, "ball_intensity")
	if ball_intensity != null and ball_intensity.has_method("register_hit"):
		ball_intensity.register_hit("player")
	var ball_effects: Object = runtime._get_instance(registry, "ball_effects")
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(helmet_pos, next_vel, 0.84, "yachaman_bomb_spin")
	return true


func _get_boss_center(context: Dictionary, fallback: Vector2) -> Vector2:
	var boss_pos: Vector2 = context.get("boss_pos", fallback) if context.get("boss_pos", fallback) is Vector2 else fallback
	var boss_size: Vector2 = context.get("boss_paddle_size", Vector2.ZERO) if context.get("boss_paddle_size", Vector2.ZERO) is Vector2 else Vector2.ZERO
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	if boss_pos == fallback and context.has("boss_x") and context.has("boss_y"):
		boss_pos = Vector2(float(context.get("boss_x", fallback.x)), float(context.get("boss_y", fallback.y)))
	return boss_pos + boss_size * 0.5


func _sign_int(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0


func _apply_bomb_stun(deps: Dictionary, stun_frames: float, boss_vel: float) -> void:
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state == null or not status_state.has_method("apply_status") or stun_frames <= 0.0:
		return
	status_state.apply_status(
		"boss",
		"stun",
		stun_frames,
		{
			"knockback_vel": boss_vel,
			"knockback_active": abs(boss_vel) > 0.001,
			"knockback_frames": 24.0,
			"knockback_decay_per_frame": 0.88,
			"knockback_stop_threshold": 0.25,
		},
		ITEM_YACHAMAN_SOUL
	)


func _apply_bomb_feedback(runtime: Object, deps: Dictionary) -> void:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null:
		feedback = runtime._get_instance(deps.get("registry", null), "battle_feedback_state")
	if feedback == null:
		return
	if feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.34, 18.0)
	elif feedback.has_method("set_screen_shake"):
		feedback.set_screen_shake(0.34, 18.0)


func _play_bomb_spin_audio(runtime: Object, registry: Object) -> void:
	if runtime.audio_router != null and runtime.audio_router.has_method("play_yachaman_bomb_spin_audio"):
		runtime.audio_router.play_yachaman_bomb_spin_audio(runtime, registry)


func _play_bomb_explosion_audio(runtime: Object, registry: Object) -> void:
	if runtime.audio_router != null and runtime.audio_router.has_method("play_yachaman_bomb_explosion_audio"):
		runtime.audio_router.play_yachaman_bomb_explosion_audio(runtime, registry)
