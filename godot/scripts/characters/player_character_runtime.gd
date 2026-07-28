extends RefCounted

const DEFAULT_CHARACTER := "smasher"
const SMASHER := "smasher"
const VIPER := "viper"
const COMMANDO := "soldier"
const OPTIMUS := "optimus"
const BLACKSMITH := "blacksmith"


func normalize(character_type: Variant) -> String:
	var value: String = str(character_type).strip_edges().to_lower()
	if value == COMMANDO or value == "commando":
		return COMMANDO
	if value == OPTIMUS or value == "io":
		return OPTIMUS
	if value == BLACKSMITH or value == "baltor" or value == "kohaku":
		return BLACKSMITH
	if value == VIPER:
		return VIPER
	return SMASHER


func is_viper(character_type: Variant) -> bool:
	return normalize(character_type) == VIPER


func is_commando(character_type: Variant) -> bool:
	return normalize(character_type) == COMMANDO


func is_optimus(character_type: Variant) -> bool:
	return normalize(character_type) == OPTIMUS


func is_blacksmith(character_type: Variant) -> bool:
	return normalize(character_type) == BLACKSMITH


func get_player_controller_key(character_type: Variant) -> String:
	if is_blacksmith(character_type):
		return "blacksmith_player_controller"
	if is_commando(character_type):
		return "commando_player_controller"
	if is_optimus(character_type):
		return "optimus_player_controller"
	if is_viper(character_type):
		return "viper_player_controller"
	return "smasher_player_controller"


func get_input_reader_key(character_type: Variant) -> String:
	if is_blacksmith(character_type):
		return "blacksmith_input_reader"
	if is_commando(character_type):
		return "commando_input_reader"
	if is_viper(character_type):
		return "viper_input_reader"
	return "smasher_input_reader"


func get_dash_state_key(_character_type: Variant) -> String:
	# The current Godot dash slice is character-neutral despite its legacy key.
	return "smasher_dash_state"


func get_combo_state_key(character_type: Variant) -> String:
	if is_viper(character_type) or is_commando(character_type) or is_optimus(character_type) or is_blacksmith(character_type):
		return ""
	return "smasher_combo_state"


func get_skill_config_key(character_type: Variant) -> String:
	if is_blacksmith(character_type):
		return "blacksmith_skill_config"
	if is_commando(character_type):
		return "commando_skill_config"
	if is_optimus(character_type):
		return "optimus_skill_config"
	if is_viper(character_type):
		return "viper_skill_config"
	return "smasher_skill_config"


func get_skill_state_key(character_type: Variant) -> String:
	if is_blacksmith(character_type):
		return "blacksmith_skill_state"
	if is_commando(character_type):
		return "commando_skill_state"
	if is_optimus(character_type):
		return ""
	if is_viper(character_type):
		return "viper_skill_state"
	return "smasher_skill_state"


func get_skill_icon_texture_key(character_type: Variant) -> String:
	if is_blacksmith(character_type):
		return ""
	if is_commando(character_type):
		return "commando_skill_icon_textures"
	if is_optimus(character_type):
		return ""
	if is_viper(character_type):
		return "viper_skill_icon_textures"
	return "smasher_skill_icon_textures"


func get_skill_cluster_frame_texture_key(character_type: Variant, max_slots: int = 5) -> String:
	var slot_count: int = int(max_slots)
	if slot_count != 5:
		return ""
	if is_blacksmith(character_type):
		return ""
	if is_commando(character_type):
		return "smasher_skill_cluster_frame_texture"
	if is_optimus(character_type):
		return ""
	if is_viper(character_type):
		return "viper_skill_cluster_frame_texture"
	return "smasher_skill_cluster_frame_texture"


func get_base_movement_config(character_type: Variant) -> Dictionary:
	if is_commando(character_type):
		return {
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
		}
	if is_optimus(character_type):
		return {
			"paddle_speed": 4.0,
			"paddle_max_speed": 4.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.25,
			"paddle_turn_decel": 0.2,
		}
	if is_viper(character_type):
		return {
			"paddle_speed": 4.0,
			"paddle_max_speed": 4.0,
			"paddle_accel": 0.38,
			"paddle_decel": 0.38,
			"paddle_turn_decel": 1.0,
		}
	if is_blacksmith(character_type):
		return {
			"paddle_speed": 6.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
		}
	return {
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
		"paddle_decel": 0.5,
		"paddle_turn_decel": 1.0,
	}


func get_player_render_context(character_type: Variant) -> Dictionary:
	if is_commando(character_type):
		return {
			"use_smasher_sprite_textures": false,
			"texture_prefix": "commando",
			"player_color": Color(0.37, 0.57, 0.27),
			"player_color_light": Color(0.62, 0.82, 0.42),
		}
	if is_viper(character_type):
		return {
			"use_smasher_sprite_textures": false,
			"texture_prefix": "viper",
			"player_color": Color(0.38, 0.08, 0.68),
			"player_color_light": Color(0.72, 0.28, 1.0),
		}
	if is_optimus(character_type):
		return {
			"use_smasher_sprite_textures": false,
			"texture_prefix": "optimus",
			"player_color": Color(0.42, 0.78, 0.95),
			"player_color_light": Color(0.78, 0.96, 1.0),
		}
	if is_blacksmith(character_type):
		return {
			"use_smasher_sprite_textures": false,
			"texture_prefix": "blacksmith",
			"player_color": Color(0.72, 0.48, 0.18),
			"player_color_light": Color(1.0, 0.78, 0.36),
		}
	return {
		"use_smasher_sprite_textures": true,
		"player_color": Color(0.25, 0.45, 1.0),
		"player_color_light": Color(0.40, 0.60, 1.0),
	}
