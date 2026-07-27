extends SceneTree

const GhostSummonRenderer := preload("res://scripts/lingpet/lingpet_ghost_summon_renderer.gd")
const GhostSummonSkill := preload("res://scripts/lingpet/lingpet_ghost_summon_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_ghost_summon(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		particles: Array[Dictionary],
		teleport_particles: Array[Dictionary],
		launch_flash_timer: float,
		launch_origin: Vector2,
		launch_flash_duration: float,
		dying_ghosts: Array[Dictionary],
		death_duration: float,
		ghosts: Array[Dictionary],
		emerge_duration: float,
		teleport_disappear_duration: float,
		teleport_appear_duration: float
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			particles,
			teleport_particles,
			launch_flash_timer,
			launch_origin,
			launch_flash_duration,
			dying_ghosts,
			death_duration,
			ghosts,
			emerge_duration,
			teleport_disappear_duration,
			teleport_appear_duration,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_dying_spark_projection_is_deterministic()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_ghost_summon_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := GhostSummonSkill.new()
	var renderer := SpyRenderer.new()
	var particles: Array[Dictionary] = [{"kind": "normal"}]
	var teleport_particles: Array[Dictionary] = [{"kind": "teleport"}]
	var dying_ghosts: Array[Dictionary] = [{"death_timer": 0.3}]
	var ghosts: Array[Dictionary] = [{"id": 1}]
	skill.set("_renderer", renderer)
	skill.set("_particles", particles)
	skill.set("_teleport_particles", teleport_particles)
	skill.set("_launch_flash_timer", 0.12)
	skill.set("_launch_origin", Vector2(380.0, 650.0))
	skill.set("_dying_ghosts", dying_ghosts)
	skill.set("_ghosts", ghosts)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Ghost Summon composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(renderer.payload[1] == particles, "renderer should borrow the live normal-particle array")
	_expect(renderer.payload[2] == teleport_particles, "renderer should borrow the live teleport-particle array")
	_expect(is_equal_approx(float(renderer.payload[3]), 0.12), "renderer should receive the launch-flash clock")
	_expect(renderer.payload[4] == Vector2(380.0, 650.0), "renderer should receive the launch origin")
	_expect(renderer.payload[6] == dying_ghosts, "renderer should borrow the live dying-ghost array")
	_expect(renderer.payload[8] == ghosts, "renderer should borrow the live ghost array")


func _verify_dying_spark_projection_is_deterministic() -> void:
	var renderer := GhostSummonRenderer.new()
	var dying := {"pos": Vector2(280.0, 340.0), "phase": 1.27, "death_timer": 0.42}
	var first: Dictionary = renderer.get_dying_spark_projection_for_tests(dying, 0.6, 2)
	var repeated: Dictionary = renderer.get_dying_spark_projection_for_tests(dying, 0.6, 2)
	var advanced_dying := dying.duplicate()
	advanced_dying["death_timer"] = 0.46
	var advanced: Dictionary = renderer.get_dying_spark_projection_for_tests(advanced_dying, 0.6, 2)
	_expect(first == repeated, "same dying payload should repeat the spark projection")
	_expect(first != advanced, "spark projection should advance with the runtime death timer")
	_expect(float(first.get("radius", 0.0)) >= 2.0 and float(first.get("radius", 0.0)) <= 5.0, "spark radius should preserve the original range")
	_expect(float(first.get("alpha_scale", 0.0)) >= 0.3 and float(first.get("alpha_scale", 0.0)) <= 1.0, "spark alpha scale should preserve the original range")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_ghost_summon_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_ghost_summon_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_ghost_summon")
	_expect(skill_source.contains("LingpetGhostSummonRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetGhostSummonRenderer.new()"), "skill should retain one renderer")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains("randf") and not skill_draw.contains("randi"), "facade should consume no RNG")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _update_roaming_ghost("), "gameplay owner should retain ghost movement and capture orchestration")
	_expect(skill_source.contains("randf() < 0.60"), "gameplay owner should retain emergence particle RNG")
	_expect(skill_source.contains("var use_far_from_boss := randf()"), "gameplay owner should retain teleport-target RNG")
	for method_name in [
		"_draw_roaming_state",
		"_draw_eating_state",
		"_draw_teleporting_ghost",
		"_draw_dying_ghost",
		"_draw_launch_flash",
		"_draw_fallback_ghost",
		"_draw_ghost_glyph",
		"_draw_ground_shadow",
		"_fill_ellipse",
		"_draw_particles",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should use deterministic dying-spark projection")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _ghosts"), "renderer should not retain the borrowed ghost array")
	_expect(not renderer_source.contains("var _dying_ghosts"), "renderer should not retain the borrowed dying-ghost array")
	var first_particles := renderer_draw.find("_draw_particles")
	var second_particles := renderer_draw.find("_draw_particles", first_particles + 1)
	var launch_flash := renderer_draw.find("_draw_launch_flash")
	var dying_pass := renderer_draw.find("_draw_dying_ghost")
	var live_pass := renderer_draw.find("for ghost_value in ghosts")
	_expect(first_particles >= 0 and second_particles > first_particles, "renderer should keep both particle passes")
	_expect(second_particles < launch_flash, "renderer should preserve particle -> launch-flash order")
	_expect(launch_flash < dying_pass, "renderer should preserve launch-flash -> dying-ghost order")
	_expect(dying_pass < live_pass, "renderer should preserve dying-ghost -> live-ghost order")
	_expect(skill_source.split("\n").size() < 680, "renderer split should materially shrink the mixed gameplay owner")


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
