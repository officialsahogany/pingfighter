extends SceneTree

const ActiveItemBrickWallParticles := preload("res://scripts/items/active_item_brick_wall_particles.gd")
const ActiveItemBrickWallParticlePayloadFactory := preload("res://scripts/items/active_item_brick_wall_particle_payload_factory.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_payload_factory_ranges()
	_verify_direct_particle_lifecycle()
	_verify_controller_delegates_particles()
	_verify_particle_delegation_and_catalog()

	if _failures.is_empty():
		print("active_item_brick_wall_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_payload_factory_ranges() -> void:
	seed(20260612)
	var wall_rect := Rect2(Vector2(100.0, 700.0), Vector2(80.0, 20.0))
	var center := wall_rect.position + wall_rect.size * 0.5

	var install_dust: Dictionary = ActiveItemBrickWallParticlePayloadFactory.build_install_dust(center, wall_rect.size)
	_expect(str(install_dust.get("kind", "")) == "dust", "install payload should be dust")
	var install_pos: Vector2 = install_dust.get("position", Vector2.INF)
	_expect(absf(install_pos.x - center.x) <= wall_rect.size.x * 0.45, "install dust should keep x jitter range")
	_expect(install_pos.y >= center.y - 3.0 and install_pos.y <= center.y + 4.0, "install dust should keep y jitter range")
	_expect(float(install_dust.get("radius", 0.0)) >= 2.0 and float(install_dust.get("radius", 0.0)) <= 4.0, "install dust should keep radius range")
	_expect(is_equal_approx(float(install_dust.get("initial_life", 0.0)), 30.0), "install dust should preserve initial life")

	var complete_dust: Dictionary = ActiveItemBrickWallParticlePayloadFactory.build_install_complete_dust(wall_rect)
	var complete_pos: Vector2 = complete_dust.get("position", Vector2.INF)
	_expect(complete_pos.x >= wall_rect.position.x and complete_pos.x <= wall_rect.position.x + wall_rect.size.x, "install-complete dust should stay on wall width")
	_expect(complete_pos.y >= wall_rect.position.y - 2.0 and complete_pos.y <= wall_rect.position.y + 4.0, "install-complete dust should stay near wall top")
	_expect(float(complete_dust.get("life", 0.0)) >= 18.0 and float(complete_dust.get("life", 0.0)) <= 34.0, "install-complete dust should keep life range")

	var hit_dust: Dictionary = ActiveItemBrickWallParticlePayloadFactory.build_hit_dust(Vector2(120.0, 710.0))
	var hit_pos: Vector2 = hit_dust.get("position", Vector2.INF)
	_expect(hit_pos.x >= 110.0 and hit_pos.x <= 130.0, "hit dust should keep x jitter range")
	_expect(hit_pos.y >= 707.0 and hit_pos.y <= 715.0, "hit dust should keep y jitter range")
	_expect(float(hit_dust.get("life", 0.0)) >= 18.0 and float(hit_dust.get("life", 0.0)) <= 38.0, "hit dust should keep life range")

	var fragment: Dictionary = ActiveItemBrickWallParticlePayloadFactory.build_brick_fragment(wall_rect, Vector2(120.0, 710.0))
	var fragment_pos: Vector2 = fragment.get("position", Vector2.INF)
	_expect(str(fragment.get("kind", "")) == "brick", "fragment payload should be brick")
	_expect(fragment_pos.x >= wall_rect.position.x and fragment_pos.x <= wall_rect.position.x + wall_rect.size.x, "brick fragment should spawn inside wall width")
	_expect(fragment_pos.y >= wall_rect.position.y and fragment_pos.y <= wall_rect.position.y + wall_rect.size.y, "brick fragment should spawn inside wall height")
	var fragment_size: Vector2 = fragment.get("size", Vector2.ZERO)
	_expect(fragment_size.x >= 4.0 and fragment_size.x <= 9.0, "brick fragment should keep width range")
	_expect(fragment_size.y >= 3.0 and fragment_size.y <= 7.0, "brick fragment should keep height range")
	_expect(float(fragment.get("life", 0.0)) >= 42.0 and float(fragment.get("life", 0.0)) <= 82.0, "brick fragment should keep life range")


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


func _verify_particle_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_brick_wall_particles.gd")
	_expect(source.find("ActiveItemBrickWallParticlePayloadFactory.build_install_dust") >= 0, "Brick Wall particles should delegate install dust payloads")
	_expect(source.find("ActiveItemBrickWallParticlePayloadFactory.build_install_complete_dust") >= 0, "Brick Wall particles should delegate install-complete dust payloads")
	_expect(source.find("ActiveItemBrickWallParticlePayloadFactory.build_hit_dust") >= 0, "Brick Wall particles should delegate hit dust payloads")
	_expect(source.find("ActiveItemBrickWallParticlePayloadFactory.build_brick_fragment") >= 0, "Brick Wall particles should delegate fragment payloads")
	_expect(source.find("particles.append({") < 0, "Brick Wall particles should not inline particle dictionaries")

	var item_modules: Dictionary = GameplayItemModuleCatalog.MODULES
	_expect(item_modules.has("active_item_brick_wall_particles"), "item module catalog should list Brick Wall particles")
	_expect(item_modules.has("active_item_brick_wall_particle_payload_factory"), "item module catalog should list Brick Wall particle payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_brick_wall_particle_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_brick_wall_particle_payload_factory.gd", "top-level module catalog should resolve Brick Wall particle payload factory")


func _has_particle_kind(particles: Array[Dictionary], kind: String) -> bool:
	for particle in particles:
		if str(particle.get("kind", "")) == kind:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
