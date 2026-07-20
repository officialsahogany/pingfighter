extends RefCounted

const PlayerSpriteSocketCatalog := preload("res://scripts/characters/player_sprite_socket_catalog.gd")

const LAYER_BACK := "back"
const LAYER_FRONT := "front"
const SLOT_BACK := "back"
const SLOT_OUTFIT_ACCENT := "outfit_accent"
const SLOT_HEAD_HAT := "head_hat"
const SLOT_ACCESSORY := "accessory"
const SLOT_PADDLE := "paddle"
const SLOT_CORE_GLOW := "core_glow"

const SUPPORTED_CHARACTERS := ["smasher", "optimus"]

const BACK_LAYER_SLOTS := [SLOT_BACK]
const FRONT_LAYER_SLOTS := [
	SLOT_OUTFIT_ACCENT,
	SLOT_CORE_GLOW,
	SLOT_HEAD_HAT,
	SLOT_ACCESSORY,
	SLOT_PADDLE,
]


func build_base_plan(
	motion_id: String,
	frame_index: int,
	dest_rect: Rect2,
	source_rect: Rect2,
	context: Dictionary = {},
	overrides: Dictionary = {}
) -> Dictionary:
	return {
		"character_id": _normalize_character(context.get("selected_character_type", "smasher")),
		"motion_id": motion_id.strip_edges().to_lower(),
		"direction": _normalize_direction(overrides.get("direction", _direction_from_context(context))),
		"frame_index": max(0, frame_index),
		"dest_rect": dest_rect,
		"source_rect": source_rect,
		"grid_cols": max(1, int(overrides.get("grid_cols", 1))),
		"grid_rows": max(1, int(overrides.get("grid_rows", 1))),
		"frame_count": max(1, int(overrides.get("frame_count", max(1, int(overrides.get("grid_cols", 1)) * int(overrides.get("grid_rows", 1)))))),
		"cell_width": max(1.0, float(overrides.get("cell_width", source_rect.size.x))),
		"cell_height": max(1.0, float(overrides.get("cell_height", source_rect.size.y))),
		"flip_h": bool(overrides.get("flip_h", false)),
		"modulate": _as_color(overrides.get("modulate", _get_context_modulate(context)), Color.WHITE),
		"rotation_degrees": float(overrides.get("rotation_degrees", context.get("player_sprite_rotation_degrees", 0.0))),
	}


func draw_layer(canvas: CanvasItem, context: Dictionary, base_plan: Dictionary, layer_id: String) -> void:
	if canvas == null:
		return
	for command in build_draw_commands(context, base_plan, layer_id):
		if command is Dictionary:
			_draw_command(canvas, command)


func build_draw_commands(context: Dictionary, base_plan: Dictionary, layer_id: String) -> Array:
	var commands: Array = []
	if not _should_draw_for_context(context, base_plan):
		return commands
	var overlay_slots: Dictionary = _get_overlay_slots(context)
	if overlay_slots.is_empty():
		return commands
	for slot_id in _slots_for_layer(layer_id):
		var entry: Dictionary = _resolve_slot_entry(overlay_slots, slot_id, base_plan)
		if entry.is_empty():
			continue
		if not bool(entry.get("enabled", true)):
			continue
		entry = _apply_context_driven_metadata(entry, context)
		var texture: Variant = _resolve_texture(context, entry, slot_id, base_plan)
		if not (texture is Texture2D):
			continue
		var texture_typed: Texture2D = texture
		var dest_rect: Rect2 = _get_entry_dest_rect(entry, base_plan)
		# Socket-anchored entries fail-closed to a zero rect when no authored
		# socket covers the current motion/frame -- skip instead of drawing a
		# part at a guessed position.
		if dest_rect.size.x <= 0.0 or dest_rect.size.y <= 0.0:
			continue
		commands.append({
			"slot_id": slot_id,
			"layer_id": layer_id,
			"motion_id": str(base_plan.get("motion_id", "")),
			"direction": str(base_plan.get("direction", "back")),
			"frame_index": int(base_plan.get("frame_index", 0)),
			"texture": texture_typed,
			"source_rect": _get_entry_source_rect(entry, base_plan, texture_typed),
			"dest_rect": dest_rect,
			"flip_h": bool(entry.get("flip_h", base_plan.get("flip_h", false))),
			"modulate": _get_entry_modulate(entry, base_plan),
			"rotation_degrees": float(entry.get("rotation_degrees", base_plan.get("rotation_degrees", 0.0))),
		})
	return commands


