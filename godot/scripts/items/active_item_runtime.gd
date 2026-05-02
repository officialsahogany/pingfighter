extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const DEFAULT_COOLDOWN_MSEC := 10000
const GAUGE_MAX := 500.0
const GAUGE_CHARGE_AMOUNT := 220.0
const GAUGE_CHARGE_ICON_PATH := "res://assets/sprites/items/gauge_200.png"
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
const ITEM_NAME_KO := {
	"gauge_charge": "에너지드링크",
}

var slot_key_pressed: Dictionary = {}
var spawned_items: Array[Dictionary] = []
var pending_spawn_items: Array[Dictionary] = []
var item_spawn_portals: Array[Dictionary] = []
var pickup_particles: Array[Dictionary] = []
var pickup_effect: Dictionary = {}
var last_item_spawn_msec: int = 0
var next_item_spawn_delay_msec: int = 0
var last_item_use_msec: int = -1000000
var portal_sheet_texture: Texture2D
var unknown_item_sheet_texture: Texture2D
var unknown_item_fallback_texture: Texture2D


func _init() -> void:
	reset()


func reset() -> void:
	slot_key_pressed.clear()
	spawned_items.clear()
	pending_spawn_items.clear()
	item_spawn_portals.clear()
	pickup_particles.clear()
	pickup_effect.clear()
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
	var item_data: Dictionary = _build_gauge_charge()
	item_data["revealed"] = false
	var position := Vector2(
		randf_range(FIELD_ITEM_RADIUS, FIELD_WIDTH - FIELD_ITEM_RADIUS),
		randf_range(FIELD_ITEM_RADIUS, FIELD_HEIGHT - FIELD_ITEM_RADIUS)
	)
	var field_item: Dictionary = {
		"item_data": item_data,
		"position": position,
		"velocity": Vector2(_roll_spawn_velocity_component(), _roll_spawn_velocity_component()),
		"angle_degrees": 0.0,
		"bounce_count": 0,
		"max_bounces": randi_range(6, 9),
		"spawn_spark_timer": SPAWN_SPARK_DURATION_SEC,
		"spawn_skip_update_once": true,
	}
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
