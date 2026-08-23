extends RefCounted

const PlayerKnockbackImmunity := preload("res://scripts/stages/common/player_knockback_immunity.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")

const STAGE_ID := 3
const VARIANT_ID := "alice"
const WIDTH := 760.0
const HEIGHT := 750.0
const LEGACY_FPS := 60.0
const DEFAULT_BALL_SIZE := 28.6
const GAUGE_MAX := 500.0
const GAUGE_GAIN_ON_HIT := 50.0

const MIRROR_COST := 500.0
const MIRROR_DURATION_SEC := 180.0 / LEGACY_FPS
const MIRROR_COOLDOWN_SEC := 900.0 / LEGACY_FPS
const MIRROR_INITIAL_COOLDOWN_SEC := MIRROR_COOLDOWN_SEC
const MIRROR_FADE_SEC := 30.0 / LEGACY_FPS

const SIZE_SHIFT_COST := 70.0
const SIZE_SHIFT_CHANCE := 0.12
const SIZE_SHIFT_DURATION_SEC := 240.0 / LEGACY_FPS
const SIZE_SHIFT_COOLDOWN_SEC := 600.0 / LEGACY_FPS
const SIZE_SHIFT_INITIAL_COOLDOWN_SEC := SIZE_SHIFT_COOLDOWN_SEC

const RABBIT_COST := 120.0
const RABBIT_CHANCE := 0.13
const RABBIT_COOLDOWN_SEC := 480.0 / LEGACY_FPS
const RABBIT_INITIAL_COOLDOWN_SEC := RABBIT_COOLDOWN_SEC
const RABBIT_WINDUP_SEC := 30.0 / LEGACY_FPS
const RABBIT_COUNT_MIN := 3
const RABBIT_COUNT_MAX := 4
const RABBIT_BASE_SPEED := 3.5
const RABBIT_HIT_RADIUS := 20.0
const RABBIT_LIFETIME_SEC := 300.0 / LEGACY_FPS
const RABBIT_PERCH_DURATION_SEC := 120.0 / LEGACY_FPS
const RABBIT_HOMING_PER_FRAME := 0.02

var rng := RandomNumberGenerator.new()
var boss_special_gauge := 0.0
var hit_timer := 0.0
var status := "charging"

var mirror_active := false
var mirror_timer := 0.0
var mirror_cooldown := 0.0
var mirror_elapsed := 0.0

var size_shift_active := false
var size_shift_timer := 0.0
var size_shift_cooldown := 0.0
var size_shift_scale := 1.0
var size_shift_pity_failures := 0
var original_ball_size := DEFAULT_BALL_SIZE

var rabbit_active := false
var rabbit_windup := 0.0
var rabbit_cooldown := 0.0
var rabbit_pity_failures := 0
var rabbit_projectiles: Array = []
var perched_rabbits: Array = []
var rabbit_burst_particles: Array = []


func _init() -> void:
	rng.seed = 33043


func reset() -> void:
	boss_special_gauge = 0.0
	size_shift_pity_failures = 0
	rabbit_pity_failures = 0
	_reset_round_effects()
	mirror_cooldown = MIRROR_INITIAL_COOLDOWN_SEC
	size_shift_cooldown = SIZE_SHIFT_INITIAL_COOLDOWN_SEC
	rabbit_cooldown = RABBIT_INITIAL_COOLDOWN_SEC


func reset_round(deps: Dictionary = {}) -> void:
	_reset_round_effects(deps)


func _reset_round_effects(deps: Dictionary = {}) -> void:
	hit_timer = 0.0
	status = "charging"
	mirror_active = false
	mirror_timer = 0.0
	mirror_cooldown = 0.0
	mirror_elapsed = 0.0
	size_shift_active = false
	size_shift_timer = 0.0
	size_shift_cooldown = 0.0
	size_shift_scale = 1.0
	rabbit_active = false
	rabbit_windup = 0.0
	rabbit_cooldown = 0.0
	rabbit_projectiles.clear()
	perched_rabbits.clear()
	rabbit_burst_particles.clear()
	var owner: Object = deps.get("owner", null)
	if owner != null:
		owner.set("ball_size", maxf(4.0, original_ball_size))
		owner.set("stage3_alice_mirror_active", false)
		owner.set("stage3_alice_mirror_ratio", 0.0)
	original_ball_size = DEFAULT_BALL_SIZE


