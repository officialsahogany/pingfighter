extends RefCounted

const HermesShoesFxHost := preload("res://scripts/items/mythic_item_hermes_shoes_fx_host.gd")
const HornStrawberryFieldRenderer := preload("res://scripts/items/mythic_item_horn_strawberry_field_renderer.gd")
const PoseidonFieldRenderer := preload("res://scripts/items/mythic_item_poseidon_field_renderer.gd")
const RagnarokFieldRenderer := preload("res://scripts/items/mythic_item_ragnarok_field_renderer.gd")
const HERMES_SHOES_FX_HOST_NAME := "MythicHermesShoesFxHost"

const MAX_RENDERED_VENOM_MIST_PARTICLES := 32
const MAX_RENDERED_RAINBOW_FUR_GLOVE_PARTICLES := 20
const MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES := 28
const MAX_RENDERED_SHRAPNEL_ARMOR_SHARDS := 10
const MAX_RENDERED_SHRAPNEL_ARMOR_TRAIL_POINTS := 2
const MAX_RENDERED_SHRAPNEL_ARMOR_DUST_PARTICLES := 32
const MAX_RENDERED_KNEE_PADS_PARTICLES := 16
const MAX_RENDERED_SOUL_BURST_WIND_TRAILS := 4
const MAX_RENDERED_SOUL_BURST_SHOCKWAVES := 3
const MAX_RENDERED_SOUL_BURST_PARTICLES := 16
const MAX_RENDERED_POSEIDON_WATER_TRAIL := 12
const MAX_RENDERED_POSEIDON_PARTICLES := 24
const MAX_RENDERED_POSEIDON_EXPLOSION_PARTICLES := 6
const MAX_RENDERED_HORN_STRAWBERRY_PROJECTILES := 6
const MAX_RENDERED_HORN_STRAWBERRY_BARRIERS := 3
const MAX_RENDERED_HORN_STRAWBERRY_TRAILS := 8
const MAX_RENDERED_HORN_STRAWBERRY_BOMBS := 18
const MAX_RENDERED_HORN_STRAWBERRY_EXPLOSIONS := 8
const MAX_RENDERED_HORN_STRAWBERRY_PAINT := 16
const MAX_RENDERED_RAGNAROK_SPARKS := 12
const RAGNAROK_IMPACT_RING_SEGMENTS := 24
const RAGNAROK_ELECTRIC_ELLIPSE_SEGMENTS := 16
const SHRAPNEL_ARMOR_FLASH_ARC_SEGMENTS := 12
const SHRAPNEL_ARMOR_BOSS_IMPACT_ARC_SEGMENTS := 18
const KNEE_PADS_RING_SEGMENTS := 44
const RAINBOW_FUR_GLOVE_RING_SEGMENTS := 44
const SOUL_BURST_ELLIPSE_SEGMENTS := 48
const MAX_POSEIDON_TRAIL_ARCS := 4
const POSEIDON_TRAIL_ARC_SEGMENTS := 8
const ADVERSITY_ARMOR_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const ADVERSITY_ARMOR_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const ADVERSITY_ARMOR_TIMER_STACK_SPACING := 18.0
const ADVERSITY_ARMOR_TIMER_STACK_KEY := "adversity_armor"

var _hermes_fx_host: Node = null
var _hermes_fx_host_canvas: Object = null
var _hermes_fx_host_add_pending := false
var _horn_strawberry_field_renderer: Object = HornStrawberryFieldRenderer.new()
var _poseidon_field_renderer: Object = PoseidonFieldRenderer.new()
var _ragnarok_field_renderer: Object = RagnarokFieldRenderer.new()


