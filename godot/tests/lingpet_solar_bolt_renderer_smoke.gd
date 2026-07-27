extends SceneTree

const SolarBoltRenderer := preload("res://scripts/lingpet/lingpet_solar_bolt_renderer.gd")
const SolarBoltSkill := preload("res://scripts/lingpet/lingpet_solar_bolt_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_solar_bolt(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		runtime_elapsed: float,
		effects: Array[Dictionary],
		particles: Array[Dictionary],
		field_size: Vector2,
		lightning_seconds: float,
		explosion_seconds: float,
		spark_seconds: float,
		screen_flash_alpha: float
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			runtime_elapsed,
			effects,
			particles,
			field_size,
			lightning_seconds,
			explosion_seconds,
			spark_seconds,
			screen_flash_alpha,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_runtime_clocked_flicker()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_solar_bolt_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := SolarBoltSkill.new()
	var renderer := SpyRenderer.new()
	var effects: Array[Dictionary] = [{"seed": 41.25, "lightning": 0.16}]
	var particles: Array[Dictionary] = [{"type": "dot", "life": 0.3}]
	skill.set("_renderer", renderer)
	skill.set("_elapsed", 0.125)
	skill.set("_effects", effects)
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Solar Bolt composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(is_equal_approx(float(renderer.payload[1]), 0.125), "renderer should receive the runtime elapsed clock")
	_expect(renderer.payload[2] == effects, "renderer should borrow the live effect array")
	_expect(renderer.payload[3] == particles, "renderer should borrow the live particle array")
	_expect(renderer.payload[4] == Vector2(760.0, 750.0), "renderer should receive the playfield size")
	_expect(is_equal_approx(float(renderer.payload[5]), 0.20), "renderer should receive the lightning lifetime")
	_expect(is_equal_approx(float(renderer.payload[6]), 0.38), "renderer should receive the explosion lifetime")
	_expect(is_equal_approx(float(renderer.payload[8]), 0.16), "renderer should receive the screen-flash alpha")


func _verify_runtime_clocked_flicker() -> void:
	var renderer := SolarBoltRenderer.new()
	var first := renderer.is_bolt_visible_for_tests(0.0, 41.25)
	var repeated := renderer.is_bolt_visible_for_tests(0.0, 41.25)
	var hidden_frame := renderer.is_bolt_visible_for_tests(3.0 / 60.0, 41.25)
	_expect(first and repeated, "fixture should keep the bolt visible on its first runtime frame")
	_expect(first == repeated, "same runtime state should repeat the bolt visibility decision")
	_expect(not hidden_frame, "runtime time should still drive the original intermittent flicker")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_solar_bolt_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_solar_bolt_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_solar_bolt")
	_expect(skill_source.contains("LingpetSolarBoltRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetSolarBoltRenderer.new()"), "skill should retain one renderer")
	_expect(skill_draw.contains("_elapsed"), "facade should forward its runtime clock")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains("randf") and not skill_draw.contains("randi"), "facade should consume no RNG")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _strike_ball("), "gameplay owner should retain ball reflection and retargeting")
	_expect(skill_source.contains("func _update_effects("), "gameplay owner should retain effect lifecycle clocks")
	_expect(skill_source.contains("func _gen_lightning("), "gameplay owner should retain one-shot lightning-path generation")
	_expect(skill_source.contains("randf_range(-disp, disp)"), "gameplay owner should retain strike-time path RNG")
	for method_name in [
		"_draw_screen_flash",
		"_draw_effect",
		"_draw_explosion",
		"_shift_points",
		"_draw_particles",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _effects"), "renderer should not retain the borrowed effect array")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particle array")
	var flash_pass := renderer_draw.find("_draw_screen_flash")
	var effect_pass := renderer_draw.find("for effect in effects")
	var particle_pass := renderer_draw.find("_draw_particles")
	_expect(flash_pass >= 0 and flash_pass < effect_pass, "renderer should preserve screen-flash -> effect order")
	_expect(effect_pass < particle_pass, "renderer should preserve effect -> particle order")
	_expect(skill_source.split("\n").size() < 630, "renderer split should materially shrink the mixed gameplay owner")


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
