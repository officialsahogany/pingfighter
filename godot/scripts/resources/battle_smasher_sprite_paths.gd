extends RefCounted

const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
# Walk rides the same rear_cloud SD family as idle/dash. The 2026-08-19 SD
# redraw refreshed idle/glide/dash together; only this walk pairing had been
# left on the 08-09 gemini_v2 sheet, whose hair silhouette and plain cloud
# read as a different character the moment the paddle starts moving.
# The sd_unified candidates stay rejected references: their left sheet is an
# independent draw (26px frame-to-frame motion), not a mirror of the right.
const PLAYER_WALK_LEFT_SPRITE_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_glide_left_autosprite_v1_mirror_4x2_160_clean.png"
const PLAYER_WALK_RIGHT_SPRITE_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_glide_right_autosprite_v1_4x2_160_clean.png"
const PLAYER_DASH_LEFT_SPRITE_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_dash_left_autosprite_v1_mirror_4x2_160_clean.png"
const PLAYER_DASH_RIGHT_SPRITE_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_dash_right_autosprite_v1_4x2_160_clean.png"
const SMASHER_IDLE_SHEET_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_idle_autosprite_v1_4x2_160_clean.png"
const PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/smasher/hanmiryang_rear_cloud_idle_autosprite_v1_4x2_160_clean.png"
const SMASHER_DEBUG_PADDLE_OVERLAY_SHEET_PATH := "res://assets/sprites/characters/smasher/customization_debug/smasher_debug_paddle_overlay_sheet.png"
const SMASHER_VICTORY_SHEET_PATH := "res://assets/sprites/smasher/hanmiryang_victory_dance_49f_7x7_160.png"
const SMASHER_WHEEL_BODY_SHEET_PATH := "res://assets/sprites/smasher/hanmiryang_pungun_cheonseonmu_spin_16f_4x4_160.png"
const SMASHER_DEFEAT_SHEET_PATH := "res://assets/sprites/smasher/hanmiryang_defeat_sad_sit_16f_4x4_160.png"
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