func update(delta: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _is_alice_context(context):
		return {}
	var step := clampf(delta, 0.0, 0.05)
	hit_timer = maxf(0.0, hit_timer - step)
	if not _is_cooldown_paused(context):
		mirror_cooldown = maxf(0.0, mirror_cooldown - step)
		size_shift_cooldown = maxf(0.0, size_shift_cooldown - step)
		rabbit_cooldown = maxf(0.0, rabbit_cooldown - step)
	_update_mirror(step)
	_update_size_shift(step)
	_update_rabbits(step, context, deps)
	_update_burst_particles(step)
	status = _resolve_status()
	return {
		"ball_size": _get_effective_ball_size(),
		"stage3_alice_mirror_active": mirror_active,
		"stage3_alice_mirror_ratio": _get_mirror_fade_ratio(),
	}


func register_boss_hit(_ball_vel: Vector2, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if not _is_alice_context(context):
		return {}
	boss_special_gauge = minf(GAUGE_MAX, boss_special_gauge + GAUGE_GAIN_ON_HIT)
	hit_timer = 0.35
	var mirror_triggered := false
	var size_triggered := false
	var rabbit_triggered := false
	# Legacy order is significant: a full-gauge mirror consumes everything and
	# makes the same-contact size check ineligible.
	if not mirror_active and mirror_cooldown <= 0.0 and boss_special_gauge >= MIRROR_COST:
		_activate_mirror(deps)
		boss_special_gauge = 0.0
		mirror_triggered = true
	if (
		boss_special_gauge >= SIZE_SHIFT_COST
		and not size_shift_active
		and size_shift_cooldown <= 0.0
		and not mirror_active
	):
		var effective_chance := minf(
			1.0,
			SIZE_SHIFT_CHANCE * (1.0 + float(size_shift_pity_failures))
		)
		if rng.randf() <= effective_chance:
			_activate_size_shift(context, deps)
			boss_special_gauge = maxf(0.0, boss_special_gauge - SIZE_SHIFT_COST)
			size_shift_pity_failures = 0
			size_triggered = true
		else:
			size_shift_pity_failures += 1
	if (
		boss_special_gauge >= RABBIT_COST
		and not rabbit_active
		and rabbit_windup <= 0.0
		and rabbit_cooldown <= 0.0
	):
		var effective_chance := minf(
			1.0,
			RABBIT_CHANCE * (1.0 + float(rabbit_pity_failures))
		)
		if rng.randf() <= effective_chance:
			_activate_rabbits()
			boss_special_gauge = maxf(0.0, boss_special_gauge - RABBIT_COST)
			rabbit_pity_failures = 0
			rabbit_triggered = true
		else:
			rabbit_pity_failures += 1
	status = _resolve_status()
	return {
		"stage3_boss_gauge": boss_special_gauge,
		"stage3_boss_gauge_gain": GAUGE_GAIN_ON_HIT,
		"alice_mirror_triggered": mirror_triggered,
		"alice_size_shift_triggered": size_triggered,
		"alice_rabbit_triggered": rabbit_triggered,
		"ball_size": _get_effective_ball_size(),
		"stage3_alice_mirror_active": mirror_active,
		"stage3_alice_mirror_ratio": _get_mirror_fade_ratio(),
	}


func handle_score_event(_scoring_side: String, _score_result: Dictionary, _deps: Dictionary = {}) -> void:
	pass


func _activate_mirror(deps: Dictionary) -> void:
	mirror_active = true
	mirror_timer = MIRROR_DURATION_SEC
	mirror_elapsed = 0.0
	mirror_cooldown = MIRROR_COOLDOWN_SEC
	# clue.wav is absent from the Godot asset set; dollcurse is the existing
	# Stage 3 magical one-shot used as the explicit port fallback.
	_play_audio(deps, "play_stage3_dollcurse")


func _update_mirror(step: float) -> void:
	if not mirror_active:
		return
	mirror_elapsed += step
	mirror_timer = maxf(0.0, mirror_timer - step)
	if mirror_timer <= 0.0:
		mirror_active = false
		mirror_elapsed = 0.0


func _activate_size_shift(context: Dictionary, deps: Dictionary, forced_scale: float = 0.0) -> void:
	size_shift_active = true
	size_shift_timer = SIZE_SHIFT_DURATION_SEC
	size_shift_cooldown = SIZE_SHIFT_COOLDOWN_SEC
	original_ball_size = maxf(4.0, float(context.get("ball_size", DEFAULT_BALL_SIZE)))
	size_shift_scale = forced_scale if forced_scale > 0.0 else (2.0 if rng.randf() < 0.5 else 0.5)
	_play_audio(deps, "play_lingpet_gravity_accel_cast")


func _update_size_shift(step: float) -> void:
	if not size_shift_active:
		return
	size_shift_timer = maxf(0.0, size_shift_timer - step)
	if size_shift_timer <= 0.0:
		size_shift_active = false
		size_shift_scale = 1.0


func _get_effective_ball_size() -> float:
	if size_shift_active:
		return maxf(4.0, original_ball_size * size_shift_scale)
	return maxf(4.0, original_ball_size)


func _activate_rabbits() -> void:
	rabbit_windup = RABBIT_WINDUP_SEC
	rabbit_cooldown = RABBIT_COOLDOWN_SEC
	rabbit_active = true


func _launch_rabbits(context: Dictionary, deps: Dictionary) -> void:
	rabbit_projectiles.clear()
	var start := _get_boss_bottom_center(context)
	var target := _get_player_center(context)
	var distance := maxf(1.0, start.distance_to(target))
	var base_angle := start.angle_to_point(target)
	for _index in range(rng.randi_range(RABBIT_COUNT_MIN, RABBIT_COUNT_MAX)):
		var angle := base_angle + deg_to_rad(rng.randf_range(-18.0, 18.0))
		var flight_frames := rng.randf_range(120.0, 180.0)
		var speed := maxf(distance / flight_frames, RABBIT_BASE_SPEED * 0.8)
		rabbit_projectiles.append({
			"pos": start + Vector2(rng.randf_range(-15.0, 15.0), 0.0),
			"vel": Vector2.from_angle(angle) * speed,
			"remaining": RABBIT_LIFETIME_SEC,
			"hop_phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(16.0, 22.0),
			"ear_angle": rng.randf_range(-0.2, 0.2),
			"target": target + Vector2(rng.randf_range(-30.0, 30.0), 0.0),
		})
	_play_audio(deps, "play_lingpet_dwarf_magic_cast")


func _update_rabbits(step: float, context: Dictionary, deps: Dictionary) -> void:
	if rabbit_windup > 0.0:
		rabbit_windup = maxf(0.0, rabbit_windup - step)
		if rabbit_windup <= 0.0:
			_launch_rabbits(context, deps)
		return
	var player_center := _get_player_center(context)
	var player_radius := _get_player_size(context).x * 0.5
	for index in range(rabbit_projectiles.size() - 1, -1, -1):
		var rabbit: Dictionary = rabbit_projectiles[index]
		rabbit["remaining"] = float(rabbit.get("remaining", 0.0)) - step
		rabbit["hop_phase"] = float(rabbit.get("hop_phase", 0.0)) + 0.15 * step * LEGACY_FPS
		var pos := _as_vector2(rabbit.get("pos", Vector2.ZERO), Vector2.ZERO)
		var vel := _as_vector2(rabbit.get("vel", Vector2.ZERO), Vector2.ZERO)
		if _is_point_in_smoke(pos, context, deps):
			rabbit_projectiles.remove_at(index)
			continue
		if pos.y < player_center.y:
			var target := _as_vector2(rabbit.get("target", player_center), player_center)
			var direction := pos.direction_to(target)
			vel += direction * RABBIT_HOMING_PER_FRAME * step * LEGACY_FPS
		var hop_offset := absf(sin(float(rabbit["hop_phase"]))) * 8.0
		pos += (vel - Vector2(0.0, hop_offset * 0.1)) * step * LEGACY_FPS
		rabbit["pos"] = pos
		rabbit["vel"] = vel
		var expired := (
			float(rabbit["remaining"]) <= 0.0
			or pos.x < -30.0
			or pos.x > WIDTH + 30.0
			or pos.y < -30.0
			or pos.y > HEIGHT + 60.0
		)
		if expired:
			rabbit_projectiles.remove_at(index)
		elif pos.distance_to(player_center) < RABBIT_HIT_RADIUS + player_radius:
			perched_rabbits.append({
				"offset_x": pos.x - player_center.x,
				"remaining": RABBIT_PERCH_DURATION_SEC,
				"knockback_clock": 30.0 / LEGACY_FPS,
				"hop_phase": rabbit["hop_phase"],
				"taunt_phase": 0.0,
				"size": rabbit["size"],
				"direction": -1 if rng.randi_range(0, 1) == 0 else 1,
			})
			rabbit_projectiles.remove_at(index)
			_play_audio(deps, "play_lingpet_dwarf_magic_hit")
		else:
			rabbit_projectiles[index] = rabbit
	_update_perched_rabbits(step, context, deps)
	rabbit_active = rabbit_windup > 0.0 or not rabbit_projectiles.is_empty() or not perched_rabbits.is_empty()


func _update_perched_rabbits(step: float, context: Dictionary, deps: Dictionary) -> void:
	var player_center := _get_player_center(context)
	var player_size := _get_player_size(context)
	var dash_snapshot: Dictionary = context.get("dash_snapshot", {})
	var dash_active := bool(dash_snapshot.get("active", false))
	for index in range(perched_rabbits.size() - 1, -1, -1):
		var rabbit: Dictionary = perched_rabbits[index]
		var size := float(rabbit.get("size", 18.0))
		var pos := Vector2(player_center.x + float(rabbit.get("offset_x", 0.0)), player_center.y - player_size.y * 0.5 - size)
		if _is_point_in_smoke(pos, context, deps) or dash_active:
			if dash_active:
				_spawn_rabbit_burst(pos)
				_play_audio(deps, "play_lingpet_dwarf_magic_hit")
			perched_rabbits.remove_at(index)
			continue
		rabbit["remaining"] = float(rabbit.get("remaining", 0.0)) - step
		rabbit["hop_phase"] = float(rabbit.get("hop_phase", 0.0)) + 0.25 * step * LEGACY_FPS
		rabbit["taunt_phase"] = float(rabbit.get("taunt_phase", 0.0)) + 0.10 * step * LEGACY_FPS
		rabbit["offset_x"] = float(rabbit.get("offset_x", 0.0)) + int(rabbit.get("direction", 1)) * 1.5 * step * LEGACY_FPS
		var half_width := maxf(0.0, player_size.x * 0.5 - 5.0)
		if float(rabbit["offset_x"]) > half_width:
			rabbit["offset_x"] = half_width
			rabbit["direction"] = -1
		elif float(rabbit["offset_x"]) < -half_width:
			rabbit["offset_x"] = -half_width
			rabbit["direction"] = 1
		rabbit["knockback_clock"] = float(rabbit.get("knockback_clock", 0.0)) - step
		if float(rabbit["knockback_clock"]) <= 0.0:
			rabbit["knockback_clock"] += 30.0 / LEGACY_FPS
			_apply_rabbit_knockback(int(rabbit.get("direction", 1)), context, deps)
		if float(rabbit["remaining"]) <= 0.0:
			perched_rabbits.remove_at(index)
		else:
			perched_rabbits[index] = rabbit


func _apply_rabbit_knockback(direction: int, context: Dictionary, deps: Dictionary) -> void:
	if (
		PlayerKnockbackImmunity.is_cleanse_immune(deps, context)
		or PlayerKnockbackImmunity.try_block_player_knockback(deps, context, "alice_rabbit")
	):
		return
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(float(direction) * 8.0, 18.0, 0.86, false, true)


func _spawn_rabbit_burst(pos: Vector2) -> void:
	for _index in range(10):
		var velocity := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(2.0, 6.0)
		velocity.y -= 2.0
		rabbit_burst_particles.append({
			"pos": pos,
			"vel": velocity,
			"life": rng.randf_range(15.0, 30.0) / LEGACY_FPS,
			"max_life": 30.0 / LEGACY_FPS,
		})


func _update_burst_particles(step: float) -> void:
	for index in range(rabbit_burst_particles.size() - 1, -1, -1):
		var particle: Dictionary = rabbit_burst_particles[index]
		var velocity := _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO)
		velocity.y += 0.18 * step * LEGACY_FPS
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + velocity * step * LEGACY_FPS
		particle["vel"] = velocity
		particle["life"] = float(particle.get("life", 0.0)) - step
		if float(particle["life"]) <= 0.0:
			rabbit_burst_particles.remove_at(index)
		else:
			rabbit_burst_particles[index] = particle


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {
		"stage3_boss_skill_hud_active": true,
		"stage3_boss_skill_hud_boss_name": str(
			StageBossVariantCatalog.get_entry(STAGE_ID, VARIANT_ID).get("display_name", "보스")
		),
		"stage3_boss_skill_hud_status": status,
		"stage3_boss_skill_hud_boss_gauge": boss_special_gauge,
		"stage3_boss_skill_hud_boss_gauge_max": GAUGE_MAX,
		"stage3_boss_skill_hud_boss_gauge_progress": get_boss_gauge_progress(),
		"stage3_boss_skill_hud_show_boss_gauge": true,
		"stage3_boss_skill_hud_skills": [
			_build_skill("mirror_world", "경화수월", mirror_active, mirror_cooldown, MIRROR_COOLDOWN_SEC, MIRROR_COST, Color("c8d9ff")),
			_build_skill("size_shift", "여의변화", size_shift_active, size_shift_cooldown, SIZE_SHIFT_COOLDOWN_SEC, SIZE_SHIFT_COST, Color("79e7ff")),
			_build_skill("rabbit_projectile", "옥토비탄", rabbit_active or rabbit_windup > 0.0, rabbit_cooldown, RABBIT_COOLDOWN_SEC, RABBIT_COST, Color("ffc2df")),
		],
	}


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage_boss_variant": VARIANT_ID,
		"stage3_alice_hit_ratio": hit_timer / 0.35,
		"stage3_alice_mirror_active": mirror_active,
		"stage3_alice_mirror_ratio": _get_mirror_fade_ratio(),
		"stage3_alice_mirror_phase": mirror_elapsed * LEGACY_FPS,
		"stage3_alice_size_shift_ratio": size_shift_timer / SIZE_SHIFT_DURATION_SEC,
		"stage3_alice_size_shift_scale": size_shift_scale if size_shift_active else 1.0,
		"stage3_alice_rabbit_windup_ratio": rabbit_windup / RABBIT_WINDUP_SEC,
		"stage3_alice_rabbit_projectiles": _draw_array(rabbit_projectiles, copy_arrays),
		"stage3_alice_perched_rabbits": _draw_array(perched_rabbits, copy_arrays),
		"stage3_alice_rabbit_burst_particles": _draw_array(rabbit_burst_particles, copy_arrays),
	}


