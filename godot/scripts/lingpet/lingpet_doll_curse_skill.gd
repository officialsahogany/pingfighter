extends RefCounted

const LingpetDollCursePayloadFactory := preload("res://scripts/lingpet/lingpet_doll_curse_payload_factory.gd")
const LingpetDollCurseRenderer := preload("res://scripts/lingpet/lingpet_doll_curse_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const EMERGE_SECONDS := 1.0
const ACTIVE_SECONDS := 4.0
const RETRACT_SECONDS := 1.0
const STATUS_REFRESH_FRAMES := 4.0
const STATUS_SOURCE := "lingpet_doll_curse"

const PHASE_IDLE := 0
const PHASE_EMERGE := 1
const PHASE_ACTIVE := 2
const PHASE_RETRACT := 3

const DOLL_OFFSET_X := 150.0
const DOLL_Y_OFFSET := 24.0
const DOLL_TARGET_Y_MIN := 560.0
const DOLL_TARGET_Y_MAX := 660.0
const DOLL_SKY_SPAWN_Y := -86.0
const DOLL_HALF := Vector2(24.0, 32.0)
const DOLL_SHEET_PATH := "res://assets/sprites/lingpet/koyora_doll_curse_wooden_marionette_dance.png"

const BEAM_LENGTH := 700.0
const BEAM_HALF_ANGLE := deg_to_rad(7.0)
const BEAM_SWEEP_HALF_ANGLE := deg_to_rad(35.0)
const BEAM_BASE_ANGLE := -PI * 0.5
const BEAM_SWEEP_PHASE_SLOW := "slow"
const BEAM_SWEEP_PHASE_FAST := "fast"
const BEAM_SLOW_TURN_RATE_MIN := 0.85
const BEAM_SLOW_TURN_RATE_MAX := 1.45
const BEAM_FAST_TURN_RATE_MIN := 8.5
const BEAM_FAST_TURN_RATE_MAX := 13.5
const BEAM_SLOW_SWEEP_MIN_SECONDS := 0.75
const BEAM_SLOW_SWEEP_MAX_SECONDS := 1.25
const BEAM_FAST_SWEEP_MIN_SECONDS := 0.18
const BEAM_FAST_SWEEP_MAX_SECONDS := 0.34
const BEAM_SLOW_DRIFT_HALF_ANGLE := deg_to_rad(16.0)
const BEAM_HOMING_CHANCE_PCT_BY_LEVEL := [35.0, 50.0, 65.0, 80.0, 95.0]
const BEAM_HOMING_FOCUS_HALF_ANGLE_DEG_BY_LEVEL := [18.0, 13.0, 9.0, 6.0, 3.0]
const BEAM_OUTER_END_HALF_WIDTH := BEAM_LENGTH * tan(BEAM_HALF_ANGLE)

const BALL_RADIUS_FALLBACK := 10.0
const BALL_SPEED_MIN := 7.65
const BALL_SIDE_NUDGE_MAX := 2.2
const DOLL_DESTROY_PARTICLE_MAX := 32
const DOLL_DESTROY_PARTICLE_LIFE := 0.55
const HIT_FLASH_SECONDS := 0.22

const COMPANION_CAST_EMERGE_PROGRESS_MAX := 0.56
const COMPANION_CAST_ACTIVE_PROGRESS := 0.70
const COMPANION_CAST_RETRACT_PROGRESS_MIN := 0.82
const COMPANION_CAST_RETRACT_PROGRESS_MAX := 0.96

var _phase := PHASE_IDLE
var _phase_timer := 0.0
var _origin := Vector2.ZERO
var _dolls: Array[Dictionary] = []
var _destroy_particles: Array[Dictionary] = []
var _registry: Object = null
var _confusion_active := false
var _confusion_apply_count := 0
var _confusion_clear_count := 0
var _doll_destroyed_count := 0
var _ball_bounce_count := 0
var _hit_flash_timer := 0.0
var _last_hit_pos := Vector2.ZERO
var _fixed_beam_angle_for_tests := false
var _doll_sheet_texture: Texture2D = null
var _active_skill_level := 1
var _beam_homing_chance_pct := 35.0
var _beam_homing_focus_half_angle := deg_to_rad(18.0)
var _beam_homing_attempt_count := 0
var _beam_homing_success_count := 0
var _beam_homing_rolls_for_tests: Array = []
var _renderer: Object = LingpetDollCurseRenderer.new()


func reset() -> void:
	_clear_boss_confusion(_registry)
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_origin = Vector2.ZERO
	_dolls.clear()
	_destroy_particles.clear()
	_confusion_active = false
	_hit_flash_timer = 0.0
	_last_hit_pos = Vector2.ZERO
	_fixed_beam_angle_for_tests = false
	_active_skill_level = 1
	_beam_homing_chance_pct = _get_beam_homing_chance_for_level(_active_skill_level)
	_beam_homing_focus_half_angle = _get_beam_homing_focus_half_angle_for_level(_active_skill_level)
	_beam_homing_attempt_count = 0
	_beam_homing_success_count = 0
	_beam_homing_rolls_for_tests.clear()


func cancel(_owner: Object = null, registry: Object = null) -> void:
	if registry != null:
		_registry = registry
	reset()


func prewarm() -> void:
	_ensure_doll_sheet()


func launch(origin: Vector2, _owner: Object = null, launch_context: Dictionary = {}) -> bool:
	reset()
	_ensure_doll_sheet()
	var ctx_registry: Variant = launch_context.get("registry", null)
	if typeof(ctx_registry) == TYPE_OBJECT and is_instance_valid(ctx_registry):
		_registry = ctx_registry as Object
	_active_skill_level = clampi(int(launch_context.get("active_skill_level", 1)), 1, 5)
	var ctx_homing_chance := float(launch_context.get("beam_homing_chance_pct", -1.0))
	_beam_homing_chance_pct = clampf(
		ctx_homing_chance if ctx_homing_chance >= 0.0 else _get_beam_homing_chance_for_level(_active_skill_level),
		0.0,
		100.0
	)
	_beam_homing_focus_half_angle = _get_beam_homing_focus_half_angle_for_level(_active_skill_level)
	_origin = Vector2(
		clampf(origin.x, DOLL_OFFSET_X + DOLL_HALF.x, FIELD_WIDTH - DOLL_OFFSET_X - DOLL_HALF.x),
		clampf(origin.y, 450.0, FIELD_HEIGHT - 40.0)
	)
	_spawn_dolls()
	_phase = PHASE_EMERGE
	_phase_timer = 0.0
	return true


func update(delta: float, owner: Object = null, registry: Object = null, _launch_context: Dictionary = {}) -> void:
	if registry != null:
		_registry = registry
	var safe_delta := maxf(0.0, delta)
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - safe_delta)
	_update_destroy_particles(safe_delta)
	if _phase == PHASE_IDLE:
		return
	_phase_timer += safe_delta
	match _phase:
		PHASE_EMERGE:
			_update_emerge()
		PHASE_ACTIVE:
			_update_active(safe_delta, owner)
		PHASE_RETRACT:
			_update_retract()


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if _phase != PHASE_IDLE:
		_renderer.draw_marionette_rigging(canvas, _dolls, shake_offset)
	if _phase == PHASE_ACTIVE:
		_renderer.draw_beams(
			canvas,
			_dolls,
			shake_offset,
			_active_skill_level,
			BEAM_LENGTH,
			BEAM_BASE_ANGLE,
			BEAM_OUTER_END_HALF_WIDTH,
			DOLL_HALF
		)
	_renderer.draw_dolls(
		canvas,
		_dolls,
		shake_offset,
		_doll_sheet_texture,
		_phase,
		_phase_timer,
		PHASE_EMERGE,
		PHASE_ACTIVE,
		PHASE_RETRACT,
		EMERGE_SECONDS,
		RETRACT_SECONDS,
		DOLL_HALF
	)
	_renderer.draw_destroy_particles(canvas, _destroy_particles, shake_offset, DOLL_DESTROY_PARTICLE_LIFE)
	if _hit_flash_timer > 0.0:
		_renderer.draw_hit_flash(canvas, _last_hit_pos + shake_offset, _hit_flash_timer, HIT_FLASH_SECONDS)


