extends SceneTree

const AfterglowLeakRenderer := preload("res://scripts/lingpet/lingpet_afterglow_leak_renderer.gd")
const AfterglowLeakState := preload("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var prewarm_calls := 0
	var payload: Array = []

	func prewarm() -> void:
		prewarm_calls += 1

	func draw_afterglow(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		visual_time_seconds: float,
		residues: Array[Dictionary],
		particles: Array,
		absorb_flash_timer: float,
		absorb_flash_seconds: float,
		last_absorb_pos: Vector2,
		default_duration_seconds: float,
		default_absorb_radius: float,
		seep_fade_seconds: float
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			visual_time_seconds,
			residues,
			particles,
			absorb_flash_timer,
			absorb_flash_seconds,
			last_absorb_pos,
			default_duration_seconds,
			default_absorb_radius,
			seep_fade_seconds,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_safe_deterministic_pool_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_afterglow_leak_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var state := AfterglowLeakState.new()
	var renderer := SpyRenderer.new()
	var residues: Array[Dictionary] = [{
		"pos": Vector2(320.0, 712.0),
		"origin": Vector2(320.0, 560.0),
		"duration": 2.8,
		"timer": 2.1,
		"age": 0.7,
		"remaining_gauge": 4.0,
		"total_gauge": 6.0,
		"absorb_radius": 58.0,
		"seed": 1.25,
		"absorb_flash": 0.1,
		"splats": [],
	}]
	var particles: Array = [{"pos": Vector2(330.0, 680.0), "kind": 0}]
	state.set("_renderer", renderer)
	state.set("_residues", residues)
	state.set("_particles", particles)
	state.set("_absorb_flash_timer", 0.18)
	state.set("_last_absorb_pos", Vector2(340.0, 704.0))
	var canvas := Node2D.new()
	state.prewarm()
	state.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.prewarm_calls == 1, "prewarm should delegate renderer preparation")
	_expect(renderer.calls == 1, "facade should delegate Afterglow Leak composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(float(renderer.payload[1]) >= 0.0, "facade should sample one non-negative visual clock value")
	_expect(renderer.payload[2] == residues, "renderer should borrow the live typed residue array")
	_expect(renderer.payload[3] == particles, "renderer should borrow the live particle array")
	_expect(is_equal_approx(float(renderer.payload[4]), 0.18) and is_equal_approx(float(renderer.payload[5]), 0.26), "renderer should receive absorb-flash timing")
	_expect(renderer.payload[6] == Vector2(340.0, 704.0), "renderer should receive the latest absorb position")
	_expect(is_equal_approx(float(renderer.payload[7]), 2.8), "renderer should receive the gameplay residue duration fallback")
	_expect(is_equal_approx(float(renderer.payload[8]), 58.0), "renderer should receive the gameplay absorb-radius fallback")
	_expect(is_equal_approx(float(renderer.payload[9]), 0.45), "renderer should receive the seep-fade duration")


func _verify_safe_deterministic_pool_projection() -> void:
	var renderer := AfterglowLeakRenderer.new()
	var residue := {
		"duration": 2.8,
		"timer": 2.1,
		"age": 0.7,
		"remaining_gauge": 4.0,
		"total_gauge": 6.0,
		"absorb_radius": 58.0,
		"seed": 1.25,
	}
	var first: Vector4 = renderer.get_pool_projection_for_tests(12.25, residue, 2.8, 58.0, 0.45)
	var repeated: Vector4 = renderer.get_pool_projection_for_tests(12.25, residue, 2.8, 58.0, 0.45)
	_expect(first == repeated, "fixed residue payload should repeat exactly")
	_expect(first.x > 8.0 and first.y > 0.0, "visible residue should retain positive ellipse radii")
	_expect(first.z > 0.0 and first.z <= 1.0, "visible residue should retain bounded alpha")
	_expect(first.w > 0.0 and first.w <= 1.0, "settled residue should retain bounded fill")
	var expired := residue.duplicate()
	expired["timer"] = 0.0
	_expect(is_zero_approx(renderer.get_pool_projection_for_tests(12.25, expired, 2.8, 58.0, 0.45).z), "expired residue should project zero alpha")


func _verify_source_ownership() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_afterglow_leak_state.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_afterglow_leak_renderer.gd")
	var state_draw := _method_source(state_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_afterglow")
	_expect(state_source.contains("LingpetAfterglowLeakRenderer"), "state should preload the focused renderer")
	_expect(state_source.contains("var _renderer: Object = LingpetAfterglowLeakRenderer.new()"), "state should retain one renderer")
	_expect(state_source.contains("_renderer.prewarm()"), "state prewarm should delegate render resources")
	_expect(not state_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not state_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(state_source.contains("func _try_absorb_residue("), "gameplay owner should retain gauge absorption")
	_expect(state_source.contains("func _emit_jet_droplet("), "gameplay owner should retain spray RNG and payload spawning")
	_expect(state_source.contains("func _deposit_splat("), "gameplay owner should retain persistent splat lifecycle")
	_expect(state_source.contains("func _update_particles("), "gameplay owner should retain particle simulation")
	_expect(state_source.contains("randf_range"), "gameplay owner should retain runtime particle RNG")
	for method_name in ["_draw_residue", "_draw_splats", "_draw_tongues", "_draw_particles", "_blit", "_ease_out_quad"]:
		_expect(not state_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("AfterglowFluidTextureCache"), "renderer should own Afterglow texture preparation")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should receive a sampled clock instead of reading wall time")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _residues"), "renderer should not retain the borrowed residues")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particles")
	var residue_pass := renderer_draw.find("for residue in residues")
	var particle_pass := renderer_draw.find("_draw_particles")
	var flash_pass := renderer_draw.find("if absorb_flash_timer > 0.0")
	_expect(residue_pass >= 0 and residue_pass < particle_pass, "renderer should preserve residues -> particles order")
	_expect(particle_pass < flash_pass, "renderer should preserve particles -> absorb flash order")
	_expect(renderer_draw.count("_draw_residue(") == 1, "renderer should compose each residue through one loop")
	_expect(renderer_draw.count("_draw_particles(") == 1, "renderer should compose particles exactly once")
	_expect(state_source.split("\n").size() < 525, "renderer split should materially shrink the mixed passive owner")


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
