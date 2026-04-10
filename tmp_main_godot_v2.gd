extends Node2D

# Phase 1 prototype: core rally loop, dash, HUD, energy ball, hit SFX.

const WIDTH := 760
const HEIGHT := 750
const PILLAR_WIDTH := 80
const PLAY_LEFT := 0
const PLAY_RIGHT := WIDTH
# PingFighter's real window is larger than the 760x750 gameplay surface.
# These values mirror the common 1080p runtime layout:
# 1488x918 window with the 760x750 game centered inside.
const VIEW_WIDTH := 1488.0
const VIEW_HEIGHT := 918.0
const OUTER_PILLAR_PAD_X := 364.0
const OUTER_PILLAR_PAD_Y := 84.0
const WINDOW_TARGET_HEIGHT_RATIO := 0.865
const WINDOW_TARGET_WIDTH_RATIO := 0.90

const BALL_SIZE := 24.0
const BALL_RENDER_RADIUS := 16.0
const INITIAL_BALL_SPEED := 6.0
const MIN_BALL_SPEED := 3.0
const MAX_BALL_SPEED := 60.0
const SPEED_SCALE_THRESHOLD := 51.0
const BALL_MAX_STEP_DISTANCE := 12.0
const WALL_DAMPING := 0.95
const PADDLE_HIT_BOOST := 1.0
const EDGE_HIT_BOOST := 1.2
const MAX_BOUNCE_ANGLE := 60.0
const BALL_IMPACT_BASE_DECAY_RATE := 0.975
const BALL_IMPACT_BASE_MIN_BOOST := 0.70
const BALL_IMPACT_SPEED_THRESHOLD_LOW := 10.0
const BALL_IMPACT_SPEED_THRESHOLD_HIGH := 18.0
const BALL_IMPACT_STAGE1_CAP := 1.7
const BASE_HIT_SPEED_MULT_MIN := 1.024
const BASE_HIT_SPEED_MULT_MAX := 1.084
const BOSS_HIT_SPEED_MULT_MIN := 1.012
const BOSS_HIT_SPEED_MULT_MAX := 1.054
const CENTER_HIT_THRESHOLD := 0.05
const MID_HIT_THRESHOLD := 0.15
const SMASH_HIT_THRESHOLD := 0.75
const BOSS_CENTER_PRESERVE_THRESHOLD := 0.35
const NORMAL_CURVE_CHANCE := 0.30
const MIN_BOUNCE_ANGLE_DEG := 25.0

const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0
const PADDLE_SPEED := 6.0
const PADDLE_MAX_SPEED := 6.0
const PADDLE_ACCEL := 0.5
const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_PADDLE_HEIGHT := 40.0
const BOSS_HITBOX_HEIGHT := BOSS_PADDLE_HEIGHT
const BOSS_STAGE1_VISUAL_CENTER_Y_OFFSET := 25.0
const HITBOX_PADDING := 5.0

const DASH_DURATION := 15.0
const HALF_DASH_DURATION := 11.0
const DASH_BASE_SPEED := 40.0
const DASH_DECEL_FRAMES := 20.0
const DASH_RECOVERY_FRAMES := 42.0
const HALF_DASH_RECOVERY_MULT := 1.5
const DASH_TOKEN_RECHARGE_FRAMES := 90.0
const CONSECUTIVE_DASH_START_DELAY_FRAMES := 12.0

const GAUGE_MAX := 350.0
const GAUGE_CHARGE_PER_HIT := 50.0

const WIN_GOAL := 5
const DEUCE_TRIGGER := 4
const DEUCE_GOAL_1 := 6
const DEUCE_GOAL_2 := 7
const SERVE_DELAY := 1.0

const PADDLE_HIT_SOUND_PATH := "res://assets/sounds/paddle_hit.wav"
const DASH_SOUND_PATH := "res://assets/sounds/dash.wav"
const HALF_DASH_SOUND_PATH := "res://assets/sounds/halfdash.wav"
const PADDLE_HIT_SOUND_COOLDOWN := 0.06
const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
const PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/smasher_idle_strip.png"
const PLAYER_HIT_SPRITE_PATH := "res://assets/sprites/smasher_hit_pose.png"
const PLAYER_HIT_LEFT_STRIP_PATH := "res://assets/sprites/smasher_hit_left_strip.png"
const PLAYER_HIT_RIGHT_STRIP_PATH := "res://assets/sprites/smasher_hit_right_strip.png"
const BOSS_SPRITE_SHEET_PATH := "res://assets/sprites/stage1walking3.png"
const PLAYER_SPRITE_DRAW_SIZE := Vector2(250.0, 120.0)
const PLAYER_IDLE_FRAME_COUNT := 8
const PLAYER_SPRITE_FRAME_COUNT := 6
const PLAYER_SPRITE_FRAME_WIDTH := 250.0
const PLAYER_SPRITE_FRAME_HEIGHT := 120.0
const PLAYER_IDLE_ANIMATION_SPEED := 0.15
const PLAYER_SPRITE_ANIMATION_SPEED := 0.10
const PLAYER_HIT_ANIM_DURATION := 0.36
const PLAYER_HIT_FRAME_COUNT := 4
const PLAYER_HIT_FRAME_WIDTH := 250.0
const PLAYER_HIT_FRAME_HEIGHT := 120.0
const PLAYER_HOVER_SPEED := 4.5
const PLAYER_HOVER_AMPLITUDE := 7.0
const PLAYER_MOVE_BOB_AMPLITUDE := 5.0
const PLAYER_IDLE_BREATH_Y := 2.5
const PLAYER_IDLE_BREATH_SCALE_X := 0.015
const PLAYER_IDLE_BREATH_SCALE_Y := 0.025
const PLAYER_HIT_LUNGE_X := 14.0
const PLAYER_HIT_LUNGE_Y := 8.0
const PLAYER_HIT_REBOUND_X := 5.0
const PLAYER_HIT_REBOUND_Y := 2.5
const PLAYER_HIT_SCALE_X := 0.055
const PLAYER_HIT_SCALE_Y := 0.045
const BOSS_SPRITE_DRAW_SIZE := Vector2(80.0, 160.0)
const BOSS_SPRITE_FRAME_COUNT := 6
const BOSS_SPRITE_FRAME_WIDTH := 162.0
const BOSS_SPRITE_FRAME_HEIGHT := 512.0
const BOSS_SPRITE_ANIMATION_SPEED := 0.10
const BOSS_HIT_SPRITE_PATH := "res://assets/sprites/stage1hit.png"
const BOSS_HIT_ANIM_DURATION := 0.35
const BOSS_HIT_FRAME_COUNT := 6
const BOSS_HIT_FRAME_SPEED := 0.05

const BG_COLOR := Color(0.03, 0.03, 0.08)
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.10)
const PLAYER_COLOR := Color(0.25, 0.45, 1.0)
const PLAYER_COLOR_LIGHT := Color(0.40, 0.60, 1.0)
const BOSS_COLOR := Color(1.0, 0.25, 0.25)
const BOSS_COLOR_LIGHT := Color(1.0, 0.45, 0.35)
const PILLAR_COLOR := Color(0.06, 0.06, 0.10)
const GAUGE_COLOR := Color(0.20, 0.80, 1.0)
const GAUGE_BG_COLOR := Color(0.15, 0.15, 0.20)
const DASH_TRAIL_COLOR := Color(0.30, 0.50, 1.0, 0.30)
const HALF_DASH_COLOR := Color(0.60, 0.60, 1.0, 0.40)

const BALL_OUTER_COLOR := Color(30.0 / 255.0, 100.0 / 255.0, 200.0 / 255.0)
const BALL_INNER_COLOR := Color(100.0 / 255.0, 180.0 / 255.0, 255.0 / 255.0)
const BALL_RING_COLOR := Color(80.0 / 255.0, 160.0 / 255.0, 255.0 / 255.0)
const BALL_CORE_COLOR := Color(1.0, 1.0, 1.0)
const ENERGY_BALL_MAX_PARTICLES := 18
const PILLAR_SILK_DARK := Color(0.52, 0.46, 0.38)
const PILLAR_SILK_LIGHT := Color(0.70, 0.64, 0.53)
const PILLAR_GOLD_DARK := Color(0.45, 0.34, 0.16)
const PILLAR_GOLD := Color(0.76, 0.61, 0.31)
const PILLAR_GOLD_BRIGHT := Color(0.92, 0.79, 0.46)
const PILLAR_BROWN := Color(0.35, 0.24, 0.15)
const PILLAR_GREEN := Color(0.30, 0.44, 0.30)
const PILLAR_RED := Color(0.82, 0.74, 0.64)
const PILLAR_CREAM := Color(0.96, 0.92, 0.82)
const PILLAR_BUTTERFLY_BLUE := Color(0.36, 0.52, 0.78)
const PILLAR_BUTTERFLY_GOLD := Color(0.84, 0.68, 0.35)
const PILLAR_BUTTERFLY_RED := Color(0.72, 0.46, 0.42)
const PILLAR_UI_SURFACE_LEFT_SIZE := Vector2(250.0, 650.0)
const PILLAR_UI_SURFACE_RIGHT_SIZE := Vector2(240.0, 320.0)
const PILLAR_UI_SIDE_MARGIN := 25.0
const PILLAR_UI_BOTTOM_MARGIN := 10.0
const PILLAR_ORB_RADIUS_BASE := 55.0
const PILLAR_ORB_FRAME_WIDTH_BASE := 10.0
const PILLAR_GAUGE_GAIN_FLASH_DURATION := 0.45
const PILLAR_DASH_FLASH_DURATION := 0.55
const PILLAR_DASH_DIVIDER_ANIM_DURATION := 0.60
const ENERGY_BALL_PARTICLE_COLORS: Array[Color] = [
	Color(200.0 / 255.0, 230.0 / 255.0, 1.0),
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
]

var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_active := false
var ball_trail: Array[Vector2] = []
var ball_impact_boost := 1.0
var ball_boost_decay_rate := BALL_IMPACT_BASE_DECAY_RATE
var ball_min_boost := BALL_IMPACT_BASE_MIN_BOOST
var vertical_bounce_count := 0

var player_pos := Vector2.ZERO
var player_speed := 0.0

var boss_pos := Vector2.ZERO
var boss_vel := 0.0
var boss_fail_timer := 0.0

var player_score := 0
var boss_score := 0
var deuce_mode := false
var deuce_goal := DEUCE_GOAL_1

var serve_timer := 0.0
var waiting_for_serve := true
var player_serves := true

var dash_tokens := 1
var dash_tokens_max := 1
var dash_active := false
var dash_timer := 0.0
var dash_direction := 0.0
var dash_is_half := false
var dash_stun_timer := 0.0
var dash_available_timer := 0.0
var dash_charge_timer := 0.0
var dash_consecutive_count := 0
var dash_key_released_since_last := true
var dash_elapsed_frames := 0.0
var special_gauge := 0.0

var screen_shake := 0.0
var screen_shake_intensity := 0.0
var hit_flash_timer := 0.0
var hit_particles: Array[Dictionary] = []
var energy_ball_particles: Array[Dictionary] = []
var paddle_sound_cooldown := 0.0
var paddle_hit_sfx: AudioStreamPlayer
var dash_sfx: AudioStreamPlayer
var half_dash_sfx: AudioStreamPlayer
var player_sprite_texture: Texture2D
var player_idle_sprite_texture: Texture2D
var player_hit_sprite_texture: Texture2D
var player_hit_left_strip_texture: Texture2D
var player_hit_right_strip_texture: Texture2D
var player_idle_frame := 0
var player_idle_timer := 0.0
var player_sprite_frame := 0
var player_sprite_timer := 0.0
var player_hit_active := false
var player_hit_timer := 0.0
var player_hit_frame := 0
var player_hit_side := -1
var player_anim_clock := 0.0
var boss_sprite_sheet: Texture2D
var boss_sprite_frame := 0
var boss_sprite_timer := 0.0
var boss_sprite_row := 1
var boss_hit_sprite_sheet: Texture2D
var boss_hit_active := false
var boss_hit_timer := 0.0
var boss_hit_frame := 0
var boss_hit_frame_timer := 0.0
var boss_hit_row := 1
var special_gauge_flash_timer := 0.0
var dash_orb_flash_timer := 0.0
var dash_divider_anim_progress := 1.0
var dash_prev_token_max := 1

const BOSS_ACCEL := 0.798
const BOSS_DECEL := 0.798
const BOSS_MAX_SPEED := 6.3175
const BOSS_INSTANT_STOP := 0.665
const BOSS_PREDICT_CHANCE := 0.45
const BOSS_PREDICT_ERROR := 95.0
const BOSS_FAIL_CHANCE := 0.010
const BOSS_FAIL_ERROR := 315.0
const BOSS_FAIL_TIMER_FRAMES := 60.0
const BOSS_PREDICT_FRAME_MIN := 10.0
const BOSS_PREDICT_FRAME_MAX := 30.0


func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_configure_window_from_monitor()
	player_pos = Vector2(WIDTH * 0.5 - PADDLE_WIDTH * 0.5, PLAYER_Y)
	boss_pos = Vector2(WIDTH * 0.5 - BOSS_PADDLE_WIDTH * 0.5, BOSS_Y)
	_setup_audio()
	_load_battle_sprites()
	_reset_ball()


func _configure_window_from_monitor() -> void:
	var window: Window = get_window()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect()
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return

	var width_scale: float = (float(usable_rect.size.x) * WINDOW_TARGET_WIDTH_RATIO) / VIEW_WIDTH
	var height_scale: float = (float(usable_rect.size.y) * WINDOW_TARGET_HEIGHT_RATIO) / VIEW_HEIGHT
	var target_scale: float = min(width_scale, height_scale)
	if target_scale <= 0.0:
		return

	var target_size := Vector2i(
		int(round(VIEW_WIDTH * target_scale)),
		int(round(VIEW_HEIGHT * target_scale))
	)
	window.size = target_size
	window.position = usable_rect.position + (usable_rect.size - target_size) / 2


