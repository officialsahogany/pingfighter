extends SceneTree

const BootFlowScene := preload("res://scenes/boot_flow.tscn")
const BattleLoadingScreenRenderer := preload("res://scripts/core/battle_loading_screen_renderer.gd")
const LoadingCameoHost := preload("res://scripts/core/loading_cameo_host.gd")

const VIEW_SIZE := Vector2i(1280, 720)

var _failures: Array[String] = []


class BattleCaptureSurface:
	extends Node2D

	var current_stage := 5
	var selected_character_name := "바이퍼"
	var selected_character_type := "viper"
	var ai_mode := "champion"
	var renderer: Object = null
	var context: Dictionary = {}

	func _draw() -> void:
		if renderer != null:
			renderer.draw(
				self,
				self,
				Callable(self, "_get_module"),
				Vector2(VIEW_SIZE),
				context
			)

	func _get_module(_key: String) -> Object:
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment("LOADING_SCREEN_QA_DIR").strip_edges()
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://.tmp/loading_screen_qa")
	DirAccess.make_dir_recursive_absolute(output_dir)
	LoadingCameoHost.prewarm_assets()

	var root_window := get_root()
	root_window.size = VIEW_SIZE
	root_window.content_scale_size = VIEW_SIZE
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var boot_path := output_dir.path_join("loading_screen_minimal_boot_live_qa.png")
	var battle_path := output_dir.path_join("loading_screen_minimal_stage_transition_live_qa.png")

	# Capture the battle surface first. BootFlow intentionally reapplies the
	# player's desktop window settings during _ready(), which belongs in the
	# boot capture but must not leak into this fixed-resolution renderer probe.
	var surface := BattleCaptureSurface.new()
	var renderer := BattleLoadingScreenRenderer.new()
	renderer.prewarm_assets()
	surface.renderer = renderer
	surface.context = {
		"loading_title": "스테이지 전환 중",
		"loading_subtitle": "다음 스테이지 준비",
		"loading_status": "전투 데이터 준비 중",
		"loading_progress": 0.46,
		"battle_initialized": true,
		"stage_landing_intro_started": false,
	}
	root_window.add_child(surface)
	surface.queue_redraw()
	await process_frame
	await process_frame
	var battle_image := root_window.get_texture().get_image()
	_expect(battle_image.save_png(battle_path) == OK, "stage-transition loading QA screenshot should save")
	_verify_minimal_pixels(battle_image, "stage transition")
	renderer.hide_loading()
	surface.queue_free()
	await process_frame

	var boot_flow := BootFlowScene.instantiate() as Control
	root_window.add_child(boot_flow)
	await process_frame
	boot_flow.set_process(false)
	boot_flow.set("logo_intro", null)
	boot_flow.set("loading_character_select", true)
	boot_flow.position = Vector2.ZERO
	boot_flow.size = Vector2(VIEW_SIZE)
	boot_flow.queue_redraw()
	await process_frame
	await process_frame
	var boot_image := root_window.get_texture().get_image()
	_expect(boot_image.save_png(boot_path) == OK, "boot loading QA screenshot should save")
	_verify_minimal_pixels(boot_image, "boot")
	boot_flow.queue_free()
	await process_frame

	if _failures.is_empty():
		print("loading_screen_minimal_pixel_qa_capture: ok")
		print("boot_capture=%s" % boot_path)
		print("stage_transition_capture=%s" % battle_path)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_minimal_pixels(image: Image, surface_name: String) -> void:
	_expect(image != null and image.get_size() == VIEW_SIZE, "%s QA capture should be 1280x720" % surface_name)
	if image == null or image.get_size() != VIEW_SIZE:
		return
	_expect(_is_black(image.get_pixel(640, 360)), "%s loading center should stay pure black" % surface_name)
	_expect(
		_count_nonblack(image, Rect2i(320, 180, 640, 300)) < 12,
		"%s loading center should contain no legacy title, wave, glow, progress bar, or percentage" % surface_name
	)
	_expect(
		_count_bright(image, Rect2i(1020, 515, 220, 135)) > 180,
		"%s loading should render a readable white cameo in the lower-right" % surface_name
	)
	_expect(
		_count_bright(image, Rect2i(1010, 640, 230, 48)) > 90,
		"%s loading should render the Now Loading copy under the cameo" % surface_name
	)
	_expect(
		_count_nonblack(image, Rect2i(36, 626, 900, 70)) > 120,
		"%s loading should render one gameplay-tip line in the lower-left" % surface_name
	)


func _count_nonblack(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var color := image.get_pixel(x, y)
			if color.r > 0.02 or color.g > 0.02 or color.b > 0.02:
				count += 1
	return count


func _count_bright(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var color := image.get_pixel(x, y)
			if color.r > 0.72 and color.g > 0.72 and color.b > 0.72:
				count += 1
	return count


func _is_black(color: Color) -> bool:
	return color.r < 0.01 and color.g < 0.01 and color.b < 0.01


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
