extends RefCounted

const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")

const DEFAULT_FIELD_SIZE := Vector2(760.0, 750.0)


static func get_reward_cinematic_positions(
	box: Dictionary,
	view_size: Vector2,
	draw_scale: float,
	timer: float,
	box_float_amplitude: float = StageClearResultBoxData.BOX_FLOAT_AMPLITUDE,
	box_float_speed: float = StageClearResultBoxData.BOX_FLOAT_SPEED,
	field_size: Vector2 = DEFAULT_FIELD_SIZE
) -> Dictionary:
	return {
		"pickup_position": get_box_pickup_position(
			box,
			view_size,
			draw_scale,
			timer,
			field_size,
			box_float_amplitude,
			box_float_speed
		),
		"target_player_center": get_live2d_target_position(view_size, draw_scale, field_size),
	}


static func get_box_pickup_position(
	box: Dictionary,
	view_size: Vector2,
	draw_scale: float,
	timer: float,
	field_size: Vector2,
	box_float_amplitude: float,
	box_float_speed: float
) -> Vector2:
	var draw_center: Vector2 = StageClearResultLayoutHelper.get_box_draw_center(
		box,
		draw_scale,
		timer,
		box_float_amplitude,
		box_float_speed
	)
	var field_origin: Vector2 = (view_size - field_size) * 0.5
	var local_position: Vector2 = draw_center - field_origin
	return Vector2(
		clamp(local_position.x, 0.0, field_size.x),
		clamp(local_position.y, 0.0, field_size.y)
	)


static func get_live2d_target_position(view_size: Vector2, draw_scale: float, field_size: Vector2) -> Vector2:
	var actor_rect: Rect2 = StageClearResultLayoutHelper.get_player_victory_actor_rect(view_size, draw_scale)
	var screen_position: Vector2 = actor_rect.get_center() + Vector2(0.0, 20.0 * draw_scale)
	return StageClearResultLayoutHelper.screen_to_acquisition_cinematic_local(screen_position, view_size, field_size)
