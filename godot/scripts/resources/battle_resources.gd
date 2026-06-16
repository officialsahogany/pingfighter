extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const BattleBlacksmithSpritePaths := preload("res://scripts/resources/battle_blacksmith_sprite_paths.gd")
const BattleBossSpritePaths := preload("res://scripts/resources/battle_boss_sprite_paths.gd")
const BattleCommandoSpritePaths := preload("res://scripts/resources/battle_commando_sprite_paths.gd")
const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const BattleOptimusSpritePaths := preload("res://scripts/resources/battle_optimus_sprite_paths.gd")
const BattleSkillCutinPaths := preload("res://scripts/resources/battle_skill_cutin_paths.gd")
const BattleSkillIconPaths := preload("res://scripts/resources/battle_skill_icon_paths.gd")
const BattleSmasherSpritePaths := preload("res://scripts/resources/battle_smasher_sprite_paths.gd")
const BattleViperSpritePaths := preload("res://scripts/resources/battle_viper_sprite_paths.gd")
const Smasher25DSheetOverride := preload("res://scripts/core/smasher_25d_sheet_override.gd")

const PINGPONG_BALL_TEXTURE_PATH := BattleCoreTexturePaths.PINGPONG_BALL_TEXTURE_PATH
const GAUGE_ORB_FRAME_TEXTURE_PATH := BattleCoreTexturePaths.GAUGE_ORB_FRAME_TEXTURE_PATH
const DASH_TOKEN_FRAME_TEXTURE_PATH := BattleCoreTexturePaths.DASH_TOKEN_FRAME_TEXTURE_PATH
const SKILL_ORB_FRAME_TEXTURE_PATH := BattleCoreTexturePaths.SKILL_ORB_FRAME_TEXTURE_PATH
const SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := BattleCoreTexturePaths.SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH
const VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := BattleCoreTexturePaths.VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH
const STAGE1_CENTER_BACKGROUND_PATH := BattleCoreTexturePaths.STAGE1_CENTER_BACKGROUND_PATH
const STAGE1_CENTER_BORDER_PATH := BattleCoreTexturePaths.STAGE1_CENTER_BORDER_PATH
const PLAYER_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_SPRITE_PATH
const PLAYER_WALK_LEFT_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_WALK_LEFT_SPRITE_PATH
const PLAYER_WALK_RIGHT_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_WALK_RIGHT_SPRITE_PATH
const PLAYER_DASH_LEFT_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_DASH_LEFT_SPRITE_PATH
const PLAYER_DASH_RIGHT_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_DASH_RIGHT_SPRITE_PATH
const SMASHER_IDLE_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_IDLE_SHEET_PATH
const PLAYER_IDLE_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_IDLE_SPRITE_PATH
const SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH
const OPTIMUS_PLAYER_IDLE_SHEET_PATH := BattleOptimusSpritePaths.OPTIMUS_PLAYER_IDLE_SHEET_PATH
const OPTIMUS_PLAYER_WALK_LEFT_SHEET_PATH := BattleOptimusSpritePaths.OPTIMUS_PLAYER_WALK_LEFT_SHEET_PATH
const OPTIMUS_PLAYER_WALK_RIGHT_SHEET_PATH := BattleOptimusSpritePaths.OPTIMUS_PLAYER_WALK_RIGHT_SHEET_PATH
const OPTIMUS_PLAYER_ATTACK_LEFT_SHEET_PATH := BattleOptimusSpritePaths.OPTIMUS_PLAYER_ATTACK_LEFT_SHEET_PATH
const OPTIMUS_PLAYER_ATTACK_RIGHT_SHEET_PATH := BattleOptimusSpritePaths.OPTIMUS_PLAYER_ATTACK_RIGHT_SHEET_PATH
const OPTIMUS_OVERLAY_PADDLE_PATH := BattleOptimusSpritePaths.OPTIMUS_OVERLAY_PADDLE_PATH
const OPTIMUS_OVERLAY_CORE_GLOW_PATH := BattleOptimusSpritePaths.OPTIMUS_OVERLAY_CORE_GLOW_PATH
const OPTIMUS_OVERLAY_BACK_PATH := BattleOptimusSpritePaths.OPTIMUS_OVERLAY_BACK_PATH
const OPTIMUS_OVERLAY_ACCESSORY_PATH := BattleOptimusSpritePaths.OPTIMUS_OVERLAY_ACCESSORY_PATH
const OPTIMUS_OVERLAY_OUTFIT_ACCENT_PATH := BattleOptimusSpritePaths.OPTIMUS_OVERLAY_OUTFIT_ACCENT_PATH
const SMASHER_VICTORY_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_VICTORY_SHEET_PATH
const SMASHER_WHEEL_BODY_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_WHEEL_BODY_SHEET_PATH
const SMASHER_DEFEAT_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_DEFEAT_SHEET_PATH
const PLAYER_HIT_SPRITE_PATH := BattleSmasherSpritePaths.PLAYER_HIT_SPRITE_PATH
const PLAYER_HIT_LEFT_STRIP_PATH := BattleSmasherSpritePaths.PLAYER_HIT_LEFT_STRIP_PATH
const PLAYER_HIT_RIGHT_STRIP_PATH := BattleSmasherSpritePaths.PLAYER_HIT_RIGHT_STRIP_PATH
const VIPER_PLAYER_SPRITE_PATH := BattleViperSpritePaths.VIPER_PLAYER_SPRITE_PATH
const VIPER_PLAYER_IDLE_SPRITE_PATH := BattleViperSpritePaths.VIPER_PLAYER_IDLE_SPRITE_PATH
const VIPER_PLAYER_IDLE_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_IDLE_SHEET_PATH
const VIPER_PLAYER_WALK_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_WALK_LEFT_SHEET_PATH
const VIPER_PLAYER_WALK_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_WALK_RIGHT_SHEET_PATH
const VIPER_PLAYER_ATTACK_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_ATTACK_LEFT_SHEET_PATH
const VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH
const VIPER_PLAYER_WALL_CLING_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_WALL_CLING_LEFT_SHEET_PATH
const VIPER_PLAYER_WALL_CLING_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_WALL_CLING_RIGHT_SHEET_PATH
const VIPER_PLAYER_WALL_FLIGHT_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_WALL_FLIGHT_LEFT_SHEET_PATH
const VIPER_PLAYER_WALL_FLIGHT_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_WALL_FLIGHT_RIGHT_SHEET_PATH
const VIPER_PLAYER_FLYING_KICK_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_FLYING_KICK_LEFT_SHEET_PATH
const VIPER_PLAYER_FLYING_KICK_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_FLYING_KICK_RIGHT_SHEET_PATH
const VIPER_PLAYER_TUMBLE_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_TUMBLE_SHEET_PATH
const VIPER_PLAYER_BLADE_FIRE_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_BLADE_FIRE_SHEET_PATH
const VIPER_PLAYER_THROW_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_THROW_SHEET_PATH
const VIPER_PLAYER_HOVER_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_HOVER_LEFT_SHEET_PATH
const VIPER_PLAYER_HOVER_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_HOVER_RIGHT_SHEET_PATH
const VIPER_PLAYER_UP_KICK_LEFT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_UP_KICK_LEFT_SHEET_PATH
const VIPER_PLAYER_UP_KICK_RIGHT_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_UP_KICK_RIGHT_SHEET_PATH
const VIPER_PLAYER_STUN_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_STUN_SHEET_PATH
const VIPER_PLAYER_CONFUSION_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_CONFUSION_SHEET_PATH
# Venom Edge dash sheet: 640x320 PNG, 4x2 grid, 8 frames, cell 160x160.
# Back-view forward-launch with both arm-blades spread wide ("wings out").
# Body size varies per cell to read the depth-into-screen burst toward boss.
# Center-anchor (no foot baseline) since character is fully airborne.
const VIPER_PLAYER_VENOM_EDGE_DASH_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_VENOM_EDGE_DASH_SHEET_PATH
# Venom Edge strike sheet: 640x320 PNG, 4x2 grid, 8 frames, cell 160x160.
# UNIQUE FRONT-VIEW sheet — viper has appeared behind the boss and is turned
# toward the camera/player to slash the boss's eyes from behind. Face, fierce
# eyes, V-chevron on chest are visible. Cells 4-5 contain the bright cyan X-cut
# afterimage at peak slash. Foot-anchored (feet planted) since the strike is
# delivered from a standing pose behind the boss.
const VIPER_PLAYER_VENOM_EDGE_STRIKE_SHEET_PATH := BattleViperSpritePaths.VIPER_PLAYER_VENOM_EDGE_STRIKE_SHEET_PATH
const VIPER_VICTORY_SHEET_PATH := BattleViperSpritePaths.VIPER_VICTORY_SHEET_PATH
const VIPER_DEFEAT_SHEET_PATH := BattleViperSpritePaths.VIPER_DEFEAT_SHEET_PATH
const VIPER_PLAYER_HIT_LEFT_STRIP_PATH := BattleViperSpritePaths.VIPER_PLAYER_HIT_LEFT_STRIP_PATH
const VIPER_PLAYER_HIT_RIGHT_STRIP_PATH := BattleViperSpritePaths.VIPER_PLAYER_HIT_RIGHT_STRIP_PATH
const COMMANDO_PLAYER_IDLE_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_IDLE_SHEET_PATH
const COMMANDO_PLAYER_WALK_LEFT_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_WALK_LEFT_SHEET_PATH
const COMMANDO_PLAYER_WALK_RIGHT_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_WALK_RIGHT_SHEET_PATH
const COMMANDO_PLAYER_WALK_BACK_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_WALK_BACK_SHEET_PATH
const COMMANDO_PLAYER_BASE_GRIP_IDLE_BACK_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_BASE_GRIP_IDLE_BACK_SHEET_PATH
const COMMANDO_PLAYER_BASE_GRIP_WALK_LEFT_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_BASE_GRIP_WALK_LEFT_SHEET_PATH
const COMMANDO_PLAYER_BASE_GRIP_WALK_RIGHT_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_BASE_GRIP_WALK_RIGHT_SHEET_PATH
# Commando pistol-fire animation sheet: 1264x848 PNG, 4x2 grid, 8 frames,
# back view. Frames 0..3 = windup (driven by pistol_fire_delay_frames),
# frames 4..7 = post-shot muzzle / smoke / lower / ready (driven by
# pistol_post_fire_animation_frames). Frame 4 (muzzle flash) plays the
# moment `_play_fire_audio()` triggers gunshot.wav.
const COMMANDO_PLAYER_PISTOL_FIRE_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_PISTOL_FIRE_SHEET_PATH
# Commando weapon-action sheets: 640x320 PNGs, 4x2 grids, 8 frames. Idle /
# walk remains empty-handed; these sheets appear only during the matching
# firing / placement / control trigger window.
const COMMANDO_PLAYER_AK47_FIRE_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_AK47_FIRE_SHEET_PATH
const COMMANDO_PLAYER_BAZOOKA_FIRE_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_BAZOOKA_FIRE_SHEET_PATH
const COMMANDO_PLAYER_NET_GUN_FIRE_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_NET_GUN_FIRE_SHEET_PATH
const COMMANDO_PLAYER_BOWLING_TRAP_PLACE_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_BOWLING_TRAP_PLACE_SHEET_PATH
const COMMANDO_PLAYER_SUICIDE_DRONE_CONTROL_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_SUICIDE_DRONE_CONTROL_SHEET_PATH
# Commando ball-strike attack sheet: 640x320 PNG, 4x2 grid, 8 frames, back
# view. Muay-Thai clothesline-style squat-uppercut: F0 standing ready,
# F1-F3 squat coil, F4-F5 rising uppercut (F5 = ball-contact peak),
# F6-F7 follow-through and recover. Pistol holstered on right hip,
# both hands free. Frame index is driven by `player_hit_timer` /
# `player_effective_hit_duration` mapped onto frames 0..7.
const COMMANDO_PLAYER_ATTACK_SHEET_PATH := BattleCommandoSpritePaths.COMMANDO_PLAYER_ATTACK_SHEET_PATH
# Commando per-firearm weapon overlay sprites. The base sheet (idle / walk_*)
# already shows the pistol in the right hand, so "pistol" needs no overlay —
# it is the default visual. For every other equipped firearm, the matching
# overlay PNG is drawn on top of the base character at a per-direction anchor
# so the rifle / launcher / trap / drone replaces the visible pistol.
const COMMANDO_WEAPON_OVERLAY_AK47_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_OVERLAY_AK47_PATH
const COMMANDO_WEAPON_OVERLAY_BAZOOKA_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_OVERLAY_BAZOOKA_PATH
const COMMANDO_WEAPON_OVERLAY_NET_GUN_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_OVERLAY_NET_GUN_PATH
const COMMANDO_WEAPON_OVERLAY_BOWLING_TRAP_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_OVERLAY_BOWLING_TRAP_PATH
const COMMANDO_WEAPON_OVERLAY_SUICIDE_DRONE_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_OVERLAY_SUICIDE_DRONE_PATH
const COMMANDO_WEAPON_B2_PISTOL_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2_PISTOL_PATH
const COMMANDO_WEAPON_B2_AK47_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2_AK47_PATH
const COMMANDO_WEAPON_B2_BAZOOKA_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2_BAZOOKA_PATH
const COMMANDO_WEAPON_B2_NET_GUN_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2_NET_GUN_PATH
const COMMANDO_WEAPON_B2_BOWLING_TRAP_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2_BOWLING_TRAP_PATH
const COMMANDO_WEAPON_B2_SUICIDE_DRONE_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2_SUICIDE_DRONE_PATH
const COMMANDO_WEAPON_B2V2_PISTOL_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2V2_PISTOL_PATH
const COMMANDO_WEAPON_B2V2_AK47_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2V2_AK47_PATH
const COMMANDO_WEAPON_B2V2_BAZOOKA_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2V2_BAZOOKA_PATH
const COMMANDO_WEAPON_B2V2_NET_GUN_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2V2_NET_GUN_PATH
const COMMANDO_WEAPON_B2V2_BOWLING_TRAP_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2V2_BOWLING_TRAP_PATH
const COMMANDO_WEAPON_B2V2_SUICIDE_DRONE_PATH := BattleCommandoSpritePaths.COMMANDO_WEAPON_B2V2_SUICIDE_DRONE_PATH
const DEFAULT_CHARACTER_TYPE := PlayerCharacterRuntime.DEFAULT_CHARACTER
const VIPER_CHARACTER_TYPE := PlayerCharacterRuntime.VIPER
const COMMANDO_CHARACTER_TYPE := PlayerCharacterRuntime.COMMANDO
const OPTIMUS_CHARACTER_TYPE := PlayerCharacterRuntime.OPTIMUS
const BLACKSMITH_CHARACTER_TYPE := PlayerCharacterRuntime.BLACKSMITH
const BLACKSMITH_PLAYER_IDLE_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_IDLE_SHEET_PATH
const BLACKSMITH_PLAYER_WALK_LEFT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_WALK_LEFT_SHEET_PATH
const BLACKSMITH_PLAYER_WALK_RIGHT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_WALK_RIGHT_SHEET_PATH
const BLACKSMITH_PLAYER_DASH_LEFT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_DASH_LEFT_SHEET_PATH
const BLACKSMITH_PLAYER_DASH_RIGHT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_DASH_RIGHT_SHEET_PATH
const BLACKSMITH_PLAYER_ATTACK_LEFT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_ATTACK_LEFT_SHEET_PATH
const BLACKSMITH_PLAYER_ATTACK_RIGHT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_ATTACK_RIGHT_SHEET_PATH
const BLACKSMITH_PLAYER_THOR_SHIELD_DEPLOY_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_THOR_SHIELD_DEPLOY_SHEET_PATH
const BLACKSMITH_THOR_SHIELD_STRETCH_TEXTURE_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_THOR_SHIELD_STRETCH_TEXTURE_PATH
const BLACKSMITH_PLAYER_VICTORY_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_VICTORY_SHEET_PATH
const BLACKSMITH_PLAYER_DEFEAT_SHEET_PATH := BattleBlacksmithSpritePaths.BLACKSMITH_PLAYER_DEFEAT_SHEET_PATH

