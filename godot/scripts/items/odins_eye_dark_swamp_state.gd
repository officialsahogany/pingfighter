extends RefCounted

## Odin's Eye transformed-skill state. All velocity values in this owner are
## px/frame, matching the battle ball and the legacy Dark Swamp contract.

const PHASE_RISING := "rising"
const PHASE_HOLD := "hold"
const PHASE_FALLING := "falling"
const PHASE_DISSOLVING := "dissolving"

const HUD_STATE_DISABLED := "disabled"
const HUD_STATE_BLOCKED := "blocked"
const HUD_STATE_READY := "ready"
const HUD_STATE_INSUFFICIENT_GAUGE := "insufficient_gauge"
const HUD_STATE_ACTIVE := "active"
const HUD_STATE_COOLDOWN := "cooldown"

const REFERENCE_FPS := 60.0
const GAUGE_COST := 100.0
const COOLDOWN_FRAMES := 120.0
const MAX_SPIKES := 12
const SPIKE_SPAWN_INTERVAL_FRAMES := 8.0
const SPIKE_WAVE_PROGRESS_PER_FRAME := 0.025
const SPIKE_RISE_FRAMES := 10.0
const SPIKE_HOLD_FRAMES := 35.0
const SPIKE_FALL_FRAMES := 15.0
const SPIKE_DISSOLVE_FRAMES := 15.0
# Godot's playfield is the full 0..760 canvas. Keep a small visual/collision
# margin around the spike center; the legacy 100..660 HUD inset is not a wall.
const SPIKE_X_MIN := 18.0
const SPIKE_X_MAX := 742.0
const SPIKE_LANE_STEP := 25.0
const SPIKE_X_JITTER := 10.0
const SPIKE_MIN_WIDTH := 6
const SPIKE_MAX_WIDTH := 10
const SPIKE_MIN_HEIGHT := 38
const SPIKE_MAX_HEIGHT := 63
const BALL_COLLISION_MIN_HEIGHT := 10.0
const BOSS_COLLISION_MIN_HEIGHT := 20.0
const BALL_FAST_SPEED_THRESHOLD := 3.0
const BALL_MIN_BOOST_BASE_SPEED := 10.0
const BALL_MIN_SPEED_BOOST := 1.4
const BALL_MAX_SPEED_BOOST := 1.7
const BALL_MAX_REFLECT_ANGLE := PI / 4.0
const BALL_FALLBACK_X := 5.0
const BALL_FALLBACK_Y := -12.0
const BOSS_KNOCKBACK_POWER := 25.0
const BOSS_KNOCKBACK_TIMER_FRAMES := 24
const BOSS_STUN_FRAMES := 60
# Python parity: the generic boss knockback handler decays with 0.85 per frame
# (pingfighter.py:193938); the shrapnel-armor sibling ports the same constant.
const BOSS_KNOCKBACK_DECAY_PER_FRAME := 0.85
const FRAGMENT_GRAVITY_PER_FRAME := 0.25
const FRAGMENT_DRAG_PER_FRAME := 0.98

var enabled := false
var active := false
var revival_blocked := false
var death_blocked := false
var cooldown_remaining_frames := 0.0
var path_start := Vector2.ZERO
var path_end := Vector2.ZERO
var wave_active := false
var wave_progress := 0.0
var boss_stun_timer_frames := 0.0
var boss_knockback_timer_frames := 0.0
var boss_knockback_vel := 0.0
var _boss_gate_release_grace := false
# Whether THIS mythic tick ran under a full-freeze gate (영체탈주): a fresh hit
# landing after the status tick in the same frame must arm the release grace
# (the frozen window may end this very frame with no further freeze tick).
var _freeze_gate_this_tick := false

var _spikes: Array[Dictionary] = []
var _fragments: Array[Dictionary] = []
var _spawn_timer_frames := 0.0
var _spawned_spike_count := 0
var _frame_accumulator_frames := 0.0
var _next_spike_id := 1
var _next_fragment_id := 1
var _pending_spawned_spike_count := 0
var _pending_activation_gauge_cost := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func set_random_seed(value: int) -> void:
	_rng.seed = value


func enable() -> void:
	# Finalize is an edge. Repeated owner sync must not erase a live cooldown.
	if enabled:
		return
	enabled = true
	revival_blocked = false
	death_blocked = false
	cooldown_remaining_frames = 0.0


