extends RefCounted

const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const Stage1BalloonPayloadFactory := preload("res://scripts/stages/stage1/stage1_balloon_payload_factory.gd")

const STAGE_ID := 1
const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)
const DEFAULT_BOSS_PADDLE_WIDTH := 100.0
const DEFAULT_BOSS_HITBOX_HEIGHT := 40.0
const DEFAULT_BALL_SIZE := 28.6
const DEFAULT_BALLOON_RADIUS := 30.0
const PADDLE_KNOCKBACK_SPEED := 7.0
const PADDLE_KNOCKBACK_FRAMES := 18.0
const DEFAULT_BALLOON_COLOR := Color(0.78, 0.48, 1.0, 1.0)

# Owns every destructive/live interaction against the retained Stage 1 balloon
# collection. The facade supplies only the established pop-feedback callback,
# which remains synchronous so reward/audio and ball-response order cannot drift.
var balloon_state: Object


func _init(balloon_state_ref: Object) -> void:
	balloon_state = balloon_state_ref


func resolve_ball_collision(
	scene: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	feedback_host: Object
) -> bool:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or _is_empty():
		return false

	var ball_pos: Vector2 = _get_vector2(scene.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var previous_ball_pos: Vector2 = _get_vector2(context.get("ball_pos", ball_pos), ball_pos)
	var ball_radius: float = float(context.get("ball_size", DEFAULT_BALL_SIZE)) * 0.5
	for index in range(balloon_state.get_count()):
		var balloon: Dictionary = balloon_state.get_balloon(index)
		var balloon_pos: Vector2 = _get_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO)
		var balloon_radius: float = float(balloon.get("radius", DEFAULT_BALLOON_RADIUS))
		if not balloon_state.ball_path_hits(previous_ball_pos, ball_pos, balloon_pos, ball_radius + balloon_radius):
			continue

		balloon_state.remove_balloon(index)
		_emit_pop_feedback(feedback_host, balloon, deps, context)
		if not _is_whip_active(deps):
			var ball_velocity: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
			scene["ball_vel"] = balloon_state.deflect_ball_velocity(ball_velocity)
		return true
	return false


func resolve_commando_bullet_collision(
	projectile: Dictionary,
	context: Dictionary,
	deps: Dictionary,
	feedback_host: Object
) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or _is_empty():
		return {}
	if not is_commando_balloon_pop_projectile(projectile):
		return {}

	var projectile_pos: Vector2 = _get_vector2(projectile.get("pos", Vector2.ZERO), Vector2.ZERO)
	var previous_projectile_pos: Vector2 = _get_vector2(projectile.get("prev_pos", projectile_pos), projectile_pos)
	var projectile_radius: float = max(1.0, float(projectile.get("radius", 3.0)))
	for index in range(balloon_state.get_count()):
		var balloon: Dictionary = balloon_state.get_balloon(index)
		var balloon_pos: Vector2 = _get_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO)
		var balloon_radius: float = float(balloon.get("radius", DEFAULT_BALLOON_RADIUS))
		if not balloon_state.ball_path_hits(
			previous_projectile_pos,
			projectile_pos,
			balloon_pos,
			balloon_radius + projectile_radius
		):
			continue

		balloon_state.remove_balloon(index)
		_emit_pop_feedback(feedback_host, balloon, deps, context)
		return {
			"commando_firearm_balloon_popped": true,
			"commando_firearm_balloon_special": bool(balloon.get("is_special", false)),
			"commando_firearm_balloon_pos": balloon_pos,
			"commando_firearm_balloon_weapon_id": str(projectile.get("weapon_id", "")),
		}
	return {}


func is_commando_balloon_pop_projectile(projectile: Dictionary) -> bool:
	if str(projectile.get("kind", "bullet")) != "bullet":
		return false
	var weapon_id := str(projectile.get("weapon_id", ""))
	return weapon_id in ["pistol", "commando_pistol", "ak47"]


