extends RefCounted

## Owns Commando cue metadata, optional-player setup order, selective prewarm
## and SFX-bus projections, primary player cache, and AK-47 layer cache.
## Playback/fallback policy, pool cursor, and loop mutation remain with
## GameAudio.

const AK47_FIRE_POOL_SIZE := 4
const CUE_IDS := [
	"supply_radio",
	"supply_radio_loop",
	"supply_aircraft",
	"weapon_change",
	"fire_support_radio",
	"fire_support_aircraft",
	"slingshot_fire",
	"pistol_ready",
	"pistol_fire",
	"pistol_reload_start",
	"pistol_reload",
	"reload",
	"ak47_fire",
	"bazooka_fire",
	"net_capture",
	"net_constrict",
	"bowling_trap_install",
	"bowling_trap_snap",
	"suicide_drone",
]
const PREWARM_CUE_IDS := [
	"supply_radio",
	"supply_aircraft",
	"weapon_change",
	"slingshot_fire",
	"pistol_ready",
	"pistol_fire",
	"pistol_reload_start",
	"pistol_reload",
	"reload",
	"ak47_fire",
	"bazooka_fire",
	"net_capture",
	"bowling_trap_install",
	"bowling_trap_snap",
	"suicide_drone",
]
const SFX_BUS_CUE_IDS := [
	"supply_radio",
	"supply_radio_loop",
	"supply_aircraft",
	"fire_support_radio",
	"fire_support_aircraft",
	"slingshot_fire",
	"pistol_ready",
	"pistol_fire",
	"pistol_reload_start",
	"pistol_reload",
	"reload",
	"ak47_fire",
	"bazooka_fire",
	"net_capture",
	"net_constrict",
	"bowling_trap_install",
	"bowling_trap_snap",
	"suicide_drone",
]
const CUE_SPECS := {
	"supply_radio": {
		"player_name": "CommandoSupplyRadioSfx",
		"path": "res://assets/sounds/radio.wav",
		"gain_db": -6.0,
	},
	"supply_radio_loop": {
		"player_name": "CommandoSupplyRadioLoopSfx",
		"path": "res://assets/sounds/radio.wav",
		"gain_db": -7.0,
	},
	"supply_aircraft": {
		"player_name": "CommandoSupplyAircraftSfx",
		"path": "res://assets/sounds/airplane.wav",
		"gain_db": -3.0980,
	},
	"weapon_change": {
		"player_name": "CommandoWeaponChangeSfx",
		"path": "res://assets/sounds/weapon.wav",
		"gain_db": -5.0,
	},
	"fire_support_radio": {
		"player_name": "CommandoFireSupportRadioSfx",
		"path": "res://assets/sounds/radio.wav",
		"gain_db": -5.5,
	},
	"fire_support_aircraft": {
		"player_name": "CommandoFireSupportAircraftSfx",
		"path": "res://assets/sounds/airplane.wav",
		"gain_db": -7.5,
	},
	"slingshot_fire": {
		"player_name": "CommandoSlingshotFireSfx",
		"path": "res://assets/sounds/shurikenthrow.wav",
		"gain_db": -4.4370,
	},
	"pistol_ready": {
		"player_name": "CommandoPistolReadySfx",
		"path": "res://assets/sounds/gunroad.wav",
		"gain_db": -3.0980,
	},
	"pistol_fire": {
		"player_name": "CommandoPistolFireSfx",
		"path": "res://assets/sounds/gunshot.wav",
		"gain_db": -6.0206,
	},
	"pistol_reload_start": {
		"player_name": "CommandoPistolReloadStartSfx",
		"path": "res://assets/sounds/pistolreloadstart.wav",
		"gain_db": -6.0206,
	},
	"pistol_reload": {
		"player_name": "CommandoPistolReloadSfx",
		"path": "res://assets/sounds/pistolreload.wav",
		"gain_db": -6.0206,
	},
	"reload": {
		"player_name": "CommandoReloadSfx",
		"path": "res://assets/sounds/reload.wav",
		"gain_db": -6.0206,
	},
	"ak47_fire": {
		"player_name": "CommandoAk47FireSfx",
		"path": "res://assets/sounds/ak47.wav",
		"gain_db": -6.0206,
	},
	"bazooka_fire": {
		"player_name": "CommandoBazookaFireSfx",
		"path": "res://assets/sounds/bazukagoing.wav",
		"gain_db": -4.4370,
	},
	"net_capture": {
		"player_name": "CommandoNetCaptureSfx",
		"path": "res://assets/sounds/net.wav",
		"gain_db": -6.0206,
	},
	"net_constrict": {
		"player_name": "CommandoNetConstrictSfx",
		"path": "res://assets/sounds/netcome.wav",
		"gain_db": -1.9382,
	},
	"bowling_trap_install": {
		"player_name": "CommandoBowlingTrapInstallSfx",
		"path": "res://assets/sounds/ballingtrapsetup.wav",
		"gain_db": -3.0980,
	},
	"bowling_trap_snap": {
		"player_name": "CommandoBowlingTrapSnapSfx",
		"path": "res://assets/sounds/ballingtrapgrap.wav",
		"gain_db": -3.0980,
	},
	"suicide_drone": {
		"player_name": "CommandoSuicideDroneSfx",
		"path": "res://assets/sounds/drone.wav",
		"gain_db": 0.0,
	},
}

var _players: Dictionary = {}
var _ak47_fire_layers: Array = []


func setup(optional_player_factory: Callable) -> void:
	_players.clear()
	_ak47_fire_layers.clear()
	if not optional_player_factory.is_valid():
		return
	for cue_id: String in CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = optional_player_factory.call(
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)
		if cue_id == "ak47_fire":
			for layer_index in range(2, AK47_FIRE_POOL_SIZE + 1):
				_ak47_fire_layers.append(optional_player_factory.call(
					"CommandoAk47FireSfxLayer%d" % layer_index,
					str(spec.get("path", "")),
					float(spec.get("gain_db", 0.0))
				))


func get_cue_ids() -> Array[String]:
	return _copy_ids(CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_sfx_bus_cue_ids() -> Array[String]:
	return _copy_ids(SFX_BUS_CUE_IDS)


func get_ak47_fire_pool_size() -> int:
	return AK47_FIRE_POOL_SIZE


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if not CUE_SPECS.has(cue_id):
		return
	_players[cue_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(CUE_IDS)


func get_sfx_bus_players() -> Array[AudioStreamPlayer]:
	return _players_for_ids(SFX_BUS_CUE_IDS)


func get_ak47_fire_layers() -> Array:
	return _ak47_fire_layers


func set_ak47_fire_layers(players: Array) -> void:
	_ak47_fire_layers = players


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PREWARM_CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _players_for_ids(cue_ids: Array) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in cue_ids:
		var player: AudioStreamPlayer = get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result
