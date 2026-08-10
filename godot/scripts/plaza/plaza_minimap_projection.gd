extends RefCounted

const PANEL_RECT := Rect2(Vector2(486.0, 18.0), Vector2(238.0, 58.0))
const TRACK_INSET := Vector2(18.0, 41.0)
const TRACK_SIZE := Vector2(202.0, 5.0)
const ICON_SIZE := 15.0
const ICON_MIN_GAP := 17.0


static func build(
	building_specs: Array[Dictionary],
	camera_x: float,
	player_x: float,
	game_width: float,
	map_width: float,
	exit_world_x: float
) -> Dictionary:
	var track_rect := get_track_rect()
	var marker_y := track_rect.get_center().y
	var camera_start_x := world_x_to_minimap_x(camera_x, map_width)
	var camera_end_x := world_x_to_minimap_x(camera_x + game_width, map_width)
	var building_markers: Array[Dictionary] = []
	for spec in building_specs:
		var pivot_pos: Vector2 = spec.get("pivot_pos", Vector2.ZERO)
		if pivot_pos == Vector2.ZERO:
			var interaction_rect: Rect2 = spec.get("interaction_rect", Rect2())
			pivot_pos = interaction_rect.get_center()
		var emblem_value: Variant = spec.get("identity_emblem", {})
		var emblem: Dictionary = emblem_value as Dictionary if emblem_value is Dictionary else {}
		var marker := {
			"type": str(spec.get("type", "")),
			"identity_emblem_id": str(emblem.get("id", "")),
			"world_x": pivot_pos.x,
			"position": Vector2(world_x_to_minimap_x(pivot_pos.x, map_width), marker_y),
		}
		var marker_color_value: Variant = spec.get("marker_color", null)
		if marker_color_value is Color:
			marker["marker_color"] = marker_color_value
		building_markers.append(marker)
	building_markers = resolve_icon_positions(building_markers, track_rect)
	return {
		"panel_rect": PANEL_RECT,
		"track_rect": track_rect,
		"camera_rect": Rect2(
			Vector2(camera_start_x, track_rect.position.y - 5.0),
			Vector2(max(4.0, camera_end_x - camera_start_x), 15.0)
		),
		"player_marker": Vector2(world_x_to_minimap_x(player_x, map_width), marker_y),
		"exit_marker": Vector2(world_x_to_minimap_x(exit_world_x, map_width), marker_y),
		"building_markers": building_markers,
	}


static func get_track_rect() -> Rect2:
	return Rect2(PANEL_RECT.position + TRACK_INSET, TRACK_SIZE)


static func world_x_to_minimap_x(world_x: float, map_width: float) -> float:
	var track_rect := get_track_rect()
	var ratio := clampf(world_x / max(1.0, map_width), 0.0, 1.0)
	return track_rect.position.x + ratio * track_rect.size.x


static func resolve_icon_positions(markers: Array[Dictionary], track_rect: Rect2) -> Array[Dictionary]:
	if markers.is_empty():
		return markers
	var resolved: Array[Dictionary] = markers.duplicate(true)
	resolved.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("world_x", 0.0)) < float(b.get("world_x", 0.0)))
	var icon_y: float = track_rect.position.y - 17.0
	var left_limit: float = track_rect.position.x + ICON_SIZE * 0.5
	var right_limit: float = track_rect.end.x - ICON_SIZE * 0.5
	var icon_positions: Array[float] = []
	for index in range(resolved.size()):
		var marker_pos: Vector2 = resolved[index].get("position", Vector2.ZERO)
		var icon_x := clampf(marker_pos.x, left_limit, right_limit)
		if index > 0:
			icon_x = max(icon_x, icon_positions[index - 1] + ICON_MIN_GAP)
		icon_positions.append(icon_x)
	if not icon_positions.is_empty():
		var overflow: float = float(icon_positions[icon_positions.size() - 1]) - right_limit
		if overflow > 0.0:
			for index in range(icon_positions.size()):
				icon_positions[index] = float(icon_positions[index]) - overflow
		var underflow: float = left_limit - float(icon_positions[0])
		if underflow > 0.0:
			for index in range(icon_positions.size()):
				icon_positions[index] = float(icon_positions[index]) + underflow
	for index in range(resolved.size()):
		resolved[index]["icon_position"] = Vector2(float(icon_positions[index]), icon_y)
	return resolved


static func get_building_color(building_type: String) -> Color:
	match building_type:
		"bank":
			return Color(1.0, 0.78, 0.32, 0.96)
		"tavern":
			return Color(1.0, 0.50, 0.32, 0.92)
		"academy":
			return Color(0.72, 0.66, 1.0, 0.92)
		"shop":
			return Color(0.32, 0.92, 1.0, 0.92)
		"gacha":
			return Color(1.0, 0.32, 0.92, 0.92)
		"lingpet_store":
			return Color(0.45, 1.0, 0.72, 0.92)
		"blacksmith":
			return Color(1.0, 0.62, 0.24, 0.92)
		_:
			return Color(0.88, 0.96, 1.0, 0.86)
