extends SceneTree

const Stage2ActorRenderer := preload("res://scripts/stages/stage2/stage2_actor_renderer.gd")
const Stage2BossVariantSkillState := preload("res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd")

const VIEW_SIZE := Vector2i(760, 750)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_unported_bosses"


class NoopRenderer:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary, _shake_offset: Vector2 = Vector2.ZERO, _perf_logger: Object = null) -> void:
		pass


class BossCaptureCanvas:
	extends Node2D
	var renderer: Object
	var draw_context: Dictionary

	func _init(value: Object, context: Dictionary) -> void:
		renderer = value
		draw_context = context

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("121a21"), true)
		renderer.draw(self, draw_context)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("stage_boss_variant_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("stage_boss_variant_visual_qa requires a Vulkan rendering device")
		return
	var variant := _get_variant_argument()
	if variant not in ["molewang", "arachne"]:
		_fail("unsupported visual QA variant: %s" % variant)
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create visual QA output directory")
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var renderer := Stage2ActorRenderer.new()
	renderer.playfield_renderer = NoopRenderer.new()
	renderer.player_renderer = NoopRenderer.new()
	renderer.commando_firearm_renderer = NoopRenderer.new()
	var state := Stage2BossVariantSkillState.new()
	var context := _build_molewang_context(state) if variant == "molewang" else _build_arachne_context(state)
	var canvas := BossCaptureCanvas.new(renderer, context)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(8):
		await process_frame
	var image := viewport.get_texture().get_image()
	var output_path := output_dir.path_join("%s.png" % variant)
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		_fail("visual QA capture failed: %s" % output_path)
		return
	if _count_non_background_pixels(image, Color("121a21")) < 900:
		_fail("visual QA capture did not contain enough rendered boss pixels")
		return
	print("[StageBossVariantVisualQA] variant=%s evidence=%s" % [variant, output_path])
	print("stage_boss_variant_visual_qa: ok")
	quit(0)


func _build_molewang_context(state: Object) -> Dictionary:
	state.update(0.0, {
		"current_stage": 2,
		"stage_boss_variant": "molewang",
		"ball_active": true,
		"waiting_for_serve": false,
	}, {})
	state.molewang_state.tunnel_active = true
	state.molewang_state.tunnel_phase = "strike"
	state.molewang_state.tunnel_timer = 0.18
	state.molewang_state.tunnel_target_x = 380.0
	state.molewang_state.spinning_claw_timer = 0.30
	state.molewang_state.friend_moles = [
		{"pos": Vector2(180.0, 480.0), "age": 0.45, "golden": true, "hit": false},
		{"pos": Vector2(585.0, 590.0), "age": 0.75, "golden": true, "hit": false},
	]
	for index in range(10):
		state.molewang_state.tunnel_spikes.append({
			"pos": Vector2(340.0 + float(index) * 7.0, 100.0 + float(index) * 55.0),
			"height": 36.0 + float(index % 4) * 7.0,
			"width": 6.0,
			"age": 0.18,
			"life": 1.05,
		})
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "molewang",
		"boss_pos": Vector2(330.0, 25.0),
		"boss_draw_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"shake_offset": Vector2.ZERO,
	}
	context.merge(state.get_actor_draw_context(), true)
	return context


func _build_arachne_context(state: Object) -> Dictionary:
	state.update(0.0, {
		"current_stage": 2,
		"stage_boss_variant": "arachne",
		"ball_active": true,
		"waiting_for_serve": false,
	}, {})
	state.arachne_state.hit_timer = 0.30
	state.arachne_state.rage_active = true
	state.arachne_state.rage_red_tint = 0.65
	state.arachne_state.rage_stomp_offset_y = 5.0
	state.arachne_state.web_traps = [
		{"pos": Vector2(170.0, 690.0), "radius": 50.0, "remaining": 3.0, "expand": 0.0, "golden": false, "rage": false},
		{"pos": Vector2(390.0, 705.0), "radius": 50.0, "remaining": -1.0, "expand": 0.0, "golden": false, "rage": true},
		{"pos": Vector2(605.0, 690.0), "radius": 50.0, "remaining": -1.0, "expand": 0.0, "golden": true, "rage": true},
	]
	state.arachne_state.web_trap_projectile = {
		"start": Vector2(380.0, 82.0), "target": Vector2(170.0, 690.0),
		"age": 0.36, "duration": 35.0 / 60.0, "golden": false, "rage": false,
	}
	state.arachne_state.rage_projectiles = [{
		"start": Vector2(380.0, 82.0), "target": Vector2(605.0, 690.0),
		"age": 0.28, "duration": 35.0 / 60.0, "golden": true, "rage": true,
	}]
	state.arachne_state.web_rescue_active = true
	state.arachne_state.web_rescue_phase = "hold_wait"
	state.arachne_state.web_rescue_timer = 0.4
	state.arachne_state.web_rescue_ball_pos = Vector2(380.0, 210.0)
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "arachne",
		"boss_pos": Vector2(315.0, 25.0),
		"boss_draw_pos": Vector2(315.0, 25.0),
		"boss_paddle_size": Vector2(130.0, 52.0),
		"shake_offset": Vector2.ZERO,
	}
	context.merge(state.get_actor_draw_context(), true)
	return context


func _count_non_background_pixels(image: Image, background: Color) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var color_delta := absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b)
			if color_delta > 0.04:
				count += 1
	return count


func _get_variant_argument() -> String:
	for argument in OS.get_cmdline_user_args():
		var value := str(argument)
		if value.begins_with("--boss-variant="):
			return value.trim_prefix("--boss-variant=").strip_edges().to_lower()
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