func _draw_command(canvas: CanvasItem, command: Dictionary) -> void:
	var texture: Variant = command.get("texture", null)
	if not (texture is Texture2D):
		return
	var texture_typed: Texture2D = texture
	var source_rect: Rect2 = _as_rect2(command.get("source_rect", Rect2(Vector2.ZERO, texture_typed.get_size())))
	var dest_rect: Rect2 = _as_rect2(command.get("dest_rect", Rect2()))
	if dest_rect.size.x <= 0.0 or dest_rect.size.y <= 0.0 or source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var modulate: Color = _as_color(command.get("modulate", Color.WHITE), Color.WHITE)
	var rotation_degrees: float = float(command.get("rotation_degrees", 0.0))
	var flip_h := bool(command.get("flip_h", false))
	if abs(rotation_degrees) > 0.01:
		_draw_rotated_texture_region(
			canvas,
			texture_typed,
			source_rect,
			dest_rect.get_center(),
			dest_rect.size,
			rotation_degrees,
			modulate,
			flip_h
		)
	elif flip_h:
		_draw_flipped_texture_region(canvas, texture_typed, source_rect, dest_rect, modulate)
	else:
		canvas.draw_texture_rect_region(texture_typed, dest_rect, source_rect, modulate, false, true)


func _apply_context_driven_metadata(entry: Dictionary, context: Dictionary) -> Dictionary:
	var needs_paddle_scale := bool(entry.get("scale_from_player_paddle", false))
	var needs_energy_alpha := bool(entry.get("alpha_from_energy_ratio", false))
	if not needs_paddle_scale and not needs_energy_alpha:
		return entry
	var result := entry.duplicate(true)
	if needs_paddle_scale:
		var paddle_scale := float(context.get("player_paddle_scale", 1.0))
		if paddle_scale > 0.0 and not is_equal_approx(paddle_scale, 1.0):
			var current_scale: Vector2 = _as_vector2(result.get("dest_scale", Vector2.ONE), Vector2.ONE)
			result["dest_scale"] = Vector2(current_scale.x * paddle_scale, current_scale.y * paddle_scale)
	if needs_energy_alpha:
		var energy_ratio: float = clampf(float(context.get("player_energy_ratio", 1.0)), 0.0, 1.0)
		if not is_equal_approx(energy_ratio, 1.0):
			var current_modulate: Color = _as_color(result.get("modulate", Color.WHITE), Color.WHITE)
			result["modulate"] = Color(current_modulate.r, current_modulate.g, current_modulate.b, current_modulate.a * energy_ratio)
	return result


func _resolve_slot_entry(overlay_slots: Dictionary, slot_id: String, base_plan: Dictionary) -> Dictionary:
	if not overlay_slots.has(slot_id):
		return {}
	var raw: Variant = overlay_slots.get(slot_id, null)
	var entry: Dictionary = _entry_from_raw(raw)
	if entry.is_empty():
		return {}
	entry["slot_id"] = slot_id
	entry = _resolve_motion_entry(entry, base_plan)
	if entry.is_empty():
		return {}
	return _resolve_direction_entry(entry, base_plan)


