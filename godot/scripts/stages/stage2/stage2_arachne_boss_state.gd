extends RefCounted

const STAGE_ID := 2
const VARIANT_ID := "arachne"
const GAUGE_MAX := 500.0
const GAUGE_GAIN_ON_HIT := 60.0
const WEB_TRAP_COST := 500.0
const WEB_TRAP_COOLDOWN_SEC := 15.0
const WEB_TRAP_TRAVEL_SEC := 35.0 / 60.0
const WEB_TRAP_DURATION_SEC := 300.0 / 60.0
const WEB_TRAP_RADIUS := 50.0
const WEB_TRAP_PLAYER_SLOW := 0.40
const WEB_TRAP_EXPAND_SEC := 12.0 / 60.0
const GOLDEN_WEB_STAR_DELAY_SEC := 48.0 / 60.0
const WEB_RESCUE_COST := 50.0
const WEB_RESCUE_COOLDOWN_SEC := 25.0
const WEB_RESCUE_TRIGGER_Y := 25.0
const WEB_RESCUE_SHOOT_SEC := 15.0 / 60.0
const WEB_RESCUE_HOLD_WAIT_SEC := 60.0 / 60.0
const WEB_RESCUE_PULL_SEC := 50.0 / 60.0
const WEB_RESCUE_HOLD_SEC := 60.0 / 60.0
const WEB_RESCUE_STRIKE_SEC := 8.0 / 60.0
const RAGE_STOMP_FRAMES := 70
const RAGE_FINISH_FRAMES := 120
const BOSS_PADDLE_WIDTH := 130.0
const BOSS_HITBOX_HEIGHT := 52.0

var rng := RandomNumberGenerator.new()
var boss_special_gauge := 0.0
var web_trap_cooldown := 0.0
var web_trap_projectile: Dictionary = {}
var web_traps: Array = []
var pending_stars: Array = []
var break_bursts: Array = []
var web_rescue_cooldown := 0.0
var web_rescue_active := false
var web_rescue_phase := "idle"
var web_rescue_timer := 0.0
var web_rescue_ball_pos := Vector2.ZERO
var web_rescue_boss_start_x := 380.0
var rage_pending := false
var rage_triggered := false
var rage_active := false
var rage_frame_accumulator := 0.0
var rage_frame := 0
var rage_targets: Array[float] = []
var rage_projectiles: Array = []
var rage_stomp_offset_y := 0.0
var rage_red_tint := 0.0
var hit_timer := 0.0
var status := "charging"


func _init() -> void:
	rng.seed = 22042


func reset() -> void:
	boss_special_gauge = 0.0
	web_trap_cooldown = 0.0
	web_trap_projectile.clear()
	web_traps.clear()
	pending_stars.clear()
	break_bursts.clear()
	web_rescue_cooldown = 0.0
	web_rescue_active = false
	web_rescue_phase = "idle"
	web_rescue_timer = 0.0
	rage_pending = false
	rage_triggered = false
	rage_active = false
	rage_frame_accumulator = 0.0
	rage_frame = 0
	rage_targets.clear()
	rage_projectiles.clear()
	rage_stomp_offset_y = 0.0
	rage_red_tint = 0.0
	hit_timer = 0.0
	status = "charging"


func reset_round() -> void:
	boss_special_gauge = 0.0
	web_trap_projectile.clear()
	web_rescue_active = false
	web_rescue_phase = "idle"
	web_rescue_timer = 0.0
	rage_projectiles.clear()
	rage_stomp_offset_y = 0.0
	rage_red_tint = 0.0
	hit_timer = 0.0
	for idx in range(web_traps.size() - 1, -1, -1):
		var trap: Dictionary = web_traps[idx]
		if not bool(trap.get("rage", false)):
			web_traps.remove_at(idx)
	if rage_pending:
		rage_pending = false
		rage_triggered = true
		_start_rage()
	elif rage_triggered:
		_start_rage()
	status = "spider_rage" if rage_active else "charging"


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or str(context.get("stage_boss_variant", "")) != VARIANT_ID:
		return {}
	var step := clampf(delta, 0.0, 0.05)
	web_trap_cooldown = maxf(0.0, web_trap_cooldown - step)
	web_rescue_cooldown = maxf(0.0, web_rescue_cooldown - step)
	hit_timer = maxf(0.0, hit_timer - step)
	_update_pending_stars(step, deps, context)
	_update_break_bursts(step)
	_update_web_trap_projectile(step, context, deps)
	_update_web_traps(step, context, deps)
	_update_rage(step, context, deps)
	var result := {
		"boss_paddle_width": BOSS_PADDLE_WIDTH,
		"boss_hitbox_height": BOSS_HITBOX_HEIGHT,
	}
	if web_rescue_active:
		result.merge(_update_web_rescue(step, context, deps), true)
	elif _can_activate_web_rescue(context):
		_activate_web_rescue(context, deps)
		result.merge(_update_web_rescue(0.0, context, deps), true)
	status = _resolve_status()
	return result


