extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")


func build(context: Dictionary, deps: Dictionary) -> Dictionary:
	var feedback = deps.get("feedback", null)
	var animation_state = deps.get("animation_state", null)
	var animation_context: Dictionary = animation_state.get_draw_context() if animation_state != null else {}
	var dash_context: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	return {
		"shake_offset": _get_vector2(context, "shake_offset", Vector2.ZERO),
		"width": float(context.get("width", 760.0)),
		"height": float(context.get("height", 750.0)),
		"play_left": float(context.get("play_left", 0.0)),
		"play_right": float(context.get("play_right", 760.0)),
		"hit_flash_timer": feedback.get_hit_flash_timer() if feedback != null else 0.0,
		"dash_active": dash_context.get("active", false),
		"dash_is_half": dash_context.get("is_half", false),
		"dash_direction": dash_context.get("direction", 0.0),
		"pillar_drawer": deps.get("pillar_drawer", null),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_speed": float(context.get("player_speed", 0.0)),
		"player_anim_clock": animation_context.get("player_anim_clock", 0.0),
		"player_paddle_size": _get_vector2(context, "player_paddle_size", Vector2.ZERO),
		"player_hit_active": animation_context.get("player_hit_active", false),
		"player_hit_timer": animation_context.get("player_hit_timer", 0.0),
		"player_hit_side": animation_context.get("player_hit_side", -1),
		"player_hit_frame": animation_context.get("player_hit_frame", 0),
		"player_idle_frame": animation_context.get("player_idle_frame", 0),
		"player_sprite_frame": animation_context.get("player_sprite_frame", 0),
		"player_sprite_texture": _get_value(textures, "player_sprite_texture"),
		"player_idle_sprite_texture": _get_value(textures, "player_idle_sprite_texture"),
		"player_hit_sprite_texture": _get_value(textures, "player_hit_sprite_texture"),
		"player_hit_left_strip_texture": _get_value(textures, "player_hit_left_strip_texture"),
		"player_hit_right_strip_texture": _get_value(textures, "player_hit_right_strip_texture"),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2.ZERO),
		"boss_hitbox_height": float(context.get("boss_hitbox_height", 0.0)),
		"boss_sprite_frame": animation_context.get("boss_sprite_frame", 0),
		"boss_sprite_row": animation_context.get("boss_sprite_row", 1),
		"boss_hit_active": animation_context.get("boss_hit_active", false),
		"boss_hit_frame": animation_context.get("boss_hit_frame", 0),
		"boss_hit_row": animation_context.get("boss_hit_row", 1),
		"boss_sprite_sheet": _get_value(textures, "boss_sprite_sheet"),
		"boss_hit_sprite_sheet": _get_value(textures, "boss_hit_sprite_sheet"),
	}


func _get_value(source: Dictionary, key: String) -> Variant:
	return source.get(key, null)


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)