func disable() -> void:
	enabled = false
	revival_blocked = false
	death_blocked = false
	_clear_transient(true)


func reset() -> void:
	reset_round()


func reset_round() -> void:
	# Odin's penalty form survives the rally boundary, but its hazards do not.
	# Preserve enabled/cooldown while directly clearing every transient payload.
	_clear_transient(false)
	revival_blocked = false
	death_blocked = false


func clear_after_victory() -> void:
	disable()


func clear_after_death() -> void:
	disable()


func on_stage_advance() -> void:
	disable()


func reset_all() -> void:
	disable()


func set_activation_blocked(reviving: bool, dying: bool) -> void:
	revival_blocked = reviving
	death_blocked = dying


func is_enabled() -> bool:
	return enabled


func is_active() -> bool:
	return active


func can_activate(current_gauge: float) -> bool:
	return (
		enabled
		and not revival_blocked
		and not death_blocked
		and not active
		and cooldown_remaining_frames <= 0.0
		and current_gauge >= GAUGE_COST
	)


func activate(
	player_center: Vector2,
	boss_center: Vector2,
	current_gauge: float = GAUGE_COST
) -> bool:
	if not can_activate(current_gauge):
		return false
	active = true
	path_start = player_center + Vector2(0.0, -30.0)
	path_end = boss_center + Vector2(0.0, 30.0)
	cooldown_remaining_frames = COOLDOWN_FRAMES
	wave_active = true
	wave_progress = 0.0
	_spawn_timer_frames = 0.0
	_spawned_spike_count = 0
	_frame_accumulator_frames = 0.0
	_next_spike_id = 1
	_next_fragment_id = 1
	_pending_spawned_spike_count = 0
	_pending_activation_gauge_cost = GAUGE_COST
	_spikes.clear()
	_fragments.clear()
	return true


func consume_activation_gauge_cost() -> float:
	var cost := _pending_activation_gauge_cost
	_pending_activation_gauge_cost = 0.0
	return cost


func consume_spawned_spike_count() -> int:
	var count := _pending_spawned_spike_count
	_pending_spawned_spike_count = 0
	return count


func update(delta_sec: float, boss_dash_gate_active: bool = false, arm_gate_release_grace: bool = true, freeze_knockback: bool = false) -> bool:
	if not has_runtime_update_work():
		_frame_accumulator_frames = 0.0
		return false
	var safe_delta_sec: float = maxf(0.0, delta_sec)
	_frame_accumulator_frames += safe_delta_sec * REFERENCE_FPS
	var frames_to_step := int(floor(_frame_accumulator_frames + 0.000001))
	if frames_to_step <= 0:
		return false
	_frame_accumulator_frames -= float(frames_to_step)
	for _frame_index in range(frames_to_step):
		_update_one_frame(boss_dash_gate_active, arm_gate_release_grace, freeze_knockback)
	return true


func has_runtime_update_work() -> bool:
	return (
		active
		or cooldown_remaining_frames > 0.0
		or not _spikes.is_empty()
		or not _fragments.is_empty()
		or boss_stun_timer_frames > 0.0
		or boss_knockback_timer_frames > 0.0
	)


func get_gauge_cost() -> float:
	return GAUGE_COST


func get_cooldown_duration_frames() -> float:
	return COOLDOWN_FRAMES


func get_cooldown_remaining_frames() -> float:
	return cooldown_remaining_frames


func get_cooldown_remaining_sec() -> float:
	return cooldown_remaining_frames / REFERENCE_FPS


func get_cooldown_ratio() -> float:
	return clampf(cooldown_remaining_frames / COOLDOWN_FRAMES, 0.0, 1.0)


