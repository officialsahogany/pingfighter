extends RefCounted

const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0


func build_sync_context(
	effective_levels: Dictionary,
	accessory_slot_bonus: int,
	laurel_leaf_count: int,
	player_paddle_size_multiplier: float,
	player_skill_cooldown_multiplier: float
) -> Dictionary:
	return {
		"effective_levels": effective_levels.duplicate(true),
		"accessory_slot_bonus": accessory_slot_bonus,
		"laurel_leaf_count": laurel_leaf_count,
		"player_paddle_size_multiplier": player_paddle_size_multiplier,
		"player_skill_cooldown_multiplier": player_skill_cooldown_multiplier,
	}


func sync_owner_effects(
	owner: Object,
	registry: Object,
	context: Dictionary,
	get_instance: Callable,
	perf_logger: Object = null
) -> void:
	if owner == null:
		return
	var sample_start: int = _perf_begin(perf_logger)
	owner.set("runtime_perk_effective_levels", context.get("effective_levels", {}))
	owner.set("runtime_accessory_slot_bonus", int(context.get("accessory_slot_bonus", 0)))
	owner.set("runtime_laurel_leaf_count", int(context.get("laurel_leaf_count", 0)))
	_perf_end(perf_logger, "process.runtime_perk.sync_owner_effects.stats", sample_start)
	sample_start = _perf_begin(perf_logger)
	var perk_scale: float = max(0.1, float(context.get("player_paddle_size_multiplier", 1.0)))
	owner.set("runtime_paddle_scale", perk_scale)
	var base_width: float = _get_runtime_paddle_base_width(owner)
	var base_height: float = _get_runtime_paddle_base_height(owner)
	var active_item_scale: float = _get_active_item_paddle_scale(registry, get_instance)
	var mythic_item_scale: float = _get_mythic_item_paddle_scale(registry, get_instance)
	var final_scale: float = max(0.1, perk_scale * active_item_scale * mythic_item_scale)
	var current_width: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var current_height: float = max(1.0, float(_safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_pos_value: Variant = _safe_owner_get(owner, "player_pos", Vector2.ZERO)
	var next_width: float = base_width * final_scale
	var next_height: float = base_height * final_scale
	if player_pos_value is Vector2 and (not is_equal_approx(current_width, next_width) or not is_equal_approx(current_height, next_height)):
		var player_pos: Vector2 = player_pos_value
		var center_x: float = player_pos.x + current_width * 0.5
		player_pos.x = _clamp_synced_player_x(
			center_x - next_width * 0.5,
			next_width,
			get_instance.call(registry, "smasher_warp_gate_state")
		)
		var current_bottom: float = player_pos.y + current_height
		if abs(current_bottom - FIELD_HEIGHT) <= max(2.0, current_height * 0.05) or current_bottom > FIELD_HEIGHT:
			player_pos.y = FIELD_HEIGHT - next_height
		owner.set("player_pos", player_pos)
	owner.set("player_paddle_width", next_width)
	owner.set("player_paddle_height", next_height)
	owner.set("player_paddle_scale", max(0.1, next_width / PLAYER_BASE_PADDLE_WIDTH))
	_perf_end(perf_logger, "process.runtime_perk.sync_owner_effects.paddle", sample_start)
	sample_start = _perf_begin(perf_logger)
	apply_training_to_skill_configs(
		registry,
		float(context.get("player_skill_cooldown_multiplier", 1.0)),
		get_instance
	)
	_perf_end(perf_logger, "process.runtime_perk.sync_owner_effects.training", sample_start)


func refresh_item_polish_consumers(owner: Object, registry: Object, get_instance: Callable) -> void:
	refresh_mythic_runtime_perk_consumers(owner, registry, get_instance)


func refresh_mythic_runtime_perk_consumers(owner: Object, registry: Object, get_instance: Callable) -> void:
	var mythic_item_runtime: Object = get_instance.call(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("refresh_runtime_perk_scaling"):
		mythic_item_runtime.refresh_runtime_perk_scaling(owner, registry)


func apply_training_to_skill_configs(registry: Object, multiplier: float, get_instance: Callable) -> void:
	for key in ["smasher_skill_config", "viper_skill_config", "commando_skill_config", "blacksmith_skill_config"]:
		var skill_config: Object = get_instance.call(registry, key)
		if skill_config != null and skill_config.has_method("set_runtime_cooldown_multiplier"):
			skill_config.set_runtime_cooldown_multiplier(multiplier)


func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_active_item_paddle_scale(registry: Object, get_instance: Callable) -> float:
	var active_item_runtime: Object = get_instance.call(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_player_paddle_scale"):
		return max(0.1, float(active_item_runtime.get_player_paddle_scale()))
	return 1.0


func _get_mythic_item_paddle_scale(registry: Object, get_instance: Callable) -> float:
	var mythic_item_runtime: Object = get_instance.call(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_player_paddle_scale"):
		return max(0.1, float(mythic_item_runtime.get_player_paddle_scale()))
	return 1.0


func _get_runtime_paddle_base_width(owner: Object) -> float:
	return max(1.0, float(_safe_owner_get(owner, "runtime_paddle_base_width", PLAYER_BASE_PADDLE_WIDTH)))


func _get_runtime_paddle_base_height(owner: Object) -> float:
	return max(1.0, float(_safe_owner_get(owner, "runtime_paddle_base_height", PLAYER_BASE_PADDLE_HEIGHT)))


func _clamp_synced_player_x(x: float, paddle_width: float, warp_gate_state: Object) -> float:
	if warp_gate_state != null and warp_gate_state.has_method("is_active") and bool(warp_gate_state.is_active()):
		return clamp(x, -max(1.0, paddle_width), FIELD_WIDTH)
	return clamp(x, 0.0, max(0.0, FIELD_WIDTH - max(1.0, paddle_width)))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("end_sample"):
		perf_logger.end_sample(label, start_usec)
