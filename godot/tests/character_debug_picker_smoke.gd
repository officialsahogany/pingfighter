extends SceneTree

const BattleSceneApi := preload("res://scripts/core/battle_scene_api.gd")
const CharacterDebugPicker := preload("res://scripts/core/character_debug_picker.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var _failures: Array[String] = []
var _ran := false


class FakeBattleOwner:
	extends Node

	var data: Dictionary = {
		"selected_character_id": "ufo_player",
		"selected_runtime_character_id": "smasher",
		"selected_character_type": "smasher",
		"selected_character_name": "\uc2a4\ub9e4\uc154",
		"player_speed": 5.0,
	}
	var redraw_count := 0

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true

	func queue_redraw() -> void:
		redraw_count += 1


class FakeRegistry:
	extends RefCounted

	var api: Object = BattleSceneApi.new()
	var character_runtime: Object = PlayerCharacterRuntime.new()

	func get_instance(key: String) -> Object:
		match key:
			"battle_scene_api":
				return api
			"player_character_runtime":
				return character_runtime
		return null


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	@warning_ignore("shadowed_variable_base_class")
	var root: Window = get_root()
	var state: Node = _get_or_create_selection_state(root)
	var owner := FakeBattleOwner.new()
	root.add_child(owner)
	var registry := FakeRegistry.new()
	var picker: Object = CharacterDebugPicker.new()

	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("character_debug_picker")
	_expect(str(spec.get("path", "")) == "res://scripts/core/character_debug_picker.gd", "character debug picker should be registered in the gameplay module catalog")

	picker.toggle(owner)
	_expect(bool(picker.is_open()), "F1 picker toggle should open the character debug menu")
	var entries: Array = picker._get_entries()
	_expect(entries.size() >= 3, "character debug menu should expose the playable runtime characters")
	_expect(_find_runtime_index(entries, "smasher") >= 0, "character debug menu should include Smasher")
	_expect(_find_runtime_index(entries, "soldier") >= 0, "character debug menu should include Commando")
	_expect(_find_runtime_index(entries, "optimus") >= 0, "character debug menu should include Optimus / Io")
	_expect(_find_runtime_index(entries, "viper") >= 0, "character debug menu should include Viper")
	_expect(_find_runtime_index(entries, "blacksmith") >= 0, "character debug menu should include Kohaku / Baltor")

	picker.selected_index = _find_runtime_index(entries, "viper")
	var enter_event := InputEventKey.new()
	enter_event.pressed = true
	enter_event.keycode = KEY_ENTER
	enter_event.physical_keycode = KEY_ENTER
	_expect(bool(picker.handle_input(enter_event, owner, registry, Vector2(1280.0, 720.0))), "Enter should apply the highlighted character")
	_expect(not bool(picker.is_open()), "character debug menu should close after applying a character")
	_expect(str(owner.data.get("selected_character_type", "")) == "viper", "applying Viper should update the live runtime character type")
	_expect(str(owner.data.get("selected_runtime_character_id", "")) == "viper", "applying Viper should update the live runtime character id")
	_expect(str(owner.data.get("selected_character_id", "")) == "viper", "applying Viper should update the live character id")
	_expect(str(owner.data.get("selected_character_name", "")) == "\ubc14\uc774\ud37c", "applying Viper should update the live Korean character name")
	_expect(float(owner.data.get("player_speed", -1.0)) == 0.0, "character switch should clear carry-over player speed")

	var selection: Dictionary = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "viper", "character debug selection should persist to GameSelectionState")
	_expect(str(selection.get("character_name", "")) == "\ubc14\uc774\ud37c", "persisted character debug selection should keep the Korean display name")

	state.set_character({"id": "optimus", "runtime_id": "optimus", "name": "\uc774\uc624"})
	selection = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "optimus", "GameSelectionState should preserve the Optimus / Io runtime id")
	state.set_character({"id": "io", "runtime_id": "io", "name": "\uc774\uc624"})
	selection = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "optimus", "GameSelectionState should normalize Io alias to Optimus runtime id")
	state.set_character({"id": "baltor", "runtime_id": "baltor", "name": "\ucf54\ud558\ucfe0"})
	selection = state.get_selection()
	_expect(str(selection.get("runtime_character_id", "")) == "blacksmith", "GameSelectionState should normalize Baltor alias to Blacksmith runtime id")

	picker.toggle(owner)
	_expect(int(picker.selected_index) == _find_runtime_index(picker._get_entries(), "viper"), "reopening the picker should highlight the current runtime character")

	owner.queue_free()
	if _failures.is_empty():
		print("character_debug_picker_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _find_runtime_index(entries: Array, runtime_id: String) -> int:
	for index in range(entries.size()):
		var value: Variant = entries[index]
		if value is Dictionary and str((value as Dictionary).get("_runtime_character_id", "")) == runtime_id:
			return index
	return -1


@warning_ignore("shadowed_variable_base_class")
func _get_or_create_selection_state(root: Node) -> Node:
	var state: Node = root.get_node_or_null("GameSelectionState")
	if state != null:
		return state
	state = GameSelectionState.new()
	state.name = "GameSelectionState"
	root.add_child(state)
	return state


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
