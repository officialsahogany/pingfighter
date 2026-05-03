extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemFieldSpawnController := preload("res://scripts/items/active_item_field_spawn_controller.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")

const DEFAULT_COOLDOWN_MSEC := ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC
const GRENADE_ICON_PATH := ActiveItemCatalog.GRENADE_ICON_PATH
const FLARE_ICON_PATH := ActiveItemCatalog.FLARE_ICON_PATH
const LONG_BOOST_ICON_PATH := ActiveItemCatalog.LONG_BOOST_ICON_PATH
const SLOT_KEY_CODES := [KEY_1, KEY_2, KEY_3]
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const MAX_ACTIVE_ITEM_SLOTS := 3
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const PICKUP_ICON_SIZE := 40.0
const GRENADE_THROW_WINDUP_MSEC := 600
const GRENADE_DRAW_SIZE := 36.0
const GRENADE_EXPLOSION_RADIUS := 190.0
const GRENADE_EXPLOSION_DURATION_FRAMES := 25.0
const FLARE_THROW_WINDUP_MSEC := 600
const FLARE_DRAW_SIZE := 34.0
const FLARE_RADIUS := 180.0
const FLARE_ZONE_DURATION_FRAMES := 9.0
const LONG_BOOST_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const LONG_BOOST_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const LONG_BOOST_TIMER_ICON_SIZE := 28.0
const REGENERATION_POTION_PARTICLE_DURATION_SEC := 0.78
const REGENERATION_POTION_RING_DURATION_SEC := 0.58
const ITEM_NAME_KO := {
	"flare": "Flare",
	"gauge_charge": "에너지드링크",
	"grenade": "수류탄",
	"long_boost": "거대화포션",
	"regeneration_potion": "재생물약",
}

var slot_key_pressed: Dictionary = {}
var last_item_use_msec: int = -1000000
var grenade_icon_texture: Texture2D
var flare_icon_texture: Texture2D
var long_boost_icon_texture: Texture2D
var item_catalog: Object = ActiveItemCatalog.new()
var field_spawn_controller: Object = ActiveItemFieldSpawnController.new()
var throw_controller: Object = ActiveItemThrowController.new()
var effect_controller: Object = ActiveItemEffectController.new()
var debug_spawn_menu: Object = ActiveItemDebugSpawnMenu.new()
var field_renderer: Object = ActiveItemFieldRenderer.new()


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

	_draw_grenade_throw_windups(canvas, shake_offset)
	_draw_grenades(canvas, shake_offset)
	_draw_flares(canvas, shake_offset)
	_draw_explosion_zones(canvas, shake_offset)
	_draw_flare_zones(canvas, shake_offset)
	_draw_regeneration_potion_effect(canvas, shake_offset)
	_draw_long_boost_timer_gauge(canvas)

	for particle in effect_controller.get_pickup_particles():
		_draw_pickup_particle(canvas, particle, shake_offset)


func draw_pickup_effect(canvas: CanvasItem, registry: Object) -> void:
	var pickup_effect: Dictionary = effect_controller.get_pickup_effect()
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
	var pending_throws: Array[Dictionary] = throw_controller.get_pending_throws()
	if pending_throws.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	for pending_throw in pending_throws:
		var item_name: String = str(pending_throw.get("item_name", "grenade"))
		var fallback_duration_msec: int = FLARE_THROW_WINDUP_MSEC if item_name == "flare" else GRENADE_THROW_WINDUP_MSEC
		var start_msec: int = int(pending_throw.get("start_msec", now_msec))
		var release_msec: int = int(pending_throw.get("release_msec", start_msec + fallback_duration_msec))
		var duration_msec: int = max(1, release_msec - start_msec)
		var progress: float = clamp(float(now_msec - start_msec) / float(duration_msec), 0.0, 1.0)
		var start_pos: Vector2 = _get_vector2(pending_throw, "start_position", Vector2.ZERO) + shake_offset
		var target_pos: Vector2 = _get_vector2(pending_throw, "target_position", start_pos) + shake_offset
		var lift_pos: Vector2 = start_pos + Vector2(0.0, -34.0 - sin(progress * PI) * 12.0)
		var throw_pos: Vector2 = lift_pos.lerp(target_pos, max(0.0, (progress - 0.72) / 0.28) * 0.18)
		var angle: float = lerp(0.0, -35.0, progress)
		var texture: Texture2D = _get_throw_item_icon_texture(item_name)
		var draw_size: float = FLARE_DRAW_SIZE if item_name == "flare" else GRENADE_DRAW_SIZE
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				throw_pos,
				Vector2(draw_size, draw_size),
				angle
			)
		elif item_name == "flare":
			canvas.draw_circle(throw_pos, 11.0, Color(1.0, 1.0, 200.0 / 255.0, 1.0))
		else:
			canvas.draw_circle(throw_pos, 12.0, Color(80.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0, 1.0))


