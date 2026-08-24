extends SceneTree

const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerGuardianSpringPresentationAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_guardian_spring_presentation_asset_catalog.gd"
)

const VIEW_SIZE := Vector2i(760, 750)
const OUTPUT_DIR := "res://.godot/codex_captures/guardian_spring_presentation"
const STATUE_SOURCE_PATH := "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_statue_palm_stele_imagegen_v1.png"
const CAPSULE_SOURCE_PATH := "res://assets/sprites/tower/noncombat/guardian_spring_presentation/guardian_spring_capsule_frame_jade_seed_imagegen_v1.png"


class CaptureFlow:
	extends RefCounted
	var modal_state: Object
	var render_context: Dictionary

	func _init(state_value: Object, context_value: Dictionary) -> void:
		modal_state = state_value
		render_context = context_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "guardian_spring"

	func get_node_modal_render_context() -> Dictionary:
		return render_context


class CaptureCanvas:
	extends Node2D
	var flow: Object
	var renderer := TowerAscentFlowRenderer.new()

	func _init(flow_value: Object) -> void:
		flow = flow_value

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


var _viewport: SubViewport
var _canvas: CaptureCanvas
var _flow: CaptureFlow


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_guardian_spring_presentation_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_guardian_spring_presentation_visual_qa requires Vulkan")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("guardian spring presentation capture directory creation failed")
		quit(1)
		return

	var catalog := TowerGuardianSpringPresentationAssetCatalog.new()
	var asset_bundle: Dictionary = catalog.prewarm_all()
	if not bool(asset_bundle.get("ready", false)):
		push_error("approved guardian spring presentation assets failed to prewarm")
		quit(1)
		return
	var card_renderer := RuntimePerkOverlayRenderer.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	card_renderer.prewarm_traditional_choice_assets()
	_prewarm_guardian_portraits(icon_renderer)

	var modal := TowerAscentNodeModalState.new()
	modal.open("spring-presentation-qa", "guardian_spring", {"gold": 2400, "muhon": 20}, _menu_actions())
	modal.configure_guardian_spring_presentation(true, Vector2(662.0, 690.0))
	_flow = CaptureFlow.new(modal, {
		"card_renderer": card_renderer,
		"icon_renderer": icon_renderer,
		"guardian_spring_presentation_assets": asset_bundle,
	})
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_viewport)
	_canvas = CaptureCanvas.new(_flow)
	_viewport.add_child(_canvas)

	var statue_before: Image = await _capture("statue_before.png")
	var statue_model: Dictionary = modal.build_view_model(Vector2(VIEW_SIZE))
	var statue_rect: Rect2 = statue_model.get("guardian_spring_presentation", {}).get("statue_rect", Rect2())
	modal.update_hover_at_position(statue_rect.get_center(), Vector2(VIEW_SIZE))
	var statue_hover: Image = await _capture("statue_hover.png")
	var glow_metrics := _measure_hover_glow(statue_before, statue_hover, statue_rect)
	var outside_glow_delta := int(glow_metrics.get("outside_delta_pixels", -1))
	var strong_inside_delta := int(glow_metrics.get("strong_inside_delta_pixels", 0))
	if outside_glow_delta != 0:
		push_error("hover glow brightened %d background pixels outside the statue silhouette" % outside_glow_delta)
		quit(1)
		return
	if strong_inside_delta < 5000:
		push_error("hover glow strong delta is too weak: %d pixels" % strong_inside_delta)
		quit(1)
		return

	modal.reveal_guardian_spring_menu()
	modal.set_status_text(str(TowerAscentNodeModalLocalization.TEXT_BY_LOCALE["ko"][TowerAscentNodeModalLocalization.KEY_SPRING_STATUE_DIALOGUE]))
	modal.begin_guardian_spring_palm_ritual(_menu_actions()[0])
	modal.advance_guardian_spring_presentation(1.0)
	await _capture("ritual_mid.png")

	modal.open("spring-capsule-qa", "guardian_spring", {"gold": 2400, "muhon": 20}, _capsule_actions())
	modal.configure_guardian_spring_presentation(true)
	modal.reveal_guardian_spring_menu()
	modal.set_status_text("수호령의 기운을 살펴봅니다")
	var capsule_rects: Array = modal.get_action_rects(Vector2(VIEW_SIZE))
	modal.update_hover_at_position((capsule_rects[1] as Rect2).get_center(), Vector2(VIEW_SIZE))
	var actual_capsule_texture: Texture2D = asset_bundle.get("textures", {}).get("capsule", null) as Texture2D
	var empty_capsule_image := Image.create_empty(1086, 1448, false, Image.FORMAT_RGBA8)
	empty_capsule_image.fill(Color.TRANSPARENT)
	var no_frame_bundle := asset_bundle.duplicate(true)
	var no_frame_textures: Dictionary = no_frame_bundle.get("textures", {})
	no_frame_textures["capsule"] = ImageTexture.create_from_image(empty_capsule_image)
	no_frame_bundle["textures"] = no_frame_textures
	_flow.render_context["guardian_spring_presentation_assets"] = no_frame_bundle
	var capsule_no_frame: Image = await _capture("capsules_no_frame_reference.png")
	_flow.render_context["guardian_spring_presentation_assets"] = asset_bundle
	var capsules_t0: Image = await _capture("capsules_t0.png")
	var contrast_metrics := _measure_capsule_exterior_contrast(
		capsule_no_frame,
		capsules_t0,
		capsule_rects
	)
	var strong_ratio := float(contrast_metrics.get("strong_ratio", 0.0))
	var mean_delta := float(contrast_metrics.get("mean_delta", 0.0))
	if actual_capsule_texture == null or strong_ratio < 0.35 or mean_delta < 12.0:
		push_error("capsule exterior contrast is weak: strong_ratio=%.4f mean_delta=%.2f" % [strong_ratio, mean_delta])
		quit(1)
		return
	modal.advance_guardian_spring_presentation(0.91)
	var capsules_t1: Image = await _capture("capsules_t1.png")
	var float_delta_pixels := _count_changed_pixels(capsules_t0, capsules_t1, 6)
	if float_delta_pixels < 1500:
		push_error("capsule float frames are not visibly distinct: %d pixels" % float_delta_pixels)
		quit(1)
		return

	print("[GuardianSpringPresentationVisualQA] %s" % output_dir)
	print("tower_guardian_spring_presentation_visual_qa: GLOW_OUTSIDE_SILHOUETTE_PIXELS=%d STRONG_INSIDE_DELTA_PIXELS=%d" % [outside_glow_delta, strong_inside_delta])
	print("tower_guardian_spring_presentation_visual_qa: CAPSULE_EXTERIOR_STRONG_RATIO=%.4f MEAN_DELTA=%.2f" % [strong_ratio, mean_delta])
	print("tower_guardian_spring_presentation_visual_qa: CAPSULE_FLOAT_DELTA_PIXELS=%d" % float_delta_pixels)
	print("tower_guardian_spring_presentation_visual_qa: captures=statue_before.png,statue_hover.png,ritual_mid.png,capsules_t0.png,capsules_t1.png")
	print("tower_guardian_spring_presentation_visual_qa: ok")
	quit(0)


