extends RefCounted

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
# Front-view sheet: viper has appeared behind the boss and is turned toward
# the camera/player to slash the boss's eyes from behind. Face, fierce eyes,
# and V-chevron on chest are visible. Cells 4-5 contain the bright cyan X-cut
# afterimage at peak slash. Foot-anchored since the strike is standing.
const VIPER_PLAYER_VENOM_EDGE_STRIKE_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_venom_edge_strike_sheet.png"

const VIPER_VICTORY_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_victory_gemini_v4_64f.png"
const VIPER_DEFEAT_SHEET_PATH := "res://assets/sprites/characters/viper/viper_subculture_defeat_autosprite_v2_64f.png"
const VIPER_PLAYER_HIT_LEFT_STRIP_PATH := "res://assets/sprites/viper_hit_left_strip.png"
const VIPER_PLAYER_HIT_RIGHT_STRIP_PATH := "res://assets/sprites/viper_hit_right_strip.png"