func _draw_grenades(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var grenades: Array[Dictionary] = throw_controller.get_grenades()
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


func _draw_flares(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var flares: Array[Dictionary] = throw_controller.get_flares()
	if flares.is_empty():
		return
	var texture: Texture2D = _get_flare_icon_texture()
	for flare in flares:
		var center: Vector2 = _get_vector2(flare, "position", Vector2.ZERO) + shake_offset
		if bool(flare.get("arrived", false)) and not bool(flare.get("exploded", false)):
			var timer_frames: int = int(flare.get("timer_frames", 0.0))
			if timer_frames % 10 < 5:
				canvas.draw_circle(center, 12.0, Color(1.0, 1.0, 100.0 / 255.0, 0.95))
			canvas.draw_circle(center, 8.0, Color(1.0, 200.0 / 255.0, 0.0, 1.0), false, 2.0)
			continue

		var trail: Array = flare.get("trail", [])
		for i in range(trail.size()):
			var trail_pos: Variant = trail[i]
			if not (trail_pos is Vector2):
				continue
			var alpha: float = float(i + 1) / float(max(1, trail.size())) * 0.34
			canvas.draw_circle(trail_pos + shake_offset, 3.5, Color(1.0, 1.0, 180.0 / 255.0, alpha))

		var angle: float = float(flare.get("rotation_degrees", 0.0))
		if texture != null:
			_draw_rotated_texture_region(
				canvas,
				texture,
				Rect2(Vector2.ZERO, texture.get_size()),
				center,
				Vector2(FLARE_DRAW_SIZE, FLARE_DRAW_SIZE),
				angle
			)
		else:
			canvas.draw_circle(center, 10.0, Color(1.0, 1.0, 200.0 / 255.0, 1.0))


func _draw_explosion_zones(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var explosion_zones: Array[Dictionary] = throw_controller.get_explosion_zones()
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


func _draw_flare_zones(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var flare_zones: Array[Dictionary] = throw_controller.get_flare_zones()
	if flare_zones.is_empty():
		return
	for zone in flare_zones:
		var center: Vector2 = _get_vector2(zone, "position", Vector2.ZERO) + shake_offset
		var radius: float = float(zone.get("radius", FLARE_RADIUS))
		var intensity: float = clamp(float(zone.get("intensity", 1.0)), 0.0, 1.0)
		if intensity <= 0.0:
			continue

		if bool(zone.get("flash", false)):
			canvas.draw_rect(Rect2(shake_offset, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(1.0, 1.0, 230.0 / 255.0, (180.0 / 255.0) * intensity))
			for i in range(5):
				var layer_radius: float = radius * (1.0 - float(i) * 0.15)
				var alpha: float = intensity * (1.0 - float(i) * 0.20)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 240.0 / 255.0, alpha))
			if intensity > 0.7:
				var cross_length: float = radius * 2.0
				canvas.draw_line(center + Vector2(-cross_length, 0.0), center + Vector2(cross_length, 0.0), Color.WHITE, 5.0)
				canvas.draw_line(center + Vector2(0.0, -cross_length), center + Vector2(0.0, cross_length), Color.WHITE, 5.0)
		else:
			for i in range(3):
				var layer_radius: float = radius * (1.0 - float(i) * 0.2)
				var alpha: float = (100.0 / 255.0) * intensity * (1.0 - float(i) * 0.3)
				if alpha > 0.0 and layer_radius > 1.0:
					canvas.draw_circle(center, layer_radius, Color(1.0, 1.0, 200.0 / 255.0, alpha))


func _draw_regeneration_potion_effect(canvas: CanvasItem, shake_offset: Vector2) -> void:
	for ring in effect_controller.get_regeneration_potion_rings():
		var center: Vector2 = _get_vector2(ring, "position", Vector2.ZERO) + shake_offset
		var age: float = float(ring.get("age", 0.0))
		var duration: float = max(0.001, float(ring.get("duration", REGENERATION_POTION_RING_DURATION_SEC)))
		var progress: float = clamp(age / duration, 0.0, 1.0)
		var life: float = 1.0 - progress
		var radius: float = lerp(24.0, 92.0, progress)
		canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 0.58 * life), 4.0)
		canvas.draw_arc(center, radius * 0.62, 0.0, TAU, 56, Color(1.0, 1.0, 170.0 / 255.0, 0.34 * life), 2.0)
		canvas.draw_circle(center, radius * 0.26, Color(1.0, 210.0 / 255.0, 30.0 / 255.0, 0.16 * life))

	for particle in effect_controller.get_regeneration_potion_particles():
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var age: float = float(particle.get("age", 0.0))
		var lifetime: float = max(0.001, float(particle.get("lifetime", REGENERATION_POTION_PARTICLE_DURATION_SEC)))
		var life: float = clamp(1.0 - age / lifetime, 0.0, 1.0)
		if life <= 0.0:
			continue
		var radius: float = max(1.0, float(particle.get("radius", 3.0))) * (0.55 + 0.45 * life)
		var color: Color = _get_color(particle.get("color", Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 1.0)), Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 1.0))
		canvas.draw_circle(center, radius * 2.1, Color(color.r, color.g, color.b, 0.13 * life))
		canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.92 * life))
		canvas.draw_circle(center + Vector2(-radius * 0.32, -radius * 0.32), radius * 0.32, Color(1.0, 1.0, 1.0, 0.42 * life))


