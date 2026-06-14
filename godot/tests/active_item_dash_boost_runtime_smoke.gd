extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemEffectStateApplier := preload("res://scripts/items/active_item_effect_state_applier.gd")
const ActiveItemDashBoostParticles := preload("res://scripts/items/active_item_dash_boost_particles.gd")
const ActiveItemDashBoostParticlePayloadFactory := preload("res://scripts/items/active_item_dash_boost_particle_payload_factory.gd")
const ActiveItemDashBoostRuntime := preload("res://scripts/items/active_item_dash_boost_runtime.gd")
const GameplayItemModuleCatalog := preload("res://scripts/resources/gameplay_item_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")

var _failures: Array[String] = []


class FakeTarget:
	extends RefCounted

	var dash_boost_active := false
	var dash_boost_timer_frames := 0.0
	var dash_boost_initial_timer_frames := 0.0
	var dash_boost_glow_phase := 0.0
	var dash_boost_particle_accumulator_frames := 0.0
	var dash_boost_player_center := Vector2(380.0, 720.0)
	var dash_boost_particles: Array[Dictionary] = []


func _init() -> void:
	_verify_particle_payload_factory()
	_verify_direct_runtime_state()
	_verify_direct_runtime_update_application()
	_verify_controller_delegates_runtime_state()
	_verify_controller_multipliers_and_query()
	_verify_particle_delegation_and_catalog()

	if _failures.is_empty():
		print("active_item_dash_boost_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_payload_factory() -> void:
	seed(20260612)
	var center := Vector2(380.0, 720.0)
	var particle: Dictionary = ActiveItemDashBoostParticlePayloadFactory.build_idle_particle(center)
	var position: Vector2 = particle.get("position", Vector2.INF)
	_expect(position.x >= 200.0 and position.x <= 560.0, "dash boost idle particle should keep x jitter range")
	_expect(position.y >= 690.0 and position.y <= 720.0, "dash boost idle particle should keep y jitter range")
	var velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
	_expect(velocity.x >= -60.0 and velocity.x <= 60.0, "dash boost idle particle should keep x velocity range")
	_expect(velocity.y >= -120.0 and velocity.y <= -30.0, "dash boost idle particle should keep y velocity range")
	_expect(float(particle.get("radius", 0.0)) >= 2.0 and float(particle.get("radius", 0.0)) <= 4.0, "dash boost idle particle should keep radius range")
	_expect(is_equal_approx(float(particle.get("alpha", 0.0)), 200.0 / 255.0), "dash boost idle particle should keep initial alpha")
	_expect(is_equal_approx(float(particle.get("shrink_per_frame", 0.0)), 0.05), "dash boost idle particle should keep shrink rate")
	_expect(_color_in(particle.get("color", Color.TRANSPARENT), ActiveItemDashBoostParticlePayloadFactory.DASH_BOOST_PARTICLE_COLORS), "dash boost idle particle should use known palette")


func _verify_direct_runtime_state() -> void:
	var runtime: Object = ActiveItemDashBoostRuntime.new()

	var started: Dictionary = runtime.start_state()
	_expect(bool(started.get("active", false)), "dash boost runtime should start active")
	_expect(is_equal_approx(float(started.get("timer_frames", 0.0)), 480.0), "dash boost runtime should use reference duration")
	_expect(is_equal_approx(float(started.get("glow_phase", -1.0)), 0.0), "dash boost runtime should reset glow on start")
	_expect(bool(started.get("clear_particles", false)), "dash boost runtime should clear particles on start")

	var updated: Dictionary = runtime.update_state(true, 30.0, 30.0, 1.0, 4.5, 1.0 / 60.0)
	_expect(bool(updated.get("active", false)), "dash boost runtime should remain active while time remains")
	_expect(is_equal_approx(float(updated.get("timer_frames", 0.0)), 29.0), "dash boost runtime should tick duration")
	_expect(is_equal_approx(float(updated.get("glow_phase", 0.0)), 1.15), "dash boost runtime should advance glow")
	_expect(bool(updated.get("advance_idle_particles", false)), "dash boost runtime should request idle particle advance")

	var expired: Dictionary = runtime.update_state(true, 1.0, 30.0, 5.0, 4.5, 1.0 / 60.0)
	_expect(not bool(expired.get("active", true)), "dash boost runtime should expire at zero timer")
	_expect(bool(expired.get("clear_particles", false)), "dash boost runtime should clear particles on expiry")

	var inactive: Dictionary = runtime.update_state(false, 99.0, 30.0, 3.0, 2.0, 1.0 / 30.0)
	_expect(not bool(inactive.get("active", true)), "inactive dash boost runtime should stay inactive")
	_expect(bool(inactive.get("update_fade_particles", false)), "inactive dash boost runtime should request particle fade update")

	_expect(is_equal_approx(runtime.get_cost_multiplier(true), 0.0), "active dash boost should report zero cost multiplier")
	_expect(is_equal_approx(runtime.get_cost_multiplier(false), 1.0), "inactive dash boost should report unit cost multiplier")
	_expect(is_equal_approx(runtime.get_cooldown_multiplier(true), 0.01), "active dash boost should report 1% cooldown multiplier")
	_expect(is_equal_approx(runtime.get_cooldown_multiplier(false), 1.0), "inactive dash boost should report unit cooldown multiplier")


func _verify_direct_runtime_update_application() -> void:
	seed(223)
	var runtime: Object = ActiveItemDashBoostRuntime.new()
	var state_applier: Object = ActiveItemEffectStateApplier.new()
	var particles_helper: Object = ActiveItemDashBoostParticles.new()
	var target := FakeTarget.new()

	target.dash_boost_active = true
	target.dash_boost_timer_frames = 30.0
	target.dash_boost_initial_timer_frames = 30.0
	target.dash_boost_particle_accumulator_frames = 4.5
	runtime.apply_update(
		target,
		target.dash_boost_particles,
		target.dash_boost_active,
		target.dash_boost_timer_frames,
		target.dash_boost_initial_timer_frames,
		target.dash_boost_glow_phase,
		target.dash_boost_particle_accumulator_frames,
		target.dash_boost_player_center,
		1.0 / 60.0,
		state_applier,
		particles_helper
	)
	_expect(target.dash_boost_active, "dash boost runtime should apply active update state")
	_expect(is_equal_approx(target.dash_boost_timer_frames, 29.0), "dash boost runtime should apply timer tick")
	_expect(is_equal_approx(target.dash_boost_glow_phase, 0.15), "dash boost runtime should apply glow tick")
	_expect(target.dash_boost_particles.size() >= 2, "dash boost runtime should advance idle particles")

	target.dash_boost_active = false
	target.dash_boost_particles.clear()
	target.dash_boost_particles.append({
		"position": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"alpha": 0.01,
	})
	runtime.apply_update(
		target,
		target.dash_boost_particles,
		target.dash_boost_active,
		target.dash_boost_timer_frames,
		target.dash_boost_initial_timer_frames,
		target.dash_boost_glow_phase,
		target.dash_boost_particle_accumulator_frames,
		target.dash_boost_player_center,
		1.0 / 30.0,
		state_applier,
		particles_helper
	)
	_expect(is_equal_approx(target.dash_boost_glow_phase, 0.0), "dash boost runtime should apply inactive glow reset")
	_expect(target.dash_boost_particles.is_empty(), "dash boost runtime should fade inactive particles")


func _verify_controller_delegates_runtime_state() -> void:
	seed(222)
	var controller: Object = ActiveItemEffectController.new()
	controller.dash_boost_particles.append({"alpha": 1.0})

	_expect(controller.activate_dash_boost(null, null), "controller should activate dash boost through runtime helper")
	_expect(controller.dash_boost_active, "controller should apply active dash boost state")
	_expect(is_equal_approx(controller.dash_boost_timer_frames, 480.0), "controller should apply helper duration")
	_expect(is_equal_approx(controller.dash_boost_glow_phase, 0.0), "controller should reset glow on activation")
	_expect(controller.dash_boost_particles.is_empty(), "controller should clear particles on activation")

	controller.dash_boost_timer_frames = 30.0
	controller.dash_boost_initial_timer_frames = 30.0
	controller.dash_boost_particle_accumulator_frames = 4.5
	controller.update(null, 1.0 / 60.0)
	_expect(controller.dash_boost_active, "controller should keep dash boost active while helper timer remains")
	_expect(is_equal_approx(controller.dash_boost_timer_frames, 29.0), "controller should apply helper timer tick")
	_expect(is_equal_approx(controller.dash_boost_glow_phase, 0.15), "controller should apply helper glow tick")

	controller.dash_boost_active = true
	controller.dash_boost_timer_frames = 1.0
	controller.dash_boost_initial_timer_frames = 30.0
	controller.update(null, 1.0 / 60.0)
	_expect(not controller.dash_boost_active, "controller should apply helper expiry")


func _verify_controller_multipliers_and_query() -> void:
	var controller: Object = ActiveItemEffectController.new()

	_expect(is_equal_approx(controller.get_dash_cost_multiplier(), 1.0), "inactive controller should report full dash cost")
	_expect(is_equal_approx(controller.get_dash_cooldown_multiplier(), 1.0), "inactive controller should report full dash cooldown")

	controller.activate_dash_boost(null, null)
	_expect(controller.is_dash_boost_active(), "controller is_dash_boost_active should reflect activation")
	_expect(is_equal_approx(controller.get_dash_cost_multiplier(), 0.0), "active controller should report zero dash cost")
	_expect(is_equal_approx(controller.get_dash_cooldown_multiplier(), 0.01), "active controller should report 1% dash cooldown")

	var ratio: float = controller.get_dash_boost_remaining_ratio()
	_expect(ratio >= 0.99, "remaining ratio should be ~1 right after activation")
	var time_left: float = controller.get_dash_boost_remaining_time()
	_expect(time_left >= 7.9 and time_left <= 8.05, "remaining time should be ~8 sec right after activation")


func _verify_particle_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_dash_boost_particles.gd")
	_expect(source.find("ActiveItemDashBoostParticlePayloadFactory.build_idle_particle") >= 0, "Dash Boost particles should delegate idle particle payloads")
	_expect(source.find("particles.append({") < 0, "Dash Boost particles should not inline particle dictionaries")

	var item_modules: Dictionary = GameplayItemModuleCatalog.MODULES
	_expect(item_modules.has("active_item_dash_boost_particles"), "item module catalog should list Dash Boost particles")
	_expect(item_modules.has("active_item_dash_boost_particle_payload_factory"), "item module catalog should list Dash Boost particle payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("active_item_dash_boost_particle_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/items/active_item_dash_boost_particle_payload_factory.gd", "top-level module catalog should resolve Dash Boost particle payload factory")


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
