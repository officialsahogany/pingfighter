extends Node

signal selection_changed(selection: Dictionary)

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const DEFAULT_CHARACTER_ID := "ufo_player"
const DEFAULT_RUNTIME_CHARACTER_ID := "smasher"
const DEFAULT_CHARACTER_NAME := "\uc2a4\ub9e4\uc154"
const DEFAULT_LEAGUE_MODE := "junior"
const STAGE1_BOSS_VARIANT_DALJI := "dalji"
const STAGE1_BOSS_VARIANT_GAKSI := "gaksi"
const STAGE1_BOSS_VARIANT_PODO := "podo"

var _character_runtime: Object = PlayerCharacterRuntime.new()
var character_id: String = DEFAULT_CHARACTER_ID
var runtime_character_id: String = DEFAULT_RUNTIME_CHARACTER_ID
var character_name: String = DEFAULT_CHARACTER_NAME
var league_mode: String = DEFAULT_LEAGUE_MODE
var stage_id: int = 1
var stage1_boss_variant: String = STAGE1_BOSS_VARIANT_DALJI
var stage1_boss_variant_explicit: bool = false
var skip_battle_logo_once: bool = false


func set_character(data: Dictionary) -> void:
	character_id = str(data.get("id", character_id))
	runtime_character_id = _character_runtime.normalize(data.get("runtime_id", data.get("id", runtime_character_id)))
	character_name = str(data.get("name", character_name))
	selection_changed.emit(get_selection())


func set_stage(
	stage: int,
	stage1_variant: String = STAGE1_BOSS_VARIANT_DALJI,
	explicit_stage1_variant: bool = false
) -> void:
	stage_id = max(1, stage)
	stage1_boss_variant = _normalize_stage1_boss_variant(stage1_variant) if stage_id == 1 else STAGE1_BOSS_VARIANT_DALJI
	stage1_boss_variant_explicit = (
		stage_id == 1
		and (
			explicit_stage1_variant
			or stage1_boss_variant != STAGE1_BOSS_VARIANT_DALJI
		)
	)
	selection_changed.emit(get_selection())


func set_stage1_boss_variant(variant: String) -> void:
	stage1_boss_variant = _normalize_stage1_boss_variant(variant) if stage_id == 1 else STAGE1_BOSS_VARIANT_DALJI
	stage1_boss_variant_explicit = stage_id == 1
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
		"stage1_boss_variant": stage1_boss_variant,
		"stage1_boss_variant_explicit": stage1_boss_variant_explicit,
	}


func _normalize_stage1_boss_variant(variant: String) -> String:
	var normalized := variant.strip_edges().to_lower()
	if normalized == STAGE1_BOSS_VARIANT_GAKSI or normalized == "gaksital" or normalized == "talkwangdae":
		return STAGE1_BOSS_VARIANT_GAKSI
	if normalized == STAGE1_BOSS_VARIANT_PODO or normalized == "pododaejang" or normalized == "podo_daejang":
		return STAGE1_BOSS_VARIANT_PODO
	return STAGE1_BOSS_VARIANT_DALJI
