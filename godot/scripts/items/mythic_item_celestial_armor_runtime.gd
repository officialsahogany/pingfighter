extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_CELESTIAL_ARMOR := "celestial_armor"
const MAX_TRIGGER_CHANCE_PCT := 100.0
const MAX_GAUGE_COST := 100.0
const WAVE_LIFE_FRAMES := 33.0
const WAVE_RADIUS_MAX := 110.0
const PAIRED_PROC_WINDOW_FRAMES := 3.0
const SHARD_COUNT := 10
const ARC_SEGMENTS := 18
const FEEDBACK_SHAKE_AMOUNT := 0.052
const FEEDBACK_SHAKE_INTENSITY := 2.4
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_CELESTIAL_ARMOR)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func get_trigger_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "trigger_chance_pct")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_CELESTIAL_ARMOR, "trigger_chance_pct"),
		0.0,
		MAX_TRIGGER_CHANCE_PCT
	)


func get_gauge_cost(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, "gauge_cost")
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_CELESTIAL_ARMOR, "gauge_cost"),
		0.0,
		MAX_GAUGE_COST
	)


func try_consume_immunity(
	runtime: Object,
	source: String,
	effect_type: String,
	deps: Dictionary
) -> bool:
	var normalized_effect_type: String = effect_type.strip_edges().to_lower() if effect_type != "" else "generic"
	if normalized_effect_type != "stun":
		return false
	if runtime.celestial_armor_state.consume_paired_proc_bypass(source, normalized_effect_type):
		return true

	if not is_active(runtime):
		return false
	var chance_pct: float = get_trigger_chance_pct(runtime)
	if chance_pct <= 0.0 or randf() * 100.0 > chance_pct:
		return false
	var gauge_cost: int = max(0, int(round(get_gauge_cost(runtime))))
	if not consume_gauge(runtime, gauge_cost, deps):
		return false

	start_wave(runtime, resolve_player_center(runtime, deps))
	runtime.celestial_armor_state.record_block(
		source,
		normalized_effect_type,
		PAIRED_PROC_WINDOW_FRAMES
	)
	runtime.audio_router.apply_ragnarok_feedback(
		runtime,
		deps,
		FEEDBACK_SHAKE_AMOUNT,
		FEEDBACK_SHAKE_INTENSITY
	)
	runtime.gauge_feedback.trigger_gauge_flash(runtime, deps)
	runtime.audio_router.play_celestial_armor_audio(runtime, runtime._get_dict(deps).get("registry", null))
	var owner: Object = deps.get("owner", null)
	if owner != null:
		runtime._sync_owner(owner, runtime._get_dict(deps).get("registry", null))
	return true


func clear_runtime(runtime: Object) -> void:
	runtime.celestial_armor_state.clear_runtime()


func clear_round_state(runtime: Object) -> void:
	runtime.celestial_armor_state.clear_round_state()


func update_runtime(runtime: Object, fps_scale: float) -> void:
	runtime.celestial_armor_state.update(fps_scale, is_active(runtime))


func consume_gauge(
	runtime: Object,
	gauge_cost: int,
	deps: Dictionary
) -> bool:
	if gauge_cost <= 0:
		return true
	var context: Dictionary = runtime._get_dict(deps.get("context", {}))
	var owner: Object = deps.get("owner", null)
	if owner == null and context.get("owner", null) is Object:
		owner = context.get("owner", null)
	var fallback_gauge: float = float(context.get("special_gauge", 0.0))
	if owner != null:
		var current_owner_gauge: float = max(
			0.0,
			float(runtime._safe_owner_get(owner, "special_gauge", fallback_gauge))
		)
		if current_owner_gauge + 0.001 < float(gauge_cost):
			return false
		var next_owner_gauge: float = max(0.0, current_owner_gauge - float(gauge_cost))
		owner.set("special_gauge", next_owner_gauge)
		context["special_gauge"] = next_owner_gauge
		return true
	if context.is_empty():
		return false
	var current_context_gauge: float = max(0.0, float(context.get("special_gauge", 0.0)))
	if current_context_gauge + 0.001 < float(gauge_cost):
		return false
	context["special_gauge"] = max(0.0, current_context_gauge - float(gauge_cost))
	return true


func start_wave(runtime: Object, center: Vector2) -> void:
	runtime.celestial_armor_state.start_wave(center, WAVE_LIFE_FRAMES)


func resolve_player_center(runtime: Object, deps: Dictionary) -> Vector2:
	var context: Dictionary = runtime._get_dict(deps.get("context", {}))
	if not context.is_empty():
		var context_pos: Vector2 = runtime._get_vector2(context.get("player_pos", Vector2.ZERO))
		var context_size: Vector2 = runtime._get_vector2(context.get("player_paddle_size", Vector2.ZERO))
		if context_size == Vector2.ZERO:
			context_size = Vector2(
				float(context.get("player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)),
				float(context.get("player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT))
			)
		if context_pos != Vector2.ZERO or context.has("player_pos"):
			return context_pos + context_size * 0.5
	var owner: Object = deps.get("owner", null)
	if owner == null and context.get("owner", null) is Object:
		owner = context.get("owner", null)
	if owner != null:
		var owner_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
		var owner_size := Vector2(
			float(runtime._safe_owner_get(
				owner,
				"player_paddle_width",
				PLAYER_BASE_PADDLE_WIDTH
			)),
			float(runtime._safe_owner_get(
				owner,
				"player_paddle_height",
				PLAYER_BASE_PADDLE_HEIGHT
			))
		)
		return owner_pos + owner_size * 0.5
	return Vector2(
		FIELD_WIDTH * 0.5,
		FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT * 0.5
	)


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_CELESTIAL_ARMOR, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_CELESTIAL_ARMOR)))
	return 0