func draw_field_effects(
	runtime: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	ragnarok_impact_effect_duration: float,
	ragnarok_electric_stun_intensity: float,
	perf_logger: Object = null,
	timer_stack: Object = null,
	constants: Dictionary = {}
) -> void:
	if canvas == null or runtime == null:
		return
	var impact_elapsed: float = runtime.ragnarok_runtime.get_impact_elapsed(runtime)
	var impact_active: bool = impact_elapsed < ragnarok_impact_effect_duration
	var stun_active: bool = runtime.ragnarok_boss_stun_timer_frames > 0.0
	var poseidon_visible: bool = runtime.poseidon_capture_active or runtime.poseidon_vortex_active or not runtime.poseidon_particles.is_empty() or not runtime.poseidon_water_trail.is_empty() or runtime.poseidon_explosion_active
	var knee_pads_visible: bool = runtime.knee_pads_flash_timer_frames > 0.0 or not runtime.knee_pads_particles.is_empty()
	var soul_burst_visible: bool = runtime.soul_burst_effect_timer_frames > 0.0 or not runtime.soul_burst_particles.is_empty() or not runtime.soul_burst_shockwaves.is_empty() or not runtime.soul_burst_wind_trails.is_empty()
	var foul_whistle_visible: bool = runtime.foul_whistle_state.animation_active
	var revival_visible: bool = runtime.revival_state.is_effect_active()
	var sensor_visible: bool = runtime.sensor_auto_dash_effect_timer_frames > 0.0
	var venom_mist_visible: bool = runtime.venom_mist_field_active or not runtime.venom_mist_particles.is_empty()
	var rainbow_glove_visible: bool = runtime.rainbow_fur_glove_aura_timer_frames > 0.0 or not runtime.rainbow_fur_glove_particles.is_empty()
	var adversity_armor_visible: bool = runtime.adversity_armor_runtime.is_effect_active(runtime)
	var shrapnel_armor_visible: bool = runtime.shrapnel_armor_runtime.is_effect_active(runtime)
	var celestial_armor_visible: bool = runtime.celestial_armor_state.is_wave_active()
	var hermes_visible: bool = runtime.hermes_shoes_state.is_visible(runtime.is_hermes_shoes_active())
	var baal_visible: bool = runtime.baal_boots_effect_state.is_visible(
		runtime.baal_boots_weather_state.cinematic_active,
		runtime.baal_boots_weather_state.round_effect_active
	)
	var horn_strawberry_context: Dictionary = runtime.get_horn_strawberry_context()
	var horn_strawberry_visible: bool = (
		runtime.horn_strawberry_mask_runtime.has_visible_effects(runtime)
		or _horn_strawberry_field_renderer.is_transform_visible(horn_strawberry_context)
	)
	var acquisition_visible: bool = runtime.acquisition_cinematic != null and runtime.acquisition_cinematic.is_active()
	if not impact_active and not stun_active and runtime.ragnarok_sparks.is_empty() and not poseidon_visible and not knee_pads_visible and not soul_burst_visible and not foul_whistle_visible and not revival_visible and not sensor_visible and not venom_mist_visible and not rainbow_glove_visible and not adversity_armor_visible and not shrapnel_armor_visible and not celestial_armor_visible and not hermes_visible and not baal_visible and not horn_strawberry_visible and not acquisition_visible:
		return
	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "mythic.field_effects") else null
	var field_size: Vector2 = _as_vector2(constants.get("field_size", Vector2(760.0, 750.0)), Vector2(760.0, 750.0))
	if horn_strawberry_visible:
		var horn_sample_start: int = _perf_begin(detail_perf_logger)
		_horn_strawberry_field_renderer.draw_horn_strawberry_effects(
			canvas,
			shake_offset,
			horn_strawberry_context,
			runtime.get_horn_strawberry_eat_context(),
			runtime.get_horn_strawberry_field_context(),
			runtime.get_horn_strawberry_horn_charge_context(),
			runtime.get_horn_strawberry_bomb_context(),
			{
				"projectiles": MAX_RENDERED_HORN_STRAWBERRY_PROJECTILES,
				"barriers": MAX_RENDERED_HORN_STRAWBERRY_BARRIERS,
				"trails": MAX_RENDERED_HORN_STRAWBERRY_TRAILS,
				"bombs": MAX_RENDERED_HORN_STRAWBERRY_BOMBS,
				"explosions": MAX_RENDERED_HORN_STRAWBERRY_EXPLOSIONS,
				"paint": MAX_RENDERED_HORN_STRAWBERRY_PAINT,
			}
		)
		_perf_end(detail_perf_logger, "mythic.horn_strawberry", horn_sample_start)
	if baal_visible:
		var baal_sample_start: int = _perf_begin(detail_perf_logger)
		runtime.baal_boots_effect_renderer.draw(
			canvas,
			shake_offset,
			runtime.baal_boots_weather_state,
			runtime.baal_boots_effect_state,
			field_size,
			runtime.baal_boots_runtime.get_weather_color(runtime.baal_boots_weather_state.get_draw_weather_type())
		)
		_perf_end(detail_perf_logger, "mythic.baal_boots", baal_sample_start)
	if hermes_visible:
		var hermes_sample_start: int = _perf_begin(detail_perf_logger)
		draw_hermes_shoes_effect(
			canvas,
			shake_offset,
			runtime.hermes_shoes_state,
			runtime.is_hermes_shoes_active(),
			float(constants.get("hermes_trail_life_frames", 24.0)),
			float(constants.get("hermes_move_trail_threshold", 2.0))
		)
		_perf_end(detail_perf_logger, "mythic.hermes_shoes", hermes_sample_start)
	if venom_mist_visible:
		var venom_sample_start: int = _perf_begin(detail_perf_logger)
		draw_venom_mist_effect(
			canvas,
			shake_offset,
			runtime.venom_mist_center,
			runtime.venom_mist_duration_frames,
			runtime.venom_mist_timer_frames,
			runtime.venom_mist_particles,
			runtime.venom_mist_boss_in_field,
			float(constants.get("venom_mist_radius", 120.0)),
			runtime.venom_mist_runtime.get_alpha(runtime)
		)
		_perf_end(detail_perf_logger, "mythic.venom_mist", venom_sample_start)
	if rainbow_glove_visible:
		var rainbow_sample_start: int = _perf_begin(detail_perf_logger)
		draw_rainbow_fur_glove_effect(
			canvas,
			shake_offset,
			runtime.rainbow_fur_glove_aura_center,
			runtime.rainbow_fur_glove_aura_life_frames,
			runtime.rainbow_fur_glove_aura_timer_frames,
			runtime.rainbow_fur_glove_aura_phase,
			runtime.rainbow_fur_glove_particles,
			_as_array(constants.get("rainbow_fur_glove_colors", []))
		)
		_perf_end(detail_perf_logger, "mythic.rainbow_fur_glove", rainbow_sample_start)
	if adversity_armor_visible:
		var adversity_sample_start: int = _perf_begin(detail_perf_logger)
		draw_adversity_armor_effect(
			canvas,
			shake_offset,
			runtime.get_adversity_armor_context(),
			runtime.adversity_armor_aura_particles,
			runtime.adversity_armor_barrier_particles,
			timer_stack
		)
		_perf_end(detail_perf_logger, "mythic.adversity_armor", adversity_sample_start)
	if shrapnel_armor_visible:
		var shrapnel_sample_start: int = _perf_begin(detail_perf_logger)
		draw_shrapnel_armor_effect(
			canvas,
			shake_offset,
			runtime.shrapnel_armor_flash_timer_frames,
			runtime.shrapnel_armor_flash_center,
			runtime.shrapnel_armor_shards,
			runtime.shrapnel_armor_dust_particles,
			runtime.shrapnel_armor_boss_impact_timer_frames,
			runtime.shrapnel_armor_boss_impact_center,
			float(constants.get("shrapnel_armor_flash_frames", 8.0)),
			float(constants.get("shrapnel_armor_shard_life_frames", 120.0)),
			float(constants.get("shrapnel_armor_boss_impact_frames", 15.0))
		)
		_perf_end(detail_perf_logger, "mythic.shrapnel_armor", shrapnel_sample_start)
	if celestial_armor_visible:
		var celestial_sample_start: int = _perf_begin(detail_perf_logger)
		draw_celestial_armor_effect(
			canvas,
			shake_offset,
			runtime.celestial_armor_state,
			float(constants.get("celestial_wave_radius_max", 110.0)),
			int(constants.get("celestial_shard_count", 10)),
			int(constants.get("celestial_arc_segments", 18))
		)
		_perf_end(detail_perf_logger, "mythic.celestial_armor", celestial_sample_start)
	if poseidon_visible:
		var poseidon_sample_start: int = _perf_begin(detail_perf_logger)
		_poseidon_field_renderer.draw_poseidon_effects(
			canvas,
			shake_offset,
			runtime.poseidon_water_trail,
			runtime.poseidon_particles,
			runtime.poseidon_explosion_active,
			runtime.poseidon_player_center,
			runtime.poseidon_explosion_timer,
			runtime.poseidon_explosion_particles,
			float(constants.get("poseidon_explosion_flash_duration", 0.4)),
			MAX_RENDERED_POSEIDON_WATER_TRAIL,
			MAX_RENDERED_POSEIDON_PARTICLES,
			MAX_RENDERED_POSEIDON_EXPLOSION_PARTICLES,
			MAX_POSEIDON_TRAIL_ARCS,
			POSEIDON_TRAIL_ARC_SEGMENTS
		)
		_perf_end(detail_perf_logger, "mythic.poseidon", poseidon_sample_start)
	if knee_pads_visible:
		var knee_sample_start: int = _perf_begin(detail_perf_logger)
		draw_knee_pads_effects(
			canvas,
			shake_offset,
			runtime.knee_pads_flash_center,
			runtime.knee_pads_flash_timer_frames,
			runtime.knee_pads_particles,
			float(constants.get("knee_pads_flash_duration_frames", 30.0))
		)
		_perf_end(detail_perf_logger, "mythic.knee_pads", knee_sample_start)
	if soul_burst_visible:
		var soul_sample_start: int = _perf_begin(detail_perf_logger)
		draw_soul_burst_effects(
			canvas,
			shake_offset,
			runtime.soul_burst_center,
			runtime.soul_burst_direction,
			runtime.soul_burst_wind_trails,
			runtime.soul_burst_shockwaves,
			runtime.soul_burst_particles,
			float(constants.get("soul_burst_particle_alpha_cutoff", 0.02))
		)
		_perf_end(detail_perf_logger, "mythic.soul_burst", soul_sample_start)
	if foul_whistle_visible:
		var foul_sample_start: int = _perf_begin(detail_perf_logger)
		runtime.support_effect_renderer.draw_foul_whistle_effect(
			canvas,
			shake_offset,
			runtime.foul_whistle_state,
			field_size,
			float(constants.get("foul_whistle_total_frames", 120.0)),
			int(constants.get("foul_whistle_referee_frame_count", 4)),
			float(constants.get("foul_whistle_referee_frame_frames", 6.0))
		)
		_perf_end(detail_perf_logger, "mythic.foul_whistle", foul_sample_start)
	if revival_visible:
		var revival_sample_start: int = _perf_begin(detail_perf_logger)
		runtime.revival_runtime.draw_effect(runtime, canvas, shake_offset, field_size)
		_perf_end(detail_perf_logger, "mythic.revival", revival_sample_start)
	if sensor_visible:
		var sensor_sample_start: int = _perf_begin(detail_perf_logger)
		runtime.support_effect_renderer.draw_sensor_auto_dash_effect(
			canvas,
			shake_offset,
			runtime.sensor_auto_dash_effect_timer_frames,
			runtime.sensor_auto_dash_center,
			runtime.sensor_last_dash_direction,
			float(constants.get("sensor_auto_dash_effect_frames", 34.0))
		)
		_perf_end(detail_perf_logger, "mythic.sensor", sensor_sample_start)
	var center: Vector2 = runtime.ragnarok_impact_center + shake_offset
	if impact_active:
		var impact_sample_start: int = _perf_begin(detail_perf_logger)
		_ragnarok_field_renderer.draw_ragnarok_impact_rings(
			canvas,
			center,
			impact_elapsed,
			ragnarok_impact_effect_duration,
			RAGNAROK_IMPACT_RING_SEGMENTS
		)
		_perf_end(detail_perf_logger, "mythic.ragnarok_impact", impact_sample_start)
	if stun_active:
		var stun_sample_start: int = _perf_begin(detail_perf_logger)
		_ragnarok_field_renderer.draw_ragnarok_electric_stun_overlay(
			canvas,
			center,
			runtime.ragnarok_stun_target_size,
			ragnarok_electric_stun_intensity,
			RAGNAROK_ELECTRIC_ELLIPSE_SEGMENTS
		)
		_perf_end(detail_perf_logger, "mythic.ragnarok_stun", stun_sample_start)
	if not runtime.ragnarok_sparks.is_empty():
		var sparks_sample_start: int = _perf_begin(detail_perf_logger)
		_ragnarok_field_renderer.draw_ragnarok_sparks(
			canvas,
			center,
			runtime.ragnarok_sparks,
			MAX_RENDERED_RAGNAROK_SPARKS,
			float(constants.get("ragnarok_particle_alpha_cutoff", 0.02))
		)
		_perf_end(detail_perf_logger, "mythic.ragnarok_sparks", sparks_sample_start)
	if acquisition_visible:
		if runtime.acquisition_cinematic != null:
			var acquisition_sample_start: int = _perf_begin(detail_perf_logger)
			runtime.acquisition_cinematic.draw(canvas, shake_offset)
			_perf_end(detail_perf_logger, "mythic.acquisition_cinematic", acquisition_sample_start)


