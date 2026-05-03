extends RefCounted

const BattleContextReader := preload("res://scripts/core/battle_context_reader.gd")


func build(context: Dictionary, deps: Dictionary) -> Dictionary:
	var animation_state = deps.get("animation_state", null)
	var animation_context: Dictionary = animation_state.get_draw_context() if animation_state != null else {}
	var whip_state = deps.get("stage1_dalji_whip_skill_state", null)
	var whip_context: Dictionary = whip_state.get_draw_context() if whip_state != null and whip_state.has_method("get_draw_context") else {}
	var active_item_runtime = deps.get("active_item_runtime", null)
	var active_item_context: Dictionary = active_item_runtime.get_actor_draw_context() if active_item_runtime != null and active_item_runtime.has_method("get_actor_draw_context") else {}
	var dash_context: Dictionary = _get_dict(context.get("dash_snapshot", {}))
	var textures: Dictionary = _get_dict(context.get("textures", {}))
	var has_player_attack_sheet: bool = textures.get("player_attack_sheet", null) is Texture2D
	var actor_context := {
		"shake_offset": _get_vector2(context, "shake_offset", Vector2.ZERO),
		"width": float(context.get("width", 760.0)),
		"height": float(context.get("height", 750.0)),
		"play_left": float(context.get("play_left", 0.0)),
		"play_right": float(context.get("play_right", 760.0)),
		"dash_active": dash_context.get("active", false),
		"dash_timer": float(dash_context.get("timer", 0.0)),
		"dash_is_half": dash_context.get("is_half", false),
		"dash_direction": dash_context.get("direction", 0.0),
		"dash_recovering": dash_context.get("recovering", false),
		"dash_stun_timer": float(dash_context.get("stun_timer", 0.0)),
		"dash_recovery_total_frames": float(dash_context.get("recovery_total_frames", 0.0)),
		"dash_recovery_progress": float(dash_context.get("recovery_progress", 1.0)),
		"pillar_drawer": deps.get("pillar_drawer", null),
		"player_pos": _get_vector2(context, "player_pos", Vector2.ZERO),
		"player_speed": float(context.get("player_speed", 0.0)),
		"player_anim_clock": animation_context.get("player_anim_clock", 0.0),
		"player_paddle_size": _get_vector2(context, "player_paddle_size", Vector2.ZERO),
		"player_paddle_scale": float(context.get("player_paddle_scale", 1.0)),
		"player_hit_active": animation_context.get("player_hit_active", false),
		"player_hit_timer": animation_context.get("player_hit_timer", 0.0),
		"player_hit_side": animation_context.get("player_hit_side", -1),
		"player_hit_frame": animation_context.get("player_hit_frame", 0),
		"player_hit_frame_count": 8 if has_player_attack_sheet else 4,
		"player_hit_anim_duration": 0.40 if has_player_attack_sheet else 0.36,
		"player_idle_frame": animation_context.get("player_idle_frame", 0),
		"player_sprite_frame": animation_context.get("player_sprite_frame", 0),
		# Smasher contact-animation state ported from pingfighter.py
		# (`smasher_swing_intensity`, `smasher_shield_raise_timer`,
		# `smasher_left_raise_timer`). Renderers can read intensity to scale
		# lunge / squash, and the bell-strength fields drive procedural
		# shield / left-arm raise overlays during the follow-through window.
		"player_swing_intensity": animation_context.get("player_swing_intensity", 1.0),
		"player_shield_raise_timer": animation_context.get("player_shield_raise_timer", 0.0),
		"player_left_raise_timer": animation_context.get("player_left_raise_timer", 0.0),
		"player_shield_raise_strength": animation_context.get("player_shield_raise_strength", 0.0),
		"player_left_raise_strength": animation_context.get("player_left_raise_strength", 0.0),
		"player_hit_pose_strength": animation_context.get("player_hit_pose_strength", 0.0),
		"player_sprite_texture": _get_value(textures, "player_sprite_texture"),
		"player_idle_sprite_texture": _get_value(textures, "player_idle_sprite_texture"),
		"player_hit_sprite_texture": _get_value(textures, "player_hit_sprite_texture"),
		"player_hit_left_strip_texture": _get_value(textures, "player_hit_left_strip_texture"),
		"player_hit_right_strip_texture": _get_value(textures, "player_hit_right_strip_texture"),
		"player_attack_sheet": _get_value(textures, "player_attack_sheet"),
		"boss_pos": _get_vector2(context, "boss_pos", Vector2.ZERO),
		"boss_paddle_size": _get_vector2(context, "boss_paddle_size", Vector2.ZERO),
		"boss_hitbox_height": float(context.get("boss_hitbox_height", 0.0)),
		"boss_sprite_frame": animation_context.get("boss_sprite_frame", 0),
		"boss_facing": animation_context.get("boss_facing", 1),
		"boss_is_walking": animation_context.get("boss_is_walking", false),
		"boss_idle_frame": animation_context.get("boss_idle_frame", 0),
		"boss_hit_active": animation_context.get("boss_hit_active", false),
		"boss_hit_frame": animation_context.get("boss_hit_frame", 0),
		"boss_hit_facing": animation_context.get("boss_hit_facing", 1),
		"boss_walk_left_sheet": _get_value(textures, "boss_walk_left_sheet"),
		"boss_walk_right_sheet": _get_value(textures, "boss_walk_right_sheet"),
		"boss_idle_sheet": _get_value(textures, "boss_idle_sheet"),
		"boss_attack_sheet": _get_value(textures, "boss_attack_sheet"),
		"boss_stun_sheet": _get_value(textures, "boss_stun_sheet"),
		"boss_whip_sheet": _get_value(textures, "boss_whip_sheet"),
		"boss_sprite_sheet": _get_value(textures, "boss_sprite_sheet"),
		"boss_hit_sprite_sheet": _get_value(textures, "boss_hit_sprite_sheet"),
	}
	actor_context.merge(whip_context, true)
	actor_context.merge(active_item_context, true)
	return actor_context


func _get_value(source: Dictionary, key: String) -> Variant:
	return source.get(key, null)


func _get_dict(value: Variant) -> Dictionary:
	return BattleContextReader.get_dictionary(value)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return BattleContextReader.get_vector2(source, key, fallback)
