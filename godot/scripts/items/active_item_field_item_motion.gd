extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_ITEM_RADIUS := 15.0
const FIELD_ITEM_COLLISION_SIZE := 30.0
const SPAWN_VELOCITY_CHOICES := [-4.0, -3.0, 3.0, 4.0]
const SPAWN_SPARK_DURATION_SEC := 1.0
const LUCKY_COIN_BONUS_OFFSET_CHOICES := [-40.0, -30.0, 30.0, 40.0]
const ADVANCE_SKIPPED_ALIVE := 0
const ADVANCE_ALIVE := 1
const ADVANCE_DEAD := 2


func roll_field_item_position() -> Vector2:
	return Vector2(
		randf_range(FIELD_ITEM_RADIUS, FIELD_WIDTH - FIELD_ITEM_RADIUS),
		randf_range(FIELD_ITEM_RADIUS, FIELD_HEIGHT - FIELD_ITEM_RADIUS)
	)


func roll_lucky_coin_bonus_position(anchor_position: Vector2 = Vector2.ZERO, use_anchor_offset: bool = false) -> Vector2:
	if not use_anchor_offset:
		return roll_field_item_position()
	return Vector2(
		clamp(
			anchor_position.x + float(LUCKY_COIN_BONUS_OFFSET_CHOICES[randi() % LUCKY_COIN_BONUS_OFFSET_CHOICES.size()]),
			FIELD_ITEM_RADIUS,
			FIELD_WIDTH - FIELD_ITEM_RADIUS
		),
		clamp(
			anchor_position.y + float(LUCKY_COIN_BONUS_OFFSET_CHOICES[randi() % LUCKY_COIN_BONUS_OFFSET_CHOICES.size()]),
			FIELD_ITEM_RADIUS,
			FIELD_HEIGHT - FIELD_ITEM_RADIUS
		)
	)


func build_field_item(item_data: Dictionary, position: Vector2) -> Dictionary:
	var stationary := bool(item_data.get("stationary_field_item", false))
	return {
		"item_data": item_data,
		"position": position,
		"velocity": Vector2.ZERO if stationary else Vector2(_roll_spawn_velocity_component(), _roll_spawn_velocity_component()),
		"angle_degrees": 0.0,
		"bounce_count": 0,
		"max_bounces": 2147483647 if stationary else randi_range(6, 9),
		"spawn_spark_timer": SPAWN_SPARK_DURATION_SEC,
		"spawn_skip_update_once": true,
		"stationary_field_item": stationary,
	}


func build_lucky_coin_bonus_field_item(item_data: Dictionary, position: Vector2) -> Dictionary:
	var field_item: Dictionary = build_field_item(item_data, position)
	field_item["lucky_bonus"] = true
	field_item["lucky_glow_timer"] = 0.0
	return field_item


func collect_items_near(field_items: Array, center: Vector2, radius: float) -> Dictionary:
	var picked_items: Array[Dictionary] = []
	var survivors: Array[Dictionary] = []
	for field_item_value in field_items:
		if not (field_item_value is Dictionary):
			continue
		var field_item: Dictionary = field_item_value
		var item_pos: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO)
		if item_pos.distance_to(center) <= radius:
			picked_items.append(field_item)
		else:
			survivors.append(field_item)
	return {
		"picked_items": picked_items,
		"survivors": survivors,
	}


func get_player_rect(owner: Object) -> Rect2:
	var player_paddle_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var player_paddle_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	return Rect2(
		BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO),
		Vector2(player_paddle_width, player_paddle_height)
	)


func get_dowsing_pendulum_context(registry: Object) -> Dictionary:
	var runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if runtime == null or not runtime.has_method("get_dowsing_pendulum_context"):
		return {}
	var context: Variant = runtime.get_dowsing_pendulum_context()
	if context is Dictionary and bool(context.get("active", false)):
		return context
	return {}


func advance_field_item(field_item: Dictionary, player_rect: Rect2, dowsing_context: Dictionary, delta: float) -> Dictionary:
	var advance_state: int = advance_field_item_in_place(field_item, player_rect, dowsing_context, delta)
	return {
		"field_item": field_item,
		"skipped": advance_state == ADVANCE_SKIPPED_ALIVE,
		"alive": advance_state != ADVANCE_DEAD,
		"item_rect": Rect2() if advance_state == ADVANCE_SKIPPED_ALIVE else get_field_item_rect(field_item),
	}


