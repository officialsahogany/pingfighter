extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")

const DEFAULT_COOLDOWN_MSEC := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const MAX_ACTIVE_ITEM_SLOTS := 3
const ALCHEMY_NOTICE_DURATION_MSEC := 1000

var slot_key_pressed: Dictionary = {}
var last_item_use_msec: int = -1000000
var gamepad_selected_use_pressed := false
var gamepad_slot_cycle_direction := 0
var cooldown_pause_started_msec := -1

# [AIDBG] manual diagnostic toggle for "active item unusable after stage transition".
# Keep false in committed code; flip to true locally only while diagnosing.
# Gated as a const so real-play and perf-capture logs stay clean by default.
const _AIDBG := false


func reset() -> void:
	slot_key_pressed.clear()
	last_item_use_msec = -1000000
	gamepad_selected_use_pressed = false
	gamepad_slot_cycle_direction = 0
	cooldown_pause_started_msec = -1


func reset_cooldowns_for_stage_transition(active_item_slots: Array) -> Array:
	last_item_use_msec = -1000000
	cooldown_pause_started_msec = -1
	var result: Array = active_item_slots.duplicate(true)
	for i in range(result.size()):
		var slot: Variant = result[i]
		if not (slot is Dictionary):
			continue
		var item: Dictionary = slot
		var item_identity: String = _get_item_identity(item)
		if str(item.get("name", "")) == "" and item_identity != "":
			item["name"] = item_identity
		if item.has("last_use_msec"):
			item["last_use_msec"] = -1
		if item.has("last_use"):
			item["last_use"] = -1
		result[i] = item
	return result


func pause_cooldowns(time_now: int) -> void:
	if cooldown_pause_started_msec >= 0:
		return
	cooldown_pause_started_msec = max(0, time_now)


func resume_cooldowns(time_now: int, active_item_slots: Array = []) -> Array:
	if cooldown_pause_started_msec < 0:
		return active_item_slots
	var pause_duration_msec: int = max(0, time_now - cooldown_pause_started_msec)
	cooldown_pause_started_msec = -1
	if pause_duration_msec <= 0:
		return active_item_slots
	if last_item_use_msec >= 0:
		last_item_use_msec += pause_duration_msec
	var result: Array = active_item_slots.duplicate(true)
	for i in range(result.size()):
		var slot: Variant = result[i]
		if not (slot is Dictionary):
			continue
		var item: Dictionary = slot
		if item.has("last_use_msec"):
			var last_use_msec: int = int(item.get("last_use_msec", -1))
			if last_use_msec >= 0:
				item["last_use_msec"] = last_use_msec + pause_duration_msec
		if item.has("last_use"):
			var last_use: int = int(item.get("last_use", -1))
			if last_use >= 0:
				item["last_use"] = last_use + pause_duration_msec
		result[i] = item
	return result


func get_cooldown_time_msec(current_time_msec: int) -> int:
	return cooldown_pause_started_msec if cooldown_pause_started_msec >= 0 else current_time_msec


func build_starting_slots() -> Array:
	return []


