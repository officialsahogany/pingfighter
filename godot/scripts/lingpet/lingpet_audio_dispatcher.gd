extends RefCounted

const GAME_AUDIO_KEY := "game_audio"


func play_lingpet_acquire_cutin(registry: Object = null) -> bool:
	return _call_game_audio(registry, "play_lingpet_acquire_cutin")


func play_lingpet_ring_dash(registry: Object = null) -> bool:
	return _call_game_audio(registry, "play_lingpet_ring_dash")


func play_lingpet_click_reaction(registry: Object = null, pet_id: String = "") -> bool:
	return _call_game_audio(registry, "play_lingpet_click_reaction", [pet_id])


func play_lingpet_acquire_click_reaction_backing(registry: Object = null) -> bool:
	return _call_game_audio(registry, "play_lingpet_acquire_click_reaction_backing")


func _call_game_audio(registry: Object, method_name: StringName, args: Array = []) -> bool:
	if registry == null or not registry.has_method("get_instance"):
		return false
	var audio: Object = registry.get_instance(GAME_AUDIO_KEY)
	if audio == null or not audio.has_method(method_name):
		return false
	audio.callv(method_name, args)
	return true