func _setup_audio() -> void:
	paddle_hit_sfx = _create_audio_player("PaddleHitSfx", PADDLE_HIT_SOUND_PATH, -5.0)
	dash_sfx = _create_audio_player("DashSfx", DASH_SOUND_PATH, -6.0)
	half_dash_sfx = _create_audio_player("HalfDashSfx", HALF_DASH_SOUND_PATH, -6.0)


func _create_audio_player(name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = name
	player.bus = "Master"
	player.volume_db = volume_db
	if ResourceLoader.exists(path):
		player.stream = load(path)
	else:
		push_warning("Missing sound at %s" % path)
	add_child(player)
	return player


func _load_battle_sprites() -> void:
	player_sprite_texture = _load_texture_resource(PLAYER_SPRITE_PATH)
	player_idle_sprite_texture = _load_texture_resource(PLAYER_IDLE_SPRITE_PATH)
	player_hit_sprite_texture = _load_texture_resource(PLAYER_HIT_SPRITE_PATH)
	player_hit_left_strip_texture = _load_texture_resource(PLAYER_HIT_LEFT_STRIP_PATH)
	player_hit_right_strip_texture = _load_texture_resource(PLAYER_HIT_RIGHT_STRIP_PATH)
	boss_sprite_sheet = _load_texture_resource(BOSS_SPRITE_SHEET_PATH)
	boss_hit_sprite_sheet = _load_texture_resource(BOSS_HIT_SPRITE_PATH)


func _load_texture_resource(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("Missing sprite at %s" % path)
		return null
	var texture = load(path)
	if texture is Texture2D:
		return texture
	push_warning("Failed to load texture at %s" % path)
	return null


func _build_ellipse_points(rect: Rect2, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x: float = rect.size.x * 0.5
	var radius_y: float = rect.size.y * 0.5
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(
			center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
	)
	return points


func _build_sector_points(center: Vector2, outer_radius: float, start_rad: float, end_rad: float, segments: int = 32, inner_radius: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	if inner_radius <= 0.0:
		points.append(center)
	for i in range(segments + 1):
		var ratio: float = float(i) / float(max(1, segments))
		var angle: float = start_rad + (end_rad - start_rad) * ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	if inner_radius > 0.0:
		for i in range(segments, -1, -1):
			var ratio: float = float(i) / float(max(1, segments))
			var angle: float = start_rad + (end_rad - start_rad) * ratio
			points.append(center + Vector2(cos(angle), sin(angle)) * inner_radius)
	return points


func _draw_soft_shadow_ellipse(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var outer_rect := rect.grow_individual(10.0, 4.0, 10.0, 4.0)
	var mid_rect := rect.grow_individual(5.0, 2.0, 5.0, 2.0)
	draw_colored_polygon(
		_build_ellipse_points(outer_rect, 28),
		Color(color.r, color.g, color.b, color.a * 0.22)
	)
	draw_colored_polygon(
		_build_ellipse_points(mid_rect, 28),
		Color(color.r, color.g, color.b, color.a * 0.45)
	)
	draw_colored_polygon(_build_ellipse_points(rect, 28), color)


func _draw_inner_side_vignette(rect: Rect2, mirrored: bool, t: float) -> void:
	var band_width: int = int(max(1.0, rect.size.x))
	for x in range(0, band_width, 2):
		var ratio: float = float(x) / max(1.0, float(band_width - 1))
		var outer_weight: float = ratio if mirrored else (1.0 - ratio)
		var pulse: float = 0.92 + sin(t * 1.2 + ratio * 5.0) * 0.04
		var alpha: float = pow(outer_weight, 1.85) * 0.18 * pulse
		var col := Color(
			PILLAR_SILK_DARK.r * 0.65,
			PILLAR_SILK_DARK.g * 0.65,
			PILLAR_SILK_DARK.b * 0.78,
			alpha
		)
		draw_rect(
			Rect2(rect.position.x + float(x), rect.position.y, 2.0, rect.size.y),
			col
		)

	var seam_x: float = rect.end.x if not mirrored else rect.position.x
	var seam_alpha: float = 0.12 + 0.03 * sin(t * 2.0)
	draw_line(
		Vector2(seam_x, rect.position.y),
		Vector2(seam_x, rect.end.y),
		Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, seam_alpha),
		1.0
	)

	var glow_rect := rect
	glow_rect.size.x = min(rect.size.x, 26.0)
	if mirrored:
		glow_rect.position.x = rect.end.x - glow_rect.size.x
	var glow_alpha: float = 0.05 + 0.02 * sin(t * 1.6)
	draw_colored_polygon(
		_build_ellipse_points(Rect2(
			glow_rect.position.x - 10.0,
			rect.position.y + 140.0,
			glow_rect.size.x + 20.0,
			rect.size.y - 280.0
		), 32),
		Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, glow_alpha)
	)


func _ease_out_cubic(t: float) -> float:
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_t, 3.0)


func _ease_in_out_sine(t: float) -> float:
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return -(cos(PI * clamped_t) - 1.0) * 0.5


func _get_player_hit_progress() -> float:
	if PLAYER_HIT_ANIM_DURATION <= 0.0:
		return 1.0
	return clamp(1.0 - (player_hit_timer / PLAYER_HIT_ANIM_DURATION), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_update_dash(delta)
	_update_boss_ai(delta)

	if waiting_for_serve:
		serve_timer += delta
		if serve_timer >= SERVE_DELAY:
			_serve_ball()
	else:
		_update_ball(delta)

	_update_effects(delta)
	queue_redraw()


func _handle_input(delta: float) -> void:
	var fps_scale = delta * 60.0
	var down_pressed = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)
	if not down_pressed:
		dash_key_released_since_last = true

	var direction = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction += 1.0

	if dash_active:
		if (
			not dash_is_half
			and dash_tokens > 0
			and dash_elapsed_frames >= CONSECUTIVE_DASH_START_DELAY_FRAMES
			and down_pressed
			and direction != 0.0
		):
			_start_dash(direction, false)
		return

	if dash_stun_timer > 0.0:
		player_speed = 0.0
		return

	if down_pressed and direction != 0.0 and dash_available_timer <= 0.0 and dash_key_released_since_last:
		if dash_tokens > 0:
			_start_dash(direction, false)
			return
		_start_dash(direction, true)
		return

	if direction != 0.0:
		player_speed = move_toward(player_speed, direction * PADDLE_MAX_SPEED, PADDLE_ACCEL * fps_scale)
		if abs(player_speed) < PADDLE_SPEED:
			player_speed = direction * PADDLE_SPEED
	else:
		player_speed = move_toward(player_speed, 0.0, PADDLE_ACCEL * 2.0 * fps_scale)

	player_pos.x += player_speed * fps_scale
	player_pos.x = clamp(player_pos.x, PLAY_LEFT, PLAY_RIGHT - PADDLE_WIDTH)


func _start_dash(direction: float, is_half: bool) -> void:
	dash_active = true
	dash_direction = direction
	dash_is_half = is_half
	dash_elapsed_frames = 0.0
	player_speed = 0.0
	dash_key_released_since_last = false
	_play_dash_start_sound(is_half)

	if is_half:
		dash_timer = HALF_DASH_DURATION
	else:
		dash_timer = DASH_DURATION
		dash_tokens = max(0, dash_tokens - 1)
		dash_charge_timer = DASH_TOKEN_RECHARGE_FRAMES
		dash_consecutive_count += 1

	screen_shake = 0.12
	screen_shake_intensity = 4.0


func _update_dash(delta: float) -> void:
	var fps_scale = delta * 60.0

	if dash_charge_timer > 0.0:
		dash_charge_timer = max(0.0, dash_charge_timer - fps_scale)
		if dash_charge_timer <= 0.0 and dash_tokens < dash_tokens_max:
			dash_tokens = dash_tokens_max
			dash_consecutive_count = 0
			dash_orb_flash_timer = PILLAR_DASH_FLASH_DURATION

	if not dash_active:
		if dash_stun_timer > 0.0:
			dash_stun_timer = max(0.0, dash_stun_timer - fps_scale)
		if dash_available_timer > 0.0:
			dash_available_timer = max(0.0, dash_available_timer - fps_scale)
		return

	dash_elapsed_frames += fps_scale
	dash_timer -= fps_scale

	var current_speed = 0.0
	if dash_timer > DASH_DECEL_FRAMES:
		current_speed = DASH_BASE_SPEED
	else:
		var dash_strength: float = clamp(dash_timer / DASH_DECEL_FRAMES, 0.0, 1.0)
		current_speed = DASH_BASE_SPEED * dash_strength

	player_pos.x += round(dash_direction * current_speed * fps_scale)
	player_pos.x = clamp(player_pos.x, PLAY_LEFT, PLAY_RIGHT - PADDLE_WIDTH)

	if dash_timer <= 0.0:
		dash_active = false
		player_speed = 0.0
		dash_elapsed_frames = 0.0
		dash_stun_timer = DASH_RECOVERY_FRAMES
		if dash_is_half:
			dash_stun_timer *= HALF_DASH_RECOVERY_MULT
		dash_available_timer = dash_stun_timer


func _update_boss_ai(delta: float) -> void:
	var fps_scale = delta * 60.0
	var boss_center: float = boss_pos.x + BOSS_PADDLE_WIDTH * 0.5
	var future_x: float = WIDTH * 0.5

	if ball_active and not waiting_for_serve:
		var predict_frame_float: float = clamp(
			60.0 / max(1.0, abs(ball_vel.x)),
			BOSS_PREDICT_FRAME_MIN,
			BOSS_PREDICT_FRAME_MAX
		)
		var predict_frame: int = int(predict_frame_float)

		if boss_fail_timer > 0.0:
			if randf() < BOSS_PREDICT_CHANCE:
				future_x = ball_pos.x + ball_vel.x * float(predict_frame)
			else:
				future_x = ball_pos.x
			future_x += randf_range(-BOSS_FAIL_ERROR, BOSS_FAIL_ERROR)
			boss_fail_timer = max(0.0, boss_fail_timer - fps_scale)
		else:
			if randf() < BOSS_FAIL_CHANCE:
				boss_fail_timer = BOSS_FAIL_TIMER_FRAMES
				future_x = ball_pos.x + ball_vel.x * float(predict_frame)
				future_x += randf_range(-BOSS_FAIL_ERROR, BOSS_FAIL_ERROR)
			else:
				if randf() < BOSS_PREDICT_CHANCE:
					future_x = ball_pos.x + ball_vel.x * float(predict_frame)
				else:
					future_x = ball_pos.x
				future_x += randf_range(-BOSS_PREDICT_ERROR, BOSS_PREDICT_ERROR)
	else:
		boss_fail_timer = 0.0
		future_x = WIDTH * 0.5

	if future_x < boss_center:
		if boss_vel > -BOSS_MAX_SPEED:
			boss_vel -= BOSS_ACCEL * fps_scale
	elif future_x > boss_center:
		if boss_vel < BOSS_MAX_SPEED:
			boss_vel += BOSS_ACCEL * fps_scale
	else:
		if boss_vel > 0.0:
			boss_vel -= BOSS_DECEL * fps_scale
		elif boss_vel < 0.0:
			boss_vel += BOSS_DECEL * fps_scale

	if future_x < boss_center and boss_vel > 0.0:
		boss_vel -= BOSS_INSTANT_STOP * fps_scale
	elif future_x > boss_center and boss_vel < 0.0:
		boss_vel += BOSS_INSTANT_STOP * fps_scale

	boss_vel = clamp(boss_vel, -BOSS_MAX_SPEED, BOSS_MAX_SPEED)
	if abs(boss_vel) < 0.001:
		boss_vel = 0.0

	boss_pos.x += boss_vel * fps_scale
	boss_pos.x = clamp(boss_pos.x, PLAY_LEFT, PLAY_RIGHT - BOSS_PADDLE_WIDTH)


func _reset_ball() -> void:
	ball_pos = Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	ball_vel = Vector2.ZERO
	ball_impact_boost = 1.0
	ball_boost_decay_rate = BALL_IMPACT_BASE_DECAY_RATE
	ball_min_boost = BALL_IMPACT_BASE_MIN_BOOST
	vertical_bounce_count = 0
	ball_active = false
	ball_trail.clear()
	energy_ball_particles.clear()
	waiting_for_serve = true
	serve_timer = 0.0
	player_pos.x = WIDTH * 0.5 - PADDLE_WIDTH * 0.5
	boss_pos.x = WIDTH * 0.5 - BOSS_PADDLE_WIDTH * 0.5
	boss_vel = 0.0
	boss_fail_timer = 0.0
	player_anim_clock = 0.0
	player_idle_frame = 0
	player_idle_timer = 0.0
	player_sprite_frame = 0
	player_sprite_timer = 0.0
	player_hit_active = false
	player_hit_timer = 0.0
	player_hit_frame = 0
	player_hit_side = -1
	boss_sprite_frame = 0
	boss_sprite_timer = 0.0
	boss_sprite_row = 1
	boss_hit_active = false
	boss_hit_timer = 0.0
	boss_hit_frame = 0
	boss_hit_frame_timer = 0.0
	dash_active = false
	dash_timer = 0.0
	dash_direction = 0.0
	dash_is_half = false
	dash_stun_timer = 0.0
	dash_available_timer = 0.0
	dash_elapsed_frames = 0.0
	player_speed = 0.0
	dash_key_released_since_last = true
	special_gauge_flash_timer = 0.0
	dash_orb_flash_timer = 0.0
	dash_divider_anim_progress = 1.0
	dash_prev_token_max = dash_tokens_max


func _serve_ball() -> void:
	waiting_for_serve = false
	ball_active = true
	ball_impact_boost = 1.0
	ball_boost_decay_rate = BALL_IMPACT_BASE_DECAY_RATE
	ball_min_boost = BALL_IMPACT_BASE_MIN_BOOST
	vertical_bounce_count = 0

	var direction = -1.0 if player_serves else 1.0
	var angle = randf_range(-0.3, 0.3)
	ball_vel = Vector2(angle * INITIAL_BALL_SPEED, direction * INITIAL_BALL_SPEED)

	if player_serves:
		ball_pos = Vector2(player_pos.x + PADDLE_WIDTH * 0.5, PLAYER_Y - BALL_SIZE)
	else:
		ball_pos = Vector2(boss_pos.x + BOSS_PADDLE_WIDTH * 0.5, BOSS_Y + BOSS_HITBOX_HEIGHT + BALL_SIZE)


func _update_ball(delta: float) -> void:
	if not ball_active:
		return

	var fps_scale = delta * 60.0
	var base_speed: float = ball_vel.length()
	if base_speed > SPEED_SCALE_THRESHOLD:
		ball_vel = ball_vel.normalized() * SPEED_SCALE_THRESHOLD

	_apply_ball_impact_decay(fps_scale)

	var effective_vel: Vector2 = _get_effective_ball_velocity() * fps_scale
	var total_distance: float = effective_vel.length()
	var num_steps := 1
	if total_distance > BALL_MAX_STEP_DISTANCE:
		num_steps = int(ceil(total_distance / BALL_MAX_STEP_DISTANCE))

	var step_move: Vector2 = effective_vel / float(num_steps)
	for _step in range(num_steps):
		ball_pos += step_move

		if ball_pos.x - BALL_SIZE * 0.5 <= 0.0:
			ball_pos.x = BALL_SIZE * 0.5
			ball_vel.x = abs(ball_vel.x) * WALL_DAMPING
			ball_vel.y *= WALL_DAMPING
			break
		elif ball_pos.x + BALL_SIZE * 0.5 >= WIDTH:
			ball_pos.x = WIDTH - BALL_SIZE * 0.5
			ball_vel.x = -abs(ball_vel.x) * WALL_DAMPING
			ball_vel.y *= WALL_DAMPING
			break

		var ball_rect = Rect2(ball_pos.x - BALL_SIZE * 0.5, ball_pos.y - BALL_SIZE * 0.5, BALL_SIZE, BALL_SIZE)

		if ball_vel.y > 0.0:
			var player_rect = Rect2(
				player_pos.x - HITBOX_PADDING,
				player_pos.y - HITBOX_PADDING,
				PADDLE_WIDTH + HITBOX_PADDING * 2.0,
				PADDLE_HEIGHT + HITBOX_PADDING * 2.0
			)
			if player_rect.intersects(ball_rect):
				_bounce_off_paddle(player_pos.x, PADDLE_WIDTH, true)
				break

		if ball_vel.y < 0.0:
			var boss_rect = Rect2(
				boss_pos.x - HITBOX_PADDING,
				boss_pos.y - HITBOX_PADDING,
				BOSS_PADDLE_WIDTH + HITBOX_PADDING * 2.0,
				BOSS_HITBOX_HEIGHT + HITBOX_PADDING * 2.0
			)
			if boss_rect.intersects(ball_rect):
				_bounce_off_paddle(boss_pos.x, BOSS_PADDLE_WIDTH, false)
				break

		if ball_pos.y < 0.0:
			_player_scored()
			return
		elif ball_pos.y > HEIGHT:
			_boss_scored()
			return

	ball_trail.append(ball_pos)
	if ball_trail.size() > 20:
		ball_trail.pop_front()


func _bounce_off_paddle(paddle_x: float, paddle_w: float, is_player: bool) -> void:
	var pre_hit_speed: float = ball_vel.length()
	var incoming_dx: float = ball_vel.x
	var hit_pos = (ball_pos.x - (paddle_x + paddle_w * 0.5)) / (paddle_w * 0.5)
	hit_pos = clamp(hit_pos, -1.0, 1.0)

	var outgoing_direction: float = -1.0 if is_player else 1.0
	var angle_rad = deg_to_rad(hit_pos * MAX_BOUNCE_ANGLE)
	var speed = ball_vel.length() * PADDLE_HIT_BOOST
	speed *= randf_range(BASE_HIT_SPEED_MULT_MIN, BASE_HIT_SPEED_MULT_MAX)
	if not is_player:
		speed *= randf_range(BOSS_HIT_SPEED_MULT_MIN, BOSS_HIT_SPEED_MULT_MAX)
	if abs(hit_pos) > 0.8:
		speed *= EDGE_HIT_BOOST
	ball_impact_boost = _compute_dynamic_impact_boost(pre_hit_speed)

	var bounce_vector := Vector2(0.0, outgoing_direction).rotated(angle_rad)

	if not is_player and abs(hit_pos) < BOSS_CENTER_PRESERVE_THRESHOLD:
		if abs(incoming_dx) > 0.5:
			var preserve_ratio: float = 0.7 * (1.0 - abs(hit_pos) / BOSS_CENTER_PRESERVE_THRESHOLD)
			bounce_vector.x += sign(incoming_dx) * preserve_ratio
			bounce_vector = bounce_vector.normalized()
		elif abs(bounce_vector.x) < MID_HIT_THRESHOLD:
			var force_dir: float = -1.0 if randf() < 0.5 else 1.0
			bounce_vector.x += force_dir * 0.5
			bounce_vector = bounce_vector.normalized()

	if abs(hit_pos) < CENTER_HIT_THRESHOLD:
		speed *= 1.03
	elif abs(hit_pos) < MID_HIT_THRESHOLD:
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-35.0, 35.0)))
	elif abs(hit_pos) > SMASH_HIT_THRESHOLD:
		speed *= randf_range(1.015, 1.05)
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-5.0, 5.0)))
	elif randf() < NORMAL_CURVE_CHANCE:
		bounce_vector = bounce_vector.rotated(deg_to_rad(randf_range(-20.0, 20.0)))

	bounce_vector = _ensure_min_vertical_component(bounce_vector, outgoing_direction)
	speed = clamp(speed, MIN_BALL_SPEED, MAX_BALL_SPEED)
	ball_vel = bounce_vector.normalized() * speed

	if abs(ball_vel.x) < 0.5:
		vertical_bounce_count += 1
		bounce_vector = bounce_vector.rotated(deg_to_rad(-3.0 if randf() < 0.5 else 3.0)).normalized()
		ball_vel = bounce_vector * speed
	else:
		vertical_bounce_count = 0

	if vertical_bounce_count >= 2:
		bounce_vector = bounce_vector.rotated(deg_to_rad(-15.0 if randf() < 0.5 else 15.0)).normalized()
		ball_vel = bounce_vector * speed
		vertical_bounce_count = 0

	if is_player:
		ball_pos.y = PLAYER_Y - BALL_SIZE
		special_gauge = min(special_gauge + GAUGE_CHARGE_PER_HIT, GAUGE_MAX)
		special_gauge_flash_timer = PILLAR_GAUGE_GAIN_FLASH_DURATION
		_trigger_player_hit_anim(hit_pos)
	else:
		ball_pos.y = BOSS_Y + BOSS_HITBOX_HEIGHT + BALL_SIZE
		_trigger_boss_hit_anim()

	hit_flash_timer = 0.08
	screen_shake = 0.10
	screen_shake_intensity = 3.0
	_spawn_hit_particles(ball_pos, PLAYER_COLOR_LIGHT if is_player else BOSS_COLOR_LIGHT)
	_play_paddle_hit_sound()