func update(
	owner: Object,
	registry: Object,
	input_locked: bool,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable = Callable(),
	perf_logger: Object = null
) -> Dictionary:
	if owner == null:
		return {}

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if _AIDBG:
		var _aidbg_edge: int = _aidbg_slot_key_edge(active_item_slots.size())
		var _aidbg_pad: bool = GamepadInput.is_active_item_use_pressed() and not gamepad_selected_use_pressed
		if _aidbg_edge >= 0 or _aidbg_pad:
			print("[AIDBG] use attempt key_slot=%d pad=%s empty=%s input_locked=%s slots=%d | %s" % [
				_aidbg_edge,
				str(_aidbg_pad),
				str(active_item_slots.is_empty()),
				str(input_locked),
				active_item_slots.size(),
				_aidbg_lock_breakdown(registry),
			])
	if active_item_slots.is_empty() or input_locked:
		_sync_slot_input_states()
		return {
			"used_slot": -1,
		}

	var slots_copy: Array = []
	var slots_copy_created: bool = false
	var used_slot: int = -1

	var cycle_direction: int = GamepadInput.get_active_item_selection_direction()
	if cycle_direction != 0 and cycle_direction != gamepad_slot_cycle_direction:
		_cycle_selected_slot(registry, active_item_slots, cycle_direction)
	gamepad_slot_cycle_direction = cycle_direction

	var selected_use_pressed: bool = GamepadInput.is_active_item_use_pressed()
	var selected_use_just_pressed: bool = selected_use_pressed and not gamepad_selected_use_pressed
	gamepad_selected_use_pressed = selected_use_pressed
	if selected_use_just_pressed:
		var selected_slot: int = _get_selected_slot_index(registry, active_item_slots)
		slots_copy = _copy_slots_for_use(active_item_slots)
		slots_copy_created = true
		if _try_use_slot(
			selected_slot,
			slots_copy,
			owner,
			registry,
			apply_item_effect_callback,
			pending_use_backup_callback,
			false,
			perf_logger
		):
			used_slot = selected_slot

	var key_count: int = int(min(active_item_slots.size(), SLOT_KEY_CODES.size()))
	if used_slot < 0:
		for i in range(SLOT_KEY_CODES.size()):
			var pressed: bool = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))
			var was_pressed: bool = bool(slot_key_pressed.get(i, false))
			slot_key_pressed[i] = pressed
			if i < key_count and pressed and not was_pressed:
				if not slots_copy_created:
					slots_copy = _copy_slots_for_use(active_item_slots)
					slots_copy_created = true
				if _try_use_slot(
					i,
					slots_copy,
					owner,
					registry,
					apply_item_effect_callback,
					pending_use_backup_callback,
					false,
					perf_logger
				):
					used_slot = i
					break

	if used_slot >= 0:
		owner.set("active_item_slots", slots_copy)

	return {
		"used_slot": used_slot,
	}


func use_slot(
	slot_index: int,
	owner: Object,
	registry: Object,
	input_locked: bool,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable = Callable(),
	perf_logger: Object = null
) -> bool:
	if owner == null:
		return false
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty() or input_locked:
		_sync_slot_input_states()
		return false

	var slots_copy: Array = active_item_slots.duplicate(true)
	var used: bool = _try_use_slot(
		slot_index,
		slots_copy,
		owner,
		registry,
		apply_item_effect_callback,
		pending_use_backup_callback,
		false,
		perf_logger
	)
	if used:
		owner.set("active_item_slots", slots_copy)
	_sync_slot_input_states()
	return used


func use_selected_slot(
	owner: Object,
	registry: Object,
	input_locked: bool,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable = Callable(),
	perf_logger: Object = null
) -> bool:
	if owner == null:
		return false
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty() or input_locked:
		_sync_slot_input_states()
		return false
	return use_slot(
		_get_selected_slot_index(registry, active_item_slots),
		owner,
		registry,
		input_locked,
		apply_item_effect_callback,
		pending_use_backup_callback,
		perf_logger
	)


func cycle_selected_slot(direction: int, owner: Object, registry: Object) -> int:
	if owner == null:
		return -1
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty():
		return -1
	return _cycle_selected_slot(registry, active_item_slots, direction)


func use_first_matching_item(
	item_names: Array,
	owner: Object,
	registry: Object,
	input_locked: bool,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable = Callable(),
	ignore_cooldown: bool = false,
	perf_logger: Object = null
) -> String:
	if owner == null or item_names.is_empty():
		return ""
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty() or input_locked:
		_sync_slot_input_states()
		return ""

	var slots_copy: Array = active_item_slots.duplicate(true)
	for target_name_value in item_names:
		var target_name: String = str(target_name_value)
		if target_name == "":
			continue
		for i in range(slots_copy.size()):
			var item_value: Variant = slots_copy[i]
			if not _slot_matches_item(item_value, target_name):
				continue
			if _try_use_slot(
				i,
				slots_copy,
				owner,
				registry,
				apply_item_effect_callback,
				pending_use_backup_callback,
				ignore_cooldown,
				perf_logger
			):
				owner.set("active_item_slots", slots_copy)
				_sync_slot_input_states()
				return target_name
	_sync_slot_input_states()
	return ""


