extends RefCounted

const BASE_TEXTURE_PATH := "res://assets/sprites/hud/stage3_layered_cyber_menhera_base_imagegen_v4.png"
const AMBIENT_TEXTURE_PATH := "res://assets/sprites/hud/stage3_menhera_ambient_sprites_imagegen_v3.png"
const CENTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/stage3_center_frame_imagegen_v2.png"
const AMBIENT_SOURCE_REGIONS := [
	Rect2(184.0, 183.0, 158.0, 155.0),
	Rect2(583.0, 100.0, 162.0, 312.0),
	Rect2(1027.0, 121.0, 139.0, 266.0),
	Rect2(1432.0, 124.0, 143.0, 284.0),
	Rect2(180.0, 544.0, 123.0, 196.0),
	Rect2(567.0, 623.0, 184.0, 68.0),
	Rect2(981.0, 546.0, 188.0, 200.0),
	Rect2(1386.0, 576.0, 195.0, 146.0),
]
const CENTER_FRAME_WINDOW_RECT := Rect2(172.0, 115.0, 971.0, 932.0)
const PREWARM_STEP_COUNT := 4