func draw_hermes_shoes_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	active: bool,
	_trail_life_frames: float,
	_move_trail_threshold: float
) -> void:
	var host: Node = _get_or_create_hermes_fx_host(canvas)
	if host == null:
		return
	var player_center: Vector2 = Vector2.ZERO
	var player_size: Vector2 = HermesShoesFxHost.DEFAULT_PADDLE_SIZE
	var move_delta_x: float = 0.0
	if state != null:
		player_center = _as_vector2(state.get("player_center"), Vector2.ZERO)
		player_size = _as_vector2(state.get("player_size"), player_size)
		var delta_value: Variant = state.get("last_move_delta_x")
		if delta_value != null:
			move_delta_x = float(delta_value)
	if host.has_method("sync_state"):
		host.sync_state(player_center, player_size, active, move_delta_x, shake_offset, 1.0)


func _get_or_create_hermes_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_hermes_fx_host() and _hermes_fx_host_canvas == canvas:
		return _hermes_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(HERMES_SHOES_FX_HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_hermes_fx_host = existing
		_hermes_fx_host_canvas = canvas
		_hermes_fx_host_add_pending = false
		return _hermes_fx_host
	_hermes_fx_host = HermesShoesFxHost.new()
	_hermes_fx_host.name = HERMES_SHOES_FX_HOST_NAME
	_hermes_fx_host.visible = false
	_hermes_fx_host_canvas = canvas
	if not _hermes_fx_host_add_pending:
		_hermes_fx_host_add_pending = true
		parent.call_deferred("add_child", _hermes_fx_host)
	return _hermes_fx_host


func _is_valid_hermes_fx_host() -> bool:
	return (
		_hermes_fx_host != null
		and is_instance_valid(_hermes_fx_host)
		and not _hermes_fx_host.is_queued_for_deletion()
	)


func draw_celestial_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	state: Object,
	wave_radius_max: float,
	shard_count: int,
	arc_segments: int
) -> void:
	if canvas == null or state == null:
		return
	var wave_timer_frames: float = float(state.get("wave_timer_frames"))
	var wave_life_frames: float = float(state.get("wave_life_frames"))
	if wave_timer_frames <= 0.0 or wave_life_frames <= 0.0:
		return
	var elapsed: float = max(0.0, wave_life_frames - wave_timer_frames)
	var t: float = clamp(elapsed / max(1.0, wave_life_frames), 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - t, 2.3)
	var radius: float = 18.0 + ease_out * wave_radius_max
	var fade: float = pow(1.0 - t, 1.1)
	if fade <= 0.02:
		return
	var center: Vector2 = _as_vector2(state.get("wave_center"), Vector2.ZERO) + shake_offset
	var thickness: float = max(1.0, 7.0 * (1.0 - pow(t, 0.9)))
	var rainbow_stops: Array[Color] = [
		Color(1.0, 70.0 / 255.0, 110.0 / 255.0),
		Color(1.0, 170.0 / 255.0, 70.0 / 255.0),
		Color(1.0, 240.0 / 255.0, 90.0 / 255.0),
		Color(120.0 / 255.0, 1.0, 140.0 / 255.0),
		Color(90.0 / 255.0, 200.0 / 255.0, 1.0),
		Color(140.0 / 255.0, 110.0 / 255.0, 1.0),
		Color(220.0 / 255.0, 120.0 / 255.0, 1.0),
	]
	var wave_seed: float = float(state.get("wave_seed"))
	var phase: float = float(state.get("phase"))
	var rotation: float = wave_seed + phase * 0.6
	for idx in range(rainbow_stops.size()):
		var base_color: Color = rainbow_stops[idx]
		var start_angle: float = (float(idx) / float(rainbow_stops.size())) * TAU + rotation
		var end_angle: float = (float(idx + 1) / float(rainbow_stops.size())) * TAU + rotation
		var glow_color := Color(base_color.r, base_color.g, base_color.b, 0.22 * fade)
		var core_color := Color(base_color.r, base_color.g, base_color.b, 0.82 * fade)
		canvas.draw_arc(center, radius + 1.0, start_angle, end_angle, arc_segments, glow_color, thickness + 6.0, true)
		canvas.draw_arc(center, radius, start_angle, end_angle, arc_segments, core_color, thickness, true)
	canvas.draw_arc(center, max(2.0, radius - 3.0), 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.46 * fade * (1.0 - t)), 1.0, true)

	for shard_idx in range(shard_count):
		var angle: float = (float(shard_idx) / float(shard_count)) * TAU + wave_seed * 1.7 - phase * 0.9
		var jitter: float = sin(phase * 4.2 + float(shard_idx) * 1.3) * 2.0
		var shard_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + jitter)
		var shard_alpha: float = 0.86 * fade * (1.0 - t * 0.6)
		if shard_alpha <= 0.02:
			continue
		var shard_color: Color = rainbow_stops[shard_idx % rainbow_stops.size()]
		canvas.draw_circle(shard_pos, 2.1, Color(shard_color.r, shard_color.g, shard_color.b, shard_alpha))
		canvas.draw_circle(shard_pos, 0.9, Color(1.0, 1.0, 1.0, min(1.0, shard_alpha + 0.15)))

	if t < 0.35:
		var core_ratio: float = 1.0 - t / 0.35
		canvas.draw_circle(center, max(2.0, 12.0 * core_ratio), Color(1.0, 1.0, 1.0, 0.68 * core_ratio))


