extends RefCounted

const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const BallSpeedPolicy := preload("res://scripts/ball/ball_speed_policy.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const BALL_SIZE := 28.6
const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE
const BALL_MAX_STEP_DISTANCE := 12.0
const MIN_BALL_SPEED := 3.0
const MAX_BALL_SPEED := BallSpeedPolicy.DEFAULT_MAX_BALL_SPEED
const POWER_SMASH_MAX_BALL_SPEED := 35.0
const IMPACT_BOOST_MAX_BALL_SPEED := MAX_BALL_SPEED
const MYTHIC_MAX_BALL_SPEED := BallSpeedPolicy.MYTHIC_MAX_BALL_SPEED
const FIRE_WEATHER_MAX_BALL_SPEED := BallSpeedPolicy.FIRE_WEATHER_MAX_BALL_SPEED
const RALLY_SPEED_CAP_INCREASE_PER_HIT := 0.5
# Bounds per-round rally cap growth so the longest rally tops out at base+10
# (champion 36 px/frame ≈ 0.35s vertical crossing stays human-reactable).
const RALLY_SPEED_CAP_BONUS_MAX := 10.0
const MAX_BOUNCE_ANGLE := 60.0
const DRIVE_GAUGE_COST := 150.0
const DRIVE_PERFECT_COOLDOWN_FRAMES := 30.0
const DRIVE_GLOBAL_COOLDOWN_FRAMES := 120.0
const DRIVE_TEXT_DURATION_FRAMES := 30.0
const POWER_SMASH_GAUGE_COST := 300.0
const POWER_SMASH_FREEZE_DURATION := 1.65
const POWER_SMASH_TEXT_DURATION_FRAMES := 48.0
const POWER_SMASH_EFFECT_MULT := 1.0
const POWER_SMASH_GRAVITY_EFFECT := 0.035 * POWER_SMASH_EFFECT_MULT
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
		"ball_render_radius": BALL_RENDER_RADIUS,
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
		"power_smash_max_ball_speed": POWER_SMASH_MAX_BALL_SPEED,
		"impact_boost_max_ball_speed": IMPACT_BOOST_MAX_BALL_SPEED,
		"mythic_max_ball_speed": MYTHIC_MAX_BALL_SPEED,
		"fire_weather_max_ball_speed": FIRE_WEATHER_MAX_BALL_SPEED,
		"rally_speed_cap_increase_per_hit": RALLY_SPEED_CAP_INCREASE_PER_HIT,
		"rally_speed_cap_bonus_max": RALLY_SPEED_CAP_BONUS_MAX,
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
		"player_y": PLAYER_Y,
		"boss_y": BOSS_Y,
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
		"ball_render_radius": BALL_RENDER_RADIUS,
	}
