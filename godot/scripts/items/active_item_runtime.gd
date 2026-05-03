extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")

const DEFAULT_COOLDOWN_MSEC := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3]
const MAX_ACTIVE_ITEM_SLOTS := 3
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const ITEM_NAME_KO := {
	"flare": "Flare",
	"gauge_charge": "에너지드링크",
	"grenade": "수류탄",
	"long_boost": "거대화포션",
	"regeneration_potion": "재생물약",
}

var slot_key_pressed: Dictionary = {}
var last_item_use_msec: int = -1000000
var item_catalog: Object = ActiveItemCatalog.new()
var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
var throw_controller: Object = ActiveItemThrowController.new()
var effect_controller: Object = ActiveItemEffectController.new()
var debug_spawn_menu: Object = ActiveItemDebugSpawnMenu.new()
var field_renderer: Object = ActiveItemFieldRenderer.new()
var throw_renderer: Object = ActiveItemThrowRenderer.new()
var effect_renderer: Object = ActiveItemEffectRenderer.new()


func _init() -> void:
	reset()


func reset() -> void:
	slot_key_pressed.clear()
	field_spawn_controller.reset()
	throw_controller.reset()
	effect_controller.reset()
	debug_spawn_menu.reset()
	last_item_use_msec = -1000000


func build_starting_slots() -> Array:
	return []


func update(owner: Object, registry: Object, delta: float) -> Dictionary:
	if owner == null:
		return {}

	var throw_locked_at_update_start: bool = is_player_control_locked()

	effect_controller.update(owner, delta)
	field_spawn_controller.update(
		owner,
		registry,
		delta,
		Callable(self, "_store_active_item"),
		Callable(self, "_trigger_pickup_effect")
	)
	throw_controller.update(owner, registry, delta)

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty():
		_sync_slot_key_states()
		effect_controller.sync_long_boost_owner_state(owner)
		return {
			"used_slot": -1,
		}

	if throw_locked_at_update_start or is_player_control_locked():
		_sync_slot_key_states()
		effect_controller.sync_long_boost_owner_state(owner)
		return {
			"used_slot": -1,
		}

	var slots_copy: Array = active_item_slots.duplicate(true)
	var used_slot: int = -1
	var key_count: int = int(min(slots_copy.size(), SLOT_KEY_CODES.size()))
	for i in range(SLOT_KEY_CODES.size()):
		var pressed: bool = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))
		var was_pressed: bool = bool(slot_key_pressed.get(i, false))
		slot_key_pressed[i] = pressed
		if i < key_count and pressed and not was_pressed:
			if _try_use_slot(i, slots_copy, owner, registry):
				used_slot = i
				break

	if used_slot >= 0:
		owner.set("active_item_slots", slots_copy)

	effect_controller.sync_long_boost_owner_state(owner)
	return {
		"used_slot": used_slot,
	}


