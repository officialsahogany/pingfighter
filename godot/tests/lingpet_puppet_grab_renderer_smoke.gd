extends SceneTree

const PuppetGrabRenderer := preload("res://scripts/lingpet/lingpet_puppet_grab_renderer.gd")
const PuppetGrabSkill := preload("res://scripts/lingpet/lingpet_puppet_grab_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls: Array[String] = []
	var strings_payload: Array = []
	var tension_payload: Array = []
	var sparkles_payload: Array = []
	var hearts_payload: Array = []

	func draw_strings(_canvas: CanvasItem, shake_offset: Vector2, phase: int, phase_timer: float, anim_time: float, cast_pos: Vector2, boss_center: Vector2, predicted_target: Vector2, cut_by_ball: bool, cut_point: Vector2, cut_fray_hand: Array, cut_fray_boss: Array, extend_seconds: float, miss_seconds: float, return_seconds: float) -> void:
		calls.append("strings")
		strings_payload = [shake_offset, phase, phase_timer, anim_time, cast_pos, boss_center, predicted_target, cut_by_ball, cut_point, cut_fray_hand, cut_fray_boss, extend_seconds, miss_seconds, return_seconds]

	func draw_pull_tension(_canvas: CanvasItem, shake_offset: Vector2, cast_pos: Vector2, boss_center: Vector2, anim_time: float, shot_count: int) -> void:
		calls.append("tension")
		tension_payload = [shake_offset, cast_pos, boss_center, anim_time, shot_count]

	func draw_hand(_canvas: CanvasItem, _shake_offset: Vector2, _cast_pos: Vector2) -> void:
		calls.append("hand")

	func draw_chu_text(_canvas: CanvasItem, _shake_offset: Vector2, _kiss_center: Vector2, _phase_timer: float) -> void:
		calls.append("chu")

	func draw_cut_text(_canvas: CanvasItem, _shake_offset: Vector2, _cut_point: Vector2, _boss_center: Vector2, _phase_timer: float, _return_seconds: float) -> void:
		calls.append("cut")

	func draw_miss_text(_canvas: CanvasItem, _shake_offset: Vector2, _predicted_target: Vector2, _phase_timer: float, _miss_seconds: float) -> void:
		calls.append("miss")

	func draw_sparkles(_canvas: CanvasItem, _shake_offset: Vector2, sparkles: Array[Dictionary]) -> void:
		calls.append("sparkles")
		sparkles_payload = sparkles

	func draw_hearts(_canvas: CanvasItem, _shake_offset: Vector2, hearts: Array[Dictionary]) -> void:
		calls.append("hearts")
		hearts_payload = hearts

	func recoil_retract(rp: float) -> float:
		return clampf(rp, 0.0, 1.0)

	func recoil_free_point(anchor: Vector2, break_point: Vector2, rp: float) -> Vector2:
		return anchor.lerp(break_point, 1.0 - clampf(rp, 0.0, 1.0))

	func string_tip_focus(t: float) -> float:
		return clampf(1.0 - t, 0.0, 1.0)


func _init() -> void:
	_verify_facade_order_and_borrowed_payloads()
	_verify_source_ownership()
	_verify_deterministic_tension_projection()
	if _failures.is_empty():
		print("lingpet_puppet_grab_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_order_and_borrowed_payloads() -> void:
	var skill := PuppetGrabSkill.new()
	var renderer := SpyRenderer.new()
	var fray_hand: Array = [[{"fiber": "hand"}]]
	var fray_boss: Array = [[{"fiber": "boss"}]]
	var sparkles: Array[Dictionary] = [{"kind": "sparkle"}]
	var hearts: Array[Dictionary] = [{"kind": "heart"}]
	skill.set("_renderer", renderer)
	skill.set("_active", true)
	skill.set("_phase_timer", 0.31)
	skill.set("_anim_time", 0.77)
	skill.set("_cast_pos", Vector2(380.0, 690.0))
	skill.set("_boss_draw_center", Vector2(390.0, 210.0))
	skill.set("_predicted_target_center", Vector2(400.0, 205.0))
	skill.set("_kiss_center", Vector2(380.0, 620.0))
	skill.set("_cut_point", Vector2(385.0, 400.0))
	skill.set("_cut_fray_hand", fray_hand)
	skill.set("_cut_fray_boss", fray_boss)
	skill.set("_sparkles", sparkles)
	skill.set("_hearts", hearts)
	skill.set("_shot_count", 3)
	var canvas := Node2D.new()
	skill.set("_phase", PuppetGrabSkill.PHASE_PULLING)
	skill.draw(canvas, Vector2(4.0, -3.0))
	_expect(renderer.calls == ["strings", "tension", "hand", "sparkles", "hearts"], "PULLING should preserve strings -> tension -> hand -> sparkles -> hearts order")
	_expect(renderer.strings_payload[9] == fray_hand and renderer.strings_payload[10] == fray_boss, "renderer should borrow both fray collections")
	_expect(renderer.sparkles_payload == sparkles and renderer.hearts_payload == hearts, "renderer should borrow particle collections")
	_expect(renderer.tension_payload[4] == 3, "stable tension projection should receive the runtime shot count")
	renderer.calls.clear()
	skill.set("_phase", PuppetGrabSkill.PHASE_KISSING)
	skill.draw(canvas)
	_expect(renderer.calls == ["strings", "hand", "chu", "sparkles", "hearts"], "KISSING should preserve CHU placement before residual particles")
	renderer.calls.clear()
	skill.set("_phase", PuppetGrabSkill.PHASE_RETURNING)
	skill.set("_cut_by_ball", true)
	skill.draw(canvas)
	_expect(renderer.calls == ["strings", "hand", "cut", "sparkles", "hearts"], "cut RETURNING should preserve snapped strings -> hand -> cut copy order")
	renderer.calls.clear()
	skill.set("_phase", PuppetGrabSkill.PHASE_MISSING)
	skill.draw(canvas)
	canvas.free()
	_expect(renderer.calls == ["strings", "hand", "miss", "sparkles", "hearts"], "MISS should preserve string retraction -> hand -> MISS copy order")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_puppet_grab_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_puppet_grab_renderer.gd")
	var draw_body := _method_source(skill_source, "draw")
	_expect(skill_source.contains("LingpetPuppetGrabRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetPuppetGrabRenderer.new()"), "skill should retain one renderer")
	_expect(draw_body.contains("_renderer.draw_strings"), "facade should delegate string composition")
	_expect(draw_body.contains("_renderer.draw_pull_tension"), "facade should delegate deterministic tension lines")
	_expect(draw_body.contains("_renderer.draw_hearts"), "facade should delegate residual heart particles")
	_expect(not draw_body.contains("canvas.draw_"), "facade should retain no CanvasItem recipes")
	_expect(not draw_body.contains("randf"), "draw facade should not consume global RNG")
	_expect(not draw_body.contains(".duplicate("), "draw facade should not copy borrowed arrays")
	_expect(not skill_source.contains("func _draw_strings("), "gameplay owner should not retain the string recipe")
	_expect(not skill_source.contains("func _draw_pull_tension("), "gameplay owner should not retain the tension recipe")
	_expect(not skill_source.contains("func _draw_heart("), "gameplay owner should not retain the heart recipe")
	_expect(renderer_source.contains("func draw_strings("), "renderer should own string composition")
	_expect(renderer_source.contains("func draw_pull_tension("), "renderer should own tension composition")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("randf"), "renderer should use deterministic runtime-clock projection instead of RNG")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG state")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should use the supplied animation clock")
	_expect(skill_source.split("\n").size() < 800, "renderer split should materially shrink the mixed gameplay owner")


func _verify_deterministic_tension_projection() -> void:
	var renderer := PuppetGrabRenderer.new()
	var first: Vector2 = renderer.get_pull_tension_line_for_tests(1, 0.77, 3)
	var repeated: Vector2 = renderer.get_pull_tension_line_for_tests(1, 0.77, 3)
	var next_tick: Vector2 = renderer.get_pull_tension_line_for_tests(1, 0.79, 3)
	_expect(first == repeated, "same runtime clock and shot should project the exact same tension line")
	_expect(first != next_tick, "tension line should still shimmer when the runtime clock advances")
	_expect(first.length() >= 20.0 and first.length() <= 40.0, "tension line should preserve the original 20..40px length range")


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
