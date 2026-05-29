extends SceneTree

const CommandoReloadDeliveryRenderer := preload("res://scripts/characters/commando_reload_delivery_renderer.gd")
const CommandoReloadDeliveryState := preload("res://scripts/characters/commando_reload_delivery_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_renderer_loads_generated_sheets()
	_verify_state_prewarm_loads_generated_sheets()
	_verify_exit_facing_matches_exit_motion()

	if _failures.is_empty():
		print("commando_reload_delivery_asset_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_renderer_loads_generated_sheets() -> void:
	var renderer: Object = CommandoReloadDeliveryRenderer.new()
	renderer.prewarm_assets()
	_expect(renderer.right_sheet != null, "reload delivery right sheet should load from the generated PNG")
	_expect(renderer.left_sheet != null, "reload delivery left sheet should load from the generated mirrored PNG")
	if renderer.right_sheet != null:
		_expect(renderer.right_sheet.get_width() == 512, "right sheet should be a 4x4 128-cell sheet")
		_expect(renderer.right_sheet.get_height() == 512, "right sheet height should match 4x4 128-cell layout")
	if renderer.left_sheet != null:
		_expect(renderer.left_sheet.get_width() == 512, "left sheet should be a 4x4 128-cell sheet")
		_expect(renderer.left_sheet.get_height() == 512, "left sheet height should match 4x4 128-cell layout")


func _verify_state_prewarm_loads_generated_sheets() -> void:
	var state: Object = CommandoReloadDeliveryState.new()
	var iterations := 0
	while not bool(state.prewarm_assets_step()) and iterations < 8:
		iterations += 1
	_expect(iterations < 8, "reload delivery state prewarm should finish quickly")
	_expect(state.renderer.right_sheet != null, "state prewarm should load the generated right sheet")
	_expect(state.renderer.left_sheet != null, "state prewarm should load the generated left sheet")


func _verify_exit_facing_matches_exit_motion() -> void:
	var state: Object = CommandoReloadDeliveryState.new()
	state.active = true
	state.phase = "run"
	state.facing = 1.0
	state.spawn_side = -1.0
	_expect(float(state.get_snapshot().get("facing", 0.0)) > 0.0, "entry run from left should face right")
	state.phase = "exit"
	_expect(float(state.get_snapshot().get("facing", 0.0)) < 0.0, "exit back to the left should face left")

	state.facing = -1.0
	state.spawn_side = 1.0
	state.phase = "run"
	_expect(float(state.get_snapshot().get("facing", 0.0)) < 0.0, "entry run from right should face left")
	state.phase = "exit"
	_expect(float(state.get_snapshot().get("facing", 0.0)) > 0.0, "exit back to the right should face right")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
