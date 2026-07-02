extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const DEFAULT_PLAYER_PADDLE_SIZE := Vector2(155.0, 50.0)


func vector2_or_fallback(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func get_owner_player_paddle_center(owner: Object, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if owner == null:
		return fallback
	var player_pos: Vector2 = vector2_or_fallback(
		BattleSceneOwnerReader.get_value(owner, "player_pos", Vector2.ZERO),
		Vector2.ZERO
	)
	var player_size := Vector2(
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", DEFAULT_PLAYER_PADDLE_SIZE.x))),
		maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", DEFAULT_PLAYER_PADDLE_SIZE.y)))
	)
	return player_pos + player_size * 0.5


func get_starlight_tracking_delivery_pos(context: Dictionary) -> Vector2:
	var owner_value: Variant = context.get("owner", null)
	var owner: Object = null
	if owner_value is Object:
		owner = owner_value as Object
	var owner_player_pos := Vector2.ZERO
	var owner_paddle_size := DEFAULT_PLAYER_PADDLE_SIZE
	if owner != null:
		owner_player_pos = vector2_or_fallback(BattleSceneOwnerReader.get_value(owner, "player_pos", Vector2.ZERO), owner_player_pos)
		owner_paddle_size = Vector2(
			float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", owner_paddle_size.x)),
			float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", owner_paddle_size.y))
		)
	var player_pos := vector2_or_fallback(context.get("player_pos", owner_player_pos), owner_player_pos)
	var player_size := vector2_or_fallback(context.get("player_paddle_size", owner_paddle_size), owner_paddle_size)
	return player_pos + player_size * 0.5
