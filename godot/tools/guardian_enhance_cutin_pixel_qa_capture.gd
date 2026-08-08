extends SceneTree

const GuardianEnhanceHost := preload(
	"res://scripts/hud/lingpet_guardian_enhance_cutin_overlay_host.gd"
)
const GuardianEnhanceState := preload(
	"res://scripts/lingpet/lingpet_guardian_enhance_cutin_state.gd"
)
const LingpetAcquireCutinHost := preload(
	"res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd"
)
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const VIEW_SIZE := Vector2i(1280, 720)
const OUTPUT_ENV := "GUARDIAN_ENHANCE_QA_DIR"

var _failures: Array[String] = []


class EnhancementRuntime:
	extends RefCounted

	var snapshot: Dictionary = {}

	func is_guardian_enhance_cutin_active() -> bool:
		return true

	func get_guardian_enhance_cutin_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class AcquireRuntime:
	extends RefCounted

	func is_acquire_cutin_active() -> bool:
		return true

	func is_acquire_cutin_dismissing() -> bool:
		return false

	func get_acquire_cutin_progress() -> float:
		return 0.76

	func get_snapshot() -> Dictionary:
		return {"cutin_pet_id": "maribo"}


class CaptureSurface:
	extends Node2D

	var enhancement_host: Object = null
	var enhancement_runtime: Object = null
	var acquire_host: Object = null
	var acquire_runtime: Object = null
	var draw_acquisition := false

	func _draw() -> void:
		if draw_acquisition:
			acquire_host.draw(self, acquire_runtime, Vector2(VIEW_SIZE))
		else:
			enhancement_host.draw(self, enhancement_runtime, Vector2(VIEW_SIZE))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("guardian enhancement pixel QA requires a non-headless Vulkan window")
		quit(1)
		return
	var output_dir := OS.get_environment(OUTPUT_ENV).strip_edges()
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://.tmp/guardian_enhance_pixel_qa")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	_expect(mkdir_error == OK, "pixel QA output directory must be creatable")

	var root_window := get_root()
	root_window.mode = Window.MODE_WINDOWED
	root_window.size = VIEW_SIZE
	root_window.content_scale_size = VIEW_SIZE
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	var enhancement_host := GuardianEnhanceHost.new()
	var enhancement_runtime := EnhancementRuntime.new()
	var acquire_host := LingpetAcquireCutinHost.new()
	var acquire_runtime := AcquireRuntime.new()
	var surface := CaptureSurface.new()
	surface.enhancement_host = enhancement_host
	surface.enhancement_runtime = enhancement_runtime
	surface.acquire_host = acquire_host
	surface.acquire_runtime = acquire_runtime
	root_window.add_child(surface)

	_expect(
		enhancement_host.prewarm_pet_assets_step("maribo", true),
		"enhancement reaction sheet must synchronously prewarm for pixel QA"
	)
	var icon_paths := _get_maribo_icon_paths()
	for icon_path in icon_paths:
		_expect(
			enhancement_host.prewarm_result_icon_path(icon_path),
			"result icon must prewarm for pixel QA: %s" % icon_path
		)
	acquire_host.prewarm_pet_assets_step("maribo", true)
	var animation_contract: Dictionary = enhancement_host.get_animation_contract("maribo")
	var result_icon_path := icon_paths[0] if not icon_paths.is_empty() else ""
	var base_result := {
		"accepted": true,
		"trigger_source_label": "수호령 강화",
		"feedback_text": "창술 Lv.1 → Lv.2",
		"display_candidate_icons": icon_paths,
		"result_detail": {
			"kind": "skill_level",
			"icon_texture_path": result_icon_path,
		},
	}

	var images: Dictionary = {}
	var scenarios := {
		"intro_mid": _snapshot(
			GuardianEnhanceState.PHASE_INTRO, 0.07, 0.5, 0.0,
			0.0, animation_contract, base_result
		),
		"roll_mid": _snapshot(
			GuardianEnhanceState.PHASE_ROLL, 0.375, 0.5, 0.5,
			0.0, animation_contract, base_result
		),
		"stamp_land": _snapshot(
			GuardianEnhanceState.PHASE_STAMP, 0.10, 0.4545, 1.0,
			0.0, animation_contract, base_result
		),
		"reaction": _snapshot(
			GuardianEnhanceState.PHASE_REACTION, 1.20, 0.34, 1.0,
			1.20, animation_contract, base_result
		),
	}
	for label in scenarios:
		enhancement_runtime.snapshot = scenarios[label]
		surface.draw_acquisition = false
		surface.queue_redraw()
		await process_frame
		await process_frame
		var image := root_window.get_texture().get_image()
		var output_path := output_dir.path_join("guardian_enhance_%s.png" % label)
		_expect(image.save_png(output_path) == OK, "%s capture must save" % label)
		images[label] = image

	surface.draw_acquisition = true
	surface.queue_redraw()
	await process_frame
	await process_frame
	var acquire_image := root_window.get_texture().get_image()
	var acquire_comparison_image := acquire_image.duplicate()
	acquire_comparison_image.convert(Image.FORMAT_RGBA8)
	var reaction_comparison_image: Image = (images.get("reaction") as Image).duplicate()
	reaction_comparison_image.convert(Image.FORMAT_RGBA8)
	var comparison := Image.create(VIEW_SIZE.x * 2, VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	comparison.fill(Color.BLACK)
	comparison.blit_rect(
		acquire_comparison_image,
		Rect2i(Vector2i.ZERO, VIEW_SIZE),
		Vector2i.ZERO
	)
	comparison.blit_rect(
		reaction_comparison_image,
		Rect2i(Vector2i.ZERO, VIEW_SIZE),
		Vector2i(VIEW_SIZE.x, 0)
	)
	var comparison_path := output_dir.path_join("guardian_acquire_vs_enhance_hierarchy.png")
	_expect(comparison.save_png(comparison_path) == OK, "acquisition hierarchy comparison must save")

	_verify_pixels(images)
	surface.queue_free()
	await process_frame
	if _failures.is_empty():
		print("guardian_enhance_cutin_pixel_qa_capture: ok")
		for label in scenarios:
			print("capture_%s=%s" % [label, output_dir.path_join("guardian_enhance_%s.png" % label)])
		print("capture_comparison=%s" % comparison_path)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _snapshot(
	phase: String,
	phase_elapsed: float,
	phase_progress: float,
	roll_progress: float,
	reaction_elapsed: float,
	animation_contract: Dictionary,
	result: Dictionary
) -> Dictionary:
	var frame_interval := maxf(0.001, float(animation_contract.get("frame_interval", 0.036)))
	var frame_count := maxi(1, int(animation_contract.get("frame_count", 98)))
	return {
		"active": true,
		"phase": phase,
		"phase_elapsed": phase_elapsed,
		"phase_progress": phase_progress,
		"roll_progress": roll_progress,
		"reaction_elapsed": reaction_elapsed,
		"animation_frame": clampi(int(floor(reaction_elapsed / frame_interval)), 0, frame_count - 1),
		"animation_contract": animation_contract.duplicate(true),
		"display_candidate_icons": result.get("display_candidate_icons", []),
		"pet_id": "maribo",
		"result": result.duplicate(true),
		"feedback_text": str(result.get("feedback_text", "강화 획득")),
	}


func _get_maribo_icon_paths() -> Array[String]:
	var paths: Array[String] = []
	for skill in LingpetCatalog.get_active_skill_pool("maribo"):
		var icon_path := str(skill.get("icon_texture_path", "")).strip_edges()
		if icon_path != "" and not paths.has(icon_path):
			paths.append(icon_path)
		if paths.size() >= 3:
			break
	return paths


func _verify_pixels(images: Dictionary) -> void:
	var intro: Image = images.get("intro_mid") as Image
	var roll: Image = images.get("roll_mid") as Image
	var stamp: Image = images.get("stamp_land") as Image
	var reaction: Image = images.get("reaction") as Image
	for label in images:
		var image: Image = images[label] as Image
		_expect(image != null and image.get_size() == VIEW_SIZE, "%s must capture at 1280x720" % label)
	if intro == null or roll == null or stamp == null or reaction == null:
		return
	_expect(_count_enso_delta(intro, roll) > 120, "ROLL capture must contain a progressing dark Enso stroke")
	_expect(_count_stamp_red(stamp) > 180, "STAMP capture must contain a strong vermilion seal landing")
	_expect(_count_reaction_color(reaction) > 180, "REACTION capture must contain the companion result reaction")
	for label in images:
		_expect(
			_count_clipped_white(images[label] as Image) < 7000,
			"%s must avoid broad white clipping over the hanji panel" % label
		)


func _count_enso_delta(intro: Image, roll: Image) -> int:
	var count := 0
	var center := Vector2(640.0, 347.0)
	for y in range(220, 475):
		for x in range(510, 770):
			var radius := Vector2(float(x), float(y)).distance_to(center)
			if radius < 101.0 or radius > 112.0:
				continue
			var before := intro.get_pixel(x, y)
			var after := roll.get_pixel(x, y)
			if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) > 0.16:
				count += 1
	return count


func _count_stamp_red(image: Image) -> int:
	var count := 0
	for y in range(455, 550):
		for x in range(425, 525):
			var color := image.get_pixel(x, y)
			if color.r > 0.24 and color.r > color.g * 1.45 and color.r > color.b * 1.25:
				count += 1
	return count


func _count_reaction_color(image: Image) -> int:
	var count := 0
	for y in range(250, 455):
		for x in range(520, 760):
			var color := image.get_pixel(x, y)
			var high := maxf(color.r, maxf(color.g, color.b))
			var low := minf(color.r, minf(color.g, color.b))
			if high - low > 0.20 and high > 0.30:
				count += 1
	return count


func _count_clipped_white(image: Image) -> int:
	var count := 0
	for y in range(135, 585):
		for x in range(325, 955):
			var color := image.get_pixel(x, y)
			if color.r > 0.98 and color.g > 0.98 and color.b > 0.98:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
