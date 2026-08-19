extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

const PLAYER_DIRECTIONAL_ATTACK_ANIM_DURATION: float = 0.72
const PLAYER_LEGACY_ATTACK_ANIM_DURATION: float = 0.40
const SMASHER_DIRECTIONAL_WALK_FRAME_COUNT: int = 8
const SMASHER_DIRECTIONAL_WALK_FRAME_SPEED: float = 0.050
# Walk frames advance per pixel actually travelled (see
# player_actor_animation_state.gd). The budget is derived per character so that
# at that character's own top speed the cadence is identical to the previous
# time-based timer: px_per_frame = top_speed(px/physics-tick) * 60 * frame_speed.
# Below top speed it slows with the paddle; at a clamped wall it stops.
const MOVEMENT_REFERENCE_FPS: float = 60.0
const SMASHER_DIRECTIONAL_DASH_FRAME_COUNT: int = 8
const SMASHER_IDLE_FRAME_COUNT: int = 8
const COMMANDO_IDLE_FRAME_COUNT: int = 8
const DALJI_WALK_FRAME_COUNT: int = 16
const DALJI_WALK_FRAME_SPEED: float = 0.050
const BOSS_LEGACY_HIT_FRAME_COUNT: int = 8
const BOSS_LEGACY_HIT_FRAME_SPEED: float = 0.075
const BOSS_4X4_HIT_FRAME_COUNT: int = 16
const BOSS_4X4_HIT_FRAME_SPEED: float = 0.045

var _character_runtime: Object = PlayerCharacterRuntime.new()


