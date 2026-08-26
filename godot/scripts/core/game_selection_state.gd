extends Node

signal selection_changed(selection: Dictionary)

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

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
var stage_boss_variant: String = ""
var skip_battle_logo_once: bool = false
var _character_prologue_entry_requested: bool = false
var _tower_start_card_entry_requested: bool = false
var tower_map_seed: int = 0
var tower_map_seed_available := false
var _pending_online_match_request: Dictionary = {}
var _online_match_skip_logo_armed := false


func _ready() -> void:
	if not is_direct_online_battle_launch(OS.get_cmdline_args()):
		return
	var command_line_request := parse_online_command_line(OS.get_cmdline_user_args())
	if command_line_request.is_empty():
		return
	set_character({
		"id": DEFAULT_CHARACTER_ID,
		"runtime_id": DEFAULT_RUNTIME_CHARACTER_ID,
		"name": "한미량",
	})
	set_league_mode("champion")
	set_stage(1)
	request_online_match(command_line_request)


static func is_direct_online_battle_launch(arguments: PackedStringArray) -> bool:
	for argument in arguments:
		var value := str(argument).replace("\\", "/").strip_edges().to_lower()
		if value == "res://scenes/main.tscn" or value.ends_with("/scenes/main.tscn"):
			return true
	return false


static func parse_online_command_line(arguments: PackedStringArray) -> Dictionary:
	var role := ""
	var address := "127.0.0.1"
	var port := 24777
	var snapshot_hz := 30
	for argument in arguments:
		var value := str(argument)
		if value == "--online-host":
			role = "host"
		elif value.begins_with("--online-join="):
			role = "client"
			address = value.trim_prefix("--online-join=").strip_edges()
		elif value.begins_with("--online-port="):
			port = clampi(int(value.trim_prefix("--online-port=")), 1, 65535)
		elif value.begins_with("--online-snapshot-hz="):
			snapshot_hz = clampi(int(value.trim_prefix("--online-snapshot-hz=")), 1, 60)
	if role == "":
		return {}
	return {
		"role": role,
		"address": address,
		"bind_ip": "*",
		"port": port,
		"snapshot_hz": snapshot_hz,
	}


func set_character(data: Dictionary) -> void:
	character_id = str(data.get("id", character_id))
	runtime_character_id = _character_runtime.normalize(data.get("runtime_id", data.get("id", runtime_character_id)))
	character_name = str(data.get("name", character_name))
	selection_changed.emit(get_selection())


func set_stage(
	stage: int,
	stage1_variant: String = STAGE1_BOSS_VARIANT_DALJI,
	explicit_stage1_variant: bool = false,
	requested_stage_boss_variant: String = ""
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
	stage_boss_variant = StageBossVariantCatalog.normalize_variant(stage_id, requested_stage_boss_variant)
	selection_changed.emit(get_selection())


func set_stage1_boss_variant(variant: String) -> void:
	stage1_boss_variant = _normalize_stage1_boss_variant(variant) if stage_id == 1 else STAGE1_BOSS_VARIANT_DALJI
	stage1_boss_variant_explicit = stage_id == 1
	selection_changed.emit(get_selection())


func set_stage_boss_variant(variant: String) -> void:
	stage_boss_variant = StageBossVariantCatalog.normalize_variant(stage_id, variant)
	selection_changed.emit(get_selection())


func set_league_mode(mode: String) -> void:
	league_mode = BattleSceneConfig.normalize_league_mode(mode)
	selection_changed.emit(get_selection())


func request_skip_battle_logo_once() -> void:
	skip_battle_logo_once = true


func request_character_prologue_entry() -> void:
	_character_prologue_entry_requested = true


func peek_character_prologue_entry_request() -> bool:
	return _character_prologue_entry_requested


func consume_character_prologue_entry_request() -> bool:
	var requested := _character_prologue_entry_requested
	_character_prologue_entry_requested = false
	return requested


func request_tower_start_card_entry() -> void:
	_tower_start_card_entry_requested = true
	if TowerAscentFeatureFlags.is_vertical_slice_enabled():
		var previous_seed := tower_map_seed
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var next_seed := rng.randi_range(1, 0x7FFFFFFF)
		if next_seed == previous_seed:
			next_seed = 1 if previous_seed >= 0x7FFFFFFF else previous_seed + 1
		tower_map_seed = next_seed
		tower_map_seed_available = true
	else:
		tower_map_seed = 0
		tower_map_seed_available = false


func debug_set_tower_map_seed(value: int, available: bool = true) -> void:
	tower_map_seed = value
	tower_map_seed_available = available


func peek_tower_start_card_entry_request() -> bool:
	return _tower_start_card_entry_requested


func consume_tower_start_card_entry_request() -> bool:
	var requested := _tower_start_card_entry_requested
	_tower_start_card_entry_requested = false
	return requested


func consume_skip_battle_logo_once() -> bool:
	var should_skip := skip_battle_logo_once
	skip_battle_logo_once = false
	_online_match_skip_logo_armed = false
	return should_skip


func request_online_match(config: Dictionary) -> void:
	# Online MVP has no shared Tower run-seed handshake. Keep its Stage 1 boss
	# routing on the legacy selection path until both peers can receive one
	# authoritative seed; independently generated seeds would desync the match.
	tower_map_seed = 0
	tower_map_seed_available = false
	var role := "host" if str(config.get("role", "host")) == "host" else "client"
	_pending_online_match_request = {
		"role": role,
		"address": str(config.get("address", "127.0.0.1")).strip_edges(),
		"bind_ip": str(config.get("bind_ip", "*")).strip_edges(),
		"port": clampi(int(config.get("port", 24777)), 1, 65535),
		"snapshot_hz": clampi(int(config.get("snapshot_hz", 30)), 1, 60),
	}
	request_skip_battle_logo_once()
	_online_match_skip_logo_armed = true
	selection_changed.emit(get_selection())


func has_pending_online_match_request() -> bool:
	return not _pending_online_match_request.is_empty()


func consume_online_match_request() -> Dictionary:
	var request := _pending_online_match_request.duplicate(true)
	_pending_online_match_request.clear()
	return request


func cancel_online_match_request() -> void:
	_pending_online_match_request.clear()
	if _online_match_skip_logo_armed:
		skip_battle_logo_once = false
		_online_match_skip_logo_armed = false


func get_selection() -> Dictionary:
	return {
		"character_id": character_id,
		"runtime_character_id": runtime_character_id,
		"character_name": character_name,
		"league_mode": league_mode,
		"stage_id": stage_id,
		"stage1_boss_variant": stage1_boss_variant,
		"stage1_boss_variant_explicit": stage1_boss_variant_explicit,
		"stage_boss_variant": stage_boss_variant,
		"tower_map_seed": tower_map_seed,
		"tower_map_seed_available": tower_map_seed_available,
		"online_match_pending": not _pending_online_match_request.is_empty(),
	}


func _normalize_stage1_boss_variant(variant: String) -> String:
	return StageBossVariantCatalog.normalize_variant(1, variant)
