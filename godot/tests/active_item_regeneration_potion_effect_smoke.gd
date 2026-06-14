extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemRegenerationPotionEffect := preload("res://scripts/items/active_item_regeneration_potion_effect.gd")
const ActiveItemRegenerationPotionPayloadFactory := preload("res://scripts/items/active_item_regeneration_potion_payload_factory.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(100.0, 600.0)
	var player_paddle_width := 120.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_payload_factory()
	_verify_direct_regeneration_effect()
	_verify_controller_delegates_regeneration_effect()
	_verify_effect_delegation_and_catalog()

	if _failures.is_empty():
		print("active_item_regeneration_potion_effect_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_payload_factory() -> void:
	seed(20260612)
	var center := Vector2(160.0, 618.0)
	var ring: Dictionary = ActiveItemRegenerationPotionPayloadFactory.build_ring(center, ActiveItemRegenerationPotionEffect.REGENERATION_POTION_RING_DURATION_SEC)
	_expect(ring.get("position", Vector2.ZERO) == center, "regeneration ring payload should preserve center")
	_expect(is_equal_approx(float(ring.get("age", -1.0)), 0.0), "regeneration ring payload should start at age zero")
	_expect(is_equal_approx(float(ring.get("duration", 0.0)), ActiveItemRegenerationPotionEffect.REGENERATION_POTION_RING_DURATION_SEC), "regeneration ring payload should preserve duration")

	var particle: Dictionary = ActiveItemRegenerationPotionPayloadFactory.build_particle(center, ActiveItemRegenerationPotionEffect.REGENERATION_POTION_PARTICLE_DURATION_SEC)
	var position: Vector2 = particle.get("position", Vector2.INF)
	_expect(position.distance_to(center) >= 6.0 and position.distance_to(center) <= 48.0, "regeneration particle payload should keep radial spawn range")
	var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
	_expect(velocity.x >= -34.0 and velocity.x <= 34.0, "regeneration particle payload should keep x velocity range")
	_expect(velocity.y >= -104.0 and velocity.y <= -34.0, "regeneration particle payload should keep y velocity range")
	_expect(float(particle.get("radius", 0.0)) >= 2.4 and float(particle.get("radius", 0.0)) <= 5.2, "regeneration particle payload should keep radius range")
	_expect(float(particle.get("lifetime", 0.0)) >= 0.42 and float(particle.get("lifetime", 0.0)) <= ActiveItemRegenerationPotionEffect.REGENERATION_POTION_PARTICLE_DURATION_SEC, "regeneration particle payload should keep lifetime range")
	_expect(_color_in(particle.get("color", Color.TRANSPARENT), ActiveItemRegenerationPotionPayloadFactory.REGENERATION_POTION_PARTICLE_COLORS), "regeneration particle payload should use known palette")


func _verify_direct_regeneration_effect() -> void:
	seed(33)
	var effect: Object = ActiveItemRegenerationPotionEffect.new()
	var particles: Array[Dictionary] = []
	var rings: Array[Dictionary] = []
	var center := Vector2(160.0, 618.0)

	effect.spawn_effect(particles, rings, center)
	_expect(rings.size() == 1, "regeneration effect should spawn one ring")
	_expect(particles.size() == 12, "regeneration effect should spawn the legacy particle count")
	_expect(rings[0].get("position", Vector2.ZERO) == center, "regeneration ring should use provided center")

	var particle_before: Dictionary = particles[0].duplicate(true)
	effect.update_effect(particles, rings, 0.1)
	_expect(float(particles[0].get("age", 0.0)) > float(particle_before.get("age", 0.0)), "regeneration particle age should advance")
	_expect(particles[0].get("position", Vector2.ZERO) != particle_before.get("position", Vector2.ZERO), "regeneration particle should move")
	_expect(float(rings[0].get("age", 0.0)) > 0.0, "regeneration ring age should advance")

	effect.update_effect(particles, rings, 2.0)
	_expect(particles.is_empty(), "regeneration particles should expire")
	_expect(rings.is_empty(), "regeneration rings should expire")


func _verify_controller_delegates_regeneration_effect() -> void:
	seed(44)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	controller.apply_regeneration_potion(owner, null)
	_expect(controller.regeneration_potion_rings.size() == 1, "controller should delegate regeneration ring spawn")
	_expect(controller.regeneration_potion_particles.size() == 12, "controller should delegate regeneration particle spawn")
	_expect(controller.regeneration_potion_rings[0].get("position", Vector2.ZERO) == Vector2(160.0, 618.0), "controller should keep regeneration anchor parity")

	controller.update(null, 2.0)
	_expect(controller.regeneration_potion_particles.is_empty(), "controller delegated particles should expire")
	_expect(controller.regeneration_potion_rings.is_empty(), "controller delegated rings should expire")


func _verify_effect_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_regeneration_potion_effect.gd")
	_expect(source.find("ActiveItemRegenerationPotionPayloadFactory.build_ring") >= 0, "Regeneration Potion effect should delegate ring payloads")
	_expect(source.find("ActiveItemRegenerationPotionPayloadFactory.build_particle") >= 0, "Regeneration Potion effect should delegate particle payloads")
	_expect(source.find("rings.append({") < 0, "Regeneration Potion effect should not inline ring dictionaries")
	_expect(source.find("particles.append({") < 0, "Regeneration Potion effect should not inline particle dictionaries")

	var item_modules: Dictionary = GameplayItemModuleCatalog.MODULES
	_expect(item_modules.has("active_item_regeneration_potion_effect"), "item module catalog should list Regeneration Potion effect")
	_expect(item_modules.has("active_item_regeneration_potion_payload_factory"), "item module catalog should list Regeneration Potion payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_regeneration_potion_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_regeneration_potion_payload_factory.gd", "top-level module catalog should resolve Regeneration Potion payload factory")


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