func register_boss_hit(_ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or str(context.get("stage_boss_variant", "")) != VARIANT_ID:
		return {}
	boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + GAUGE_GAIN_ON_HIT)
	hit_timer = 0.45
	var triggered := false
	if web_trap_cooldown <= 0.0 and web_trap_projectile.is_empty() and boss_special_gauge >= WEB_TRAP_COST:
		boss_special_gauge -= WEB_TRAP_COST
		_activate_web_trap(context, deps)
		triggered = true
	return {
		"boss_special_gauge": boss_special_gauge,
		"stage2_boss_gauge_gain": GAUGE_GAIN_ON_HIT,
		"arachne_web_trap_triggered": triggered,
	}


func handle_score_event(scoring_side: String, score_result: Dictionary, _deps: Dictionary = {}) -> void:
	if scoring_side == "player" and int(score_result.get("player_score", 0)) == 4 and not rage_triggered:
		rage_pending = true


func get_boss_ai_context(_stage_background: Object = null) -> Dictionary:
	return {
		"stage2_boss_movement_locked": web_rescue_active,
		"stage2_water_cannon_phase": "idle",
		"stage2_boss_skill_status": status,
		"stage2_speed_defense_active": false,
		"stage2_speed_defense_status_immunity_active": false,
		"stage2_speed_defense_speed_multiplier": 1.0,
		"stage2_speed_defense_turn_multiplier": 1.0,
		"stage2_speed_defense_initial_speed_ratio": 0.0,
	}


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage2_boss_skill_hud_active": true,
		"stage2_boss_skill_hud_boss_name": "아라크네",
		"stage2_boss_skill_hud_speech": _get_speech(),
		"stage2_boss_skill_hud_status": status,
		"stage2_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage2_boss_skill_hud_boss_gauge_max": GAUGE_MAX,
		"stage2_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage2_boss_skill_hud_skills": [
			_build_skill("web_trap", "거미줄 장판", not web_trap_projectile.is_empty(), web_trap_cooldown, WEB_TRAP_COOLDOWN_SEC, Color(0.78, 0.73, 0.68)),
			_build_skill("web_rescue", "거미줄 구출", web_rescue_active, web_rescue_cooldown, WEB_RESCUE_COOLDOWN_SEC, Color(0.88, 0.88, 0.96)),
			_build_skill("spider_rage", "분노 거미줄", rage_active, 0.0 if rage_active else 1.0, 1.0, Color(0.88, 0.18, 0.16)),
		],
	}


func get_pressure_snapshot(_context: Dictionary = {}) -> Dictionary:
	return {
		"boss_gauge": boss_special_gauge,
		"boss_gauge_max": GAUGE_MAX,
		"boss_gauge_progress": get_boss_gauge_progress(),
		"boss_gauge_gain_on_hit": GAUGE_GAIN_ON_HIT,
	}


func get_actor_draw_context() -> Dictionary:
	return {
		"stage_boss_variant": VARIANT_ID,
		"arachne_hit_progress": hit_timer / 0.45,
		"arachne_web_trap_projectile": web_trap_projectile.duplicate(true),
		"arachne_web_traps": web_traps.duplicate(true),
		"arachne_web_break_bursts": break_bursts.duplicate(true),
		"arachne_web_rescue_active": web_rescue_active,
		"arachne_web_rescue_phase": web_rescue_phase,
		"arachne_web_rescue_progress": _web_rescue_progress(),
		"arachne_web_rescue_ball_pos": web_rescue_ball_pos,
		"arachne_rage_active": rage_active,
		"arachne_rage_projectiles": rage_projectiles.duplicate(true),
		"arachne_rage_stomp_offset_y": rage_stomp_offset_y,
		"arachne_rage_red_tint": rage_red_tint,
	}


