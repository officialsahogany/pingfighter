extends RefCounted

const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")


func handle_round_restart(reason: String, deps: Dictionary, callbacks: Dictionary) -> void:
	AngelBlessingRollOverlayHost.hide_all_existing_hosts()
	# Score/serve ball resets must preserve held-input discard latches. Only this
	# true round-restart lifecycle clears the actor-owned Vision input state.
	_call_callback(callbacks, "reset_vision_input_state")
	var round_state: Object = deps.get("round_state", null)
	if not _call_callback(callbacks, "reset_ball") and round_state != null and round_state.has_method("reset_round_wait"):
		round_state.reset_round_wait()
	if reason == "rematch" and round_state != null and round_state.has_method("start_round_restart_notice"):
		round_state.start_round_restart_notice()
	_stop_round_restart_audio(deps)


func _stop_round_restart_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	GameplayLoopAudioCleanup.stop_all(audio)


func _call_callback(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	if not callback.is_valid():
		return false
	callback.call()
	return true