const SMASHER_ATTACK_LEFT_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_ATTACK_LEFT_SHEET_PATH
const SMASHER_ATTACK_RIGHT_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_ATTACK_RIGHT_SHEET_PATH
const SMASHER_ATTACK_SHEET_PATH := BattleSmasherSpritePaths.SMASHER_ATTACK_SHEET_PATH

const DALJI_BOSS_WALK_LEFT_PATH := BattleBossSpritePaths.DALJI_BOSS_WALK_LEFT_PATH
const DALJI_BOSS_WALK_RIGHT_PATH := BattleBossSpritePaths.DALJI_BOSS_WALK_RIGHT_PATH
const DALJI_BOSS_IDLE_PATH := BattleBossSpritePaths.DALJI_BOSS_IDLE_PATH
const DALJI_BOSS_ATTACK_PATH := BattleBossSpritePaths.DALJI_BOSS_ATTACK_PATH
const DALJI_BOSS_DASH_PATH := BattleBossSpritePaths.DALJI_BOSS_DASH_PATH
const DALJI_BOSS_VICTORY_PATH := BattleBossSpritePaths.DALJI_BOSS_VICTORY_PATH
const DALJI_BOSS_DEFEAT_PATH := BattleBossSpritePaths.DALJI_BOSS_DEFEAT_PATH
const DALJI_BOSS_STUN_PATH := BattleBossSpritePaths.DALJI_BOSS_STUN_PATH
const DALJI_BOSS_WHIP_PATH := BattleBossSpritePaths.DALJI_BOSS_WHIP_PATH
const DALJI_BOSS_PAENGI_TOP_WHIP_PATH := BattleBossSpritePaths.DALJI_BOSS_PAENGI_TOP_WHIP_PATH
const STAGE2_BOSS_WALK_LEFT_PATH := BattleBossSpritePaths.STAGE2_BOSS_WALK_LEFT_PATH
const STAGE2_BOSS_WALK_RIGHT_PATH := BattleBossSpritePaths.STAGE2_BOSS_WALK_RIGHT_PATH
const STAGE2_BOSS_IDLE_PATH := BattleBossSpritePaths.STAGE2_BOSS_IDLE_PATH
const STAGE2_BOSS_ATTACK_PATH := BattleBossSpritePaths.STAGE2_BOSS_ATTACK_PATH
const STAGE2_BOSS_QUAKE_STOMP_PATH := BattleBossSpritePaths.STAGE2_BOSS_QUAKE_STOMP_PATH
const STAGE2_BOSS_VICTORY_PATH := BattleBossSpritePaths.STAGE2_BOSS_VICTORY_PATH
const STAGE2_BOSS_DEFEAT_PATH := BattleBossSpritePaths.STAGE2_BOSS_DEFEAT_PATH
const STAGE3_MENHERA_BOSS_WALK_PATH := BattleBossSpritePaths.STAGE3_MENHERA_BOSS_WALK_PATH
const STAGE3_MENHERA_BOSS_ATTACK_PATH := BattleBossSpritePaths.STAGE3_MENHERA_BOSS_ATTACK_PATH
const STAGE3_MENHERA_BOSS_DASH_PATH := BattleBossSpritePaths.STAGE3_MENHERA_BOSS_DASH_PATH
const STAGE3_MENHERA_BOSS_VICTORY_PATH := BattleBossSpritePaths.STAGE3_MENHERA_BOSS_VICTORY_PATH
const STAGE3_MENHERA_BOSS_DEFEAT_PATH := BattleBossSpritePaths.STAGE3_MENHERA_BOSS_DEFEAT_PATH
const STAGE5_HONGRYUN_BOSS_SHEET_PATH := BattleBossSpritePaths.STAGE5_HONGRYUN_BOSS_SHEET_PATH
const STAGE5_HONGRYUN_BOSS_ATTACK_PATH := BattleBossSpritePaths.STAGE5_HONGRYUN_BOSS_ATTACK_PATH
const STAGE5_HONGRYUN_BOSS_DASH_PATH := BattleBossSpritePaths.STAGE5_HONGRYUN_BOSS_DASH_PATH
const STAGE5_HONGRYUN_BOSS_TURN_PATH := BattleBossSpritePaths.STAGE5_HONGRYUN_BOSS_TURN_PATH
const SMASHER_POWER_SMASHING_CUTIN_SHEET_PATH := BattleSkillCutinPaths.SMASHER_POWER_SMASHING_CUTIN_SHEET_PATH
const SMASHER_GHOST_SMASHING_CUTIN_SHEET_PATH := BattleSkillCutinPaths.SMASHER_GHOST_SMASHING_CUTIN_SHEET_PATH
const VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH := BattleSkillCutinPaths.VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH
const SMASHER_DRIVE_CUTIN_BACKPLATE_PATH := BattleSkillCutinPaths.SMASHER_DRIVE_CUTIN_BACKPLATE_PATH
const SMASHER_DRIVE_CUTIN_ARC_PATH := BattleSkillCutinPaths.SMASHER_DRIVE_CUTIN_ARC_PATH
const SMASHER_DRIVE_CUTIN_CHARACTER_PATH := BattleSkillCutinPaths.SMASHER_DRIVE_CUTIN_CHARACTER_PATH
const SMASHER_DRIVE_CUTIN_PARTICLE_PATH := BattleSkillCutinPaths.SMASHER_DRIVE_CUTIN_PARTICLE_PATH
const SMASHER_SHIELD_KITING_CUTIN_CHARACTER_PATH := BattleSkillCutinPaths.SMASHER_SHIELD_KITING_CUTIN_CHARACTER_PATH
const LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH := BattleSkillCutinPaths.LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH

const SMASHER_SKILL_ICON_PATHS := BattleSkillIconPaths.SMASHER_SKILL_ICON_PATHS
const VIPER_SKILL_ICON_PATHS := BattleSkillIconPaths.VIPER_SKILL_ICON_PATHS
const COMMANDO_SKILL_ICON_PATHS := BattleSkillIconPaths.COMMANDO_SKILL_ICON_PATHS

