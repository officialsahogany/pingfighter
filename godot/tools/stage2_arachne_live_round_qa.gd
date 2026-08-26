extends SceneTree

const Stage2BossVariantSkillState := preload("res://scripts/stages/stage2/stage2_boss_variant_skill_state.gd")
const Stage2VariantBossRenderer := preload("res://scripts/stages/stage2/stage2_variant_boss_renderer.gd")
const Stage2BossSkillHudRenderer := preload("res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const PLAYFIELD_SIZE := Vector2(760.0, 750.0)
const PLAYFIELD_SCALE := 1246.0 / 750.0
const SCALED_GAME_SIZE := PLAYFIELD_SIZE * PLAYFIELD_SCALE
const GAME_OFFSET := Vector2((2020.0 - SCALED_GAME_SIZE.x) * 0.5, 0.0)
const OUTPUT_PATH := "res://.godot/codex_captures/stage2_arachne_parity_2020x1246/06_live_round_strike.png"
const REQUIRED_PHASES := ["shoot", "hold_wait", "pull", "hold", "strike"]


class LiveCanvas:
	extends Node2D
	var draw_callback: Callable

	func _init(callback: Callable) -> void:
		draw_callback = callback

	func _draw() -> void:
		draw_callback.call(self)


var _state: Object
var _variant_renderer: Object
var _hud_renderer: Object
var _viewport: SubViewport
var _canvas: LiveCanvas
var _context: Dictionary
var _draw_context: Dictionary = {}
var _phase_frames := {}
var _phase_order: Array[String] = []
var _strike_capture_saved := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("stage2_arachne_live_round_qa requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("stage2_arachne_live_round_qa requires a Vulkan rendering device")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir())) != OK:
		_fail("could not create live-round evidence directory")
		return
	_state = Stage2BossVariantSkillState.new()
	_variant_renderer = Stage2VariantBossRenderer.new()
	_hud_renderer = Stage2BossSkillHudRenderer.new()
	_hud_renderer.prewarm_assets()
	_context = {
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
	_state.update(0.0, _context, {})
	_state.arachne_state.boss_special_gauge = 50.0
	_state.arachne_state.web_rescue_cooldown = 0.0
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_canvas = LiveCanvas.new(Callable(self, "_draw_live_round"))
	_viewport.add_child(_canvas)

	var released := false
	for frame_index in range(300):
		var boss_x := 315.0 + sin(float(frame_index) * 0.045) * 72.0
		_context["boss_pos"] = Vector2(boss_x, 25.0)
		_context["boss_draw_pos"] = _context["boss_pos"]
		var result: Dictionary = _state.update(1.0 / 60.0, _context, {})
		if result.has("ball_pos"):
			_context["ball_pos"] = result["ball_pos"]
		if result.has("ball_vel"):
			_context["ball_vel"] = result["ball_vel"]
		var phase := str(_state.arachne_state.web_rescue_phase)
		if _state.arachne_state.web_rescue_active and phase in REQUIRED_PHASES:
			_phase_frames[phase] = int(_phase_frames.get(phase, 0)) + 1
			if _phase_order.is_empty() or _phase_order.back() != phase:
				_phase_order.append(phase)
		_draw_context = _context.duplicate(true)
		_draw_context.merge(_state.get_actor_draw_context(), true)
		_draw_context.merge(_state.get_hud_context(null, _context), true)
		_draw_context["view_size"] = Vector2(VIEW_SIZE)
		_draw_context["game_offset"] = GAME_OFFSET
		_draw_context["game_size"] = SCALED_GAME_SIZE
		_draw_context["commando_firearm_panel_rect"] = Rect2()
		_canvas.queue_redraw()
		await process_frame
		if phase == "strike" and int(_phase_frames.get("strike", 0)) >= 3 and not _strike_capture_saved:
			var image := _viewport.get_texture().get_image()
			if image == null or image.is_empty() or image.get_size() != VIEW_SIZE or image.save_png(OUTPUT_PATH) != OK:
				_fail("could not save live Arachne strike evidence")
				return
			_strike_capture_saved = true
		if not _state.arachne_state.web_rescue_active and _phase_order.size() == REQUIRED_PHASES.size():
			released = true
			break

	if not released:
		_fail("live Arachne round did not release the rescued ball")
		return
	if _phase_order != REQUIRED_PHASES:
		_fail("live rescue phase order mismatch: %s" % str(_phase_order))
		return
	for phase: String in REQUIRED_PHASES:
		if int(_phase_frames.get(phase, 0)) <= 0:
			_fail("live rescue phase was not visibly rendered: %s" % phase)
			return
	if not _strike_capture_saved:
		_fail("live rescue strike capture was not saved")
		return
	if _state.arachne_state.boss_special_gauge != 0.0 or _state.arachne_state.web_rescue_cooldown <= 20.0 or _state.arachne_state.web_rescue_cooldown > 25.0:
		_fail("live rescue did not consume gauge and arm cooldown")
		return
	var release_velocity: Vector2 = _context.get("ball_vel", Vector2.ZERO)
	if release_velocity.length() < 17.5 or release_velocity.y <= 0.0:
		_fail("live rescue did not release the ball toward the player")
		return
	print("[Stage2ArachneLiveRoundQA] phase_order=%s phase_frames=%s" % [str(_phase_order), str(_phase_frames)])
	print("[Stage2ArachneLiveRoundQA] release_velocity=%s cooldown=%.3f evidence=%s" % [str(release_velocity), _state.arachne_state.web_rescue_cooldown, ProjectSettings.globalize_path(OUTPUT_PATH)])
	print("stage2_arachne_live_round_qa: ok")
	quit(0)


func _draw_live_round(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("101820"), true)
	canvas.draw_set_transform(GAME_OFFSET, 0.0, Vector2.ONE * PLAYFIELD_SCALE)
	canvas.draw_rect(Rect2(Vector2.ZERO, PLAYFIELD_SIZE), Color("15232c"), true)
	_variant_renderer.draw(canvas, _draw_context)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_hud_renderer.draw(canvas, _draw_context)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