func draw_venom_mist_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	mist_center: Vector2,
	duration_frames: float,
	timer_frames: float,
	particles: Array,
	boss_in_field: bool,
	radius: float,
	alpha: float
) -> void:
	if canvas == null or alpha <= 0.0:
		return
	# Low-cost procedural fog until a dedicated Godot particle/sheet remaster is authored.
	var center: Vector2 = mist_center + shake_offset
	var elapsed: float = max(0.0, duration_frames - timer_frames)
	for layer in range(5):
		var ratio: float = 1.0 - float(layer) / 5.0
		var breathe: float = 1.0 + 0.08 * sin(elapsed * 0.025 * 1.2 + float(layer) * 0.9)
		var layer_radius: float = radius * (0.30 + float(layer) * 0.16) * breathe
		var fill := Color(
			20.0 / 255.0,
			(130.0 + 50.0 * ratio) / 255.0,
			(60.0 + 40.0 * (1.0 - ratio)) / 255.0,
			0.18 * ratio * alpha
		)
		canvas.draw_circle(center, layer_radius, fill)
	for particle_index in range(_recent_start(particles, MAX_RENDERED_VENOM_MIST_PARTICLES), particles.size()):
		var particle_value = particles[particle_index]
		var particle: Dictionary = _as_dict(particle_value)
		var offset: Vector2 = _as_vector2(particle.get("offset", Vector2.ZERO), Vector2.ZERO)
		var life_ratio: float = clamp(float(particle.get("life", 0.0)) / max(1.0, float(particle.get("max_life", 1.0))), 0.0, 1.0)
		var particle_alpha: float = float(particle.get("alpha", 0.2)) * alpha * min(1.0, life_ratio * 1.35)
		if particle_alpha <= 0.01:
			continue
		var layer_id: int = int(particle.get("layer", 1))
		var color := Color(35.0 / 255.0, 160.0 / 255.0, 80.0 / 255.0, particle_alpha)
		if layer_id == 0:
			color = Color(25.0 / 255.0, 135.0 / 255.0, 70.0 / 255.0, particle_alpha * 0.75)
		elif layer_id == 2:
			color = Color(130.0 / 255.0, 235.0 / 255.0, 115.0 / 255.0, particle_alpha * 0.82)
		canvas.draw_circle(center + offset, float(particle.get("size", 12.0)), color)
	if boss_in_field:
		canvas.draw_arc(center, radius * 0.86, 0.0, TAU, 52, Color(0.55, 1.0, 0.35, 0.28 * alpha), 2.0)


