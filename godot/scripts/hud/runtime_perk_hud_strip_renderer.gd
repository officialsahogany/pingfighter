extends RefCounted

const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")

# Vampire-Survivors-style acquired-perk strip (2026-07-09 request): a compact row of
# small perk icons in the top-left letterbox margin, above the gold HUD, showing the
# player's current passive-perk build at a glance during battle.
#
# Excludes active-skill unlock perks (they live in the 5-orb skill HUD and do not
# consume a perk slot) so the strip mirrors the "현재 퍽" list.

const ICON_SIZE_BASE := 26.0
const GAP_BASE := 4.0
const MARGIN_BASE := 6.0
const GOLD_HUD_TOP_MARGIN := 8.0

var _cache_hash := 0
var _cache_ready := false
var _cache_entries: Array = []


# Filtered, sorted list of {id, color, level} for the owned passive perks.
func build_strip_entries(levels: Dictionary, catalog: Object, display_projection: Dictionary = {}) -> Array:
	var entries: Array = []
	var projected_entries_value: Variant = display_projection.get("entries", [])
	if projected_entries_value is Array and not (projected_entries_value as Array).is_empty():
		return _build_projected_strip_entries(projected_entries_value as Array, catalog)
	for skill_id_value in levels.keys():
		var level: int = int(levels.get(skill_id_value, 0))
		if level <= 0:
			continue
		var skill_id: String = str(skill_id_value)
		var data: Dictionary = {}
		if catalog != null and catalog.has_method("get_perk_data"):
			var raw: Variant = catalog.get_perk_data(skill_id)
			if raw is Dictionary:
				data = raw
		# Active-skill unlocks show in the 5-orb HUD, not as perks.
		if str(data.get("unlocks_skill", "")).strip_edges() != "":
			continue
		var color := Color(0.62, 0.76, 1.0)
		if data.get("icon_color") is Color:
			color = data.get("icon_color")
		entries.append({"id": skill_id, "color": color, "level": level})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return entries