func check_ball_collision(ball_rect: Rect2, ball_velocity: Vector2) -> Dictionary:
	var miss_result := {
		"hit": false,
		"consumed": false,
		"spike_id": -1,
		"impact_pos": Vector2.ZERO,
		"new_velocity": ball_velocity,
		"velocity": ball_velocity,
		"new_vx": ball_velocity.x,
		"new_vy": ball_velocity.y,
		"force": Vector2.ZERO,
		"force_x": 0.0,
		"force_y": 0.0,
		"used_fallback": false,
		"speed_boost": 1.0,
		"audio_cue": "",
		"audio_volume": 0.0,
	}
	var ball_center: Vector2 = ball_rect.position + ball_rect.size * 0.5
	for spike in _spikes:
		if bool(spike.get("consumed", false)):
			continue
		var phase := str(spike.get("phase", ""))
		if phase != PHASE_RISING and phase != PHASE_HOLD:
			continue
		var height := float(spike.get("height", 0.0))
		if height < BALL_COLLISION_MIN_HEIGHT:
			continue
		var spike_x := float(spike.get("x", 0.0))
		var spike_y := float(spike.get("y", 0.0))
		var spike_width := float(spike.get("width", 0.0))
		var collision_rect := Rect2(
			Vector2(spike_x - spike_width - 5.0, spike_y - height),
			Vector2(spike_width * 2.0 + 10.0, height)
		)
		if not collision_rect.intersects(ball_rect):
			continue

		var current_speed := ball_velocity.length()
		var new_velocity := ball_velocity
		var force := Vector2.ZERO
		var used_fallback := current_speed <= BALL_FAST_SPEED_THRESHOLD
		var speed_boost := 1.0
		if used_fallback:
			var side := -1.0 if ball_center.x < spike_x else 1.0
			force = Vector2(side * BALL_FALLBACK_X, BALL_FALLBACK_Y)
			new_velocity = force
		else:
			var base_speed := maxf(BALL_MIN_BOOST_BASE_SPEED, current_speed)
			var hit_half_width := spike_width + 2.5
			var hit_offset := clampf((ball_center.x - spike_x) / hit_half_width, -1.0, 1.0)
			var reflect_angle := hit_offset * BALL_MAX_REFLECT_ANGLE
			speed_boost = _rng.randf_range(BALL_MIN_SPEED_BOOST, BALL_MAX_SPEED_BOOST)
			var boosted_speed := base_speed * speed_boost
			new_velocity = Vector2(sin(reflect_angle), -cos(reflect_angle)) * boosted_speed

		var impact_pos := Vector2(spike_x, spike_y - height * 0.5)
		var spike_id := int(spike.get("id", -1))
		_consume_spike(spike, "ball", impact_pos)
		return {
			"hit": true,
			"consumed": true,
			"spike_id": spike_id,
			"impact_pos": impact_pos,
			"new_velocity": new_velocity,
			"velocity": new_velocity,
			"new_vx": new_velocity.x,
			"new_vy": new_velocity.y,
			"force": force,
			"force_x": force.x,
			"force_y": force.y,
			"used_fallback": used_fallback,
			"speed_before": current_speed,
			"speed_after": new_velocity.length(),
			"speed_boost": speed_boost,
			"audio_cue": "odinattack",
			"audio_volume": 0.6,
		}
	return miss_result


func check_boss_collision(boss_rect: Rect2) -> Dictionary:
	var miss_result := {
		"hit": false,
		"consumed": false,
		"spike_id": -1,
		"impact_pos": Vector2.ZERO,
		"knockback_direction": 0,
		"knockback_power": 0.0,
		"knockback_timer_frames": 0,
		"knockback_timer": 0,
		"stun_duration_frames": 0,
		"stun_duration": 0,
		"audio_cue": "",
		"audio_volume": 0.0,
	}
	var boss_center: Vector2 = boss_rect.position + boss_rect.size * 0.5
	for spike in _spikes:
		if bool(spike.get("consumed", false)):
			continue
		var phase := str(spike.get("phase", ""))
		if phase != PHASE_RISING and phase != PHASE_HOLD:
			continue
		var height := float(spike.get("height", 0.0))
		if height < BOSS_COLLISION_MIN_HEIGHT:
			continue
		var spike_x := float(spike.get("x", 0.0))
		var spike_y := float(spike.get("y", 0.0))
		var spike_width := float(spike.get("width", 0.0))
		var tip_rect := Rect2(
			Vector2(spike_x - spike_width - 3.0, spike_y - height - 5.0),
			Vector2(spike_width * 2.0 + 6.0, 15.0)
		)
		if not tip_rect.intersects(boss_rect):
			continue
		var direction := 1 if spike_x < boss_center.x else -1
		var impact_pos := Vector2(spike_x, spike_y - height)
		var spike_id := int(spike.get("id", -1))
		_consume_spike(spike, "boss", impact_pos)
		boss_stun_timer_frames = maxf(boss_stun_timer_frames, float(BOSS_STUN_FRAMES))
		boss_knockback_timer_frames = maxf(
			boss_knockback_timer_frames,
			float(BOSS_KNOCKBACK_TIMER_FRAMES)
		)
		boss_knockback_vel = float(direction) * BOSS_KNOCKBACK_POWER
		# A fresh hit starts a fresh CC window: a stale release grace from an
		# earlier (non-freezing) gate must not skip this window's first
		# consumption. But if THIS tick ran under a full freeze (영체탈주), the
		# grace must arm — the boss AI never applies during the freeze, and the
		# escape may end this very frame with no further freeze tick to re-arm.
		_boss_gate_release_grace = _freeze_gate_this_tick
		return {
			"hit": true,
			"consumed": true,
			"spike_id": spike_id,
			"impact_pos": impact_pos,
			"knockback_direction": direction,
			"knockback_power": BOSS_KNOCKBACK_POWER,
			"knockback_timer_frames": BOSS_KNOCKBACK_TIMER_FRAMES,
			"knockback_timer": BOSS_KNOCKBACK_TIMER_FRAMES,
			"stun_duration_frames": BOSS_STUN_FRAMES,
			"stun_duration": BOSS_STUN_FRAMES,
			"audio_cue": "odinattack",
			"audio_volume": 0.7,
		}
	return miss_result


