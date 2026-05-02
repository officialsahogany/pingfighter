extends RefCounted

var text_timer_frames: float = 0.0


func reset(clear_text: bool = true) -> void:
	if clear_text:
		text_timer_frames = 0.0


func begin(text_duration_frames: float) -> void:
	text_timer_frames = text_duration_frames


func update(fps_scale: float) -> void:
	text_timer_frames = max(0.0, text_timer_frames - fps_scale)


func get_text_timer_frames() -> float:
	return text_timer_frames