func _get_effective_ball_velocity() -> Vector2:
	return ball_vel * ball_impact_boost


func _compute_dynamic_impact_boost(current_speed: float) -> float:
	var speed_ratio: float = 0.0
	if current_speed <= BALL_IMPACT_SPEED_THRESHOLD_LOW:
		speed_ratio = 0.0
	elif current_speed >= BALL_IMPACT_SPEED_THRESHOLD_HIGH:
		speed_ratio = 1.0
	else:
		speed_ratio = (
			(current_speed - BALL_IMPACT_SPEED_THRESHOLD_LOW)
			/ (BALL_IMPACT_SPEED_THRESHOLD_HIGH - BALL_IMPACT_SPEED_THRESHOLD_LOW)
		)

	var ball_angle_deg := 90.0
	if abs(ball_vel.x) > 0.1:
		var ball_angle_rad: float = atan2(abs(ball_vel.y), abs(ball_vel.x))
		ball_angle_deg = rad_to_deg(ball_angle_rad)

	var angle_boost_multiplier := 2.0
	if ball_angle_deg >= 90.0:
		angle_boost_multiplier = 2.0
	elif ball_angle_deg >= 80.0:
		var angle_ratio_80: float = (90.0 - ball_angle_deg) / 10.0
		angle_boost_multiplier = 2.0 + 0.2 * angle_ratio_80
	elif ball_angle_deg >= 70.0:
		var angle_ratio_70: float = (80.0 - ball_angle_deg) / 10.0
		angle_boost_multiplier = 2.2 + 0.2 * angle_ratio_70
	elif ball_angle_deg >= 60.0:
		var angle_ratio_60: float = (70.0 - ball_angle_deg) / 10.0
		angle_boost_multiplier = 2.4 + 0.2 * angle_ratio_60
	elif ball_angle_deg >= 45.0:
		var angle_ratio_45: float = (60.0 - ball_angle_deg) / 15.0
		angle_boost_multiplier = 2.6 + 0.2 * angle_ratio_45
	else:
		angle_boost_multiplier = 2.8

	var base_boost: float = angle_boost_multiplier
	var min_boost_floor: float = 1.1
	var speed_ratio_softened: float = pow(speed_ratio, 0.7)
	var dynamic_boost: float = base_boost - (base_boost - min_boost_floor) * speed_ratio_softened
	dynamic_boost = min(dynamic_boost, BALL_IMPACT_STAGE1_CAP)

	var dynamic_decay_frames: float = 42.0 - (42.0 - 35.0) * speed_ratio
	var dynamic_min_boost: float = 0.70 - (0.70 - 0.55) * speed_ratio
	if dynamic_decay_frames > 0.0 and dynamic_boost > dynamic_min_boost:
		var speed_penalty_factor: float = 1.0 + speed_ratio * 0.18
		var adjusted_decay_frames: float = dynamic_decay_frames / speed_penalty_factor
		ball_boost_decay_rate = pow(dynamic_min_boost / dynamic_boost, 1.0 / adjusted_decay_frames)
	else:
		ball_boost_decay_rate = 0.95
	ball_min_boost = dynamic_min_boost
	return dynamic_boost


func _apply_ball_impact_decay(fps_scale: float) -> void:
	if ball_impact_boost <= ball_min_boost:
		return

	var current_speed: float = ball_vel.length() * ball_impact_boost
	var adaptive_decay_rate: float = ball_boost_decay_rate
	if current_speed < 10.0:
		adaptive_decay_rate = 1.0 - (1.0 - ball_boost_decay_rate) * 0.4
	elif current_speed < 15.0:
		adaptive_decay_rate = ball_boost_decay_rate
	else:
		var speed_ratio: float = min(current_speed / 25.0, 1.0)
		var penalty_factor: float = 1.0 + speed_ratio * 1.2
		adaptive_decay_rate = 1.0 - (1.0 - ball_boost_decay_rate) * penalty_factor
		if current_speed > 30.0:
			adaptive_decay_rate *= 0.95

	adaptive_decay_rate = clamp(adaptive_decay_rate, 0.01, 0.9999)
	ball_impact_boost *= pow(adaptive_decay_rate, fps_scale)
	if ball_impact_boost < ball_min_boost:
		ball_impact_boost = ball_min_boost


func _ensure_min_vertical_component(vector: Vector2, direction_sign: float) -> Vector2:
	if vector.length() == 0.0:
		return Vector2(0.0, direction_sign)

	var result: Vector2 = vector.normalized()
	var min_vertical_ratio: float = sin(deg_to_rad(MIN_BOUNCE_ANGLE_DEG))
	if abs(result.y) >= min_vertical_ratio:
		return result

	result.y = sign(direction_sign) * min_vertical_ratio
	var remaining_x_sq: float = max(0.0, 1.0 - result.y * result.y)
	var x_sign: float = sign(result.x)
	if x_sign == 0.0:
		x_sign = -1.0 if randf() < 0.5 else 1.0
	result.x = x_sign * sqrt(remaining_x_sq)
	return result.normalized()


func _play_paddle_hit_sound() -> void:
	if paddle_sound_cooldown > 0.0:
		return
	if paddle_hit_sfx == null or paddle_hit_sfx.stream == null:
		return
	paddle_hit_sfx.pitch_scale = randf_range(0.98, 1.02)
	if paddle_hit_sfx.playing:
		paddle_hit_sfx.stop()
	paddle_hit_sfx.play()
	paddle_sound_cooldown = PADDLE_HIT_SOUND_COOLDOWN


func _play_dash_start_sound(is_half: bool) -> void:
	var player: AudioStreamPlayer = half_dash_sfx if is_half else dash_sfx
	if player == null or player.stream == null:
		return
	player.pitch_scale = randf_range(0.98, 1.02)
	if player.playing:
		player.stop()
	player.play()


func _spawn_hit_particles(pos: Vector2, color: Color) -> void:
	for _i in range(8):
		hit_particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
			"life": randf_range(0.20, 0.40),
			"max_life": 0.40,
			"size": randf_range(2.0, 5.0),
			"color": color
		})


func _update_effects(delta: float) -> void:
	screen_shake = move_toward(screen_shake, 0.0, delta * 2.0)
	hit_flash_timer = move_toward(hit_flash_timer, 0.0, delta)
	paddle_sound_cooldown = max(0.0, paddle_sound_cooldown - delta)
	special_gauge_flash_timer = max(0.0, special_gauge_flash_timer - delta)
	dash_orb_flash_timer = max(0.0, dash_orb_flash_timer - delta)
	if dash_tokens_max != dash_prev_token_max:
		dash_prev_token_max = dash_tokens_max
		dash_divider_anim_progress = 0.0
	if dash_divider_anim_progress < 1.0:
		dash_divider_anim_progress = min(1.0, dash_divider_anim_progress + delta / PILLAR_DASH_DIVIDER_ANIM_DURATION)
	_update_player_sprite_animation(delta)
	_update_boss_sprite_animation(delta)
	_update_boss_hit_animation(delta)

	var to_remove: Array[int] = []
	for i in range(hit_particles.size()):
		var p: Dictionary = hit_particles[i]
		var particle_pos: Vector2 = p["pos"]
		var particle_vel: Vector2 = p["vel"]
		var particle_life: float = float(p["life"])
		particle_pos += particle_vel
		particle_vel *= 0.92
		particle_life -= delta
		p["pos"] = particle_pos
		p["vel"] = particle_vel
		p["life"] = particle_life
		hit_particles[i] = p
		if particle_life <= 0.0:
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		hit_particles.remove_at(idx)


