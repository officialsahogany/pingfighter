extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const SmasherPlasmaFxHost := preload("res://scripts/characters/smasher_plasma_fx_host.gd")

const SKILL_NAME := "plasma"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_Y := 700.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const CHARGE_DRAIN_INTERVAL_FRAMES := 30.0
const CHARGE_DRAIN_AMOUNT := 30.0
const MIN_GAUGE_COST := 40.0
const MIN_CHARGE_FRAMES := 30.0
const MAX_CHARGE_FRAMES := 180.0
const FIELD_MIN_RADIUS := 26.0
const FIELD_MAX_RADIUS := 104.0
const WAVE_BASE_RADIUS := 52.0
const WAVE_MAX_RADIUS := 130.0
const WAVE_SPEED := 6.0
const WAVE_DURATION_FRAMES := 180.0
const WAVE_HOMING_SPEED := 1.2
# 투사체 크기 +30%(FIELD 26/104, WAVE 52/130) + 차징 비례 감속/쿨타임
# (2026-07-06 게임플레이 변경, WIP 파괴 후 재구현): 차징이 클수록 파동이
# 최대 60% 느려지고(수명을 역비례로 늘려 도달거리는 불변), 쿨타임은
# 발사가능 최소 차징 3초 ~ 최대 차징 15초로 비례한다.
const WAVE_CHARGE_SLOWDOWN_MAX := 0.60
const COOLDOWN_MIN_SECONDS := 3.0
const COOLDOWN_MAX_SECONDS := 15.0
const WAVE_FADE_FRAMES := 12.0
const ENRAGED_CHARGE_THRESHOLD := 0.9
const BASE_SLOW_AMOUNT := 0.20
const SLOW_PER_CHARGE_TICK := 0.05
const MAX_SLOW_AMOUNT := 0.80
const BOSS_SLOW_REFRESH_FRAMES := 10.0
const PLASMA_SLOW_SOURCE := "smasher_plasma"
const CONTACT_DISTORTION_GAIN := 0.15
const CONTACT_DISTORTION_DECAY := 0.10
const MAX_CHARGE_PARTICLES := 50
const MAX_WAVE_PARTICLES := 64
const WAVE_PARTICLE_SPAWN_CHANCE := 0.40
const HONGRYUN_STAGE_ID := 5

var charging := false
var charge_time_frames := 0.0
var gauge_consumed := 0.0
var charge_size := 0.0
var charge_particles: Array[Dictionary] = []
var wave_active := false
var wave_pos := Vector2.ZERO
var wave_radius := 0.0
var wave_slow_amount := 0.0
var wave_timer_frames := 0.0
var wave_speed := WAVE_SPEED
var wave_enraged := false
var wave_fade_timer_frames := 0.0
var wave_fade_pos := Vector2.ZERO
var wave_fade_radius := 0.0
var wave_fade_enraged := false
var wave_trail: Array[Dictionary] = []
var wave_particles: Array[Dictionary] = []
var boss_slowed := false
var boss_slow_amount := 0.0
var boss_slow_timer_frames := 0.0
var plasma_contact_distortion := 0.0
var shock_audio_active := false
var charge_audio_active := false
var _gauge_drain_accumulator := 0.0
var _last_player_pos := Vector2(FIELD_WIDTH * 0.5, PLAYER_Y)
var _last_player_size := Vector2(155.0, 50.0)
var _last_boss_pos := Vector2(FIELD_WIDTH * 0.5 - BOSS_PADDLE_WIDTH * 0.5, 25.0)
var _last_boss_size := Vector2(BOSS_PADDLE_WIDTH, BOSS_HITBOX_HEIGHT)
var _prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			ImpactFlareTextureCache.get_glow_texture()
		1:
			ImpactFlareTextureCache.get_burst_texture()
		2:
			ImpactFlareTextureCache.get_sparkle_texture()
		3:
			ImpactShockwaveTextureCache.get_full_ring_texture()
		4:
			ImpactShockwaveTextureCache.get_wall_ring_texture("left")
		5:
			ImpactShockwaveTextureCache.get_wall_ring_texture("right")
		6:
			# 3-피스 모듈러 VFX 호스트 프리웜(셰이더 4프리셋+텍스처 3장) —
			# 첫 캐스트 핫패스 lazy-init을 차단한다.
			SmasherPlasmaFxHost.prewarm_assets()
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func reset() -> void:
	charging = false
	charge_time_frames = 0.0
	gauge_consumed = 0.0
	charge_size = 0.0
	charge_particles.clear()
	wave_active = false
	wave_pos = Vector2.ZERO
	wave_radius = 0.0
	wave_slow_amount = 0.0
	wave_timer_frames = 0.0
	wave_speed = WAVE_SPEED
	wave_enraged = false
	wave_fade_timer_frames = 0.0
	wave_fade_pos = Vector2.ZERO
	wave_fade_radius = 0.0
	wave_fade_enraged = false
	wave_trail.clear()
	wave_particles.clear()
	boss_slowed = false
	boss_slow_amount = 0.0
	boss_slow_timer_frames = 0.0
	plasma_contact_distortion = 0.0
	shock_audio_active = false
	charge_audio_active = false
	_gauge_drain_accumulator = 0.0


