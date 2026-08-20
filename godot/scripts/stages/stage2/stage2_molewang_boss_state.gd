extends RefCounted

const STAGE_ID := 2
const VARIANT_ID := "molewang"
const GAUGE_MAX := 500.0
const GAUGE_GAIN_ON_HIT := 60.0
const TUNNEL_COST := 500.0
const TUNNEL_COOLDOWN_SEC := 8.0
const TUNNEL_WARN_SEC := 30.0 / 60.0
const TUNNEL_STRIKE_SEC := 40.0 / 60.0
const TUNNEL_RETURN_SEC := 60.0 / 60.0
const TUNNEL_SPIKE_INTERVAL_SEC := 4.0 / 60.0
const TUNNEL_MAX_SPIKES := 10
const SPINNING_CLAW_COST := 60.0
const SPINNING_CLAW_COOLDOWN_SEC := 20.0
const SPINNING_CLAW_DURATION_SEC := 30.0 / 60.0
const SPINNING_CLAW_BALL_SPEED_MULTIPLIER := 0.8
const SPINNING_CLAW_SPIN_STRENGTH := 0.55
const FRIEND_MOLE_SPAWN_SEC := 90.0 / 60.0
const FRIEND_MOLE_RADIUS := 18.0
const FRIEND_MOLE_RISE_SEC := 12.0 / 60.0
const FRIEND_MOLE_HOLD_SEC := 60.0 / 60.0
const FRIEND_MOLE_FALL_SEC := 12.0 / 60.0
const PHYSICS_TICKS_PER_SECOND := 72
const FRIEND_MOLES_DURATION_TICKS := PHYSICS_TICKS_PER_SECOND * 10
const FRIEND_MOLES_COOLDOWN_TICKS := PHYSICS_TICKS_PER_SECOND * 40

var rng := RandomNumberGenerator.new()
var boss_special_gauge := 0.0
var tunnel_cooldown := 0.0
var tunnel_active := false
var tunnel_phase := "idle"
var tunnel_timer := 0.0
var tunnel_target_x := 380.0
var tunnel_spike_accumulator := 0.0
var tunnel_spikes: Array = []
var tunnel_strike_applied := false
var spinning_claw_timer := 0.0
var spinning_claw_cooldown := 0.0
var spinning_claw_direction := 1
var hit_emerge_timer := 0.0
var friend_moles_pending := false
var friend_moles_triggered := false
var friend_moles_active := false
var friend_moles_duration_ticks_remaining := 0
var friend_moles_cooldown_ticks_remaining := 0
var friend_moles_spawn_timer := 0.0
var friend_moles: Array = []
var friend_mole_particles: Array = []
var status := "charging"


func _init() -> void:
	rng.seed = 22041


func reset() -> void:
	boss_special_gauge = 0.0
	tunnel_cooldown = 0.0
	tunnel_active = false
	tunnel_phase = "idle"
	tunnel_timer = 0.0
	tunnel_spike_accumulator = 0.0
	tunnel_spikes.clear()
	tunnel_strike_applied = false
	spinning_claw_timer = 0.0
	spinning_claw_cooldown = 0.0
	hit_emerge_timer = 0.0
	friend_moles_pending = false
	friend_moles_triggered = false
	friend_moles_active = false
	friend_moles_duration_ticks_remaining = 0
	friend_moles_cooldown_ticks_remaining = 0
	friend_moles_spawn_timer = 0.0
	friend_moles.clear()
	friend_mole_particles.clear()
	status = "charging"


func reset_round() -> void:
	boss_special_gauge = 0.0
	tunnel_active = false
	tunnel_phase = "idle"
	tunnel_timer = 0.0
	tunnel_spikes.clear()
	tunnel_strike_applied = false
	spinning_claw_timer = 0.0
	spinning_claw_cooldown = 0.0
	hit_emerge_timer = 0.0
	_stop_friend_moles()
	if friend_moles_pending:
		friend_moles_pending = false
		friend_moles_triggered = true
		friend_moles_cooldown_ticks_remaining = 0
	status = "charging"


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or str(context.get("stage_boss_variant", "")) != VARIANT_ID:
		return {}
	var step := clampf(delta, 0.0, 0.05)
	tunnel_cooldown = maxf(0.0, tunnel_cooldown - step)
	spinning_claw_cooldown = maxf(0.0, spinning_claw_cooldown - step)
	spinning_claw_timer = maxf(0.0, spinning_claw_timer - step)
	hit_emerge_timer = maxf(0.0, hit_emerge_timer - step)
	_update_spikes(step)
	_update_friend_moles_cycle(context)
	var result := _update_friend_moles(step, context, deps)
	if tunnel_active:
		result.merge(_update_tunnel(step, context, deps), true)
	elif (
		tunnel_cooldown <= 0.0
		and spinning_claw_timer <= 0.0
		and boss_special_gauge >= TUNNEL_COST
		and bool(context.get("ball_active", false))
		and not bool(context.get("waiting_for_serve", false))
	):
		_activate_tunnel(context, deps)
	status = _resolve_status()
	return result


