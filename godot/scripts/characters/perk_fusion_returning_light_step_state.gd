extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetRingDashVfx := preload("res://scripts/lingpet/lingpet_ring_dash_vfx.gd")
const SmasherDashActiveMotionResolver := preload("res://scripts/characters/smasher_dash_active_motion_resolver.gd")

const BYPRODUCT_ID := "returning_light_step"
const FORCE_ROLL_OWNER_KEY := "perk_fusion_returning_light_step_roll_unit"
const TRIGGER_CHANCE := 0.30
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BALL_RADIUS_FALLBACK := 14.3
const PLAYER_WIDTH_FALLBACK := 155.0
const PLAYER_HEIGHT_FALLBACK := 50.0
const LOOKAHEAD_GAP := 96.0

var _rolled_this_descent := false
var _last_roll_unit := -1.0
var _last_trigger_pos := Vector2.ZERO
var _trigger_count := 0
var _vfx: Object = LingpetRingDashVfx.new()


func advance(
	delta: float,
	owned_ids: Variant,
	owner: Object,
	dash_state: Object,
	player_guard_available: bool = true
) -> Dictionary:
	_vfx.advance(maxf(0.0, delta))
	_update_descent_roll_lock(owner)
	var result := {
		"rolled": false,
		"triggered": false,
		"chance": TRIGGER_CHANCE,
	}
	if not _owns_byproduct(owned_ids) or owner == null or not player_guard_available:
		return result
	# has_full_dash_token() is the canonical usability query: it includes a
	# Boost Charging refund, unlike a raw `tokens == 0` snapshot check.
	if _has_usable_dash_token(dash_state):
		return result
	var target_data: Dictionary = _build_emergency_target(owner, dash_state)
	if target_data.is_empty() or _rolled_this_descent:
		return result
	_rolled_this_descent = true
	_last_roll_unit = _roll_unit(owner)
	result["rolled"] = true
	result["roll_unit"] = _last_roll_unit
	if _last_roll_unit >= TRIGGER_CHANCE:
		return result

	var departure_center: Vector2 = target_data.get("departure_center", Vector2.ZERO)
	var arrival_center: Vector2 = target_data.get("arrival_center", Vector2.ZERO)
	var target_player_pos: Vector2 = target_data.get("target_player_pos", Vector2.ZERO)
	owner.set("player_pos", target_player_pos)
	owner.set("player_speed", 0.0)
	# An opposite-direction committed dash may be the reason the guard is going
	# to miss. End it without adding recovery so the next physics tick cannot
	# drag the teleported paddle away before contact.
	if dash_state != null and dash_state.has_method("cancel_active_without_recovery"):
		dash_state.cancel_active_without_recovery()
	_vfx.trigger(departure_center, arrival_center)
	_last_trigger_pos = arrival_center
	_trigger_count += 1
	result["triggered"] = true
	result["target_player_pos"] = target_player_pos
	result["departure_center"] = departure_center
	result["arrival_center"] = arrival_center
	result["frames_to_contact"] = float(target_data.get("frames_to_contact", 0.0))
	return result


func reset_round() -> void:
	_rolled_this_descent = false
	_last_roll_unit = -1.0
	_last_trigger_pos = Vector2.ZERO
	_vfx.reset()


func reset_all() -> void:
	reset_round()
	_trigger_count = 0


func has_visible_effects() -> bool:
	return bool(_vfx.has_visible_effects())


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if has_visible_effects():
		_vfx.draw(canvas, shake_offset)


func get_snapshot() -> Dictionary:
	return {
		"returning_light_step_rolled_this_descent": _rolled_this_descent,
		"returning_light_step_last_roll_unit": _last_roll_unit,
		"returning_light_step_last_trigger_pos": _last_trigger_pos,
		"returning_light_step_trigger_count": _trigger_count,
		"returning_light_step_vfx_active": has_visible_effects(),
	}


func _build_emergency_target(owner: Object, dash_state: Object) -> Dictionary:
	if not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return {}
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return {}
	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius := maxf(
		1.0,
		float(BattleSceneOwnerReader.get_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5
	)
	var player_size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_WIDTH_FALLBACK))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_HEIGHT_FALLBACK)))
	)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5 - player_size.x * 0.5, FIELD_HEIGHT - player_size.y)
	)
	var vertical_gap := player_pos.y - (ball_pos.y + ball_radius)
	# Permit a last-frame overlap inside the paddle height, but never rescue a
	# ball that has already passed completely below the guard body.
	if vertical_gap < -(player_size.y + ball_radius):
		return {}
	if vertical_gap > LOOKAHEAD_GAP:
		return {}
	var impact_boost := maxf(
		0.01,
		float(BattleSceneOwnerReader.get_value(owner, "ball_impact_boost", 1.0))
	)
	var frames_to_contact := maxf(0.0, vertical_gap) / maxf(0.01, ball_vel.y * impact_boost)
	var future_ball_x := _predict_reflected_ball_x(
		ball_pos.x,
		ball_vel.x * impact_boost,
		frames_to_contact,
		ball_radius
	)
	if _span_covers_ball(player_pos.x, player_size.x, future_ball_x, ball_radius):
		return {}

	# Ordinary movement that is already carrying the paddle into the landing
	# span remains a real defense and must not consume this descent's one roll.
	var player_speed := float(BattleSceneOwnerReader.get_value(owner, "player_speed", 0.0))
	var projected_player_x := clampf(
		player_pos.x + player_speed * frames_to_contact,
		0.0,
		maxf(0.0, FIELD_WIDTH - player_size.x)
	)
	if _span_covers_ball(projected_player_x, player_size.x, future_ball_x, ball_radius):
		return {}
	if _active_dash_projects_block(
		dash_state,
		player_pos,
		player_size,
		future_ball_x,
		ball_radius,
		frames_to_contact
	):
		return {}

	var target_x := clampf(
		future_ball_x - player_size.x * 0.5,
		0.0,
		maxf(0.0, FIELD_WIDTH - player_size.x)
	)
	var target_player_pos := Vector2(target_x, player_pos.y)
	return {
		"target_player_pos": target_player_pos,
		"departure_center": player_pos + player_size * 0.5,
		"arrival_center": target_player_pos + player_size * 0.5,
		"frames_to_contact": frames_to_contact,
	}


