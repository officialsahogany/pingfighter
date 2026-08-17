extends RefCounted

## Owns Viper and Chaos Spear cue metadata, phase-stable player creation,
## selective prewarm projection, and the shared SFX-bus player order.
## Playback, pitch policy, loop mutation, and cleanup remain with GameAudio.

const CUE_IDS := [
	"jetpack",
	"backstep",
	"shadow_kick",
	"marshal_kick",
	"dive_prep",
	"dive_strike",
	"ignition_aura",
	"ignition_aura_fallback",
	"phantom_show",
	"phantom_kick_hit",
	"blade",
	"blade_spin",
	"venom_moving",
	"venom_attack",
	"hwarang_kick",
	"kick_guard_knockback",
	"dual_glitch_windup",
	"dual_glitch_split",
	"chaos_spear_windup",
	"chaos_spear_flying",
	"chaos_spear_impact",
	"chaos_spear_blackhole",
]
const PREWARM_CUE_IDS := [
	"jetpack",
	"backstep",
	"shadow_kick",
	"dive_prep",
	"dive_strike",
	"ignition_aura",
	"ignition_aura_fallback",
	"phantom_show",
	"phantom_kick_hit",
	"blade",
	"blade_spin",
	"venom_moving",
	"venom_attack",
	"hwarang_kick",
	"kick_guard_knockback",
	"dual_glitch_windup",
	"dual_glitch_split",
	"chaos_spear_windup",
	"chaos_spear_flying",
	"chaos_spear_impact",
	"chaos_spear_blackhole",
]
const CUE_SPECS := {
	"jetpack": {"player_name": "ViperJetpackSfx", "path": "res://assets/sounds/jetpack.wav", "gain_db": -8.5},
	"backstep": {"player_name": "ViperBackstepSfx", "path": "res://assets/sounds/backstep.wav", "gain_db": -6.0},
	"shadow_kick": {"player_name": "ViperShadowKickSfx", "path": "res://assets/sounds/shadowkick.wav", "gain_db": -4.4},
	"marshal_kick": {"player_name": "ViperMarshalKickSfx", "path": "res://assets/sounds/shadowkick.wav", "gain_db": -4.4},
	"dive_prep": {"player_name": "ViperDivePrepSfx", "path": "res://assets/sounds/beforedivestrike.wav", "gain_db": -4.4370},
	"dive_strike": {"player_name": "ViperDiveStrikeSfx", "path": "res://assets/sounds/divestrike.wav", "gain_db": -4.4370},
	"ignition_aura": {"player_name": "ViperIgnitionAuraSfx", "path": "res://assets/sounds/beforedivestrike.wav", "gain_db": -3.0980},
	"ignition_aura_fallback": {"player_name": "ViperIgnitionAuraFallbackSfx", "path": "res://assets/sounds/backstep.wav", "gain_db": -3.0980},
	"phantom_show": {"player_name": "ViperPhantomShowSfx", "path": "res://assets/sounds/bypershow.wav", "gain_db": -1.5},
	"phantom_kick_hit": {"player_name": "ViperPhantomKickHitSfx", "path": "res://assets/sounds/pentomkick.wav", "gain_db": -2.5},
	"blade": {"player_name": "ViperBladeSfx", "path": "res://assets/sounds/blade.wav", "gain_db": -6.0},
	"blade_spin": {"player_name": "ViperBladeSpinSfx", "path": "res://assets/sounds/bladeafter.wav", "gain_db": -3.0},
	"venom_moving": {"player_name": "ViperVenomMovingSfx", "path": "res://assets/sounds/venommoving.wav", "gain_db": -4.4},
	"venom_attack": {"player_name": "ViperVenomAttackSfx", "path": "res://assets/sounds/venomattack.wav", "gain_db": -4.4},
	"hwarang_kick": {"player_name": "ViperHwarangKickSfx", "path": "res://assets/sounds/hwarangkick.wav", "gain_db": -3.2},
	"kick_guard_knockback": {"player_name": "ViperKickGuardKnockbackSfx", "path": "res://assets/sounds/nuckbackball.wav", "gain_db": -4.0},
	"dual_glitch_windup": {"player_name": "ViperDualGlitchWindupSfx", "path": "res://assets/sounds/dualglitch1.wav", "gain_db": -13.5},
	"dual_glitch_split": {"player_name": "ViperDualGlitchSplitSfx", "path": "res://assets/sounds/dualglitch2.wav", "gain_db": 0.0},
	"chaos_spear_windup": {"player_name": "ChaosSpearWindupSfx", "path": "res://assets/sounds/chaosphase1.wav", "gain_db": -4.4},
	"chaos_spear_flying": {"player_name": "ChaosSpearFlyingSfx", "path": "res://assets/sounds/chaosphase2.wav", "gain_db": -4.4},
	"chaos_spear_impact": {"player_name": "ChaosSpearImpactSfx", "path": "res://assets/sounds/chaosphase3.wav", "gain_db": -4.4},
	"chaos_spear_blackhole": {"player_name": "ChaosSpearBlackholeSfx", "path": "res://assets/sounds/gravityaccel.wav", "gain_db": -5.5},
}

var _players: Dictionary = {}


func setup(parent: Node, player_factory: Object) -> void:
	for cue_id: String in CUE_IDS:
		var spec: Dictionary = CUE_SPECS[cue_id]
		_players[cue_id] = player_factory.create(
			parent,
			str(spec.get("player_name", "")),
			str(spec.get("path", "")),
			float(spec.get("gain_db", 0.0))
		)


func get_cue_ids() -> Array[String]:
	return _copy_ids(CUE_IDS)


func get_prewarm_cue_ids() -> Array[String]:
	return _copy_ids(PREWARM_CUE_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = CUE_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func set_player(cue_id: String, player: AudioStreamPlayer) -> void:
	if CUE_SPECS.has(cue_id):
		_players[cue_id] = player


func get_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in CUE_IDS:
		var player := get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func get_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in PREWARM_CUE_IDS:
		result.append(str(CUE_SPECS[cue_id].get("path", "")))
	return result


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in source:
		result.append(cue_id)
	return result
