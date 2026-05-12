extends RefCounted

const ActiveItemFieldPickupFlow := preload("res://scripts/items/active_item_field_pickup_flow.gd")
const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemFieldSpawnPortals := preload("res://scripts/items/active_item_field_spawn_portals.gd")
const ActiveItemFieldSpawnQueue := preload("res://scripts/items/active_item_field_spawn_queue.gd")
const ActiveItemFieldSpawnScheduler := preload("res://scripts/items/active_item_field_spawn_scheduler.gd")

var spawned_items: Array[Dictionary] = []
var field_pickup_flow: Object = ActiveItemFieldPickupFlow.new()
var field_item_motion: Object = ActiveItemFieldItemMotion.new()
var spawn_pool: Object = ActiveItemFieldSpawnPool.new()
var spawn_portals: Object = ActiveItemFieldSpawnPortals.new()
var spawn_queue: Object = ActiveItemFieldSpawnQueue.new()
var spawn_scheduler: Object = ActiveItemFieldSpawnScheduler.new()


func reset() -> void:
	spawned_items.clear()
	spawn_portals.reset()
	spawn_scheduler.reset()


func update(
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable
) -> void:
	_update_dimension_gate(owner, registry)
	if not spawn_portals.is_dimension_gate_active():
		_update_spawn_timer(owner, registry)
	_release_pending_spawn_items()
	_update_item_spawn_portals()
	_update_field_items(owner, registry, delta, store_item_callback, pickup_callback)


func debug_spawn_item(item_name: String) -> bool:
	return debug_spawn_item_at(item_name, _roll_field_item_position())


func debug_spawn_item_at(item_name: String, position: Vector2) -> bool:
	var item_data: Dictionary = spawn_pool.build_catalog_item(item_name)
	return debug_spawn_item_data_at(item_data, position)


func debug_spawn_item_data(item_data: Dictionary, position: Variant = null) -> bool:
	var spawn_position: Vector2 = _roll_field_item_position()
	if position is Vector2:
		spawn_position = position
	return debug_spawn_item_data_at(item_data, spawn_position)


func debug_spawn_item_data_at(item_data: Dictionary, position: Vector2) -> bool:
	if item_data.is_empty():
		return false
	if str(item_data.get("name", "")) == "":
		return false
	item_data = item_data.duplicate(true)
	item_data["revealed"] = false
	spawned_items.append(_build_field_item(item_data, _clamp_field_item_position(position)))
	spawn_scheduler.mark_spawn_now()
	return true


func activate_dimension_gate() -> bool:
	var was_active: bool = spawn_portals.is_dimension_gate_active()
	var activated: bool = spawn_portals.activate_dimension_gate()
	if activated and not was_active:
		spawn_scheduler.mark_spawn_now()
	return activated


func is_dimension_gate_active() -> bool:
	return spawn_portals.is_dimension_gate_active()


func get_spawned_items() -> Array[Dictionary]:
	return spawned_items


func get_item_spawn_portals() -> Array[Dictionary]:
	return spawn_portals.get_item_spawn_portals()


func get_pending_spawn_items() -> Array[Dictionary]:
	return spawn_portals.get_pending_spawn_items()


func has_visible_field_items() -> bool:
	return not spawned_items.is_empty() or spawn_portals.has_visible_portals()


func get_field_spawn_candidate_names() -> Dictionary:
	return spawn_pool.get_field_spawn_candidate_names()


func collect_items_near(center: Vector2, radius: float) -> Array[Dictionary]:
	if spawned_items.is_empty():
		return []
	var result: Dictionary = field_pickup_flow.collect_items_near(
		spawned_items,
		field_item_motion,
		center,
		radius
	)
	spawned_items = _get_dictionary_array(result, "survivors")
	return _get_dictionary_array(result, "picked_items")


func _update_spawn_timer(owner: Object, registry: Object) -> void:
	if spawn_scheduler.consume_regular_spawn_due(
		owner,
		registry,
		not spawned_items.is_empty(),
		spawn_portals.has_pending_spawn_or_portals()
	):
		_queue_item_after_portal(owner, registry)


func _update_dimension_gate(owner: Object, registry: Object) -> void:
	if spawn_portals.update_dimension_gate(spawn_scheduler.is_item_spawn_blocked(owner)):
		_queue_dimension_gate_item(owner, registry)


func _update_field_items(
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable
) -> void:
	spawned_items = field_pickup_flow.update_field_items(
		owner,
		registry,
		spawned_items,
		field_item_motion,
		delta,
		store_item_callback,
		pickup_callback
	)


func _queue_item_after_portal(owner: Object = null, registry: Object = null) -> void:
	spawn_queue.queue_item_after_portal(
		owner,
		registry,
		spawn_pool,
		field_item_motion,
		spawn_portals
	)


func _queue_dimension_gate_item(owner: Object = null, registry: Object = null) -> void:
	spawn_queue.queue_dimension_gate_item(
		owner,
		registry,
		spawn_pool,
		field_item_motion,
		spawn_portals
	)


func _build_random_spawn_item(registry: Object = null, owner: Object = null) -> Dictionary:
	return spawn_pool.build_random_spawn_item(registry, owner)


func _build_weighted_spawn_item(
	candidates: Array[Dictionary],
	excluded_names: Dictionary = {},
	registry: Object = null
) -> Dictionary:
	return spawn_pool.build_weighted_spawn_item(candidates, excluded_names, registry)


func _build_group_scaled_spawn_weights(
	candidates: Array[Dictionary],
	excluded_names: Dictionary = {},
	registry: Object = null
) -> Array[Dictionary]:
	return spawn_pool.build_group_scaled_spawn_weights(candidates, excluded_names, registry)


func _get_spawn_group_target_shares(group_sums: Dictionary, registry: Object = null) -> Dictionary:
	return spawn_pool.get_spawn_group_target_shares(group_sums, registry)


func _build_spawn_candidates(registry: Object = null, owner: Object = null) -> Array[Dictionary]:
	return spawn_pool.build_spawn_candidates(registry, owner)


func _roll_field_item_position() -> Vector2:
	return field_item_motion.roll_field_item_position()


func _clamp_field_item_position(position: Vector2) -> Vector2:
	return Vector2(
		clamp(position.x, ActiveItemFieldItemMotion.FIELD_ITEM_RADIUS, ActiveItemFieldItemMotion.FIELD_WIDTH - ActiveItemFieldItemMotion.FIELD_ITEM_RADIUS),
		clamp(position.y, ActiveItemFieldItemMotion.FIELD_ITEM_RADIUS, ActiveItemFieldItemMotion.FIELD_HEIGHT - ActiveItemFieldItemMotion.FIELD_ITEM_RADIUS)
	)


func _build_field_item(item_data: Dictionary, position: Vector2) -> Dictionary:
	return field_item_motion.build_field_item(item_data, position)


func _release_pending_spawn_items() -> void:
	for field_item in spawn_portals.release_pending_spawn_items():
		spawned_items.append(field_item)


func _update_item_spawn_portals() -> void:
	spawn_portals.update_item_spawn_portals()


func _get_dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var value: Variant = source.get(key, [])
	var items: Array[Dictionary] = []
	if value is Array:
		for item_value in value:
			if item_value is Dictionary:
				items.append(item_value)
	return items
