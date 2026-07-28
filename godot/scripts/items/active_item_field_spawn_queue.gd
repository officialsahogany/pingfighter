extends RefCounted

var _method_argument_count_cache: Dictionary = {}


func queue_item_after_portal(
	owner: Object,
	registry: Object,
	spawn_pool: Object,
	field_item_motion: Object,
	spawn_portals: Object,
	perf_logger: Object = null
) -> bool:
	var context: Dictionary = _normalize_owner_registry(owner, registry)
	owner = context.get("owner", null)
	registry = context.get("registry", null)
	var sample_start: int = _perf_begin(perf_logger)
	var item_data: Dictionary = _build_random_spawn_item(registry, owner, spawn_pool, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.regular.random_item", sample_start)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	sample_start = _perf_begin(perf_logger)
	var position: Vector2 = field_item_motion.roll_field_item_position()
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.regular.position", sample_start)
	sample_start = _perf_begin(perf_logger)
	var field_item: Dictionary = field_item_motion.build_field_item(item_data, position)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.regular.build_field_item", sample_start)
	sample_start = _perf_begin(perf_logger)
	var release_msec: int = spawn_portals.queue_item_after_portal(field_item, position)
	_mark_spirit_water_drop_pending(item_data, registry)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.regular.portal_queue", sample_start)
	sample_start = _perf_begin(perf_logger)
	_queue_lucky_coin_bonus_after_portal(
		registry,
		release_msec,
		Vector2.ZERO,
		false,
		owner,
		spawn_pool,
		field_item_motion,
		spawn_portals,
		perf_logger
	)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.regular.lucky_bonus", sample_start)
	return true


func queue_dimension_gate_item(
	owner: Object,
	registry: Object,
	spawn_pool: Object,
	field_item_motion: Object,
	spawn_portals: Object,
	perf_logger: Object = null
) -> bool:
	var context: Dictionary = _normalize_owner_registry(owner, registry)
	owner = context.get("owner", null)
	registry = context.get("registry", null)
	var sample_start: int = _perf_begin(perf_logger)
	var item_data: Dictionary = _build_random_spawn_item(registry, owner, spawn_pool, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.dimension.random_item", sample_start)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	sample_start = _perf_begin(perf_logger)
	var position: Vector2 = spawn_portals.get_dimension_gate_center()
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.dimension.position", sample_start)
	sample_start = _perf_begin(perf_logger)
	var field_item: Dictionary = field_item_motion.build_field_item(item_data, position)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.dimension.build_field_item", sample_start)
	sample_start = _perf_begin(perf_logger)
	var release_msec: int = spawn_portals.queue_dimension_gate_item(field_item)
	_mark_spirit_water_drop_pending(item_data, registry)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.dimension.portal_queue", sample_start)
	sample_start = _perf_begin(perf_logger)
	_queue_lucky_coin_bonus_after_portal(
		registry,
		release_msec,
		position,
		true,
		owner,
		spawn_pool,
		field_item_motion,
		spawn_portals,
		perf_logger
	)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.dimension.lucky_bonus", sample_start)
	return true


func _queue_lucky_coin_bonus_after_portal(
	registry: Object,
	release_msec: int,
	anchor_position: Vector2,
	use_anchor_offset: bool,
	owner: Object,
	spawn_pool: Object,
	field_item_motion: Object,
	spawn_portals: Object,
	perf_logger: Object = null
) -> bool:
	var sample_start: int = _perf_begin(perf_logger)
	var item_data: Dictionary = _build_lucky_coin_bonus_spawn_item(registry, owner, spawn_pool, perf_logger)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.lucky.random_item", sample_start)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	sample_start = _perf_begin(perf_logger)
	var position: Vector2 = field_item_motion.roll_lucky_coin_bonus_position(anchor_position, use_anchor_offset)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.lucky.position", sample_start)
	sample_start = _perf_begin(perf_logger)
	var field_item: Dictionary = field_item_motion.build_lucky_coin_bonus_field_item(item_data, position)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.lucky.build_field_item", sample_start)
	sample_start = _perf_begin(perf_logger)
	spawn_portals.queue_lucky_coin_bonus_after_portal(field_item, position, release_msec)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.lucky.portal_queue", sample_start)
	sample_start = _perf_begin(perf_logger)
	_play_lucky_coin_spawn_audio(registry)
	_perf_end(perf_logger, "physics.callback.active_items.field_spawn.queue.lucky.audio", sample_start)
	return true


func _build_random_spawn_item(
	registry: Object,
	owner: Object,
	spawn_pool: Object,
	perf_logger: Object = null
) -> Dictionary:
	if spawn_pool == null or not spawn_pool.has_method("build_random_spawn_item"):
		return {}
	if _get_method_argument_count(spawn_pool, "build_random_spawn_item") >= 3:
		return spawn_pool.build_random_spawn_item(registry, owner, perf_logger)
	return spawn_pool.build_random_spawn_item(registry, owner)


func _build_lucky_coin_bonus_spawn_item(
	registry: Object,
	owner: Object,
	spawn_pool: Object,
	perf_logger: Object = null
) -> Dictionary:
	if spawn_pool == null or not spawn_pool.has_method("build_lucky_coin_bonus_spawn_item"):
		return {}
	if _get_method_argument_count(spawn_pool, "build_lucky_coin_bonus_spawn_item") >= 3:
		return spawn_pool.build_lucky_coin_bonus_spawn_item(registry, owner, perf_logger)
	return spawn_pool.build_lucky_coin_bonus_spawn_item(registry, owner)


func _normalize_owner_registry(owner: Object, registry: Object) -> Dictionary:
	if registry == null and owner != null and owner.has_method("get_instance"):
		return {
			"owner": null,
			"registry": owner,
		}
	return {
		"owner": owner,
		"registry": registry,
	}


func _play_lucky_coin_spawn_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lucky_coin_spawn"):
		audio.play_lucky_coin_spawn()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _mark_spirit_water_drop_pending(item_data: Dictionary, registry: Object) -> void:
	if str(item_data.get("name", "")) != "lingpet_spirit_water":
		return
	var runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	if runtime != null and runtime.has_method("mark_spirit_water_drop_pending"):
		runtime.mark_spirit_water_drop_pending()


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	var value: Variant = registry.get_cached_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


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
