extends SceneTree

const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}
var _order: Array[String] = []


class FakeOwner:
	extends RefCounted

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakePillarDrawPass:
	extends RefCounted

	var full_draw_calls := 0
	var background_overlay_calls := 0
	var hud_overlay_calls := 0
	var background_context_owner: Object = null
	var hud_context_owner: Object = null

	func draw(_canvas: CanvasItem, _registry: Object, _view_size: Vector2, _layout: Dictionary) -> void:
		full_draw_calls += 1

	func draw_background_overlay(_canvas: CanvasItem, _registry: Object, _view_size: Vector2, _layout: Dictionary, context_owner: Object = null) -> void:
		background_overlay_calls += 1
		background_context_owner = context_owner

	func draw_hud_overlay(_canvas: CanvasItem, _registry: Object, _view_size: Vector2, _layout: Dictionary, context_owner: Object = null) -> void:
		hud_overlay_calls += 1
		hud_context_owner = context_owner


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		if typeof(value) == TYPE_OBJECT:
			return value as Object
		return null


class FakeIntroFrame:
	extends RefCounted

	var overlay_active := true
	var restore_pillar_overlay := true
	var order: Array[String] = []

	func draw_intro_or_boot(
		_canvas: CanvasItem,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_callbacks: Dictionary,
		_view_size: Vector2
	) -> bool:
		order.append("intro_or_boot")
		return false

	func is_ball_spawn_overlay_active(_module_getter: Callable) -> bool:
		order.append("overlay_active")
		return overlay_active

	func should_restore_ball_spawn_pillar_overlay(_module_getter: Callable) -> bool:
		order.append("restore_pillar_overlay")
		return restore_pillar_overlay

	func draw_ball_spawn_overlay(
		_canvas: CanvasItem,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_view_size: Vector2
	) -> bool:
		if not overlay_active:
			return false
		order.append("spawn_overlay")
		return true


class FakeStageTransitionDriver:
	extends RefCounted

	var active := true
	var order: Array[String] = []

	func is_stage_transition_loading_active() -> bool:
		return active

	func update_stage_transition_loading(_delta: float, _owner: Object, _registry: Object) -> void:
		order.append("transition_update")

	func draw_stage_transition_loading(
		_canvas: CanvasItem,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_view_size: Vector2
	) -> bool:
		order.append("transition_loading")
		return true


class FakeUpdateDriver:
	extends RefCounted

	var order: Array[String] = []

	func update(_owner: Object, _registry: Object, _delta: float) -> void:
		order.append("battle_update")


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeRuntimePerkOverlayRenderer:
	extends RefCounted

	var visible := false
	var visible_checks := 0
	var draw_calls := 0

	func has_visible_effects(_runtime_state: Object, _mythic_item_runtime: Object = null, _treasure_hunt_runtime: Object = null) -> bool:
		visible_checks += 1
		return visible

	func draw(
		_canvas: CanvasItem,
		_runtime_state: Object,
		_catalog: Object,
		_view_size: Vector2,
		_icon_renderer: Object = null,
		_mythic_item_runtime: Object = null,
		_treasure_hunt_runtime: Object = null,
		_perf_logger: Object = null
	) -> void:
		draw_calls += 1


func _init() -> void:
	_verify_stage_transition_loading_preempts_idle_and_draw()
	_verify_stage_transition_loading_blocks_physics()
	_verify_spawn_overlay_is_drawn_between_playfield_and_pillars()
	_verify_handoff_spawn_overlay_skips_pillar_restore()
	_verify_inactive_spawn_overlay_uses_normal_scene_draw()
	_verify_pillar_overlay_restores_hud_without_redrawing_pillar_background()
	_verify_pillar_overlay_can_skip_background_for_detached_host()
	_verify_inactive_runtime_perk_overlay_skips_draw()

	if _failures.is_empty():
		print("battle_scene_frame_controller_draw_order_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_transition_loading_preempts_idle_and_draw() -> void:
	var controller: Object = BattleSceneFrameController.new()
	var intro := FakeIntroFrame.new()
	var transition := FakeStageTransitionDriver.new()
	_order = []
	intro.order = _order
	transition.order = _order
	_modules = {
		"battle_scene_intro_frame_controller": intro,
		"battle_scene_match_event_driver": transition,
	}
	var canvas := Node2D.new()

	controller.process_idle(
		0.016,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{}
	)
	controller.draw(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		_get_split_callbacks()
	)
	canvas.free()

	_expect(
		_order == [
			"transition_update",
			"transition_loading",
		],
		"stage-transition loading should preempt intro, battle draw, spawn overlay, and mobile controls"
	)


func _verify_stage_transition_loading_blocks_physics() -> void:
	var controller: Object = BattleSceneFrameController.new()
	var transition := FakeStageTransitionDriver.new()
	var update_driver := FakeUpdateDriver.new()
	var perf_logger := FakePerfLogger.new()
	_order = []
	transition.order = _order
	update_driver.order = _order
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_match_event_driver": transition,
		"battle_scene_update_driver": update_driver,
	}

	controller.process_physics(
		0.016,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		{
			"is_battle_initialized": Callable(self, "_true_callback"),
			"is_stage_landing_intro_started": Callable(self, "_true_callback"),
		}
	)

	_expect(
		_order.is_empty(),
		"stage-transition loading should block normal battle physics updates"
	)
	_expect(
		perf_logger.labels.has("physics.frame.gate.stage_transition_loading"),
		"physics perf should sample the stage-transition loading gate before returning"
	)
	_expect(
		perf_logger.labels.has("physics.frame.perf_logger_lookup"),
		"physics perf should include the initial perf logger lookup in frame-controller timing"
	)
	_expect(
		not perf_logger.labels.has("physics.frame.update_driver"),
		"blocked physics should not sample the normal update driver"
	)
	_expect(perf_logger.labels.has("physics.frame.total"), "blocked physics should still sample total physics frame time")


