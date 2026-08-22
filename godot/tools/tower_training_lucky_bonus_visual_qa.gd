extends SceneTree

const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_training_lucky_bonus_s4"
const CLOCK_MSEC := 4000
const LONGEST_DESCRIPTION := "수련 효과와 실제 적용값을 확인하는 가장 긴 설명 문구를 세 행 예산으로 정확하게 검증합니다 반복 문장"
const BONUS_BADGE := "행운 20% · 효과 +50%"


class CaptureFlow:
	extends RefCounted
	var modal_state: Object
	var card_renderer: Object
	var icon_renderer: Object

	func _init(state_value: Object, card_value: Object, icon_value: Object) -> void:
		modal_state = state_value
		card_renderer = card_value
		icon_renderer = icon_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "training"

	func get_node_modal_render_context() -> Dictionary:
		return {
			"card_renderer": card_renderer,
			"icon_renderer": icon_renderer,
		}


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


var _modal := TowerAscentNodeModalState.new()
var _card_renderer := RuntimePerkOverlayRenderer.new()
var _icon_renderer := RuntimePerkIconRenderer.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("requires Vulkan")
		return
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("capture directory creation failed")
		return
	var flow := CaptureFlow.new(_modal, _card_renderer, _icon_renderer)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new(flow)
	viewport.add_child(canvas)

	var lucky_image := await _capture_receipt(
		viewport,
		canvas,
		"행운 발동! 기본 4% -> 6% 적용"
	)
	if lucky_image == null:
		_fail("lucky frame capture failed")
		return
	var lucky_path := output_dir.path_join("training_lucky_triggered_2020x1246.png")
	if lucky_image.save_png(lucky_path) != OK:
		_fail("lucky frame save failed")
		return

	var normal_image := await _capture_receipt(viewport, canvas, "4% 적용")
	if normal_image == null:
		_fail("normal frame capture failed")
		return
	var normal_path := output_dir.path_join("training_lucky_not_triggered_2020x1246.png")
	if normal_image.save_png(normal_path) != OK:
		_fail("normal frame save failed")
		return

	var comparison := Image.create(VIEW_SIZE.x, VIEW_SIZE.y / 2, false, Image.FORMAT_RGBA8)
	comparison.fill(Color(0.02, 0.02, 0.025, 1.0))
	var lucky_half := lucky_image.duplicate()
	lucky_half.resize(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2, Image.INTERPOLATE_LANCZOS)
	lucky_half.convert(Image.FORMAT_RGBA8)
	var normal_half := normal_image.duplicate()
	normal_half.resize(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2, Image.INTERPOLATE_LANCZOS)
	normal_half.convert(Image.FORMAT_RGBA8)
	comparison.blit_rect(lucky_half, Rect2i(Vector2i.ZERO, lucky_half.get_size()), Vector2i.ZERO)
	comparison.blit_rect(normal_half, Rect2i(Vector2i.ZERO, normal_half.get_size()), Vector2i(VIEW_SIZE.x / 2, 0))
	var comparison_path := output_dir.path_join("training_lucky_bonus_comparison_2020x623.png")
	if comparison.save_png(comparison_path) != OK:
		_fail("comparison save failed")
		return

	var model: Dictionary = _modal.build_view_model(Vector2(VIEW_SIZE))
	var first_rect := (model.get("action_rects", []) as Array)[0] as Rect2
	var text_layout := _card_renderer.build_tower_node_card_text_layout(
		(model.get("actions", []) as Array)[0],
		first_rect
	)
	if int(text_layout.get("appended_text_row_count", -1)) != 4:
		_fail("production badge boundary did not append exactly four rows")
		return
	var crop_rect := Rect2i(first_rect.grow(8.0)).intersection(
		Rect2i(Vector2i.ZERO, lucky_image.get_size())
	)
	var badge_crop := lucky_image.get_region(crop_rect)
	var badge_path := output_dir.path_join("training_lucky_badge_four_row_boundary.png")
	if badge_crop.save_png(badge_path) != OK:
		_fail("badge boundary crop save failed")
		return

	print("[TowerTrainingLuckyBonusVisualQA] %s" % lucky_path)
	print("[TowerTrainingLuckyBonusVisualQA] %s" % normal_path)
	print("[TowerTrainingLuckyBonusVisualQA] %s" % comparison_path)
	print("[TowerTrainingLuckyBonusVisualQA] %s" % badge_path)
	print("tower_training_lucky_bonus_visual_qa: captures=2")
	print("tower_training_lucky_bonus_visual_qa: badge_rows=4")
	print("tower_training_lucky_bonus_visual_qa: comparison=ok")
	print("tower_training_lucky_bonus_visual_qa: ok")
	quit(0)


func _capture_receipt(
	viewport: SubViewport,
	canvas: CanvasItem,
	message: String
) -> Image:
	var actions := _actions()
	_modal.open("s4-lucky-visual", "training", {"gold": 0, "muhon": 8}, actions)
	_modal.set_clock_msec_for_tests(CLOCK_MSEC)
	_modal.record_action_feedback(actions[0], {
		"accepted": true,
		"applied": true,
		"message": message,
		"costs": {"muhon": 1},
		"balances_before": {"muhon": 9},
		"balances": {"muhon": 8},
	})
	# Production _execute_training_action also publishes the same receipt to the
	# modal status row, where the full Korean value copy remains legible.
	_modal.set_status_text(message)
	_modal.set_clock_msec_for_tests(CLOCK_MSEC + 250)
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	return image if image != null and not image.is_empty() else null


func _actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names := ["유운보", "철산공", "비천보", "태허심법", "격기심법", "수납술"]
	for index in range(names.size()):
		result.append({
			"id": "training_visual_%d" % index,
			"label": names[index],
			"cost_text": "1 무혼",
			"enabled": true,
			"payload": {
				"choice": {
					"id": "training_visual_%d" % index,
					"name": names[index],
					"description": LONGEST_DESCRIPTION,
					"bonus_badge_text": BONUS_BADGE if index < 5 else "고정 +1칸",
					"level_text": "Lv.2" if index < 5 else "2/3",
					"icon_color": Color(0.72, 0.40 + float(index) * 0.03, 0.18),
				},
				"presentation": {
					"current": "8%" if index < 5 else "2/3",
					"result": "12%" if index < 5 else "3/3",
					"target": names[index],
				},
			},
		})
	return result


func _fail(message: String) -> void:
	push_error("tower_training_lucky_bonus_visual_qa: %s" % message)
	quit(1)