func has_visible_effects() -> bool:
	return _phase != PHASE_IDLE or not _destroy_particles.is_empty() or _hit_flash_timer > 0.0


func is_active() -> bool:
	return _phase != PHASE_IDLE


func has_companion_position_override() -> bool:
	return _phase != PHASE_IDLE


func get_companion_position_override(fallback: Vector2 = Vector2.ZERO) -> Vector2:
	return _origin if _phase != PHASE_IDLE else fallback


func get_companion_cast_pose_progress() -> float:
	if _phase == PHASE_IDLE:
		return -1.0
	match _phase:
		PHASE_EMERGE:
			var emerge_ratio := clampf(_phase_timer / EMERGE_SECONDS, 0.0, 1.0)
			return lerpf(0.0, COMPANION_CAST_EMERGE_PROGRESS_MAX, emerge_ratio)
		PHASE_ACTIVE:
			return COMPANION_CAST_ACTIVE_PROGRESS
		PHASE_RETRACT:
			var retract_ratio := clampf(_phase_timer / RETRACT_SECONDS, 0.0, 1.0)
			return lerpf(COMPANION_CAST_RETRACT_PROGRESS_MIN, COMPANION_CAST_RETRACT_PROGRESS_MAX, retract_ratio)
	return -1.0


func get_snapshot() -> Dictionary:
	return {
		"doll_curse_active": _phase != PHASE_IDLE,
		"doll_curse_phase": _phase,
		"doll_curse_phase_timer": _phase_timer,
		"doll_curse_phase_idle": PHASE_IDLE,
		"doll_curse_phase_emerge": PHASE_EMERGE,
		"doll_curse_phase_active": PHASE_ACTIVE,
		"doll_curse_phase_retract": PHASE_RETRACT,
		"doll_curse_emerge_seconds": EMERGE_SECONDS,
		"doll_curse_active_seconds": ACTIVE_SECONDS,
		"doll_curse_retract_seconds": RETRACT_SECONDS,
		"doll_curse_doll_count": _count_live_dolls(),
		"doll_curse_dolls": _dolls.duplicate(true),
		"doll_curse_confusion_active": _confusion_active,
		"doll_curse_confusion_apply_count": _confusion_apply_count,
		"doll_curse_confusion_clear_count": _confusion_clear_count,
		"doll_curse_doll_destroyed_count": _doll_destroyed_count,
		"doll_curse_ball_bounce_count": _ball_bounce_count,
		"doll_curse_companion_override_active": has_companion_position_override(),
		"doll_curse_companion_cast_pose_progress": get_companion_cast_pose_progress(),
		"doll_curse_status_source": STATUS_SOURCE,
		"doll_curse_doll_sheet_loaded": _doll_sheet_texture != null,
		"doll_curse_sky_spawn_y": DOLL_SKY_SPAWN_Y,
		"doll_curse_marionette_rigging": true,
		"doll_curse_beam_slow_turn_rate_max": BEAM_SLOW_TURN_RATE_MAX,
		"doll_curse_beam_fast_turn_rate_min": BEAM_FAST_TURN_RATE_MIN,
		"doll_curse_active_skill_level": _active_skill_level,
		"doll_curse_beam_homing_chance_pct": _beam_homing_chance_pct,
		"doll_curse_beam_homing_chance_pct_by_level": BEAM_HOMING_CHANCE_PCT_BY_LEVEL.duplicate(),
		"doll_curse_beam_homing_focus_half_angle_deg": rad_to_deg(_beam_homing_focus_half_angle),
		"doll_curse_beam_homing_focus_half_angle_deg_by_level": BEAM_HOMING_FOCUS_HALF_ANGLE_DEG_BY_LEVEL.duplicate(),
		"doll_curse_beam_outer_end_half_width": BEAM_OUTER_END_HALF_WIDTH,
		"doll_curse_beam_homing_attempt_count": _beam_homing_attempt_count,
		"doll_curse_beam_homing_success_count": _beam_homing_success_count,
	}


