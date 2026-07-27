extends SceneTree

const SkeletonArcherRenderer := preload("res://scripts/lingpet/lingpet_skeleton_archer_renderer.gd")
const SkeletonArcherSkill := preload("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		particles: Array[Dictionary],
		dying_archers: Array[Dictionary],
		archers: Array[Dictionary],
		arrows: Array[Dictionary],
		emerge_duration: float,
		death_duration: float,
		arrow_draw_time: float
	) -> void:
		calls += 1
		payload = [shake_offset, particles, dying_archers, archers, arrows, emerge_duration, death_duration, arrow_draw_time]


func _init() -> void:
	_verify_facade_payload()
	_verify_source_ownership_and_order()
	_verify_renderer_is_stateless()
	if _failures.is_empty():
		print("lingpet_skeleton_archer_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payload() -> void:
	var skill := SkeletonArcherSkill.new()
	var renderer := SpyRenderer.new()
	var particles: Array[Dictionary] = [{"kind": "particle"}]
	var dying_archers: Array[Dictionary] = [{"kind": "dying"}]
	var archers: Array[Dictionary] = [{"kind": "archer"}]
	var arrows: Array[Dictionary] = [{"kind": "arrow"}]
	skill.set("_renderer", renderer)
	skill.set("_particles", particles)
	skill.set("_dying_archers", dying_archers)
	skill.set("_archers", archers)
	skill.set("_arrows", arrows)
	skill.set("_arrow_draw_time", 0.84)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate the complete scene exactly once")
	_expect(_vector(renderer.payload, 0) == Vector2(4.0, -3.0), "renderer should receive the original shake offset")
	_expect(renderer.payload[1] == particles, "renderer should receive the borrowed particle array")
	_expect(renderer.payload[2] == dying_archers, "renderer should receive the borrowed dying-archer array")
	_expect(renderer.payload[3] == archers, "renderer should receive the borrowed live-archer array")
	_expect(renderer.payload[4] == arrows, "renderer should receive the borrowed arrow array")
	_expect(is_equal_approx(float(renderer.payload[5]), SkeletonArcherSkill.EMERGE_DURATION), "runtime should own emerge timing")
	_expect(is_equal_approx(float(renderer.payload[6]), SkeletonArcherSkill.DEATH_DURATION), "runtime should own death timing")
	_expect(is_equal_approx(float(renderer.payload[7]), 0.84), "renderer should receive the current level-scaled draw time")


func _verify_source_ownership_and_order() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skeleton_archer_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skeleton_archer_renderer.gd")
	var facade_body := _method_source(skill_source, "draw")
	var renderer_body := _method_source(renderer_source, "draw")
	_expect(skill_source.contains("LingpetSkeletonArcherRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetSkeletonArcherRenderer.new()"), "skill should retain one renderer instance")
	_expect(facade_body.contains("_renderer.draw("), "draw facade should delegate to the renderer")
	_expect(not facade_body.contains("canvas.draw_"), "draw facade should not retain CanvasItem recipes")
	_expect(not facade_body.contains(".duplicate("), "draw facade should not copy render arrays per frame")
	_expect(not skill_source.contains("func _draw_archer("), "gameplay owner should not retain the live-archer recipe")
	_expect(not skill_source.contains("func _draw_dying_archer("), "gameplay owner should not retain the death recipe")
	_expect(not skill_source.contains("func _draw_arrow("), "gameplay owner should not retain the arrow recipe")
	_expect(not skill_source.contains("func _draw_particles("), "gameplay owner should not retain the particle recipe")
	_expect(renderer_source.contains("func _draw_archer("), "renderer should own live-archer composition")
	_expect(renderer_source.contains("func _draw_dying_archer("), "renderer should own death composition")
	_expect(renderer_source.contains("func _draw_arrow("), "renderer should own arrow composition")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own the CanvasItem primitives")
	_expect(not renderer_body.contains(".duplicate("), "renderer should iterate borrowed arrays without copying")
	var particle_index := renderer_body.find("_draw_particles")
	var dying_index := renderer_body.find("for dying in dying_archers")
	var archer_index := renderer_body.find("for archer in archers")
	var arrow_index := renderer_body.find("for arrow in arrows")
	_expect(particle_index >= 0 and particle_index < dying_index and dying_index < archer_index and archer_index < arrow_index, "renderer should preserve particles -> dying -> live -> arrows draw order")
	_expect(skill_source.split("\n").size() < 750, "renderer split should materially shrink the gameplay owner")


func _verify_renderer_is_stateless() -> void:
	var renderer := SkeletonArcherRenderer.new()
	_expect(renderer != null, "focused renderer should construct")
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skeleton_archer_renderer.gd")
	_expect(not source.contains("var _archers"), "renderer should not mirror live gameplay collections")
	_expect(not source.contains("var _particles"), "renderer should not mirror particle state")
	_expect(not source.contains("RandomNumberGenerator"), "renderer should not own RNG")
	_expect(not source.contains("randf"), "renderer should remain deterministic for a supplied snapshot")
	_expect(not source.contains("Time.get_ticks"), "renderer animation should use runtime-owned clocks")


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _vector(values: Array, index: int) -> Vector2:
	var value: Variant = values[index] if index >= 0 and index < values.size() else Vector2.ZERO
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
