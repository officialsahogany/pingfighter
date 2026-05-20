extends RefCounted

const FEEDBACK_SHAKE_AMOUNT := 0.025
const FEEDBACK_SHAKE_DURATION := 0.85


func activate(
	target: Object,
	owner: Object,
	registry: Object,
	installing: bool,
	particles: Array[Dictionary],
	geometry: Object,
	installation: Object,
	particles_helper: Object,
	state_applier: Object,
	effect_feedback: Object
) -> bool:
	if installing or owner == null:
		return false

	var wall_rect: Rect2 = geometry.build_wall_rect(
		owner,
		_get_instance(registry, "mythic_item_runtime")
	)
	state_applier.apply_brick_wall_installation_state(
		target,
		installation.start_installation(wall_rect, geometry.get_gauge_center(owner, wall_rect))
	)
	particles_helper.spawn_install_particles(particles, wall_rect)

	effect_feedback.trigger_registry_feedback(
		registry,
		false,
		false,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_DURATION
	)
	effect_feedback.play_first_audio(registry, ["play_active_item"])

	return true


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