func get_confusion_apply_count_for_tests() -> int:
	return _confusion_apply_count


func get_confusion_clear_count_for_tests() -> int:
	return _confusion_clear_count


func get_doll_destroyed_count_for_tests() -> int:
	return _doll_destroyed_count


func get_ball_bounce_count_for_tests() -> int:
	return _ball_bounce_count


func get_doll_sheet_frame_for_tests(doll: Dictionary) -> int:
	return _renderer.get_doll_sheet_frame(
		doll,
		_phase,
		_phase_timer,
		PHASE_EMERGE,
		PHASE_ACTIVE,
		PHASE_RETRACT,
		EMERGE_SECONDS,
		RETRACT_SECONDS
	)


func set_beam_homing_rolls_for_tests(rolls: Array) -> void:
	_beam_homing_rolls_for_tests = rolls.duplicate()


func force_beam_angle_for_tests(angle: float) -> void:
	_fixed_beam_angle_for_tests = true
	for idx in range(_dolls.size()):
		_dolls[idx]["beam_angle"] = angle
		_dolls[idx]["beam_target_angle"] = angle
		_dolls[idx]["beam_sweep_phase"] = BEAM_SWEEP_PHASE_SLOW
		_dolls[idx]["beam_sweep_timer"] = 999.0
		_dolls[idx]["beam_turn_rate"] = BEAM_SLOW_TURN_RATE_MIN
		_dolls[idx]["beam_homing_targeted"] = false
		_dolls[idx]["beam_homing_focus_active"] = false
		_dolls[idx]["beam_on_boss"] = false
		_dolls[idx]["beam_boss_point"] = Vector2.ZERO


