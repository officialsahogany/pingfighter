extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func can_player_block(owner: Object, ball_radius_fallback: float, player_width_fallback: float) -> bool:
	if owner == null:
		return false
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO)
	if player_pos == Vector2.ZERO:
		return false
	var ball_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "ball_size", ball_radius_fallback * 2.0)) * 0.5)
	var player_width: float = maxf(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", player_width_fallback)))
	return ball_pos.x >= player_pos.x - ball_radius and ball_pos.x <= player_pos.x + player_width + ball_radius
