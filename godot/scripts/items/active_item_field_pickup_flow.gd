extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")


func update_field_items(
	owner: Object,
	registry: Object,
	spawned_items: Array[Dictionary],
	field_item_motion: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable,
	perf_logger: Object = null
) -> Array[Dictionary]:
	if spawned_items.is_empty() or field_item_motion == null:
		return spawned_items

	var detail_perf_logger: Object = _detail_perf_logger(perf_logger, "active_item.field_items.update")
	var sample_start: int = _perf_begin(detail_perf_logger)
	var player_rect: Rect2 = field_item_motion.get_player_rect(owner)
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var slots_changed := false
	var next_items: Array[Dictionary] = []
	var dowsing_context: Dictionary = field_item_motion.get_dowsing_pendulum_context(registry)
	_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.field_items.prepare", sample_start)

	for field_item in spawned_items:
		sample_start = _perf_begin(detail_perf_logger)
		var advance_state: int = field_item_motion.advance_field_item_in_place(field_item, player_rect, dowsing_context, delta)
		_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.field_items.motion", sample_start)
		var advanced_item: Dictionary = field_item
		if advance_state == ActiveItemFieldItemMotion.ADVANCE_SKIPPED_ALIVE:
			next_items.append(advanced_item)
			continue

		var item_rect: Rect2 = field_item_motion.get_field_item_rect(advanced_item)
		var should_try_pickup: bool = item_rect.intersects(player_rect)
		var did_store_item := false
		if should_try_pickup:
			sample_start = _perf_begin(detail_perf_logger)
			did_store_item = _try_store_field_item(advanced_item, active_item_slots, registry, owner, store_item_callback)
			_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.field_items.store", sample_start)
			if did_store_item:
				slots_changed = true
				if pickup_callback.is_valid():
					sample_start = _perf_begin(detail_perf_logger)
					pickup_callback.call(advanced_item, registry)
					_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.field_items.pickup_feedback", sample_start)
				continue

		if advance_state == ActiveItemFieldItemMotion.ADVANCE_ALIVE:
			next_items.append(advanced_item)

	if slots_changed and owner != null:
		sample_start = _perf_begin(detail_perf_logger)
		owner.set("active_item_slots", active_item_slots)
		_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.field_items.owner_slots", sample_start)
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


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _detail_perf_logger(perf_logger: Object, label: String) -> Object:
	if perf_logger == null:
		return null
	if perf_logger.has_method("should_sample_detail"):
		return perf_logger if bool(perf_logger.should_sample_detail(label)) else null
	return perf_logger
