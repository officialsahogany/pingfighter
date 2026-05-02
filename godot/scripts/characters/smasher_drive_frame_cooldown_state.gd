extends RefCounted

var perfect_cooldown_frames: float = 0.0
var global_cooldown_frames: float = 0.0


func reset() -> void:
	perfect_cooldown_frames = 0.0
	global_cooldown_frames = 0.0


func update(fps_scale: float) -> void:
	perfect_cooldown_frames = max(0.0, perfect_cooldown_frames - fps_scale)
	global_cooldown_frames = max(0.0, global_cooldown_frames - fps_scale)


func trigger(perfect_frames: float, global_frames: float) -> void:
	perfect_cooldown_frames = max(0.0, perfect_frames)
	global_cooldown_frames = max(0.0, global_frames)


func is_blocked() -> bool:
	return perfect_cooldown_frames > 0.0 or global_cooldown_frames > 0.0


func get_perfect_cooldown_frames() -> float:
	return perfect_cooldown_frames


func get_global_cooldown_frames() -> float:
	return global_cooldown_frames
