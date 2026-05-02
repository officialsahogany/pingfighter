extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_COOLDOWN_MSEC := 10000
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 220.0
const GAUGE_CHARGE_ICON_PATH := "res://assets/sprites/items/gauge_200.png"
const GRENADE_ICON_PATH := "res://assets/sprites/items/grenade.png"
const UNKNOWN_ITEM_SHEET_PATH := "res://assets/sprites/items/unknown_item_hq_sprite_sheet.png"
const UNKNOWN_ITEM_FALLBACK_PATH := "res://assets/sprites/items/unknown_item_hq_sprite.png"
const UNKNOWN_ITEM_FRAME_MSEC := 140
const ITEM_SPAWN_PORTAL_SHEET_PATH := "res://assets/sprites/effects/item_spawn_portal_sheet_imagegen_v1.png"
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3]
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const MAX_ACTIVE_ITEM_SLOTS := 3
const FIELD_ITEM_RADIUS := 15.0
const FIELD_ITEM_DRAW_SIZE := 60.0
const FIELD_ITEM_COLLISION_SIZE := 30.0
const SPAWN_DELAY_MIN_MSEC := 20000
const SPAWN_DELAY_MAX_MSEC := 50000
const SPAWN_VELOCITY_CHOICES := [-4.0, -3.0, 3.0, 4.0]
const SPAWN_SPARK_DURATION_SEC := 1.0
const ITEM_SPAWN_PORTAL_FRAME_COUNT := 16
const ITEM_SPAWN_PORTAL_SHEET_ROWS := 4
const ITEM_SPAWN_PORTAL_SHEET_COLS := 4
const ITEM_SPAWN_PORTAL_RELEASE_FRAME := 8
const ITEM_SPAWN_PORTAL_DURATION_MSEC := 1000
const ITEM_SPAWN_PORTAL_DRAW_SIZE := 104.0
const ITEM_SPAWN_PORTAL_RELEASE_DELAY_MSEC := 438
const PICKUP_EFFECT_DURATION_SEC := 2.0
const PICKUP_FADE_DURATION_SEC := 1.0
const PICKUP_ICON_SIZE := 40.0
const PICKUP_TARGET := Vector2(100.0, FIELD_HEIGHT * 0.5)
const THROW_LOCK_MSEC := 3000
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_SPEED_PER_FRAME := 12.0
const GRENADE_AIM_ERROR_DEGREES := 15.0
const GRENADE_TARGET_RANDOM_X := 30.0
const GRENADE_TARGET_REACHED_DISTANCE := 30.0
const GRENADE_DRAW_SIZE := 36.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const GRENADE_BOSS_STUN_FRAMES := 126.0
const GRENADE_BOSS_KNOCKBACK_FRAMES := 18.0
const GRENADE_BOSS_KNOCKBACK_POWER := 38.4
const GRENADE_BOSS_KNOCKBACK_DECAY := 0.88
const DEBUG_SPAWN_MENU_MARGIN := 18.0
const DEBUG_SPAWN_MENU_TOP := 70.0
const DEBUG_SPAWN_MENU_WIDTH := 330.0
const DEBUG_SPAWN_MENU_TITLE_HEIGHT := 48.0
const DEBUG_SPAWN_MENU_ROW_HEIGHT := 58.0
const DEBUG_SPAWN_MENU_ICON_SIZE := 36.0
const ITEM_NAME_KO := {
	"gauge_charge": "에너지드링크",
	"grenade": "수류탄",
}

var slot_key_pressed: Dictionary = {}
var spawned_items: Array[Dictionary] = []
var pending_spawn_items: Array[Dictionary] = []
var item_spawn_portals: Array[Dictionary] = []
var pending_grenade_throws: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var explosion_zones: Array[Dictionary] = []
var pickup_particles: Array[Dictionary] = []
var pickup_effect: Dictionary = {}
var grenade_boss_stun_timer_frames: float = 0.0
var grenade_boss_knockback_timer_frames: float = 0.0
var grenade_boss_knockback_vel: float = 0.0
var last_item_spawn_msec: int = 0
var next_item_spawn_delay_msec: int = 0
var last_item_use_msec: int = -1000000
var debug_spawn_menu_open := false
var portal_sheet_texture: Texture2D
var gauge_charge_icon_texture: Texture2D
var unknown_item_sheet_texture: Texture2D
var unknown_item_fallback_texture: Texture2D
var grenade_icon_texture: Texture2D


func _init() -> void:
	reset()


func reset() -> void:
	slot_key_pressed.clear()
	spawned_items.clear()
	pending_spawn_items.clear()
	item_spawn_portals.clear()
	pending_grenade_throws.clear()
	grenades.clear()
	explosion_zones.clear()
	pickup_particles.clear()
	pickup_effect.clear()
	grenade_boss_stun_timer_frames = 0.0
	grenade_boss_knockback_timer_frames = 0.0
	grenade_boss_knockback_vel = 0.0
	debug_spawn_menu_open = false
	last_item_use_msec = -1000000
	_reset_spawn_timer()


func build_starting_slots() -> Array:
	return []


func update(owner: Object, registry: Object, delta: float) -> Dictionary:
	if owner == null:
		return {}

	_update_spawn_timer(owner)
	_release_pending_spawn_items()
	_update_item_spawn_portals()
	_update_field_items(owner, registry, delta)
	_update_grenade_throw_windups(owner, registry)
	_update_grenades(owner, registry, delta)
	_update_explosion_zones(delta)
	_update_grenade_boss_effect(delta)
	_update_pickup_particles(delta)
	_update_pickup_effect(delta)

	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	if active_item_slots.is_empty():
		_sync_slot_key_states()
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

	return {
		"used_slot": used_slot,
	}