func _capture(file_name: String) -> Image:
	_canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("guardian spring presentation frame capture failed: %s" % file_name)
		quit(1)
		return Image.new()
	var output_path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	if image.save_png(output_path) != OK:
		push_error("guardian spring presentation PNG save failed: %s" % output_path)
		quit(1)
		return Image.new()
	return image


func _measure_hover_glow(before: Image, after: Image, statue_rect: Rect2) -> Dictionary:
	var statue := Image.load_from_file(ProjectSettings.globalize_path(STATUE_SOURCE_PATH))
	statue.convert(Image.FORMAT_RGBA8)
	before.convert(Image.FORMAT_RGBA8)
	after.convert(Image.FORMAT_RGBA8)
	var outside_delta_pixels := 0
	var strong_inside_delta_pixels := 0
	for y in range(VIEW_SIZE.y):
		for x in range(VIEW_SIZE.x):
			var delta := _pixel_delta_255(before.get_pixel(x, y), after.get_pixel(x, y))
			if delta <= 2:
				continue
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside_silhouette := false
			if statue_rect.has_point(point):
				var uv := (point - statue_rect.position) / statue_rect.size
				# The production draw downsamples 1024x1536 to 324x486 with linear
				# filtering. Classify the rendered silhouette with the same bilinear
				# alpha footprint so anti-aliased stone-edge pixels are not mislabeled
				# as background; zero-alpha background remains a strict RED.
				inside_silhouette = _sample_bilinear_alpha(statue, uv) > (1.0 / 1024.0)
			if not inside_silhouette:
				outside_delta_pixels += 1
			elif delta >= 40:
				strong_inside_delta_pixels += 1
	return {
		"outside_delta_pixels": outside_delta_pixels,
		"strong_inside_delta_pixels": strong_inside_delta_pixels,
	}


