extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")


func maybe_arm_from_sources(
	owner: Object,
	companion_pos: Vector2,
	current_profile: Object,
	body_hit_state: Object,
	animator: Object,
	active_skill_ids: Array[String],
	active_skill_slot_resolver: Object,
	skill_visual_resolver: Object,
	skill_runtime_surface: Object,
	skill_runtime_host: Object,
	ball_radius_fallback: float,
	hit_width_fallback: float,
	hit_height_fallback: float
) -> void:
	if animator == null:
		return
	var body_skill_id := _get_companion_body_skill_id(
		active_skill_ids,
		active_skill_slot_resolver,
		skill_visual_resolver,
		skill_runtime_host,
		current_profile,
		companion_pos
	)
	if _is_body_hit_suppressed(skill_runtime_surface, skill_runtime_host, body_skill_id):
		animator.reset_latch()
		return
	maybe_arm(
		owner,
		companion_pos,
		_get_profile_hit_half_width(current_profile, hit_width_fallback),
		_get_profile_hit_half_height(current_profile, hit_height_fallback),
		_get_body_hit_cooldown(body_hit_state),
		animator,
		ball_radius_fallback
	)


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


func _get_companion_body_skill_id(
	active_skill_ids: Array[String],
	active_skill_slot_resolver: Object,
	skill_visual_resolver: Object,
	skill_runtime_host: Object,
	current_profile: Object,
	companion_pos: Vector2
) -> String:
	if skill_visual_resolver == null:
		return _get_primary_skill_id(active_skill_slot_resolver, current_profile)
	var active_position_owner: Dictionary = {}
	if skill_visual_resolver.has_method("get_active_position_override_owner"):
		var override_owner: Variant = skill_visual_resolver.get_active_position_override_owner(
			active_skill_ids,
			skill_runtime_host,
			companion_pos
		)
		if override_owner is Dictionary:
			active_position_owner = override_owner as Dictionary
	var primary_skill_id: String = _get_primary_skill_id(active_skill_slot_resolver, current_profile)
	if skill_visual_resolver.has_method("get_companion_body_skill_id"):
		return str(skill_visual_resolver.get_companion_body_skill_id(active_position_owner, primary_skill_id))
	return primary_skill_id


func _get_primary_skill_id(active_skill_slot_resolver: Object, current_profile: Object) -> String:
	if active_skill_slot_resolver == null or not active_skill_slot_resolver.has_method("get_skill_id_for_slot"):
		return ""
	return str(active_skill_slot_resolver.get_skill_id_for_slot(current_profile, 0))


func _is_body_hit_suppressed(skill_runtime_surface: Object, skill_runtime_host: Object, body_skill_id: String) -> bool:
	if skill_runtime_surface == null or not skill_runtime_surface.has_method("is_companion_body_hit_suppressed"):
		return false
	return bool(skill_runtime_surface.is_companion_body_hit_suppressed(skill_runtime_host, body_skill_id))


func _get_profile_hit_half_width(current_profile: Object, fallback_width: float) -> float:
	if current_profile == null or not current_profile.has_method("get_hit_half_width"):
		return maxf(1.0, fallback_width * 0.5)
	return float(current_profile.get_hit_half_width(fallback_width))


func _get_profile_hit_half_height(current_profile: Object, fallback_height: float) -> float:
	if current_profile == null or not current_profile.has_method("get_hit_half_height"):
		return maxf(1.0, fallback_height * 0.5)
	return float(current_profile.get_hit_half_height(fallback_height))


func _get_body_hit_cooldown(body_hit_state: Object) -> float:
	if body_hit_state == null:
		return 0.0
	return maxf(0.0, float(body_hit_state.get("cooldown")))