func draw_field_items(canvas: CanvasItem, registry: Object, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return

	_draw_item_spawn_portals(canvas, shake_offset)

	for item in spawned_items:
		_draw_spawn_electric_spark(canvas, item, shake_offset)
		_draw_field_item(canvas, item, registry, shake_offset)

	_draw_grenade_throw_windups(canvas, shake_offset)
	_draw_grenades(canvas, shake_offset)
	_draw_explosion_zones(canvas, shake_offset)

	for particle in pickup_particles:
		_draw_pickup_particle(canvas, particle, shake_offset)


func draw_pickup_effect(canvas: CanvasItem, registry: Object) -> void:
	if canvas == null or pickup_effect.is_empty():
		return

	var center: Vector2 = _get_vector2(pickup_effect, "position", Vector2.ZERO)
	var alpha: float = clamp(float(pickup_effect.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= 0.0:
		return

	_draw_pickup_glow(canvas, center, alpha)

	var icon_texture: Texture2D = _get_item_icon_texture(_get_dictionary(pickup_effect, "item_data"), registry)
	if icon_texture != null:
		var icon_rect := Rect2(
			center - Vector2(PICKUP_ICON_SIZE, PICKUP_ICON_SIZE) * 0.5,
			Vector2(PICKUP_ICON_SIZE, PICKUP_ICON_SIZE)
		)
		canvas.draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_circle(center, PICKUP_ICON_SIZE * 0.45, Color(1.0, 100.0 / 255.0, 1.0, 0.85 * alpha))

	var item_name: String = str(pickup_effect.get("display_name", ""))
	_draw_centered_text(canvas, item_name, center + Vector2(0.0, 54.0), 16, Color(1.0, 1.0, 1.0, alpha))
	_draw_centered_text(canvas, "획득!", center + Vector2(0.0, 70.0), 14, Color(1.0, 215.0 / 255.0, 0.0, alpha))


func toggle_debug_spawn_menu() -> void:
	debug_spawn_menu_open = not debug_spawn_menu_open


func is_debug_spawn_menu_open() -> bool:
	return debug_spawn_menu_open


func handle_debug_spawn_menu_click(mouse_position: Vector2, view_size: Vector2) -> bool:
	if not debug_spawn_menu_open:
		return false
	var panel_rect: Rect2 = _get_debug_spawn_menu_panel_rect(view_size)
	if not panel_rect.has_point(mouse_position):
		debug_spawn_menu_open = false
		return true

	var entries: Array[Dictionary] = _get_debug_spawn_entries()
	for i in range(entries.size()):
		var row_rect: Rect2 = _get_debug_spawn_menu_row_rect(panel_rect, i)
		if row_rect.has_point(mouse_position):
			debug_spawn_item(str(entries[i].get("name", "")))
			debug_spawn_menu_open = false
			return true
	return true


func debug_spawn_item(item_name: String) -> bool:
	var item_data: Dictionary = _build_item_by_name(item_name)
	if item_data.is_empty():
		return false
	item_data["revealed"] = false
	spawned_items.append(_build_field_item(item_data, _roll_field_item_position()))
	last_item_spawn_msec = Time.get_ticks_msec()
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()
	return true


func draw_debug_spawn_menu(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null or not debug_spawn_menu_open:
		return

	var panel_rect: Rect2 = _get_debug_spawn_menu_panel_rect(view_size)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, 0.26))
	canvas.draw_rect(panel_rect, Color(0.04, 0.05, 0.07, 0.94))
	canvas.draw_rect(panel_rect, Color(0.30, 0.74, 1.0, 0.88), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var title_pos := panel_rect.position + Vector2(16.0, 30.0)
	canvas.draw_string(font, title_pos, "F2 Item Spawn", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.82, 0.95, 1.0, 1.0))
	canvas.draw_string(font, panel_rect.position + Vector2(16.0, 48.0), "Click an item to spawn it now", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.72, 0.78, 0.84, 1.0))

	var mouse_pos: Vector2 = canvas.get_viewport().get_mouse_position()
	var entries: Array[Dictionary] = _get_debug_spawn_entries()
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var row_rect: Rect2 = _get_debug_spawn_menu_row_rect(panel_rect, i)
		var hovered: bool = row_rect.has_point(mouse_pos)
		var base_color := Color(0.10, 0.12, 0.16, 0.95)
		if hovered:
			base_color = Color(0.14, 0.20, 0.27, 0.98)
		canvas.draw_rect(row_rect, base_color)
		canvas.draw_rect(row_rect, Color(0.24, 0.36, 0.48, 0.65), false, 1.0)

		var item_name: String = str(entry.get("name", ""))
		var icon_center: Vector2 = row_rect.position + Vector2(28.0, row_rect.size.y * 0.5)
		_draw_debug_spawn_entry_icon(canvas, item_name, icon_center)
		canvas.draw_string(font, row_rect.position + Vector2(56.0, 23.0), str(entry.get("title", item_name)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(1.0, 1.0, 1.0, 1.0))
		canvas.draw_string(font, row_rect.position + Vector2(56.0, 42.0), str(entry.get("subtitle", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.70, 0.76, 0.82, 1.0))


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
		return _apply_gauge_charge(item_data, owner, registry)
	if item_name == "grenade" or effect_name == "grenade":
		return _activate_grenade(item_data, owner, registry)
	return false


func _apply_gauge_charge(item_data: Dictionary, owner: Object, registry: Object) -> bool:
	var gauge_gain: float = float(item_data.get("gauge_gain", GAUGE_CHARGE_AMOUNT))
	var gauge_max: float = _get_effective_gauge_max(owner, item_data)
	var current_gauge: float = float(BattleSceneOwnerReader.get_value(owner, "special_gauge", 0.0))
	var next_gauge: float = min(gauge_max, current_gauge + gauge_gain)
	owner.set("special_gauge", next_gauge)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null:
		if feedback.has_method("trigger_gauge_flash"):
			feedback.trigger_gauge_flash()
		if feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(0.06, 1.6)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_drink"):
		audio.play_drink()

	return true


func _activate_grenade(_item_data: Dictionary, owner: Object, registry: Object) -> bool:
	if _is_throw_locked(registry):
		return false

	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 50.0))
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var player_center := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target := Vector2(
		boss_pos.x + 100.0 * 0.5 + randf_range(-GRENADE_TARGET_RANDOM_X, GRENADE_TARGET_RANDOM_X),
		boss_pos.y + 20.0
	)
	pending_grenade_throws.append({
		"start_msec": Time.get_ticks_msec(),
		"release_msec": Time.get_ticks_msec() + GRENADE_THROW_WINDUP_MSEC,
		"start_position": player_center,
		"target_position": target,
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null:
		if audio.has_method("play_throw_before"):
			audio.play_throw_before()

	return true


func _is_throw_locked(registry: Object) -> bool:
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state == null or not round_state.has_method("get_round_start_time_msec"):
		return false
	var round_start_msec: int = int(round_state.get_round_start_time_msec())
	if round_start_msec <= 0:
		return false
	return Time.get_ticks_msec() - round_start_msec < THROW_LOCK_MSEC


func _get_effective_gauge_max(owner: Object, item_data: Dictionary) -> float:
	var fallback_max: float = max(1.0, float(item_data.get("gauge_max", GAUGE_MAX)))
	return max(1.0, float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", fallback_max)))


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


func _build_gauge_charge() -> Dictionary:
	return {
		"name": "gauge_charge",
		"display_name": "Energy Drink",
		"type": "active",
		"effect": "gauge_charge",
		"chance": 0.042,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"gauge_gain": GAUGE_CHARGE_AMOUNT,
		"gauge_max": GAUGE_MAX,
		"icon_path": GAUGE_CHARGE_ICON_PATH,
		"color": Color(1.0, 100.0 / 255.0, 1.0),
		"consumable": true,
	}


func _build_grenade() -> Dictionary:
	return {
		"name": "grenade",
		"display_name": "Grenade",
		"type": "active",
		"effect": "grenade",
		"chance": 0.018,
		"duration": 600,
		"cooldown_msec": DEFAULT_COOLDOWN_MSEC,
		"icon_path": GRENADE_ICON_PATH,
		"color": Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0),
		"consumable": true,
		"count": 1,
	}


func _build_item_by_name(item_name: String) -> Dictionary:
	match item_name:
		"gauge_charge":
			return _build_gauge_charge()
		"grenade":
			return _build_grenade()
	return {}


func _build_random_spawn_item() -> Dictionary:
	var candidates: Array[Dictionary] = [
		_build_gauge_charge(),
		_build_grenade(),
	]
	var total_weight: float = 0.0
	for candidate in candidates:
		total_weight += max(0.0, float(candidate.get("chance", 0.0)))
	var roll: float = randf() * max(0.001, total_weight)
	for candidate in candidates:
		roll -= max(0.0, float(candidate.get("chance", 0.0)))
		if roll <= 0.0:
			return candidate.duplicate(true)
	return candidates.back().duplicate(true)


func _update_spawn_timer(owner: Object) -> void:
	if _is_item_spawn_blocked(owner):
		_reset_spawn_timer()
		return
	if not spawned_items.is_empty():
		return
	if not pending_spawn_items.is_empty() or not item_spawn_portals.is_empty():
		return

	var now_msec: int = Time.get_ticks_msec()
	if last_item_spawn_msec <= 0:
		last_item_spawn_msec = now_msec
		return
	if now_msec - last_item_spawn_msec < next_item_spawn_delay_msec:
		return

	_queue_gauge_charge_after_portal()
	last_item_spawn_msec = now_msec
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()


func _update_field_items(owner: Object, registry: Object, delta: float) -> void:
	if spawned_items.is_empty():
		return

	var player_rect := Rect2(
		BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO),
		Vector2(155.0, 50.0)
	)
	var active_item_slots: Array = BattleSceneOwnerReader.get_array(owner, "active_item_slots")
	var slots_changed := false
	var next_items: Array[Dictionary] = []
	var fps_scale: float = delta * 60.0

	for field_item in spawned_items:
		if bool(field_item.get("spawn_skip_update_once", false)):
			field_item["spawn_skip_update_once"] = false
			next_items.append(field_item)
			continue

		var item_pos: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO)
		var item_vel: Vector2 = _get_vector2(field_item, "velocity", Vector2.ZERO)
		item_pos += item_vel * fps_scale
		var bounce_count: int = int(field_item.get("bounce_count", 0))

		if item_pos.x <= FIELD_ITEM_RADIUS or item_pos.x >= FIELD_WIDTH - FIELD_ITEM_RADIUS:
			item_pos.x = clamp(item_pos.x, FIELD_ITEM_RADIUS, FIELD_WIDTH - FIELD_ITEM_RADIUS)
			item_vel.x *= -1.0
			bounce_count += 1
		if item_pos.y <= FIELD_ITEM_RADIUS or item_pos.y >= FIELD_HEIGHT - FIELD_ITEM_RADIUS:
			item_pos.y = clamp(item_pos.y, FIELD_ITEM_RADIUS, FIELD_HEIGHT - FIELD_ITEM_RADIUS)
			item_vel.y *= -1.0
			bounce_count += 1

		field_item["position"] = item_pos
		field_item["velocity"] = item_vel
		field_item["bounce_count"] = bounce_count
		field_item["angle_degrees"] = fmod(float(field_item.get("angle_degrees", 0.0)) + 2.0 * fps_scale, 360.0)
		field_item["spawn_spark_timer"] = max(0.0, float(field_item.get("spawn_spark_timer", 0.0)) - delta)

		var item_rect := Rect2(
			item_pos - Vector2(FIELD_ITEM_COLLISION_SIZE, FIELD_ITEM_COLLISION_SIZE) * 0.5,
			Vector2(FIELD_ITEM_COLLISION_SIZE, FIELD_ITEM_COLLISION_SIZE)
		)
		if item_rect.intersects(player_rect) and _store_active_item(field_item, active_item_slots, registry):
			slots_changed = true
			_trigger_pickup_effect(field_item, registry)
			continue

		if bounce_count < int(field_item.get("max_bounces", 10)):
			next_items.append(field_item)

	spawned_items = next_items
	if slots_changed:
		owner.set("active_item_slots", active_item_slots)


func _update_pickup_particles(delta: float) -> void:
	if pickup_particles.is_empty():
		return
	var survivors: Array[Dictionary] = []
	for particle in pickup_particles:
		var age: float = float(particle.get("age", 0.0)) + delta
		var lifetime: float = max(0.01, float(particle.get("lifetime", 0.45)))
		if age >= lifetime:
			continue
		particle["age"] = age
		particle["position"] = _get_vector2(particle, "position", Vector2.ZERO) + _get_vector2(particle, "velocity", Vector2.ZERO) * delta
		particle["velocity"] = _get_vector2(particle, "velocity", Vector2.ZERO) * 0.94
		survivors.append(particle)
	pickup_particles = survivors


func _update_pickup_effect(delta: float) -> void:
	if pickup_effect.is_empty():
		return
	var timer: float = float(pickup_effect.get("timer", 0.0)) - delta
	if timer <= 0.0:
		pickup_effect.clear()
		return
	pickup_effect["timer"] = timer
	var progress: float = 1.0 - (timer / PICKUP_EFFECT_DURATION_SEC)
	var ease_progress: float = 1.0 - pow(1.0 - clamp(progress, 0.0, 1.0), 2.0)
	var start_pos: Vector2 = _get_vector2(pickup_effect, "start_position", Vector2.ZERO)
	pickup_effect["position"] = start_pos.lerp(PICKUP_TARGET, ease_progress)
	if timer < PICKUP_FADE_DURATION_SEC:
		pickup_effect["alpha"] = clamp(timer / PICKUP_FADE_DURATION_SEC, 0.0, 1.0)
	else:
		pickup_effect["alpha"] = 180.0 / 255.0


func _update_grenade_throw_windups(owner: Object, registry: Object) -> void:
	if pending_grenade_throws.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for pending_throw in pending_grenade_throws:
		if now_msec < int(pending_throw.get("release_msec", now_msec)):
			survivors.append(pending_throw)
			continue
		_throw_grenade(owner, pending_throw, registry)
	pending_grenade_throws = survivors


func _throw_grenade(owner: Object, pending_throw: Dictionary, registry: Object) -> void:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", _get_vector2(pending_throw, "start_position", Vector2.ZERO))
	var start_pos := Vector2(player_pos.x + 155.0 * 0.5, player_pos.y + 25.0)
	var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos + Vector2(0.0, -120.0))
	var direction: Vector2 = target_pos - start_pos
	if direction.length() <= 0.001:
		direction = Vector2.UP
	else:
		direction = direction.normalized()
	direction = direction.rotated(deg_to_rad(randf_range(-GRENADE_AIM_ERROR_DEGREES, GRENADE_AIM_ERROR_DEGREES)))
	grenades.append({
		"position": start_pos,
		"velocity": direction * GRENADE_SPEED_PER_FRAME,
		"target_position": target_pos,
		"rotation_degrees": 0.0,
		"trail": [start_pos],
	})

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw"):
		audio.play_throw()


