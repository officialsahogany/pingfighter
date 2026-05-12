extends RefCounted

var animation_active := false
var animation_frame := 0.0
var reset_ready := false
var pending_round_reset := false
var last_loss_type := ""


func clear() -> void:
	animation_active = false
	animation_frame = 0.0
	reset_ready = false
	pending_round_reset = false
	last_loss_type = ""


func start(loss_type: String) -> void:
	animation_active = true
	animation_frame = 0.0
	reset_ready = false
	pending_round_reset = true
	last_loss_type = loss_type


func update(fps_scale: float, reset_frame: float, total_frames: float) -> void:
	if not animation_active:
		return
	animation_frame += max(0.0, fps_scale)
	if not reset_ready and animation_frame >= reset_frame:
		reset_ready = true
	if animation_frame >= total_frames:
		animation_active = false


func consume_reset_ready() -> bool:
	if not pending_round_reset or not reset_ready:
		return false
	clear()
	return true
