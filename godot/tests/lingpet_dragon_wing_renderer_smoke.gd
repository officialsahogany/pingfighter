extends SceneTree

const DragonWingRenderer := preload("res://scripts/lingpet/lingpet_dragon_wing_renderer.gd")
const DragonWingSkill := preload("res://scripts/lingpet/lingpet_dragon_wing_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_dragon_wing(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		swirl_active: bool,
		runtime_elapsed: float,
		swirl_envelope: float,
		swirl_center: Vector2,
		swirl_spin_sign: float,
		last_ball_pos: Vector2,
		wind_direction: float,
		wind_particles: Array[Dictionary],
		ball_swirl_trail: Array[Dictionary],
		swirl_trail_life_seconds: float,
		dragon_trail: Array[Dictionary],
		dragon_trail_life_seconds: float,
		flying_dragon: Dictionary,
		hit_flash_timer: float,
		hit_flash_seconds: float,
		last_hit_pos: Vector2,
		last_hit_dir: Vector2
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			swirl_active,
			runtime_elapsed,
			swirl_envelope,
			swirl_center,
			swirl_spin_sign,
			last_ball_pos,
			wind_direction,
			wind_particles,
			ball_swirl_trail,
			swirl_trail_life_seconds,
			dragon_trail,
			dragon_trail_life_seconds,
			flying_dragon,
			hit_flash_timer,
			hit_flash_seconds,
			last_hit_pos,
			last_hit_dir,
		]


func _init() -> void:
	_verify_facade_payloads_and_runtime_clock()
	_verify_runtime_clocked_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_dragon_wing_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_runtime_clock() -> void:
	var skill := DragonWingSkill.new()
	var renderer := SpyRenderer.new()
	var wind_particles: Array[Dictionary] = [{"kind": "wind"}]
	var ball_trail: Array[Dictionary] = [{"kind": "ball"}]
	var dragon_trail: Array[Dictionary] = [{"kind": "dragon"}]
	var flying_dragon := {"active": true, "pos": Vector2(240.0, 520.0)}
	skill.set("_renderer", renderer)
	skill.set("_active", true)
	skill.set("_elapsed", 0.74)
	skill.set("_swirl_center", Vector2(390.0, 360.0))
	skill.set("_swirl_spin_sign", -1.0)
	skill.set("_last_ball_pos", Vector2(448.0, 332.0))
	skill.set("_wind_direction", 1.0)
	skill.set("_wind_particles", wind_particles)
	skill.set("_ball_swirl_trail", ball_trail)
	skill.set("_dragon_trail", dragon_trail)
	skill.set("_flying_dragon", flying_dragon)
	skill.set("_hit_flash_timer", 0.21)
	skill.set("_last_hit_pos", Vector2(470.0, 410.0))
	skill.set("_last_hit_dir", Vector2(0.6, -0.8))
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Dragon Wing composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(bool(renderer.payload[1]), "facade should forward active swirl state")
	_expect(is_equal_approx(float(renderer.payload[2]), 0.74), "renderer should receive the runtime elapsed clock")
	_expect(float(renderer.payload[3]) > 0.0, "facade should forward the gameplay-owned swirl envelope")
	_expect(renderer.payload[8] == wind_particles, "renderer should borrow the live wind-particle array")
	_expect(renderer.payload[9] == ball_trail, "renderer should borrow the live ball-swirl trail")
	_expect(renderer.payload[11] == dragon_trail, "renderer should borrow the live dragon trail")
	_expect(renderer.payload[13] == flying_dragon, "renderer should borrow the flying-dragon payload")
	_expect(is_equal_approx(float(renderer.payload[14]), 0.21), "renderer should receive the hit-flash clock")
	_expect(renderer.payload[17] == Vector2(0.6, -0.8), "renderer should receive the post-hit direction")


func _verify_runtime_clocked_projection() -> void:
	var renderer := DragonWingRenderer.new()
	var first: Dictionary = renderer.get_swirl_ring_projection_for_tests(0.74, 2, -1.0)
	var repeated: Dictionary = renderer.get_swirl_ring_projection_for_tests(0.74, 2, -1.0)
	var next_frame: Dictionary = renderer.get_swirl_ring_projection_for_tests(0.76, 2, -1.0)
	_expect(first == repeated, "same runtime clock should repeat the swirl projection")
	_expect(first != next_frame, "swirl projection should advance with runtime elapsed")
	_expect(float(first.get("radius", 0.0)) > 0.0, "swirl projection should retain a positive ring radius")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_dragon_wing_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_dragon_wing_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_dragon_wing")
	_expect(skill_source.contains("LingpetDragonWingRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetDragonWingRenderer.new()"), "skill should retain one renderer")
	_expect(skill_draw.contains("_elapsed"), "facade should forward its runtime clock")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains("Time.get_ticks"), "facade should not read wall time")
	_expect(not skill_draw.contains("randf") and not skill_draw.contains("randi"), "facade should consume no RNG")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render payloads")
	_expect(skill_source.contains("func _apply_wind_to_ball("), "gameplay owner should retain vortex and wind steering")
	_expect(skill_source.contains("randf_range(WIND_VARIATION_MIN"), "gameplay owner should retain wind-force RNG")
	_expect(skill_source.contains("randf_range(BALL_SPEED_MULT_MIN"), "gameplay owner should retain collision boost RNG")
	for method_name in [
		"_draw_dragon_trail",
		"_draw_wind_particles",
		"_draw_swirl_field",
		"_draw_ball_swirl_trail",
		"_draw_flying_dragon",
		"_draw_dragon_sprite",
		"_draw_flying_dragon_procedural",
		"_draw_hit_flash",
		"_draw_centered_tex",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _wind_particles"), "renderer should not retain the borrowed wind-particle array")
	_expect(not renderer_source.contains("var _ball_swirl_trail"), "renderer should not retain the borrowed ball trail")
	_expect(not renderer_source.contains("var _dragon_trail"), "renderer should not retain the borrowed dragon trail")
	_expect(renderer_draw.find("_draw_swirl_field") < renderer_draw.find("_draw_ball_swirl_trail"), "renderer should preserve swirl-field -> ball-trail order")
	_expect(renderer_draw.find("_draw_ball_swirl_trail") < renderer_draw.find("_draw_wind_particles"), "renderer should preserve ball-trail -> wind-particle order")
	_expect(renderer_draw.find("_draw_wind_particles") < renderer_draw.find("_draw_dragon_trail"), "renderer should preserve wind-particle -> dragon-trail order")
	_expect(renderer_draw.find("_draw_dragon_trail") < renderer_draw.find("_draw_flying_dragon"), "renderer should preserve dragon-trail -> flying-dragon order")
	_expect(renderer_draw.find("_draw_flying_dragon") < renderer_draw.find("_draw_hit_flash"), "renderer should preserve flying-dragon -> hit-flash order")
	_expect(skill_source.split("\n").size() < 560, "renderer split should materially shrink the mixed gameplay owner")


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
