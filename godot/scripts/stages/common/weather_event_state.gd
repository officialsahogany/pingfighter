extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const WeatherEventPayloadFactory := preload("res://scripts/stages/common/weather_event_payload_factory.gd")
const WeatherEventRenderBudget := preload("res://scripts/stages/common/weather_event_render_budget.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

const WEATHER_TYPES := ["breeze", "gust", "fire", "ice", "rain", "hail", "sand"]
const WEATHER_DURATION_WEIGHTS := [1, 1, 1, 1, 1, 2, 2, 2, 3, 3]
const WEATHER_EVENT_PROBABILITY := 0.10
const WEATHER_RENDER_PARTICLE_LIMIT := WeatherEventRenderBudget.WEATHER_RENDER_PARTICLE_LIMIT
const WIND_RENDER_PARTICLE_LIMIT := WeatherEventRenderBudget.WIND_RENDER_PARTICLE_LIMIT
const LOD_ACTIVE_THRESHOLD := WeatherEventRenderBudget.LOD_ACTIVE_THRESHOLD
const SEVERE_LOD_ACTIVE_THRESHOLD := WeatherEventRenderBudget.SEVERE_LOD_ACTIVE_THRESHOLD
const WEATHER_RENDER_PARTICLE_LIMIT_LOD := WeatherEventRenderBudget.WEATHER_RENDER_PARTICLE_LIMIT_LOD
const WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD := WeatherEventRenderBudget.WEATHER_RENDER_PARTICLE_LIMIT_SEVERE_LOD
# Wind is the cheapest weather effect (one streak per particle), so keep it near-full
# even under render LOD. Decimating wind to ~12 made the flow read as a few blinking
# streaks ("뚝뚝 끊김") for no measurable perf gain.
const WIND_RENDER_PARTICLE_LIMIT_LOD := WeatherEventRenderBudget.WIND_RENDER_PARTICLE_LIMIT_LOD
const WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD := WeatherEventRenderBudget.WIND_RENDER_PARTICLE_LIMIT_SEVERE_LOD
const PARTICLE_RENDER_STRIDE_LOD := WeatherEventRenderBudget.PARTICLE_RENDER_STRIDE_LOD
const PARTICLE_RENDER_STRIDE_SEVERE_LOD := WeatherEventRenderBudget.PARTICLE_RENDER_STRIDE_SEVERE_LOD
const BREEZE_VISUAL_PARTICLE_TARGET := 28
const GUST_VISUAL_PARTICLE_TARGET := 34
const WARNING_FRAMES := 180.0
const END_FRAMES := 180.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BREEZE_WIND_FORCE_PLAYER := 1.2
const BREEZE_WIND_FORCE_BOSS := 1.0
const BREEZE_WIND_FORCE_BALL := 0.096
const GUST_WIND_FORCE_PLAYER := 1.8
const GUST_WIND_FORCE_BOSS := 1.5
const GUST_WIND_FORCE_BALL := 0.168
const FIRE_BASE_SPEED_BOOST := 1.07
const FIRE_HIT_SPEED_INCREASE_MULTIPLIER := 2.0
const FIRE_HIT_SPEED_BOOST_MIN := 1.0 + (0.05 * FIRE_HIT_SPEED_INCREASE_MULTIPLIER)
const FIRE_HIT_SPEED_BOOST_MAX := 1.0 + (0.07 * FIRE_HIT_SPEED_INCREASE_MULTIPLIER)
const FIRE_GAUGE_DRAIN_PER_SECOND := 5.0
const FIRE_PADDLE_KNOCKBACK_VELOCITY := 22.0
const FIRE_PADDLE_KNOCKBACK_FRAMES := 36.0
const FIRE_PADDLE_KNOCKBACK_DECAY := 0.85
const FIRE_ICE_KNOCKBACK_DECAY := 0.94
const FIRE_WEATHER_PARTICLE_TARGET := 44
const FIRE_VISUAL_PARTICLE_CAP := 72
const FIRE_HIT_EXPLOSION_PARTICLES := 14
const FIRE_HIT_SPARK_PARTICLES := 8
const ICE_DIRECTION_CHANGE_MULTIPLIER := 0.20
const ICE_ACCELERATION_MULTIPLIER := 0.25
const ICE_DECELERATION_MULTIPLIER := 0.05
const ICE_DASH_SLIDE_INITIAL_SPEED := 25.0
const ICE_DASH_SLIDE_DECAY := 0.96
const ICE_DASH_SLIDE_TRANSITION_TIMER_FRAMES := 20.0
const ICE_BOSS_BLEND := 0.35
const ICE_BOSS_FRICTION := 0.975
const RAIN_SPEED_MULTIPLIER := 0.70
const HAIL_MAX_PARTICLES := 3
const HAIL_SPAWN_INTERVAL_FRAMES := 30.0
const HAIL_HIT_COOLDOWN_FRAMES := 45.0
const HAIL_PLAYER_KNOCKBACK_SPEED := 12.0
const HAIL_PLAYER_STUN_FRAMES := 6.0
const HAIL_KNOCKBACK_DECAY := 0.85
const SAND_SEGMENTS := 64
const SAND_SEG_SIZE := 12.0
const SAND_RENDER_STRIDE_LOD := WeatherEventRenderBudget.SAND_RENDER_STRIDE_LOD
const SAND_RENDER_STRIDE_SEVERE_LOD := WeatherEventRenderBudget.SAND_RENDER_STRIDE_SEVERE_LOD
const SAND_VERTICAL_START := 60.0
const SAND_VERTICAL_END := 690.0
const SAND_HORIZONTAL_START := 40.0
const SAND_HORIZONTAL_END := 720.0
const SAND_DEPTH_MIN := 8.0
const SAND_DEPTH_MAX := 45.0
const SAND_BALL_ERODE_AMOUNT := 30.0
const SAND_BALL_ERODE_RADIUS_SEGS := 6
const SAND_WALK_ERODE_AMOUNT := 0.12
const SAND_WALK_ERODE_RADIUS_SEGS := 2
const SAND_DASH_ERODE_AMOUNT := 6.0
const SAND_DASH_ERODE_RADIUS_SEGS := 2
const SAND_DISSOLVE_FRAMES := 90.0
const SAND_DISSOLVE_PARTICLE_INTERVAL_FRAMES := 3.0
# Kick-up emission is driven by eroded VOLUME rather than a per-frame count, which
# keeps it approximately frame-rate independent (per-frame dash displacement scales
# with fps_scale, and eroded volume tracks displacement). It is not exact: the shared
# _erode_sand_range does ceil(distance / SAND_SEG_SIZE) + 1 un-scaled erode calls, so
# the constant +1 term yields slightly more volume when the same travel is split over
# more, shorter ticks. Erosion is gameplay (sand is a ball collision surface), so that
# term is left alone and the carry below absorbs the difference.
# Raised once the eroded-span and crest gates started rejecting candidates that used to
# be emitted onto bare floor: the visible density is what those gates thinned, and the
# live population still settles well inside the severe-LOD window.
const SAND_DASH_SPRAY_GRAINS_PER_ERODE_UNIT := 0.13
const SAND_DASH_SPRAY_MAX_PER_FRAME := 4
const SAND_WALK_SPRAY_GRAINS_PER_ERODE_UNIT := 0.35
const SAND_WALK_SPRAY_MAX_PER_FRAME := 1
const SAND_SPRAY_MIN_TRAVEL_PX := 0.5
const SAND_SPRAY_SPEED_REFERENCE_PX := 14.0
const SAND_SPRAY_TRAILING_STRIDE := 4
const SAND_SPRAY_MIN_CREST_DEPTH := 1.0
# Every stride the shipped renderer can walk the wall with: full quality, LOD, severe LOD.
const SAND_SPRAY_RENDER_STRIDES: Array[int] = [
	1,
	WeatherEventRenderBudget.SAND_RENDER_STRIDE_LOD,
	WeatherEventRenderBudget.SAND_RENDER_STRIDE_SEVERE_LOD,
]
# Ceiling for the two ACTIVE-weather sand producers (paddle kick-up and ball impact).
# Sand had no cap at all and kick-up is its first PER-FRAME producer, so without one the
# array grows for the whole event: culled-from-render grains still cost a full update +
# draw iteration each. Sized against the SEVERE-LOD window (24), not the full-quality
# one: the shipped render cap is 72, which trips FPS_CAP_LOD_MAX_FPS, so live play is the
# severe budget. A cap far above the window buys nothing but invisible per-tick work and
# evicts other sand bursts sooner (GRT-029).
# NOT applied to the dissolve pulse: that runs in a separate phase with no live producer
# competing, and its authored population is intentionally larger.
const SAND_VISUAL_PARTICLE_CAP := 28

var weather_event_active := false
var weather_event_type := ""
var weather_event_direction := 0
var weather_event_remaining_rounds := 0
var warning_timer_frames := 0.0
var end_timer_frames := 0.0
var warning_text := ""
var end_text := ""
var fire_gauge_drain_accumulator := 0.0
var weather_particles: Array = []
var sand_depths: Array = []
var sand_wall_depths: Dictionary = {}
var sand_collision_active := false
var sand_dissolving := false
var _sand_dissolve_timer := 0.0
var _sand_dissolve_particle_timer := 0.0
var _sand_visual_segments_cache: Array = []
var _sand_visual_segments_dirty := true
var _sand_player_spray_carry := 0.0
var _sand_boss_spray_carry := 0.0
# Grain ordinal persists ACROSS frames. Deriving the wake/bow split from a per-frame
# loop index makes the walk leg (which emits at most one grain per frame) forever pick
# ordinal 0, i.e. the bow-spray slot, so walking would never throw a grain backwards.
var _sand_player_spray_ordinal := 0
var _sand_boss_spray_ordinal := 0
# Sub-span of the last _erode_sand_range sweep that actually removed depth. Plain floats
# rather than a per-frame array: this sits on the physics path.
var _sand_erode_hit_min := INF
var _sand_erode_hit_max := -INF
var _sand_spray_rng := RandomNumberGenerator.new()
var hail_spawn_timer_frames := 0.0
var hail_player_hit_cooldown_frames := 0.0
var hail_destroy_count := 0
var hail_hit_count := 0
var ice_player_slide_active := false
var ice_player_slide_speed := 0.0
var ice_player_slide_direction := 0
var ice_boss_slide_active := false
var ice_boss_slide_speed := 0.0
var ice_boss_slide_direction := 0
var _previous_player_dash_active := false
var _previous_boss_dash_active := false
var _phase := 0.0


func reset() -> void:
	weather_event_active = false
	weather_event_type = ""
	weather_event_direction = 0
	weather_event_remaining_rounds = 0
	warning_timer_frames = 0.0
	end_timer_frames = 0.0
	warning_text = ""
	end_text = ""
	fire_gauge_drain_accumulator = 0.0
	weather_particles.clear()
	sand_depths.clear()
	sand_wall_depths.clear()
	sand_collision_active = false
	sand_dissolving = false
	_sand_dissolve_timer = 0.0
	_sand_dissolve_particle_timer = 0.0
	_reset_sand_spray_carry()
	_mark_sand_visual_dirty()
	hail_spawn_timer_frames = 0.0
	hail_player_hit_cooldown_frames = 0.0
	hail_destroy_count = 0
	hail_hit_count = 0
	_reset_ice_slide_state()


func advance_round_start(owner: Object = null, registry: Object = null) -> Dictionary:
	var context := _build_owner_context(owner)
	var result := {
		"started": false,
		"ended": false,
		"type": weather_event_type,
		"direction": weather_event_direction,
		"remaining_rounds": weather_event_remaining_rounds,
		"message": "",
	}
	if _is_weather_disabled(context):
		force_end_weather_event(owner, registry)
		result["type"] = ""
		result["direction"] = 0
		result["remaining_rounds"] = 0
		return result

	if weather_event_active:
		weather_event_remaining_rounds -= 1
		if weather_event_remaining_rounds <= 0:
			var ended_type := weather_event_type
			force_end_weather_event(owner, registry, ended_type == "sand")
			result["ended"] = true
			result["type"] = ended_type
			result["direction"] = 0
			result["remaining_rounds"] = 0
			result["message"] = end_text
			return result
		result["remaining_rounds"] = weather_event_remaining_rounds
		_sync_owner_and_physics(owner, registry)
		return result

	if randf() >= WEATHER_EVENT_PROBABILITY:
		_sync_owner_and_physics(owner, registry)
		return result

	var next_type: String = WEATHER_TYPES[randi() % WEATHER_TYPES.size()]
	var start_result: Dictionary = force_start_weather_event(next_type, 0, 0, owner, registry)
	result.merge(start_result, true)
	return result


func force_start_weather_event(
	next_type: String,
	duration_rounds: int = 0,
	direction: int = 0,
	owner: Object = null,
	registry: Object = null
) -> Dictionary:
	if not WEATHER_TYPES.has(next_type):
		return {
			"started": false,
			"ended": false,
			"type": "",
			"direction": 0,
			"remaining_rounds": 0,
			"message": "",
		}
	weather_event_active = true
	weather_event_type = next_type
	weather_event_direction = _roll_wind_direction(direction)
	weather_event_remaining_rounds = _resolve_duration(next_type, duration_rounds)
	warning_timer_frames = WARNING_FRAMES
	end_timer_frames = 0.0
	warning_text = _get_start_text(next_type, weather_event_direction)
	end_text = ""
	fire_gauge_drain_accumulator = 0.0
	weather_particles.clear()
	sand_depths.clear()
	sand_wall_depths.clear()
	sand_collision_active = false
	_reset_sand_spray_carry()
	_mark_sand_visual_dirty()
	hail_spawn_timer_frames = 0.0
	hail_player_hit_cooldown_frames = 0.0
	hail_destroy_count = 0
	hail_hit_count = 0
	_reset_ice_slide_state()
	if next_type == "sand":
		_build_sand_wall()
	_sync_owner_and_physics(owner, registry)
	return {
		"started": true,
		"ended": false,
		"type": weather_event_type,
		"direction": weather_event_direction,
		"remaining_rounds": weather_event_remaining_rounds,
		"message": warning_text,
	}


func force_end_weather_event(
	owner: Object = null,
	registry: Object = null,
	dissolve_sand: bool = false
) -> bool:
	var had_weather := weather_event_active or weather_event_type != "" or not weather_particles.is_empty()
	var ended_type := weather_event_type
	var keep_sand_for_dissolve: bool = (
		dissolve_sand
		and ended_type == "sand"
		and not sand_wall_depths.is_empty()
	)
	weather_event_active = false
	weather_event_type = ""
	weather_event_direction = 0
	weather_event_remaining_rounds = 0
	warning_timer_frames = 0.0
	end_timer_frames = END_FRAMES if ended_type != "" else 0.0
	end_text = _get_end_text(ended_type)
	fire_gauge_drain_accumulator = 0.0
	if keep_sand_for_dissolve:
		_clear_non_sand_particles()
		sand_collision_active = false
		sand_dissolving = true
		_sand_dissolve_timer = SAND_DISSOLVE_FRAMES
		_sand_dissolve_particle_timer = 0.0
		_mark_sand_visual_dirty()
	else:
		weather_particles.clear()
		sand_depths.clear()
		sand_wall_depths.clear()
		sand_collision_active = false
		sand_dissolving = false
		_sand_dissolve_timer = 0.0
		_sand_dissolve_particle_timer = 0.0
		_mark_sand_visual_dirty()
	hail_spawn_timer_frames = 0.0
	hail_player_hit_cooldown_frames = 0.0
	_reset_sand_spray_carry()
	_reset_ice_slide_state()
	_sync_owner_and_physics(owner, registry)
	return had_weather


func debug_cycle_weather_event(owner: Object = null, registry: Object = null) -> Dictionary:
	var current_type: String = get_weather_type()
	if current_type == "":
		return _debug_force_weather_type(WEATHER_TYPES[0], owner, registry)

	var current_index: int = WEATHER_TYPES.find(current_type)
	if current_index < 0 or current_index >= WEATHER_TYPES.size() - 1:
		var ended: bool = force_end_weather_event(owner, registry)
		return {
			"handled": true,
			"started": false,
			"ended": ended,
			"type": current_type,
			"next_type": "",
			"remaining_rounds": 0,
		}

	return _debug_force_weather_type(WEATHER_TYPES[current_index + 1], owner, registry)


func debug_force_weather_event(next_type: String, owner: Object = null, registry: Object = null) -> Dictionary:
	if next_type == "":
		var ended: bool = force_end_weather_event(owner, registry)
		return {
			"handled": true,
			"started": false,
			"ended": ended,
			"type": "",
			"next_type": "",
			"remaining_rounds": 0,
		}
	if not WEATHER_TYPES.has(next_type):
		return {
			"handled": false,
			"started": false,
			"ended": false,
			"type": get_weather_type(),
			"next_type": next_type,
			"remaining_rounds": weather_event_remaining_rounds,
		}
	return _debug_force_weather_type(next_type, owner, registry)


func update(owner: Object, registry: Object, delta: float) -> void:
	var fps_scale: float = max(0.0, delta * 60.0)
	_phase += fps_scale
	warning_timer_frames = max(0.0, warning_timer_frames - fps_scale)
	end_timer_frames = max(0.0, end_timer_frames - fps_scale)
	if weather_event_active:
		_spawn_weather_particles(fps_scale)
		_apply_fire_gauge_drain(owner, fps_scale)
	else:
		fire_gauge_drain_accumulator = 0.0
	_update_sand_dissolve(fps_scale)
	_update_weather_particles(fps_scale)
	_update_hail_collision(owner, registry, fps_scale)
	_sync_owner_and_physics(owner, registry)


func _debug_force_weather_type(next_type: String, owner: Object, registry: Object) -> Dictionary:
	var result: Dictionary = force_start_weather_event(next_type, 3, 1, owner, registry)
	result["handled"] = true
	result["next_type"] = next_type
	return result


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, effect_lod_scale: float = 1.0) -> void:
	if canvas == null:
		return
	_draw_sand(canvas, shake_offset, effect_lod_scale)
	var particle_start: int = max(0, weather_particles.size() - _get_render_particle_limit(effect_lod_scale))
	var particle_stride: int = _get_particle_render_stride_for_type(weather_event_type, effect_lod_scale)
	# Iterate from 0 (not particle_start): the window/stride cutoff is deferred to the
	# shared helper so core sparse particles (falling hail stones) are never evicted by
	# a transient debris burst. See WeatherEventRenderBudget.should_skip_windowed_particle.
	for particle_index in range(0, weather_particles.size()):
		var value: Variant = weather_particles[particle_index]
		var particle: Dictionary = _get_dict(value)
		var kind := str(particle.get("kind", "dust"))
		if WeatherEventRenderBudget.should_skip_windowed_particle(
			weather_event_type, kind, particle_index, particle_start, particle_stride
		):
			continue
		var pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var alpha: float = clamp(float(particle.get("life", 1.0)) / max(0.001, float(particle.get("max_life", 1.0))), 0.0, 1.0)
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		color.a *= alpha
		match kind:
			"rain":
				var tail := pos - Vector2(float(particle.get("wind", 0.0)), float(particle.get("length", 12.0)))
				canvas.draw_line(tail, pos, color, 2.0)
			"hail":
				var hail_size: float = float(particle.get("size", 7.0))
				var hail_alpha: float = clamp(alpha, 0.36, 1.0)
				canvas.draw_circle(pos + Vector2(1.6, 2.0), hail_size + 3.2, Color(0.015, 0.035, 0.075, 0.48 * hail_alpha))
				canvas.draw_circle(pos, hail_size + 2.0, Color(0.10, 0.25, 0.42, 0.54 * hail_alpha))
				canvas.draw_circle(pos, hail_size, Color(color.r, color.g, color.b, 0.94 * hail_alpha))
				canvas.draw_circle(pos + Vector2(-hail_size * 0.24, -hail_size * 0.25), max(2.0, hail_size * 0.35), Color(1.0, 1.0, 1.0, 0.78 * hail_alpha))
				canvas.draw_line(pos + Vector2(-hail_size * 0.58, 0.0), pos + Vector2(hail_size * 0.50, 0.0), Color(1.0, 1.0, 1.0, 0.36 * hail_alpha), 1.4)
			"hail_impact":
				var s_impact: float = float(particle.get("size", 3.0))
				var impact_alpha: float = clamp(alpha, 0.30, 1.0)
				canvas.draw_circle(pos, s_impact * 1.65, Color(0.06, 0.16, 0.26, 0.36 * impact_alpha))
				canvas.draw_circle(pos, s_impact, Color(0.82, 0.94, 1.0, 0.86 * impact_alpha))
				canvas.draw_line(pos + Vector2(-s_impact * 1.9, 0.0), pos + Vector2(s_impact * 1.9, 0.0), Color(1.0, 1.0, 1.0, 0.46 * impact_alpha), 1.2)
			"hail_burst":
				var s_burst: float = float(particle.get("size", 10.0))
				var burst_alpha: float = clamp(alpha, 0.0, 1.0)
				canvas.draw_circle(pos, s_burst * 1.28, Color(0.16, 0.38, 0.62, 0.20 * burst_alpha))
				canvas.draw_circle(pos, s_burst * 0.72, Color(0.84, 0.97, 1.0, 0.36 * burst_alpha))
				canvas.draw_circle(pos, s_burst * 0.28, Color(1.0, 1.0, 1.0, 0.56 * burst_alpha))
				for line_idx in range(4):
					var line_angle: float = float(line_idx) * PI * 0.5 + float(particle.get("angle", 0.0))
					var dir := Vector2(cos(line_angle), sin(line_angle))
					canvas.draw_line(pos + dir * s_burst * 0.30, pos + dir * s_burst * 1.55, Color(0.90, 0.99, 1.0, 0.54 * burst_alpha), 1.4)
			"hail_shard":
				var s_shard: float = float(particle.get("size", 4.0))
				var shard_alpha: float = clamp(alpha, 0.0, 1.0)
				var shard_angle: float = float(particle.get("angle", 0.0))
				var dir := Vector2(cos(shard_angle), sin(shard_angle))
				var perp := Vector2(-dir.y, dir.x)
				canvas.draw_line(pos - dir * s_shard * 1.45, pos + dir * s_shard * 1.90, Color(0.08, 0.18, 0.30, 0.36 * shard_alpha), max(1.8, s_shard * 0.46))
				canvas.draw_line(pos - dir * s_shard * 1.35, pos + dir * s_shard * 1.75, Color(0.78, 0.94, 1.0, 0.86 * shard_alpha), max(1.2, s_shard * 0.30))
				canvas.draw_line(pos - dir * s_shard * 0.65 + perp * s_shard * 0.38, pos + dir * s_shard * 0.80, Color(1.0, 1.0, 1.0, 0.62 * shard_alpha), 1.0)
			"fire":
				canvas.draw_circle(pos, float(particle.get("size", 4.0)) * 2.2, Color(1.0, 0.25, 0.05, 0.15 * alpha))
				canvas.draw_circle(pos, float(particle.get("size", 4.0)), color)
			"ice":
				var s: float = float(particle.get("size", 4.0))
				canvas.draw_line(pos + Vector2(-s, 0.0), pos + Vector2(s, 0.0), color, 1.5)
				canvas.draw_line(pos + Vector2(0.0, -s), pos + Vector2(0.0, s), color, 1.5)
				canvas.draw_circle(pos, max(1.0, s * 0.35), Color(0.9, 1.0, 1.0, 0.75 * alpha))
			_:
				var drift := Vector2(float(particle.get("vx", 0.0)) * -6.0, 0.0)
				canvas.draw_line(pos + drift, pos, color, max(1.0, float(particle.get("size", 2.0))))
	_draw_weather_message(canvas)


