extends Node

signal selection_changed(selection: Dictionary)

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const DEFAULT_CHARACTER_ID := "ufo_player"
const DEFAULT_RUNTIME_CHARACTER_ID := "smasher"
const DEFAULT_CHARACTER_NAME := "\uc2a4\ub9e4\uc154"
const DEFAULT_LEAGUE_MODE := "junior"

var _character_runtime: Object = PlayerCharacterRuntime.new()
var character_id: String = DEFAULT_CHARACTER_ID
var runtime_character_id: String = DEFAULT_RUNTIME_CHARACTER_ID
var character_name: String = DEFAULT_CHARACTER_NAME
var league_mode: String = DEFAULT_LEAGUE_MODE
var stage_id: int = 1
var skip_battle_logo_once: bool = false


func set_character(data: Dictionary) -> void:
	character_id = str(data.get("id", character_id))
	runtime_character_id = _character_runtime.normalize(data.get("runtime_id", data.get("id", runtime_character_id)))
	character_name = str(data.get("name", character_name))
	selection_changed.emit(get_selection())


func set_stage(stage: int) -> void:
	stage_id = max(1, stage)
	selection_changed.emit(get_selection())


func set_league_mode(mode: String) -> void:
	league_mode = BattleSceneConfig.normalize_league_mode(mode)
	selection_changed.emit(get_selection())


func request_skip_battle_logo_once() -> void:
	skip_battle_logo_once = true


func consume_skip_battle_logo_once() -> bool:
	var should_skip := skip_battle_logo_once
	skip_battle_logo_once = false
	return should_skip


func get_selection() -> Dictionary:
	return {
		"character_id": character_id,
		"runtime_character_id": runtime_character_id,
		"character_name": character_name,
		"league_mode": league_mode,
		"stage_id": stage_id,
	}
