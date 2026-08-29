extends SceneTree

const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
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
const CharacterInfoOverlayCore := preload(
	"res://scripts/hud/character_info_overlay_core.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_shop_split_feedback7"
const FRAME_NAMES := [
	"idle",
	"hover_000",
	"hover_060",
	"hover_120",
	"press",
	"success_000",
	"success_210",
	"success_419",
	"reject_000",
	"reject_040",
	"reject_159",
	"shop_idle",
	"shop_hover",
	"fallen_monk_hover",
]


class QaRunState:
	extends RefCounted
	var balances := {"gold": 30, "muhon": 8, "chance_gems": 0}

	func can_afford(_costs: Dictionary) -> Dictionary:
		return {"accepted": true, "balances": balances.duplicate(true)}

	func apply_economy_transaction(costs: Dictionary, rewards: Dictionary) -> Dictionary:
		for currency_value in costs.keys():
			var currency := str(currency_value)
			balances[currency] = int(balances.get(currency, 0)) - int(costs.get(currency, 0))
		for currency_value in rewards.keys():
			var currency := str(currency_value)
			balances[currency] = int(balances.get(currency, 0)) + int(rewards.get(currency, 0))
		return {
			"accepted": true,
			"costs": costs.duplicate(true),
			"rewards": rewards.duplicate(true),
			"balances": balances.duplicate(true),
		}


class CaptureFlow:
	extends RefCounted
	var modal_state: Object
	var card_renderer: Object
	var icon_renderer: Object
	var tooltip_overlay: Object

	func _init(
		state_value: Object,
		card_value: Object,
		icon_value: Object,
		tooltip_value: Object
	) -> void:
		modal_state = state_value
		card_renderer = card_value
		icon_renderer = icon_value
		tooltip_overlay = tooltip_value

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return str(modal_state.build_view_model().get("node_kind", "training"))

	func get_node_modal_render_context() -> Dictionary:
		var context := {"card_renderer": card_renderer, "icon_renderer": icon_renderer}
		if modal_state.has_shop_item_hover():
			context["shop_item_tooltip_overlay"] = tooltip_overlay
		return context


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


var _card_renderer := RuntimePerkOverlayRenderer.new()
var _icon_renderer := RuntimePerkIconRenderer.new()
var _tooltip_overlay := CharacterInfoOverlayCore.new()
var _modal := TowerAscentNodeModalState.new()
var _frames: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_node_modal_feedback_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_node_modal_feedback_visual_qa requires Vulkan")
		quit(1)
		return
	_card_renderer.prewarm_assets()
	_icon_renderer.prewarm_assets()
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("feedback capture directory creation failed")
		quit(1)
		return
	_modal.open("s3-visual", "training", {"gold": 30, "muhon": 8}, _actions("training", false))
	_modal.set_clock_msec_for_tests(1000)
	var flow := CaptureFlow.new(
		_modal,
		_card_renderer,
		_icon_renderer,
		_tooltip_overlay
	)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new(flow)
	viewport.add_child(canvas)
	if not await _capture_frame(viewport, canvas, output_dir, "idle"):
		return
	var top_corner := (_modal.get_action_rects(Vector2(VIEW_SIZE))[0] as Rect2).position + Vector2(2.0, 2.0)
	_modal.update_hover_at_position(top_corner, Vector2(VIEW_SIZE))
	for timed_frame in [["hover_000", 1000], ["hover_060", 1060], ["hover_120", 1120]]:
		_modal.set_clock_msec_for_tests(int(timed_frame[1]))
		if not await _capture_frame(viewport, canvas, output_dir, str(timed_frame[0])):
			return
	_modal.begin_pointer_press(top_corner, Vector2(VIEW_SIZE))
	if not await _capture_frame(viewport, canvas, output_dir, "press"):
		return
	var action := _modal.release_pointer_at_position(top_corner, Vector2(VIEW_SIZE))
	var run_state := QaRunState.new()
	var transaction_result := TowerAscentNodeActionTransaction.new().apply_once(
		"s3-visual-success",
		{"muhon": 2},
		{},
		run_state,
		{}
	)
	transaction_result["message"] = "철산공 수련 완료"
	_modal.set_balances(transaction_result.get("balances", {}))
	_modal.set_clock_msec_for_tests(2000)
	_modal.record_action_feedback(action, transaction_result)
	for timed_frame in [["success_000", 2000], ["success_210", 2210], ["success_419", 2419]]:
		_modal.set_clock_msec_for_tests(int(timed_frame[1]))
		if not await _capture_frame(viewport, canvas, output_dir, str(timed_frame[0])):
			return
	_modal.set_actions(_actions("training", true))
	_modal.set_clock_msec_for_tests(3000)
	_modal.record_action_feedback(_modal.get_selected_action(), {
		"accepted": false,
		"applied": false,
		"reason": "insufficient_muhon",
		"message": "무혼 2 필요, 2 부족",
	})
	for timed_frame in [["reject_000", 3000], ["reject_040", 3040], ["reject_159", 3159]]:
		_modal.set_clock_msec_for_tests(int(timed_frame[1]))
		if not await _capture_frame(viewport, canvas, output_dir, str(timed_frame[0])):
			return
	_modal.open("s3-shop-visual", "shop", {"gold": 120, "muhon": 6}, _actions("shop", false))
	_modal.set_shop_owned_items([
		_shop_owned_choice("단련의 부적", Color(0.56, 0.78, 0.92)),
		_shop_owned_choice("화염 구슬", Color(0.93, 0.42, 0.22)),
		_shop_owned_choice("수호 장식", Color(0.54, 0.84, 0.58)),
	])
	_modal.set_clock_msec_for_tests(4000)
	if not await _capture_frame(viewport, canvas, output_dir, "shop_idle"):
		return
	var shop_corner := (_modal.get_action_rects(Vector2(VIEW_SIZE))[0] as Rect2).position + Vector2(2.0, 2.0)
	_modal.update_hover_at_position(shop_corner, Vector2(VIEW_SIZE))
	_modal.set_clock_msec_for_tests(4120)
	if not await _capture_frame(viewport, canvas, output_dir, "shop_hover"):
		return
	_modal.open("s3-monk-visual", "fallen_monk", {"gold": 120, "muhon": 6}, _actions("fallen_monk", false))
	_modal.set_clock_msec_for_tests(5000)
	var monk_corner := (_modal.get_action_rects(Vector2(VIEW_SIZE))[0] as Rect2).position + Vector2(2.0, 2.0)
	_modal.update_hover_at_position(monk_corner, Vector2(VIEW_SIZE))
	_modal.set_clock_msec_for_tests(5120)
	if not await _capture_frame(viewport, canvas, output_dir, "fallen_monk_hover"):
		return
	if not _assert_visible_differences():
		quit(1)
		return
	if not _save_strip(output_dir, "hover_strip.png", ["hover_000", "hover_060", "hover_120"]):
		quit(1)
		return
	if not _save_strip(output_dir, "success_strip.png", ["success_000", "success_210", "success_419"]):
		quit(1)
		return
	if not _save_strip(output_dir, "reject_strip.png", ["reject_000", "reject_040", "reject_159"]):
		quit(1)
		return
	print("tower_node_modal_feedback_visual_qa: evidence=%s" % output_dir)
	print("tower_node_modal_feedback_visual_qa: captures=%d" % FRAME_NAMES.size())
	print("tower_node_modal_feedback_visual_qa: strips=3")
	print("tower_node_modal_feedback_visual_qa: ok")
	quit(0)


func _capture_frame(
	viewport: SubViewport,
	canvas: CanvasItem,
	output_dir: String,
	frame_name: String
) -> bool:
	canvas.queue_redraw()
	for _frame_index in range(3):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("empty feedback frame: %s" % frame_name)
		quit(1)
		return false
	var path := output_dir.path_join("%s.png" % frame_name)
	if image.save_png(path) != OK:
		push_error("failed to save feedback frame: %s" % path)
		quit(1)
		return false
	_frames[frame_name] = image.duplicate()
	print("[TowerNodeModalFeedbackVisualQA] %s" % path)
	return true


func _save_strip(output_dir: String, file_name: String, frame_names: Array) -> bool:
	var cell_size := Vector2i(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2)
	var strip := Image.create(cell_size.x * frame_names.size(), cell_size.y, false, Image.FORMAT_RGBA8)
	for index in range(frame_names.size()):
		var frame := (_frames.get(str(frame_names[index]), null) as Image).duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(
			frame,
			Rect2i(Vector2i.ZERO, cell_size),
			Vector2i(index * cell_size.x, 0)
		)
	var output_path := output_dir.path_join(file_name)
	if strip.save_png(output_path) != OK:
		push_error("failed to save motion strip: %s" % output_path)
		return false
	print("[TowerNodeModalFeedbackVisualQA] %s" % output_path)
	return true


func _assert_visible_differences() -> bool:
	for comparison in [
		["idle", "hover_120", "idle/hover"],
		["hover_120", "press", "hover/press"],
		["success_000", "success_210", "success motion"],
		["reject_000", "reject_040", "rejection shake"],
		["shop_idle", "shop_hover", "shop icon hover tooltip"],
	]:
		if _sampled_difference_count(
			_frames.get(str(comparison[0]), null),
			_frames.get(str(comparison[1]), null)
		) < 40:
			push_error("feedback visual difference too small: %s" % str(comparison[2]))
			return false
	return true


func _sampled_difference_count(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var changed := 0
	for y in range(0, first.get_height(), 6):
		for x in range(0, first.get_width(), 6):
			var first_color := first.get_pixel(x, y)
			var second_color := second.get_pixel(x, y)
			var difference := (
				absf(first_color.r - second_color.r)
				+ absf(first_color.g - second_color.g)
				+ absf(first_color.b - second_color.b)
				+ absf(first_color.a - second_color.a)
			)
			if difference > 0.035:
				changed += 1
	return changed


func _actions(node_kind: String, disabled_first: bool) -> Array:
	var result: Array[Dictionary] = []
	var card_count := 4 if node_kind == "training" else 6
	for index in range(card_count):
		var display_name: String = (
			["탕약", "폭화탄", "환광탄", "요술 회중시계", "액티브 캡슐", "기회의 보석"][index]
			if node_kind == "shop"
			else ["철산공", "유운보", "태허심법", "격기심법", "순환결", "비천보"][index]
		)
		if node_kind == "fallen_monk":
			display_name = ["청류식", "철벽식", "비연식", "태허결", "격기결", "순환결"][index]
		var current_text := "Lv.2"
		var result_text := "Lv.3"
		var cost_text := "2 무혼"
		var cost_gold := 0
		if node_kind == "shop":
			current_text = "진열 중"
			result_text = "획득"
			cost_gold = int([200, 250, 300, 350, 80, 150][index])
			cost_text = "%d 금화" % cost_gold
		elif node_kind == "fallen_monk":
			current_text = "Lv.0"
			result_text = "Lv.1"
		result.append({
			"id": "%s:visual_%d" % [node_kind, index],
			"label": display_name,
			"cost_text": cost_text,
			"cost_gold": cost_gold,
			"enabled": not disabled_first or index != 0,
			"disabled_reason": "insufficient_muhon" if disabled_first and index == 0 else "",
			"unavailable_reason": "무혼 2 필요, 2 부족" if disabled_first and index == 0 else "",
			"payload": {
				"choice": {
					"id": (
						["gauge_charge", "grenade", "flare", "stopwatch", "active_item_capsule", "chance_gem"][index]
						if node_kind == "shop"
						else "visual_%d" % index
					),
					"name": display_name,
					"price": cost_gold,
					"description": "몸을 단련해 전투 능력과 생존 능력을 함께 높입니다.",
					"current_level": 2,
					"next_level": 3,
					"level_text": "Lv.2 → Lv.3",
					"icon_color": Color(0.72, 0.39 + float(index) * 0.035, 0.18),
				},
				"presentation": {
					"current": current_text,
					"result": result_text,
					"target": display_name,
				},
			},
		})
	return result


func _shop_owned_choice(display_name: String, color: Color) -> Dictionary:
	return {
		"id": display_name,
		"name": display_name,
		"description": "현재 원정에서 보유한 아이템입니다. 이 목록에서는 판매할 수 없습니다.",
		"rarity": "rare",
		"level_text": "희귀 · 보유 중",
		"icon_color": color,
		"card_content_kind": "active_item",
		"item_data": {"name": display_name, "color": color},
		"owned_kind": "active",
	}
