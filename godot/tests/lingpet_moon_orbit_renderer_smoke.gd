extends SceneTree

const MoonOrbitRenderer := preload("res://scripts/lingpet/lingpet_moon_orbit_renderer.gd")
const MoonOrbitSkill := preload("res://scripts/lingpet/lingpet_moon_orbit_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var prewarm_calls := 0
	var payload: Array = []

	func prewarm() -> void:
		prewarm_calls += 1

	func draw_moon_orbit(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		visual_time_seconds: float,
		projectile_active: bool,
		projectile_pos: Vector2,
		projectile_vel: Vector2,
		projectile_radius: float,
		trail: Array[Vector2],
		orbit_active: bool,
		orbit_pos: Vector2,
		orbit_timer: float,
		orbit_duration: float,
		orbit_seed: int,
		orbit_half_width: float,
		orbit_half_height: float,
		orbit_drop_y: float,
		burst_timer: float,
		burst_duration: float,
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
			orbit_active,
			orbit_pos,
			orbit_timer,
			orbit_duration,
			orbit_seed,
			orbit_half_width,
			orbit_half_height,
			orbit_drop_y,
			burst_timer,
			burst_duration,
			particles,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_safe_deterministic_ellipse_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_moon_orbit_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := MoonOrbitSkill.new()
	var renderer := SpyRenderer.new()
	var trail: Array[Vector2] = [Vector2(380.0, 500.0), Vector2(380.0, 450.0)]
	var particles: Array = [{"pos": Vector2(360.0, 80.0), "kind": 0}]
	skill.set("_renderer", renderer)
	skill.set("_projectile_active", true)
	skill.set("_projectile_pos", Vector2(380.0, 420.0))
	skill.set("_projectile_vel", Vector2(0.0, -620.0))
	skill.set("_trail", trail)
	skill.set("_orbit_pos", Vector2(400.0, 62.0))
	skill.set("_orbit_timer", 2.0)
	skill.set("_orbit_seed", 17)
	skill.set("_burst_timer", 0.21)
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.prewarm()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.prewarm_calls == 1, "prewarm should delegate renderer preparation")
	_expect(renderer.calls == 1, "facade should delegate Moon Orbit composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(float(renderer.payload[1]) >= 0.0, "facade should sample one non-negative visual clock value")
	_expect(bool(renderer.payload[2]) and renderer.payload[3] == Vector2(380.0, 420.0), "facade should forward projectile state")
	_expect(renderer.payload[4] == Vector2(0.0, -620.0), "facade should forward projectile velocity")
	_expect(is_equal_approx(float(renderer.payload[5]), 9.0), "renderer should receive the gameplay projectile radius")
	_expect(renderer.payload[6] == trail, "renderer should borrow the live typed trail")
	_expect(bool(renderer.payload[7]) and renderer.payload[8] == Vector2(400.0, 62.0), "facade should forward orbit field state")
	_expect(is_equal_approx(float(renderer.payload[9]), 2.0) and is_equal_approx(float(renderer.payload[10]), 4.0), "renderer should receive orbit timing")
	_expect(int(renderer.payload[11]) == 17, "renderer should receive deterministic orbit seed")
	_expect(is_equal_approx(float(renderer.payload[12]), 220.0) and is_equal_approx(float(renderer.payload[13]), 54.0), "renderer should receive collision-aligned ellipse size")
	_expect(is_equal_approx(float(renderer.payload[14]), 50.0), "renderer should receive impact-to-field drop")
	_expect(is_equal_approx(float(renderer.payload[15]), 0.21) and is_equal_approx(float(renderer.payload[16]), 0.42), "renderer should receive burst timing")
	_expect(renderer.payload[17] == particles, "renderer should borrow the live particle array")


func _verify_safe_deterministic_ellipse_projection() -> void:
	var renderer := MoonOrbitRenderer.new()
	var first: PackedVector2Array = renderer.get_ellipse_points_for_tests(Vector2(20.0, 30.0), 12.0, 5.0, 8, true)
	var repeated: PackedVector2Array = renderer.get_ellipse_points_for_tests(Vector2(20.0, 30.0), 12.0, 5.0, 8, true)
	_expect(first == repeated, "fixed ellipse payload should repeat exactly")
	_expect(first.size() == 9, "closed eight-segment ellipse should include its closing vertex")
	_expect(first[0] == first[first.size() - 1], "closed ellipse should repeat only the boundary endpoint")
	var unique := {}
	for index in range(first.size() - 1):
		unique[first[index]] = true
	_expect(unique.size() == 8, "ellipse projection should not collapse distinct boundary points")
	_expect(renderer.get_ellipse_points_for_tests(Vector2.ZERO, 0.0, 5.0, 8, true).is_empty(), "degenerate ellipse should be rejected before CanvasItem drawing")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_moon_orbit_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_moon_orbit_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_moon_orbit")
	_expect(skill_source.contains("LingpetMoonOrbitRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetMoonOrbitRenderer.new()"), "skill should retain one renderer")
	_expect(skill_source.contains("_renderer.prewarm()"), "skill prewarm should delegate render resources")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _spawn_orbit_field("), "gameplay owner should retain impact-to-field lifecycle")
	_expect(skill_source.contains("func _update_particles("), "gameplay owner should retain particle spawning and simulation")
	_expect(skill_source.contains("func _apply_boss_slow("), "gameplay owner should retain status application")
	_expect(skill_source.contains("func _is_boss_touching_orbit("), "gameplay owner should retain collision ellipse")
	_expect(skill_source.contains("func _get_wall_y("), "gameplay owner should retain opponent-wall routing")
	for method_name in [
		"_draw_projectile",
		"_draw_orbit_field",
		"_draw_burst",
		"_draw_particles",
		"_draw_ellipse_fill",
		"_draw_ellipse_outline",
		"_draw_crescent_arc",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should receive a sampled clock instead of reading wall time")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _trail"), "renderer should not retain the borrowed trail")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particles")
	var orbit_pass := renderer_draw.find("if orbit_active")
	var particle_pass := renderer_draw.find("_draw_particles")
	var burst_pass := renderer_draw.find("if burst_timer > 0.0")
	var projectile_pass := renderer_draw.find("if projectile_active")
	_expect(orbit_pass >= 0 and orbit_pass < particle_pass, "renderer should preserve orbit -> particles order")
	_expect(particle_pass < burst_pass and burst_pass < projectile_pass, "renderer should preserve particles -> burst -> projectile order")
	_expect(renderer_draw.count("_draw_particles(") == 1, "renderer should compose particles exactly once")
	_expect(skill_source.split("\n").size() < 300, "renderer split should materially shrink the mixed gameplay owner")


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
