extends RefCounted

const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const Stage3BossSkillPayloadFactory := preload("res://scripts/stages/stage3/stage3_boss_skill_payload_factory.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const COOLDOWN_SEC := 25.0
const DURATION_SEC := 400.0 / 60.0
const CAST_DURATION_SEC := 0.8
const MIN_COUNT := 4
const MAX_COUNT := 7
const ENRAGED_MIN_COUNT := 8
const ENRAGED_MAX_COUNT := 14
const SLOW_SOURCE := "stage3_tear_shower"
const SLOW_DURATION_FRAMES := 130.0
const SLOW_STACK_AMOUNT := 0.20
const SLOW_STACK_MAX := 0.80

var tears_active := false
var tears_timer := 0.0
var tears_cooldown := COOLDOWN_SEC
var falling_tears: Array = []

var _rng: RandomNumberGenerator


func _init(shared_rng: RandomNumberGenerator) -> void:
	_rng = shared_rng


func reset() -> void:
	tears_cooldown = COOLDOWN_SEC
	reset_effects()


func reset_effects() -> void:
	tears_active = false
	tears_timer = 0.0
	falling_tears.clear()


func update_cooldown(delta: float) -> void:
	tears_cooldown = max(0.0, tears_cooldown - delta)


func is_ready() -> bool:
	return tears_cooldown <= 0.0 and not tears_active


func activate(context: Dictionary, deps: Dictionary) -> void:
	tears_active = true
	tears_timer = DURATION_SEC
	tears_cooldown = COOLDOWN_SEC
	falling_tears.clear()
	var count_min := ENRAGED_MIN_COUNT if bool(context.get("enraged_boss_active", false)) else MIN_COUNT
	var count_max := ENRAGED_MAX_COUNT if bool(context.get("enraged_boss_active", false)) else MAX_COUNT
	for _index in range(_rng.randi_range(count_min, count_max)):
		falling_tears.append(Stage3BossSkillPayloadFactory.build_falling_tear(WIDTH, _rng))
	_play_audio(deps)


func consume_parried() -> void:
	tears_cooldown = COOLDOWN_SEC
	reset_effects()


func update(delta: float, context: Dictionary, deps: Dictionary) -> void:
	if not tears_active:
		return
	tears_timer -= delta
	if tears_timer <= 0.0:
		tears_active = false
		falling_tears.clear()
		return
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_rect := Rect2(player_pos, player_size)
	for idx in range(falling_tears.size() - 1, -1, -1):
		var tear: Dictionary = falling_tears[idx]
		tear["prev_y"] = float(tear.get("y", 0.0))
		tear["y"] = float(tear.get("y", 0.0)) + float(tear.get("speed", 3.0)) * delta * 60.0
		if float(tear.get("y", 0.0)) > HEIGHT + 50.0:
			tear["x"] = _rng.randf_range(0.0, WIDTH - 20.0)
			tear["y"] = _rng.randf_range(-100.0, -20.0)
			tear["prev_y"] = tear["y"]
			tear["speed"] = _rng.randf_range(2.0, 5.0)
		if player_rect.intersects(Rect2(Vector2(float(tear["x"]) - 5.0, float(tear["y"]) - 5.0), Vector2(10.0, 10.0))):
			falling_tears.remove_at(idx)
			_apply_player_slow(deps)
			_play_audio(deps)
		else:
			falling_tears[idx] = tear


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage3_tears_active": tears_active,
		"stage3_falling_tears": StageActorDrawContextArrays.snapshot(falling_tears, copy_arrays, true),
		"stage3_tear_shower_cast_active": is_cast_active(),
		"stage3_tear_shower_cast_progress": get_cast_progress(),
	}


func is_cast_active() -> bool:
	return tears_active and _get_cast_elapsed_sec() < CAST_DURATION_SEC


func get_cast_progress() -> float:
	if not is_cast_active():
		return 0.0
	return clamp(_get_cast_elapsed_sec() / CAST_DURATION_SEC, 0.0, 1.0)


func _get_cast_elapsed_sec() -> float:
	return max(0.0, DURATION_SEC - tears_timer)


func _apply_player_slow(deps: Dictionary) -> void:
	if _is_player_cleanse_immune(deps):
		return
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state == null or not status_effect_state.has_method("apply_status"):
		return
	var current_multiplier := 1.0
	if status_effect_state.has_method("get_status_source"):
		var current_tears_slow: Dictionary = status_effect_state.get_status_source("player", "slow", SLOW_SOURCE)
		if not current_tears_slow.is_empty():
			current_multiplier = clamp(float(current_tears_slow.get("multiplier", current_multiplier)), 0.0, 1.0)
	var minimum_multiplier: float = 1.0 - SLOW_STACK_MAX
	var next_multiplier: float = max(minimum_multiplier, current_multiplier - SLOW_STACK_AMOUNT)
	status_effect_state.apply_status("player", "slow", SLOW_DURATION_FRAMES, {
		"multiplier": next_multiplier,
		"cleansable": true,
		"visual_variant": "tears",
		"label": "환루천우",
	}, SLOW_SOURCE)


func _is_player_cleanse_immune(deps: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	return cleanse_state != null and cleanse_state.has_method("is_immune") and bool(cleanse_state.is_immune())


func _play_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage3_tears"):
		audio.play_stage3_tears()


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
