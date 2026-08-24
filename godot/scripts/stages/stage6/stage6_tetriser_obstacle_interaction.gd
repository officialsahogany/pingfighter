extends RefCounted

# Stage 6 Tetriser obstacle collision and attack-sweep policy.
#
# Owns tetromino -> guard -> wall hit priority, boss-serve penetration,
# power-smash bypass, legacy reflection math, and dash/smoke/explosion geometry.
# The host supplies one-time callbacks for starpoint, debris, cube-progress, and
# audio side effects so this owner never duplicates those mutable domains.

const BALL_MIN_V_SPEED := 6.0
const BALL_MIN_H_SPEED := 3.0
const BALL_REFLECT_X_JITTER := 0.35

var _rng: RandomNumberGenerator
var _tetromino_state: Object
var _guard_state: Object
var _wall_state: Object
var _destroy_tetromino: Callable
var _destroy_guard_collision: Callable
var _handle_extracted_guard: Callable
var _destroy_wall_piece: Callable
var _handle_super_bounce: Callable


func _init(
	random_source: RandomNumberGenerator,
	tetromino_state: Object,
	guard_state: Object,
	wall_state: Object,
	destroy_tetromino: Callable,
	destroy_guard_collision: Callable,
	handle_extracted_guard: Callable,
	destroy_wall_piece: Callable,
	handle_super_bounce: Callable
) -> void:
	_rng = random_source
	_tetromino_state = tetromino_state
	_guard_state = guard_state
	_wall_state = wall_state
	_destroy_tetromino = destroy_tetromino
	_destroy_guard_collision = destroy_guard_collision
	_handle_extracted_guard = handle_extracted_guard
	_destroy_wall_piece = destroy_wall_piece
	_handle_super_bounce = handle_super_bounce


