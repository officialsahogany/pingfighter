extends RefCounted

## Owns item/reward/perk-fusion feedback cue metadata, phase-correct eager
## setup, selective prewarm projections, legacy SFX-bus projections, and the
## two optional Angel Blessing absorb layers. Playback, fallbacks, pool
## rotation, explicit cinematic stopping, and forced Angel cleanup remain in
## GameAudio.

const ITEM_GET_SOUND_PATH := "res://assets/sounds/itemget.wav"
const DRINK_SOUND_PATH := "res://assets/sounds/drink.wav"
const ACTIVE_ITEM_SOUND_PATH := "res://assets/sounds/activeitem.wav"
const TRADE_SOUND_PATH := "res://assets/sounds/trade.wav"
const TRADE_SOUND_GAIN_DB := -4.4370
const BRICK_WALL_DESTROY_SOUND_PATH := "res://assets/sounds/stonebreak2.wav"
const BRICK_WALL_DESTROY_GAIN_DB := -5.0
const ALCHEMY_SOUND_PATH := "res://assets/sounds/alchemy.wav"
const PANDORA_SOUND_PATH := "res://assets/sounds/pandora.wav"
const LUCKY_COIN_SPAWN_SOUND_PATH := "res://assets/sounds/lucky_coin_spawn.wav"
const FOUL_WHISTLE_SOUND_PATH := "res://assets/sounds/foul_whistle.wav"
const MEGINGJORD_SOUND_PATH := "res://assets/sounds/megin.wav"
const LEGENDARY_OPEN_SOUND_PATH := "res://assets/sounds/legendopen.wav"
const ANGEL_BLESSING_ROLL_SOUND_PATH := "res://assets/sounds/angeldice.wav"
const ANGEL_BLESSING_ABSORB_SOUND_PATH := "res://assets/sounds/angeldicewhisp.wav"
const ANGEL_BLESSING_ABSORB_POOL_SIZE := 3
const ANGEL_BLESSING_ROLL_GAIN_DB := 0.0
const ANGEL_BLESSING_ABSORB_GAIN_DB := 0.0
const RESULT_BOX_OPEN_SOUND_PATH := "res://assets/sounds/boxopen.wav"
const DEFEAT_JEWEL_SOUND_PATH := "res://assets/sounds/defeatjewel1.wav"
const DEFEAT_GEM_SHATTER_SOUND_PATH := "res://assets/sounds/defeat_gem_shatter.wav"
# Perk-fusion cold-boot transition cues are one-shots. They intentionally stay
# out of staged prewarm and do not need central loop-stop registration.
const COLD_BOOT_CHNK_LATCH_SOUND_PATH := "res://assets/sounds/cold_boot_chnk_latch.wav"
const COLD_BOOT_POST_RAMP_SOUND_PATH := "res://assets/sounds/cold_boot_post_ramp.wav"
const COLD_BOOT_IGNITION_THUNK_SOUND_PATH := "res://assets/sounds/cold_boot_ignition_thunk.wav"
const COLD_BOOT_AWAKEN_FANFARE_SOUND_PATH := "res://assets/sounds/cold_boot_awaken_fanfare.wav"
const LEGENDARY_AFTER_SOUND_PATH := "res://assets/sounds/legendafter.wav"
const LEGENDARY_ENDING_SOUND_PATH := "res://assets/sounds/legendending.wav"
const TIMEWATCH_SOUND_PATH := "res://assets/sounds/timewatch.wav"
const THROW_BEFORE_SOUND_PATH := "res://assets/sounds/throwbefore.wav"
const THROW_SOUND_PATH := "res://assets/sounds/throw.wav"