func register_boss_hit(ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or str(context.get("stage_boss_variant", "")) != VARIANT_ID:
		return {}
	boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + GAUGE_GAIN_ON_HIT)
	hit_emerge_timer = 0.65
	var triggered := false
	if not tunnel_active and spinning_claw_cooldown <= 0.0 and boss_special_gauge >= SPINNING_CLAW_COST:
		boss_special_gauge -= SPINNING_CLAW_COST
		spinning_claw_timer = SPINNING_CLAW_DURATION_SEC
		spinning_claw_cooldown = SPINNING_CLAW_COOLDOWN_SEC
		var ball_center_x := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO).x + float(context.get("ball_size", 0.0)) * 0.5
		var boss_center_x := _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO).x + float(context.get("boss_paddle_width", 0.0)) * 0.5
		spinning_claw_direction = 1 if ball_center_x < boss_center_x else -1
		triggered = true
		_play_audio(deps, "play_stage2_molewang_spinning_claw")
	var result := {
		"boss_special_gauge": boss_special_gauge,
		"stage2_boss_gauge_gain": GAUGE_GAIN_ON_HIT,
		"molewang_spinning_claw_triggered": triggered,
	}
	if triggered:
		result["ball_vel"] = ball_vel * SPINNING_CLAW_BALL_SPEED_MULTIPLIER
		result["ball_spin_strength"] = SPINNING_CLAW_SPIN_STRENGTH
		result["ball_spin_direction"] = spinning_claw_direction
	return result


func handle_score_event(scoring_side: String, score_result: Dictionary, _deps: Dictionary = {}) -> void:
	_stop_friend_moles()
	if scoring_side == "player" and int(score_result.get("player_score", 0)) == 4 and not friend_moles_triggered:
		friend_moles_pending = true


