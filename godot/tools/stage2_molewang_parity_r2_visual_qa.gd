extends SceneTree

const Stage2MolewangBossState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const Stage2VariantBossRenderer := preload("res://scripts/stages/stage2/stage2_variant_boss_renderer.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const PLAYFIELD_SCALE := 1246.0 / 750.0
const SCALED_GAME_SIZE := PLAYFIELD_SIZE * PLAYFIELD_SCALE
const GAME_OFFSET := Vector2((2020.0 - SCALED_GAME_SIZE.x) * 0.5, 0.0)
const OUTPUT_DIR := "res://.godot/codex_captures/stage2_molewang_parity_r2_2020x1246"
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
var _saved_paths: Array[String] = []
var _capture_hashes: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("stage2_molewang_parity_r2_visual_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("stage2_molewang_parity_r2_visual_qa requires a Vulkan rendering device")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) != OK:
		_fail("could not create the Molewang parity capture directory")
		return
	_variant_renderer = Stage2VariantBossRenderer.new()
	_hud_renderer = Stage2BossSkillHudRenderer.new()
	_hud_renderer.prewarm_assets()
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_canvas = CaptureCanvas.new(Callable(self, "_draw_capture"))
	_viewport.add_child(_canvas)

	await _capture("01_spinning_claw_left_final_plus_1", _build_claw_context(true))
	await _capture("02_spinning_claw_right_final_minus_1", _build_claw_context(false))
	var friend_contexts := _build_friend_mole_contexts()
	if friend_contexts.is_empty():
		return
	await _capture("03_friend_moles_active_720_ticks", friend_contexts["active"])
	await _capture("04_friend_moles_ended_after_720_ticks", friend_contexts["ended"])
	if _saved_paths.size() != 4:
		_fail("expected four Molewang parity captures, saved %d" % _saved_paths.size())
		return
	if int(_capture_hashes.get("01_spinning_claw_left_final_plus_1", 0)) == int(_capture_hashes.get("02_spinning_claw_right_final_minus_1", 0)):
		_fail("left and right Spinning Claw captures must differ")
		return
	if int(_capture_hashes.get("03_friend_moles_active_720_ticks", 0)) == int(_capture_hashes.get("04_friend_moles_ended_after_720_ticks", 0)):
		_fail("active and ended friend-mole captures must differ")
		return
	print("[Stage2MolewangParityR2VisualQA] renderer=vulkan resolution=%dx%d captures=%d" % [VIEW_SIZE.x, VIEW_SIZE.y, _saved_paths.size()])
	for path in _saved_paths:
		print("[Stage2MolewangParityR2VisualQA] evidence=%s" % ProjectSettings.globalize_path(path))
	print("stage2_molewang_parity_r2_visual_qa: ok")
	quit(0)


func _capture(label: String, context: Dictionary) -> void:
	_draw_context = context
	_canvas.queue_redraw()
	for _frame in range(5):
		await process_frame
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_fail("%s did not produce a 2020x1246 framebuffer" % label)
		return
	var output_path := OUTPUT_DIR.path_join("%s.png" % label)
	if image.save_png(output_path) != OK:
		_fail("could not save %s" % output_path)
		return
	_capture_hashes[label] = hash(image.get_data())
	_saved_paths.append(output_path)


func _draw_capture(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), BACKGROUND, true)
	canvas.draw_rect(Rect2(GAME_OFFSET, SCALED_GAME_SIZE), Color(0.03, 0.05, 0.07, 1.0), true)
	canvas.draw_set_transform(GAME_OFFSET, 0.0, Vector2.ONE * PLAYFIELD_SCALE)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), PLAYFIELD_BACKGROUND, true)
	_variant_renderer.draw(canvas, _draw_context)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_hud_renderer.draw(canvas, _draw_context)


func _build_base_context() -> Dictionary:
	return {
		"current_stage": 2,
		"stage_boss_variant": "molewang",
		"boss_pos": Vector2(330.0, 25.0),
		"boss_draw_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 124.0,
		"boss_hitbox_height": 40.0,
		"boss_paddle_size": Vector2(124.0, 40.0),
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(330.0, 110.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_size": 32.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"view_size": Vector2(VIEW_SIZE),
		"game_offset": GAME_OFFSET,
		"game_size": SCALED_GAME_SIZE,
		"commando_firearm_panel_rect": Rect2(),
	}


func _build_claw_context(ball_is_left_of_boss: bool) -> Dictionary:
	var state := Stage2MolewangBossState.new()
	var context := _build_base_context()
	context["ball_pos"] = Vector2(330.0 if ball_is_left_of_boss else 470.0, 110.0)
	var result: Dictionary = state.register_boss_hit(Vector2(0.0, -8.0), context, {})
	var expected_direction := 1 if ball_is_left_of_boss else -1
	if int(result.get("ball_spin_direction", 0)) != expected_direction:
		_fail("Spinning Claw state did not produce expected direction %d" % expected_direction)
		return context
	state.update(0.05, context, {})
	context.merge(state.get_actor_draw_context(), true)
	context.merge(state.get_hud_context(null, context), true)
	state = null
	return context


func _build_friend_mole_contexts() -> Dictionary:
	var state := Stage2MolewangBossState.new()
	var context := _build_base_context()
	state.handle_score_event("player", {"player_score": 4})
	state.reset_round()
	state.update(0.0, context, {})
	if not state.friend_moles_active or state.friend_moles_duration_ticks_remaining != 720:
		_fail("friend moles did not activate with the 720-tick duration")
		return {}
	for _index in range(116):
		state.update(1.0 / 72.0, context, {})
	if state.friend_moles.is_empty():
		_fail("friend moles did not produce an actor for the active capture")
		return {}
	var active_context := context.duplicate(true)
	active_context.merge(state.get_actor_draw_context(), true)
	active_context.merge(state.get_hud_context(null, context), true)
	var guard := 0
	while state.friend_moles_active and guard < 720:
		state.update(0.0, context, {})
		guard += 1
	if state.friend_moles_active or not state.friend_moles.is_empty() or not state.friend_mole_particles.is_empty():
		_fail("the 720-tick end boundary left detached friend-mole visuals")
		return {}
	var ended_context := context.duplicate(true)
	ended_context.merge(state.get_actor_draw_context(), true)
	ended_context.merge(state.get_hud_context(null, context), true)
	state = null
	return {"active": active_context, "ended": ended_context}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