func _update_boss_sprite_animation(delta: float) -> void:
	if boss_sprite_sheet == null:
		return

	if abs(boss_vel) > 0.2:
		boss_sprite_row = 0 if boss_vel < 0.0 else 1
		boss_sprite_timer += delta
		if boss_sprite_timer >= BOSS_SPRITE_ANIMATION_SPEED:
			boss_sprite_timer -= BOSS_SPRITE_ANIMATION_SPEED
			boss_sprite_frame = (boss_sprite_frame + 1) % BOSS_SPRITE_FRAME_COUNT
	else:
		boss_sprite_timer = 0.0
		boss_sprite_frame = 0


func _update_player_sprite_animation(delta: float) -> void:
	player_anim_clock += delta

	if player_hit_active:
		player_hit_timer -= delta
		if player_hit_timer <= 0.0:
			player_hit_active = false
		else:
			var hit_progress: float = _get_player_hit_progress()
			var frame_progress: float = _ease_out_cubic(hit_progress)
			player_hit_frame = min(
				int(floor(frame_progress * float(PLAYER_HIT_FRAME_COUNT))),
				PLAYER_HIT_FRAME_COUNT - 1
			)
		return

	var player_is_moving: bool = abs(player_speed) > 0.2 or dash_active
	if player_is_moving and player_sprite_texture != null:
		player_sprite_timer += delta
		if player_sprite_timer >= PLAYER_SPRITE_ANIMATION_SPEED:
			player_sprite_timer -= PLAYER_SPRITE_ANIMATION_SPEED
			player_sprite_frame = (player_sprite_frame + 1) % PLAYER_SPRITE_FRAME_COUNT
		player_idle_timer = 0.0
		player_idle_frame = 0
	else:
		player_sprite_timer = 0.0
		player_sprite_frame = 0
		if player_idle_sprite_texture != null:
			player_idle_timer += delta
			if player_idle_timer >= PLAYER_IDLE_ANIMATION_SPEED:
				player_idle_timer -= PLAYER_IDLE_ANIMATION_SPEED
				player_idle_frame = (player_idle_frame + 1) % PLAYER_IDLE_FRAME_COUNT


func _trigger_player_hit_anim(hit_pos: float) -> void:
	if player_hit_sprite_texture == null and player_hit_left_strip_texture == null and player_hit_right_strip_texture == null:
		return
	player_hit_active = true
	player_hit_timer = PLAYER_HIT_ANIM_DURATION
	player_hit_frame = 0
	player_hit_side = 1 if hit_pos >= 0.0 else -1


func _get_player_idle_sprite_region() -> Rect2:
	var frame_x: float = PLAYER_SPRITE_FRAME_WIDTH * float(player_idle_frame)
	return Rect2(frame_x, 0.0, PLAYER_SPRITE_FRAME_WIDTH, PLAYER_SPRITE_FRAME_HEIGHT)


func _get_player_hit_sprite_region() -> Rect2:
	var frame_x: float = PLAYER_HIT_FRAME_WIDTH * float(player_hit_frame)
	return Rect2(frame_x, 0.0, PLAYER_HIT_FRAME_WIDTH, PLAYER_HIT_FRAME_HEIGHT)


func _get_player_sprite_region() -> Rect2:
	var frame_x: float = PLAYER_SPRITE_FRAME_WIDTH * float(player_sprite_frame)
	return Rect2(frame_x, 0.0, PLAYER_SPRITE_FRAME_WIDTH, PLAYER_SPRITE_FRAME_HEIGHT)


func _trigger_boss_hit_anim() -> void:
	if boss_hit_sprite_sheet == null:
		return
	boss_hit_active = true
	boss_hit_timer = BOSS_HIT_ANIM_DURATION
	boss_hit_frame = 0
	boss_hit_frame_timer = 0.0
	boss_hit_row = 0 if boss_vel < 0.0 else 1


func _update_boss_hit_animation(delta: float) -> void:
	if not boss_hit_active:
		return
	boss_hit_timer -= delta
	if boss_hit_timer <= 0.0:
		boss_hit_active = false
		return
	boss_hit_frame_timer += delta
	if boss_hit_frame_timer >= BOSS_HIT_FRAME_SPEED:
		boss_hit_frame_timer -= BOSS_HIT_FRAME_SPEED
		boss_hit_frame = (boss_hit_frame + 1) % BOSS_HIT_FRAME_COUNT


func _get_boss_hit_sprite_region() -> Rect2:
	var frame_width_float: float = 1024.0 / float(BOSS_HIT_FRAME_COUNT)
	var frame_center_x: float = floor(frame_width_float * (float(boss_hit_frame) + 0.5))
	var frame_x: float = frame_center_x - BOSS_SPRITE_FRAME_WIDTH * 0.5
	var frame_y: float = BOSS_SPRITE_FRAME_HEIGHT * float(boss_hit_row)
	return Rect2(frame_x, frame_y, BOSS_SPRITE_FRAME_WIDTH, BOSS_SPRITE_FRAME_HEIGHT)


func _get_boss_sprite_region() -> Rect2:
	var frame_width_float: float = 1024.0 / float(BOSS_SPRITE_FRAME_COUNT)
	var frame_center_x: float = floor(frame_width_float * (float(boss_sprite_frame) + 0.5))
	var frame_x: float = frame_center_x - BOSS_SPRITE_FRAME_WIDTH * 0.5
	var frame_y: float = BOSS_SPRITE_FRAME_HEIGHT * float(boss_sprite_row)
	return Rect2(frame_x, frame_y, BOSS_SPRITE_FRAME_WIDTH, BOSS_SPRITE_FRAME_HEIGHT)


func _player_scored() -> void:
	if deuce_mode:
		player_score += 1
		_check_deuce_end()
	else:
		player_score += 1
		_check_win()
	player_serves = false
	_reset_ball()


func _boss_scored() -> void:
	if deuce_mode:
		boss_score += 1
		_check_deuce_end()
	else:
		boss_score += 1
		_check_win()
	player_serves = true
	_reset_ball()


func _check_win() -> void:
	if player_score >= WIN_GOAL:
		_reset_game()
	elif boss_score >= WIN_GOAL:
		_reset_game()
	elif player_score == DEUCE_TRIGGER and boss_score == DEUCE_TRIGGER:
		deuce_mode = true
		deuce_goal = DEUCE_GOAL_1


func _check_deuce_end() -> void:
	if player_score == 5 and boss_score == 5:
		deuce_goal = DEUCE_GOAL_2
	if player_score >= deuce_goal or boss_score >= deuce_goal:
		_reset_game()


func _reset_game() -> void:
	player_score = 0
	boss_score = 0
	deuce_mode = false
	deuce_goal = DEUCE_GOAL_1
	player_serves = true
	special_gauge = 0.0
	dash_tokens = dash_tokens_max
	dash_charge_timer = 0.0
	dash_consecutive_count = 0
	_reset_ball()


func _draw() -> void:
	var shake_offset = Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(
			randf_range(-screen_shake_intensity, screen_shake_intensity),
			randf_range(-screen_shake_intensity, screen_shake_intensity)
		) * screen_shake

	var view_size: Vector2 = get_viewport_rect().size
	var render_margin_y: float = max(floor(view_size.y * 0.065), 30.0)
	var render_scale: float = (view_size.y - render_margin_y * 2.0) / HEIGHT
	var scaled_game_size := Vector2(WIDTH * render_scale, HEIGHT * render_scale)
	var game_offset := Vector2(
		(view_size.x - scaled_game_size.x) * 0.5,
		(view_size.y - scaled_game_size.y) * 0.5
	)

	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.02, 0.05))
	_draw_stage1_pillar_background(view_size, game_offset, scaled_game_size)

	draw_set_transform(game_offset, 0.0, Vector2(render_scale, render_scale))

	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), BG_COLOR)

	if hit_flash_timer > 0.0:
		var flash_alpha = (hit_flash_timer / 0.08) * 0.06
		draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color(1.0, 1.0, 1.0, flash_alpha))

	draw_line(
		Vector2(PLAY_LEFT, HEIGHT * 0.5) + shake_offset,
		Vector2(PLAY_RIGHT, HEIGHT * 0.5) + shake_offset,
		LINE_COLOR,
		1.0
	)
	draw_line(
		Vector2(PLAY_LEFT, 120) + shake_offset,
		Vector2(PLAY_RIGHT, 120) + shake_offset,
		LINE_COLOR,
		1.0
	)
	draw_line(
		Vector2(PLAY_LEFT, 630) + shake_offset,
		Vector2(PLAY_RIGHT, 630) + shake_offset,
		LINE_COLOR,
		1.0
	)

	if dash_active:
		var dash_trail_color: Color = HALF_DASH_COLOR if dash_is_half else DASH_TRAIL_COLOR
		for i in range(3):
			var offset: float = -dash_direction * float(i + 1) * 15.0
			var alpha: float = 0.30 - float(i) * 0.10
			draw_rect(
				Rect2(
					player_pos.x + offset + shake_offset.x,
					player_pos.y + shake_offset.y,
					PADDLE_WIDTH,
					PADDLE_HEIGHT
				),
				Color(dash_trail_color.r, dash_trail_color.g, dash_trail_color.b, alpha)
			)

	var player_shadow_rect: Rect2 = Rect2(
		0.0,
		0.0,
		0.0,
		0.0
	)
	var player_move_active: bool = abs(player_speed) > 0.2 or dash_active
	var hover_wave: float = sin(player_anim_clock * PLAYER_HOVER_SPEED)
	var hover_offset: float = hover_wave * PLAYER_HOVER_AMPLITUDE
	var move_bob: float = 0.0
	var breath_wave: float = 0.0
	var player_draw_size: Vector2 = PLAYER_SPRITE_DRAW_SIZE
	var player_visual_x_offset: float = 0.0

	if player_move_active:
		move_bob = abs(sin(player_anim_clock * 10.0)) * PLAYER_MOVE_BOB_AMPLITUDE
	else:
		breath_wave = sin(player_anim_clock * 5.236)
		player_draw_size.x *= 1.0 - breath_wave * PLAYER_IDLE_BREATH_SCALE_X
		player_draw_size.y *= 1.0 + breath_wave * PLAYER_IDLE_BREATH_SCALE_Y

	var player_visual_y_offset: float = -hover_offset - move_bob - (breath_wave * PLAYER_IDLE_BREATH_Y)
	if player_hit_active:
		var hit_progress: float = _get_player_hit_progress()
		var hit_snap: float = 1.0 - _ease_out_cubic(hit_progress)
		var hit_rebound: float = _ease_in_out_sine(hit_progress) * (1.0 - hit_progress)
		player_visual_x_offset = float(player_hit_side) * (
			PLAYER_HIT_LUNGE_X * hit_snap - PLAYER_HIT_REBOUND_X * hit_rebound
		)
		player_visual_y_offset += -PLAYER_HIT_LUNGE_Y * hit_snap + PLAYER_HIT_REBOUND_Y * hit_rebound
		player_draw_size.x *= 1.0 + PLAYER_HIT_SCALE_X * hit_snap - PLAYER_HIT_SCALE_X * 0.35 * hit_rebound
		player_draw_size.y *= 1.0 - PLAYER_HIT_SCALE_Y * hit_snap + PLAYER_HIT_SCALE_Y * 0.4 * hit_rebound

	var shadow_scale: float = 1.0 - ((hover_offset + PLAYER_HOVER_AMPLITUDE) / (PLAYER_HOVER_AMPLITUDE * 2.0)) * 0.18
	var shadow_width: float = 180.0 * shadow_scale
	var shadow_height: float = 16.0 * shadow_scale
	player_shadow_rect = Rect2(
		player_pos.x + PADDLE_WIDTH * 0.5 - shadow_width * 0.5 + shake_offset.x,
		player_pos.y + PADDLE_HEIGHT - 6.0 + shake_offset.y,
		shadow_width,
		shadow_height
	)
	_draw_soft_shadow_ellipse(
		player_shadow_rect,
		Color(0.0, 0.0, 0.0, 0.18 + (1.0 - shadow_scale) * 0.05)
	)

	if (
		player_sprite_texture != null
		or player_idle_sprite_texture != null
		or player_hit_sprite_texture != null
		or player_hit_left_strip_texture != null
		or player_hit_right_strip_texture != null
	):
		var player_visual_rect := Rect2(
			player_pos.x + PADDLE_WIDTH * 0.5 - player_draw_size.x * 0.5 + shake_offset.x + player_visual_x_offset,
			player_pos.y + PADDLE_HEIGHT - player_draw_size.y + 12.0 + shake_offset.y + player_visual_y_offset,
			player_draw_size.x,
			player_draw_size.y
		)

		if player_hit_active:
			var hit_texture: Texture2D = player_hit_left_strip_texture if player_hit_side < 0 else player_hit_right_strip_texture
			if hit_texture != null:
				draw_texture_rect_region(hit_texture, player_visual_rect, _get_player_hit_sprite_region(), Color.WHITE, false, true)
			elif player_hit_sprite_texture != null:
				draw_texture_rect(player_hit_sprite_texture, player_visual_rect, false)
		elif not player_move_active and player_idle_sprite_texture != null:
			draw_texture_rect_region(player_idle_sprite_texture, player_visual_rect, _get_player_idle_sprite_region(), Color.WHITE, false, true)
		elif player_sprite_texture != null:
			draw_texture_rect_region(player_sprite_texture, player_visual_rect, _get_player_sprite_region(), Color.WHITE, false, true)
		else:
			draw_rect(Rect2(player_pos + shake_offset, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT)), PLAYER_COLOR)
	else:
		draw_rect(Rect2(player_pos + shake_offset, Vector2(PADDLE_WIDTH, PADDLE_HEIGHT)), PLAYER_COLOR)
		draw_rect(
			Rect2(player_pos.x + 2.0 + shake_offset.x, player_pos.y + 2.0 + shake_offset.y, PADDLE_WIDTH - 4.0, PADDLE_HEIGHT / 3.0),
			PLAYER_COLOR_LIGHT
		)

	var boss_shadow_rect := Rect2(
		boss_pos.x + BOSS_PADDLE_WIDTH * 0.5 - 42.0 + shake_offset.x,
		boss_pos.y + BOSS_HITBOX_HEIGHT - 6.0 + shake_offset.y,
		84.0,
		12.0
	)
	draw_rect(boss_shadow_rect, Color(0.0, 0.0, 0.0, 0.16), true)

	if boss_sprite_sheet != null:
		var boss_visual_center_y: float = boss_pos.y + BOSS_HITBOX_HEIGHT * 0.5 + BOSS_STAGE1_VISUAL_CENTER_Y_OFFSET
		var boss_visual_rect := Rect2(
			boss_pos.x + BOSS_PADDLE_WIDTH * 0.5 - BOSS_SPRITE_DRAW_SIZE.x * 0.5 + shake_offset.x,
			boss_visual_center_y - BOSS_SPRITE_DRAW_SIZE.y * 0.5 + shake_offset.y,
			BOSS_SPRITE_DRAW_SIZE.x,
			BOSS_SPRITE_DRAW_SIZE.y
		)
		if boss_hit_active and boss_hit_sprite_sheet != null:
			draw_texture_rect_region(boss_hit_sprite_sheet, boss_visual_rect, _get_boss_hit_sprite_region(), Color.WHITE, false, true)
		else:
			draw_texture_rect_region(boss_sprite_sheet, boss_visual_rect, _get_boss_sprite_region(), Color.WHITE, false, true)
	else:
		draw_rect(Rect2(boss_pos + shake_offset, Vector2(BOSS_PADDLE_WIDTH, BOSS_PADDLE_HEIGHT)), BOSS_COLOR)
		draw_rect(
			Rect2(
				boss_pos.x + 2.0 + shake_offset.x,
				boss_pos.y + BOSS_PADDLE_HEIGHT - BOSS_PADDLE_HEIGHT / 3.0 + shake_offset.y,
				BOSS_PADDLE_WIDTH - 4.0,
				BOSS_PADDLE_HEIGHT / 3.0
			),
			BOSS_COLOR_LIGHT
		)

	if ball_active and ball_trail.size() > 1:
		for i in range(ball_trail.size()):
			var ratio: float = float(i + 1) / float(ball_trail.size())
			_draw_energy_ball_trail(ball_trail[i] + shake_offset, ratio)

	if ball_active or waiting_for_serve:
		var draw_pos: Vector2 = ball_pos
		if waiting_for_serve:
			if player_serves:
				draw_pos = Vector2(player_pos.x + PADDLE_WIDTH * 0.5, PLAYER_Y - BALL_RENDER_RADIUS)
			else:
				draw_pos = Vector2(boss_pos.x + BOSS_PADDLE_WIDTH * 0.5, BOSS_Y + BOSS_HITBOX_HEIGHT + BALL_RENDER_RADIUS)
		_draw_energy_ball(draw_pos + shake_offset)

	for p in hit_particles:
		var life: float = float(p["life"])
		var max_life: float = float(p["max_life"])
		var alpha: float = life / max_life
		var size: float = float(p["size"]) * alpha
		var particle_pos: Vector2 = p["pos"]
		var color: Color = p["color"]
		draw_circle(particle_pos + shake_offset, size, Color(color.r, color.g, color.b, alpha))

	var inner_wall_time: float = float(Time.get_ticks_msec()) / 1000.0
	_draw_inner_side_vignette(Rect2(0.0, 0.0, PILLAR_WIDTH, HEIGHT), false, inner_wall_time)
	_draw_inner_side_vignette(Rect2(WIDTH - PILLAR_WIDTH, 0.0, PILLAR_WIDTH, HEIGHT), true, inner_wall_time)

	_draw_hud()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stage1_pillar_background(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var left_rect := Rect2(0.0, 0.0, game_offset.x, view_size.y)
	var right_rect := Rect2(game_offset.x + game_size.x, 0.0, max(0.0, view_size.x - (game_offset.x + game_size.x)), view_size.y)
	var top_rect := Rect2(game_offset.x, 0.0, game_size.x, game_offset.y)
	var bottom_rect := Rect2(game_offset.x, game_offset.y + game_size.y, game_size.x, max(0.0, view_size.y - (game_offset.y + game_size.y)))

	if left_rect.size.x > 0.0:
		_draw_stage1_pillar_panel(left_rect, false, t)
	if right_rect.size.x > 0.0:
		_draw_stage1_pillar_panel(right_rect, true, t)
	if top_rect.size.y > 0.0:
		_draw_stage1_border_band(top_rect, t)
	if bottom_rect.size.y > 0.0:
		_draw_stage1_border_band(bottom_rect, t + PI * 0.5)

	var game_rect := Rect2(game_offset, game_size)
	draw_rect(game_rect, Color(PILLAR_GOLD_DARK.r, PILLAR_GOLD_DARK.g, PILLAR_GOLD_DARK.b, 0.75), false, 2.0)
	draw_rect(Rect2(game_offset.x - 4.0, game_offset.y - 4.0, game_size.x + 8.0, game_size.y + 8.0), Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.25), false, 1.0)
	_draw_stage1_frame_motifs(game_rect, t)
	_draw_stage1_pillar_ui(game_offset, game_size, t)


