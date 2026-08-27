extends SceneTree

# expect-zero-object-leaks
const CONTROLLER_PATH := "res://scripts/core/defeat_continue_transition_controller.gd"
const SCREEN_PATH := "res://scripts/core/defeat_chance_gems_continue_screen.gd"
const SCENE_RENDERER_PATH := "res://scripts/core/defeat_continue_scene_renderer.gd"
const VIEW_SIZE := Vector2(1280.0, 720.0)

var _failures: Array[String] = []


class FakeRevivalBeat:
	extends RefCounted

	var active: bool = false
	var start_calls: int = 0
	var update_calls: int = 0
	var draw_calls: int = 0
	var reset_calls: int = 0


	func start(_owner: Object, _source_pos: Vector2, _view_size: Vector2) -> void:
		active = true
		start_calls += 1


	func update(_delta: float, _owner: Object, _view_size: Vector2) -> void:
		update_calls += 1


	func draw_overlay(_canvas: CanvasItem, _owner: Object, _view_size: Vector2) -> void:
		draw_calls += 1


	func reset(_owner: Object = null) -> void:
		active = false
		reset_calls += 1


	func blocks_battle_physics() -> bool:
		return active


	func get_status_for_tests() -> Dictionary:
		return {
			"active": active,
			"phase": "defeat_hold" if active else "inactive",
		}


	func get_color_restore_status(view_size: Vector2) -> Dictionary:
		return {
			"active": active,
			"view_size": view_size,
			"center_px": view_size * 0.5,
			"restore_radius_px": 0.0,
			"restore_feather_px": 64.0,
			"desaturate_amount": 1.0,
		}


class FakeRegistry:
	extends RefCounted

	var beat := FakeRevivalBeat.new()


	func get_instance(key: String) -> Object:
		if key == "defeat_continue_revival_beat_state":
			return beat
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_ownership()
	if FileAccess.file_exists(CONTROLLER_PATH):
		await _verify_runtime_lifecycle()
	if _failures.is_empty():
		print("defeat_continue_transition_controller_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_source_ownership() -> void:
	_expect(FileAccess.file_exists(CONTROLLER_PATH), "transition controller module must exist")
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var screen_source := FileAccess.get_file_as_string(SCREEN_PATH)
	var scene_renderer_source := FileAccess.get_file_as_string(SCENE_RENDERER_PATH)
	_expect(controller_source.contains("DefeatGemShatterFxHost"), "transition controller must own the shatter host")
	_expect(controller_source.contains("DefeatContinueColorRestoreFxHost"), "transition controller must own the color-restore host")
	_expect(controller_source.contains("DefeatContinueRevivalBeatState"), "transition controller must prewarm the revival beat")
	_expect(controller_source.contains("func bind"), "transition controller must bind owner and registry explicitly")
	_expect(controller_source.contains("func reset"), "transition controller must expose direct round-boundary cleanup")
	_expect(controller_source.contains("func sync_shatter"), "transition controller must sync the detached shatter host")
	_expect(controller_source.contains("func sync_color_restore"), "transition controller must sync the detached color-restore host")
	_expect(controller_source.contains("func start_revival"), "transition controller must bridge the post-reset revival beat")
	_expect(not controller_source.contains("func _process"), "transition controller must remain caller-clocked")
	_expect(screen_source.contains("DefeatContinueTransitionController"), "continue screen must compose the transition controller")
	_expect(not screen_source.contains("const DefeatGemShatterFxHost"), "continue screen must not retain the shatter-host class")
	_expect(not screen_source.contains("const DefeatContinueColorRestoreFxHost"), "continue screen must not retain the color-restore-host class")
	_expect(not screen_source.contains("func _ensure_gem_shatter_fx_host"), "continue screen must not retain host attachment logic")
	_expect(not screen_source.contains("func _ensure_color_restore_fx_host"), "continue screen must not retain color-host attachment logic")
	_expect(not screen_source.contains("func _get_continue_revival_beat_state"), "continue screen must not retain registry beat lookup")
	_expect(scene_renderer_source.contains("func draw_whiteout"), "scene renderer must own the full-screen whiteout overlay")
	_expect(not screen_source.contains("func _draw_whiteout"), "continue screen must not retain whiteout drawing")


func _verify_runtime_lifecycle() -> void:
	var controller_script: Variant = load(CONTROLLER_PATH)
	_expect(controller_script != null, "transition controller script must load")
	if controller_script == null:
		return
	var controller: Object = controller_script.new()
	var owner := Node2D.new()
	var registry := FakeRegistry.new()
	root.add_child(owner)
	controller.bind(owner, registry)
	await process_frame
	var shatter_host := owner.get_node_or_null("DefeatGemShatterFxHost")
	var color_host := owner.get_node_or_null("DefeatContinueColorRestoreFxHost")
	_expect(shatter_host != null, "bind must attach the shatter host outside draw")
	_expect(color_host != null, "bind must attach the color-restore host outside draw")
	controller.sync_shatter(VIEW_SIZE, true, Vector2(640.0, 540.0), 0.10, 0.65)
	_expect(shatter_host != null and bool(shatter_host.get_debug_status().get("active", false)), "active shatter sync must show its detached host")
	controller.start_revival(Vector2(500.0, 410.0), VIEW_SIZE)
	controller.update_revival(0.1, VIEW_SIZE)
	controller.draw_revival(owner, VIEW_SIZE)
	controller.sync_color_restore(VIEW_SIZE)
	_expect(registry.beat.start_calls == 1, "transition controller must start the bound revival beat exactly once")
	_expect(registry.beat.update_calls == 1 and registry.beat.draw_calls == 1, "transition controller must forward the caller clock and overlay draw")
	_expect(controller.is_revival_active(), "transition controller must expose the beat physics gate")
	_expect(color_host != null and bool(color_host.get_debug_status().get("visible", false)), "active revival status must show the color-restore host")
	controller.reset()
	_expect(registry.beat.reset_calls == 1 and not registry.beat.active, "reset must stop the bound revival beat")
	_expect(shatter_host != null and not bool(shatter_host.get_debug_status().get("active", true)), "reset must directly hide the shatter host")
	_expect(color_host != null and not bool(color_host.get_debug_status().get("visible", true)), "reset must directly hide the color-restore host")
	owner.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