func get_boss_gauge_progress() -> float:
	return clampf(boss_special_gauge / GAUGE_MAX, 0.0, 1.0)


func get_snapshot() -> Dictionary:
	var snapshot := get_actor_draw_context(true)
	snapshot.merge({
		"status": status,
		"boss_special_gauge": boss_special_gauge,
		"mirror_cooldown": mirror_cooldown,
		"size_shift_cooldown": size_shift_cooldown,
		"rabbit_cooldown": rabbit_cooldown,
		"ball_size": _get_effective_ball_size(),
	}, true)
	return snapshot


func _get_mirror_fade_ratio() -> float:
	if not mirror_active:
		return 0.0
	return minf(1.0, minf(mirror_elapsed / MIRROR_FADE_SEC, mirror_timer / MIRROR_FADE_SEC))


func _build_skill(id: String, label: String, active: bool, cooldown: float, total: float, gauge_cost: float, color: Color) -> Dictionary:
	var cooldown_progress := clampf(1.0 - cooldown / maxf(total, 0.001), 0.0, 1.0)
	var gauge_progress := clampf(boss_special_gauge / maxf(gauge_cost, 0.001), 0.0, 1.0)
	var ready := not active and cooldown <= 0.0 and boss_special_gauge >= gauge_cost
	var skill_status := "casting" if active else ("ready" if ready else "charging")
	return {
		"id": id,
		"label": label,
		"status": skill_status,
		"cooldown_remaining": cooldown,
		"cooldown_total": total,
		"progress": 1.0 if active else minf(cooldown_progress, gauge_progress),
		"ready": ready,
		"activation_gauge_current": boss_special_gauge,
		"activation_gauge_cost": gauge_cost,
		"activation_gauge_progress": gauge_progress,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": "boss_hit",
		"color": color,
	}