var _character_runtime: Object = PlayerCharacterRuntime.new()
var _resource_cache: Dictionary = {}
var _transition_texture_prewarm_key: String = ""
var _transition_texture_prewarm_step_index: int = 0
var _transition_skill_icon_map_cache: Dictionary = {}
var _transition_skill_icon_temp_keys: Array[String] = []
var _transition_texture_prewarm_current: Dictionary = {}
var _transition_texture_prewarm_path: String = ""
var _transition_texture_prewarm_active: bool = false
var _result_texture_prewarm_jobs: Array = []
var _result_texture_prewarm_current: Dictionary = {}
var _result_texture_prewarm_path: String = ""
var _result_texture_prewarm_active: bool = false
var _result_texture_prewarm_pending: Dictionary = {}
var _result_texture_prewarm_pending_delay_frames: int = 0


func prewarm_core_textures(_context: Dictionary = {}) -> void:
	_load_core_textures()


func prewarm_player_textures(context: Dictionary = {}) -> void:
	_load_player_textures(
		_get_selected_character_type(context),
		_should_include_all_characters(context),
		_should_include_result_sheets(context)
	)


func prewarm_boss_textures(context: Dictionary = {}) -> void:
	_load_stage_textures(
		_get_current_stage(context),
		_should_include_all_stages(context),
		_should_include_result_sheets(context)
	)


func prewarm_smasher_skill_icons() -> void:
	for path in SMASHER_SKILL_ICON_PATHS.values():
		_load_texture_resource(str(path))


func prewarm_viper_skill_icons() -> void:
	for path in VIPER_SKILL_ICON_PATHS.values():
		_load_texture_resource(str(path))


func prewarm_commando_skill_icons() -> void:
	for path in COMMANDO_SKILL_ICON_PATHS.values():
		_load_texture_resource(str(path))


func load_all(context: Dictionary = {}) -> Dictionary:
	_load_core_textures()
	_load_player_textures(
		_get_selected_character_type(context),
		_should_include_all_characters(context),
		_should_include_result_sheets(context)
	)
	_load_stage_textures(
		_get_current_stage(context),
		_should_include_all_stages(context),
		_should_include_result_sheets(context)
	)
	_load_skill_icon_textures(
		_get_selected_character_type(context),
		_should_include_all_characters(context)
	)
	return _resource_cache


func get_resource_cache() -> Dictionary:
	return _resource_cache


# Battle resources owns its own threaded load slots (transition + result
# texture specs) via ResourceLoader.load_threaded_request, SEPARATE from the
# shared ProjectResourceLoader prewarm slot. Frame-budgeted warmup batching
# must consult this too, or it spin-polls _update_transition_texture_prewarm_thread
# for the whole frame budget while the worker loads (observed: step 02 call
# count 172 -> 7,469 on Stage 1 entry).
func is_threaded_prewarm_in_flight() -> bool:
	return _transition_texture_prewarm_active or _result_texture_prewarm_active


# Job list ({path, prefer_imported}) the staged transition texture prewarm will
# walk for this context, for the menu-idle background prewarmer. Filling
# ProjectResourceLoader's static texture cache with these paths makes the boot
# transition steps resolve as instant cache hits (_try_store_cached_texture_spec).
# Pseudo-specs without a path (e.g. clear_smasher_player_fallbacks) are skipped.
func get_transition_texture_prewarm_jobs(context: Dictionary = {}) -> Array:
	var character_type := _get_selected_character_type(context)
	var current_stage := _get_current_stage(context)
	var include_result_sheets := _should_include_result_sheets(context)
	var specs: Array = []
	specs.append_array(_get_core_texture_specs())
	specs.append_array(_get_player_texture_specs(character_type, include_result_sheets))
	specs.append_array(_get_stage_boss_texture_specs(current_stage, include_result_sheets))
	var jobs: Array = []
	for spec_value in specs:
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		var spec_path := str(spec.get("path", ""))
		if spec_path == "":
			continue
		jobs.append({"path": spec_path, "prefer_imported": bool(spec.get("prefer_imported", false))})
	var icon_paths: Dictionary = _get_selected_skill_icon_paths(character_type)
	for icon_path_value in icon_paths.values():
		var icon_path := str(icon_path_value)
		if icon_path != "":
			jobs.append({"path": icon_path, "prefer_imported": false})
	return jobs


func reset_transition_texture_prewarm() -> void:
	_transition_texture_prewarm_key = ""
	_transition_texture_prewarm_step_index = 0
	_transition_skill_icon_map_cache.clear()
	_clear_transition_skill_icon_temp_keys()
	_clear_transition_texture_prewarm_thread()


func prewarm_transition_textures_step(context: Dictionary = {}) -> bool:
	var character_type: String = _get_selected_character_type(context)
	var current_stage: int = _get_current_stage(context)
	var include_result_sheets: bool = _should_include_result_sheets(context)
	var include_all_characters: bool = _should_include_all_characters(context)
	var include_all_stages: bool = _should_include_all_stages(context)
	if include_all_characters or include_all_stages:
		load_all(context)
		reset_transition_texture_prewarm()
		return true

	var prewarm_key := "%s:%d:%s" % [character_type, current_stage, str(include_result_sheets)]
	if _transition_texture_prewarm_key != prewarm_key:
		_transition_texture_prewarm_key = prewarm_key
		_transition_texture_prewarm_step_index = 0
		_transition_skill_icon_map_cache.clear()
		_clear_transition_skill_icon_temp_keys()
		_clear_transition_texture_prewarm_thread()

	var core_step_count := _get_core_texture_step_count()
	var player_step_count := _get_player_texture_step_count(character_type, include_result_sheets)
	var boss_step_count := _get_stage_boss_texture_step_count(current_stage, include_result_sheets)
	var skill_icon_step_count := _get_selected_skill_icon_texture_step_count(character_type)
	var total_step_count := core_step_count + player_step_count + boss_step_count + skill_icon_step_count
	var step_index := _transition_texture_prewarm_step_index
	var step_done := true
	if step_index < core_step_count:
		step_done = _prewarm_core_texture_step(step_index)
	elif step_index < core_step_count + player_step_count:
		step_done = _prewarm_player_texture_step(character_type, include_result_sheets, step_index - core_step_count)
	elif step_index < core_step_count + player_step_count + boss_step_count:
		step_done = _prewarm_stage_boss_texture_step(
			current_stage,
			include_result_sheets,
			step_index - core_step_count - player_step_count
		)
	elif step_index < total_step_count:
		step_done = _prewarm_selected_skill_icon_texture_step(
			character_type,
			step_index - core_step_count - player_step_count - boss_step_count
		)
	else:
		reset_transition_texture_prewarm()
		return true

	if not step_done:
		return false
	_transition_texture_prewarm_step_index += 1
	if _transition_texture_prewarm_step_index >= total_step_count:
		reset_transition_texture_prewarm()
		return true
	return false


func ensure_result_textures(
	character_type: String = DEFAULT_CHARACTER_TYPE,
	current_stage: int = 1,
	result_context: Dictionary = {}
) -> Dictionary:
	var selected_character_type := _normalize_character_type(character_type)
	for spec in _get_result_texture_specs(selected_character_type, current_stage, result_context):
		if not _is_texture_spec_loaded(spec):
			_load_texture_spec(spec)
			return _resource_cache
	return _resource_cache


func sync_cached_result_textures(
	character_type: String = DEFAULT_CHARACTER_TYPE,
	current_stage: int = 1,
	result_context: Dictionary = {}
) -> Dictionary:
	var selected_character_type := _normalize_character_type(character_type)
	for spec in _get_result_texture_specs(selected_character_type, current_stage, result_context):
		if _is_texture_spec_loaded(spec):
			continue
		_try_store_cached_texture_spec(spec)
	return _resource_cache


func begin_result_texture_prewarm(
	character_type: String = DEFAULT_CHARACTER_TYPE,
	current_stage: int = 1,
	result_context: Dictionary = {}
) -> void:
	_result_texture_prewarm_pending = {}
	_result_texture_prewarm_pending_delay_frames = 0
	_begin_result_texture_prewarm_now(character_type, current_stage, result_context)


func queue_result_texture_prewarm(
	character_type: String = DEFAULT_CHARACTER_TYPE,
	current_stage: int = 1,
	result_context: Dictionary = {},
	delay_frames: int = 1
) -> void:
	_result_texture_prewarm_jobs.clear()
	_result_texture_prewarm_current = {}
	_result_texture_prewarm_path = ""
	_result_texture_prewarm_active = false
	_result_texture_prewarm_pending = {
		"character_type": character_type,
		"current_stage": current_stage,
		"result_context": result_context.duplicate(true),
	}
	_result_texture_prewarm_pending_delay_frames = max(0, delay_frames)


func _begin_result_texture_prewarm_now(
	character_type: String = DEFAULT_CHARACTER_TYPE,
	current_stage: int = 1,
	result_context: Dictionary = {}
) -> void:
	_result_texture_prewarm_jobs.clear()
	_result_texture_prewarm_current = {}
	_result_texture_prewarm_path = ""
	_result_texture_prewarm_active = false

	var queued_paths: Dictionary = {}
	var selected_character_type := _normalize_character_type(character_type)
	for spec in _get_result_texture_specs(selected_character_type, current_stage, result_context):
		if _is_texture_spec_loaded(spec):
			continue
		if _try_store_cached_texture_spec(spec):
			continue
		var path := str(spec.get("path", ""))
		if path == "" or queued_paths.has(path) or not _is_thread_loadable_texture_path(path):
			continue
		queued_paths[path] = true
		_result_texture_prewarm_jobs.append(spec)
	_request_next_result_texture_prewarm_job()


func update_result_texture_prewarm() -> bool:
	if _has_pending_result_texture_prewarm():
		if _result_texture_prewarm_pending_delay_frames > 0:
			_result_texture_prewarm_pending_delay_frames -= 1
			return false
		var pending := _result_texture_prewarm_pending.duplicate(true)
		_result_texture_prewarm_pending = {}
		_begin_result_texture_prewarm_now(
			str(pending.get("character_type", DEFAULT_CHARACTER_TYPE)),
			int(pending.get("current_stage", 1)),
			_get_dictionary(pending.get("result_context", {}))
		)
	if not _result_texture_prewarm_active:
		return _result_texture_prewarm_jobs.is_empty() and not _has_pending_result_texture_prewarm()
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_result_texture_prewarm_path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish_result_texture_threaded_job(ResourceLoader.load_threaded_get(_result_texture_prewarm_path))
			_request_next_result_texture_prewarm_job()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_request_next_result_texture_prewarm_job()
	return not _result_texture_prewarm_active and _result_texture_prewarm_jobs.is_empty()


func has_result_texture_prewarm_work() -> bool:
	return _result_texture_prewarm_active or not _result_texture_prewarm_jobs.is_empty() or _has_pending_result_texture_prewarm()


func _has_pending_result_texture_prewarm() -> bool:
	return not _result_texture_prewarm_pending.is_empty()


func _load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing sprite at %s",
		"Failed to load texture at %s"
	)


func _load_optional_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(path, "", "")


func _load_imported_texture_resource(path: String, optional: bool = false) -> Texture2D:
	return ProjectResourceLoader.load_imported_texture(
		path,
		"" if optional else "Missing sprite at %s",
		"" if optional else "Failed to load texture at %s"
	)