func get_status() -> String:
	return status


func is_speed_defense_active() -> bool:
	return false


func is_boss_status_immune() -> bool:
	return false


func get_quake_cooldown() -> float:
	return web_trap_cooldown


func get_boss_special_gauge() -> float:
	return boss_special_gauge


func get_boss_gauge_max() -> float:
	return GAUGE_MAX


func get_boss_gauge_progress() -> float:
	return clampf(boss_special_gauge / GAUGE_MAX, 0.0, 1.0)


func get_water_cannon_delay() -> float:
	return 0.0


func get_water_cannon_delay_total() -> float:
	return 0.0


func defer_water_cannon_after_rock_spawn(_delay_sec: float = 7.0) -> void:
	pass


func _activate_web_trap(context: Dictionary, deps: Dictionary) -> void:
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2(315.0, 25.0)), Vector2(315.0, 25.0))
	web_trap_projectile = {
		"start": boss_pos + Vector2(BOSS_PADDLE_WIDTH * 0.5, BOSS_HITBOX_HEIGHT + 5.0),
		"target": Vector2(rng.randf_range(20.0, 740.0), rng.randf_range(695.0, 720.0)),
		"age": 0.0,
		"duration": WEB_TRAP_TRAVEL_SEC,
		"golden": rng.randf() < 0.30,
		"rage": false,
	}
	web_trap_cooldown = WEB_TRAP_COOLDOWN_SEC
	_play_audio(deps, "play_commando_net_gun_capture")


func _update_web_trap_projectile(step: float, context: Dictionary, deps: Dictionary) -> void:
	if web_trap_projectile.is_empty():
		return
	web_trap_projectile["age"] = float(web_trap_projectile.get("age", 0.0)) + step
	var pos := _get_projectile_pos(web_trap_projectile)
	if _is_point_in_smoke(pos, context, deps):
		_spawn_break_burst(pos, bool(web_trap_projectile.get("golden", false)), bool(web_trap_projectile.get("rage", false)))
		web_trap_projectile.clear()
		return
	if float(web_trap_projectile.get("age", 0.0)) >= float(web_trap_projectile.get("duration", WEB_TRAP_TRAVEL_SEC)):
		_land_web_projectile(web_trap_projectile)
		web_trap_projectile.clear()


func _land_web_projectile(projectile: Dictionary) -> void:
	web_traps.append({
		"pos": _as_vector2(projectile.get("target", Vector2.ZERO), Vector2.ZERO),
		"radius": WEB_TRAP_RADIUS,
		"remaining": -1.0 if bool(projectile.get("rage", false)) else WEB_TRAP_DURATION_SEC,
		"expand": WEB_TRAP_EXPAND_SEC,
		"phase": rng.randf_range(0.0, TAU),
		"rage": bool(projectile.get("rage", false)),
		"golden": bool(projectile.get("golden", false)),
	})


func _update_web_traps(step: float, context: Dictionary, deps: Dictionary) -> void:
	var player_pos := _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_rect := Rect2(player_pos, player_size)
	var dash_snapshot: Dictionary = context.get("dash_snapshot", {})
	var dash_active := bool(dash_snapshot.get("active", false))
	for idx in range(web_traps.size() - 1, -1, -1):
		var trap: Dictionary = web_traps[idx]
		trap["phase"] = float(trap.get("phase", 0.0)) + step * 3.0
		trap["expand"] = maxf(0.0, float(trap.get("expand", 0.0)) - step)
		if not bool(trap.get("rage", false)):
			trap["remaining"] = float(trap.get("remaining", 0.0)) - step
		var center := _as_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
		var radius := float(trap.get("radius", WEB_TRAP_RADIUS))
		var trap_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		var expanded := float(trap.get("expand", 0.0)) <= 0.0
		var destroyed := expanded and _is_point_in_smoke(center, context, deps)
		if expanded and dash_active and player_rect.intersects(trap_rect):
			destroyed = true
			_play_audio(deps, "play_spider_mine_setup")
			if bool(trap.get("golden", false)):
				pending_stars.append({"pos": center, "remaining": GOLDEN_WEB_STAR_DELAY_SEC})
		if destroyed or float(trap.get("remaining", 1.0)) == 0.0 or float(trap.get("remaining", 1.0)) < -0.001 and not bool(trap.get("rage", false)):
			_spawn_break_burst(center, bool(trap.get("golden", false)), bool(trap.get("rage", false)))
			web_traps.remove_at(idx)
			continue
		if expanded and player_rect.intersects(trap_rect) and not dash_active:
			_apply_web_slow(deps)
		web_traps[idx] = trap


