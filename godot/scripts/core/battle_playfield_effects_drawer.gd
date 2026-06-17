extends RefCounted

const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const INACTIVE_ACTOR_TRANSIENT_CLEANUP_FRAMES := 2

var _method_argument_count_cache: Dictionary = {}
var _method_acceptance_cache: Dictionary = {}
var _last_actor_stage_for_transient_cleanup: int = -1
var _last_actor_renderer_id_for_transient_cleanup: int = 0
var _inactive_actor_transient_cleanup_frames_remaining: int = 0
var character_runtime: Object = PlayerCharacterRuntime.new()


func draw_actors(
	canvas: CanvasItem,
	registry: Object,
	draw_context: Dictionary,
	actor_context: Dictionary,
	perf_logger: Object = null
) -> void:
	var current_stage: int = int(draw_context.get("current_stage", 1))
	var lookup_start: int = _perf_begin(perf_logger)
	var actor_renderer: Object = _get_stage_instance(registry, current_stage, "actor_renderer", "stage1_actor_renderer")
	_perf_end(perf_logger, "actors.lookup_renderer", lookup_start)
	var cleanup_start: int = _perf_begin(perf_logger)
	_clear_inactive_stage_actor_transients_if_needed(registry, current_stage, actor_renderer)
	_perf_end(perf_logger, "actors.clear_inactive_transients", cleanup_start)
	if actor_renderer == null:
		return
	if actor_context.is_empty():
		_clear_transient_canvas_items(actor_renderer)
		return
	var draw_start: int = _perf_begin(perf_logger)
	if _method_accepts_argument_count(actor_renderer, "draw", 3):
		actor_renderer.draw(canvas, actor_context, perf_logger)
	else:
		actor_renderer.draw(canvas, actor_context)
	_perf_end(perf_logger, "actors.renderer_draw", draw_start)