func _texture_spec(keys: Array, path: String, optional: bool = false) -> Dictionary:
	return {
		"keys": keys,
		"path": path,
		"optional": optional,
	}


func _imported_texture_spec(keys: Array, path: String, optional: bool = false) -> Dictionary:
	var spec := _texture_spec(keys, path, optional)
	spec["prefer_imported"] = true
	return spec


func _get_result_texture_specs(character_type: String, current_stage: int, result_context: Dictionary) -> Array:
	var player_victory_specs: Array = []
	var player_defeat_specs: Array = []
	if character_type == DEFAULT_CHARACTER_TYPE:
		player_victory_specs.append(_texture_spec(["player_victory_sheet"], SMASHER_VICTORY_SHEET_PATH))
		player_defeat_specs.append(_texture_spec(["player_defeat_sheet"], SMASHER_DEFEAT_SHEET_PATH))
	elif character_type == VIPER_CHARACTER_TYPE:
		player_victory_specs.append(_texture_spec(["player_victory_sheet"], VIPER_VICTORY_SHEET_PATH))
		player_defeat_specs.append(_texture_spec(["player_defeat_sheet"], VIPER_DEFEAT_SHEET_PATH))
	elif character_type == BLACKSMITH_CHARACTER_TYPE:
		player_victory_specs.append(_texture_spec(["player_victory_sheet"], BLACKSMITH_PLAYER_VICTORY_SHEET_PATH))
		player_defeat_specs.append(_texture_spec(["player_defeat_sheet"], BLACKSMITH_PLAYER_DEFEAT_SHEET_PATH))

	var boss_victory_specs: Array = []
	var boss_defeat_specs: Array = []
	if current_stage == 1:
		boss_victory_specs.append(_texture_spec(["boss_victory_sheet"], DALJI_BOSS_VICTORY_PATH))
		boss_defeat_specs.append(_texture_spec(["boss_defeat_sheet"], DALJI_BOSS_DEFEAT_PATH))
	elif current_stage == 2:
		boss_victory_specs.append(_texture_spec(["boss_victory_sheet"], STAGE2_BOSS_VICTORY_PATH))
		boss_defeat_specs.append(_texture_spec(["boss_defeat_sheet"], STAGE2_BOSS_DEFEAT_PATH))
	elif current_stage == 3:
		boss_victory_specs.append(_texture_spec(["boss_victory_sheet"], STAGE3_MENHERA_BOSS_VICTORY_PATH))
		boss_defeat_specs.append(_texture_spec(["boss_defeat_sheet"], STAGE3_MENHERA_BOSS_DEFEAT_PATH))

	var player_scored: bool = (
		bool(result_context.get("player_victory_active", false))
		or bool(result_context.get("boss_defeat_active", false))
	)
	var boss_scored: bool = (
		bool(result_context.get("player_defeat_active", false))
		or bool(result_context.get("boss_victory_active", false))
	)
	if player_scored:
		return player_victory_specs + boss_defeat_specs + player_defeat_specs + boss_victory_specs
	if boss_scored:
		return player_defeat_specs + boss_victory_specs + player_victory_specs + boss_defeat_specs
	return player_victory_specs + player_defeat_specs + boss_victory_specs + boss_defeat_specs


func _is_texture_spec_loaded(spec: Dictionary) -> bool:
	var keys_value: Variant = spec.get("keys", [])
	if not (keys_value is Array):
		return true
	var expected_path := str(spec.get("path", ""))
	for key_value in keys_value:
		var texture: Variant = _resource_cache.get(str(key_value), null)
		if not (texture is Texture2D):
			return false
		if expected_path != "" and str((texture as Texture2D).resource_path) != expected_path:
			return false
	return true


func _try_store_cached_texture_spec(spec: Dictionary) -> bool:
	var path := str(spec.get("path", ""))
	if path == "":
		return false
	var texture: Texture2D = ProjectResourceLoader.get_cached_texture(path)
	if texture == null:
		return false
	_store_texture_spec(spec, texture)
	return true


func _prewarm_texture_spec_step(spec: Dictionary) -> bool:
	if bool(spec.get("clear_smasher_player_fallbacks", false)):
		_clear_smasher_player_fallback_textures()
		return true
	if _is_texture_spec_loaded(spec):
		return true
	if _try_store_cached_texture_spec(spec):
		return true

	var path := str(spec.get("path", ""))
	if path == "":
		return true
	if not _is_thread_loadable_texture_path(path):
		_load_texture_spec(spec)
		return true
	if _transition_texture_prewarm_active:
		return _update_transition_texture_prewarm_thread()

	var request_error := ResourceLoader.load_threaded_request(path, "Texture2D", true)
	if request_error != OK and request_error != ERR_BUSY:
		_load_texture_spec(spec)
		return true
	_transition_texture_prewarm_current = spec
	_transition_texture_prewarm_path = path
	_transition_texture_prewarm_active = true
	return false


func _update_transition_texture_prewarm_thread() -> bool:
	if not _transition_texture_prewarm_active:
		return true
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_transition_texture_prewarm_path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish_transition_texture_threaded_job(ResourceLoader.load_threaded_get(_transition_texture_prewarm_path))
			_clear_transition_texture_prewarm_thread()
			return true
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var failed_spec := _transition_texture_prewarm_current.duplicate(true)
			_clear_transition_texture_prewarm_thread()
			_load_texture_spec(failed_spec)
			return true
	return false


func _finish_transition_texture_threaded_job(resource: Resource) -> void:
	var texture := resource as Texture2D
	if texture == null:
		return
	ProjectResourceLoader.store_texture(_transition_texture_prewarm_path, texture)
	_store_texture_spec(_transition_texture_prewarm_current, texture)


func _clear_transition_texture_prewarm_thread() -> void:
	_transition_texture_prewarm_current = {}
	_transition_texture_prewarm_path = ""
	_transition_texture_prewarm_active = false


func _request_next_result_texture_prewarm_job() -> void:
	_result_texture_prewarm_active = false
	_result_texture_prewarm_current = {}
	_result_texture_prewarm_path = ""
	while not _result_texture_prewarm_jobs.is_empty():
		var spec_value: Variant = _result_texture_prewarm_jobs.pop_front()
		if not (spec_value is Dictionary):
			continue
		var spec: Dictionary = spec_value
		if _is_texture_spec_loaded(spec):
			continue
		if _try_store_cached_texture_spec(spec):
			continue
		var path := str(spec.get("path", ""))
		if path == "" or not _is_thread_loadable_texture_path(path):
			continue
		var request_error := ResourceLoader.load_threaded_request(path, "Texture2D", true)
		if request_error == OK or request_error == ERR_BUSY:
			_result_texture_prewarm_current = spec
			_result_texture_prewarm_path = path
			_result_texture_prewarm_active = true
			return


func _finish_result_texture_threaded_job(resource: Resource) -> void:
	var texture := resource as Texture2D
	if texture == null:
		return
	ProjectResourceLoader.store_texture(_result_texture_prewarm_path, texture)
	_store_texture_spec(_result_texture_prewarm_current, texture)


func _is_thread_loadable_texture_path(path: String) -> bool:
	return ProjectResourceLoader.can_thread_load_texture(path)


func _clear_smasher_player_fallback_spec() -> Dictionary:
	return {"clear_smasher_player_fallbacks": true}


func _load_texture_spec(spec: Dictionary) -> void:
	if bool(spec.get("clear_smasher_player_fallbacks", false)):
		_clear_smasher_player_fallback_textures()
		return
	var path := str(spec.get("path", ""))
	if path == "":
		return
	var prefer_imported := bool(spec.get("prefer_imported", false))
	var texture: Texture2D = null
	if prefer_imported:
		texture = _load_imported_texture_resource(path, bool(spec.get("optional", false)))
	elif bool(spec.get("optional", false)):
		texture = _load_optional_texture_resource(path)
	else:
		texture = _load_texture_resource(path)
	_store_texture_spec(spec, texture)


func _load_texture_specs(specs: Array) -> void:
	for spec_value in specs:
		if spec_value is Dictionary:
			_load_texture_spec(spec_value)


func _store_texture_spec(spec: Dictionary, texture: Texture2D) -> void:
	var keys_value: Variant = spec.get("keys", [])
	if not (keys_value is Array):
		return
	for key_value in keys_value:
		_resource_cache[str(key_value)] = texture


func _get_core_texture_specs() -> Array:
	return [
		_texture_spec(["pingpong_ball_texture"], PINGPONG_BALL_TEXTURE_PATH),
		_texture_spec(["gauge_orb_frame_texture"], GAUGE_ORB_FRAME_TEXTURE_PATH),
		_texture_spec(["dash_token_frame_texture"], DASH_TOKEN_FRAME_TEXTURE_PATH),
		_texture_spec(["skill_orb_frame_texture"], SKILL_ORB_FRAME_TEXTURE_PATH),
		_texture_spec(["smasher_skill_cluster_frame_texture"], SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH),
		_texture_spec(["viper_skill_cluster_frame_texture"], VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH),
		_texture_spec(["stage1_center_background_texture"], STAGE1_CENTER_BACKGROUND_PATH),
		_texture_spec(["stage1_center_border_texture"], STAGE1_CENTER_BORDER_PATH),
		_imported_texture_spec(["lingpet_acquire_resonance_portal"], LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH),
	]


func _get_core_texture_step_count() -> int:
	return _get_core_texture_specs().size()


func _prewarm_core_texture_step(step_index: int) -> bool:
	var specs := _get_core_texture_specs()
	if step_index < 0 or step_index >= specs.size():
		return true
	return _prewarm_texture_spec_step(specs[step_index])


func _load_core_textures() -> void:
	_load_texture_specs(_get_core_texture_specs())


func _load_player_textures(character_type: String, include_all_characters: bool, include_result_sheets: bool) -> void:
	if include_all_characters or character_type == DEFAULT_CHARACTER_TYPE:
		_load_smasher_player_textures(include_result_sheets and character_type == DEFAULT_CHARACTER_TYPE)
	if include_all_characters or character_type == VIPER_CHARACTER_TYPE:
		_load_viper_player_textures(include_result_sheets and character_type == VIPER_CHARACTER_TYPE)
	if include_all_characters or character_type == COMMANDO_CHARACTER_TYPE:
		_load_commando_player_textures()
	if include_all_characters or character_type == OPTIMUS_CHARACTER_TYPE:
		_load_optimus_player_textures(character_type == OPTIMUS_CHARACTER_TYPE)
	if include_all_characters or character_type == BLACKSMITH_CHARACTER_TYPE:
		_load_blacksmith_player_textures(
			character_type == BLACKSMITH_CHARACTER_TYPE,
			include_result_sheets and character_type == BLACKSMITH_CHARACTER_TYPE
		)


func _get_player_texture_step_count(character_type: String, include_result_sheets: bool) -> int:
	return _get_player_texture_specs(character_type, include_result_sheets).size()


func _prewarm_player_texture_step(character_type: String, include_result_sheets: bool, step_index: int) -> bool:
	var specs := _get_player_texture_specs(character_type, include_result_sheets)
	if step_index < 0 or step_index >= specs.size():
		return true
	return _prewarm_texture_spec_step(specs[step_index])


