extends SceneTree

const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_particle_lifecycle()
	_verify_controller_delegates_particles()

	if _failures.is_empty():
		print("active_item_brick_wall_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_particle_lifecycle() -> void:
	seed(11)
	var particles_helper: Object = ActiveItemBrickWallParticles.new()
	var particles: Array[Dictionary] = []
	var wall_rect := Rect2(Vector2(100.0, 700.0), Vector2(80.0, 20.0))

	particles_helper.spawn_install_particles(particles, wall_rect)
	_expect(particles.size() == 8, "install particles should add the legacy dust count")
	_expect(str(particles[0].get("kind", "")) == "dust", "install particles should be dust")

	particles_helper.spawn_install_complete_particles(particles, wall_rect)
	_expect(particles.size() == 18, "install-complete particles should append dust")

	particles_helper.spawn_hit_dust(particles, Vector2(120.0, 710.0), 12)
	_expect(particles.size() == 30, "hit dust should append requested amount")

	particles_helper.spawn_destruction_effect(particles, wall_rect, Vector2(120.0, 710.0))
	_expect(particles.size() > 30, "destruction should add fragments and dust")
	_expect(particles.size() <= 64, "destruction particles should respect cap")
	_expect(_has_particle_kind(particles, "brick"), "destruction should include brick fragments")

	var tracked: Dictionary = particles[0].duplicate(true)
	particles_helper.update_particles(particles, 1.0 / 60.0)
	_expect(particles.size() > 0, "short update should keep live particles")
	_expect(float(particles[0].get("life", 0.0)) < float(tracked.get("life", 0.0)), "update should reduce particle life")

	var expired: Array[Dictionary] = [{
		"kind": "dust",
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"life": 0.5,
		"initial_life": 1.0,
	}]
	particles_helper.update_particles(expired, 1.0)
	_expect(expired.is_empty(), "expired particles should be compacted out")


func _verify_controller_delegates_particles() -> void:
	var controller: Object = ActiveItemEffectController.new()
	controller.brick_particles.append({
		"kind": "dust",
		"position": Vector2.ZERO,
		"velocity": Vector2(1.0, -1.0),
		"life": 30.0,
		"initial_life": 30.0,
	})

	controller.update(null, 1.0 / 60.0)
	_expect(controller.brick_particles.size() > 0, "controller delegated particle update should keep live particles")
	_expect(float(controller.brick_particles[0].get("life", 0.0)) < 30.0, "controller delegated particle update should tick life")


func _has_particle_kind(particles: Array[Dictionary], kind: String) -> bool:
	for particle in particles:
		if str(particle.get("kind", "")) == kind:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
