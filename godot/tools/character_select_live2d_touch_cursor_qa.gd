extends SceneTree

# Real-window QA for the Han Miryang Live2D touch cursor. The viewport capture
# includes an exact cursor-texture echo because hardware cursors are not part of
# Godot's framebuffer; the report separately verifies the live cursor shape.

const CharacterSelectScene := preload("res://scenes/character_select.tscn")
const TouchCursor := preload("res://scripts/ui/character_select_live2d_touch_cursor.gd")

const OUTPUT_DIR := "D:/main/bosspong/preview_outputs/character_select_live2d_touch_cursor_qa_20260816"
const OUTPUT_CAPTURE := OUTPUT_DIR + "/han_miryang_live2d_touch_cursor_vulkan.png"
const OUTPUT_CURSOR := OUTPUT_DIR + "/han_miryang_touch_hand_cursor_8x.png"
const OUTPUT_REPORT := OUTPUT_DIR + "/qa_report.json"
const WINDOW_SIZE := Vector2i(1920, 1080)
# 한미량의 캐릭터 선택 호환 id (config 호환 식별자 — 리네임 금지 계약)
const HAN_MIRYANG_CHARACTER_ID := "ufo_player"

var _failure_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("character_select_live2d_touch_cursor_qa requires a real display server")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	DisplayServer.window_set_size(WINDOW_SIZE)
	get_root().size = WINDOW_SIZE

	var screen := CharacterSelectScene.instantiate()
	screen.auto_start_battle = false
	get_root().add_child(screen)
	for _frame in range(30):
		await process_frame

	var han_index := _find_character_index(screen, HAN_MIRYANG_CHARACTER_ID)
	_expect(han_index >= 0, "Han Miryang should exist in the production character list")
	if han_index < 0:
		await _finish(screen, {})
		return
	screen.call("_select_index", han_index)

	var preview := screen.get_node_or_null("LivePreview") as Control
	_expect(preview != null, "production character select should contain LivePreview")
	if preview == null:
		await _finish(screen, {})
		return
	var live2d_rect := Rect2()
	for _frame in range(600):
		live2d_rect = preview.call("get_live2d_region_rect", TouchCursor.FULL_LIVE2D_REGION)
		if live2d_rect.has_area():
			break
		await process_frame
	_expect(live2d_rect.has_area(), "Han Miryang production Live2D should resolve its interactive art rect")
	if not live2d_rect.has_area():
		await _finish(screen, {})
		return

	var hover_point := preview.position + live2d_rect.get_center()
	Input.warp_mouse(hover_point)
	screen.call("_update_live2d_touch_cursor", hover_point)
	await process_frame
	await process_frame
	var controller: Object = screen.get("_live2d_touch_cursor")
	_expect(controller != null and bool(controller.call("is_active")), "Han Miryang art hover should activate the cursor controller")
	_expect(screen.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "screen cursor shape should become pointing-hand on Han Miryang art")
	_expect(DisplayServer.cursor_get_shape() == DisplayServer.CURSOR_POINTING_HAND, "display server should materialize the pointing-hand cursor shape")

	var cursor_texture := load(TouchCursor.CURSOR_TEXTURE_PATH) as Texture2D
	_expect(cursor_texture != null, "runtime touch cursor texture should load")
	if cursor_texture != null:
		var cursor_image := cursor_texture.get_image()
		cursor_image.resize(384, 384, Image.INTERPOLATE_NEAREST)
		_expect(cursor_image.save_png(OUTPUT_CURSOR) == OK, "cursor inspection PNG should save")
		var cursor_echo := TextureRect.new()
		cursor_echo.name = "CursorTextureEchoForCapture"
		cursor_echo.texture = cursor_texture
		cursor_echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cursor_echo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cursor_echo.position = hover_point - TouchCursor.CURSOR_HOTSPOT
		cursor_echo.size = Vector2(48.0, 48.0)
		cursor_echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cursor_echo.z_index = 4096
		screen.add_child(cursor_echo)

	await process_frame
	await RenderingServer.frame_post_draw
	var capture := get_root().get_texture().get_image()
	_expect(capture.get_size() == WINDOW_SIZE, "Vulkan capture should use the acceptance resolution")
	_expect(capture.save_png(OUTPUT_CAPTURE) == OK, "Vulkan cursor capture should save")

	var outside_point := Vector2(12.0, 12.0)
	Input.warp_mouse(outside_point)
	screen.call("_update_live2d_touch_cursor", outside_point)
	await process_frame
	_expect(not bool(controller.call("is_active")), "leaving the Live2D art should deactivate the custom cursor")
	_expect(screen.mouse_default_cursor_shape == Control.CURSOR_ARROW, "leaving the Live2D art should restore the arrow")

	var other_index := _find_other_character_index(screen, han_index)
	_expect(other_index >= 0, "a non-Han-Miryang reverse-leg character should exist")
	if other_index >= 0:
		screen.call("_select_index", other_index)
		await process_frame
		screen.call("_update_live2d_touch_cursor", hover_point)
		await process_frame
		_expect(not bool(controller.call("is_active")), "other characters must not activate the Han Miryang cursor")

	var report := {
		"status": "pass" if _failure_count == 0 else "fail",
		"display_server": DisplayServer.get_name(),
		"rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"window_size": [WINDOW_SIZE.x, WINDOW_SIZE.y],
		"han_miryang_index": han_index,
		"reverse_leg_character_index": other_index,
		"live2d_rect": [live2d_rect.position.x, live2d_rect.position.y, live2d_rect.size.x, live2d_rect.size.y],
		"hover_point": [hover_point.x, hover_point.y],
		"cursor_hotspot": [TouchCursor.CURSOR_HOTSPOT.x, TouchCursor.CURSOR_HOTSPOT.y],
		"cursor_texture_size": [cursor_texture.get_width(), cursor_texture.get_height()] if cursor_texture != null else [0, 0],
		"capture": OUTPUT_CAPTURE,
		"cursor_preview": OUTPUT_CURSOR,
	}
	await _finish(screen, report)


func _find_character_index(screen: Control, character_id: String) -> int:
	var entries: Array = screen.get("characters")
	for index in range(entries.size()):
		var value: Variant = entries[index]
		if value is Dictionary and str((value as Dictionary).get("id", "")) == character_id:
			return index
	return -1


func _find_other_character_index(screen: Control, excluded_index: int) -> int:
	var entries: Array = screen.get("characters")
	for index in range(entries.size()):
		if index != excluded_index:
			return index
	return -1


func _finish(screen: Control, report: Dictionary) -> void:
	if not report.is_empty():
		var report_file := FileAccess.open(OUTPUT_REPORT, FileAccess.WRITE)
		if report_file == null:
			_expect(false, "cursor QA report should open for writing")
		else:
			report_file.store_string(JSON.stringify(report, "  "))
			report_file.close()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		await process_frame
	if _failure_count > 0:
		quit(1)
		return
	print("character_select_live2d_touch_cursor_qa: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failure_count += 1
	push_error(message)