func _get_player_texture_specs(character_type: String, include_result_sheets: bool) -> Array:
	match character_type:
		DEFAULT_CHARACTER_TYPE:
			return _get_smasher_player_texture_specs(include_result_sheets)
		VIPER_CHARACTER_TYPE:
			return _get_viper_player_texture_specs(include_result_sheets)
		COMMANDO_CHARACTER_TYPE:
			return _get_commando_player_texture_specs()
		OPTIMUS_CHARACTER_TYPE:
			return _get_optimus_player_texture_specs(true)
		BLACKSMITH_CHARACTER_TYPE:
			return _get_blacksmith_player_texture_specs(true, include_result_sheets)
	return _get_smasher_player_texture_specs(include_result_sheets)


func _get_smasher_player_texture_specs(include_result_sheets: bool) -> Array:
	var sheet_paths := _get_smasher_player_sheet_paths()
	var specs := [
		_texture_spec(["player_sprite_texture"], str(sheet_paths["sprite"])),
		_texture_spec(["player_walk_left_texture"], str(sheet_paths["walk_left"])),
		_texture_spec(["player_walk_right_texture"], str(sheet_paths["walk_right"])),
		_texture_spec(["player_dash_left_texture"], PLAYER_DASH_LEFT_SPRITE_PATH),
		_texture_spec(["player_dash_right_texture"], PLAYER_DASH_RIGHT_SPRITE_PATH),
		_texture_spec(["player_idle_back_sheet", "player_idle_sprite_texture"], str(sheet_paths["idle"])),
		_texture_spec(["player_hit_sprite_texture"], PLAYER_HIT_SPRITE_PATH),
		_texture_spec(["player_hit_left_strip_texture"], PLAYER_HIT_LEFT_STRIP_PATH),
		_texture_spec(["player_hit_right_strip_texture"], PLAYER_HIT_RIGHT_STRIP_PATH),
		_texture_spec(["player_attack_left_sheet"], str(sheet_paths["attack_left"])),
		_texture_spec(["player_attack_right_sheet"], str(sheet_paths["attack_right"])),
		_texture_spec(["player_attack_sheet"], SMASHER_ATTACK_SHEET_PATH),
		_texture_spec(["player_wheel_spin_sheet"], SMASHER_WHEEL_BODY_SHEET_PATH),
		_texture_spec(["smasher_debug_paddle_overlay_sheet"], SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH),
		_imported_texture_spec(["smasher_power_smashing_cutin_sheet"], SMASHER_POWER_SMASHING_CUTIN_SHEET_PATH),
		_imported_texture_spec(["smasher_ghost_smashing_cutin_sheet"], SMASHER_GHOST_SMASHING_CUTIN_SHEET_PATH),
		_imported_texture_spec(["smasher_drive_cutin_backplate"], SMASHER_DRIVE_CUTIN_BACKPLATE_PATH),
		_imported_texture_spec(["smasher_drive_cutin_arc"], SMASHER_DRIVE_CUTIN_ARC_PATH),
		_imported_texture_spec(["smasher_drive_cutin_character"], SMASHER_DRIVE_CUTIN_CHARACTER_PATH),
		_imported_texture_spec(["smasher_drive_cutin_particle"], SMASHER_DRIVE_CUTIN_PARTICLE_PATH),
		_imported_texture_spec(["smasher_shield_kiting_cutin_character"], SMASHER_SHIELD_KITING_CUTIN_CHARACTER_PATH),
	]
	if include_result_sheets:
		specs.append(_texture_spec(["player_victory_sheet"], SMASHER_VICTORY_SHEET_PATH))
		specs.append(_texture_spec(["player_defeat_sheet"], SMASHER_DEFEAT_SHEET_PATH))
	return specs


func _get_smasher_player_sheet_paths() -> Dictionary:
	var paths := {
		"sprite": PLAYER_SPRITE_PATH,
		"walk_left": PLAYER_WALK_LEFT_SPRITE_PATH,
		"walk_right": PLAYER_WALK_RIGHT_SPRITE_PATH,
		"idle": SMASHER_IDLE_SHEET_PATH,
		"attack_left": SMASHER_ATTACK_LEFT_SHEET_PATH,
		"attack_right": SMASHER_ATTACK_RIGHT_SHEET_PATH,
	}
	var override_paths: Dictionary = Smasher25DSheetOverride.get_active_sheet_paths()
	if override_paths.is_empty():
		return paths
	paths["walk_left"] = str(override_paths.get("walk_left", paths["walk_left"]))
	paths["walk_right"] = str(override_paths.get("walk_right", paths["walk_right"]))
	paths["idle"] = str(override_paths.get("idle", paths["idle"]))
	paths["attack_left"] = str(override_paths.get("attack_left", paths["attack_left"]))
	return paths


func _get_viper_player_texture_specs(include_result_sheets: bool) -> Array:
	var specs := [
		_texture_spec(["viper_player_sprite_texture"], VIPER_PLAYER_SPRITE_PATH),
		_texture_spec(["viper_player_idle_sprite_texture"], VIPER_PLAYER_IDLE_SPRITE_PATH),
		_texture_spec(["viper_player_idle_sheet"], VIPER_PLAYER_IDLE_SHEET_PATH),
		_texture_spec(["viper_player_walk_left_sheet"], VIPER_PLAYER_WALK_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_walk_right_sheet"], VIPER_PLAYER_WALK_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_attack_left_sheet"], VIPER_PLAYER_ATTACK_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_attack_right_sheet"], VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_wall_cling_left_sheet"], VIPER_PLAYER_WALL_CLING_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_wall_cling_right_sheet"], VIPER_PLAYER_WALL_CLING_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_wall_flight_left_sheet"], VIPER_PLAYER_WALL_FLIGHT_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_wall_flight_right_sheet"], VIPER_PLAYER_WALL_FLIGHT_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_flying_kick_left_sheet"], VIPER_PLAYER_FLYING_KICK_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_flying_kick_right_sheet"], VIPER_PLAYER_FLYING_KICK_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_tumble_sheet"], VIPER_PLAYER_TUMBLE_SHEET_PATH),
		_texture_spec(["viper_player_blade_fire_sheet"], VIPER_PLAYER_BLADE_FIRE_SHEET_PATH),
		_texture_spec(["viper_player_throw_sheet"], VIPER_PLAYER_THROW_SHEET_PATH),
		_texture_spec(["viper_player_hover_left_sheet"], VIPER_PLAYER_HOVER_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_hover_right_sheet"], VIPER_PLAYER_HOVER_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_up_kick_left_sheet"], VIPER_PLAYER_UP_KICK_LEFT_SHEET_PATH),
		_texture_spec(["viper_player_up_kick_right_sheet"], VIPER_PLAYER_UP_KICK_RIGHT_SHEET_PATH),
		_texture_spec(["viper_player_stun_sheet"], VIPER_PLAYER_STUN_SHEET_PATH),
		_texture_spec(["viper_player_confusion_sheet"], VIPER_PLAYER_CONFUSION_SHEET_PATH),
		_texture_spec(["viper_player_venom_edge_dash_sheet"], VIPER_PLAYER_VENOM_EDGE_DASH_SHEET_PATH),
		_texture_spec(["viper_player_venom_edge_strike_sheet"], VIPER_PLAYER_VENOM_EDGE_STRIKE_SHEET_PATH),
		_texture_spec(["viper_player_hit_left_strip_texture"], VIPER_PLAYER_HIT_LEFT_STRIP_PATH),
		_texture_spec(["viper_player_hit_right_strip_texture"], VIPER_PLAYER_HIT_RIGHT_STRIP_PATH),
		_imported_texture_spec(["viper_phantom_kick_cutin_sheet"], VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH),
	]
	if include_result_sheets:
		specs.append(_texture_spec(["player_victory_sheet"], VIPER_VICTORY_SHEET_PATH))
		specs.append(_texture_spec(["player_defeat_sheet"], VIPER_DEFEAT_SHEET_PATH))
	return specs


func _get_commando_player_texture_specs() -> Array:
	return [
		_texture_spec(["commando_player_legacy_idle_sheet"], COMMANDO_PLAYER_IDLE_SHEET_PATH),
		_texture_spec(["commando_player_legacy_walk_left_sheet"], COMMANDO_PLAYER_WALK_LEFT_SHEET_PATH),
		_texture_spec(["commando_player_legacy_walk_right_sheet"], COMMANDO_PLAYER_WALK_RIGHT_SHEET_PATH),
		_texture_spec(["commando_player_idle_sheet"], COMMANDO_PLAYER_BASE_GRIP_IDLE_BACK_SHEET_PATH),
		_texture_spec(["commando_player_walk_left_sheet"], COMMANDO_PLAYER_BASE_GRIP_WALK_LEFT_SHEET_PATH),
		_texture_spec(["commando_player_walk_right_sheet"], COMMANDO_PLAYER_BASE_GRIP_WALK_RIGHT_SHEET_PATH),
		_texture_spec(["commando_player_walk_back_sheet"], COMMANDO_PLAYER_WALK_BACK_SHEET_PATH),
		_texture_spec(["commando_player_pistol_fire_sheet"], COMMANDO_PLAYER_PISTOL_FIRE_SHEET_PATH),
		_texture_spec(["commando_player_ak47_fire_sheet"], COMMANDO_PLAYER_AK47_FIRE_SHEET_PATH),
		_texture_spec(["commando_player_bazooka_fire_sheet"], COMMANDO_PLAYER_BAZOOKA_FIRE_SHEET_PATH),
		_texture_spec(["commando_player_net_gun_fire_sheet"], COMMANDO_PLAYER_NET_GUN_FIRE_SHEET_PATH),
		_texture_spec(["commando_player_bowling_trap_place_sheet"], COMMANDO_PLAYER_BOWLING_TRAP_PLACE_SHEET_PATH),
		_texture_spec(["commando_player_suicide_drone_control_sheet"], COMMANDO_PLAYER_SUICIDE_DRONE_CONTROL_SHEET_PATH),
		_texture_spec(["commando_player_attack_sheet"], COMMANDO_PLAYER_ATTACK_SHEET_PATH),
		_texture_spec(["commando_weapon_overlay_ak47"], COMMANDO_WEAPON_OVERLAY_AK47_PATH),
		_texture_spec(["commando_weapon_overlay_bazooka"], COMMANDO_WEAPON_OVERLAY_BAZOOKA_PATH),
		_texture_spec(["commando_weapon_overlay_net_gun"], COMMANDO_WEAPON_OVERLAY_NET_GUN_PATH),
		_texture_spec(["commando_weapon_overlay_bowling_trap"], COMMANDO_WEAPON_OVERLAY_BOWLING_TRAP_PATH),
		_texture_spec(["commando_weapon_overlay_suicide_drone"], COMMANDO_WEAPON_OVERLAY_SUICIDE_DRONE_PATH),
		_texture_spec(["commando_weapon_b2_pistol"], COMMANDO_WEAPON_B2_PISTOL_PATH),
		_texture_spec(["commando_weapon_b2_ak47"], COMMANDO_WEAPON_B2_AK47_PATH),
		_texture_spec(["commando_weapon_b2_bazooka"], COMMANDO_WEAPON_B2_BAZOOKA_PATH),
		_texture_spec(["commando_weapon_b2_net_gun"], COMMANDO_WEAPON_B2_NET_GUN_PATH),
		_texture_spec(["commando_weapon_b2_bowling_trap"], COMMANDO_WEAPON_B2_BOWLING_TRAP_PATH),
		_texture_spec(["commando_weapon_b2_suicide_drone"], COMMANDO_WEAPON_B2_SUICIDE_DRONE_PATH),
		_texture_spec(["commando_weapon_b2v2_pistol"], COMMANDO_WEAPON_B2V2_PISTOL_PATH),
		_texture_spec(["commando_weapon_b2v2_ak47"], COMMANDO_WEAPON_B2V2_AK47_PATH),
		_texture_spec(["commando_weapon_b2v2_bazooka"], COMMANDO_WEAPON_B2V2_BAZOOKA_PATH),
		_texture_spec(["commando_weapon_b2v2_net_gun"], COMMANDO_WEAPON_B2V2_NET_GUN_PATH),
		_texture_spec(["commando_weapon_b2v2_bowling_trap"], COMMANDO_WEAPON_B2V2_BOWLING_TRAP_PATH),
		_texture_spec(["commando_weapon_b2v2_suicide_drone"], COMMANDO_WEAPON_B2V2_SUICIDE_DRONE_PATH),
	]