func _verify_spawn_overlay_is_drawn_between_playfield_and_pillars() -> void:
	var controller: Object = BattleSceneFrameController.new()
	var intro := FakeIntroFrame.new()
	var perf_logger := FakePerfLogger.new()
	_order = []
	intro.order = _order
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_intro_frame_controller": intro,
	}
	var canvas := Node2D.new()

	controller.draw(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		_get_split_callbacks()
	)
	canvas.free()

	_expect(
		_order == [
			"intro_or_boot",
			"overlay_active",
			"restore_pillar_overlay",
			"battle_scene",
			"spawn_overlay",
			"pillar_overlay",
			"mobile_touch",
		],
		"spawn overlay should be drawn above the full scene and below restored pillar UI"
	)
	_expect(perf_logger.labels.has("draw.frame.intro_or_boot"), "draw perf should sample intro/boot handoff")
	_expect(perf_logger.labels.has("draw.frame.battle_scene"), "draw perf should sample battle scene callback")
	_expect(perf_logger.labels.has("draw.frame.ball_spawn_overlay"), "draw perf should sample ball-spawn overlay pass")
	_expect(perf_logger.labels.has("draw.frame.pillar_overlay"), "draw perf should sample pillar overlay pass")
	_expect(perf_logger.labels.has("draw.frame.mobile_touch"), "draw perf should sample mobile touch pass")
	_expect(perf_logger.labels.has("draw.frame.total"), "draw perf should sample full frame-controller draw")


func _verify_handoff_spawn_overlay_skips_pillar_restore() -> void:
	var controller: Object = BattleSceneFrameController.new()
	var intro := FakeIntroFrame.new()
	intro.restore_pillar_overlay = false
	_order = []
	intro.order = _order
	_modules = {"battle_scene_intro_frame_controller": intro}
	var canvas := Node2D.new()

	controller.draw(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		_get_split_callbacks()
	)
	canvas.free()

	_expect(
		_order == [
			"intro_or_boot",
			"overlay_active",
			"restore_pillar_overlay",
			"battle_scene",
			"spawn_overlay",
			"mobile_touch",
		],
		"post-handoff spawn overlay should not redraw the pillar overlay"
	)


func _verify_inactive_spawn_overlay_uses_normal_scene_draw() -> void:
	var controller: Object = BattleSceneFrameController.new()
	var intro := FakeIntroFrame.new()
	intro.overlay_active = false
	_order = []
	intro.order = _order
	_modules = {"battle_scene_intro_frame_controller": intro}
	var canvas := Node2D.new()

	controller.draw(
		canvas,
		FakeOwner.new(),
		null,
		Callable(self, "_get_module"),
		_get_split_callbacks()
	)
	canvas.free()

	_expect(
		_order == [
			"intro_or_boot",
			"overlay_active",
			"battle_scene",
			"mobile_touch",
		],
		"inactive spawn overlay should keep the regular single battle-scene draw path"
	)


