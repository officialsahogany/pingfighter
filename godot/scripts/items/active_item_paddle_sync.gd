extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0


func sync_owner_state(
	owner: Object,
	active_item_scale: float,
	warp_gate_state: Object = null,
	mythic_item_runtime: Object = null
) -> void:
	if owner == null:
		return

	var runtime_paddle_scale: float = max(0.1, float(BattleSceneOwnerReader.get_value(owner, "runtime_paddle_scale", 1.0)))
	var base_width: float = _get_runtime_paddle_base_width(owner)
	var base_height: float = _get_runtime_paddle_base_height(owner)
	var bulkup_scale: float = get_mythic_item_paddle_scale(mythic_item_runtime)
	var next_width: float = get_player_paddle_width(active_item_scale, base_width * runtime_paddle_scale * bulkup_scale)
	var next_height: float = get_player_paddle_height(active_item_scale, base_height * runtime_paddle_scale * bulkup_scale)
	var current_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var current_height: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5 - current_width * 0.5, FIELD_HEIGHT - current_height)
	)
	if not is_equal_approx(current_width, next_width) or not is_equal_approx(current_height, next_height):
		var center_x: float = player_pos.x + current_width * 0.5
		player_pos.x = clamp_synced_player_x(center_x - next_width * 0.5, next_width, warp_gate_state)
		var current_bottom: float = player_pos.y + current_height
		if abs(current_bottom - FIELD_HEIGHT) <= max(2.0, current_height * 0.05) or current_bottom > FIELD_HEIGHT:
			player_pos.y = FIELD_HEIGHT - next_height
	_set_if_changed_vector2(owner, "player_pos", player_pos)
	_set_if_changed_float(owner, "player_paddle_width", next_width)
	_set_if_changed_float(owner, "player_paddle_height", next_height)
	_set_if_changed_float(owner, "player_paddle_scale", max(0.1, next_width / PLAYER_BASE_PADDLE_WIDTH))


func get_player_paddle_scale(long_boost_scale: float, strange_vial_scale: float) -> float:
	return long_boost_scale * strange_vial_scale


func get_player_paddle_width(active_item_scale: float, base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return max(1.0, base_width * active_item_scale)


func get_player_paddle_height(active_item_scale: float, base_height: float = PLAYER_BASE_PADDLE_HEIGHT) -> float:
	return max(1.0, base_height * active_item_scale)


func get_mythic_item_paddle_scale(mythic_item_runtime: Object) -> float:
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_paddle_scale"):
		return max(0.1, float(mythic_item_runtime.get_player_paddle_scale()))
	return 1.0


func clamp_synced_player_x(x: float, paddle_width: float, warp_gate_state: Object) -> float:
	if warp_gate_state != null and warp_gate_state.has_method("is_active") and bool(warp_gate_state.is_active()):
		return clamp(x, -max(1.0, paddle_width), FIELD_WIDTH)
	return clamp(x, 0.0, max(0.0, FIELD_WIDTH - max(1.0, paddle_width)))


func _get_runtime_paddle_base_width(owner: Object) -> float:
	return max(1.0, float(BattleSceneOwnerReader.get_value(owner, "runtime_paddle_base_width", PLAYER_BASE_PADDLE_WIDTH)))


func _get_runtime_paddle_base_height(owner: Object) -> float:
	return max(1.0, float(BattleSceneOwnerReader.get_value(owner, "runtime_paddle_base_height", PLAYER_BASE_PADDLE_HEIGHT)))


func _set_if_changed_float(owner: Object, key: String, value: float) -> void:
	var current_value: Variant = owner.get(key)
	if current_value != null and is_equal_approx(float(current_value), value):
		return
	owner.set(key, value)


func _set_if_changed_vector2(owner: Object, key: String, value: Vector2) -> void:
	var current_value: Variant = owner.get(key)
	if current_value is Vector2 and (current_value as Vector2).is_equal_approx(value):
		return
	owner.set(key, value)
