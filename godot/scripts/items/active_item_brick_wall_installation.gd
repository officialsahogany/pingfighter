extends RefCounted

const BRICK_WALL_INSTALL_FRAMES := 30.0


func start_installation(wall_rect: Rect2, gauge_center: Vector2) -> Dictionary:
	return {
		"installing": true,
		"timer_frames": BRICK_WALL_INSTALL_FRAMES,
		"initial_frames": BRICK_WALL_INSTALL_FRAMES,
		"pending_wall": {
			"rect": wall_rect,
			"hit_count": 0,
			"crack_level": 0,
			"gauge_center": gauge_center,
		},
		"completed_wall": {},
	}


func clear_installation() -> Dictionary:
	return {
		"installing": false,
		"timer_frames": 0.0,
		"initial_frames": 0.0,
		"pending_wall": {},
		"completed_wall": {},
	}


func update_installation(
	installing: bool,
	timer_frames: float,
	initial_frames: float,
	pending_wall: Dictionary,
	delta: float
) -> Dictionary:
	if not installing:
		return {
			"installing": false,
			"timer_frames": 0.0,
			"initial_frames": 0.0,
			"pending_wall": pending_wall,
			"completed_wall": {},
		}

	var fps_scale: float = delta * 60.0
	var next_timer: float = max(0.0, timer_frames - fps_scale)
	if next_timer > 0.0:
		return {
			"installing": true,
			"timer_frames": next_timer,
			"initial_frames": initial_frames,
			"pending_wall": pending_wall,
			"completed_wall": {},
		}

	var completed_wall: Dictionary = {}
	if not pending_wall.is_empty():
		completed_wall = pending_wall.duplicate(true)
		completed_wall.erase("gauge_center")
	return {
		"installing": false,
		"timer_frames": 0.0,
		"initial_frames": initial_frames,
		"pending_wall": {},
		"completed_wall": completed_wall,
	}


func apply_update(
	target: Object,
	installing: bool,
	timer_frames: float,
	initial_frames: float,
	pending_wall: Dictionary,
	brick_walls: Array[Dictionary],
	particles: Array[Dictionary],
	delta: float,
	state_applier: Object,
	particles_helper: Object
) -> void:
	var result: Dictionary = update_installation(
		installing,
		timer_frames,
		initial_frames,
		pending_wall,
		delta
	)
	state_applier.apply_brick_wall_installation_state(target, result)

	var completed_wall: Dictionary = _get_dictionary(result, "completed_wall")
	if completed_wall.is_empty():
		return
	brick_walls.append(completed_wall)
	particles_helper.spawn_install_complete_particles(particles, _get_rect2(completed_wall, "rect", Rect2()))


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_rect2(source: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = source.get(key, fallback)
	if value is Rect2:
		return value
	return fallback