func resolve_ball_collision(scene: Dictionary, context: Dictionary) -> bool:
	if not _has_obstacles():
		return false
	var ball_pos: Vector2 = scene.get("ball_pos", Vector2.ZERO)
	var radius: float = maxf(1.0, float(context.get("ball_size", 28.6)) * 0.5)
	var ball_rect := Rect2(ball_pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	var penetrates_tetromino: bool = _should_ball_penetrate_tetromino(context)
	var power_smash: bool = bool(context.get("power_smashing_parabola_active", false))

	# 1) Falling/settled tetromino. Assembly cells are intentionally non-solid.
	var tetromino_hit: Dictionary = _tetromino_state.find_solid_hit(ball_rect)
	if not tetromino_hit.is_empty():
		if penetrates_tetromino:
			return false
		var tetromino: Dictionary = tetromino_hit["item"]
		if power_smash:
			_destroy_tetromino.call(tetromino, "player")
			return true
		_apply_cell_reflection(scene, context, radius, tetromino_hit["cell_rect"])
		if bool(tetromino.get("super", false)):
			_handle_super_bounce.call(tetromino)
		else:
			_destroy_tetromino.call(tetromino, "ball")
		return true

	# 2) Guard bars remain solid even for the opening boss serve.
	var guard_hit: Dictionary = _guard_state.find_active_hit(ball_rect)
	if not guard_hit.is_empty():
		_apply_cell_reflection(scene, context, radius, guard_hit["cell_rect"])
		_destroy_guard_collision.call(guard_hit["item"])
		return true

	# 3) Installed edge-wall pieces share the tetromino penetration policy.
	var wall_hit: Dictionary = _wall_state.find_installed_hit(ball_rect)
	if not wall_hit.is_empty():
		if penetrates_tetromino:
			return false
		var wall_piece: Dictionary = wall_hit["item"]
		if power_smash:
			_destroy_wall_piece.call(wall_piece)
			return true
		_apply_cell_reflection(scene, context, radius, wall_hit["cell_rect"])
		_destroy_wall_piece.call(wall_piece)
		return true

	return false


func apply_player_attack_destruction(context: Dictionary, deps: Dictionary) -> void:
	if not _has_obstacles():
		return

	var dash_snapshot: Dictionary = context.get("dash_snapshot", {})
	if bool(dash_snapshot.get("active", false)):
		var player_pos: Vector2 = context.get("player_pos", Vector2.ZERO)
		var paddle_size: Vector2 = context.get("player_paddle_size", Vector2(155.0, 50.0))
		var paddle_rect := Rect2(player_pos, paddle_size)
		_destroy_solid_obstacles(
			func(cell_rect: Rect2) -> bool: return paddle_rect.intersects(cell_rect),
			"dash"
		)

	var active_item_runtime = deps.get("active_item_runtime", null)
	if active_item_runtime == null or not ("throw_controller" in active_item_runtime):
		return
	var throw_controller = active_item_runtime.throw_controller
	if throw_controller == null:
		return

	if throw_controller.has_method("get_tear_gas_zones"):
		for zone in throw_controller.get_tear_gas_zones():
			if float(zone.get("opacity", 1.0)) <= 0.12:
				continue
			var gas_center: Vector2 = zone.get("position", Vector2.ZERO)
			var gas_rx: float = float(zone.get("radius_x", zone.get("radius", 0.0)))
			var gas_ry: float = float(zone.get("radius", 0.0))
			if gas_rx > 0.0 and gas_ry > 0.0:
				_destroy_solid_obstacles(
					func(cell_rect: Rect2) -> bool: return _rect_in_ellipse(cell_rect, gas_center, gas_rx, gas_ry),
					"smoke"
				)

	if throw_controller.has_method("get_explosion_zones"):
		for zone in throw_controller.get_explosion_zones():
			if not bool(zone.get("active", true)):
				continue
			var blast_center: Vector2 = zone.get("position", Vector2.ZERO)
			var blast_radius: float = float(zone.get("radius", 0.0))
			if blast_radius > 0.0:
				_destroy_solid_obstacles(
					func(cell_rect: Rect2) -> bool: return _rect_in_circle(cell_rect, blast_center, blast_radius),
					"explosion"
				)


func _has_obstacles() -> bool:
	return _tetromino_state.has_blocks() or _guard_state.has_blocks() or _wall_state.has_blocks()


func _should_ball_penetrate_tetromino(context: Dictionary) -> bool:
	var has_rally_key: bool = context.has("ball_rally_count") or context.has("rally_count")
	var has_last_hit_key: bool = context.has("last_hit_by")
	if not has_rally_key and not has_last_hit_key:
		return false
	var rally_count: int = int(context.get("ball_rally_count", context.get("rally_count", 0)))
	var last_hit_by: String = str(context.get("last_hit_by", ""))
	return rally_count == 0 and (last_hit_by == "boss" or last_hit_by == "")


func _apply_cell_reflection(scene: Dictionary, context: Dictionary, radius: float, cell_rect: Rect2) -> void:
	var ball_pos: Vector2 = scene.get("ball_pos", Vector2.ZERO)
	var previous_pos: Vector2 = scene.get("previous_ball_pos", context.get("ball_pos", ball_pos))
	var ball_velocity: Vector2 = scene.get("ball_vel", Vector2.ZERO)
	var diameter := Vector2(radius * 2.0, radius * 2.0)
	var ball_rect := Rect2(ball_pos - Vector2(radius, radius), diameter)
	var previous_rect := Rect2(previous_pos - Vector2(radius, radius), diameter)
	var axis: String = _choose_reflection_axis(previous_rect, ball_rect, cell_rect)
	var block_center: Vector2 = cell_rect.get_center()
	if axis == "v":
		if previous_pos.y < block_center.y:
			ball_pos.y = cell_rect.position.y - radius - 1.0
			ball_velocity.y = -maxf(BALL_MIN_V_SPEED, absf(ball_velocity.y))
		else:
			ball_pos.y = cell_rect.position.y + cell_rect.size.y + radius + 1.0
			ball_velocity.y = maxf(BALL_MIN_V_SPEED, absf(ball_velocity.y))
	else:
		if previous_pos.x < block_center.x:
			ball_pos.x = cell_rect.position.x - radius - 1.0
			ball_velocity.x = -maxf(BALL_MIN_H_SPEED, absf(ball_velocity.x))
		else:
			ball_pos.x = cell_rect.position.x + cell_rect.size.x + radius + 1.0
			ball_velocity.x = maxf(BALL_MIN_H_SPEED, absf(ball_velocity.x))
	ball_velocity.x += _rng.randf_range(-BALL_REFLECT_X_JITTER, BALL_REFLECT_X_JITTER)
	scene["ball_pos"] = ball_pos
	scene["ball_vel"] = ball_velocity


func _choose_reflection_axis(previous_rect: Rect2, current_rect: Rect2, block: Rect2) -> String:
	var block_left: float = block.position.x
	var block_right: float = block.position.x + block.size.x
	var block_top: float = block.position.y
	var block_bottom: float = block.position.y + block.size.y
	var collided_horizontally: bool = (previous_rect.position.x + previous_rect.size.x <= block_left) or (previous_rect.position.x >= block_right)
	var collided_vertically: bool = (previous_rect.position.y + previous_rect.size.y <= block_top) or (previous_rect.position.y >= block_bottom)
	if collided_horizontally and not collided_vertically:
		return "h"
	if collided_vertically and not collided_horizontally:
		return "v"
	var overlap_x: float = minf(current_rect.position.x + current_rect.size.x - block_left, block_right - current_rect.position.x)
	var overlap_y: float = minf(current_rect.position.y + current_rect.size.y - block_top, block_bottom - current_rect.position.y)
	return "h" if overlap_x < overlap_y else "v"


func _destroy_solid_obstacles(test: Callable, reason: String) -> int:
	var destroyed := 0
	var tetromino_matches: Array = _tetromino_state.find_solid_matching(test)
	for tetromino in tetromino_matches:
		_destroy_tetromino.call(tetromino, reason)
	destroyed += tetromino_matches.size()
	var removed_guards: Array = _guard_state.extract_active_matching(test)
	for guard in removed_guards:
		_handle_extracted_guard.call(guard)
	destroyed += removed_guards.size()
	var wall_matches: Array = _wall_state.find_installed_matching(test)
	for wall in wall_matches:
		_destroy_wall_piece.call(wall)
	destroyed += wall_matches.size()
	return destroyed


func _rect_in_ellipse(cell_rect: Rect2, center: Vector2, radius_x: float, radius_y: float) -> bool:
	if radius_x <= 0.0 or radius_y <= 0.0:
		return false
	var cell_center: Vector2 = cell_rect.get_center()
	var normalized_x: float = (cell_center.x - center.x) / radius_x
	var normalized_y: float = (cell_center.y - center.y) / radius_y
	return normalized_x * normalized_x + normalized_y * normalized_y <= 1.0


func _rect_in_circle(cell_rect: Rect2, center: Vector2, radius: float) -> bool:
	return cell_rect.get_center().distance_to(center) <= radius
