extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const SLINGSHOT_STONE_SHEET_PATH := "res://assets/sprites/effects/commando_slingshot_stone_projectile_sheet_imagegen_v1.png"
const SLINGSHOT_STONE_SHEET_COLS := 4
const SLINGSHOT_STONE_SHEET_ROWS := 3
const SLINGSHOT_STONE_VARIANTS_PER_LEVEL := 4
const SLINGSHOT_STONE_MIN_DRAW_DIAMETERS := {1: 22.0, 2: 27.0, 3: 32.0}
const BOWLING_TRAP_INSTALLED_TEXTURE_PATH := "res://assets/sprites/effects/commando_bowling_trap_installed_imagegen_v1.png"
const BOWLING_TRAP_CAPTURE_SHEET_PATH := "res://assets/sprites/effects/commando_bowling_trap_capture_sheet_autosprite_v1.png"
const BOWLING_TRAP_LAUNCH_SHEET_PATH := "res://assets/sprites/effects/commando_bowling_trap_launch_sheet_autosprite_v1.png"
const BOWLING_TRAP_SHEET_COLS := 4
const BOWLING_TRAP_SHEET_ROWS := 4
const BOWLING_TRAP_SHEET_FRAME_COUNT := 16
const SUPPORT_AIRCRAFT_TEXTURE_PATH := "res://assets/sprites/effects/commando_fire_support_aircraft_stealth_imagegen_v1.png"
const SUPPORT_BOMB_TEXTURE_PATH := "res://assets/sprites/effects/commando_fire_support_bomb_projectile_imagegen_v1.png"

const REMASTER_TEXTURE_FAMILIES := [
	"muzzle_glow",
	"impact_burst",
	"impact_ring",
	"lingering_field_glow",
	"projectile_silhouette",
	"bowling_trap_claw",
	"drone_rotor",
	"support_aircraft",
	"support_bomb_projectile",
	"support_airstrike_explosion",
]

const REQUIRED_VISUAL_FAMILIES := [
	"pistol",
	"commando_pistol",
	"ak47",
	"bazooka",
	"net_gun",
	"fire_support",
	"bowling_trap",
	"suicide_drone",
]


static func load_slingshot_stone_texture() -> Texture2D:
	return ProjectResourceLoader.load_texture(
		SLINGSHOT_STONE_SHEET_PATH,
		"Missing Commando slingshot stone sheet at %s",
		"Failed to load Commando slingshot stone sheet at %s"
	)


static func load_bowling_trap_installed_texture() -> Texture2D:
	return ProjectResourceLoader.load_texture(
		BOWLING_TRAP_INSTALLED_TEXTURE_PATH,
		"Missing Commando bowling trap installed texture at %s",
		"Failed to load Commando bowling trap installed texture at %s"
	)


static func load_bowling_trap_capture_sheet_texture() -> Texture2D:
	return ProjectResourceLoader.load_texture(
		BOWLING_TRAP_CAPTURE_SHEET_PATH,
		"Missing Commando bowling trap capture sheet at %s",
		"Failed to load Commando bowling trap capture sheet at %s"
	)


static func load_bowling_trap_launch_sheet_texture() -> Texture2D:
	return ProjectResourceLoader.load_texture(
		BOWLING_TRAP_LAUNCH_SHEET_PATH,
		"Missing Commando bowling trap launch sheet at %s",
		"Failed to load Commando bowling trap launch sheet at %s"
	)


static func load_support_aircraft_texture() -> Texture2D:
	return ProjectResourceLoader.load_texture(
		SUPPORT_AIRCRAFT_TEXTURE_PATH,
		"Missing Commando fire-support stealth aircraft texture at %s",
		"Failed to load Commando fire-support stealth aircraft texture at %s"
	)


static func load_support_bomb_texture() -> Texture2D:
	return ProjectResourceLoader.load_texture(
		SUPPORT_BOMB_TEXTURE_PATH,
		"Missing Commando fire-support bomb projectile texture at %s",
		"Failed to load Commando fire-support bomb projectile texture at %s"
	)
