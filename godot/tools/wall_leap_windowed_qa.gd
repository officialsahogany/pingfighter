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
const BODY_HEAT_OUT_PATH := "res://.godot/codex_logs/wall_leap_body_heat_full_windowed.png"
const BODY_HEAT_CROP_OUT_PATH := "res://.godot/codex_logs/wall_leap_body_heat_crop_windowed.png"
const BODY_WHITE_HOT_CROP_OUT_PATH := "res://.godot/codex_logs/wall_leap_body_white_hot_crop_windowed.png"

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
	var wall_leap_state: Object

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
		var visual_size := Vector2(160.0, 160.0)
		var visual_y_offset := float(player_actor_context.get("viper_wall_leap_raid_visual_y_offset", 0.0))
		var player_visual_rect := Rect2(
			Vector2(
				player_rect.position.x + player_rect.size.x * 0.5 - visual_size.x * 0.5,
				player_rect.position.y + player_rect.size.y - visual_size.y + 12.0 + visual_y_offset
			),
			visual_size
		)
		# The body is drawn by the shipped directional renderer so the capture
		# contains the authored left/right walk or sword-swing sheet, not fallback art.
		var move_active := absf(float(player_actor_context.get("player_speed", 0.0))) > 0.2
		player_sprite_renderer.draw(self, player_actor_context, player_visual_rect, move_active, infiltrating_pos, player_rect.size, Vector2.ZERO)
		if wall_leap_state != null:
			wall_leap_state.draw_effects(self, Vector2.ZERO, {
				"game_offset": Vector2(20.0, 20.0),
				"render_scale": 1.0,
			})
		draw_rect(player_rect, Color(0.75, 0.96, 1.0), false, 2.0)
		var barrier_rect := Rect2(Vector2(20.0, 745.0), Vector2(760.0, 20.0))
		draw_rect(barrier_rect, Color(0.95, 0.84, 0.36, 0.72), true)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(38.0, 188.0), "RMB Serin body heat -> body detonation -> predicted ball-arrival X", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
		draw_string(font, Vector2(38.0, 212.0), "body pass-through: %s | floor save: %s" % [str(body_passthrough), str(floor_save_live)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.82, 0.92, 1.0))
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

	Input.action_press("ui_left", 1.0)
	await physics_frame
	_step_controller(fixture, controller)
	var left_walk_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	_expect(int(left_walk_context.get("player_walk_direction", 0)) == -1, "windowed ui_left must latch the authored left-facing walk route")
	_expect(float(left_walk_context.get("player_speed", 0.0)) < -0.2, "windowed ui_left must keep walk animation active during infiltration")
	Input.action_release("ui_left")
	await physics_frame
	_step_controller(fixture, controller)
	_expect(int(fixture["runtime"].get_actor_draw_context().get("player_walk_direction", 0)) == -1, "windowed no-input frame must retain the left-facing latch")

	var jetpack_updates_before := jetpack.update_count
	await _set_mouse(MOUSE_BUTTON_LEFT, true)
	var lmb_snapshot: Dictionary = input_reader.get_snapshot()
	_expect(bool(lmb_snapshot.get("mouse_left_just_pressed", false)), "desktop LMB edge must reach the skill reader")
	var slash_result: Dictionary = _step_controller(fixture, controller)
	_expect(str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "slash", "LMB must commit SLASH windup before blade spawn")
	_expect(jetpack.update_count == jetpack_updates_before, "owned LMB must not also update jetpack")
	_expect(is_equal_approx(float(slash_result.get("special_gauge", -1.0)), 340.0), "slash must spend 60 gauge")
	await _set_mouse(MOUSE_BUTTON_LEFT, false)
	_step_controller(fixture, controller)
	for _index in range(8):
		if str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "blade_flight":
			break
		await physics_frame
		_step_controller(fixture, controller)
	var blade_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var blade_actor_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	var slash_origin_pos: Vector2 = blade_snapshot.get("wall_leap_raid_current_pos", infiltrating_pos)
	blade_actor_context.merge({
		"player_walk_left_texture": load("res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png"),
		"player_walk_right_texture": load("res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png"),
		"player_attack_left_sheet": load("res://assets/sprites/characters/viper/viper_subculture_left_attack_sheet.png"),
		"player_attack_right_sheet": load("res://assets/sprites/characters/viper/viper_subculture_right_attack_sheet.png"),
		"player_directional_attack_cell_width": 160.0,
		"player_directional_attack_cell_height": 160.0,
		"player_directional_attack_grid_cols": 4,
		"player_directional_attack_grid_rows": 2,
	}, true)
	_expect(str(blade_snapshot.get("wall_leap_raid_state", "")) == "blade_flight", "windowed impact frame must enter BLADE_FLIGHT")
	_expect(bool(blade_snapshot.get("wall_leap_raid_blade_active", false)), "windowed blade must remain visible before range expiry")
	_expect(int(blade_snapshot.get("wall_leap_raid_blade_direction", 0)) == -1, "left-facing sword sheet and blade must share direction")
	_expect(int(blade_actor_context.get("player_hit_side", 0)) == -1, "windowed actor context must select the authored left sword-swing sheet")
	var landing_result: Dictionary = {}
	var return_arc_deviation_seen := false
	for _index in range(70):
		await physics_frame
		landing_result = _step_controller(fixture, controller)
		var return_snapshot: Dictionary = fixture["runtime"].get_snapshot()
		arc_points.append(return_snapshot.get("wall_leap_raid_current_pos", fixture["player_pos"]))
		if str(return_snapshot.get("wall_leap_raid_state", "")) == "return":
			var return_t := clampf(float(return_snapshot.get("wall_leap_raid_elapsed_seconds", 0.0)) / 0.22, 0.0, 1.0)
			var return_linear := slash_origin_pos.lerp(Vector2(300.0, 680.0), return_t)
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
	fixture["context"]["ball_pos"] = Vector2(590.0, 360.0)
	fixture["context"]["ball_vel"] = Vector2(-6.0, 10.0)
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
	for _index in range(21):
		await physics_frame
		_step_controller(fixture, controller)
	var fuse_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var fuse_actor_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	fuse_actor_context.merge({
		"player_walk_left_texture": load("res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png"),
		"player_walk_right_texture": load("res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png"),
		"player_speed": -1.0,
		"player_walk_direction": -1,
	}, true)
	_expect(str(fuse_snapshot.get("wall_leap_raid_state", "")) == "fuse", "mid-FUSE production capture must keep Serin in the body-heat state")
	_expect(float(fuse_actor_context.get("viper_wall_leap_raid_body_heat_ratio", 0.0)) > 0.45, "mid-FUSE production actor context must heat Serin's body")
	var fuse_viewport := SubViewport.new()
	fuse_viewport.size = VIEW_SIZE
	fuse_viewport.transparent_bg = false
	fuse_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(fuse_viewport)
	var fuse_canvas := QACanvas.new()
	fuse_canvas.tooltip_renderer = SmasherSkillOrbTooltipRenderer.new()
	fuse_canvas.player_sprite_renderer = Stage1PlayerSpriteRenderer.new()
	fuse_canvas.skill_data = ViperSkillConfig.new().get_skill_data("wall_leap_raid")
	fuse_canvas.player_actor_context = fuse_actor_context
	fuse_canvas.arc_points = arc_points
	fuse_canvas.infiltrating_pos = fuse_snapshot.get("wall_leap_raid_current_pos", infiltrating_pos)
	fuse_canvas.body_passthrough = body_passthrough
	fuse_canvas.floor_save_live = floor_save_live
	fuse_canvas.wall_leap_state = fixture["runtime"].wall_leap_state
	fuse_viewport.add_child(fuse_canvas)
	fixture["runtime"].wall_leap_state.prewarm_runtime_nodes(fuse_canvas)
	fuse_canvas.queue_redraw()
	for _index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var fuse_image: Image = fuse_viewport.get_texture().get_image()
	_expect(fuse_image != null and not fuse_image.is_empty(), "body-heat production capture must render")
	if fuse_image != null and not fuse_image.is_empty():
		_expect(fuse_image.save_png(ProjectSettings.globalize_path(BODY_HEAT_OUT_PATH)) == OK, "body-heat production capture must save")
		var fuse_center: Vector2 = fuse_snapshot.get("wall_leap_raid_fuse_visual_center", Vector2.ZERO) + Vector2(20.0, 20.0)
		_expect(_count_body_heat_pixels(fuse_image, fuse_center) > 1800, "production renderer must show a substantial red Serin body and attached heat aura")
		var crop_rect := Rect2i(Vector2i(fuse_center) - Vector2i(100, 100), Vector2i(200, 200))
		var body_heat_crop := fuse_image.get_region(crop_rect)
		_expect(body_heat_crop.save_png(ProjectSettings.globalize_path(BODY_HEAT_CROP_OUT_PATH)) == OK, "body-heat production crop must save for close visual review")
	for _index in range(18):
		await physics_frame
		_step_controller(fixture, controller)
	var white_hot_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var white_hot_actor_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	white_hot_actor_context.merge({
		"player_walk_left_texture": load("res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png"),
		"player_walk_right_texture": load("res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png"),
		"player_speed": -1.0,
		"player_walk_direction": -1,
	}, true)
	_expect(str(white_hot_snapshot.get("wall_leap_raid_state", "")) == "fuse", "late production capture must precede the blast commit")
	_expect(float(white_hot_actor_context.get("viper_wall_leap_raid_body_heat_ratio", 0.0)) > 0.96, "late production capture must reach Serin's white-hot body phase")
	fuse_canvas.player_actor_context = white_hot_actor_context
	fuse_canvas.infiltrating_pos = white_hot_snapshot.get("wall_leap_raid_current_pos", infiltrating_pos)
	fuse_canvas.queue_redraw()
	for _index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var white_hot_image: Image = fuse_viewport.get_texture().get_image()
	_expect(white_hot_image != null and not white_hot_image.is_empty(), "white-hot production capture must render")
	if white_hot_image != null and not white_hot_image.is_empty():
		var white_hot_center: Vector2 = white_hot_snapshot.get("wall_leap_raid_fuse_visual_center", Vector2.ZERO) + Vector2(20.0, 20.0)
		var white_hot_rect := Rect2i(Vector2i(white_hot_center) - Vector2i(100, 100), Vector2i(200, 200))
		var white_hot_crop := white_hot_image.get_region(white_hot_rect)
		_expect(white_hot_crop.save_png(ProjectSettings.globalize_path(BODY_WHITE_HOT_CROP_OUT_PATH)) == OK, "white-hot production crop must save for close visual review")
	fuse_viewport.queue_free()
	await process_frame
	for _index in range(11):
		await physics_frame
		_step_controller(fixture, controller)
		if str(fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "return":
			break
	var blast_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	var blast_actor_context: Dictionary = fixture["runtime"].get_actor_draw_context()
	blast_actor_context.merge({
		"player_walk_left_texture": load("res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png"),
		"player_walk_right_texture": load("res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png"),
	}, true)
	var blast_display_pos: Vector2 = blast_snapshot.get("wall_leap_raid_current_pos", infiltrating_pos)
	_expect(str(blast_snapshot.get("wall_leap_raid_last_action", "")) == "blast", "FUSE must commit blast")
	_expect(bool(blast_snapshot.get("wall_leap_raid_last_action_hit", false)), "aligned blast must hit")
	_expect(bool(blast_snapshot.get("wall_leap_raid_blast_vfx_active", false)), "physical RMB blast must own the layered impact presentation")
	_expect(fixture["status"].calls.any(func(call: Dictionary) -> bool: return str(call.get("status_id", "")) == "stun" and is_equal_approx(float(call.get("duration_frames", 0.0)), 180.0)), "blast must apply the production three-second stun")
	fixture["runtime"].wall_leap_state.prewarm_assets()
	fixture["context"]["ball_pos"] = Vector2(100.0, 360.0)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := QACanvas.new()
	canvas.tooltip_renderer = SmasherSkillOrbTooltipRenderer.new()
	canvas.player_sprite_renderer = Stage1PlayerSpriteRenderer.new()
	canvas.skill_data = ViperSkillConfig.new().get_skill_data("wall_leap_raid")
	canvas.player_actor_context = blast_actor_context
	canvas.arc_points = arc_points
	canvas.infiltrating_pos = blast_display_pos
	canvas.body_passthrough = body_passthrough
	canvas.floor_save_live = floor_save_live
	canvas.wall_leap_state = fixture["runtime"].wall_leap_state
	viewport.add_child(canvas)
	fixture["runtime"].wall_leap_state.prewarm_runtime_nodes(canvas)
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
		_expect(_count_blast_pixels(image, blast_snapshot.get("wall_leap_raid_blast_vfx_origin", Vector2.ZERO) + Vector2(20.0, 20.0)) > 1500, "windowed capture must contain a substantial warm-core and ink-smoke RMB blast footprint")
	viewport.queue_free()
	await process_frame
	for _index in range(14):
		await physics_frame
		_step_controller(fixture, controller)
	var ball_return_snapshot: Dictionary = fixture["runtime"].get_snapshot()
	_expect(str(ball_return_snapshot.get("wall_leap_raid_state", "")) == "idle", "physical blast return must land after the capture")
	_expect(absf((fixture["player_pos"] as Vector2).x - 332.08) <= 0.02, "physical blast return must land at the ball's captured player-line arrival X")
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


func _count_blast_pixels(image: Image, center: Vector2) -> int:
	var count := 0
	var min_x := maxi(0, int(center.x - 175.0))
	var max_x := mini(image.get_width(), int(center.x + 175.0))
	var min_y := maxi(0, int(center.y - 175.0))
	var max_y := mini(image.get_height(), int(center.y + 175.0))
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			var color := image.get_pixel(x, y)
			var warm_core := color.r > 0.44 and color.g > 0.14 and color.r > color.b * 1.18
			var ink_smoke := color.b > color.r * 1.08 and color.b > 0.10 and color.r < 0.34
			if warm_core or ink_smoke:
				count += 1
	return count


func _count_body_heat_pixels(image: Image, center: Vector2) -> int:
	var count := 0
	var radius_squared := 95.0 * 95.0
	var min_x := maxi(0, int(center.x - 95.0))
	var max_x := mini(image.get_width(), int(center.x + 95.0))
	var min_y := maxi(0, int(center.y - 95.0))
	var max_y := mini(image.get_height(), int(center.y + 95.0))
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			if Vector2(float(x), float(y)).distance_squared_to(center) > radius_squared:
				continue
			var color := image.get_pixel(x, y)
			if color.r > 0.18 and color.r > color.g * 1.35 and color.r > color.b * 1.12:
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
