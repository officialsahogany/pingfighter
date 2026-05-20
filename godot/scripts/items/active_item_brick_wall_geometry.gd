extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const BRICK_WALL_WIDTH := 80.0
const BRICK_WALL_HEIGHT := 20.0
const BRICK_WALL_BOTTOM_Y := FIELD_HEIGHT - 7.0


func build_wall_rect(owner: Object, mythic_item_runtime: Object = null) -> Rect2:
	var fallback_pos := Vector2(FIELD_WIDTH * 0.5 - PLAYER_BASE_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", fallback_pos)
	var paddle_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var player_center_x: float = player_pos.x + paddle_width * 0.5
	var wall_width: float = get_wall_width(mythic_item_runtime)
	var x: float = clamp(player_center_x - wall_width * 0.5, 0.0, max(0.0, FIELD_WIDTH - wall_width))
	var y: float = clamp(BRICK_WALL_BOTTOM_Y - BRICK_WALL_HEIGHT, 0.0, max(0.0, FIELD_HEIGHT - BRICK_WALL_HEIGHT))
	return Rect2(Vector2(x, y), Vector2(wall_width, BRICK_WALL_HEIGHT))


func get_wall_width(mythic_item_runtime: Object = null) -> float:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_brick_wall_width"):
		return max(1.0, float(mythic_item_runtime.get_brick_wall_width(BRICK_WALL_WIDTH)))
	return BRICK_WALL_WIDTH


func get_gauge_center(owner: Object, wall_rect: Rect2) -> Vector2:
	var fallback_pos := Vector2(FIELD_WIDTH * 0.5 - PLAYER_BASE_PADDLE_WIDTH * 0.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", fallback_pos)
	var gauge_y: float = clamp(player_pos.y - 30.0, 18.0, FIELD_HEIGHT - 64.0)
	return Vector2(wall_rect.position.x + wall_rect.size.x * 0.5, gauge_y)