func _resolve_status() -> String:
	if mirror_active:
		return "mirror_world"
	if size_shift_active:
		return "size_shift"
	if rabbit_active or rabbit_windup > 0.0:
		return "rabbit_projectile"
	return "charging"


func _is_alice_context(context: Dictionary) -> bool:
	return int(context.get("current_stage", STAGE_ID)) == STAGE_ID and str(context.get("stage_boss_variant", "")) == VARIANT_ID


func _is_cooldown_paused(context: Dictionary) -> bool:
	return bool(context.get(
		"active_item_boss_skill_cooldown_paused",
		context.get("active_item_tear_gas_cooldown_pause_active", false)
	))


func _get_boss_bottom_center(context: Dictionary) -> Vector2:
	var pos := _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	return pos + Vector2(float(context.get("boss_paddle_width", 100.0)) * 0.5, float(context.get("boss_hitbox_height", 40.0)))


func _get_player_center(context: Dictionary) -> Vector2:
	return _as_vector2(context.get("player_pos", Vector2(302.5, 680.0)), Vector2(302.5, 680.0)) + _get_player_size(context) * 0.5


func _get_player_size(context: Dictionary) -> Vector2:
	return _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))


func _is_point_in_smoke(pos: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	for value in _get_smoke_zones(context, deps):
		if not (value is Dictionary):
			continue
		var zone: Dictionary = value
		var opacity := float(zone.get("opacity", 0.0))
		var threshold := 50.0 if opacity > 1.0 else 0.20
		if opacity <= threshold:
			continue
		var center := _as_vector2(zone.get("center", zone.get("pos", Vector2.ZERO)), Vector2.ZERO)
		var radius_x := maxf(1.0, float(zone.get("radius_x", zone.get("radius", 1.0))))
		var radius_y := maxf(1.0, float(zone.get("radius_y", zone.get("radius", radius_x))))
		var relative := pos - center
		if relative.x * relative.x / (radius_x * radius_x) + relative.y * relative.y / (radius_y * radius_y) <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var value: Variant = context.get(key, [])
		if value is Array and not value.is_empty():
			return value
	var runtime: Object = deps.get("active_item_runtime", null)
	if runtime != null and runtime.has_method("get_tear_gas_zones"):
		var zones: Variant = runtime.get_tear_gas_zones()
		if zones is Array:
			return zones
	return []


func _draw_array(source: Array, copy_arrays: bool) -> Array:
	return source.duplicate(true) if copy_arrays else source


func _play_audio(deps: Dictionary, method: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method):
		audio.call(method)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
