extends SceneTree

const Stage1PillarHudSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
)
const Stage1PillarUiRenderer := preload(
	"res://scripts/hud/stage1_pillar_ui_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const GAME_SOURCE_SIZE := Vector2(760.0, 750.0)
const PIXEL_DIFF_THRESHOLD := 0.08
const CORNER_DIFF_LIMIT := 0.035


class FakeTowerFlow:
	extends RefCounted

	var run_id := "pillar-currency-qa"
	var muhon := 99999

	func get_run_id() -> String:
		return run_id

	func get_run_state_snapshot() -> Dictionary:
		return {"muhon": muhon}


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func get_cached_instance(key: String) -> Variant:
		return modules.get(key, null)


class CaptureDrawer:
	extends Node2D

	var scene_drawer: Object
	var registry: Object
	var view_size := Vector2(VIEW_SIZE)
	var game_offset := Vector2.ZERO
	var game_size := Vector2.ZERO
	var bright_background := true
	var show_hud := false

	func _draw() -> void:
		_draw_background()
		if show_hud:
			scene_drawer.call(
				"_draw_gold_hud",
				self,
				{
					"height": 750.0,
					"current_stage": 1,
					"runtime_perk_gold": 99999,
				},
				registry,
				game_offset,
				game_size
			)

	func _draw_background() -> void:
		var base := Color(0.86, 0.82, 0.70, 1.0) if bright_background else Color(0.045, 0.055, 0.075, 1.0)
		var fiber := Color(0.36, 0.29, 0.18, 0.10) if bright_background else Color(0.30, 0.42, 0.56, 0.09)
		draw_rect(Rect2(Vector2.ZERO, view_size), base, true)
		for y in range(10, int(view_size.y), 29):
			var skew := float((y * 17) % 41)
			draw_line(Vector2(0.0, float(y)), Vector2(view_size.x, float(y) + skew * 0.08), fiber, 1.0)
		draw_rect(Rect2(game_offset, game_size), Color(0.09, 0.11, 0.14, 1.0), true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("pillar_currency_hud_visual_qa requires a Vulkan window")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path("res://.godot/codex_artifacts/pillar_currency_hud")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	DirAccess.make_dir_recursive_absolute(output_dir)

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var scale_factor := float(VIEW_SIZE.y) / GAME_SOURCE_SIZE.y
	var game_size := GAME_SOURCE_SIZE * scale_factor
	var game_offset := (Vector2(VIEW_SIZE) - game_size) * 0.5
	var cases := [
		{"name": "tower_bright", "bright": true, "tower": true},
		{"name": "tower_dark", "bright": false, "tower": true},
		{"name": "non_tower_bright", "bright": true, "tower": false},
	]
	var captures := 0
	for case_value in cases:
		var case := case_value as Dictionary
		var renderer := Stage1PillarUiRenderer.new()
		var flow := FakeTowerFlow.new()
		if not bool(case.get("tower", false)):
			flow.run_id = ""
		var registry := FakeRegistry.new()
		registry.modules = {
			"stage1_pillar_ui_renderer": renderer,
			"tower_ascent_flow_owner": flow,
		}
		var capture_drawer := CaptureDrawer.new()
		capture_drawer.scene_drawer = Stage1PillarHudSceneDrawer.new()
		capture_drawer.registry = registry
		capture_drawer.game_offset = game_offset
		capture_drawer.game_size = game_size
		capture_drawer.bright_background = bool(case.get("bright", true))
		viewport.add_child(capture_drawer)
		capture_drawer.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var background: Image = viewport.get_texture().get_image()
		capture_drawer.show_hud = true
		capture_drawer.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var rendered: Image = viewport.get_texture().get_image()
		var hud_context := {
			"height": 750.0,
			"gold_hud_amount": 99999,
			"tower_muhon_hud_visible": bool(case.get("tower", false)),
			"tower_muhon_hud_amount": 99999,
		}
		var layout: Dictionary = renderer.build_currency_hud_layout(game_offset, game_size, hud_context)
		var output_path := output_dir.path_join("%s_2020x1246.png" % str(case.get("name", "case")))
		var background_path := output_dir.path_join("%s_background_2020x1246.png" % str(case.get("name", "case")))
		background.save_png(background_path)
		rendered.save_png(output_path)
		var changed_pixels := _verify_pixels(
			background,
			rendered,
			layout,
			bool(case.get("tower", false)),
			str(case.get("name", "case"))
		)
		if changed_pixels < 0:
			viewport.remove_child(capture_drawer)
			capture_drawer.queue_free()
			viewport.queue_free()
			await process_frame
			quit(1)
			return
		if not FileAccess.file_exists(output_path):
			push_error("failed to save pillar currency capture: %s" % output_path)
			quit(1)
			return
		DirAccess.remove_absolute(background_path)
		print("pillar_currency_hud_visual_qa: %s_changed_pixels=%d" % [str(case.get("name", "case")), changed_pixels])
		captures += 1
		viewport.remove_child(capture_drawer)
		capture_drawer.queue_free()
	print("pillar_currency_hud_visual_qa: captures=%d" % captures)
	print("pillar_currency_hud_visual_qa: output_dir=%s" % output_dir)
	print("pillar_currency_hud_visual_qa: ok")
	quit(0)


func _verify_pixels(
	background: Image,
	rendered: Image,
	layout: Dictionary,
	tower_visible: bool,
	case_name: String
) -> int:
	var gold_rect: Rect2 = layout.get("gold_rect", Rect2())
	var muhon_rect: Rect2 = layout.get("muhon_rect", Rect2())
	var changed_pixels := _count_changed_pixels(background, rendered, gold_rect)
	if tower_visible:
		changed_pixels += _count_changed_pixels(background, rendered, muhon_rect)
	if changed_pixels < 120:
		push_error("%s did not render enough contrasting currency pixels" % case_name)
		return -1
	var rects := [gold_rect, muhon_rect] if tower_visible else [gold_rect]
	for rect_value in rects:
		var rect := rect_value as Rect2
		var changed_corners := 0
		for point in [
			rect.position + Vector2(2.0, 2.0),
			Vector2(rect.end.x - 3.0, rect.position.y + 2.0),
			Vector2(rect.position.x + 2.0, rect.end.y - 3.0),
			rect.end - Vector2(3.0, 3.0),
		]:
			var pixel := Vector2i(clampi(int(point.x), 0, VIEW_SIZE.x - 1), clampi(int(point.y), 0, VIEW_SIZE.y - 1))
			if _color_distance(background.get_pixelv(pixel), rendered.get_pixelv(pixel)) > CORNER_DIFF_LIMIT:
				changed_corners += 1
		if changed_corners >= 3:
			push_error("%s retained a flat frame or rectangular halo (%d changed corners)" % [case_name, changed_corners])
			return -1
	return changed_pixels


func _count_changed_pixels(background: Image, rendered: Image, rect: Rect2) -> int:
	var count := 0
	var x0 := clampi(int(floor(rect.position.x)), 0, VIEW_SIZE.x - 1)
	var x1 := clampi(int(ceil(rect.end.x)), 0, VIEW_SIZE.x)
	var y0 := clampi(int(floor(rect.position.y)), 0, VIEW_SIZE.y - 1)
	var y1 := clampi(int(ceil(rect.end.y)), 0, VIEW_SIZE.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			if _color_distance(background.get_pixel(x, y), rendered.get_pixel(x, y)) >= PIXEL_DIFF_THRESHOLD:
				count += 1
	return count


func _color_distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