const SETUP_CUE_IDS := [
	"item_get",
	"drink",
	"active_item",
	"trade",
	"brick_wall_destroy",
	"alchemy",
	"pandora",
	"lucky_coin_spawn",
	"foul_whistle",
	"megingjord",
	"legendary_open",
	"angel_blessing_roll",
	"angel_blessing_absorb",
	"angel_blessing_absorb_layer2",
	"angel_blessing_absorb_layer3",
	"result_box_open",
	"defeat_jewel",
	"defeat_gem_shatter",
	"cold_boot_chnk_latch",
	"cold_boot_post_ramp",
	"cold_boot_ignition_thunk",
	"cold_boot_awaken_fanfare",
]
const SFX_BUS_CUE_IDS := [
	"item_get",
	"drink",
	"active_item",
	"trade",
	"brick_wall_destroy",
	"alchemy",
	"pandora",
	"lucky_coin_spawn",
	"foul_whistle",
	"megingjord",
	"legendary_open",
	"angel_blessing_roll",
	"angel_blessing_absorb",
	"result_box_open",
	"defeat_jewel",
	"cold_boot_chnk_latch",
	"cold_boot_post_ramp",
	"cold_boot_ignition_thunk",
	"cold_boot_awaken_fanfare",
	"defeat_gem_shatter",
]
const PREWARM_CUE_IDS := [
	"item_get",
	"drink",
	"active_item",
	"trade",
	"brick_wall_destroy",
	"alchemy",
	"pandora",
	"lucky_coin_spawn",
	"foul_whistle",
	"megingjord",
	"legendary_open",
	"angel_blessing_roll",
	"angel_blessing_absorb",
	"result_box_open",
	"defeat_jewel",
	"defeat_gem_shatter",
]
const ABSORB_LAYER_CUE_IDS := [
	"angel_blessing_absorb_layer2",
	"angel_blessing_absorb_layer3",
]
const CINEMATIC_CUE_IDS := [
	"legendary_after",
	"legendary_ending",
]
const ITEM_ACTION_CUE_IDS := [
	"timewatch",
	"throw_before",
	"throw",
]
const CUE_SPECS := {
	"item_get": {"player_name": "ItemGetSfx", "path": ITEM_GET_SOUND_PATH, "gain_db": -5.0},
	"drink": {"player_name": "DrinkSfx", "path": DRINK_SOUND_PATH, "gain_db": -5.0},
	"active_item": {"player_name": "ActiveItemSfx", "path": ACTIVE_ITEM_SOUND_PATH, "gain_db": -5.0},
	"trade": {"player_name": "TradeSfx", "path": TRADE_SOUND_PATH, "gain_db": TRADE_SOUND_GAIN_DB},
	"brick_wall_destroy": {"player_name": "BrickWallDestroySfx", "path": BRICK_WALL_DESTROY_SOUND_PATH, "gain_db": BRICK_WALL_DESTROY_GAIN_DB},
	"alchemy": {"player_name": "AlchemySfx", "path": ALCHEMY_SOUND_PATH, "gain_db": -4.5},
	"pandora": {"player_name": "PandoraSfx", "path": PANDORA_SOUND_PATH, "gain_db": -5.0},
	"lucky_coin_spawn": {"player_name": "LuckyCoinSpawnSfx", "path": LUCKY_COIN_SPAWN_SOUND_PATH, "gain_db": -5.0},
	"foul_whistle": {"player_name": "FoulWhistleSfx", "path": FOUL_WHISTLE_SOUND_PATH, "gain_db": -4.0},
	"megingjord": {"player_name": "MegingjordSfx", "path": MEGINGJORD_SOUND_PATH, "gain_db": -5.0},
	"legendary_open": {"player_name": "LegendaryOpenSfx", "path": LEGENDARY_OPEN_SOUND_PATH, "gain_db": -5.0},
	"angel_blessing_roll": {"player_name": "AngelBlessingRollSfx", "path": ANGEL_BLESSING_ROLL_SOUND_PATH, "gain_db": ANGEL_BLESSING_ROLL_GAIN_DB},
	"angel_blessing_absorb": {"player_name": "AngelBlessingAbsorbSfx", "path": ANGEL_BLESSING_ABSORB_SOUND_PATH, "gain_db": ANGEL_BLESSING_ABSORB_GAIN_DB},
	"angel_blessing_absorb_layer2": {"player_name": "AngelBlessingAbsorbSfxLayer2", "path": ANGEL_BLESSING_ABSORB_SOUND_PATH, "gain_db": ANGEL_BLESSING_ABSORB_GAIN_DB},
	"angel_blessing_absorb_layer3": {"player_name": "AngelBlessingAbsorbSfxLayer3", "path": ANGEL_BLESSING_ABSORB_SOUND_PATH, "gain_db": ANGEL_BLESSING_ABSORB_GAIN_DB},
	"result_box_open": {"player_name": "ResultBoxOpenSfx", "path": RESULT_BOX_OPEN_SOUND_PATH, "gain_db": -4.0},
	"defeat_jewel": {"player_name": "DefeatJewelSfx", "path": DEFEAT_JEWEL_SOUND_PATH, "gain_db": -4.0},
	"defeat_gem_shatter": {"player_name": "DefeatGemShatterSfx", "path": DEFEAT_GEM_SHATTER_SOUND_PATH, "gain_db": -3.0},
	"cold_boot_chnk_latch": {"player_name": "ColdBootChnkLatchSfx", "path": COLD_BOOT_CHNK_LATCH_SOUND_PATH, "gain_db": -5.0},
	"cold_boot_post_ramp": {"player_name": "ColdBootPostRampSfx", "path": COLD_BOOT_POST_RAMP_SOUND_PATH, "gain_db": -8.0},
	"cold_boot_ignition_thunk": {"player_name": "ColdBootIgnitionThunkSfx", "path": COLD_BOOT_IGNITION_THUNK_SOUND_PATH, "gain_db": -4.0},
	"cold_boot_awaken_fanfare": {"player_name": "ColdBootAwakenFanfareSfx", "path": COLD_BOOT_AWAKEN_FANFARE_SOUND_PATH, "gain_db": -6.0},
	"legendary_after": {"player_name": "LegendaryAfterSfx", "path": LEGENDARY_AFTER_SOUND_PATH, "gain_db": -6.0},
	"legendary_ending": {"player_name": "LegendaryEndingSfx", "path": LEGENDARY_ENDING_SOUND_PATH, "gain_db": -5.0},
	"timewatch": {"player_name": "TimewatchSfx", "path": TIMEWATCH_SOUND_PATH, "gain_db": -5.0},
	"throw_before": {"player_name": "ThrowBeforeSfx", "path": THROW_BEFORE_SOUND_PATH, "gain_db": -5.0},
	"throw": {"player_name": "ThrowSfx", "path": THROW_SOUND_PATH, "gain_db": -5.0},
}

