extends RefCounted

var pending_weather_type := ""
var trigger_timer_frames := 0.0
var activated_this_round := false
var cinematic_active := false
var cinematic_timer_frames := 0.0
var cinematic_total_frames := 0.0
var absorbed_weather_type := ""
var round_weather_type := ""
var round_effect_active := false
var absorb_center := Vector2.ZERO
var sand_absorbed_total := 0.0
var gauge_given := false


func clear_round_state() -> bool:
	var had_sand_round := round_weather_type == "sand" or absorbed_weather_type == "sand"
	pending_weather_type = ""
	trigger_timer_frames = 0.0
	activated_this_round = false
	cinematic_active = false
	cinematic_timer_frames = 0.0
	cinematic_total_frames = 0.0
	absorbed_weather_type = ""
	round_weather_type = ""
	round_effect_active = false
	absorb_center = Vector2.ZERO
	sand_absorbed_total = 0.0
	gauge_given = false
	return had_sand_round


func has_round_activity() -> bool:
	return pending_weather_type != "" or cinematic_active or round_effect_active


func arm(weather_type: String, center: Vector2, delay_frames: float) -> void:
	pending_weather_type = weather_type
	trigger_timer_frames = delay_frames
	activated_this_round = true
	absorb_center = center


func cancel_pending_activation() -> void:
	pending_weather_type = ""
	trigger_timer_frames = 0.0
	activated_this_round = false


func tick_trigger(step: float) -> bool:
	if pending_weather_type == "":
		return false
	trigger_timer_frames = max(0.0, trigger_timer_frames - max(0.0, step))
	return trigger_timer_frames <= 0.0


func start_absorb_cinematic(
	weather_type: String,
	center: Vector2,
	sand_total: float,
	total_frames: float
) -> void:
	pending_weather_type = ""
	trigger_timer_frames = 0.0
	cinematic_active = true
	cinematic_total_frames = total_frames
	cinematic_timer_frames = total_frames
	absorbed_weather_type = weather_type
	round_weather_type = ""
	round_effect_active = false
	absorb_center = center
	sand_absorbed_total = sand_total
	gauge_given = false


func tick_cinematic(step: float) -> bool:
	if not cinematic_active:
		return false
	cinematic_timer_frames = max(0.0, cinematic_timer_frames - max(0.0, step))
	return cinematic_timer_frames <= 0.0


func finish_absorb() -> bool:
	if absorbed_weather_type == "":
		cinematic_active = false
		return false
	cinematic_active = false
	cinematic_timer_frames = 0.0
	round_weather_type = absorbed_weather_type
	round_effect_active = true
	return true


func set_absorb_center(center: Vector2) -> void:
	absorb_center = center


func get_draw_weather_type() -> String:
	if absorbed_weather_type != "":
		return absorbed_weather_type
	if round_weather_type != "":
		return round_weather_type
	return pending_weather_type


func get_context(equipped: bool, active: bool, gauge_recovery: float) -> Dictionary:
	return {
		"equipped": equipped,
		"active": active,
		"pending": pending_weather_type != "",
		"pending_weather_type": pending_weather_type,
		"trigger_timer_frames": trigger_timer_frames,
		"cinematic_active": cinematic_active,
		"cinematic_timer_frames": cinematic_timer_frames,
		"absorbed_weather_type": absorbed_weather_type,
		"round_effect_active": round_effect_active,
		"round_weather_type": round_weather_type,
		"gauge_recovery": gauge_recovery,
		"sand_absorbed_total": sand_absorbed_total,
	}