func get_context(current_gauge: float = -1.0) -> Dictionary:
	var gauge_known := current_gauge >= 0.0
	var gauge_sufficient := current_gauge >= GAUGE_COST if gauge_known else true
	return {
		"enabled": enabled,
		"active": active,
		"activation_blocked": revival_blocked or death_blocked,
		"revival_blocked": revival_blocked,
		"death_blocked": death_blocked,
		"state": _get_hud_state(current_gauge),
		"gauge_known": gauge_known,
		"current_gauge": current_gauge,
		"gauge_sufficient": gauge_sufficient,
		"gauge_cost": GAUGE_COST,
		"can_activate": can_activate(current_gauge) if gauge_known else _is_ready_except_gauge(),
		"cooldown_duration_frames": COOLDOWN_FRAMES,
		"cooldown_remaining_frames": cooldown_remaining_frames,
		"cooldown_duration_sec": COOLDOWN_FRAMES / REFERENCE_FPS,
		"cooldown_remaining_sec": get_cooldown_remaining_sec(),
		"cooldown_ratio": get_cooldown_ratio(),
		"path_start": path_start,
		"path_end": path_end,
		"wave_active": wave_active,
		"wave_progress": wave_progress,
		"boss_stun_active": boss_stun_timer_frames > 0.0,
		"boss_stun_timer_frames": boss_stun_timer_frames,
		# Timer-only gate (Python parity, pingfighter.py:178178): after a wall
		# stop zeroes the velocity the remaining knockback frames still hold the
		# boss (branch keeps returning with vel 0, dash stays blocked).
		"boss_knockback_active": boss_knockback_timer_frames > 0.0,
		"boss_knockback_timer_frames": boss_knockback_timer_frames,
		"boss_knockback_vel": boss_knockback_vel,
		"spawn_interval_frames": SPIKE_SPAWN_INTERVAL_FRAMES,
		"spawned_spike_count": _spawned_spike_count,
		"max_spikes": MAX_SPIKES,
		"spikes": _spikes.duplicate(true),
		"fragments": _fragments.duplicate(true),
		"pending_spawned_spike_count": _pending_spawned_spike_count,
		"pending_activation_gauge_cost": _pending_activation_gauge_cost,
	}


func _update_one_frame(boss_dash_gate_active: bool = false, arm_gate_release_grace: bool = true, freeze_knockback: bool = false) -> void:
	_update_boss_status(boss_dash_gate_active, arm_gate_release_grace, freeze_knockback)
	if cooldown_remaining_frames > 0.0:
		cooldown_remaining_frames = maxf(0.0, cooldown_remaining_frames - 1.0)
	if not active:
		_update_fragments()
		return
	if wave_active:
		wave_progress = minf(1.0, wave_progress + SPIKE_WAVE_PROGRESS_PER_FRAME)
		if wave_progress >= 1.0:
			wave_active = false
	_spawn_timer_frames += 1.0
	if _spawn_timer_frames >= SPIKE_SPAWN_INTERVAL_FRAMES and _spawned_spike_count < MAX_SPIKES:
		_spawn_timer_frames = 0.0
		_spawn_spike()
	_update_spikes()
	_update_fragments()
	if _spawned_spike_count >= MAX_SPIKES and _spikes.is_empty() and _fragments.is_empty():
		active = false