func _update_grenades(owner: Object, registry: Object, delta: float) -> void:
	if grenades.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var survivors: Array[Dictionary] = []
	for grenade in grenades:
		var pos: Vector2 = _get_vector2(grenade, "position", Vector2.ZERO)
		var vel: Vector2 = _get_vector2(grenade, "velocity", Vector2.ZERO)
		var target: Vector2 = _get_vector2(grenade, "target_position", pos)
		pos += vel * fps_scale
		grenade["position"] = pos
		grenade["velocity"] = vel
		grenade["rotation_degrees"] = fposmod(float(grenade.get("rotation_degrees", 0.0)) + 15.0 * fps_scale, 360.0)
		var trail: Array = grenade.get("trail", [])
		trail.append(pos)
		while trail.size() > 10:
			trail.pop_front()
		grenade["trail"] = trail

		if pos.distance_to(target) <= GRENADE_TARGET_REACHED_DISTANCE:
			_trigger_grenade_explosion(owner, registry, pos)
			continue
		if pos.y <= 10.0:
			_trigger_grenade_explosion(owner, registry, Vector2(pos.x, 10.0))
			continue

		var wall_margin := 10.0
		if pos.x <= wall_margin:
			pos.x = wall_margin
			vel.x = abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			grenade["position"] = pos
			grenade["velocity"] = vel
		elif pos.x >= FIELD_WIDTH - wall_margin:
			pos.x = FIELD_WIDTH - wall_margin
			vel.x = -abs(vel.x) * 0.7
			if vel.y > 0.0:
				vel.y = -abs(vel.y) * 0.5
			grenade["position"] = pos
			grenade["velocity"] = vel

		if pos.x < -100.0 or pos.x > FIELD_WIDTH + 100.0 or pos.y > FIELD_HEIGHT + 100.0:
			continue
		survivors.append(grenade)
	grenades = survivors


