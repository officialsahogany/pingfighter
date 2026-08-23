extends RefCounted

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const BossSkillTriggerClass := preload("res://scripts/stages/common/boss_skill_trigger_class.gd")

const STAGE_ID := 2
const VARIANT_ID := "arachne"
const GAUGE_MAX := 500.0
const GAUGE_GAIN_ON_HIT := 60.0
const WEB_TRAP_COST := 500.0
const WEB_TRAP_COOLDOWN_SEC := 15.0
const WEB_TRAP_INITIAL_COOLDOWN_SEC := WEB_TRAP_COOLDOWN_SEC
const WEB_TRAP_TRAVEL_SEC := 35.0 / 60.0
const WEB_TRAP_DURATION_SEC := 300.0 / 60.0
const WEB_TRAP_RADIUS := 50.0
const WEB_TRAP_PLAYER_SLOW := 0.40
const WEB_TRAP_EXPAND_SEC := 12.0 / 60.0
const GOLDEN_WEB_STAR_DELAY_SEC := 48.0 / 60.0
const WEB_RESCUE_COST := 50.0
const WEB_RESCUE_COOLDOWN_SEC := 25.0
const WEB_RESCUE_INITIAL_COOLDOWN_SEC := WEB_RESCUE_COOLDOWN_SEC
const WEB_RESCUE_TRIGGER_Y := 25.0
const WEB_RESCUE_SHOOT_SEC := 15.0 / 60.0
const WEB_RESCUE_HOLD_WAIT_SEC := 60.0 / 60.0
const WEB_RESCUE_PULL_SEC := 50.0 / 60.0
const WEB_RESCUE_HOLD_SEC := 60.0 / 60.0
const WEB_RESCUE_STRIKE_SEC := 8.0 / 60.0
const RAGE_STOMP_FRAMES := 70
const RAGE_FINISH_FRAMES := 120
const RAGE_TARGET_PLAYFIELD_WIDTH := 760
const RAGE_TARGET_EDGE_MARGIN := 30
const RAGE_TARGET_ZONE_COUNT := 3
const RAGE_TARGET_CANDIDATE_COUNT := 20
const BOSS_PADDLE_WIDTH := 130.0
const BOSS_HITBOX_HEIGHT := 52.0
const HIT_DURATION_SEC := 0.45
const MOTION_DIRECTION_CHANGE_SEC := 0.15
const LEG_COUNT := 8

var rng := RandomNumberGenerator.new()
var presentation_rng := RandomNumberGenerator.new()
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
var hit_direction := 1
var venom_particles: Array = []
var motion_time := 0.0
var motion_initialized := false
var previous_boss_x := 0.0
var motion_direction := 0
var motion_velocity := 0.0
var movement_accumulator := 0.0
var direction_change_cooldown := 0.0
var step_phase := 0.0
var body_bob := 0.0
var leg_twitch: Array[float] = []
var leg_twitch_timer: Array[float] = []
var status := "charging"


func _init() -> void:
	rng.seed = 22042
	presentation_rng.seed = 22043
	_reset_leg_motion()