func draw_rainbow_fur_glove_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	aura_center: Vector2,
	aura_life_frames: float,
	aura_timer_frames: float,
	aura_phase: float,
	particles: Array,
	colors: Array
) -> void:
	if canvas == null:
		return
	var center: Vector2 = aura_center + shake_offset
	var life_frames: float = max(1.0, aura_life_frames)
	if aura_timer_frames > 0.0:
		var progress: float = 1.0 - clamp(aura_timer_frames / life_frames, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - progress, 2.0)
		var fade: float = clamp(aura_timer_frames / life_frames, 0.0, 1.0)
		var ring_base: float = 20.0 + 110.0 * ease_out
		var thickness: float = max(1.0, 6.0 * fade)
		var color_count: int = colors.size()
		for idx in range(color_count):
			var base_color: Color = _as_color(colors[idx], Color.WHITE)
			var wobble: float = sin(aura_phase + float(idx) * TAU / float(color_count)) * 6.0
			var radius: float = max(4.0, ring_base + (float(idx) - 2.0) * 4.0 + wobble)
			canvas.draw_arc(center, radius + 2.0, 0.0, TAU, RAINBOW_FUR_GLOVE_RING_SEGMENTS, Color(base_color.r, base_color.g, base_color.b, 0.16 * fade), thickness + 6.0, true)
			canvas.draw_arc(center, radius, 0.0, TAU, RAINBOW_FUR_GLOVE_RING_SEGMENTS, Color(base_color.r, base_color.g, base_color.b, 0.70 * fade), thickness, true)
		canvas.draw_circle(center, max(2.0, 18.0 * fade), Color(1.0, 1.0, 1.0, 0.62 * fade))
		for ray_idx in range(12):
			var angle: float = float(ray_idx) * TAU / 12.0 + aura_phase
			var color: Color = _as_color(colors[ray_idx % color_count], Color.WHITE)
			var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * max(2.0, ring_base - 12.0)
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (ring_base + 30.0 * fade)
			canvas.draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, 0.58 * fade), max(1.0, 3.0 * fade), true)

	for particle_index in range(_recent_start(particles, MAX_RENDERED_RAINBOW_FUR_GLOVE_PARTICLES), particles.size()):
		var particle_value = particles[particle_index]
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)) * (0.8 + 0.25 * sin(float(particle.get("phase", 0.0)))))
		var color: Color = _as_color(particle.get("color", Color.WHITE), Color.WHITE)
		canvas.draw_circle(pos, size + 3.0, Color(color.r, color.g, color.b, 0.17 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.86 * alpha))
		canvas.draw_circle(pos, max(0.8, size * 0.38), Color(1.0, 1.0, 1.0, 0.68 * alpha))


