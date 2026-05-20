extends RefCounted


func is_current_layout(
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	ambient_layout_size: Vector2,
	ambient_game_offset: Vector2,
	ambient_game_size: Vector2,
	fireflies: Array
) -> bool:
	return (
		ambient_layout_size == view_size
		and ambient_game_offset == game_offset
		and ambient_game_size == game_size
		and not fireflies.is_empty()
	)


func populate_initial_layout(
	falling_leaves: Array,
	fireflies: Array,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	payload_factory: Object,
	random_source: RandomNumberGenerator,
	initial_leaf_count: int,
	firefly_count: int
) -> void:
	falling_leaves.clear()
	fireflies.clear()
	for _leaf_idx in range(max(0, initial_leaf_count)):
		append_ambient_leaf(
			falling_leaves,
			view_size,
			game_offset,
			game_size,
			payload_factory,
			random_source,
			initial_leaf_count
		)
	for _fly_idx in range(max(0, firefly_count)):
		fireflies.append(payload_factory.build_firefly(view_size, random_source))


func should_spawn_ambient_leaf(
	layout_size: Vector2,
	random_source: RandomNumberGenerator,
	delta: float,
	excitement: float,
	spawn_rate: float
) -> bool:
	if layout_size.x <= 0.0:
		return false
	return random_source.randf() < spawn_rate * delta * 60.0 * (1.0 + excitement)


func append_ambient_leaf(
	falling_leaves: Array,
	layout_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	payload_factory: Object,
	random_source: RandomNumberGenerator,
	max_leaf_count: int
) -> void:
	if falling_leaves.size() >= max_leaf_count:
		return
	var leaf: Dictionary = payload_factory.build_ambient_leaf(
		layout_size,
		game_offset,
		game_size,
		random_source
	)
	if leaf.is_empty():
		return
	falling_leaves.append(leaf)