func _resolve_motion_entry(entry: Dictionary, base_plan: Dictionary) -> Dictionary:
	var motion_id := str(base_plan.get("motion_id", "")).strip_edges().to_lower()
	var explicit_motion := str(entry.get("motion_id", entry.get("motion", ""))).strip_edges().to_lower()
	if explicit_motion != "" and explicit_motion != "any" and explicit_motion != motion_id:
		return {}
	var motions_raw: Variant = entry.get("motions", null)
	if not (motions_raw is Dictionary):
		return entry
	var motions: Dictionary = motions_raw
	var motion_raw: Variant = null
	if motions.has(motion_id):
		motion_raw = motions.get(motion_id)
	elif motions.has("any"):
		motion_raw = motions.get("any")
	if motion_raw == null:
		return {}
	var merged := entry.duplicate(true)
	merged.erase("motions")
	merged.merge(_entry_from_raw(motion_raw), true)
	return merged


func _resolve_direction_entry(entry: Dictionary, base_plan: Dictionary) -> Dictionary:
	var directions_raw: Variant = entry.get("directions", null)
	if not (directions_raw is Dictionary):
		var direction_id := str(entry.get("direction", "any")).strip_edges().to_lower()
		if direction_id != "" and direction_id != "any" and direction_id != str(base_plan.get("direction", "back")):
			return {}
		return entry

	var directions: Dictionary = directions_raw
	var direction: String = _normalize_direction(base_plan.get("direction", "back"))
	var selected_raw: Variant = null
	var mirror_fallback := false
	if directions.has(direction):
		selected_raw = directions.get(direction)
	elif directions.has("any"):
		selected_raw = directions.get("any")
	elif direction == "left" and _entry_allows_mirror_fallback(entry) and directions.has("right"):
		selected_raw = directions.get("right")
		mirror_fallback = true
	elif direction == "right" and _entry_allows_mirror_fallback(entry) and directions.has("left"):
		selected_raw = directions.get("left")
		mirror_fallback = true
	if selected_raw == null:
		return {}

	var merged := entry.duplicate(true)
	merged.erase("directions")
	merged.merge(_entry_from_raw(selected_raw), true)
	if mirror_fallback and not merged.has("flip_h"):
		merged["flip_h"] = true
	return merged


func _entry_from_raw(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	if raw is Texture2D:
		return {"texture": raw}
	return {}


func _resolve_texture(context: Dictionary, entry: Dictionary, slot_id: String, base_plan: Dictionary) -> Variant:
	var texture: Variant = entry.get("texture", null)
	if texture is Texture2D:
		return texture
	var texture_key := str(entry.get("texture_key", "")).strip_edges()
	if texture_key == "":
		var character_id := _normalize_character(base_plan.get("character_id", "smasher"))
		texture_key = _default_texture_key(character_id, slot_id, str(entry.get("motion_id", "")), str(entry.get("direction", "")))
	var texture_maps := [
		context.get("player_customization_overlay_textures", {}),
		context.get("character_overlay_textures", {}),
		context.get("textures", {}),
	]
	for texture_map_raw in texture_maps:
		if texture_map_raw is Dictionary:
			var texture_map: Dictionary = texture_map_raw
			if texture_map.has(texture_key):
				return texture_map.get(texture_key)
	return null


func _get_entry_source_rect(entry: Dictionary, base_plan: Dictionary, texture: Texture2D) -> Rect2:
	if entry.get("source_rect", null) is Rect2:
		return entry.get("source_rect")
	var frame: int = clamp(int(base_plan.get("frame_index", 0)), 0, max(0, int(entry.get("frame_count", base_plan.get("frame_count", 1))) - 1))
	var grid_cols: int = max(1, int(entry.get("grid_cols", base_plan.get("grid_cols", 1))))
	var texture_size: Vector2 = texture.get_size()
	var cell_w: float = max(1.0, float(entry.get("cell_width", base_plan.get("cell_width", texture_size.x / float(grid_cols)))))
	var grid_rows: int = max(1, int(entry.get("grid_rows", ceil(texture_size.y / cell_w))))
	var cell_h: float = max(1.0, float(entry.get("cell_height", base_plan.get("cell_height", texture_size.y / float(grid_rows)))))
	var col: int = frame % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame / grid_cols)
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func _get_entry_dest_rect(entry: Dictionary, base_plan: Dictionary) -> Rect2:
	var socket_id := str(entry.get("socket_id", "")).strip_edges()
	if socket_id != "":
		return _get_socket_entry_dest_rect(entry, base_plan, socket_id)
	var dest_rect: Rect2 = _as_rect2(base_plan.get("dest_rect", Rect2()))
	if entry.get("dest_rect", null) is Rect2:
		dest_rect = entry.get("dest_rect")
	var offset: Vector2 = _as_vector2(entry.get("dest_offset", Vector2.ZERO), Vector2.ZERO)
	var scale: Vector2 = _as_vector2(entry.get("dest_scale", Vector2.ONE), Vector2.ONE)
	if scale != Vector2.ONE:
		var center: Vector2 = dest_rect.get_center()
		dest_rect.size = Vector2(dest_rect.size.x * scale.x, dest_rect.size.y * scale.y)
		dest_rect.position = center - dest_rect.size * 0.5
	dest_rect.position += offset
	return dest_rect


