extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")


func maybe_arm(
	owner: Object,
	companion_pos: Vector2,
	hit_half_width: float,
	hit_half_height: float,
	hit_cooldown: float,
	animator: Object,
	ball_radius_fallback: float
) -> void:
	if animator == null:
		return
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		animator.reset_latch()
		return
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		animator.reset_latch()
		return
	if bool(animator.strike_latched) or bool(animator.strike_active):
		return
	if hit_cooldown > 0.0:
		animator.reset_latch()
		return
	if companion_pos == Vector2.ZERO:
		return

	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "ball_size", ball_radius_fallback * 2.0)) * 0.5)
	var vertical_gap: float = (companion_pos.y - maxf(1.0, hit_half_height)) - (ball_pos.y + ball_radius)
	if vertical_gap < 0.0:
		return
	if vertical_gap > LingpetCompanionSpriteAnimator.STRIKE_MAX_GAP:
		return

	var impact_boost: float = maxf(0.01, float(BattleSceneOwnerReader.get_value(owner, "ball_impact_boost", 1.0)))
	var downward_speed: float = maxf(0.01, ball_vel.y * impact_boost)
	var frames_to_contact: float = vertical_gap / downward_speed
	var start_frame: int = animator.get_strike_start_frame(frames_to_contact)
	if start_frame < 0:
		return

	var future_ball_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var x_tolerance: float = maxf(1.0, hit_half_width) + ball_radius + LingpetCompanionSpriteAnimator.STRIKE_X_TOLERANCE
	if absf(future_ball_x - companion_pos.x) > x_tolerance:
		return

	animator.begin_strike(start_frame)
	animator.strike_latched = true
