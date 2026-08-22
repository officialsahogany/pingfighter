extends RefCounted

const BallContextReader := preload("res://scripts/ball/ball_context_reader.gd")

const STAGE_ID := 1
const BOSS_VARIANT := "podo"
const SKILL_ID := "arrest_rope"
const GAUGE_COST := 200.0
const PHASE_IDLE := "idle"
const PHASE_THROWING := "throwing"
const PHASE_BOUND := "bound"
const PHASE_RELEASING := "releasing"
const PHASE_MISS := "miss"
const THROWING_FRAMES := 45.0
const BOUND_FRAMES := 180.0
const RELEASING_FRAMES := 28.0
const MISS_FRAMES := 30.0
const PLAYER_SPEED_MULTIPLIER := 0.5
const SMOKE_OPACITY_THRESHOLD := 0.05
const ATTACK_FRAME_COUNT := 8

var phase := PHASE_IDLE
var timer_frames := 0.0
var origin_pos := Vector2.ZERO
var target_snapshot_pos := Vector2.ZERO
var visual_target_pos := Vector2.ZERO


func _init() -> void:
	reset()


func reset() -> void:
	reset_round()


func reset_round() -> void:
	phase = PHASE_IDLE
	timer_frames = 0.0
	origin_pos = Vector2.ZERO
	target_snapshot_pos = Vector2.ZERO
	visual_target_pos = Vector2.ZERO


func can_activate(context: Dictionary = {}) -> bool:
	return (
		int(context.get("current_stage", STAGE_ID)) == STAGE_ID
		and _is_pododaejang_context(context)
		and phase == PHASE_IDLE
	)


func should_roll_activation(gauge: float, context: Dictionary = {}) -> bool:
	return gauge >= GAUGE_COST and can_activate(context)


func register_boss_hit(context: Dictionary, deps: Dictionary = {}) -> bool:
	if not can_activate(context):
		return false
	var cooldown_state: Object = deps.get("stage1_pododaejang_boss_skill_cooldown_state", null)
	if (
		cooldown_state == null
		or not cooldown_state.has_method("consume_on_hit")
		or not bool(cooldown_state.consume_on_hit(SKILL_ID, context, deps))
	):
		return false
	_start_throw(context, deps)
	return true


func activate_for_test(context: Dictionary, deps: Dictionary = {}) -> bool:
	if not can_activate(context):
		return false
	_start_throw(context, deps)
	return true


func update(fps_scale: float, context: Dictionary, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", STAGE_ID)) != STAGE_ID or not _is_pododaejang_context(context):
		reset_round()
		return {}
	if phase == PHASE_IDLE:
		return {}
	if phase == PHASE_BOUND:
		visual_target_pos = _get_player_center(context)
		if _is_player_dash_active(context):
			phase = PHASE_RELEASING
			timer_frames = RELEASING_FRAMES
			return {"stage1_pododaejang_arrest_rope_dash_break": true}
	timer_frames = maxf(0.0, timer_frames - fps_scale)
	match phase:
		PHASE_THROWING:
			if timer_frames <= 0.0:
				_resolve_throw(context, deps)
		PHASE_BOUND:
			if timer_frames <= 0.0:
				phase = PHASE_RELEASING
				timer_frames = RELEASING_FRAMES
		PHASE_RELEASING, PHASE_MISS:
			if timer_frames <= 0.0:
				reset_round()
	return {}


func get_draw_context() -> Dictionary:
	var throw_progress: float = 0.0
	if phase == PHASE_THROWING:
		throw_progress = clampf(1.0 - timer_frames / THROWING_FRAMES, 0.0, 1.0)
	var attack_frame: int = clampi(int(floor(throw_progress * float(ATTACK_FRAME_COUNT))), 0, ATTACK_FRAME_COUNT - 1)
	return {
		"stage1_pododaejang_arrest_rope_visible": phase != PHASE_IDLE,
		"stage1_pododaejang_arrest_rope_phase": phase,
		"stage1_pododaejang_arrest_rope_timer": timer_frames,
		"stage1_pododaejang_arrest_rope_origin": origin_pos,
		"stage1_pododaejang_arrest_rope_target": visual_target_pos,
		"stage1_pododaejang_arrest_rope_throw_progress": throw_progress,
		"stage1_pododaejang_arrest_rope_bound_ratio": clampf(timer_frames / BOUND_FRAMES, 0.0, 1.0) if phase == PHASE_BOUND else 0.0,
		"stage1_pododaejang_arrest_rope_active": phase == PHASE_THROWING,
		"stage1_pododaejang_arrest_rope_frame": attack_frame,
		"boss_arrest_rope_active": phase == PHASE_THROWING,
		"boss_arrest_rope_frame": attack_frame,
	}


func get_player_speed_multiplier() -> float:
	return PLAYER_SPEED_MULTIPLIER if phase == PHASE_BOUND else 1.0


func is_active() -> bool:
	return phase != PHASE_IDLE


func get_phase() -> String:
	return phase


func _start_throw(context: Dictionary, deps: Dictionary) -> void:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2.ZERO)
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 40.0))
	var boss_height: float = maxf(1.0, float(context.get("boss_hitbox_height", boss_size.y)))
	origin_pos = Vector2(boss_pos.x + boss_size.x * 0.5, boss_pos.y + boss_height)
	target_snapshot_pos = _get_player_center(context)
	visual_target_pos = target_snapshot_pos
	phase = PHASE_THROWING
	timer_frames = THROWING_FRAMES
	_play_throw_audio(deps)