func _draw_stage1_border_band(rect: Rect2, t: float) -> void:
	for y in range(0, int(rect.size.y), 4):
		var ratio: float = float(y) / max(1.0, rect.size.y)
		var wave: float = sin(t + ratio * 8.0) * 0.03
		var color_r: float = clamp(PILLAR_SILK_DARK.r + (PILLAR_SILK_LIGHT.r - PILLAR_SILK_DARK.r) * (0.28 + wave), 0.0, 1.0)
		var color_g: float = clamp(PILLAR_SILK_DARK.g + (PILLAR_SILK_LIGHT.g - PILLAR_SILK_DARK.g) * (0.28 + wave), 0.0, 1.0)
		var color_b: float = clamp(PILLAR_SILK_DARK.b + (PILLAR_SILK_LIGHT.b - PILLAR_SILK_DARK.b) * (0.28 + wave), 0.0, 1.0)
		draw_rect(Rect2(rect.position.x, rect.position.y + float(y), rect.size.x, 4.0), Color(color_r, color_g, color_b, 1.0))
	draw_rect(rect, Color(PILLAR_GOLD_DARK.r, PILLAR_GOLD_DARK.g, PILLAR_GOLD_DARK.b, 0.95), false, 2.0)
	draw_rect(rect.grow(-4.0), Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.80), false, 1.0)


func _draw_stage1_pillar_panel(rect: Rect2, mirrored: bool, t: float) -> void:
	for y in range(0, int(rect.size.y), 6):
		var ratio: float = float(y) / rect.size.y
		var center_bias: float = 1.0 - abs(ratio - 0.5) * 1.3
		var silk_wave: float = sin(ratio * 16.0 + t * 0.7 + (PI if mirrored else 0.0)) * 0.035
		var color_r: float = clamp(PILLAR_SILK_DARK.r + (PILLAR_SILK_LIGHT.r - PILLAR_SILK_DARK.r) * (0.3 + center_bias * 0.4 + silk_wave), 0.0, 1.0)
		var color_g: float = clamp(PILLAR_SILK_DARK.g + (PILLAR_SILK_LIGHT.g - PILLAR_SILK_DARK.g) * (0.3 + center_bias * 0.4 + silk_wave), 0.0, 1.0)
		var color_b: float = clamp(PILLAR_SILK_DARK.b + (PILLAR_SILK_LIGHT.b - PILLAR_SILK_DARK.b) * (0.3 + center_bias * 0.4 + silk_wave), 0.0, 1.0)
		draw_rect(Rect2(rect.position.x, rect.position.y + float(y), rect.size.x, 6.0), Color(color_r, color_g, color_b, 1.0))

	for x in range(0, int(rect.size.x), 10):
		var stripe_alpha: float = 0.03 + sin(t * 0.9 + float(x) * 0.22) * 0.01
		draw_rect(
			Rect2(rect.position.x + float(x), rect.position.y, 4.0, rect.size.y),
			Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, stripe_alpha)
		)

	draw_rect(rect, Color(PILLAR_GOLD_DARK.r, PILLAR_GOLD_DARK.g, PILLAR_GOLD_DARK.b, 0.95), false, 2.0)
	draw_rect(rect.grow(-4.0), Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.85), false, 2.0)
	draw_rect(rect.grow(-8.0), Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.55), false, 1.0)

	var seam_x: float = rect.position.x + (6.0 if not mirrored else rect.size.x - 6.0)
	draw_line(
		Vector2(seam_x, rect.position.y + 10.0),
		Vector2(seam_x, rect.position.y + rect.size.y - 10.0),
		Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.35),
		1.0
	)

	var center_x: float = rect.position.x + rect.size.x * 0.5
	_draw_stage1_flower(Vector2(center_x, 108.0), 20.0, t * 12.0)
	_draw_stage1_flower(Vector2(center_x + (8.0 if mirrored else -8.0), rect.position.y + rect.size.y * 0.5), 18.0, -t * 10.0)
	_draw_stage1_flower(Vector2(center_x, rect.position.y + rect.size.y - 118.0), 22.0, t * 9.0)

	_draw_stage1_branch(rect, mirrored)
	_draw_stage1_butterflies(rect, mirrored, t)
	_draw_stage1_petals(rect, mirrored, t)


func _draw_stage1_flower(center: Vector2, size: float, rotation_deg: float) -> void:
	draw_circle(center, size * 0.22, Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.95))
	draw_circle(center, size * 0.11, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.95))
	for i in range(6):
		var angle: float = deg_to_rad(rotation_deg + float(i) * 60.0)
		var petal_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * size * 0.45
		draw_circle(petal_center, size * 0.23, Color(PILLAR_RED.r, PILLAR_RED.g, PILLAR_RED.b, 0.82))
		draw_circle(petal_center + Vector2(-1.0, -1.0), size * 0.10, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.55))
	draw_circle(center, size * 0.60, Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.18))


func _draw_stage1_branch(rect: Rect2, mirrored: bool) -> void:
	var start_x: float = rect.position.x + (10.0 if not mirrored else rect.size.x - 10.0)
	var base_points: PackedVector2Array = PackedVector2Array()
	for i in range(7):
		var ratio: float = float(i) / 6.0
		var dir: float = 1.0 if not mirrored else -1.0
		var x: float = start_x + dir * (14.0 + sin(ratio * PI * 2.0) * 8.0)
		var y: float = rect.position.y + 60.0 + ratio * (rect.size.y - 120.0)
		base_points.append(Vector2(x, y))
	if base_points.size() >= 2:
		draw_polyline(base_points, Color(PILLAR_BROWN.r, PILLAR_BROWN.g, PILLAR_BROWN.b, 0.85), 2.0)
	for i in range(1, base_points.size() - 1):
		var p: Vector2 = base_points[i]
		var leaf_offset: float = 12.0 if i % 2 == 0 else -12.0
		var dir_mul: float = 1.0 if not mirrored else -1.0
		var leaf_center: Vector2 = p + Vector2(leaf_offset * dir_mul, -6.0 + float(i % 3) * 4.0)
		draw_circle(leaf_center, 4.5, Color(PILLAR_GREEN.r, PILLAR_GREEN.g, PILLAR_GREEN.b, 0.78))
		draw_circle(leaf_center + Vector2(-1.0 * dir_mul, -1.0), 2.0, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.20))


func _draw_stage1_butterflies(rect: Rect2, mirrored: bool, t: float) -> void:
	for i in range(2):
		var phase: float = t * (1.5 + float(i) * 0.22) + float(i) * 1.7
		var wing_open: float = sin(phase * 7.0) * 4.0
		var x_center: float = rect.position.x + rect.size.x * (0.48 + sin(phase * 0.8) * 0.12)
		var y_center: float = 165.0 + float(i) * 220.0 + sin(phase * 1.3) * 18.0
		if mirrored:
			x_center = rect.position.x + rect.size.x * (0.52 - sin(phase * 0.8) * 0.12)

		var wing_color: Color = PILLAR_BUTTERFLY_BLUE if i == 0 else PILLAR_BUTTERFLY_GOLD
		if mirrored and i == 1:
			wing_color = PILLAR_BUTTERFLY_RED

		var center: Vector2 = Vector2(x_center, y_center)
		draw_circle(center + Vector2(-6.0 - wing_open, -1.0), 5.0, Color(wing_color.r, wing_color.g, wing_color.b, 0.82))
		draw_circle(center + Vector2(6.0 + wing_open, -1.0), 5.0, Color(wing_color.r, wing_color.g, wing_color.b, 0.82))
		draw_circle(center + Vector2(-4.0 - wing_open * 0.6, 4.0), 3.8, Color(wing_color.r, wing_color.g, wing_color.b, 0.72))
		draw_circle(center + Vector2(4.0 + wing_open * 0.6, 4.0), 3.8, Color(wing_color.r, wing_color.g, wing_color.b, 0.72))
		draw_line(center + Vector2(0.0, -5.0), center + Vector2(0.0, 6.0), Color(0.20, 0.16, 0.12, 0.90), 1.2)
		draw_line(center + Vector2(-1.0, -4.0), center + Vector2(-4.0, -8.0), Color(0.20, 0.16, 0.12, 0.65), 1.0)
		draw_line(center + Vector2(1.0, -4.0), center + Vector2(4.0, -8.0), Color(0.20, 0.16, 0.12, 0.65), 1.0)
		draw_circle(center + Vector2(-6.0 - wing_open, -1.0), 1.2, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.30))
		draw_circle(center + Vector2(6.0 + wing_open, -1.0), 1.2, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.30))


