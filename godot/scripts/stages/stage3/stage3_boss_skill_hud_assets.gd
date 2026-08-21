extends RefCounted

const SKILLCARD_ATLAS_PATH := "res://assets/sprites/stage3/stage3_hwangyeokjeon_boss_skill_cards_imagegen_v1.png"
const SKILLCARD_ID_TO_INDEX := {
	"tear_shower": 0,
	"curse_chest": 1,
	"psycho_ball": 2,
	"cotton_throw": 4,
	"cotton_bomb": 5,
	"deadly_hug": 6,
	"heart_beam": 7,
	"mirror_world": 8,
	"size_shift": 9,
	"rabbit_projectile": 10,
}
const SKILLCARD_ATLAS_COLS := 4
const SKILLCARD_ATLAS_ROWS := 3
const SKILLCARD_ATLAS_FRAMES := 11
# Compatibility name retained for callers that still use the former one-row owner API.
const SKILLCARD_ATLAS_COLUMNS := SKILLCARD_ATLAS_COLS
const SKILLCARD_FRAME_SIZE := Vector2i(256, 96)
const SKILLCARD_ATLAS_SIZE := Vector2i(
	SKILLCARD_ATLAS_COLS * SKILLCARD_FRAME_SIZE.x,
	SKILLCARD_ATLAS_ROWS * SKILLCARD_FRAME_SIZE.y
)
