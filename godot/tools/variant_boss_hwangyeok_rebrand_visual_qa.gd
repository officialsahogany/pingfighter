extends SceneTree

const ScoreboardOverlayHeaderRenderer := preload(
	"res://scripts/hud/scoreboard_overlay_header_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_PATH := (
	"res://.godot/codex_captures/variant_boss_hwangyeok_rebrand/"
	+ "scoreboard_four_variants_ko.png"
)
const CASES := [
	{"stage": 2, "variant": "arachne", "display_name": "거미각시"},
	{"stage": 2, "variant": "molewang", "display_name": "지굴왕"},
	{"stage": 3, "variant": "alice", "display_name": "옥토선자"},
	{"stage": 3, "variant": "teddy_bear", "display_name": "포웅귀"},
]


class CaptureCanvas:
	extends Node2D

	var renderer: Object = ScoreboardOverlayHeaderRenderer.new()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("17100b"), true)
		for case_index in range(CASES.size()):
			var column: int = case_index % 2
			var row: int = case_index / 2
			var panel_rect := Rect2(
				Vector2(60.0 + float(column) * 970.0, 60.0 + float(row) * 583.0),
				Vector2(930.0, 543.0)
			)
			draw_rect(panel_rect, Color("ead5ad"), true)
			draw_rect(panel_rect, Color("8b5d24"), false, 4.0)
			var case_data: Dictionary = CASES[case_index]
			var board_rect := Rect2(
				panel_rect.position + Vector2(24.0, 92.0),
				Vector2(panel_rect.size.x - 48.0, 360.0)
			)
			renderer.draw(
				self,
				board_rect,
				1.0,
				"boss",
				case_index + 1,
				{
					"current_stage": int(case_data.get("stage", 0)),
					"stage_boss_variant": str(case_data.get("variant", "")),
					"selected_character_type": "smasher",
					"selected_character_name": "스매셔",
				}
			)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("variant boss display-name visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("variant boss display-name visual QA requires a Vulkan rendering device")
		return
	var renderer := ScoreboardOverlayHeaderRenderer.new()
	for case_data in CASES:
		var actual_name: String = str(renderer.resolve_boss_name({
			"current_stage": int(case_data.get("stage", 0)),
			"stage_boss_variant": str(case_data.get("variant", "")),
		}))
		if actual_name != str(case_data.get("display_name", "")):
			_fail("production scoreboard resolver returned stale name for %s" % str(case_data.get("variant", "")))
			return
	var output_absolute: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	var output_dir: String = output_absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("could not create variant boss display-name capture directory")
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new()
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(8):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output_absolute) != OK:
		_fail("failed to save variant boss display-name capture")
		return
	if _count_changed_pixels(image, Color("17100b")) < 100000:
		_fail("variant boss display-name capture did not render the production panels")
		return
	print("[VariantBossHwangyeokVisualQA] evidence=%s" % output_absolute)
	print("variant_boss_hwangyeok_rebrand_visual_qa: ok")
	quit(0)


func _count_changed_pixels(image: Image, background: Color) -> int:
	var changed := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			var distance := (
				absf(pixel.r - background.r)
				+ absf(pixel.g - background.g)
				+ absf(pixel.b - background.b)
			)
			if distance > 0.04:
				changed += 1
	return changed


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
