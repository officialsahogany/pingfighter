extends SceneTree

const SoulCloneRenderer := preload("res://scripts/lingpet/lingpet_soul_clone_renderer.gd")
const SoulCloneSkill := preload("res://scripts/lingpet/lingpet_soul_clone_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var prewarm_calls := 0
	var payload: Array = []

	func prewarm() -> void:
		prewarm_calls += 1

	func draw_soul_clone(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		active: bool,
		elapsed: float,
		active_duration: float,
		visual_time_msec: float,
		clones: Array[Dictionary],
		particles: Array[Dictionary]
	) -> void:
		calls += 1
		payload = [shake_offset, active, elapsed, active_duration, visual_time_msec, clones, particles]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_visual_clock_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_soul_clone_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := SoulCloneSkill.new()
	var renderer := SpyRenderer.new()
	var clones: Array[Dictionary] = [{"pos": Vector2(320.0, 620.0)}]
	var particles: Array[Dictionary] = [{"pos": Vector2(300.0, 600.0)}]
	skill.set("_renderer", renderer)
	skill.set("_active", true)
	skill.set("_elapsed", 1.25)
	skill.set("_active_duration", 17.0)
	skill.set("_clones", clones)
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.prewarm()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.prewarm_calls == 1, "prewarm should delegate clone texture preparation")
	_expect(renderer.calls == 1, "facade should delegate Soul Clone composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(bool(renderer.payload[1]), "facade should forward active state")
	_expect(is_equal_approx(float(renderer.payload[2]), 1.25), "renderer should receive elapsed active time")
	_expect(is_equal_approx(float(renderer.payload[3]), 17.0), "renderer should receive the active duration")
	_expect(float(renderer.payload[4]) >= 0.0, "facade should sample one non-negative visual clock value")
	_expect(renderer.payload[5] == clones, "renderer should borrow the live clone array")
	_expect(renderer.payload[6] == particles, "renderer should borrow the live particle array")


func _verify_visual_clock_projection() -> void:
	var renderer := SoulCloneRenderer.new()
	var first: Dictionary = renderer.get_clone_visual_phase_for_tests(1000.0, 0.35)
	var repeated: Dictionary = renderer.get_clone_visual_phase_for_tests(1000.0, 0.35)
	_expect(first == repeated, "fixed runtime payload should repeat Soul Clone visual phase")
	_expect(float(first.get("pulse", -1.0)) >= 0.0 and float(first.get("pulse", 2.0)) <= 1.0, "pulse should stay normalized")
	_expect(absf(float(first.get("bob_offset", 99.0))) <= 2.4, "clone bob should retain the 2.4px envelope")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_soul_clone_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_soul_clone_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_soul_clone")
	_expect(skill_source.contains("LingpetSoulCloneRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetSoulCloneRenderer.new()"), "skill should retain one renderer")
	_expect(skill_source.contains("_renderer.prewarm()"), "skill prewarm should delegate render resources")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _advance_clone_runtime("), "gameplay owner should retain clone timing")
	_expect(skill_source.contains("func _update_motion("), "gameplay owner should retain target motion and RNG")
	_expect(skill_source.contains("func _resolve_ball_hit("), "gameplay owner should retain collision and reflection")
	_expect(skill_source.contains("func _update_particles("), "gameplay owner should retain particle simulation")
	_expect(skill_source.contains("func _spawn_burst("), "gameplay owner should retain particle payload generation")
	for method_name in [
		"_draw_particles",
		"_draw_clone_aura",
		"_draw_clone_sprite",
		"_draw_region",
		"_draw_flipped_texture_region",
		"_draw_procedural_fallback",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(not skill_source.contains("ProjectResourceLoader"), "gameplay owner should not retain clone texture loading")
	_expect(renderer_source.contains("ProjectResourceLoader.load_imported_texture"), "renderer should own clone texture loading")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should receive a sampled clock instead of reading wall time")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _clones"), "renderer should not retain the borrowed clone array")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particle array")
	var particle_pass := renderer_draw.find("_draw_particles")
	var inactive_guard := renderer_draw.find("if not active")
	var clone_pass := renderer_draw.find("for clone_value in clones")
	_expect(renderer_draw.count("_draw_particles(") == 1, "renderer should compose the particle pass exactly once")
	_expect(particle_pass >= 0 and particle_pass < inactive_guard, "particles should render before the inactive early return")
	_expect(inactive_guard < clone_pass, "renderer should preserve particles -> clones order")
	_expect(skill_source.split("\n").size() < 450, "renderer split should materially shrink the mixed gameplay owner")


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
