extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemMagnetFieldParticles := preload("res://scripts/items/active_item_magnet_field_particles.gd")
const ActiveItemMagnetFieldParticlePayloadFactory := preload("res://scripts/items/active_item_magnet_field_particle_payload_factory.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_particle_payload_factory()
	_verify_direct_particle_lifecycle()
	_verify_controller_delegates_particles()
	_verify_particle_delegation_and_catalog()

	if _failures.is_empty():
		print("active_item_magnet_field_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_payload_factory() -> void:
	seed(20260612)
	var center := Vector2(160.0, 620.0)
	var particle: Dictionary = ActiveItemMagnetFieldParticlePayloadFactory.build_particle(center)
	var position: Vector2 = particle.get("position", Vector2.INF)
	_expect(position.x >= 10.0 and position.x <= 310.0, "magnet particle should keep radial x range")
	_expect(position.y >= 500.0 and position.y <= 600.0, "magnet particle should keep vertical spawn range")
	var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
	_expect(velocity.x >= -0.3 and velocity.x <= 0.3, "magnet particle should keep x velocity range")
	_expect(velocity.y >= -1.5 and velocity.y <= -0.5, "magnet particle should keep y velocity range")
	_expect(float(particle.get("radius", 0.0)) >= 2.0 and float(particle.get("radius", 0.0)) <= 4.0, "magnet particle should keep radius range")
	_expect(is_equal_approx(float(particle.get("alpha", 0.0)), 200.0 / 255.0), "magnet particle should keep initial alpha")
	_expect(_color_in(particle.get("color", Color.TRANSPARENT), ActiveItemMagnetFieldParticlePayloadFactory.MAGNET_FIELD_PARTICLE_COLORS), "magnet particle should use known palette")


func _verify_direct_particle_lifecycle() -> void:
	seed(77)
	var particles_helper: Object = ActiveItemMagnetFieldParticles.new()
	var particles: Array[Dictionary] = []
	var center := Vector2(160.0, 620.0)

	var accumulator: float = particles_helper.advance_particles(particles, center, 2.5, 1.0)
	_expect(is_equal_approx(accumulator, 0.5), "magnet particles should return remaining spawn accumulator")
	_expect(particles.size() == 1, "magnet particles should spawn after interval threshold")
	_expect(float(particles[0].get("alpha", 0.0)) < 200.0 / 255.0, "magnet particle should update alpha after spawning")

	for _i in range(120):
		particles_helper.spawn_particle(particles, center)
	_expect(particles.size() == 96, "magnet particle helper should enforce cap")

	var expired: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	}]
	particles_helper.update_particles(expired, 2.0)
	_expect(expired.is_empty(), "magnet particle helper should compact faded particles")


func _verify_controller_delegates_particles() -> void:
	seed(88)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	controller.magnet_field_active = true
	controller.magnet_field_timer_frames = 30.0
	controller.magnet_field_initial_timer_frames = 30.0
	controller.magnet_field_particle_accumulator_frames = 2.5

	controller.update(owner, 1.0 / 60.0)
	_expect(controller.magnet_field_particles.size() == 1, "controller should delegate magnet particle spawning")
	_expect(is_equal_approx(controller.magnet_field_particle_accumulator_frames, 0.5), "controller should preserve delegated accumulator")
	_expect(controller.magnet_field_player_center == Vector2(160.0, 620.0), "controller should still update magnet player center")


func _verify_particle_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_magnet_field_particles.gd")
	_expect(source.find("ActiveItemMagnetFieldParticlePayloadFactory.build_particle") >= 0, "Magnet Field particles should delegate particle payloads")
	_expect(source.find("particles.append({") < 0, "Magnet Field particles should not inline particle dictionaries")

	var item_modules: Dictionary = GameplayItemModuleCatalog.MODULES
	_expect(item_modules.has("active_item_magnet_field_particles"), "item module catalog should list Magnet Field particles")
	_expect(item_modules.has("active_item_magnet_field_particle_payload_factory"), "item module catalog should list Magnet Field particle payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_magnet_field_particle_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_magnet_field_particle_payload_factory.gd", "top-level module catalog should resolve Magnet Field particle payload factory")


func _color_in(value: Variant, colors: Array) -> bool:
	if not (value is Color):
		return false
	for color in colors:
		if (value as Color).is_equal_approx(color):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
