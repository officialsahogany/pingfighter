extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const Stage1PillarHudSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
)
const Stage1PillarUiRenderer := preload(
	"res://scripts/hud/stage1_pillar_ui_renderer.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const GAME_SOURCE_SIZE := Vector2(760.0, 750.0)
const PIXEL_DIFF_THRESHOLD := 0.06

var _failures: Array[String] = []


class CachedOnlyRegistry:
	extends RefCounted

	var flow_owner: Object
	var pillar_renderer: Object = Stage1PillarUiRenderer.new()
	var cold_get_calls := 0

	func _init(value: Object) -> void:
		flow_owner = value

	func get_cached_instance(key: String) -> Object:
		match key:
			"tower_ascent_flow_owner":
				return flow_owner
			"stage1_pillar_ui_renderer":
				return pillar_renderer
		return null

	func get_instance(_key: String) -> Object:
		cold_get_calls += 1
		return null


class ShopModalFlow:
	extends RefCounted

	var modal_state: Object = TowerAscentNodeModalState.new()

	func _init(economy: Dictionary) -> void:
		modal_state.open("shop", "shop", economy, [])

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "shop"


class CaptureCanvas:
	extends Node2D

	var registry: Object
	var scene_drawer: Object = Stage1PillarHudSceneDrawer.new()
	var flow_renderer: Object = TowerAscentFlowRenderer.new()
	var modal_flow: Object
	var game_offset := Vector2.ZERO
	var game_size := Vector2.ZERO
	var show_shop := false

	func _draw() -> void:
		if show_shop:
			flow_renderer.draw_fullscreen_node_modal(
				self,
				modal_flow,
				Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
			)
		else:
			_draw_battle_backdrop()
		scene_drawer.call(
			"_draw_gold_hud",
			self,
			{
				"height": 750.0,
				"current_stage": 1,
				"runtime_perk_gold": 9999,
			},
			registry,
			game_offset,
			game_size
		)

	func _draw_battle_backdrop() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("111724"), true)
		draw_rect(Rect2(game_offset, game_size), Color("24191d"), true)
		for row in range(12):
			var y := game_offset.y + 42.0 + float(row) * 72.0
			draw_line(
				Vector2(game_offset.x, y),
				Vector2(game_offset.x + game_size.x, y + 18.0),
				Color(0.58, 0.22, 0.18, 0.12),
				2.0
			)
		draw_circle(
			game_offset + game_size * Vector2(0.5, 0.28),
			game_size.y * 0.12,
			Color(0.95, 0.60, 0.24, 0.16)
		)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("tower battle gold live-sync visual QA requires a real window")
		_finish(0, 0, 0, 0)
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("tower battle gold live-sync visual QA requires Vulkan")
		_finish(0, 0, 0, 0)
		return
	var output_dir := ProjectSettings.globalize_path(
		"res://.godot/codex_artifacts/tower_battle_gold_hud_live_sync"
	)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output_dir = argument.substr("--output-dir=".length())
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("failed to create visual QA output directory: %s" % output_dir)
		_finish(0, 0, 0, 0)
		return

	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow: Object = TowerAscentFlowOwner.new()
	_expect(bool(flow.ensure_run_started(null, {
		"run_id": "tower-gold-vulkan-live-sync",
		"run_state": {"gold": 0, "muhon": 17, "chance_gems": 3},
	})), "visual QA should start the production Tower run")
	var registry := CachedOnlyRegistry.new(flow)
	var scale_factor := float(VIEW_SIZE.y) / GAME_SOURCE_SIZE.y
	var game_size := GAME_SOURCE_SIZE * scale_factor
	var game_offset := (Vector2(VIEW_SIZE) - game_size) * 0.5
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new()
	canvas.registry = registry
	canvas.game_offset = game_offset
	canvas.game_size = game_size
	canvas.modal_flow = ShopModalFlow.new(flow.get_run_state_snapshot())
	viewport.add_child(canvas)

	var before_economy: Dictionary = flow.get_run_state_snapshot()
	var before_gold := int(before_economy.get("gold", -1))
	var before_image: Image = await _capture(
		viewport,
		canvas,
		output_dir.path_join("battle_gold_before_2020x1246.png")
	)
	var perk_state: Object = RuntimePerkState.new()
	perk_state.award_gold(120, {}, {"registry": registry})
	var after_economy: Dictionary = flow.get_run_state_snapshot()
	var after_gold := int(after_economy.get("gold", -1))
	var after_image: Image = await _capture(
		viewport,
		canvas,
		output_dir.path_join("battle_gold_after_2020x1246.png")
	)
	canvas.show_shop = true
	canvas.modal_flow = ShopModalFlow.new(after_economy)
	var shop_image: Image = await _capture(
		viewport,
		canvas,
		output_dir.path_join("shop_gold_after_2020x1246.png")
	)
	var shop_model: Dictionary = canvas.modal_flow.get_node_modal_view_model(Vector2(VIEW_SIZE))
	var shop_gold := int(shop_model.get("balances", {}).get("gold", -1))
	var muhon := int(after_economy.get("muhon", -1))
	_expect(before_gold == 0, "before capture should render zero run gold")
	_expect(after_gold == 120, "after capture should render the live awarded run gold")
	_expect(shop_gold == after_gold, "shop capture and after-battle pillar should share run gold")
	_expect(str(shop_model.get("gold_text", "")).contains("120"), "shop capture model should render gold 120")
	_expect(perk_state.gold_from_perks == 0, "visual production award must not retain plaza-bound runtime gold")
	_expect(muhon == 17, "visual production award must preserve Muhon")
	_expect(registry.cold_get_calls == 0, "visual pillar draw must stay cached-only")
	if not before_image.is_empty() and not after_image.is_empty():
		var layout: Dictionary = registry.pillar_renderer.build_currency_hud_layout(
			game_offset,
			game_size,
			{
				"height": 750.0,
				"gold_hud_amount": after_gold,
				"tower_muhon_hud_visible": true,
				"tower_muhon_hud_amount": muhon,
			}
		)
		var gold_changed := _count_changed_pixels(
			before_image,
			after_image,
			layout.get("gold_rect", Rect2())
		)
		var muhon_changed := _count_changed_pixels(
			before_image,
			after_image,
			layout.get("muhon_rect", Rect2())
		)
		_expect(gold_changed >= 20, "gold award should visibly change the pillar gold digits")
		_expect(muhon_changed <= 4, "gold award should not change the Muhon pixels")
	_expect(not shop_image.is_empty(), "shop capture image should be materialized")

	get_root().remove_child(viewport)
	viewport.queue_free()
	await process_frame
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_finish(before_gold, after_gold, shop_gold, muhon)