func _measure_capsule_exterior_contrast(
	without_frame: Image,
	with_frame: Image,
	capsule_rects: Array
) -> Dictionary:
	var capsule := Image.load_from_file(ProjectSettings.globalize_path(CAPSULE_SOURCE_PATH))
	capsule.convert(Image.FORMAT_RGBA8)
	without_frame.convert(Image.FORMAT_RGBA8)
	with_frame.convert(Image.FORMAT_RGBA8)
	var sampled_pixels := 0
	var strong_pixels := 0
	var delta_sum := 0.0
	for action_index in range(mini(3, capsule_rects.size())):
		var rect: Rect2 = capsule_rects[action_index]
		var left := maxi(0, int(floor(rect.position.x)))
		var top := maxi(0, int(floor(rect.position.y)))
		var right := mini(VIEW_SIZE.x, int(ceil(rect.end.x)))
		var bottom := mini(VIEW_SIZE.y, int(ceil(rect.end.y)))
		for y in range(top, bottom):
			for x in range(left, right):
				var uv := (Vector2(float(x) + 0.5, float(y) + 0.5) - rect.position) / rect.size
				if not (uv.x < 0.28 or uv.x > 0.72 or uv.y < 0.20 or uv.y > 0.82):
					continue
				var sx := clampi(int(floor(uv.x * float(capsule.get_width()))), 0, capsule.get_width() - 1)
				var sy := clampi(int(floor(uv.y * float(capsule.get_height()))), 0, capsule.get_height() - 1)
				if capsule.get_pixel(sx, sy).a < 0.08:
					continue
				var delta := _pixel_delta_255(without_frame.get_pixel(x, y), with_frame.get_pixel(x, y))
				sampled_pixels += 1
				delta_sum += float(delta)
				if delta >= 18:
					strong_pixels += 1
	return {
		"sampled_pixels": sampled_pixels,
		"strong_ratio": float(strong_pixels) / float(maxi(1, sampled_pixels)),
		"mean_delta": delta_sum / float(maxi(1, sampled_pixels)),
	}


func _count_changed_pixels(first: Image, second: Image, threshold: int) -> int:
	first.convert(Image.FORMAT_RGBA8)
	second.convert(Image.FORMAT_RGBA8)
	var result := 0
	for y in range(mini(first.get_height(), second.get_height())):
		for x in range(mini(first.get_width(), second.get_width())):
			if _pixel_delta_255(first.get_pixel(x, y), second.get_pixel(x, y)) >= threshold:
				result += 1
	return result


func _pixel_delta_255(first: Color, second: Color) -> int:
	return int(round(maxf(
		absf(first.r - second.r),
		maxf(absf(first.g - second.g), absf(first.b - second.b))
	) * 255.0))


func _sample_bilinear_alpha(image: Image, uv: Vector2) -> float:
	var sample_x := clampf(
		uv.x * float(image.get_width()) - 0.5,
		0.0,
		float(image.get_width() - 1)
	)
	var sample_y := clampf(
		uv.y * float(image.get_height()) - 0.5,
		0.0,
		float(image.get_height() - 1)
	)
	var x0 := int(floor(sample_x))
	var y0 := int(floor(sample_y))
	var x1 := mini(image.get_width() - 1, x0 + 1)
	var y1 := mini(image.get_height() - 1, y0 + 1)
	var tx := sample_x - float(x0)
	var ty := sample_y - float(y0)
	var top := lerpf(image.get_pixel(x0, y0).a, image.get_pixel(x1, y0).a, tx)
	var bottom := lerpf(image.get_pixel(x0, y1).a, image.get_pixel(x1, y1).a, tx)
	return lerpf(top, bottom, ty)


func _prewarm_guardian_portraits(icon_renderer: Object) -> void:
	var jobs_value: Variant = icon_renderer.call("_build_prewarm_asset_jobs")
	if not (jobs_value is Array):
		return
	for job_value in jobs_value as Array:
		if (
			job_value is Dictionary
			and str((job_value as Dictionary).get("type", "")) == "guardian_portrait"
		):
			icon_renderer.call("_run_prewarm_asset_job", job_value)


func _menu_actions() -> Array[Dictionary]:
	return [
		{
			"id": "guardian_spring:palm",
			"label": "손바닥을 대본다",
			"enabled": true,
			"payload": {"operation": "palm", "cost": 0},
		},
		{
			"id": "guardian_spring:prayer",
			"label": "기도한다",
			"enabled": true,
			"payload": {"operation": "prayer", "cost": 0},
		},
		{"id": "end_work", "label": "업무 종료", "enabled": true, "payload": {}},
	]


func _capsule_actions() -> Array[Dictionary]:
	return [
		_guardian_action("maribo", "마리보", "first_pick", "첫 수호령을 맞이합니다.", "무료", true),
		_guardian_action("koyora", "코요라", "browse_candidate", "물결탄 Lv.2\n회복의 숨결 Lv.2\n방어 보조", "800 금화", false),
		_guardian_action("lunabi", "루나비", "browse_candidate", "달빛탄 Lv.3\n월광의 기운 Lv.3\n공격 보조", "900 금화", false),
		{"id": "end_work", "label": "업무 종료", "enabled": true, "payload": {}},
	]


func _guardian_action(
	pet_id: String,
	display_name: String,
	operation: String,
	description: String,
	cost_text: String,
	blind_preview: bool
) -> Dictionary:
	return {
		"id": "guardian_spring:%s:%s" % [operation, pet_id],
		"label": display_name,
		"cost_text": cost_text,
		"enabled": true,
		"payload": {
			"operation": operation,
			"pet_id": pet_id,
			"choice": {
				"name": display_name,
				"description": description,
				"guardian_blind_preview": blind_preview,
			},
		},
	}
