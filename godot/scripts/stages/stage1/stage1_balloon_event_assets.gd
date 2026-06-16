extends RefCounted

const NORMAL_BALLOON_SHEET_PATH := "res://assets/sprites/stage1/balloon/stage1_joseon_balloon_sheet_imagegen_v1.png"
const SPECIAL_BALLOON_SHEET_PATH := "res://assets/sprites/stage1/balloon/stage1_joseon_star_balloon_gold_sheet_v1.png"
const NORMAL_BALLOON_BODY_YAW_SHEET_PATH := "res://assets/sprites/stage1/balloon/stage1_joseon_balloon_body_yaw_sheet_imagegen_v4.png"
const SPECIAL_BALLOON_BODY_YAW_SHEET_PATH := "res://assets/sprites/stage1/balloon/stage1_joseon_star_balloon_gold_body_yaw_sheet_v1.png"
const BALLOON_POP_SHEET_PATH := "res://assets/sprites/stage1/balloon/stage1_joseon_balloon_pop_sheet_imagegen_v1.png"
const BALLOON_TEXTURE_PREWARM_STEPS := 5
const NORMAL_BALLOON_FRAME_COUNT := 8
const SPECIAL_BALLOON_FRAME_COUNT := 4
const BALLOON_YAW_FRAME_COUNT := 16
const BALLOON_POP_FRAME_COUNT := 6

const NORMAL_BALLOON_COLORS := [
	Color(1.0, 100.0 / 255.0, 100.0 / 255.0),
	Color(100.0 / 255.0, 1.0, 100.0 / 255.0),
	Color(100.0 / 255.0, 100.0 / 255.0, 1.0),
	Color(1.0, 100.0 / 255.0, 1.0),
	Color(100.0 / 255.0, 1.0, 1.0),
	Color(1.0, 200.0 / 255.0, 100.0 / 255.0),
	Color(200.0 / 255.0, 100.0 / 255.0, 1.0),
]
const STARPOINT_BALLOON_COLOR := Color(1.0, 232.0 / 255.0, 88.0 / 255.0)
