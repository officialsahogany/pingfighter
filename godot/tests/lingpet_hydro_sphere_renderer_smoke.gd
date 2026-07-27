extends SceneTree

const HydroSphereRenderer := preload("res://scripts/lingpet/lingpet_hydro_sphere_renderer.gd")
const HydroSphereSkill := preload("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var prewarm_calls := 0
	var payload: Array = []

	func prewarm() -> void:
		prewarm_calls += 1

	func draw_hydro_sphere(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		visual_time_seconds: float,
		projectile_active: bool,
		projectile_pos: Vector2,
		projectile_vel: Vector2,
		projectile_radius: float,
		trail: Array[Vector2],
		puddle_pos: Vector2,
		puddle_timer: float,
		puddle_duration: float,
		puddle_seed: int,
		puddle_half_width: float,
		puddle_half_height: float,
		puddle_drop_y: float,
		splash_timer: float,
		splash_duration: float,
		particles: Array
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			visual_time_seconds,
			projectile_active,
			projectile_pos,
			projectile_vel,
			projectile_radius,
			trail,
			puddle_pos,
			puddle_timer,
			puddle_duration,
			puddle_seed,
			puddle_half_width,
			puddle_half_height,
			puddle_drop_y,
			splash_timer,
			splash_duration,
			particles,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_safe_deterministic_puddle_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_hydro_sphere_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := HydroSphereSkill.new()
	var renderer := SpyRenderer.new()
	var trail: Array[Vector2] = [Vector2(380.0, 500.0), Vector2(380.0, 450.0)]
	var particles: Array = [{"pos": Vector2(372.0, 70.0), "kind": 0}]
	skill.set("_renderer", renderer)
	skill.set("_projectile_active", true)
	skill.set("_projectile_pos", Vector2(380.0, 420.0))
	skill.set("_projectile_vel", Vector2(0.0, -560.0))
	skill.set("_trail", trail)
	skill.set("_puddle_pos", Vector2(400.0, 74.0))
	skill.set("_puddle_timer", 4.2)
	skill.set("_puddle_seed", 17)
	skill.set("_puddle_half_width", 154.56)
	skill.set("_splash_timer", 0.21)
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.prewarm()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.prewarm_calls == 1, "prewarm should delegate renderer preparation")
	_expect(renderer.calls == 1, "facade should delegate Hydro Sphere composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(float(renderer.payload[1]) >= 0.0, "facade should sample one non-negative visual clock value")
	_expect(bool(renderer.payload[2]) and renderer.payload[3] == Vector2(380.0, 420.0), "facade should forward projectile state")
	_expect(renderer.payload[4] == Vector2(0.0, -560.0), "facade should forward projectile velocity")
	_expect(is_equal_approx(float(renderer.payload[5]), 8.0), "renderer should receive the gameplay projectile radius")
	_expect(renderer.payload[6] == trail, "renderer should borrow the live typed trail")
	_expect(renderer.payload[7] == Vector2(400.0, 74.0), "facade should forward puddle position")
	_expect(is_equal_approx(float(renderer.payload[8]), 4.2) and is_equal_approx(float(renderer.payload[9]), 5.0), "renderer should receive puddle timing")
	_expect(int(renderer.payload[10]) == 17, "renderer should receive the deterministic puddle seed")
	_expect(is_equal_approx(float(renderer.payload[11]), 154.56) and is_equal_approx(float(renderer.payload[12]), 33.6), "renderer should receive collision-aligned puddle size")
	_expect(is_equal_approx(float(renderer.payload[13]), 62.0), "renderer should receive impact-to-puddle drop")
	_expect(is_equal_approx(float(renderer.payload[14]), 0.21) and is_equal_approx(float(renderer.payload[15]), 0.48), "renderer should receive splash timing")
	_expect(renderer.payload[16] == particles, "renderer should borrow the live particle array")


func _verify_safe_deterministic_puddle_projection() -> void:
	var renderer := HydroSphereRenderer.new()
	var first: Vector4 = renderer.get_puddle_projection_for_tests(12.25, 4.82, 5.0, 134.4, 33.6)
	var repeated: Vector4 = renderer.get_puddle_projection_for_tests(12.25, 4.82, 5.0, 134.4, 33.6)
	_expect(first == repeated, "fixed puddle payload should repeat exactly")
	_expect(first != Vector4.ZERO, "visible puddle state should produce a projection")
	_expect(first.x > 134.4 * 0.7, "appearing puddle should retain a positive horizontal radius")
	_expect(first.y > 33.6 * 0.7, "appearing puddle should retain a positive vertical radius")
	_expect(first.z > 0.0, "visible puddle should retain alpha")
	_expect(renderer.get_puddle_projection_for_tests(1.0, 1.0, 0.0, 134.4, 33.6) == Vector4.ZERO, "invalid duration should be rejected")
	_expect(renderer.get_puddle_projection_for_tests(1.0, 1.0, 5.0, 0.0, 33.6) == Vector4.ZERO, "degenerate puddle radii should be rejected")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_hydro_sphere_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_hydro_sphere")
	_expect(skill_source.contains("LingpetHydroSphereRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetHydroSphereRenderer.new()"), "skill should retain one renderer")
	_expect(skill_source.contains("_renderer.prewarm()"), "skill prewarm should delegate render resources")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _spawn_puddle("), "gameplay owner should retain impact-to-puddle lifecycle")
	_expect(skill_source.contains("func _update_particles("), "gameplay owner should retain particle spawning and simulation")
	_expect(skill_source.contains("func _apply_boss_slow("), "gameplay owner should retain status application")
	_expect(skill_source.contains("func _is_boss_touching_puddle("), "gameplay owner should retain collision ellipse")
	_expect(skill_source.contains("func _get_wall_y("), "gameplay owner should retain opponent-wall routing")
	for method_name in [
		"_draw_projectile",
		"_draw_puddle",
		"_draw_splash",
		"_draw_particles",
		"_blit_hydro",
		"_blit_hydro_caustic",
		"_ease_out_back",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("HydroPuddleTextureCache"), "renderer should own Hydro Sphere texture preparation")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should receive a sampled clock instead of reading wall time")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _trail"), "renderer should not retain the borrowed trail")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particles")
	var puddle_pass := renderer_draw.find("if puddle_timer > 0.0")
	var particle_pass := renderer_draw.find("if not particles.is_empty()")
	var splash_pass := renderer_draw.find("if splash_timer > 0.0")
	var projectile_pass := renderer_draw.find("if projectile_active")
	_expect(puddle_pass >= 0 and puddle_pass < particle_pass, "renderer should preserve puddle -> particles order")
	_expect(particle_pass < splash_pass and splash_pass < projectile_pass, "renderer should preserve particles -> splash -> projectile order")
	_expect(renderer_draw.count("_draw_puddle(") == 1, "renderer should compose the puddle exactly once")
	_expect(renderer_draw.count("_draw_particles(") == 1, "renderer should compose particles exactly once")
	_expect(renderer_draw.count("_draw_splash(") == 1, "renderer should compose the splash exactly once")
	_expect(renderer_draw.count("_draw_projectile(") == 1, "renderer should compose the projectile exactly once")
	_expect(skill_source.split("\n").size() < 315, "renderer split should materially shrink the mixed gameplay owner")


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