func _capture(viewport: SubViewport, canvas: Node2D, output_path: String) -> Image:
	canvas.queue_redraw()
	for _frame_index in range(5):
		await process_frame
	RenderingServer.force_draw(false)
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output_path) != OK:
		_fail("failed to save Vulkan capture: %s" % output_path)
		return Image.new()
	print("[TowerBattleGoldLiveSyncVisualQA] %s" % output_path)
	return image


func _count_changed_pixels(first: Image, second: Image, rect: Rect2) -> int:
	var count := 0
	var x0 := clampi(int(floor(rect.position.x)), 0, VIEW_SIZE.x - 1)
	var x1 := clampi(int(ceil(rect.end.x)), 0, VIEW_SIZE.x)
	var y0 := clampi(int(floor(rect.position.y)), 0, VIEW_SIZE.y - 1)
	var y1 := clampi(int(ceil(rect.end.y)), 0, VIEW_SIZE.y)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) >= PIXEL_DIFF_THRESHOLD:
				count += 1
	return count


func _finish(before_gold: int, after_gold: int, shop_gold: int, muhon: int) -> void:
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("tower_battle_gold_hud_live_sync_visual_qa: captures=3")
	print("tower_battle_gold_hud_live_sync_visual_qa: gold_before=%d gold_after=%d shop_gold=%d muhon=%d" % [
		before_gold,
		after_gold,
		shop_gold,
		muhon,
	])
	print("tower_battle_gold_hud_live_sync_visual_qa: ok")
	quit(0)


func _fail(message: String) -> void:
	_failures.append(message)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)
