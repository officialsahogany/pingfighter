extends RefCounted

const TREE_DROP_PETAL_MAX := 48

var tree_drop_petals: Array[Dictionary] = []
var last_view_size := Vector2.ZERO
var last_game_offset := Vector2.ZERO
var last_game_size := Vector2.ZERO


func reset() -> void:
	tree_drop_petals.clear()


func update_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	last_view_size = view_size
	last_game_offset = game_offset
	last_game_size = game_size


func update(delta: float, fps_scale: float, current_time: float) -> void:
	var remove_indices: Array[int] = []
	for i in range(tree_drop_petals.size()):
		var petal: Dictionary = tree_drop_petals[i]
		var life: float = float(petal["life"]) - delta
		var vy: float = float(petal["vy"]) + float(petal["gravity"]) * delta
		var sway: float = sin(current_time * float(petal["sway_speed"]) + float(petal["sway"])) * 0.36
		petal["life"] = life
		petal["vy"] = vy
		petal["x"] = float(petal["x"]) + float(petal["vx"]) * delta + sway
		petal["y"] = float(petal["y"]) + vy * delta
		petal["rotation"] = float(petal["rotation"]) + float(petal["rot_speed"]) * delta
		petal["vx"] = float(petal["vx"]) * pow(0.985, fps_scale)
		tree_drop_petals[i] = petal
		if life <= 0.0 or float(petal["y"]) > last_view_size.y + 30.0:
			remove_indices.append(i)
	_remove_indices(tree_drop_petals, remove_indices)


func spawn(
	side: String,
	strength: float,
	layer_renderer: Object,
	tree_shakes: Dictionary
) -> void:
	if last_view_size.x <= 0.0 or last_game_size.y <= 0.0 or layer_renderer == null:
		return
	var tree_rect: Rect2 = layer_renderer.get_tree_rect(side, last_view_size, last_game_offset, last_game_size)
	if tree_rect.size.x <= 2.0 or tree_rect.size.y <= 2.0:
		return
	var shake: Dictionary = tree_shakes.get(side, {})
	var impact_y_ratio: float = float(shake.get("impact_y_ratio", 0.5))
	var base_y: float = clamp(
		last_game_offset.y + last_game_size.y * impact_y_ratio,
		tree_rect.position.y + 18.0,
		tree_rect.end.y - 18.0
	)
	var base_x: float
	if side == "left":
		base_x = randf_range(tree_rect.position.x + tree_rect.size.x * 0.42, tree_rect.end.x - 16.0)
	else:
		base_x = randf_range(tree_rect.position.x + 16.0, tree_rect.position.x + tree_rect.size.x * 0.58)
	var side_dir: float = 1.0 if side == "left" else -1.0
	var colors: Array[Color] = [
		Color(1.0, 246.0 / 255.0, 218.0 / 255.0, 1.0),
		Color(1.0, 232.0 / 255.0, 224.0 / 255.0, 1.0),
		Color(248.0 / 255.0, 239.0 / 255.0, 204.0 / 255.0, 1.0),
		Color(1.0, 218.0 / 255.0, 226.0 / 255.0, 1.0),
	]
	var count: int = randi_range(3, 6)
	var clamped_strength: float = clamp(strength, 0.25, 1.0)
	for _i in range(count):
		var burst: float = 0.75 + clamped_strength * 0.6
		var life: float = randf_range(1.35, 2.15)
		tree_drop_petals.append({
			"x": base_x + randf_range(-16.0, 16.0),
			"y": base_y + randf_range(-28.0, 24.0),
			"vx": (side_dir * randf_range(16.0, 48.0) + randf_range(-18.0, 18.0)) * burst,
			"vy": randf_range(24.0, 76.0) * burst,
			"gravity": randf_range(34.0, 72.0),
			"sway": randf_range(0.0, TAU),
			"sway_speed": randf_range(4.0, 7.5),
			"rotation": randf_range(0.0, 360.0),
			"rot_speed": randf_range(-165.0, 165.0),
			"size": float(randi_range(5, 9)),
			"color": colors[randi() % colors.size()],
			"life": life,
			"max_life": life,
		})
	while tree_drop_petals.size() > TREE_DROP_PETAL_MAX:
		tree_drop_petals.pop_front()


func get_petals() -> Array[Dictionary]:
	return tree_drop_petals


func _remove_indices(items: Array[Dictionary], remove_indices: Array[int]) -> void:
	remove_indices.reverse()
	for idx in remove_indices:
		items.remove_at(idx)
