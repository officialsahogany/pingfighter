extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemCooldownComposer := preload("res://scripts/items/active_item_cooldown_composer.gd")
const ActiveItemSlotCooldownState := preload("res://scripts/items/active_item_slot_cooldown_state.gd")
const GamepadInput := preload("res://scripts/core/gamepad_input.gd")
const GuardianEggAccessPolicy := preload("res://scripts/lingpet/guardian_egg_access_policy.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")

const DEFAULT_COOLDOWN_MSEC := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const MAX_ACTIVE_ITEM_SLOTS := 3
const ALCHEMY_NOTICE_DURATION_MSEC := 1000

var slot_key_pressed: Dictionary = {}
var gamepad_selected_use_pressed := false
var gamepad_slot_cycle_direction := 0
var _cooldown_state: Object = ActiveItemSlotCooldownState.new()
var last_item_use_msec: int:
	get:
		return int(_cooldown_state.last_item_use_msec)
	set(value):
		_cooldown_state.last_item_use_msec = value
var cooldown_pause_started_msec: int:
	get:
		return int(_cooldown_state.cooldown_pause_started_msec)
	set(value):
		_cooldown_state.cooldown_pause_started_msec = value


func reset() -> void:
	slot_key_pressed.clear()
	gamepad_selected_use_pressed = false
	gamepad_slot_cycle_direction = 0
	_cooldown_state.reset()


func reset_cooldowns_for_stage_transition(active_item_slots: Array) -> Array:
	return _cooldown_state.reset_for_stage_transition(active_item_slots)


func pause_cooldowns(time_now: int) -> void:
	_cooldown_state.pause(time_now)


func resume_cooldowns(time_now: int, active_item_slots: Array = []) -> Array:
	return _cooldown_state.resume(time_now, active_item_slots)


func get_cooldown_time_msec(current_time_msec: int) -> int:
	return _cooldown_state.get_effective_time_msec(current_time_msec)


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
				return target_name
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

	# lingpet_egg is a one-shot deploy item: never store a duplicate while one is
	# already held or while the runtime cannot accept another egg acquisition. Reject
	# the pickup; the egg left on the field simply expires. (item_runtime_checklist §1.7)
	if item_name == "lingpet_egg" and _is_lingpet_egg_pickup_redundant(active_item_slots, registry, owner):
		if compacted and owner != null:
			owner.set("active_item_slots", active_item_slots)
		return false

	source_item_data["revealed"] = true
	field_item["item_data"] = source_item_data
	var item_data: Dictionary = source_item_data.duplicate(true)
	item_data = _apply_item_runtime_visual_overrides(item_data, registry)
	item_data["revealed"] = true
	item_data["last_use_msec"] = _cooldown_state.get_inherited_last_use_msec()
	active_item_slots.append(item_data)
	var stored_slot_index: int = active_item_slots.size() - 1
	field_item["stored_active_slot_index"] = stored_slot_index
	_select_slot(registry, stored_slot_index)
	_register_slot_acquire_flight(registry, item_data, stored_slot_index, field_item)
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
	if item_name == "lingpet_egg" and _is_lingpet_egg_pickup_redundant(
		BattleSceneOwnerReader.get_array(owner, "active_item_slots"),
		registry,
		owner
	):
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
	next_item["last_use_msec"] = _cooldown_state.get_inherited_last_use_msec()
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
	# A one-shot deploy item flagged no_recycle (lingpet_egg) must never be kept by
	# the Alchemy recycle perk: a second deploy is impossible while a lingpet is
	# already present, so a recycled egg would strand a permanently-dead, unusable
	# slot for the rest of the battle — the exact dead-duplicate failure class the
	# pickup gate already prevents (item_runtime_checklist §1.7).
	var recyclable: bool = consumable and not bool(item_data.get("no_recycle", false))
	var recycle_triggered: bool = recyclable and _should_recycle_used_item(registry)
	if consumable and not recycle_triggered and pending_use_backup_callback.is_valid():
		pending_use_backup_callback.call(item_data.duplicate(true), slot_index, owner, registry)

	item_data["last_use_msec"] = now_msec
	# An ignore_cooldown use is a forced / automatic use (the Smartphone passive,
	# the only caller that passes ignore_cooldown = true). It bypasses its own
	# readiness check above and is rate-limited separately (smartphone_cooldown_frames),
	# so it must stay cooldown-NEUTRAL toward the player's manual slots: it must not
	# bump the shared global cooldown anchor, nor the per-item cooldown of the other
	# slots. Otherwise the instant the Smartphone auto-consumes one item, the player's
	# remaining (often lone) item is blocked for the full checked-item cooldown and
	# reads as "the first item does nothing" (live godot.log: a gauge_charge auto-use
	# left a lone dash_boost BLOCKED by global-cooldown for the next ~7s).
	if not ignore_cooldown and _uses_global_cooldown(item_data):
		_cooldown_state.start_global_cooldown(now_msec)
	if recycle_triggered:
		_mark_alchemy_notice(item_data, now_msec)
		active_item_slots[slot_index] = item_data
		_play_alchemy_feedback(registry)
	elif consumable:
		active_item_slots.remove_at(slot_index)
		_select_slot(registry, max(0, min(slot_index, active_item_slots.size() - 1)))
	else:
		active_item_slots[slot_index] = item_data
	if not ignore_cooldown and _uses_global_cooldown(item_data):
		_cooldown_state.propagate_global_cooldown(active_item_slots, now_msec)
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
	return _cooldown_state.is_item_ready(
		item_data,
		now_msec,
		cooldown_msec,
		_uses_global_cooldown(item_data)
	)