func draw_adversity_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	context: Dictionary,
	aura_particles: Array,
	barrier_particles: Array,
	timer_stack: Object = null
) -> void:
	if canvas == null:
		return
	var active: bool = bool(context.get("invincible", false))
	var barrier_y: float = float(context.get("barrier_y", 732.0))
	var phase: float = float(context.get("phase", 0.0))
	var timer_ratio: float = clamp(float(context.get("timer_ratio", 0.0)), 0.0, 1.0)
	var flash_timer: float = float(context.get("flash_timer_frames", 0.0))
	var flash_frames: float = max(1.0, float(context.get("flash_frames", 30.0)))
	var flash: float = clamp(flash_timer / flash_frames, 0.0, 1.0)
	if active:
		var line_y: float = barrier_y + shake_offset.y
		var core_color := Color(1.0, 0.92, 0.45, 0.68 + 0.18 * sin(phase * 2.1))
		var glow_color := Color(1.0, 0.55, 0.14, 0.18 + 0.12 * timer_ratio)
		canvas.draw_line(Vector2(14.0 + shake_offset.x, line_y), Vector2(746.0 + shake_offset.x, line_y), glow_color, 12.0, true)
		canvas.draw_line(Vector2(24.0 + shake_offset.x, line_y), Vector2(736.0 + shake_offset.x, line_y), core_color, 4.2, true)
		for wave_index in range(3):
			var wave_offset: float = sin(phase + float(wave_index) * 1.7) * (3.0 + float(wave_index))
			var alpha: float = 0.34 - float(wave_index) * 0.07
			canvas.draw_line(
				Vector2(40.0 + shake_offset.x, line_y - 9.0 - float(wave_index) * 7.0 + wave_offset),
				Vector2(720.0 + shake_offset.x, line_y - 9.0 - float(wave_index) * 7.0 - wave_offset),
				Color(1.0, 0.78, 0.22, alpha * timer_ratio),
				max(1.0, 2.4 - float(wave_index) * 0.3),
				true
			)
		_draw_adversity_armor_timer_gauge(canvas, timer_ratio, timer_stack)
	if flash > 0.0:
		var center: Vector2 = _as_vector2(context.get("last_reflect_center", Vector2(380.0, barrier_y)), Vector2(380.0, barrier_y)) + shake_offset
		for ring_index in range(3):
			var radius: float = 26.0 + (1.0 - flash) * 86.0 + float(ring_index) * 18.0
			canvas.draw_arc(center, radius, PI, TAU, 56, Color(1.0, 0.78, 0.25, flash * (0.48 - float(ring_index) * 0.10)), 3.0, true)

	for particle_index in range(_recent_start(aura_particles, MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES), aura_particles.size()):
		_draw_adversity_armor_particle(
			canvas,
			_as_dict(aura_particles[particle_index]),
			shake_offset,
			Color(1.0, 0.80, 0.28, 1.0),
			true
		)
	for particle_index in range(_recent_start(barrier_particles, MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES), barrier_particles.size()):
		_draw_adversity_armor_particle(
			canvas,
			_as_dict(barrier_particles[particle_index]),
			shake_offset,
			Color(1.0, 0.68, 0.18, 1.0),
			false
		)


func _draw_adversity_armor_timer_gauge(canvas: CanvasItem, timer_ratio: float, timer_stack: Object = null) -> void:
	var stack_index: int = 0
	if timer_stack != null and timer_stack.has_method("claim"):
		stack_index = int(timer_stack.claim(ADVERSITY_ARMOR_TIMER_STACK_KEY, true))
	var frame_rect := Rect2(_get_adversity_armor_timer_bar_position(stack_index), ADVERSITY_ARMOR_TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(0.20, 0.12, 0.03, 0.94))
	canvas.draw_rect(mid_rect, Color(0.82, 0.48, 0.12, 0.96))
	canvas.draw_rect(mid_rect, Color(1.0, 0.74, 0.24, 0.90), false, 2.0)
	canvas.draw_rect(border_rect, Color(0.18, 0.10, 0.02, 0.96))
	canvas.draw_rect(frame_rect, Color(0.10, 0.06, 0.02, 0.94))

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * clamp(timer_ratio, 0.0, 1.0))
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, Color(1.0, 0.68, 0.18, 0.98))
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), Color(1.0, 0.92, 0.45, 0.92))
	for tick_index in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(tick_index) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 0.80, 0.32, 0.76),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)


func _get_adversity_armor_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		760.0 - ADVERSITY_ARMOR_TIMER_BAR_SIZE.x - ADVERSITY_ARMOR_TIMER_BAR_MARGIN.x,
		750.0 - ADVERSITY_ARMOR_TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * ADVERSITY_ARMOR_TIMER_STACK_SPACING
	)


func _draw_adversity_armor_particle(
	canvas: CanvasItem,
	particle: Dictionary,
	shake_offset: Vector2,
	base_color: Color,
	aura: bool
) -> void:
	var life: float = float(particle.get("life", 0.0))
	var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
	var alpha: float = clamp(life / max_life, 0.0, 1.0)
	if alpha <= 0.02:
		return
	var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var size: float = max(0.8, float(particle.get("size", 2.0)))
	var glow_alpha: float = 0.16 if aura else 0.22
	canvas.draw_circle(pos, size + 3.0, Color(base_color.r, base_color.g, base_color.b, glow_alpha * alpha))
	canvas.draw_circle(pos, size, Color(base_color.r, base_color.g, base_color.b, 0.72 * alpha))
	canvas.draw_circle(pos, max(0.6, size * 0.35), Color(1.0, 0.96, 0.72, 0.72 * alpha))


