extends RefCounted

const Stage5HongryunFireMachinePayloadFactory := preload("res://scripts/stages/stage5/stage5_hongryun_fire_machine_payload_factory.gd")

const STAGE_ID := 5
const WIDTH := 760.0
const HEIGHT := 750.0

const MIN_COOLDOWN_FRAMES := 600.0
const MAX_COOLDOWN_FRAMES := 1200.0
const DOOR_OPEN_TIME := 60.0
const DOOR_OPEN_DELAY := 30.0
const MACHINE_RISE_TIME := 90.0
const MACHINE_RISE_DELAY := 90.0
const SPRAYING_TIME := 120.0
const SPRAYING_DELAY := 60.0
const MACHINE_LOWER_TIME := 90.0
const MACHINE_LOWER_DELAY := 30.0
const DOOR_CLOSE_TIME := 60.0
const DRAGON_EMERGE_TIME := 45.0
const DRAGON_JAW_OPEN_TIME := 30.0
const STREAM_DURATION := 60.0
const FIRE_ZONE_DURATION := 150.0
const FIRE_ZONE_WIDTH := 80.0
const FIRE_ZONE_HEIGHT := 32.0
const FIRE_ZONE_KNOCKBACK := 25.0
const FIRE_ZONE_KNOCKBACK_FRAMES := 18.0
const FIRE_ZONE_KNOCKBACK_DECAY := 0.90
const FIRE_ZONE_HIT_COOLDOWN_FRAMES := 30.0
const CANNON_LENGTH := 68.0
const DRAGON_HEAD_LENGTH := 64.0
const DRAGON_HIDE_SCALE := 0.08
const MAX_FLAMES_PER_ZONE := 30
const STREAM_PARTICLE_RENDER_LIMIT := 36
const SMOKE_RENDER_LIMIT := 90
const SPRAY_PARTICLE_RENDER_LIMIT := 36

var active := false
var phase := "idle"
var timer_frames := 0.0
var cooldown_timer := 0.0
var door_open_percent := 0.0
var machine_scale := 0.0
var machine_pos := Vector2(WIDTH * 0.5, HEIGHT * 0.5)
var play_left := 0.0
var play_right := WIDTH
var play_height := HEIGHT
var enraged_mode := false
var dragon_count := 1
var max_fire_zones := 1
var dragons: Array[Dictionary] = []
var fire_streams: Array[Dictionary] = []
var fire_zones: Array[Dictionary] = []
var spray_particles: Array[Dictionary] = []
var smoke_particles: Array[Dictionary] = []
var spray_count := 0
var player_in_fire_zone := false
var fire_zone_hit_cooldown := 0.0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	_init_dragons()
	_set_next_cooldown()


func reset() -> void:
	_clear_all_state()
	_set_next_cooldown()


func reset_round() -> void:
	reset()


func reset_for_result() -> void:
	reset()


func set_enraged_mode(enraged: bool) -> void:
	enraged_mode = enraged
	dragon_count = 2 if enraged else 1
	max_fire_zones = 2 if enraged else 1


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	var result := {}
	var fps_scale: float = clampf(delta, 0.0, 0.1) * 60.0
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID:
		if active or not fire_zones.is_empty() or not fire_streams.is_empty():
			_clear_all_state()
		return result

	_sync_geometry(context)
	_update_lingering_effects(fps_scale)
	fire_zone_hit_cooldown = max(0.0, fire_zone_hit_cooldown - fps_scale)

	if bool(context.get("waiting_for_serve", false)) or not bool(context.get("ball_active", false)):
		result.merge(_build_public_update_result(), true)
		return result

	var perf_logger: Object = deps.get("perf_logger", null)
	var sample_start: int = _perf_begin(perf_logger)
	if active:
		_update_machine(fps_scale, context, deps, result)
	elif cooldown_timer <= 0.0:
		_activate()
	else:
		cooldown_timer = max(0.0, cooldown_timer - fps_scale)
		if cooldown_timer <= 0.0:
			_activate()
	_perf_end(perf_logger, "physics.stage5.hongryun.fire_machine_event", sample_start)

	sample_start = _perf_begin(perf_logger)
	_resolve_player_fire_zone(context, deps, result)
	_perf_end(perf_logger, "physics.stage5.hongryun.fire_machine_collision", sample_start)
	result.merge(_build_public_update_result(), true)
	return result