func get_boss_ai_context(_stage_background: Object = null) -> Dictionary:
	return {
		"stage2_boss_movement_locked": false,
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
		"stage2_boss_skill_hud_boss_name": "두더지왕",
		"stage2_boss_skill_hud_speech": _get_speech(),
		"stage2_boss_skill_hud_status": status,
		"stage2_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage2_boss_skill_hud_boss_gauge_max": GAUGE_MAX,
		"stage2_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage2_boss_skill_hud_skills": [
			_build_skill("tunnel_raid", "땅굴 습격", tunnel_active, tunnel_cooldown, TUNNEL_COOLDOWN_SEC, Color(0.72, 0.43, 0.20)),
			_build_skill("spinning_claw", "회전발톱", spinning_claw_timer > 0.0, spinning_claw_cooldown, SPINNING_CLAW_COOLDOWN_SEC, Color(0.96, 0.78, 0.28)),
			_build_skill("friend_moles", "친구두더지", friend_moles_active, _get_friend_moles_hud_cooldown_sec(), float(FRIEND_MOLES_COOLDOWN_TICKS) / float(PHYSICS_TICKS_PER_SECOND), Color(0.94, 0.72, 0.16)),
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
		"molewang_tunnel_active": tunnel_active,
		"molewang_tunnel_phase": tunnel_phase,
		"molewang_tunnel_warning_active": tunnel_active and tunnel_phase == "warn",
		"molewang_tunnel_progress": _phase_progress(),
		"molewang_tunnel_target_x": tunnel_target_x,
		"molewang_tunnel_spikes": tunnel_spikes.duplicate(true),
		"molewang_spinning_claw_active": spinning_claw_timer > 0.0,
		"molewang_spinning_claw_progress": 1.0 - spinning_claw_timer / SPINNING_CLAW_DURATION_SEC if spinning_claw_timer > 0.0 else 0.0,
		"molewang_spinning_claw_direction": spinning_claw_direction,
		"molewang_hit_emerge_progress": hit_emerge_timer / 0.65,
		"molewang_friend_moles": friend_moles.duplicate(true),
		"molewang_friend_mole_particles": friend_mole_particles.duplicate(true),
	}


func get_status() -> String:
	return status


func is_speed_defense_active() -> bool:
	return false


func is_boss_status_immune() -> bool:
	return false


func get_quake_cooldown() -> float:
	return tunnel_cooldown


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


func _activate_tunnel(context: Dictionary, deps: Dictionary) -> void:
	boss_special_gauge = 0.0
	tunnel_active = true
	tunnel_phase = "warn"
	tunnel_timer = 0.0
	tunnel_spike_accumulator = 0.0
	tunnel_spikes.clear()
	tunnel_strike_applied = false
	var player_pos := _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	tunnel_target_x = player_pos.x + player_size.x * 0.5
	tunnel_cooldown = TUNNEL_COOLDOWN_SEC
	_play_audio(deps, "play_stage2_molewang_tunnel_start")


func _update_tunnel(step: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	tunnel_timer += step
	match tunnel_phase:
		"warn":
			if tunnel_timer >= TUNNEL_WARN_SEC:
				var player_pos := _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
				var player_size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
				tunnel_target_x = player_pos.x + player_size.x * 0.5
				tunnel_phase = "charge"
				tunnel_timer = 0.0
		"charge":
			tunnel_spike_accumulator += step
			while tunnel_spike_accumulator >= TUNNEL_SPIKE_INTERVAL_SEC and tunnel_spikes.size() < TUNNEL_MAX_SPIKES:
				tunnel_spike_accumulator -= TUNNEL_SPIKE_INTERVAL_SEC
				_spawn_tunnel_spike(context)
				_play_audio(deps, "play_stage2_molewang_tunnel_spike")
			if tunnel_spikes.size() >= TUNNEL_MAX_SPIKES:
				tunnel_phase = "strike"
				tunnel_timer = 0.0
		"strike":
			if not tunnel_strike_applied:
				tunnel_strike_applied = true
				_apply_tunnel_strike(context, deps)
				_play_audio(deps, "play_stage2_molewang_tunnel_impact")
			if tunnel_timer >= TUNNEL_STRIKE_SEC:
				tunnel_phase = "return"
				tunnel_timer = 0.0
		"return":
			if tunnel_timer >= TUNNEL_RETURN_SEC:
				tunnel_active = false
				tunnel_phase = "idle"
				tunnel_timer = 0.0
	return {}


func _spawn_tunnel_spike(context: Dictionary) -> void:
	var boss_pos := _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var player_pos := _as_vector2(context.get("player_pos", Vector2(302.5, 700.0)), Vector2(302.5, 700.0))
	var ratio := float(tunnel_spikes.size() + 1) / float(TUNNEL_MAX_SPIKES)
	tunnel_spikes.append({
		"pos": Vector2(lerpf(boss_pos.x + 50.0, tunnel_target_x, ratio) + rng.randf_range(-6.0, 6.0), lerpf(boss_pos.y + 40.0, player_pos.y + 25.0, ratio)),
		"height": rng.randf_range(30.0, 65.0),
		"width": rng.randf_range(5.0, 8.0),
		"age": 0.0,
		"life": 63.0 / 60.0,
	})


func _update_spikes(step: float) -> void:
	for idx in range(tunnel_spikes.size() - 1, -1, -1):
		var spike: Dictionary = tunnel_spikes[idx]
		spike["age"] = float(spike.get("age", 0.0)) + step
		if float(spike["age"]) >= float(spike.get("life", 1.0)):
			tunnel_spikes.remove_at(idx)
		else:
			tunnel_spikes[idx] = spike


func _apply_tunnel_strike(context: Dictionary, deps: Dictionary) -> void:
	var player_pos := _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size := _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center_x := player_pos.x + player_size.x * 0.5
	var distance := absf(player_center_x - tunnel_target_x)
	if distance >= 160.0:
		return
	var direction := 1.0 if player_center_x >= tunnel_target_x else -1.0
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(direction * (14.0 if distance < 100.0 else 7.0), 18.0)
	if distance < 100.0:
		var status_effect_state: Object = deps.get("status_effect_state", null)
		if status_effect_state != null and status_effect_state.has_method("apply_status"):
			status_effect_state.apply_status("player", "stun", 60.0, {"cleansable": true}, "molewang_tunnel_raid")


func _update_friend_moles_cycle(context: Dictionary) -> void:
	if not bool(context.get("ball_active", false)) or bool(context.get("waiting_for_serve", false)):
		return
	if friend_moles_cooldown_ticks_remaining > 0:
		friend_moles_cooldown_ticks_remaining -= 1
	if friend_moles_active:
		friend_moles_duration_ticks_remaining -= 1
		if friend_moles_duration_ticks_remaining <= 0:
			_stop_friend_moles()
	if not friend_moles_active and friend_moles_triggered and friend_moles_cooldown_ticks_remaining <= 0:
		_activate_friend_moles()


func _activate_friend_moles() -> void:
	friend_moles_active = true
	friend_moles_duration_ticks_remaining = FRIEND_MOLES_DURATION_TICKS
	friend_moles_cooldown_ticks_remaining = FRIEND_MOLES_COOLDOWN_TICKS
	friend_moles_spawn_timer = 0.0


func _stop_friend_moles() -> void:
	friend_moles_active = false
	friend_moles_duration_ticks_remaining = 0
	friend_moles_spawn_timer = 0.0
	friend_moles.clear()
	friend_mole_particles.clear()


func _update_friend_moles(step: float, context: Dictionary, deps: Dictionary) -> Dictionary:
	_update_friend_mole_particles(step)
	if friend_moles_active:
		friend_moles_spawn_timer += step
		while friend_moles_spawn_timer >= FRIEND_MOLE_SPAWN_SEC:
			friend_moles_spawn_timer -= FRIEND_MOLE_SPAWN_SEC
			friend_moles.append({
				"pos": Vector2(rng.randf_range(30.0, 730.0), rng.randf_range(150.0, 600.0)),
				"age": 0.0,
				"phase": "rising",
				"phase_age": 0.0,
				"golden": true,
				"hit": false,
			})
			var spawned_mole: Dictionary = friend_moles.back()
			var spawn_pos := _as_vector2(spawned_mole.get("pos", Vector2.ZERO), Vector2.ZERO)
			_spawn_friend_mole_particles(spawn_pos, 8, "dirt", Color("8b5a2b"), 1.0, 3.0, 2.0, 4.0, 15.0 / 60.0, 25.0 / 60.0, -1.0)
			_play_audio(deps, "play_stage2_friend_mole_spawn")
	var result := {}
	var ball_pos := _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_vel := _as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var ball_radius := maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	for idx in range(friend_moles.size() - 1, -1, -1):
		var mole: Dictionary = friend_moles[idx]
		mole["age"] = float(mole.get("age", 0.0)) + step
		mole["phase_age"] = float(mole.get("phase_age", 0.0)) + step
		var center := _as_vector2(mole.get("pos", Vector2.ZERO), Vector2.ZERO)
		var phase := str(mole.get("phase", "rising"))
		if phase in ["rising", "hold"] and not bool(mole.get("hit", false)) and _is_point_in_smoke(center, context, deps):
			mole["phase"] = "falling"
			mole["phase_age"] = 0.0
			_spawn_friend_mole_particles(center, 6, "smoke", Color("b4b4b4"), 1.5, 3.5, 3.0, 6.0, 12.0 / 60.0, 20.0 / 60.0, -1.0)
			friend_moles[idx] = mole
			continue
		match phase:
			"rising":
				if float(mole["phase_age"]) >= FRIEND_MOLE_RISE_SEC:
					mole["phase"] = "hold"
					mole["phase_age"] = 0.0
			"hold":
				if float(mole["phase_age"]) >= FRIEND_MOLE_HOLD_SEC:
					mole["phase"] = "falling"
					mole["phase_age"] = 0.0
				if not bool(mole.get("hit", false)) and ball_pos.distance_to(center) <= FRIEND_MOLE_RADIUS + ball_radius:
					ball_vel.y = -ball_vel.y
					ball_vel.x += rng.randf_range(-1.5, 1.5)
					mole["hit"] = true
					mole["phase"] = "falling"
					mole["phase_age"] = 0.0
					result["ball_vel"] = ball_vel
					_spawn_friend_mole_particles(center, 10, "hit", Color("ffd73c"), 2.0, 5.0, 2.0, 5.0, 15.0 / 60.0, 30.0 / 60.0, -1.5)
					_spawn_friend_mole_particles(center, 6, "star", Color("fff2a3"), 2.0, 4.0, 3.0, 5.0, 18.0 / 60.0, 28.0 / 60.0, -1.2)
					_play_audio(deps, "play_stage2_friend_mole_hit")
					_spawn_starpoint(center, deps, context)
			"falling":
				if float(mole["phase_age"]) >= FRIEND_MOLE_FALL_SEC:
					friend_moles.remove_at(idx)
					continue
		friend_moles[idx] = mole
	return result


func _update_friend_mole_particles(step: float) -> void:
	var frame_step := step * 60.0
	for idx in range(friend_mole_particles.size() - 1, -1, -1):
		var particle: Dictionary = friend_mole_particles[idx]
		particle["age"] = float(particle.get("age", 0.0)) + step
		if float(particle["age"]) >= float(particle.get("life", 0.25)):
			friend_mole_particles.remove_at(idx)
			continue
		var velocity := _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + velocity * frame_step
		velocity.y += 0.1 * frame_step
		velocity *= pow(0.95, frame_step)
		particle["vel"] = velocity
		friend_mole_particles[idx] = particle


func _spawn_friend_mole_particles(
	pos: Vector2,
	count: int,
	kind: String,
	color: Color,
	min_speed: float,
	max_speed: float,
	min_size: float,
	max_size: float,
	min_life: float,
	max_life: float,
	vertical_bias: float
) -> void:
	for _index in range(count):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(min_speed, max_speed)
		friend_mole_particles.append({
			"kind": kind,
			"pos": pos,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed + vertical_bias),
			"size": rng.randf_range(min_size, max_size),
			"age": 0.0,
			"life": rng.randf_range(min_life, max_life),
			"color": color,
		})


func _is_point_in_smoke(pos: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	for value in _get_smoke_zones(context, deps):
		if not (value is Dictionary):
			continue
		var zone: Dictionary = value
		var opacity := float(zone.get("opacity", 0.0))
		var threshold := 50.0 if opacity > 1.0 else 0.20
		if opacity <= threshold:
			continue
		var fallback_center := Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))
		var center := _as_vector2(zone.get("position", zone.get("center", zone.get("pos", fallback_center))), fallback_center)
		var radius_y := float(zone.get("radius_y", zone.get("radius", 0.0)))
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
	if runtime != null:
		if runtime.has_method("get_tear_gas_zones"):
			var runtime_zones: Variant = runtime.get_tear_gas_zones()
			if runtime_zones is Array and not runtime_zones.is_empty():
				return runtime_zones
		var throw_controller: Object = runtime.get("throw_controller")
		if throw_controller != null and throw_controller.has_method("get_tear_gas_zones"):
			var controller_zones: Variant = throw_controller.get_tear_gas_zones()
			if controller_zones is Array:
				return controller_zones
	return []


