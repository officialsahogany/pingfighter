extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SkillOrbTextureNormalizer := preload("res://scripts/resources/skill_orb_texture_normalizer.gd")

const PINGPONG_BALL_TEXTURE_PATH := "res://assets/sprites/ball_runtime_128.png"
const GAUGE_ORB_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/gauge_orb_frame_imagegen_v1.png"
const DASH_TOKEN_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/dash_token_frame_imagegen_v2.png"
const SKILL_ORB_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/skill_orb_frame_imagegen_v1.png"
const SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/player_skill_gauge_full_frame_165_33_5_imagegen_v1.png"
const VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/player_skill_gauge_full_frame_155_32_5_imagegen_v1.png"
const STAGE1_CENTER_BACKGROUND_PATH := "res://assets/sprites/stage1/stage1_center_background_python_v1.png"
const STAGE1_CENTER_BORDER_PATH := "res://assets/sprites/stage1/stage1_center_danjeong_border_overlay_v1.png"
const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
const PLAYER_WALK_LEFT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_rear_move_left_sd_blue_energy_glide_bodyweight_v9_mirror_from_right_4x2_160_clean.png"
const PLAYER_WALK_RIGHT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_rear_move_right_sd_blue_energy_glide_bodyweight_v9_4x2_160_clean.png"
const PLAYER_DASH_LEFT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_dash_left_rugby_shoulder_charge_autosprite_v4_mirror_from_right_4x2_160_clean.png"
const PLAYER_DASH_RIGHT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_dash_right_rugby_shoulder_charge_autosprite_v4_4x2_160_clean.png"
const SMASHER_IDLE_SHEET_PATH := "res://assets/sprites/smasher/smasher_rear_idle_breathe_sd_idle_layout_autosprite_v2_4x2_160_clean.png"
const PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/smasher/smasher_rear_idle_breathe_sd_idle_layout_autosprite_v2_4x2_160_clean.png"
const SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH := "res://assets/sprites/characters/smasher/customization_debug/smasher_debug_paddle_overlay_sheet.png"
const OPTIMUS_PLAYER_IDLE_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_idle_sheet.png"
const OPTIMUS_PLAYER_WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_walk_left_sheet.png"
const OPTIMUS_PLAYER_WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_walk_right_sheet.png"
const OPTIMUS_PLAYER_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_attack_left_sheet.png"
const OPTIMUS_PLAYER_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/optimus/optimus_attack_right_sheet.png"
const OPTIMUS_OVERLAY_PADDLE_PATH := "res://assets/sprites/characters/optimus/overlays/optimus_paddle_energy_overlay_sheet.png"
const OPTIMUS_OVERLAY_CORE_GLOW_PATH := "res://assets/sprites/characters/optimus/overlays/optimus_core_glow_overlay_sheet.png"
const OPTIMUS_OVERLAY_BACK_PATH := "res://assets/sprites/characters/optimus/overlays/optimus_back_unit_overlay_sheet.png"
const OPTIMUS_OVERLAY_ACCESSORY_PATH := "res://assets/sprites/characters/optimus/overlays/optimus_accessory_overlay_sheet.png"
const OPTIMUS_OVERLAY_OUTFIT_ACCENT_PATH := "res://assets/sprites/characters/optimus/overlays/optimus_outfit_accent_overlay_sheet.png"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/smasher_victory_joydance_64f_autosprite_v6.png"
const SMASHER_WHEEL_BODY_SHEET_PATH := "res://assets/sprites/smasher/smasher_wheel_flame_blade_spin_16f_autosprite_v3.png"
const SMASHER_DEFEAT_SHEET_PATH := "res://assets/sprites/smasher/smasher_defeat_sad_expression_16f_autosprite_v4_scale80.png"
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
const OPTIMUS_CHARACTER_TYPE := "optimus"
const BLACKSMITH_CHARACTER_TYPE := "blacksmith"
const BLACKSMITH_PLAYER_IDLE_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_idle_back_autosprite_v3_custom_4x2_160_clean.png"
const BLACKSMITH_PLAYER_WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_sprint_dash_left_25deg_custom_v3_selected_mirror_from_right_4x2_160_clean.png"
const BLACKSMITH_PLAYER_WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_sprint_dash_right_25deg_custom_v3_selected_4x2_160_clean.png"
const BLACKSMITH_PLAYER_DASH_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_dash_slide_tackle_rear_left_hold_v4_mirror_from_right_4x2_160_clean.png"
const BLACKSMITH_PLAYER_DASH_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_dash_slide_tackle_rear_right_hold_v4_4x2_160_clean.png"
const BLACKSMITH_PLAYER_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_attack_left_shield_bash_autosprite_v2_16f_4x4_160_clean.png"
const BLACKSMITH_PLAYER_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_attack_right_hammer_smash_autosprite_v4_16f_4x4_160_clean.png"
const BLACKSMITH_PLAYER_THOR_SHIELD_DEPLOY_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_thor_shield_overhead_autosprite_v3_hybrid_4x4_160_clean.png"
const BLACKSMITH_THOR_SHIELD_STRETCH_TEXTURE_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_thor_shield_stretch_imagegen_v1.png"
const BLACKSMITH_PLAYER_VICTORY_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_victory_rear_autosprite_v1_49f_7x7_160_clean.png"
const BLACKSMITH_PLAYER_DEFEAT_SHEET_PATH := "res://assets/sprites/characters/blacksmith/blacksmith_defeat_rear_autosprite_v1_49f_7x7_160_clean.png"

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
const STAGE2_BOSS_QUAKE_STOMP_PATH := "res://assets/sprites/stage2/stage2_boss_jungle_quake_stomp_autosprite_v1_16f.png"
const STAGE2_BOSS_VICTORY_PATH := "res://assets/sprites/stage2/stage2_boss_victory_hop_autosprite_v1_64f.png"
const STAGE2_BOSS_DEFEAT_PATH := "res://assets/sprites/stage2/stage2_boss_defeat_collapse_autosprite_v1_64f.png"
const STAGE3_MENHERA_BOSS_WALK_PATH := "res://assets/sprites/stage3/menhera_boss_sheet.png"
const STAGE3_MENHERA_BOSS_ATTACK_PATH := "res://assets/sprites/stage3/menhera_boss_attack.png"
const STAGE3_MENHERA_BOSS_DASH_PATH := "res://assets/sprites/stage3/menhera_boss_dash.png"
const STAGE3_MENHERA_BOSS_VICTORY_PATH := "res://assets/sprites/stage3/menhera_boss_victory.png"
const STAGE3_MENHERA_BOSS_DEFEAT_PATH := "res://assets/sprites/stage3/menhera_boss_defeat.png"
const STAGE5_HONGRYUN_BOSS_SHEET_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_sheet.png"
const STAGE5_HONGRYUN_BOSS_ATTACK_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_attack.png"
const STAGE5_HONGRYUN_BOSS_DASH_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_dash.png"
const STAGE5_HONGRYUN_BOSS_TURN_PATH := "res://assets/sprites/stage5/stage5_hongryun_boss_turn.png"
const SMASHER_POWER_SMASHING_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_power_smashing_cutin_sheet.png"
const SMASHER_GHOST_SMASHING_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/smasher_ghost_smashing_cutin_sheet.png"
const VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH := "res://assets/ui/skill_cutin/viper_phantom_kick_cutin_sheet.png"
const SMASHER_DRIVE_CUTIN_BACKPLATE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_backplate.png"
const SMASHER_DRIVE_CUTIN_ARC_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_arc.png"
const SMASHER_DRIVE_CUTIN_CHARACTER_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_character.png"
const SMASHER_DRIVE_CUTIN_PARTICLE_PATH := "res://assets/ui/skill_cutin/drive/drive_cutin_particle.png"
const SMASHER_SHIELD_KITING_CUTIN_CHARACTER_PATH := "res://assets/ui/skill_cutin/smasher_shield_kiting_cutin_character.png"
const LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH := "res://assets/sprites/lingpet/effects/lingpet_acquire_resonance_backplate_imagegen_v1.png"

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
	"emergency_supply": "res://assets/sprites/skills/commando_emergency_supply_skill_orb.png",
	"commando_pistol": "res://assets/sprites/skills/commando_pistol_skill_orb.png",
	"net_gun": "res://assets/sprites/skills/commando_net_gun_skill_orb.png",
	"fire_support": "res://assets/sprites/skills/commando_fire_support_skill_orb.png",
	"bowling_trap": "res://assets/sprites/skills/commando_bowling_trap_skill_orb.png",
	"suicide_drone": "res://assets/sprites/skills/commando_suicide_drone_skill_orb.png",
	"ak47": "res://assets/sprites/skills/commando_ak47_skill_orb.png",
	"bazooka": "res://assets/sprites/skills/commando_bazooka_skill_orb.png",
}

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
	return FileAccess.file_exists("%s.import" % path) or ResourceLoader.exists(path, "Texture2D")


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