func draw_shrapnel_armor_effect(
	canvas: CanvasItem,
	shake_offset: Vector2,
	flash_timer_frames: float,
	flash_center: Vector2,
	shards: Array,
	dust_particles: Array,
	boss_impact_timer_frames: float,
	boss_impact_center: Vector2,
	flash_frames: float,
	shard_life_frames: float,
	boss_impact_frames: float
) -> void:
	if canvas == null:
		return
	if flash_timer_frames > 0.0:
		var fade: float = clamp(flash_timer_frames / flash_frames, 0.0, 1.0)
		var center: Vector2 = flash_center + shake_offset
		canvas.draw_arc(center, 22.0 + 14.0 * (1.0 - fade), PI, TAU * 2.0, SHRAPNEL_ARMOR_FLASH_ARC_SEGMENTS, Color(1.0, 0.66, 0.22, 0.58 * fade), 3.0, true)
		canvas.draw_circle(center, 13.0 + 8.0 * (1.0 - fade), Color(1.0, 0.48, 0.12, 0.18 * fade))

	for shard_index in range(_recent_start(shards, MAX_RENDERED_SHRAPNEL_ARMOR_SHARDS), shards.size()):
		var shard: Dictionary = _as_dict(shards[shard_index])
		var life: float = float(shard.get("life", 0.0))
		var max_life: float = max(1.0, float(shard.get("max_life", shard_life_frames)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var size: float = max(1.0, float(shard.get("size", 4.0)))
		var color_shift: float = float(shard.get("color_shift", 0.0)) / 255.0
		var shard_color := Color(1.0, clamp(0.48 + color_shift, 0.25, 0.75), 0.10, 0.92 * alpha)
		var trail: Array = _as_array(shard.get("trail", []))
		var trail_start: int = _recent_start(trail, MAX_RENDERED_SHRAPNEL_ARMOR_TRAIL_POINTS)
		var rendered_trail_count: int = max(1, trail.size() - trail_start)
		for trail_index in range(trail_start, trail.size()):
			var trail_pos: Vector2 = _as_vector2(trail[trail_index], Vector2.ZERO) + shake_offset
			var trail_alpha: float = 0.08 + 0.20 * float(trail_index - trail_start + 1) / float(rendered_trail_count)
			canvas.draw_circle(trail_pos, max(1.0, size * 0.48), Color(1.0, 0.52, 0.12, trail_alpha * alpha))
		var position: Vector2 = _as_vector2(shard.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var rotation: float = float(shard.get("rotation", 0.0))
		var long_axis := Vector2(cos(rotation), sin(rotation)) * size * 1.75
		var short_axis := Vector2(-sin(rotation), cos(rotation)) * size * 0.92
		var points := PackedVector2Array([
			position + long_axis,
			position + short_axis,
			position - long_axis,
			position - short_axis,
		])
		canvas.draw_circle(position, size + 4.0, Color(1.0, 0.42, 0.08, 0.18 * alpha))
		canvas.draw_colored_polygon(points, shard_color)
		var outline := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
		canvas.draw_polyline(outline, Color(1.0, 0.92, 0.54, 0.62 * alpha), 1.0, true)
		canvas.draw_circle(position, max(0.8, size * 0.35), Color(1.0, 0.95, 0.72, 0.76 * alpha))

	for particle_index in range(_recent_start(dust_particles, MAX_RENDERED_SHRAPNEL_ARMOR_DUST_PARTICLES), dust_particles.size()):
		var particle_value = dust_particles[particle_index]
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(1.0, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		var color: Color = _as_color(particle.get("color", Color(1.0, 0.55, 0.18)), Color(1.0, 0.55, 0.18))
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(0.6, float(particle.get("size", 1.5)))
		canvas.draw_circle(pos, size + 1.5, Color(color.r, color.g, color.b, 0.14 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.62 * alpha))

	if boss_impact_timer_frames > 0.0:
		var impact_fade: float = clamp(boss_impact_timer_frames / boss_impact_frames, 0.0, 1.0)
		var impact_center: Vector2 = boss_impact_center + shake_offset
		for ring_index in range(2):
			var radius: float = 28.0 + (1.0 - impact_fade) * 42.0 + float(ring_index) * 13.0
			canvas.draw_arc(impact_center, radius, 0.0, TAU, SHRAPNEL_ARMOR_BOSS_IMPACT_ARC_SEGMENTS, Color(1.0, 0.54, 0.12, 0.54 * impact_fade), max(1.0, 3.0 - float(ring_index)), true)


func draw_knee_pads_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	flash_center: Vector2,
	flash_timer_frames: float,
	particles: Array,
	flash_duration_frames: float
) -> void:
	if canvas == null:
		return
	var center: Vector2 = flash_center + shake_offset
	if flash_timer_frames > 0.0:
		var progress: float = 1.0 - clamp(flash_timer_frames / flash_duration_frames, 0.0, 1.0)
		var alpha: float = clamp(flash_timer_frames / flash_duration_frames, 0.0, 1.0)
		for ring_index in range(3):
			var radius: float = 16.0 + progress * 74.0 + float(ring_index) * 13.0
			var ring_alpha: float = max(0.0, alpha * (0.62 - float(ring_index) * 0.13))
			canvas.draw_arc(center, radius, 0.0, TAU, KNEE_PADS_RING_SEGMENTS, Color(1.0, 0.86, 0.12, ring_alpha), 3.0, true)
		for ray_index in range(8):
			var angle: float = float(ray_index) / 8.0 * TAU + progress * 1.7
			var ray_len: float = 24.0 + progress * 48.0
			var start_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * 10.0
			var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * ray_len
			canvas.draw_line(start_pos, end_pos, Color(1.0, 0.93, 0.28, alpha * 0.55), 4.0, true)
			canvas.draw_line(start_pos, end_pos, Color(1.0, 1.0, 1.0, alpha * 0.35), 1.3, true)
		canvas.draw_circle(center, 30.0 * alpha + 6.0, Color(1.0, 0.86, 0.0, alpha * 0.24))
		canvas.draw_circle(center, 7.0 + 6.0 * (1.0 - progress), Color.WHITE, alpha * 0.88)

	for particle_index in range(_recent_start(particles, MAX_RENDERED_KNEE_PADS_PARTICLES), particles.size()):
		var particle: Dictionary = _as_dict(particles[particle_index])
		var life: float = max(0.0, float(particle.get("life", 0.0)))
		var max_life: float = max(0.1, float(particle.get("max_life", 30.0)))
		var particle_alpha: float = clamp(life / max_life, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		var color: Color = _as_color(particle.get("color", Color(1.0, 0.78, 0.0)), Color(1.0, 0.78, 0.0))
		color.a = particle_alpha
		canvas.draw_circle(pos, size * 2.1, Color(color.r, color.g, color.b, particle_alpha * 0.18))
		canvas.draw_circle(pos, size, color)


func draw_soul_burst_effects(
	canvas: CanvasItem,
	shake_offset: Vector2,
	center_base: Vector2,
	dash_direction: float,
	wind_trails: Array,
	shockwaves: Array,
	particles: Array,
	alpha_cutoff: float
) -> void:
	if canvas == null:
		return
	# Short dash accent: keep this in the shared procedural mythic-effect lane
	# instead of allocating a dedicated particle scene for a sub-second burst.
	var center: Vector2 = center_base + shake_offset
	var direction: float = dash_direction
	if abs(direction) <= 0.01:
		direction = 1.0

	for trail_index in range(_recent_start(wind_trails, MAX_RENDERED_SOUL_BURST_WIND_TRAILS), wind_trails.size()):
		var trail: Dictionary = _as_dict(wind_trails[trail_index])
		var life: float = float(trail.get("life", 0.0))
		var max_life: float = max(0.1, float(trail.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var offset: Vector2 = _as_vector2(trail.get("offset", Vector2.ZERO), Vector2.ZERO)
		var length: float = float(trail.get("length", 60.0))
		var base: Vector2 = center + offset
		var start_pos: Vector2 = base - Vector2(direction * length, 0.0)
		var end_pos: Vector2 = base + Vector2(direction * length * 0.26, 0.0)
		var width: float = float(trail.get("width", 2.0))
		canvas.draw_line(start_pos, end_pos, Color(42.0 / 255.0, 0.0, 72.0 / 255.0, 0.22 * alpha), width + 5.0, true)
		canvas.draw_line(start_pos, end_pos, Color(180.0 / 255.0, 86.0 / 255.0, 1.0, 0.58 * alpha), width + 1.2, true)
		canvas.draw_line(start_pos.lerp(end_pos, 0.38), end_pos, Color(245.0 / 255.0, 220.0 / 255.0, 1.0, 0.42 * alpha), max(1.0, width * 0.45), true)

	for wave_index in range(_recent_start(shockwaves, MAX_RENDERED_SOUL_BURST_SHOCKWAVES), shockwaves.size()):
		var wave: Dictionary = _as_dict(shockwaves[wave_index])
		var life: float = float(wave.get("life", 0.0))
		var max_life: float = max(0.1, float(wave.get("max_life", 1.0)))
		var progress: float = 1.0 - clamp(life / max_life, 0.0, 1.0)
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var radius: float = lerp(float(wave.get("start_radius", 20.0)), float(wave.get("max_radius", 92.0)), progress)
		var squeeze: float = float(wave.get("squeeze", 0.72))
		var ring_color := Color(165.0 / 255.0, 72.0 / 255.0, 1.0, 0.62 * alpha)
		canvas.draw_arc(center, radius, 0.0, TAU, SOUL_BURST_ELLIPSE_SEGMENTS, Color(45.0 / 255.0, 0.0, 80.0 / 255.0, 0.18 * alpha), 7.0, true)
		draw_soul_burst_ellipse_arc(canvas, center, radius, radius * squeeze, ring_color, 3.0)
		draw_soul_burst_ellipse_arc(canvas, center, radius * 0.74, radius * squeeze * 0.74, Color(1.0, 230.0 / 255.0, 1.0, 0.35 * alpha), 1.2)

	for particle_index in range(_recent_start(particles, MAX_RENDERED_SOUL_BURST_PARTICLES), particles.size()):
		var particle_value = particles[particle_index]
		var particle: Dictionary = _as_dict(particle_value)
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(0.1, float(particle.get("max_life", 1.0)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= alpha_cutoff:
			continue
		var pos: Vector2 = _as_vector2(particle.get("position", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = max(1.0, float(particle.get("size", 2.0)))
		var color: Color = _as_color(particle.get("color", Color(0.72, 0.32, 1.0, 1.0)), Color(0.72, 0.32, 1.0, 1.0))
		canvas.draw_circle(pos, size * 2.2, Color(color.r, color.g, color.b, 0.18 * alpha))
		canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, color.a * alpha))
		canvas.draw_circle(pos, max(1.0, size * 0.38), Color(1.0, 0.88, 1.0, 0.68 * alpha))


func draw_soul_burst_ellipse_arc(
	canvas: CanvasItem,
	center: Vector2,
	radius_x: float,
	radius_y: float,
	color: Color,
	width: float
) -> void:
	if canvas == null:
		return
	var points := PackedVector2Array()
	for idx in range(SOUL_BURST_ELLIPSE_SEGMENTS + 1):
		var angle: float = TAU * float(idx) / float(SOUL_BURST_ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width, true)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return fallback


func _array_color(values: Array, fallback: Color) -> Color:
	if values.is_empty():
		return fallback
	return _as_color(values[randi() % values.size()], fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _should_sample_detail(perf_logger: Object, label: String) -> bool:
	if perf_logger == null or not perf_logger.has_method("should_sample_detail"):
		return false
	return bool(perf_logger.should_sample_detail(label))


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit < 0:
		return 0
	return max(0, source.size() - max(0, render_limit))


func get_render_budget_status() -> Dictionary:
	return {
		"venom_mist_particle_render_limit": MAX_RENDERED_VENOM_MIST_PARTICLES,
		"rainbow_fur_glove_particle_render_limit": MAX_RENDERED_RAINBOW_FUR_GLOVE_PARTICLES,
		"shrapnel_armor_shard_render_limit": MAX_RENDERED_SHRAPNEL_ARMOR_SHARDS,
		"shrapnel_armor_trail_render_limit": MAX_RENDERED_SHRAPNEL_ARMOR_TRAIL_POINTS,
		"shrapnel_armor_dust_render_limit": MAX_RENDERED_SHRAPNEL_ARMOR_DUST_PARTICLES,
		"knee_pads_particle_render_limit": MAX_RENDERED_KNEE_PADS_PARTICLES,
		"soul_burst_wind_trail_render_limit": MAX_RENDERED_SOUL_BURST_WIND_TRAILS,
		"soul_burst_shockwave_render_limit": MAX_RENDERED_SOUL_BURST_SHOCKWAVES,
		"soul_burst_particle_render_limit": MAX_RENDERED_SOUL_BURST_PARTICLES,
		"poseidon_water_trail_render_limit": MAX_RENDERED_POSEIDON_WATER_TRAIL,
		"poseidon_particle_render_limit": MAX_RENDERED_POSEIDON_PARTICLES,
		"poseidon_explosion_particle_render_limit": MAX_RENDERED_POSEIDON_EXPLOSION_PARTICLES,
		"ragnarok_spark_render_limit": MAX_RENDERED_RAGNAROK_SPARKS,
		"poseidon_trail_arc_render_limit": MAX_POSEIDON_TRAIL_ARCS,
	}
