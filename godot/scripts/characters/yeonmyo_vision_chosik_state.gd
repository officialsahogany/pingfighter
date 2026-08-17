extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const YeonmyoVisionChosikRenderer := preload(
	"res://scripts/characters/yeonmyo_vision_chosik_renderer.gd"
)

const SKILL_ID := CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID
const COST := CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_COST
const BASE_COOLDOWN_SEC := CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_COOLDOWN
const STATUS_SOURCE := "yeonmyo_vision_bonghongwe"
const THROW_DURATION_SEC := 0.82
const THROW_PEAK_HEIGHT := 150.0
const THROW_ROTATION_RADIANS := PI * 1.35
const THROW_TARGET_FORWARD_OFFSET := 70.0
const LANDING_SETTLE_SEC := 0.34
const CHEST_LIFETIME_SEC := 12.0
const CHEST_DASH_TRIGGER_RADIUS := 56.0
const GAS_RADIUS := 80.0
const SMOKE_EMIT_SEC := 3.0
const SMOKE_FADE_SEC := 2.0
const SMOKE_CONFUSION_FRAMES := 180.0

var cooldown_remaining := 0.0
var cooldown_duration := BASE_COOLDOWN_SEC
var phase := "idle"
var throw_elapsed := 0.0
var active_remaining := 0.0
var landing_elapsed := 0.0
var smoke_elapsed := 0.0
var visual_time := 0.0
var throw_start_pos := Vector2.ZERO
var throw_target_pos := Vector2.ZERO
var throw_ground_pos := Vector2.ZERO
var throw_height := 0.0
var throw_rotation := 0.0
var throw_scale := 1.0
var chest_pos := Vector2.ZERO
var chest_opened := false
var smoke_confusion_consumed := false
var _last_down_pressed := false
var _cached_status_effect_state: Object = null
var renderer: Object = YeonmyoVisionChosikRenderer.new()


func update(
	delta: float,
	input_snapshot: Dictionary,
	modifier_pressed: bool,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - safe_delta)
	visual_time += safe_delta
	_cache_runtime_deps(deps)
	_update_effects(safe_delta, config, deps)

	var down_pressed := bool(input_snapshot.get("down_pressed", false))
	var down_edge := down_pressed and not _last_down_pressed
	_last_down_pressed = down_pressed
	if not modifier_pressed or not down_edge:
		return {"activated": false, "movement_locked": false}
	if not _can_activate(config, deps):
		return {"activated": false, "movement_locked": false}
	return _activate(player_pos, config, deps)


func is_ready(special_gauge: float, equipped: bool = true) -> bool:
	return (
		equipped
		and cooldown_remaining <= 0.0
		and phase == "idle"
		and special_gauge >= COST
	)


func is_movement_locked() -> bool:
	return false


func has_visible_effects() -> bool:
	return phase in ["throw", "closed", "open"]


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if renderer != null and has_visible_effects():
		renderer.draw(canvas, get_snapshot(), shake_offset)


func get_cooldown_ratio() -> float:
	return clampf(cooldown_remaining / maxf(0.001, cooldown_duration), 0.0, 1.0)


func get_snapshot() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"cooldown_ratio": get_cooldown_ratio(),
		"phase": phase,
		"throw_elapsed": throw_elapsed,
		"throw_duration": THROW_DURATION_SEC,
		"active_remaining": active_remaining,
		"chest_lifetime": CHEST_LIFETIME_SEC,
		"landing_elapsed": landing_elapsed,
		"landing_settle_duration": LANDING_SETTLE_SEC,
		"smoke_elapsed": smoke_elapsed,
		"smoke_emit_duration": SMOKE_EMIT_SEC,
		"smoke_fade_duration": SMOKE_FADE_SEC,
		"throw_start_pos": throw_start_pos,
		"throw_target_pos": throw_target_pos,
		"throw_ground_pos": throw_ground_pos,
		"throw_height": throw_height,
		"throw_rotation": throw_rotation,
		"throw_scale": throw_scale,
		"chest_pos": chest_pos,
		"gas_radius": GAS_RADIUS,
		"chest_opened": chest_opened,
		"smoke_confusion_consumed": smoke_confusion_consumed,
		"visual_time": visual_time,
	}


func reset_round(deps: Dictionary = {}) -> void:
	_cache_runtime_deps(deps)
	_clear_owned_confusion()
	phase = "idle"
	throw_elapsed = 0.0
	active_remaining = 0.0
	landing_elapsed = 0.0
	smoke_elapsed = 0.0
	visual_time = 0.0
	throw_start_pos = Vector2.ZERO
	throw_target_pos = Vector2.ZERO
	throw_ground_pos = Vector2.ZERO
	throw_height = 0.0
	throw_rotation = 0.0
	throw_scale = 1.0
	chest_pos = Vector2.ZERO
	chest_opened = false
	smoke_confusion_consumed = false
	_last_down_pressed = false


func reset_cooldowns() -> void:
	cooldown_remaining = 0.0


