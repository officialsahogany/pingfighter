extends RefCounted

const Stage1PillarPetalPayloadFactory := preload("res://scripts/stages/stage1/stage1_pillar_petal_payload_factory.gd")
const Stage1PillarTreeDropPetalState := preload("res://scripts/stages/stage1/stage1_pillar_tree_drop_petal_state.gd")

const FLOATING_PETAL_MAX := 8
const FLOATING_PETAL_SPAWN_RATE := 0.72

var floating_petals: Array[Dictionary] = []
var last_view_size := Vector2.ZERO
var last_game_offset := Vector2.ZERO
var last_game_size := Vector2.ZERO
var tree_drop_state: Object = Stage1PillarTreeDropPetalState.new()


func reset() -> void:
	floating_petals.clear()
	tree_drop_state.reset()


func update_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	last_view_size = view_size
	last_game_offset = game_offset
	last_game_size = game_size
	tree_drop_state.update_layout(view_size, game_offset, game_size)


func update(delta: float, current_time: float) -> void:
	var fps_scale: float = delta * 60.0
	if floating_petals.size() < FLOATING_PETAL_MAX and randf() < FLOATING_PETAL_SPAWN_RATE * delta:
		_spawn_floating_petal()
	_update_floating_petals(fps_scale, current_time)
	tree_drop_state.update(delta, fps_scale, current_time)


func spawn_tree_drop_petals(
	side: String,
	strength: float,
	layer_renderer: Object,
	tree_shakes: Dictionary
) -> void:
	tree_drop_state.spawn(side, strength, layer_renderer, tree_shakes)


func get_floating_petals() -> Array[Dictionary]:
	return floating_petals


func get_tree_drop_petals() -> Array[Dictionary]:
	return tree_drop_state.get_petals()


func _update_floating_petals(fps_scale: float, current_time: float) -> void:
	var write_idx: int = 0
	for i in range(floating_petals.size()):
		var petal: Dictionary = floating_petals[i]
		var wave: float = sin(current_time * 2.0 + float(petal["rotation"]) * 0.1) * 0.3
		petal["x"] = float(petal["x"]) + (float(petal["vx"]) + wave) * fps_scale
		petal["y"] = float(petal["y"]) + float(petal["vy"]) * fps_scale
		petal["rotation"] = float(petal["rotation"]) + float(petal["rot_speed"]) * fps_scale
		if float(petal["y"]) <= last_view_size.y + 24.0:
			floating_petals[write_idx] = petal
			write_idx += 1
	floating_petals.resize(write_idx)


func _spawn_floating_petal() -> void:
	if last_view_size.x <= 0.0 or last_game_offset.x <= 50.0:
		return
	var left_w: float = last_game_offset.x
	var right_x: float = last_game_offset.x + last_game_size.x
	var right_w: float = max(0.0, last_view_size.x - right_x)
	var x: float
	if randf() < 0.5 and left_w > 50.0:
		x = randf_range(20.0, max(21.0, left_w - 20.0))
	elif right_w > 50.0:
		x = randf_range(right_x + 20.0, max(right_x + 21.0, last_view_size.x - 20.0))
	else:
		return
	floating_petals.append(Stage1PillarPetalPayloadFactory.build_floating_petal(x))