func build_context(textures: Dictionary, character_type: Variant) -> Dictionary:
	var normalized_character: String = _character_runtime.normalize(character_type)
	var is_viper: bool = _character_runtime.is_viper(normalized_character)
	var is_commando: bool = _character_runtime.is_commando(normalized_character)
	var is_blacksmith: bool = _character_runtime.is_blacksmith(normalized_character)
	var has_directional_attack_sheet: bool = not is_commando and (
		(is_viper and (_has_texture(textures, "viper_player_attack_left_sheet") or _has_texture(textures, "viper_player_attack_right_sheet")))
		or (is_blacksmith and (_has_texture(textures, "blacksmith_player_attack_left_sheet") or _has_texture(textures, "blacksmith_player_attack_right_sheet")))
		or (not is_viper and (_has_texture(textures, "player_attack_left_sheet") or _has_texture(textures, "player_attack_right_sheet")))
	)
	var has_legacy_attack_sheet: bool = not is_viper and not is_commando and not is_blacksmith and _has_texture(textures, "player_attack_sheet")
	var has_commando_attack_sheet: bool = is_commando and _has_texture(textures, "commando_player_attack_sheet")
	var has_attack_sheet: bool = has_directional_attack_sheet or has_legacy_attack_sheet or has_commando_attack_sheet
	var has_directional_walk_sheet := false
	if is_commando:
		has_directional_walk_sheet = _has_texture(textures, "commando_player_walk_left_sheet") or _has_texture(textures, "commando_player_walk_right_sheet")
	elif is_blacksmith:
		has_directional_walk_sheet = _has_texture(textures, "blacksmith_player_walk_left_sheet") or _has_texture(textures, "blacksmith_player_walk_right_sheet")
	elif is_viper:
		has_directional_walk_sheet = _has_texture(textures, "viper_player_walk_left_sheet") or _has_texture(textures, "viper_player_walk_right_sheet")
	else:
		has_directional_walk_sheet = _has_texture(textures, "player_walk_left_texture") or _has_texture(textures, "player_walk_right_texture")
	var has_directional_dash_sheet: bool = (
		is_blacksmith
		and (
			_has_texture(textures, "blacksmith_player_dash_left_sheet")
			or _has_texture(textures, "blacksmith_player_dash_right_sheet")
		)
	) or (
		not is_viper
		and not is_commando
		and not is_blacksmith
		and (
			_has_texture(textures, "player_dash_left_texture")
			or _has_texture(textures, "player_dash_right_texture")
		)
	)
	var has_player_sprite := false
	if is_viper:
		has_player_sprite = _has_texture(textures, "viper_player_sprite_texture")
	elif is_commando:
		has_player_sprite = _has_texture(textures, "commando_player_walk_back_sheet") or has_directional_walk_sheet
	elif is_blacksmith:
		has_player_sprite = _has_texture(textures, "blacksmith_player_idle_sheet") or has_directional_walk_sheet
	else:
		has_player_sprite = _has_texture(textures, "player_sprite_texture") or has_directional_walk_sheet
	var has_smasher_idle_sheet: bool = not is_viper and not is_commando and not is_blacksmith and _has_texture(textures, "player_idle_back_sheet")
	var has_commando_idle_sheet: bool = is_commando and _has_texture(textures, "commando_player_idle_sheet")
	var has_viper_idle_sheet: bool = is_viper and _has_texture(textures, "viper_player_idle_sheet")
	var has_blacksmith_idle_sheet: bool = is_blacksmith and _has_texture(textures, "blacksmith_player_idle_sheet")
	var has_idle_sprite: bool = (has_viper_idle_sheet or _has_texture(textures, "viper_player_idle_sprite_texture")) if is_viper else (
		has_commando_idle_sheet if is_commando else (
		has_blacksmith_idle_sheet if is_blacksmith else (
		has_smasher_idle_sheet or _has_texture(textures, "player_idle_sprite_texture")
	)))
	var has_dalji_walk_sheet: bool = (
		_has_texture(textures, "boss_walk_left_sheet")
		or _has_texture(textures, "boss_walk_right_sheet")
	)
	var boss_attack_texture: Texture2D = _get_boss_attack_texture(textures)
	var has_boss_hit_sprite: bool = boss_attack_texture != null
	var boss_hit_frame_count: int = BOSS_4X4_HIT_FRAME_COUNT if _is_4x4_boss_attack_sheet(boss_attack_texture) else BOSS_LEGACY_HIT_FRAME_COUNT
	var boss_hit_frame_speed: float = BOSS_4X4_HIT_FRAME_SPEED if boss_hit_frame_count == BOSS_4X4_HIT_FRAME_COUNT else BOSS_LEGACY_HIT_FRAME_SPEED
	var sprite_frame_count: int = 6
	var sprite_frame_speed: float = 0.10
	if is_viper:
		sprite_frame_count = 8
		sprite_frame_speed = 0.10
	elif has_directional_walk_sheet:
		sprite_frame_count = SMASHER_DIRECTIONAL_WALK_FRAME_COUNT
		sprite_frame_speed = SMASHER_DIRECTIONAL_WALK_FRAME_SPEED

	return {
		"selected_character_type": normalized_character,
		"player_has_sprite": has_player_sprite,
		"player_has_idle_sprite": has_idle_sprite,
		"player_sprite_frame_count": sprite_frame_count,
		"player_sprite_animation_speed": sprite_frame_speed,
		"player_walk_distance_per_frame": _walk_distance_per_frame(normalized_character, sprite_frame_speed),
		"player_has_dash_sheet": has_directional_dash_sheet,
		"player_dash_frame_count": SMASHER_DIRECTIONAL_DASH_FRAME_COUNT if has_directional_dash_sheet else 0,
		"player_idle_frame_count": COMMANDO_IDLE_FRAME_COUNT if has_commando_idle_sheet else (SMASHER_IDLE_FRAME_COUNT if has_smasher_idle_sheet or has_blacksmith_idle_sheet else 8),
		"player_idle_animation_speed": 0.13 if is_viper else 0.15,
		"player_has_attack_sheet": has_attack_sheet,
		"player_hit_frame_count": (16 if is_blacksmith else (8 if is_viper else 16)) if has_directional_attack_sheet else (8 if has_legacy_attack_sheet else (8 if has_commando_attack_sheet else 4)),
		"player_hit_linear_frames": has_directional_attack_sheet,
		"player_hit_anim_duration": (
			PLAYER_LEGACY_ATTACK_ANIM_DURATION
			if (is_viper and has_directional_attack_sheet)
			else PLAYER_DIRECTIONAL_ATTACK_ANIM_DURATION
			if has_directional_attack_sheet
			else (
				PLAYER_DIRECTIONAL_ATTACK_ANIM_DURATION
				if has_commando_attack_sheet
				else (PLAYER_LEGACY_ATTACK_ANIM_DURATION if has_legacy_attack_sheet else 0.36)
			)
		),
		"boss_has_sprite": _has_texture(textures, "boss_sprite_sheet"),
		"boss_sprite_frame_count": DALJI_WALK_FRAME_COUNT if has_dalji_walk_sheet else 8,
		"boss_sprite_animation_speed": DALJI_WALK_FRAME_SPEED if has_dalji_walk_sheet else 0.10,
		"boss_has_hit_sprite": has_boss_hit_sprite,
		"boss_hit_frame_count": boss_hit_frame_count,
		"boss_hit_frame_speed": boss_hit_frame_speed,
	}


## Pixels of drawn travel per walk frame, so each character keeps its own
## full-speed cadence. Falls back to the shared 6.0 px/tick paddle speed when a
## character has no base movement config.
func _walk_distance_per_frame(character_type: String, frame_speed: float) -> float:
	var top_speed: float = 6.0
	if _character_runtime.has_method("get_base_movement_config"):
		var movement_config: Dictionary = _character_runtime.get_base_movement_config(character_type)
		top_speed = float(movement_config.get("paddle_max_speed", top_speed))
	return maxf(1.0, top_speed * MOVEMENT_REFERENCE_FPS * frame_speed)


func _has_texture(textures: Dictionary, key: String) -> bool:
	return textures.get(key, null) is Texture2D


func _get_boss_attack_texture(textures: Dictionary) -> Texture2D:
	var attack_texture: Variant = textures.get("boss_attack_sheet", null)
	if attack_texture is Texture2D:
		return attack_texture
	var legacy_hit_texture: Variant = textures.get("boss_hit_sprite_sheet", null)
	if legacy_hit_texture is Texture2D:
		return legacy_hit_texture
	return null


func _is_4x4_boss_attack_sheet(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var texture_size: Vector2 = texture.get_size()
	if texture_size == Vector2(768.0, 768.0):
		return false
	return (
		texture_size.x == texture_size.y
		and texture_size.x >= 512.0
		and int(texture_size.x) % 4 == 0
		and int(texture_size.y) % 4 == 0
	)
