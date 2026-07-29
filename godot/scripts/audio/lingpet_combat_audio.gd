extends RefCounted

## Owns the Guardian Spirit combat-cue catalog, phase-stable player creation,
## prewarm projection, player cache, and egg-hit candidate streams.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const ITEM_PLAYER_IDS := [
	"puppet_grab_cast",
	"puppet_grab_pull",
	"puppet_grab_kiss",
	"puppet_grab_miss",
	"sand_prison",
	"wild_roar",
	"star_coil_bind",
	"star_coil_move",
	"ring_dash",
	"egg_hit",
]
const PROJECTILE_PLAYER_IDS := [
	"gatling_transform",
	"gatling_loop",
	"gatling_fire",
	"gatling_hit",
	"dwarf_magic_cast",
	"dwarf_magic_hit",
	"gravity_accel_cast",
]
const STAGE_PLAYER_IDS := [
	"ghost_summon",
	"ghost_summon_out",
	"skeleton_archer_summon",
	"skeleton_archer_death",
	"skeleton_archer_arrow_fire",
	"skeleton_archer_arrow_hit",
	"bone_barrier_build",
	"bone_barrier_break",
	"bone_barrier_build_break",
]
# Preserve the existing staged-prewarm contract: the Star Coil movement loop
# and all projectile-phase cues stay lazy even though their players are eager.
const ITEM_PREWARM_IDS := [
	"puppet_grab_cast",
	"puppet_grab_pull",
	"puppet_grab_kiss",
	"puppet_grab_miss",
	"sand_prison",
	"wild_roar",
	"star_coil_bind",
	"ring_dash",
]
const EGG_HIT_STREAM_PATHS := [
	"res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_1.wav",
	"res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_2.wav",
]
const PLAYER_SPECS := {
	"puppet_grab_cast": {
		"player_name": "LingpetPuppetGrabCastSfx",
		"path": "res://assets/sounds/lingpet/puppet_grab_tentacle.wav",
		"gain_db": -5.0,
	},
	"puppet_grab_pull": {
		"player_name": "LingpetPuppetGrabPullSfx",
		"path": "res://assets/sounds/lingpet/puppet_grab.wav",
		"gain_db": -5.0,
	},
	"puppet_grab_kiss": {
		"player_name": "LingpetPuppetGrabKissSfx",
		"path": "res://assets/sounds/lingpet/puppet_grab_kissing.wav",
		"gain_db": -5.0,
	},
	"puppet_grab_miss": {
		"player_name": "LingpetPuppetGrabMissSfx",
		"path": "res://assets/sounds/lingpet/puppet_grab_tentacle.wav",
		"gain_db": -5.0,
	},
	"sand_prison": {
		"player_name": "LingpetSandPrisonOpenSfx",
		"path": "res://assets/sounds/lingpet/rahoset_sand_prison_open.wav",
		"gain_db": -6.0,
	},
	"wild_roar": {
		"player_name": "LingpetWildRoarSfx",
		"path": "res://assets/sounds/lingpet/monkeyshouting.wav",
		"gain_db": -4.0,
	},
	"star_coil_bind": {
		# Authored bind-window squish; stopped explicitly when the bind releases.
		"player_name": "LingpetStarCoilBindSfx",
		"path": "res://assets/sounds/lingpet/orosha_star_coil_bind.wav",
		"gain_db": -2.0,
	},
	"star_coil_move": {
		# Travel-phase loop. GameAudio retains stream duplication and loop policy.
		"player_name": "LingpetStarCoilMoveSfx",
		"path": "res://assets/sounds/starmoving.wav",
		"gain_db": -6.0,
	},
	"ring_dash": {
		"player_name": "LingpetRingDashSfx",
		"path": "res://assets/sounds/lingpet/ring_dash_whoosh_strike.wav",
		"gain_db": -5.0,
	},
	"egg_hit": {
		# One player swaps between the two bone-break candidates on each hit.
		"player_name": "LingpetEggHitSfx",
		"path": "res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_1.wav",
		"gain_db": -5.0,
	},
	"gatling_transform": {
		"player_name": "LingpetGatlingTransformSfx",
		"path": "res://assets/sounds/tanktransform.wav",
		"gain_db": -3.0980,
	},
	"gatling_loop": {
		"player_name": "LingpetGatlingLoopSfx",
		"path": "res://assets/sounds/gatling.wav",
		"gain_db": -3.0980,
	},
	"gatling_fire": {
		"player_name": "LingpetGatlingFireSfx",
		"path": "res://assets/sounds/smallboyshoot.wav",
		"gain_db": -16.4782,
	},
	"gatling_hit": {
		"player_name": "LingpetGatlingHitSfx",
		"path": "res://assets/sounds/bullethit.wav",
		"gain_db": -13.9794,
	},
	"dwarf_magic_cast": {
		# Original PingFighter Dwarf Magic cast/hit pair.
		"player_name": "LingpetDwarfMagicCastSfx",
		"path": "res://assets/sounds/smallboyshoot.wav",
		"gain_db": -4.0,
	},
	"dwarf_magic_hit": {
		"player_name": "LingpetDwarfMagicHitSfx",
		"path": "res://assets/sounds/smallboyhit.wav",
		"gain_db": -4.0,
	},
	"gravity_accel_cast": {
		# One-shot user of gravityaccel.wav; never mutate its cached stream in place.
		"player_name": "LingpetGravityAccelCastSfx",
		"path": "res://assets/sounds/gravityaccel.wav",
		"gain_db": -4.0,
	},
	"ghost_summon": {
		"player_name": "LingpetGhostSummonSfx",
		"path": "res://assets/sounds/bencyghost.wav",
		"gain_db": -5.0,
	},
	"ghost_summon_out": {
		"player_name": "LingpetGhostSummonOutSfx",
		"path": "res://assets/sounds/bencyghostout.wav",
		"gain_db": -5.0,
	},
	# Original PingFighter Skeleton Archer mapping. The gains preserve the
	# legacy 0.6 / 0.3 / 0.7 pygame volumes and playback stays at native pitch.
	"skeleton_archer_summon": {
		"player_name": "LingpetSkeletonArcherSummonSfx",
		"path": "res://assets/sounds/bonemake2.wav",
		"gain_db": -4.4,
	},
	"skeleton_archer_death": {
		"player_name": "LingpetSkeletonArcherDeathSfx",
		"path": "res://assets/sounds/skulldead.wav",
		"gain_db": -10.5,
	},
	"skeleton_archer_arrow_fire": {
		"player_name": "LingpetSkeletonArcherArrowFireSfx",
		"path": "res://assets/sounds/arrow.wav",
		"gain_db": -3.1,
	},
	"skeleton_archer_arrow_hit": {
		"player_name": "LingpetSkeletonArcherArrowHitSfx",
		"path": "res://assets/sounds/bullethit.wav",
		"gain_db": -3.1,
	},
	"bone_barrier_build": {
		"player_name": "LingpetBoneBarrierBuildSfx",
		"path": "res://assets/sounds/bonemake3.wav",
		"gain_db": -3.1,
	},
	"bone_barrier_break": {
		"player_name": "LingpetBoneBarrierBreakSfx",
		"path": "res://assets/sounds/bonebreak.wav",
		"gain_db": -3.1,
	},
	"bone_barrier_build_break": {
		"player_name": "LingpetBoneBarrierBuildBreakSfx",
		"path": "res://assets/sounds/shurikenhit.wav",
		"gain_db": -10.5,
	},
}

