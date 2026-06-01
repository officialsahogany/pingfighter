extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")

const SLOT_COUNT := 3
const SLOT_KEYS := [KEY_7, KEY_8, KEY_9]
const SLOT_KEY_LABELS := ["7", "8", "9"]
const EMPTY_LABEL := "+"

static var _layout_helper: Object = Stage1PillarUiLayout.new()


static func draw(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2, _time_seconds: float, context: Dictionary) -> void:
	if canvas == null:
		return
	var snapshot := _get_lingpet_snapshot(context)
	var slots := _get_slots(snapshot)
	if not _has_any_slot(slots):
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var active_index := clampi(int(snapshot.get("active_slot_index", 0)), 0, SLOT_COUNT - 1)
	var rects := build_slot_rects(game_offset, game_size, context)
	if rects.size() < SLOT_COUNT:
		return
	var scale_factor := _get_scale_factor(game_offset, game_size, context)
	var title_size := maxi(10, int(round(12.0 * scale_factor)))
	var label_pos := rects[0].position + Vector2(0.0, -8.0 * scale_factor)
	canvas.draw_string(
		font,
		label_pos,
		"링펫",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		title_size,
		Color(0.35, 0.96, 1.0, 0.92)
	)
	for i in range(SLOT_COUNT):
		_draw_slot(canvas, font, rects[i], slots[i], i, active_index, scale_factor)


static func build_slot_rects(game_offset: Vector2, game_size: Vector2, context: Dictionary = {}) -> Array[Rect2]:
	var layout: Dictionary = _layout_helper.build_layout(game_offset, game_size, context)
	var scale_factor: float = float(layout.get("scale_factor", _get_scale_factor(game_offset, game_size, context)))
	var left_center: Vector2 = layout.get("left_center", Vector2(42.0, game_offset.y + game_size.y - 90.0))
	var slot_size := maxf(24.0, 34.0 * scale_factor)
	var gap := maxf(4.0, 7.0 * scale_factor)
	var center_x := maxf(slot_size * 0.5 + 6.0 * scale_factor, left_center.x)
	var start_y := left_center.y - 236.0 * scale_factor
	var rects: Array[Rect2] = []
	for i in range(SLOT_COUNT):
		rects.append(Rect2(
			Vector2(center_x - slot_size * 0.5, start_y + float(i) * (slot_size + gap)),
			Vector2(slot_size, slot_size)
		))
	return rects


static func get_slot_index_for_key(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return -1
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return -1
	for i in range(SLOT_COUNT):
		var keycode: int = int(SLOT_KEYS[i])
		if key_event.keycode == keycode or key_event.physical_keycode == keycode:
			return i
	return -1


static func get_slot_index_at_position(position: Vector2, game_offset: Vector2, game_size: Vector2, context: Dictionary = {}) -> int:
	var rects := build_slot_rects(game_offset, game_size, context)
	for i in range(mini(SLOT_COUNT, rects.size())):
		if rects[i].has_point(position):
			return i
	return -1


static func _draw_slot(
	canvas: CanvasItem,
	font: Font,
	rect: Rect2,
	pet_id: String,
	index: int,
	active_index: int,
	scale_factor: float
) -> void:
	var occupied := pet_id.strip_edges() != ""
	var active := occupied and index == active_index
	var bg := Color(0.015, 0.025, 0.040, 0.86) if occupied else Color(0.010, 0.014, 0.024, 0.66)
	var border := Color(0.18, 0.92, 1.0, 0.96) if active else (Color(0.28, 0.42, 0.62, 0.80) if occupied else Color(0.18, 0.22, 0.32, 0.72))
	canvas.draw_rect(rect, bg, true)
	canvas.draw_rect(rect, border, false, maxf(1.0, 2.0 * scale_factor))
	if active:
		canvas.draw_rect(rect.grow(3.0 * scale_factor), Color(0.18, 0.92, 1.0, 0.18), false, maxf(1.0, 1.0 * scale_factor))
	var key_size := maxi(8, int(round(9.0 * scale_factor)))
	canvas.draw_string(
		font,
		rect.position + Vector2(3.0 * scale_factor, 9.0 * scale_factor),
		str(SLOT_KEY_LABELS[index]),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		key_size,
		Color(0.96, 0.86, 0.35, 0.90)
	)
	var label := EMPTY_LABEL
	if occupied:
		label = _get_pet_short_label(pet_id)
	var label_size := maxi(12, int(round((16.0 if occupied else 18.0) * scale_factor)))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, label_size)
	var baseline := Vector2(
		rect.position.x + rect.size.x * 0.5 - text_size.x * 0.5,
		rect.position.y + rect.size.y * 0.5 + text_size.y * 0.35
	)
	canvas.draw_string(
		font,
		baseline,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		label_size,
		Color(0.82, 1.0, 0.96, 1.0) if occupied else Color(0.45, 0.52, 0.64, 0.72)
	)


static func _get_lingpet_snapshot(context: Dictionary) -> Dictionary:
	var runtime: Object = context.get("lingpet_runtime", null)
	if runtime != null and runtime.has_method("get_snapshot"):
		var snapshot: Variant = runtime.get_snapshot()
		if snapshot is Dictionary:
			return (snapshot as Dictionary).duplicate(true)
	return {}


static func _get_slots(snapshot: Dictionary) -> Array[String]:
	var value: Variant = snapshot.get("battle_slot_pet_ids", snapshot.get("lingpet_slots", []))
	var slots: Array[String] = []
	for _i in range(SLOT_COUNT):
		slots.append("")
	if value is Array:
		for i in range(mini(SLOT_COUNT, (value as Array).size())):
			var pet_id := str((value as Array)[i]).strip_edges().to_lower()
			if pet_id != "" and LingpetCatalog.has_pet(pet_id):
				slots[i] = pet_id
	return slots


static func _get_pet_short_label(pet_id: String) -> String:
	var display_name := LingpetCatalog.get_display_name(pet_id).strip_edges()
	if display_name == "":
		return pet_id.substr(0, 1).to_upper()
	return display_name.substr(0, 1)


static func _has_any_slot(slots: Array[String]) -> bool:
	for pet_id in slots:
		if pet_id != "":
			return true
	return false


static func _get_scale_factor(_game_offset: Vector2, game_size: Vector2, context: Dictionary) -> float:
	var height := maxf(1.0, float(context.get("height", 750.0)))
	return maxf(0.35, game_size.y / height)
