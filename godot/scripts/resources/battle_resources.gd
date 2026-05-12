extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")

const PINGPONG_BALL_TEXTURE_PATH := "res://assets/sprites/ball.png"
const GAUGE_ORB_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/gauge_orb_frame_imagegen_v1.png"
const DASH_TOKEN_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/dash_token_frame_imagegen_v2.png"
const SKILL_ORB_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/skill_orb_frame_imagegen_v1.png"
const SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/player_skill_gauge_full_frame_165_33_5_imagegen_v1.png"
const VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/player_skill_gauge_full_frame_155_32_5_imagegen_v1.png"
const STAGE1_CENTER_BACKGROUND_PATH := "res://assets/sprites/stage1/stage1_center_background_python_v1.png"
const STAGE1_CENTER_BORDER_PATH := "res://assets/sprites/stage1/stage1_center_danjeong_border_overlay_v1.png"
const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
const PLAYER_WALK_LEFT_SPRITE_PATH := "res://assets/sprites/characters/smasher/smasher_subculture_left_walk_sheet.png"
const PLAYER_WALK_RIGHT_SPRITE_PATH := "res://assets/sprites/characters/smasher/smasher_subculture_right_walk_sheet.png"
const SMASHER_IDLE_SHEET_PATH := "res://assets/sprites/characters/smasher/smasher_subculture_idle_sheet.png"
const PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/characters/smasher/smasher_subculture_idle_sheet.png"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/smasher_victory_fullhelmet_64f_autosprite_v3.png"
const SMASHER_WHEEL_BODY_SHEET_PATH := SMASHER_VICTORY_SHEET_PATH
const SMASHER_DEFEAT_SHEET_PATH := "res://assets/sprites/smasher/smasher_defeat_sheet_autosprite_v1.png"
const PLAYER_HIT_SPRITE_PATH := "res://assets/sprites/smasher_hit_pose.png"
const PLAYER_HIT_LEFT_STRIP_PATH := "res://assets/sprites/smasher_hit_left_strip.png"
const PLAYER_HIT_RIGHT_STRIP_PATH := "res://assets/sprites/smasher_hit_right_strip.png"
const VIPER_PLAYER_SPRITE_PATH := "res://assets/sprites/viper_walk_strip.png"
const VIPER_PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/viper_idle_strip.png"
const VIPER_PLAYER_IDLE_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_idle_sheet.png"
const VIPER_PLAYER_WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_walk_sheet.png"
const VIPER_PLAYER_WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_walk_sheet.png"
const VIPER_PLAYER_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_attack_sheet.png"
const VIPER_PLAYER_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_attack_sheet.png"
const VIPER_PLAYER_WALL_CLING_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_wall_cling_sheet.png"
const VIPER_PLAYER_WALL_CLING_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_wall_cling_sheet.png"
const VIPER_PLAYER_WALL_FLIGHT_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_wall_flight_sheet.png"
const VIPER_PLAYER_WALL_FLIGHT_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_wall_flight_sheet.png"
const VIPER_PLAYER_FLYING_KICK_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_flying_kick_sheet.png"
const VIPER_PLAYER_FLYING_KICK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_flying_kick_sheet.png"
const VIPER_PLAYER_TUMBLE_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_tumble_sheet.png"
const VIPER_PLAYER_BLADE_FIRE_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_blade_fire_sheet.png"
const VIPER_PLAYER_THROW_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_throw_sheet.png"
const VIPER_PLAYER_HOVER_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_hover_sheet.png"
const VIPER_PLAYER_HOVER_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_hover_sheet.png"
const VIPER_PLAYER_UP_KICK_LEFT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_up_kick_sheet.png"
const VIPER_PLAYER_UP_KICK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_up_kick_sheet.png"
const VIPER_PLAYER_STUN_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_stun_sheet.png"
const VIPER_PLAYER_CONFUSION_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_confusion_sheet.png"
# Venom Edge dash sheet: 640x320 PNG, 4x2 grid, 8 frames, cell 160x160.
# Back-view forward-launch with both arm-blades spread wide ("wings out").
# Body size varies per cell to read the depth-into-screen burst toward boss.
# Center-anchor (no foot baseline) since character is fully airborne.
const VIPER_PLAYER_VENOM_EDGE_DASH_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_venom_edge_dash_sheet.png"
# Venom Edge strike sheet: 640x320 PNG, 4x2 grid, 8 frames, cell 160x160.
# UNIQUE FRONT-VIEW sheet — viper has appeared behind the boss and is turned
# toward the camera/player to slash the boss's eyes from behind. Face, fierce
# eyes, V-chevron on chest are visible. Cells 4-5 contain the bright cyan X-cut
# afterimage at peak slash. Foot-anchored (feet planted) since the strike is
# delivered from a standing pose behind the boss.
const VIPER_PLAYER_VENOM_EDGE_STRIKE_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_venom_edge_strike_sheet.png"
const VIPER_VICTORY_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_victory_gemini_v4_64f.png"
const VIPER_DEFEAT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_defeat_autosprite_v2_64f.png"
const VIPER_PLAYER_HIT_LEFT_STRIP_PATH := "res://assets/sprites/viper_hit_left_strip.png"
const VIPER_PLAYER_HIT_RIGHT_STRIP_PATH := "res://assets/sprites/viper_hit_right_strip.png"
const COMMANDO_PLAYER_IDLE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_idle_sheet.png"
const COMMANDO_PLAYER_WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_left_walk_sheet.png"
const COMMANDO_PLAYER_WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_right_walk_sheet.png"
const COMMANDO_PLAYER_WALK_BACK_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_back_walk_sheet.png"
const COMMANDO_PLAYER_BASE_GRIP_IDLE_BACK_SHEET_PATH := "res://assets/sprites/characters/commando/base_grip/commando_base_grip_idle_back_gemini_v1.png"
const COMMANDO_PLAYER_BASE_GRIP_WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/commando/base_grip/commando_base_grip_walk_left_gemini_v1.png"
const COMMANDO_PLAYER_BASE_GRIP_WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/commando/base_grip/commando_base_grip_walk_right_gemini_v1.png"
# Commando pistol-fire animation sheet: 1264x848 PNG, 4x2 grid, 8 frames,
# back view. Frames 0..3 = windup (driven by pistol_fire_delay_frames),
# frames 4..7 = post-shot muzzle / smoke / lower / ready (driven by
# pistol_post_fire_animation_frames). Frame 4 (muzzle flash) plays the
# moment `_play_fire_audio()` triggers gunshot.wav.
const COMMANDO_PLAYER_PISTOL_FIRE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_pistol_fire_sheet.png"
# Commando weapon-action sheets: 640x320 PNGs, 4x2 grids, 8 frames. Idle /
# walk remains empty-handed; these sheets appear only during the matching
# firing / placement / control trigger window.
const COMMANDO_PLAYER_AK47_FIRE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_ak47_fire_sheet.png"
const COMMANDO_PLAYER_BAZOOKA_FIRE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_bazooka_fire_sheet.png"
const COMMANDO_PLAYER_NET_GUN_FIRE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_net_gun_fire_sheet.png"
const COMMANDO_PLAYER_BOWLING_TRAP_PLACE_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_bowling_trap_place_sheet.png"
const COMMANDO_PLAYER_SUICIDE_DRONE_CONTROL_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_suicide_drone_control_sheet.png"
# Commando ball-strike attack sheet: 640x320 PNG, 4x2 grid, 8 frames, back
# view. Muay-Thai clothesline-style squat-uppercut: F0 standing ready,
# F1-F3 squat coil, F4-F5 rising uppercut (F5 = ball-contact peak),
# F6-F7 follow-through and recover. Pistol holstered on right hip,
# both hands free. Frame index is driven by `player_hit_timer` /
# `player_effective_hit_duration` mapped onto frames 0..7.
const COMMANDO_PLAYER_ATTACK_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_attack_sheet.png"
# Commando per-firearm weapon overlay sprites. The base sheet (idle / walk_*)
# already shows the pistol in the right hand, so "pistol" needs no overlay —
# it is the default visual. For every other equipped firearm, the matching
# overlay PNG is drawn on top of the base character at a per-direction anchor
# so the rifle / launcher / trap / drone replaces the visible pistol.
const COMMANDO_WEAPON_OVERLAY_AK47_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_ak47.png"
const COMMANDO_WEAPON_OVERLAY_BAZOOKA_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_bazooka.png"
const COMMANDO_WEAPON_OVERLAY_NET_GUN_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_net_gun.png"
const COMMANDO_WEAPON_OVERLAY_BOWLING_TRAP_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_bowling_trap.png"
const COMMANDO_WEAPON_OVERLAY_SUICIDE_DRONE_PATH := "res://assets/sprites/characters/commando/weapons/commando_weapon_overlay_suicide_drone.png"
const COMMANDO_WEAPON_B2_PISTOL_PATH := "res://assets/sprites/characters/commando/weapons_b2/commando_weapon_b2_pistol.png"
const COMMANDO_WEAPON_B2_AK47_PATH := "res://assets/sprites/characters/commando/weapons_b2/commando_weapon_b2_ak47.png"
const COMMANDO_WEAPON_B2_BAZOOKA_PATH := "res://assets/sprites/characters/commando/weapons_b2/commando_weapon_b2_bazooka.png"
const COMMANDO_WEAPON_B2_NET_GUN_PATH := "res://assets/sprites/characters/commando/weapons_b2/commando_weapon_b2_net_gun.png"
const COMMANDO_WEAPON_B2_BOWLING_TRAP_PATH := "res://assets/sprites/characters/commando/weapons_b2/commando_weapon_b2_bowling_trap.png"
const COMMANDO_WEAPON_B2_SUICIDE_DRONE_PATH := "res://assets/sprites/characters/commando/weapons_b2/commando_weapon_b2_suicide_drone.png"
const COMMANDO_WEAPON_B2V2_PISTOL_PATH := "res://assets/sprites/characters/commando/weapons_b2_perspective/commando_weapon_b2v2_pistol.png"
const COMMANDO_WEAPON_B2V2_AK47_PATH := "res://assets/sprites/characters/commando/weapons_b2_perspective/commando_weapon_b2v2_ak47.png"
const COMMANDO_WEAPON_B2V2_BAZOOKA_PATH := "res://assets/sprites/characters/commando/weapons_b2_perspective/commando_weapon_b2v2_bazooka.png"
const COMMANDO_WEAPON_B2V2_NET_GUN_PATH := "res://assets/sprites/characters/commando/weapons_b2_perspective/commando_weapon_b2v2_net_gun.png"
const COMMANDO_WEAPON_B2V2_BOWLING_TRAP_PATH := "res://assets/sprites/characters/commando/weapons_b2_perspective/commando_weapon_b2v2_bowling_trap.png"
const COMMANDO_WEAPON_B2V2_SUICIDE_DRONE_PATH := "res://assets/sprites/characters/commando/weapons_b2_perspective/commando_weapon_b2v2_suicide_drone.png"
const DEFAULT_CHARACTER_TYPE := "smasher"
const VIPER_CHARACTER_TYPE := "viper"
const COMMANDO_CHARACTER_TYPE := "soldier"