func _verify_pillar_overlay_restores_hud_without_redrawing_pillar_background() -> void:
	var drawer: Object = BattleSceneDrawer.new()
	var pillar_pass := FakePillarDrawPass.new()
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new()
	registry.modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_pillar_draw_pass": pillar_pass,
	}
	var canvas := Node2D.new()
	var context_owner := Node2D.new()
	get_root().add_child(canvas)
	get_root().add_child(context_owner)

	drawer.draw_pillar_overlay(canvas, registry, {
		"view_size": Vector2(1280.0, 720.0),
		"context_owner": context_owner,
	})

	_expect(pillar_pass.full_draw_calls == 0, "pillar overlay should not redraw the full pillar background over the playfield")
	_expect(pillar_pass.background_overlay_calls == 1, "pillar overlay should restore clipped pillar background regions")
	_expect(pillar_pass.hud_overlay_calls == 1, "pillar overlay should restore only the pillar HUD/UI layer")
	_expect(pillar_pass.background_context_owner == context_owner, "pillar overlay should read background state from the real battle scene owner")
	_expect(pillar_pass.hud_context_owner == context_owner, "pillar overlay should read HUD textures and skill icons from the real battle scene owner")
	_expect(perf_logger.labels.has("draw.pillar_overlay.background"), "pillar overlay perf should sample background restore")
	_expect(perf_logger.labels.has("draw.pillar_overlay.hud"), "pillar overlay perf should sample HUD restore")
	_expect(perf_logger.labels.has("draw.pillar_overlay.post_hud"), "pillar overlay perf should sample post-playfield HUD restore")
	_expect(perf_logger.labels.has("draw.pillar_overlay.hud_overlays"), "pillar overlay perf should sample HUD overlays")
	_expect(perf_logger.labels.has("draw.pillar_overlay.total"), "pillar overlay perf should sample total restore")
	canvas.free()
	context_owner.free()


func _verify_pillar_overlay_can_skip_background_for_detached_host() -> void:
	var drawer: Object = BattleSceneDrawer.new()
	var pillar_pass := FakePillarDrawPass.new()
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new()
	registry.modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_pillar_draw_pass": pillar_pass,
	}
	var canvas := Node2D.new()
	var context_owner := Node2D.new()
	get_root().add_child(canvas)
	get_root().add_child(context_owner)

	drawer.draw_pillar_overlay(canvas, registry, {
		"view_size": Vector2(1280.0, 720.0),
		"context_owner": context_owner,
		"skip_background": true,
	})

	_expect(pillar_pass.background_overlay_calls == 0, "detached pillar host should skip already-visible pillar background")
	_expect(pillar_pass.hud_overlay_calls == 1, "detached pillar host should still restore HUD above the spawn FX host")
	_expect(not perf_logger.labels.has("draw.pillar_overlay.background"), "skipped pillar background should not be sampled as draw work")
	_expect(perf_logger.labels.has("draw.pillar_overlay.hud"), "detached pillar host should still sample HUD restore")
	_expect(perf_logger.labels.has("draw.pillar_overlay.total"), "detached pillar host should still sample total overlay cost")
	canvas.free()
	context_owner.free()


func _verify_inactive_runtime_perk_overlay_skips_draw() -> void:
	var drawer: Object = BattleSceneDrawer.new()
	var overlay := FakeRuntimePerkOverlayRenderer.new()
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new()
	registry.modules = {
		"battle_perf_logger": perf_logger,
		"runtime_perk_overlay_renderer": overlay,
	}
	var canvas := Node2D.new()
	get_root().add_child(canvas)

	drawer._draw_hud_overlays(canvas, registry, Vector2(1280.0, 720.0), {})
	_expect(overlay.visible_checks == 1, "battle scene drawer should ask the perk overlay if it has visible work")
	_expect(overlay.draw_calls == 0, "inactive runtime perk overlay should not enter its draw path")

	overlay.visible = true
	drawer._draw_hud_overlays(canvas, registry, Vector2(1280.0, 720.0), {})
	_expect(overlay.visible_checks == 2, "active runtime perk overlay should still pass the visibility gate")
	_expect(overlay.draw_calls == 1, "visible runtime perk overlay should draw normally")

	canvas.free()


func _get_split_callbacks() -> Dictionary:
	return {
		"draw_battle_scene": Callable(self, "_draw_battle_scene"),
		"draw_battle_playfield_scene": Callable(self, "_draw_battle_playfield_scene"),
		"draw_battle_pillar_overlay": Callable(self, "_draw_battle_pillar_overlay"),
		"draw_mobile_touch_controls": Callable(self, "_draw_mobile_touch_controls"),
	}


func _draw_battle_scene() -> void:
	_order.append("battle_scene")


func _draw_battle_playfield_scene() -> void:
	_order.append("playfield_scene")


func _draw_battle_pillar_overlay() -> void:
	_order.append("pillar_overlay")


func _draw_mobile_touch_controls() -> void:
	_order.append("mobile_touch")


func _true_callback() -> bool:
	return true


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT:
		return value as Object
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
