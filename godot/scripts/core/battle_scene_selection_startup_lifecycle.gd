extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const DEFAULT_LEAGUE_MODE := "junior"

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
	var entry_stage: int = max(1, int(selection.get("stage_id", 1)))
	owner.set("current_stage", entry_stage)
	owner.set("selected_character_id", str(selection.get("character_id", "ufo_player")))
	owner.set("selected_runtime_character_id", runtime_character_id)
	owner.set("selected_character_type", runtime_character_id)
	owner.set("selected_character_name", str(selection.get("character_name", "\uc2a4\ub9e4\uc154")))
	owner.set("ai_mode", normalize_league_mode(str(selection.get("league_mode", DEFAULT_LEAGUE_MODE))))
	reset_plaza_progress_if_new_game(entry_stage, _default_plaza_save_path(owner))


func reset_plaza_progress_if_new_game(entry_stage: int, save_path: String) -> void:
	# Parity with original PingFighter: a brand-new playthrough always enters at
	# stage 1 from character select. Stage transitions reuse this scene (they
	# never re-run apply_selection_state, and keep GameSelectionState.stage_id
	# synced to the live stage), so a stage > 1 here is never a fresh start and
	# must not wipe accumulated gold. An empty save_path => no-op, so the real
	# plaza save is only touched for live scenes (RefCounted unit-test owners
	# resolve to "" via _default_plaza_save_path and are skipped).
	if entry_stage != 1 or save_path.strip_edges() == "":
		return
	var store: Object = PlazaSaveStore.new()
	store.set_save_path(save_path)
	store.reset_gold_and_ap_for_new_playthrough()


func _default_plaza_save_path(owner: Object) -> String:
	# Live battle scene (a Node) resolves to the canonical plaza save; RefCounted
	# unit-test owners get "" so apply_selection_state never writes the real save
	# during the selection-startup unit tests.
	if owner is Node:
		return PlazaSaveStore.SAVE_PATH
	return ""


func normalize_league_mode(mode: String) -> String:
	var normalized: String = mode.strip_edges().to_lower().replace(" ", "").replace("_", "").replace("-", "")
	if normalized == "junior" or normalized == "juniorleague":
		return "junior"
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
