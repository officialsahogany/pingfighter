extends SceneTree

const HeadbuttRenderer := preload("res://scripts/lingpet/lingpet_headbutt_renderer.gd")
const HeadbuttSkill := preload("res://scripts/lingpet/lingpet_headbutt_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls: Array[String] = []
	var mega_charge_payload: Array = []
	var dash_payload: Array = []
	var impact_payload: Array = []
	var miss_payload: Array = []
	var miss_text_payload: Array = []
	var self_stun_payload: Array = []

	func draw_mega_charge(_canvas: CanvasItem, center: Vector2, ratio: float, elapsed: float) -> void:
		calls.append("mega_charge")
		mega_charge_payload = [center, ratio, elapsed]

	func draw_dash(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		ground_slam: bool,
		trail: Array[Vector2],
		pos: Vector2,
		dash_radius: float,
		dash_dir: Vector2,
		dash_elapsed: float
	) -> void:
		calls.append("dash")
		dash_payload = [shake_offset, ground_slam, trail, pos, dash_radius, dash_dir, dash_elapsed]

	func draw_hit_impact(
		_canvas: CanvasItem,
		pos: Vector2,
		stable_impact_pos: Vector2,
		ratio: float,
		ground_slam: bool,
		mega_impact: bool,
		slam_radius: float,
		target: Vector2,
		outcome_seed: int
	) -> void:
		calls.append("hit_impact")
		impact_payload = [pos, stable_impact_pos, ratio, ground_slam, mega_impact, slam_radius, target, outcome_seed]

	func draw_miss_impact(_canvas: CanvasItem, pos: Vector2, ratio: float) -> void:
		calls.append("miss_impact")
		miss_payload = [pos, ratio]

	func draw_miss_text(_canvas: CanvasItem, draw_origin: Vector2, progress: float) -> void:
		calls.append("miss_text")
		miss_text_payload = [draw_origin, progress]

	func draw_self_stun(_canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
		calls.append("self_stun")
		self_stun_payload = [center, elapsed]


func _init() -> void:
	_verify_delegate_order_and_payloads()
	_verify_source_ownership()
	_verify_renderer_is_stateless()
	if _failures.is_empty():
		print("lingpet_headbutt_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_delegate_order_and_payloads() -> void:
	var skill := HeadbuttSkill.new()
	var renderer := SpyRenderer.new()
	skill.set("_renderer", renderer)
	skill.set("_active", true)
	skill.set("_ground_slam", true)
	skill.set("_pos", Vector2(300.0, 400.0))
	skill.set("_dash_radius", 44.0)
	skill.set("_dash_dir", Vector2(0.0, -1.0))
	skill.set("_dash_elapsed", 0.21)
	skill.set("_trail", [Vector2(280.0, 440.0), Vector2(300.0, 400.0)])
	skill.set("_impact_pos", Vector2(320.0, 120.0))
	skill.set("_impact_timer", HeadbuttSkill.IMPACT_SECONDS * 0.5)
	skill.set("_mega_impact", true)
	skill.set("_slam_radius", 180.0)
	skill.set("_target", Vector2(330.0, 70.0))
	skill.set("_hit_count", 3)
	skill.set("_miss_count", 2)
	skill.set("_miss_timer", HeadbuttSkill.MISS_FLASH_SECONDS * 0.25)
	skill.set("_miss_text_timer", HeadbuttSkill.MISS_TEXT_SECONDS * 0.75)
	skill.set("_miss_text_pos", Vector2(500.0, 260.0))
	skill.set("_mega_charge_timer", HeadbuttSkill.MEGA_CHARGE_SECONDS * 0.5)
	skill.set("_mega_charge_origin", Vector2(220.0, 420.0))
	skill.set("_self_stun_seconds", 3.0)
	skill.set("_self_stun_timer", 2.25)
	skill.set("_self_stun_pos", Vector2(620.0, 560.0))

	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == ["mega_charge", "dash", "hit_impact", "miss_impact", "miss_text", "self_stun"], "facade should preserve the exact effect draw order")
	_expect(_vector(renderer.mega_charge_payload, 0) == Vector2(224.0, 417.0), "mega charge should receive shaken center")
	_expect(is_equal_approx(_float(renderer.mega_charge_payload, 1), 0.5), "mega charge should receive normalized progress")
	_expect(is_equal_approx(_float(renderer.mega_charge_payload, 2), 1.0), "mega charge should receive elapsed charge time")
	_expect(bool(renderer.dash_payload[1]), "dash renderer should receive ground-slam mode")
	_expect(_vector(renderer.dash_payload, 3) == Vector2(300.0, 400.0), "dash renderer should receive unshaken runtime position")
	_expect(_vector(renderer.impact_payload, 0) == Vector2(324.0, 117.0), "impact renderer should receive shaken impact position")
	_expect(_vector(renderer.impact_payload, 1) == Vector2(320.0, 120.0), "impact renderer should receive the unshaken deterministic seed position")
	_expect(is_equal_approx(_float(renderer.impact_payload, 2), 0.5), "impact renderer should receive normalized remaining ratio")
	_expect(int(renderer.impact_payload[7]) == 5, "impact renderer should receive the stable hit+miss deterministic seed")
	_expect(is_equal_approx(_float(renderer.miss_payload, 1), 0.25), "miss impact should keep its independent timer ratio")
	_expect(is_equal_approx(_float(renderer.miss_text_payload, 1), 0.25), "MISS text should receive elapsed progress")
	_expect(is_equal_approx(_float(renderer.self_stun_payload, 1), 0.75), "self-stun renderer should receive elapsed stun time")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_headbutt_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_headbutt_renderer.gd")
	var draw_body := _method_source(skill_source, "draw")
	_expect(skill_source.contains("LingpetHeadbuttRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetHeadbuttRenderer.new()"), "skill should retain one renderer")
	_expect(draw_body.contains("_renderer.draw_mega_charge"), "draw facade should delegate mega charge")
	_expect(draw_body.contains("_renderer.draw_dash"), "draw facade should delegate dash rendering")
	_expect(draw_body.contains("_renderer.draw_hit_impact"), "draw facade should delegate ordered hit impact rendering")
	_expect(draw_body.contains("_renderer.draw_miss_text"), "draw facade should delegate MISS text")
	_expect(draw_body.contains("_renderer.draw_self_stun"), "draw facade should delegate self-stun rendering")
	_expect(not draw_body.contains("canvas.draw_"), "draw facade should not retain procedural recipes")
	_expect(not skill_source.contains("func _draw_dash("), "skill should not retain the dash recipe")
	_expect(not skill_source.contains("func _draw_ground_slam("), "skill should not retain the ground-slam recipe")
	_expect(renderer_source.contains("func draw_dash("), "renderer should own dash rendering")
	_expect(renderer_source.contains("func draw_hit_impact("), "renderer should own hit-impact composition")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own the CanvasItem primitives")
	_expect(skill_source.split("\n").size() < 1000, "renderer split should materially shrink the gameplay owner")


func _verify_renderer_is_stateless() -> void:
	var renderer := HeadbuttRenderer.new()
	_expect(renderer != null, "focused renderer should construct")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_headbutt_renderer.gd")
	_expect(not renderer_source.contains("var _active"), "renderer should not mirror active gameplay state")
	_expect(not renderer_source.contains("var _impact_timer"), "renderer should not mirror impact clocks")
	_expect(not renderer_source.contains("RandomNumberGenerator"), "renderer should not own RNG")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer animation should use runtime-owned clocks")


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _vector(values: Array, index: int) -> Vector2:
	var value: Variant = values[index] if index >= 0 and index < values.size() else Vector2.ZERO
	return value if value is Vector2 else Vector2.ZERO


func _float(values: Array, index: int) -> float:
	return float(values[index]) if index >= 0 and index < values.size() else 0.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
