extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemHolyBarrierParticles := preload("res://scripts/items/active_item_holy_barrier_particles.gd")
const ActiveItemHolyBarrierParticlePayloadFactory := preload("res://scripts/items/active_item_holy_barrier_particle_payload_factory.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_particle_payload_factory()
	_verify_direct_particle_lifecycle()
	_verify_controller_delegates_particles()
	_verify_particle_delegation_and_catalog()

	if _failures.is_empty():
		print("active_item_holy_barrier_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_payload_factory() -> void:
	seed(20260612)
	var hit: Dictionary = ActiveItemHolyBarrierParticlePayloadFactory.build_hit_particle(Vector2(200.0, 720.0))
	var hit_position: Vector2 = hit.get("position", Vector2.INF)
	_expect(hit_position.x >= 185.0 and hit_position.x <= 215.0, "holy barrier hit particle should keep x jitter range")
	_expect(is_equal_approx(hit_position.y, 720.0), "holy barrier hit particle should keep impact y")
	var hit_velocity: Vector2 = hit.get("velocity", Vector2.ZERO)
	_expect(hit_velocity.x >= -120.0 and hit_velocity.x <= 120.0, "holy barrier hit particle should keep x velocity range")
	_expect(hit_velocity.y >= -180.0 and hit_velocity.y <= -60.0, "holy barrier hit particle should keep y velocity range")
	_expect(float(hit.get("radius", 0.0)) >= 3.0 and float(hit.get("radius", 0.0)) <= 7.0, "holy barrier hit particle should keep radius range")
	_expect(is_equal_approx(float(hit.get("alpha", 0.0)), 1.0), "holy barrier hit particle should keep alpha")

	var idle: Dictionary = ActiveItemHolyBarrierParticlePayloadFactory.build_idle_particle(760.0, 735.0)
	var idle_position: Vector2 = idle.get("position", Vector2.INF)
	_expect(idle_position.x >= 0.0 and idle_position.x <= 760.0, "holy barrier idle particle should keep field x range")
	_expect(idle_position.y >= 730.0 and idle_position.y <= 740.0, "holy barrier idle particle should keep barrier y range")
	var idle_velocity: Vector2 = idle.get("velocity", Vector2.ZERO)
	_expect(idle_velocity.x >= -30.0 and idle_velocity.x <= 30.0, "holy barrier idle particle should keep x velocity range")
	_expect(idle_velocity.y >= -90.0 and idle_velocity.y <= -30.0, "holy barrier idle particle should keep y velocity range")
	_expect(_color_in(idle.get("color", Color.TRANSPARENT), ActiveItemHolyBarrierParticlePayloadFactory.HOLY_BARRIER_PARTICLE_COLORS), "holy barrier idle particle should use known palette")


func _verify_direct_particle_lifecycle() -> void:
	seed(99)
	var particles_helper: Object = ActiveItemHolyBarrierParticles.new()
	var particles: Array[Dictionary] = []

	var accumulator: float = particles_helper.advance_idle_particles(particles, 4.5, 1.0, 1.0 / 60.0)
	_expect(is_equal_approx(accumulator, 0.5), "holy barrier particles should return remaining spawn accumulator")
	_expect(particles.size() == 2, "holy barrier idle particles should spawn in pairs")
	_expect(float(particles[0].get("alpha", 0.0)) < 1.0, "holy barrier idle particles should fade after spawning")

	particles_helper.spawn_hit_particles(particles, Vector2(200.0, 720.0))
	_expect(particles.size() == 12, "holy barrier hit should add burst particles")

	var expired: Array[Dictionary] = [{
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	}]
	particles_helper.update_particles(expired, 2.0, 1.0 / 30.0)
	_expect(expired.is_empty(), "holy barrier particles should compact faded entries")


func _verify_controller_delegates_particles() -> void:
	seed(111)
	var controller: Object = ActiveItemEffectController.new()
	controller.holy_barrier_active = true
	controller.holy_barrier_timer_frames = 30.0
	controller.holy_barrier_initial_timer_frames = 30.0
	controller.holy_barrier_particle_accumulator_frames = 4.5

	controller.update(null, 1.0 / 60.0)
	_expect(controller.holy_barrier_particles.size() == 2, "controller should delegate holy barrier idle particles")
	_expect(is_equal_approx(controller.holy_barrier_particle_accumulator_frames, 0.5), "controller should preserve delegated holy barrier accumulator")

	controller.notify_holy_barrier_hit(Vector2(200.0, 720.0))
	_expect(controller.holy_barrier_particles.size() == 12, "controller should delegate holy barrier hit particles")

	controller.holy_barrier_active = false
	controller.holy_barrier_particles.clear()
	controller.holy_barrier_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	})
	controller.update(null, 1.0 / 30.0)
	_expect(controller.holy_barrier_particles.is_empty(), "inactive controller should still fade remaining holy barrier particles")


func _verify_particle_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_holy_barrier_particles.gd")
	_expect(source.find("ActiveItemHolyBarrierParticlePayloadFactory.build_hit_particle") >= 0, "Holy Barrier particles should delegate hit payloads")
	_expect(source.find("ActiveItemHolyBarrierParticlePayloadFactory.build_idle_particle") >= 0, "Holy Barrier particles should delegate idle payloads")
	_expect(source.find("particles.append({") < 0, "Holy Barrier particles should not inline particle dictionaries")

	var item_modules: Dictionary = GameplayItemModuleCatalog.MODULES
	_expect(item_modules.has("active_item_holy_barrier_particles"), "item module catalog should list Holy Barrier particles")
	_expect(item_modules.has("active_item_holy_barrier_particle_payload_factory"), "item module catalog should list Holy Barrier particle payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_holy_barrier_particle_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_holy_barrier_particle_payload_factory.gd", "top-level module catalog should resolve Holy Barrier particle payload factory")


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
