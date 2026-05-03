extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_ITEM_RADIUS := 15.0
const FIELD_ITEM_COLLISION_SIZE := 30.0
const SPAWN_DELAY_MIN_MSEC := 20000
const SPAWN_DELAY_MAX_MSEC := 50000
const SPAWN_VELOCITY_CHOICES := [-4.0, -3.0, 3.0, 4.0]
const SPAWN_SPARK_DURATION_SEC := 1.0
const ITEM_SPAWN_PORTAL_DURATION_MSEC := 1000
const ITEM_SPAWN_PORTAL_RELEASE_DELAY_MSEC := 438

var spawned_items: Array[Dictionary] = []
var pending_spawn_items: Array[Dictionary] = []
var item_spawn_portals: Array[Dictionary] = []
var last_item_spawn_msec: int = 0
var next_item_spawn_delay_msec: int = 0
var item_catalog: Object = ActiveItemCatalog.new()


func reset() -> void:
	spawned_items.clear()
	pending_spawn_items.clear()
	item_spawn_portals.clear()
	_reset_spawn_timer()


func update(
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable
) -> void:
	_update_spawn_timer(owner)
	_release_pending_spawn_items()
	_update_item_spawn_portals()
	_update_field_items(owner, registry, delta, store_item_callback, pickup_callback)


func debug_spawn_item(item_name: String) -> bool:
	var item_data: Dictionary = item_catalog.build_item_by_name(item_name)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	spawned_items.append(_build_field_item(item_data, _roll_field_item_position()))
	last_item_spawn_msec = Time.get_ticks_msec()
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()
	return true


func get_spawned_items() -> Array[Dictionary]:
	return spawned_items


func get_item_spawn_portals() -> Array[Dictionary]:
	return item_spawn_portals


func _update_spawn_timer(owner: Object) -> void:
	if _is_item_spawn_blocked(owner):
		_reset_spawn_timer()
		return
	if not spawned_items.is_empty():
		return
	if not pending_spawn_items.is_empty() or not item_spawn_portals.is_empty():
		return

	var now_msec: int = Time.get_ticks_msec()
	if last_item_spawn_msec <= 0:
		last_item_spawn_msec = now_msec
		return
	if now_msec - last_item_spawn_msec < next_item_spawn_delay_msec:
		return

	_queue_item_after_portal()
	last_item_spawn_msec = now_msec
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()


func _update_field_items(
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable
) -> void:
	if spawned_items.is_empty():
		return

	var player_paddle_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var player_paddle_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_rect := Rect2(
		BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO),
		Vector2(player_paddle_width, player_paddle_height)
	)
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var slots_changed := false
	var next_items: Array[Dictionary] = []
	var fps_scale: float = delta * 60.0

	for field_item in spawned_items:
		if bool(field_item.get("spawn_skip_update_once", false)):
			field_item["spawn_skip_update_once"] = false
			next_items.append(field_item)
			continue

		var item_pos: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO)
		var item_vel: Vector2 = _get_vector2(field_item, "velocity", Vector2.ZERO)
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

		var item_rect := Rect2(
			item_pos - Vector2(FIELD_ITEM_COLLISION_SIZE, FIELD_ITEM_COLLISION_SIZE) * 0.5,
			Vector2(FIELD_ITEM_COLLISION_SIZE, FIELD_ITEM_COLLISION_SIZE)
		)
		if item_rect.intersects(player_rect) and _try_store_field_item(field_item, active_item_slots, registry, store_item_callback):
			slots_changed = true
			if pickup_callback.is_valid():
				pickup_callback.call(field_item, registry)
			continue

		if bounce_count < int(field_item.get("max_bounces", 10)):
			next_items.append(field_item)

	spawned_items = next_items
	if slots_changed:
		owner.set("active_item_slots", active_item_slots)


func _try_store_field_item(
	field_item: Dictionary,
	active_item_slots: Array,
	registry: Object,
	store_item_callback: Callable
) -> bool:
	if not store_item_callback.is_valid():
		return false
	return bool(store_item_callback.call(field_item, active_item_slots, registry))


func _queue_item_after_portal() -> void:
	var item_data: Dictionary = item_catalog.build_random_spawn_item()
	item_data["revealed"] = false
	var position: Vector2 = _roll_field_item_position()
	var field_item: Dictionary = _build_field_item(item_data, position)
	var now_msec: int = Time.get_ticks_msec()
	pending_spawn_items.append({
		"item": field_item,
		"release_msec": now_msec + ITEM_SPAWN_PORTAL_RELEASE_DELAY_MSEC,
	})
	item_spawn_portals.append({
		"position": position,
		"start_msec": now_msec,
		"duration_msec": ITEM_SPAWN_PORTAL_DURATION_MSEC,
	})


func _roll_field_item_position() -> Vector2:
	return Vector2(
		randf_range(FIELD_ITEM_RADIUS, FIELD_WIDTH - FIELD_ITEM_RADIUS),
		randf_range(FIELD_ITEM_RADIUS, FIELD_HEIGHT - FIELD_ITEM_RADIUS)
	)


func _build_field_item(item_data: Dictionary, position: Vector2) -> Dictionary:
	return {
		"item_data": item_data,
		"position": position,
		"velocity": Vector2(_roll_spawn_velocity_component(), _roll_spawn_velocity_component()),
		"angle_degrees": 0.0,
		"bounce_count": 0,
		"max_bounces": randi_range(6, 9),
		"spawn_spark_timer": SPAWN_SPARK_DURATION_SEC,
		"spawn_skip_update_once": true,
	}


func _release_pending_spawn_items() -> void:
	if pending_spawn_items.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for pending in pending_spawn_items:
		if now_msec < int(pending.get("release_msec", now_msec)):
			survivors.append(pending)
			continue
		var item_value: Variant = pending.get("item", {})
		if item_value is Dictionary:
			spawned_items.append(item_value)
	pending_spawn_items = survivors


func _update_item_spawn_portals() -> void:
	if item_spawn_portals.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for portal in item_spawn_portals:
		var start_msec: int = int(portal.get("start_msec", now_msec))
		var duration_msec: int = max(1, int(portal.get("duration_msec", ITEM_SPAWN_PORTAL_DURATION_MSEC)))
		if now_msec - start_msec < duration_msec:
			survivors.append(portal)
	item_spawn_portals = survivors


func _reset_spawn_timer() -> void:
	last_item_spawn_msec = Time.get_ticks_msec()
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()


func _roll_spawn_delay_msec() -> int:
	return randi_range(SPAWN_DELAY_MIN_MSEC, SPAWN_DELAY_MAX_MSEC)


func _roll_spawn_velocity_component() -> float:
	return float(SPAWN_VELOCITY_CHOICES[randi() % SPAWN_VELOCITY_CHOICES.size()])


func _is_item_spawn_blocked(owner: Object) -> bool:
	if int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1)) == 50:
		return true
	if bool(BattleSceneOwnerReader.get_value(owner, "arena_mode_enabled", false)):
		return true
	return false


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
