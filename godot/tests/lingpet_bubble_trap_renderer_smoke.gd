extends SceneTree

const BubbleTrapRenderer := preload("res://scripts/lingpet/lingpet_bubble_trap_renderer.gd")
const BubbleTrapSkill := preload("res://scripts/lingpet/lingpet_bubble_trap_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_bubble_trap(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		runtime_elapsed: float,
		capture_timer: float,
		capture_duration_seconds: float,
		bubble_center: Vector2,
		capture_bubble_radius: float,
		capture_visual_seed: float,
		projectiles: Array,
		projectile_radius: float,
		burst_timer: float,
		burst_pos: Vector2,
		burst_flash_seconds: float,
		particles: Array,
		inner_bubble_size_variance: float
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			runtime_elapsed,
			capture_timer,
			capture_duration_seconds,
			bubble_center,
			capture_bubble_radius,
			capture_visual_seed,
			projectiles,
			projectile_radius,
			burst_timer,
			burst_pos,
			burst_flash_seconds,
			particles,
			inner_bubble_size_variance,
		]


func _init() -> void:
	_verify_facade_payloads_and_runtime_clock()
	_verify_runtime_clocked_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_bubble_trap_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_runtime_clock() -> void:
	var skill := BubbleTrapSkill.new()
	var renderer := SpyRenderer.new()
	var projectiles: Array = [{"kind": "projectile"}]
	var particles: Array = [{"kind": "burst"}]
	skill.set("_renderer", renderer)
	skill.set("_visual_elapsed", 0.74)
	skill.set("_capture_timer", 1.4)
	skill.set("_capture_duration_seconds", 2.8)
	skill.set("_bubble_center", Vector2(390.0, 150.0))
	skill.set("_capture_bubble_radius", 92.0)
	skill.set("_capture_visual_seed", 0.37)
	skill.set("_projectiles", projectiles)
	skill.set("_burst_timer", 0.21)
	skill.set("_burst_pos", Vector2(280.0, 330.0))
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Bubble Trap composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(is_equal_approx(float(renderer.payload[1]), 0.74), "renderer should receive the runtime visual clock")
	_expect(is_equal_approx(float(renderer.payload[2]), 1.4), "renderer should receive the capture clock")
	_expect(renderer.payload[4] == Vector2(390.0, 150.0), "renderer should receive the capture center")
	_expect(renderer.payload[7] == projectiles, "renderer should borrow the live projectile array")
	_expect(renderer.payload[10] == Vector2(280.0, 330.0), "renderer should receive the burst center")
	_expect(renderer.payload[12] == particles, "renderer should borrow the live particle array")
	_expect(is_equal_approx(float(renderer.payload[13]), 0.30), "renderer should receive the inner-bubble variance")


func _verify_runtime_clocked_projection() -> void:
	var renderer := BubbleTrapRenderer.new()
	var center := Vector2(420.0, 260.0)
	var first: Dictionary = renderer.get_animated_projection_for_tests(0.74, center)
	var repeated: Dictionary = renderer.get_animated_projection_for_tests(0.74, center)
	var next_frame: Dictionary = renderer.get_animated_projection_for_tests(0.76, center)
	_expect(first == repeated, "same runtime clock should repeat Bubble Trap animation projection")
	_expect(first != next_frame, "Bubble Trap animation projection should advance with runtime elapsed")
	_expect(float(first.get("capture_pulse", 0.0)) >= 0.88 and float(first.get("capture_pulse", 0.0)) <= 1.0, "capture pulse should preserve the original envelope")
	_expect(float(first.get("rainbow_hue", -1.0)) >= 0.0 and float(first.get("rainbow_hue", -1.0)) < 1.0, "rainbow hue should remain normalized")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bubble_trap_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_bubble_trap_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_bubble_trap")
	_expect(skill_source.contains("LingpetBubbleTrapRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetBubbleTrapRenderer.new()"), "skill should retain one renderer")
	_expect(skill_draw.contains("_visual_elapsed"), "facade should forward its runtime visual clock")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains("Time.get_ticks"), "facade should not read wall time")
	_expect(not skill_draw.contains("randf") and not skill_draw.contains("randi"), "facade should consume no RNG")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _update_projectile("), "gameplay owner should retain projectile collision and motion")
	_expect(skill_source.contains("func _begin_capture("), "gameplay owner should retain boss capture orchestration")
	_expect(skill_source.contains("func _spawn_burst_particles("), "gameplay owner should retain burst-particle spawning")
	_expect(skill_source.contains("func _roll_extra_success("), "gameplay owner should retain extra-shot rolls")
	_expect(skill_source.contains("func _roll_rainbow("), "gameplay owner should retain rainbow-shot rolls")
	for method_name in [
		"_draw_projectile",
		"_draw_rainbow_projectile_shimmer",
		"_draw_capture_bubble",
		"_draw_burst",
		"_draw_bubble_core",
		"_draw_inner_bubbles",
		"_draw_particles",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _projectiles"), "renderer should not retain the borrowed projectile array")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particle array")
	var capture_pass := renderer_draw.find("_draw_capture_bubble")
	var projectile_pass := renderer_draw.find("for projectile_value in projectiles")
	var burst_pass := renderer_draw.find("_draw_burst")
	var particle_pass := renderer_draw.find("_draw_particles")
	_expect(capture_pass >= 0 and capture_pass < projectile_pass, "renderer should preserve capture -> projectile order")
	_expect(projectile_pass < burst_pass, "renderer should preserve projectile -> burst order")
	_expect(burst_pass < particle_pass, "renderer should preserve burst -> particle order")
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
