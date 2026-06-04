extends RefCounted

const ActiveItemFieldPickupFlow := preload("res://scripts/items/active_item_field_pickup_flow.gd")
const ActiveItemFieldItemMotion := preload("res://scripts/items/active_item_field_item_motion.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ActiveItemFieldSpawnPortals := preload("res://scripts/items/active_item_field_spawn_portals.gd")
const ActiveItemFieldSpawnQueue := preload("res://scripts/items/active_item_field_spawn_queue.gd")
const ActiveItemFieldSpawnScheduler := preload("res://scripts/items/active_item_field_spawn_scheduler.gd")

const MILK_BOTTLE_BREAK_EFFECT_DURATION_SEC := 0.56
const MILK_BOTTLE_BREAK_SHARD_COUNT := 9
const MILK_BOTTLE_BREAK_DROPLET_COUNT := 8
const MILK_BOTTLE_BREAK_RENDER_LIMIT := 6

var spawned_items: Array[Dictionary] = []
var field_item_break_effects: Array[Dictionary] = []
var field_pickup_flow: Object = ActiveItemFieldPickupFlow.new()
var field_item_motion: Object = ActiveItemFieldItemMotion.new()
var spawn_pool: Object = ActiveItemFieldSpawnPool.new()
var spawn_portals: Object = ActiveItemFieldSpawnPortals.new()
var spawn_queue: Object = ActiveItemFieldSpawnQueue.new()
var spawn_scheduler: Object = ActiveItemFieldSpawnScheduler.new()
var _method_argument_count_cache: Dictionary = {}


func reset() -> void:
	spawned_items.clear()
	field_item_break_effects.clear()
	spawn_portals.reset()
	spawn_scheduler.reset()


func prewarm_spawn_candidate_templates(perf_logger: Object = null) -> void:
	if spawn_pool != null and spawn_pool.has_method("prewarm_spawn_candidate_templates_step"):
		while not bool(spawn_pool.prewarm_spawn_candidate_templates_step(perf_logger)):
			pass
	elif spawn_pool != null and spawn_pool.has_method("prewarm_spawn_candidate_templates"):
		spawn_pool.prewarm_spawn_candidate_templates(perf_logger)


func prewarm_spawn_candidate_templates_step(perf_logger: Object = null) -> bool:
	if spawn_pool != null and spawn_pool.has_method("prewarm_spawn_candidate_templates_step"):
		return bool(spawn_pool.prewarm_spawn_candidate_templates_step(perf_logger))
	if spawn_pool != null and spawn_pool.has_method("prewarm_spawn_candidate_templates"):
		spawn_pool.prewarm_spawn_candidate_templates(perf_logger)
	return true


func get_spawn_candidate_cache_status() -> Dictionary:
	if spawn_pool != null and spawn_pool.has_method("get_spawn_candidate_cache_status"):
		return spawn_pool.get_spawn_candidate_cache_status()
	return {}


func update(
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable,
	perf_logger: Object = null
) -> void:
	_record_counter(perf_logger, "active_item.field_items.before", float(spawned_items.size()))
	_record_counter(perf_logger, "active_item.spawn_portals", float(spawn_portals.get_item_spawn_portals().size()))
	_record_counter(perf_logger, "active_item.spawn_pending", float(spawn_portals.get_pending_spawn_items().size()))
	var detail_perf_logger: Object = _detail_perf_logger(perf_logger, "active_item.field_spawn.update")
	var sample_start: int = _perf_begin(detail_perf_logger)
	_update_dimension_gate(owner, registry, detail_perf_logger)
	_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.dimension_gate", sample_start)
	if not spawn_portals.is_dimension_gate_active():
		sample_start = _perf_begin(detail_perf_logger)
		_update_spawn_timer(owner, registry, detail_perf_logger)
		_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.spawn_timer", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_release_pending_spawn_items()
	_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.release_pending", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_update_item_spawn_portals()
	_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.portal_update", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_update_field_item_break_effects(delta)
	_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.break_effects", sample_start)
	_record_counter(perf_logger, "active_item.field_items.released", float(spawned_items.size()))
	sample_start = _perf_begin(detail_perf_logger)
	_update_field_items(owner, registry, delta, store_item_callback, pickup_callback, detail_perf_logger)
	_perf_end(detail_perf_logger, "physics.callback.active_items.field_spawn.field_items", sample_start)
	_record_counter(perf_logger, "active_item.field_items.after", float(spawned_items.size()))


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


func get_field_item_break_effects() -> Array[Dictionary]:
	return field_item_break_effects


func get_pending_spawn_items() -> Array[Dictionary]:
	return spawn_portals.get_pending_spawn_items()


func has_visible_field_items() -> bool:
	return not spawned_items.is_empty() or not field_item_break_effects.is_empty() or spawn_portals.has_visible_portals()


func get_field_item_break_effect_count_for_tests() -> int:
	return field_item_break_effects.size()


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


func _update_spawn_timer(owner: Object, registry: Object, perf_logger: Object = null) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	var spawn_due: bool = spawn_scheduler.consume_regular_spawn_due(
		owner,
		registry,
		not spawned_items.is_empty(),
		spawn_portals.has_pending_spawn_or_portals()
	)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.spawn_timer.scheduler", sample_start)
	if spawn_due:
		sample_start = _perf_begin(perf_logger)
		_queue_item_after_portal(owner, registry, perf_logger)
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.spawn_timer.queue_regular", sample_start)


func _update_dimension_gate(owner: Object, registry: Object, perf_logger: Object = null) -> void:
	var sample_start: int = _perf_begin(perf_logger)
	var spawn_blocked: bool = spawn_scheduler.is_item_spawn_blocked(owner)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.dimension_gate.block_check", sample_start)
	sample_start = _perf_begin(perf_logger)
	var should_queue_item: bool = spawn_portals.update_dimension_gate(spawn_blocked)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.dimension_gate.portal_update", sample_start)
	if should_queue_item:
		sample_start = _perf_begin(perf_logger)
		_queue_dimension_gate_item(owner, registry, perf_logger)
		_perf_end(perf_logger, "physics.callback.active_items.field_spawn.dimension_gate.queue_item", sample_start)


func _update_field_items(
	owner: Object,
	registry: Object,
	delta: float,
	store_item_callback: Callable,
	pickup_callback: Callable,
	perf_logger: Object = null
) -> void:
	if _get_method_argument_count(field_pickup_flow, "update_field_items") >= 9:
		spawned_items = field_pickup_flow.update_field_items(
			owner,
			registry,
			spawned_items,
			field_item_motion,
			delta,
			store_item_callback,
			pickup_callback,
			perf_logger,
			Callable(self, "_trigger_dash_destroy_effect")
		)
	elif _get_method_argument_count(field_pickup_flow, "update_field_items") >= 8:
		spawned_items = field_pickup_flow.update_field_items(
			owner,
			registry,
			spawned_items,
			field_item_motion,
			delta,
			store_item_callback,
			pickup_callback,
			perf_logger
		)
	else:
		spawned_items = field_pickup_flow.update_field_items(
			owner,
			registry,
			spawned_items,
			field_item_motion,
			delta,
			store_item_callback,
			pickup_callback
		)


func _queue_item_after_portal(owner: Object = null, registry: Object = null, perf_logger: Object = null) -> void:
	spawn_queue.queue_item_after_portal(
		owner,
		registry,
		spawn_pool,
		field_item_motion,
		spawn_portals,
		perf_logger
	)


func _queue_dimension_gate_item(owner: Object = null, registry: Object = null, perf_logger: Object = null) -> void:
	spawn_queue.queue_dimension_gate_item(
		owner,
		registry,
		spawn_pool,
		field_item_motion,
		spawn_portals,
		perf_logger
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


func _update_field_item_break_effects(delta: float) -> void:
	if field_item_break_effects.is_empty():
		return
	var write_index := 0
	for read_index in range(field_item_break_effects.size()):
		var effect: Dictionary = field_item_break_effects[read_index]
		var age: float = float(effect.get("age", 0.0)) + delta
		var duration: float = max(0.001, float(effect.get("duration", MILK_BOTTLE_BREAK_EFFECT_DURATION_SEC)))
		if age >= duration:
			continue
		effect["age"] = age
		field_item_break_effects[write_index] = effect
		write_index += 1
	if write_index < field_item_break_effects.size():
		field_item_break_effects.resize(write_index)


func _trigger_dash_destroy_effect(field_item: Dictionary, registry: Object) -> void:
	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	var item_name: String = str(item_data.get("name", ""))
	var center: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO)
	var effect_seed: int = _stable_effect_seed(item_name, center)
	field_item_break_effects.append({
		"kind": "milk_bottle_break" if item_name == "milk_bottle" else "field_item_dash_break",
		"item_name": item_name,
		"position": _clamp_break_effect_center(center),
		"age": 0.0,
		"duration": MILK_BOTTLE_BREAK_EFFECT_DURATION_SEC,
		"effect_seed": effect_seed,
		"shards": _build_break_shards(effect_seed),
		"droplets": _build_milk_droplets(effect_seed),
	})
	if field_item_break_effects.size() > MILK_BOTTLE_BREAK_RENDER_LIMIT:
		while field_item_break_effects.size() > MILK_BOTTLE_BREAK_RENDER_LIMIT:
			field_item_break_effects.remove_at(0)
	_play_dash_destroy_audio(registry)


func _build_break_shards(effect_seed: int) -> Array[Dictionary]:
	var shards: Array[Dictionary] = []
	for index in range(MILK_BOTTLE_BREAK_SHARD_COUNT):
		var ratio: float = _hash_unit(effect_seed, index * 11 + 3)
		var angle: float = -PI * 0.92 + ratio * PI * 1.84
		var speed: float = 82.0 + _hash_unit(effect_seed, index * 13 + 7) * 118.0
		var lift: float = 36.0 + _hash_unit(effect_seed, index * 17 + 5) * 104.0
		shards.append({
			"velocity": Vector2(cos(angle) * speed, sin(angle) * speed - lift),
			"size": 3.2 + _hash_unit(effect_seed, index * 19 + 9) * 4.8,
			"spin": -3.2 + _hash_unit(effect_seed, index * 23 + 1) * 6.4,
			"tint": index % 3,
		})
	return shards


func _build_milk_droplets(effect_seed: int) -> Array[Dictionary]:
	var droplets: Array[Dictionary] = []
	for index in range(MILK_BOTTLE_BREAK_DROPLET_COUNT):
		var angle: float = -PI + _hash_unit(effect_seed, index * 29 + 4) * PI
		var speed: float = 42.0 + _hash_unit(effect_seed, index * 31 + 8) * 72.0
		droplets.append({
			"velocity": Vector2(cos(angle) * speed, -abs(sin(angle)) * speed - 18.0),
			"radius": 2.0 + _hash_unit(effect_seed, index * 37 + 6) * 3.0,
		})
	return droplets


func _play_dash_destroy_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_boomerang_break"):
		audio.play_boomerang_break()
	elif audio.has_method("play_boomerang_hit"):
		audio.play_boomerang_hit()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _stable_effect_seed(item_name: String, center: Vector2) -> int:
	var raw_seed: int = int(abs(center.x) * 92821.0 + abs(center.y) * 68917.0) ^ item_name.hash()
	return max(1, abs(raw_seed))


func _hash_unit(effect_seed: int, salt: int) -> float:
	var value: int = int(abs(sin(float(effect_seed + salt * 1013)) * 100000.0)) % 10000
	return float(value) / 9999.0


func _clamp_break_effect_center(center: Vector2) -> Vector2:
	const VISUAL_MARGIN := 34.0
	return Vector2(
		clamp(center.x, VISUAL_MARGIN, ActiveItemFieldItemMotion.FIELD_WIDTH - VISUAL_MARGIN),
		clamp(center.y, VISUAL_MARGIN, ActiveItemFieldItemMotion.FIELD_HEIGHT - VISUAL_MARGIN)
	)


func _get_dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var value: Variant = source.get(key, [])
	var items: Array[Dictionary] = []
	if value is Array:
		for item_value in value:
			if item_value is Dictionary:
				items.append(item_value)
	return items


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null


func _get_method_argument_count(target: Object, method_name: String) -> int:
	if target == null:
		return 0
	var cache_key := "%d:%s" % [target.get_instance_id(), method_name]
	if _method_argument_count_cache.has(cache_key):
		return int(_method_argument_count_cache[cache_key])
	for method_info in target.get_method_list():
		if not (method_info is Dictionary):
			continue
		if str(method_info.get("name", "")) != method_name:
			continue
		var args_value: Variant = method_info.get("args", [])
		if args_value is Array:
			var args_count: int = args_value.size()
			_method_argument_count_cache[cache_key] = args_count
			return args_count
	_method_argument_count_cache[cache_key] = 0
	return 0


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _record_counter(perf_logger: Object, label: String, value: float) -> void:
	if perf_logger != null and perf_logger.has_method("record_counter_sample"):
		perf_logger.record_counter_sample(label, value)


func _detail_perf_logger(perf_logger: Object, label: String) -> Object:
	if perf_logger == null:
		return null
	if perf_logger.has_method("should_sample_detail"):
		return perf_logger if bool(perf_logger.should_sample_detail(label)) else null
	return perf_logger