func store_active_item(
	field_item: Dictionary,
	active_item_slots: Array,
	registry: Object,
	can_store_item_callback: Callable,
	owner: Object = null
) -> bool:
	var compacted: bool = _compact_active_item_slots(active_item_slots)
	if active_item_slots.size() >= _get_max_active_item_slots(registry):
		if compacted and owner != null:
			owner.set("active_item_slots", active_item_slots)
		return false

	var source_item_data: Dictionary = _get_dictionary(field_item, "item_data")
	var item_name: String = str(source_item_data.get("name", ""))
	if can_store_item_callback.is_valid() and not bool(can_store_item_callback.call(item_name)):
		if compacted and owner != null:
			owner.set("active_item_slots", active_item_slots)
		return false

	source_item_data["revealed"] = true
	field_item["item_data"] = source_item_data
	var item_data: Dictionary = source_item_data.duplicate(true)
	item_data = _apply_item_runtime_visual_overrides(item_data, registry)
	item_data["revealed"] = true
	item_data["last_use_msec"] = last_item_use_msec
	active_item_slots.append(item_data)
	var stored_slot_index: int = active_item_slots.size() - 1
	field_item["stored_active_slot_index"] = stored_slot_index
	_select_slot(registry, stored_slot_index)
	return true


func append_item_data(
	owner: Object,
	item_data: Dictionary,
	registry: Object,
	allow_overflow: bool = false,
	can_store_item_callback: Callable = Callable()
) -> bool:
	if owner == null or item_data.is_empty():
		return false
	var item_name: String = str(item_data.get("name", ""))
	if can_store_item_callback.is_valid() and not bool(can_store_item_callback.call(item_name)):
		return false

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var compacted: bool = _compact_active_item_slots(active_item_slots)
	if active_item_slots.size() >= _get_max_active_item_slots(registry) and not allow_overflow:
		if compacted:
			owner.set("active_item_slots", active_item_slots)
		return false

	var next_item: Dictionary = item_data.duplicate(true)
	next_item = _apply_item_runtime_visual_overrides(next_item, registry)
	next_item["revealed"] = true
	next_item["last_use_msec"] = last_item_use_msec
	active_item_slots.append(next_item)
	owner.set("active_item_slots", active_item_slots)
	_select_slot(registry, active_item_slots.size() - 1)
	return true


func _try_use_slot(
	slot_index: int,
	active_item_slots: Array,
	owner: Object,
	registry: Object,
	apply_item_effect_callback: Callable,
	pending_use_backup_callback: Callable = Callable(),
	ignore_cooldown: bool = false,
	perf_logger: Object = null
) -> bool:
	if slot_index < 0 or slot_index >= active_item_slots.size():
		return false

	var item_value: Variant = active_item_slots[slot_index]
	if not (item_value is Dictionary):
		return false

	var item_data: Dictionary = item_value
	_select_slot(registry, slot_index)

	var now_msec: int = Time.get_ticks_msec()
	if not ignore_cooldown and not _is_item_ready(item_data, now_msec, registry):
		return false

	if not apply_item_effect_callback.is_valid():
		return false
	var item_label: String = _build_item_label(item_data)
	var sample_start: int = _perf_begin(perf_logger)
	var applied: bool = bool(apply_item_effect_callback.call(item_data, owner, registry))
	_perf_end(perf_logger, "physics.callback.active_items.use.%s" % item_label, sample_start)
	if not applied:
		return false
	sample_start = _perf_begin(perf_logger)
	_apply_active_item_use_gauge_bonus(owner, registry)
	_perf_end(perf_logger, "physics.callback.active_items.use_gauge_bonus", sample_start)
	var consumable: bool = bool(item_data.get("consumable", true))
	var recycle_triggered: bool = consumable and _should_recycle_used_item(registry)
	if consumable and not recycle_triggered and pending_use_backup_callback.is_valid():
		pending_use_backup_callback.call(item_data.duplicate(true), slot_index, owner, registry)

	item_data["last_use_msec"] = now_msec
	last_item_use_msec = now_msec
	if recycle_triggered:
		_mark_alchemy_notice(item_data, now_msec)
		active_item_slots[slot_index] = item_data
		_play_alchemy_feedback(registry)
	elif consumable:
		active_item_slots.remove_at(slot_index)
		_select_slot(registry, max(0, min(slot_index, active_item_slots.size() - 1)))
	else:
		active_item_slots[slot_index] = item_data
	for i in range(active_item_slots.size()):
		var other_value: Variant = active_item_slots[i]
		if other_value is Dictionary:
			var other_item: Dictionary = other_value
			other_item["last_use_msec"] = now_msec
			active_item_slots[i] = other_item
	return true


func _copy_slots_for_use(active_item_slots: Array) -> Array:
	return active_item_slots.duplicate(true)


