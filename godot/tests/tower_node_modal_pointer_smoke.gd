extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const TowerAscentNodeModalState := preload("res://scripts/tower_ascent/tower_ascent_node_modal_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var redraw_requests := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(2400.0, 1800.0))

	func queue_redraw() -> void:
		redraw_requests += 1


class FakeFlow:
	extends RefCounted
	var modal := TowerAscentNodeModalState.new()
	var confirmed := false
	var received_position := Vector2.ZERO

	func _init() -> void:
		modal.open("pointer-node", "rest", {}, [{"id": "top-row", "label": "첫 항목"}])

	func is_active() -> bool:
		return true

	func handle_input(event: InputEvent) -> bool:
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			received_position = mouse_event.position
			confirmed = (
				mouse_event.pressed
				and mouse_event.button_index == MOUSE_BUTTON_LEFT
				and modal.select_at_position(mouse_event.position)
			)
		return true


class FakeRegistry:
	extends RefCounted
	var flow: Object

	func _init(value: Object) -> void:
		flow = value

	func get_cached_instance(key: String) -> Object:
		return flow if key == "tower_ascent_flow_owner" else null


class FakeViewLayout:
	extends RefCounted

	func build_game_layout(_view_size: Vector2, _width: float, _height: float) -> Dictionary:
		return {
			"game_offset": Vector2(700.0, 120.0),
			"game_size": Vector2(1520.0, 1500.0),
			"render_scale": 2.0,
		}


class ModuleHolder:
	extends RefCounted
	var layout := FakeViewLayout.new()

	func get_module(key: String) -> Object:
		return layout if key == "battle_view_layout" else null


func _init() -> void:
	_verify_scaled_top_corner_click_uses_playfield_coordinates()
	if _failures.is_empty():
		print("tower_node_modal_pointer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_scaled_top_corner_click_uses_playfield_coordinates() -> void:
	var owner := FakeOwner.new()
	var flow := FakeFlow.new()
	var registry := FakeRegistry.new(flow)
	var holder := ModuleHolder.new()
	var local_top_corner := TowerAscentNodeModalState.ACTION_LIST_RECT.position + Vector2(2.0, 2.0)
	var screen_top_corner := Vector2(700.0, 120.0) + local_top_corner * 2.0
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_top_corner
	BattleSceneInputController.new().handle_unhandled_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module"),
		{}
	)
	_expect(flow.confirmed, "the rendered first-row top corner must be mouse-selectable after screen-to-playfield projection")
	_expect(flow.received_position.is_equal_approx(local_top_corner), "tower modal hit testing must receive the same playfield coordinates used by rendering")
	_expect(not TowerAscentNodeModalState.ACTION_LIST_RECT.has_point(screen_top_corner), "counterproof requires a screen point that the old unprojected hit test rejects")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
