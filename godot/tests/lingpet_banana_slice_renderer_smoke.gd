extends SceneTree

const BananaSliceRenderer := preload("res://scripts/lingpet/lingpet_banana_slice_renderer.gd")
const BananaSliceSkill := preload("res://scripts/lingpet/lingpet_banana_slice_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var prewarm_calls := 0
	var texture_loaded := true
	var payload: Array = []

	func prewarm() -> void:
		prewarm_calls += 1

	func is_banana_texture_loaded() -> bool:
		return texture_loaded

	func draw_banana_slice(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		prepare_active: bool,
		prepare_progress: float,
		prepare_pos: Vector2,
		projectiles: Array[Dictionary],
		landed_bananas: Array[Dictionary],
		particles: Array[Dictionary]
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			prepare_active,
			prepare_progress,
			prepare_pos,
			projectiles,
			landed_bananas,
			particles,
		]


func _init() -> void:
	_verify_facade_payloads_and_texture_snapshot()
	_verify_rotated_quad_projection()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_banana_slice_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_texture_snapshot() -> void:
	var skill := BananaSliceSkill.new()
	var renderer := SpyRenderer.new()
	var projectiles: Array[Dictionary] = [{"position": Vector2(300.0, 420.0)}]
	var landed: Array[Dictionary] = [{"position": Vector2(420.0, 45.0)}]
	var particles: Array[Dictionary] = [{"position": Vector2(380.0, 80.0)}]
	skill.set("_renderer", renderer)
	skill.set("_phase", 1)
	skill.set("_phase_timer", 0.15)
	skill.set("_origin", Vector2(320.0, 600.0))
	skill.set("_projectiles", projectiles)
	skill.set("_landed_bananas", landed)
	skill.set("_particles", particles)
	var canvas := Node2D.new()
	skill.prewarm()
	skill.draw(canvas, Vector2(4.0, -3.0))
	var snapshot: Dictionary = skill.get_snapshot()
	canvas.free()
	_expect(renderer.prewarm_calls == 1, "prewarm should delegate banana texture and mesh preparation")
	_expect(renderer.calls == 1, "facade should delegate Banana Slice composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(bool(renderer.payload[1]), "facade should expose prepare state")
	_expect(is_equal_approx(float(renderer.payload[2]), 0.5), "facade should forward normalized prepare progress")
	_expect(renderer.payload[3] == Vector2(320.0, 590.0), "facade should forward the gameplay-owned prepare position")
	_expect(renderer.payload[4] == projectiles, "renderer should borrow the live projectile array")
	_expect(renderer.payload[5] == landed, "renderer should borrow the live landed-banana array")
	_expect(renderer.payload[6] == particles, "renderer should borrow the live particle array")
	_expect(bool(snapshot.get("banana_slice_banana_texture_loaded", false)), "compatibility snapshot should read texture readiness from the renderer")


func _verify_rotated_quad_projection() -> void:
	var renderer := BananaSliceRenderer.new()
	var first: PackedVector2Array = renderer.get_rotated_quad_for_tests(Vector2(20.0, 30.0), Vector2(10.0, 6.0), 90.0)
	var repeated: PackedVector2Array = renderer.get_rotated_quad_for_tests(Vector2(20.0, 30.0), Vector2(10.0, 6.0), 90.0)
	_expect(first == repeated, "fixed Banana Slice geometry should repeat exactly")
	_expect(first.size() == 4, "rotated banana projection should keep four corners")
	var unique := {}
	for point in first:
		unique[point] = true
	_expect(unique.size() == 4, "rotated banana quad should not collapse duplicate points")
	_expect(first[0].distance_to(first[2]) > 10.0, "rotated banana quad should preserve its diagonal")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_banana_slice_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_banana_slice_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_banana_slice")
	_expect(skill_source.contains("LingpetBananaSliceRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetBananaSliceRenderer.new()"), "skill should retain one renderer")
	_expect(skill_source.contains("_renderer.prewarm()"), "skill prewarm should delegate render resources")
	_expect(skill_source.contains("_renderer.is_banana_texture_loaded()"), "snapshot should preserve texture readiness through the renderer")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _execute_throw("), "gameplay owner should retain throw payload creation")
	_expect(skill_source.contains("func _update_projectiles("), "gameplay owner should retain projectile movement and landing")
	_expect(skill_source.contains("func _update_landed("), "gameplay owner should retain boss collision")
	_expect(skill_source.contains("func _start_boss_slip("), "gameplay owner should retain slip direction and timing")
	_expect(skill_source.contains("func _update_particles("), "gameplay owner should retain particle simulation")
	_expect(skill_source.contains("func _pick_landing_xs("), "gameplay owner should retain landing RNG")
	for method_name in [
		"_draw_projectile_trail",
		"_draw_banana",
		"_draw_rotated_texture_region",
		"_draw_particles",
		"_draw_filled_ellipse",
		"_get_filled_ellipse_mesh",
		"_rotated_local",
		"_ensure_banana_texture",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(not skill_source.contains("ProjectResourceLoader"), "gameplay owner should not retain banana texture loading")
	_expect(not skill_source.contains("var _ellipse_mesh"), "gameplay owner should not retain render mesh cache")
	_expect(renderer_source.contains("ProjectResourceLoader.load_texture"), "renderer should own banana texture loading")
	_expect(renderer_source.contains("ArrayMesh.new()"), "renderer should own the filled-ellipse mesh cache")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _projectiles"), "renderer should not retain the borrowed projectile array")
	_expect(not renderer_source.contains("var _landed_bananas"), "renderer should not retain the borrowed landed array")
	_expect(not renderer_source.contains("var _particles"), "renderer should not retain the borrowed particle array")
	var prepare_pass := renderer_draw.find("if prepare_active")
	var projectile_pass := renderer_draw.find("for projectile in projectiles")
	var landed_pass := renderer_draw.find("for landed in landed_bananas")
	var particle_pass := renderer_draw.find("_draw_particles")
	_expect(prepare_pass >= 0 and prepare_pass < projectile_pass, "renderer should preserve prepare -> projectile order")
	_expect(projectile_pass < landed_pass, "renderer should preserve projectile -> landed order")
	_expect(landed_pass < particle_pass, "renderer should preserve landed -> particle order")
	_expect(renderer_draw.count("_draw_particles(") == 1, "renderer should compose the particle pass exactly once")
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
