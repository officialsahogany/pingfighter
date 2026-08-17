extends RefCounted

## Owns throwable/deployable item cue metadata, the exact split eager setup,
## selective prewarm projection, SFX-bus order, and player cache. Playback,
## dynamic Dynamite Fuse lifecycle, loop mutation, and cleanup remain in
## GameAudio.

const GRENADE_SOUND_PATH := "res://assets/sounds/grenade.wav"
const DYNAMITE_FUSE_SOUND_PATH := "res://assets/sounds/bombfuse.wav"
const FLASHBOMB_SOUND_PATH := "res://assets/sounds/flashbomb.wav"
const SMOKEBOMB_SOUND_PATH := "res://assets/sounds/smokebomb.wav"
const FIREBOMB_SOUND_PATH := "res://assets/sounds/firebomb.wav"
const BOOMERANG_SOUND_PATH := "res://assets/sounds/boomerang.wav"
const BOOMERANG_HIT_SOUND_PATH := "res://assets/sounds/boomeranghit.wav"
const BOOMERANG_BREAK_SOUND_PATH := "res://assets/sounds/bonebreak.wav"
const SHRAPNEL_ARMOR_FIRE_SOUND_PATH := "res://assets/sounds/arrow.wav"
const SHRAPNEL_ARMOR_HIT_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const BANANA_THROW_SOUND_PATH := "res://assets/sounds/throwingbanana.wav"
const BANANA_SLIP_SOUND_PATH := "res://assets/sounds/bananastep.wav"
const SOAP_THROW_SOUND_PATH := "res://assets/sounds/oil.wav"
const SOAP_LAND_SOUND_PATH := "res://assets/sounds/shootoil.wav"
const SOAP_SLIP_SOUND_PATH := "res://assets/sounds/bananastep.wav"
const SPIDER_MINE_WALK_SOUND_PATH := "res://assets/sounds/spiderminewalk.wav"
const SPIDER_MINE_SETUP_SOUND_PATH := "res://assets/sounds/spiderminesetup.wav"
const BOMB_SURPRISE_ATTACH_SOUND_PATH := "res://assets/sounds/boomstart.wav"
const BOMB_SURPRISE_TICK1_SOUND_PATH := "res://assets/sounds/ticking1.wav"
const BOMB_SURPRISE_TICK2_SOUND_PATH := "res://assets/sounds/ticking2.wav"
const BOMB_SURPRISE_URGENT_TICK_SOUND_PATH := "res://assets/sounds/ticking3.wav"
const BOMB_SURPRISE_SELF_EXPLOSION_SOUND_PATH := "res://assets/sounds/weakexplosion.wav"
const BOMB_SURPRISE_ATTACH_GAIN_DB := -9.1186
const BOMB_SURPRISE_TRANSFER_GAIN_DB := -10.4576
const BOMB_SURPRISE_URGENT_TICK_GAIN_DB := -6.9357
const BOMB_SURPRISE_EXPLOSION_GAIN_DB := -1.9382

