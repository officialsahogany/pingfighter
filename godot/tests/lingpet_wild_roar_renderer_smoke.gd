extends SceneTree

const WildRoarRenderer := preload("res://scripts/lingpet/lingpet_wild_roar_renderer.gd")
const WildRoarSkill := preload("res://scripts/lingpet/lingpet_wild_roar_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var prewarm_calls := 0
	var payload: Array = []

	func prewarm() -> void:
		prewarm_calls += 1

	func draw_wild_roar(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		field_size: Vector2,
		vfx_timer: float,
		vfx_duration: float,
		origin: Vector2,
		roar_radius: float,
		screen_flash_state_alpha: float,
		screen_flash_draw_alpha_cap: float,
		particles: Array[Dictionary],
		last_reflected: bool,
		last_ball_pos: Vector2,
		last_reflect_dir: Vector2,
		particle_life_seconds: float
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			field_size,
			vfx_timer,
			vfx_duration,
			origin,
			roar_radius,
			screen_flash_state_alpha,
			screen_flash_draw_alpha_cap,
			particles,
			last_reflected,
			last_ball_pos,
			last_reflect_dir,
			particle_life_seconds,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_particles()
	_verify_deterministic_delayed_ring_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_wild_roar_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_particles() -> void:
	var skill := WildRoarSkill.new()
	var renderer := SpyRenderer.new()
	var particles: Array[Dictionary] = [{"position": Vector2(360.0, 560.0)}]
	skill.set("_renderer", renderer)
	skill.set("_vfx_timer", 1.2)
	skill.set("_origin", Vector2(380.0, 620.0))
	skill.set("_roar_radius", 216.0)
	skill.set("_particles", particles)
	skill.set("_last_reflected", true)
	skill.set("_last_ball_pos", Vector2(420.0, 540.0))
	skill.set("_last_reflect_dir", Vector2(0.6, -0.8))
	var canvas := Node2D.new()
	skill.prewarm()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.prewarm_calls == 1, "prewarm should delegate renderer preparation")
	_expect(renderer.calls == 1, "facade should delegate Wild Roar composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(renderer.payload[1] == Vector2(760.0, 750.0), "renderer should receive the full game-canvas size")
	_expect(is_equal_approx(float(renderer.payload[2]), 1.2) and is_equal_approx(float(renderer.payload[3]), 1.8), "renderer should receive VFX timing")
	_expect(renderer.payload[4] == Vector2(380.0, 620.0), "renderer should receive roar origin")
	_expect(is_equal_approx(float(renderer.payload[5]), 216.0), "renderer should receive level-scaled gameplay radius")
	_expect(is_equal_approx(float(renderer.payload[6]), 200.0 / 255.0), "renderer should receive screen-flash state alpha")
	_expect(is_equal_approx(float(renderer.payload[7]), 120.0 / 255.0), "renderer should receive screen-flash draw cap")
	_expect(renderer.payload[8] == particles, "renderer should borrow the live particle array")
	_expect(bool(renderer.payload[9]) and renderer.payload[10] == Vector2(420.0, 540.0), "facade should forward reflected-ball presentation state")
	_expect(renderer.payload[11] == Vector2(0.6, -0.8), "facade should forward the reflected direction")
	_expect(is_equal_approx(float(renderer.payload[12]), 0.66), "renderer should receive the particle fallback lifetime")


func _verify_deterministic_delayed_ring_projection() -> void:
	var renderer := WildRoarRenderer.new()
	var first: Dictionary = renderer.get_ring_projection_for_tests(0.22, 216.0, 2)
	var repeated: Dictionary = renderer.get_ring_projection_for_tests(0.22, 216.0, 2)
	_expect(first == repeated, "fixed ring payload should repeat exactly")
	_expect(not first.is_empty(), "elapsed time should activate the delayed third ring")
	_expect(float(first.get("radius", 0.0)) > 216.0 * 0.16, "active ring should expand beyond its initial radius")
	_expect(float(first.get("alpha", 0.0)) > 0.0, "active ring should retain visible alpha")
	_expect(bool(first.get("secondary", false)), "even ring should retain the cyan secondary arc")
	_expect(renderer.get_ring_projection_for_tests(0.10, 216.0, 3).is_empty(), "ring should stay hidden before its delay")
	_expect(renderer.get_ring_projection_for_tests(1.0, 216.0, 0).is_empty(), "ring should disappear after its lifetime")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_wild_roar_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_wild_roar_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_wild_roar")
	_expect(skill_source.contains("LingpetWildRoarRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetWildRoarRenderer.new()"), "skill should retain one renderer")
	_expect(skill_source.contains("_renderer.prewarm()"), "skill prewarm should delegate render resources")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy the live particle array")
	_expect(skill_source.contains("func can_arm("), "gameplay owner should retain proximity arm policy")
	_expect(skill_source.contains("func _try_reflect_ball("), "gameplay owner should retain reflection and boost")
	_expect(skill_source.contains("func _spawn_roar_sparks("), "gameplay owner should retain spark RNG")
	_expect(skill_source.contains("func _spawn_impact_particles("), "gameplay owner should retain impact RNG")
	_expect(skill_source.contains("func _update_particles("), "gameplay owner should retain particle simulation")
	_expect(skill_source.contains("func _consume_trigger_distance_roll("), "gameplay owner should retain arm-distance RNG")
	_expect(skill_source.contains("func _consume_jitter_radians("), "gameplay owner should retain reflection-jitter RNG")
	_expect(skill_source.contains("randf_range"), "gameplay owner should still consume all runtime random rolls")
	for method_name in ["_draw_screen_flash", "_draw_roar_zone", "_draw_particles", "_draw_ball_glow"]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particle array")
	var flash_pass := renderer_draw.find("_draw_screen_flash")
	var zone_pass := renderer_draw.find("_draw_roar_zone")
	var particle_pass := renderer_draw.find("_draw_particles")
	var glow_pass := renderer_draw.find("if last_reflected")
	_expect(flash_pass >= 0 and flash_pass < zone_pass, "renderer should preserve flash -> zone order")
	_expect(zone_pass < particle_pass and particle_pass < glow_pass, "renderer should preserve zone -> particles -> ball glow order")
	_expect(renderer_draw.count("_draw_particles(") == 1, "renderer should compose particles exactly once")
	_expect(skill_source.split("\n").size() < 500, "renderer split should materially shrink the mixed gameplay owner")


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
