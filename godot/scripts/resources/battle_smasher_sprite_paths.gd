extends RefCounted

const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
# 환격전 한미량 리스타일 (2026-07-22): rear-view SD, 근두운 구름 탑승.
# 구세대 서브컬처(smasher_rear_*_blue_energy / rugby_shoulder) 시트는 롤백
# 레퍼런스로 디스크에 보존. attack 계열은 아직 구세대 — 후속 슬라이스.
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