const PRE_LOOP_CUE_IDS := [
	"grenade",
	"flashbomb",
	"smokebomb",
	"firebomb",
	"boomerang",
	"boomerang_hit",
	"boomerang_break",
	"shrapnel_armor_fire",
	"shrapnel_armor_hit",
]
const POST_LOOP_CUE_IDS := [
	"banana_throw",
	"banana_slip",
	"soap_throw",
	"soap_land",
	"soap_slip",
	"spider_mine_walk",
	"spider_mine_setup",
	"bomb_surprise_attach",
	"bomb_surprise_transfer",
	"bomb_surprise_tick1",
	"bomb_surprise_tick2",
	"bomb_surprise_urgent_tick",
	"bomb_surprise_explosion",
	"bomb_surprise_self_explosion",
]
const SETUP_CUE_IDS := PRE_LOOP_CUE_IDS + POST_LOOP_CUE_IDS
const PREWARM_CUE_IDS := [
	"grenade",
	"flashbomb",
	"smokebomb",
	"firebomb",
	"boomerang",
	"boomerang_hit",
	"boomerang_break",
	"shrapnel_armor_fire",
	"shrapnel_armor_hit",
	"banana_throw",
	"banana_slip",
	"soap_throw",
	"soap_land",
	"soap_slip",
	"spider_mine_walk",
	"spider_mine_setup",
]
const CUE_SPECS := {
	"grenade": {"player_name": "GrenadeSfx", "path": GRENADE_SOUND_PATH, "gain_db": -4.0},
	"dynamite_fuse": {"player_name": "DynamiteFuseSfx", "path": DYNAMITE_FUSE_SOUND_PATH, "gain_db": -4.0},
	"flashbomb": {"player_name": "FlashbombSfx", "path": FLASHBOMB_SOUND_PATH, "gain_db": -4.0},
	"smokebomb": {"player_name": "SmokebombSfx", "path": SMOKEBOMB_SOUND_PATH, "gain_db": -5.0},
	"firebomb": {"player_name": "FirebombSfx", "path": FIREBOMB_SOUND_PATH, "gain_db": -4.0},
	"boomerang": {"player_name": "BoomerangSfx", "path": BOOMERANG_SOUND_PATH, "gain_db": -8.0},
	"boomerang_hit": {"player_name": "BoomerangHitSfx", "path": BOOMERANG_HIT_SOUND_PATH, "gain_db": -5.0},
	"boomerang_break": {"player_name": "BoomerangBreakSfx", "path": BOOMERANG_BREAK_SOUND_PATH, "gain_db": -5.0},
	"shrapnel_armor_fire": {"player_name": "ShrapnelArmorFireSfx", "path": SHRAPNEL_ARMOR_FIRE_SOUND_PATH, "gain_db": -5.0},
	"shrapnel_armor_hit": {"player_name": "ShrapnelArmorHitSfx", "path": SHRAPNEL_ARMOR_HIT_SOUND_PATH, "gain_db": -5.0},
	"banana_throw": {"player_name": "BananaThrowSfx", "path": BANANA_THROW_SOUND_PATH, "gain_db": -6.0},
	"banana_slip": {"player_name": "BananaSlipSfx", "path": BANANA_SLIP_SOUND_PATH, "gain_db": -4.0},
	"soap_throw": {"player_name": "SoapThrowSfx", "path": SOAP_THROW_SOUND_PATH, "gain_db": -7.0},
	"soap_land": {"player_name": "SoapLandSfx", "path": SOAP_LAND_SOUND_PATH, "gain_db": -8.0},
	"soap_slip": {"player_name": "SoapSlipSfx", "path": SOAP_SLIP_SOUND_PATH, "gain_db": -4.0},
	"spider_mine_walk": {"player_name": "SpiderMineWalkSfx", "path": SPIDER_MINE_WALK_SOUND_PATH, "gain_db": -6.5},
	"spider_mine_setup": {"player_name": "SpiderMineSetupSfx", "path": SPIDER_MINE_SETUP_SOUND_PATH, "gain_db": -5.0},
	"bomb_surprise_attach": {"player_name": "BombSurpriseAttachSfx", "path": BOMB_SURPRISE_ATTACH_SOUND_PATH, "gain_db": BOMB_SURPRISE_ATTACH_GAIN_DB},
	"bomb_surprise_transfer": {"player_name": "BombSurpriseTransferSfx", "path": SPIDER_MINE_SETUP_SOUND_PATH, "gain_db": BOMB_SURPRISE_TRANSFER_GAIN_DB},
	"bomb_surprise_tick1": {"player_name": "BombSurpriseTick1Sfx", "path": BOMB_SURPRISE_TICK1_SOUND_PATH, "gain_db": -16.4782},
	"bomb_surprise_tick2": {"player_name": "BombSurpriseTick2Sfx", "path": BOMB_SURPRISE_TICK2_SOUND_PATH, "gain_db": -16.4782},
	"bomb_surprise_urgent_tick": {"player_name": "BombSurpriseUrgentTickSfx", "path": BOMB_SURPRISE_URGENT_TICK_SOUND_PATH, "gain_db": BOMB_SURPRISE_URGENT_TICK_GAIN_DB},
	"bomb_surprise_explosion": {"player_name": "BombSurpriseExplosionSfx", "path": GRENADE_SOUND_PATH, "gain_db": BOMB_SURPRISE_EXPLOSION_GAIN_DB},
	"bomb_surprise_self_explosion": {"player_name": "BombSurpriseSelfExplosionSfx", "path": BOMB_SURPRISE_SELF_EXPLOSION_SOUND_PATH, "gain_db": BOMB_SURPRISE_EXPLOSION_GAIN_DB},
}

var _players: Dictionary = {}


func setup_pre_loop_players(parent: Node, player_factory: Object) -> void:
	_setup_players(PRE_LOOP_CUE_IDS, parent, player_factory)


func setup_post_loop_players(parent: Node, player_factory: Object) -> void:
	_setup_players(POST_LOOP_CUE_IDS, parent, player_factory)


func get_pre_loop_cue_ids() -> Array[String]:
	return _copy_ids(PRE_LOOP_CUE_IDS)


func get_post_loop_cue_ids() -> Array[String]:
	return _copy_ids(POST_LOOP_CUE_IDS)


func get_setup_cue_ids() -> Array[String]:
	return _copy_ids(SETUP_CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if SETUP_CUE_IDS.has(cue_id):
		_players[cue_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(SETUP_CUE_IDS)


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PREWARM_CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _setup_players(cue_ids: Array, parent: Node, player_factory: Object) -> void:
	for cue_id: String in cue_ids:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


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