func _load_core_texture_step(step_index: int) -> void:
	var specs := _get_core_texture_specs()
	if step_index < 0 or step_index >= specs.size():
		return
	_load_texture_spec(specs[step_index])


func _prewarm_core_texture_step(step_index: int) -> bool:
	var specs := _get_core_texture_specs()
	if step_index < 0 or step_index >= specs.size():
		return true
	return _prewarm_texture_spec_step(specs[step_index])


func _load_core_textures() -> void:
	_resource_cache["pingpong_ball_texture"] = _load_texture_resource(PINGPONG_BALL_TEXTURE_PATH)
	_resource_cache["gauge_orb_frame_texture"] = _load_texture_resource(GAUGE_ORB_FRAME_TEXTURE_PATH)
	_resource_cache["dash_token_frame_texture"] = _load_texture_resource(DASH_TOKEN_FRAME_TEXTURE_PATH)
	_resource_cache["skill_orb_frame_texture"] = _load_texture_resource(SKILL_ORB_FRAME_TEXTURE_PATH)
	_resource_cache["smasher_skill_cluster_frame_texture"] = _load_texture_resource(SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH)
	_resource_cache["viper_skill_cluster_frame_texture"] = _load_texture_resource(VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH)
	_resource_cache["stage1_center_background_texture"] = _load_texture_resource(STAGE1_CENTER_BACKGROUND_PATH)
	_resource_cache["stage1_center_border_texture"] = _load_texture_resource(STAGE1_CENTER_BORDER_PATH)
	_resource_cache["lingpet_acquire_resonance_portal"] = _load_imported_texture_resource(LINGPET_ACQUIRE_RESONANCE_PORTAL_PATH)


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


