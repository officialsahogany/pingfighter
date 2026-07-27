extends SceneTree

const DollCurseRenderer := preload("res://scripts/lingpet/lingpet_doll_curse_renderer.gd")
const DollCurseSkill := preload("res://scripts/lingpet/lingpet_doll_curse_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls: Array[String] = []
	var dolls: Array[Dictionary] = []
	var destroy_particles: Array[Dictionary] = []
	var phase := -1
	var phase_timer := -1.0
	var active_skill_level := -1
	var beam_length := -1.0
	var beam_outer_end_half_width := -1.0

	func draw_marionette_rigging(_canvas: CanvasItem, borrowed_dolls: Array[Dictionary], _shake_offset: Vector2) -> void:
		calls.append("rigging")
		dolls = borrowed_dolls

	func draw_beams(
		_canvas: CanvasItem,
		borrowed_dolls: Array[Dictionary],
		_shake_offset: Vector2,
		level: int,
		length: float,
		_base_angle: float,
		outer_end_half_width: float,
		_doll_half: Vector2
	) -> void:
		calls.append("beams")
		dolls = borrowed_dolls
		active_skill_level = level
		beam_length = length
		beam_outer_end_half_width = outer_end_half_width

	func draw_dolls(
		_canvas: CanvasItem,
		borrowed_dolls: Array[Dictionary],
		_shake_offset: Vector2,
		_texture: Texture2D,
		phase_value: int,
		phase_timer_value: float,
		_phase_emerge: int,
		_phase_active: int,
		_phase_retract: int,
		_emerge_seconds: float,
		_retract_seconds: float,
		_doll_half: Vector2
	) -> void:
		calls.append("dolls")
		dolls = borrowed_dolls
		phase = phase_value
		phase_timer = phase_timer_value

	func draw_destroy_particles(
		_canvas: CanvasItem,
		borrowed_particles: Array[Dictionary],
		_shake_offset: Vector2,
		_destroy_particle_life: float
	) -> void:
		calls.append("destroy_particles")
		destroy_particles = borrowed_particles

	func draw_hit_flash(
		_canvas: CanvasItem,
		_position: Vector2,
		_timer: float,
		_hit_flash_seconds: float
	) -> void:
		calls.append("hit_flash")

	func get_doll_sheet_frame(
		_doll: Dictionary,
		_phase: int,
		_phase_timer: float,
		_phase_emerge: int,
		_phase_active: int,
		_phase_retract: int,
		_emerge_seconds: float,
		_retract_seconds: float
	) -> int:
		return 7

	func get_beam_draw_debug(_doll: Dictionary, _active_skill_level: int, _outer_end_half_width: float) -> Dictionary:
		return {"renderer_marker": true}


func _init() -> void:
	_verify_facade_fanout_and_borrowed_payloads()
	_verify_compatibility_queries_delegate()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_doll_curse_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_fanout_and_borrowed_payloads() -> void:
	var skill := DollCurseSkill.new()
	var renderer := SpyRenderer.new()
	var dolls: Array[Dictionary] = [{"alive": true, "pos": Vector2(230.0, 620.0)}]
	var particles: Array[Dictionary] = [{"life": 0.4, "pos": Vector2(230.0, 620.0)}]
	skill.set("_renderer", renderer)
	skill.set("_phase", 2)
	skill.set("_phase_timer", 1.25)
	skill.set("_dolls", dolls)
	skill.set("_destroy_particles", particles)
	skill.set("_hit_flash_timer", 0.12)
	skill.set("_last_hit_pos", Vector2(510.0, 80.0))
	skill.set("_active_skill_level", 5)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(3.0, -2.0))
	canvas.free()
	_expect(renderer.calls == ["rigging", "beams", "dolls", "destroy_particles", "hit_flash"], "facade should preserve rigging -> beams -> dolls -> debris -> hit-flash order")
	_expect(renderer.dolls == dolls, "renderer should borrow the live doll array")
	_expect(renderer.destroy_particles == particles, "renderer should borrow the live destroy-particle array")
	_expect(renderer.phase == 2 and is_equal_approx(renderer.phase_timer, 1.25), "renderer should receive the runtime phase clock")
	_expect(renderer.active_skill_level == 5, "beam renderer should receive the runtime skill level")
	_expect(renderer.beam_length > 0.0 and renderer.beam_outer_end_half_width > 0.0, "beam renderer should receive gameplay-derived cone geometry")


func _verify_compatibility_queries_delegate() -> void:
	var skill := DollCurseSkill.new()
	var renderer := SpyRenderer.new()
	skill.set("_renderer", renderer)
	skill.set("_phase", 2)
	skill.set("_phase_timer", 0.5)
	_expect(skill.get_doll_sheet_frame_for_tests({}) == 7, "sheet-frame compatibility query should delegate to the renderer")
	_expect(bool(skill.get_beam_draw_debug_for_tests({}).get("renderer_marker", false)), "beam-debug compatibility query should delegate to the renderer")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_renderer.gd")
	var draw_body := _method_source(skill_source, "draw")
	_expect(skill_source.contains("LingpetDollCurseRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetDollCurseRenderer.new()"), "skill should retain one renderer")
	_expect(not draw_body.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not draw_body.contains(".duplicate("), "facade should not copy live render collections")
	_expect(not skill_source.contains("func _draw_marionette_rigging("), "gameplay owner should not retain rigging recipes")
	_expect(not skill_source.contains("func _draw_beams("), "gameplay owner should not retain beam recipes")
	_expect(not skill_source.contains("func _draw_dolls("), "gameplay owner should not retain doll recipes")
	_expect(not skill_source.contains("func _draw_destroy_particles("), "gameplay owner should not retain debris recipes")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _dolls"), "renderer should retain no borrowed collection")
	_expect(skill_source.contains("BEAM_OUTER_END_HALF_WIDTH := BEAM_LENGTH * tan(BEAM_HALF_ANGLE)"), "gameplay owner should retain the hit-cone-derived visual boundary")
	_expect(skill_source.split("\n").size() < 800, "renderer split should materially shrink the mixed gameplay owner")


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
