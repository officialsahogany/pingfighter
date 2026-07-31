extends SceneTree

# Windowed production-path QA for Viper's Wall-Leap Night Raid. This uses the
# real desktop input reader, Viper player controller, collision detector, and
# skill tooltip renderer. Run without --headless.

const Support := preload("res://tests/wall_leap_test_support.gd")
const ViperInputReader := preload("res://scripts/characters/viper_input_reader.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const VIEW_SIZE := Vector2i(1200, 800)
const OUT_PATH := "res://.godot/codex_logs/wall_leap_windowed_qa.png"

var _support := Support.new()
var _failures: Array[String] = []
var _frame_counter := 0


class JetpackProbe:
	extends RefCounted
	var update_count := 0
	func is_airborne(_minimum_height: float = 0.0) -> bool:
		return false
	func get_movement_bonus_multiplier() -> float:
		return 1.0
	func update(_delta: float, player_pos: Vector2, _config: Dictionary, _deps: Dictionary) -> Dictionary:
		update_count += 1
		return {"player_pos": player_pos, "viper_jetpack_active": false}


class QACanvas:
	extends Node2D
	var tooltip_renderer: Object
	var player_sprite_renderer: Object
	var skill_data: Dictionary = {}
	var player_actor_context: Dictionary = {}
	var arc_points: PackedVector2Array = PackedVector2Array()
	var infiltrating_pos := Vector2.ZERO
	var body_passthrough := false
	var floor_save_live := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.025, 0.035, 0.065), true)
		var playfield := Rect2(20.0, 20.0, 760.0, 750.0)
		draw_rect(playfield, Color(0.055, 0.085, 0.13), true)
		draw_rect(playfield, Color(0.22, 0.70, 0.80), false, 2.0)
		var shifted := PackedVector2Array()
		for point in arc_points:
			shifted.append(point + Vector2(20.0, 20.0))
		if shifted.size() >= 2:
			draw_polyline(shifted, Color(0.30, 0.82, 0.92, 0.82), 4.0, true)
		var boss_rect := Rect2(Vector2(327.5, 25.0) + Vector2(20.0, 20.0), Vector2(100.0, 40.0))
		draw_rect(boss_rect, Color(0.95, 0.28, 0.34), true)
		var player_rect := Rect2(infiltrating_pos + Vector2(20.0, 20.0), Vector2(155.0, 50.0))
		# The body is drawn by the shipped player renderer so the capture proves
		# player_sprite_modulate reaches a real production draw consumer.
		player_sprite_renderer.draw_fallback(self, player_actor_context, player_rect.position, player_rect.size, Vector2.ZERO)
		draw_rect(player_rect, Color(0.75, 0.96, 1.0), false, 2.0)
		var barrier_rect := Rect2(Vector2(20.0, 745.0), Vector2(760.0, 20.0))
		draw_rect(barrier_rect, Color(0.95, 0.84, 0.36, 0.72), true)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(38.0, 48.0), "RMB entry -> LMB slash -> return", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
		draw_string(font, Vector2(38.0, 72.0), "body pass-through: %s | floor save: %s" % [str(body_passthrough), str(floor_save_live)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.82, 0.92, 1.0))
		var hover_context := {
			"scale_factor": 1.0,
			"view_size": Vector2(VIEW_SIZE),
			"game_offset": Vector2.ZERO,
			"mouse_pos": Vector2(1030.0, 390.0),
			"selected_character_type": "viper",
			"special_gauge": 500.0,
		}
		tooltip_renderer.call("_draw_tooltip", self, hover_context, skill_data)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		_fail("windowed renderer required")
		_finish()
		return
	LanguageSettings.set_test_locale_override("ko")
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE

	var fixture: Dictionary = _support.make_fixture()
	var input_reader := ViperInputReader.new()
	var jetpack := JetpackProbe.new()
	var dash_state := SmasherDashState.new()
	fixture["deps"]["input_reader"] = input_reader
	fixture["deps"]["viper_jetpack_state"] = jetpack
	fixture["deps"]["dash_state"] = dash_state
	fixture["registry"].instances["viper_input_reader"] = input_reader
	fixture["registry"].instances["viper_jetpack_state"] = jetpack
	fixture["registry"].instances["smasher_dash_state"] = dash_state
	var controller := ViperPlayerController.new()

	var arc_points := PackedVector2Array([fixture["player_pos"]])
	await _set_mouse(MOUSE_BUTTON_RIGHT, true)
	var rmb_snapshot: Dictionary = input_reader.get_snapshot()
	_expect(bool(rmb_snapshot.get("secondary_action_pressed", false)), "desktop RMB must reach secondary_action_pressed")
	_expect(bool(rmb_snapshot.get("secondary_action_just_pressed", false)), "desktop RMB edge must reach secondary_action_just_pressed")
	var entry_result: Dictionary = _step_controller(fixture, controller)
	_expect(bool(entry_result.get("activated", false)), "RMB must enter through ViperPlayerController")
	_expect(is_equal_approx(float(fixture["special_gauge"]), 400.0), "entry must spend 100 gauge")
	await _set_mouse(MOUSE_BUTTON_RIGHT, false)
	_step_controller(fixture, controller)
	var arc_deviation_seen := false
	for _index in range(28):
		await physics_frame
		_step_controller(fixture, controller)
		var snapshot: Dictionary = fixture["runtime"].get_snapshot()
		arc_points.append(snapshot.get("wall_leap_raid_current_pos", fixture["player_pos"]))
		if str(snapshot.get("wall_leap_raid_state", "")) == "infiltrate_in":
			var t := clampf(float(snapshot.get("wall_leap_raid_elapsed_seconds", 0.0)) / 0.22, 0.0, 1.0)
			var linear_pos := Vector2(300.0, 680.0).lerp(Vector2(300.0, 25.0), t)
			if (snapshot.get("wall_leap_raid_current_pos", Vector2.ZERO) as Vector2).distance_to(linear_pos) > 20.0:
				arc_deviation_seen = true
		if str(snapshot.get("wall_leap_raid_state", "")) == "infiltrating":
			break
	var infiltrating_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var infiltrating_pos: Vector2 = infiltrating_snapshot.get("wall_leap_raid_current_pos", Vector2.ZERO)
	var infiltrating_actor_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(str(infiltrating_snapshot.get("wall_leap_raid_state", "")) == "infiltrating", "entry tween must land in infiltrating state")
	_expect(arc_deviation_seen, "entry tween must visibly deviate from a straight line")
	_expect(is_equal_approx(infiltrating_pos.x, 300.0) and is_equal_approx(infiltrating_pos.y, 25.0), "entry must keep X and land at boss Y")
	_expect((infiltrating_actor_context.get("player_sprite_modulate", Color.WHITE) as Color).a < 0.60, "infiltrating actor context must request translucent production rendering")

	var detector := BallMotionCollisionDetector.new()
	var collision_context := {
		"player_pos": infiltrating_pos,
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
	}
	collision_context.merge(fixture["runtime"].get_ball_collision_context(), true)
	var body_ball := infiltrating_pos + Vector2(77.5, 25.0)
	var body_passthrough := detector.check_paddles(body_ball, Vector2(0.0, 9.0), 28.6, collision_context).is_empty()
	var holy_hit: Dictionary = detector.check_holy_barrier(Vector2(377.5, 730.0), Vector2(0.0, 9.0), 28.6, {
		"holy_barrier_active": true,
		"holy_barrier_y": 725.0,
		"holy_barrier_height": 20.0,
		"width": 760.0,
		"player_guard_available": false,
	})
	var floor_save_live := str(holy_hit.get("event", "")) == "holy_barrier"
	_expect(body_passthrough, "windowed active body collision must pass through")
	_expect(floor_save_live, "windowed holy-barrier floor save must remain live")

	var jetpack_updates_before := jetpack.update_count
	await _set_mouse(MOUSE_BUTTON_LEFT, true)
	var lmb_snapshot: Dictionary = input_reader.get_snapshot()
	_expect(bool(lmb_snapshot.get("mouse_left_just_pressed", false)), "desktop LMB edge must reach the skill reader")
	var slash_result: Dictionary = _step_controller(fixture, controller)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return", "LMB must commit slash and start return")
	_expect(jetpack.update_count == jetpack_updates_before, "owned LMB must not also update jetpack")
	_expect(is_equal_approx(float(slash_result.get("special_gauge", -1.0)), 340.0), "slash must spend 60 gauge")
	await _set_mouse(MOUSE_BUTTON_LEFT, false)
	_step_controller(fixture, controller)
	var landing_result: Dictionary = {}
	var return_arc_deviation_seen := false
	for _index in range(28):
		await physics_frame
		landing_result = _step_controller(fixture, controller)
		var return_snapshot: Dictionary = fixture["runtime"].get_snapshot()
		arc_points.append(return_snapshot.get("wall_leap_raid_current_pos", fixture["player_pos"]))
		if str(return_snapshot.get("wall_leap_raid_state", "")) == "return":
			var return_t := clampf(float(return_snapshot.get("wall_leap_raid_elapsed_seconds", 0.0)) / 0.22, 0.0, 1.0)
			var return_linear := infiltrating_pos.lerp(Vector2(300.0, 680.0), return_t)
			if (return_snapshot.get("wall_leap_raid_current_pos", Vector2.ZERO) as Vector2).distance_to(return_linear) > 20.0:
				return_arc_deviation_seen = true
		if str(return_snapshot.get("wall_leap_raid_state", "")) == "idle":
			break
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "idle", "return tween must land back in idle")
	_expect(return_arc_deviation_seen, "return tween must visibly deviate from a straight line")
	_expect(is_equal_approx(float(landing_result.get("player_collision_cooldown", -1.0)), 6.0), "landing must restore the six-frame collision cooldown")

	fixture["runtime"].wall_leap_state.reset()
	fixture["skill_state"].cooldowns.clear()
	fixture["special_gauge"] = 500.0
	fixture["player_pos"] = Vector2(300.0, 680.0)
	await _set_mouse(MOUSE_BUTTON_RIGHT, true)
	_step_controller(fixture, controller)
	await _set_mouse(MOUSE_BUTTON_RIGHT, false)
	_step_controller(fixture, controller)
	for _index in range(31):
		await physics_frame
		_step_controller(fixture, controller)
	await _set_mouse(MOUSE_BUTTON_RIGHT, true)
	var fuse_result: Dictionary = _step_controller(fixture, controller)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "fuse", "second desktop RMB must arm FUSE after the lock")
	_expect(is_equal_approx(float(fuse_result.get("special_gauge", -1.0)), 250.0), "FUSE commit must spend 150 gauge")
	await _set_mouse(MOUSE_BUTTON_RIGHT, false)
	_step_controller(fixture, controller)
	for _index in range(50):
		await physics_frame
		_step_controller(fixture, controller)
		if str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return":
			break
	var blast_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(blast_snapshot.get("wall_leap_raid_last_action", "")) == "blast", "FUSE must commit blast")
	_expect(bool(blast_snapshot.get("wall_leap_raid_last_action_hit", false)), "aligned blast must hit")
	_expect(fixture["status"].calls.any(func(call: Dictionary) -> bool: return str(call.get("status_id", "")) == "stun" and is_equal_approx(float(call.get("duration_frames", 0.0)), 180.0)), "blast must apply the production three-second stun")

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := QACanvas.new()
	canvas.tooltip_renderer = SmasherSkillOrbTooltipRenderer.new()
	canvas.player_sprite_renderer = Stage1PlayerSpriteRenderer.new()
	canvas.skill_data = ViperSkillConfig.new().get_skill_data("wall_leap_raid")
	canvas.player_actor_context = infiltrating_actor_context
	canvas.arc_points = arc_points
	canvas.infiltrating_pos = infiltrating_pos
	canvas.body_passthrough = body_passthrough
	canvas.floor_save_live = floor_save_live
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.get_size() == VIEW_SIZE, "windowed production-path capture must render at 1200x800")
	if image != null and not image.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
		_expect(image.save_png(ProjectSettings.globalize_path(OUT_PATH)) == OK, "windowed QA capture must save")
		_expect(_count_non_background_pixels(image) > 12000, "windowed QA capture must contain the playfield and production tooltip")
		var actor_sample := image.get_pixel(int(infiltrating_pos.x) + 97, int(infiltrating_pos.y) + 55)
		_expect(actor_sample.r > 0.35, "production player renderer pixel must preserve the boss color beneath the translucent infiltrator")
	viewport.queue_free()
	await process_frame
	_finish()


