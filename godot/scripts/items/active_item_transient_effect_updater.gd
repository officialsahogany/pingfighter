extends RefCounted


func apply_update(
	brick_particles: Array[Dictionary],
	regeneration_potion_particles: Array[Dictionary],
	regeneration_potion_rings: Array[Dictionary],
	pickup_particles: Array[Dictionary],
	pickup_effect: Dictionary,
	delta: float,
	brick_particles_helper: Object,
	regeneration_potion_effect: Object,
	pickup_effect_state: Object
) -> void:
	brick_particles_helper.update_particles(brick_particles, delta)
	regeneration_potion_effect.update_effect(regeneration_potion_particles, regeneration_potion_rings, delta)
	pickup_effect_state.update_pickup_particles(pickup_particles, delta)
	pickup_effect_state.update_pickup_effect(pickup_effect, delta)
