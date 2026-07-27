extends SceneTree

const GatlingBurstRenderer := preload("res://scripts/lingpet/lingpet_gatling_burst_renderer.gd")
const GatlingBurstSkill := preload("res://scripts/lingpet/lingpet_gatling_burst_skill.gd")

var _failures: Array[String] = []


class SpyRenderer:
	var calls := 0
	var payload: Array = []

	func draw_gatling_burst(
		_canvas: CanvasItem,
		shake_offset: Vector2,
		active: bool,
		mounting: bool,
		dismounting: bool,
		tank_center: Vector2,
		aim_angle: float,
		recoil_offset: float,
		muzzle_flash_timer: float,
		mount_progress: float,
		dismount_progress: float,
		transform_frame_index: int,
		bullets: Array[Dictionary],
		hit_particles: Array[Dictionary],
		shell_casings: Array[Dictionary],
		smoke_puffs: Array[Dictionary]
	) -> void:
		calls += 1
		payload = [
			shake_offset,
			active,
			mounting,
			dismounting,
			tank_center,
			aim_angle,
			recoil_offset,
			muzzle_flash_timer,
			mount_progress,
			dismount_progress,
			transform_frame_index,
			bullets,
			hit_particles,
			shell_casings,
			smoke_puffs,
		]


func _init() -> void:
	_verify_facade_payloads_and_borrowed_collections()
	_verify_render_tuning_contract()
	_verify_source_ownership()
	if _failures.is_empty():
		print("lingpet_gatling_burst_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_facade_payloads_and_borrowed_collections() -> void:
	var skill := GatlingBurstSkill.new()
	var renderer := SpyRenderer.new()
	var bullets: Array[Dictionary] = [{"kind": "bullet"}]
	var hit_particles: Array[Dictionary] = [{"kind": "hit"}]
	var shell_casings: Array[Dictionary] = [{"kind": "casing"}]
	var smoke_puffs: Array[Dictionary] = [{"kind": "smoke"}]
	skill.set("_renderer", renderer)
	skill.set("_phase", "mounting")
	skill.set("_phase_timer", 0.50)
	skill.set("_body_pos", Vector2(380.0, 640.0))
	skill.set("_aim_angle", -PI * 0.5)
	skill.set("_recoil_offset", 2.0)
	skill.set("_muzzle_flash_timer", 0.04)
	skill.set("_bullets", bullets)
	skill.set("_hit_particles", hit_particles)
	skill.set("_shell_casings", shell_casings)
	skill.set("_smoke_puffs", smoke_puffs)
	var canvas := Node2D.new()
	skill.draw(canvas, Vector2(4.0, -3.0))
	canvas.free()
	_expect(renderer.calls == 1, "facade should delegate Gatling Burst composition exactly once")
	_expect(renderer.payload[0] == Vector2(4.0, -3.0), "facade should forward shake offset")
	_expect(bool(renderer.payload[1]) and bool(renderer.payload[2]) and not bool(renderer.payload[3]), "facade should forward active mounting state")
	_expect(renderer.payload[4] is Vector2, "facade should forward the gameplay-aligned tank center")
	_expect(is_equal_approx(float(renderer.payload[5]), -PI * 0.5), "renderer should receive the current aim angle")
	_expect(is_equal_approx(float(renderer.payload[6]), 2.0), "renderer should receive recoil")
	_expect(is_equal_approx(float(renderer.payload[7]), 0.04), "renderer should receive muzzle-flash time")
	_expect(is_equal_approx(float(renderer.payload[8]), 0.5), "renderer should receive mount progress")
	_expect(int(renderer.payload[10]) == 6, "renderer should receive the original half-mounted transform frame")
	_expect(renderer.payload[11] == bullets, "renderer should borrow the live bullet array")
	_expect(renderer.payload[12] == hit_particles, "renderer should borrow the live hit-particle array")
	_expect(renderer.payload[13] == shell_casings, "renderer should borrow the live shell-casing array")
	_expect(renderer.payload[14] == smoke_puffs, "renderer should borrow the live smoke array")


func _verify_render_tuning_contract() -> void:
	var tuning: Dictionary = GatlingBurstRenderer.new().get_visual_tuning_for_tests()
	_expect(is_equal_approx(float(tuning.get("tank_draw_size", 0.0)), 96.0), "renderer should preserve the 96px tank draw size")
	_expect(float(tuning.get("tank_visual_scale", 1.0)) < 0.82, "renderer should preserve the scaled Volty-body footprint")
	_expect(int(tuning.get("transform_frame_count", 0)) == 25, "renderer should preserve the 25-frame transform sheet")
	_expect(int(tuning.get("transform_chassis_frame_index", -1)) == 11, "renderer should preserve the no-baked-barrel chassis frame")


func _verify_source_ownership() -> void:
	var skill_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_gatling_burst_skill.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_gatling_burst_renderer.gd")
	var skill_draw := _method_source(skill_source, "draw")
	var renderer_draw := _method_source(renderer_source, "draw_gatling_burst")
	_expect(skill_source.contains("LingpetGatlingBurstRenderer"), "skill should preload the focused renderer")
	_expect(skill_source.contains("var _renderer: Object = LingpetGatlingBurstRenderer.new()"), "skill should retain one renderer")
	_expect(skill_source.contains("_renderer.prewarm()"), "skill prewarm should delegate render resources")
	_expect(not skill_draw.contains("canvas.draw_"), "facade should retain no CanvasItem recipe")
	_expect(not skill_draw.contains(".duplicate("), "facade should not copy live render collections")
	_expect(skill_source.contains("func _fire_bullet("), "gameplay owner should retain bullet launch and spread RNG")
	_expect(skill_source.contains("func _update_bullets("), "gameplay owner should retain bullet movement and collision")
	_expect(skill_source.contains("func _apply_boss_ak47_hit_status("), "gameplay owner should retain boss status application")
	for method_name in [
		"_draw_tank_body",
		"_draw_transform_frame",
		"_draw_cannon_overlay",
		"_draw_fallback_tank",
		"_draw_mount_bar",
		"_draw_bullets",
		"_draw_hit_particles",
		"_draw_shell_casings",
		"_draw_smoke",
	]:
		_expect(not skill_source.contains("func %s(" % method_name), "gameplay owner should not retain %s" % method_name)
	_expect(renderer_source.contains("ProjectResourceLoader.load_texture"), "renderer should own transform-sheet loading")
	_expect(renderer_source.contains("canvas.draw_"), "renderer should own CanvasItem primitives")
	_expect(not renderer_source.contains("Time.get_ticks"), "renderer should retain no wall clock")
	_expect(not renderer_source.contains("randf") and not renderer_source.contains("randi"), "renderer should retain no RNG calls")
	_expect(not renderer_source.contains("var _bullets"), "renderer should not retain the borrowed bullet array")
	_expect(not renderer_source.contains("var _hit_particles"), "renderer should not retain the borrowed hit-particle array")
	_expect(not renderer_source.contains("var _shell_casings"), "renderer should not retain the borrowed casing array")
	_expect(not renderer_source.contains("var _smoke_puffs"), "renderer should not retain the borrowed smoke array")
	var smoke_pass := renderer_draw.find("_draw_smoke")
	var bullet_pass := renderer_draw.find("_draw_bullets")
	var hit_pass := renderer_draw.find("_draw_hit_particles")
	var casing_pass := renderer_draw.find("_draw_shell_casings")
	var tank_pass := renderer_draw.find("_draw_tank_body")
	_expect(smoke_pass >= 0 and smoke_pass < bullet_pass, "renderer should preserve smoke -> bullet order")
	_expect(bullet_pass < hit_pass and hit_pass < casing_pass, "renderer should preserve bullet -> hit -> casing order")
	_expect(casing_pass < tank_pass, "renderer should preserve effects -> tank order")
	_expect(skill_source.split("\n").size() < 570, "renderer split should materially shrink the mixed gameplay owner")


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