func _spawn_spike() -> void:
	var progress := float(_spawned_spike_count) / float(maxi(1, MAX_SPIKES - 1))
	var spike_y := lerpf(path_start.y, path_end.y, progress)
	var lane_index := int(floor(float(_spawned_spike_count) / 2.0)) + 1
	var lane_side := -1.0 if _spawned_spike_count % 2 == 0 else 1.0
	var spread_offset := lane_side * float(lane_index) * SPIKE_LANE_STEP
	var spike_x := clampf(
		path_start.x + spread_offset + _rng.randf_range(-SPIKE_X_JITTER, SPIKE_X_JITTER),
		SPIKE_X_MIN,
		SPIKE_X_MAX
	)
	var sub_crystals: Array[Dictionary] = []
	var sub_count := _rng.randi_range(2, 4)
	for sub_index in range(sub_count):
		var side := -1.0 if sub_index % 2 == 0 else 1.0
		sub_crystals.append({
			"offset_x": side * float(_rng.randi_range(6, 18)),
			"offset_y_ratio": _rng.randf_range(0.1, 0.4),
			"height_ratio": _rng.randf_range(0.3, 0.6),
			"width_ratio": _rng.randf_range(0.5, 0.8),
			"angle_deg": side * _rng.randf_range(5.0, 20.0),
		})
	var width := float(_rng.randi_range(SPIKE_MIN_WIDTH, SPIKE_MAX_WIDTH))
	var max_height := float(_rng.randi_range(SPIKE_MIN_HEIGHT, SPIKE_MAX_HEIGHT))
	_spikes.append({
		"id": _next_spike_id,
		"x": spike_x,
		"y": spike_y,
		"position": Vector2(spike_x, spike_y),
		"height": 0.0,
		"max_height": max_height,
		"width": width,
		"base_width": width,
		"timer_frames": 0.0,
		"phase": PHASE_RISING,
		"phase_timer_frames": 0.0,
		"rise_frames": SPIKE_RISE_FRAMES,
		"hold_frames": SPIKE_HOLD_FRAMES,
		"fall_frames": SPIKE_FALL_FRAMES,
		"dissolve_frames": SPIKE_DISSOLVE_FRAMES,
		"dissolve_alpha": 1.0,
		"offset": _rng.randf_range(0.0, TAU),
		"wobble": 0.0,
		"consumed": false,
		"consumed_by": "",
		"hit_ball": false,
		"hit_boss": false,
		"color_shift": _rng.randf(),
		"sub_crystals": sub_crystals,
	})
	_next_spike_id += 1
	_spawned_spike_count += 1
	_pending_spawned_spike_count += 1


func _update_spikes() -> void:
	for spike_index in range(_spikes.size() - 1, -1, -1):
		var spike: Dictionary = _spikes[spike_index]
		var timer_frames := float(spike.get("timer_frames", 0.0)) + 1.0
		var phase_timer := float(spike.get("phase_timer_frames", 0.0)) + 1.0
		var max_height := float(spike.get("max_height", 0.0))
		var phase := str(spike.get("phase", ""))
		spike["timer_frames"] = timer_frames
		spike["phase_timer_frames"] = phase_timer
		match phase:
			PHASE_RISING:
				var rise_progress := minf(1.0, phase_timer / SPIKE_RISE_FRAMES)
				spike["height"] = max_height * _ease_out_back(rise_progress)
				if phase_timer >= SPIKE_RISE_FRAMES:
					spike["phase"] = PHASE_HOLD
					spike["phase_timer_frames"] = 0.0
			PHASE_HOLD:
				if phase_timer >= SPIKE_HOLD_FRAMES:
					spike["phase"] = PHASE_FALLING
					spike["phase_timer_frames"] = 0.0
			PHASE_FALLING:
				var fall_progress := minf(1.0, phase_timer / SPIKE_FALL_FRAMES)
				spike["height"] = max_height * (1.0 - fall_progress * fall_progress)
				if phase_timer >= SPIKE_FALL_FRAMES:
					_spikes.remove_at(spike_index)
					continue
			PHASE_DISSOLVING:
				var dissolve_progress := minf(1.0, phase_timer / SPIKE_DISSOLVE_FRAMES)
				spike["dissolve_alpha"] = 1.0 - dissolve_progress
				spike["height"] = max_height * (1.0 - dissolve_progress * 0.5)
				spike["width"] = maxf(
					1.0,
					float(spike.get("base_width", 1.0)) * (1.0 - dissolve_progress * 0.3)
				)
				if phase_timer >= SPIKE_DISSOLVE_FRAMES:
					_spikes.remove_at(spike_index)
					continue
		spike["wobble"] = sin(timer_frames * 0.3 + float(spike.get("offset", 0.0))) * 2.0