func _get_optimus_player_texture_specs(clear_generic_player_fallbacks: bool) -> Array:
	var specs := [
		_texture_spec(["optimus_player_idle_sheet"], OPTIMUS_PLAYER_IDLE_SHEET_PATH, true),
		_texture_spec(["optimus_player_walk_left_sheet"], OPTIMUS_PLAYER_WALK_LEFT_SHEET_PATH, true),
		_texture_spec(["optimus_player_walk_right_sheet"], OPTIMUS_PLAYER_WALK_RIGHT_SHEET_PATH, true),
		_texture_spec(["optimus_player_attack_left_sheet"], OPTIMUS_PLAYER_ATTACK_LEFT_SHEET_PATH, true),
		_texture_spec(["optimus_player_attack_right_sheet"], OPTIMUS_PLAYER_ATTACK_RIGHT_SHEET_PATH, true),
		_texture_spec(["optimus_overlay_paddle"], OPTIMUS_OVERLAY_PADDLE_PATH, true),
		_texture_spec(["optimus_overlay_core_glow"], OPTIMUS_OVERLAY_CORE_GLOW_PATH, true),
		_texture_spec(["optimus_overlay_back"], OPTIMUS_OVERLAY_BACK_PATH, true),
		_texture_spec(["optimus_overlay_accessory"], OPTIMUS_OVERLAY_ACCESSORY_PATH, true),
		_texture_spec(["optimus_overlay_outfit_accent"], OPTIMUS_OVERLAY_OUTFIT_ACCENT_PATH, true),
	]
	if clear_generic_player_fallbacks:
		specs.append(_clear_smasher_player_fallback_spec())
	return specs


func _get_blacksmith_player_texture_specs(
	clear_generic_player_fallbacks: bool,
	include_result_sheets: bool = false
) -> Array:
	var specs := [
		_texture_spec(["blacksmith_player_idle_sheet"], BLACKSMITH_PLAYER_IDLE_SHEET_PATH),
		_texture_spec(["blacksmith_player_walk_left_sheet"], BLACKSMITH_PLAYER_WALK_LEFT_SHEET_PATH),
		_texture_spec(["blacksmith_player_walk_right_sheet"], BLACKSMITH_PLAYER_WALK_RIGHT_SHEET_PATH),
		_texture_spec(["blacksmith_player_dash_left_sheet"], BLACKSMITH_PLAYER_DASH_LEFT_SHEET_PATH),
		_texture_spec(["blacksmith_player_dash_right_sheet"], BLACKSMITH_PLAYER_DASH_RIGHT_SHEET_PATH),
		_texture_spec(["blacksmith_player_attack_left_sheet"], BLACKSMITH_PLAYER_ATTACK_LEFT_SHEET_PATH),
		_texture_spec(["blacksmith_player_attack_right_sheet"], BLACKSMITH_PLAYER_ATTACK_RIGHT_SHEET_PATH),
		_texture_spec(["blacksmith_player_thor_shield_deploy_sheet"], BLACKSMITH_PLAYER_THOR_SHIELD_DEPLOY_SHEET_PATH),
		# Stretch-shield overlay PNG (the actual "코하쿠 방패가 길게 늘어난" body).
		# This MUST stay in the spec list, not only in `_load_blacksmith_player_textures`:
		# the threaded boot / stage-transition prewarm path
		# (`prewarm_transition_textures_step` -> `_get_player_texture_specs`) is what
		# fills `_resource_cache` in normal gameplay. `load_all` (which also direct-loads
		# the stretch texture) only runs on the synchronous fallback path, so a spec
		# omission here leaves `blacksmith_thor_shield_stretch_texture` null at runtime
		# and the shield body silently never draws.
		_texture_spec(["blacksmith_thor_shield_stretch_texture"], BLACKSMITH_THOR_SHIELD_STRETCH_TEXTURE_PATH),
	]
	if include_result_sheets:
		specs.append(_texture_spec(["player_victory_sheet"], BLACKSMITH_PLAYER_VICTORY_SHEET_PATH))
		specs.append(_texture_spec(["player_defeat_sheet"], BLACKSMITH_PLAYER_DEFEAT_SHEET_PATH))
	if clear_generic_player_fallbacks:
		specs.append(_clear_smasher_player_fallback_spec())
	return specs


func _load_smasher_player_textures(include_result_sheets: bool) -> void:
	var sheet_paths := _get_smasher_player_sheet_paths()
	_resource_cache["player_sprite_texture"] = _load_texture_resource(str(sheet_paths["sprite"]))
	_resource_cache["player_walk_left_texture"] = _load_texture_resource(str(sheet_paths["walk_left"]))
	_resource_cache["player_walk_right_texture"] = _load_texture_resource(str(sheet_paths["walk_right"]))
	_resource_cache["player_dash_left_texture"] = _load_texture_resource(PLAYER_DASH_LEFT_SPRITE_PATH)
	_resource_cache["player_dash_right_texture"] = _load_texture_resource(PLAYER_DASH_RIGHT_SPRITE_PATH)
	var idle_sheet: Texture2D = _load_texture_resource(str(sheet_paths["idle"]))
	_resource_cache["player_idle_back_sheet"] = idle_sheet
	_resource_cache["player_idle_sprite_texture"] = idle_sheet
	_resource_cache["player_hit_sprite_texture"] = _load_texture_resource(PLAYER_HIT_SPRITE_PATH)
	_resource_cache["player_hit_left_strip_texture"] = _load_texture_resource(PLAYER_HIT_LEFT_STRIP_PATH)
	_resource_cache["player_hit_right_strip_texture"] = _load_texture_resource(PLAYER_HIT_RIGHT_STRIP_PATH)
	_resource_cache["player_attack_left_sheet"] = _load_texture_resource(str(sheet_paths["attack_left"]))
	_resource_cache["player_attack_right_sheet"] = _load_texture_resource(str(sheet_paths["attack_right"]))
	_resource_cache["player_attack_sheet"] = _load_texture_resource(SMASHER_ATTACK_SHEET_PATH)
	_resource_cache["player_wheel_spin_sheet"] = _load_texture_resource(SMASHER_WHEEL_BODY_SHEET_PATH)
	_resource_cache["smasher_debug_paddle_overlay_sheet"] = _load_texture_resource(SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH)
	if include_result_sheets:
		_resource_cache["player_victory_sheet"] = _load_texture_resource(SMASHER_VICTORY_SHEET_PATH)
		_resource_cache["player_defeat_sheet"] = _load_texture_resource(SMASHER_DEFEAT_SHEET_PATH)