func _apply_web_slow(deps: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null and status_effect_state.has_method("apply_status"):
		status_effect_state.apply_status("player", "slow", 2.0, {
			"multiplier": WEB_TRAP_PLAYER_SLOW,
			"cleansable": false,
		}, "arachne_web_trap")


func _can_activate_web_rescue(context: Dictionary) -> bool:
	if web_rescue_cooldown > 0.0 or boss_special_gauge < WEB_RESCUE_COST:
		return false
	if not bool(context.get("ball_active", false)):
		return false
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel := _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	return ball_pos.y < WEB_RESCUE_TRIGGER_Y and ball_vel.y < 0.0


func _activate_web_rescue(context: Dictionary, deps: Dictionary) -> void:
	boss_special_gauge -= WEB_RESCUE_COST
	web_rescue_cooldown = WEB_RESCUE_COOLDOWN_SEC
	web_rescue_active = true
	web_rescue_phase = "shoot"
	web_rescue_timer = 0.0
	web_rescue_ball_pos = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	web_rescue_boss_start_x = boss_pos.x
	_play_audio(deps, "play_commando_net_gun_capture")


func _update_web_rescue(step: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	web_rescue_timer += step
	var result := {
		"ball_pos": web_rescue_ball_pos,
		"ball_vel": Vector2.ZERO,
		"skip_ball_motion_step": true,
	}
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	match web_rescue_phase:
		"shoot":
			if web_rescue_timer >= WEB_RESCUE_SHOOT_SEC:
				web_rescue_phase = "hold_wait"
				web_rescue_timer = 0.0
		"hold_wait":
			if web_rescue_timer >= WEB_RESCUE_HOLD_WAIT_SEC:
				web_rescue_phase = "pull"
				web_rescue_timer = 0.0
				web_rescue_boss_start_x = boss_pos.x
		"pull":
			var pull_ratio := clampf(web_rescue_timer / WEB_RESCUE_PULL_SEC, 0.0, 1.0)
			var target_x := web_rescue_ball_pos.x - BOSS_PADDLE_WIDTH * 0.5
			boss_pos.x = lerpf(web_rescue_boss_start_x, target_x, pull_ratio * pull_ratio)
			result["boss_pos"] = boss_pos
			if web_rescue_timer >= WEB_RESCUE_PULL_SEC:
				web_rescue_phase = "hold"
				web_rescue_timer = 0.0
		"hold":
			web_rescue_ball_pos = boss_pos + Vector2(BOSS_PADDLE_WIDTH * 0.5, BOSS_HITBOX_HEIGHT + 8.0)
			result["ball_pos"] = web_rescue_ball_pos
			if web_rescue_timer >= WEB_RESCUE_HOLD_SEC:
				web_rescue_phase = "strike"
				web_rescue_timer = 0.0
				_play_audio(deps, "play_stage3_tail")
		"strike":
			web_rescue_ball_pos = boss_pos + Vector2(BOSS_PADDLE_WIDTH * 0.5, BOSS_HITBOX_HEIGHT + 8.0 + minf(web_rescue_timer * 180.0, 20.0))
			result["ball_pos"] = web_rescue_ball_pos
			if web_rescue_timer >= WEB_RESCUE_STRIKE_SEC:
				web_rescue_phase = "release"
				web_rescue_timer = 0.0
		"release":
			var angle := rng.randf_range(-0.3, 0.3)
			result["ball_vel"] = Vector2(18.0 * sin(angle), 18.0 * cos(angle))
			result["skip_ball_motion_step"] = false
			web_rescue_active = false
			web_rescue_phase = "idle"
	return result


func _start_rage() -> void:
	rage_active = true
	rage_frame_accumulator = 0.0
	rage_frame = 0
	rage_targets.clear()
	rage_projectiles.clear()


func _update_rage(step: float, context: Dictionary, deps: Dictionary) -> void:
	_update_rage_projectiles(step, context, deps)
	if not rage_active:
		return
	rage_frame_accumulator += step * 60.0
	while rage_frame_accumulator >= 1.0:
		rage_frame_accumulator -= 1.0
		rage_frame += 1
		_update_rage_frame(context, deps)
	if rage_frame > RAGE_FINISH_FRAMES and rage_projectiles.is_empty():
		rage_active = false
		rage_frame = 0
		rage_stomp_offset_y = 0.0
		rage_red_tint = 0.0


func _update_rage_frame(context: Dictionary, deps: Dictionary) -> void:
	if rage_frame <= RAGE_STOMP_FRAMES:
		rage_red_tint = minf(1.0, float(rage_frame * 4) / 255.0)
		var stomp_phase := rage_frame % 15
		if stomp_phase == 0:
			rage_stomp_offset_y = -15.0
			_play_audio(deps, "play_spider_mine_setup")
			var feedback: Object = deps.get("feedback", null)
			if feedback != null and feedback.has_method("max_screen_shake"):
				feedback.max_screen_shake(0.10, 4.0)
		elif stomp_phase == 5:
			rage_stomp_offset_y = 8.0
		else:
			rage_stomp_offset_y *= 0.7
	if rage_frame == RAGE_STOMP_FRAMES:
		_build_rage_targets()
	if rage_frame in [80, 90, 100]:
		var shot_index := (rage_frame - 80) / 10
		_spawn_rage_projectile(context, int(shot_index), deps)
	if rage_frame > 100 and rage_frame <= RAGE_FINISH_FRAMES:
		rage_red_tint = maxf(0.0, 1.0 - float(rage_frame - 100) / 20.0)
		rage_stomp_offset_y *= 0.8


func _build_rage_targets() -> void:
	rage_targets = [140.0, 380.0, 620.0]
	for idx in range(rage_targets.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, idx)
		var temp := rage_targets[idx]
		rage_targets[idx] = rage_targets[swap_index]
		rage_targets[swap_index] = temp
	for idx in range(rage_targets.size()):
		rage_targets[idx] = float(rage_targets[idx]) + rng.randf_range(-28.0, 28.0)


func _spawn_rage_projectile(context: Dictionary, index: int, deps: Dictionary) -> void:
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2(315.0, 25.0)), Vector2(315.0, 25.0))
	var target_x := rage_targets[index] if index >= 0 and index < rage_targets.size() else rng.randf_range(30.0, 730.0)
	rage_projectiles.append({
		"start": boss_pos + Vector2(BOSS_PADDLE_WIDTH * 0.5, BOSS_HITBOX_HEIGHT + 5.0),
		"target": Vector2(target_x, rng.randf_range(695.0, 720.0)),
		"age": 0.0,
		"duration": WEB_TRAP_TRAVEL_SEC,
		"golden": rng.randf() < 0.30,
		"rage": true,
	})
	_play_audio(deps, "play_commando_net_gun_capture")


