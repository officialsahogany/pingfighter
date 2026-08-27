extends RefCounted

# Stateful lifecycle owner for Commando Supply Drop parachute collectibles.
#
# Aircraft timing and drawing remain in CommandoSupplyDropState. This owner
# owns the live drop array, motion/despawn, pickup collision, reward routing,
# rejection retention, and pickup audio order.

const COLLECTIBLE_DROP_BOX_SIZE := Vector2(40.0, 30.0)
const COLLECTIBLE_DROP_SAFE_MARGIN := 32.0
const COLLECTIBLE_DROP_FALL_SPEED := 168.0
const COLLECTIBLE_DROP_SWAY_SPEED := 4.2
const COLLECTIBLE_DROP_SWAY_AMOUNT := 13.0
const COLLECTIBLE_DROP_DESPAWN_MARGIN := 50.0
const DEFAULT_PLAY_WIDTH := 760.0
const DEFAULT_PLAY_HEIGHT := 800.0

var drops: Array[Dictionary] = []


func reset() -> void:
	drops.clear()


func restore(value: Variant) -> void:
	drops = _duplicate_dictionary_array(value)


func get_snapshot() -> Array[Dictionary]:
	return drops.duplicate(true)


func spawn(drop: Dictionary, fallback_position: Vector2) -> void:
	var drop_position: Vector2 = _get_vector2(
		drop.get("drop_position", fallback_position),
		fallback_position
	)
	var collectible: Dictionary = drop.duplicate(true)
	var payload_index: int = int(collectible.get("payload_index", drops.size()))
	collectible["pos"] = drop_position
	collectible["base_x"] = drop_position.x
	collectible["elapsed"] = 0.0
	collectible["sway_phase"] = float(payload_index) * 0.83
	collectible["vy"] = COLLECTIBLE_DROP_FALL_SPEED + float(payload_index) * 8.0
	collectible["rotation"] = 0.0
	collectible["active"] = true
	drops.append(collectible)


func update(delta: float, deps: Dictionary) -> void:
	if drops.is_empty():
		return
	var play_width: float = max(1.0, float(deps.get(
		"play_width",
		deps.get("width", DEFAULT_PLAY_WIDTH)
	)))
	var play_height: float = max(1.0, float(deps.get(
		"play_height",
		deps.get("height", DEFAULT_PLAY_HEIGHT)
	)))
	var next_drops: Array[Dictionary] = []
	for drop in drops:
		var next_drop: Dictionary = drop.duplicate(true)
		var elapsed: float = float(next_drop.get("elapsed", 0.0)) + delta
		var pos: Vector2 = _get_vector2(
			next_drop.get("pos", next_drop.get("drop_position", Vector2.ZERO)),
			Vector2.ZERO
		)
		var base_x: float = float(next_drop.get("base_x", pos.x))
		var sway_phase: float = float(next_drop.get("sway_phase", 0.0))
		pos.x = clamp(
			base_x + sin(elapsed * COLLECTIBLE_DROP_SWAY_SPEED + sway_phase) * COLLECTIBLE_DROP_SWAY_AMOUNT,
			COLLECTIBLE_DROP_SAFE_MARGIN,
			play_width - COLLECTIBLE_DROP_SAFE_MARGIN
		)
		pos.y += float(next_drop.get("vy", COLLECTIBLE_DROP_FALL_SPEED)) * delta
		next_drop["pos"] = pos
		next_drop["elapsed"] = elapsed
		next_drop["rotation"] = float(next_drop.get("rotation", 0.0)) + delta * 120.0
		if pos.y <= play_height + COLLECTIBLE_DROP_DESPAWN_MARGIN:
			next_drops.append(next_drop)
	drops = next_drops


func resolve_pickups(player_rect: Rect2, deps: Dictionary) -> Dictionary:
	if drops.is_empty() or player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return {}
	var next_drops: Array[Dictionary] = []
	var picked_drops: Array[Dictionary] = []
	var rejected_count := 0
	for drop in drops:
		var next_drop: Dictionary = drop.duplicate(true)
		if not player_rect.intersects(get_drop_rect(next_drop)):
			next_drops.append(next_drop)
			continue
		var collect_result: Dictionary = _collect_drop(next_drop, deps)
		if bool(collect_result.get("keep_collectible", false)):
			rejected_count += 1
			next_drops.append(next_drop)
			continue
		var picked_drop: Dictionary = next_drop.duplicate(true)
		picked_drop.merge(collect_result, true)
		picked_drops.append(picked_drop)
	drops = next_drops

	if picked_drops.is_empty() and rejected_count <= 0:
		return {}
	var result: Dictionary = {
		"pickup_resolved": not picked_drops.is_empty(),
		"picked_drops": picked_drops,
		"collectible_count": drops.size(),
	}
	if not picked_drops.is_empty():
		result["picked_drop"] = picked_drops[0]
	if rejected_count > 0:
		result["pickup_rejected"] = true
		result["rejected_pickups"] = rejected_count
	return result


