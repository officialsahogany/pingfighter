extends SceneTree

const LingpetAudioDispatcher := preload("res://scripts/lingpet/lingpet_audio_dispatcher.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func play_lingpet_acquire_cutin() -> void:
		calls.append({"method": "play_lingpet_acquire_cutin"})

	func play_lingpet_ring_dash() -> void:
		calls.append({"method": "play_lingpet_ring_dash"})

	func play_lingpet_egg_hit() -> void:
		calls.append({"method": "play_lingpet_egg_hit"})

	func play_lingpet_click_reaction(pet_id: String) -> void:
		calls.append({"method": "play_lingpet_click_reaction", "pet_id": pet_id})

	func play_lingpet_acquire_click_reaction_backing() -> void:
		calls.append({"method": "play_lingpet_acquire_click_reaction_backing"})


class FakeRegistry:
	extends RefCounted

	var audio: Object = null
	var requested_keys: Array[String] = []

	func _init(audio_instance: Object = null) -> void:
		audio = audio_instance

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_dispatch_methods_call_game_audio()
	_verify_runtime_delegates_lingpet_audio_dispatch()

	if _failures.is_empty():
		print("lingpet_audio_dispatcher_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatch_methods_call_game_audio() -> void:
	var dispatcher := LingpetAudioDispatcher.new()
	_expect(not dispatcher.play_lingpet_acquire_cutin(null), "missing registry should not dispatch acquire cut-in audio")
	_expect(not dispatcher.play_lingpet_ring_dash(FakeRegistry.new(null)), "missing game_audio instance should not dispatch ring dash audio")
	_expect(not dispatcher.play_lingpet_egg_hit(FakeRegistry.new(null)), "missing game_audio instance should not dispatch egg-hit audio")

	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	_expect(dispatcher.play_lingpet_acquire_cutin(registry), "dispatcher should play acquisition cut-in through GameAudio")
	_expect(dispatcher.play_lingpet_ring_dash(registry), "dispatcher should play ring dash through GameAudio")
	_expect(dispatcher.play_lingpet_click_reaction(registry, "lunabi"), "dispatcher should pass pet id to click-reaction voice dispatch")
	_expect(dispatcher.play_lingpet_acquire_click_reaction_backing(registry), "dispatcher should play acquisition click backing through GameAudio")
	_expect(dispatcher.play_lingpet_egg_hit(registry), "dispatcher should play egg-hit through GameAudio")
	_expect(registry.requested_keys == ["game_audio", "game_audio", "game_audio", "game_audio", "game_audio"], "dispatcher should resolve only the game_audio registry key")
	_expect(audio.calls.size() == 5, "dispatcher should produce one GameAudio call per successful request")
	if audio.calls.size() >= 5:
		_expect(str(audio.calls[0].get("method", "")) == "play_lingpet_acquire_cutin", "first call should be acquisition cut-in")
		_expect(str(audio.calls[1].get("method", "")) == "play_lingpet_ring_dash", "second call should be ring dash")
		_expect(str(audio.calls[2].get("method", "")) == "play_lingpet_click_reaction", "third call should be click reaction")
		_expect(str(audio.calls[2].get("pet_id", "")) == "lunabi", "click reaction should forward the current pet id")
		_expect(str(audio.calls[3].get("method", "")) == "play_lingpet_acquire_click_reaction_backing", "fourth call should be acquisition click backing")
		_expect(str(audio.calls[4].get("method", "")) == "play_lingpet_egg_hit", "fifth call should be egg-hit")


func _verify_runtime_delegates_lingpet_audio_dispatch() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var dispatcher_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_audio_dispatcher.gd")
	_expect(runtime_source.find("LingpetAudioDispatcher") >= 0, "egg runtime should preload the lingpet audio dispatcher")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_acquire_cutin") >= 0, "acquisition cut-in wrapper should delegate to the audio dispatcher")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_ring_dash") >= 0, "ring dash wrapper should delegate to the audio dispatcher")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_egg_hit") >= 0, "egg-hit wrapper should delegate to the audio dispatcher")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_click_reaction") >= 0, "click-reaction wrapper should delegate to the audio dispatcher")
	_expect(runtime_source.find("_audio_dispatcher.play_lingpet_acquire_click_reaction_backing") >= 0, "acquisition click backing wrapper should delegate to the audio dispatcher")
	_expect(runtime_source.find("get_instance(\"game_audio\")") < 0, "egg runtime should not directly resolve GameAudio after dispatcher extraction")
	_expect(dispatcher_source.find("get_instance(GAME_AUDIO_KEY)") >= 0, "audio dispatcher should own GameAudio registry lookup")
	_expect(dispatcher_source.find("callv(method_name, args)") >= 0, "audio dispatcher should own guarded GameAudio method invocation")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