func set_phase_for_tests(phase: int, timer: float = 0.0) -> void:
	_phase = phase
	_phase_timer = maxf(0.0, timer)
	if _phase == PHASE_ACTIVE:
		for idx in range(_dolls.size()):
			_dolls[idx]["emerge_progress"] = 1.0
			_dolls[idx]["pos"] = _dolls[idx].get("target_pos", _dolls[idx].get("pos", Vector2.ZERO))


func _spawn_dolls() -> void:
	_dolls.clear()
	var target_y := clampf(_origin.y + DOLL_Y_OFFSET, DOLL_TARGET_Y_MIN, DOLL_TARGET_Y_MAX)
	for side in [-1, 1]:
		var target := Vector2(
			clampf(_origin.x + float(side) * DOLL_OFFSET_X, DOLL_HALF.x, FIELD_WIDTH - DOLL_HALF.x),
			target_y
		)
		var spawn_pos := _get_doll_sky_spawn_pos(target)
		_dolls.append(LingpetDollCursePayloadFactory.build_doll(
			int(side),
			spawn_pos,
			target,
			BEAM_BASE_ANGLE,
			BEAM_SWEEP_HALF_ANGLE,
			BEAM_SWEEP_PHASE_SLOW,
			BEAM_SLOW_SWEEP_MIN_SECONDS,
			BEAM_SLOW_SWEEP_MAX_SECONDS,
			BEAM_SLOW_TURN_RATE_MIN,
			BEAM_SLOW_TURN_RATE_MAX
		))


func _get_doll_sky_spawn_pos(target: Vector2) -> Vector2:
	return Vector2(target.x, DOLL_SKY_SPAWN_Y)