# Smasher directional attack sheets: 4x4 grids, 16 frames, cell 160x160.
# Authored from the current subculture left/right walk sprites so colors,
# proportions, hover-board, shield, and paddle stay consistent.
const SMASHER_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/smasher/smasher_attack_left_sheet_16f.png"
const SMASHER_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/smasher/smasher_attack_right_sheet_16f.png"

# Legacy fallback: 4x2 grid, 8 frames, cell 344x384.
const SMASHER_ATTACK_SHEET_PATH := "res://assets/sprites/smasher/smasher_attack_sheet.png"

# Stage 1 boss = Dalji. Walk uses two separate baked 16-frame AutoSprite run
# sheets with full keyposes, lifted knees, and a light bounce. No runtime mirror.
const DALJI_BOSS_WALK_LEFT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_run_left_16f_fullkeypose_autosprite_v15.png"
const DALJI_BOSS_WALK_RIGHT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_run_right_16f_fullkeypose_autosprite_v15.png"
const DALJI_BOSS_IDLE_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_idle.png"
const DALJI_BOSS_ATTACK_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_attack.png"
const DALJI_BOSS_DASH_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_dash.png"
const DALJI_BOSS_VICTORY_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_victory.png"
const DALJI_BOSS_DEFEAT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_defeat.png"
const DALJI_BOSS_STUN_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_stun.png"
const DALJI_BOSS_WHIP_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_whip.png"
const DALJI_BOSS_PAENGI_TOP_WHIP_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_paengi_top_whip_32f_autosprite_v1.png"
const STAGE2_BOSS_WALK_LEFT_PATH := "res://assets/sprites/stage2/stage2_boss_run_left_angled_autosprite_v1_16f.png"
const STAGE2_BOSS_WALK_RIGHT_PATH := "res://assets/sprites/stage2/stage2_boss_run_right_angled_autosprite_v1_16f.png"
const STAGE2_BOSS_IDLE_PATH := "res://assets/sprites/stage2/stage2_boss_idle_combat_breath_autosprite_v2_8f.png"
const STAGE2_BOSS_ATTACK_PATH := "res://assets/sprites/stage2/stage2_boss_attack_front_paddle_autosprite_v1_16f.png"
const STAGE2_BOSS_VICTORY_PATH := "res://assets/sprites/stage2/stage2_boss_victory_hop_autosprite_v1_64f.png"
const STAGE2_BOSS_DEFEAT_PATH := "res://assets/sprites/stage2/stage2_boss_defeat_collapse_autosprite_v1_64f.png"
const STAGE3_MENHERA_BOSS_WALK_PATH := "res://assets/sprites/stage3/menhera_boss_sheet.png"
const STAGE3_MENHERA_BOSS_ATTACK_PATH := "res://assets/sprites/stage3/menhera_boss_attack.png"
const STAGE3_MENHERA_BOSS_DASH_PATH := "res://assets/sprites/stage3/menhera_boss_dash.png"
const STAGE3_MENHERA_BOSS_VICTORY_PATH := "res://assets/sprites/stage3/menhera_boss_victory.png"
const STAGE3_MENHERA_BOSS_DEFEAT_PATH := "res://assets/sprites/stage3/menhera_boss_defeat.png"