func _resolve_throw(context: Dictionary, deps: Dictionary) -> void:
	var player_center: Vector2 = _get_player_center(context)
	visual_target_pos = player_center
	var player_width: float = maxf(1.0, _get_vector2(context, "player_paddle_size", Vector2(100.0, 50.0)).x)
	if _is_player_in_smoke(player_center, context, deps):
		phase = PHASE_MISS
		timer_frames = MISS_FRAMES
		return
	if absf(target_snapshot_pos.x - player_center.x) < player_width * 0.6:
		phase = PHASE_BOUND
		timer_frames = BOUND_FRAMES
		_play_bind_audio(deps)
		return
	phase = PHASE_MISS
	timer_frames = MISS_FRAMES


func _is_player_dash_active(context: Dictionary) -> bool:
	var snapshot_value: Variant = context.get("dash_snapshot", {})
	if snapshot_value is Dictionary:
		return bool((snapshot_value as Dictionary).get("active", false))
	return bool(context.get("player_dash_active", false))


func _is_player_in_smoke(player_center: Vector2, context: Dictionary, deps: Dictionary) -> bool:
	if bool(context.get("player_in_smoke", false)):
		return true
	for value in _get_smoke_zones(context, deps):
		if not (value is Dictionary):
			continue
		var zone: Dictionary = value
		var opacity: float = float(zone.get("opacity", 0.0))
		var threshold: float = 50.0 if opacity > 1.0 else SMOKE_OPACITY_THRESHOLD
		if opacity <= threshold:
			continue
		var center: Vector2 = _get_smoke_zone_center(zone)
		var radius_y: float = float(zone.get("radius", 0.0))
		var radius_x: float = float(zone.get("radius_x", radius_y))
		if radius_x <= 0.0 or radius_y <= 0.0:
			continue
		var dx: float = (player_center.x - center.x) / radius_x
		var dy: float = (player_center.y - center.y) / radius_y
		if dx * dx + dy * dy <= 1.0:
			return true
	return false


func _get_smoke_zones(context: Dictionary, deps: Dictionary) -> Array:
	for key in ["stage3_smoke_zones", "smoke_zones", "active_item_tear_gas_zones", "tear_gas_zones"]:
		var context_value: Variant = context.get(key, [])
		if context_value is Array and not (context_value as Array).is_empty():
			return context_value as Array
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("get_tear_gas_zones"):
			var runtime_value: Variant = active_item_runtime.get_tear_gas_zones()
			if runtime_value is Array and not (runtime_value as Array).is_empty():
				return runtime_value as Array
		var throw_controller: Variant = active_item_runtime.get("throw_controller")
		if throw_controller != null and typeof(throw_controller) == TYPE_OBJECT:
			var controller: Object = throw_controller as Object
			if controller.has_method("get_tear_gas_zones"):
				var controller_value: Variant = controller.get_tear_gas_zones()
				if controller_value is Array and not (controller_value as Array).is_empty():
					return controller_value as Array
	return []


func _get_smoke_zone_center(zone: Dictionary) -> Vector2:
	var position_value: Variant = zone.get("position", null)
	if position_value is Vector2:
		return position_value as Vector2
	return Vector2(float(zone.get("x", 0.0)), float(zone.get("y", 0.0)))


func _get_player_center(context: Dictionary) -> Vector2:
	var player_pos: Vector2 = _get_vector2(context, "player_pos", Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(context, "player_paddle_size", Vector2(100.0, 50.0))
	return player_pos + player_size * 0.5


func _play_throw_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_whip"):
		audio.play_whip()


func _play_bind_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_whipcrack"):
		audio.play_whipcrack()


func _is_pododaejang_context(context: Dictionary) -> bool:
	var variant: String = str(context.get("stage1_boss_variant", "dalji")).strip_edges().to_lower()
	return variant in [BOSS_VARIANT, "pododaejang", "podo_daejang"]


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BallContextReader.get_vector2(source, key, fallback)
