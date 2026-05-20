extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0


func get_player_center(owner: Object) -> Vector2:
	return get_player_anchor(owner, 0.5)


func get_player_anchor(owner: Object, height_factor: float) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", _get_default_player_pos())
	var paddle_size: Vector2 = get_player_paddle_size(owner)
	return player_pos + Vector2(paddle_size.x * 0.5, paddle_size.y * height_factor)


func get_player_paddle_size(owner: Object) -> Vector2:
	return Vector2(
		max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH))),
		max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	)


func _get_default_player_pos() -> Vector2:
	return Vector2(FIELD_WIDTH * 0.5 - PLAYER_BASE_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)
