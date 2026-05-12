extends RefCounted


func queue_item_after_portal(
	owner: Object,
	registry: Object,
	spawn_pool: Object,
	field_item_motion: Object,
	spawn_portals: Object
) -> bool:
	var context: Dictionary = _normalize_owner_registry(owner, registry)
	owner = context.get("owner", null)
	registry = context.get("registry", null)
	var item_data: Dictionary = _build_random_spawn_item(registry, owner, spawn_pool)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	var position: Vector2 = field_item_motion.roll_field_item_position()
	var field_item: Dictionary = field_item_motion.build_field_item(item_data, position)
	var release_msec: int = spawn_portals.queue_item_after_portal(field_item, position)
	_queue_lucky_coin_bonus_after_portal(
		registry,
		release_msec,
		Vector2.ZERO,
		false,
		owner,
		spawn_pool,
		field_item_motion,
		spawn_portals
	)
	return true


func queue_dimension_gate_item(
	owner: Object,
	registry: Object,
	spawn_pool: Object,
	field_item_motion: Object,
	spawn_portals: Object
) -> bool:
	var context: Dictionary = _normalize_owner_registry(owner, registry)
	owner = context.get("owner", null)
	registry = context.get("registry", null)
	var item_data: Dictionary = _build_random_spawn_item(registry, owner, spawn_pool)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	var position: Vector2 = spawn_portals.get_dimension_gate_center()
	var field_item: Dictionary = field_item_motion.build_field_item(item_data, position)
	var release_msec: int = spawn_portals.queue_dimension_gate_item(field_item)
	_queue_lucky_coin_bonus_after_portal(
		registry,
		release_msec,
		position,
		true,
		owner,
		spawn_pool,
		field_item_motion,
		spawn_portals
	)
	return true


func _queue_lucky_coin_bonus_after_portal(
	registry: Object,
	release_msec: int,
	anchor_position: Vector2,
	use_anchor_offset: bool,
	owner: Object,
	spawn_pool: Object,
	field_item_motion: Object,
	spawn_portals: Object
) -> bool:
	var item_data: Dictionary = spawn_pool.build_lucky_coin_bonus_spawn_item(registry, owner)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	var position: Vector2 = field_item_motion.roll_lucky_coin_bonus_position(anchor_position, use_anchor_offset)
	var field_item: Dictionary = field_item_motion.build_lucky_coin_bonus_field_item(item_data, position)
	spawn_portals.queue_lucky_coin_bonus_after_portal(field_item, position, release_msec)
	_play_lucky_coin_spawn_audio(registry)
	return true


func _build_random_spawn_item(registry: Object, owner: Object, spawn_pool: Object) -> Dictionary:
	if spawn_pool == null or not spawn_pool.has_method("build_random_spawn_item"):
		return {}
	return spawn_pool.build_random_spawn_item(registry, owner)


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


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