func get_drop_rect(drop: Dictionary) -> Rect2:
	var pos: Vector2 = _get_vector2(
		drop.get("pos", drop.get("drop_position", Vector2.ZERO)),
		Vector2.ZERO
	)
	return Rect2(pos - COLLECTIBLE_DROP_BOX_SIZE * 0.5, COLLECTIBLE_DROP_BOX_SIZE)


func _collect_drop(drop: Dictionary, deps: Dictionary) -> Dictionary:
	var drop_type: String = str(drop.get("type", ""))
	if drop_type == "rental_weapon":
		var weapon_id: String = str(drop.get("weapon_id", ""))
		var granted := false
		var weapon_controller: Object = deps.get("commando_weapon_controller", null)
		if weapon_controller != null and weapon_controller.has_method("add_rental_weapon"):
			var stage: int = int(deps.get("current_stage", 1))
			granted = bool(weapon_controller.add_rental_weapon(
				weapon_id,
				stage,
				-1,
				true,
				true
			))
		if granted:
			_play_audio_method(deps, "play_commando_weapon_change")
		_play_first_audio_method(deps, ["play_item_get", "play_commando_supply_drop"])
		return {
			"type": drop_type,
			"weapon_id": weapon_id,
			"rental_granted": granted,
		}
	if drop_type == "field_item":
		return _collect_field_item_drop(drop, deps)
	return {
		"type": drop_type,
		"unknown_drop": true,
	}


func _collect_field_item_drop(drop: Dictionary, deps: Dictionary) -> Dictionary:
	var item_id: String = str(drop.get("item_id", ""))
	if item_id == "":
		return {
			"type": "field_item",
			"field_item_collected": false,
		}
	var pos: Vector2 = _get_vector2(
		drop.get("pos", drop.get("drop_position", Vector2.ZERO)),
		Vector2.ZERO
	)
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	var owner: Object = deps.get("owner", null)
	var registry: Object = deps.get("registry", null)
	if active_item_runtime != null and owner != null:
		if active_item_runtime.has_method("collect_item_by_name"):
			var collected: bool = bool(active_item_runtime.collect_item_by_name(
				item_id,
				pos,
				owner,
				registry
			))
			if collected:
				return {
					"type": "field_item",
					"item_id": item_id,
					"field_item_collected": true,
				}
			return _rejected_field_item_result(item_id)
		if active_item_runtime.has_method("grant_item_to_slot"):
			var granted: bool = bool(active_item_runtime.grant_item_to_slot(
				item_id,
				owner,
				registry,
				false
			))
			if granted:
				_play_first_audio_method(deps, ["play_item_get", "play_commando_supply_drop"])
				return {
					"type": "field_item",
					"item_id": item_id,
					"field_item_collected": true,
				}
			return _rejected_field_item_result(item_id)
	var spawned: bool = _spawn_field_item(item_id, deps, pos)
	return {
		"type": "field_item",
		"item_id": item_id,
		"field_item_collected": false,
		"field_item_spawned": spawned,
		"keep_collectible": not spawned,
	}


func _rejected_field_item_result(item_id: String) -> Dictionary:
	return {
		"type": "field_item",
		"item_id": item_id,
		"field_item_collected": false,
		"pickup_rejected": true,
		"keep_collectible": true,
	}


func _spawn_field_item(item_id: String, deps: Dictionary, position: Vector2) -> bool:
	if item_id == "":
		return false
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null:
		if active_item_runtime.has_method("spawn_field_item"):
			return bool(active_item_runtime.spawn_field_item(item_id, position))
		var field_spawn_controller_value: Variant = active_item_runtime.get("field_spawn_controller")
		if field_spawn_controller_value is Object:
			var field_spawn_controller: Object = field_spawn_controller_value
			if field_spawn_controller.has_method("debug_spawn_item_at"):
				return bool(field_spawn_controller.debug_spawn_item_at(item_id, position))
			if field_spawn_controller.has_method("debug_spawn_item"):
				return bool(field_spawn_controller.debug_spawn_item(item_id))
	var direct_field_spawn: Object = deps.get("active_item_field_spawn_controller", null)
	if direct_field_spawn != null and direct_field_spawn.has_method("debug_spawn_item_at"):
		return bool(direct_field_spawn.debug_spawn_item_at(item_id, position))
	if direct_field_spawn != null and direct_field_spawn.has_method("debug_spawn_item"):
		return bool(direct_field_spawn.debug_spawn_item(item_id))
	return false


func _play_audio_method(deps: Dictionary, method_name: String) -> void:
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio == null or not audio.has_method(method_name):
		return
	audio.call(method_name)


func _play_first_audio_method(deps: Dictionary, method_names: Array[String]) -> void:
	var audio: Object = deps.get("audio", deps.get("game_audio", null))
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func _duplicate_dictionary_array(value: Variant) -> Array[Dictionary]:
	var source: Array = value if value is Array else []
	var result: Array[Dictionary] = []
	for entry in source:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
