extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()


func apply_selection_state(owner: Object) -> void:
	if owner == null or not owner.has_method("get_node_or_null"):
		return
	var selection_state: Object = owner.get_node_or_null("/root/GameSelectionState")
	if selection_state == null or not selection_state.has_method("get_selection"):
		return
	var selection: Dictionary = selection_state.get_selection()
	var runtime_character_id: String = normalize_runtime_character_id(
		selection.get("runtime_character_id", selection.get("character_id", "smasher"))
	)
	owner.set("current_stage", max(1, int(selection.get("stage_id", 1))))
	owner.set("selected_character_id", str(selection.get("character_id", "ufo_player")))
	owner.set("selected_runtime_character_id", runtime_character_id)
	owner.set("selected_character_type", runtime_character_id)
	owner.set("selected_character_name", str(selection.get("character_name", "\uc2a4\ub9e4\uc154")))
	owner.set("ai_mode", normalize_league_mode(str(selection.get("league_mode", "champion"))))


func normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "mythic" or normalized == "mythicleague":
		return "mythic"
	return "champion"


func normalize_runtime_character_id(value: Variant) -> String:
	if character_runtime != null and character_runtime.has_method("normalize"):
		return str(character_runtime.normalize(value))
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	return "smasher"