var owner_node: Node = null
var player_factory: Object = null
var egg_hit_streams: Array[AudioStream] = []
var _players: Dictionary = {}


func configure(parent: Node, factory: Object) -> void:
	owner_node = parent
	player_factory = factory


func setup_item_players(parent: Node, factory: Object) -> void:
	configure(parent, factory)
	for cue_id: String in ITEM_PLAYER_IDS:
		_players[cue_id] = _create_player(PLAYER_SPECS[cue_id])
	egg_hit_streams = _load_audio_stream_candidates(EGG_HIT_STREAM_PATHS)


func setup_projectile_players(parent: Node, factory: Object) -> void:
	configure(parent, factory)
	for cue_id: String in PROJECTILE_PLAYER_IDS:
		_players[cue_id] = _create_player(PLAYER_SPECS[cue_id])


func setup_stage_players(parent: Node, factory: Object) -> void:
	configure(parent, factory)
	for cue_id: String in STAGE_PLAYER_IDS:
		_players[cue_id] = _create_player(PLAYER_SPECS[cue_id])


func get_item_player_ids() -> Array[String]:
	return _copy_ids(ITEM_PLAYER_IDS)


func get_projectile_player_ids() -> Array[String]:
	return _copy_ids(PROJECTILE_PLAYER_IDS)


func get_stage_player_ids() -> Array[String]:
	return _copy_ids(STAGE_PLAYER_IDS)


func get_spec(cue_id: String) -> Dictionary:
	var value: Variant = PLAYER_SPECS.get(cue_id, null)
	return value as Dictionary if value is Dictionary else {}


func get_player(cue_id: String) -> AudioStreamPlayer:
	var value: Variant = _players.get(cue_id, null)
	return value as AudioStreamPlayer if value is AudioStreamPlayer else null


func get_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in ITEM_PLAYER_IDS:
		var player: AudioStreamPlayer = get_player(cue_id)
		if player != null:
			result.append(player)
	for cue_id: String in PROJECTILE_PLAYER_IDS:
		var projectile_player: AudioStreamPlayer = get_player(cue_id)
		if projectile_player != null:
			result.append(projectile_player)
	return result


func get_stage_sfx_bus_players() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for cue_id: String in ["ghost_summon", "ghost_summon_out"]:
		var player: AudioStreamPlayer = get_player(cue_id)
		if player != null:
			result.append(player)
	return result


func get_candidate_stream_paths(cue_id: String) -> Array[String]:
	if cue_id != "egg_hit":
		return []
	return _copy_ids(EGG_HIT_STREAM_PATHS)


func get_candidate_streams(cue_id: String) -> Array[AudioStream]:
	if cue_id == "egg_hit":
		return egg_hit_streams
	return []


func get_item_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in ITEM_PREWARM_IDS:
		result.append(str(PLAYER_SPECS[cue_id].get("path", "")))
	result.append_array(_copy_ids(EGG_HIT_STREAM_PATHS))
	return result


func get_stage_prewarm_stream_paths() -> Array[String]:
	var result: Array[String] = []
	for cue_id: String in STAGE_PLAYER_IDS:
		result.append(str(PLAYER_SPECS[cue_id].get("path", "")))
	return result


func _create_player(spec: Dictionary) -> AudioStreamPlayer:
	if player_factory == null:
		return null
	return player_factory.create(
		owner_node,
		str(spec.get("player_name", "")),
		str(spec.get("path", "")),
		float(spec.get("gain_db", 0.0))
	) as AudioStreamPlayer


func _load_audio_stream_candidates(paths: Array) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for path_value in paths:
		var path := str(path_value)
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(
			path,
			"Missing sound at %s",
			"Failed to load sound at %s"
		)
		if stream != null:
			streams.append(stream)
	return streams


func _copy_ids(source: Array) -> Array[String]:
	var result: Array[String] = []
	for value in source:
		result.append(str(value))
	return result