func reset() -> void:
	boss_special_gauge = 0.0
	web_trap_cooldown = WEB_TRAP_INITIAL_COOLDOWN_SEC
	web_trap_projectile.clear()
	web_traps.clear()
	pending_stars.clear()
	break_bursts.clear()
	web_rescue_cooldown = WEB_RESCUE_INITIAL_COOLDOWN_SEC
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
	hit_direction = 1
	venom_particles.clear()
	motion_time = 0.0
	motion_initialized = false
	previous_boss_x = 0.0
	motion_direction = 0
	motion_velocity = 0.0
	movement_accumulator = 0.0
	direction_change_cooldown = 0.0
	step_phase = 0.0
	body_bob = 0.0
	presentation_rng.seed = 22043
	_reset_leg_motion()
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
	venom_particles.clear()
	motion_initialized = false
	motion_direction = 0
	motion_velocity = 0.0
	movement_accumulator = 0.0
	direction_change_cooldown = 0.0
	step_phase = 0.0
	body_bob = 0.0
	_reset_leg_motion()
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
	_update_actor_motion(step, context)
	_update_venom_particles(step)
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
	hit_timer = HIT_DURATION_SEC
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_size := float(context.get("ball_size", 0.0))
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_width := float(context.get("boss_paddle_width", BOSS_PADDLE_WIDTH))
	hit_direction = 1 if ball_pos.x + ball_size * 0.5 > boss_pos.x + boss_width * 0.5 else -1
	_spawn_venom_particles()
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
		"stage2_boss_skill_hud_boss_name": str(
			StageBossVariantCatalog.get_entry(STAGE_ID, VARIANT_ID).get("display_name", "보스")
		),
		"stage2_boss_skill_hud_speech": _get_speech(),
		"stage2_boss_skill_hud_status": status,
		"stage2_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage2_boss_skill_hud_boss_gauge_max": GAUGE_MAX,
		"stage2_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage2_boss_skill_hud_skills": [
			_build_skill("web_trap", "천라주망", not web_trap_projectile.is_empty(), web_trap_cooldown, WEB_TRAP_COOLDOWN_SEC, Color(0.78, 0.73, 0.68), "time", BossSkillTriggerClass.TRIGGER_ON_BOSS_HIT),
			_build_skill("web_rescue", "견사회수", web_rescue_active, web_rescue_cooldown, WEB_RESCUE_COOLDOWN_SEC, Color(0.88, 0.88, 0.96)),
			_build_skill("spider_rage", "혈주망진", rage_active, 0.0 if rage_active else 1.0, 1.0, Color(0.88, 0.18, 0.16), "score_latched"),
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
		"arachne_hit_progress": hit_timer / HIT_DURATION_SEC,
		"arachne_hit_direction": hit_direction,
		"arachne_motion_direction": motion_direction,
		"arachne_motion_speed": motion_velocity,
		"arachne_step_phase": step_phase,
		"arachne_body_bob": body_bob,
		"arachne_leg_twitch": leg_twitch.duplicate(),
		"arachne_venom_particles": venom_particles.duplicate(true),
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


func absorb_chaos_spear_objects(center: Vector2, pull_radius: float, _deps: Dictionary = {}) -> Array:
	var absorbed: Array = []
	if not web_trap_projectile.is_empty():
		var projectile_pos := _get_projectile_pos(web_trap_projectile)
		if projectile_pos.distance_to(center) <= pull_radius:
			absorbed.append(_build_chaos_absorb_entry(
				projectile_pos,
				bool(web_trap_projectile.get("golden", false)),
				false,
				0.95
			))
			web_trap_projectile.clear()
	for idx in range(rage_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = rage_projectiles[idx]
		var projectile_pos := _get_projectile_pos(projectile)
		if projectile_pos.distance_to(center) > pull_radius:
			continue
		absorbed.append(_build_chaos_absorb_entry(
			projectile_pos,
			bool(projectile.get("golden", false)),
			true,
			1.0
		))
		rage_projectiles.remove_at(idx)
	for idx in range(web_traps.size() - 1, -1, -1):
		var trap: Dictionary = web_traps[idx]
		var trap_pos := _as_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO)
		var trap_radius := maxf(0.0, float(trap.get("radius", WEB_TRAP_RADIUS)))
		if trap_pos.distance_to(center) > pull_radius + trap_radius:
			continue
		absorbed.append(_build_chaos_absorb_entry(
			trap_pos,
			bool(trap.get("golden", false)),
			bool(trap.get("rage", false)),
			1.05
		))
		web_traps.remove_at(idx)
	if web_rescue_active and web_rescue_ball_pos.distance_to(center) <= pull_radius:
		absorbed.append({
			"position": web_rescue_ball_pos,
			"strength": 1.1,
			"color": Color(0.86, 0.89, 1.0, 1.0),
		})
		web_rescue_active = false
		web_rescue_phase = "idle"
		web_rescue_timer = 0.0
	return absorbed


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
	_cancel_power_smash_for_web_rescue(deps)
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
	var zones := [0, 1, 2]
	for idx in range(zones.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, idx)
		var temp: int = zones[idx]
		zones[idx] = zones[swap_index]
		zones[swap_index] = temp
	var existing_x: Array[float] = []
	for trap_value in web_traps:
		if trap_value is not Dictionary:
			continue
		var trap: Dictionary = trap_value
		existing_x.append(_as_vector2(trap.get("pos", Vector2.ZERO), Vector2.ZERO).x)
	var zone_width := int(float(RAGE_TARGET_PLAYFIELD_WIDTH - RAGE_TARGET_EDGE_MARGIN * 2) / float(RAGE_TARGET_ZONE_COUNT))
	var zone_start := RAGE_TARGET_EDGE_MARGIN
	rage_targets.clear()
	for zone: int in zones:
		var zone_low := zone_start + zone * zone_width + int(WEB_TRAP_RADIUS)
		var zone_high := zone_start + (zone + 1) * zone_width - int(WEB_TRAP_RADIUS)
		if zone_low >= zone_high:
			zone_low = zone_start + zone * zone_width + 5
			zone_high = zone_start + (zone + 1) * zone_width - 5
		var best_x := 0.0
		var best_distance := -1.0
		for _attempt in range(RAGE_TARGET_CANDIDATE_COUNT):
			var candidate_x := float(rng.randi_range(zone_low, zone_high))
			var minimum_distance := INF
			for occupied_x: float in existing_x:
				minimum_distance = minf(minimum_distance, absf(candidate_x - occupied_x))
			if minimum_distance > best_distance:
				best_distance = minimum_distance
				best_x = candidate_x
		rage_targets.append(best_x)
		existing_x.append(best_x)


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


func _update_actor_motion(step: float, context: Dictionary) -> void:
	motion_time += step
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	if not motion_initialized:
		motion_initialized = true
		previous_boss_x = boss_pos.x
		_update_leg_twitch(step)
		body_bob = sin(motion_time * 2.5) * 0.006
		return
	var delta_x := boss_pos.x - previous_boss_x
	direction_change_cooldown = maxf(0.0, direction_change_cooldown - step)
	if absf(delta_x) > 2.0:
		var new_direction := 1 if delta_x > 0.0 else -1
		movement_accumulator += delta_x
		if new_direction != motion_direction and direction_change_cooldown <= 0.0:
			if absf(movement_accumulator) > 5.0:
				motion_direction = new_direction
				direction_change_cooldown = MOTION_DIRECTION_CHANGE_SEC
				movement_accumulator = 0.0
		elif new_direction == motion_direction:
			movement_accumulator = 0.0
	else:
		movement_accumulator *= pow(0.9, step * 60.0)
		if absf(movement_accumulator) < 1.0:
			motion_direction = 0
	motion_velocity = absf(delta_x) / maxf(step, 0.001)
	if motion_direction != 0:
		var speed_ratio := minf(motion_velocity / 80.0, 2.0)
		var acceleration_curve := pow(speed_ratio, 1.2)
		step_phase += step * 6.0 * maxf(acceleration_curve, 0.4)
		body_bob = sin(step_phase * TAU * 0.5) * 0.025 * speed_ratio
	else:
		step_phase *= pow(0.95, step * 60.0)
		body_bob = sin(motion_time * 2.5) * 0.006
	_update_leg_twitch(step)
	previous_boss_x = boss_pos.x


func _update_leg_twitch(step: float) -> void:
	for index in range(LEG_COUNT):
		leg_twitch_timer[index] += step
		if motion_direction == 0:
			leg_twitch[index] = sin(leg_twitch_timer[index] * (2.0 + float(index) * 0.4)) * 0.02
		else:
			leg_twitch[index] *= pow(0.88, step * 60.0)


func _reset_leg_motion() -> void:
	leg_twitch.clear()
	leg_twitch_timer.clear()
	for index in range(LEG_COUNT):
		leg_twitch.append(0.0)
		leg_twitch_timer.append(0.37 + float(index) * 0.61)


func _spawn_venom_particles() -> void:
	var particle_count := presentation_rng.randi_range(6, 10)
	for _index in range(particle_count):
		var angle := presentation_rng.randf_range(-0.8, 0.8) + PI * 0.5
		var speed := presentation_rng.randf_range(40.0, 120.0)
		var lifetime := presentation_rng.randf_range(0.25, 0.55)
		venom_particles.append({
			"pos": Vector2.ZERO,
			"velocity": Vector2(cos(angle) * speed + float(hit_direction) * 30.0, sin(angle) * speed),
			"remaining": lifetime,
			"lifetime": 0.55,
			"size": presentation_rng.randf_range(1.2, 2.8),
		})


func _update_venom_particles(step: float) -> void:
	for idx in range(venom_particles.size() - 1, -1, -1):
		var particle: Dictionary = venom_particles[idx]
		var remaining := float(particle.get("remaining", 0.0)) - step
		if remaining <= 0.0:
			venom_particles.remove_at(idx)
			continue
		var velocity := _as_vector2(particle.get("velocity", Vector2.ZERO), Vector2.ZERO)
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + velocity * step
		velocity.y += 120.0 * step
		particle["velocity"] = velocity
		particle["remaining"] = remaining
		venom_particles[idx] = particle


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


func _build_chaos_absorb_entry(pos: Vector2, golden: bool, rage: bool, strength: float) -> Dictionary:
	var color := Color("ffd750") if golden else Color("de3d3a") if rage else Color("d7d1cc")
	return {
		"position": pos,
		"strength": strength,
		"color": color,
	}


func _cancel_power_smash_for_web_rescue(deps: Dictionary) -> void:
	var power_state: Object = deps.get("power_state", null)
	if power_state == null or not power_state.has_method("is_parabola_active"):
		return
	if not bool(power_state.is_parabola_active()) or not power_state.has_method("reset"):
		return
	power_state.reset(false)


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


func _build_skill(
	id: String,
	label: String,
	active: bool,
	cooldown: float,
	total: float,
	color: Color,
	cooldown_contract: String = "time",
	trigger_type: String = BossSkillTriggerClass.TRIGGER_INSTANT
) -> Dictionary:
	var normalized_cooldown: float = maxf(0.0, cooldown)
	var normalized_total: float = maxf(0.001, total)
	var ready: bool = not active and normalized_cooldown <= 0.0
	var skill_status := "casting" if active else ("ready" if ready else "charging")
	var progress := clampf(1.0 - normalized_cooldown / normalized_total, 0.0, 1.0)
	return {
		"id": id,
		"label": label,
		"active": active,
		"cooldown": normalized_cooldown,
		"cooldown_remaining": normalized_cooldown,
		"cooldown_total": normalized_total,
		"cooldown_progress": progress,
		"status": skill_status,
		"ready": ready,
		"cooldown_contract": cooldown_contract,
		"trigger_type": trigger_type,
		"initial_ready_allowed": false,
		"progress": progress,
		"color": color,
	}


func _play_audio(deps: Dictionary, method_name: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
