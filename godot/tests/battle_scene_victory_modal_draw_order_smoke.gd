extends SceneTree

const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const VIEW_SIZE := Vector2(1280.0, 720.0)

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeVictoryLootState:
	extends RefCounted

	var external_modal_active := false
	var external_modal_checks := 0
	var draw_calls := 0
	var order: Array[String] = []
	var last_canvas: CanvasItem = null
	var last_view_size := Vector2.ZERO

	func is_reward_pick_external_modal_active() -> bool:
		external_modal_checks += 1
		return external_modal_active

	func is_reward_pick_active() -> bool:
		return true

	func draw_reward_pick(canvas: CanvasItem, view_size: Vector2) -> void:
		draw_calls += 1
		order.append("reward_pick")
		last_canvas = canvas
		last_view_size = view_size


class FakeRuntimePerkOverlayRenderer:
	extends RefCounted

	var draw_calls := 0
	var order: Array[String] = []
	var last_canvas: CanvasItem = null
	var last_view_size := Vector2.ZERO

	func has_visible_effects(_runtime_state: Object, _mythic_item_runtime: Object = null) -> bool:
		return true

	func draw(
		canvas: CanvasItem,
		_runtime_state: Object,
		_catalog: Object,
		view_size: Vector2,
		_icon_renderer: Object = null,
		_mythic_item_runtime: Object = null,
		_perf_logger: Object = null
	) -> void:
		draw_calls += 1
		order.append("external_modal")
		last_canvas = canvas
		last_view_size = view_size


class DrawHarness:
	extends Node2D

	var drawer: Object = null
	var registry: Object = null

	func _draw() -> void:
		drawer.draw(self, registry, {"view_size": VIEW_SIZE})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_external_modal_draws_after_reward_pick()
	await _verify_inactive_external_modal_preserves_normal_order()

	if _failures.is_empty():
		print("battle_scene_victory_modal_draw_order_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_external_modal_draws_after_reward_pick() -> void:
	var result := await _draw_case(true)
	var loot: FakeVictoryLootState = result["loot"]
	var overlay: FakeRuntimePerkOverlayRenderer = result["overlay"]
	var canvas: CanvasItem = result["canvas"]
	_expect(
		result["order"] == ["reward_pick", "external_modal"],
		"active victory external modal must draw after the reward-pick board"
	)
	_expect(overlay.draw_calls == 1, "active victory external modal must draw exactly once per frame")
	_expect(loot.draw_calls == 1, "active reward-pick board must draw exactly once per frame")
	_expect(loot.external_modal_checks == 1, "draw-order gate must evaluate the victory external-modal facade once per frame")
	_expect(
		overlay.last_canvas == canvas and loot.last_canvas == canvas,
		"reward pick and its external modal must use the same canvas"
	)
	_expect(
		overlay.last_view_size.is_equal_approx(VIEW_SIZE)
		and loot.last_view_size.is_equal_approx(VIEW_SIZE),
		"reward pick and its external modal must use the same screen-space view size"
	)
	(result["viewport"] as SubViewport).queue_free()
	await process_frame


func _verify_inactive_external_modal_preserves_normal_order() -> void:
	var result := await _draw_case(false)
	var loot: FakeVictoryLootState = result["loot"]
	var overlay: FakeRuntimePerkOverlayRenderer = result["overlay"]
	_expect(
		result["order"] == ["external_modal", "reward_pick"],
		"inactive victory external-modal gate must preserve the normal HUD-before-reward order"
	)
	_expect(overlay.draw_calls == 1, "normal HUD overlay must still draw exactly once per frame")
	_expect(loot.draw_calls == 1, "normal reward-pick board must still draw exactly once per frame")
	_expect(loot.external_modal_checks == 1, "inactive draw-order gate must use the same single facade check")
	(result["viewport"] as SubViewport).queue_free()
	await process_frame


func _draw_case(external_modal_active: bool) -> Dictionary:
	var order: Array[String] = []
	var loot := FakeVictoryLootState.new()
	loot.external_modal_active = external_modal_active
	loot.order = order
	var overlay := FakeRuntimePerkOverlayRenderer.new()
	overlay.order = order
	var registry := FakeRegistry.new()
	registry.modules = {
		"runtime_perk_overlay_renderer": overlay,
		"victory_loot_phase_state": loot,
	}
	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEW_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := DrawHarness.new()
	canvas.drawer = BattleSceneDrawer.new()
	canvas.registry = registry
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	return {
		"canvas": canvas,
		"loot": loot,
		"order": order,
		"overlay": overlay,
		"viewport": viewport,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
