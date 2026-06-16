extends RefCounted

const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
const PLAYER_WALK_LEFT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_rear_move_left_sd_blue_energy_glide_bodyweight_v9_mirror_from_right_4x2_160_clean.png"
const PLAYER_WALK_RIGHT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_rear_move_right_sd_blue_energy_glide_bodyweight_v9_4x2_160_clean.png"
const PLAYER_DASH_LEFT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_dash_left_rugby_shoulder_charge_autosprite_v4_mirror_from_right_4x2_160_clean.png"
const PLAYER_DASH_RIGHT_SPRITE_PATH := "res://assets/sprites/smasher/smasher_dash_right_rugby_shoulder_charge_autosprite_v4_4x2_160_clean.png"
const SMASHER_IDLE_SHEET_PATH := "res://assets/sprites/smasher/smasher_rear_idle_breathe_sd_idle_layout_autosprite_v2_4x2_160_clean.png"
const PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/smasher/smasher_rear_idle_breathe_sd_idle_layout_autosprite_v2_4x2_160_clean.png"
const SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH := "res://assets/sprites/characters/smasher/customization_debug/smasher_debug_paddle_overlay_sheet.png"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/smasher_victory_joydance_64f_autosprite_v6.png"
const SMASHER_WHEEL_BODY_SHEET_PATH := "res://assets/sprites/smasher/smasher_wheel_flame_blade_spin_16f_autosprite_v3.png"
const SMASHER_DEFEAT_SHEET_PATH := "res://assets/sprites/smasher/smasher_defeat_sad_expression_16f_autosprite_v4_scale80.png"
const PLAYER_HIT_SPRITE_PATH := "res://assets/sprites/smasher_hit_pose.png"
const PLAYER_HIT_LEFT_STRIP_PATH := "res://assets/sprites/smasher_hit_left_strip.png"
const PLAYER_HIT_RIGHT_STRIP_PATH := "res://assets/sprites/smasher_hit_right_strip.png"

# Smasher directional attack sheets: 4x4 grids, 16 frames, cell 160x160.
# Authored from the current subculture left/right walk sprites so colors,
# proportions, hover-board, shield, and paddle stay consistent.
const SMASHER_ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/smasher/smasher_attack_left_sheet_16f.png"
const SMASHER_ATTACK_RIGHT_SHEET_PATH := "res://assets/sprites/smasher/smasher_attack_right_sheet_16f.png"

# Legacy fallback: 4x2 grid, 8 frames, cell 344x384.
const SMASHER_ATTACK_SHEET_PATH := "res://assets/sprites/smasher/smasher_attack_sheet.png"