func _consume_spike(spike: Dictionary, consumer: String, impact_pos: Vector2) -> void:
	spike["consumed"] = true
	spike["consumed_by"] = consumer
	spike["hit_ball"] = consumer == "ball"
	spike["hit_boss"] = consumer == "boss"
	spike["phase"] = PHASE_DISSOLVING
	spike["phase_timer_frames"] = 0.0
	spike["dissolve_alpha"] = 1.0
	_spawn_fragments(impact_pos, float(spike.get("height", 0.0)))


func _spawn_fragments(impact_pos: Vector2, spike_height: float) -> void:
	var fragment_count := 8 + int(floor(spike_height / 10.0))
	for fragment_index in range(fragment_count):
		var angle := (
			float(fragment_index) / float(maxi(1, fragment_count)) * TAU
			+ _rng.randf_range(-0.3, 0.3)
		)
		var speed := _rng.randf_range(3.0, 8.0)
		var life_frames := float(_rng.randi_range(30, 50))
		var shape_index := _rng.randi_range(0, 2)
		var shape := "triangle"
		if shape_index == 1:
			shape = "diamond"
		elif shape_index == 2:
			shape = "shard"
		_fragments.append({
			"id": _next_fragment_id,
			"position": impact_pos + Vector2(
				_rng.randf_range(-10.0, 10.0),
				_rng.randf_range(-spike_height * 0.5, 0.0)
			),
			"velocity": Vector2(cos(angle) * speed, sin(angle) * speed - 2.0),
			"size": float(_rng.randi_range(4, 10)),
			"alpha": 1.0,
			"life_frames": life_frames,
			"max_life_frames": life_frames,
			"rotation": _rng.randf_range(0.0, TAU),
			"rotation_speed": _rng.randf_range(-0.3, 0.3),
			"color_shift": _rng.randf(),
			"shape": shape,
		})
		_next_fragment_id += 1


func _update_fragments() -> void:
	for fragment_index in range(_fragments.size() - 1, -1, -1):
		var fragment: Dictionary = _fragments[fragment_index]
		var position := Vector2(fragment.get("position", Vector2.ZERO))
		var velocity := Vector2(fragment.get("velocity", Vector2.ZERO))
		var life_frames := float(fragment.get("life_frames", 0.0)) - 1.0
		var max_life_frames := maxf(1.0, float(fragment.get("max_life_frames", 1.0)))
		position += velocity
		velocity.y += FRAGMENT_GRAVITY_PER_FRAME
		velocity.x *= FRAGMENT_DRAG_PER_FRAME
		fragment["position"] = position
		fragment["velocity"] = velocity
		fragment["rotation"] = (
			float(fragment.get("rotation", 0.0))
			+ float(fragment.get("rotation_speed", 0.0))
		)
		fragment["life_frames"] = life_frames
		fragment["alpha"] = clampf(life_frames / max_life_frames, 0.0, 1.0)
		fragment["size"] = maxf(1.0, float(fragment.get("size", 1.0)) * 0.97)
		if life_frames <= 0.0 or float(fragment.get("alpha", 0.0)) < 0.04:
			_fragments.remove_at(fragment_index)