func _trigger_grenade_explosion(owner: Object, registry: Object, center: Vector2) -> void:
	explosion_zones.append({
		"position": center,
		"radius": GRENADE_EXPLOSION_RADIUS,
		"duration_frames": GRENADE_EXPLOSION_DURATION_FRAMES,
		"max_duration_frames": GRENADE_EXPLOSION_DURATION_FRAMES,
		"active": true,
		"source": "grenade",
	})
	_apply_grenade_boss_effect(owner, center, GRENADE_EXPLOSION_RADIUS)

	var feedback: Object = _get_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(0.24, 7.0)

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_grenade_explosion"):
		audio.play_grenade_explosion()


func _apply_grenade_boss_effect(owner: Object, center: Vector2, radius: float) -> void:
	if owner == null:
		return
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2(FIELD_WIDTH * 0.5 - 50.0, 25.0))
	var boss_center := Vector2(boss_pos.x + 50.0, boss_pos.y + 20.0)
	if boss_center.distance_to(center) > radius:
		return
	grenade_boss_stun_timer_frames = max(grenade_boss_stun_timer_frames, GRENADE_BOSS_STUN_FRAMES)
	grenade_boss_knockback_timer_frames = max(grenade_boss_knockback_timer_frames, GRENADE_BOSS_KNOCKBACK_FRAMES)
	var direction: float = 1.0 if boss_center.x >= center.x else -1.0
	var knockback_vel: float = direction * GRENADE_BOSS_KNOCKBACK_POWER
	if abs(knockback_vel) >= abs(grenade_boss_knockback_vel):
		grenade_boss_knockback_vel = knockback_vel


func _update_explosion_zones(delta: float) -> void:
	if explosion_zones.is_empty():
		return
	var fps_scale: float = delta * 60.0
	var survivors: Array[Dictionary] = []
	for zone in explosion_zones:
		var remaining: float = float(zone.get("duration_frames", 0.0)) - fps_scale
		if remaining <= 0.0:
			continue
		zone["duration_frames"] = remaining
		survivors.append(zone)
	explosion_zones = survivors


