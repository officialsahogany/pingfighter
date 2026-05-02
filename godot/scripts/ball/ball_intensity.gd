extends RefCounted

const BallIntensityPalette := preload("res://scripts/ball/ball_intensity_palette.gd")

const INTENSITY_TRANSITION_SPEED := 0.033

var rally_count := 0
var last_hit_by := ""
var display_level := 0.0
var target_level := 0
var current_display_colors: Array[Color] = [
	Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
	Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
	Color(60.0 / 255.0, 140.0 / 255.0, 1.0),
]
var current_glow_color := Color(60.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0, 30.0 / 255.0)
var palette: Object = BallIntensityPalette.new()


func reset() -> void:
	rally_count = 0
	last_hit_by = ""
	display_level = 0.0
	target_level = 0
	current_display_colors = get_palette(0)
	current_glow_color = get_glow_color(0)


func register_hit(hit_by: String) -> void:
	if last_hit_by != "" and last_hit_by != hit_by:
		rally_count += 1
	last_hit_by = hit_by


func calculate(ball_velocity: Vector2) -> float:
	var current_speed: float = ball_velocity.length()
	var speed_level := 0
	if current_speed >= 35.0:
		speed_level = 5
	elif current_speed >= 28.0:
		speed_level = 4
	elif current_speed >= 22.0:
		speed_level = 3
	elif current_speed >= 16.0:
		speed_level = 2
	elif current_speed >= 12.0:
		speed_level = 1

	var rally_bonus: float = min(float(rally_count) * 0.1, 0.5)
	return min(1.0, float(speed_level) / 5.0 + rally_bonus)


func update_transition(ball_velocity: Vector2, fps_scale: float) -> void:
	var intensity: float = calculate(ball_velocity)
	target_level = min(5, int(intensity * 5.0))
	var step: float = INTENSITY_TRANSITION_SPEED * fps_scale
	if display_level < float(target_level):
		display_level = min(float(target_level), display_level + step)
	elif display_level > float(target_level):
		display_level = max(float(target_level), display_level - step)

	var current_level: int = int(display_level)
	var next_level: int = min(5, current_level + 1)
	var blend_factor: float = display_level - float(current_level)
	current_display_colors = palette.blend_palette(current_level, next_level, blend_factor)
	current_glow_color = palette.blend_glow_color(current_level, next_level, blend_factor)


func get_palette(level: int) -> Array[Color]:
	return palette.get_palette(level)


func get_glow_color(level: int) -> Color:
	return palette.get_glow_color(level)


func get_current_colors() -> Array[Color]:
	return current_display_colors.duplicate()


func get_current_glow_color() -> Color:
	return current_glow_color


func get_rally_count() -> int:
	return rally_count


func get_last_hit_by() -> String:
	return last_hit_by


func get_display_level() -> float:
	return display_level


func get_target_level() -> int:
	return target_level
