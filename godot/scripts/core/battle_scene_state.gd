extends RefCounted

const DEFAULT_VALUES: Dictionary = {
	"ball_pos": Vector2.ZERO,
	"ball_vel": Vector2.ZERO,
	"ball_active": false,
	"ball_impact_boost": 1.0,
	"ball_boost_decay_rate": 0.975,
	"ball_min_boost": 0.70,
	"player_collision_cooldown": 0.0,
	"boss_collision_cooldown": 0.0,
	"vertical_bounce_count": 0,
	"ball_spin_strength": 0.0,
	"ball_spin_direction": 0,
	"drive_ball_active": false,
	"drive_hit_boss": false,
	"drive_speed_increase": 0.0,
	"drive_text_timer_frames": 0.0,
	"gameplay_frame_counter": 0,
	"ball_visual_type": "energy",
	"boost_charging_active": false,
	"poisoned_ball_overlay_active": false,
	"viper_knockback_overlay_active": false,
	"bomb_ball_loaded": false,
	"player_pos": Vector2.ZERO,
	"player_speed": 0.0,
	"player_paddle_width": 155.0,
	"player_paddle_height": 50.0,
	"player_paddle_scale": 1.0,
	"boss_pos": Vector2.ZERO,
	"boss_vel": 0.0,
	"current_stage": 1,
	"selected_character_type": "smasher",
	"ai_mode": "champion",
	"arena_mode_enabled": false,
	"weather_type": "",
	"selected_character_id": "ufo_player",
	"selected_runtime_character_id": "smasher",
	"selected_character_name": "스매셔",
	"active_item_slots": [],
	"smasher_skill_icon_textures": {},
	"viper_skill_icon_textures": {},
	"special_gauge": 0.0,
	"battle_textures": {},
	"runtime_perk_levels": {},
	"runtime_perk_pending_choices": 0,
	"runtime_perk_starpoints": 0,
	"runtime_perk_gold": 0,
	"runtime_perk_choice_active": false,
}

var values: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	values.clear()
	for key in DEFAULT_VALUES.keys():
		values[key] = _copy_default(DEFAULT_VALUES[key])


func has_key(key: String) -> bool:
	return DEFAULT_VALUES.has(key)


func get_value(key: String) -> Variant:
	if values.has(key):
		return values[key]
	if DEFAULT_VALUES.has(key):
		return _copy_default(DEFAULT_VALUES[key])
	return null


func set_value(key: String, value: Variant) -> void:
	if DEFAULT_VALUES.has(key):
		values[key] = value


func _copy_default(value: Variant) -> Variant:
	if value is Array:
		var array_value: Array = value
		return array_value.duplicate(true)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	return value