func draw_field_items(canvas: CanvasItem, registry: Object, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return

	field_renderer.draw(
		canvas,
		field_spawn_controller.get_item_spawn_portals(),
		field_spawn_controller.get_spawned_items(),
		shake_offset
	)

	throw_renderer.draw(
		canvas,
		throw_controller.get_pending_throws(),
		throw_controller.get_grenades(),
		throw_controller.get_flares(),
		throw_controller.get_explosion_zones(),
		throw_controller.get_flare_zones(),
		shake_offset
	)
	effect_renderer.draw_field_effects(
		canvas,
		effect_controller.get_pickup_particles(),
		effect_controller.get_regeneration_potion_rings(),
		effect_controller.get_regeneration_potion_particles(),
		effect_controller.get_long_boost_timer_context(),
		shake_offset
	)


func draw_pickup_effect(canvas: CanvasItem, registry: Object) -> void:
	effect_renderer.draw_pickup_effect(canvas, registry, effect_controller.get_pickup_effect())


func toggle_debug_spawn_menu() -> void:
	debug_spawn_menu.toggle()


func is_debug_spawn_menu_open() -> bool:
	return debug_spawn_menu.is_open()


func is_throw_windup_active() -> bool:
	return throw_controller.is_throw_windup_active()


func is_player_control_locked() -> bool:
	return throw_controller.is_player_control_locked()


func get_player_paddle_scale() -> float:
	return effect_controller.get_player_paddle_scale()


func get_player_paddle_width(base_width: float = PLAYER_BASE_PADDLE_WIDTH) -> float:
	return effect_controller.get_player_paddle_width(base_width)


func get_actor_draw_context() -> Dictionary:
	var context: Dictionary = throw_controller.get_actor_draw_context()
	context["player_paddle_scale"] = effect_controller.get_player_paddle_scale()
	return context


func handle_debug_spawn_menu_click(mouse_position: Vector2, view_size: Vector2) -> bool:
	var result: Dictionary = debug_spawn_menu.handle_click(mouse_position, view_size)
	var item_name: String = str(result.get("item_name", ""))
	if item_name != "":
		debug_spawn_item(item_name)
	return bool(result.get("handled", false))


func debug_spawn_item(item_name: String) -> bool:
	return field_spawn_controller.debug_spawn_item(item_name)


func draw_debug_spawn_menu(canvas: CanvasItem, view_size: Vector2) -> void:
	debug_spawn_menu.draw(canvas, view_size)


func _try_use_slot(slot_index: int, active_item_slots: Array, owner: Object, registry: Object) -> bool:
	if slot_index < 0 or slot_index >= active_item_slots.size():
		return false

	var item_value: Variant = active_item_slots[slot_index]
	if not (item_value is Dictionary):
		return false

	var item_data: Dictionary = item_value
	_select_slot(registry, slot_index)

	var now_msec: int = Time.get_ticks_msec()
	if not _is_item_ready(item_data, now_msec):
		return false

	if not _apply_item_effect(item_data, owner, registry):
		return false

	item_data["last_use_msec"] = now_msec
	last_item_use_msec = now_msec
	if bool(item_data.get("consumable", true)):
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


func _sync_slot_key_states() -> void:
	for i in range(SLOT_KEY_CODES.size()):
		slot_key_pressed[i] = Input.is_key_pressed(int(SLOT_KEY_CODES[i]))


func _apply_item_effect(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	var item_name: String = str(item_data.get("name", ""))
	var effect_name: String = str(item_data.get("effect", item_name))
	if item_name == "gauge_charge" or effect_name == "gauge_charge":
		return effect_controller.apply_gauge_charge(item_data, owner, registry)
	if item_name == "grenade" or effect_name == "grenade":
		return throw_controller.activate_grenade(owner, registry)
	if item_name == "flare" or effect_name == "flare":
		return throw_controller.activate_flare(owner, registry)
	if item_name == "long_boost" or effect_name == "long_boost":
		return effect_controller.activate_long_boost(owner, registry)
	if item_name == "regeneration_potion" or effect_name == "regeneration_potion":
		return effect_controller.apply_regeneration_potion(owner, registry)
	return false


func _is_item_ready(item_data: Dictionary, now_msec: int) -> bool:
	var cooldown_msec: int = max(0, int(item_data.get("cooldown_msec", DEFAULT_COOLDOWN_MSEC)))
	if now_msec - last_item_use_msec < cooldown_msec:
		return false
	var last_use_msec: int = int(item_data.get("last_use_msec", item_data.get("last_use", -1)))
	if last_use_msec < 0:
		return true
	return now_msec - last_use_msec >= cooldown_msec


func _select_slot(registry: Object, slot_index: int) -> void:
	var hud_state: Object = _get_instance(registry, "active_item_hud_state")
	if hud_state != null and hud_state.has_method("set_selected_index"):
		hud_state.set_selected_index(slot_index)


func get_boss_ai_context() -> Dictionary:
	return throw_controller.get_boss_ai_context()


func _store_active_item(field_item: Dictionary, active_item_slots: Array, registry: Object) -> bool:
	if active_item_slots.size() >= MAX_ACTIVE_ITEM_SLOTS:
		return false
	var source_item_data: Dictionary = _get_dictionary(field_item, "item_data")
	if not effect_controller.can_store_item(str(source_item_data.get("name", ""))):
		return false
	source_item_data["revealed"] = true
	field_item["item_data"] = source_item_data
	var item_data: Dictionary = source_item_data.duplicate(true)
	item_data["revealed"] = true
	item_data["last_use_msec"] = last_item_use_msec
	active_item_slots.append(item_data)
	_select_slot(registry, active_item_slots.size() - 1)
	return true


func _trigger_pickup_effect(field_item: Dictionary, registry: Object) -> void:
	var item_data: Dictionary = _get_dictionary(field_item, "item_data").duplicate(true)
	var item_name: String = str(item_data.get("name", ""))
	effect_controller.trigger_pickup_effect(
		field_item,
		_get_korean_item_name(item_name),
		_get_item_color(item_data),
		registry
	)


func _get_korean_item_name(item_name: String) -> String:
	if item_name == "long_boost":
		return "거대화포션"
	return str(ITEM_NAME_KO.get(item_name, item_catalog.get_display_name(item_name)))


func _get_item_color(item_data: Dictionary) -> Color:
	return _get_color(item_data.get("color", Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)), Color(200.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0))


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
