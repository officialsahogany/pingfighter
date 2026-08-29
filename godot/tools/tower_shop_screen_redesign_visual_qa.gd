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
const OUTPUT_NAME := "tower_shop_screen_redesign_1456x1086.png"
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
		_build_actions()
	)
	modal.set_shop_owned_items(_build_owned_slots())
	var model: Dictionary = modal.build_view_model(Vector2(VIEW_SIZE))
	if not _verify_model(model):
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
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := viewport.get_texture().get_image()
	var output_path := output_dir.path_join(OUTPUT_NAME)
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		_fail("Vulkan capture save failed")
		return
	var debug: Dictionary = renderer.get_tower_shop_draw_debug_state_for_tests()
	if (
		int(debug.get("product_count", -1)) != 8
		or int(debug.get("owned_slot_count", -1)) != 5
		or int(debug.get("currency_entry_count", -1)) != 2
		or not bool(debug.get("within_ceiling", false))
	):
		_fail("captured draw path lost product, slot, currency, or draw-budget contract")
		return
	print("tower_shop_screen_redesign_visual_qa: evidence=%s" % output_path)
	print("tower_shop_screen_redesign_visual_qa: structure=8+5+exit")
	print("tower_shop_screen_redesign_visual_qa: currencies=gold+muhon")
	print("tower_shop_screen_redesign_visual_qa: vulkan=ok")
	print("tower_shop_screen_redesign_visual_qa: ok")
	quit(0)


func _build_actions() -> Array[Dictionary]:
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
		"label": "액티브 캡슐",
		"cost_gold": 80,
		"cost_text": "80 금화",
		"enabled": true,
		"payload": {"choice": {
			"id": "capsule",
			"name": "액티브 캡슐",
			"description": "봉인된 액티브 아이템 하나를 획득합니다.",
			"level_text": "액티브 물자",
			"card_content_kind": "capsule",
			"icon_color": Color(0.88, 0.55, 0.22),
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


func _build_owned_slots() -> Array[Dictionary]:
	var catalog := ActiveItemCatalog.new()
	var result: Array[Dictionary] = []
	for slot_index in range(5):
		if slot_index < 3:
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


func _verify_model(model: Dictionary) -> bool:
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
	var owned_panel: Rect2 = model.get("shop_owned_panel_rect", Rect2())
	for rect_value in owned_rects:
		if not (rect_value is Rect2) or not owned_panel.encloses(rect_value as Rect2):
			return false
	return true


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
