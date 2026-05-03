extends RefCounted

const DEFAULT_CHARACTER := "smasher"
const SMASHER := "smasher"
const VIPER := "viper"


func normalize(character_type: Variant) -> String:
	var value: String = str(character_type).strip_edges().to_lower()
	if value == VIPER:
		return VIPER
	return SMASHER


func is_viper(character_type: Variant) -> bool:
	return normalize(character_type) == VIPER


func get_player_controller_key(character_type: Variant) -> String:
	if is_viper(character_type):
		return "viper_player_controller"
	return "smasher_player_controller"


func get_input_reader_key(character_type: Variant) -> String:
	if is_viper(character_type):
		return "viper_input_reader"
	return "smasher_input_reader"


func get_dash_state_key(_character_type: Variant) -> String:
	# The current Godot dash slice is character-neutral despite its legacy key.
	return "smasher_dash_state"


func get_combo_state_key(character_type: Variant) -> String:
	if is_viper(character_type):
		return ""
	return "smasher_combo_state"


func get_skill_config_key(character_type: Variant) -> String:
	if is_viper(character_type):
		return "viper_skill_config"
	return "smasher_skill_config"


func get_skill_state_key(character_type: Variant) -> String:
	if is_viper(character_type):
		return "viper_skill_state"
	return "smasher_skill_state"


func get_skill_icon_texture_key(character_type: Variant) -> String:
	if is_viper(character_type):
		return "viper_skill_icon_textures"
	return "smasher_skill_icon_textures"


func get_skill_cluster_frame_texture_key(_character_type: Variant) -> String:
	return "smasher_skill_cluster_frame_texture"


func get_base_movement_config(character_type: Variant) -> Dictionary:
	if is_viper(character_type):
		return {
			"paddle_speed": 3.0,
			"paddle_max_speed": 3.0,
			"paddle_accel": 0.38,
		}
	return {
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
	}


func get_player_render_context(character_type: Variant) -> Dictionary:
	if is_viper(character_type):
		return {
			"use_smasher_sprite_textures": false,
			"player_color": Color(0.38, 0.08, 0.68),
			"player_color_light": Color(0.72, 0.28, 1.0),
		}
	return {
		"use_smasher_sprite_textures": true,
		"player_color": Color(0.25, 0.45, 1.0),
		"player_color_light": Color(0.40, 0.60, 1.0),
	}