func _update_emerge() -> void:
	var ratio := clampf(_phase_timer / EMERGE_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - ratio, 3.0)
	for idx in range(_dolls.size()):
		var doll := _dolls[idx]
		if not bool(doll.get("alive", false)):
			continue
		var spawn_pos: Vector2 = doll.get("spawn_pos", Vector2.ZERO)
		var target_pos: Vector2 = doll.get("target_pos", Vector2.ZERO)
		doll["pos"] = spawn_pos.lerp(target_pos, eased)
		doll["emerge_progress"] = ratio
		_dolls[idx] = doll
	if _phase_timer >= EMERGE_SECONDS:
		_phase = PHASE_ACTIVE
		_phase_timer = 0.0


func _update_active(delta: float, owner: Object) -> void:
	_update_beams(delta, owner)
	_try_bounce_ball_from_dolls(owner)
	if _count_live_dolls() <= 0:
		_clear_boss_confusion(_registry)
		_clear_beam_boss_contacts()
		_finish()
		return
	var touching := _update_beam_boss_contacts(owner)
	if touching:
		_apply_boss_confusion(_registry)
	else:
		_clear_boss_confusion(_registry)
	if _phase_timer >= ACTIVE_SECONDS:
		_clear_boss_confusion(_registry)
		_clear_beam_boss_contacts()
		if _count_live_dolls() > 0:
			_phase = PHASE_RETRACT
			_phase_timer = 0.0
		else:
			_finish()


func _update_retract() -> void:
	var ratio := clampf(_phase_timer / RETRACT_SECONDS, 0.0, 1.0)
	var eased := pow(ratio, 2.0)
	for idx in range(_dolls.size()):
		var doll := _dolls[idx]
		if not bool(doll.get("alive", false)):
			continue
		var target_pos: Vector2 = doll.get("target_pos", Vector2.ZERO)
		var spawn_pos: Vector2 = doll.get("spawn_pos", Vector2.ZERO)
		doll["pos"] = target_pos.lerp(spawn_pos, eased)
		doll["emerge_progress"] = 1.0 - ratio
		_dolls[idx] = doll
	if _phase_timer >= RETRACT_SECONDS:
		_finish()


func _finish() -> void:
	_clear_boss_confusion(_registry)
	_phase = PHASE_IDLE
	_phase_timer = 0.0
	_clear_beam_boss_contacts()
	_dolls.clear()
	_fixed_beam_angle_for_tests = false


func _update_beams(delta: float, owner: Object) -> void:
	for idx in range(_dolls.size()):
		var doll := _dolls[idx]
		if not bool(doll.get("alive", false)):
			continue
		var current := float(doll.get("beam_angle", BEAM_BASE_ANGLE))
		if not _fixed_beam_angle_for_tests:
			var timer := float(doll.get("beam_sweep_timer", 0.0)) - delta
			if timer <= 0.0:
				doll = _advance_beam_sweep(doll, current, owner)
			else:
				doll["beam_sweep_timer"] = timer
		var target := float(doll.get("beam_target_angle", BEAM_BASE_ANGLE))
		var turn_rate := float(doll.get("beam_turn_rate", BEAM_SLOW_TURN_RATE_MAX))
		doll["beam_angle"] = lerp_angle(current, target, clampf(delta * turn_rate, 0.0, 1.0))
		doll["wobble"] = float(doll.get("wobble", 0.0)) + delta * 4.0
		_dolls[idx] = doll


