extends RefCounted

var _impact_state: Object
var _collision_resolver: Object


func _init(impact_state: Object, collision_resolver: Object) -> void:
	_impact_state = impact_state
	_collision_resolver = collision_resolver


func apply_screen_shake(deps: Dictionary, amount: float, intensity: float) -> bool:
	var feedback: Object = deps.get("feedback", null)
	if feedback == null or not feedback.has_method("max_screen_shake"):
		return false
	feedback.max_screen_shake(amount, intensity)
	return true


func try_apply_player_knockback(
	context: Dictionary,
	deps: Dictionary,
	aircraft_direction: String,
	default_hitbox_padding: float,
	radius: float,
	velocity: float,
	frames: float,
	decay: float
) -> bool:
	if not _impact_state.is_player_knockback_pending():
		return false
	var player_rect: Rect2 = _collision_resolver.get_player_paddle_rect(
		context,
		default_hitbox_padding
	)
	var fallback_direction := 1.0 if aircraft_direction != "right_to_left" else -1.0
	var knockback: Dictionary = _collision_resolver.resolve_player_blast_knockback(
		player_rect,
		_impact_state.get_blast_center(),
		radius,
		fallback_direction,
		velocity
	)
	if knockback.is_empty():
		return false
	var movement_state: Object = _get_player_movement_state(deps)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return false
	# One-shot per blast: only consume the player gate after a real movement
	# target accepts the response. A spatial miss remains eligible for walk-in.
	_impact_state.mark_player_knocked()
	movement_state.start_knockback(
		float(knockback.get("velocity", 0.0)),
		frames,
		decay,
		true,
		true
	)
	return true


func apply_pending_ball_impulse(
	scene: Dictionary,
	radius: float,
	power: float,
	speed_ceiling: float,
	minimum_up_bias: float
) -> bool:
	var pending_impulse: Dictionary = _impact_state.consume_ball_impulse()
	if pending_impulse.is_empty():
		return false
	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var impulse: Dictionary = _collision_resolver.resolve_crash_ball_impulse(
		ball_pos,
		ball_vel,
		_get_vector2(pending_impulse.get("center", Vector2.ZERO), Vector2.ZERO),
		radius,
		power,
		speed_ceiling,
		minimum_up_bias
	)
	if impulse.is_empty():
		return false
	scene["ball_vel"] = _get_vector2(impulse.get("ball_vel", ball_vel), ball_vel)
	return true


func _get_player_movement_state(deps: Dictionary) -> Object:
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null:
		return movement_state
	var registry: Object = deps.get("registry", null)
	if registry == null:
		return null
	# Avoid creating a new hot-path state while the battle is already running.
	# A cache miss means there is no current movement target for this response.
	if registry.has_method("get_cached_instance"):
		return registry.get_cached_instance("player_movement_state")
	if registry.has_method("get_instance"):
		return registry.get_instance("player_movement_state")
	return null


static func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