func _update_grenade_boss_effect(delta: float) -> void:
	var fps_scale: float = delta * 60.0
	grenade_boss_stun_timer_frames = max(0.0, grenade_boss_stun_timer_frames - fps_scale)
	if grenade_boss_knockback_timer_frames > 0.0:
		grenade_boss_knockback_timer_frames = max(0.0, grenade_boss_knockback_timer_frames - fps_scale)
		grenade_boss_knockback_vel *= pow(GRENADE_BOSS_KNOCKBACK_DECAY, fps_scale)
		if grenade_boss_knockback_timer_frames <= 0.0 or abs(grenade_boss_knockback_vel) <= 0.3:
			grenade_boss_knockback_timer_frames = 0.0
			grenade_boss_knockback_vel = 0.0
	elif abs(grenade_boss_knockback_vel) > 0.0:
		grenade_boss_knockback_vel = 0.0


func get_boss_ai_context() -> Dictionary:
	return {
		"active_item_grenade_stun_active": grenade_boss_stun_timer_frames > 0.0,
		"active_item_grenade_knockback_active": grenade_boss_knockback_timer_frames > 0.0 and abs(grenade_boss_knockback_vel) > 0.0,
		"active_item_grenade_knockback_vel": grenade_boss_knockback_vel,
	}


func _store_active_item(field_item: Dictionary, active_item_slots: Array, registry: Object) -> bool:
	if active_item_slots.size() >= MAX_ACTIVE_ITEM_SLOTS:
		return false
	var source_item_data: Dictionary = _get_dictionary(field_item, "item_data")
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
	var start_pos: Vector2 = _get_vector2(field_item, "position", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5))
	var item_name: String = str(item_data.get("name", ""))
	pickup_effect = {
		"item_data": item_data,
		"display_name": _get_korean_item_name(item_name),
		"timer": PICKUP_EFFECT_DURATION_SEC,
		"alpha": 180.0 / 255.0,
		"position": start_pos,
		"start_position": start_pos,
	}
	_create_balloon_pop_particles(start_pos, _get_item_color(item_data))

	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_item_get"):
		audio.play_item_get()


func _queue_gauge_charge_after_portal() -> void:
	var item_data: Dictionary = _build_random_spawn_item()
	item_data["revealed"] = false
	var position: Vector2 = _roll_field_item_position()
	var field_item: Dictionary = _build_field_item(item_data, position)
	var now_msec: int = Time.get_ticks_msec()
	pending_spawn_items.append({
		"item": field_item,
		"release_msec": now_msec + ITEM_SPAWN_PORTAL_RELEASE_DELAY_MSEC,
	})
	item_spawn_portals.append({
		"position": position,
		"start_msec": now_msec,
		"duration_msec": ITEM_SPAWN_PORTAL_DURATION_MSEC,
	})


func _roll_field_item_position() -> Vector2:
	return Vector2(
		randf_range(FIELD_ITEM_RADIUS, FIELD_WIDTH - FIELD_ITEM_RADIUS),
		randf_range(FIELD_ITEM_RADIUS, FIELD_HEIGHT - FIELD_ITEM_RADIUS)
	)


func _build_field_item(item_data: Dictionary, position: Vector2) -> Dictionary:
	return {
		"item_data": item_data,
		"position": position,
		"velocity": Vector2(_roll_spawn_velocity_component(), _roll_spawn_velocity_component()),
		"angle_degrees": 0.0,
		"bounce_count": 0,
		"max_bounces": randi_range(6, 9),
		"spawn_spark_timer": SPAWN_SPARK_DURATION_SEC,
		"spawn_skip_update_once": true,
	}


func _release_pending_spawn_items() -> void:
	if pending_spawn_items.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for pending in pending_spawn_items:
		if now_msec < int(pending.get("release_msec", now_msec)):
			survivors.append(pending)
			continue
		var item_value: Variant = pending.get("item", {})
		if item_value is Dictionary:
			spawned_items.append(item_value)
	pending_spawn_items = survivors


func _update_item_spawn_portals() -> void:
	if item_spawn_portals.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var survivors: Array[Dictionary] = []
	for portal in item_spawn_portals:
		var start_msec: int = int(portal.get("start_msec", now_msec))
		var duration_msec: int = max(1, int(portal.get("duration_msec", ITEM_SPAWN_PORTAL_DURATION_MSEC)))
		if now_msec - start_msec < duration_msec:
			survivors.append(portal)
	item_spawn_portals = survivors


func _draw_field_item(canvas: CanvasItem, field_item: Dictionary, _registry: Object, shake_offset: Vector2) -> void:
	var center: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO) + shake_offset
	var item_data: Dictionary = _get_dictionary(field_item, "item_data")
	var item_color: Color = _get_item_color(item_data)
	var t: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(t * 5.2)
	var glow_radius: float = FIELD_ITEM_DRAW_SIZE * (0.38 + pulse * 0.05)
	canvas.draw_circle(center, glow_radius, Color(item_color.r, item_color.g, item_color.b, 0.20))
	canvas.draw_circle(center, FIELD_ITEM_DRAW_SIZE * 0.31, Color(0.08, 0.10, 0.18, 0.48))
	_draw_unknown_item_icon(canvas, center, float(field_item.get("angle_degrees", 0.0)))


