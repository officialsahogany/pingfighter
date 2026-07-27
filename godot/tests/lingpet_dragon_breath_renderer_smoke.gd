extends SceneTree

const DragonBreathRenderer := preload("res://scripts/lingpet/lingpet_dragon_breath_renderer.gd")
const DragonBreathSkill := preload("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")

var _failures: Array[String] = []


class SpyBreathRenderer:
	var calls := 0
	var payload: Array = []

	func draw_breath(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		breath_active: bool,
		elapsed: float,
		origin: Vector2,
		direction: float,
		particles: Array[Dictionary],
		hit_flash_timer: float,
		last_hit_pos: Vector2,
		hit_flash_seconds: float,
		breath_spawn_seconds: float,
		jet_material: ShaderMaterial,
		additive_material: CanvasItemMaterial
	) -> void:
		calls += 1
		payload = [shake_offset, breath_active, elapsed, origin, direction, particles, hit_flash_timer, last_hit_pos, hit_flash_seconds, breath_spawn_seconds, jet_material, additive_material]


class SpyZoneRenderer:
	var calls := 0
	var elapsed := -1.0

	func draw_molotov_fire_zones(_canvas: CanvasItem, _zones: Array, _shake_offset: Vector2, render_time_seconds: float = -1.0) -> void:
		calls += 1
		elapsed = render_time_seconds


func _init() -> void:
	_verify_facade_payloads_and_clock()
	_verify_source_ownership()
	_verify_deterministic_mote_projection()
	if _failures.is_empty():
		print("lingpet_dragon_breath_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_clock() -> void:
	var skill := DragonBreathSkill.new()
	var renderer := SpyBreathRenderer.new()
	var zone_renderer := SpyZoneRenderer.new()
	var particles: Array[Dictionary] = [{"kind": "ember"}]
	var fire_zones: Array[Dictionary] = [{
		"position": Vector2(320.0, 180.0),
		"width": 100.0,
		"height": 50.0,
		"timer": 1.5,
		"max_timer": 2.0,
		"zone_id": 1,
		"flames": [],
	}]
	skill.set("_renderer", renderer)
	skill.set("_zone_fx_renderer", zone_renderer)
	skill.set("_jet_material", ShaderMaterial.new())
	skill.set("_additive_material", CanvasItemMaterial.new())
	skill.set("_breath_active", true)
	skill.set("_elapsed", 0.74)
	skill.set("_origin", Vector2(380.0, 675.0))
	skill.set("_direction", -1.0)
	skill.set("_particles", particles)
	skill.set("_fire_zones", fire_zones)
	skill.set("_hit_flash_timer", 0.21)
	skill.set("_last_hit_pos", Vector2(510.0, 330.0))
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(zone_renderer.calls == 1, "facade should sync the reused fire-zone renderer first")
	_expect(is_equal_approx(zone_renderer.elapsed, 0.74), "fire-zone fallback animation should receive runtime elapsed instead of wall time")
	_expect(renderer.calls == 1, "facade should delegate breath composition exactly once")
	_expect(renderer.payload[5] == particles, "renderer should borrow the live particle array")
	_expect(is_equal_approx(float(renderer.payload[2]), 0.74), "renderer should receive runtime elapsed")
	_expect(renderer.payload[3] == Vector2(380.0, 675.0), "renderer should receive the runtime mouth origin")
	_expect(is_equal_approx(float(renderer.payload[6]), 0.21), "renderer should receive the hit-flash clock")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_dragon_breath_renderer.gd")
	var molotov_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_molotov_renderer.gd")
	var draw_body := _method_source(skill_source, "draw")
	_expect(skill_source.contains("LingpetDragonBreathRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetDragonBreathRenderer.new()"), "skill should retain one renderer")
	_expect(draw_body.find("_draw_fire_zones_molotov") < draw_body.find("_renderer.draw_breath"), "facade should sync zone hosts before breath composition")
	_expect(draw_body.contains("_elapsed"), "facade should forward its runtime clock")
	_expect(not draw_body.contains("Time.get_ticks"), "facade should not read wall time")
	_expect(not draw_body.contains("randf"), "facade should not consume RNG")
	_expect(not draw_body.contains("canvas.draw_"), "facade should retain no direct drawing recipe")
	_expect(not draw_body.contains(".duplicate("), "facade should not copy the particle array")
	_expect(not skill_source.contains("func _draw_breath_jet("), "gameplay owner should not retain the jet recipe")
	_expect(not skill_source.contains("func _draw_breath_particle("), "gameplay owner should not retain the particle recipe")
	_expect(renderer_source.contains("func draw_breath("), "renderer should own breath composition")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should use runtime elapsed instead of wall time")
	_expect(not renderer_source.contains("randf"), "renderer should use deterministic mote projection")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG")
	_expect(molotov_source.contains("render_time_seconds: float = -1.0"), "shared Molotov renderer should keep a backward-compatible explicit-time argument")
	_expect(skill_source.split("\n").size() < 800, "renderer split should materially shrink the mixed gameplay owner")


func _verify_deterministic_mote_projection() -> void:
	var renderer := DragonBreathRenderer.new()
	var particle := {"phase": 0.17, "wob": 0.74, "size": 19.0}
	var first_roll := float(renderer.get_particle_mote_roll_for_tests(particle, 1, 0.74))
	var repeated_roll := float(renderer.get_particle_mote_roll_for_tests(particle, 1, 0.74))
	var first_offset: Vector2 = renderer.get_particle_mote_offset_for_tests(particle, 1, 0.74)
	var repeated_offset: Vector2 = renderer.get_particle_mote_offset_for_tests(particle, 1, 0.74)
	var next_offset: Vector2 = renderer.get_particle_mote_offset_for_tests(particle, 1, 0.76)
	_expect(is_equal_approx(first_roll, repeated_roll), "same particle and runtime clock should produce the same mote roll")
	_expect(first_offset == repeated_offset, "same particle and runtime clock should produce the same mote offset")
	_expect(first_offset != next_offset, "mote shimmer should advance with the runtime clock")
	_expect(first_roll >= 0.0 and first_roll < 1.0, "mote roll should remain normalized")
	_expect(absf(first_offset.x) <= 19.0 and absf(first_offset.y) <= 19.0, "mote offset should preserve the original particle-size bounds")


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
