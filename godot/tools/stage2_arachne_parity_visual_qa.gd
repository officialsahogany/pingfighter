extends SceneTree

const Stage2ArachneBossState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const Stage2VariantBossRenderer := preload("res://scripts/stages/stage2/stage2_variant_boss_renderer.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const PLAYFIELD_SCALE := 1246.0 / 750.0
const SCALED_GAME_SIZE := PLAYFIELD_SIZE * PLAYFIELD_SCALE
const GAME_OFFSET := Vector2((2020.0 - SCALED_GAME_SIZE.x) * 0.5, 0.0)
const OUTPUT_DIR := "res://.godot/codex_captures/stage2_arachne_parity_2020x1246"
const BACKGROUND := Color("101820")
const PLAYFIELD_BACKGROUND := Color("15232c")


class CaptureCanvas:
	extends Node2D
	var draw_callback: Callable

	func _init(callback: Callable) -> void:
		draw_callback = callback

	func _draw() -> void:
		draw_callback.call(self)


var _variant_renderer: Object
var _hud_renderer: Object
var _viewport: SubViewport
var _canvas: CaptureCanvas
var _draw_context: Dictionary = {}
var _draw_hud := false
var _saved_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("stage2_arachne_parity_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("stage2_arachne_parity_visual_qa requires a Vulkan rendering device")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		_fail("could not create the Arachne parity capture directory")
		return
	_variant_renderer = Stage2VariantBossRenderer.new()
	_hud_renderer = Stage2BossSkillHudRenderer.new()
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_canvas = CaptureCanvas.new(Callable(self, "_draw_capture"))
	_viewport.add_child(_canvas)

	await _capture("01_rescue_shoot", _build_rescue_context("shoot", 0.62), false)
	await _capture("02_rescue_strike", _build_rescue_context("strike", 0.42), false)
	await _capture("03_hud_progress", _build_hud_progress_context(), true)
	await _capture("04_rage_non_overlap", _build_rage_non_overlap_context(), false)
	await _capture("05_gait_hit_venom", _build_gait_hit_context(), false)
	if _saved_paths.size() != 5:
		_fail("expected five Arachne parity captures, saved %d" % _saved_paths.size())
		return
	print("[Stage2ArachneParityVisualQA] resolution=%dx%d captures=%d" % [VIEW_SIZE.x, VIEW_SIZE.y, _saved_paths.size()])
	for path in _saved_paths:
		print("[Stage2ArachneParityVisualQA] evidence=%s" % ProjectSettings.globalize_path(path))
	print("stage2_arachne_parity_visual_qa: ok")
	quit(0)


func _capture(label: String, context: Dictionary, draw_hud: bool) -> void:
	_draw_context = context
	_draw_hud = draw_hud
	_canvas.queue_redraw()
	for _frame in range(5):
		await process_frame
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_fail("%s did not produce a 2020x1246 framebuffer" % label)
		return
	if _count_non_background_pixels(image) < 2800:
		_fail("%s did not contain enough production-rendered pixels" % label)
		return
	var output_path := OUTPUT_DIR.path_join("%s.png" % label)
	if image.save_png(output_path) != OK:
		_fail("could not save %s" % output_path)
		return
	_saved_paths.append(output_path)


func _draw_capture(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND, true)
	canvas.draw_rect(Rect2(GAME_OFFSET, SCALED_GAME_SIZE), Color(0.03, 0.05, 0.07, 1.0), true)
	canvas.draw_set_transform(GAME_OFFSET, 0.0, Vector2.ONE * PLAYFIELD_SCALE)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), PLAYFIELD_BACKGROUND, true)
	_variant_renderer.draw(canvas, _draw_context)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _draw_hud:
		_hud_renderer.draw(canvas, _draw_context)