func _draw_unknown_item_icon(canvas: CanvasItem, center: Vector2, angle_degrees: float) -> void:
	var icon_size := Vector2(FIELD_ITEM_DRAW_SIZE, FIELD_ITEM_DRAW_SIZE)
	var sheet: Texture2D = _get_unknown_item_sheet_texture()
	if sheet != null:
		var sheet_size: Vector2 = sheet.get_size()
		var frame_size: float = sheet_size.y
		var frame_count: int = int(floor(sheet_size.x / frame_size)) if frame_size > 0.0 else 0
		if frame_count > 0:
			var frame_index: int = int(Time.get_ticks_msec() / UNKNOWN_ITEM_FRAME_MSEC) % frame_count
			var source_rect := Rect2(float(frame_index) * frame_size, 0.0, frame_size, frame_size)
			_draw_rotated_texture_region(canvas, sheet, source_rect, center, icon_size, angle_degrees)
			return

	var fallback: Texture2D = _get_unknown_item_fallback_texture()
	if fallback != null:
		_draw_rotated_texture_region(canvas, fallback, Rect2(Vector2.ZERO, fallback.get_size()), center, icon_size, angle_degrees)
		return

	canvas.draw_circle(center, FIELD_ITEM_DRAW_SIZE * 0.33, Color(0.84, 0.68, 1.0, 0.96))
	canvas.draw_circle(center + Vector2(-8.0, -9.0), 6.0, Color(1.0, 1.0, 1.0, 0.30))


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float
) -> void:
	var half_size: Vector2 = draw_size * 0.5
	var radians: float = deg_to_rad(angle_degrees)
	var cos_a: float = cos(radians)
	var sin_a: float = sin(radians)
	var offsets := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_max.x, uv_max.y),
		Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_grenade_throw_windups(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if pending_grenade_throws.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	for pending_throw in pending_grenade_throws:
		var start_msec: int = int(pending_throw.get("start_msec", now_msec))
		var release_msec: int = int(pending_throw.get("release_msec", start_msec + GRENADE_THROW_WINDUP_MSEC))
		var duration_msec: int = max(1, release_msec - start_msec)
		var progress: float = clamp(float(now_msec - start_msec) / float(duration_msec), 0.0, 1.0)
		var start_pos: Vector2 = _get_vector2(pending_throw, "start_position", Vector2.ZERO) + shake_offset
		var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos) + shake_offset
		var lift_pos: Vector2 = start_pos + Vector2(0.0, -34.0 - sin(progress * PI) * 12.0)
		var throw_pos: Vector2 = lift_pos.lerp(target_pos, max(0.0, (progress - 0.72) / 0.28) * 0.18)
		var angle: float = lerp(0.0, -35.0, progress)
		var texture: Texture2D = _get_grenade_icon_texture()
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				throw_pos,
				Vector2(GRENADE_DRAW_SIZE, GRENADE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(throw_pos, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_grenades(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if grenades.is_empty():
		return
	var texture: Texture2D = _get_grenade_icon_texture()
	for grenade in grenades:
		var trail: Array = grenade.get("trail", [])
		for i in range(trail.size()):
			var trail_pos: Variant = trail[i]
			if not (trail_pos is Vector2):
				continue
			var alpha: float = float(i + 1) / float(max(1, trail.size())) * 0.28
			canvas.draw_circle(trail_pos + shake_offset, 3.0, Color(1.0, 190.0 / 255.0, 80.0 / 255.0, alpha))

		var center: Vector2 = _get_vector2(grenade, "position", Vector2.ZERO) + shake_offset
		var angle: float = float(grenade.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(GRENADE_DRAW_SIZE, GRENADE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(center, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_explosion_zones(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if explosion_zones.is_empty():
		return
	for zone in explosion_zones:
		if not bool(zone.get("active", true)):
			continue
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius: float = float(zone.get("radius", GRENADE_EXPLOSION_RADIUS))
		var max_duration: float = max(1.0, float(zone.get("max_duration_frames", GRENADE_EXPLOSION_DURATION_FRAMES)))
		var remaining: float = clamp(float(zone.get("duration_frames", max_duration)), 0.0, max_duration)
		var elapsed: float = max_duration - remaining
		var life: float = remaining / max_duration

		var shockwave_radius: float = radius + elapsed * 6.0
		if shockwave_radius < radius * 2.5:
			canvas.draw_arc(center, shockwave_radius, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.18 * life), 4.0)

		var fire_scale: float = min(1.0, (elapsed + 1.0) / 3.0) if elapsed < 4.0 else max(0.0, 1.0 - (elapsed - 4.0) / 21.0)
		var fire_radius: float = radius * fire_scale
		if fire_radius > 3.0:
			for step in range(0, 12):
				var ratio: float = 1.0 - float(step) / 12.0
				var ring_radius: float = max(2.0, fire_radius * ratio)
				var color: Color
				if remaining > max_duration * 0.65:
					color = Color(1.0, lerp(155.0 / 255.0, 1.0, ratio), lerp(50.0 / 255.0, 200.0 / 255.0, ratio), 0.78 * life * ratio)
				elif remaining > max_duration * 0.3:
					color = Color(1.0, lerp(50.0 / 255.0, 150.0 / 255.0, ratio), lerp(10.0 / 255.0, 50.0 / 255.0, ratio), 0.72 * life * ratio)
				else:
					color = Color(lerp(100.0 / 255.0, 200.0 / 255.0, ratio), lerp(10.0 / 255.0, 50.0 / 255.0, ratio), 30.0 / 255.0, 0.58 * life * ratio)
				canvas.draw_circle(center, ring_radius, color)

		var smoke_radius: float = radius * 0.6 + elapsed * 3.0
		for j in range(6):
			var angle: float = float(j) * TAU / 6.0 + elapsed * 0.09
			var distance: float = 16.0 + float((j * 17) % 31)
			var offset := Vector2(cos(angle), sin(angle)) * distance + Vector2(0.0, -elapsed * 1.5)
			var smoke_alpha: float = 0.22 * life
			var tone: float = 0.22 + float(j % 3) * 0.04
			canvas.draw_circle(center + offset, smoke_radius * (0.42 + float(j % 2) * 0.08), Color(tone, tone * 0.9, tone * 0.78, smoke_alpha))

		if elapsed < 6.0:
			var spark_alpha: float = 0.78 * (1.0 - elapsed / 6.0)
			for k in range(10):
				var angle: float = float(k) * TAU / 10.0 + sin(float(k) * 2.17 + elapsed) * 0.22
				var end_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius * 0.7 + float((k * 11) % 21))
				canvas.draw_line(center, end_pos, Color(1.0, 1.0, 200.0 / 255.0, spark_alpha), 2.0)
				canvas.draw_circle(end_pos, 4.0, Color(1.0, 1.0, 220.0 / 255.0, spark_alpha * 0.6))

		if elapsed < 3.0:
			var flash_alpha: float = 0.78 * (1.0 - elapsed / 3.0)
			canvas.draw_circle(center, radius * 0.4, Color(1.0, 250.0 / 255.0, 230.0 / 255.0, flash_alpha))


func _get_debug_spawn_entries() -> Array[Dictionary]:
	return [
		{
			"name": "gauge_charge",
			"title": "에너지드링크",
			"subtitle": "active / gauge +220",
		},
		{
			"name": "grenade",
			"title": "수류탄",
			"subtitle": "active / throw explosive",
		},
	]


func _get_debug_spawn_menu_panel_rect(view_size: Vector2) -> Rect2:
	var entries: Array[Dictionary] = _get_debug_spawn_entries()
	var width: float = min(DEBUG_SPAWN_MENU_WIDTH, max(220.0, view_size.x - DEBUG_SPAWN_MENU_MARGIN * 2.0))
	var height: float = DEBUG_SPAWN_MENU_TITLE_HEIGHT + float(entries.size()) * DEBUG_SPAWN_MENU_ROW_HEIGHT + DEBUG_SPAWN_MENU_MARGIN
	var x: float = clamp(DEBUG_SPAWN_MENU_MARGIN, 0.0, max(0.0, view_size.x - width))
	var y: float = clamp(DEBUG_SPAWN_MENU_TOP, 0.0, max(0.0, view_size.y - height))
	return Rect2(Vector2(x, y), Vector2(width, height))


func _get_debug_spawn_menu_row_rect(panel_rect: Rect2, index: int) -> Rect2:
	return Rect2(
		panel_rect.position + Vector2(12.0, DEBUG_SPAWN_MENU_TITLE_HEIGHT + float(index) * DEBUG_SPAWN_MENU_ROW_HEIGHT + 4.0),
		Vector2(panel_rect.size.x - 24.0, DEBUG_SPAWN_MENU_ROW_HEIGHT - 8.0)
	)


func _draw_debug_spawn_entry_icon(canvas: CanvasItem, item_name: String, center: Vector2) -> void:
	var texture: Texture2D = _get_debug_item_icon_texture(item_name)
	var icon_size := Vector2(DEBUG_SPAWN_MENU_ICON_SIZE, DEBUG_SPAWN_MENU_ICON_SIZE)
	if texture != null:
		canvas.draw_texture_rect(texture, Rect2(center - icon_size * 0.5, icon_size), false)
		return

	var item_data: Dictionary = _build_item_by_name(item_name)
	var item_color: Color = _get_item_color(item_data)
	canvas.draw_circle(center, DEBUG_SPAWN_MENU_ICON_SIZE * 0.42, item_color)
	canvas.draw_circle(center + Vector2(-5.0, -6.0), 4.0, Color(1.0, 1.0, 1.0, 0.25))


func _get_debug_item_icon_texture(item_name: String) -> Texture2D:
	match item_name:
		"gauge_charge":
			return _get_gauge_charge_icon_texture()
		"grenade":
			return _get_grenade_icon_texture()
	return null


func _draw_item_spawn_portals(canvas: CanvasItem, shake_offset: Vector2) -> void:
	if item_spawn_portals.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var sheet: Texture2D = _get_portal_sheet_texture()
	for portal in item_spawn_portals:
		var start_msec: int = int(portal.get("start_msec", now_msec))
		var duration_msec: int = max(1, int(portal.get("duration_msec", ITEM_SPAWN_PORTAL_DURATION_MSEC)))
		var elapsed_msec: int = max(0, now_msec - start_msec)
		if sheet != null:
			_draw_item_spawn_portal_sprite(canvas, sheet, portal, elapsed_msec, duration_msec, shake_offset)
		else:
			_draw_item_spawn_portal_fallback(canvas, portal, elapsed_msec, duration_msec, shake_offset)


func _draw_item_spawn_portal_sprite(
	canvas: CanvasItem,
	sheet: Texture2D,
	portal: Dictionary,
	elapsed_msec: int,
	duration_msec: int,
	shake_offset: Vector2
) -> void:
	var sheet_size: Vector2 = sheet.get_size()
	var frame_w: float = sheet_size.x / float(ITEM_SPAWN_PORTAL_SHEET_COLS)
	var frame_h: float = sheet_size.y / float(ITEM_SPAWN_PORTAL_SHEET_ROWS)
	if frame_w <= 0.0 or frame_h <= 0.0:
		return

	var progress: float = clamp(float(elapsed_msec) / float(duration_msec), 0.0, 0.999)
	var frame_position: float = progress * float(ITEM_SPAWN_PORTAL_FRAME_COUNT)
	var frame_index: int = min(ITEM_SPAWN_PORTAL_FRAME_COUNT - 1, int(frame_position))
	var col: int = frame_index % ITEM_SPAWN_PORTAL_SHEET_COLS
	var row: int = int(floor(float(frame_index) / float(ITEM_SPAWN_PORTAL_SHEET_COLS)))
	var source_rect := Rect2(float(col) * frame_w, float(row) * frame_h, frame_w, frame_h)
	var center: Vector2 = _get_vector2(portal, "position", Vector2.ZERO) + shake_offset
	var draw_size: Vector2 = Vector2(ITEM_SPAWN_PORTAL_DRAW_SIZE, ITEM_SPAWN_PORTAL_DRAW_SIZE)
	var dest_rect := Rect2(center - draw_size * 0.5, draw_size)
	canvas.draw_texture_rect_region(sheet, dest_rect, source_rect)


func _draw_item_spawn_portal_fallback(
	canvas: CanvasItem,
	portal: Dictionary,
	elapsed_msec: int,
	duration_msec: int,
	shake_offset: Vector2
) -> void:
	var center: Vector2 = _get_vector2(portal, "position", Vector2.ZERO) + shake_offset
	var open_factor: float = _portal_open_factor(elapsed_msec, duration_msec)
	if open_factor <= 0.001:
		return
	var rw: float = 22.0 * open_factor
	var rh: float = 36.0 * open_factor
	canvas.draw_circle(center, max(rw, rh) + 10.0, Color(180.0 / 255.0, 90.0 / 255.0, 1.0, 0.22))
	canvas.draw_circle(center, max(rw, rh), Color(28.0 / 255.0, 8.0 / 255.0, 56.0 / 255.0, 0.92))
	canvas.draw_arc(center, max(rw, rh), 0.0, TAU, 32, Color(1.0, 240.0 / 255.0, 1.0, 0.86), 2.0)


func _draw_spawn_electric_spark(canvas: CanvasItem, field_item: Dictionary, shake_offset: Vector2) -> void:
	var remaining: float = float(field_item.get("spawn_spark_timer", 0.0))
	if remaining <= 0.0:
		return
	var progress: float = 1.0 - (remaining / SPAWN_SPARK_DURATION_SEC)
	var alpha_scale: float = pow(1.0 - clamp(progress, 0.0, 1.0), 0.65)
	var center: Vector2 = _get_vector2(field_item, "position", Vector2.ZERO) + shake_offset
	var now: float = Time.get_ticks_msec() / 1000.0
	var ring_radius: float = 25.0 + 8.0 * sin(now * 35.0)
	canvas.draw_arc(center, max(18.0, ring_radius), 0.0, TAU, 34, Color(70.0 / 255.0, 210.0 / 255.0, 1.0, 0.34 * alpha_scale), 2.0)

	for i in range(8):
		var angle: float = now * 7.0 + float(i) * TAU / 8.0 + sin(now * 3.0 + float(i)) * 0.18
		var inner: float = 16.0 + fmod(float(i) * 4.7, 11.0)
		var outer: float = 32.0 + fmod(float(i) * 6.1, 13.0)
		var prev: Vector2 = center + Vector2(cos(angle), sin(angle)) * inner
		for segment in range(1, 4):
			var ratio: float = float(segment) / 3.0
			var jitter: float = sin(now * 13.0 + float(i * 5 + segment)) * 0.22
			var point: Vector2 = center + Vector2(cos(angle + jitter), sin(angle + jitter)) * lerp(inner, outer, ratio)
			var spark_color: Color = Color(0.66, 0.86, 1.0, 0.72 * alpha_scale)
			if i % 3 == 0:
				spark_color = Color(0.92, 0.98, 1.0, 0.92 * alpha_scale)
			elif i % 3 == 1:
				spark_color = Color(0.68, 0.42, 1.0, 0.70 * alpha_scale)
			canvas.draw_line(prev, point, spark_color, 1.0 + float(i % 2))
			prev = point


func _draw_pickup_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var age: float = float(particle.get("age", 0.0))
	var lifetime: float = max(0.01, float(particle.get("lifetime", 0.45)))
	var alpha: float = (1.0 - age / lifetime) * 0.72
	var color: Color = _get_color(particle.get("color", Color.WHITE), Color.WHITE)
	color.a *= alpha
	canvas.draw_circle(
		_get_vector2(particle, "position", Vector2.ZERO) + shake_offset,
		float(particle.get("radius", 3.0)),
		color
	)


func _draw_pickup_glow(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	for i in range(6):
		var ratio: float = float(i) / 6.0
		var radius: float = 40.0 * (1.0 - ratio)
		canvas.draw_circle(center, radius, Color(1.0, 1.0, 1.0, 0.10 * (1.0 - ratio) * alpha))
	canvas.draw_circle(center, 30.0, Color(30.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0, 150.0 / 255.0 * alpha))
	canvas.draw_arc(center, 30.0, 0.0, TAU, 32, Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 150.0 / 255.0 * alpha), 2.0)


func _draw_centered_text(canvas: CanvasItem, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.65))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _create_balloon_pop_particles(center: Vector2, item_color: Color) -> void:
	for i in range(22):
		var angle: float = randf_range(0.0, TAU)
		var speed: float = randf_range(90.0, 250.0)
		var color := item_color.lerp(Color.WHITE, randf_range(0.15, 0.55))
		pickup_particles.append({
			"position": center,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"radius": randf_range(2.0, 4.5),
			"age": 0.0,
			"lifetime": randf_range(0.28, 0.62),
			"color": color,
		})


func _reset_spawn_timer() -> void:
	last_item_spawn_msec = Time.get_ticks_msec()
	next_item_spawn_delay_msec = _roll_spawn_delay_msec()


func _roll_spawn_delay_msec() -> int:
	return randi_range(SPAWN_DELAY_MIN_MSEC, SPAWN_DELAY_MAX_MSEC)


func _roll_spawn_velocity_component() -> float:
	return float(SPAWN_VELOCITY_CHOICES[randi() % SPAWN_VELOCITY_CHOICES.size()])


func _is_item_spawn_blocked(owner: Object) -> bool:
	if int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1)) == 50:
		return true
	if bool(BattleSceneOwnerReader.get_value(owner, "arena_mode_enabled", false)):
		return true
	return false


func _portal_open_factor(elapsed_msec: int, duration_msec: int) -> float:
	var t: float = float(elapsed_msec) / float(max(1, duration_msec))
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.40:
		var open_t: float = t / 0.40
		return 1.0 - pow(1.0 - open_t, 3.0)
	if t < 0.55:
		return 1.0
	var close_t: float = (t - 0.55) / 0.45
	return pow(1.0 - close_t, 2.0)


func _get_korean_item_name(item_name: String) -> String:
	return str(ITEM_NAME_KO.get(item_name, str(_build_gauge_charge().get("display_name", item_name))))


func _get_item_icon_texture(item_data: Dictionary, registry: Object) -> Texture2D:
	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("get_icon_texture"):
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			return texture
	return null


func _get_portal_sheet_texture() -> Texture2D:
	if portal_sheet_texture == null:
		portal_sheet_texture = ProjectResourceLoader.load_texture(
			ITEM_SPAWN_PORTAL_SHEET_PATH,
			"Missing item spawn portal sheet at %s",
			"Failed to load item spawn portal sheet at %s"
		)
	return portal_sheet_texture


func _get_gauge_charge_icon_texture() -> Texture2D:
	if gauge_charge_icon_texture == null:
		gauge_charge_icon_texture = ProjectResourceLoader.load_texture(
			GAUGE_CHARGE_ICON_PATH,
			"Missing gauge charge icon at %s",
			"Failed to load gauge charge icon at %s"
		)
	return gauge_charge_icon_texture


func _get_unknown_item_sheet_texture() -> Texture2D:
	if unknown_item_sheet_texture == null:
		unknown_item_sheet_texture = ProjectResourceLoader.load_texture(
			UNKNOWN_ITEM_SHEET_PATH,
			"Missing unknown item icon sheet at %s",
			"Failed to load unknown item icon sheet at %s"
		)
	return unknown_item_sheet_texture


func _get_unknown_item_fallback_texture() -> Texture2D:
	if unknown_item_fallback_texture == null:
		unknown_item_fallback_texture = ProjectResourceLoader.load_texture(
			UNKNOWN_ITEM_FALLBACK_PATH,
			"Missing unknown item fallback icon at %s",
			"Failed to load unknown item fallback icon at %s"
		)
	return unknown_item_fallback_texture


func _get_grenade_icon_texture() -> Texture2D:
	if grenade_icon_texture == null:
		grenade_icon_texture = ProjectResourceLoader.load_texture(
			GRENADE_ICON_PATH,
			"Missing grenade icon at %s",
			"Failed to load grenade icon at %s"
		)
	return grenade_icon_texture


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


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