func _spawn_starpoint(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var stage_background: Object = deps.get("stage_background", null)
	if stage_background != null and stage_background.has_method("spawn_starpoint_drop"):
		stage_background.spawn_starpoint_drop(pos, "golden_mole", deps, context)


func _resolve_status() -> String:
	if tunnel_active:
		return "tunnel_%s" % tunnel_phase
	if spinning_claw_timer > 0.0:
		return "spinning_claw"
	if friend_moles_active:
		return "friend_moles"
	return "charging"


func _phase_progress() -> float:
	match tunnel_phase:
		"warn":
			return clampf(tunnel_timer / TUNNEL_WARN_SEC, 0.0, 1.0)
		"charge":
			return clampf(float(tunnel_spikes.size()) / float(TUNNEL_MAX_SPIKES), 0.0, 1.0)
		"strike":
			return clampf(tunnel_timer / TUNNEL_STRIKE_SEC, 0.0, 1.0)
		"return":
			return clampf(tunnel_timer / TUNNEL_RETURN_SEC, 0.0, 1.0)
	return 0.0


func _get_speech() -> String:
	if tunnel_active:
		return "땅굴 습격!"
	if spinning_claw_timer > 0.0:
		return "회전발톱!"
	if friend_moles_active:
		return "친구들! 도와줘!"
	return ""


func _get_friend_moles_hud_cooldown_sec() -> float:
	if friend_moles_active:
		return 0.0
	if not friend_moles_triggered:
		return float(FRIEND_MOLES_COOLDOWN_TICKS) / float(PHYSICS_TICKS_PER_SECOND)
	return float(friend_moles_cooldown_ticks_remaining) / float(PHYSICS_TICKS_PER_SECOND)


func _build_skill(id: String, label: String, active: bool, cooldown: float, total: float, color: Color) -> Dictionary:
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
		"cooldown_total": normalized_total,
		"cooldown_progress": progress,
		"status": skill_status,
		"ready": ready,
		"progress": progress,
		"color": color,
	}


func _play_audio(deps: Dictionary, method_name: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