func _uses_global_cooldown(item_data: Dictionary) -> bool:
	return not bool(item_data.get("no_global_cooldown", false))


func _get_effective_active_item_cooldown_msec(item_data: Dictionary, registry: Object) -> int:
	var base_cooldown_msec: int = max(0, int(item_data.get("cooldown_msec", item_data.get("cooldown_ms", DEFAULT_COOLDOWN_MSEC))))
	return ActiveItemCooldownComposer.compose_effective_cooldown_msec(
		base_cooldown_msec,
		_get_instance(registry, "runtime_perk_state"),
		_get_instance(registry, "mythic_item_runtime")
	)


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
	if mythic_item_runtime == null:
		return item_data
	if not _is_reinforced_boomerang_gauntlet_effect_active(mythic_item_runtime):
		return item_data
	var result: Dictionary = item_data.duplicate(true)
	result["icon_path"] = ActiveItemCatalog.BOOMERANG_METAL_ICON_PATH
	result["color"] = Color(150.0 / 255.0, 220.0 / 255.0, 1.0)
	result["visual_variant"] = "metal"
	return result


func _is_reinforced_boomerang_gauntlet_effect_active(mythic_item_runtime: Object) -> bool:
	if mythic_item_runtime.has_method("is_reinforced_boomerang_gauntlet_effect_active"):
		return bool(mythic_item_runtime.is_reinforced_boomerang_gauntlet_effect_active())
	if mythic_item_runtime.has_method("is_reinforced_boomerang_gauntlet_equipped"):
		return bool(mythic_item_runtime.is_reinforced_boomerang_gauntlet_equipped())
	return false


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


# Register the "fly into the empty slot" acquisition animation for a field pickup.
# hud_state was already instantiated by _select_slot above, so this reuses the cached
# module. A missing field position simply skips the flight (the pickup pop still fires).
func _register_slot_acquire_flight(registry: Object, item_data: Dictionary, slot_index: int, field_item: Dictionary) -> void:
	if slot_index < 0 or item_data.is_empty():
		return
	var source_pos_value: Variant = field_item.get("position", null)
	if not (source_pos_value is Vector2):
		return
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("register_slot_flight"):
		hud_state.register_slot_flight(item_data, slot_index, source_pos_value, Time.get_ticks_msec())


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


func _is_lingpet_egg_pickup_redundant(active_item_slots: Array, registry: Object, owner: Object) -> bool:
	for slot_value in active_item_slots:
		if slot_value is Dictionary and str((slot_value as Dictionary).get("name", "")) == "lingpet_egg":
			return true
	# Authoritative offer / wrong-league check via the runtime. Cache-only peek so
	# the pickup path never lazy-instantiates the lingpet runtime; if it is not cached
	# yet no lingpet can be deployed, so only the in-slot check above applies.
	var lingpet_runtime: Object = _get_cached_instance(registry, "lingpet_egg_runtime")
	if lingpet_runtime != null and lingpet_runtime.has_method("can_offer_egg_item"):
		return not bool(lingpet_runtime.can_offer_egg_item(owner, registry))
	if not GuardianEggAccessPolicy.has_egg_access(owner, registry):
		return true
	return LingpetCollectionState.new().is_auto_present_league(owner)


func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_cached_instance"):
		return null
	return registry.get_cached_instance(key)


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