func _build_projected_strip_entries(projected_entries: Array, catalog: Object) -> Array:
	var entries: Array = []
	for entry_value: Variant in projected_entries:
		if not (entry_value is Dictionary):
			continue
		var projected: Dictionary = entry_value
		if str(projected.get("type", "")) == "fusion":
			var fusion_sources: Array = (projected.get("sources", []) as Array).duplicate(true)
			entries.append({
				"id": str(projected.get("fusion_id", projected.get("id", ""))),
				"draw_id": _fusion_pair_draw_id(
					str(projected.get("fusion_id", projected.get("id", ""))),
					int(projected.get("fusion_revision", 0)),
					fusion_sources
				),
				"type": "fusion",
				"color": Color(1.0, 0.70, 0.24),
				"level": 1,
				"sources": fusion_sources,
			})
			continue
		var projected_type := str(projected.get("type", "perk"))
		var perk_id: String = str(projected.get("perk_id", projected.get("id", "")))
		var level: int = int(projected.get("effective_level", projected.get("base_level", 0)))
		if perk_id == "" or level <= 0:
			continue
		var data: Dictionary = {}
		if catalog != null and catalog.has_method("get_perk_data"):
			var raw: Variant = catalog.get_perk_data(perk_id)
			if raw is Dictionary:
				data = raw
		if str(data.get("unlocks_skill", "")).strip_edges() != "":
			continue
		var color := Color(0.62, 0.76, 1.0)
		if data.get("icon_color") is Color:
			color = data.get("icon_color")
		entries.append({
			"id": perk_id,
			"draw_id": perk_id,
			"type": projected_type,
			"color": color,
			"level": level,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return entries


func get_strip_entries_cached(levels: Dictionary, catalog: Object, display_projection: Dictionary = {}) -> Array:
	var levels_hash: int = hash([
		hash(levels),
		int(display_projection.get("cache_signature", 0)),
		int(display_projection.get("fusion_revision", 0)),
		int(display_projection.get("mystic_dice_revision", 0)),
	])
	if _cache_ready and levels_hash == _cache_hash:
		return _cache_entries
	_cache_hash = levels_hash
	_cache_ready = true
	_cache_entries = build_strip_entries(levels, catalog, display_projection)
	return _cache_entries


func has_visible_entries(levels: Dictionary, display_projection: Dictionary = {}) -> bool:
	if not levels.is_empty():
		return true
	var projected_entries_value: Variant = display_projection.get("entries", [])
	return projected_entries_value is Array and not (projected_entries_value as Array).is_empty()


func get_strip_layout(entry_count: int, game_offset: Vector2, game_size: Vector2) -> Dictionary:
	if entry_count <= 0:
		return {"visible": false}
	var scale: float = clampf(game_size.y / 750.0, 0.45, 3.0)
	var icon_size: float = ICON_SIZE_BASE * scale
	var gap: float = GAP_BASE * scale
	var margin: float = MARGIN_BASE * scale
	# This strip exclusively owns the left horizontal letterbox. Portrait and
	# narrow layouts can have no side letterbox, or only a sliver narrower than
	# one cell; in both cases drawing would cover the live 760x750 playfield.
	var strip_left: float = margin
	var strip_right: float = maxf(0.0, game_offset.x) - margin
	var available_width: float = strip_right - strip_left
	if available_width + 0.001 < icon_size:
		return {
			"visible": false,
			"required_letterbox_width": icon_size + margin * 2.0,
			"available_letterbox_width": maxf(0.0, game_offset.x),
		}
	var columns: int = clampi(
		int(floor((available_width + gap) / (icon_size + gap))),
		1,
		entry_count
	)
	var rows: int = int(ceil(float(entry_count) / float(columns)))
	var grid_height: float = float(rows) * icon_size + float(maxi(0, rows - 1)) * gap
	var gold_top: float = game_offset.y + GOLD_HUD_TOP_MARGIN * scale
	var bottom_y: float = gold_top - gap - 2.0 * scale
	return {
		"visible": true,
		"scale": scale,
		"icon_size": icon_size,
		"gap": gap,
		"margin": margin,
		"strip_left": strip_left,
		"strip_right": strip_right,
		"columns": columns,
		"rows": rows,
		"top_y": maxf(4.0, bottom_y - grid_height),
	}


func draw(
	canvas: CanvasItem,
	levels: Dictionary,
	catalog: Object,
	icon_renderer: Object,
	game_offset: Vector2,
	game_size: Vector2,
	display_projection: Dictionary = {}
) -> void:
	if canvas == null or icon_renderer == null or not icon_renderer.has_method("draw_icon"):
		return
	if not has_visible_entries(levels, display_projection):
		return
	var entries: Array = get_strip_entries_cached(levels, catalog, display_projection)
	if entries.is_empty():
		return

	var layout := get_strip_layout(entries.size(), game_offset, game_size)
	if not bool(layout.get("visible", false)):
		return
	var scale := float(layout.get("scale", 1.0))
	var icon_size := float(layout.get("icon_size", ICON_SIZE_BASE))
	var gap := float(layout.get("gap", GAP_BASE))
	# Span the left letterbox margin (window edge → playfield edge), above the gold HUD.
	var strip_left := float(layout.get("strip_left", MARGIN_BASE))
	var strip_right := float(layout.get("strip_right", game_offset.x - MARGIN_BASE))
	var cols := int(layout.get("columns", 1))
	var top_y := float(layout.get("top_y", 4.0))
	var border_width: float = max(1.0, 1.2 * scale)
	var icon_inset: float = 2.0 * scale

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var col: int = i % cols
		var row: int = i / cols
		var rect := Rect2(
			Vector2(strip_left + float(col) * (icon_size + gap), top_y + float(row) * (icon_size + gap)),
			Vector2(icon_size, icon_size)
		)
		if rect.end.x > strip_right + 0.001:
			continue
		var color: Color = entry.get("color", Color.WHITE) if entry.get("color") is Color else Color.WHITE
		canvas.draw_rect(rect, Color(6.0 / 255.0, 9.0 / 255.0, 16.0 / 255.0, 0.82))
		canvas.draw_rect(rect, Color(color.r, color.g, color.b, 0.62), false, border_width)
		icon_renderer.draw_icon(canvas, str(entry.get("draw_id", entry.get("id", ""))), rect.grow(-icon_inset), 1.0, true)


func _fusion_pair_draw_id(fusion_id: String, fusion_revision: int, sources: Array) -> String:
	return PerkFusionIconKey.build(fusion_id, fusion_revision, sources)
