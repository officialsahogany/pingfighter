extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

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

# Stage 1 boss = Dalji. Walk uses two separate sheets (left + right, no runtime
# mirror). Ball-contact "hit" uses the attack sheet; stun stays separate for
# future real stun/electrocution states. See CLAUDE.md's Dalji sprite contract
# entries for the sheet specs this file mirrors.
const DALJI_BOSS_WALK_LEFT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_walk_left.png"
const DALJI_BOSS_WALK_RIGHT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_walk_right.png"
const DALJI_BOSS_IDLE_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_idle.png"
const DALJI_BOSS_ATTACK_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_attack.png"
const DALJI_BOSS_STUN_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_stun.png"
const DALJI_BOSS_WHIP_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_whip.png"

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

	var dalji_walk_left: Texture2D = _load_texture_resource(DALJI_BOSS_WALK_LEFT_PATH)
	var dalji_walk_right: Texture2D = _load_texture_resource(DALJI_BOSS_WALK_RIGHT_PATH)
	var dalji_idle: Texture2D = _load_texture_resource(DALJI_BOSS_IDLE_PATH)
	var dalji_attack: Texture2D = _load_texture_resource(DALJI_BOSS_ATTACK_PATH)
	var dalji_stun: Texture2D = _load_texture_resource(DALJI_BOSS_STUN_PATH)
	var dalji_whip: Texture2D = _load_texture_resource(DALJI_BOSS_WHIP_PATH)

	return {
		"player_sprite_texture": _load_texture_resource(PLAYER_SPRITE_PATH),
		"player_idle_sprite_texture": _load_texture_resource(PLAYER_IDLE_SPRITE_PATH),
		"player_hit_sprite_texture": _load_texture_resource(PLAYER_HIT_SPRITE_PATH),
		"player_hit_left_strip_texture": _load_texture_resource(PLAYER_HIT_LEFT_STRIP_PATH),
		"player_hit_right_strip_texture": _load_texture_resource(PLAYER_HIT_RIGHT_STRIP_PATH),
		"boss_walk_left_sheet": dalji_walk_left,
		"boss_walk_right_sheet": dalji_walk_right,
		"boss_idle_sheet": dalji_idle,
		"boss_attack_sheet": dalji_attack,
		"boss_stun_sheet": dalji_stun,
		"boss_whip_sheet": dalji_whip,
		# Legacy keys preserved so non-renderer call sites (boss_has_sprite check,
		# hit-trigger predicate) keep working without per-call updates.
		"boss_sprite_sheet": dalji_walk_right,
		"boss_hit_sprite_sheet": dalji_attack,
		"pingpong_ball_texture": _load_texture_resource(PINGPONG_BALL_TEXTURE_PATH),
		"gauge_orb_frame_texture": _load_texture_resource(GAUGE_ORB_FRAME_TEXTURE_PATH),
		"dash_token_frame_texture": _load_texture_resource(DASH_TOKEN_FRAME_TEXTURE_PATH),
		"skill_orb_frame_texture": _load_texture_resource(SKILL_ORB_FRAME_TEXTURE_PATH),
		"smasher_skill_cluster_frame_texture": _load_texture_resource(SMASHER_SKILL_CLUSTER_FRAME_TEXTURE_PATH),
		"smasher_skill_icon_textures": skill_icons,
	}


func _load_texture_resource(path: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing sprite at %s",
		"Failed to load texture at %s"
	)
