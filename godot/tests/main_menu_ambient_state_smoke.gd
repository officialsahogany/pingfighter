extends SceneTree

const MainMenuAmbient := preload("res://scripts/ui/main_menu_ambient.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ambient := MainMenuAmbient.new()
	ambient.size = Vector2(760.0, 426.0)
	get_root().add_child(ambient)
	await process_frame
	var ready_fingerprint := _fingerprint(ambient)
	ambient.set_intro_reveal_active(false)
	ambient.set_process(false)
	var active_fingerprint := _fingerprint(ambient)
	ambient._process(0.25)
	ambient.set_process(false)
	var tick_fingerprint := _fingerprint(ambient)
	_expect_fingerprint(ready_fingerprint, {
		"elapsed": 0.0,
		"next": 21.637848,
		"particle_x": 468.005829,
		"particle_y": 121.174187,
		"particle_age": 0.231017,
		"particle_lifetime": 12.689487,
		"light_x": 0.291958,
		"light_period": 3.318816,
		"silhouettes": 0,
	}, "ready state should preserve the seeded particle-light-schedule RNG order")
	_expect_fingerprint(active_fingerprint, {
		"elapsed": 0.55,
		"next": 19.051919,
		"particle_x": 413.549408,
		"particle_y": 159.945831,
		"particle_age": 7.335445,
		"particle_lifetime": 14.483595,
		"light_x": 0.291958,
		"light_period": 3.318816,
		"silhouettes": 0,
	}, "reveal activation should preserve reseed/schedule RNG order")
	_expect_fingerprint(tick_fingerprint, {
		"elapsed": 0.8,
		"next": 19.051919,
		"particle_x": 412.882311,
		"particle_y": 155.605558,
		"particle_age": 7.585445,
		"particle_lifetime": 14.483595,
		"light_x": 0.291958,
		"light_period": 3.318816,
		"silhouettes": 0,
	}, "250ms tick should preserve deterministic particle integration")
	_expect(ambient.particles.size() == MainMenuAmbient.PARTICLE_COUNT, "ambient state should preserve particle count")
	_expect(ambient.sky_lights.size() == MainMenuAmbient.SKY_LIGHT_COUNT, "ambient state should preserve sky-light count")
	_verify_source_contract()
	ambient.queue_free()
	await process_frame
	_finish()


func _fingerprint(ambient: MainMenuAmbient) -> Dictionary:
	var particle: Dictionary = ambient.particles[0] if not ambient.particles.is_empty() else {}
	var light: Dictionary = ambient.sky_lights[0] if not ambient.sky_lights.is_empty() else {}
	return {
		"elapsed": snappedf(ambient.elapsed_time, 0.000001),
		"next": snappedf(ambient.next_silhouette_spawn_time, 0.000001),
		"particle_x": snappedf(float(particle.get("x", 0.0)), 0.000001),
		"particle_y": snappedf(float(particle.get("y", 0.0)), 0.000001),
		"particle_age": snappedf(float(particle.get("age", 0.0)), 0.000001),
		"particle_lifetime": snappedf(float(particle.get("lifetime", 0.0)), 0.000001),
		"light_x": snappedf(float(light.get("x_rel", 0.0)), 0.000001),
		"light_period": snappedf(float(light.get("blink_period", 0.0)), 0.000001),
		"silhouettes": ambient.silhouettes.size(),
	}


func _verify_source_contract() -> void:
	var ambient_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_ambient.gd")
	var state_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_ambient_state.gd")
	_expect(ambient_source.find("var _ambient_state: MainMenuAmbientState") >= 0, "ambient should keep one typed simulation-state owner")
	_expect(_function_body(ambient_source, "func _seed_particles(").find("_ambient_state.seed_particles") >= 0, "particle seed facade should delegate")
	_expect(_function_body(ambient_source, "func _update_particles(").find("_ambient_state.update_particles") >= 0, "particle update facade should delegate")
	_expect(_function_body(ambient_source, "func _seed_sky_lights(").find("_ambient_state.seed_sky_lights") >= 0, "sky-light seed facade should delegate")
	_expect(_function_body(ambient_source, "func _update_silhouettes(").find("_ambient_state.update_silhouettes") >= 0, "silhouette update facade should delegate")
	_expect(state_source.find("CanvasItem") < 0 and state_source.find("FileAccess") < 0 and state_source.find("Image") < 0, "ambient state should remain draw-, I/O-, and image-free")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect_fingerprint(actual: Dictionary, expected: Dictionary, message: String) -> void:
	for key in expected:
		if key == "silhouettes":
			if int(actual.get(key, -1)) != int(expected[key]):
				_failures.append("%s: %s" % [message, key])
			return
		if not is_equal_approx(float(actual.get(key, -999.0)), float(expected[key])):
			_failures.append("%s: %s" % [message, key])
			return


func _finish() -> void:
	if _failures.is_empty():
		print("main_menu_ambient_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
