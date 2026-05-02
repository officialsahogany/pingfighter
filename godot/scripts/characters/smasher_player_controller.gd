extends RefCounted

const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")

var dash_controller: Object = SmasherPlayerDashController.new()


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var next_frame_counter: int = frame_counter + 1
	var next_pos: Vector2 = player_pos
	var next_speed: float = player_speed

	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null else {}
	var down_pressed: bool = bool(input_snapshot.get("down_pressed", false))
	var left_pressed: bool = bool(input_snapshot.get("left_pressed", false))
	var right_pressed: bool = bool(input_snapshot.get("right_pressed", false))
	var action_pressed: bool = bool(input_snapshot.get("action_pressed", false))
	var direction: float = float(input_snapshot.get("direction", 0.0))

	var drive_input_state: Object = deps.get("drive_input_state", null)
	if drive_input_state != null:
		drive_input_state.update_input_and_cooldowns(
			left_pressed,
			right_pressed,
			action_pressed,
			next_frame_counter,
			fps_scale
		)

	var dash_input: Dictionary = dash_controller.handle_dash_input(
		down_pressed,
		direction,
		next_speed,
		deps
	)
	next_speed = float(dash_input.get("player_speed", next_speed))
	var handled_by_dash: bool = bool(dash_input.get("handled_by_dash", false))

	if not handled_by_dash:
		var movement_state: Object = deps.get("movement_state", null)
		if movement_state != null:
			var movement: Dictionary = movement_state.update_horizontal(
				delta,
				next_pos,
				next_speed,
				direction,
				float(config.get("play_left", 0.0)),
				float(config.get("play_right", 0.0)),
				float(config.get("paddle_width", 0.0))
			)
			var moved_pos: Variant = movement.get("player_pos", next_pos)
			if moved_pos is Vector2:
				next_pos = moved_pos
			next_speed = float(movement.get("player_speed", next_speed))

	var dash_update: Dictionary = dash_controller.update_dash_motion(delta, next_pos, next_speed, config, deps)
	var dash_pos: Variant = dash_update.get("player_pos", next_pos)
	if dash_pos is Vector2:
		next_pos = dash_pos
	next_speed = float(dash_update.get("player_speed", next_speed))

	return {
		"frame_counter": next_frame_counter,
		"player_pos": next_pos,
		"player_speed": next_speed,
	}
