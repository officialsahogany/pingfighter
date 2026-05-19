extends RefCounted

const BALL_POS := "ball_pos"
const BALL_POS_PREV := "ball_pos_prev"
const RESET_REQUESTED := "ball_interp_reset_requested"
const ENABLED := "ball_render_interpolation_enabled"
const STEP_STARTED_SKIP := "_ball_interp_step_started_skip"
const LAST_PHYSICS_USEC := "ball_interp_last_physics_usec"
const DEFAULT_PHYSICS_TICKS_PER_SECOND := 60.0


static func begin_physics_step(scene: Dictionary) -> void:
	var current_pos: Vector2 = _get_vector2(scene, BALL_POS, Vector2.ZERO)
	scene[BALL_POS_PREV] = current_pos
	scene[LAST_PHYSICS_USEC] = Time.get_ticks_usec()
	scene[STEP_STARTED_SKIP] = bool(scene.get("skip_ball_motion_step", false))
	if not scene.has(RESET_REQUESTED):
		scene[RESET_REQUESTED] = false
	if not scene.has(ENABLED):
		scene[ENABLED] = true


static func finalize_physics_step(scene: Dictionary) -> void:
	if bool(scene.get(STEP_STARTED_SKIP, false)) and not bool(scene.get("skip_ball_motion_step", false)):
		reset_ball_interpolation(scene)
	scene.erase(STEP_STARTED_SKIP)


static func reset_ball_interpolation(scene: Dictionary) -> void:
	var current_pos: Vector2 = _get_vector2(scene, BALL_POS, Vector2.ZERO)
	scene[BALL_POS_PREV] = current_pos
	scene[RESET_REQUESTED] = true


static func reset_ball_interpolation_on_owner(owner: Object) -> void:
	if owner == null:
		return
	var current_pos: Vector2 = _get_owner_vector2(owner, BALL_POS, Vector2.ZERO)
	owner.set(BALL_POS_PREV, current_pos)
	owner.set(RESET_REQUESTED, true)


static func consume_reset_on_owner(owner: Object) -> void:
	if owner == null:
		return
	if bool(owner.get(RESET_REQUESTED)):
		owner.set(RESET_REQUESTED, false)


static func get_render_ball_pos(context: Dictionary, fallback: Vector2) -> Vector2:
	var current_pos: Vector2 = _get_vector2(context, BALL_POS, fallback)
	if not bool(context.get(ENABLED, true)):
		return current_pos
	if bool(context.get(RESET_REQUESTED, false)):
		return current_pos
	var previous_pos: Vector2 = _get_vector2(context, BALL_POS_PREV, current_pos)
	var fraction: float = _get_manual_interpolation_fraction(context)
	return previous_pos.lerp(current_pos, fraction)


static func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


static func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = owner.get(key)
	if value is Vector2:
		return value
	return fallback


static func _get_manual_interpolation_fraction(context: Dictionary) -> float:
	var last_physics_usec: int = int(context.get(LAST_PHYSICS_USEC, 0))
	if last_physics_usec <= 0:
		return clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var tick_rate: float = float(ProjectSettings.get_setting(
		"physics/common/physics_ticks_per_second",
		DEFAULT_PHYSICS_TICKS_PER_SECOND
	))
	var tick_usec: float = 1000000.0 / max(1.0, tick_rate)
	var elapsed_usec: float = float(Time.get_ticks_usec() - last_physics_usec)
	return clampf(elapsed_usec / tick_usec, 0.0, 1.0)