func draw_power_smash_effects(
	canvas: CanvasItem,
	registry: Object,
	power_state: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	if not bool(canvas.get("ball_active")):
		return
	if not _has_visible_effects(power_state):
		return
	var skill_feedback_renderer: Object = _get_instance(registry, "smasher_skill_feedback_renderer")
	if skill_feedback_renderer != null:
		skill_feedback_renderer.draw_power_smash_effects(canvas, power_state, shake_offset)


func draw_magnum_grip_effects(
	canvas: CanvasItem,
	registry: Object,
	draw_context: Dictionary,
	shake_offset: Vector2
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var magnum_state: Object = _get_instance(registry, "smasher_magnum_grip_state")
	if magnum_state == null or not magnum_state.has_method("is_active") or not bool(magnum_state.is_active()):
		return
	var skill_feedback_renderer: Object = _get_instance(registry, "smasher_skill_feedback_renderer")
	if skill_feedback_renderer != null and skill_feedback_renderer.has_method("draw_magnum_grip_effect"):
		skill_feedback_renderer.draw_magnum_grip_effect(canvas, magnum_state, draw_context, shake_offset)


func draw_boost_charging_effect(
	canvas: CanvasItem,
	_registry: Object,
	draw_context: Dictionary,
	shake_offset: Vector2
) -> void:
	if canvas == null:
		return
	var dash_snapshot: Dictionary = _get_dict(draw_context.get("dash_snapshot", {}))
	var effect_timer: float = float(dash_snapshot.get("boost_charging_effect_timer", 0.0))
	if effect_timer <= 0.0:
		return

	var effect_duration: float = max(1.0, float(dash_snapshot.get("boost_charging_effect_duration", 12.0)))
	var progress: float = clamp(1.0 - effect_timer / effect_duration, 0.0, 1.0)
	var player_pos: Vector2 = _get_vector2(draw_context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(draw_context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var center: Vector2 = player_pos + player_size * 0.5 + shake_offset

	var max_radius: float = 120.0
	var current_radius: float = max_radius * progress
	var base_alpha: float = 0.78 * (1.0 - progress * progress)
	for i in range(4):
		var layer_progress: float = min(1.0, progress + float(i) * 0.05)
		var layer_radius: float = max_radius * layer_progress
		if layer_radius <= 0.0:
			continue
		var layer_alpha: float = max(0.0, base_alpha * (1.0 - float(i) * 0.20))
		if layer_alpha <= 0.0:
			continue
		var layer_color := Color(
			1.0,
			clamp((150.0 - 80.0 * layer_progress) / 255.0, 0.0, 1.0),
			clamp((50.0 - 30.0 * layer_progress) / 255.0, 0.0, 1.0),
			layer_alpha
		)
		canvas.draw_arc(center, layer_radius, 0.0, TAU, 64, layer_color, max(1.0, 3.0 - float(i)), true)

	var core_alpha: float = max(0.0, 0.70 * (1.0 - progress * 1.5))
	if core_alpha > 0.0 and progress < 0.7:
		var core_radius: float = current_radius * 0.4
		if core_radius > 0.0:
			canvas.draw_circle(center, core_radius, Color(1.0, 200.0 / 255.0, 100.0 / 255.0, core_alpha))
			canvas.draw_circle(center, core_radius * 0.5, Color(1.0, 1.0, 200.0 / 255.0, min(1.0, core_alpha + 0.20)))

	for i in range(8):
		var angle: float = TAU * float(i) / 8.0 + progress * 0.5
		var start_dist: float = current_radius * 0.3
		var end_dist: float = start_dist + current_radius * 0.8
		var direction := Vector2(cos(angle), sin(angle))
		var spark_alpha: float = max(0.0, base_alpha * 0.7)
		if spark_alpha > 0.02:
			canvas.draw_line(
				center + direction * start_dist,
				center + direction * end_dist,
				Color(1.0, 180.0 / 255.0, 80.0 / 255.0, spark_alpha),
				2.0,
				true
			)


func draw_dash_acceleration_effect(
	canvas: CanvasItem,
	_registry: Object,
	draw_context: Dictionary,
	shake_offset: Vector2
) -> void:
	if canvas == null:
		return
	var dash_snapshot: Dictionary = _get_dict(draw_context.get("dash_snapshot", {}))
	if not bool(dash_snapshot.get("active", false)):
		return
	if not bool(dash_snapshot.get("dash_acceleration_active", false)):
		return

	var level: int = max(1, int(dash_snapshot.get("dash_acceleration_skill_level", 1)))
	var height_bonus: float = max(0.0, float(dash_snapshot.get("dash_acceleration_height_bonus", 0.0)))
	var direction: float = float(dash_snapshot.get("direction", 0.0))
	if abs(direction) <= 0.01:
		return

	var player_pos: Vector2 = _get_vector2(draw_context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(draw_context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var center: Vector2 = player_pos + player_size * 0.5 + shake_offset
	var trail_length: float = min(max(0.0, float(dash_snapshot.get("timer", 0.0))) * 20.0, 250.0)
	if trail_length <= 0.5:
		return

	var palette: Dictionary = _get_dash_acceleration_palette(level)
	var primary: Color = palette.get("primary", Color(1.0, 1.0, 1.0))
	var secondary: Color = palette.get("secondary", Color(0.9, 0.9, 1.0))
	var accent: Color = palette.get("accent", Color(1.0, 1.0, 1.0))
	var glow_intensity: float = float(palette.get("glow", 0.4))
	var base_half_width: float = max(1.0, player_size.x * 0.5)
	var trail_start_x: float = center.x + base_half_width if direction < 0.0 else center.x - base_half_width
	var trail_end_x: float = trail_start_x + trail_length if direction < 0.0 else trail_start_x - trail_length
	var min_x: float = min(trail_start_x, trail_end_x)
	var max_x: float = max(trail_start_x, trail_end_x)
	var time_factor: float = float(Time.get_ticks_msec()) * 0.002

	for layer in range(8):
		var layer_progress: float = float(layer) / 7.0
		var layer_color: Color = primary.lerp(secondary, layer_progress)
		var layer_alpha: float = 0.12 * glow_intensity * (1.0 - layer_progress * 0.70)
		var layer_width: float = 80.0 - float(layer) * 8.0
		if layer_alpha <= 0.0 or layer_width <= 0.0:
			continue
		for offset_index in range(-3, 4):
			var offset_ratio: float = float(offset_index) / 3.0
			var offset_y: float = offset_ratio * layer_width * 0.5
			var falloff: float = max(0.0, 1.0 - offset_ratio * offset_ratio)
			var wave_offset: float = sin(time_factor + float(layer) * 0.5) * 2.0
			canvas.draw_line(
				Vector2(min_x, center.y + offset_y + wave_offset),
				Vector2(max_x, center.y + offset_y + wave_offset),
				Color(layer_color.r, layer_color.g, layer_color.b, layer_alpha * falloff),
				1.0,
				true
			)

	var ribbon_count: int = 2 + level
	for ribbon_idx in range(ribbon_count):
		@warning_ignore("integer_division")
		var ribbon_offset: float = float(ribbon_idx - ribbon_count / 2) * 12.0
		var points := PackedVector2Array()
		var segments: int = 32
		for segment in range(segments + 1):
			var t: float = float(segment) / float(segments)
			var x: float = lerp(trail_start_x, trail_end_x, t)
			var wave1: float = sin(t * 3.0 + time_factor * 1.5) * 4.0
			var wave2: float = sin(t * 5.0 + time_factor * 2.25) * 2.0
			points.append(Vector2(x, center.y + ribbon_offset + wave1 + wave2))
		var fade_center: float = 1.0 - abs(float(ribbon_idx) - float(ribbon_count - 1) * 0.5) / max(1.0, float(ribbon_count))
		canvas.draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.36 * glow_intensity * fade_center), 2.0, true)
		canvas.draw_polyline(points, Color(primary.r, primary.g, primary.b, 0.24 * glow_intensity * fade_center), 4.0, true)

	var particle_count: int = 8 + level * 3
	for i in range(particle_count):
		var phase: float = fmod(float(i) * 0.618 + time_factor * 0.18, 1.0)
		var particle_x: float = lerp(trail_start_x, trail_end_x, phase)
		var jitter: float = sin(time_factor * 4.0 + float(i) * 1.7)
		var particle_y: float = center.y + jitter * 25.0
		var particle_alpha: float = max(0.0, 0.26 * (1.0 - phase * 0.6) * glow_intensity)
		var particle_radius: float = 1.5 + float(level) * 0.18 + abs(jitter) * 0.8
		canvas.draw_circle(Vector2(particle_x, particle_y), particle_radius * 2.0, Color(primary.r, primary.g, primary.b, particle_alpha * 0.35))
		canvas.draw_circle(Vector2(particle_x, particle_y), particle_radius, Color(accent.r, accent.g, accent.b, particle_alpha))

	var aura_size := Vector2(player_size.x, player_size.y + height_bonus)
	for i in range(5):
		var aura_progress: float = float(i) / 4.0
		var aura_color: Color = accent.lerp(secondary, aura_progress)
		var pulse: float = 1.0 + sin(time_factor + float(i) * 0.5) * 0.10
		var aura_alpha: float = 0.24 * (1.0 - aura_progress) * glow_intensity * pulse
		var aura_expand: float = (10.0 + float(i) * 8.0) * pulse
		_draw_oval_ring(canvas, center, aura_size * 0.5 + Vector2(aura_expand, aura_expand), Color(aura_color.r, aura_color.g, aura_color.b, aura_alpha), 1.0)

	var fade_length: int = 40
	for i in range(fade_length):
		var fade_progress: float = float(i) / float(fade_length)
		var fade_alpha: float = 0.10 * (1.0 - fade_progress * fade_progress) * glow_intensity
		if fade_alpha <= 0.0:
			continue
		var fade_x: float = trail_end_x - (float(i) if direction > 0.0 else -float(i))
		var fade_color: Color = primary.lerp(secondary, fade_progress)
		var fade_height: float = 25.0 * (1.0 - fade_progress)
		canvas.draw_line(
			Vector2(fade_x, center.y - fade_height),
			Vector2(fade_x, center.y + fade_height),
			Color(fade_color.r, fade_color.g, fade_color.b, fade_alpha),
			1.0,
			true
		)


func draw_viper_skill_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {},
	perf_logger: Object = null
) -> void:
	if not _is_character_context(draw_context, PlayerCharacterRuntime.VIPER):
		return
	var viper_skill_runtime: Object = _get_instance(registry, "viper_skill_runtime")
	if _has_visible_effects(viper_skill_runtime) and viper_skill_runtime.has_method("draw"):
		var effect_lod_scale: float = ViperAirborneLod.effect_scale(draw_context)
		viper_skill_runtime.draw(
			canvas,
			shake_offset,
			_build_node_fx_layout(canvas, registry),
			_get_instance(registry, "horizontal_timer_gauge_stack"),
			perf_logger,
			effect_lod_scale
		)


func draw_commando_supply_drop_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_character_context(draw_context, PlayerCharacterRuntime.COMMANDO):
		return
	var supply_state: Object = _get_instance(registry, "commando_supply_drop_state")
	if _has_visible_effects(supply_state) and supply_state.has_method("draw"):
		supply_state.draw(canvas, shake_offset, _build_node_fx_layout(canvas, registry))


func draw_dash_spirit_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var dash_spirit_state: Object = _get_instance(registry, "smasher_dash_spirit_state")
	if _has_visible_effects(dash_spirit_state) and dash_spirit_state.has_method("draw"):
		dash_spirit_state.draw(canvas, shake_offset)


func draw_shield_kiting_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var shield_kiting_state: Object = _get_instance(registry, "smasher_shield_kiting_state")
	if _has_visible_effects(shield_kiting_state) and shield_kiting_state.has_method("draw"):
		shield_kiting_state.draw(canvas, shake_offset)


func draw_blacksmith_thor_shield_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_character_context(draw_context, PlayerCharacterRuntime.BLACKSMITH):
		return
	var blacksmith_thor_shield_state: Object = _get_instance(registry, "blacksmith_thor_shield_state")
	if _has_visible_effects(blacksmith_thor_shield_state) and blacksmith_thor_shield_state.has_method("draw"):
		blacksmith_thor_shield_state.draw(canvas, shake_offset, draw_context)


func draw_laurel_leaf_shield(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	var laurel_leaf_shield_state: Object = _get_instance(registry, "laurel_leaf_shield_state")
	if _has_visible_effects(laurel_leaf_shield_state) and laurel_leaf_shield_state.has_method("draw"):
		laurel_leaf_shield_state.draw(canvas, shake_offset, BattleRenderQuality.effect_scale(draw_context))


func draw_plasma_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var plasma_state: Object = _get_instance(registry, "smasher_plasma_state")
	if _has_visible_effects(plasma_state) and plasma_state.has_method("draw"):
		plasma_state.draw(canvas, shake_offset)


func draw_recovery_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var recovery_state: Object = _get_instance(registry, "smasher_recovery_state")
	if _has_visible_effects(recovery_state) and recovery_state.has_method("draw"):
		recovery_state.draw(canvas, shake_offset, _get_instance(registry, "horizontal_timer_gauge_stack"))


func draw_cleanse_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var cleanse_state: Object = _get_instance(registry, "smasher_cleanse_state")
	if _has_visible_effects(cleanse_state) and cleanse_state.has_method("draw"):
		cleanse_state.draw(canvas, shake_offset, _get_instance(registry, "horizontal_timer_gauge_stack"))


func draw_warp_gate_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var warp_gate_state: Object = _get_instance(registry, "smasher_warp_gate_state")
	if _has_visible_effects(warp_gate_state) and warp_gate_state.has_method("draw"):
		warp_gate_state.draw(
			canvas,
			shake_offset,
			_build_node_fx_layout(canvas, registry),
			_get_instance(registry, "horizontal_timer_gauge_stack")
		)


func draw_smasher_wheel_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	if not _is_smasher_context(draw_context):
		return
	var wheel_state: Object = _get_instance(registry, "smasher_wheel_state")
	if _has_visible_effects(wheel_state) and wheel_state.has_method("draw"):
		wheel_state.draw(canvas, shake_offset, _get_instance(registry, "horizontal_timer_gauge_stack"))


func draw_monkey_blessing_delivery(canvas: CanvasItem, registry: Object, shake_offset: Vector2) -> void:
	var delivery_state: Object = _get_instance(registry, "monkey_blessing_delivery_state")
	if _has_visible_effects(delivery_state) and delivery_state.has_method("draw"):
		delivery_state.draw(canvas, shake_offset)


func draw_commando_reload_delivery(canvas: CanvasItem, registry: Object, shake_offset: Vector2) -> void:
	var delivery_state: Object = _get_instance(registry, "commando_reload_delivery_state")
	if _has_visible_effects(delivery_state) and delivery_state.has_method("draw"):
		delivery_state.draw(canvas, shake_offset)


func draw_impact_and_combo_effects(
	canvas: CanvasItem,
	registry: Object,
	shake_offset: Vector2,
	draw_context: Dictionary = {}
) -> void:
	var impact_effects: Object = _get_instance(registry, "impact_effects")
	if _has_visible_effects(impact_effects):
		var impact_renderer: Object = _get_instance(registry, "impact_effects_renderer")
		if impact_renderer != null:
			impact_renderer.draw(canvas, impact_effects, shake_offset)

	if not _is_smasher_context(draw_context):
		return
	var combo_state: Object = _get_instance(registry, "smasher_combo_state")
	if _has_combo_effects(combo_state):
		var combo_renderer: Object = _get_instance(registry, "smasher_combo_renderer")
		if combo_renderer != null:
			combo_renderer.draw_effect(canvas, combo_state, shake_offset)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	var cache_key := "%d:%s" % [target.get_instance_id(), method_name]
	if _method_argument_count_cache.has(cache_key):
		return int(_method_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			var args_count: int = args_value.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0


func _method_accepts_argument_count(target: Object, method_name: String, requested_count: int) -> bool:
	if target == null:
		return false
	var cache_key := "%d:%s:%d" % [target.get_instance_id(), method_name, requested_count]
	if _method_acceptance_cache.has(cache_key):
		return bool(_method_acceptance_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		var default_args_value: Variant = method_info.get("default_args", [])
		var method_arg_count: int = 0
		if args_value is Array:
			method_arg_count = int((args_value as Array).size())
		var default_count: int = 0
		if default_args_value is Array:
			default_count = int((default_args_value as Array).size())
		var accepts: bool = method_arg_count >= requested_count or method_arg_count + default_count >= requested_count
		_method_acceptance_cache[cache_key] = accepts
		return accepts
	_method_acceptance_cache[cache_key] = false
	return false


func _build_node_fx_layout(canvas: CanvasItem, registry: Object) -> Dictionary:
	var render_scale: float = 1.0
	var game_offset := Vector2.ZERO
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if canvas != null and layout_module != null and layout_module.has_method("build_game_layout"):
		var layout: Dictionary = layout_module.build_game_layout(canvas.get_viewport_rect().size, 760.0, 750.0)
		render_scale = max(0.01, float(layout.get("render_scale", 1.0)))
		game_offset = _get_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	return {
		"game_offset": game_offset,
		"render_scale": render_scale,
	}


func _get_stage_instance(registry: Object, current_stage: int, role: String, fallback_key: String) -> Object:
	var router: Object = _get_instance(registry, "stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		var routed: Object = router.get_instance(registry, current_stage, role)
		if routed != null:
			return routed
	return _get_instance(registry, fallback_key)


func _get_cached_stage_instance(registry: Object, stage: int, role: String) -> Object:
	var router: Object = _get_cached_instance(registry, "stage_runtime_router")
	if router == null or not router.has_method("get_module_key"):
		return null
	var key: String = str(router.get_module_key(stage, role))
	if key == "":
		return null
	return _get_cached_instance(registry, key)


func _clear_inactive_stage_actor_transients(registry: Object, current_stage: int, current_renderer: Object) -> void:
	for stage in [1, 2, 3, 4, 5, 6]:
		if stage == current_stage:
			continue
		var renderer: Object = _get_cached_stage_instance(registry, stage, "actor_renderer")
		if renderer == null or renderer == current_renderer:
			continue
		_clear_transient_canvas_items(renderer)


func _clear_inactive_stage_actor_transients_if_needed(registry: Object, current_stage: int, current_renderer: Object) -> void:
	var current_renderer_id := 0
	if current_renderer != null:
		current_renderer_id = current_renderer.get_instance_id()
	if (
		current_stage != _last_actor_stage_for_transient_cleanup
		or current_renderer_id != _last_actor_renderer_id_for_transient_cleanup
	):
		_last_actor_stage_for_transient_cleanup = current_stage
		_last_actor_renderer_id_for_transient_cleanup = current_renderer_id
		# Keep one grace frame for detached FX hosts created around stage handoff.
		_inactive_actor_transient_cleanup_frames_remaining = INACTIVE_ACTOR_TRANSIENT_CLEANUP_FRAMES
	if _inactive_actor_transient_cleanup_frames_remaining <= 0:
		return
	_inactive_actor_transient_cleanup_frames_remaining -= 1
	_clear_inactive_stage_actor_transients(registry, current_stage, current_renderer)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if value is Object and is_instance_valid(value):
		return value
	return null


func _clear_transient_canvas_items(renderer: Object) -> void:
	if renderer != null and renderer.has_method("clear_transient_canvas_items"):
		renderer.clear_transient_canvas_items()


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _get_dash_acceleration_palette(level: int) -> Dictionary:
	if level >= 3:
		return {
			"primary": Color(1.0, 200.0 / 255.0, 180.0 / 255.0),
			"secondary": Color(240.0 / 255.0, 160.0 / 255.0, 140.0 / 255.0),
			"accent": Color(1.0, 230.0 / 255.0, 210.0 / 255.0),
			"glow": 0.60,
		}
	if level >= 2:
		return {
			"primary": Color(180.0 / 255.0, 230.0 / 255.0, 1.0),
			"secondary": Color(150.0 / 255.0, 210.0 / 255.0, 240.0 / 255.0),
			"accent": Color(220.0 / 255.0, 245.0 / 255.0, 1.0),
			"glow": 0.50,
		}
	return {
		"primary": Color(245.0 / 255.0, 245.0 / 255.0, 1.0),
		"secondary": Color(230.0 / 255.0, 230.0 / 255.0, 245.0 / 255.0),
		"accent": Color(1.0, 1.0, 1.0),
		"glow": 0.40,
	}


func _draw_oval_ring(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color, width: float = 1.0) -> void:
	if canvas == null or color.a <= 0.0 or radius.x <= 0.0 or radius.y <= 0.0:
		return
	var points := PackedVector2Array()
	var segments: int = 48
	for i in range(segments + 1):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polyline(points, color, max(1.0, width), true)


func _has_visible_effects(state: Object) -> bool:
	if state == null:
		return false
	if state.has_method("has_visible_effects"):
		return bool(state.has_visible_effects())
	return true


func _has_combo_effects(combo_state: Object) -> bool:
	if combo_state == null:
		return false
	return (
		(combo_state.has_method("is_effect_active") and bool(combo_state.is_effect_active()))
		or (combo_state.has_method("has_particles") and bool(combo_state.has_particles()))
	)


func _is_smasher_context(context: Dictionary) -> bool:
	return _character_type(context) == PlayerCharacterRuntime.SMASHER


func _is_character_context(context: Dictionary, expected_character_type: String) -> bool:
	return _character_type(context) == expected_character_type


func _character_type(context: Dictionary) -> String:
	if context.is_empty() or not context.has("selected_character_type"):
		return PlayerCharacterRuntime.SMASHER
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	if character_type == "":
		return PlayerCharacterRuntime.SMASHER
	var normalized_character: String = character_runtime.normalize(character_type)
	if normalized_character == PlayerCharacterRuntime.SMASHER and character_type != PlayerCharacterRuntime.SMASHER:
		return character_type
	return normalized_character
