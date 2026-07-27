extends SceneTree

const ThunderOrbRenderer := preload("res://scripts/lingpet/lingpet_thunder_orb_renderer.gd")
const ThunderOrbSkill := preload("res://scripts/lingpet/lingpet_thunder_orb_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls: Array[String] = []
	var trail: Array[Vector2] = []
	var energy_particles: Array = []
	var explosion_particles: Array = []
	var mini_spark_flashes: Array = []
	var elapsed := -1.0
	var visual_seed := -1.0

	func draw_particles(_canvas: CanvasItem, particles: Array, _shake_offset: Vector2) -> void:
		calls.append("particles")
		explosion_particles = particles

	func draw_explosion(
		_canvas: CanvasItem,
		_center: Vector2,
		_explosion_timer: float,
		_explosion_duration_seconds: float,
		_explosion_radius: float,
		seed: float
	) -> void:
		calls.append("explosion")
		visual_seed = seed

	func draw_mini_spark_flashes(
		_canvas: CanvasItem,
		flashes: Array,
		_shake_offset: Vector2,
		_flash_seconds: float,
		_visual_radius: float
	) -> void:
		calls.append("mini_sparks")
		mini_spark_flashes = flashes

	func draw_orb(
		_canvas: CanvasItem,
		_position: Vector2,
		_shake_offset: Vector2,
		runtime_elapsed: float,
		seed: float,
		_orb_rotation: float,
		_orb_visual_radius: float,
		borrowed_trail: Array[Vector2],
		borrowed_energy_particles: Array
	) -> void:
		calls.append("orb")
		elapsed = runtime_elapsed
		visual_seed = seed
		trail = borrowed_trail
		energy_particles = borrowed_energy_particles


func _init() -> void:
	_verify_facade_fanout_and_borrowed_payloads()
	_verify_projection_is_runtime_clocked()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_thunder_orb_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_fanout_and_borrowed_payloads() -> void:
	var skill := ThunderOrbSkill.new()
	var renderer := SpyRenderer.new()
	var trail: Array[Vector2] = [Vector2(380.0, 690.0), Vector2(380.0, 640.0)]
	var energy_particles: Array = [{"life": 0.3}]
	var explosion_particles: Array = [{"life": 0.4}]
	var flashes: Array = [{"timer": 0.2}]
	skill.set("_renderer", renderer)
	skill.set("_phase", 1)
	skill.set("_elapsed", 0.74)
	skill.set("_visual_seed", 0.42)
	skill.set("_orb_pos", Vector2(380.0, 420.0))
	skill.set("_trail", trail)
	skill.set("_energy_particles", energy_particles)
	skill.set("_explosion_timer", 0.12)
	skill.set("_explosion_pos", Vector2(420.0, 130.0))
	skill.set("_explosion_particles", explosion_particles)
	skill.set("_mini_spark_flashes", flashes)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(3.0, -2.0))
	canvas.free()
	_expect(renderer.calls == ["particles", "explosion", "mini_sparks", "orb"], "facade should preserve particles -> explosion -> mini-sparks -> orb order")
	_expect(renderer.trail == trail, "renderer should borrow the live typed trail")
	_expect(renderer.energy_particles == energy_particles, "renderer should borrow live energy particles")
	_expect(renderer.explosion_particles == explosion_particles, "renderer should borrow live explosion particles")
	_expect(renderer.mini_spark_flashes == flashes, "renderer should borrow live mini-spark flashes")
	_expect(is_equal_approx(renderer.elapsed, 0.74), "orb renderer should receive the runtime elapsed clock")
	_expect(is_equal_approx(renderer.visual_seed, 0.42), "renderer should receive the launch visual seed")


func _verify_projection_is_runtime_clocked() -> void:
	var renderer := ThunderOrbRenderer.new()
	var first := float(renderer.get_crackle_unit_for_tests(0.42, 0.74, 1, 3))
	var repeated := float(renderer.get_crackle_unit_for_tests(0.42, 0.74, 1, 3))
	var next_frame := float(renderer.get_crackle_unit_for_tests(0.42, 0.76, 1, 3))
	_expect(is_equal_approx(first, repeated), "same visual seed and runtime clock should repeat the crackle projection")
	_expect(not is_equal_approx(first, next_frame), "crackle projection should advance with runtime elapsed")
	_expect(first >= 0.0 and first < 1.0, "crackle projection should stay normalized")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_thunder_orb_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_thunder_orb_renderer.gd")
	var draw_body := _method_source(skill_source, "draw")
	_expect(skill_source.contains("LingpetThunderOrbRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetThunderOrbRenderer.new()"), "skill should retain one renderer")
	_expect(not draw_body.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not draw_body.contains("Time.get_ticks"), "facade should forward runtime clocks instead of reading wall time")
	_expect(not draw_body.contains("randf") and not draw_body.contains("randi"), "facade should consume no RNG")
	_expect(not draw_body.contains(".duplicate("), "facade should not copy live render collections")
	_expect(not skill_source.contains("func _draw_orb("), "gameplay owner should not retain the orb recipe")
	_expect(not skill_source.contains("func _draw_explosion("), "gameplay owner should not retain the explosion recipe")
	_expect(not skill_source.contains("func _draw_mini_spark_flashes("), "gameplay owner should not retain the mini-spark recipe")
	_expect(not skill_source.contains("func _draw_particles("), "gameplay owner should not retain the particle recipe")
	_expect(not skill_source.contains("func _draw_boss_electric_stun("), "obsolete local stun fallback should not remain beside the shared host")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should use deterministic projection instead of RNG")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should retain no RNG object")
	_expect(not renderer_source.contains("var _trail"), "renderer should retain no borrowed collection")
	_expect(skill_source.split("\n").size() < 700, "renderer split should materially shrink the mixed gameplay owner")


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
