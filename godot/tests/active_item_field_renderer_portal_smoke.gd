extends SceneTree

const ActiveItemFieldRenderer := preload("res://scripts/items/active_item_field_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_portal_sheet_loads()
	_verify_regular_portal_frame_progress()
	_verify_sustained_portal_phase_frames()
	_verify_sustained_portal_open_factor()

	if _failures.is_empty():
		print("active_item_field_renderer_portal_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_portal_sheet_loads() -> void:
	var renderer := ActiveItemFieldRenderer.new()
	var sheet: Texture2D = renderer._get_portal_sheet_texture()
	_expect(sheet != null, "64-frame item spawn portal sheet should load")
	if sheet != null:
		_expect(sheet.get_size().x > 0.0 and sheet.get_size().y > 0.0, "portal sheet should expose a non-empty texture size")


func _verify_regular_portal_frame_progress() -> void:
	var renderer := ActiveItemFieldRenderer.new()
	var frame_position: float = renderer._get_portal_frame_position({}, 1000, 500, 1000)
	_expect_close(frame_position, 32.0, "regular portal should map halfway progress to frame 32 of 64")


func _verify_sustained_portal_phase_frames() -> void:
	var renderer := ActiveItemFieldRenderer.new()
	var now_msec := 2000
	var opening := {
		"sustained": true,
		"phase": "opening",
		"phase_start_msec": now_msec - 219,
		"start_msec": now_msec - 219,
	}
	var holding := {
		"sustained": true,
		"phase": "holding",
		"phase_start_msec": now_msec,
		"start_msec": now_msec,
	}
	var closing := {
		"sustained": true,
		"phase": "closing",
		"phase_start_msec": now_msec - 250,
		"start_msec": now_msec - 1000,
	}

	var opening_frame: float = renderer._get_portal_frame_position(opening, now_msec, 219, 1000)
	var holding_frame: float = renderer._get_portal_frame_position(holding, now_msec, 0, 1000)
	var closing_frame: float = renderer._get_portal_frame_position(closing, now_msec, 1000, 1000)
	_expect(opening_frame > 0.0 and opening_frame <= 28.0, "opening sustained portal should advance up to the release frame")
	_expect_close(holding_frame, 28.0, "holding sustained portal should stay on the release frame")
	_expect(closing_frame > 28.0 and closing_frame < 63.0, "closing sustained portal should advance toward the final frame")


func _verify_sustained_portal_open_factor() -> void:
	var renderer := ActiveItemFieldRenderer.new()
	var now_msec := 3000
	var opening := {
		"sustained": true,
		"phase": "opening",
		"phase_start_msec": now_msec - 219,
		"start_msec": now_msec - 219,
	}
	var holding := {
		"sustained": true,
		"phase": "holding",
		"phase_start_msec": now_msec,
		"start_msec": now_msec,
	}
	var closing := {
		"sustained": true,
		"phase": "closing",
		"phase_start_msec": now_msec - 250,
		"start_msec": now_msec - 1000,
	}
	var opening_factor: float = renderer._portal_open_factor_for_portal(opening, now_msec, 219, 1000)
	var holding_factor: float = renderer._portal_open_factor_for_portal(holding, now_msec, 0, 1000)
	var closing_factor: float = renderer._portal_open_factor_for_portal(closing, now_msec, 1000, 1000)
	_expect(opening_factor > 0.0 and opening_factor < 1.0, "opening sustained portal should ease in")
	_expect_close(holding_factor, 1.0, "holding sustained portal should remain fully open")
	_expect(closing_factor > 0.0 and closing_factor < 1.0, "closing sustained portal should ease out")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
