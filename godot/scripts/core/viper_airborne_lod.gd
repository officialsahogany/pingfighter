extends RefCounted

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const LOD_EFFECT_SCALE := 0.48
const GLIDE_EFFECT_SCALE := 0.58
const AIRBORNE_EFFECT_SCALE := 0.72
const FPS_CAP_EFFECT_SCALE := GLIDE_EFFECT_SCALE
const FPS_CAP_LOD_MAX_FPS := 72
const AIR_STRIKE_FLASH_VISIBLE_PROGRESS_CAP := 0.52
const GLIDE_SEVERE_ENTER_MSEC := 96
const GLIDE_SEVERE_EXIT_HOLD_MSEC := 128

static var _glide_candidate_started_msec := -1
static var _glide_severe_hold_until_msec := -1
static var _glide_severe_lod_active := false
static var _character_runtime: Object = PlayerCharacterRuntime.new()


static func is_airborne_lod_active(context: Dictionary) -> bool:
	return (
		_is_viper_selected(context)
		and bool(context.get("viper_jetpack_airborne", false))
	)


static func is_air_strike_lod_active(context: Dictionary) -> bool:
	return (
		is_airborne_lod_active(context)
		and float(context.get("viper_air_strike_flash_timer", 0.0)) > 0.0
	)


static func is_glide_lod_active(context: Dictionary) -> bool:
	return (
		is_airborne_lod_active(context)
		and not bool(context.get("viper_jetpack_active", false))
	)


static func is_fps_cap_lod_active(context: Dictionary) -> bool:
	var max_fps: int = _get_configured_max_fps()
	return (
		_is_viper_selected(context)
		and max_fps > 0
		and max_fps <= FPS_CAP_LOD_MAX_FPS
	)


static func is_any_lod_active(context: Dictionary) -> bool:
	return (
		is_air_strike_lod_active(context)
		or is_airborne_lod_active(context)
		or is_fps_cap_lod_active(context)
	)


static func effect_scale(context: Dictionary) -> float:
	var current_msec: int = _get_context_msec(context)
	if is_air_strike_lod_active(context):
		_prime_glide_severe_hold(current_msec)
		return LOD_EFFECT_SCALE
	if is_glide_lod_active(context):
		return _get_glide_hysteresis_scale(current_msec)
	_reset_glide_candidate()
	if _glide_severe_lod_active:
		if is_airborne_lod_active(context) and current_msec <= _glide_severe_hold_until_msec:
			return GLIDE_EFFECT_SCALE
		_reset_glide_hysteresis_state()
	if is_airborne_lod_active(context):
		return AIRBORNE_EFFECT_SCALE
	if is_fps_cap_lod_active(context):
		_reset_glide_hysteresis_state()
		return FPS_CAP_EFFECT_SCALE
	_reset_glide_hysteresis_state()
	return 1.0


static func reset_cache_for_test() -> void:
	_reset_glide_hysteresis_state()


static func _get_configured_max_fps() -> int:
	var max_fps: int = int(Engine.get("max_fps"))
	if max_fps > 0:
		return max_fps
	var runtime_cap: int = int(BattleViewLayout.get_runtime_render_fps_cap())
	if runtime_cap > 0:
		return runtime_cap
	return max_fps


static func _is_viper_selected(context: Dictionary) -> bool:
	return _character_runtime.is_viper(context.get("selected_character_type", ""))


static func _get_context_msec(context: Dictionary) -> int:
	for key in ["current_msec", "current_time_msec", "time_msec", "viper_lod_msec"]:
		if context.has(key):
			return int(context.get(key, Time.get_ticks_msec()))
	return Time.get_ticks_msec()


static func _get_glide_hysteresis_scale(current_msec: int) -> float:
	if _glide_candidate_started_msec < 0:
		_glide_candidate_started_msec = current_msec
	if (
		_glide_severe_lod_active
		or current_msec - _glide_candidate_started_msec >= GLIDE_SEVERE_ENTER_MSEC
	):
		_prime_glide_severe_hold(current_msec)
		return GLIDE_EFFECT_SCALE
	return AIRBORNE_EFFECT_SCALE


static func _prime_glide_severe_hold(current_msec: int) -> void:
	_glide_severe_lod_active = true
	_glide_severe_hold_until_msec = current_msec + GLIDE_SEVERE_EXIT_HOLD_MSEC
	if _glide_candidate_started_msec < 0:
		_glide_candidate_started_msec = current_msec


static func _reset_glide_candidate() -> void:
	_glide_candidate_started_msec = -1


static func _reset_glide_hysteresis_state() -> void:
	_glide_candidate_started_msec = -1
	_glide_severe_hold_until_msec = -1
	_glide_severe_lod_active = false