func update_input(
	input_snapshot: Dictionary,
	current_msec: int,
	special_gauge: float,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	_last_player_pos = player_pos
	_last_player_size = _get_player_size(config)
	var result := {
		"special_gauge": special_gauge,
		"charging": charging,
		"activated": false,
	}
	var up_held: bool = bool(input_snapshot.get("up_pressed", false))
	var blocked: bool = _is_input_blocked(config, deps)
	if blocked:
		if charging and gauge_consumed > 0.0:
			result["special_gauge"] = _fire_wave(float(result["special_gauge"]), player_pos, current_msec, deps)
			result["activated"] = true
		_stop_charging()
		_sync_charge_audio(deps)
		result["charging"] = charging
		return result

	if up_held:
		if not charging:
			if not _can_start_charge(float(result["special_gauge"]), current_msec, deps):
				_sync_charge_audio(deps)
				return result
			charging = true
			charge_time_frames = 0.0
			gauge_consumed = 0.0
			charge_size = 0.0
			charge_particles.clear()
		else:
			charge_time_frames += 1.0
			var drain_per_frame: float = CHARGE_DRAIN_AMOUNT / CHARGE_DRAIN_INTERVAL_FRAMES
			if float(result["special_gauge"]) >= drain_per_frame:
				result["special_gauge"] = max(0.0, float(result["special_gauge"]) - drain_per_frame)
				gauge_consumed += drain_per_frame
			else:
				if gauge_consumed > 0.0:
					result["special_gauge"] = _fire_wave(float(result["special_gauge"]), player_pos, current_msec, deps)
					result["activated"] = true
				_stop_charging()
				_sync_charge_audio(deps)
				result["charging"] = charging
				return result
			charge_size = min(1.0, charge_time_frames / MAX_CHARGE_FRAMES)
			if int(charge_time_frames) % 2 == 0:
				_spawn_charge_particle()
	else:
		if charging:
			if charge_time_frames >= MIN_CHARGE_FRAMES and gauge_consumed > 0.0:
				result["special_gauge"] = _fire_wave(float(result["special_gauge"]), player_pos, current_msec, deps)
				result["activated"] = true
			elif gauge_consumed > 0.0:
				var gauge_max: float = max(1.0, float(config.get("gauge_max", 500.0)))
				result["special_gauge"] = min(gauge_max, float(result["special_gauge"]) + gauge_consumed)
			_stop_charging()

	_sync_charge_audio(deps)
	result["charging"] = charging
	return result


func update_effects(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	_last_player_pos = _get_vector2(context, "player_pos", _last_player_pos)
	_last_player_size = _get_vector2(context, "player_paddle_size", _last_player_size)
	_last_boss_pos = _get_vector2(context, "boss_pos", _last_boss_pos)
	_last_boss_size = Vector2(
		max(1.0, float(context.get("boss_paddle_width", _last_boss_size.x))),
		max(1.0, float(context.get("boss_hitbox_height", _last_boss_size.y)))
	)
	_update_charge_particles(fps_scale)
	_update_wave(fps_scale, context, deps)
	_update_wave_fade(fps_scale)
	_update_contact_distortion(fps_scale)
	_sync_charge_audio(deps)
	_sync_shock_audio(deps)


func get_boss_ai_context() -> Dictionary:
	return {
		"smasher_plasma_boss_slow_active": boss_slowed,
		"smasher_plasma_boss_slow_multiplier": 1.0 - boss_slow_amount if boss_slowed else 1.0,
	}


func get_draw_context() -> Dictionary:
	return {
		"smasher_plasma_charging": charging,
		"smasher_plasma_charge_size": charge_size,
		"smasher_plasma_charge_particles": charge_particles,
		"smasher_plasma_wave_active": wave_active,
		"smasher_plasma_wave_pos": wave_pos,
		"smasher_plasma_wave_radius": wave_radius,
		"smasher_plasma_wave_slow_amount": wave_slow_amount,
		"smasher_plasma_wave_trail": wave_trail,
		"smasher_plasma_wave_particles": wave_particles,
		"smasher_plasma_boss_slowed": boss_slowed,
		"smasher_plasma_boss_slow_amount": boss_slow_amount,
		"smasher_plasma_contact_distortion": plasma_contact_distortion,
	}


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if charging:
		_draw_charge_field(canvas, shake_offset, now)
	if wave_active:
		_draw_wave(canvas, shake_offset, now)
	if boss_slowed or plasma_contact_distortion > 0.01:
		_draw_boss_contact_overlay(canvas, shake_offset, now)


# 라이브 경로: 구체 본체는 3-피스 모듈러 FX 호스트가 그리고, 절차 draw는
# 보스 접촉 오버레이만 유지한다(full draw()는 폴백/스모크 호환용 보존).
func draw_contact_overlay(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	if boss_slowed or plasma_contact_distortion > 0.01:
		_draw_boss_contact_overlay(canvas, shake_offset, Time.get_ticks_msec() / 1000.0)


func is_charging() -> bool:
	return charging


func is_wave_active() -> bool:
	return wave_active


func is_boss_slowed() -> bool:
	return boss_slowed


func has_visible_effects() -> bool:
	return (
		charging
		or wave_active
		or boss_slowed
		or plasma_contact_distortion > 0.01
		or not charge_particles.is_empty()
		or not wave_trail.is_empty()
		or not wave_particles.is_empty()
		or wave_fade_timer_frames > 0.0
	)


func needs_effect_update() -> bool:
	return has_visible_effects()


func _can_start_charge(special_gauge: float, current_msec: int, deps: Dictionary) -> bool:
	if wave_active:
		return false
	if special_gauge < MIN_GAUGE_COST:
		return false
	if not _is_skill_equipped(deps.get("skill_config", null)):
		return false
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state != null and skill_state.has_method("get_configured_cooldown_remaining"):
		if float(skill_state.get_configured_cooldown_remaining(SKILL_NAME, current_msec, deps.get("skill_config", null))) > 0.0:
			return false
	return true


func _is_input_blocked(config: Dictionary, deps: Dictionary) -> bool:
	var round_state: Object = deps.get("round_state", null)
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return true
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var dash_snapshot: Dictionary = dash_state.get_snapshot()
		if bool(dash_snapshot.get("active", false)) or bool(dash_snapshot.get("recovering", false)):
			return true
	var power_state: Object = deps.get("power_state", null)
	if power_state != null:
		if power_state.has_method("is_freeze_active") and bool(power_state.is_freeze_active()):
			return true
		if power_state.has_method("is_parabola_active") and bool(power_state.is_parabola_active()):
			return true
		if power_state.has_method("is_ghost_shot_motion_active") and bool(power_state.is_ghost_shot_motion_active()):
			return true
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("is_player_control_locked"):
		if bool(active_item_runtime.is_player_control_locked()):
			return true
	return not bool(config.get("ball_active", false))


func _fire_wave(special_gauge: float, player_pos: Vector2, current_msec: int, deps: Dictionary) -> float:
	if wave_active:
		return special_gauge
	var next_gauge: float = special_gauge
	if gauge_consumed < MIN_GAUGE_COST:
		var additional_drain: float = MIN_GAUGE_COST - gauge_consumed
		if next_gauge >= additional_drain:
			next_gauge = max(0.0, next_gauge - additional_drain)
			gauge_consumed = MIN_GAUGE_COST

	var player_size: Vector2 = _last_player_size
	wave_pos = Vector2(player_pos.x + player_size.x * 0.5, player_pos.y - 20.0)
	wave_radius = WAVE_BASE_RADIUS + (WAVE_MAX_RADIUS - WAVE_BASE_RADIUS) * charge_size
	var charge_ticks: float = floor(gauge_consumed / CHARGE_DRAIN_AMOUNT)
	wave_slow_amount = min(MAX_SLOW_AMOUNT, BASE_SLOW_AMOUNT + charge_ticks * SLOW_PER_CHARGE_TICK)
	# 차징 비례 감속(최대 60%): 큰 구체일수록 느리고 묵직하게. 수명을
	# 역비례로 늘려 도달거리는 불변 — 소멸은 위치 조건이 소유한다.
	wave_speed = WAVE_SPEED * (1.0 - WAVE_CHARGE_SLOWDOWN_MAX * charge_size)
	wave_enraged = charge_size >= ENRAGED_CHARGE_THRESHOLD
	wave_fade_timer_frames = 0.0
	wave_timer_frames = WAVE_DURATION_FRAMES * (WAVE_SPEED / maxf(0.1, wave_speed))
	wave_active = true
	wave_trail.clear()
	wave_particles.clear()
	_gauge_drain_accumulator = 0.0
	_trigger_cooldown(current_msec, deps)
	_play_shoot_sound(deps)
	return next_gauge


func _stop_charging() -> void:
	charging = false
	charge_time_frames = 0.0
	gauge_consumed = 0.0
	charge_size = 0.0
	charge_particles.clear()


func _update_wave(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if not wave_active:
		if boss_slowed and boss_slow_timer_frames <= 0.0:
			boss_slowed = false
			boss_slow_amount = 0.0
			_clear_shared_boss_slow(deps)
		shock_audio_active = false
		return

	var speed: float = wave_speed * 0.5 if boss_slowed else wave_speed
	wave_pos.y -= speed * fps_scale
	var boss_center_x: float = _last_boss_pos.x + _last_boss_size.x * 0.5
	var dx: float = boss_center_x - wave_pos.x
	if abs(dx) > 2.0:
		wave_pos.x += sign(dx) * WAVE_HOMING_SPEED * fps_scale

	if wave_trail.is_empty() or int(wave_timer_frames) % 3 == 0:
		wave_trail.append({
			"pos": wave_pos,
			"radius": wave_radius,
			"alpha": 0.47,
		})
	_update_wave_trail(fps_scale)
	_spawn_wave_particle()
	_update_wave_particles(fps_scale)

	var boss_in_plasma: bool = _is_boss_inside_wave()
	if boss_in_plasma:
		boss_slowed = true
		boss_slow_amount = wave_slow_amount
		boss_slow_timer_frames = BOSS_SLOW_REFRESH_FRAMES
		_apply_shared_boss_slow(deps)
		shock_audio_active = true
		_drain_boss_gauge(fps_scale, context, deps)
	else:
		shock_audio_active = false
		if boss_slowed and boss_slow_timer_frames > 0.0:
			boss_slow_timer_frames = max(0.0, boss_slow_timer_frames - fps_scale)
			if boss_slow_timer_frames <= 0.0:
				boss_slowed = false
				boss_slow_amount = 0.0
				_clear_shared_boss_slow(deps)

	wave_timer_frames = max(0.0, wave_timer_frames - fps_scale)
	if wave_pos.y < -wave_radius or wave_timer_frames <= 0.0:
		_clear_wave(deps)


func _clear_wave(deps: Dictionary = {}) -> void:
	# 릴리즈 테일: 파동 종료 시 12프레임 fade 페이즈(비주얼 전용)로 넘겨
	# FX 호스트가 뚝 끊기지 않게 한다.
	if wave_active:
		wave_fade_timer_frames = WAVE_FADE_FRAMES
		wave_fade_pos = wave_pos
		wave_fade_radius = wave_radius
		wave_fade_enraged = wave_enraged
	wave_active = false
	wave_trail.clear()
	wave_particles.clear()
	boss_slowed = false
	boss_slow_amount = 0.0
	boss_slow_timer_frames = 0.0
	_clear_shared_boss_slow(deps)
	shock_audio_active = false
	_gauge_drain_accumulator = 0.0


func _apply_shared_boss_slow(deps: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null or not status_effect_state.has_method("apply_status"):
		return
	status_effect_state.apply_status(
		"boss",
		"slow",
		BOSS_SLOW_REFRESH_FRAMES,
		{
			"multiplier": clamp(1.0 - boss_slow_amount, 0.0, 1.0),
			"source": PLASMA_SLOW_SOURCE,
			"suppress_legacy_boss_ai_slow": true,
			"visual_variant": "plasma",
			"label": "플라즈마",
		},
		PLASMA_SLOW_SOURCE
	)


func _clear_shared_boss_slow(deps: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null or not status_effect_state.has_method("clear_status"):
		return
	status_effect_state.clear_status("boss", "slow", PLASMA_SLOW_SOURCE)


func _is_boss_inside_wave() -> bool:
	var boss_center := Vector2(
		_last_boss_pos.x + _last_boss_size.x * 0.5,
		_last_boss_pos.y + _last_boss_size.y * 0.5
	)
	var collision_radius: float = wave_radius + max(_last_boss_size.x, _last_boss_size.y) * 0.5
	return wave_pos.distance_squared_to(boss_center) < collision_radius * collision_radius


func _drain_boss_gauge(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	_gauge_drain_accumulator += 0.5 * fps_scale
	if _gauge_drain_accumulator < 1.0:
		return
	var amount: int = int(_gauge_drain_accumulator)
	_gauge_drain_accumulator -= float(amount)
	var current_stage: int = int(deps.get("current_stage", context.get("current_stage", 1)))
	if current_stage == HONGRYUN_STAGE_ID:
		_drain_hongryun_orb_gauge(float(amount), deps)
		return
	_drain_boss_special_gauge(float(amount), current_stage, deps)


func _drain_boss_special_gauge(amount: float, current_stage: int, deps: Dictionary) -> bool:
	if amount <= 0.0:
		return false
	var state_keys: Array[String] = []
	match current_stage:
		1:
			state_keys = ["stage1_dalji_whip_skill_state"]
		2:
			state_keys = ["stage2_boss_skill_state"]
		3:
			state_keys = ["stage3_boss_skill_state"]
		4:
			state_keys = ["stage4_ponk_skill_state"]
		_:
			state_keys = [
				"stage1_dalji_whip_skill_state",
				"stage2_boss_skill_state",
				"stage3_boss_skill_state",
				"stage4_ponk_skill_state",
			]
	for key in state_keys:
		var state: Object = deps.get(key, null)
		if _drain_state_boss_special_gauge(state, amount):
			return true
	var registry: Object = deps.get("registry", null)
	for key in state_keys:
		if registry != null and registry.has_method("get_instance"):
			if _drain_state_boss_special_gauge(registry.get_instance(key), amount):
				return true
	return false


func _drain_state_boss_special_gauge(state: Object, amount: float) -> bool:
	if state == null:
		return false
	if state.has_method("drain_boss_special_gauge"):
		state.drain_boss_special_gauge(amount)
		return true
	var current_value: Variant = state.get("boss_special_gauge")
	if current_value == null:
		return false
	state.set("boss_special_gauge", max(0.0, float(current_value) - amount))
	return true


func _drain_hongryun_orb_gauge(amount: float, deps: Dictionary) -> bool:
	if amount <= 0.0:
		return false
	var state_keys: Array[String] = [
		"stage5_hongryun_state",
		"stage6_hongryun_state",
		"hongryun_boss_skill_state",
		"stage_background",
	]
	for key in state_keys:
		var state: Object = deps.get(key, null)
		if _drain_state_hongryun_orb_gauge(state, amount):
			return true
	var registry: Object = deps.get("registry", null)
	for key in state_keys:
		if registry != null and registry.has_method("get_instance"):
			if _drain_state_hongryun_orb_gauge(registry.get_instance(key), amount):
				return true
	return false


func _drain_state_hongryun_orb_gauge(state: Object, amount: float) -> bool:
	if state == null:
		return false
	if state.has_method("drain_hongryun_orb_gauge"):
		state.drain_hongryun_orb_gauge(amount)
		return true
	if state.has_method("drain_hongryun_hit_count"):
		state.drain_hongryun_hit_count(amount)
		return true
	var current_value: Variant = state.get("hongryun_hit_count")
	if current_value == null:
		return false
	state.set("hongryun_hit_count", max(0.0, float(current_value) - amount))
	var max_hits: Variant = state.get("hongryun_max_hits")
	if max_hits != null and state.get("hongryun_ready") != null and float(state.get("hongryun_hit_count")) < float(max_hits):
		state.set("hongryun_ready", false)
	return true


func _update_charge_particles(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(charge_particles.size()):
		var particle: Dictionary = charge_particles[read_index]
		var life: float = float(particle.get("life", 30.0)) - fps_scale
		if life <= 0.0:
			continue
		particle["life"] = life
		particle["angle"] = float(particle.get("angle", 0.0)) + float(particle.get("speed", 1.0)) * 0.10 * fps_scale
		particle["dist"] = float(particle.get("dist", 5.0)) + 0.5 * fps_scale
		charge_particles[write_index] = particle
		write_index += 1
	if write_index < charge_particles.size():
		charge_particles.resize(write_index)


func _spawn_charge_particle() -> void:
	charge_particles.append({
		"angle": randf_range(0.0, TAU),
		"dist": randf_range(5.0, 15.0),
		"alpha": randf_range(0.58, 1.0),
		"speed": randf_range(0.5, 1.5),
		"life": 30.0,
	})
	if charge_particles.size() > MAX_CHARGE_PARTICLES:
		charge_particles.pop_front()


func _spawn_wave_particle() -> void:
	if randf() >= WAVE_PARTICLE_SPAWN_CHANCE:
		return
	var angle: float = randf_range(0.0, TAU)
	var dist: float = randf_range(0.0, wave_radius * 0.8)
	wave_particles.append({
		"pos": wave_pos + Vector2(cos(angle), sin(angle)) * dist,
		"vel": Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)),
		"life": 25.0,
		"alpha": 0.78,
	})
	if wave_particles.size() > MAX_WAVE_PARTICLES:
		wave_particles.pop_front()


func _update_wave_particles(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(wave_particles.size()):
		var particle: Dictionary = wave_particles[read_index]
		var life: float = float(particle.get("life", 0.0)) - fps_scale
		if life <= 0.0:
			continue
		var alpha: float = max(0.0, float(particle.get("alpha", 0.0)) - 0.031 * fps_scale)
		particle["pos"] = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + _as_vector2(particle.get("vel", Vector2.ZERO), Vector2.ZERO) * fps_scale
		particle["life"] = life
		particle["alpha"] = alpha
		wave_particles[write_index] = particle
		write_index += 1
	if write_index < wave_particles.size():
		wave_particles.resize(write_index)


func _update_wave_trail(fps_scale: float) -> void:
	var write_index := 0
	for read_index in range(wave_trail.size()):
		var trail: Dictionary = wave_trail[read_index]
		var alpha: float = float(trail.get("alpha", 0.0)) - 0.047 * fps_scale
		if alpha <= 0.0:
			continue
		trail["alpha"] = alpha
		wave_trail[write_index] = trail
		write_index += 1
	if write_index < wave_trail.size():
		wave_trail.resize(write_index)


func _update_contact_distortion(fps_scale: float) -> void:
	if boss_slowed and wave_active:
		plasma_contact_distortion = min(1.0, plasma_contact_distortion + CONTACT_DISTORTION_GAIN * fps_scale)
	else:
		plasma_contact_distortion = max(0.0, plasma_contact_distortion - CONTACT_DISTORTION_DECAY * fps_scale)


func _draw_charge_field(canvas: CanvasItem, shake_offset: Vector2, now: float) -> void:
	var center: Vector2 = _last_player_pos + Vector2(_last_player_size.x * 0.5, _last_player_size.y * 0.5 - 10.0) + shake_offset
	var radius: float = FIELD_MIN_RADIUS + (FIELD_MAX_RADIUS - FIELD_MIN_RADIUS) * charge_size
	var pulse: float = 0.5 + 0.5 * sin(now * 9.0)
	ImpactFlareTextureCache.draw_glow(
		canvas,
		center,
		radius * 0.98,
		Color(0.35, 0.72, 1.0),
		(0.16 + charge_size * 0.18) * (0.82 + pulse * 0.18)
	)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius + 8.0, Color(0.42, 0.82, 1.0), 0.18 + charge_size * 0.22)
	if charge_size > 0.35:
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius * 0.62, Color(0.82, 0.95, 1.0), 0.12 + charge_size * 0.16)
	var spark_count: int = 1 + int(charge_size * 2.0)
	for i in range(spark_count):
		var spark_angle: float = now * 7.0 + float(i) * TAU / float(max(1, spark_count)) + sin(now * 18.0 + float(i)) * 0.5
		var start_pos: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle)) * radius * 0.85
		var spark_extension: float = 1.04 + (0.04 + 0.08 * (0.5 + 0.5 * sin(now * 11.0 + float(i) * 2.17))) * charge_size
		var end_pos: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle)) * (radius * spark_extension)
		canvas.draw_line(start_pos, end_pos, Color(0.52, 0.86, 1.0, 0.32), 1.0)
	var core_radius: float = max(3.0, radius * 0.08 * (0.85 + 0.15 * sin(now * 15.0)))
	ImpactFlareTextureCache.draw_sparkle(canvas, center, core_radius + 6.0, Color(0.82, 0.95, 1.0), 0.42 + charge_size * 0.18)
	for particle in charge_particles:
		var angle: float = float(particle.get("angle", 0.0))
		var dist: float = float(particle.get("dist", 0.0)) * charge_size * 2.0
		var life: float = clamp(float(particle.get("life", 0.0)) / 30.0, 0.0, 1.0)
		var alpha: float = float(particle.get("alpha", 1.0)) * life * 0.34
		ImpactFlareTextureCache.draw_sparkle(canvas, center + Vector2(cos(angle), sin(angle)) * dist, 3.2, Color(0.42, 0.82, 1.0), alpha * 0.55)


func _draw_wave(canvas: CanvasItem, shake_offset: Vector2, now: float) -> void:
	for trail in wave_trail:
		var pos: Vector2 = _as_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius: float = float(trail.get("radius", wave_radius))
		var alpha: float = float(trail.get("alpha", 0.0)) * 0.4
		ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius, Color(0.36, 0.74, 1.0), alpha * 0.42)

	var center: Vector2 = wave_pos + shake_offset
	var pulse: float = 0.92 + 0.08 * sin(now * 25.0)
	var fast_pulse: float = 0.95 + 0.05 * sin(now * 80.0)
	var main_radius: float = max(3.0, wave_radius * pulse)
	ImpactFlareTextureCache.draw_glow(canvas, center, main_radius * 0.88, Color(0.18, 0.50, 0.95), 0.13 * fast_pulse)
	for layer in range(2):
		var ring_radius: float = main_radius - float(layer) * 10.0
		if ring_radius > 5.0:
			ImpactShockwaveTextureCache.draw_full_ring(canvas, center, ring_radius, Color(0.34 + float(layer) * 0.07, 0.78, 1.0), (0.22 - float(layer) * 0.055) * fast_pulse)
	var outer_arcs: int = 3 + int(wave_slow_amount * 2.0)
	for i in range(outer_arcs):
		var angle: float = now * 10.0 + float(i) * TAU / float(max(1, outer_arcs)) + sin(now * 40.0 + float(i)) * 0.4
		var points := PackedVector2Array()
		for j in range(3):
			var t: float = float(j) / 2.0
			var dist_noise: float = 0.5 + 0.5 * sin(now * 13.0 + float(i) * 1.71 + float(j) * 0.9)
			var dist: float = main_radius * (0.90 + t * (0.25 + 0.22 * dist_noise))
			var jitter: float = pow(t, 1.5) * 0.16 * sin(now * 17.0 + float(i) * 2.3 + float(j))
			points.append(center + Vector2(cos(angle + jitter), sin(angle + jitter)) * dist)
		canvas.draw_polyline(points, Color(0.58, 0.88, 1.0, 0.48), 1.4, true)
	var core_radius: float = max(3.0, main_radius * 0.15 * fast_pulse)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, core_radius + 6.0, Color(0.80, 0.94, 1.0), 0.46 * fast_pulse)
	for particle in wave_particles:
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, 3.0, Color(0.55, 0.84, 1.0), alpha * 0.48)


