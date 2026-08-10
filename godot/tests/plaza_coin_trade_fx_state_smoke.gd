extends SceneTree

const PlazaCoinTradeFxState := preload("res://scripts/plaza/plaza_coin_trade_fx_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaCoinTradeFxState.new()
	_verify_particle_material(state)
	_verify_particle_projection(state)
	_verify_animation_gate(state)
	_verify_aura_projection(state)
	_verify_reset(state)
	if _failures.is_empty():
		print("plaza_coin_trade_fx_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_particle_material(state: PlazaCoinTradeFxState) -> void:
	var material := state.build_particle_process_material()
	_expect(material.direction == Vector3(0.0, -1.0, 0.0), "particle direction")
	_expect(is_equal_approx(material.spread, 42.0), "particle spread")
	_expect(material.gravity == Vector3(0.0, -42.0, 0.0), "particle gravity")
	_expect(material.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX, "particle emission shape")
	_expect(material.emission_box_extents == Vector3(42.0, 14.0, 0.0), "particle base emission extents")


func _verify_particle_projection(state: PlazaCoinTradeFxState) -> void:
	var rect := Rect2(Vector2(475.0, 430.0), Vector2(86.0, 50.0))
	var idle := state.build_particle_snapshot(rect, 1.0, 0.0, 0.0)
	_expect(not bool(idle.get("visible", true)), "idle particle snapshot should be hidden")
	state.seed_burst()
	_expect(is_equal_approx(state.burst_value, PlazaCoinTradeFxState.BURST_SEED), "burst seed")
	var snapshot := state.build_particle_snapshot(rect, 2.0, 0.5, 0.25)
	_expect(bool(snapshot.get("visible", false)), "energized particle snapshot should be visible")
	_expect(is_equal_approx(float(snapshot.get("intensity", 0.0)), 0.86), "particle intensity formula")
	_expect(snapshot.get("position", Vector2.ZERO) == Vector2(1036.0, 900.0), "particle scaled position")
	_expect(snapshot.get("visibility_rect", Rect2()) == Rect2(-300.0, -236.0, 600.0, 440.0), "particle visibility rect")
	_expect(is_equal_approx(float(snapshot.get("initial_velocity_min", 0.0)), 15.4), "particle burst velocity minimum")
	_expect(is_equal_approx(float(snapshot.get("initial_velocity_max", 0.0)), 63.2), "particle burst velocity maximum")


func _verify_animation_gate(state: PlazaCoinTradeFxState) -> void:
	_expect(not state.is_animating("bank", false, true, true, true, 1.0), "non-shop should gate FX")
	_expect(not state.is_animating("shop", true, true, true, true, 1.0), "trade modal should gate FX")
	_expect(state.is_animating("shop", false, false, false, false, 0.0), "active burst should animate even before spec lookup")
	state.burst_value = 0.0
	_expect(not state.is_animating("shop", false, false, true, true, 1.0), "missing spec should gate hover/flare")
	_expect(state.is_animating("shop", false, true, true, false, 0.0), "hover should animate")
	_expect(state.is_animating("shop", false, true, false, true, 0.2), "clicked flare should animate")
	_expect(not state.is_animating("shop", false, true, false, true, 0.0), "expired flare should stop")


func _verify_aura_projection(state: PlazaCoinTradeFxState) -> void:
	var rect := Rect2(Vector2(475.0, 430.0), Vector2(86.0, 50.0))
	_expect(state.build_aura_snapshot(rect, 1.0, 0.0, 0.0).is_empty(), "idle aura should have no draw snapshot")
	state.pulse_value = 0.5
	state.burst_value = 0.35
	var snapshot := state.build_aura_snapshot(rect, 1.0, 0.5, 0.25)
	_expect(not snapshot.is_empty(), "energized aura should project draw layers")
	_expect(float(snapshot.get("energy", 0.0)) > 0.89, "aura energy formula")
	_expect(bool(snapshot.get("burst_visible", false)), "burst state should project burst layers")
	_expect(snapshot.get("backplate_rect", Rect2()).size.x > snapshot.get("ring_rect", Rect2()).size.x, "backplate should remain wider than ring")
	_expect(float(snapshot.get("burst_ring_intensity", 0.0)) > 1.0, "burst ring intensity")


func _verify_reset(state: PlazaCoinTradeFxState) -> void:
	state.pulse_value = 0.75
	state.burst_value = 0.80
	state.reset()
	_expect(is_zero_approx(state.pulse_value), "reset should clear pulse state")
	_expect(is_zero_approx(state.burst_value), "reset should clear burst state")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