# Socket-anchored placement: the part rides a per-frame authored anchor
# (PlayerSpriteSocketCatalog) instead of the whole-body rect. `socket_offset`
# and `socket_part_size` are in the authored cell's pixel space and scale with
# the body draw. Fail-closed: any missing precondition returns a zero rect so
# the command builder skips the part rather than guessing a position.
func _get_socket_entry_dest_rect(entry: Dictionary, base_plan: Dictionary, socket_id: String) -> Rect2:
	var dest_rect: Rect2 = _as_rect2(base_plan.get("dest_rect", Rect2()))
	if dest_rect.size.x <= 0.0 or dest_rect.size.y <= 0.0:
		return Rect2()
	var character_id := _normalize_character(base_plan.get("character_id", "smasher"))
	var authored_cell: Vector2 = PlayerSpriteSocketCatalog.get_cell_size(character_id)
	var base_cell := Vector2(float(base_plan.get("cell_width", 0.0)), float(base_plan.get("cell_height", 0.0)))
	if authored_cell == Vector2.ZERO or not base_cell.is_equal_approx(authored_cell):
		return Rect2()
	var part_size_cell: Vector2 = _as_vector2(entry.get("socket_part_size", Vector2.ZERO), Vector2.ZERO)
	if part_size_cell.x <= 0.0 or part_size_cell.y <= 0.0:
		return Rect2()
	var sockets: Dictionary = PlayerSpriteSocketCatalog.resolve_screen_sockets(
		character_id,
		str(base_plan.get("motion_id", "")),
		str(base_plan.get("direction", "back")),
		int(base_plan.get("frame_index", 0)),
		dest_rect
	)
	if not sockets.has(socket_id):
		return Rect2()
	var scale := Vector2(dest_rect.size.x / authored_cell.x, dest_rect.size.y / authored_cell.y)
	var offset_cell: Vector2 = _as_vector2(entry.get("socket_offset", Vector2.ZERO), Vector2.ZERO)
	if str(base_plan.get("direction", "back")) == "left":
		offset_cell.x = -offset_cell.x
	var center: Vector2 = sockets[socket_id] + Vector2(offset_cell.x * scale.x, offset_cell.y * scale.y)
	var part_size := Vector2(part_size_cell.x * scale.x, part_size_cell.y * scale.y)
	return Rect2(center - part_size * 0.5, part_size)


