extends SceneTree

const ConfirmFlashOverlay := preload("res://scripts/ui/character_select_confirm_flash_overlay.gd")

var failure_count: int = 0
var ran: bool = false


func _process(_delta: float) -> bool:
	if ran:
		return true
	ran = true
	_run()
	return true


func _run() -> void:
	var main_window: Window = get_root()
	var overlay: Control = ConfirmFlashOverlay.new()
	overlay.size = Vector2(960.0, 540.0)
	main_window.add_child(overlay)

	overlay.call("play", {
		"duration": 0.18,
		"source_rect": Rect2(120.0, 80.0, 420.0, 360.0),
		"style": "slash",
		"split_intensity": 0.72,
		"split_count": 13,
	})
	_expect(bool(overlay.get("active")), "confirm flash should become active after play")
	_expect(overlay.visible, "confirm flash should become visible after play")
	_expect(is_equal_approx(float(overlay.get("split_intensity")), 0.72), "confirm flash should apply split fracture intensity")
	_expect(int(overlay.get("split_count")) == 13, "confirm flash should apply split fracture count")
	_expect(overlay.get("_field_rect") is ColorRect, "confirm flash should keep the shader field layer")
	_expect(overlay.get("_halo_rect") is ColorRect, "confirm flash should keep the halo layer")
	_expect(overlay.get("_white_rect") is ColorRect, "confirm flash should keep the white wash layer")

	overlay.call("_process", 0.09)
	_expect(float(overlay.get("accent_progress")) > 0.0, "confirm flash should advance its accent progress")
	overlay.call("cancel")
	_expect(not bool(overlay.get("active")), "confirm flash cancel should clear active state")
	_expect(not overlay.visible, "confirm flash cancel should hide the overlay")

	overlay.queue_free()
	if failure_count > 0:
		quit(1)
		return
	print("character_select_confirm_flash_split_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
