extends SceneTree

const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameplayActorModuleCatalog := preload("res://scripts/resources/gameplay_actor_module_catalog.gd")
const GameplayHudModuleCatalog := preload("res://scripts/resources/gameplay_hud_module_catalog.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var _failures: Array[String] = []


class FakeSelectionState:
	extends RefCounted

	var selection: Dictionary = {}

	func get_selection() -> Dictionary:
		return selection


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}
	var selection_state := FakeSelectionState.new()

	func get_node_or_null(path: NodePath) -> Object:
		if str(path) == "/root/GameSelectionState":
			return selection_state
		return null

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


func _init() -> void:
	_verify_character_runtime_routes()
	_verify_module_catalogs()
	_verify_selection_state_and_startup()

	if _failures.is_empty():
		print("commando_runtime_routing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_runtime_routes() -> void:
	var runtime := PlayerCharacterRuntime.new()
	_expect(runtime.normalize("soldier") == "soldier", "soldier should normalize to Commando runtime")
	_expect(runtime.normalize("commando") == "soldier", "commando alias should normalize to soldier")
	_expect(runtime.is_commando("soldier"), "soldier should be recognized as Commando")
	_expect(runtime.get_player_controller_key("soldier") == "commando_player_controller", "Commando should use its player controller")
	_expect(runtime.get_input_reader_key("soldier") == "commando_input_reader", "Commando should use wheel-aware input reader")
	_expect(runtime.get_skill_config_key("soldier") == "commando_skill_config", "Commando should use its skill config")
	_expect(runtime.get_skill_state_key("soldier") == "commando_skill_state", "Commando should use its skill state")
	_expect(runtime.get_combo_state_key("soldier") == "", "Commando should not inherit Smasher combo HUD")
	_expect(runtime.get_skill_icon_texture_key("soldier") == "commando_skill_icon_textures", "Commando should use Commando orb icons")


func _verify_module_catalogs() -> void:
	var actor_catalog := GameplayActorModuleCatalog.new()
	for key in [
		"commando_skill_config",
		"commando_skill_state",
		"commando_weapon_controller",
		"commando_emergency_supply_state",
		"commando_reload_delivery_state",
		"commando_firearm_runtime",
		"commando_supply_drop_state",
		"commando_input_reader",
		"commando_player_controller",
	]:
		_expect(not actor_catalog.get_spec(key).is_empty(), "actor catalog should register %s" % key)

	var hud_catalog := GameplayHudModuleCatalog.new()
	_expect(not hud_catalog.get_spec("commando_firearm_selector_renderer").is_empty(), "HUD catalog should register the fixed firearm selector")


func _verify_selection_state_and_startup() -> void:
	var selection_state := GameSelectionState.new()
	selection_state.set_character({"id": "commando", "name": "코만도"})
	_expect(str(selection_state.get_selection().get("runtime_character_id", "")) == "soldier", "commando alias should persist soldier runtime id")
	selection_state.set_character({"id": "soldier", "runtime_id": "soldier", "name": "코만도"})
	_expect(str(selection_state.get_selection().get("runtime_character_id", "")) == "soldier", "soldier card should persist soldier runtime id")
	selection_state.free()

	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": 2,
		"character_id": "soldier",
		"runtime_character_id": "soldier",
		"character_name": "코만도",
		"league_mode": "champion",
	}
	var startup := BattleSceneSelectionStartupLifecycle.new()
	startup.apply_selection_state(owner)
	_expect(int(owner.data.get("current_stage", 0)) == 2, "startup should apply selected stage")
	_expect(str(owner.data.get("selected_character_type", "")) == "soldier", "startup should keep Commando runtime type")
	_expect(str(owner.data.get("selected_runtime_character_id", "")) == "soldier", "startup should keep Commando runtime id")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