func get_actor_draw_context() -> Dictionary:
	return {
		"stage5_hongryun_fire_machine_active": active,
		"stage5_hongryun_fire_machine_phase": phase,
		"stage5_hongryun_fire_machine_timer_frames": timer_frames,
		"stage5_hongryun_fire_machine_cooldown_frames": cooldown_timer,
		"stage5_hongryun_fire_machine_door_open_percent": door_open_percent,
		"stage5_hongryun_fire_machine_scale": machine_scale,
		"stage5_hongryun_fire_machine_pos": machine_pos,
		"stage5_hongryun_fire_machine_dragons": _get_dragon_draw_context(),
		"stage5_hongryun_fire_machine_streams": fire_streams.duplicate(true),
		"stage5_hongryun_fire_machine_zones": fire_zones.duplicate(true),
		"stage5_hongryun_fire_machine_spray_particles": _recent_duplicate(spray_particles, SPRAY_PARTICLE_RENDER_LIMIT),
		"stage5_hongryun_fire_machine_smoke_particles": _recent_duplicate(smoke_particles, SMOKE_RENDER_LIMIT),
	}


func has_actor_draw_context() -> bool:
	return active or not fire_zones.is_empty() or not fire_streams.is_empty() or not smoke_particles.is_empty()


func _get_deprecated_hud_skill_context() -> Dictionary:
	var skill_status := "casting" if active else ("ready" if cooldown_timer <= 0.0 else "charging")
	var total: float = maxf(1.0, MAX_COOLDOWN_FRAMES)
	var progress: float = 1.0 if active else clampf(1.0 - cooldown_timer / total, 0.0, 1.0)
	return {
		"id": "hongryun_fire_machine",
		"label": "화염기관",
		"status": skill_status,
		"cooldown_remaining": max(0.0, cooldown_timer / 60.0),
		"cooldown_total": total / 60.0,
		"progress": progress,
		"ready": skill_status == "ready",
		"trigger_type": "timer",
		"color": Color(0.85, 0.55, 0.20, 1.0),
	}


func is_active() -> bool:
	return active


func get_fire_zones() -> Array[Dictionary]:
	return fire_zones.duplicate(true)


func debug_force_ready() -> void:
	cooldown_timer = 0.0


func _clear_all_state() -> void:
	active = false
	phase = "idle"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	spray_count = 0
	player_in_fire_zone = false
	fire_zone_hit_cooldown = 0.0
	fire_streams.clear()
	fire_zones.clear()
	spray_particles.clear()
	smoke_particles.clear()
	_init_dragons()


func _activate() -> void:
	if active:
		return
	active = true
	phase = "door_opening"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	spray_count = 0
	_init_dragons()


func _deactivate() -> void:
	active = false
	phase = "idle"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	_set_next_cooldown()


func _set_next_cooldown() -> void:
	cooldown_timer = rng.randf_range(MIN_COOLDOWN_FRAMES, MAX_COOLDOWN_FRAMES)


func _init_dragons() -> void:
	dragons = Stage5HongryunFireMachinePayloadFactory.build_dragons(2)


func _sync_geometry(context: Dictionary) -> void:
	var width: float = maxf(1.0, float(context.get("width", WIDTH)))
	play_left = float(context.get("play_left", 0.0))
	play_right = float(context.get("play_right", width))
	play_height = maxf(1.0, float(context.get("height", HEIGHT)))
	machine_pos = Vector2((play_left + play_right) * 0.5, play_height * 0.5)