func _update_rage_projectiles(step: float, context: Dictionary, deps: Dictionary) -> void:
	for idx in range(rage_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = rage_projectiles[idx]
		projectile["age"] = float(projectile.get("age", 0.0)) + step
		var pos := _get_projectile_pos(projectile)
		if _is_point_in_smoke(pos, context, deps):
			_spawn_break_burst(pos, bool(projectile.get("golden", false)), true)
			rage_projectiles.remove_at(idx)
		elif float(projectile.get("age", 0.0)) >= float(projectile.get("duration", WEB_TRAP_TRAVEL_SEC)):
			_land_web_projectile(projectile)
			rage_projectiles.remove_at(idx)
		else:
			rage_projectiles[idx] = projectile


func _update_pending_stars(step: float, deps: Dictionary, context: Dictionary) -> void:
	for idx in range(pending_stars.size() - 1, -1, -1):
		var pending: Dictionary = pending_stars[idx]
		pending["remaining"] = float(pending.get("remaining", 0.0)) - step
		if float(pending["remaining"]) <= 0.0:
			_spawn_starpoint(_as_vector2(pending.get("pos", Vector2.ZERO), Vector2.ZERO), deps, context)
			pending_stars.remove_at(idx)
		else:
			pending_stars[idx] = pending


func _spawn_starpoint(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("spawn_starpoint_drop"):
		stage_background.spawn_starpoint_drop(pos, "golden_web", deps, context)


func _spawn_break_burst(pos: Vector2, golden: bool, rage: bool) -> void:
	break_bursts.append({"pos": pos, "age": 0.0, "golden": golden, "rage": rage})
	if break_bursts.size() > 18:
		break_bursts.pop_front()


func _update_break_bursts(step: float) -> void:
	for idx in range(break_bursts.size() - 1, -1, -1):
		var burst: Dictionary = break_bursts[idx]
		burst["age"] = float(burst.get("age", 0.0)) + step
		if float(burst["age"]) >= 0.55:
			break_bursts.remove_at(idx)
		else:
			break_bursts[idx] = burst


func _is_point_in_smoke(pos: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	for value in _get_smoke_zones(context, deps):
		if not (value is Dictionary):
			continue
		var zone: Dictionary = value
		var opacity := float(zone.get("opacity", 0.0))
		var threshold := 50.0 if opacity > 1.0 else 0.20
		if opacity <= threshold:
			continue
		var center := _as_vector2(zone.get("position", Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))), Vector2.ZERO)
		var radius_y := float(zone.get("radius", 0.0))
		var radius_x := float(zone.get("radius_x", radius_y))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var relative := pos - center
		if relative.x * relative.x / (radius_x * radius_x) + relative.y * relative.y / (radius_y * radius_y) <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var value: Variant = context.get(key, [])
		if value is Array and not value.is_empty():
			return value
	var runtime: Object = deps.get("active_item_runtime", null)
	if runtime != null and runtime.has_method("get_tear_gas_zones"):
		var runtime_zones: Variant = runtime.get_tear_gas_zones()
		if runtime_zones is Array:
			return runtime_zones
	return []


func _get_projectile_pos(projectile: Dictionary) -> Vector2:
	var start := _as_vector2(projectile.get("start", Vector2.ZERO), Vector2.ZERO)
	var target := _as_vector2(projectile.get("target", Vector2.ZERO), Vector2.ZERO)
	var ratio := clampf(float(projectile.get("age", 0.0)) / maxf(0.001, float(projectile.get("duration", WEB_TRAP_TRAVEL_SEC))), 0.0, 1.0)
	var eased := 1.0 - (1.0 - ratio) * (1.0 - ratio)
	return start.lerp(target, eased)


func _resolve_status() -> String:
	if web_rescue_active:
		return "web_rescue_%s" % web_rescue_phase
	if rage_active:
		return "spider_rage"
	if not web_trap_projectile.is_empty():
		return "web_trap"
	return "charging"


func _get_speech() -> String:
	if web_rescue_active:
		return "잡았다!"
	if rage_active:
		return "용서 못 해...!"
	if not web_trap_projectile.is_empty():
		return "거미줄!"
	return ""


func _web_rescue_progress() -> float:
	match web_rescue_phase:
		"shoot":
			return clampf(web_rescue_timer / WEB_RESCUE_SHOOT_SEC, 0.0, 1.0)
		"hold_wait":
			return clampf(web_rescue_timer / WEB_RESCUE_HOLD_WAIT_SEC, 0.0, 1.0)
		"pull":
			return clampf(web_rescue_timer / WEB_RESCUE_PULL_SEC, 0.0, 1.0)
		"hold":
			return clampf(web_rescue_timer / WEB_RESCUE_HOLD_SEC, 0.0, 1.0)
		"strike":
			return clampf(web_rescue_timer / WEB_RESCUE_STRIKE_SEC, 0.0, 1.0)
	return 0.0


func _build_skill(id: String, label: String, active: bool, cooldown: float, total: float, color: Color) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"active": active,
		"cooldown": maxf(0.0, cooldown),
		"cooldown_total": maxf(0.001, total),
		"cooldown_progress": clampf(1.0 - maxf(0.0, cooldown) / maxf(0.001, total), 0.0, 1.0),
		"color": color,
	}


func _play_audio(deps: Dictionary, method_name: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
