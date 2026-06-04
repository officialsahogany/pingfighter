extends RefCounted

const AuraFieldRenderer := preload("res://scripts/items/mythic_item_aura_field_renderer.gd")
const ArmorFieldRenderer := preload("res://scripts/items/mythic_item_armor_field_renderer.gd")
const HermesFieldRenderer := preload("res://scripts/items/mythic_item_hermes_field_renderer.gd")
const HornStrawberryFieldRenderer := preload("res://scripts/items/mythic_item_horn_strawberry_field_renderer.gd")
const HornStrawberryTimerGaugeRenderer := preload("res://scripts/items/horn_strawberry_timer_gauge_renderer.gd")
const MomentumFieldRenderer := preload("res://scripts/items/mythic_item_momentum_field_renderer.gd")
const PoseidonFieldRenderer := preload("res://scripts/items/mythic_item_poseidon_field_renderer.gd")
const RagnarokFieldRenderer := preload("res://scripts/items/mythic_item_ragnarok_field_renderer.gd")

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
const HORN_STRAWBERRY_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const HORN_STRAWBERRY_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const HORN_STRAWBERRY_TIMER_STACK_SPACING := 18.0
const HORN_STRAWBERRY_TIMER_STACK_KEY := "horn_strawberry_mask"

var _aura_field_renderer: Object = AuraFieldRenderer.new()
var _armor_field_renderer: Object = ArmorFieldRenderer.new()
var _hermes_field_renderer: Object = HermesFieldRenderer.new()
var _horn_strawberry_field_renderer: Object = HornStrawberryFieldRenderer.new()
var _horn_strawberry_timer_renderer: Object = HornStrawberryTimerGaugeRenderer.new()
var _momentum_field_renderer: Object = MomentumFieldRenderer.new()
var _poseidon_field_renderer: Object = PoseidonFieldRenderer.new()
var _ragnarok_field_renderer: Object = RagnarokFieldRenderer.new()


