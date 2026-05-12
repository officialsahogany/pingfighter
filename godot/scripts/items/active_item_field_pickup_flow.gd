extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func update_field_items(
	owner: Object,
	registry: Object,
	spawned_items: Array[Dictionary],
	field_item_motion: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable
) -> Array[Dictionary]:
	if spawned_items.is_empty() or field_item_motion == null:
		return spawned_items

	var player_rect: Rect2 = field_item_motion.get_player_rect(owner)
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var slots_changed := false
	var next_items: Array[Dictionary] = []
	var dowsing_context: Dictionary = field_item_motion.get_dowsing_pendulum_context(registry)

	for field_item in spawned_items:
		var motion_result: Dictionary = field_item_motion.advance_field_item(field_item, player_rect, dowsing_context, delta)
		var advanced_item: Dictionary = _get_dict(motion_result, "field_item")
		if bool(motion_result.get("skipped", false)):
			next_items.append(advanced_item)
			continue

		var item_rect: Rect2 = _get_rect2(motion_result, "item_rect", Rect2())
		if (
			item_rect.intersects(player_rect)
			and _try_store_field_item(advanced_item, active_item_slots, registry, owner, store_item_callback)
		):
			slots_changed = true
			if pickup_callback.is_valid():
				pickup_callback.call(advanced_item, registry)
			continue

		if bool(motion_result.get("alive", false)):
			next_items.append(advanced_item)

	if slots_changed and owner != null:
		owner.set("active_item_slots", active_item_slots)
	return next_items


func collect_items_near(
	spawned_items: Array[Dictionary],
	field_item_motion: Object,
	center: Vector2,
	radius: float
) -> Dictionary:
	if spawned_items.is_empty() or field_item_motion == null:
		return {
			"picked_items": [],
			"survivors": spawned_items,
		}
	return field_item_motion.collect_items_near(spawned_items, center, radius)


func _try_store_field_item(
	field_item: Dictionary,
	active_item_slots: Array,
	registry: Object,
	owner: Object,
	store_item_callback: Callable
) -> bool:
	if not store_item_callback.is_valid():
		return false
	return bool(store_item_callback.call(field_item, active_item_slots, registry, owner))


func _get_dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_rect2(source: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = source.get(key, fallback)
	if value is Rect2:
		return value
	return fallback