func _step_controller(fixture: Dictionary, controller: Object) -> Dictionary:
	fixture["context"]["special_gauge"] = fixture["special_gauge"]
	var result: Dictionary = controller.update(
		1.0 / 60.0,
		_frame_counter,
		fixture["player_pos"],
		0.0,
		fixture["context"],
		fixture["deps"]
	)
	_frame_counter += 1
	if result.has("player_pos"):
		fixture["player_pos"] = result["player_pos"]
	if result.has("special_gauge"):
		fixture["special_gauge"] = float(result["special_gauge"])
	return result


func _set_mouse(button: MouseButton, pressed: bool) -> void:
	var action := "press" if pressed else "release"
	var button_name := "rmb" if button == MOUSE_BUTTON_RIGHT else "lmb"
	print("wall_leap_windowed_qa: await_%s_%s" % [button_name, action])
	var deadline := Time.get_ticks_msec() + 10000
	while Input.is_mouse_button_pressed(button) != pressed and Time.get_ticks_msec() < deadline:
		await physics_frame
	if Input.is_mouse_button_pressed(button) != pressed:
		_fail("timed out waiting for physical %s %s" % [button_name, action])
	await physics_frame


func _count_non_background_pixels(image: Image) -> int:
	var count := 0
	var background := Color(0.025, 0.035, 0.065)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var color_delta := absf(color.r - background.r) + absf(color.g - background.g) + absf(color.b - background.b)
			if color_delta > 0.08:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("wall_leap_windowed_qa: capture=%s" % ProjectSettings.globalize_path(OUT_PATH))
		print("wall_leap_windowed_qa: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
