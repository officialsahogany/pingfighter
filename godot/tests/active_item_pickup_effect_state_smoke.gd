extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")
const ActiveItemPickupEffectPayloadFactory := preload("res://scripts/items/active_item_pickup_effect_payload_factory.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_payload_factory()
	_verify_direct_pickup_effect()
	_verify_controller_delegates_pickup_effect()
	_verify_effect_delegation_and_catalog()

	if _failures.is_empty():
		print("active_item_pickup_effect_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_payload_factory() -> void:
	seed(20260612)
	var item_data := {"id": "banana", "nested": {"rarity": "test"}}
	var effect: Dictionary = ActiveItemPickupEffectPayloadFactory.build_pickup_effect(
		item_data,
		"banana",
		Vector2(240.0, 300.0),
		2.0,
		180.0 / 255.0,
		"hint"
	)
	item_data["nested"]["rarity"] = "mutated"
	_expect(str((effect.get("item_data", {}) as Dictionary).get("id", "")) == "banana", "pickup effect payload should preserve item data")
	_expect(str(((effect.get("item_data", {}) as Dictionary).get("nested", {}) as Dictionary).get("rarity", "")) == "test", "pickup effect payload should deep-copy item data")
	_expect(str(effect.get("display_name", "")) == "banana", "pickup effect payload should preserve display name")
	_expect(str(effect.get("use_hint_text", "")) == "hint", "pickup effect payload should preserve use hint")
	_expect(effect.get("position", Vector2.ZERO) == Vector2(240.0, 300.0), "pickup effect payload should preserve position")
	_expect(is_equal_approx(float(effect.get("timer", 0.0)), 2.0), "pickup effect payload should preserve timer")

	var particle: Dictionary = ActiveItemPickupEffectPayloadFactory.build_balloon_pop_particle(Vector2(240.0, 300.0), Color.YELLOW)
	_expect(particle.get("position", Vector2.ZERO) == Vector2(240.0, 300.0), "balloon pop particle payload should preserve center")
	var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
	_expect(velocity.length() >= 90.0 and velocity.length() <= 250.0, "balloon pop particle payload should keep speed range")
	_expect(float(particle.get("radius", 0.0)) >= 2.0 and float(particle.get("radius", 0.0)) <= 4.5, "balloon pop particle payload should keep radius range")
	_expect(float(particle.get("lifetime", 0.0)) >= 0.28 and float(particle.get("lifetime", 0.0)) <= 0.62, "balloon pop particle payload should keep lifetime range")
	_expect(particle.get("color", null) is Color, "balloon pop particle payload should expose color")


func _verify_direct_pickup_effect() -> void:
	seed(55)
	var state: Object = ActiveItemPickupEffectState.new()
	var particles: Array[Dictionary] = []
	var field_item := {
		"item_data": {"id": "banana"},
		"position": Vector2(240.0, 300.0),
		"pickup_use_hint_text": "1번 키로 사용",
	}

	var effect: Dictionary = state.trigger_pickup_effect(field_item, "banana", Color.YELLOW, particles)
	_expect(state.has_pickup_effect(effect), "pickup effect should become active after trigger")
	_expect(effect.get("display_name", "") == "banana", "pickup effect should preserve display name")
	_expect(effect.get("use_hint_text", "") == "1번 키로 사용", "pickup effect should preserve active-item use hint text")
	_expect(effect.get("position", Vector2.ZERO) == Vector2(240.0, 300.0), "pickup effect should start at field item position")
	_expect(particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "pickup effect should spawn capped balloon pop particles")

	state.update_pickup_effect(effect, 1.0)
	_expect(effect.get("position", Vector2.ZERO) != Vector2(240.0, 300.0), "pickup effect should move toward HUD target")
	_expect(is_equal_approx(float(effect.get("alpha", 0.0)), 180.0 / 255.0), "pickup effect should keep full alpha before fade window")

	state.update_pickup_particles(particles, 0.1)
	_expect(float(particles[0].get("age", 0.0)) > 0.0, "pickup particles should age")

	state.update_pickup_effect(effect, 2.0)
	_expect(effect.is_empty(), "pickup effect should expire")
	state.update_pickup_particles(particles, 2.0)
	_expect(particles.is_empty(), "pickup particles should expire")

	for _i in range(4):
		state.trigger_pickup_effect(field_item, "banana", Color.YELLOW, particles)
	_expect(particles.size() <= ActiveItemPickupEffectState.MAX_PICKUP_PARTICLES, "rapid pickup effects should cap particle accumulation")


func _verify_controller_delegates_pickup_effect() -> void:
	seed(66)
	var controller: Object = ActiveItemEffectController.new()
	var field_item := {
		"item_data": {"id": "gauge_charge"},
		"position": Vector2(320.0, 420.0),
	}

	controller.trigger_pickup_effect(field_item, "energy charge", Color.CYAN, null)
	_expect(controller.has_pickup_effect(), "controller should delegate pickup effect activation")
	_expect(controller.pickup_particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "controller should delegate capped pickup particles")

	controller.update(null, 2.1)
	_expect(not controller.has_pickup_effect(), "controller delegated pickup effect should expire")
	_expect(controller.pickup_particles.is_empty(), "controller delegated pickup particles should expire")


func _verify_effect_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_pickup_effect_state.gd")
	_expect(source.find("ActiveItemPickupEffectPayloadFactory.build_pickup_effect") >= 0, "Pickup effect state should delegate pickup effect payloads")
	_expect(source.find("ActiveItemPickupEffectPayloadFactory.build_balloon_pop_particle") >= 0, "Pickup effect state should delegate balloon particle payloads")
	_expect(source.find("var pickup_effect: Dictionary = {") < 0, "Pickup effect state should not inline pickup effect dictionaries")
	_expect(source.find("particles.append({") < 0, "Pickup effect state should not inline particle dictionaries")

	var item_modules: Dictionary = GameplayItemModuleCatalog.MODULES
	_expect(item_modules.has("active_item_pickup_effect_state"), "item module catalog should list pickup effect state")
	_expect(item_modules.has("active_item_pickup_effect_payload_factory"), "item module catalog should list pickup effect payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_pickup_effect_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_pickup_effect_payload_factory.gd", "top-level module catalog should resolve pickup effect payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
