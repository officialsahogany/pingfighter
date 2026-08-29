extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const VIEW_SIZE := Vector2i(1456, 1086)
const OUTPUT_DIR := "res://.godot/codex_captures/tower_shop_screen_redesign"
const OUTPUT_NAME_BEFORE := "tower_shop_lucky_pouch_before_1456x1086.png"
const OUTPUT_NAME_AFTER := "tower_shop_lucky_pouch_after_1456x1086.png"
const SHOP_BACKGROUND_PATH := (
	"res://assets/sprites/tower/noncombat/shop_arena_background_imagegen_v1.png"
)
const PRODUCT_ITEM_NAMES := [
	"gauge_charge",
	"life_elixir",
	"mystic_dice",
	"wall",
	"boomerang",
	"elixir_of_mastery",
]


class CaptureFlow:
	extends RefCounted
	var model: Dictionary = {}
	var background: Texture2D
	var context: Dictionary = {}

	func get_node_modal_view_model(_view_size: Vector2) -> Dictionary:
		return model.duplicate(true)

	func get_node_modal_kind() -> String:
		return "shop"

	func get_node_modal_render_context() -> Dictionary:
		return context

	func get_retained_noncombat_node_background_resolution() -> Dictionary:
		return {
			"kind": "shop",
			"source": "bitmap",
			"texture": background,
			"ready": background != null,
			"fallback_to_stage_background": background == null,
		}


class CaptureCanvas:
	extends Node2D
	var flow: Object
	var renderer: Object

	func _draw() -> void:
		renderer.draw_fullscreen_node_modal(
			self,
			flow,
			Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
		)


class CaptureActiveItemVisuals:
	extends RefCounted
	var texture_by_path: Dictionary = {}

	func prewarm(items: Array[Dictionary]) -> bool:
		for item_data in items:
			var path := str(item_data.get("icon_path", ""))
			if path.is_empty() or texture_by_path.has(path):
				continue
			var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
			if texture == null:
				return false
			texture_by_path[path] = texture
		return true

	func get_icon_texture(item_data: Dictionary) -> Texture2D:
		return texture_by_path.get(str(item_data.get("icon_path", "")), null) as Texture2D

	func get_item_color(item_data: Dictionary) -> Color:
		var color_value: Variant = item_data.get("color", Color(0.78, 0.78, 0.78))
		return color_value as Color if color_value is Color else Color(0.78, 0.78, 0.78)


var _failed := false


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
	var background := ResourceLoader.load(SHOP_BACKGROUND_PATH, "Texture2D") as Texture2D
	if background == null:
		_fail("approved shop-arena background did not load")
		return

	var modal := TowerAscentNodeModalState.new()
	modal.open(
		"tower-shop-visual-qa",
		"shop",
		{"gold": 830, "muhon": 42},
		_build_actions(false)
	)
	modal.set_shop_owned_items(_build_owned_slots(false))
	var model: Dictionary = modal.build_view_model(Vector2(VIEW_SIZE))
	if not _verify_model(model, false):
		_fail("stacked shop structure contract failed")
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var renderer := TowerAscentFlowRenderer.new()
	var flow := CaptureFlow.new()
	flow.model = model
	flow.background = background
	var active_item_visuals := CaptureActiveItemVisuals.new()
	if not active_item_visuals.prewarm(_visual_item_data()):
		_fail("production active-item icon texture did not load")
		return
	flow.context = {
		"card_renderer": RuntimePerkOverlayRenderer.new(),
		"active_item_hud_visuals": active_item_visuals,
	}
	var canvas := CaptureCanvas.new()
	canvas.flow = flow
	canvas.renderer = renderer
	viewport.add_child(canvas)
	var before_path := output_dir.path_join(OUTPUT_NAME_BEFORE)
	if not await _capture_frame(viewport, canvas, before_path):
		_fail("pre-purchase Vulkan capture save failed")
		return
	var debug: Dictionary = renderer.get_tower_shop_draw_debug_state_for_tests()
	if not _verify_draw_debug(debug):
		_fail("captured draw path lost product, slot, currency, or draw-budget contract")
		return

	var purchased_modal := TowerAscentNodeModalState.new()
	purchased_modal.open(
		"tower-shop-visual-qa",
		"shop",
		{"gold": 630, "muhon": 42},
		_build_actions(true)
	)
	purchased_modal.set_shop_owned_items(_build_owned_slots(true))
	var purchased_model := purchased_modal.build_view_model(Vector2(VIEW_SIZE))
	if not _verify_model(purchased_model, true):
		_fail("post-purchase stacked shop structure contract failed")
		return
	flow.model = purchased_model
	var after_path := output_dir.path_join(OUTPUT_NAME_AFTER)
	if not await _capture_frame(viewport, canvas, after_path):
		_fail("post-purchase Vulkan capture save failed")
		return
	debug = renderer.get_tower_shop_draw_debug_state_for_tests()
	if not _verify_draw_debug(debug):
		_fail("post-purchase draw path lost product, slot, currency, or draw-budget contract")
		return
	print("tower_shop_screen_redesign_visual_qa: evidence_before=%s" % before_path)
	print("tower_shop_screen_redesign_visual_qa: evidence_after=%s" % after_path)
	print("tower_shop_screen_redesign_visual_qa: before_question_mark=ok")
	print("tower_shop_screen_redesign_visual_qa: after_item_reveal=ok")
	print("tower_shop_screen_redesign_visual_qa: structure=8+5+exit")
	print("tower_shop_screen_redesign_visual_qa: currencies=gold+muhon")
	print("tower_shop_screen_redesign_visual_qa: vulkan=ok")
	print("tower_shop_screen_redesign_visual_qa: ok")
	quit(0)