func _load_player_texture_step(character_type: String, include_result_sheets: bool, step_index: int) -> void:
	var specs := _get_player_texture_specs(character_type, include_result_sheets)
	if step_index < 0 or step_index >= specs.size():
		return
	_load_texture_spec(specs[step_index])


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
	var specs := [
		_texture_spec(["player_sprite_texture"], PLAYER_SPRITE_PATH),
		_texture_spec(["player_walk_left_texture"], PLAYER_WALK_LEFT_SPRITE_PATH),
		_texture_spec(["player_walk_right_texture"], PLAYER_WALK_RIGHT_SPRITE_PATH),
		_texture_spec(["player_dash_left_texture"], PLAYER_DASH_LEFT_SPRITE_PATH),
		_texture_spec(["player_dash_right_texture"], PLAYER_DASH_RIGHT_SPRITE_PATH),
		_texture_spec(["player_idle_back_sheet", "player_idle_sprite_texture"], SMASHER_IDLE_SHEET_PATH),
		_texture_spec(["player_hit_sprite_texture"], PLAYER_HIT_SPRITE_PATH),
		_texture_spec(["player_hit_left_strip_texture"], PLAYER_HIT_LEFT_STRIP_PATH),
		_texture_spec(["player_hit_right_strip_texture"], PLAYER_HIT_RIGHT_STRIP_PATH),
		_texture_spec(["player_attack_left_sheet"], SMASHER_ATTACK_LEFT_SHEET_PATH),
		_texture_spec(["player_attack_right_sheet"], SMASHER_ATTACK_RIGHT_SHEET_PATH),
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
	_resource_cache["player_sprite_texture"] = _load_texture_resource(PLAYER_SPRITE_PATH)
	_resource_cache["player_walk_left_texture"] = _load_texture_resource(PLAYER_WALK_LEFT_SPRITE_PATH)
	_resource_cache["player_walk_right_texture"] = _load_texture_resource(PLAYER_WALK_RIGHT_SPRITE_PATH)
	_resource_cache["player_dash_left_texture"] = _load_texture_resource(PLAYER_DASH_LEFT_SPRITE_PATH)
	_resource_cache["player_dash_right_texture"] = _load_texture_resource(PLAYER_DASH_RIGHT_SPRITE_PATH)
	var idle_sheet: Texture2D = _load_texture_resource(SMASHER_IDLE_SHEET_PATH)
	_resource_cache["player_idle_back_sheet"] = idle_sheet
	_resource_cache["player_idle_sprite_texture"] = idle_sheet
	_resource_cache["player_hit_sprite_texture"] = _load_texture_resource(PLAYER_HIT_SPRITE_PATH)
	_resource_cache["player_hit_left_strip_texture"] = _load_texture_resource(PLAYER_HIT_LEFT_STRIP_PATH)
	_resource_cache["player_hit_right_strip_texture"] = _load_texture_resource(PLAYER_HIT_RIGHT_STRIP_PATH)
	_resource_cache["player_attack_left_sheet"] = _load_texture_resource(SMASHER_ATTACK_LEFT_SHEET_PATH)
	_resource_cache["player_attack_right_sheet"] = _load_texture_resource(SMASHER_ATTACK_RIGHT_SHEET_PATH)
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
	_resource_cache["boss_quake_stomp_sheet"] = _load_texture_resource(STAGE2_BOSS_QUAKE_STOMP_PATH)
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


func _load_stage_boss_texture_step(stage_id: int, include_result_sheets: bool, step_index: int) -> void:
	match stage_id:
		1:
			_load_stage1_boss_texture_step(include_result_sheets, step_index)
		2:
			_load_stage2_boss_texture_step(include_result_sheets, step_index)
		3:
			_load_stage3_boss_texture_step(include_result_sheets, step_index)
		5:
			_load_stage5_hongryun_boss_texture_step(include_result_sheets, step_index)


func _prewarm_stage_boss_texture_step(stage_id: int, include_result_sheets: bool, step_index: int) -> bool:
	var specs := _get_stage_boss_texture_specs(stage_id, include_result_sheets)
	if step_index < 0 or step_index >= specs.size():
		return true
	return _prewarm_texture_spec_step(specs[step_index])


func _load_stage1_boss_texture_step(include_result_sheets: bool, step_index: int) -> void:
	match step_index:
		0:
			_resource_cache["boss_walk_left_sheet"] = _load_texture_resource(DALJI_BOSS_WALK_LEFT_PATH)
		1:
			var walk_right: Texture2D = _load_texture_resource(DALJI_BOSS_WALK_RIGHT_PATH)
			_resource_cache["boss_walk_right_sheet"] = walk_right
			_resource_cache["boss_sprite_sheet"] = walk_right
		2:
			_resource_cache["boss_idle_sheet"] = _load_texture_resource(DALJI_BOSS_IDLE_PATH)
		3:
			var attack: Texture2D = _load_texture_resource(DALJI_BOSS_ATTACK_PATH)
			_resource_cache["boss_attack_sheet"] = attack
			_resource_cache["boss_hit_sprite_sheet"] = attack
		4:
			_resource_cache["boss_dash_sheet"] = _load_texture_resource(DALJI_BOSS_DASH_PATH)
		5:
			_resource_cache["boss_stun_sheet"] = _load_texture_resource(DALJI_BOSS_STUN_PATH)
		6:
			_resource_cache["boss_whip_sheet"] = _load_texture_resource(DALJI_BOSS_WHIP_PATH)
		7:
			_resource_cache["boss_paengi_top_whip_sheet"] = _load_texture_resource(DALJI_BOSS_PAENGI_TOP_WHIP_PATH)
		8:
			if include_result_sheets:
				_resource_cache["boss_victory_sheet"] = _load_texture_resource(DALJI_BOSS_VICTORY_PATH)
		9:
			if include_result_sheets:
				_resource_cache["boss_defeat_sheet"] = _load_texture_resource(DALJI_BOSS_DEFEAT_PATH)


func _load_stage2_boss_texture_step(include_result_sheets: bool, step_index: int) -> void:
	match step_index:
		0:
			_resource_cache["boss_walk_left_sheet"] = _load_texture_resource(STAGE2_BOSS_WALK_LEFT_PATH)
		1:
			var walk_right: Texture2D = _load_texture_resource(STAGE2_BOSS_WALK_RIGHT_PATH)
			_resource_cache["boss_walk_right_sheet"] = walk_right
			_resource_cache["boss_sprite_sheet"] = walk_right
		2:
			_resource_cache["boss_idle_sheet"] = _load_texture_resource(STAGE2_BOSS_IDLE_PATH)
		3:
			var attack: Texture2D = _load_texture_resource(STAGE2_BOSS_ATTACK_PATH)
			_resource_cache["boss_attack_sheet"] = attack
			_resource_cache["boss_hit_sprite_sheet"] = attack
		4:
			_resource_cache["boss_quake_stomp_sheet"] = _load_texture_resource(STAGE2_BOSS_QUAKE_STOMP_PATH)
		5:
			if include_result_sheets:
				_resource_cache["boss_victory_sheet"] = _load_texture_resource(STAGE2_BOSS_VICTORY_PATH)
		6:
			if include_result_sheets:
				_resource_cache["boss_defeat_sheet"] = _load_texture_resource(STAGE2_BOSS_DEFEAT_PATH)


func _load_stage3_boss_texture_step(include_result_sheets: bool, step_index: int) -> void:
	match step_index:
		0:
			var walk: Texture2D = _load_texture_resource(STAGE3_MENHERA_BOSS_WALK_PATH)
			_resource_cache["boss_sprite_sheet"] = walk
		1:
			var attack: Texture2D = _load_texture_resource(STAGE3_MENHERA_BOSS_ATTACK_PATH)
			_resource_cache["boss_attack_sheet"] = attack
			_resource_cache["boss_hit_sprite_sheet"] = attack
		2:
			_resource_cache["boss_dash_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_DASH_PATH)
		3:
			if include_result_sheets:
				_resource_cache["boss_victory_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_VICTORY_PATH)
		4:
			if include_result_sheets:
				_resource_cache["boss_defeat_sheet"] = _load_texture_resource(STAGE3_MENHERA_BOSS_DEFEAT_PATH)


func _load_stage5_hongryun_boss_texture_step(_include_result_sheets: bool, step_index: int) -> void:
	match step_index:
		0:
			var walk: Texture2D = _load_texture_resource(STAGE5_HONGRYUN_BOSS_SHEET_PATH)
			_resource_cache["boss_walk_left_sheet"] = walk
			_resource_cache["boss_walk_right_sheet"] = walk
			_resource_cache["boss_sprite_sheet"] = walk
		1:
			var attack: Texture2D = _load_texture_resource(STAGE5_HONGRYUN_BOSS_ATTACK_PATH)
			_resource_cache["boss_attack_sheet"] = attack
			_resource_cache["boss_hit_sprite_sheet"] = attack
		2:
			_resource_cache["boss_dash_sheet"] = _load_texture_resource(STAGE5_HONGRYUN_BOSS_DASH_PATH)
		3:
			_resource_cache["boss_turn_sheet"] = _load_texture_resource(STAGE5_HONGRYUN_BOSS_TURN_PATH)


func _load_stage5_hongryun_boss_textures() -> void:
	var walk: Texture2D = _load_texture_resource(STAGE5_HONGRYUN_BOSS_SHEET_PATH)
	var attack: Texture2D = _load_texture_resource(STAGE5_HONGRYUN_BOSS_ATTACK_PATH)
	_resource_cache["boss_walk_left_sheet"] = walk
	_resource_cache["boss_walk_right_sheet"] = walk
	_resource_cache["boss_sprite_sheet"] = walk
	_resource_cache["boss_attack_sheet"] = attack
	_resource_cache["boss_hit_sprite_sheet"] = attack
	_resource_cache["boss_dash_sheet"] = _load_texture_resource(STAGE5_HONGRYUN_BOSS_DASH_PATH)
	_resource_cache["boss_turn_sheet"] = _load_texture_resource(STAGE5_HONGRYUN_BOSS_TURN_PATH)


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
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == COMMANDO_CHARACTER_TYPE or normalized == "commando":
		return COMMANDO_CHARACTER_TYPE
	if normalized == OPTIMUS_CHARACTER_TYPE or normalized == "io":
		return OPTIMUS_CHARACTER_TYPE
	if normalized == BLACKSMITH_CHARACTER_TYPE or normalized == "baltor" or normalized == "kohaku":
		return BLACKSMITH_CHARACTER_TYPE
	if normalized == VIPER_CHARACTER_TYPE:
		return VIPER_CHARACTER_TYPE
	return DEFAULT_CHARACTER_TYPE


func _should_include_all_characters(context: Dictionary) -> bool:
	return bool(context.get("include_all_characters", context.is_empty()))


func _should_include_all_stages(context: Dictionary) -> bool:
	return bool(context.get("include_all_stages", context.is_empty()))


func _should_include_result_sheets(context: Dictionary) -> bool:
	return bool(context.get("include_result_sheets", context.is_empty()))