var _players: Dictionary = {}


func setup(parent: Node, player_factory: Object, optional_player_factory: Callable) -> void:
	for cue_id: String in SETUP_CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		var player: AudioStreamPlayer
		if ABSORB_LAYER_CUE_IDS.has(cue_id):
			var optional_value: Variant = optional_player_factory.call(
				str(spec.get("player_name", "")),
				str(spec.get("path", "")),
				float(spec.get("gain_db", 0.0))
			)
			player = optional_value as AudioStreamPlayer if optional_value is AudioStreamPlayer else null
		else:
			player = player_factory.create(
				parent,
				str(spec.get("player_name", "")),
				str(spec.get("path", "")),
				float(spec.get("gain_db", 0.0))
			)
		_players[cue_id] = player


func setup_cinematic(parent: Node, player_factory: Object) -> void:
	_setup_required_players(CINEMATIC_CUE_IDS, parent, player_factory)


func setup_item_actions(parent: Node, player_factory: Object) -> void:
	_setup_required_players(ITEM_ACTION_CUE_IDS, parent, player_factory)


func get_setup_cue_ids() -> Array[String]:
	return _copy_ids(SETUP_CUE_IDS)


func get_sfx_bus_cue_ids() -> Array[String]:
	return _copy_ids(SFX_BUS_CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_absorb_layer_cue_ids() -> Array[String]:
	return _copy_ids(ABSORB_LAYER_CUE_IDS)


func get_cinematic_cue_ids() -> Array[String]:
	return _copy_ids(CINEMATIC_CUE_IDS)


func get_item_action_cue_ids() -> Array[String]:
	return _copy_ids(ITEM_ACTION_CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if CUE_SPECS.has(cue_id):
		_players[cue_id] = player


func get_sfx_bus_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(SFX_BUS_CUE_IDS)


func get_absorb_layers() -> Array:
	return _players_for_ids(ABSORB_LAYER_CUE_IDS)


func get_cinematic_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(CINEMATIC_CUE_IDS)


func get_item_action_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(ITEM_ACTION_CUE_IDS)


func set_absorb_layers(players: Array) -> void:
	for index: int in range(ABSORB_LAYER_CUE_IDS.size()):
		var player: AudioStreamPlayer = null
		if index < players.size() and players[index] is AudioStreamPlayer:
			player = players[index] as AudioStreamPlayer
		_players[ABSORB_LAYER_CUE_IDS[index]] = player


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PREWARM_CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func get_cinematic_prewarm_stream_paths() -> Array[String]:
	return _paths_for_ids(CINEMATIC_CUE_IDS)


func get_item_action_prewarm_stream_paths() -> Array[String]:
	return _paths_for_ids(ITEM_ACTION_CUE_IDS)


func _setup_required_players(cue_ids: Array, parent: Node, player_factory: Object) -> void:
	for cue_id: String in cue_ids:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func _paths_for_ids(cue_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in cue_ids:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _players_for_ids(cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in cue_ids:
		var player := get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result