func _draw_stage1_petals(rect: Rect2, mirrored: bool, t: float) -> void:
	for i in range(4):
		var fall_progress: float = fmod(t * (0.14 + float(i) * 0.018) + float(i) * 0.23, 1.0)
		var y: float = rect.position.y - 24.0 + fall_progress * (rect.size.y + 48.0)
		var drift: float = sin(t * 1.8 + float(i) * 1.4) * 12.0
		var x: float = rect.position.x + rect.size.x * 0.5 + drift
		if mirrored:
			x = rect.position.x + rect.size.x * 0.5 - drift
		var petal_color: Color = Color(1.0, 0.86 - float(i) * 0.03, 0.90 - float(i) * 0.04, 0.58)
		draw_circle(Vector2(x, y), 3.0 + float(i % 2), petal_color)
		draw_circle(Vector2(x - 1.0, y - 1.0), 1.2, Color(PILLAR_CREAM.r, PILLAR_CREAM.g, PILLAR_CREAM.b, 0.20))


func _draw_stage1_thunder_symbol(origin: Vector2, size: float, vertical: bool, color: Color) -> void:
	var s: float = size
	var points: PackedVector2Array = PackedVector2Array()
	if not vertical:
		points = PackedVector2Array([
			origin + Vector2(0.0, 0.0),
			origin + Vector2(s, 0.0),
			origin + Vector2(s, s * 0.50),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(s * 0.50, s),
			origin + Vector2(0.0, s),
			origin + Vector2(0.0, s * 0.50),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(s * 0.50, 0.0),
		])
	else:
		points = PackedVector2Array([
			origin + Vector2(0.0, 0.0),
			origin + Vector2(0.0, s),
			origin + Vector2(s * 0.50, s),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(s, s * 0.50),
			origin + Vector2(s, 0.0),
			origin + Vector2(s * 0.50, 0.0),
			origin + Vector2(s * 0.50, s * 0.50),
			origin + Vector2(0.0, s * 0.50),
		])
	draw_polyline(points, color, max(1.0, size * 0.16))


func _draw_stage1_frame_motifs(game_rect: Rect2, t: float) -> void:
	var scale_factor: float = game_rect.size.y / HEIGHT
	var thunder_color := Color(PILLAR_GOLD_BRIGHT.r, PILLAR_GOLD_BRIGHT.g, PILLAR_GOLD_BRIGHT.b, 0.42 + 0.08 * sin(t * 2.0))
	var thunder_dim := Color(PILLAR_GOLD.r, PILLAR_GOLD.g, PILLAR_GOLD.b, 0.22)
	var thunder_size: float = 8.0 * scale_factor
	var spacing_x: float = max(28.0 * scale_factor, game_rect.size.x / 20.0)
	var spacing_y: float = max(28.0 * scale_factor, game_rect.size.y / 18.0)
	var start_x: float = game_rect.position.x + 28.0 * scale_factor
	var end_x: float = game_rect.end.x - 28.0 * scale_factor
	var start_y: float = game_rect.position.y + 28.0 * scale_factor
	var end_y: float = game_rect.end.y - 28.0 * scale_factor

	var x: float = start_x
	while x < end_x:
		_draw_stage1_thunder_symbol(Vector2(x, game_rect.position.y - 12.0 * scale_factor), thunder_size, false, thunder_color)
		_draw_stage1_thunder_symbol(Vector2(x, game_rect.end.y + 2.0 * scale_factor), thunder_size, false, thunder_dim)
		x += spacing_x

	var y: float = start_y
	while y < end_y:
		_draw_stage1_thunder_symbol(Vector2(game_rect.position.x - 12.0 * scale_factor, y), thunder_size, true, thunder_dim)
		_draw_stage1_thunder_symbol(Vector2(game_rect.end.x + 2.0 * scale_factor, y), thunder_size, true, thunder_color)
		y += spacing_y

	var corner_size: float = clamp(22.0 * scale_factor, 14.0, 28.0)
	_draw_stage1_flower(game_rect.position + Vector2(-18.0, -18.0) * scale_factor, corner_size, t * 18.0)
	_draw_stage1_flower(Vector2(game_rect.end.x + 18.0 * scale_factor, game_rect.position.y - 18.0 * scale_factor), corner_size, -t * 14.0)
	_draw_stage1_flower(Vector2(game_rect.position.x - 18.0 * scale_factor, game_rect.end.y + 18.0 * scale_factor), corner_size, -t * 16.0)
	_draw_stage1_flower(game_rect.end + Vector2(18.0, 18.0) * scale_factor, corner_size, t * 20.0)


func _draw_pillar_orb_frame(center: Vector2, radius: float, frame_width: float, metal_dark: Color, metal_mid: Color, metal_light: Color, gem_core: Color, gem_highlight: Color) -> void:
	draw_circle(center, radius + frame_width, metal_dark)
	draw_arc(center, radius + frame_width - 1.0, 0.0, TAU, 48, Color(metal_mid.r, metal_mid.g, metal_mid.b, 0.95), 4.0)
	draw_arc(center, radius + frame_width - 4.5, 0.0, TAU, 48, Color(metal_light.r, metal_light.g, metal_light.b, 0.82), 2.0)
	draw_arc(center, radius + frame_width - 5.5, deg_to_rad(200.0), deg_to_rad(340.0), 22, Color(1.0, 0.97, 0.86, 0.62), 3.0)
	draw_arc(center, radius + frame_width - 5.5, deg_to_rad(20.0), deg_to_rad(160.0), 22, Color(0.12, 0.08, 0.05, 0.62), 3.0)
	draw_arc(center, radius + 1.5, 0.0, TAU, 48, Color(0.08, 0.06, 0.04, 0.85), 2.0)

	for i in range(8):
		var angle: float = -PI * 0.5 + float(i) * TAU / 8.0
		var stud_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.55)
		draw_circle(stud_pos, frame_width * 0.58, Color(metal_dark.r * 0.70, metal_dark.g * 0.70, metal_dark.b * 0.70, 1.0))
		draw_circle(stud_pos, frame_width * 0.48, metal_mid)
		draw_circle(stud_pos, frame_width * 0.36, metal_light)
		draw_circle(stud_pos, frame_width * 0.24, gem_core)
		draw_circle(stud_pos + Vector2(-1.0, -1.0), frame_width * 0.11, Color(gem_highlight.r, gem_highlight.g, gem_highlight.b, 0.90))

	for angle_deg in [315.0, 45.0, 225.0, 135.0]:
		var angle: float = deg_to_rad(angle_deg)
		var bolt_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + frame_width * 0.92)
		draw_circle(bolt_pos, frame_width * 0.60, Color(metal_dark.r * 0.82, metal_dark.g * 0.82, metal_dark.b * 0.82, 1.0))
		draw_circle(bolt_pos, frame_width * 0.50, metal_mid)
		draw_circle(bolt_pos, frame_width * 0.38, metal_light)
		draw_circle(bolt_pos, frame_width * 0.24, gem_core)
		draw_circle(bolt_pos + Vector2(-1.0, -1.0), frame_width * 0.12, Color(gem_highlight.r, gem_highlight.g, gem_highlight.b, 0.72))


func _draw_pillar_orb_glass(center: Vector2, radius: float, rim_color: Color) -> void:
	var highlight_rect_1 := Rect2(center.x - radius + 8.0, center.y - radius + 5.0, radius + 12.0, radius * 0.55)
	var highlight_rect_2 := Rect2(center.x - radius + 14.0, center.y - radius + 11.0, max(8.0, radius - 10.0), radius * 0.36)
	var highlight_rect_3 := Rect2(center.x - radius + 18.0, center.y - radius + 15.0, max(7.0, radius * 0.56), max(6.0, radius * 0.25))
	draw_colored_polygon(_build_ellipse_points(highlight_rect_1, 24), Color(1.0, 1.0, 1.0, 0.12))
	draw_colored_polygon(_build_ellipse_points(highlight_rect_2, 24), Color(1.0, 1.0, 1.0, 0.18))
	draw_colored_polygon(_build_ellipse_points(highlight_rect_3, 20), Color(1.0, 1.0, 1.0, 0.22))
	draw_circle(center + Vector2(-radius * 0.34, -radius * 0.34), max(1.5, radius * 0.06), Color(1.0, 1.0, 1.0, 0.72))
	draw_circle(center + Vector2(-radius * 0.30, -radius * 0.30), max(1.0, radius * 0.04), Color(1.0, 1.0, 1.0, 0.42))
	draw_arc(center, radius - 2.0, deg_to_rad(30.0), deg_to_rad(150.0), 18, Color(rim_color.r, rim_color.g, rim_color.b, 0.20), 2.0)


func _draw_pillar_text_centered(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.35)
	for offset in [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)]:
		draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, min(1.0, color.a + 0.20)))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_pillar_liquid_fill(center: Vector2, radius: float, fill_ratio: float, t: float, top_color: Color, bottom_color: Color, wave_glow: Color) -> void:
	var clamped_ratio: float = clamp(fill_ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return

	var inner_radius: float = max(4.0, radius)
	var fill_height: float = inner_radius * 2.0 * clamped_ratio
	var fill_top: float = center.y + inner_radius - fill_height
	var wave_amp: float = max(3.5, inner_radius * 0.10)
	var wave_offset: float = sin(t * 2.3) * wave_amp * 0.5
	var prev_wave_point: Vector2 = Vector2.ZERO
	var has_prev: bool = false

	# --- liquid column fill (2px stride for performance) ---
	var step: int = 2
	for ix in range(int(-inner_radius), int(inner_radius) + 1, step):
		var local_x: float = float(ix)
		var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
		var primary_wave: float = sin(local_x * 0.08 + t * 3.8) * wave_amp
		var secondary_wave: float = cos(local_x * 0.05 - t * 4.6) * wave_amp * 0.55
		var wave_y: float = fill_top + primary_wave + secondary_wave + wave_offset
		var line_top: float = clamp(max(center.y - y_limit, wave_y), center.y - y_limit, center.y + y_limit)
		var line_bottom: float = center.y + y_limit
		if line_top >= line_bottom:
			has_prev = false
			continue
		var gradient_t: float = clamp((line_top - (center.y - inner_radius)) / max(1.0, inner_radius * 2.0), 0.0, 1.0)
		var fill_color: Color = top_color.lerp(bottom_color, gradient_t)
		draw_line(Vector2(center.x + local_x, line_top), Vector2(center.x + local_x, line_bottom), fill_color, float(step))
		# wave surface line
		var wave_point := Vector2(center.x + local_x, line_top)
		if has_prev:
			draw_line(prev_wave_point, wave_point, Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.50), 2.0)
		prev_wave_point = wave_point
		has_prev = true

	# --- refraction bands (2 bands, sparse) ---
	for band_idx in range(2):
		var band_ratio: float = 0.28 + float(band_idx) * 0.28
		var band_center_y: float = center.y + inner_radius - fill_height * band_ratio + sin(t * (2.6 + float(band_idx) * 0.8) + float(band_idx)) * (wave_amp * 1.0)
		for ix in range(int(-inner_radius) + 4, int(inner_radius) - 3, 4):
			var local_x: float = float(ix)
			var y_limit: float = sqrt(max(0.0, inner_radius * inner_radius - local_x * local_x))
			var band_dx_ratio: float = abs(local_x) / max(1.0, inner_radius)
			var band_width: float = (1.0 - band_dx_ratio) * (10.0 + inner_radius * 0.08)
			var line_y: float = clamp(band_center_y + sin(local_x * 0.09 + t * 2.0 + float(band_idx) * 0.6) * 1.4, center.y - y_limit, center.y + y_limit)
			var band_alpha: float = 0.06 + (1.0 - band_dx_ratio) * 0.08 * clamped_ratio
			if line_y > fill_top + 3.0 and line_y < center.y + y_limit - 2.0:
				draw_line(
					Vector2(center.x + local_x - band_width * 0.5, line_y),
					Vector2(center.x + local_x + band_width * 0.5, line_y),
					Color(wave_glow.r, wave_glow.g, wave_glow.b, band_alpha),
					1.5
				)

	# --- bubbles (max 5) ---
	var bubble_count: int = mini(5, int(round(3.0 + clamped_ratio * 3.0)))
	for i in range(bubble_count):
		var phase: float = t * 1.4 + float(i) * 1.26
		var bubble_x: float = center.x + sin(phase * 0.6 + float(i) * 2.1) * (inner_radius * (0.25 + float(i % 3) * 0.10))
		var bubble_offset_y: float = fmod(phase * (16.0 + float(i % 3) * 4.0) + float(i) * 24.0, max(1.0, fill_height))
		var bubble_y: float = center.y + inner_radius - bubble_offset_y
		var dx: float = bubble_x - center.x
		var dy: float = bubble_y - center.y
		if dx * dx + dy * dy < (inner_radius - 4.0) * (inner_radius - 4.0):
			var bubble_alpha: float = 0.35 + 0.18 * abs(sin(phase * 0.9))
			var bubble_radius: float = 2.0 + float(i % 3) * 0.8
			draw_circle(Vector2(bubble_x, bubble_y), bubble_radius, Color(0.86, 0.94, 1.0, bubble_alpha))
			draw_circle(Vector2(bubble_x - bubble_radius * 0.3, bubble_y - bubble_radius * 0.4), max(0.8, bubble_radius * 0.4), Color(1.0, 1.0, 1.0, bubble_alpha * 0.55))


