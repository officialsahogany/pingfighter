extends SceneTree

const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")
const ActiveItemRegenerationPotionEffect := preload("res://scripts/items/active_item_regeneration_potion_effect.gd")
const ActiveItemTransientEffectUpdater := preload("res://scripts/items/active_item_transient_effect_updater.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_transient_update_sequence()

	if _failures.is_empty():
		print("active_item_transient_effect_updater_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_transient_update_sequence() -> void:
	var brick_particles: Array[Dictionary] = [{
		"kind": "dust",
		"position": Vector2.ZERO,
		"velocity": Vector2(1.0, -1.0),
		"life": 30.0,
		"initial_life": 30.0,
	}]
	var regeneration_potion_particles: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"velocity": Vector2(0.0, -12.0),
		"age": 0.0,
		"lifetime": 1.0,
	}]
	var regeneration_potion_rings: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"age": 0.0,
		"duration": 1.0,
	}]
	var pickup_particles: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"velocity": Vector2(12.0, 0.0),
		"age": 0.0,
		"lifetime": 1.0,
	}]
	var pickup_effect := {
		"timer": 2.0,
		"alpha": 180.0 / 255.0,
		"position": Vector2.ZERO,
		"start_position": Vector2.ZERO,
	}

	_apply_update(
		brick_particles,
		regeneration_potion_particles,
		regeneration_potion_rings,
		pickup_particles,
		pickup_effect,
		1.0 / 60.0
	)

	_expect(float(brick_particles[0].get("life", 0.0)) < 30.0, "transient updater should tick brick particles")
	_expect(float(regeneration_potion_particles[0].get("age", 0.0)) > 0.0, "transient updater should tick regeneration particles")
	_expect(float(regeneration_potion_rings[0].get("age", 0.0)) > 0.0, "transient updater should tick regeneration rings")
	_expect(float(pickup_particles[0].get("age", 0.0)) > 0.0, "transient updater should tick pickup particles")
	_expect(float(pickup_effect.get("timer", 0.0)) < 2.0, "transient updater should tick pickup popup")

	_apply_update(
		brick_particles,
		regeneration_potion_particles,
		regeneration_potion_rings,
		pickup_particles,
		pickup_effect,
		2.0
	)

	_expect(brick_particles.is_empty(), "transient updater should expire brick particles")
	_expect(regeneration_potion_particles.is_empty(), "transient updater should expire regeneration particles")
	_expect(regeneration_potion_rings.is_empty(), "transient updater should expire regeneration rings")
	_expect(pickup_particles.is_empty(), "transient updater should expire pickup particles")
	_expect(pickup_effect.is_empty(), "transient updater should expire pickup popup")


func _apply_update(
	brick_particles: Array[Dictionary],
	regeneration_potion_particles: Array[Dictionary],
	regeneration_potion_rings: Array[Dictionary],
	pickup_particles: Array[Dictionary],
	pickup_effect: Dictionary,
	delta: float
) -> void:
	ActiveItemTransientEffectUpdater.new().apply_update(
		brick_particles,
		regeneration_potion_particles,
		regeneration_potion_rings,
		pickup_particles,
		pickup_effect,
		delta,
		ActiveItemBrickWallParticles.new(),
		ActiveItemRegenerationPotionEffect.new(),
		ActiveItemPickupEffectState.new()
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
