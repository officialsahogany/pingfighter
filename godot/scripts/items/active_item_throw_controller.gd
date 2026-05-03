extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const THROW_LOCK_MSEC := 3000
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_SPEED_PER_FRAME := 12.0
const GRENADE_AIM_ERROR_DEGREES := 15.0
const GRENADE_TARGET_RANDOM_X := 30.0
const GRENADE_TARGET_REACHED_DISTANCE := 30.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const GRENADE_BOSS_STUN_FRAMES := 126.0
const GRENADE_BOSS_KNOCKBACK_FRAMES := 18.0
const GRENADE_BOSS_KNOCKBACK_POWER := 38.4
const GRENADE_BOSS_KNOCKBACK_DECAY := 0.88
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_SPEED_PER_FRAME := 9.6
const FLARE_AIM_ERROR_DEGREES := 15.0
const FLARE_TARGET_RANDOM_X := 50.0
const FLARE_TARGET_BELOW_BOSS := 40.0
const FLARE_TARGET_REACHED_DISTANCE := 10.0
const FLARE_ARMED_DELAY_FRAMES := 90.0
const FLARE_RADIUS := 180.0
const FLARE_ZONE_DURATION_FRAMES := 9.0
const FLARE_BOSS_CONFUSION_FRAMES := 180.0
const THROW_POSE_HOLD_ANGLE_DEGREES := 30.0
const THROW_POSE_RELEASE_ANGLE_DEGREES := -20.0
const BOSS_STUN_FRAME_MSEC := 100

var pending_throws: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var flares: Array[Dictionary] = []
var explosion_zones: Array[Dictionary] = []
var flare_zones: Array[Dictionary] = []
var grenade_boss_stun_timer_frames: float = 0.0
var grenade_boss_knockback_timer_frames: float = 0.0
var grenade_boss_knockback_vel: float = 0.0
var flare_boss_confused_timer_frames: float = 0.0


func reset() -> void:
	pending_throws.clear()
	grenades.clear()
	flares.clear()
	explosion_zones.clear()
	flare_zones.clear()
	grenade_boss_stun_timer_frames = 0.0
	grenade_boss_knockback_timer_frames = 0.0
	grenade_boss_knockback_vel = 0.0
	flare_boss_confused_timer_frames = 0.0


func update(owner: Object, registry: Object, delta: float) -> void:
	_update_throw_windups(owner, registry)
	_update_grenades(owner, registry, delta)
	_update_flares(owner, registry, delta)
	_update_explosion_zones(delta)
	_update_flare_zones(delta)
	_update_grenade_boss_effect(delta)
	_update_flare_boss_confusion(delta)