func _advance_beam_sweep(doll: Dictionary, current_angle: float, owner: Object) -> Dictionary:
	var phase := str(doll.get("beam_sweep_phase", BEAM_SWEEP_PHASE_SLOW))
	if phase == BEAM_SWEEP_PHASE_SLOW:
		doll["beam_sweep_phase"] = BEAM_SWEEP_PHASE_FAST
		doll["beam_sweep_timer"] = randf_range(BEAM_FAST_SWEEP_MIN_SECONDS, BEAM_FAST_SWEEP_MAX_SECONDS)
		doll["beam_turn_rate"] = randf_range(BEAM_FAST_TURN_RATE_MIN, BEAM_FAST_TURN_RATE_MAX)
		var homing_target := _pick_homing_beam_angle(doll, owner)
		if homing_target.is_empty():
			doll["beam_target_angle"] = _pick_beam_angle()
			doll["beam_homing_targeted"] = false
			doll["beam_homing_focus_active"] = false
		else:
			doll["beam_target_angle"] = float(homing_target.get("angle", BEAM_BASE_ANGLE))
			doll["beam_homing_targeted"] = true
			doll["beam_homing_focus_active"] = true
	else:
		var was_homing := bool(doll.get("beam_homing_focus_active", false))
		doll["beam_sweep_phase"] = BEAM_SWEEP_PHASE_SLOW
		doll["beam_sweep_timer"] = randf_range(BEAM_SLOW_SWEEP_MIN_SECONDS, BEAM_SLOW_SWEEP_MAX_SECONDS)
		doll["beam_turn_rate"] = randf_range(BEAM_SLOW_TURN_RATE_MIN, BEAM_SLOW_TURN_RATE_MAX)
		if was_homing:
			doll["beam_target_angle"] = _pick_focused_homing_drift_angle(doll, owner, current_angle)
		else:
			doll["beam_target_angle"] = _pick_beam_drift_angle(current_angle)
		doll["beam_homing_targeted"] = false
	return doll


func _update_beam_boss_contacts(owner: Object) -> bool:
	var any_touching := false
	var boss_center := Vector2.ZERO
	var has_owner := owner != null
	if has_owner:
		boss_center = _get_boss_rect(owner).get_center()
	for idx in range(_dolls.size()):
		var doll := _dolls[idx]
		var touching := false
		var contact_point := Vector2.ZERO
		if has_owner and bool(doll.get("alive", false)) and _point_in_doll_beam(doll, boss_center):
			touching = true
			contact_point = _project_point_onto_doll_beam(doll, boss_center)
			any_touching = true
		doll["beam_on_boss"] = touching
		doll["beam_boss_point"] = contact_point
		_dolls[idx] = doll
	return any_touching


func _clear_beam_boss_contacts() -> void:
	for idx in range(_dolls.size()):
		_dolls[idx]["beam_on_boss"] = false
		_dolls[idx]["beam_boss_point"] = Vector2.ZERO


# Hit primitive: boss-center-in-cone. The visible beam cone and gameplay hit
# cone share the same origin, angle, half-angle, and length.
func _point_in_doll_beam(doll: Dictionary, point: Vector2) -> bool:
	var origin := _get_doll_beam_origin(doll)
	var to_point := point - origin
	var distance := to_point.length()
	if distance <= 0.01 or distance > BEAM_LENGTH:
		return false
	var beam_angle := float(doll.get("beam_angle", BEAM_BASE_ANGLE))
	var beam_dir := Vector2(cos(beam_angle), sin(beam_angle))
	var angle_to_point := absf(beam_dir.angle_to(to_point / distance))
	return angle_to_point <= BEAM_HALF_ANGLE


func _project_point_onto_doll_beam(doll: Dictionary, point: Vector2) -> Vector2:
	var origin := _get_doll_beam_origin(doll)
	var beam_angle := float(doll.get("beam_angle", BEAM_BASE_ANGLE))
	var beam_dir := Vector2(cos(beam_angle), sin(beam_angle))
	var projected_distance := clampf((point - origin).dot(beam_dir), 0.0, BEAM_LENGTH)
	return origin + beam_dir * projected_distance


func _try_bounce_ball_from_dolls(owner: Object) -> void:
	if owner == null:
		return
	if not bool(_get_owner_value(owner, "ball_active", false)):
		return
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		return
	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius := _get_ball_radius(owner)
	for idx in range(_dolls.size()):
		var doll := _dolls[idx]
		if not bool(doll.get("alive", false)):
			continue
		var doll_pos: Vector2 = doll.get("pos", Vector2.ZERO)
		if absf(ball_pos.x - doll_pos.x) > DOLL_HALF.x + ball_radius:
			continue
		if absf(ball_pos.y - doll_pos.y) > DOLL_HALF.y + ball_radius:
			continue
		_bounce_ball(owner, ball_pos, ball_vel, doll_pos)
		doll["alive"] = false
		_dolls[idx] = doll
		_doll_destroyed_count += 1
		_spawn_destroy_particles(doll_pos)
		_play_doll_destroy_feedback(_registry)
		break


