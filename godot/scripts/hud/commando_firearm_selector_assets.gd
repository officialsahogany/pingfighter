extends RefCounted

const HUD_FRAME_TEXTURE_PATH := "res://assets/ui/commando_firearm_hud_frame_v1.png"
const PISTOL_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_pistol_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png"
const BERETTA_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_beretta_firearm_icon_imagegen_v1.png"
const PISTOL_FIRE_RECOIL_SHEET_PATH := "res://assets/sprites/hud/commando_pistol_firearm_fire_recoil_sheet_autosprite_v1_realesrgan_animev3_hq1024.png"
const BERETTA_FIRE_RECOIL_SHEET_PATH := "res://assets/sprites/hud/commando_beretta_firearm_fire_recoil_sheet_autosprite_v1.png"
const AK47_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_ak47_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png"
const AK47_FIRE_RECOIL_SHEET_PATH := "res://assets/sprites/hud/commando_ak47_firearm_fire_recoil_sheet_autosprite_v2_realesrgan_animev3_hq1024.png"
const NET_GUN_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_net_gun_firearm_icon_imagegen_v1.png"
const NET_GUN_FIRE_RECOIL_SHEET_PATH := "res://assets/sprites/hud/commando_net_gun_firearm_fire_recoil_sheet_autosprite_v1.png"
const BAZOOKA_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_bazooka_firearm_icon_imagegen_v1_realesrgan_animev3_hq1024.png"
const BAZOOKA_FIRE_RECOIL_SHEET_PATH := "res://assets/sprites/hud/commando_bazooka_firearm_fire_recoil_sheet_autosprite_v2_realesrgan_animev3_hq1024.png"
const FIRE_SUPPORT_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_fire_support_firearm_icon_imagegen_v1.png"
const FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH := "res://assets/sprites/hud/commando_fire_support_radio_ammo_icon_imagegen_v1.png"
const BOWLING_TRAP_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_bowling_trap_firearm_icon_imagegen_v1.png"
const BOWLING_TRAP_INSTALL_SHEET_PATH := "res://assets/sprites/hud/commando_bowling_trap_firearm_install_sheet_autosprite_v1.png"
const BOWLING_TRAP_CAPTURE_SHEET_PATH := "res://assets/sprites/effects/commando_bowling_trap_capture_sheet_autosprite_v1.png"
const SUICIDE_DRONE_ICON_TEXTURE_PATH := "res://assets/sprites/hud/commando_suicide_drone_firearm_icon_imagegen_v1.png"
const SUICIDE_DRONE_HOVER_SHEET_PATH := "res://assets/sprites/hud/commando_suicide_drone_firearm_hover_sheet_autosprite_v1.png"

const WEAPON_TEXTURE_PATHS := [
	PISTOL_ICON_TEXTURE_PATH,
	BERETTA_ICON_TEXTURE_PATH,
	PISTOL_FIRE_RECOIL_SHEET_PATH,
	BERETTA_FIRE_RECOIL_SHEET_PATH,
	AK47_ICON_TEXTURE_PATH,
	AK47_FIRE_RECOIL_SHEET_PATH,
	NET_GUN_ICON_TEXTURE_PATH,
	NET_GUN_FIRE_RECOIL_SHEET_PATH,
	BAZOOKA_ICON_TEXTURE_PATH,
	BAZOOKA_FIRE_RECOIL_SHEET_PATH,
	FIRE_SUPPORT_ICON_TEXTURE_PATH,
	FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH,
	BOWLING_TRAP_ICON_TEXTURE_PATH,
	BOWLING_TRAP_INSTALL_SHEET_PATH,
	BOWLING_TRAP_CAPTURE_SHEET_PATH,
	SUICIDE_DRONE_ICON_TEXTURE_PATH,
	SUICIDE_DRONE_HOVER_SHEET_PATH,
]

const PANEL_ASSET_PATHS := {
	"hud_frame_path": HUD_FRAME_TEXTURE_PATH,
	"pistol_icon_path": PISTOL_ICON_TEXTURE_PATH,
	"beretta_icon_path": BERETTA_ICON_TEXTURE_PATH,
	"pistol_fire_recoil_sheet_path": PISTOL_FIRE_RECOIL_SHEET_PATH,
	"beretta_fire_recoil_sheet_path": BERETTA_FIRE_RECOIL_SHEET_PATH,
	"ak47_icon_path": AK47_ICON_TEXTURE_PATH,
	"ak47_fire_recoil_sheet_path": AK47_FIRE_RECOIL_SHEET_PATH,
	"net_gun_icon_path": NET_GUN_ICON_TEXTURE_PATH,
	"net_gun_fire_recoil_sheet_path": NET_GUN_FIRE_RECOIL_SHEET_PATH,
	"bazooka_icon_path": BAZOOKA_ICON_TEXTURE_PATH,
	"bazooka_fire_recoil_sheet_path": BAZOOKA_FIRE_RECOIL_SHEET_PATH,
	"fire_support_icon_path": FIRE_SUPPORT_ICON_TEXTURE_PATH,
	"fire_support_radio_ammo_icon_path": FIRE_SUPPORT_RADIO_AMMO_TEXTURE_PATH,
	"bowling_trap_icon_path": BOWLING_TRAP_ICON_TEXTURE_PATH,
	"bowling_trap_install_sheet_path": BOWLING_TRAP_INSTALL_SHEET_PATH,
	"bowling_trap_capture_sheet_path": BOWLING_TRAP_CAPTURE_SHEET_PATH,
	"suicide_drone_icon_path": SUICIDE_DRONE_ICON_TEXTURE_PATH,
	"suicide_drone_hover_sheet_path": SUICIDE_DRONE_HOVER_SHEET_PATH,
}


static func get_weapon_texture_paths() -> Array:
	return WEAPON_TEXTURE_PATHS.duplicate()


static func build_panel_asset_paths() -> Dictionary:
	return PANEL_ASSET_PATHS.duplicate()
