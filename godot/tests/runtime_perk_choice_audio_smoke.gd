extends SceneTree

const RuntimePerkChoiceAudio := preload("res://scripts/characters/runtime_perk_choice_audio.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_audio_priority()
	_verify_runtime_state_facade_audio_paths()
	_verify_state_wrapper_audio_paths()
	_verify_source_contract()

	if _failures.is_empty():
		print("runtime_perk_choice_audio_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_audio_priority() -> void:
	var helper := RuntimePerkChoiceAudio.new()
	var item_audio := ItemGetAudio.new()
	var registry := FakeRegistry.new({"game_audio": item_audio})
	_expect(helper.play_active_unlock_flight(registry, Callable(self, "_get_instance")), "active unlock flight audio should play when game_audio is present")
	_expect(item_audio.item_get_calls == 1, "active unlock flight audio should prefer the item-get cue")
	_expect(item_audio.choice_open_calls == 0, "item-get cue should suppress the choice-open fallback")

	var open_audio := ChoiceOpenAudio.new()
	registry = FakeRegistry.new({"game_audio": open_audio})
	_expect(helper.play_active_unlock_flight(registry, Callable(self, "_get_instance")), "active unlock flight audio should fall back to choice-open cue")
	_expect(open_audio.choice_open_calls == 1, "choice-open fallback should be called")

	var select_audio := SelectAudio.new()
	registry = FakeRegistry.new({"game_audio": select_audio})
	_expect(helper.play_perk_select(registry, Callable(self, "_get_instance")), "perk select audio should call its one-shot cue")
	_expect(select_audio.select_calls == 1, "perk select cue should be called once")
	_expect(not helper.play_perk_select(FakeRegistry.new({}), Callable(self, "_get_instance")), "missing game_audio should report no cue played")


func _verify_runtime_state_facade_audio_paths() -> void:
	var helper := RuntimePerkChoiceAudio.new()
	var runtime_state := FakeRuntimeState.new()
	var item_audio := ItemGetAudio.new()
	var registry := FakeRegistry.new({"game_audio": item_audio})
	_expect(helper.play_active_unlock_flight_from_runtime_state(runtime_state, registry), "runtime-state facade should play active unlock flight audio")
	_expect(item_audio.item_get_calls == 1, "runtime-state facade should resolve game audio through state get-instance")

	var select_audio := SelectAudio.new()
	registry = FakeRegistry.new({"game_audio": select_audio})
	_expect(helper.play_perk_select_from_runtime_state(runtime_state, registry), "runtime-state facade should play perk select audio")
	_expect(select_audio.select_calls == 1, "runtime-state facade should call perk select once")


func _verify_state_wrapper_audio_paths() -> void:
	var state := RuntimePerkState.new()
	var select_audio := SelectAudio.new()
	var registry := FakeRegistry.new({"game_audio": select_audio})
	state._play_perk_select_audio(registry)
	_expect(select_audio.select_calls == 1, "state wrapper should delegate perk select audio")

	var item_audio := ItemGetAudio.new()
	registry = FakeRegistry.new({"game_audio": item_audio})
	state._play_active_unlock_flight_audio(registry)
	_expect(item_audio.item_get_calls == 1, "state wrapper should delegate active unlock flight audio")


func _verify_source_contract() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_audio.gd")
	_expect(helper_source.find("play_active_unlock_flight_from_runtime_state") >= 0, "choice audio should expose active-unlock runtime-state facade")
	_expect(helper_source.find("play_perk_select_from_runtime_state") >= 0, "choice audio should expose perk-select runtime-state facade")
	_expect(helper_source.find("RuntimePerkRuntimeStateAccess.build_callable(runtime_state, \"_get_instance\")") >= 0, "choice audio should assemble runtime-state get-instance callback")

	var flight_body: String = _function_body(state_source, "func _play_active_unlock_flight_audio(")
	_expect(flight_body.find("play_active_unlock_flight_from_runtime_state") >= 0, "state active-unlock audio wrapper should use runtime-state facade")
	_expect(flight_body.find("Callable(self, \"_get_instance\")") < 0, "state active-unlock audio wrapper should not assemble get-instance callback inline")

	var select_body: String = _function_body(state_source, "func _play_perk_select_audio(")
	_expect(select_body.find("play_perk_select_from_runtime_state") >= 0, "state perk-select audio wrapper should use runtime-state facade")
	_expect(select_body.find("Callable(self, \"_get_instance\")") < 0, "state perk-select audio wrapper should not assemble get-instance callback inline")


func _get_instance(registry: Object, key: String) -> Object:
	if registry != null and registry.has_method("get_instance"):
		return registry.get_instance(key)
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeRegistry:
	var instances: Dictionary = {}

	func _init(source: Dictionary) -> void:
		instances = source

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeRuntimeState:
	func _get_instance(registry: Object, key: String) -> Object:
		if registry != null and registry.has_method("get_instance"):
			return registry.get_instance(key)
		return null


class ItemGetAudio:
	var item_get_calls := 0
	var choice_open_calls := 0

	func play_item_get() -> void:
		item_get_calls += 1

	func play_runtime_perk_choice_open() -> void:
		choice_open_calls += 1


class ChoiceOpenAudio:
	var choice_open_calls := 0

	func play_runtime_perk_choice_open() -> void:
		choice_open_calls += 1


class SelectAudio:
	var select_calls := 0

	func play_runtime_perk_select() -> void:
		select_calls += 1


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