func _bounce_ball(owner: Object, ball_pos: Vector2, ball_vel: Vector2, doll_pos: Vector2) -> void:
	var speed := maxf(ball_vel.length(), BALL_SPEED_MIN)
	var hit_offset := clampf((ball_pos.x - doll_pos.x) / maxf(1.0, DOLL_HALF.x), -1.0, 1.0)
	var next_vel := ball_vel
	next_vel.y = -absf(next_vel.y)
	if absf(next_vel.y) < BALL_SPEED_MIN * 0.5:
		next_vel.y = -BALL_SPEED_MIN * 0.5
	next_vel.x += hit_offset * BALL_SIDE_NUDGE_MAX
	if next_vel.length() > speed:
		next_vel = next_vel.normalized() * speed
	owner.set("ball_vel", next_vel)
	_last_hit_pos = ball_pos
	_hit_flash_timer = HIT_FLASH_SECONDS
	_ball_bounce_count += 1


func _apply_boss_confusion(registry: Object) -> void:
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if status_state == null or not status_state.has_method("apply_status"):
		return
	status_state.apply_status(
		"boss",
		"confusion",
		STATUS_REFRESH_FRAMES,
		LingpetDollCursePayloadFactory.build_confusion_status_data(),
		STATUS_SOURCE
	)
	_confusion_active = true
	_confusion_apply_count += 1


func _clear_boss_confusion(registry: Object) -> void:
	var status_state := _get_registry_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("clear_status"):
		status_state.clear_status("boss", "confusion", STATUS_SOURCE)
	_confusion_active = false
	_confusion_clear_count += 1


func _spawn_destroy_particles(pos: Vector2) -> void:
	for _i in range(14):
		if _destroy_particles.size() >= DOLL_DESTROY_PARTICLE_MAX:
			break
		_destroy_particles.append(LingpetDollCursePayloadFactory.build_destroy_particle(pos, DOLL_DESTROY_PARTICLE_LIFE))


func _update_destroy_particles(delta: float) -> void:
	if _destroy_particles.is_empty():
		return
	var kept: Array[Dictionary] = []
	for particle in _destroy_particles:
		var life := float(particle.get("life", 0.0)) - delta
		if life <= 0.0:
			continue
		var vel: Vector2 = particle.get("vel", Vector2.ZERO)
		vel *= 0.88
		vel.y += 80.0 * delta
		particle["vel"] = vel
		particle["pos"] = (particle.get("pos", Vector2.ZERO) as Vector2) + vel * delta
		particle["life"] = life
		kept.append(particle)
	_destroy_particles = kept


func get_beam_draw_debug_for_tests(doll: Dictionary) -> Dictionary:
	return _renderer.get_beam_draw_debug(doll, _active_skill_level, BEAM_OUTER_END_HALF_WIDTH)


func _ensure_doll_sheet() -> void:
	if _doll_sheet_texture != null:
		return
	_doll_sheet_texture = ProjectResourceLoader.load_texture(DOLL_SHEET_PATH)


func _get_doll_beam_origin(doll: Dictionary) -> Vector2:
	var pos: Vector2 = doll.get("pos", Vector2.ZERO)
	return pos + Vector2(0.0, -DOLL_HALF.y * 0.70)


func _count_live_dolls() -> int:
	var count := 0
	for doll in _dolls:
		if bool(doll.get("alive", false)):
			count += 1
	return count


func _pick_beam_angle() -> float:
	return BEAM_BASE_ANGLE + randf_range(-BEAM_SWEEP_HALF_ANGLE, BEAM_SWEEP_HALF_ANGLE)


