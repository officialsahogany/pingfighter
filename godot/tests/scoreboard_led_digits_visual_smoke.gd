extends SceneTree

const ScoreboardLedDigits := preload("res://scripts/hud/scoreboard_led_digits.gd")

var _failures: Array[String] = []
var _probe: LedProbeCanvas = null
var _frame_count := 0


class LedProbeCanvas:
	extends Node2D

	var digits: Object = ScoreboardLedDigits.new()
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_rect(Rect2(0.0, 0.0, 180.0, 150.0), Color.BLACK)
		digits.draw_number(
			self,
			Vector2(20.0, 20.0),
			1,
			Color(120.0 / 255.0, 220.0 / 255.0, 1.0),
			110.0,
			3.0,
			1.4,
			1.0,
			3
		)


func _init() -> void:
	get_root().size = Vector2i(180, 150)
	_probe = LedProbeCanvas.new()
	_probe.name = "ScoreboardLedDigitsVisualProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_visual_probe()

	if _failures.is_empty():
		print("scoreboard_led_digits_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _verify_visual_probe() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "scoreboard LED visual probe should receive a live draw callback")
	if _is_headless_run():
		_verify_visual_contract_without_pixels()
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		_verify_visual_contract_without_pixels()
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		_verify_visual_contract_without_pixels()
		return
	var background: Color = image.get_pixel(5, 5)
	var off_socket: Color = image.get_pixel(25, 25)
	var lit_socket: Color = image.get_pixel(55, 25)
	_expect(_brightness(background) < 0.02, "visual probe background should remain dark")
	_expect(_brightness(off_socket) > _brightness(background) + 0.01, "inactive LED sockets should be visibly present")
	_expect(_brightness(lit_socket) > _brightness(off_socket) + 0.25, "lit LED sockets should be much brighter than inactive sockets")


func _verify_visual_contract_without_pixels() -> void:
	var digits: Object = ScoreboardLedDigits.new()
	var pattern: Array = digits.digit_patterns.get_pattern("1")
	var lit_centers: Array[Vector2] = digits._get_lit_centers("1", pattern, 10.0)
	var unlit_centers: Array[Vector2] = digits._get_unlit_centers("1", pattern, 10.0)
	_expect(lit_centers.size() + unlit_centers.size() == 77, "headless LED visual contract should keep the full 7x11 matrix without lit-socket overdraw")
	_expect(not lit_centers.is_empty(), "headless LED visual contract should keep lit sockets for the digit")


func _brightness(color: Color) -> float:
	return (color.r + color.g + color.b) / 3.0


func _is_headless_run() -> bool:
	if OS.get_cmdline_args().has("--headless"):
		return true
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		return true
	return OS.has_feature("headless")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