func activate_grenade(owner: Object, registry: Object) -> bool:
	if _is_throw_locked(registry):
		return false
	if is_throw_windup_active():
		return false

	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 50.0))
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var player_center := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target := Vector2(
		boss_pos.x + 100.0 * 0.5 + randf_range(-GRENADE_TARGET_RANDOM_X, GRENADE_TARGET_RANDOM_X),
		boss_pos.y + 20.0
	)
	var now_msec: int = Time.get_ticks_msec()
	pending_throws.append({
		"item_name": "grenade",
		"start_msec": now_msec,
		"release_msec": now_msec + GRENADE_THROW_WINDUP_MSEC,
		"start_position": player_center,
		"target_position": target,
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw_before"):
		audio.play_throw_before()
	return true


func activate_flare(owner: Object, registry: Object) -> bool:
	if _is_throw_locked(registry):
		return false
	if is_throw_windup_active():
		return false

	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 50.0))
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var player_center := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target := Vector2(
		boss_pos.x + 100.0 * 0.5 + randf_range(-FLARE_TARGET_RANDOM_X, FLARE_TARGET_RANDOM_X),
		boss_pos.y + 40.0 + FLARE_TARGET_BELOW_BOSS
	)
	var now_msec: int = Time.get_ticks_msec()
	pending_throws.append({
		"item_name": "flare",
		"start_msec": now_msec,
		"release_msec": now_msec + FLARE_THROW_WINDUP_MSEC,
		"start_position": player_center,
		"target_position": target,
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw_before"):
		audio.play_throw_before()
	return true


func is_throw_windup_active() -> bool:
	return not pending_throws.is_empty()


func is_player_control_locked() -> bool:
	return is_throw_windup_active()


func get_pending_throws() -> Array[Dictionary]:
	return pending_throws


func get_grenades() -> Array[Dictionary]:
	return grenades


func get_flares() -> Array[Dictionary]:
	return flares


func get_explosion_zones() -> Array[Dictionary]:
	return explosion_zones


func get_flare_zones() -> Array[Dictionary]:
	return flare_zones


func get_actor_draw_context() -> Dictionary:
	var throw_context: Dictionary = _get_throw_windup_draw_context()
	return {
		"active_item_throw_windup_active": bool(throw_context.get("active", false)),
		"active_item_throw_windup_progress": float(throw_context.get("progress", 0.0)),
		"active_item_throw_windup_angle_degrees": float(throw_context.get("angle_degrees", 0.0)),
		"active_item_throw_windup_name": str(throw_context.get("item_name", "")),
		"active_item_boss_stun_active": grenade_boss_stun_timer_frames > 0.0,
		"active_item_boss_stun_frame": int(Time.get_ticks_msec() / BOSS_STUN_FRAME_MSEC) % 8,
		"active_item_boss_confusion_active": flare_boss_confused_timer_frames > 0.0,
	}


func get_boss_ai_context() -> Dictionary:
	return {
		"active_item_grenade_stun_active": grenade_boss_stun_timer_frames > 0.0,
		"active_item_grenade_knockback_active": grenade_boss_knockback_timer_frames > 0.0 and abs(grenade_boss_knockback_vel) > 0.0,
		"active_item_grenade_knockback_vel": grenade_boss_knockback_vel,
		"active_item_flare_confusion_active": flare_boss_confused_timer_frames > 0.0,
	}


func _is_throw_locked(registry: Object) -> bool:
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state == null or not round_state.has_method("get_round_start_time_msec"):
		return false
	var round_start_msec: int = int(round_state.get_round_start_time_msec())
	if round_start_msec <= 0:
		return false
	return Time.get_ticks_msec() - round_start_msec < THROW_LOCK_MSEC


func _update_throw_windups(owner: Object, registry: Object) -> void:
	if pending_throws.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for pending_throw in pending_throws:
		if now_msec < int(pending_throw.get("release_msec", now_msec)):
			survivors.append(pending_throw)
			continue
		var item_name: String = str(pending_throw.get("item_name", "grenade"))
		if item_name == "flare":
			_throw_flare(owner, pending_throw, registry)
		else:
			_throw_grenade(owner, pending_throw, registry)
	pending_throws = survivors


func _throw_grenade(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", _get_vector2(pending_throw, "start_position", Vector2.ZERO))
	var start_pos := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos + Vector2(0.0, -120.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(-GRENADE_AIM_ERROR_DEGREES, GRENADE_AIM_ERROR_DEGREES)))
	grenades.append({
		"position": start_pos,
		"velocity": direction * GRENADE_SPEED_PER_FRAME,
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"trail": [start_pos],
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw"):
		audio.play_throw()


func _throw_flare(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", _get_vector2(pending_throw, "start_position", Vector2.ZERO))
	var start_pos := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos + Vector2(0.0, -120.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(-FLARE_AIM_ERROR_DEGREES, FLARE_AIM_ERROR_DEGREES)))
	flares.append({
		"position": start_pos,
		"velocity": direction * FLARE_SPEED_PER_FRAME,
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"timer_frames": 0.0,
		"exploded": false,
		"arrived": false,
		"trail": [start_pos],
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw"):
		audio.play_throw()


func _update_grenades(owner: Object, registry: Object, delta: float) -> void:
	if grenades.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var survivors: Array[Dictionary] = []
	for grenade in grenades:
		var pos: Vector2 = _get_vector2(grenade, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(grenade, "velocity", Vector2.ZERO)
		var target: Vector2 = _get_vector2(grenade, "target_position", pos)
		pos += vel * fps_scale
		grenade["position"] = pos
		grenade["velocity"] = vel
		grenade["rotation_degrees"] = fposmod(float(grenade.get("rotation_degrees", 0.0)) + 15.0 * fps_scale, 360.0)
		var trail: Array = grenade.get("trail", [])
		trail.append(pos)
		while trail.size() > 10:
			trail.pop_front()
		grenade["trail"] = trail

		if pos.distance_to(target) <= GRENADE_TARGET_REACHED_DISTANCE:
			_trigger_grenade_explosion(owner, registry, pos)
			continue
		if pos.y <= 10.0:
			_trigger_grenade_explosion(owner, registry, Vector2(pos.x, 10.0))
			continue

		var wall_margin := 10.0
		if pos.x <= wall_margin:
			pos.x = wall_margin
			vel.x = abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			grenade["position"] = pos
			grenade["velocity"] = vel
		elif pos.x >= FIELD_WIDTH - wall_margin:
			pos.x = FIELD_WIDTH - wall_margin
			vel.x = -abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			grenade["position"] = pos
			grenade["velocity"] = vel

		if pos.x < -100.0 or pos.x > FIELD_WIDTH + 100.0 or pos.y > FIELD_HEIGHT + 100.0:
			continue
		survivors.append(grenade)
	grenades = survivors


func _update_flares(owner: Object, registry: Object, delta: float) -> void:
	if flares.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var survivors: Array[Dictionary] = []
	for flare in flares:
		var arrived: bool = bool(flare.get("arrived", false))
		var exploded: bool = bool(flare.get("exploded", false))
		var pos: Vector2 = _get_vector2(flare, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(flare, "velocity", Vector2.ZERO)
		var target: Vector2 = _get_vector2(flare, "target_position", pos)

		if not arrived:
			pos += vel * fps_scale
			flare["position"] = pos
			flare["velocity"] = vel
			flare["rotation_degrees"] = fposmod(float(flare.get("rotation_degrees", 0.0)) + 12.0 * fps_scale, 360.0)
			var trail: Array = flare.get("trail", [])
			trail.append(pos)
			while trail.size() > 8:
				trail.pop_front()
			flare["trail"] = trail

			if pos.y <= 10.0:
				pos.y = 10.0
				flare["position"] = pos
				flare["arrived"] = true
				survivors.append(flare)
				continue

			var wall_margin := 10.0
			if pos.x <= wall_margin:
				pos.x = wall_margin
				vel.x = abs(vel.x) * 0.7
				if vel.y > 0.0:
					vel.y = -abs(vel.y) * 0.5
				flare["position"] = pos
				flare["velocity"] = vel
			elif pos.x >= FIELD_WIDTH - wall_margin:
				pos.x = FIELD_WIDTH - wall_margin
				vel.x = -abs(vel.x) * 0.7
				if vel.y > 0.0:
					vel.y = -abs(vel.y) * 0.5
				flare["position"] = pos
				flare["velocity"] = vel

			if pos.x < -100.0 or pos.x > FIELD_WIDTH + 100.0 or pos.y > FIELD_HEIGHT + 100.0:
				continue
			if pos.distance_to(target) < FLARE_TARGET_REACHED_DISTANCE:
				flare["position"] = target
				flare["arrived"] = true
			survivors.append(flare)
			continue

		if not exploded:
			var timer_frames: float = float(flare.get("timer_frames", 0.0)) + fps_scale
			flare["timer_frames"] = timer_frames
			if timer_frames >= FLARE_ARMED_DELAY_FRAMES:
				flare["exploded"] = true
				_trigger_flare_flash(owner, registry, pos)
				continue
			survivors.append(flare)
	flares = survivors


func _trigger_grenade_explosion(owner: Object, registry: Object, center: Vector2) -> void:
	explosion_zones.append({
		"position": center,
		"radius": GRENADE_EXPLOSION_RADIUS,
		"duration_frames": GRENADE_EXPLOSION_DURATION_FRAMES,
		"max_duration_frames": GRENADE_EXPLOSION_DURATION_FRAMES,
		"active": true,
		"source": "grenade",
	})
	_apply_grenade_boss_effect(owner, center, GRENADE_EXPLOSION_RADIUS)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.24, 7.0)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()


func _apply_grenade_boss_effect(owner: Object, center: Vector2, radius: float) -> void:
	if owner == null:
		return
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	if boss_center.distance_to(center) > radius:
		return
	grenade_boss_stun_timer_frames = max(grenade_boss_stun_timer_frames, GRENADE_BOSS_STUN_FRAMES)
	grenade_boss_knockback_timer_frames = max(grenade_boss_knockback_timer_frames, GRENADE_BOSS_KNOCKBACK_FRAMES)
	var direction: float = 1.0 if boss_center.x >= center.x else -1.0
	var knockback_vel: float = direction * GRENADE_BOSS_KNOCKBACK_POWER
	if abs(knockback_vel) >= abs(grenade_boss_knockback_vel):
		grenade_boss_knockback_vel = knockback_vel


func _trigger_flare_flash(owner: Object, registry: Object, center: Vector2) -> void:
	flare_zones.append({
		"position": center,
		"radius": FLARE_RADIUS,
		"duration_frames": FLARE_ZONE_DURATION_FRAMES,
		"max_duration_frames": FLARE_ZONE_DURATION_FRAMES,
		"intensity": 1.0,
		"flash": true,
	})
	_apply_flare_boss_confusion(owner, center, FLARE_RADIUS)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_flashbomb"):
		audio.play_flashbomb()


func _apply_flare_boss_confusion(owner: Object, center: Vector2, radius: float) -> void:
	if owner == null:
		return
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	if boss_center.distance_to(center) > radius:
		return
	flare_boss_confused_timer_frames = max(flare_boss_confused_timer_frames, FLARE_BOSS_CONFUSION_FRAMES)


func _update_explosion_zones(delta: float) -> void:
	if explosion_zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var survivors: Array[Dictionary] = []
	for zone in explosion_zones:
		var remaining: float = float(zone.get("duration_frames", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		zone["duration_frames"] = remaining
		survivors.append(zone)
	explosion_zones = survivors


func _update_flare_zones(delta: float) -> void:
	if flare_zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var survivors: Array[Dictionary] = []
	for zone in flare_zones:
		var remaining: float = float(zone.get("duration_frames", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		zone["duration_frames"] = remaining
		if bool(zone.get("flash", false)):
			if remaining > 6.0:
				zone["intensity"] = 1.0
			elif remaining > 3.0:
				zone["intensity"] = 0.3
			else:
				zone["intensity"] = 0.8
		else:
			zone["intensity"] = remaining / max(1.0, float(zone.get("max_duration_frames", FLARE_ZONE_DURATION_FRAMES)))
		survivors.append(zone)
	flare_zones = survivors


func _update_grenade_boss_effect(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	grenade_boss_stun_timer_frames = max(0.0, grenade_boss_stun_timer_frames - fps_scale)
	if grenade_boss_knockback_timer_frames > 0.0:
		grenade_boss_knockback_timer_frames = max(0.0, grenade_boss_knockback_timer_frames - fps_scale)
		grenade_boss_knockback_vel *= pow(GRENADE_BOSS_KNOCKBACK_DECAY, fps_scale)
		if grenade_boss_knockback_timer_frames <= 0.0 or abs(grenade_boss_knockback_vel) <= 0.3:
			grenade_boss_knockback_timer_frames = 0.0
			grenade_boss_knockback_vel = 0.0
	elif abs(grenade_boss_knockback_vel) > 0.0:
		grenade_boss_knockback_vel = 0.0


func _update_flare_boss_confusion(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	flare_boss_confused_timer_frames = max(0.0, flare_boss_confused_timer_frames - fps_scale)


func _get_throw_windup_draw_context() -> Dictionary:
	if pending_throws.is_empty():
		return {
			"active": false,
		}
	var pending_throw: Dictionary = pending_throws[0]
	var progress: float = _get_throw_windup_progress(pending_throw)
	return {
		"active": true,
		"progress": progress,
		"angle_degrees": _get_throw_pose_angle_degrees(progress),
		"item_name": str(pending_throw.get("item_name", "grenade")),
	}


func _get_throw_windup_progress(pending_throw: Dictionary) -> float:
	var now_msec: int = Time.get_ticks_msec()
	var start_msec: int = int(pending_throw.get("start_msec", now_msec))
	var release_msec: int = int(pending_throw.get("release_msec", start_msec + GRENADE_THROW_WINDUP_MSEC))
	var duration_msec: int = max(1, release_msec - start_msec)
	return clamp(float(now_msec - start_msec) / float(duration_msec), 0.0, 1.0)


func _get_throw_pose_angle_degrees(progress: float) -> float:
	var clamped_progress: float = clamp(progress, 0.0, 1.0)
	if clamped_progress < 0.30:
		return THROW_POSE_HOLD_ANGLE_DEGREES * (clamped_progress / 0.30)
	if clamped_progress < 0.70:
		return THROW_POSE_HOLD_ANGLE_DEGREES
	return lerp(
		THROW_POSE_HOLD_ANGLE_DEGREES,
		THROW_POSE_RELEASE_ANGLE_DEGREES,
		(clamped_progress - 0.70) / 0.30
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
