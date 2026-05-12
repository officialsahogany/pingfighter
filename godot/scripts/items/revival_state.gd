extends RefCounted

var used := false
var effect_timer_frames := 0.0
var last_loss_type := ""


func clear_runtime(clear_used: bool = false) -> void:
	effect_timer_frames = 0.0
	last_loss_type = ""
	if clear_used:
		used = false


func is_available(equipped: bool) -> bool:
	return equipped and not used


func is_effect_active() -> bool:
	return effect_timer_frames > 0.0


func start(loss_type: String, effect_frames: float) -> void:
	used = true
	last_loss_type = loss_type
	effect_timer_frames = effect_frames


func update(fps_scale: float) -> void:
	if effect_timer_frames <= 0.0:
		return
	effect_timer_frames = max(0.0, effect_timer_frames - max(0.0, fps_scale))