func draw_field_effects(
	runtime: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	ragnarok_impact_effect_duration: float,
	_ragnarok_electric_stun_intensity: float,
	perf_logger: Object = null,
	timer_stack: Object = null,
	constants: Dictionary = {},
	draw_context: Dictionary = {}
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
	var horn_strawberry_transformed: bool = runtime.is_horn_strawberry_transformed()
	var horn_strawberry_effect_visible: bool = runtime.horn_strawberry_mask_runtime.has_visible_effects(runtime)
	var horn_strawberry_context: Dictionary = {}
	if horn_strawberry_transformed or horn_strawberry_effect_visible:
		horn_strawberry_context = runtime.get_horn_strawberry_context()
	if not horn_strawberry_context.is_empty():
		horn_strawberry_effect_visible = horn_strawberry_effect_visible or _horn_strawberry_field_renderer.is_transform_visible(horn_strawberry_context)
	var horn_strawberry_visible: bool = (
		horn_strawberry_transformed
		or horn_strawberry_effect_visible
	)
	var acquisition_visible: bool = runtime.acquisition_cinematic != null and runtime.acquisition_cinematic.is_active()
	if not impact_active and not stun_active and runtime.ragnarok_sparks.is_empty() and not poseidon_visible and not knee_pads_visible and not soul_burst_visible and not foul_whistle_visible and not revival_visible and not sensor_visible and not venom_mist_visible and not rainbow_glove_visible and not adversity_armor_visible and not shrapnel_armor_visible and not celestial_armor_visible and not hermes_visible and not baal_visible and not horn_strawberry_visible and not acquisition_visible:
		return
	_record_visible_counters(perf_logger, {
		"ragnarok_impact": impact_active,
		"ragnarok_stun": stun_active,
		"ragnarok_sparks": not runtime.ragnarok_sparks.is_empty(),
		"poseidon": poseidon_visible,
		"knee_pads": knee_pads_visible,
		"soul_burst": soul_burst_visible,
		"foul_whistle": foul_whistle_visible,
		"revival": revival_visible,
		"sensor": sensor_visible,
		"venom_mist": venom_mist_visible,
		"rainbow_fur_glove": rainbow_glove_visible,
		"adversity_armor": adversity_armor_visible,
		"shrapnel_armor": shrapnel_armor_visible,
		"celestial_armor": celestial_armor_visible,
		"hermes_shoes": hermes_visible,
		"baal_boots": baal_visible,
		"horn_strawberry_effect": horn_strawberry_effect_visible,
		"horn_strawberry_timer": horn_strawberry_transformed,
		"acquisition_cinematic": acquisition_visible,
	})
	var detail_perf_logger: Object = perf_logger if _should_record_field_detail(perf_logger) else null
	var field_size: Vector2 = _as_vector2(constants.get("field_size", Vector2(760.0, 750.0)), Vector2(760.0, 750.0))
	if horn_strawberry_effect_visible:
		var horn_sample_start: int = _perf_begin(detail_perf_logger)
		if horn_strawberry_context.is_empty():
			horn_strawberry_context = runtime.get_horn_strawberry_context()
		_horn_strawberry_field_renderer.draw_horn_strawberry_effects(
			canvas,
			shake_offset,
			horn_strawberry_context,
			runtime.get_horn_strawberry_eat_context() if _state_has_visible_effects(runtime.horn_strawberry_eat_state) else {},
			runtime.get_horn_strawberry_field_context() if _state_has_visible_effects(runtime.horn_strawberry_field_state) else {},
			runtime.get_horn_strawberry_horn_charge_context() if _state_has_visible_effects(runtime.horn_strawberry_horn_charge_state) else {},
			runtime.get_horn_strawberry_bomb_context() if _state_has_visible_effects(runtime.horn_strawberry_bomb_state) else {},
			{
				"projectiles": MAX_RENDERED_HORN_STRAWBERRY_PROJECTILES,
				"barriers": MAX_RENDERED_HORN_STRAWBERRY_BARRIERS,
				"trails": MAX_RENDERED_HORN_STRAWBERRY_TRAILS,
				"bombs": MAX_RENDERED_HORN_STRAWBERRY_BOMBS,
				"explosions": MAX_RENDERED_HORN_STRAWBERRY_EXPLOSIONS,
				"paint": MAX_RENDERED_HORN_STRAWBERRY_PAINT,
			},
			draw_context
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
		_hermes_field_renderer.draw_hermes_shoes_effect(
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
		_aura_field_renderer.draw_venom_mist_effect(
			canvas,
			shake_offset,
			runtime.venom_mist_center,
			runtime.venom_mist_duration_frames,
			runtime.venom_mist_timer_frames,
			runtime.venom_mist_particles,
			runtime.venom_mist_boss_in_field,
			float(constants.get("venom_mist_radius", 120.0)),
			runtime.venom_mist_runtime.get_alpha(runtime),
			MAX_RENDERED_VENOM_MIST_PARTICLES
		)
		_perf_end(detail_perf_logger, "mythic.venom_mist", venom_sample_start)
	if rainbow_glove_visible:
		var rainbow_sample_start: int = _perf_begin(detail_perf_logger)
		_aura_field_renderer.draw_rainbow_fur_glove_effect(
			canvas,
			shake_offset,
			runtime.rainbow_fur_glove_aura_center,
			runtime.rainbow_fur_glove_aura_life_frames,
			runtime.rainbow_fur_glove_aura_timer_frames,
			runtime.rainbow_fur_glove_aura_phase,
			runtime.rainbow_fur_glove_particles,
			_as_array(constants.get("rainbow_fur_glove_colors", [])),
			MAX_RENDERED_RAINBOW_FUR_GLOVE_PARTICLES,
			RAINBOW_FUR_GLOVE_RING_SEGMENTS
		)
		_perf_end(detail_perf_logger, "mythic.rainbow_fur_glove", rainbow_sample_start)
	if adversity_armor_visible:
		var adversity_sample_start: int = _perf_begin(detail_perf_logger)
		_armor_field_renderer.draw_adversity_armor_effect(
			canvas,
			shake_offset,
			runtime.get_adversity_armor_context(),
			runtime.adversity_armor_aura_particles,
			runtime.adversity_armor_barrier_particles,
			timer_stack,
			MAX_RENDERED_ADVERSITY_ARMOR_PARTICLES,
			ADVERSITY_ARMOR_TIMER_BAR_SIZE,
			ADVERSITY_ARMOR_TIMER_BAR_MARGIN,
			ADVERSITY_ARMOR_TIMER_STACK_SPACING,
			ADVERSITY_ARMOR_TIMER_STACK_KEY
		)
		_perf_end(detail_perf_logger, "mythic.adversity_armor", adversity_sample_start)
	if shrapnel_armor_visible:
		var shrapnel_sample_start: int = _perf_begin(detail_perf_logger)
		_armor_field_renderer.draw_shrapnel_armor_effect(
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
			float(constants.get("shrapnel_armor_boss_impact_frames", 15.0)),
			MAX_RENDERED_SHRAPNEL_ARMOR_SHARDS,
			MAX_RENDERED_SHRAPNEL_ARMOR_TRAIL_POINTS,
			MAX_RENDERED_SHRAPNEL_ARMOR_DUST_PARTICLES,
			SHRAPNEL_ARMOR_FLASH_ARC_SEGMENTS,
			SHRAPNEL_ARMOR_BOSS_IMPACT_ARC_SEGMENTS
		)
		_perf_end(detail_perf_logger, "mythic.shrapnel_armor", shrapnel_sample_start)
	if celestial_armor_visible:
		var celestial_sample_start: int = _perf_begin(detail_perf_logger)
		_aura_field_renderer.draw_celestial_armor_effect(
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
		_momentum_field_renderer.draw_knee_pads_effects(
			canvas,
			shake_offset,
			runtime.knee_pads_flash_center,
			runtime.knee_pads_flash_timer_frames,
			runtime.knee_pads_particles,
			float(constants.get("knee_pads_flash_duration_frames", 30.0)),
			MAX_RENDERED_KNEE_PADS_PARTICLES,
			KNEE_PADS_RING_SEGMENTS
		)
		_perf_end(detail_perf_logger, "mythic.knee_pads", knee_sample_start)
	if soul_burst_visible:
		var soul_sample_start: int = _perf_begin(detail_perf_logger)
		_momentum_field_renderer.draw_soul_burst_effects(
			canvas,
			shake_offset,
			runtime.soul_burst_center,
			runtime.soul_burst_direction,
			runtime.soul_burst_wind_trails,
			runtime.soul_burst_shockwaves,
			runtime.soul_burst_particles,
			float(constants.get("soul_burst_particle_alpha_cutoff", 0.02)),
			MAX_RENDERED_SOUL_BURST_WIND_TRAILS,
			MAX_RENDERED_SOUL_BURST_SHOCKWAVES,
			MAX_RENDERED_SOUL_BURST_PARTICLES,
			SOUL_BURST_ELLIPSE_SEGMENTS
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
	# Ragnarok's on-boss electric arcs are now drawn by the shared, source-agnostic
	# BossElectrocutionFieldHost (driven from the boss actor renderer via the
	# `ragnarok_hammer_electric_stun_active` flag), so the "감전" symptom matches
	# every other electric stun. Only the ragnarok-specific impact rings + sparks
	# stay here; `draw_ragnarok_electric_stun_overlay` (and the now-unused
	# `_ragnarok_electric_stun_intensity` arg) are intentionally retired but kept
	# as an immediate-draw fallback reference in the field renderer.
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
	if horn_strawberry_transformed:
		var horn_timer_sample_start: int = _perf_begin(detail_perf_logger)
		if horn_strawberry_context.is_empty():
			horn_strawberry_context = runtime.get_horn_strawberry_context()
		_horn_strawberry_timer_renderer.draw_transform_timer_gauge(
			canvas,
			timer_stack,
			horn_strawberry_context,
			HORN_STRAWBERRY_TIMER_BAR_SIZE,
			HORN_STRAWBERRY_TIMER_BAR_MARGIN,
			HORN_STRAWBERRY_TIMER_STACK_SPACING,
			HORN_STRAWBERRY_TIMER_STACK_KEY
		)
		_perf_end(detail_perf_logger, "mythic.horn_strawberry_timer", horn_timer_sample_start)
	if acquisition_visible:
		if runtime.acquisition_cinematic != null:
			var acquisition_sample_start: int = _perf_begin(detail_perf_logger)
			runtime.acquisition_cinematic.draw(canvas, shake_offset)
			_perf_end(detail_perf_logger, "mythic.acquisition_cinematic", acquisition_sample_start)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _should_record_field_detail(perf_logger: Object) -> bool:
	if perf_logger == null:
		return false
	if perf_logger.has_method("is_enabled") and not bool(perf_logger.is_enabled()):
		return false
	return perf_logger.has_method("begin_sample") and perf_logger.has_method("finish_sample")


func _should_sample_detail(perf_logger: Object, label: String) -> bool:
	if perf_logger == null or not perf_logger.has_method("should_sample_detail"):
		return false
	return bool(perf_logger.should_sample_detail(label))


func _record_visible_counters(perf_logger: Object, visibility: Dictionary) -> void:
	if perf_logger == null or not perf_logger.has_method("record_counter_sample"):
		return
	if perf_logger.has_method("is_enabled") and not bool(perf_logger.is_enabled()):
		return
	for key_value in visibility.keys():
		if bool(visibility.get(key_value, false)):
			perf_logger.record_counter_sample("mythic.visible.%s" % str(key_value), 1.0)


func _state_has_visible_effects(state: Object) -> bool:
	return state != null and state.has_method("has_visible_effects") and bool(state.has_visible_effects())


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