func _pick_beam_drift_angle(current_angle: float) -> float:
	return clampf(
		current_angle + randf_range(-BEAM_SLOW_DRIFT_HALF_ANGLE, BEAM_SLOW_DRIFT_HALF_ANGLE),
		BEAM_BASE_ANGLE - BEAM_SWEEP_HALF_ANGLE,
		BEAM_BASE_ANGLE + BEAM_SWEEP_HALF_ANGLE
	)


func _pick_focused_homing_drift_angle(doll: Dictionary, owner: Object, current_angle: float) -> float:
	var homing_angle := _get_beam_homing_angle(doll, owner)
	if homing_angle.is_empty():
		return _pick_beam_drift_angle(current_angle)
	var boss_angle := float(homing_angle.get("angle", current_angle))
	return clampf(
		boss_angle + randf_range(-_beam_homing_focus_half_angle, _beam_homing_focus_half_angle),
		BEAM_BASE_ANGLE - BEAM_SWEEP_HALF_ANGLE,
		BEAM_BASE_ANGLE + BEAM_SWEEP_HALF_ANGLE
	)


func _pick_homing_beam_angle(doll: Dictionary, owner: Object) -> Dictionary:
	var homing_angle := _get_beam_homing_angle(doll, owner)
	if homing_angle.is_empty():
		return {}
	_beam_homing_attempt_count += 1
	if not _roll_beam_homing():
		return {}
	_beam_homing_success_count += 1
	return homing_angle


func _get_beam_homing_angle(doll: Dictionary, owner: Object) -> Dictionary:
	if owner == null:
		return {}
	var origin := _get_doll_beam_origin(doll)
	var to_boss := _get_boss_rect(owner).get_center() - origin
	if to_boss.length() <= 0.01:
		return {}
	var raw_angle := to_boss.angle()
	return {
		"angle": clampf(raw_angle, BEAM_BASE_ANGLE - BEAM_SWEEP_HALF_ANGLE, BEAM_BASE_ANGLE + BEAM_SWEEP_HALF_ANGLE),
	}


func _roll_beam_homing() -> bool:
	if not _beam_homing_rolls_for_tests.is_empty():
		return bool(_beam_homing_rolls_for_tests.pop_front())
	return randf() * 100.0 < _beam_homing_chance_pct


func _get_beam_homing_chance_for_level(level: int) -> float:
	var index := clampi(level, 1, BEAM_HOMING_CHANCE_PCT_BY_LEVEL.size()) - 1
	return float(BEAM_HOMING_CHANCE_PCT_BY_LEVEL[index])


func _get_beam_homing_focus_half_angle_for_level(level: int) -> float:
	var index := clampi(level, 1, BEAM_HOMING_FOCUS_HALF_ANGLE_DEG_BY_LEVEL.size()) - 1
	return deg_to_rad(float(BEAM_HOMING_FOCUS_HALF_ANGLE_DEG_BY_LEVEL[index]))


func _get_boss_rect(owner: Object) -> Rect2:
	var boss_pos: Vector2 = _get_owner_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_w := maxf(1.0, float(_get_owner_value(owner, "boss_paddle_width", 100.0)))
	var boss_h := maxf(1.0, float(_get_owner_value(owner, "boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_w, boss_h))


func _get_ball_radius(owner: Object) -> float:
	var ball_radius := float(_get_owner_value(owner, "ball_radius", 0.0))
	if ball_radius > 0.0:
		return ball_radius
	var ball_size := float(_get_owner_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0))
	return maxf(1.0, ball_size * 0.5)


func _play_doll_destroy_feedback(registry: Object) -> void:
	var audio := _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_dragon_breath_ball_hit"):
		audio.play_dragon_breath_ball_hit()
	elif audio.has_method("play_wall_hit"):
		audio.play_wall_hit(BALL_SPEED_MIN)
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null and owner.get(key) != null:
		return owner.get(key)
	return fallback


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	return value if value is Vector2 else fallback


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
