extends RefCounted


static func resolve_audio(deps: Dictionary, fallback: Object = null) -> Object:
	var audio: Object = deps.get("audio", null)
	if audio != null:
		return audio
	return fallback


static func play_quake_loop(deps: Dictionary, fallback: Object = null, current_active: bool = false) -> bool:
	var audio: Object = resolve_audio(deps, fallback)
	if audio == null or not audio.has_method("play_stage2_quake_loop"):
		return current_active
	audio.play_stage2_quake_loop()
	return true


static func stop_quake_loop(deps: Dictionary, fallback: Object = null) -> bool:
	var audio: Object = resolve_audio(deps, fallback)
	if audio != null and audio.has_method("stop_stage2_quake_loop"):
		audio.stop_stage2_quake_loop()
	return false


static func sync_quake_loop(
	quake_timer: float,
	current_active: bool,
	deps: Dictionary,
	fallback: Object = null
) -> bool:
	if quake_timer > 0.0:
		return play_quake_loop(deps, fallback, current_active)
	if current_active:
		return stop_quake_loop(deps, fallback)
	return current_active


static func play_boss_cry(deps: Dictionary, fallback: Object = null) -> void:
	var audio: Object = resolve_audio(deps, fallback)
	if audio != null and audio.has_method("play_stage2_boss_cry"):
		audio.play_stage2_boss_cry()