func _build_base_context(state: Object) -> Dictionary:
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "arachne",
		"boss_pos": Vector2(315.0, 25.0),
		"boss_draw_pos": Vector2(315.0, 25.0),
		"boss_paddle_width": 130.0,
		"boss_hitbox_height": 52.0,
		"boss_paddle_size": Vector2(130.0, 52.0),
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(366.0, 12.0),
		"ball_vel": Vector2(1.5, -8.0),
		"ball_size": 28.6,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"dash_snapshot": {"active": false},
	}
	state.update(0.0, context, {})
	return context


func _build_rescue_context(phase: String, progress: float) -> Dictionary:
	var state: Object = Stage2ArachneBossState.new()
	var context := _build_base_context(state)
	state.web_rescue_active = true
	state.web_rescue_phase = phase
	state.web_rescue_timer = progress * _get_rescue_phase_duration(phase)
	state.web_rescue_ball_pos = Vector2(380.0, 14.0)
	context.merge(state.get_actor_draw_context(), true)
	state = null
	return context


func _build_hud_progress_context() -> Dictionary:
	var state: Object = Stage2ArachneBossState.new()
	var context := _build_base_context(state)
	state.web_trap_cooldown = 7.5
	state.web_rescue_cooldown = 18.75
	var hud_context: Dictionary = state.get_hud_context()
	var skills: Array = hud_context.get("stage2_boss_skill_hud_skills", [])
	if skills.size() < 2 or not is_equal_approx(float(skills[0].get("progress", -1.0)), 0.5):
		_fail("HUD producer did not expose the expected 50-percent Arachne progress")
		return context
	context.merge(state.get_actor_draw_context(), true)
	context.merge(hud_context, true)
	context["view_size"] = Vector2(VIEW_SIZE)
	context["game_offset"] = GAME_OFFSET
	context["game_size"] = SCALED_GAME_SIZE
	context["commando_firearm_panel_rect"] = Rect2()
	state = null
	return context


func _build_rage_non_overlap_context() -> Dictionary:
	var state: Object = Stage2ArachneBossState.new()
	var context := _build_base_context(state)
	state.rng.seed = 918273
	state.web_traps = [
		{"pos": Vector2(250.0, 680.0), "radius": 50.0, "remaining": 4.0, "expand": 0.0, "rage": false, "golden": false},
		{"pos": Vector2(500.0, 680.0), "radius": 50.0, "remaining": 4.0, "expand": 0.0, "rage": false, "golden": true},
	]
	state._build_rage_targets()
	var occupied_x: Array[float] = [250.0, 500.0]
	for target_x: float in state.rage_targets:
		for existing_x: float in occupied_x:
			if absf(target_x - existing_x) < 100.0:
				_fail("rage target %.1f overlaps occupied web %.1f" % [target_x, existing_x])
				return context
		occupied_x.append(target_x)
		state.web_traps.append({
			"pos": Vector2(target_x, 680.0),
			"radius": 50.0,
			"remaining": -1.0,
			"expand": 0.0,
			"rage": true,
			"golden": false,
		})
	state.rage_active = true
	state.rage_red_tint = 0.72
	context.merge(state.get_actor_draw_context(), true)
	state = null
	return context


func _build_gait_hit_context() -> Dictionary:
	var state: Object = Stage2ArachneBossState.new()
	var context := _build_base_context(state)
	context["boss_pos"] = Vector2(329.0, 25.0)
	context["boss_draw_pos"] = context["boss_pos"]
	state.update(1.0 / 60.0, context, {})
	context["ball_pos"] = Vector2(455.0, 70.0)
	state.register_boss_hit(Vector2(-3.0, 8.0), context, {})
	state.update(0.05, context, {})
	state.update(0.05, context, {})
	context.merge(state.get_actor_draw_context(), true)
	state = null
	return context


func _get_rescue_phase_duration(phase: String) -> float:
	match phase:
		"shoot":
			return 15.0 / 60.0
		"strike":
			return 8.0 / 60.0
	return 1.0


func _count_non_background_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var delta := absf(pixel.r - BACKGROUND.r) + absf(pixel.g - BACKGROUND.g) + absf(pixel.b - BACKGROUND.b)
			if delta > 0.04:
				count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