func _build_actions(purchased: bool) -> Array[Dictionary]:
	var catalog := ActiveItemCatalog.new()
	var actions: Array[Dictionary] = []
	for index in range(PRODUCT_ITEM_NAMES.size()):
		var item_data: Dictionary = catalog.build_item_by_name(PRODUCT_ITEM_NAMES[index])
		var price := TowerAscentTuning.get_shop_active_item_gold_price(
			str(item_data.get("name", ""))
		)
		actions.append({
			"id": "shop_purchase:visual-%d" % index,
			"label": str(item_data.get("display_name", item_data.get("name", ""))),
			"cost_gold": price,
			"cost_text": "%d 금화" % price,
			"enabled": true,
			"payload": {"choice": _active_item_choice(item_data)},
		})
	actions.append({
		"id": "shop_purchase:visual-capsule",
		"label": "복주머니",
		"cost_gold": 200,
		"cost_text": "매진" if purchased else "200 금화",
		"enabled": not purchased,
		"unavailable_reason": "매진" if purchased else "",
		"payload": {"choice": {
			"id": "capsule",
			"name": "복주머니",
			"description": "복주머니를 열어 무작위 액티브 아이템 하나를 획득합니다.",
			"level_text": "행운 물자",
			"rarity": "unknown",
			"card_content_kind": "capsule",
			"icon_color": Color(0.88, 0.55, 0.22),
			"item_data": {},
		}},
	})
	actions.append({
		"id": "shop_purchase:visual-gem",
		"label": "기회의 보석",
		"cost_gold": 150,
		"cost_text": "150 금화",
		"enabled": true,
		"payload": {"choice": {
			"id": "chance_gem",
			"name": "기회의 보석",
			"description": "패배 뒤 도전을 이어갈 때 쓰는 보석입니다.",
			"level_text": "탑 물자",
			"card_content_kind": "chance_gem",
			"icon_color": Color(0.35, 0.72, 1.0),
		}},
	})
	return actions


func _visual_item_data() -> Array[Dictionary]:
	var catalog := ActiveItemCatalog.new()
	var result: Array[Dictionary] = []
	for item_name in PRODUCT_ITEM_NAMES:
		result.append(catalog.build_item_by_name(str(item_name)))
	return result


func _build_owned_slots(purchased: bool) -> Array[Dictionary]:
	var catalog := ActiveItemCatalog.new()
	var result: Array[Dictionary] = []
	for slot_index in range(5):
		if slot_index < 3 or (purchased and slot_index == 3):
			result.append(_active_item_choice(
				catalog.build_item_by_name(PRODUCT_ITEM_NAMES[slot_index])
			))
		else:
			result.append({"empty_slot": true, "slot_index": slot_index})
	return result


func _active_item_choice(item_data: Dictionary) -> Dictionary:
	return {
		"id": str(item_data.get("name", "")),
		"name": str(item_data.get("display_name", item_data.get("name", ""))),
		"description": str(item_data.get("description", "")),
		"level_text": str(item_data.get("rarity", "common")),
		"rarity": str(item_data.get("rarity", "common")),
		"card_content_kind": "active_item",
		"item_data": item_data,
	}


func _verify_model(model: Dictionary, purchased: bool) -> bool:
	var actions: Array = model.get("actions", [])
	var action_rects: Array = model.get("action_rects", [])
	var product_rects: Array = model.get("shop_stock_card_rects", [])
	var owned_rects: Array = model.get("shop_owned_slot_rects", [])
	if actions.size() != 9 or action_rects.size() != 9:
		return false
	if product_rects.size() != 8 or owned_rects.size() != 5:
		return false
	if str((actions[8] as Dictionary).get("label", "")) != "상점 나가기":
		return false
	var pouch_action: Dictionary = actions[6]
	var pouch_choice: Dictionary = pouch_action.get("payload", {}).get("choice", {})
	if (
		str(pouch_action.get("label", "")) != "복주머니"
		or int(pouch_action.get("cost_gold", -1)) != 200
		or bool(pouch_action.get("enabled", false)) == purchased
		or str(pouch_choice.get("card_content_kind", "")) != "capsule"
		or not (pouch_choice.get("item_data", {}) as Dictionary).is_empty()
	):
		return false
	var owned_panel: Rect2 = model.get("shop_owned_panel_rect", Rect2())
	for rect_value in owned_rects:
		if not (rect_value is Rect2) or not owned_panel.encloses(rect_value as Rect2):
			return false
	var revealed_slot: Dictionary = (model.get("shop_owned_items", []) as Array)[3]
	if purchased:
		if str(revealed_slot.get("item_data", {}).get("name", "")) != PRODUCT_ITEM_NAMES[3]:
			return false
	elif not bool(revealed_slot.get("empty_slot", false)):
		return false
	return true


func _verify_draw_debug(debug: Dictionary) -> bool:
	return (
		int(debug.get("product_count", -1)) == 8
		and int(debug.get("owned_slot_count", -1)) == 5
		and int(debug.get("currency_entry_count", -1)) == 2
		and bool(debug.get("within_ceiling", false))
	)


func _capture_frame(
	viewport: SubViewport,
	canvas: CanvasItem,
	output_path: String
) -> bool:
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := viewport.get_texture().get_image()
	return (
		image != null
		and not image.is_empty()
		and image.save_png(output_path) == OK
	)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