func _update_machine(fps_scale: float, context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	var phase_started := timer_frames <= 0.0
	timer_frames += fps_scale
	match phase:
		"door_opening":
			if phase_started:
				_play_door_sound(deps)
			door_open_percent = _ease_out_cubic(min(1.0, timer_frames / DOOR_OPEN_TIME))
			if timer_frames >= DOOR_OPEN_TIME:
				_set_phase("door_open_wait")
		"door_open_wait":
			if timer_frames >= DOOR_OPEN_DELAY:
				_set_phase("machine_rising")
		"machine_rising":
			if phase_started:
				_play_machine_sound(deps)
			machine_scale = _ease_out_cubic(min(1.0, timer_frames / MACHINE_RISE_TIME))
			if timer_frames >= MACHINE_RISE_TIME:
				_set_phase("machine_rise_wait")
		"machine_rise_wait":
			if timer_frames >= MACHINE_RISE_DELAY:
				_set_phase("spraying")
				_lock_dragon_targets(context)
		"spraying":
			_update_dragons_for_spraying(deps, result)
			if timer_frames >= SPRAYING_TIME:
				_set_phase("spraying_wait")
		"spraying_wait":
			_update_dragon_jaw_close(fps_scale)
			if timer_frames >= SPRAYING_DELAY:
				_set_phase("machine_lowering")
		"machine_lowering":
			if phase_started:
				_play_machine_sound(deps)
			var lower_progress: float = minf(1.0, timer_frames / MACHINE_LOWER_TIME)
			machine_scale = 1.0 - _ease_in_cubic(lower_progress)
			for index in range(dragon_count):
				var dragon: Dictionary = dragons[index]
				dragon["cannon_emergence"] = 1.0 - _ease_in_cubic(lower_progress)
				dragon["cannon_current_length"] = CANNON_LENGTH * float(dragon.get("cannon_emergence", 0.0))
				dragons[index] = dragon
			if timer_frames >= MACHINE_LOWER_TIME:
				_set_phase("machine_lower_wait")
		"machine_lower_wait":
			if timer_frames >= MACHINE_LOWER_DELAY:
				_set_phase("door_closing")
		"door_closing":
			if phase_started:
				_play_door_sound(deps)
			door_open_percent = 1.0 - _ease_in_cubic(min(1.0, timer_frames / DOOR_CLOSE_TIME))
			if timer_frames >= DOOR_CLOSE_TIME:
				_deactivate()


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	timer_frames = 0.0


func _lock_dragon_targets(context: Dictionary) -> void:
	var floor_y: float = maxf(80.0, play_height - 50.0)
	for index in range(dragon_count):
		var dragon: Dictionary = dragons[index]
		var target_x: float
		if dragon_count >= 2:
			var mid: float = (play_left + play_right) * 0.5
			target_x = rng.randf_range(play_left + 50.0, mid - 30.0) if index == 0 else rng.randf_range(mid + 30.0, play_right - 50.0)
		else:
			target_x = rng.randf_range(play_left + 50.0, play_right - 50.0)
		if bool(context.get("stage5_hongryun_inferno_active", false)):
			var player_rect := _get_player_rect(context)
			target_x = clampf(player_rect.get_center().x + rng.randf_range(-90.0, 90.0), play_left + 50.0, play_right - 50.0)
		var target := Vector2(target_x, floor_y)
		var base_angle := (target - machine_pos).angle()
		dragon["aim_target"] = target
		dragon["cannon_angle"] = base_angle + float(dragon.get("base_angle_offset", 0.0))
		dragon["target_cannon_angle"] = base_angle
		dragon["is_aiming"] = false
		dragon["fired"] = false
		dragons[index] = dragon


func _update_dragons_for_spraying(deps: Dictionary, result: Dictionary) -> void:
	for index in range(dragon_count):
		var dragon: Dictionary = dragons[index]
		if timer_frames < DRAGON_EMERGE_TIME:
			var emergence := _ease_out_cubic(timer_frames / DRAGON_EMERGE_TIME)
			dragon["cannon_emergence"] = emergence
			dragon["cannon_current_length"] = CANNON_LENGTH * emergence
			dragon["jaw_phase"] = "closed"
			dragon["jaw_open"] = 0.0
		elif timer_frames < DRAGON_EMERGE_TIME + DRAGON_JAW_OPEN_TIME:
			dragon["cannon_emergence"] = 1.0
			dragon["cannon_current_length"] = CANNON_LENGTH
			var jaw_progress := (timer_frames - DRAGON_EMERGE_TIME) / DRAGON_JAW_OPEN_TIME
			dragon["jaw_open"] = _ease_out_cubic(min(1.0, jaw_progress))
			dragon["jaw_phase"] = "open" if jaw_progress >= 1.0 else "opening"
		else:
			dragon["cannon_emergence"] = 1.0
			dragon["cannon_current_length"] = CANNON_LENGTH
			dragon["jaw_phase"] = "breathing"
			dragon["jaw_open"] = 1.0 + 0.1 * sin(timer_frames * 0.20 + float(index) * 0.5)
			_spray_fire_dragon(index, dragon, deps, result)
		dragons[index] = dragon


func _update_dragon_jaw_close(_fps_scale: float) -> void:
	for index in range(dragon_count):
		var dragon: Dictionary = dragons[index]
		if timer_frames < 30.0:
			dragon["jaw_open"] = max(0.0, 1.0 - _ease_in_cubic(timer_frames / 30.0))
			dragon["jaw_phase"] = "closing"
		else:
			dragon["jaw_open"] = 0.0
			dragon["jaw_phase"] = "closed"
		dragons[index] = dragon


func _spray_fire_dragon(index: int, dragon: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if bool(dragon.get("fired", false)) or spray_count >= max_fire_zones:
		return
	if not bool(dragon.get("is_aiming", false)):
		dragon["is_aiming"] = true

	var angle: float = float(dragon.get("cannon_angle", 0.0))
	var target_angle: float = float(dragon.get("target_cannon_angle", angle))
	var angle_diff := wrapf(target_angle - angle, -PI, PI)
	angle += angle_diff * 0.15
	dragon["cannon_angle"] = angle
	if abs(angle_diff) >= 0.10 or float(dragon.get("jaw_open", 0.0)) < 0.8:
		dragons[index] = dragon
		return

	var mouth_pos := _get_dragon_mouth_position(dragon)
	var target := _get_vector2(dragon, "aim_target", machine_pos + Vector2.DOWN * 220.0)
	fire_streams.append(Stage5HongryunFireMachinePayloadFactory.build_fire_stream(
		mouth_pos,
		target,
		angle,
		STREAM_DURATION
	))
	spray_count += 1
	dragon["is_aiming"] = false
	dragon["fired"] = true
	dragons[index] = dragon
	result["stage5_hongryun_fire_machine_breath_fired"] = true
	result["stage5_hongryun_fire_machine_breath_count"] = int(result.get("stage5_hongryun_fire_machine_breath_count", 0)) + 1
	_play_fire_sound(deps)


func _update_lingering_effects(fps_scale: float) -> void:
	_update_fire_streams(fps_scale)
	_update_fire_zones(fps_scale)
	_update_spray_particles(fps_scale)
	_update_smoke_particles(fps_scale)


func _update_fire_streams(fps_scale: float) -> void:
	for index in range(fire_streams.size() - 1, -1, -1):
		var stream: Dictionary = fire_streams[index]
		stream["timer"] = float(stream.get("timer", 0.0)) + fps_scale
		var duration: float = max(1.0, float(stream.get("duration", STREAM_DURATION)))
		var progress: float = clampf(float(stream.get("timer", 0.0)) / duration, 0.0, 1.0)
		var particles: Array = _get_array(stream.get("particles", []))
		if progress < 1.0 and not bool(stream.get("completed", false)):
			var start: Vector2 = _get_vector2(stream, "start", machine_pos)
			var target: Vector2 = _get_vector2(stream, "target", machine_pos)
			var stream_pos := start.lerp(target, progress)
			for _i in range(3):
				particles.append(Stage5HongryunFireMachinePayloadFactory.build_stream_particle(stream_pos, rng))
		elif not bool(stream.get("completed", false)):
			stream["completed"] = true
			_create_fire_zone(_get_vector2(stream, "target", machine_pos))

		var write_index := 0
		for particle_index in range(particles.size()):
			var particle: Dictionary = particles[particle_index]
			var pos: Vector2 = _get_vector2(particle, "pos", Vector2.ZERO)
			var vel: Vector2 = _get_vector2(particle, "vel", Vector2.ZERO)
			pos += vel * fps_scale
			particle["pos"] = pos
			particle["life"] = float(particle.get("life", 0.0)) - fps_scale
			particle["size"] = max(0.0, float(particle.get("size", 0.0)) * pow(0.96, fps_scale))
			if float(particle.get("life", 0.0)) > 0.0 and float(particle.get("size", 0.0)) > 0.75:
				particles[write_index] = particle
				write_index += 1
		particles.resize(write_index)
		stream["particles"] = particles
		if bool(stream.get("completed", false)) and particles.is_empty():
			fire_streams.remove_at(index)
		else:
			fire_streams[index] = stream


func _create_fire_zone(pos: Vector2) -> void:
	fire_zones.append(Stage5HongryunFireMachinePayloadFactory.build_fire_zone(
		pos,
		FIRE_ZONE_WIDTH,
		FIRE_ZONE_HEIGHT,
		FIRE_ZONE_DURATION,
		15,
		rng
	))


func _update_fire_zones(fps_scale: float) -> void:
	for index in range(fire_zones.size() - 1, -1, -1):
		var zone: Dictionary = fire_zones[index]
		zone["duration"] = float(zone.get("duration", 0.0)) - fps_scale
		zone["spread_timer"] = float(zone.get("spread_timer", 0.0)) + fps_scale
		var pos: Vector2 = _get_vector2(zone, "pos", Vector2.ZERO)
		var width: float = float(zone.get("width", FIRE_ZONE_WIDTH))
		var height: float = float(zone.get("height", FIRE_ZONE_HEIGHT))
		var flames: Array = _get_array(zone.get("flames", []))
		if int(zone.get("spread_timer", 0.0)) % 5 == 0 and flames.size() < MAX_FLAMES_PER_ZONE:
			for _i in range(3):
				flames.append(Stage5HongryunFireMachinePayloadFactory.build_flame(pos, width, height, false, rng))
		var write_index := 0
		for flame_index in range(flames.size()):
			var flame: Dictionary = flames[flame_index]
			var flame_pos: Vector2 = _get_vector2(flame, "pos", pos)
			flame_pos += Vector2(rng.randf_range(-1.0, 1.0), -rng.randf_range(0.5, 1.5)) * fps_scale
			flame["pos"] = flame_pos
			flame["life"] = float(flame.get("life", 0.0)) - fps_scale
			flame["size"] = max(0.0, float(flame.get("size", 0.0)) * pow(0.98, fps_scale))
			flame["color_phase"] = fposmod(float(flame.get("color_phase", 0.0)) + 0.05 * fps_scale, 1.0)
			if float(flame.get("life", 0.0)) > 0.0 and float(flame.get("size", 0.0)) > 1.4:
				flames[write_index] = flame
				write_index += 1
		flames.resize(write_index)
		zone["flames"] = flames
		if float(zone.get("duration", 0.0)) <= 0.0:
			fire_zones.remove_at(index)
		else:
			fire_zones[index] = zone


func _update_spray_particles(fps_scale: float) -> void:
	var write_index := 0
	for index in range(spray_particles.size()):
		var particle: Dictionary = spray_particles[index]
		var pos: Vector2 = _get_vector2(particle, "pos", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle, "vel", Vector2.ZERO)
		pos += vel * fps_scale
		particle["pos"] = pos
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["size"] = max(0.0, float(particle.get("size", 0.0)) * pow(0.95, fps_scale))
		if float(particle.get("life", 0.0)) > 0.0 and float(particle.get("size", 0.0)) > 0.75:
			spray_particles[write_index] = particle
			write_index += 1
	spray_particles.resize(write_index)


func _update_smoke_particles(fps_scale: float) -> void:
	var write_index := 0
	for index in range(smoke_particles.size()):
		var particle: Dictionary = smoke_particles[index]
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		var max_life: float = max(1.0, float(particle.get("max_life", 90.0)))
		var progress := 1.0 - clampf(life / max_life, 0.0, 1.0)
		var pos: Vector2 = _get_vector2(particle, "pos", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(particle, "vel", Vector2.ZERO)
		var wobble_phase := float(particle.get("wobble_phase", 0.0)) + float(particle.get("wobble_freq", 0.05)) * fps_scale
		var wobble := sin(wobble_phase) * float(particle.get("wobble_amp", 0.6))
		pos += (vel + Vector2(wobble * 0.4, 0.0)) * fps_scale
		vel.x *= pow(0.97, fps_scale)
		vel.y *= pow(0.985, fps_scale)
		var size: float = float(particle.get("size", 8.0))
		var max_size: float = float(particle.get("max_size", 36.0))
		size += (max_size - size) * 0.045 * fps_scale
		var alpha := 0.0
		if progress < 0.12:
			alpha = 0.70 * (progress / 0.12)
		else:
			alpha = 0.70 * pow(max(0.0, 1.0 - (progress - 0.12) / 0.88), 1.6)
		particle["pos"] = pos
		particle["vel"] = vel
		particle["life"] = life
		particle["size"] = size
		particle["alpha"] = alpha
		particle["wobble_phase"] = wobble_phase
		particle["warmth"] = float(particle.get("warmth", 0.0)) * pow(0.965, fps_scale)
		if life > 0.0 and alpha > 0.02:
			smoke_particles[write_index] = particle
			write_index += 1
	smoke_particles.resize(write_index)


func _create_smoke_effect(center: Vector2, width: float, height: float) -> void:
	smoke_particles.append_array(Stage5HongryunFireMachinePayloadFactory.build_smoke_particles(
		center,
		width,
		height,
		rng.randi_range(22, 34),
		rng
	))


func _resolve_player_fire_zone(context: Dictionary, deps: Dictionary, result: Dictionary) -> void:
	if fire_zones.is_empty():
		player_in_fire_zone = false
		return
	var player_rect := _get_player_rect(context)
	var player_touching := false
	var dash_snapshot: Dictionary = _get_dictionary(context.get("dash_snapshot", {}))
	var player_dashing := bool(dash_snapshot.get("active", false))
	var immune := _is_boss_skill_immune(context, deps)
	for index in range(fire_zones.size() - 1, -1, -1):
		var zone: Dictionary = fire_zones[index]
		var zone_rect := _get_fire_zone_rect(zone)
		if not player_rect.intersects(zone_rect):
			continue
		player_touching = true
		if player_dashing:
			_create_smoke_effect(_get_vector2(zone, "pos", Vector2.ZERO), float(zone.get("width", FIRE_ZONE_WIDTH)), float(zone.get("height", FIRE_ZONE_HEIGHT)))
			fire_zones.remove_at(index)
			result["stage5_hongryun_fire_machine_zone_extinguished"] = true
			continue
		if immune:
			result["stage5_hongryun_fire_machine_zone_parried"] = true
			_trigger_boss_skill_parry(zone_rect.get_center(), deps)
			continue
		if not player_in_fire_zone or fire_zone_hit_cooldown <= 0.0:
			var zone_center := zone_rect.get_center()
			var push_direction := 1.0 if player_rect.get_center().x >= zone_center.x else -1.0
			if abs(player_rect.get_center().x - zone_center.x) < 5.0:
				push_direction = -1.0 if rng.randf() < 0.5 else 1.0
			_apply_fire_zone_knockback(push_direction, deps, result)
			fire_zone_hit_cooldown = FIRE_ZONE_HIT_COOLDOWN_FRAMES
			result["stage5_hongryun_fire_machine_zone_hit_player"] = true
	player_in_fire_zone = player_touching


func _apply_fire_zone_knockback(push_direction: float, deps: Dictionary, result: Dictionary) -> void:
	var movement_state: Object = deps.get("movement_state", null)
	var velocity := push_direction * FIRE_ZONE_KNOCKBACK
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(
			velocity,
			FIRE_ZONE_KNOCKBACK_FRAMES,
			FIRE_ZONE_KNOCKBACK_DECAY,
			true,
			true
		)
	result["stage5_hongryun_fire_machine_knockback_vel"] = velocity


func _get_dragon_draw_context() -> Array:
	var result: Array = []
	for index in range(dragon_count):
		var dragon: Dictionary = dragons[index]
		var mouth_pos := _get_dragon_mouth_position(dragon)
		result.append({
			"cannon_angle": float(dragon.get("cannon_angle", 0.0)),
			"target_cannon_angle": float(dragon.get("target_cannon_angle", 0.0)),
			"cannon_emergence": float(dragon.get("cannon_emergence", 0.0)),
			"cannon_current_length": float(dragon.get("cannon_current_length", 0.0)),
			"jaw_open": float(dragon.get("jaw_open", 0.0)),
			"jaw_phase": str(dragon.get("jaw_phase", "closed")),
			"fired": bool(dragon.get("fired", false)),
			"is_aiming": bool(dragon.get("is_aiming", false)),
			"aim_target": _get_vector2(dragon, "aim_target", Vector2.ZERO),
			"mouth_pos": mouth_pos,
			"head_pos": _get_dragon_head_position(dragon),
		})
	return result


func _get_dragon_head_position(dragon: Dictionary) -> Vector2:
	var angle := float(dragon.get("cannon_angle", 0.0))
	var emergence := float(dragon.get("cannon_emergence", 0.0))
	var length := float(dragon.get("cannon_current_length", 0.0)) * machine_scale * 1.5
	return machine_pos + Vector2(cos(angle), sin(angle)) * (length * 0.70 + DRAGON_HEAD_LENGTH * machine_scale * max(DRAGON_HIDE_SCALE, emergence) * 0.24)


func _get_dragon_mouth_position(dragon: Dictionary) -> Vector2:
	var angle := float(dragon.get("cannon_angle", 0.0))
	var emergence := float(dragon.get("cannon_emergence", 0.0))
	var length := float(dragon.get("cannon_current_length", 0.0)) * machine_scale * 1.5
	var head_length: float = DRAGON_HEAD_LENGTH * machine_scale * max(DRAGON_HIDE_SCALE, emergence)
	return machine_pos + Vector2(cos(angle), sin(angle)) * (length * 0.70 + head_length)


func _get_fire_zone_rect(zone: Dictionary) -> Rect2:
	var pos := _get_vector2(zone, "pos", Vector2.ZERO)
	return Rect2(
		pos - Vector2(float(zone.get("width", FIRE_ZONE_WIDTH)), float(zone.get("height", FIRE_ZONE_HEIGHT))) * 0.5,
		Vector2(float(zone.get("width", FIRE_ZONE_WIDTH)), float(zone.get("height", FIRE_ZONE_HEIGHT)))
	)


func _build_public_update_result() -> Dictionary:
	return {
		"stage5_hongryun_fire_machine_active": active,
		"stage5_hongryun_fire_machine_phase": phase,
		"stage5_hongryun_fire_machine_fire_zone_count": fire_zones.size(),
		"stage5_hongryun_fire_machine_stream_count": fire_streams.size(),
	}


func _play_door_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_door"):
		audio.play_stage1_balloon_door()


func _play_machine_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_machine"):
		audio.play_stage1_balloon_machine()


func _play_fire_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage5_hongryun_fireball"):
		audio.play_stage5_hongryun_fireball()


func _is_boss_skill_immune(context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("boss_skill_immune", false)) or bool(context.get("active_item_boss_skill_immune", false)):
		return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime == null:
		return false
	for method_name in [
		"is_boss_skill_immune",
		"is_player_boss_skill_immune",
		"is_magic_anti_active",
	]:
		if active_item_runtime.has_method(method_name) and bool(active_item_runtime.call(method_name)):
			return true
	return false


func _trigger_boss_skill_parry(pos: Vector2, deps: Dictionary) -> void:
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("trigger_magic_anti_potion_parry"):
		active_item_runtime.trigger_magic_anti_potion_parry("fire_zone", pos, "stage5_fire_machine_zone")


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2(302.5, 690.0))
	var player_size: Vector2 = _get_vector2(
		context,
		"player_paddle_size",
		Vector2(float(context.get("player_paddle_width", 155.0)), float(context.get("player_paddle_height", 50.0)))
	)
	return Rect2(player_pos, player_size)


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


func _ease_in_cubic(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return clamped * clamped * clamped


func _recent_duplicate(source: Array, limit: int) -> Array:
	if limit <= 0 or source.size() <= limit:
		return source.duplicate(true)
	return source.slice(source.size() - limit).duplicate(true)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