func _compact_active_item_slots(active_item_slots: Array) -> bool:
	var write_index := 0
	var changed := false
	for read_index in range(active_item_slots.size()):
		var item_value: Variant = active_item_slots[read_index]
		if not _is_stored_active_item_value(item_value):
			changed = true
			continue
		if write_index != read_index:
			active_item_slots[write_index] = item_value
			changed = true
		write_index += 1
	while active_item_slots.size() > write_index:
		active_item_slots.remove_at(active_item_slots.size() - 1)
		changed = true
	return changed


func _is_stored_active_item_value(item_value: Variant) -> bool:
	if not (item_value is Dictionary):
		return false
	var item_data: Dictionary = item_value
	return _get_item_identity(item_data) != ""


func _slot_matches_item(item_value: Variant, item_name: String) -> bool:
	if not (item_value is Dictionary):
		return false
	var item_data: Dictionary = item_value
	return _get_item_identity(item_data) == item_name or str(item_data.get("effect", "")) == item_name


func _build_item_label(item_data: Dictionary) -> String:
	var raw_label: String = _get_item_identity(item_data)
	if raw_label == "":
		raw_label = "unknown"
	return raw_label.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func _get_item_identity(item_data: Dictionary) -> String:
	for key in ["name", "effect", "item_name", "item_id"]:
		var raw_value: Variant = item_data.get(str(key), "")
		if raw_value == null:
			continue
		var value: String = str(raw_value)
		if value != "":
			return value
	return ""


func _sync_slot_input_states() -> void:
	for i in range(SLOT_KEY_CODES.size()):
		slot_key_pressed[i] = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))
	gamepad_selected_use_pressed = GamepadInput.is_active_item_use_pressed()
	gamepad_slot_cycle_direction = GamepadInput.get_active_item_selection_direction()


func _is_item_ready(item_data: Dictionary, now_msec: int, registry: Object) -> bool:
	var cooldown_msec: int = _get_effective_active_item_cooldown_msec(item_data, registry)
	if now_msec - last_item_use_msec < cooldown_msec:
		if _AIDBG:
			print("[AIDBG] BLOCKED global-cooldown item=%s now=%d anchor=%d remain=%dms cd=%d" % [
				_get_item_identity(item_data), now_msec, last_item_use_msec,
				cooldown_msec - (now_msec - last_item_use_msec), cooldown_msec,
			])
		return false
	var last_use_msec: int = int(item_data.get("last_use_msec", item_data.get("last_use", -1)))
	if last_use_msec < 0:
		return true
	if now_msec - last_use_msec < cooldown_msec:
		if _AIDBG:
			print("[AIDBG] BLOCKED per-item-cooldown item=%s now=%d last_use=%d remain=%dms cd=%d" % [
				_get_item_identity(item_data), now_msec, last_use_msec,
				cooldown_msec - (now_msec - last_use_msec), cooldown_msec,
			])
		return false
	return true


func _get_effective_active_item_cooldown_msec(item_data: Dictionary, registry: Object) -> int:
	var base_cooldown_msec: int = max(0, int(item_data.get("cooldown_msec", item_data.get("cooldown_ms", DEFAULT_COOLDOWN_MSEC))))
	var cooldown_msec: int = base_cooldown_msec
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_cooldown_msec"):
		cooldown_msec = int(runtime_perk_state.get_active_item_cooldown_msec(cooldown_msec))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_cooldown_msec"):
		cooldown_msec = int(mythic_item_runtime.get_active_item_cooldown_msec(cooldown_msec))
	return max(0, cooldown_msec)


func _should_recycle_used_item(registry: Object) -> bool:
	var chance: float = _get_active_item_recycle_chance(registry)
	return chance > 0.0 and randf() < chance


func _get_active_item_recycle_chance(registry: Object) -> float:
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_recycle_chance"):
		return clamp(float(runtime_perk_state.get_active_item_recycle_chance()), 0.0, 0.90)
	return 0.0


func _mark_alchemy_notice(item_data: Dictionary, now_msec: int) -> void:
	item_data["alchemy_notice_until_msec"] = now_msec + ALCHEMY_NOTICE_DURATION_MSEC
	item_data["alchemy_notice_started_msec"] = now_msec