func _get_entry_modulate(entry: Dictionary, base_plan: Dictionary) -> Color:
	var base_modulate: Color = _as_color(base_plan.get("modulate", Color.WHITE), Color.WHITE)
	var entry_modulate: Color = _as_color(entry.get("modulate", Color.WHITE), Color.WHITE)
	return Color(
		base_modulate.r * entry_modulate.r,
		base_modulate.g * entry_modulate.g,
		base_modulate.b * entry_modulate.b,
		base_modulate.a * entry_modulate.a
	)


func _get_overlay_slots(context: Dictionary) -> Dictionary:
	for key in ["player_customization_overlay_slots", "character_overlay_slots", "player_overlay_slots"]:
		var value: Variant = context.get(key, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			return value
	return {}


func _should_draw_for_context(context: Dictionary, base_plan: Dictionary) -> bool:
	if not bool(context.get("player_customization_overlays_enabled", true)):
		return false
	var character_id := _normalize_character(base_plan.get("character_id", context.get("selected_character_type", "smasher")))
	return SUPPORTED_CHARACTERS.has(character_id)


func _slots_for_layer(layer_id: String) -> Array:
	if layer_id == LAYER_BACK:
		return BACK_LAYER_SLOTS
	return FRONT_LAYER_SLOTS


func _direction_from_context(context: Dictionary) -> String:
	if bool(context.get("player_hit_active", false)):
		return "left" if int(context.get("player_hit_side", context.get("player_walk_direction", 1))) < 0 else "right"
	return "left" if int(context.get("player_walk_direction", 1)) < 0 else "right"


func _normalize_direction(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	if normalized == "l":
		return "left"
	if normalized == "r":
		return "right"
	if normalized == "left" or normalized == "right" or normalized == "back":
		return normalized
	return "back"


func _normalize_character(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	if normalized == "" or normalized == "ufo_player":
		return "smasher"
	return normalized


func _entry_allows_mirror_fallback(entry: Dictionary) -> bool:
	if entry.has("mirror_ok"):
		return bool(entry.get("mirror_ok", false))
	var policy := str(entry.get("mirror_policy", "mirror_ok")).strip_edges().to_lower()
	return policy == "mirror_ok" or policy == "mirror_ok_v1" or policy == "follow_base"


func _default_texture_key(character_id: String, slot_id: String, motion_id: String, direction: String) -> String:
	var prefix := character_id.strip_edges().to_lower()
	if prefix == "":
		prefix = "smasher"
	var parts := PackedStringArray([prefix + "_overlay", slot_id])
	if motion_id.strip_edges() != "":
		parts.append(motion_id.strip_edges().to_lower())
	if direction.strip_edges() != "" and direction != "any":
		parts.append(direction.strip_edges().to_lower())
	return "_".join(parts)


func _get_context_modulate(context: Dictionary) -> Color:
	var modulate := Color.WHITE
	if bool(context.get("soul_burst_dash_active", false)):
		modulate = _multiply_rgb(modulate, Color(0.82, 0.42, 1.18, 1.0))
	if bool(context.get("dash_recovering", false)):
		var pulse: float = 0.6 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.02)
		modulate = _multiply_rgb(modulate, Color((180.0 * pulse) / 255.0, (120.0 * pulse) / 255.0, (200.0 * pulse) / 255.0, 1.0))
	modulate = _multiply_rgb(modulate, _as_color(context.get("player_sprite_modulate", Color.WHITE), Color.WHITE))
	return modulate


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_rotated_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	center: Vector2,
	draw_size: Vector2,
	angle_degrees: float,
	modulate: Color,
	flip_h: bool = false
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

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

	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y) if flip_h else Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y) if flip_h else Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y) if flip_h else Vector2(uv_max.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y) if flip_h else Vector2(uv_min.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _as_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


func _as_rect2(value: Variant) -> Rect2:
	return value if value is Rect2 else Rect2()


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _multiply_rgb(color: Color, modulate: Color) -> Color:
	return Color(color.r * modulate.r, color.g * modulate.g, color.b * modulate.b, color.a * modulate.a)