func _draw_boss_contact_overlay(canvas: CanvasItem, shake_offset: Vector2, now: float) -> void:
	var strength: float = max(plasma_contact_distortion, boss_slow_amount * 0.55)
	if strength <= 0.01:
		return
	var rect := Rect2(_last_boss_pos + shake_offset, _last_boss_size)
	var center: Vector2 = rect.get_center()
	var radius: float = max(rect.size.x, rect.size.y) * (0.70 + 0.06 * sin(now * 18.0))
	ImpactFlareTextureCache.draw_glow(canvas, center, radius, Color(0.35, 0.85, 1.0), 0.10 * strength)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius, Color(0.68, 0.94, 1.0), 0.30 * strength)
	for i in range(2):
		var angle: float = now * 9.0 + float(i) * TAU * 0.5
		var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.45
		var end_pos: Vector2 = center + Vector2(cos(angle + 0.18 * sin(now * 13.0 + float(i))), sin(angle + 0.18 * sin(now * 13.0 + float(i)))) * radius
		canvas.draw_line(start_pos, end_pos, Color(0.76, 0.96, 1.0, 0.28 * strength), 1.2)


func _trigger_cooldown(current_msec: int, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("trigger_cooldown"):
		return
	var seconds: float = _charge_scaled_cooldown_seconds(charge_size)
	# 런타임/아이템 쿨감 배수는 configured 경로와 같은 실효 배수로 승계한다
	# (configured/base 비율 — 배수 소스가 늘어도 이 비율이 전부 담는다).
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		var base: float = 8.0
		var configured: float = float(skill_config.get_cooldown_seconds(SKILL_NAME))
		if base > 0.0 and configured > 0.0:
			seconds *= configured / base
	skill_state.trigger_cooldown(SKILL_NAME, current_msec, seconds)


# 차징 비례 쿨타임: 발사가능 최소 차징(MIN/MAX_CHARGE_FRAMES=1/6)=3초,
# 최대 차징=15초 선형 보간.
func _charge_scaled_cooldown_seconds(charge: float) -> float:
	var min_charge: float = MIN_CHARGE_FRAMES / MAX_CHARGE_FRAMES
	var charge_t: float = clampf((charge - min_charge) / maxf(0.001, 1.0 - min_charge), 0.0, 1.0)
	return lerpf(COOLDOWN_MIN_SECONDS, COOLDOWN_MAX_SECONDS, charge_t)


# FX 호스트 피드(3-피스 모듈러 VFX): phase/pos(플레이필드 px)/radius/
# intensity/enraged. 드로어가 스크린 좌표 변환을 소유한다.
func _update_wave_fade(fps_scale: float) -> void:
	if wave_fade_timer_frames > 0.0:
		wave_fade_timer_frames = maxf(0.0, wave_fade_timer_frames - maxf(0.0, fps_scale))


func get_plasma_fx_state(shake_offset: Vector2 = Vector2.ZERO) -> Dictionary:
	if charging:
		var charge_center := Vector2(
			_last_player_pos.x + _last_player_size.x * 0.5,
			_last_player_pos.y - 20.0
		)
		return {
			"phase": "charge",
			"phase_active": true,
			"pos": charge_center + shake_offset,
			"radius": FIELD_MIN_RADIUS + (FIELD_MAX_RADIUS - FIELD_MIN_RADIUS) * charge_size,
			"intensity": charge_size,
			"enraged": charge_size >= ENRAGED_CHARGE_THRESHOLD,
		}
	if wave_active:
		return {
			"phase": "wave",
			"phase_active": true,
			"pos": wave_pos + shake_offset,
			"radius": wave_radius,
			"intensity": maxf(0.6, wave_slow_amount),
			"enraged": wave_enraged,
		}
	if wave_fade_timer_frames > 0.0:
		var fade_t: float = wave_fade_timer_frames / WAVE_FADE_FRAMES
		return {
			"phase": "fade",
			"phase_active": true,
			"pos": wave_fade_pos + shake_offset,
			"radius": wave_fade_radius,
			"intensity": 0.6 * fade_t,
			"enraged": wave_fade_enraged,
		}
	return {
		"phase": "idle",
		"phase_active": false,
		"pos": Vector2.ZERO,
		"radius": 0.0,
		"intensity": 0.0,
		"enraged": false,
	}


func _play_shoot_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_plasma_shoot"):
		audio.play_plasma_shoot()


func _sync_charge_audio(deps: Dictionary) -> void:
	charge_audio_active = charging
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_plasma_charge"):
		audio.sync_plasma_charge(charge_audio_active)


func _sync_shock_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("sync_plasma_shock"):
		audio.sync_plasma_shock(shock_audio_active)


func _is_skill_equipped(skill_config: Object) -> bool:
	if skill_config != null and skill_config.has_method("is_skill_equipped"):
		return bool(skill_config.is_skill_equipped(SKILL_NAME))
	return false


func _get_player_size(source: Dictionary) -> Vector2:
	return Vector2(
		max(1.0, float(source.get("paddle_width", source.get("player_paddle_width", 155.0)))),
		max(1.0, float(source.get("paddle_height", source.get("player_paddle_height", 50.0))))
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