func _load_viper_player_textures(include_result_sheets: bool = false) -> void:
	_resource_cache["viper_player_sprite_texture"] = _load_texture_resource(VIPER_PLAYER_SPRITE_PATH)
	_resource_cache["viper_player_idle_sprite_texture"] = _load_texture_resource(VIPER_PLAYER_IDLE_SPRITE_PATH)
	_resource_cache["viper_player_idle_sheet"] = _load_texture_resource(VIPER_PLAYER_IDLE_SHEET_PATH)
	_resource_cache["viper_player_walk_left_sheet"] = _load_texture_resource(VIPER_PLAYER_WALK_LEFT_SHEET_PATH)
	_resource_cache["viper_player_walk_right_sheet"] = _load_texture_resource(VIPER_PLAYER_WALK_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_attack_left_sheet"] = _load_texture_resource(VIPER_PLAYER_ATTACK_LEFT_SHEET_PATH)
	_resource_cache["viper_player_attack_right_sheet"] = _load_texture_resource(VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_wall_cling_left_sheet"] = _load_texture_resource(VIPER_PLAYER_WALL_CLING_LEFT_SHEET_PATH)
	_resource_cache["viper_player_wall_cling_right_sheet"] = _load_texture_resource(VIPER_PLAYER_WALL_CLING_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_wall_flight_left_sheet"] = _load_texture_resource(VIPER_PLAYER_WALL_FLIGHT_LEFT_SHEET_PATH)
	_resource_cache["viper_player_wall_flight_right_sheet"] = _load_texture_resource(VIPER_PLAYER_WALL_FLIGHT_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_flying_kick_left_sheet"] = _load_texture_resource(VIPER_PLAYER_FLYING_KICK_LEFT_SHEET_PATH)
	_resource_cache["viper_player_flying_kick_right_sheet"] = _load_texture_resource(VIPER_PLAYER_FLYING_KICK_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_tumble_sheet"] = _load_texture_resource(VIPER_PLAYER_TUMBLE_SHEET_PATH)
	_resource_cache["viper_player_blade_fire_sheet"] = _load_texture_resource(VIPER_PLAYER_BLADE_FIRE_SHEET_PATH)
	_resource_cache["viper_player_throw_sheet"] = _load_texture_resource(VIPER_PLAYER_THROW_SHEET_PATH)
	_resource_cache["viper_player_hover_left_sheet"] = _load_texture_resource(VIPER_PLAYER_HOVER_LEFT_SHEET_PATH)
	_resource_cache["viper_player_hover_right_sheet"] = _load_texture_resource(VIPER_PLAYER_HOVER_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_up_kick_left_sheet"] = _load_texture_resource(VIPER_PLAYER_UP_KICK_LEFT_SHEET_PATH)
	_resource_cache["viper_player_up_kick_right_sheet"] = _load_texture_resource(VIPER_PLAYER_UP_KICK_RIGHT_SHEET_PATH)
	_resource_cache["viper_player_stun_sheet"] = _load_texture_resource(VIPER_PLAYER_STUN_SHEET_PATH)
	_resource_cache["viper_player_confusion_sheet"] = _load_texture_resource(VIPER_PLAYER_CONFUSION_SHEET_PATH)
	_resource_cache["viper_player_venom_edge_dash_sheet"] = _load_texture_resource(VIPER_PLAYER_VENOM_EDGE_DASH_SHEET_PATH)
	_resource_cache["viper_player_venom_edge_strike_sheet"] = _load_texture_resource(VIPER_PLAYER_VENOM_EDGE_STRIKE_SHEET_PATH)
	_resource_cache["viper_player_hit_left_strip_texture"] = _load_texture_resource(VIPER_PLAYER_HIT_LEFT_STRIP_PATH)
	_resource_cache["viper_player_hit_right_strip_texture"] = _load_texture_resource(VIPER_PLAYER_HIT_RIGHT_STRIP_PATH)
	if include_result_sheets:
		_resource_cache["player_victory_sheet"] = _load_texture_resource(VIPER_VICTORY_SHEET_PATH)
		_resource_cache["player_defeat_sheet"] = _load_texture_resource(VIPER_DEFEAT_SHEET_PATH)


func _load_commando_player_textures() -> void:
	_resource_cache["commando_player_legacy_idle_sheet"] = _load_texture_resource(COMMANDO_PLAYER_IDLE_SHEET_PATH)
	_resource_cache["commando_player_legacy_walk_left_sheet"] = _load_texture_resource(COMMANDO_PLAYER_WALK_LEFT_SHEET_PATH)
	_resource_cache["commando_player_legacy_walk_right_sheet"] = _load_texture_resource(COMMANDO_PLAYER_WALK_RIGHT_SHEET_PATH)
	_resource_cache["commando_player_idle_sheet"] = _load_texture_resource(COMMANDO_PLAYER_BASE_GRIP_IDLE_BACK_SHEET_PATH)
	_resource_cache["commando_player_walk_left_sheet"] = _load_texture_resource(COMMANDO_PLAYER_BASE_GRIP_WALK_LEFT_SHEET_PATH)
	_resource_cache["commando_player_walk_right_sheet"] = _load_texture_resource(COMMANDO_PLAYER_BASE_GRIP_WALK_RIGHT_SHEET_PATH)
	_resource_cache["commando_player_walk_back_sheet"] = _load_texture_resource(COMMANDO_PLAYER_WALK_BACK_SHEET_PATH)
	_resource_cache["commando_player_pistol_fire_sheet"] = _load_texture_resource(COMMANDO_PLAYER_PISTOL_FIRE_SHEET_PATH)
	_resource_cache["commando_player_ak47_fire_sheet"] = _load_texture_resource(COMMANDO_PLAYER_AK47_FIRE_SHEET_PATH)
	_resource_cache["commando_player_bazooka_fire_sheet"] = _load_texture_resource(COMMANDO_PLAYER_BAZOOKA_FIRE_SHEET_PATH)
	_resource_cache["commando_player_net_gun_fire_sheet"] = _load_texture_resource(COMMANDO_PLAYER_NET_GUN_FIRE_SHEET_PATH)
	_resource_cache["commando_player_bowling_trap_place_sheet"] = _load_texture_resource(COMMANDO_PLAYER_BOWLING_TRAP_PLACE_SHEET_PATH)
	_resource_cache["commando_player_suicide_drone_control_sheet"] = _load_texture_resource(COMMANDO_PLAYER_SUICIDE_DRONE_CONTROL_SHEET_PATH)
	_resource_cache["commando_player_attack_sheet"] = _load_texture_resource(COMMANDO_PLAYER_ATTACK_SHEET_PATH)
	_resource_cache["commando_weapon_overlay_ak47"] = _load_texture_resource(COMMANDO_WEAPON_OVERLAY_AK47_PATH)
	_resource_cache["commando_weapon_overlay_bazooka"] = _load_texture_resource(COMMANDO_WEAPON_OVERLAY_BAZOOKA_PATH)
	_resource_cache["commando_weapon_overlay_net_gun"] = _load_texture_resource(COMMANDO_WEAPON_OVERLAY_NET_GUN_PATH)
	_resource_cache["commando_weapon_overlay_bowling_trap"] = _load_texture_resource(COMMANDO_WEAPON_OVERLAY_BOWLING_TRAP_PATH)
	_resource_cache["commando_weapon_overlay_suicide_drone"] = _load_texture_resource(COMMANDO_WEAPON_OVERLAY_SUICIDE_DRONE_PATH)
	_resource_cache["commando_weapon_b2_pistol"] = _load_texture_resource(COMMANDO_WEAPON_B2_PISTOL_PATH)
	_resource_cache["commando_weapon_b2_ak47"] = _load_texture_resource(COMMANDO_WEAPON_B2_AK47_PATH)
	_resource_cache["commando_weapon_b2_bazooka"] = _load_texture_resource(COMMANDO_WEAPON_B2_BAZOOKA_PATH)
	_resource_cache["commando_weapon_b2_net_gun"] = _load_texture_resource(COMMANDO_WEAPON_B2_NET_GUN_PATH)
	_resource_cache["commando_weapon_b2_bowling_trap"] = _load_texture_resource(COMMANDO_WEAPON_B2_BOWLING_TRAP_PATH)
	_resource_cache["commando_weapon_b2_suicide_drone"] = _load_texture_resource(COMMANDO_WEAPON_B2_SUICIDE_DRONE_PATH)
	_resource_cache["commando_weapon_b2v2_pistol"] = _load_texture_resource(COMMANDO_WEAPON_B2V2_PISTOL_PATH)
	_resource_cache["commando_weapon_b2v2_ak47"] = _load_texture_resource(COMMANDO_WEAPON_B2V2_AK47_PATH)
	_resource_cache["commando_weapon_b2v2_bazooka"] = _load_texture_resource(COMMANDO_WEAPON_B2V2_BAZOOKA_PATH)
	_resource_cache["commando_weapon_b2v2_net_gun"] = _load_texture_resource(COMMANDO_WEAPON_B2V2_NET_GUN_PATH)
	_resource_cache["commando_weapon_b2v2_bowling_trap"] = _load_texture_resource(COMMANDO_WEAPON_B2V2_BOWLING_TRAP_PATH)
	_resource_cache["commando_weapon_b2v2_suicide_drone"] = _load_texture_resource(COMMANDO_WEAPON_B2V2_SUICIDE_DRONE_PATH)


func _load_optimus_player_textures(clear_generic_player_fallbacks: bool) -> void:
	_resource_cache["optimus_player_idle_sheet"] = _load_optional_texture_resource(OPTIMUS_PLAYER_IDLE_SHEET_PATH)
	_resource_cache["optimus_player_walk_left_sheet"] = _load_optional_texture_resource(OPTIMUS_PLAYER_WALK_LEFT_SHEET_PATH)
	_resource_cache["optimus_player_walk_right_sheet"] = _load_optional_texture_resource(OPTIMUS_PLAYER_WALK_RIGHT_SHEET_PATH)
	_resource_cache["optimus_player_attack_left_sheet"] = _load_optional_texture_resource(OPTIMUS_PLAYER_ATTACK_LEFT_SHEET_PATH)
	_resource_cache["optimus_player_attack_right_sheet"] = _load_optional_texture_resource(OPTIMUS_PLAYER_ATTACK_RIGHT_SHEET_PATH)
	_resource_cache["optimus_overlay_paddle"] = _load_optional_texture_resource(OPTIMUS_OVERLAY_PADDLE_PATH)
	_resource_cache["optimus_overlay_core_glow"] = _load_optional_texture_resource(OPTIMUS_OVERLAY_CORE_GLOW_PATH)
	_resource_cache["optimus_overlay_back"] = _load_optional_texture_resource(OPTIMUS_OVERLAY_BACK_PATH)
	_resource_cache["optimus_overlay_accessory"] = _load_optional_texture_resource(OPTIMUS_OVERLAY_ACCESSORY_PATH)
	_resource_cache["optimus_overlay_outfit_accent"] = _load_optional_texture_resource(OPTIMUS_OVERLAY_OUTFIT_ACCENT_PATH)
	if clear_generic_player_fallbacks:
		_clear_smasher_player_fallback_textures()


func _load_blacksmith_player_textures(
	clear_generic_player_fallbacks: bool,
	include_result_sheets: bool = false
) -> void:
	_resource_cache["blacksmith_player_idle_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_IDLE_SHEET_PATH)
	_resource_cache["blacksmith_player_walk_left_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_WALK_LEFT_SHEET_PATH)
	_resource_cache["blacksmith_player_walk_right_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_WALK_RIGHT_SHEET_PATH)
	_resource_cache["blacksmith_player_dash_left_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_DASH_LEFT_SHEET_PATH)
	_resource_cache["blacksmith_player_dash_right_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_DASH_RIGHT_SHEET_PATH)
	_resource_cache["blacksmith_player_attack_left_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_ATTACK_LEFT_SHEET_PATH)
	_resource_cache["blacksmith_player_attack_right_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_ATTACK_RIGHT_SHEET_PATH)
	_resource_cache["blacksmith_player_thor_shield_deploy_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_THOR_SHIELD_DEPLOY_SHEET_PATH)
	_resource_cache["blacksmith_thor_shield_stretch_texture"] = _load_texture_resource(BLACKSMITH_THOR_SHIELD_STRETCH_TEXTURE_PATH)
	if include_result_sheets:
		_resource_cache["player_victory_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_VICTORY_SHEET_PATH)
		_resource_cache["player_defeat_sheet"] = _load_texture_resource(BLACKSMITH_PLAYER_DEFEAT_SHEET_PATH)
	if clear_generic_player_fallbacks:
		_clear_smasher_player_fallback_textures()


func _clear_smasher_player_fallback_textures() -> void:
	for key in [
		"player_sprite_texture",
		"player_walk_left_texture",
		"player_walk_right_texture",
		"player_idle_back_sheet",
		"player_idle_sprite_texture",
		"player_hit_sprite_texture",
		"player_hit_left_strip_texture",
		"player_hit_right_strip_texture",
		"player_attack_left_sheet",
		"player_attack_right_sheet",
		"player_attack_sheet",
		"player_wheel_spin_sheet",
		"smasher_debug_paddle_overlay_sheet",
	]:
		_resource_cache[key] = null


func _load_stage_textures(current_stage: int, include_all_stages: bool, include_result_sheets: bool) -> void:
	if include_all_stages:
		var stage_order := [1, 2, 3, 5]
		for stage_id in stage_order:
			var normalized_stage := int(stage_id)
			if normalized_stage == current_stage:
				continue
			_load_stage_boss_textures(normalized_stage, include_result_sheets)
		_load_stage_boss_textures(current_stage, include_result_sheets)
		return
	_load_stage_boss_textures(current_stage, include_result_sheets)


func _load_stage_boss_textures(stage_id: int, include_result_sheets: bool) -> void:
	if stage_id == 1:
		_load_stage1_boss_textures(include_result_sheets)
	elif stage_id == 2:
		_load_stage2_boss_textures(include_result_sheets)
	elif stage_id == 3:
		_load_stage3_boss_textures(include_result_sheets)
	elif stage_id == 5:
		_load_stage5_hongryun_boss_textures()


func _load_stage1_boss_textures(include_result_sheets: bool) -> void:
	_load_texture_specs(_get_stage1_boss_texture_specs(include_result_sheets))


func _load_stage2_boss_textures(include_result_sheets: bool = false) -> void:
	_load_texture_specs(_get_stage2_boss_texture_specs(include_result_sheets))


func _load_stage3_boss_textures(include_result_sheets: bool = false) -> void:
	_load_texture_specs(_get_stage3_boss_texture_specs(include_result_sheets))


func _get_stage_boss_texture_specs(stage_id: int, include_result_sheets: bool) -> Array:
	match stage_id:
		1:
			return _get_stage1_boss_texture_specs(include_result_sheets)
		2:
			return _get_stage2_boss_texture_specs(include_result_sheets)
		3:
			return _get_stage3_boss_texture_specs(include_result_sheets)
		5:
			return _get_stage5_hongryun_boss_texture_specs()
	return []


func _get_stage1_boss_texture_specs(include_result_sheets: bool) -> Array:
	var specs := [
		_texture_spec(["boss_walk_left_sheet"], DALJI_BOSS_WALK_LEFT_PATH),
		_texture_spec(["boss_walk_right_sheet", "boss_sprite_sheet"], DALJI_BOSS_WALK_RIGHT_PATH),
		_texture_spec(["boss_idle_sheet"], DALJI_BOSS_IDLE_PATH),
		_texture_spec(["boss_attack_sheet", "boss_hit_sprite_sheet"], DALJI_BOSS_ATTACK_PATH),
		_texture_spec(["boss_dash_sheet"], DALJI_BOSS_DASH_PATH),
		_texture_spec(["boss_stun_sheet"], DALJI_BOSS_STUN_PATH),
		_texture_spec(["boss_whip_sheet"], DALJI_BOSS_WHIP_PATH),
		_texture_spec(["boss_paengi_top_whip_sheet"], DALJI_BOSS_PAENGI_TOP_WHIP_PATH),
	]
	if include_result_sheets:
		specs.append(_texture_spec(["boss_victory_sheet"], DALJI_BOSS_VICTORY_PATH))
		specs.append(_texture_spec(["boss_defeat_sheet"], DALJI_BOSS_DEFEAT_PATH))
	return specs


func _get_stage2_boss_texture_specs(include_result_sheets: bool) -> Array:
	var specs := [
		_texture_spec(["boss_walk_left_sheet"], STAGE2_BOSS_WALK_LEFT_PATH),
		_texture_spec(["boss_walk_right_sheet", "boss_sprite_sheet"], STAGE2_BOSS_WALK_RIGHT_PATH),
		_texture_spec(["boss_idle_sheet"], STAGE2_BOSS_IDLE_PATH),
		_texture_spec(["boss_attack_sheet", "boss_hit_sprite_sheet"], STAGE2_BOSS_ATTACK_PATH),
		_texture_spec(["boss_quake_stomp_sheet"], STAGE2_BOSS_QUAKE_STOMP_PATH),
	]
	if include_result_sheets:
		specs.append(_texture_spec(["boss_victory_sheet"], STAGE2_BOSS_VICTORY_PATH))
		specs.append(_texture_spec(["boss_defeat_sheet"], STAGE2_BOSS_DEFEAT_PATH))
	return specs


func _get_stage3_boss_texture_specs(include_result_sheets: bool) -> Array:
	var specs := [
		_texture_spec(["boss_sprite_sheet"], STAGE3_MENHERA_BOSS_WALK_PATH),
		_texture_spec(["boss_attack_sheet", "boss_hit_sprite_sheet"], STAGE3_MENHERA_BOSS_ATTACK_PATH),
		_texture_spec(["boss_dash_sheet"], STAGE3_MENHERA_BOSS_DASH_PATH),
	]
	if include_result_sheets:
		specs.append(_texture_spec(["boss_victory_sheet"], STAGE3_MENHERA_BOSS_VICTORY_PATH))
		specs.append(_texture_spec(["boss_defeat_sheet"], STAGE3_MENHERA_BOSS_DEFEAT_PATH))
	return specs


func _get_stage5_hongryun_boss_texture_specs() -> Array:
	return [
		_texture_spec(["boss_walk_left_sheet", "boss_walk_right_sheet", "boss_sprite_sheet"], STAGE5_HONGRYUN_BOSS_SHEET_PATH),
		_texture_spec(["boss_attack_sheet", "boss_hit_sprite_sheet"], STAGE5_HONGRYUN_BOSS_ATTACK_PATH),
		_texture_spec(["boss_dash_sheet"], STAGE5_HONGRYUN_BOSS_DASH_PATH),
		_texture_spec(["boss_turn_sheet"], STAGE5_HONGRYUN_BOSS_TURN_PATH),
	]


func _get_stage_boss_texture_step_count(stage_id: int, include_result_sheets: bool) -> int:
	return _get_stage_boss_texture_specs(stage_id, include_result_sheets).size()


func _prewarm_stage_boss_texture_step(stage_id: int, include_result_sheets: bool, step_index: int) -> bool:
	var specs := _get_stage_boss_texture_specs(stage_id, include_result_sheets)
	if step_index < 0 or step_index >= specs.size():
		return true
	return _prewarm_texture_spec_step(specs[step_index])


func _load_stage5_hongryun_boss_textures() -> void:
	_load_texture_specs(_get_stage5_hongryun_boss_texture_specs())


func _load_skill_icon_textures(character_type: String, include_all_characters: bool) -> void:
	if include_all_characters or character_type == DEFAULT_CHARACTER_TYPE:
		_resource_cache["smasher_skill_icon_textures"] = _load_skill_icon_map(SMASHER_SKILL_ICON_PATHS)
	elif not _resource_cache.has("smasher_skill_icon_textures"):
		_resource_cache["smasher_skill_icon_textures"] = {}
	if include_all_characters or character_type == VIPER_CHARACTER_TYPE:
		_resource_cache["viper_skill_icon_textures"] = _load_skill_icon_map(VIPER_SKILL_ICON_PATHS)
	elif not _resource_cache.has("viper_skill_icon_textures"):
		_resource_cache["viper_skill_icon_textures"] = {}
	if include_all_characters or character_type == COMMANDO_CHARACTER_TYPE:
		_resource_cache["commando_skill_icon_textures"] = _load_skill_icon_map(COMMANDO_SKILL_ICON_PATHS)
	elif not _resource_cache.has("commando_skill_icon_textures"):
		_resource_cache["commando_skill_icon_textures"] = {}


func _load_skill_icon_map(paths: Dictionary) -> Dictionary:
	var skill_icons: Dictionary = {}
	for skill_name in paths.keys():
		var skill_id := str(skill_name)
		skill_icons[skill_id] = SkillOrbTextureNormalizer.normalize(
			skill_id,
			_load_texture_resource(paths[skill_name])
		)
	return skill_icons


func _get_selected_skill_icon_texture_step_count(character_type: String) -> int:
	return max(1, _get_selected_skill_icon_paths(character_type).size())


func _prewarm_selected_skill_icon_texture_step(character_type: String, step_index: int) -> bool:
	_ensure_inactive_skill_icon_maps(character_type)
	var paths := _get_selected_skill_icon_paths(character_type)
	var cache_key := _get_selected_skill_icon_cache_key(character_type)
	if cache_key == "":
		return true
	if not _transition_skill_icon_map_cache.has(cache_key):
		var existing_icons: Variant = _resource_cache.get(cache_key, {})
		_transition_skill_icon_map_cache[cache_key] = existing_icons if existing_icons is Dictionary else {}
	var skill_names := paths.keys()
	if step_index < 0 or step_index >= skill_names.size():
		_resource_cache[cache_key] = _transition_skill_icon_map_cache[cache_key]
		return true
	var skill_id := str(skill_names[step_index])
	var skill_icons: Dictionary = {}
	var cached_icons: Variant = _transition_skill_icon_map_cache.get(cache_key, {})
	if cached_icons is Dictionary:
		skill_icons = cached_icons
	if skill_icons.get(skill_id, null) is Texture2D:
		_transition_skill_icon_map_cache[cache_key] = skill_icons
		_resource_cache[cache_key] = skill_icons
		return true
	var temp_key := _get_transition_skill_icon_temp_key(cache_key, skill_id)
	var spec := _texture_spec([temp_key], str(paths[skill_id]))
	if not _prewarm_texture_spec_step(spec):
		return false
	var texture: Variant = _resource_cache.get(temp_key, null)
	_resource_cache.erase(temp_key)
	_transition_skill_icon_temp_keys.erase(temp_key)
	if not (texture is Texture2D):
		_transition_skill_icon_map_cache[cache_key] = skill_icons
		_resource_cache[cache_key] = skill_icons
		return true
	skill_icons[skill_id] = SkillOrbTextureNormalizer.normalize(
		skill_id,
		texture as Texture2D
	)
	_transition_skill_icon_map_cache[cache_key] = skill_icons
	_resource_cache[cache_key] = skill_icons
	return true


func _get_transition_skill_icon_temp_key(cache_key: String, skill_id: String) -> String:
	var temp_key := "__transition_skill_icon_texture.%s.%s" % [cache_key, skill_id]
	if not _transition_skill_icon_temp_keys.has(temp_key):
		_transition_skill_icon_temp_keys.append(temp_key)
	return temp_key


func _clear_transition_skill_icon_temp_keys() -> void:
	for key in _transition_skill_icon_temp_keys:
		_resource_cache.erase(key)
	_transition_skill_icon_temp_keys.clear()


func _get_selected_skill_icon_paths(character_type: String) -> Dictionary:
	match character_type:
		DEFAULT_CHARACTER_TYPE:
			return SMASHER_SKILL_ICON_PATHS
		VIPER_CHARACTER_TYPE:
			return VIPER_SKILL_ICON_PATHS
		COMMANDO_CHARACTER_TYPE:
			return COMMANDO_SKILL_ICON_PATHS
	return {}


func _get_selected_skill_icon_cache_key(character_type: String) -> String:
	match character_type:
		DEFAULT_CHARACTER_TYPE:
			return "smasher_skill_icon_textures"
		VIPER_CHARACTER_TYPE:
			return "viper_skill_icon_textures"
		COMMANDO_CHARACTER_TYPE:
			return "commando_skill_icon_textures"
	return ""


func _ensure_inactive_skill_icon_maps(character_type: String) -> void:
	if character_type != DEFAULT_CHARACTER_TYPE and not _resource_cache.has("smasher_skill_icon_textures"):
		_resource_cache["smasher_skill_icon_textures"] = {}
	if character_type != VIPER_CHARACTER_TYPE and not _resource_cache.has("viper_skill_icon_textures"):
		_resource_cache["viper_skill_icon_textures"] = {}
	if character_type != COMMANDO_CHARACTER_TYPE and not _resource_cache.has("commando_skill_icon_textures"):
		_resource_cache["commando_skill_icon_textures"] = {}


func _get_selected_character_type(context: Dictionary) -> String:
	return _normalize_character_type(context.get("selected_character_type", DEFAULT_CHARACTER_TYPE))


func _get_current_stage(context: Dictionary) -> int:
	return max(1, int(context.get("current_stage", 1)))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _normalize_character_type(value: Variant) -> String:
	return _character_runtime.normalize(value)


func _should_include_all_characters(context: Dictionary) -> bool:
	return bool(context.get("include_all_characters", context.is_empty()))


func _should_include_all_stages(context: Dictionary) -> bool:
	return bool(context.get("include_all_stages", context.is_empty()))


func _should_include_result_sheets(context: Dictionary) -> bool:
	return bool(context.get("include_result_sheets", context.is_empty()))
