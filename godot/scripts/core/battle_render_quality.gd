extends RefCounted

const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const FPS_CAP_EFFECT_SCALE := ViperAirborneLod.FPS_CAP_EFFECT_SCALE
const FPS_CAP_LOD_MAX_FPS := ViperAirborneLod.FPS_CAP_LOD_MAX_FPS
const HIGH_REFRESH_EFFECT_SCALE := ViperAirborneLod.GLIDE_EFFECT_SCALE
const HIGH_REFRESH_LOD_MIN_FPS := 120

static var _character_runtime: Object = PlayerCharacterRuntime.new()

static func effect_scale(context: Dictionary = {}) -> float:
	var scale := 1.0
	if _is_viper_selected(context):
		scale = minf(scale, ViperAirborneLod.effect_scale(context))
	if is_fps_cap_lod_active():
		scale = minf(scale, FPS_CAP_EFFECT_SCALE)
	if is_high_refresh_lod_active():
		scale = minf(scale, HIGH_REFRESH_EFFECT_SCALE)
	return scale


static func is_fps_cap_lod_active() -> bool:
	var max_fps: int = _get_configured_max_fps()
	return max_fps > 0 and max_fps <= FPS_CAP_LOD_MAX_FPS


static func is_high_refresh_lod_active() -> bool:
	var max_fps: int = _get_configured_max_fps()
	return max_fps >= HIGH_REFRESH_LOD_MIN_FPS


static func reset_cache_for_test() -> void:
	ViperAirborneLod.reset_cache_for_test()


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
