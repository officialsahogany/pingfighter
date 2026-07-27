extends SceneTree

const BoneBarrierRenderer := preload("res://scripts/lingpet/lingpet_bone_barrier_renderer.gd")
const BoneBarrierSkill := preload("res://scripts/lingpet/lingpet_bone_barrier_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_bone_barrier(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		build_time: float,
		death_duration: float,
		barriers: Array[Dictionary],
		dying_barriers: Array[Dictionary],
		particles: Array[Dictionary]
	) -> void:
		calls += 1
		payload = [shake_offset, build_time, death_duration, barriers, dying_barriers, particles]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_build_progress_contract()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_bone_barrier_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := BoneBarrierSkill.new()
	var renderer := SpyRenderer.new()
	var barriers: Array[Dictionary] = [{"id": 1}]
	var dying_barriers: Array[Dictionary] = [{"timer": 0.2}]
	var particles: Array[Dictionary] = [{"age": 0.1}]
	skill.set("_renderer", renderer)
	skill.set("_barriers", barriers)
	skill.set("_dying_barriers", dying_barriers)
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Bone Barrier composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(is_equal_approx(float(renderer.payload[1]), 3.0), "renderer should receive the gameplay-owned build duration")
	_expect(is_equal_approx(float(renderer.payload[2]), 0.6), "renderer should receive the gameplay-owned death duration")
	_expect(renderer.payload[3] == barriers, "renderer should borrow the live barrier array")
	_expect(renderer.payload[4] == dying_barriers, "renderer should borrow the live dying-barrier array")
	_expect(renderer.payload[5] == particles, "renderer should borrow the live particle array")


func _verify_build_progress_contract() -> void:
	var early := BoneBarrierRenderer.get_build_segment_adjusted_progress(1.14, 0.0, 3.0)
	var delayed := BoneBarrierRenderer.get_build_segment_adjusted_progress(1.14, 0.60, 3.0)
	var finished := BoneBarrierRenderer.get_build_segment_adjusted_progress(3.0, 0.60, 3.0)
	_expect(early > 0.30 and early < 0.50, "renderer should preserve full-duration early assembly progress")
	_expect(delayed < early, "delayed bone segments should trail earlier segments")
	_expect(is_equal_approx(finished, 1.0), "delayed segments should finish at the gameplay build duration")
	_expect(is_equal_approx(BoneBarrierSkill._get_build_segment_adjusted_progress(1.14, 0.60), delayed), "skill compatibility facade should delegate the same build projection")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bone_barrier_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bone_barrier_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_bone_barrier")
	_expect(skill_source.contains("LingpetBoneBarrierRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetBoneBarrierRenderer.new()"), "skill should retain one renderer")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func notify_ball_collision("), "gameplay owner should retain collision notification")
	_expect(skill_source.contains("func _break_barrier_at_index("), "gameplay owner should retain barrier break lifecycle")
	_expect(skill_source.contains("func _update_dying_barriers("), "gameplay owner should retain fragment simulation")
	_expect(skill_source.contains("func _choose_barrier_x("), "gameplay owner should retain placement RNG")
	for method_name in [
		"_draw_barrier",
		"_draw_building_barrier",
		"_draw_built_barrier",
		"_draw_dying_barrier",
		"_draw_particles",
		"_draw_bone_segment",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _barriers"), "renderer should not retain the borrowed barrier array")
	_expect(not renderer_source.contains("var _dying_barriers"), "renderer should not retain the borrowed dying-barrier array")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particle array")
	var particle_pass := renderer_draw.find("_draw_particles")
	var dying_pass := renderer_draw.find("for dying in dying_barriers")
	var barrier_pass := renderer_draw.find("for barrier in barriers")
	_expect(particle_pass >= 0 and particle_pass < dying_pass, "renderer should preserve particles -> dying barriers order")
	_expect(dying_pass < barrier_pass, "renderer should preserve dying -> live barriers order")
	_expect(skill_source.split("\n").size() < 540, "renderer split should materially shrink the mixed gameplay owner")


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
