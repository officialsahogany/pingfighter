extends RefCounted

const Stage1PillarPetalState := preload("res://scripts/stages/stage1/stage1_pillar_petal_state.gd")

const TREE_SHAKE_DURATION := 0.28

var time := 0.0
var butterflies: Array[Dictionary] = []
var last_view_size := Vector2.ZERO
var last_game_offset := Vector2.ZERO
var last_game_size := Vector2.ZERO
var petal_state: Object = Stage1PillarPetalState.new()
var tree_shakes: Dictionary = {
	"left": {"timer": 0.0, "strength": 0.0, "impact_y_ratio": 0.5},
	"right": {"timer": 0.0, "strength": 0.0, "impact_y_ratio": 0.5},
}


func init_state() -> void:
	butterflies.clear()
	petal_state.reset()
	var color_indices: Array[int] = [0, 1, 2, 3]
	var sides: Array[String] = ["left", "left", "right", "right"]
	var y_ratios: Array[float] = [1.0 / 3.0, 2.0 / 3.0, 1.0 / 3.0, 2.0 / 3.0]
	for i in range(4):
		butterflies.append({
			"side": sides[i],
			"y_ratio": y_ratios[i],
			"phase": randf_range(0.0, TAU),
			"wing_speed": 10.0,
			"color_index": color_indices[i],
			"size": 1.0,
		})


func update_layout(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	last_view_size = view_size
	last_game_offset = game_offset
	last_game_size = game_size
	petal_state.update_layout(view_size, game_offset, game_size)


func update(delta: float) -> void:
	time += delta
	_update_tree_shakes(delta)
	petal_state.update(delta, time)


func trigger_tree_shake(
	side: String,
	impact_y: float,
	impact_speed: float,
	field_height: float,
	layer_renderer: Object
) -> void:
	if side != "left" and side != "right":
		return
	var shake: Dictionary = tree_shakes[side]
	var strength: float = clamp((impact_speed - 6.0) / 18.0, 0.25, 1.0)
	shake["timer"] = TREE_SHAKE_DURATION
	shake["strength"] = max(strength, float(shake.get("strength", 0.0)) * 0.5)
	shake["impact_y_ratio"] = clamp(impact_y / max(1.0, field_height), 0.04, 0.96)
	tree_shakes[side] = shake
	petal_state.spawn_tree_drop_petals(side, strength, layer_renderer, tree_shakes)


func get_time() -> float:
	return time


func get_tree_shakes() -> Dictionary:
	return tree_shakes


func get_butterflies() -> Array[Dictionary]:
	return butterflies


func get_floating_petals() -> Array[Dictionary]:
	return petal_state.get_floating_petals()


func get_tree_drop_petals() -> Array[Dictionary]:
	return petal_state.get_tree_drop_petals()


func _update_tree_shakes(delta: float) -> void:
	for side in ["left", "right"]:
		var shake: Dictionary = tree_shakes[side]
		var timer: float = float(shake.get("timer", 0.0))
		if timer > 0.0:
			timer = max(0.0, timer - delta)
			shake["timer"] = timer
			if timer <= 0.0:
				shake["strength"] = 0.0
			tree_shakes[side] = shake
