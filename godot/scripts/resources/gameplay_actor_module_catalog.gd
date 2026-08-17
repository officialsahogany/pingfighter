extends RefCounted

const MODULES := {
	"smasher_combo_state": {
		"path": "res://scripts/characters/smasher_combo_state.gd",
		"label": "smasher combo state",
	},
	"smasher_combo_renderer": {
		"path": "res://scripts/characters/smasher_combo_renderer.gd",
		"label": "smasher combo renderer",
	},
	"smasher_skill_state": {
		"path": "res://scripts/characters/smasher_skill_state.gd",
		"label": "smasher skill state",
	},
	"viper_skill_state": {
		"path": "res://scripts/characters/viper_skill_state.gd",
		"label": "viper skill state",
	},
	"commando_skill_state": {
		"path": "res://scripts/characters/commando_skill_state.gd",
		"label": "commando skill state",
	},
	"blacksmith_skill_state": {
		"path": "res://scripts/characters/blacksmith_skill_state.gd",
		"label": "blacksmith skill state",
	},
	"blacksmith_thor_shield_state": {
		"path": "res://scripts/characters/blacksmith_thor_shield_state.gd",
		"label": "blacksmith thor shield state",
	},
	"commando_weapon_controller": {
		"path": "res://scripts/characters/commando_weapon_controller.gd",
		"label": "commando weapon controller",
	},
	"commando_emergency_supply_state": {
		"path": "res://scripts/characters/commando_emergency_supply_state.gd",
		"label": "commando emergency supply state",
	},
	"commando_firearm_runtime": {
		"path": "res://scripts/characters/commando_firearm_runtime.gd",
		"label": "commando firearm runtime",
	},
	"commando_supply_drop_state": {
		"path": "res://scripts/characters/commando_supply_drop_state.gd",
		"label": "commando supply drop state",
	},
	"viper_skill_runtime": {
		"path": "res://scripts/characters/viper_skill_runtime.gd",
		"label": "viper skill runtime",
	},
	"viper_jetpack_state": {
		"path": "res://scripts/characters/viper_jetpack_state.gd",
		"label": "viper jetpack state",
	},
	"optimus_energy_state": {
		"path": "res://scripts/characters/optimus_energy_state.gd",
		"label": "optimus energy state",
	},
	"player_character_runtime": {
		"path": "res://scripts/characters/player_character_runtime.gd",
		"label": "player character runtime",
	},
	"player_customization_overlay_renderer": {
		"path": "res://scripts/characters/player_customization_overlay_renderer.gd",
		"label": "player customization overlay renderer",
	},
	"runtime_perk_catalog": {
		"path": "res://scripts/characters/runtime_perk_catalog.gd",
		"label": "runtime perk catalog",
	},
	"runtime_perk_state": {
		"path": "res://scripts/characters/runtime_perk_state.gd",
		"label": "runtime perk state",
	},
	"dalji_vision_chosik_state": {
		"path": "res://scripts/characters/dalji_vision_chosik_state.gd",
		"label": "dalji vision Chosik state",
	},
	"cheongringwi_vision_chosik_state": {
		"path": "res://scripts/characters/cheongringwi_vision_chosik_state.gd",
		"label": "cheongringwi vision Chosik state",
	},
	"yeonmyo_vision_chosik_state": {
		"path": "res://scripts/characters/yeonmyo_vision_chosik_state.gd",
		"label": "yeonmyo vision Chosik state",
	},
	"smasher_plasma_state": {
		"path": "res://scripts/characters/smasher_plasma_state.gd",
		"label": "smasher plasma state",
	},
	"smasher_recovery_state": {
		"path": "res://scripts/characters/smasher_recovery_state.gd",
		"label": "smasher recovery state",
	},
	"smasher_cleanse_state": {
		"path": "res://scripts/characters/smasher_cleanse_state.gd",
		"label": "smasher cleanse state",
	},
	"smasher_warp_gate_state": {
		"path": "res://scripts/characters/smasher_warp_gate_state.gd",
		"label": "smasher warp gate state",
	},
	"smasher_wheel_state": {
		"path": "res://scripts/characters/smasher_wheel_state.gd",
		"label": "smasher wheel state",
	},
	"smasher_overdrive_state": {
		"path": "res://scripts/characters/smasher_overdrive_state.gd",
		"label": "smasher overdrive state",
	},
	"smasher_void_phantom_state": {
		"path": "res://scripts/characters/smasher_void_phantom_state.gd",
		"label": "smasher void phantom state",
	},
	"smasher_magnum_grip_state": {
		"path": "res://scripts/characters/smasher_magnum_grip_state.gd",
		"label": "smasher magnum grip state",
	},
	"smasher_dash_spirit_state": {
		"path": "res://scripts/characters/smasher_dash_spirit_state.gd",
		"label": "smasher dash spirit state",
	},
	"smasher_shield_kiting_state": {
		"path": "res://scripts/characters/smasher_shield_kiting_state.gd",
		"label": "smasher shield kiting state",
	},
	"monkey_blessing_delivery_state": {
		"path": "res://scripts/characters/monkey_blessing_delivery_state.gd",
		"label": "monkey blessing delivery state",
	},
	"commando_reload_delivery_state": {
		"path": "res://scripts/characters/commando_reload_delivery_state.gd",
		"label": "commando reload delivery state",
	},
	"laurel_leaf_shield_state": {
		"path": "res://scripts/characters/laurel_leaf_shield_state.gd",
		"label": "laurel leaf shield state",
	},
	"smasher_player_controller": {
		"path": "res://scripts/characters/smasher_player_controller.gd",
		"label": "smasher player controller",
	},
	"viper_player_controller": {
		"path": "res://scripts/characters/viper_player_controller.gd",
		"label": "viper player controller",
	},
	"commando_player_controller": {
		"path": "res://scripts/characters/commando_player_controller.gd",
		"label": "commando player controller",
	},
	"optimus_player_controller": {
		"path": "res://scripts/characters/optimus_player_controller.gd",
		"label": "optimus player controller",
	},
	"blacksmith_player_controller": {
		"path": "res://scripts/characters/blacksmith_player_controller.gd",
		"label": "blacksmith player controller",
	},
	"smasher_input_reader": {
		"path": "res://scripts/characters/smasher_input_reader.gd",
		"label": "smasher input reader",
	},
	"viper_input_reader": {
		"path": "res://scripts/characters/viper_input_reader.gd",
		"label": "viper input reader",
	},
	"commando_input_reader": {
		"path": "res://scripts/characters/commando_input_reader.gd",
		"label": "commando input reader",
	},
	"blacksmith_input_reader": {
		"path": "res://scripts/characters/blacksmith_input_reader.gd",
		"label": "blacksmith input reader",
	},
	"smasher_drive_input_state": {
		"path": "res://scripts/characters/smasher_drive_input_state.gd",
		"label": "smasher drive input state",
	},
	"smasher_drive_activation_controller": {
		"path": "res://scripts/characters/smasher_drive_activation_controller.gd",
		"label": "smasher drive activation controller",
	},
	"smasher_drive_bounce_state": {
		"path": "res://scripts/characters/smasher_drive_bounce_state.gd",
		"label": "smasher drive bounce state",
	},
	"smasher_drive_counter_state": {
		"path": "res://scripts/characters/smasher_drive_counter_state.gd",
		"label": "smasher drive counter state",
	},
	"smasher_power_smash_state": {
		"path": "res://scripts/characters/smasher_power_smash_state.gd",
		"label": "smasher power smash state",
	},
	"smasher_power_smash_activation_controller": {
		"path": "res://scripts/characters/smasher_power_smash_activation_controller.gd",
		"label": "smasher power smash activation controller",
	},
	"smasher_power_smash_motion_controller": {
		"path": "res://scripts/characters/smasher_power_smash_motion_controller.gd",
		"label": "smasher power smash motion controller",
	},
	"smasher_skill_feedback_renderer": {
		"path": "res://scripts/characters/smasher_skill_feedback_renderer.gd",
		"label": "smasher skill feedback renderer",
	},
	"smasher_skill_timing_monitor_renderer": {
		"path": "res://scripts/characters/smasher_skill_timing_monitor_renderer.gd",
		"label": "smasher skill timing monitor renderer",
	},
	"actor_animation_state": {
		"path": "res://scripts/characters/actor_animation_state.gd",
		"label": "actor animation state",
	},
	"boss_ai_state": {
		"path": "res://scripts/ai/boss_ai_state.gd",
		"label": "boss ai state",
	},
	"smasher_dash_state": {
		"path": "res://scripts/characters/smasher_dash_state.gd",
		"label": "smasher dash state",
	},
	"smasher_skill_config": {
		"path": "res://scripts/characters/smasher_skill_config.gd",
		"label": "smasher skill config",
	},
	"viper_skill_config": {
		"path": "res://scripts/characters/viper_skill_config.gd",
		"label": "viper skill config",
	},
	"commando_skill_config": {
		"path": "res://scripts/characters/commando_skill_config.gd",
		"label": "commando skill config",
	},
	"blacksmith_skill_config": {
		"path": "res://scripts/characters/blacksmith_skill_config.gd",
		"label": "blacksmith skill config",
	},
	"optimus_skill_config": {
		"path": "res://scripts/characters/optimus_skill_config.gd",
		"label": "optimus skill config",
	},
	"player_movement_state": {
		"path": "res://scripts/characters/player_movement_state.gd",
		"label": "player movement state",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
