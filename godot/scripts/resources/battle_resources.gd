extends RefCounted

const PINGPONG_BALL_TEXTURE_PATH := "res://assets/sprites/ball.png"
const GAUGE_ORB_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/gauge_orb_frame_imagegen_v1.png"
const DASH_TOKEN_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/dash_token_frame_imagegen_v2.png"
const SKILL_ORB_FRAME_TEXTURE_PATH := "res://assets/sprites/orbs/skill_orb_frame_imagegen_v1.png"
const SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH := "res://assets/sprites/hud/player_skill_gauge_full_frame_165_33_5_imagegen_v1.png"
const PLAYER_SPRITE_PATH := "res://assets/sprites/smasher_walk_strip.png"
const PLAYER_IDLE_SPRITE_PATH := "res://assets/sprites/smasher_idle_strip.png"
const PLAYER_HIT_SPRITE_PATH := "res://assets/sprites/smasher_hit_pose.png"
const PLAYER_HIT_LEFT_STRIP_PATH := "res://assets/sprites/smasher_hit_left_strip.png"
const PLAYER_HIT_RIGHT_STRIP_PATH := "res://assets/sprites/smasher_hit_right_strip.png"
const BOSS_SPRITE_SHEET_PATH := "res://assets/sprites/stage1walking3.png"
const BOSS_HIT_SPRITE_PATH := "res://assets/sprites/stage1hit.png"

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


func load_all() -> Dictionary:
	var skill_icons: Dictionary = {}
	for skill_name in SMASHER_SKILL_ICON_PATHS.keys():
		skill_icons[skill_name] = _load_texture_resource(SMASHER_SKILL_ICON_PATHS[skill_name])

	return {
		"player_sprite_texture": _load_texture_resource(PLAYER_SPRITE_PATH),
		"player_idle_sprite_texture": _load_texture_resource(PLAYER_IDLE_SPRITE_PATH),
		"player_hit_sprite_texture": _load_texture_resource(PLAYER_HIT_SPRITE_PATH),
		"player_hit_left_strip_texture": _load_texture_resource(PLAYER_HIT_LEFT_STRIP_PATH),
		"player_hit_right_strip_texture": _load_texture_resource(PLAYER_HIT_RIGHT_STRIP_PATH),
		"boss_sprite_sheet": _load_texture_resource(BOSS_SPRITE_SHEET_PATH),
		"boss_hit_sprite_sheet": _load_texture_resource(BOSS_HIT_SPRITE_PATH),
		"pingpong_ball_texture": _load_texture_resource(PINGPONG_BALL_TEXTURE_PATH),
		"gauge_orb_frame_texture": _load_texture_resource(GAUGE_ORB_FRAME_TEXTURE_PATH),
		"dash_token_frame_texture": _load_texture_resource(DASH_TOKEN_FRAME_TEXTURE_PATH),
		"skill_orb_frame_texture": _load_texture_resource(SKILL_ORB_FRAME_TEXTURE_PATH),
		"smasher_skill_cluster_frame_texture": _load_texture_resource(SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH),
		"smasher_skill_icon_textures": skill_icons,
	}


func _load_texture_resource(path: String) -> Texture2D:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("Missing sprite at %s" % path)
		return null
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	if ResourceLoader.exists(path):
		var texture_resource: Resource = load(path)
		if texture_resource is Texture2D:
			return texture_resource
	push_warning("Failed to load texture at %s" % path)
	return null