const SMASHER_SKILL_ICON_PATHS := {
	"drive": "res://assets/sprites/skills/smasher_drive_skill_orb.png",
	"power_smashing": "res://assets/sprites/skills/smasher_power_smashing_skill_orb.png",
	"plasma": "res://assets/sprites/skills/smasher_plasma_skill_orb.png",
	"recovery": "res://assets/sprites/skills/smasher_recovery_skill_orb.png",
	"cleanse": "res://assets/sprites/skills/smasher_cleanse_skill_orb.png",
	"shield_kiting": "res://assets/sprites/skills/smasher_shield_kiting_skill_orb.png",
	"magnum_grip": "res://assets/sprites/skills/smasher_magnum_grip_skill_orb.png",
	"ghost_shot": "res://assets/sprites/skills/smasher_ghost_shot_skill_orb.png",
	"warp_gate": "res://assets/sprites/skills/smasher_warp_gate_skill_orb.png",
	"smasher_wheel": "res://assets/sprites/skills/smasher_wheel_skill_orb.png",
}

const VIPER_SKILL_ICON_PATHS := {
	"shadow_step": "res://assets/sprites/skills/viper_shadow_step_skill_orb.png",
	"blade_rush": "res://assets/sprites/skills/viper_blade_rush_skill_orb.png",
	"nerve_strike": "res://assets/sprites/skills/viper_nerve_strike_skill_orb.png",
	"dive_strike": "res://assets/sprites/skills/viper_emp_strike_skill_orb.png",
	"marshal_kick": "res://assets/sprites/skills/viper_marshal_kick_skill_orb.png",
	"phantom_kick": "res://assets/sprites/skills/viper_phantom_kick_skill_orb.png",
	"dark_blade": "res://assets/sprites/skills/viper_dark_blade_skill_orb.png",
	"chaos_spear": "res://assets/sprites/skills/viper_chaos_spear_skill_orb.png",
	"core_flip": "res://assets/sprites/skills/viper_core_flip_skill_orb.png",
	"dual_glitch": "res://assets/sprites/skills/viper_dual_glitch_skill_orb.png",
	"ignition_aura": "res://assets/sprites/skills/viper_ignition_aura_skill_orb.png",
}