func apply_player_wind_to_result(result: Dictionary, owner: Object, fps_scale: float, registry: Object = null) -> void:
	if not _has_wind_motion():
		return
	var pos: Vector2 = _get_result_or_owner_vec(result, owner, "player_pos", Vector2.ZERO)
	var width: float = max(1.0, float(_get_result_or_owner_value(result, owner, "player_paddle_width", 155.0)))
	var push: float = _get_wind_push(width, pos.x, true) * max(0.0, fps_scale)
	if abs(push) <= 0.001:
		return
	pos.x += push
	if not _is_player_warp_gate_active(registry):
		pos.x = clamp(pos.x, 0.0, FIELD_WIDTH - width)
	result["player_pos"] = pos


func apply_player_motion_effects_to_result(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_weather_active():
		_clear_player_ice_slide_state()
		_wrap_player_position_for_warp_gate_if_needed(result, owner, registry)
		return
	if is_ice_active():
		_apply_player_ice_dash_slide(result, owner, registry, fps_scale)
	else:
		_clear_player_ice_slide_state()
	if is_sand_active():
		_apply_player_sand_erosion(result, owner, registry, fps_scale)
	if _has_wind_motion():
		apply_player_wind_to_result(result, owner, fps_scale, registry)
	_wrap_player_position_for_warp_gate_if_needed(result, owner, registry)


func apply_boss_wind_to_result(result: Dictionary, owner: Object, fps_scale: float) -> void:
	if not _has_wind_motion():
		return
	var pos: Vector2 = _get_result_or_owner_vec(result, owner, "boss_pos", Vector2.ZERO)
	var width: float = max(1.0, float(_get_result_or_owner_value(result, owner, "boss_paddle_width", 100.0)))
	var push: float = _get_wind_push(width, pos.x, false) * max(0.0, fps_scale)
	if abs(push) <= 0.001:
		return
	pos.x = clamp(pos.x + push, 0.0, FIELD_WIDTH - width)
	result["boss_pos"] = pos


func apply_boss_motion_effects_to_result(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_weather_active():
		_clear_boss_ice_slide_state()
		return
	if is_ice_active():
		_apply_boss_ice_motion(result, owner, registry, fps_scale)
	else:
		_clear_boss_ice_slide_state()
	if is_sand_active():
		_apply_boss_sand_erosion(result, owner, registry, fps_scale)
	if _has_wind_motion():
		apply_boss_wind_to_result(result, owner, fps_scale)


func apply_ball_weather_motion(scene: Dictionary, fps_scale: float) -> void:
	if not is_weather_active():
		return
	var force := 0.0
	if weather_event_type == "breeze":
		force = BREEZE_WIND_FORCE_BALL
	elif weather_event_type == "gust":
		force = GUST_WIND_FORCE_BALL
	if force <= 0.0:
		return
	var velocity: Vector2 = _get_vector2(scene.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	velocity.x += force * float(weather_event_direction) * max(0.0, fps_scale)
	scene["ball_vel"] = velocity


func resolve_sand_ball_collision(ball_pos: Vector2, ball_vel: Vector2, ball_size: float, _context: Dictionary = {}) -> Dictionary:
	if not sand_collision_active:
		return {}
	var ball_rect := Rect2(
		ball_pos - Vector2(ball_size, ball_size) * 0.5,
		Vector2(ball_size, ball_size)
	)
	for side in ["left", "right", "top", "bottom"]:
		if not _sand_side_can_intersect_ball_rect(side, ball_rect):
			continue
		var depths: Array = _get_sand_depths(side)
		var index_bounds := _get_sand_collision_index_bounds(side, ball_rect, depths.size())
		if index_bounds.y < index_bounds.x:
			continue
		for index in range(index_bounds.x, index_bounds.y + 1):
			var depth: float = max(0.0, float(depths[index]))
			if depth <= 1.0:
				continue
			var segment_rect := _get_sand_segment_rect(side, index, depth)
			if not segment_rect.intersects(ball_rect):
				continue
			var normal := _get_sand_normal(side)
			var next_vel := ball_vel
			var impact_speed := ball_vel.length()
			var dot := ball_vel.dot(normal)
			if dot < 0.0:
				next_vel = (ball_vel - 2.0 * dot * normal) * 0.95
			else:
				next_vel *= 0.95
			var next_pos := _push_ball_out_of_sand(side, depth, ball_pos, ball_size)
			var world_pos := next_pos.y if side == "left" or side == "right" else next_pos.x
			var eroded := _erode_sand_at(side, world_pos, SAND_BALL_ERODE_AMOUNT, SAND_BALL_ERODE_RADIUS_SEGS)
			if eroded > 0.0:
				_spawn_sand_particles(side, next_pos, eroded)
			return {
				"event": "sand_terrain",
				"ball_pos": next_pos,
				"ball_vel": next_vel,
				"impact_pos": next_pos,
				"side": side,
				"impact_speed": impact_speed,
			}
	return {}


func apply_fire_hit_speed(ball_vel: Vector2) -> Vector2:
	if not is_fire_active() or ball_vel.length() <= 0.001:
		return ball_vel
	return ball_vel * get_fire_hit_speed_multiplier()


func apply_fire_paddle_hit_knockback(
	is_player: bool,
	ball_pos: Vector2,
	_context: Dictionary = {},
	deps: Dictionary = {}
) -> Dictionary:
	if not is_fire_active():
		return {}
	_spawn_fire_hit_explosion(ball_pos)
	var velocity: float = _roll_fire_paddle_knockback_velocity()
	var decay: float = FIRE_ICE_KNOCKBACK_DECAY if is_ice_active() else FIRE_PADDLE_KNOCKBACK_DECAY
	var result := {
		"applied": true,
		"velocity": velocity,
		"frames": FIRE_PADDLE_KNOCKBACK_FRAMES,
		"decay_per_frame": decay,
		"is_player": is_player,
	}
	if is_player:
		var movement_state = deps.get("movement_state", null)
		if movement_state == null:
			movement_state = _get_instance(deps.get("registry", null), "player_movement_state")
		if movement_state != null and movement_state.has_method("start_knockback"):
			movement_state.start_knockback(
				velocity,
				FIRE_PADDLE_KNOCKBACK_FRAMES,
				decay,
				true,
				false
			)
		result["player_fire_knockback_vel"] = velocity
	else:
		var ai_state = deps.get("ai_state", null)
		if ai_state == null:
			ai_state = _get_instance(deps.get("registry", null), "boss_ai_state")
		if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
			ai_state.start_paddle_hit_knockback(
				velocity,
				FIRE_PADDLE_KNOCKBACK_FRAMES,
				decay,
				true
			)
		result["boss_fire_knockback_vel"] = velocity
		result["boss_vel"] = velocity
	return result


func apply_player_movement_config(config: Dictionary) -> void:
	if not is_ice_active():
		return
	if config.has("paddle_accel"):
		config["paddle_accel"] = float(config["paddle_accel"]) * ICE_ACCELERATION_MULTIPLIER
	if config.has("paddle_decel"):
		config["paddle_decel"] = float(config["paddle_decel"]) * ICE_DECELERATION_MULTIPLIER
	if config.has("paddle_turn_decel"):
		config["paddle_turn_decel"] = float(config["paddle_turn_decel"]) * ICE_DIRECTION_CHANGE_MULTIPLIER


func get_player_speed_multiplier() -> float:
	return RAIN_SPEED_MULTIPLIER if is_rain_active() else 1.0


func get_player_stat_breakdown(stat_key: String, _base_value: float = 0.0) -> Array:
	if stat_key != "player_speed" or not is_rain_active():
		return []
	return [{
		"label": "비",
		"icon_id": "",
		"ratio": RAIN_SPEED_MULTIPLIER,
	}]


func get_fire_base_speed_multiplier() -> float:
	return FIRE_BASE_SPEED_BOOST if is_fire_active() else 1.0


func get_fire_hit_speed_multiplier() -> float:
	if not is_fire_active():
		return 1.0
	return randf_range(FIRE_HIT_SPEED_BOOST_MIN, FIRE_HIT_SPEED_BOOST_MAX)


func get_weather_context() -> Dictionary:
	return {
		"active": is_weather_active(),
		"type": weather_event_type,
		"direction": weather_event_direction,
		"remaining_rounds": weather_event_remaining_rounds,
		"warning_timer_frames": warning_timer_frames,
		"end_timer_frames": end_timer_frames,
		"warning_text": warning_text,
		"end_text": end_text,
		"sand_total_depth": get_sand_total_depth(),
		"sand_dissolving": sand_dissolving,
		"sand_dissolve_alpha": get_sand_dissolve_alpha(),
		"hail_hit_count": hail_hit_count,
		"hail_destroy_count": hail_destroy_count,
		"hail_player_hit_cooldown_frames": hail_player_hit_cooldown_frames,
		"ice_player_slide_active": ice_player_slide_active,
		"ice_boss_slide_active": ice_boss_slide_active,
	}


func harvest_particles(type_filter: String = "") -> Array:
	var result: Array = []
	for value in weather_particles:
		var particle: Dictionary = _get_dict(value)
		if type_filter != "" and str(particle.get("weather_type", "")) != type_filter:
			continue
		result.append(particle.duplicate(true))
	if type_filter == "sand" or (type_filter == "" and weather_event_type == "sand"):
		for side in ["left", "right", "top", "bottom"]:
			var depths: Array = _get_sand_depths(side)
			for index in range(depths.size()):
				var depth: float = max(0.0, float(depths[index]))
				if depth <= 1.0:
					continue
				result.append(_make_sand_harvest_particle(side, index, depth))
	return result


func get_render_particles() -> Array:
	return weather_particles


func has_visible_effects() -> bool:
	if is_weather_active():
		return true
	if warning_timer_frames > 0.0 or end_timer_frames > 0.0:
		return true
	if not weather_particles.is_empty() or sand_dissolving:
		return true
	return _has_sand_depths_over_threshold()


func clear_visual_particles() -> void:
	weather_particles.clear()


func dissolve_sand_terrain() -> void:
	for index in range(sand_depths.size()):
		sand_depths[index] = 0.0
	for side in sand_wall_depths.keys():
		var depths: Array = _get_sand_depths(str(side))
		for index in range(depths.size()):
			depths[index] = 0.0
	sand_collision_active = false
	_mark_sand_visual_dirty()


func rebuild_sand_behind_player(player_pos: Vector2 = Vector2.ZERO) -> void:
	if sand_depths.is_empty():
		for _i in range(SAND_SEGMENTS):
			sand_depths.append(0.0)
	var fallback_center_x: float = (SAND_HORIZONTAL_START + SAND_HORIZONTAL_END) * 0.5
	var center_x: float = fallback_center_x
	if player_pos != Vector2.ZERO:
		center_x = clamp(player_pos.x, SAND_HORIZONTAL_START, SAND_HORIZONTAL_END)
	var mid: int = clampi(int(round((center_x - SAND_HORIZONTAL_START) / SAND_SEG_SIZE)), 0, SAND_SEGMENTS - 1)
	for index in range(SAND_SEGMENTS):
		var dist: float = abs(float(index) - float(mid)) / max(1.0, float(SAND_SEGMENTS) * 0.5)
		sand_depths[index] = max(float(sand_depths[index]), 55.0 * max(0.25, 1.0 - dist * 0.55))
	sand_collision_active = true
	_mark_sand_visual_dirty()


func get_sand_total_depth() -> float:
	var total := 0.0
	for value in sand_depths:
		total += max(0.0, float(value))
	for side in ["left", "right", "top"]:
		for value in _get_sand_depths(side):
			total += max(0.0, float(value))
	return total


func get_sand_dissolve_alpha() -> float:
	if not sand_dissolving:
		return 1.0
	return clamp(_sand_dissolve_timer / SAND_DISSOLVE_FRAMES, 0.0, 1.0)


func get_sand_wall_depth_arrays() -> Dictionary:
	var result: Dictionary = {}
	for side in ["left", "right", "top", "bottom"]:
		var depths: Array = _get_sand_depths(str(side))
		if not depths.is_empty():
			result[side] = depths
	return result


func get_sand_visual_segments() -> Array:
	if not _sand_visual_segments_dirty:
		return _sand_visual_segments_cache
	_sand_visual_segments_cache.clear()
	for side in ["left", "right", "top", "bottom"]:
		var depths: Array = _get_sand_depths(side)
		for index in range(depths.size()):
			var depth: float = max(0.0, float(depths[index]))
			if depth <= 0.5:
				continue
			_sand_visual_segments_cache.append({
				"side": side,
				"index": index,
				"depth": depth,
				"rect": _get_sand_segment_rect(side, index, depth),
			})
	_sand_visual_segments_dirty = false
	return _sand_visual_segments_cache


func is_weather_active() -> bool:
	return weather_event_active and weather_event_type != ""


func get_weather_type() -> String:
	return weather_event_type if is_weather_active() else ""


func get_weather_direction() -> int:
	return weather_event_direction if is_weather_active() else 0


func is_fire_active() -> bool:
	return is_weather_active() and weather_event_type == "fire"


func is_ice_active() -> bool:
	return is_weather_active() and weather_event_type == "ice"


func is_rain_active() -> bool:
	return is_weather_active() and weather_event_type == "rain"


func is_hail_active() -> bool:
	return is_weather_active() and weather_event_type == "hail"


func is_sand_active() -> bool:
	return is_weather_active() and weather_event_type == "sand"


func _has_wind_motion() -> bool:
	return is_weather_active() and (weather_event_type == "breeze" or weather_event_type == "gust")


func _resolve_duration(next_type: String, duration_rounds: int) -> int:
	if duration_rounds > 0:
		return duration_rounds
	if next_type == "gust" or next_type == "sand":
		return 1
	return int(WEATHER_DURATION_WEIGHTS[randi() % WEATHER_DURATION_WEIGHTS.size()])


func _roll_wind_direction(direction: int) -> int:
	if direction < 0:
		return -1
	if direction > 0:
		return 1
	return -1 if randf() < 0.5 else 1


func _is_weather_disabled(context: Dictionary) -> bool:
	var ai_mode := str(context.get("ai_mode", "champion")).strip_edges().to_lower()
	return ai_mode == "junior" or int(context.get("current_stage", 1)) == 30


func _build_owner_context(owner: Object) -> Dictionary:
	return {
		"current_stage": int(_safe_owner_get(owner, "current_stage", 1)),
		"ai_mode": str(_safe_owner_get(owner, "ai_mode", "champion")),
		"arena_mode_enabled": bool(_safe_owner_get(owner, "arena_mode_enabled", false)),
	}


func _sync_owner_and_physics(owner: Object, registry: Object) -> void:
	if owner != null:
		owner.set("weather_type", get_weather_type())
		owner.set("weather_event_active", is_weather_active())
		owner.set("weather_event_context", get_weather_context())
	var ball_physics: Object = _get_instance(registry, "ball_physics")
	if ball_physics != null and ball_physics.has_method("configure_context"):
		ball_physics.configure_context(
			int(_safe_owner_get(owner, "current_stage", 1)),
			str(_safe_owner_get(owner, "ai_mode", "champion")),
			bool(_safe_owner_get(owner, "arena_mode_enabled", false)),
			get_weather_type()
		)


func _apply_fire_gauge_drain(owner: Object, fps_scale: float) -> void:
	if not is_fire_active() or owner == null:
		return
	fire_gauge_drain_accumulator += (FIRE_GAUGE_DRAIN_PER_SECOND / 60.0) * max(0.0, fps_scale)
	if fire_gauge_drain_accumulator < 1.0:
		return
	var drain: float = floor(fire_gauge_drain_accumulator)
	fire_gauge_drain_accumulator -= drain
	var max_gauge: float = max(1.0, float(_safe_owner_get(owner, "special_gauge_max", 500.0)))
	var current: float = clamp(float(_safe_owner_get(owner, "special_gauge", 0.0)) - drain, 0.0, max_gauge)
	owner.set("special_gauge", current)


func _get_wind_push(width: float, x: float, player: bool) -> float:
	if not is_weather_active():
		return 0.0
	var force := 0.0
	if weather_event_type == "breeze":
		force = BREEZE_WIND_FORCE_PLAYER if player else BREEZE_WIND_FORCE_BOSS
	elif weather_event_type == "gust":
		force = GUST_WIND_FORCE_PLAYER if player else GUST_WIND_FORCE_BOSS
	if force <= 0.0:
		return 0.0
	var push: float = force * float(weather_event_direction)
	var center := x + width * 0.5
	var next_center := center + push
	var half_width := width * 0.5
	if next_center - half_width < 0.0:
		push = -(center - half_width)
	elif next_center + half_width > FIELD_WIDTH:
		push = FIELD_WIDTH - half_width - center
	return push


func _spawn_weather_particles(fps_scale: float) -> void:
	if weather_event_type == "hail":
		_spawn_hail_particles(fps_scale)
		return
	var target := 34
	if weather_event_type == "rain":
		target = 120
	elif weather_event_type == "fire":
		target = FIRE_WEATHER_PARTICLE_TARGET
	elif weather_event_type == "ice":
		target = 52
	elif weather_event_type == "breeze":
		target = BREEZE_VISUAL_PARTICLE_TARGET
	elif weather_event_type == "gust":
		target = GUST_VISUAL_PARTICLE_TARGET
	if weather_event_type == "sand":
		return
	var spawn_budget: int = min(max(0, target - weather_particles.size()), max(1, int(ceil(fps_scale * 5.0))))
	for _i in range(spawn_budget):
		weather_particles.append(_make_particle(weather_event_type))
	if weather_event_type == "fire":
		_trim_weather_particles_for_type("fire", FIRE_VISUAL_PARTICLE_CAP)


func _make_particle(next_type: String) -> Dictionary:
	var color := _get_weather_color(next_type)
	match next_type:
		"rain":
			return {
				"x": randf_range(10.0, FIELD_WIDTH - 10.0),
				"y": randf_range(-80.0, FIELD_HEIGHT * 0.45),
				"vx": weather_event_direction * randf_range(0.8, 2.4),
				"vy": randf_range(12.0, 18.0),
				"life": randf_range(36.0, 62.0),
				"max_life": 62.0,
				"length": randf_range(10.0, 24.0),
				"wind": weather_event_direction * randf_range(2.0, 5.0),
				"size": 2.0,
				"kind": "rain",
				"weather_type": next_type,
				"color": color,
			}
		"hail":
			return {
				"x": randf_range(20.0, FIELD_WIDTH - 20.0),
				"y": randf_range(-80.0, 50.0),
				"vx": randf_range(-0.9, 0.9),
				"vy": randf_range(6.0, 10.0),
				"life": randf_range(70.0, 105.0),
				"max_life": 105.0,
				"size": randf_range(7.0, 13.0),
				"kind": "hail",
				"weather_type": next_type,
				"color": color,
			}
		"fire":
			return {
				"x": randf_range(24.0, FIELD_WIDTH - 24.0),
				"y": randf_range(FIELD_HEIGHT - 95.0, FIELD_HEIGHT - 20.0) if randf() < 0.55 else randf_range(50.0, 135.0),
				"vx": randf_range(-0.7, 0.7),
				"vy": randf_range(-2.6, -0.4),
				"life": randf_range(34.0, 58.0),
				"max_life": 58.0,
				"size": randf_range(2.5, 5.0),
				"kind": "fire",
				"weather_type": next_type,
				"color": color,
			}
		"ice":
			return {
				"x": randf_range(25.0, FIELD_WIDTH - 25.0),
				"y": randf_range(75.0, FIELD_HEIGHT - 70.0),
				"vx": randf_range(-0.4, 0.4),
				"vy": randf_range(-0.35, 0.35),
				"life": randf_range(55.0, 95.0),
				"max_life": 95.0,
				"size": randf_range(3.0, 6.0),
				"kind": "ice",
				"weather_type": next_type,
				"color": color,
			}
		_:
			var wind_direction: float = float(weather_event_direction)
			if is_zero_approx(wind_direction):
				wind_direction = 1.0
			var source_x: float = -30.0 if wind_direction > 0.0 else FIELD_WIDTH + 30.0
			var speed: float = randf_range(3.8, 7.0)
			return {
				"x": source_x,
				"y": randf_range(60.0, FIELD_HEIGHT - 60.0),
				"vx": wind_direction * speed,
				"vy": randf_range(-0.35, 0.35),
				"life": randf_range(54.0, 84.0),
				"max_life": 84.0,
				"size": randf_range(1.5, 3.0),
				"kind": "wind",
				"weather_type": next_type,
				"color": color,
			}


func _get_render_particle_limit(effect_lod_scale: float = 1.0) -> int:
	return WeatherEventRenderBudget.get_weather_particle_limit(weather_event_type, effect_lod_scale)


func _update_weather_particles(fps_scale: float) -> void:
	var write_index := 0
	var particle_count := weather_particles.size()
	for index in range(particle_count):
		var particle: Dictionary = _get_dict(weather_particles[index])
		var kind := str(particle.get("kind", "dust"))
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		if kind == "hail_impact" or kind == "hail_shard" or kind == "sand":
			particle["vy"] = float(particle.get("vy", 0.0)) + float(particle.get("gravity", 0.18)) * fps_scale
			particle["vx"] = float(particle.get("vx", 0.0)) * pow(float(particle.get("friction", 0.96)), fps_scale)
		if kind == "fire_explosion" or kind == "fire_spark":
			particle["vy"] = float(particle.get("vy", 0.0)) + float(particle.get("gravity", 0.05)) * fps_scale
			particle["vx"] = float(particle.get("vx", 0.0)) * pow(float(particle.get("friction", 0.94)), fps_scale)
			particle["vy"] = float(particle.get("vy", 0.0)) * pow(float(particle.get("friction", 0.94)), fps_scale)
			particle["size"] = max(0.4, float(particle.get("size", 3.0)) * pow(float(particle.get("size_decay", 0.985)), fps_scale))
		if kind == "hail_shard":
			particle["angle"] = float(particle.get("angle", 0.0)) + float(particle.get("spin", 0.0)) * fps_scale
		elif kind == "fire_spark":
			particle["angle"] = float(particle.get("angle", 0.0)) + float(particle.get("spin", 0.0)) * fps_scale
		elif kind == "hail_burst":
			particle["size"] = float(particle.get("size", 10.0)) + 0.58 * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		if (
			float(particle.get("life", 0.0)) <= 0.0
			or float(particle.get("x", 0.0)) < -90.0
			or float(particle.get("x", 0.0)) > FIELD_WIDTH + 90.0
			or float(particle.get("y", 0.0)) > FIELD_HEIGHT + 90.0
		):
			continue
		weather_particles[write_index] = particle
		write_index += 1
	if write_index < particle_count:
		weather_particles.resize(write_index)


func _spawn_hail_particles(fps_scale: float) -> void:
	hail_spawn_timer_frames += max(0.0, fps_scale)
	if hail_spawn_timer_frames < HAIL_SPAWN_INTERVAL_FRAMES:
		return
	hail_spawn_timer_frames = 0.0
	var hail_count := 0
	for particle_value in weather_particles:
		var particle: Dictionary = _get_dict(particle_value)
		if str(particle.get("kind", "")) == "hail":
			hail_count += 1
	var spawn_count := randi_range(1, 3)
	for _i in range(spawn_count):
		if hail_count >= HAIL_MAX_PARTICLES:
			return
		weather_particles.append(_make_particle("hail"))
		hail_count += 1


func _roll_fire_paddle_knockback_velocity() -> float:
	return (-FIRE_PADDLE_KNOCKBACK_VELOCITY if randf() < 0.5 else FIRE_PADDLE_KNOCKBACK_VELOCITY)


func _spawn_fire_hit_explosion(pos: Vector2) -> void:
	weather_particles.append_array(WeatherEventPayloadFactory.build_fire_hit_explosion_particles(
		pos,
		FIRE_HIT_EXPLOSION_PARTICLES,
		FIRE_HIT_SPARK_PARTICLES,
		_get_weather_color("fire")
	))
	_trim_weather_particles_for_type("fire", FIRE_VISUAL_PARTICLE_CAP)


func _trim_weather_particles_for_type(type_filter: String, max_count: int) -> void:
	if type_filter == "" or max_count <= 0:
		return
	var kept := 0
	for index in range(weather_particles.size() - 1, -1, -1):
		var particle: Dictionary = _get_dict(weather_particles[index])
		if str(particle.get("weather_type", "")) != type_filter:
			continue
		kept += 1
		if kept > max_count:
			weather_particles.remove_at(index)


func _update_hail_collision(owner: Object, registry: Object, fps_scale: float) -> void:
	if hail_player_hit_cooldown_frames > 0.0:
		hail_player_hit_cooldown_frames = max(0.0, hail_player_hit_cooldown_frames - max(0.0, fps_scale))
	if not is_hail_active() or owner == null:
		return
	var player_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size := Vector2(
		max(1.0, float(_safe_owner_get(owner, "player_paddle_width", 155.0))),
		max(1.0, float(_safe_owner_get(owner, "player_paddle_height", 50.0)))
	)
	var player_rect := Rect2(player_pos, player_size)
	var dash_snapshot := _get_dash_snapshot(registry)
	var is_dashing := bool(dash_snapshot.get("active", false))
	for index in range(weather_particles.size() - 1, -1, -1):
		var hail: Dictionary = _get_dict(weather_particles[index])
		if str(hail.get("kind", "")) != "hail":
			continue
		var size: float = float(hail.get("size", 8.0))
		var hail_rect := Rect2(
			Vector2(float(hail.get("x", 0.0)), float(hail.get("y", 0.0))) - Vector2(size, size) * 0.5,
			Vector2(size, size)
		)
		if not hail_rect.intersects(player_rect):
			continue
		var hit_pos := hail_rect.get_center()
		if is_dashing:
			weather_particles.remove_at(index)
			hail_destroy_count += 1
			_spawn_hail_impact(hit_pos, size, true)
			_play_hail_dash_destroy_feedback(registry)
			continue
		if hail_player_hit_cooldown_frames > 0.0:
			continue
		weather_particles.remove_at(index)
		hail_hit_count += 1
		hail_player_hit_cooldown_frames = HAIL_HIT_COOLDOWN_FRAMES
		_spawn_hail_impact(hit_pos, size, false)
		_apply_hail_player_hit(owner, registry)
		break


func _spawn_hail_impact(pos: Vector2, size: float, dash_destroy: bool) -> void:
	weather_particles.append_array(WeatherEventPayloadFactory.build_hail_impact_particles(
		pos,
		size,
		dash_destroy,
		_get_weather_color("hail")
	))


func _apply_hail_player_hit(owner: Object, registry: Object) -> void:
	var direction := -1.0 if randf() < 0.5 else 1.0
	var movement_state: Object = _get_instance(registry, "player_movement_state")
	if movement_state != null and movement_state.has_method("start_knockback"):
		movement_state.start_knockback(
			direction * HAIL_PLAYER_KNOCKBACK_SPEED,
			HAIL_PLAYER_STUN_FRAMES,
			HAIL_KNOCKBACK_DECAY,
			true,
			true
		)
	else:
		var pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO), Vector2.ZERO)
		var width: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_width", 155.0)))
		pos.x = clamp(pos.x + direction * HAIL_PLAYER_KNOCKBACK_SPEED, 0.0, FIELD_WIDTH - width)
		owner.set("player_pos", pos)
	var status_state: Object = _get_instance(registry, "status_effect_state")
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status(
			"player",
			"stun",
			HAIL_PLAYER_STUN_FRAMES,
			{"cleansable": true, "visual": "weather_hail"},
			"weather_hail"
		)
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_wall_hit"):
		audio.play_wall_hit(HAIL_PLAYER_KNOCKBACK_SPEED)


func _play_hail_dash_destroy_feedback(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_dash_spirit_delete"):
			audio.play_dash_spirit_delete()
		elif audio.has_method("play_wall_hit"):
			audio.play_wall_hit(16.0)


func _build_sand_wall() -> void:
	sand_wall_depths.clear()
	for side in ["left", "right", "top", "bottom"]:
		sand_wall_depths[side] = _generate_sand_depths(_get_sand_segment_count(side))
	sand_depths = _get_sand_depths("bottom")
	sand_collision_active = true
	_mark_sand_visual_dirty()


func _draw_sand(canvas: CanvasItem, shake_offset: Vector2, effect_lod_scale: float = 1.0) -> void:
	if sand_wall_depths.is_empty() and sand_depths.is_empty():
		return
	var stride: int = _get_sand_render_stride(effect_lod_scale)
	for side in ["left", "right", "top", "bottom"]:
		var depths: Array = _get_sand_depths(side)
		for index in range(0, depths.size(), stride):
			var depth: float = max(0.0, float(depths[index]))
			if depth <= 0.5:
				continue
			var rect := _get_sand_segment_rect(side, index, depth)
			rect = _expand_sand_segment_rect_for_stride(rect, side, stride)
			rect.position += shake_offset
			canvas.draw_rect(rect, Color(0.72, 0.55, 0.24, 0.58))
			if side == "left" or side == "right":
				var edge_x: float = rect.end.x if side == "left" else rect.position.x
				canvas.draw_line(Vector2(edge_x, rect.position.y), Vector2(edge_x, rect.end.y), Color(0.95, 0.79, 0.42, 0.42), 1.0)
			else:
				var edge_y: float = rect.end.y if side == "top" else rect.position.y
				canvas.draw_line(Vector2(rect.position.x, edge_y), Vector2(rect.end.x, edge_y), Color(0.95, 0.79, 0.42, 0.42), 1.0)


func _apply_player_ice_dash_slide(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	var dash_snapshot := _get_dash_snapshot(registry)
	var dash_active := bool(dash_snapshot.get("active", false))
	var dash_direction := int(sign(float(dash_snapshot.get("direction", 0.0))))
	if is_ice_active():
		if _should_start_player_ice_slide(dash_snapshot, dash_active, dash_direction):
			ice_player_slide_active = true
			ice_player_slide_direction = dash_direction
			ice_player_slide_speed = ICE_DASH_SLIDE_INITIAL_SPEED
			result["player_pos"] = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO), Vector2.ZERO)
			_cancel_player_dash_for_ice_slide(registry)
			_spawn_ice_slide_particles(_get_result_or_owner_vec(result, owner, "player_pos", Vector2.ZERO), dash_direction, true)
		if ice_player_slide_active:
			var pos: Vector2 = _get_result_or_owner_vec(result, owner, "player_pos", Vector2.ZERO)
			var width: float = max(1.0, float(_get_result_or_owner_value(result, owner, "player_paddle_width", 155.0)))
			pos.x += ice_player_slide_speed * float(ice_player_slide_direction) * max(0.0, fps_scale)
			if _is_player_warp_gate_active(registry):
				ice_player_slide_speed *= pow(ICE_DASH_SLIDE_DECAY, max(0.0, fps_scale))
				if ice_player_slide_speed < 1.0:
					ice_player_slide_active = false
					ice_player_slide_speed = 0.0
			else:
				var min_x := 0.0
				var max_x := FIELD_WIDTH - width
				if pos.x <= min_x:
					pos.x = min_x
					ice_player_slide_active = false
					ice_player_slide_speed = 0.0
				elif pos.x >= max_x:
					pos.x = max_x
					ice_player_slide_active = false
					ice_player_slide_speed = 0.0
				else:
					ice_player_slide_speed *= pow(ICE_DASH_SLIDE_DECAY, max(0.0, fps_scale))
					if ice_player_slide_speed < 1.0:
						ice_player_slide_active = false
						ice_player_slide_speed = 0.0
			result["player_pos"] = pos
			result["player_speed"] = 0.0
	else:
		ice_player_slide_active = false
		ice_player_slide_speed = 0.0
	_previous_player_dash_active = dash_active


func _should_start_player_ice_slide(dash_snapshot: Dictionary, dash_active: bool, dash_direction: int) -> bool:
	if ice_player_slide_active or not dash_active or dash_direction == 0:
		return false
	var dash_timer: float = float(dash_snapshot.get("timer", ICE_DASH_SLIDE_TRANSITION_TIMER_FRAMES))
	return dash_timer <= ICE_DASH_SLIDE_TRANSITION_TIMER_FRAMES


func _cancel_player_dash_for_ice_slide(registry: Object) -> void:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state == null:
		return
	if dash_state.has_method("cancel_active_without_recovery"):
		dash_state.cancel_active_without_recovery()
	elif dash_state.has_method("cancel_until_key_release"):
		dash_state.cancel_until_key_release()


func _wrap_player_position_for_warp_gate(result: Dictionary, owner: Object, registry: Object) -> void:
	var warp_gate_state: Object = _get_warp_gate_state(registry)
	if not _is_warp_gate_active(warp_gate_state) or not warp_gate_state.has_method("wrap_player_position"):
		return
	var pos: Vector2 = _get_result_or_owner_vec(result, owner, "player_pos", Vector2.ZERO)
	var paddle_size := Vector2(
		max(1.0, float(_get_result_or_owner_value(result, owner, "player_paddle_width", 155.0))),
		max(1.0, float(_get_result_or_owner_value(result, owner, "player_paddle_height", 50.0)))
	)
	var special_gauge: float = float(_get_result_or_owner_value(result, owner, "special_gauge", 0.0))
	var wrap_result: Variant = warp_gate_state.wrap_player_position(
		pos,
		paddle_size,
		special_gauge,
		_build_warp_gate_deps(registry)
	)
	if not (wrap_result is Dictionary):
		return
	var next_pos: Variant = wrap_result.get("player_pos", pos)
	if next_pos is Vector2:
		result["player_pos"] = next_pos
	if result.has("special_gauge") or wrap_result.has("special_gauge"):
		result["special_gauge"] = float(wrap_result.get("special_gauge", special_gauge))


func _wrap_player_position_for_warp_gate_if_needed(result: Dictionary, owner: Object, registry: Object) -> void:
	if not _should_check_player_warp_gate(owner):
		return
	_wrap_player_position_for_warp_gate(result, owner, registry)


func _should_check_player_warp_gate(owner: Object) -> bool:
	var character_type: String = str(_safe_owner_get(owner, "selected_character_type", "smasher")).strip_edges().to_lower()
	return character_type == "" or character_type == "smasher"


func _is_player_warp_gate_active(registry: Object) -> bool:
	return _is_warp_gate_active(_get_warp_gate_state(registry))


func _get_warp_gate_state(registry: Object) -> Object:
	return _get_instance(registry, "smasher_warp_gate_state")


func _is_warp_gate_active(warp_gate_state: Object) -> bool:
	return (
		warp_gate_state != null
		and warp_gate_state.has_method("is_active")
		and bool(warp_gate_state.is_active())
	)


func _build_warp_gate_deps(registry: Object) -> Dictionary:
	return {
		"registry": registry,
		"audio": _get_instance(registry, "game_audio"),
		"feedback": _get_instance(registry, "battle_feedback_state"),
	}


func _apply_boss_ice_motion(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	var dash_snapshot := _get_boss_dash_snapshot(registry)
	var dash_active := bool(dash_snapshot.get("active", false))
	var dash_direction := int(sign(float(dash_snapshot.get("direction", 0.0))))
	var boss_width: float = max(1.0, float(_get_result_or_owner_value(result, owner, "boss_paddle_width", 100.0)))
	if is_ice_active():
		if _previous_boss_dash_active and not dash_active and not ice_boss_slide_active and dash_direction != 0:
			ice_boss_slide_active = true
			ice_boss_slide_direction = dash_direction
			ice_boss_slide_speed = ICE_DASH_SLIDE_INITIAL_SPEED
			_spawn_ice_slide_particles(_get_result_or_owner_vec(result, owner, "boss_pos", Vector2.ZERO), dash_direction, false)
		if ice_boss_slide_active:
			var slide_pos: Vector2 = _get_result_or_owner_vec(result, owner, "boss_pos", Vector2.ZERO)
			slide_pos.x += ice_boss_slide_speed * float(ice_boss_slide_direction) * max(0.0, fps_scale)
			var min_x := 0.0
			var max_x := FIELD_WIDTH - boss_width
			if slide_pos.x <= min_x:
				slide_pos.x = min_x
				ice_boss_slide_active = false
				ice_boss_slide_speed = 0.0
			elif slide_pos.x >= max_x:
				slide_pos.x = max_x
				ice_boss_slide_active = false
				ice_boss_slide_speed = 0.0
			else:
				ice_boss_slide_speed *= pow(ICE_DASH_SLIDE_DECAY, max(0.0, fps_scale))
				if ice_boss_slide_speed < 1.0:
					ice_boss_slide_active = false
					ice_boss_slide_speed = 0.0
			result["boss_pos"] = slide_pos
			result["boss_vel"] = ice_boss_slide_speed * float(ice_boss_slide_direction)
		elif result.has("boss_pos"):
			var old_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_pos", Vector2.ZERO), Vector2.ZERO)
			var old_speed: float = float(_safe_owner_get(owner, "boss_vel", 0.0))
			var ai_pos: Vector2 = _get_result_or_owner_vec(result, owner, "boss_pos", old_pos)
			var ai_speed: float = float(result.get("boss_vel", old_speed))
			var momentum_x: float = old_pos.x + old_speed * max(0.0, fps_scale)
			var next_speed: float = (old_speed + (ai_speed - old_speed) * ICE_BOSS_BLEND) * pow(ICE_BOSS_FRICTION, max(0.0, fps_scale))
			var next_pos := ai_pos
			next_pos.x = momentum_x + (ai_pos.x - momentum_x) * ICE_BOSS_BLEND
			if next_pos.x < 0.0:
				next_pos.x = 0.0
				next_speed = abs(next_speed) * 0.3
			elif next_pos.x > FIELD_WIDTH - boss_width:
				next_pos.x = FIELD_WIDTH - boss_width
				next_speed = -abs(next_speed) * 0.3
			result["boss_pos"] = next_pos
			result["boss_vel"] = next_speed
	else:
		ice_boss_slide_active = false
		ice_boss_slide_speed = 0.0
	_previous_boss_dash_active = dash_active


func _apply_player_sand_erosion(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_sand_active() or sand_wall_depths.is_empty():
		return
	var old_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "player_pos", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = _get_result_or_owner_vec(result, owner, "player_pos", old_pos)
	var width: float = max(1.0, float(_get_result_or_owner_value(result, owner, "player_paddle_width", 155.0)))
	var moved: float = abs(pos.x - old_pos.x)
	var travel_dir: float = signf(pos.x - old_pos.x)
	var old_center: float = old_pos.x + width * 0.5
	var center: float = pos.x + width * 0.5
	# The walk and dash legs are not exclusive — a dashing paddle runs both — so the
	# spray is keyed to exactly one of them to avoid double-emitting per frame.
	var dash_snapshot := _get_dash_snapshot(registry)
	var dashing: bool = bool(dash_snapshot.get("active", false))
	if moved > 0.25:
		_begin_sand_erode_tracking()
		var walk_eroded: float = _erode_sand_at("bottom", center, SAND_WALK_ERODE_AMOUNT * max(0.0, fps_scale), SAND_WALK_ERODE_RADIUS_SEGS)
		if not dashing:
			_spawn_sand_kickup_spray("bottom", walk_eroded, travel_dir, moved, false)
	if dashing:
		_begin_sand_erode_tracking()
		var dash_eroded: float = _erode_sand_range("bottom", old_center, center, SAND_DASH_ERODE_AMOUNT, SAND_DASH_ERODE_RADIUS_SEGS)
		_spawn_sand_kickup_spray("bottom", dash_eroded, travel_dir, moved, true)


func _apply_boss_sand_erosion(result: Dictionary, owner: Object, registry: Object, fps_scale: float) -> void:
	if not is_sand_active() or sand_wall_depths.is_empty():
		return
	var old_pos: Vector2 = _get_vector2(_safe_owner_get(owner, "boss_pos", Vector2.ZERO), Vector2.ZERO)
	var pos: Vector2 = _get_result_or_owner_vec(result, owner, "boss_pos", old_pos)
	var width: float = max(1.0, float(_get_result_or_owner_value(result, owner, "boss_paddle_width", 100.0)))
	var moved: float = abs(pos.x - old_pos.x)
	var travel_dir: float = signf(pos.x - old_pos.x)
	var old_center: float = old_pos.x + width * 0.5
	var center: float = pos.x + width * 0.5
	var dash_snapshot := _get_boss_dash_snapshot(registry)
	var dashing: bool = bool(dash_snapshot.get("active", false))
	if moved > 0.25:
		_begin_sand_erode_tracking()
		var walk_eroded: float = _erode_sand_at("top", center, SAND_WALK_ERODE_AMOUNT * max(0.0, fps_scale), SAND_WALK_ERODE_RADIUS_SEGS)
		if not dashing:
			_spawn_sand_kickup_spray("top", walk_eroded, travel_dir, moved, false)
	if dashing:
		_begin_sand_erode_tracking()
		var dash_eroded: float = _erode_sand_range("top", old_center, center, SAND_DASH_ERODE_AMOUNT, SAND_DASH_ERODE_RADIUS_SEGS)
		_spawn_sand_kickup_spray("top", dash_eroded, travel_dir, moved, true)


func _spawn_ice_slide_particles(pos: Vector2, direction: int, player: bool) -> void:
	var y: float = FIELD_HEIGHT - 35.0 if player else 55.0
	var ice_color: Color = _get_weather_color("ice")
	for _i in range(12):
		weather_particles.append(WeatherEventPayloadFactory.build_ice_slide_particle(
			pos,
			y,
			direction,
			ice_color
		))


func _reset_ice_slide_state() -> void:
	_clear_player_ice_slide_state()
	_clear_boss_ice_slide_state()


func _clear_player_ice_slide_state() -> void:
	ice_player_slide_active = false
	ice_player_slide_speed = 0.0
	ice_player_slide_direction = 0
	_previous_player_dash_active = false


func _clear_boss_ice_slide_state() -> void:
	ice_boss_slide_active = false
	ice_boss_slide_speed = 0.0
	ice_boss_slide_direction = 0
	_previous_boss_dash_active = false


func _generate_sand_depths(count: int) -> Array:
	var result: Array = []
	for _i in range(max(1, count)):
		result.append(0.0)
	var cluster_count: int = randi_range(2, 5)
	for _cluster in range(cluster_count):
		var center := randf_range(0.05, 0.95)
		var half_width := randf_range(0.05, 0.25)
		var peak := randf_range(SAND_DEPTH_MIN + 5.0, SAND_DEPTH_MAX)
		for index in range(result.size()):
			var t: float = float(index) / max(1.0, float(result.size() - 1))
			var dist: float = abs(t - center) / max(0.001, half_width)
			if dist > 1.0:
				continue
			var shape := pow(1.0 - dist, randf_range(0.85, 1.65))
			result[index] = max(float(result[index]), peak * shape + randf_range(-2.0, 2.0))
	for index in range(result.size()):
		result[index] = clamp(float(result[index]), 0.0, SAND_DEPTH_MAX)
	return result


func _get_sand_depths(side: String) -> Array:
	if sand_wall_depths.has(side):
		var depths: Variant = sand_wall_depths[side]
		if depths is Array:
			return depths
	if side == "bottom":
		return sand_depths
	return []


func _has_sand_depths_over_threshold() -> bool:
	if _depths_have_visible_amount(sand_depths):
		return true
	for side in sand_wall_depths.keys():
		var depths_value: Variant = sand_wall_depths[side]
		if depths_value is Array and _depths_have_visible_amount(depths_value):
			return true
	return false


func _depths_have_visible_amount(depths: Array) -> bool:
	for value in depths:
		if float(value) > 0.5:
			return true
	return false


func _mark_sand_visual_dirty() -> void:
	_sand_visual_segments_dirty = true


func _sand_side_can_intersect_ball_rect(side: String, ball_rect: Rect2) -> bool:
	var axis_min: float = ball_rect.position.y if side == "left" or side == "right" else ball_rect.position.x
	var axis_max: float = ball_rect.end.y if side == "left" or side == "right" else ball_rect.end.x
	if axis_max < _get_sand_axis_start(side) - SAND_SEG_SIZE or axis_min > _get_sand_axis_end(side) + SAND_SEG_SIZE:
		return false
	var max_depth: float = max(SAND_DEPTH_MAX, 60.0)
	match side:
		"left":
			return ball_rect.position.x <= max_depth
		"right":
			return ball_rect.end.x >= FIELD_WIDTH - max_depth
		"top":
			return ball_rect.position.y <= max_depth
		_:
			return ball_rect.end.y >= FIELD_HEIGHT - max_depth


func _get_sand_collision_index_bounds(side: String, ball_rect: Rect2, depth_count: int) -> Vector2i:
	if depth_count <= 0:
		return Vector2i(0, -1)
	var axis_min: float = ball_rect.position.y if side == "left" or side == "right" else ball_rect.position.x
	var axis_max: float = ball_rect.end.y if side == "left" or side == "right" else ball_rect.end.x
	var axis_start: float = _get_sand_axis_start(side)
	var first := int(floor((axis_min - axis_start) / SAND_SEG_SIZE)) - 1
	var last := int(ceil((axis_max - axis_start) / SAND_SEG_SIZE)) + 1
	return Vector2i(
		clampi(first, 0, depth_count - 1),
		clampi(last, 0, depth_count - 1)
	)


func _get_sand_segment_count(side: String) -> int:
	var start: float = _get_sand_axis_start(side)
	var end: float = _get_sand_axis_end(side)
	return int(max(1.0, floor((end - start) / SAND_SEG_SIZE)))


func _get_sand_axis_start(side: String) -> float:
	return SAND_VERTICAL_START if side == "left" or side == "right" else SAND_HORIZONTAL_START


func _get_sand_axis_end(side: String) -> float:
	return SAND_VERTICAL_END if side == "left" or side == "right" else SAND_HORIZONTAL_END


func _get_sand_segment_rect(side: String, index: int, depth: float) -> Rect2:
	var start: float = _get_sand_axis_start(side)
	var segment_start: float = start + float(index) * SAND_SEG_SIZE
	var length: float = SAND_SEG_SIZE + 1.0
	match side:
		"left":
			return Rect2(0.0, segment_start, depth, length)
		"right":
			return Rect2(FIELD_WIDTH - depth, segment_start, depth, length)
		"top":
			return Rect2(segment_start, 0.0, length, depth)
		_:
			return Rect2(segment_start, FIELD_HEIGHT - depth, length, depth)


func _expand_sand_segment_rect_for_stride(rect: Rect2, side: String, stride: int) -> Rect2:
	if stride <= 1:
		return rect
	var target_length: float = SAND_SEG_SIZE * float(stride) + 1.0
	if side == "left" or side == "right":
		rect.size.y = minf(target_length, maxf(1.0, _get_sand_axis_end(side) - rect.position.y))
	else:
		rect.size.x = minf(target_length, maxf(1.0, _get_sand_axis_end(side) - rect.position.x))
	return rect


func _get_particle_render_stride(effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_particle_render_stride(effect_lod_scale)


func _get_particle_render_stride_for_type(weather_type: String, effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_particle_render_stride_for_type(weather_type, effect_lod_scale)


func _get_sand_render_stride(effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_sand_render_stride(effect_lod_scale)


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, effect_lod_scale: float) -> int:
	return WeatherEventRenderBudget.get_lod_count(base_count, lod_count, severe_lod_count, effect_lod_scale)


func _is_lod_active(effect_lod_scale: float) -> bool:
	return WeatherEventRenderBudget.is_lod_active(effect_lod_scale)


func _is_severe_lod_active(effect_lod_scale: float) -> bool:
	return WeatherEventRenderBudget.is_severe_lod_active(effect_lod_scale)


func _get_sand_normal(side: String) -> Vector2:
	match side:
		"left":
			return Vector2.RIGHT
		"right":
			return Vector2.LEFT
		"top":
			return Vector2.DOWN
		_:
			return Vector2.UP


func _push_ball_out_of_sand(side: String, depth: float, ball_pos: Vector2, ball_size: float) -> Vector2:
	var half: float = ball_size * 0.5
	match side:
		"left":
			ball_pos.x = max(ball_pos.x, depth + half + 1.0)
		"right":
			ball_pos.x = min(ball_pos.x, FIELD_WIDTH - depth - half - 1.0)
		"top":
			ball_pos.y = max(ball_pos.y, depth + half + 1.0)
		"bottom":
			ball_pos.y = min(ball_pos.y, FIELD_HEIGHT - depth - half - 1.0)
	return ball_pos


func _erode_sand_range(side: String, start_pos: float, end_pos: float, amount: float, radius_segments: int) -> float:
	var total: float = 0.0
	var distance: float = abs(end_pos - start_pos)
	var steps: int = max(1, int(ceil(distance / SAND_SEG_SIZE)))
	for step in range(steps + 1):
		var t: float = float(step) / max(1.0, float(steps))
		total += _erode_sand_at(side, lerp(start_pos, end_pos, t), amount, radius_segments)
	return total


# Sand clusters cover only part of the wall, so a dash clipping a cluster edge erodes
# over a fraction of its travel. The spray reads the span recorded here to emit on ground
# that actually lost depth instead of anywhere along the swept path.
func _begin_sand_erode_tracking() -> void:
	_sand_erode_hit_min = INF
	_sand_erode_hit_max = -INF


# Recorded per ERODED SEGMENT, not per erode call: an erode call spreads over
# radius_segments either side, so its centre can sit on bare floor while only a
# neighbouring column loses depth. Using the call centre would place the span where
# nothing was actually carved.
func _note_sand_erode_hit(side: String, index: int) -> void:
	var segment_start: float = _get_sand_axis_start(side) + float(index) * SAND_SEG_SIZE
	_sand_erode_hit_min = minf(_sand_erode_hit_min, segment_start)
	_sand_erode_hit_max = maxf(_sand_erode_hit_max, segment_start + SAND_SEG_SIZE)


func _has_sand_erode_hit_span() -> bool:
	return _sand_erode_hit_max >= _sand_erode_hit_min


func _erode_sand_at(side: String, world_pos: float, amount: float, radius_segments: int) -> float:
	var depths: Array = _get_sand_depths(side)
	if depths.is_empty() or amount <= 0.0:
		return 0.0
	var local: float = (world_pos - _get_sand_axis_start(side)) / SAND_SEG_SIZE
	var center_index: int = int(round(local))
	var total: float = 0.0
	var start_index: int = max(0, center_index - radius_segments)
	var end_index: int = min(depths.size(), center_index + radius_segments + 1)
	for index in range(start_index, end_index):
		var dist: float = abs(float(index) - local)
		var factor: float = max(0.0, 1.0 - dist / float(radius_segments + 1))
		var before: float = max(0.0, float(depths[index]))
		var erode: float = min(before, amount * factor)
		if erode <= 0.0:
			continue
		depths[index] = before - erode
		total += erode
		_note_sand_erode_hit(side, index)
	if side == "bottom":
		sand_depths = depths
	if total > 0.0:
		_mark_sand_visual_dirty()
	return total


func _spawn_sand_particles(side: String, pos: Vector2, eroded: float) -> void:
	var count: int = max(3, min(10, int(eroded / 3.0)))
	var sand_color: Color = _get_weather_color("sand")
	for _i in range(count):
		var velocity := _get_sand_particle_velocity(side)
		weather_particles.append(WeatherEventPayloadFactory.build_sand_erosion_particle(
			pos,
			velocity,
			sand_color
		))
	# Shares the sand ceiling with paddle kick-up: both run during ACTIVE sand weather and
	# would otherwise stack without bound. (Dissolve is a separate phase — sand collision
	# is off and weather is inactive, so neither of these producers runs then.)
	_trim_weather_particles_for_type("sand", SAND_VISUAL_PARTICLE_CAP)


func _spawn_sand_kickup_spray(
	side: String,
	eroded: float,
	travel_dir: float,
	moved: float,
	is_dash: bool
) -> void:
	if not _is_sand_spray_supported_side(side):
		return
	# The eroded total is the only proof sand was actually there: sand clusters cover a
	# few of the 56 segments, so keying on "is dashing" alone puffs over bare floor.
	if eroded <= 0.0 or is_zero_approx(travel_dir):
		return
	# A wall-pinned dash keeps carving depth with zero displacement; spraying there
	# would read as a stationary fountain, so relative motion is what earns the grains.
	if moved < SAND_SPRAY_MIN_TRAVEL_PX:
		return
	var rate: float = SAND_DASH_SPRAY_GRAINS_PER_ERODE_UNIT if is_dash else SAND_WALK_SPRAY_GRAINS_PER_ERODE_UNIT
	var max_per_frame: int = SAND_DASH_SPRAY_MAX_PER_FRAME if is_dash else SAND_WALK_SPRAY_MAX_PER_FRAME
	var carry: float = _get_sand_spray_carry(side) + eroded * rate
	var count: int = mini(int(carry), max_per_frame)
	_set_sand_spray_carry(side, clampf(carry - float(count), 0.0, 2.0))
	if count <= 0:
		return
	# Emit only across the segments that actually lost depth this frame, and only where
	# the dune mesh actually exists (it stops at the outer segment CENTRES).
	if not _has_sand_erode_hit_span():
		return
	var crest_span: Vector2 = _get_sand_crest_span(side)
	if crest_span.y <= crest_span.x:
		return
	var span_from: float = clampf(_sand_erode_hit_min, crest_span.x, crest_span.y)
	var span_to: float = clampf(_sand_erode_hit_max, crest_span.x, crest_span.y)
	var outward: float = -1.0 if side == "bottom" else 1.0
	var speed_scale: float = clampf(moved / SAND_SPRAY_SPEED_REFERENCE_PX, 0.55, 2.1)
	var sand_color: Color = _get_weather_color("sand")
	var min_stride: int = _get_sand_spray_min_render_stride()
	var ordinal: int = _get_sand_spray_ordinal(side)
	var emitted := 0
	for _grain in range(count):
		# Along-wall scatter is decided HERE, before the crest lookup, so each grain's
		# spawn height belongs to the very column it sits on — and it is clamped back
		# inside the eroded span, or the scatter itself would fling grains onto ground the
		# paddle never touched.
		var along: float = clampf(
			lerpf(span_from, span_to, _sand_spray_rng.randf()) + _sand_spray_rng.randf_range(-5.0, 5.0),
			span_from,
			span_to
		)
		# Even inside the eroded sub-span the wall can have gaps, so a grain is only
		# thrown where there is still a dune to throw it off.
		if _get_sand_depth_at(side, along, min_stride) <= SAND_SPRAY_MIN_CREST_DEPTH:
			continue
		weather_particles.append(WeatherEventPayloadFactory.build_sand_kickup_particle(
			_get_sand_surface_point(side, along, min_stride),
			travel_dir,
			outward,
			speed_scale,
			ordinal % SAND_SPRAY_TRAILING_STRIDE != 0,
			sand_color,
			_sand_spray_rng
		))
		ordinal += 1
		emitted += 1
	_set_sand_spray_ordinal(side, ordinal)
	if emitted > 0:
		_trim_weather_particles_for_type("sand", SAND_VISUAL_PARTICLE_CAP)


# Only the horizontal walls are supported: build_sand_kickup_particle hardcodes vx to
# the travel axis and vy to the wall normal, which is the paddle-scrape geometry. A
# left/right caller would need both axes swapped, so it is rejected at the gate rather
# than silently sprayed sideways (and _get_sand_spray_ordinal would file it under the
# boss besides).
func _is_sand_spray_supported_side(side: String) -> bool:
	return side == "bottom" or side == "top"


func _get_sand_surface_point(side: String, world_pos: float, min_stride: int = 1) -> Vector2:
	var depth: float = _get_sand_depth_at(side, world_pos, min_stride)
	# Strictly outward. Any inward component would seat the grain below the painted crest,
	# which is what makes a spray read as climbing out of solid sand rather than off it.
	var lift: float = _sand_spray_rng.randf_range(1.5, 6.5)
	if side == "top":
		return Vector2(world_pos, depth + lift)
	return Vector2(world_pos, FIELD_HEIGHT - depth - lift)


# Depth to launch a grain from, chosen so the spawn point is never INSIDE the painted
# dune at any render quality.
#
# The renderer walks the wall with a stride that depends on the draw-time LOD (1 at full
# quality, up to SAND_RENDER_STRIDE_SEVERE_LOD at the shipped severe budget) and
# straight-lines between the sampled segment centres, then adds a small crest jitter. So
# a trench carved into a segment the renderer did not sample is simply bridged over: the
# dune still LOOKS intact there. Spraying from that trench's own depth would start the
# grain below the painted surface and it would climb out of solid sand.
#
# This runs on the physics path and cannot know which LOD will draw the frame, so it
# evaluates the crest EACH shipped stride would paint and takes the highest. That is at
# or above every candidate surface (no burying) while staying a real surface — a raw
# neighbourhood maximum also clears them all, but it can borrow an unrelated peak several
# segments away and launch the grain tens of pixels above the sand.
func _get_sand_depth_at(side: String, world_pos: float, min_stride: int = 1) -> float:
	var depths: Array = _get_sand_depths(side)
	if depths.is_empty():
		return 0.0
	var crest: float = 0.0
	for stride in SAND_SPRAY_RENDER_STRIDES:
		var candidate: int = int(stride)
		if candidate < min_stride:
			continue
		crest = maxf(crest, _get_sand_drawn_depth(depths, side, world_pos, candidate))
	return crest


# The stride the wall will actually be drawn with, resolved from the LIVE render quality
# rather than assumed. Taking the maximum over EVERY stride is safe but not honest: where
# a fine stride sees a spike the shipped severe stride bridges past, it starts the grain
# tens of pixels off the dune the player is really looking at.
#
# Only per-context modifiers (Viper airborne) can push the draw-time scale BELOW what is
# visible from here, and a lower scale only ever means a coarser stride — so every stride
# at or above this one stays a candidate, and the shipped severe case resolves to severe
# alone.
func _get_sand_spray_min_render_stride() -> int:
	return WeatherEventRenderBudget.get_sand_render_stride(BattleRenderQuality.effect_scale())


# The textured dune mesh only spans the FIRST to the LAST segment centre — it stitches
# consecutive crest vertices, and those sit at centres. The eroded span reaches the outer
# segment BOUNDARIES, half a segment further out at each end, where no dune is painted at
# all. Emission is clamped to the crest span so a wall-end dash cannot throw grains off
# geometry that does not exist.
func _get_sand_crest_span(side: String) -> Vector2:
	var depths: Array = _get_sand_depths(side)
	var axis_start: float = _get_sand_axis_start(side)
	if depths.is_empty():
		return Vector2(axis_start, axis_start)
	return Vector2(
		axis_start + SAND_SEG_SIZE * 0.5,
		axis_start + float(depths.size() - 1) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
	)


# The crest one specific render stride paints at world_pos: the renderer samples every
# stride-th segment, anchors a vertex at each sampled segment's CENTRE, and straight-lines
# between them (always closing on the final segment).
func _get_sand_drawn_depth(depths: Array, side: String, world_pos: float, stride: int) -> float:
	var last_index: int = depths.size() - 1
	var axis_start: float = _get_sand_axis_start(side)
	var centred: float = (world_pos - axis_start) / SAND_SEG_SIZE - 0.5
	var step: int = maxi(stride, 1)
	var low_index: int = clampi(int(floor(centred / float(step))) * step, 0, last_index)
	if low_index >= last_index:
		return maxf(0.0, float(depths[last_index]))
	var high_index: int = mini(low_index + step, last_index)
	var low_x: float = axis_start + float(low_index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
	var high_x: float = axis_start + float(high_index) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
	var blend: float = clampf((world_pos - low_x) / maxf(0.001, high_x - low_x), 0.0, 1.0)
	return maxf(0.0, lerpf(float(depths[low_index]), float(depths[high_index]), blend))


func _get_sand_spray_carry(side: String) -> float:
	return _sand_player_spray_carry if side == "bottom" else _sand_boss_spray_carry


func _set_sand_spray_carry(side: String, value: float) -> void:
	if side == "bottom":
		_sand_player_spray_carry = value
	else:
		_sand_boss_spray_carry = value


func _get_sand_spray_ordinal(side: String) -> int:
	return _sand_player_spray_ordinal if side == "bottom" else _sand_boss_spray_ordinal


func _set_sand_spray_ordinal(side: String, value: int) -> void:
	if side == "bottom":
		_sand_player_spray_ordinal = value
	else:
		_sand_boss_spray_ordinal = value


func _reset_sand_spray_carry() -> void:
	_sand_player_spray_carry = 0.0
	_sand_boss_spray_carry = 0.0
	_sand_player_spray_ordinal = 0
	_sand_boss_spray_ordinal = 0


func _update_sand_dissolve(fps_scale: float) -> void:
	if not sand_dissolving:
		return
	var step: float = max(0.0, fps_scale)
	_sand_dissolve_timer = max(0.0, _sand_dissolve_timer - step)
	var progress: float = clamp(1.0 - (_sand_dissolve_timer / SAND_DISSOLVE_FRAMES), 0.0, 1.0)
	var shrink_per_frame: float = clamp(0.06 + 0.12 * progress, 0.0, 0.5)
	var keep_factor: float = pow(1.0 - shrink_per_frame, step)
	var changed := false
	for side in ["left", "right", "top", "bottom"]:
		var depths: Array = _get_sand_depths(str(side))
		if depths.is_empty():
			continue
		for index in range(depths.size()):
			var before: float = float(depths[index])
			if before <= 0.0:
				continue
			var after: float = before * keep_factor
			if after < 0.5:
				after = 0.0
			if not is_equal_approx(after, before):
				depths[index] = after
				changed = true
		if str(side) == "bottom":
			sand_depths = depths
	if changed:
		_mark_sand_visual_dirty()

	_sand_dissolve_particle_timer += step
	if _sand_dissolve_particle_timer >= SAND_DISSOLVE_PARTICLE_INTERVAL_FRAMES:
		_sand_dissolve_particle_timer = 0.0
		_spawn_sand_dissolve_particles(progress)

	if _sand_dissolve_timer <= 0.0:
		sand_dissolving = false
		_sand_dissolve_particle_timer = 0.0
		sand_wall_depths.clear()
		sand_depths.clear()
		_mark_sand_visual_dirty()


func _spawn_sand_dissolve_particles(progress: float) -> void:
	var per_wall: int = max(1, int(round(4.0 * (1.0 - progress))))
	var sand_color: Color = _get_weather_color("sand")
	for side in ["left", "right", "top", "bottom"]:
		var depths: Array = _get_sand_depths(str(side))
		if depths.is_empty():
			continue
		var candidates: Array = []
		for index in range(depths.size()):
			if float(depths[index]) > 1.0:
				candidates.append(index)
		if candidates.is_empty():
			continue
		for _i in range(per_wall):
			var idx: int = int(candidates[randi() % candidates.size()])
			var depth: float = float(depths[idx])
			var seg_center: float = _get_sand_axis_start(str(side)) + float(idx) * SAND_SEG_SIZE + SAND_SEG_SIZE * 0.5
			var px: float = 0.0
			var py: float = 0.0
			var vx: float = 0.0
			var vy: float = 0.0
			match str(side):
				"left":
					px = depth * 0.5
					py = seg_center
					vx = randf_range(0.3, 1.5)
					vy = randf_range(0.5, 2.0)
				"right":
					px = FIELD_WIDTH - depth * 0.5
					py = seg_center
					vx = randf_range(-1.5, -0.3)
					vy = randf_range(0.5, 2.0)
				"top":
					px = seg_center
					py = depth * 0.5
					vx = randf_range(-1.0, 1.0)
					vy = randf_range(0.5, 2.5)
				_:
					px = seg_center
					py = FIELD_HEIGHT - depth * 0.5
					vx = randf_range(-1.0, 1.0)
					vy = randf_range(-0.5, 1.0)
			weather_particles.append(WeatherEventPayloadFactory.build_sand_dissolve_particle(
				Vector2(px, py),
				Vector2(vx, vy),
				sand_color
			))


func _clear_non_sand_particles() -> void:
	var write_index := 0
	for index in range(weather_particles.size()):
		var particle: Dictionary = _get_dict(weather_particles[index])
		if str(particle.get("kind", "")) == "sand":
			if write_index != index:
				weather_particles[write_index] = particle
			write_index += 1
	if write_index < weather_particles.size():
		weather_particles.resize(write_index)


func _get_sand_particle_velocity(side: String) -> Vector2:
	match side:
		"left":
			return Vector2(randf_range(1.0, 3.5), randf_range(-1.5, 1.5))
		"right":
			return Vector2(randf_range(-3.5, -1.0), randf_range(-1.5, 1.5))
		"top":
			return Vector2(randf_range(-1.5, 1.5), randf_range(1.0, 3.5))
		_:
			return Vector2(randf_range(-1.5, 1.5), randf_range(-3.5, -1.0))


func _make_sand_harvest_particle(side: String, index: int, depth: float) -> Dictionary:
	var rect := _get_sand_segment_rect(side, index, depth)
	return {
		"x": rect.get_center().x,
		"y": rect.get_center().y,
		"size": clamp(depth / 14.0, 2.0, 6.0),
		"color": _get_weather_color("sand"),
		"kind": "sand",
		"weather_type": "sand",
		"life": 1.0,
		"max_life": 1.0,
	}


func _get_dash_snapshot(registry: Object) -> Dictionary:
	var dash_state: Object = _get_instance(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("get_snapshot"):
		var snapshot: Variant = dash_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _get_boss_dash_snapshot(registry: Object) -> Dictionary:
	var ai_state: Object = _get_instance(registry, "boss_ai_state")
	if ai_state != null and ai_state.has_method("get_dash_token_snapshot"):
		var snapshot: Variant = ai_state.get_dash_token_snapshot()
		if snapshot is Dictionary:
			return snapshot
	return {}


func _draw_weather_message(canvas: CanvasItem) -> void:
	var text := warning_text
	var timer := warning_timer_frames
	var color := _get_weather_color(weather_event_type)
	if timer <= 0.0 and end_timer_frames > 0.0:
		text = end_text
		timer = end_timer_frames
		color = Color(0.55, 1.0, 0.62, 1.0)
	if timer <= 0.0 or text == "":
		return
	var alpha := 1.0
	if timer > 150.0:
		alpha = clamp((180.0 - timer) / 30.0, 0.0, 1.0)
	elif timer < 30.0:
		alpha = clamp(timer / 30.0, 0.0, 1.0)
	var font: Font = ThemeDB.fallback_font
	var font_size := 22
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := Vector2(FIELD_WIDTH * 0.5 - text_size.x * 0.5, FIELD_HEIGHT * 0.33)
	var panel := Rect2(baseline - Vector2(24.0, 28.0), Vector2(text_size.x + 48.0, text_size.y + 26.0))
	canvas.draw_rect(panel, Color(0.0, 0.0, 0.03, 0.58 * alpha))
	canvas.draw_rect(panel, Color(color.r, color.g, color.b, 0.72 * alpha), false, 2.0)
	canvas.draw_string(font, baseline + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72 * alpha))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color.r, color.g, color.b, alpha))


func _get_start_text(next_type: String, direction: int) -> String:
	match next_type:
		"breeze":
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
				return "A breeze blows %s" % ("left" if direction < 0 else "right")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
				return "Una brisa sopla hacia la %s" % ("izquierda" if direction < 0 else "derecha")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
				return "Uma brisa sopra para a %s" % ("esquerda" if direction < 0 else "direita")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
				return "Легкий ветер дует %s" % ("влево" if direction < 0 else "вправо")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
				return "微风向%s吹拂" % ("左" if direction < 0 else "右")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
				return "そよ風が%sへ吹きます" % ("左" if direction < 0 else "右")
			return "미풍이 %s쪽으로 붑니다" % ("왼" if direction < 0 else "오른")
		"gust":
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
				return "A strong gust drives %s" % ("left" if direction < 0 else "right")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
				return "Una ráfaga fuerte empuja hacia la %s" % ("izquierda" if direction < 0 else "derecha")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
				return "Uma rajada forte empurra para a %s" % ("esquerda" if direction < 0 else "direita")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
				return "Сильный порыв несет %s" % ("влево" if direction < 0 else "вправо")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
				return "强风向%s侧猛吹" % ("左" if direction < 0 else "右")
			if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
				return "強風が%sへ吹き荒れます" % ("左" if direction < 0 else "右")
			return "강풍이 %s쪽으로 몰아칩니다" % ("왼" if direction < 0 else "오른")
		"fire":
			return LanguageSettings.translate_text("화재가 번집니다")
		"ice":
			return LanguageSettings.translate_text("빙판이 깔립니다")
		"rain":
			return LanguageSettings.translate_text("소나기가 쏟아집니다")
		"hail":
			return LanguageSettings.translate_text("우박이 떨어집니다")
		"sand":
			return LanguageSettings.translate_text("사막화가 시작됩니다")
	return ""


func _get_end_text(ended_type: String) -> String:
	match ended_type:
		"breeze":
			return LanguageSettings.translate_text("미풍이 잦아들었습니다")
		"gust":
			return LanguageSettings.translate_text("강풍이 멎었습니다")
		"fire":
			return LanguageSettings.translate_text("불길이 꺼졌습니다")
		"ice":
			return LanguageSettings.translate_text("빙판이 녹았습니다")
		"rain":
			return LanguageSettings.translate_text("소나기가 그쳤습니다")
		"hail":
			return LanguageSettings.translate_text("우박이 그쳤습니다")
		"sand":
			return LanguageSettings.translate_text("모래가 가라앉았습니다")
	return ""


func _get_weather_color(next_type: String) -> Color:
	match next_type:
		"breeze":
			return Color(180.0 / 255.0, 230.0 / 255.0, 1.0, 1.0)
		"gust":
			return Color(1.0, 205.0 / 255.0, 110.0 / 255.0, 1.0)
		"fire":
			return Color(1.0, 95.0 / 255.0, 35.0 / 255.0, 1.0)
		"ice":
			return Color(145.0 / 255.0, 225.0 / 255.0, 1.0, 1.0)
		"rain":
			return Color(95.0 / 255.0, 180.0 / 255.0, 1.0, 1.0)
		"hail":
			return Color(215.0 / 255.0, 240.0 / 255.0, 1.0, 1.0)
		"sand":
			return Color(224.0 / 255.0, 190.0 / 255.0, 120.0 / 255.0, 1.0)
	return Color.WHITE


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner != null:
		var value: Variant = owner.get(key)
		if value != null:
			return value
	return fallback


func _get_result_or_owner_value(result: Dictionary, owner: Object, key: String, fallback: Variant) -> Variant:
	if result.has(key):
		return result[key]
	return _safe_owner_get(owner, key, fallback)


func _get_result_or_owner_vec(result: Dictionary, owner: Object, key: String, fallback: Vector2) -> Vector2:
	return _get_vector2(_get_result_or_owner_value(result, owner, key, fallback), fallback)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