func _play_alchemy_feedback(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_alchemy"):
			audio.play_alchemy()
		elif audio.has_method("play_active_item"):
			audio.play_active_item()


func _get_max_active_item_slots(registry: Object) -> int:
	var capacity: int = MAX_ACTIVE_ITEM_SLOTS
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state != null and runtime_perk_state.has_method("get_active_item_slot_capacity"):
		capacity = int(runtime_perk_state.get_active_item_slot_capacity(capacity))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_active_item_slot_capacity"):
		capacity = int(mythic_item_runtime.get_active_item_slot_capacity(capacity))
	return max(1, capacity)


func _apply_active_item_use_gauge_bonus(owner: Object, registry: Object) -> void:
	if owner == null:
		return
	var runtime_perk_state: Object = _get_instance(registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("get_active_item_use_gauge_bonus"):
		return
	var gauge_bonus: float = float(runtime_perk_state.get_active_item_use_gauge_bonus())
	if gauge_bonus <= 0.0:
		return
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("apply_gold_digger_gauge_bonus"):
		gauge_bonus = float(mythic_item_runtime.apply_gold_digger_gauge_bonus(gauge_bonus))
	var current_gauge: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0))
	var gauge_max: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", 500.0)))
	owner.set("special_gauge", min(gauge_max, current_gauge + gauge_bonus))
	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()


func _apply_item_runtime_visual_overrides(item_data: Dictionary, registry: Object) -> Dictionary:
	var item_name: String = _get_item_identity(item_data)
	var effect_name: String = str(item_data.get("effect", ""))
	if item_name != "boomerang" and effect_name != "boomerang":
		return item_data
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("is_reinforced_boomerang_gauntlet_equipped"):
		return item_data
	if not bool(mythic_item_runtime.is_reinforced_boomerang_gauntlet_equipped()):
		return item_data
	var result: Dictionary = item_data.duplicate(true)
	result["icon_path"] = ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH
	result["color"] = Color(150.0 / 255.0, 220.0 / 255.0, 1.0)
	result["visual_variant"] = "metal"
	return result


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


func _cycle_selected_slot(registry: Object, active_item_slots: Array, direction: int) -> int:
	if active_item_slots.is_empty():
		return -1
	var current_index: int = _get_selected_slot_index(registry, active_item_slots)
	var step: int = int(sign(direction))
	if step == 0:
		return current_index
	var next_index: int = (current_index + step) % active_item_slots.size()
	if next_index < 0:
		next_index += active_item_slots.size()
	_select_slot(registry, next_index)
	return next_index


func _get_selected_slot_index(registry: Object, active_item_slots: Array) -> int:
	if active_item_slots.is_empty():
		return -1
	var selected_index := 0
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("get_selected_index"):
		selected_index = int(hud_state.get_selected_index())
	selected_index = clampi(selected_index, 0, active_item_slots.size() - 1)
	_select_slot(registry, selected_index)
	return selected_index


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


# [AIDBG] temporary diagnostic helpers — remove with the rest of the _AIDBG blocks.
func _aidbg_slot_key_edge(slot_count: int) -> int:
	var limit: int = int(min(slot_count, SLOT_KEY_CODES.size()))
	for i in range(limit):
		if Input.is_key_pressed(int(SLOT_KEY_CODES[i])) and not bool(slot_key_pressed.get(i, false)):
			return i
	return -1


func _aidbg_lock_breakdown(registry: Object) -> String:
	var rs: Object = _get_instance(registry, "round_flow_state")
	var waiting: bool = rs != null and rs.has_method("is_waiting_for_serve") and bool(rs.is_waiting_for_serve())
	var rt: Object = _get_instance(registry, "active_item_runtime")
	var ctrl_locked: bool = rt != null and rt.has_method("is_player_control_locked") and bool(rt.is_player_control_locked())
	var aipill: bool = rt != null and rt.has_method("is_aipill_active") and bool(rt.is_aipill_active())
	return "waiting_for_serve=%s landing_intro=%s ball_spawn_intro=%s ctrl_locked=%s aipill=%s" % [
		str(waiting),
		str(_aidbg_module_active(registry, "stage_landing_intro")),
		str(_aidbg_module_active(registry, "stage_ball_spawn_intro")),
		str(ctrl_locked),
		str(aipill),
	]


func _aidbg_module_active(registry: Object, key: String) -> bool:
	var module: Object = _get_instance(registry, key)
	return module != null and module.has_method("is_active") and bool(module.is_active())