const COMMANDO_SKILL_ICON_PATHS := {
	"supply_drop": "res://assets/sprites/skills/commando_supply_drop_skill_orb.png",
	"commando_pistol": "res://assets/sprites/skills/commando_pistol_skill_orb.png",
	"net_gun": "res://assets/sprites/skills/commando_net_gun_skill_orb.png",
	"fire_support": "res://assets/sprites/skills/commando_fire_support_skill_orb.png",
	"bowling_trap": "res://assets/sprites/skills/commando_bowling_trap_skill_orb.png",
	"suicide_drone": "res://assets/sprites/skills/commando_suicide_drone_skill_orb.png",
	"ak47": "res://assets/sprites/skills/commando_ak47_skill_orb.png",
	"bazooka": "res://assets/sprites/skills/commando_bazooka_skill_orb.png",
}

var _resource_cache: Dictionary = {}


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


func ensure_result_textures(character_type: String = DEFAULT_CHARACTER_TYPE, current_stage: int = 1) -> Dictionary:
	var selected_character_type := _normalize_character_type(character_type)
	if selected_character_type == DEFAULT_CHARACTER_TYPE:
		_resource_cache["player_victory_sheet"] = _load_texture_resource(SMASHER_VICTORY_SHEET_PATH)
		_resource_cache["player_defeat_sheet"] = _load_texture_resource(SMASHER_DEFEAT_SHEET_PATH)
	elif selected_character_type == VIPER_CHARACTER_TYPE:
		_resource_cache["player_victory_sheet"] = _load_texture_resource(VIPER_VICTORY_SHEET_PATH)
		_resource_cache["player_defeat_sheet"] = _load_texture_resource(VIPER_DEFEAT_SHEET_PATH)
	if current_stage == 1:
		_resource_cache["boss_victory_sheet"] = _load_texture_resource(DALJI_BOSS_VICTORY_PATH)
		_resource_cache["boss_defeat_sheet"] = _load_texture_resource(DALJI_BOSS_DEFEAT_PATH)
	if current_stage == 2:
		_resource_cache["boss_victory_sheet"] = _load_texture_resource(STAGE2_BOSS_VICTORY_PATH)
		_resource_cache["boss_defeat_sheet"] = _load_texture_resource(STAGE2_BOSS_DEFEAT_PATH)
	if current_stage == 3:
		_resource_cache["boss_victory_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_VICTORY_PATH)
		_resource_cache["boss_defeat_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_DEFEAT_PATH)
	return _resource_cache


func _load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing sprite at %s",
		"Failed to load texture at %s"
	)


func _load_core_textures() -> void:
	_resource_cache["pingpong_ball_texture"] = _load_texture_resource(PINGPONG_BALL_TEXTURE_PATH)
	_resource_cache["gauge_orb_frame_texture"] = _load_texture_resource(GAUGE_ORB_FRAME_TEXTURE_PATH)
	_resource_cache["dash_token_frame_texture"] = _load_texture_resource(DASH_TOKEN_FRAME_TEXTURE_PATH)
	_resource_cache["skill_orb_frame_texture"] = _load_texture_resource(SKILL_ORB_FRAME_TEXTURE_PATH)
	_resource_cache["smasher_skill_cluster_frame_texture"] = _load_texture_resource(SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH)
	_resource_cache["viper_skill_cluster_frame_texture"] = _load_texture_resource(VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH)
	_resource_cache["stage1_center_background_texture"] = _load_texture_resource(STAGE1_CENTER_BACKGROUND_PATH)
	_resource_cache["stage1_center_border_texture"] = _load_texture_resource(STAGE1_CENTER_BORDER_PATH)


func _load_player_textures(character_type: String, include_all_characters: bool, include_result_sheets: bool) -> void:
	if include_all_characters or character_type == DEFAULT_CHARACTER_TYPE:
		_load_smasher_player_textures(include_result_sheets and character_type == DEFAULT_CHARACTER_TYPE)
	if include_all_characters or character_type == VIPER_CHARACTER_TYPE:
		_load_viper_player_textures(include_result_sheets and character_type == VIPER_CHARACTER_TYPE)
	if include_all_characters or character_type == COMMANDO_CHARACTER_TYPE:
		_load_commando_player_textures()


func _load_smasher_player_textures(include_result_sheets: bool) -> void:
	_resource_cache["player_sprite_texture"] = _load_texture_resource(PLAYER_SPRITE_PATH)
	_resource_cache["player_walk_left_texture"] = _load_texture_resource(PLAYER_WALK_LEFT_SPRITE_PATH)
	_resource_cache["player_walk_right_texture"] = _load_texture_resource(PLAYER_WALK_RIGHT_SPRITE_PATH)
	_resource_cache["player_idle_back_sheet"] = _load_texture_resource(SMASHER_IDLE_SHEET_PATH)
	_resource_cache["player_idle_sprite_texture"] = _load_texture_resource(PLAYER_IDLE_SPRITE_PATH)
	_resource_cache["player_hit_sprite_texture"] = _load_texture_resource(PLAYER_HIT_SPRITE_PATH)
	_resource_cache["player_hit_left_strip_texture"] = _load_texture_resource(PLAYER_HIT_LEFT_STRIP_PATH)
	_resource_cache["player_hit_right_strip_texture"] = _load_texture_resource(PLAYER_HIT_RIGHT_STRIP_PATH)
	_resource_cache["player_attack_left_sheet"] = _load_texture_resource(SMASHER_ATTACK_LEFT_SHEET_PATH)
	_resource_cache["player_attack_right_sheet"] = _load_texture_resource(SMASHER_ATTACK_RIGHT_SHEET_PATH)
	_resource_cache["player_attack_sheet"] = _load_texture_resource(SMASHER_ATTACK_SHEET_PATH)
	_resource_cache["player_wheel_spin_sheet"] = _load_texture_resource(SMASHER_WHEEL_BODY_SHEET_PATH)
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


func _load_stage_textures(current_stage: int, include_all_stages: bool, include_result_sheets: bool) -> void:
	if include_all_stages:
		var stage_order := [1, 2, 3]
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


func _load_stage1_boss_textures(include_result_sheets: bool) -> void:
	var dalji_walk_left: Texture2D = _load_texture_resource(DALJI_BOSS_WALK_LEFT_PATH)
	var dalji_walk_right: Texture2D = _load_texture_resource(DALJI_BOSS_WALK_RIGHT_PATH)
	var dalji_attack: Texture2D = _load_texture_resource(DALJI_BOSS_ATTACK_PATH)
	_resource_cache["boss_walk_left_sheet"] = dalji_walk_left
	_resource_cache["boss_walk_right_sheet"] = dalji_walk_right
	_resource_cache["boss_idle_sheet"] = _load_texture_resource(DALJI_BOSS_IDLE_PATH)
	_resource_cache["boss_attack_sheet"] = dalji_attack
	_resource_cache["boss_dash_sheet"] = _load_texture_resource(DALJI_BOSS_DASH_PATH)
	_resource_cache["boss_stun_sheet"] = _load_texture_resource(DALJI_BOSS_STUN_PATH)
	_resource_cache["boss_whip_sheet"] = _load_texture_resource(DALJI_BOSS_WHIP_PATH)
	_resource_cache["boss_paengi_top_whip_sheet"] = _load_texture_resource(DALJI_BOSS_PAENGI_TOP_WHIP_PATH)
	if include_result_sheets:
		_resource_cache["boss_victory_sheet"] = _load_texture_resource(DALJI_BOSS_VICTORY_PATH)
		_resource_cache["boss_defeat_sheet"] = _load_texture_resource(DALJI_BOSS_DEFEAT_PATH)
	# Legacy keys preserved so non-renderer call sites (boss_has_sprite check,
	# hit-trigger predicate) keep working without per-call updates.
	_resource_cache["boss_sprite_sheet"] = dalji_walk_right
	_resource_cache["boss_hit_sprite_sheet"] = dalji_attack


func _load_stage2_boss_textures(include_result_sheets: bool = false) -> void:
	var walk_left: Texture2D = _load_texture_resource(STAGE2_BOSS_WALK_LEFT_PATH)
	var walk_right: Texture2D = _load_texture_resource(STAGE2_BOSS_WALK_RIGHT_PATH)
	var attack: Texture2D = _load_texture_resource(STAGE2_BOSS_ATTACK_PATH)
	_resource_cache["boss_walk_left_sheet"] = walk_left
	_resource_cache["boss_walk_right_sheet"] = walk_right
	_resource_cache["boss_idle_sheet"] = _load_texture_resource(STAGE2_BOSS_IDLE_PATH)
	_resource_cache["boss_attack_sheet"] = attack
	if include_result_sheets:
		_resource_cache["boss_victory_sheet"] = _load_texture_resource(STAGE2_BOSS_VICTORY_PATH)
		_resource_cache["boss_defeat_sheet"] = _load_texture_resource(STAGE2_BOSS_DEFEAT_PATH)
	_resource_cache["boss_sprite_sheet"] = walk_right
	_resource_cache["boss_hit_sprite_sheet"] = attack


func _load_stage3_boss_textures(include_result_sheets: bool = false) -> void:
	var walk: Texture2D = _load_texture_resource(STAGE3_MENHERA_BOSS_WALK_PATH)
	var attack: Texture2D = _load_texture_resource(STAGE3_MENHERA_BOSS_ATTACK_PATH)
	_resource_cache["boss_sprite_sheet"] = walk
	_resource_cache["boss_attack_sheet"] = attack
	_resource_cache["boss_hit_sprite_sheet"] = attack
	_resource_cache["boss_dash_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_DASH_PATH)
	if include_result_sheets:
		_resource_cache["boss_victory_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_VICTORY_PATH)
		_resource_cache["boss_defeat_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_DEFEAT_PATH)


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


func _get_selected_character_type(context: Dictionary) -> String:
	return _normalize_character_type(context.get("selected_character_type", DEFAULT_CHARACTER_TYPE))


func _get_current_stage(context: Dictionary) -> int:
	return max(1, int(context.get("current_stage", 1)))


func _normalize_character_type(value: Variant) -> String:
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == COMMANDO_CHARACTER_TYPE or normalized == "commando":
		return COMMANDO_CHARACTER_TYPE
	if normalized == VIPER_CHARACTER_TYPE:
		return VIPER_CHARACTER_TYPE
	return DEFAULT_CHARACTER_TYPE


func _should_include_all_characters(context: Dictionary) -> bool:
	return bool(context.get("include_all_characters", context.is_empty()))


func _should_include_all_stages(context: Dictionary) -> bool:
	return bool(context.get("include_all_stages", context.is_empty()))


func _should_include_result_sheets(context: Dictionary) -> bool:
	return bool(context.get("include_result_sheets", context.is_empty()))
