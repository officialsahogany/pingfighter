extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")
const BallFrameMotionController := preload("res://scripts/ball/ball_frame_motion_controller.gd")

const CAP_KEY := "perk_fusion_overload_speed_cap"
const CAP_FRAMES_KEY := "perk_fusion_overload_speed_cap_frames"
const FAILSAFE_CAP_FRAMES := 180.0


static func apply_player_bounce(
	result: Dictionary,
	context: Dictionary,
	deps: Dictionary
) -> bool:
	var outgoing_velocity := BallContextReader.get_vector2(
		result,
		"ball_vel",
		BallContextReader.get_vector2(context, "ball_vel", Vector2.ZERO)
	)
	if outgoing_velocity.length_squared() <= 0.0001:
		return false
	# A successful player return starts a new outgoing leg. Any surviving cap
	# belongs to the previous excursion (for example after an auxiliary boss-side
	# reflector), so close it even when no new overload charge is armed.
	clear(result)
	var runtime_perk_state: Object = deps.get("runtime_perk_state", null)
	if (
		runtime_perk_state == null
		or not runtime_perk_state.has_method("consume_perk_fusion_paddle_bounce_speed_multiplier")
	):
		return false

	# Resolve the ordinary effective-speed policy before consuming the one-shot.
	# This keeps the promise at exactly +15% even when impact_boost > 1, and it
	# reuses every existing league/weather/skill cap instead of duplicating them.
	var ordinary_scene: Dictionary = _build_owner_ball_context(deps)
	ordinary_scene.merge(context, true)
	ordinary_scene.merge(result, true)
	clear(ordinary_scene)
	BallFrameMotionController.new().apply_ball_speed_limits(
		ordinary_scene,
		_build_limiter_deps(deps)
	)
	var ordinary_velocity := BallContextReader.get_vector2(
		ordinary_scene,
		"ball_vel",
		outgoing_velocity
	)
	if ordinary_velocity.length_squared() <= 0.0001:
		return false
	var speed_multiplier := float(
		runtime_perk_state.consume_perk_fusion_paddle_bounce_speed_multiplier()
	)
	if speed_multiplier <= 1.0:
		return false

	var boosted_velocity := ordinary_velocity * speed_multiplier
	var impact_boost := maxf(1.0, float(ordinary_scene.get("ball_impact_boost", 1.0)))
	result["ball_vel"] = boosted_velocity
	result["ball_impact_boost"] = impact_boost
	result[CAP_KEY] = boosted_velocity.length() * impact_boost
	result[CAP_FRAMES_KEY] = FAILSAFE_CAP_FRAMES
	return true


static func clear(scene: Dictionary) -> void:
	scene[CAP_KEY] = 0.0
	scene[CAP_FRAMES_KEY] = 0.0


static func clear_owner(owner: Object) -> void:
	if owner == null:
		return
	owner.set(CAP_KEY, 0.0)
	owner.set(CAP_FRAMES_KEY, 0.0)


static func _build_owner_ball_context(deps: Dictionary) -> Dictionary:
	var owner: Object = deps.get("owner", null)
	var registry: Object = deps.get("registry", null)
	if owner == null or registry == null or not registry.has_method("get_instance"):
		return {}
	var context_builder: Object = registry.get_instance("ball_update_context")
	if context_builder == null or not context_builder.has_method("build_update_context"):
		return {}
	return context_builder.build_update_context(owner)


static func _build_limiter_deps(deps: Dictionary) -> Dictionary:
	if deps.get("ball_physics", null) != null:
		return deps
	var registry: Object = deps.get("registry", null)
	if registry == null or not registry.has_method("get_instance"):
		return deps
	var ball_physics: Object = registry.get_instance("ball_physics")
	if ball_physics == null:
		return deps
	var limiter_deps := deps.duplicate()
	limiter_deps["ball_physics"] = ball_physics
	return limiter_deps
