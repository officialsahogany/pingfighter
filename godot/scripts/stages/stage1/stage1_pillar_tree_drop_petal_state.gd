extends RefCounted

const Stage1PillarPetalPayloadFactory := preload("res://scripts/stages/stage1/stage1_pillar_petal_payload_factory.gd")

const TREE_DROP_PETAL_MAX := 18
const TREE_DROP_PETAL_SPAWN_MIN := 1
const TREE_DROP_PETAL_SPAWN_MAX := 2

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
	var write_idx: int = 0
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
		if life > 0.0 and float(petal["y"]) <= last_view_size.y + 30.0:
			tree_drop_petals[write_idx] = petal
			write_idx += 1
	tree_drop_petals.resize(write_idx)


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
	var count: int = randi_range(TREE_DROP_PETAL_SPAWN_MIN, TREE_DROP_PETAL_SPAWN_MAX)
	var clamped_strength: float = clamp(strength, 0.25, 1.0)
	for _i in range(count):
		var burst: float = 0.75 + clamped_strength * 0.6
		tree_drop_petals.append(Stage1PillarPetalPayloadFactory.build_tree_drop_petal(
			Vector2(base_x, base_y),
			side_dir,
			burst
		))
	while tree_drop_petals.size() > TREE_DROP_PETAL_MAX:
		tree_drop_petals.pop_front()


func get_petals() -> Array[Dictionary]:
	return tree_drop_petals