func advance_cooldowns_by_msec(bonus_msec: int, _time_now: int = -1) -> int:
	var bonus_seconds := float(maxi(0, bonus_msec)) / 1000.0
	if bonus_seconds <= 0.0 or cooldown_remaining <= 0.0:
		return 0
	cooldown_remaining = maxf(0.0, cooldown_remaining - bonus_seconds)
	return 1


func reduce_all_cooldowns_by_fraction(fraction: float, _time_now: int = -1) -> int:
	var safe_fraction := clampf(fraction, 0.0, 0.95)
	if safe_fraction <= 0.0 or cooldown_remaining <= 0.0:
		return 0
	cooldown_remaining = maxf(0.0, cooldown_remaining - cooldown_duration * safe_fraction)
	return 1


func reset() -> void:
	reset_round()
	cooldown_remaining = 0.0
	cooldown_duration = BASE_COOLDOWN_SEC


func _activate(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> Dictionary:
	phase = "throw"
	throw_elapsed = 0.0
	active_remaining = 0.0
	landing_elapsed = 0.0
	smoke_elapsed = 0.0
	visual_time = 0.0
	throw_height = 0.0
	throw_rotation = 0.0
	throw_scale = 1.0
	chest_opened = false
	smoke_confusion_consumed = false
	var player_width := maxf(1.0, float(config.get("paddle_width", 155.0)))
	var player_height := maxf(1.0, float(config.get("paddle_height", 50.0)))
	throw_start_pos = player_pos + Vector2(player_width * 0.5, player_height * 0.15)
	var boss_pos := _as_vector2(config.get("boss_pos", Vector2(380.0, 45.0)), Vector2(380.0, 45.0))
	var boss_width := maxf(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height := maxf(1.0, float(config.get("boss_hitbox_height", 40.0)))
	throw_target_pos = boss_pos + Vector2(
		boss_width * 0.5,
		boss_height * 0.5 + THROW_TARGET_FORWARD_OFFSET
	)
	throw_target_pos.x = clampf(throw_target_pos.x, 40.0, 720.0)
	throw_target_pos.y = clampf(throw_target_pos.y, 80.0, 650.0)
	throw_ground_pos = throw_start_pos
	chest_pos = throw_start_pos

	var cooldown := BASE_COOLDOWN_SEC
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		cooldown = maxf(0.0, float(skill_config.get_cooldown_seconds(SKILL_ID)))
	cooldown_remaining = cooldown
	cooldown_duration = maxf(0.001, cooldown)
	var next_gauge := maxf(0.0, float(config.get("special_gauge", 0.0)) - COST)
	var owner: Object = deps.get("owner", null)
	if owner != null:
		owner.set("special_gauge", next_gauge)
	_play_activation_audio(deps)
	return {"activated": true, "movement_locked": false, "special_gauge": next_gauge}


func _update_effects(delta: float, config: Dictionary, deps: Dictionary) -> void:
	if phase == "throw":
		throw_elapsed = minf(THROW_DURATION_SEC, throw_elapsed + delta)
		var progress := clampf(throw_elapsed / THROW_DURATION_SEC, 0.0, 1.0)
		# The ground projection travels at a steady horizontal velocity while the
		# chest follows an actual gravity parabola above it. Keeping those two
		# quantities separate lets the renderer attach a moving shadow without a
		# player-to-chest tether line.
		throw_ground_pos = throw_start_pos.lerp(throw_target_pos, progress)
		throw_height = 4.0 * THROW_PEAK_HEIGHT * progress * (1.0 - progress)
		throw_rotation = THROW_ROTATION_RADIANS * progress
		throw_scale = 1.0 + (throw_height / THROW_PEAK_HEIGHT) * 0.12
		chest_pos = throw_ground_pos - Vector2(0.0, throw_height)
		if progress >= 1.0:
			phase = "closed"
			chest_pos = throw_target_pos
			throw_ground_pos = throw_target_pos
			throw_height = 0.0
			throw_rotation = 0.0
			throw_scale = 1.0
			active_remaining = CHEST_LIFETIME_SEC
			landing_elapsed = 0.0
			_play_audio(deps, "play_stage3_chest_land")
		return
	if phase == "closed":
		landing_elapsed = minf(LANDING_SETTLE_SEC, landing_elapsed + delta)
		_try_open_from_dash(config, deps)
		if phase == "open":
			_try_apply_smoke_confusion(config, deps)
			return
		active_remaining = maxf(0.0, active_remaining - delta)
		if active_remaining <= 0.0:
			phase = "idle"
		return
	if phase != "open":
		return
	smoke_elapsed += delta
	_try_apply_smoke_confusion(config, deps)
	if smoke_elapsed >= SMOKE_EMIT_SEC + SMOKE_FADE_SEC:
		phase = "idle"


func _try_open_from_dash(config: Dictionary, deps: Dictionary) -> void:
	if chest_opened:
		return
	var ai_state: Object = deps.get("boss_ai_state", null)
	if ai_state == null or not ai_state.has_method("get_dash_token_snapshot"):
		return
	var dash_snapshot_value: Variant = ai_state.get_dash_token_snapshot()
	if not (dash_snapshot_value is Dictionary) or not bool((dash_snapshot_value as Dictionary).get("active", false)):
		return
	var owner: Object = deps.get("owner", null)
	if owner == null:
		return
	var boss_width := maxf(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height := maxf(1.0, float(config.get("boss_hitbox_height", 40.0)))
	var previous_pos := _get_owner_vector2(owner, "boss_pos_prev", _as_vector2(config.get("boss_pos", Vector2.ZERO), Vector2.ZERO))
	var current_pos := _get_owner_vector2(owner, "boss_pos", previous_pos)
	var center_offset := Vector2(boss_width * 0.5, boss_height * 0.5)
	if not _segment_intersects_circle(
		previous_pos + center_offset,
		current_pos + center_offset,
		chest_pos,
		CHEST_DASH_TRIGGER_RADIUS
	):
		return
	chest_opened = true
	phase = "open"
	smoke_elapsed = 0.0
	active_remaining = 0.0


func _try_apply_smoke_confusion(config: Dictionary, deps: Dictionary) -> void:
	# Match the original Stage 3 chest: only actively emitted smoke is hazardous.
	# The following two seconds are a visual fade, not an extended hit window.
	if (
		smoke_elapsed > SMOKE_EMIT_SEC
		or smoke_confusion_consumed
		or _is_boss_status_immune(config, deps)
	):
		return
	var owner: Object = deps.get("owner", null)
	if owner == null:
		return
	var boss_width := maxf(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height := maxf(1.0, float(config.get("boss_hitbox_height", 40.0)))
	var boss_pos := _get_owner_vector2(
		owner,
		"boss_pos",
		_as_vector2(config.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	)
	var boss_center := boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5)
	if boss_center.distance_to(chest_pos) >= GAS_RADIUS:
		return
	if not _apply_confusion(SMOKE_CONFUSION_FRAMES):
		return
	smoke_confusion_consumed = true
	var ai_state: Object = deps.get("boss_ai_state", null)
	if ai_state != null and ai_state.has_method("get_dash_token_snapshot"):
		var dash_snapshot_value: Variant = ai_state.get_dash_token_snapshot()
		if (
			dash_snapshot_value is Dictionary
			and bool((dash_snapshot_value as Dictionary).get("active", false))
			and ai_state.has_method("cancel_dash_without_stun")
		):
			ai_state.cancel_dash_without_stun(deps.get("audio", null))


func _apply_confusion(duration_frames: float) -> bool:
	if _cached_status_effect_state == null or not _cached_status_effect_state.has_method("apply_status"):
		return false
	_cached_status_effect_state.apply_status(
		"boss",
		"confusion",
		duration_frames,
		{},
		STATUS_SOURCE
	)
	return true


func _clear_owned_confusion() -> void:
	if _cached_status_effect_state != null and _cached_status_effect_state.has_method("clear_status"):
		_cached_status_effect_state.clear_status("boss", "confusion", STATUS_SOURCE)


func _cache_runtime_deps(deps: Dictionary) -> void:
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null:
		_cached_status_effect_state = status_effect_state


func _can_activate(config: Dictionary, deps: Dictionary) -> bool:
	if phase != "idle" or cooldown_remaining > 0.0:
		return false
	if not bool(config.get("ball_active", false)) or bool(config.get("player_skill_input_locked", false)):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config == null or not skill_config.has_method("is_skill_equipped"):
		return false
	if not bool(skill_config.is_skill_equipped(SKILL_ID)):
		return false
	return float(config.get("special_gauge", 0.0)) >= COST


func _is_boss_status_immune(config: Dictionary, deps: Dictionary) -> bool:
	if int(config.get("current_stage", 0)) != 2:
		return false
	if bool(config.get("stage2_speed_defense_status_immunity_active", false)) or bool(config.get("stage2_speed_defense_active", false)):
		return true
	var registry: Object = deps.get("registry", null)
	var stage2_state: Object = null
	if registry != null and registry.has_method("get_instance"):
		stage2_state = registry.get_instance("stage2_boss_skill_state")
	return stage2_state != null and stage2_state.has_method("is_boss_status_immune") and bool(stage2_state.is_boss_status_immune())


func _segment_intersects_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start.distance_squared_to(center) <= radius * radius
	var projection := clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
	var nearest := start + segment * projection
	return nearest.distance_squared_to(center) <= radius * radius


func _get_owner_vector2(owner: Object, property_name: String, fallback: Vector2) -> Vector2:
	var value: Variant = owner.get(property_name)
	return value if value is Vector2 else fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _play_activation_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_stage3_dollcurse"):
		audio.play_stage3_dollcurse()
	elif audio.has_method("play_whip"):
		audio.play_whip()


func _play_audio(deps: Dictionary, method_name: String) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)
