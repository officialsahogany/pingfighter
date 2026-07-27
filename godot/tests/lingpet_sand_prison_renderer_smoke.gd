extends SceneTree

const SandPrisonRenderer := preload("res://scripts/lingpet/lingpet_sand_prison_renderer.gd")
const SandPrisonSkill := preload("res://scripts/lingpet/lingpet_sand_prison_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_sand_prison(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		active: bool,
		creating: bool,
		dissolving: bool,
		missing: bool,
		retry_wait: bool,
		phase_timer: float,
		anim_time: float,
		creation_seconds: float,
		dissolve_seconds: float,
		miss_seconds: float,
		cage_left: float,
		cage_right: float,
		cage_top: float,
		cage_bottom: float,
		wash_dir: float,
		sand_particles: Array[Dictionary],
		body_particles: Array[Dictionary]
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			active,
			creating,
			dissolving,
			missing,
			retry_wait,
			phase_timer,
			anim_time,
			creation_seconds,
			dissolve_seconds,
			miss_seconds,
			cage_left,
			cage_right,
			cage_top,
			cage_bottom,
			wash_dir,
			sand_particles,
			body_particles,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_runtime_clocked_grain_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_sand_prison_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := SandPrisonSkill.new()
	var renderer := SpyRenderer.new()
	var sand_particles: Array[Dictionary] = [{"kind": "ambient"}]
	var body_particles: Array[Dictionary] = [{"kind": "body"}]
	skill.set("_renderer", renderer)
	skill.set("_active", true)
	skill.set("_phase", 0)
	skill.set("_phase_timer", 0.42)
	skill.set("_anim_time", 1.25)
	skill.set("_boss_y", 25.0)
	skill.set("_boss_size", Vector2(100.0, 40.0))
	skill.set("_cage_left", 250.0)
	skill.set("_cage_right", 510.0)
	skill.set("_sand_particles", sand_particles)
	skill.set("_body_particles", body_particles)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Sand Prison composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(bool(renderer.payload[1]) and bool(renderer.payload[2]), "facade should forward active creating state")
	_expect(is_equal_approx(float(renderer.payload[6]), 0.42), "renderer should receive the phase clock")
	_expect(is_equal_approx(float(renderer.payload[7]), 1.25), "renderer should receive the runtime animation clock")
	_expect(is_equal_approx(float(renderer.payload[11]), 250.0) and is_equal_approx(float(renderer.payload[12]), 510.0), "renderer should receive cage bounds")
	_expect(is_equal_approx(float(renderer.payload[13]), 0.0) and is_equal_approx(float(renderer.payload[14]), 153.0), "facade should forward gameplay-owned cage geometry")
	_expect(renderer.payload[16] == sand_particles, "renderer should borrow the live ambient-particle array")
	_expect(renderer.payload[17] == body_particles, "renderer should borrow the live body-particle array")


func _verify_runtime_clocked_grain_projection() -> void:
	var renderer := SandPrisonRenderer.new()
	var first: Dictionary = renderer.get_grain_projection_for_tests(1.25, 0, 12, 0.7)
	var repeated: Dictionary = renderer.get_grain_projection_for_tests(1.25, 0, 12, 0.7)
	var next_frame: Dictionary = renderer.get_grain_projection_for_tests(1.25 + 1.0 / 18.0, 0, 12, 0.7)
	_expect(first == repeated, "same runtime clock should repeat the wall-grain projection")
	_expect(first != next_frame, "wall-grain projection should advance on the runtime 18Hz cadence")
	_expect(float(first.get("segment_height", 0.0)) >= 2.0 and float(first.get("segment_height", 0.0)) <= 4.0, "wall-grain segment height should preserve its original range")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_sand_prison_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_sand_prison_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_sand_prison")
	_expect(skill_source.contains("LingpetSandPrisonRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetSandPrisonRenderer.new()"), "skill should retain one renderer")
	_expect(skill_draw.contains("_anim_time"), "facade should forward its runtime animation clock")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains("randf") and not skill_draw.contains("randi"), "facade should consume no RNG")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _capture_succeeds("), "gameplay owner should retain capture resolution")
	_expect(skill_source.contains("func _write_owner_clamp("), "gameplay owner should retain boss clamp publication")
	_expect(skill_source.contains("func _update_ambient_sand("), "gameplay owner should retain ambient-particle simulation")
	_expect(skill_source.contains("func _spawn_body_particle("), "gameplay owner should retain body-particle spawning")
	_expect(skill_source.contains("randf_range(CAGE_HALF_MIN"), "gameplay owner should retain cage-width RNG")
	for method_name in [
		"_draw_cage",
		"_draw_wall_grain",
		"_draw_wall_glow",
		"_draw_grain_bar",
		"_draw_sand_particles",
		"_draw_body_particles",
		"_draw_miss_text",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _sand_particles"), "renderer should not retain the borrowed ambient-particle array")
	_expect(not renderer_source.contains("var _body_particles"), "renderer should not retain the borrowed body-particle array")
	var sand_pass := renderer_draw.find("_draw_sand_particles")
	var cage_pass := renderer_draw.find("_draw_cage")
	var body_pass := renderer_draw.find("_draw_body_particles")
	var miss_pass := renderer_draw.find("_draw_miss_text")
	_expect(sand_pass >= 0 and sand_pass < cage_pass, "renderer should preserve ambient particles -> cage order")
	_expect(cage_pass < body_pass, "renderer should preserve cage -> body particles order")
	_expect(body_pass < miss_pass, "renderer should preserve body particles -> MISS text order")
	_expect(skill_source.split("\n").size() < 650, "renderer split should materially shrink the mixed gameplay owner")


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
