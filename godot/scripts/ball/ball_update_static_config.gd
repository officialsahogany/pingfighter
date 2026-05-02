extends RefCounted

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const BALL_SIZE := 22.0
const BALL_MAX_STEP_DISTANCE := 12.0
const MIN_BALL_SPEED := 3.0
const MAX_BALL_SPEED := 60.0
const MAX_BOUNCE_ANGLE := 60.0
const DRIVE_GAUGE_COST := 150.0
const DRIVE_PERFECT_COOLDOWN_FRAMES := 30.0
const DRIVE_GLOBAL_COOLDOWN_FRAMES := 120.0
const DRIVE_TEXT_DURATION_FRAMES := 30.0
const POWER_SMASH_GAUGE_COST := 300.0
const POWER_SMASH_FREEZE_DURATION := 0.30
const POWER_SMASH_TEXT_DURATION_FRAMES := 48.0
const POWER_SMASH_GRAVITY_EFFECT := 0.035
const POWER_SMASH_BOOST_DURATION := 0.50
const SMASHER_COMBO_MIN_SKILL_COUNT := 2
const PADDLE_WIDTH := 155.0
const PADDLE_HEIGHT := 50.0
const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_PADDLE_HEIGHT := 40.0
const BOSS_HITBOX_HEIGHT := BOSS_PADDLE_HEIGHT
const HITBOX_PADDING := 5.0
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_PER_HIT := 50.0


func build_update_config() -> Dictionary:
	return {
		"ball_size": BALL_SIZE,
		"width": WIDTH,
		"height": HEIGHT,
		"max_step_distance": BALL_MAX_STEP_DISTANCE,
		"player_paddle_size": Vector2(PADDLE_WIDTH, PADDLE_HEIGHT),
		"boss_paddle_size": Vector2(BOSS_PADDLE_WIDTH, BOSS_HITBOX_HEIGHT),
		"hitbox_padding": HITBOX_PADDING,
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
		"boss_hitbox_height": BOSS_HITBOX_HEIGHT,
		"paddle_width": PADDLE_WIDTH,
		"drive_gauge_cost": DRIVE_GAUGE_COST,
		"drive_text_duration_frames": DRIVE_TEXT_DURATION_FRAMES,
		"drive_perfect_cooldown_frames": DRIVE_PERFECT_COOLDOWN_FRAMES,
		"drive_global_cooldown_frames": DRIVE_GLOBAL_COOLDOWN_FRAMES,
		"power_smash_gauge_cost": POWER_SMASH_GAUGE_COST,
		"power_smash_text_duration_frames": POWER_SMASH_TEXT_DURATION_FRAMES,
		"gauge_max": GAUGE_MAX,
		"gauge_charge_per_hit": GAUGE_CHARGE_PER_HIT,
		"combo_min_count": SMASHER_COMBO_MIN_SKILL_COUNT,
		"current_msec": Time.get_ticks_msec(),
		"max_bounce_angle": MAX_BOUNCE_ANGLE,
		"min_ball_speed": MIN_BALL_SPEED,
		"max_ball_speed": MAX_BALL_SPEED,
		"base_ball_speed": BallPhysics.BALL_BASE_SPEED,
		"power_smash_freeze_duration": POWER_SMASH_FREEZE_DURATION,
		"power_smash_gravity_effect": POWER_SMASH_GRAVITY_EFFECT,
		"power_smash_boost_duration": POWER_SMASH_BOOST_DURATION,
	}


func build_reset_config(player_pos: Vector2, boss_pos: Vector2) -> Dictionary:
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"player_pos": player_pos,
		"boss_pos": boss_pos,
		"player_paddle_width": PADDLE_WIDTH,
		"boss_paddle_width": BOSS_PADDLE_WIDTH,
	}


func build_serve_config(player_pos: Vector2, boss_pos: Vector2) -> Dictionary:
	return {
		"current_msec": Time.get_ticks_msec(),
		"player_pos": player_pos,
		"boss_pos": boss_pos,
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
		"player_paddle_width": PADDLE_WIDTH,
		"boss_paddle_width": BOSS_PADDLE_WIDTH,
		"boss_hitbox_height": BOSS_HITBOX_HEIGHT,
		"ball_size": BALL_SIZE,
	}
