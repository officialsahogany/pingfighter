extends RefCounted

const ITEM_HERMES_SHOES := "hermes_shoes"
const MAX_SPEED_BONUS_PCT := 300.0
const TRAIL_LIFE_FRAMES := 24.0
const TRAIL_MAX := 5
const MOVE_TRAIL_THRESHOLD := 2.0
const WING_FLAP_SPEED := 0.16
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0


func is_equipped(runtime: Object) -> bool:
	return runtime.is_equipped(ITEM_HERMES_SHOES)


func get_speed_bonus_pct(runtime: Object) -> float:
	if not is_equipped(runtime):
		return 0.0
	return clamp(
		runtime.roll_query.get_equipped_roll_value(runtime, ITEM_HERMES_SHOES, "speed_bonus"),
		0.0,
		MAX_SPEED_BONUS_PCT
	)


func get_speed_multiplier(runtime: Object) -> float:
	return max(0.0, 1.0 + get_speed_bonus_pct(runtime) / 100.0)


func clear_runtime(runtime: Object) -> void:
	runtime.hermes_shoes_state.clear_runtime(get_default_player_size())
	_tear_down_field_fx(runtime)


func clear_round_state(runtime: Object) -> void:
	runtime.hermes_shoes_state.clear_round_state(get_default_player_size())
	_tear_down_field_fx(runtime)


func update_runtime(runtime: Object, owner: Object, fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	var player_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2.ZERO))
	var player_size := Vector2(
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
	runtime.hermes_shoes_state.update(
		is_equipped(runtime),
		player_pos,
		player_size,
		step,
		TRAIL_LIFE_FRAMES,
		TRAIL_MAX,
		MOVE_TRAIL_THRESHOLD,
		WING_FLAP_SPEED
	)


func get_default_player_size() -> Vector2:
	return Vector2(PLAYER_BASE_PADDLE_WIDTH, PLAYER_BASE_PADDLE_HEIGHT)


func _tear_down_field_fx(runtime: Object) -> void:
	if runtime == null:
		return
	var renderer: Object = runtime.get("field_effect_renderer")
	if renderer != null and renderer.has_method("tear_down_hermes_shoes_fx"):
		renderer.tear_down_hermes_shoes_fx(false)