func absorb_chaos_spear_objects(
	center: Vector2,
	radius: float,
	deps: Dictionary,
	feedback_host: Object
) -> Array:
	if _is_empty():
		return []
	var absorbed: Array = []
	for index in range(balloon_state.get_count() - 1, -1, -1):
		var balloon: Dictionary = balloon_state.get_balloon(index)
		var balloon_pos: Vector2 = _get_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO)
		var balloon_radius: float = float(balloon.get("radius", DEFAULT_BALLOON_RADIUS))
		if balloon_pos.distance_to(center) > radius + balloon_radius:
			continue
		balloon_state.remove_balloon(index)
		_emit_pop_feedback(feedback_host, balloon, deps, {})
		var balloon_color: Color = _get_color(balloon.get("color", DEFAULT_BALLOON_COLOR), DEFAULT_BALLOON_COLOR)
		absorbed.append(Stage1BalloonPayloadFactory.build_absorbed_balloon_payload(
			balloon_pos,
			balloon_radius,
			balloon_color
		))
	return absorbed


func resolve_paddle_interactions(context: Dictionary, deps: Dictionary, feedback_host: Object) -> void:
	var player_rect := Rect2(
		_get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_get_vector2(context.get("player_paddle_size", DEFAULT_PLAYER_PADDLE_SIZE), DEFAULT_PLAYER_PADDLE_SIZE)
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var boss_rect := Rect2(
		_get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO),
		Vector2(
			float(context.get("boss_paddle_width", DEFAULT_BOSS_PADDLE_WIDTH)),
			float(context.get("boss_hitbox_height", DEFAULT_BOSS_HITBOX_HEIGHT))
		)
	)
	var dash_snapshot: Dictionary = _get_dictionary(context.get("dash_snapshot", {}))
	var player_dashing: bool = bool(dash_snapshot.get("active", false))
	for index in range(balloon_state.get_count() - 1, -1, -1):
		var balloon: Dictionary = balloon_state.get_balloon(index)
		var hit_player_rect: Rect2 = balloon_state.get_first_overlapping_rect(balloon, player_rects)
		if player_dashing and hit_player_rect.size.x > 0.0:
			balloon_state.remove_balloon(index)
			_emit_pop_feedback(feedback_host, balloon, deps, context)
			continue
		if float(balloon.get("paddle_bounce_cooldown", 0.0)) > 0.0:
			continue
		if hit_player_rect.size.x > 0.0:
			var direction: float = balloon_state.bounce_from_paddle(balloon, hit_player_rect)
			balloon_state.set_balloon(index, balloon)
			var movement_state: Object = deps.get("movement_state", null)
			if not _is_player_status_immune(deps, context) and movement_state != null and movement_state.has_method("start_knockback"):
				movement_state.start_knockback(direction * PADDLE_KNOCKBACK_SPEED, PADDLE_KNOCKBACK_FRAMES)
		elif balloon_state.circle_rect_overlap(balloon, boss_rect):
			balloon_state.bounce_from_paddle(balloon, boss_rect)
			balloon_state.set_balloon(index, balloon)


func _is_empty() -> bool:
	return balloon_state == null or bool(balloon_state.is_empty())


func _emit_pop_feedback(
	feedback_host: Object,
	balloon: Dictionary,
	deps: Dictionary,
	context: Dictionary
) -> void:
	if feedback_host != null and feedback_host.has_method("_handle_balloon_pop"):
		feedback_host.call("_handle_balloon_pop", balloon, deps, context)


func _is_whip_active(deps: Dictionary) -> bool:
	var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null)
	if whip_state == null or not whip_state.has_method("get_draw_context"):
		return false
	var draw_context: Dictionary = whip_state.get_draw_context()
	return bool(draw_context.get("boss_whip_active", false))


func _is_player_status_immune(deps: Dictionary, context: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("is_immune"):
		if bool(cleanse_state.is_immune()):
			return true
	var mythic_item_runtime: Object = StarpointBonusDropPolicy.get_mythic_item_runtime(deps, context)
	if mythic_item_runtime != null and mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		var status_deps: Dictionary = deps.duplicate()
		status_deps["context"] = context
		if context.get("owner", null) is Object:
			status_deps["owner"] = context.get("owner", null)
		if bool(mythic_item_runtime.try_consume_celestial_armor_immunity("stage1_balloon", "knockback", status_deps)):
			return true
	return false


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _get_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback
