extends SceneTree

const StarCoilRenderer := preload("res://scripts/lingpet/lingpet_star_coil_renderer.gd")
const StarCoilSkill := preload("res://scripts/lingpet/lingpet_star_coil_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_star_coil(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		trail_visible: bool,
		trail: Array[Vector2],
		sparks: Array[Dictionary]
	) -> void:
		calls += 1
		payload = [shake_offset, trail_visible, trail, sparks]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_safe_deterministic_star_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_star_coil_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := StarCoilSkill.new()
	var renderer := SpyRenderer.new()
	var trail: Array[Vector2] = [Vector2(300.0, 620.0), Vector2(330.0, 590.0)]
	var sparks: Array[Dictionary] = [{"kind": "star"}]
	skill.set("_renderer", renderer)
	skill.set("_phase", "climb")
	skill.set("_trail", trail)
	skill.set("_sparks", sparks)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	_expect(renderer.calls == 1, "facade should delegate Star Coil composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(bool(renderer.payload[1]), "moving phase should expose the motion trail")
	_expect(renderer.payload[2] == trail, "renderer should borrow the live trail array")
	_expect(renderer.payload[3] == sparks, "renderer should borrow the live spark array")
	skill.set("_phase", "bind")
	skill.draw(canvas)
	canvas.free()
	_expect(renderer.calls == 2 and not bool(renderer.payload[1]), "bind phase should suppress only the procedural trail")


func _verify_safe_deterministic_star_projection() -> void:
	var renderer := StarCoilRenderer.new()
	var first: PackedVector2Array = renderer.get_star_vertices_for_tests(Vector2(20.0, 30.0), 6.0, 0.25, 5)
	var repeated: PackedVector2Array = renderer.get_star_vertices_for_tests(Vector2(20.0, 30.0), 6.0, 0.25, 5)
	_expect(first == repeated, "same runtime payload should repeat the star polygon")
	_expect(first.size() == 10, "five-point star should alternate ten outer/inner vertices")
	var unique := {}
	for vertex in first:
		unique[vertex] = true
	_expect(unique.size() == first.size(), "regular star projection should not collapse duplicate vertices")
	_expect(first[0].distance_to(Vector2(20.0, 30.0)) > first[1].distance_to(Vector2(20.0, 30.0)), "star projection should alternate outer and inner radii")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_star_coil_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_star_coil_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_star_coil")
	_expect(skill_source.contains("LingpetStarCoilRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetStarCoilRenderer.new()"), "skill should retain one renderer")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _update_bind("), "gameplay owner should retain bind timing and release")
	_expect(skill_source.contains("func _sync_owner_slow("), "gameplay owner should retain boss status publication")
	_expect(skill_source.contains("func _spawn_star("), "gameplay owner should retain spark payload generation")
	_expect(skill_source.contains("func _update_sparks("), "gameplay owner should retain spark simulation")
	for method_name in ["_draw_motion_trail", "_draw_sparks", "_draw_star"]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _trail"), "renderer should not retain the borrowed trail array")
	_expect(not renderer_source.contains("var _sparks"), "renderer should not retain the borrowed spark array")
	var trail_pass := renderer_draw.find("_draw_motion_trail")
	var spark_pass := renderer_draw.find("_draw_sparks")
	_expect(trail_pass >= 0 and trail_pass < spark_pass, "renderer should preserve trail -> spark order")
	_expect(skill_source.split("\n").size() < 640, "renderer split should materially shrink the mixed gameplay owner")


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