func _active_dash_projects_block(
	dash_state: Object,
	player_pos: Vector2,
	player_size: Vector2,
	future_ball_x: float,
	ball_radius: float,
	frames_to_contact: float
) -> bool:
	if dash_state == null or not dash_state.has_method("is_active") or not bool(dash_state.is_active()):
		return false
	if not dash_state.has_method("get_snapshot"):
		return false
	var snapshot_value: Variant = dash_state.get_snapshot()
	if not (snapshot_value is Dictionary):
		return false
	var snapshot: Dictionary = snapshot_value
	var direction := signf(float(snapshot.get("direction", 0.0)))
	var dash_timer := maxf(0.0, float(snapshot.get("timer", 0.0)))
	if is_zero_approx(direction) or dash_timer <= 0.0:
		return false
	var travel_frames := clampf(frames_to_contact, 0.0, dash_timer)
	var travel := _resolve_dash_travel(
		dash_timer,
		travel_frames,
		maxf(0.0, float(snapshot.get("dash_distance_multiplier", 1.0)))
	)
	var projected_x := clampf(
		player_pos.x + direction * travel,
		0.0,
		maxf(0.0, FIELD_WIDTH - player_size.x)
	)
	return _span_covers_ball(projected_x, player_size.x, future_ball_x, ball_radius)


func _resolve_dash_travel(dash_timer: float, frames: float, distance_multiplier: float) -> float:
	var full := SmasherDashActiveMotionResolver.compute_total_dash_distance(
		dash_timer,
		distance_multiplier
	)
	var remaining_after := SmasherDashActiveMotionResolver.compute_total_dash_distance(
		maxf(0.0, dash_timer - frames),
		distance_multiplier
	)
	return maxf(0.0, full - remaining_after)


func _predict_reflected_ball_x(
	ball_x: float,
	horizontal_velocity: float,
	frames_to_contact: float,
	ball_radius: float
) -> float:
	var min_x := ball_radius
	var max_x := FIELD_WIDTH - ball_radius
	var span := maxf(1.0, max_x - min_x)
	var unfolded := ball_x - min_x + horizontal_velocity * frames_to_contact
	var folded := fposmod(unfolded, span * 2.0)
	if folded > span:
		folded = span * 2.0 - folded
	return min_x + folded


func _span_covers_ball(
	player_x: float,
	player_width: float,
	ball_x: float,
	ball_radius: float
) -> bool:
	return ball_x >= player_x - ball_radius and ball_x <= player_x + player_width + ball_radius


func _has_usable_dash_token(dash_state: Object) -> bool:
	# A missing dash owner is treated conservatively as an unknown usable dash;
	# the battle boot prewarms this module in production.
	if dash_state == null:
		return true
	if dash_state.has_method("has_full_dash_token"):
		return bool(dash_state.has_full_dash_token())
	if not dash_state.has_method("get_snapshot"):
		return true
	var snapshot_value: Variant = dash_state.get_snapshot()
	if not (snapshot_value is Dictionary):
		return true
	var snapshot: Dictionary = snapshot_value
	return (
		int(snapshot.get("tokens", 0)) > 0
		or bool(snapshot.get("boost_charging_pending_dash_refund", false))
	)


func _update_descent_roll_lock(owner: Object) -> void:
	if owner == null or not bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		_rolled_this_descent = false
		return
	# A zero velocity can be a Stopwatch/freeze hold during the same descent;
	# preserve the lock until the ball genuinely travels upward or the round resets.
	var ball_vel: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y < 0.0:
		_rolled_this_descent = false


func _roll_unit(owner: Object) -> float:
	var forced := float(BattleSceneOwnerReader.get_value(owner, FORCE_ROLL_OWNER_KEY, -1.0))
	if forced >= 0.0:
		return clampf(forced, 0.0, 1.0)
	return randf()


func _owns_byproduct(owned_ids: Variant) -> bool:
	match typeof(owned_ids):
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return BYPRODUCT_ID in owned_ids
		TYPE_DICTIONARY:
			var lookup: Dictionary = owned_ids as Dictionary
			return lookup.has(BYPRODUCT_ID) and bool(lookup.get(BYPRODUCT_ID, false))
	return false