func _draw_long_boost_timer_gauge(canvas: CanvasItem) -> void:
	var timer_context: Dictionary = effect_controller.get_long_boost_timer_context()
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var bar_pos := Vector2(
		FIELD_WIDTH - LONG_BOOST_TIMER_BAR_SIZE.x - LONG_BOOST_TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - LONG_BOOST_TIMER_BAR_MARGIN.y
	)
	var frame_rect := Rect2(bar_pos, LONG_BOOST_TIMER_BAR_SIZE)
	var frame_bg := frame_rect.grow(4.0)
	canvas.draw_rect(frame_bg, Color(0.0, 0.0, 0.0, 0.54))
	canvas.draw_rect(frame_rect, Color(0.08, 0.07, 0.04, 0.92))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 6.0:
		base_color = Color(1.0, 215.0 / 255.0, 0.0, 0.96)
		highlight_color = Color(1.0, 235.0 / 255.0, 120.0 / 255.0, 0.96)
	elif remaining_seconds > 3.0:
		base_color = Color(1.0, 170.0 / 255.0, 0.0, 0.96)
		highlight_color = Color(1.0, 200.0 / 255.0, 60.0 / 255.0, 0.96)
	else:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.018)
		base_color = Color(1.0, lerp(0.18, 0.45, pulse), 0.04, 0.98)
		highlight_color = Color(1.0, lerp(0.55, 0.82, pulse), 0.20, 0.98)

	var fill_rect := Rect2(frame_rect.position, Vector2(frame_rect.size.x * ratio, frame_rect.size.y))
	if fill_rect.size.x > 0.5:
		canvas.draw_rect(fill_rect, base_color)
		canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.35))), highlight_color)

	canvas.draw_rect(frame_rect, Color(1.0, 215.0 / 255.0, 0.0, 0.86), false, 2.0)
	canvas.draw_line(frame_rect.position + Vector2(0.0, frame_rect.size.y + 2.0), frame_rect.end + Vector2(0.0, 2.0), Color(0.35, 0.18, 0.02, 0.65), 2.0)

	var icon_center := frame_rect.position + Vector2(-16.0, frame_rect.size.y * 0.5)
	var icon_pulse: float = 1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.012)
	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * icon_pulse
	canvas.draw_circle(icon_center, icon_size.x * 0.58, Color(0.0, 0.0, 0.0, 0.42))
	var icon_texture: Texture2D = _get_long_boost_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_center - icon_size * 0.5, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0))
		canvas.draw_circle(icon_center + Vector2(-4.0, -5.0), icon_size.x * 0.12, Color(1.0, 1.0, 1.0, 0.36))


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


func _get_korean_item_name(item_name: String) -> String:
	if item_name == "long_boost":
		return "거대화포션"
	return str(ITEM_NAME_KO.get(item_name, item_catalog.get_display_name(item_name)))


func _get_item_icon_texture(item_data: Dictionary, registry: Object) -> Texture2D:
	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("get_icon_texture"):
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			return texture
	return null


func _get_grenade_icon_texture() -> Texture2D:
	if grenade_icon_texture == null:
		grenade_icon_texture = ProjectResourceLoader.load_texture(
			GRENADE_ICON_PATH,
			"Missing grenade icon at %s",
			"Failed to load grenade icon at %s"
		)
	return grenade_icon_texture


func _get_flare_icon_texture() -> Texture2D:
	if flare_icon_texture == null:
		flare_icon_texture = ProjectResourceLoader.load_texture(
			FLARE_ICON_PATH,
			"Missing flare icon at %s",
			"Failed to load flare icon at %s"
		)
	return flare_icon_texture


func _get_long_boost_icon_texture() -> Texture2D:
	if long_boost_icon_texture == null:
		long_boost_icon_texture = ProjectResourceLoader.load_texture(
			LONG_BOOST_ICON_PATH,
			"Missing long boost icon at %s",
			"Failed to load long boost icon at %s"
		)
	return long_boost_icon_texture


func _get_throw_item_icon_texture(item_name: String) -> Texture2D:
	if item_name == "flare":
		return _get_flare_icon_texture()
	return _get_grenade_icon_texture()


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