func _draw_stage1_pillar_ui(game_offset: Vector2, game_size: Vector2, t: float) -> void:
	var scale_factor: float = game_size.y / HEIGHT
	var left_center := Vector2(
		game_offset.x - (PILLAR_UI_SIDE_MARGIN + (PILLAR_UI_SURFACE_LEFT_SIZE.x - PILLAR_ORB_RADIUS_BASE * 2.0) * 0.5) * scale_factor,
		game_offset.y + game_size.y - (PILLAR_UI_BOTTOM_MARGIN + PILLAR_ORB_RADIUS_BASE) * scale_factor
	)
	var right_center := Vector2(
		game_offset.x + game_size.x + (PILLAR_UI_SIDE_MARGIN + PILLAR_ORB_RADIUS_BASE) * scale_factor,
		game_offset.y + game_size.y - (PILLAR_UI_BOTTOM_MARGIN + 70.0) * scale_factor
	)
	var orb_radius: float = PILLAR_ORB_RADIUS_BASE * scale_factor
	_draw_stage1_gauge_orb(left_center, orb_radius, t, scale_factor)
	_draw_stage1_dash_orb(right_center, orb_radius, t, scale_factor)


func _draw_stage1_gauge_orb(center: Vector2, orb_radius: float, t: float, scale_factor: float) -> void:
	var radius: float = max(16.0, orb_radius)
	var frame_width: float = max(4.0, PILLAR_ORB_FRAME_WIDTH_BASE * scale_factor)
	var full_ratio: float = clamp(special_gauge / GAUGE_MAX, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var glow_strength: float = 0.08 + 0.06 * pulse
	if full_ratio >= 0.999:
		glow_strength += 0.14 + 0.10 * pulse
	if special_gauge_flash_timer > 0.0:
		glow_strength += 0.28 * (special_gauge_flash_timer / PILLAR_GAUGE_GAIN_FLASH_DURATION)

	# --- outer glow ---
	for layer in range(4):
		var glow_radius: float = radius + frame_width + 14.0 - float(layer) * 3.0
		var alpha: float = glow_strength * (1.0 - float(layer) * 0.18)
		draw_circle(center, glow_radius, Color(0.36, 0.58, 1.0, alpha))

	# --- frame FIRST (its filled circle is the base layer) ---
	_draw_pillar_orb_frame(
		center,
		radius,
		frame_width,
		Color(0.18, 0.14, 0.08, 1.0),
		Color(0.58, 0.48, 0.24, 1.0),
		Color(0.85, 0.73, 0.42, 1.0),
		Color(0.18, 0.46, 0.88, 1.0),
		Color(0.72, 0.88, 1.0, 1.0)
	)

	# --- dark glass background (overwrites interior of frame circle) ---
	for r in range(int(radius), 0, -4):
		var ratio: float = float(r) / radius
		var bg_color := Color(
			0.02 + 0.06 * (1.0 - ratio),
			0.05 + 0.08 * (1.0 - ratio),
			0.12 + 0.14 * (1.0 - ratio),
			1.0
		)
		draw_circle(center, float(r), bg_color)

	# --- ambient energy particles (always visible) ---
	for i in range(6):
		var pa: float = t * 0.8 + float(i) * 1.05
		var orbit_r: float = (radius - 10.0) * (0.25 + 0.45 * abs(sin(pa * 0.5 + float(i) * 0.7)))
		var orbit_angle: float = pa * (0.6 + float(i % 3) * 0.15)
		var particle_pos := center + Vector2(cos(orbit_angle), sin(orbit_angle * 0.8 + float(i))) * orbit_r
		if particle_pos.distance_to(center) < radius - 5.0:
			var pa_alpha: float = 0.30 + 0.20 * abs(sin(pa * 1.3))
			var pa_size: float = 1.8 + float(i % 3) * 0.6
			draw_circle(particle_pos, pa_size, Color(0.55, 0.78, 1.0, pa_alpha))
			draw_circle(particle_pos, pa_size * 0.4, Color(1.0, 1.0, 1.0, pa_alpha * 0.5))

	# --- pulsing core glow ---
	var core_pulse: float = 0.5 + 0.5 * sin(t * 3.0)
	var core_alpha: float = 0.06 + 0.05 * core_pulse + full_ratio * 0.08
	draw_circle(center, radius * 0.55, Color(0.30, 0.55, 1.0, core_alpha))
	draw_circle(center, radius * 0.30, Color(0.50, 0.75, 1.0, core_alpha * 0.7))

	# --- liquid fill ---
	var fill_top_color := Color(0.36, 0.70, 1.0, 1.0)
	var fill_bottom_color := Color(0.10, 0.26, 0.72, 1.0)
	var wave_glow := Color(0.82, 0.94, 1.0, 1.0)
	if full_ratio >= 0.999:
		fill_top_color = Color(1.0, 0.92, 0.62, 1.0)
		fill_bottom_color = Color(0.70, 0.52, 0.16, 1.0)
		wave_glow = Color(1.0, 0.95, 0.82, 1.0)
	elif full_ratio >= 0.75:
		fill_top_color = Color(0.58, 0.86, 1.0, 1.0)
		fill_bottom_color = Color(0.18, 0.46, 0.88, 1.0)
	elif full_ratio < 0.35:
		fill_top_color = Color(0.22, 0.46, 0.92, 1.0)
		fill_bottom_color = Color(0.07, 0.17, 0.48, 1.0)

	_draw_pillar_liquid_fill(center, radius - 5.0 * scale_factor, full_ratio, t, fill_top_color, fill_bottom_color, wave_glow)

	# --- center glow that grows with fill ---
	if full_ratio > 0.0:
		draw_circle(center, radius * (0.20 + full_ratio * 0.24), Color(wave_glow.r, wave_glow.g, wave_glow.b, 0.12 + full_ratio * 0.16))
		draw_circle(center + Vector2(0.0, radius * 0.10), radius * (0.10 + full_ratio * 0.12), Color(1.0, 1.0, 1.0, 0.06 + full_ratio * 0.07))

	# --- glass on top ---
	_draw_pillar_orb_glass(center, radius, Color(0.50, 0.74, 1.0, 1.0))

	# --- gauge gain flash ---
	if special_gauge_flash_timer > 0.0:
		var flash_progress: float = special_gauge_flash_timer / PILLAR_GAUGE_GAIN_FLASH_DURATION
		for layer in range(3):
			var flash_radius: float = radius + 10.0 * scale_factor + float(layer) * 12.0 * scale_factor
			var flash_alpha: float = (0.38 - float(layer) * 0.10) * flash_progress
			draw_circle(center, flash_radius, Color(1.0, 0.82, 0.46, flash_alpha))
		draw_arc(center, radius + 26.0 * scale_factor * (1.0 - flash_progress), 0.0, TAU, 32, Color(1.0, 0.86, 0.50, 0.50 * flash_progress), 3.0)

	# --- expanding pulse ring ---
	var ring_phase: float = fmod(t * 0.8, 1.0)
	var ring_r: float = radius * (0.5 + ring_phase * 0.5)
	var ring_alpha: float = 0.12 * (1.0 - ring_phase)
	if ring_alpha > 0.01:
		draw_arc(center, ring_r, 0.0, TAU, 32, Color(0.50, 0.74, 1.0, ring_alpha), 1.5)

	draw_circle(center, radius * 0.40, Color(0.78, 0.90, 1.0, 0.12 + full_ratio * 0.18))
	_draw_pillar_text_centered(center, "%d/%d" % [int(round(special_gauge)), int(round(GAUGE_MAX))], int(round(16.0 * scale_factor)), Color.WHITE)


func _draw_stage1_dash_orb(center: Vector2, orb_radius: float, t: float, scale_factor: float) -> void:
	var radius: float = max(16.0, orb_radius)
	var frame_width: float = max(4.0, PILLAR_ORB_FRAME_WIDTH_BASE * scale_factor)
	var max_tokens: int = max(1, dash_tokens_max)
	var available_tokens: int = clamp(dash_tokens, 0, max_tokens)
	var charge_progress: float = 0.0
	if dash_charge_timer > 0.0 and available_tokens < max_tokens:
		charge_progress = clamp(1.0 - (dash_charge_timer / DASH_TOKEN_RECHARGE_FRAMES), 0.0, 1.0)

	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var outer_glow: float = 0.08 + 0.06 * pulse
	if available_tokens > 0:
		outer_glow += 0.08 + 0.06 * pulse
	if dash_orb_flash_timer > 0.0:
		outer_glow += 0.28 * (dash_orb_flash_timer / PILLAR_DASH_FLASH_DURATION)

	# --- outer glow ---
	for layer in range(4):
		var glow_radius: float = radius + frame_width + 14.0 - float(layer) * 3.0
		var alpha: float = outer_glow * (1.0 - float(layer) * 0.18)
		draw_circle(center, glow_radius, Color(0.92, 0.28, 0.28, alpha))

	# --- frame FIRST (base layer) ---
	_draw_pillar_orb_frame(
		center,
		radius,
		frame_width,
		Color(0.16, 0.10, 0.09, 1.0),
		Color(0.46, 0.34, 0.32, 1.0),
		Color(0.70, 0.54, 0.50, 1.0),
		Color(0.84, 0.20, 0.20, 1.0),
		Color(1.0, 0.72, 0.72, 1.0)
	)

	# --- dark background (overwrites interior) ---
	for r in range(int(radius), 0, -4):
		var ratio: float = float(r) / radius
		var bg_color := Color(
			0.06 + 0.12 * (1.0 - ratio),
			0.02 + 0.04 * (1.0 - ratio),
			0.03 + 0.06 * (1.0 - ratio),
			1.0
		)
		draw_circle(center, float(r), bg_color)

	# --- ambient energy particles (5 particles) ---
	for i in range(5):
		var pa: float = t * 0.9 + float(i) * 1.26
		var orbit_r: float = (radius - 10.0) * (0.25 + 0.45 * abs(sin(pa * 0.5 + float(i) * 0.8)))
		var orbit_angle: float = pa * (0.7 + float(i % 3) * 0.12)
		var particle_pos := center + Vector2(cos(orbit_angle), sin(orbit_angle * 0.8 + float(i))) * orbit_r
		if particle_pos.distance_to(center) < radius - 5.0:
			var pa_alpha: float = 0.28 + 0.18 * abs(sin(pa * 1.2))
			var pa_size: float = 1.6 + float(i % 3) * 0.5
			draw_circle(particle_pos, pa_size, Color(1.0, 0.55, 0.42, pa_alpha))
			draw_circle(particle_pos, pa_size * 0.4, Color(1.0, 1.0, 0.9, pa_alpha * 0.5))

	# --- pulsing core glow ---
	var core_pulse: float = 0.5 + 0.5 * sin(t * 3.2)
	var core_a: float = 0.06 + 0.05 * core_pulse + float(available_tokens) / float(max_tokens) * 0.08
	draw_circle(center, radius * 0.50, Color(0.80, 0.20, 0.18, core_a))
	draw_circle(center, radius * 0.28, Color(1.0, 0.45, 0.35, core_a * 0.7))

	# --- token fill ---
	var inner_radius: float = radius - 5.0 * scale_factor
	var start_angle_offset: float = -PI * 0.5
	var sector_angle: float = TAU / float(max_tokens)

	if max_tokens == 1:
		# single token: use liquid fill for all states
		var fill_ratio_total: float = 0.0
		if available_tokens >= 1:
			fill_ratio_total = 1.0
		elif charge_progress > 0.0:
			fill_ratio_total = charge_progress
		if fill_ratio_total > 0.0:
			_draw_pillar_liquid_fill(center, inner_radius, fill_ratio_total, t, Color(0.98, 0.46, 0.36, 1.0), Color(0.42, 0.10, 0.12, 1.0), Color(1.0, 0.78, 0.70, 1.0))
			draw_circle(center, inner_radius * (0.18 + fill_ratio_total * 0.24), Color(1.0, 0.46, 0.36, 0.12 + fill_ratio_total * 0.16))
			draw_circle(center + Vector2(0.0, inner_radius * 0.10), inner_radius * (0.10 + fill_ratio_total * 0.12), Color(1.0, 0.92, 0.88, 0.06 + fill_ratio_total * 0.08))
	else:
		# multiple tokens: each sector gets liquid-style fill
		for i in range(max_tokens):
			var start_rad: float = start_angle_offset + sector_angle * float(i)
			var end_rad: float = start_rad + sector_angle
			if i < available_tokens:
				# filled token: pulsing sector with inner glow
				var token_pulse: float = 0.5 + 0.5 * sin(t * 3.5 + float(i) * 1.2)
				var base_alpha: float = 0.88 + 0.10 * token_pulse
				draw_colored_polygon(_build_sector_points(center, inner_radius, start_rad, end_rad, 24), Color(0.78, 0.16, 0.20, base_alpha))
				draw_colored_polygon(_build_sector_points(center, inner_radius * 0.72, start_rad, end_rad, 16), Color(1.0, 0.52, 0.42, 0.12 + 0.10 * token_pulse))
			elif charge_progress > 0.0 and i == available_tokens:
				# charging token: liquid-like fill rising
				_draw_dash_sector_liquid(center, inner_radius, start_rad, end_rad, charge_progress, t, scale_factor)

		# --- divider lines ---
		var divider_progress: float = _ease_out_cubic(dash_divider_anim_progress)
		for i in range(max_tokens):
			var divider_angle: float = start_angle_offset + sector_angle * float(i)
			var current_length: float = (inner_radius - 6.0) * divider_progress
			for seg in range(12):
				var start_ratio: float = float(seg) / 12.0
				var end_ratio: float = float(seg + 1) / 12.0
				var seg_start := center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length * start_ratio
				var seg_end := center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length * end_ratio
				var thickness: float = max(1.0, 4.0 - float(seg) * 0.25)
				var gold_mix: float = 1.0 - float(seg) / 12.0
				draw_line(seg_start, seg_end, Color(0.62 + gold_mix * 0.18, 0.46 + gold_mix * 0.14, 0.20 + gold_mix * 0.10, 0.80), thickness)
			var tip_pos := center + Vector2(cos(divider_angle), sin(divider_angle)) * current_length
			draw_circle(tip_pos, 3.0 * scale_factor, Color(0.82, 0.66, 0.34, 0.76))
			draw_circle(tip_pos, 2.0 * scale_factor, Color(1.0, 0.86, 0.54, 0.64))
		draw_circle(center, 6.0 * scale_factor, Color(0.70, 0.54, 0.24, 0.92))
		draw_circle(center, 4.0 * scale_factor, Color(0.90, 0.74, 0.40, 0.92))
		draw_circle(center, 2.0 * scale_factor, Color(1.0, 0.90, 0.66, 0.94))

	# --- glass on top ---
	_draw_pillar_orb_glass(center, radius, Color(1.0, 0.56, 0.50, 1.0))

	# --- charge completion flash ---
	if dash_orb_flash_timer > 0.0:
		var flash_progress: float = dash_orb_flash_timer / PILLAR_DASH_FLASH_DURATION
		for layer in range(3):
			var flash_radius: float = radius + 10.0 * scale_factor + float(layer) * 12.0 * scale_factor
			var flash_alpha: float = (0.38 - float(layer) * 0.10) * flash_progress
			draw_circle(center, flash_radius, Color(1.0, 0.82, 0.46, flash_alpha))
		draw_arc(center, radius + 26.0 * scale_factor * (1.0 - flash_progress), 0.0, TAU, 32, Color(1.0, 0.86, 0.54, 0.50 * flash_progress), 3.0)
		# burst particles
		for burst_i in range(8):
			var burst_angle: float = float(burst_i) * TAU / 8.0
			var burst_dist: float = (radius + 14.0 * scale_factor) * (1.0 + (1.0 - flash_progress) * 0.6)
			var burst_pos := center + Vector2(cos(burst_angle), sin(burst_angle)) * burst_dist
			draw_circle(burst_pos, 3.0 * scale_factor * flash_progress, Color(1.0, 0.90, 0.60, 0.50 * flash_progress))

	# --- expanding pulse ring ---
	var ring_phase: float = fmod(t * 0.9, 1.0)
	var ring_r: float = radius * (0.5 + ring_phase * 0.5)
	var ring_alpha: float = 0.10 * (1.0 - ring_phase)
	if ring_alpha > 0.01:
		draw_arc(center, ring_r, 0.0, TAU, 32, Color(1.0, 0.50, 0.40, ring_alpha), 1.5)

	_draw_pillar_text_centered(center, "%d/%d" % [available_tokens, max_tokens], int(round(16.0 * scale_factor)), Color.WHITE)
	if available_tokens <= 0 and dash_available_timer <= 0.0 and not dash_active:
		var half_alpha: float = 0.50 + 0.30 * sin(t * 8.0)
		_draw_pillar_text_centered(center + Vector2(0.0, radius + 20.0 * scale_factor), "HALF", int(round(10.0 * scale_factor)), Color(0.72, 0.76, 1.0, half_alpha))


func _draw_dash_sector_liquid(center: Vector2, inner_radius: float, start_rad: float, end_rad: float, progress: float, t: float, scale_factor: float) -> void:
	var charge_radius: float = inner_radius * progress
	# base fill
	draw_colored_polygon(_build_sector_points(center, charge_radius, start_rad, end_rad, 20), Color(0.76, 0.26, 0.22, 0.92))
	# inner glow
	if progress > 0.15:
		draw_colored_polygon(_build_sector_points(center, charge_radius * 0.72, start_rad, end_rad, 14), Color(1.0, 0.58, 0.44, 0.16 + 0.12 * progress))
	# pulsing edge
	var pulse_r: float = charge_radius * (0.85 + 0.15 * sin(t * 5.0))
	draw_arc(center, pulse_r, start_rad, end_rad, 12, Color(1.0, 0.72, 0.56, 0.28 + 0.18 * sin(t * 4.0)), 2.0)


func _draw_energy_ball_trail(pos: Vector2, ratio: float) -> void:
	var outer_alpha: float = 0.03 + ratio * 0.09
	var inner_alpha: float = 0.05 + ratio * 0.14
	var outer_radius: float = BALL_RENDER_RADIUS * (0.25 + ratio * 0.55)
	var inner_radius: float = BALL_RENDER_RADIUS * (0.10 + ratio * 0.22)

	draw_circle(pos, outer_radius, Color(BALL_OUTER_COLOR.r, BALL_OUTER_COLOR.g, BALL_OUTER_COLOR.b, outer_alpha))
	draw_circle(pos, inner_radius, Color(BALL_INNER_COLOR.r, BALL_INNER_COLOR.g, BALL_INNER_COLOR.b, inner_alpha))


func _draw_energy_ball(pos: Vector2) -> void:
	var current_time_ms: float = float(Time.get_ticks_msec())
	var t: float = current_time_ms / 1000.0
	var pulse: float = sin(t * 7.5) * 0.08 + 1.0
	var pulse2: float = sin(t * 10.0) * 0.06 + 1.0

	draw_circle(pos + Vector2(2, 4), BALL_RENDER_RADIUS + 1.0, Color(0.0, 0.0, 0.0, 0.28))

	for i in range(3):
		var glow_radius: float = BALL_RENDER_RADIUS * pulse + 9.0 - float(i) * 3.0
		var glow_alpha: float = 0.08 - float(i) * 0.018
		draw_circle(pos, glow_radius, Color(BALL_OUTER_COLOR.r, BALL_OUTER_COLOR.g, BALL_OUTER_COLOR.b, glow_alpha))

	var ring_angles: Array[float] = [
		fmod(current_time_ms * 0.15, 360.0),
		fmod(360.0 - current_time_ms * 0.12, 360.0),
		fmod(current_time_ms * 0.15, 360.0),
	]
	var ring_tilts: Array[float] = [
		20.0 + sin(current_time_ms * 0.002) * 10.0,
		45.0 + sin(current_time_ms * 0.0015 + 1.0) * 12.0,
		70.0 + sin(current_time_ms * 0.001 + 2.0) * 8.0,
	]
	var ring_radii: Array[float] = [
		BALL_RENDER_RADIUS * 1.156,
		BALL_RENDER_RADIUS * 1.264,
		BALL_RENDER_RADIUS * 1.372,
	]

	for ring_idx in range(ring_radii.size()):
		var ring_rotation: float = ring_angles[ring_idx]
		var ring_tilt: float = ring_tilts[ring_idx]
		var ring_radius: float = ring_radii[ring_idx]
		var orbit_points: PackedVector2Array = PackedVector2Array()

		for point_idx in range(24):
			var angle_deg: float = ring_rotation + float(point_idx) * (360.0 / 24.0)
			var angle: float = deg_to_rad(angle_deg)
			var tilt_rad: float = deg_to_rad(ring_tilt)
			var x_offset: float = cos(angle) * ring_radius
			var y_offset: float = sin(angle) * ring_radius * cos(tilt_rad)
			var z_depth: float = sin(angle) * sin(tilt_rad)
			var depth_factor: float = (z_depth + 1.0) * 0.5
			var orbit_pos: Vector2 = pos + Vector2(x_offset, y_offset)
			var point_radius: float = max(1.0, floor(1.7 + depth_factor * 1.3))
			var point_alpha: float = (15.0 + depth_factor * 35.0) / 255.0
			var ring_color: Color = Color(
				clamp(BALL_RING_COLOR.r * 0.3 + depth_factor * BALL_RING_COLOR.r * 0.7 + float(ring_idx) * 0.02, 0.0, 1.0),
				clamp(BALL_RING_COLOR.g * 0.3 + depth_factor * BALL_RING_COLOR.g * 0.7 + float(ring_idx) * 0.04, 0.0, 1.0),
				clamp(BALL_RING_COLOR.b * 0.3 + depth_factor * BALL_RING_COLOR.b * 0.7, 0.0, 1.0),
				point_alpha
			)
			orbit_points.append(orbit_pos)
			draw_circle(orbit_pos, point_radius, ring_color)

		if orbit_points.size() > 2:
			for point_idx in range(orbit_points.size()):
				var start: Vector2 = orbit_points[point_idx]
				var next_index: int = (point_idx + 1) % orbit_points.size()
				var end: Vector2 = orbit_points[next_index]
				draw_line(start, end, Color(BALL_RING_COLOR.r, BALL_RING_COLOR.g, BALL_RING_COLOR.b, 10.0 / 255.0), 1.0)

		for bright_idx in range(3):
			var bright_angle_deg: float = ring_rotation + float(bright_idx) * 120.0
			var bright_angle: float = deg_to_rad(bright_angle_deg)
			var tilt_rad: float = deg_to_rad(ring_tilt)
			var x_offset: float = cos(bright_angle) * ring_radius
			var y_offset: float = sin(bright_angle) * ring_radius * cos(tilt_rad)
			var z_depth: float = sin(bright_angle) * sin(tilt_rad)
			if z_depth > -0.3:
				var bright_pos: Vector2 = pos + Vector2(x_offset, y_offset)
				var bright_pulse: float = (sin(t * 10.0 + float(bright_idx)) + 1.0) * 0.5
				var bright_size: float = 0.72 + bright_pulse * 0.85
				var bright_alpha: float = (40.0 + bright_pulse * 35.0) / 255.0
				draw_circle(bright_pos, bright_size + 1.0, Color(BALL_INNER_COLOR.r, BALL_INNER_COLOR.g, BALL_INNER_COLOR.b, bright_alpha * 0.5))
				draw_circle(bright_pos, bright_size, Color(150.0 / 255.0, 210.0 / 255.0, 1.0, bright_alpha))

	draw_circle(pos, BALL_RENDER_RADIUS * 0.78 * pulse2, Color(BALL_INNER_COLOR.r, BALL_INNER_COLOR.g, BALL_INNER_COLOR.b, 0.20))
	draw_circle(pos, BALL_RENDER_RADIUS * 0.56 * pulse, Color(BALL_INNER_COLOR.r, BALL_INNER_COLOR.g, BALL_INNER_COLOR.b, 0.34))
	draw_circle(pos, BALL_RENDER_RADIUS * 0.40, Color(0.78, 0.90, 1.0, 0.70))
	draw_circle(pos, BALL_RENDER_RADIUS * 0.22, Color(BALL_CORE_COLOR.r, BALL_CORE_COLOR.g, BALL_CORE_COLOR.b, 0.95))
	draw_circle(pos + Vector2(-3, -3), BALL_RENDER_RADIUS * 0.11, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(
		pos + Vector2(-BALL_RENDER_RADIUS * 0.11, -BALL_RENDER_RADIUS * 0.11),
		max(1.0, BALL_RENDER_RADIUS * 0.072),
		Color(1.0, 1.0, 1.0, 0.31)
	)
	draw_circle(
		pos + Vector2(-BALL_RENDER_RADIUS * 0.11 - 1.0, -BALL_RENDER_RADIUS * 0.11 - 1.0),
		max(2.0, BALL_RENDER_RADIUS * 0.072 + 1.0),
		Color(1.0, 1.0, 1.0, 0.16)
	)

	if randf() < 0.4:
		var spawn_angle: float = randf_range(0.0, TAU)
		var spawn_dist: float = BALL_RENDER_RADIUS * randf_range(0.867, 1.445)
		energy_ball_particles.append({
			"x": cos(spawn_angle) * spawn_dist,
			"y": sin(spawn_angle) * spawn_dist,
			"vx": randf_range(-0.5, 0.5),
			"vy": randf_range(-1.5, -0.5),
			"life": float(randi_range(20, 40)),
			"max_life": 40.0,
			"size": randf_range(0.42, 1.02),
			"color": ENERGY_BALL_PARTICLE_COLORS[randi_range(0, ENERGY_BALL_PARTICLE_COLORS.size() - 1)]
		})

	while energy_ball_particles.size() > ENERGY_BALL_MAX_PARTICLES:
		energy_ball_particles.pop_front()

	var new_energy_particles: Array[Dictionary] = []
	for particle in energy_ball_particles:
		var p: Dictionary = particle
		var px: float = float(p["x"]) + float(p["vx"])
		var py: float = float(p["y"]) + float(p["vy"])
		var life: float = float(p["life"]) - 1.0
		var max_life: float = float(p["max_life"])
		var base_size: float = float(p["size"])
		var color: Color = p["color"]

		p["x"] = px
		p["y"] = py
		p["life"] = life

		if life > 0.0:
			var alpha: float = (200.0 * (life / max_life)) / 255.0
			var size: float = max(1.0, floor(base_size * (life / max_life)))
			var particle_pos: Vector2 = pos + Vector2(px, py)
			draw_circle(particle_pos, size + 2.0, Color(color.r, color.g, color.b, alpha * 0.33))
			draw_circle(particle_pos, size, Color(color.r, color.g, color.b, alpha))
			new_energy_particles.append(p)

	energy_ball_particles = new_energy_particles


func _draw_hud() -> void:
	var font: Font = ThemeDB.fallback_font
	var center_x: float = WIDTH * 0.5
	var score_y: float = 20.0

	draw_string(font, Vector2(center_x - 55.0, score_y + 28.0), str(player_score), HORIZONTAL_ALIGNMENT_CENTER, -1.0, 36, PLAYER_COLOR)
	draw_string(font, Vector2(center_x - 5.0, score_y + 24.0), "-", HORIZONTAL_ALIGNMENT_CENTER, -1.0, 24, Color(1.0, 1.0, 1.0, 0.4))
	draw_string(font, Vector2(center_x + 30.0, score_y + 28.0), str(boss_score), HORIZONTAL_ALIGNMENT_CENTER, -1.0, 36, BOSS_COLOR)

	draw_string(font, Vector2(center_x - 65.0, score_y + 8.0), "YOU", HORIZONTAL_ALIGNMENT_CENTER, -1.0, 11, Color(1.0, 1.0, 1.0, 0.4))
	draw_string(font, Vector2(center_x + 25.0, score_y + 8.0), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, -1.0, 11, Color(1.0, 1.0, 1.0, 0.4))

	if deuce_mode:
		draw_string(font, Vector2(center_x - 25.0, score_y + 48.0), "DEUCE", HORIZONTAL_ALIGNMENT_CENTER, -1.0, 14, Color.YELLOW)

	if dash_active:
		var dash_text: String = "HALF DASH!" if dash_is_half else "DASH!"
		var dash_color: Color = HALF_DASH_COLOR if dash_is_half else GAUGE_COLOR
		draw_string(font, Vector2(center_x - 30.0, HEIGHT - 30.0), dash_text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 16, dash_color)