func _update_boss_status(boss_dash_gate_active: bool, arm_gate_release_grace: bool = true, freeze_knockback: bool = false) -> void:
	_freeze_gate_this_tick = freeze_knockback
	# Python parity: the CC timers consume SEQUENTIALLY, not in parallel.
	# pingfighter.py:178176-178258 — the knockback branch runs ABOVE dash and
	# returns for each of its 24 frames, so the stun timer is untouched there.
	# pingfighter.py:178654-178677 — the stun branch then spends its 60 frames,
	# but ONLY on frames the boss AI actually reaches it: a dash / dash-recovery
	# frame returns first, so a live dash FREEZES (never drains) the stun timer.
	# The knockback velocity is NOT zeroed at timer end — the decaying residual
	# keeps applying through the stun window (~3.4px tail; total travel ≈166.7px).
	# Wall-stop zeroing is positional-only here: the boss AI clamp pins the
	# position, and the residual decays to nothing on its own.
	if freeze_knockback and (boss_knockback_timer_frames > 0.0 or boss_stun_timer_frames > 0.0):
		# 영체탈주-class FULL freeze: Python's escape return sits above the
		# knockback branch, so both timers hold in place and the release grace
		# arms so the AI consumes the preserved frame right after the freeze.
		_boss_gate_release_grace = arm_gate_release_grace
		return
	if boss_knockback_timer_frames > 0.0:
		if _boss_gate_release_grace:
			# The release grace covers the knockback window too (a full freeze
			# may have held it): the AI applies the preserved frame this frame.
			_boss_gate_release_grace = false
			return
		boss_knockback_timer_frames = maxf(0.0, boss_knockback_timer_frames - 1.0)
		boss_knockback_vel *= BOSS_KNOCKBACK_DECAY_PER_FRAME
		return
	if boss_stun_timer_frames <= 0.0:
		_boss_gate_release_grace = false
		return
	if boss_dash_gate_active:
		# A ZOMBIE gate frame (superspeed-owned dash the AI cancels and
		# replaces with the first stun application THIS frame) must hold the
		# mutation but DROP the grace — the preserved frame is being consumed
		# right now, and keeping the grace would duplicate it next frame.
		_boss_gate_release_grace = arm_gate_release_grace
		return
	if _boss_gate_release_grace:
		# One-frame release grace: this state ticks in update_mythic_items,
		# BEFORE the boss AI phase. On the first frame after a dash /
		# dash-recovery / superspeed window ends, the AI has not yet applied
		# the frame the freeze preserved — mutating here would eat one of the
		# 60 stun applications (59 observed) and pre-decay the residual the AI
		# is about to apply. Python has no such split (the stun branch mutates
		# and applies in the same handler), so the release frame must pass
		# through untouched.
		_boss_gate_release_grace = false
		return
	boss_stun_timer_frames = maxf(0.0, boss_stun_timer_frames - 1.0)
	boss_knockback_vel *= BOSS_KNOCKBACK_DECAY_PER_FRAME
	if boss_stun_timer_frames <= 0.0:
		boss_knockback_vel = 0.0


func clear_boss_stun_for_escape() -> void:
	# Python 영체탈주 parity (pingfighter.py stun-escape): the escape consumes
	# the STUN and its residual velocity immediately, but the knockback WINDOW
	# (timer) is preserved — it stays frozen behind the escape and the boss
	# holds for the remaining frames after the escape ends.
	boss_stun_timer_frames = 0.0
	boss_knockback_vel = 0.0


func clear_boss_status() -> void:
	# Single owner for generic boss-CC clears (tear-gas style disable wipes,
	# debug resets): timers, velocity, AND the release grace must drop together
	# or the stale grace skips a frame on the next spike hit.
	boss_stun_timer_frames = 0.0
	boss_knockback_timer_frames = 0.0
	boss_knockback_vel = 0.0
	_boss_gate_release_grace = false


func _clear_transient(clear_cooldown: bool) -> void:
	active = false
	path_start = Vector2.ZERO
	path_end = Vector2.ZERO
	wave_active = false
	wave_progress = 0.0
	_spawn_timer_frames = 0.0
	_spawned_spike_count = 0
	_frame_accumulator_frames = 0.0
	_next_spike_id = 1
	_next_fragment_id = 1
	_pending_spawned_spike_count = 0
	_pending_activation_gauge_cost = 0.0
	boss_stun_timer_frames = 0.0
	boss_knockback_timer_frames = 0.0
	boss_knockback_vel = 0.0
	_boss_gate_release_grace = false
	_spikes.clear()
	_fragments.clear()
	if clear_cooldown:
		cooldown_remaining_frames = 0.0


func _is_ready_except_gauge() -> bool:
	return (
		enabled
		and not revival_blocked
		and not death_blocked
		and not active
		and cooldown_remaining_frames <= 0.0
	)


func _get_hud_state(current_gauge: float) -> String:
	if not enabled:
		return HUD_STATE_DISABLED
	if active:
		return HUD_STATE_ACTIVE
	if revival_blocked or death_blocked:
		return HUD_STATE_BLOCKED
	if cooldown_remaining_frames > 0.0:
		return HUD_STATE_COOLDOWN
	if current_gauge >= 0.0 and current_gauge < GAUGE_COST:
		return HUD_STATE_INSUFFICIENT_GAUGE
	return HUD_STATE_READY


func _ease_out_back(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