func advance_field_item_in_place(field_item: Dictionary, player_rect: Rect2, dowsing_context: Dictionary, delta: float) -> int:
	if bool(field_item.get("spawn_skip_update_once", false)):
		field_item["spawn_skip_update_once"] = false
		return ADVANCE_SKIPPED_ALIVE

	if _is_stationary_field_item(field_item):
		field_item["velocity"] = Vector2.ZERO
		field_item["angle_degrees"] = 0.0
		field_item["spawn_spark_timer"] = max(0.0, float(field_item.get("spawn_spark_timer", 0.0)) - delta)
		return ADVANCE_ALIVE

	var fps_scale: float = delta * 60.0
	var item_pos: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO)
	var item_vel: Vector2 = _get_vector2(field_item, "velocity", Vector2.ZERO)
	item_vel = apply_dowsing_pendulum_attraction(item_pos, item_vel, player_rect, dowsing_context, fps_scale)
	item_pos += item_vel * fps_scale
	var bounce_count: int = int(field_item.get("bounce_count", 0))

	if item_pos.x <= FIELD_ITEM_RADIUS or item_pos.x >= FIELD_WIDTH - FIELD_ITEM_RADIUS:
		item_pos.x = clamp(item_pos.x, FIELD_ITEM_RADIUS, FIELD_WIDTH - FIELD_ITEM_RADIUS)
		item_vel.x *= -1.0
		bounce_count += 1
	if item_pos.y <= FIELD_ITEM_RADIUS or item_pos.y >= FIELD_HEIGHT - FIELD_ITEM_RADIUS:
		item_pos.y = clamp(item_pos.y, FIELD_ITEM_RADIUS, FIELD_HEIGHT - FIELD_ITEM_RADIUS)
		item_vel.y *= -1.0
		bounce_count += 1

	field_item["position"] = item_pos
	field_item["velocity"] = item_vel
	field_item["bounce_count"] = bounce_count
	field_item["angle_degrees"] = fmod(float(field_item.get("angle_degrees", 0.0)) + 2.0 * fps_scale, 360.0)
	field_item["spawn_spark_timer"] = max(0.0, float(field_item.get("spawn_spark_timer", 0.0)) - delta)

	return ADVANCE_ALIVE if bounce_count < int(field_item.get("max_bounces", 10)) else ADVANCE_DEAD


func get_field_item_rect(field_item: Dictionary) -> Rect2:
	var item_pos: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO)
	var item_rect := Rect2(
		item_pos - Vector2(FIELD_ITEM_COLLISION_SIZE, FIELD_ITEM_COLLISION_SIZE) * 0.5,
		Vector2(FIELD_ITEM_COLLISION_SIZE, FIELD_ITEM_COLLISION_SIZE)
	)
	return item_rect


func apply_dowsing_pendulum_attraction(
	item_pos: Vector2,
	item_vel: Vector2,
	player_rect: Rect2,
	context: Dictionary,
	fps_scale: float
) -> Vector2:
	if context.is_empty():
		return item_vel
	var attraction_range: float = max(0.0, float(context.get("range", 0.0)))
	if attraction_range <= 0.0:
		return item_vel
	var offset: Vector2 = player_rect.get_center() - item_pos
	var distance: float = offset.length()
	var min_distance: float = max(0.0, float(context.get("min_distance", 30.0)))
	if distance <= min_distance or distance > attraction_range:
		return item_vel

	var force_multiplier: float = 1.0 - distance / attraction_range
	var force: float = max(0.0, float(context.get("force", 3.5))) * force_multiplier
	var result: Vector2 = item_vel + offset / distance * force * max(0.0, fps_scale)
	var max_speed: float = max(0.0, float(context.get("max_speed", 8.0)))
	if max_speed > 0.0 and result.length() > max_speed:
		result = result.normalized() * max_speed
	return result


func _roll_spawn_velocity_component() -> float:
	return float(SPAWN_VELOCITY_CHOICES[randi() % SPAWN_VELOCITY_CHOICES.size()])


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _is_stationary_field_item(field_item: Dictionary) -> bool:
	if bool(field_item.get("stationary_field_item", false)):
		return true
	var item_data_value: Variant = field_item.get("item_data", {})
	if item_data_value is Dictionary:
		return bool((item_data_value as Dictionary).get("stationary_field_item", false))
	return false


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
