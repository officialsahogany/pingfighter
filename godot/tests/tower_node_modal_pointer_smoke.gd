extends SceneTree

const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const BattlePlayfieldSceneDrawer := preload(
	"res://scripts/core/battle_playfield_scene_drawer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const TowerAscentFlowOwner := preload("res://scripts/tower_ascent/tower_ascent_flow_owner.gd")
const TowerAscentNodeModalState := preload("res://scripts/tower_ascent/tower_ascent_node_modal_state.gd")
const TowerAscentScreenSpaceSurfacePolicy := preload(
	"res://scripts/tower_ascent/tower_ascent_screen_space_surface_policy.gd"
)

var _failures: Array[String] = []
const LIVE_VIEW_SIZE := Vector2(2020.0, 1246.0)


class FakeOwner:
	extends RefCounted
	var redraw_requests := 0

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, LIVE_VIEW_SIZE)

	func queue_redraw() -> void:
		redraw_requests += 1


class FakeModalRuntimeState:
	extends RefCounted
	var capture_calls := 0
	var pause_calls := 0
	var resume_calls := 0
	var safety_calls := 0

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		capture_calls += 1

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func _resume_skill_cooldowns_for_choice() -> void:
		resume_calls += 1

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		safety_calls += 1


class FakeModalAudio:
	extends RefCounted
	var stop_calls := 0

	func stop_dash_delay() -> void:
		stop_calls += 1


class FakeModalRegistry:
	extends RefCounted
	var runtime_state: Object
	var audio: Object

	func _init(runtime_state_value: Object, audio_value: Object) -> void:
		runtime_state = runtime_state_value
		audio = audio_value

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_state
		if key == "game_audio":
			return audio
		return null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FakeRouteServeRuntime:
	extends RefCounted
	var cancel_calls := 0

	func cancel() -> void:
		cancel_calls += 1


class FakeFlow:
	extends RefCounted
	var modal := TowerAscentNodeModalState.new()
	var confirmed := false
	var confirm_count := 0
	var received_position := Vector2.ZERO
	var phase := "NODE_MODAL"
	var fullscreen_draw_calls := 0
	var playfield_draw_calls := 0
	var fullscreen_fallback := Rect2()

	func _init() -> void:
		modal.open("pointer-node", "rest", {}, [{"id": "top-row", "label": "첫 항목"}])

	func is_active() -> bool:
		return true

	func get_phase_name() -> String:
		return phase

	func handle_input(event: InputEvent) -> bool:
		if event is InputEventMouseMotion:
			var motion_event := event as InputEventMouseMotion
			received_position = motion_event.position
			modal.update_hover_at_position(motion_event.position, LIVE_VIEW_SIZE)
		if event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			received_position = mouse_event.position
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				if mouse_event.pressed:
					modal.begin_pointer_press(mouse_event.position, LIVE_VIEW_SIZE)
				else:
					var action := modal.release_pointer_at_position(
						mouse_event.position,
						LIVE_VIEW_SIZE
					)
					if not action.is_empty():
						confirmed = true
						confirm_count += 1
		return true

	func draw_fullscreen_surface(_canvas: CanvasItem, fallback_rect: Rect2) -> void:
		fullscreen_draw_calls += 1
		fullscreen_fallback = fallback_rect

	func draw(_canvas: CanvasItem) -> void:
		playfield_draw_calls += 1


class FakeLoot:
	extends RefCounted

	var active := true
	var reward_pick_active := true
	var playfield_draw_calls := 0
	var fullscreen_draw_calls := 0
	var input_calls := 0
	var received_position := Vector2.ZERO
	var received_view_size := Vector2.ZERO

	func is_active() -> bool:
		return active

	func is_reward_pick_active() -> bool:
		return reward_pick_active

	func is_reward_pick_external_modal_active() -> bool:
		return false

	func draw(_canvas: CanvasItem, _shake_offset: Vector2 = Vector2.ZERO) -> void:
		playfield_draw_calls += 1

	func draw_reward_pick(_canvas: CanvasItem, view_size: Vector2) -> void:
		fullscreen_draw_calls += 1
		received_view_size = view_size

	func handle_input(event: InputEvent, view_size: Vector2) -> bool:
		input_calls += 1
		received_view_size = view_size
		if event is InputEventMouseButton:
			received_position = (event as InputEventMouseButton).position
		return true


class FakeRegistry:
	extends RefCounted
	var flow: Object
	var loot: Object

	func _init(value: Object, loot_value: Object = null) -> void:
		flow = value
		loot = loot_value

	func get_cached_instance(key: String) -> Object:
		if key == "tower_ascent_flow_owner":
			return flow
		if key == "victory_loot_phase_state":
			return loot
		return null

	func get_instance(key: String) -> Object:
		return get_cached_instance(key)


class FakeViewLayout:
	extends RefCounted

	func build_game_layout(_view_size: Vector2, _width: float, _height: float) -> Dictionary:
		return {
			"view_size": LIVE_VIEW_SIZE,
			"game_offset": Vector2(700.0, 120.0),
			"game_size": Vector2(1520.0, 1500.0),
			"render_scale": 2.0,
		}


class ModuleHolder:
	extends RefCounted
	var layout := FakeViewLayout.new()
	var loot: Object = null

	func get_module(key: String) -> Object:
		if key == "battle_view_layout":
			return layout
		if key == "victory_loot_phase_state":
			return loot
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_node_modal_top_corner_uses_screen_coordinates()
	_verify_shared_pointer_state_contract()
	_verify_production_release_inside_contract()
	_verify_physical_modal_lifecycle_contract()
	_verify_balance_row_is_horizontal_unboxed_and_not_clickable()
	_verify_playfield_phase_keeps_coordinate_projection()
	_verify_reward_pick_uses_screen_coordinates_and_view_size()
	_verify_six_card_grid_top_corners_match_hit_test()
	_verify_tower_node_card_description_rows()
	_verify_screen_space_render_routing_and_viewport_priority()
	if _failures.is_empty():
		print("tower_node_modal_pointer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_node_modal_top_corner_uses_screen_coordinates() -> void:
	var owner := FakeOwner.new()
	var flow := FakeFlow.new()
	var registry := FakeRegistry.new(flow)
	var holder := ModuleHolder.new()
	var screen_rects := flow.modal.get_action_rects(LIVE_VIEW_SIZE)
	var screen_top_corner := (screen_rects[0] as Rect2).position + Vector2(2.0, 2.0)
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
	_expect(not flow.confirmed, "a top-corner press must arm without executing the action")
	var release_event := InputEventMouseButton.new()
	release_event.pressed = false
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.position = screen_top_corner
	BattleSceneInputController.new().handle_unhandled_input(
		release_event,
		owner,
		registry,
		Callable(holder, "get_module"),
		{}
	)
	var old_projected := (screen_top_corner - Vector2(700.0, 120.0)) / 2.0
	_expect(flow.confirmed and flow.confirm_count == 1, "the fullscreen node action's rendered top corner must execute once on release-inside")
	_expect(flow.received_position.is_equal_approx(screen_top_corner), "NODE_MODAL must receive the same unscaled screen coordinate used by rendering")
	_expect(not (screen_rects[0] as Rect2).has_point(old_projected), "counterproof requires the old playfield projection to miss the fullscreen action")


func _verify_shared_pointer_state_contract() -> void:
	var modal := TowerAscentNodeModalState.new()
	modal.open("state-contract", "shop", {"gold": 70}, [
		{"id": "alpha", "label": "첫 카드"},
		{"id": "bravo", "label": "둘째 카드"},
		{"id": "charlie", "label": "셋째 카드"},
	])
	var fixed_rects := modal.get_action_rects(LIVE_VIEW_SIZE)
	var alpha_top_corner := (fixed_rects[0] as Rect2).position + Vector2(2.0, 2.0)
	var charlie_top_corner := (fixed_rects[2] as Rect2).position + Vector2(2.0, 2.0)
	_expect(modal.select_index(1), "keyboard focus fixture must select the second action")
	_expect(modal.update_hover_at_position(alpha_top_corner, LIVE_VIEW_SIZE), "mouse motion into a card must change hover state")
	var hovered_model := modal.build_view_model(LIVE_VIEW_SIZE)
	_expect(int(hovered_model.get("keyboard_selected_index", -1)) == 1, "pointer hover must not destroy keyboard focus")
	_expect(int(hovered_model.get("selected_index", -1)) == 1, "legacy selected_index must remain the keyboard-focus projection")
	_expect(int(hovered_model.get("hovered_index", -1)) == 0, "card top-corner hover must expose its action index")
	_expect(not modal.update_hover_at_position(alpha_top_corner, LIVE_VIEW_SIZE), "stationary hover must not report a state change")
	_expect(modal.begin_pointer_press(alpha_top_corner, LIVE_VIEW_SIZE), "card top-corner press must arm its fixed rect")
	_expect(modal.get_pressed_index() == 0, "pressed state must expose the armed card index")
	var pressed_rects := modal.get_action_rects(LIVE_VIEW_SIZE)
	_expect(pressed_rects.size() == fixed_rects.size(), "hover and press must not change the shared action-rect count")
	for index in range(mini(pressed_rects.size(), fixed_rects.size())):
		_expect((pressed_rects[index] as Rect2).is_equal_approx(fixed_rects[index] as Rect2), "hover and press must keep fixed action rect %d" % index)
	var released_action := modal.release_pointer_at_position(alpha_top_corner, LIVE_VIEW_SIZE)
	_expect(str(released_action.get("id", "")) == "alpha", "release inside the armed top-corner rect must return that action")
	_expect(modal.get_pressed_index() == -1, "release must clear pressed state")
	_expect(modal.release_pointer_at_position(alpha_top_corner, LIVE_VIEW_SIZE).is_empty(), "a second release must not execute without a new press")
	_expect(modal.begin_pointer_press(alpha_top_corner, LIVE_VIEW_SIZE), "drag-cancel fixture must arm from the card top corner")
	_expect(modal.release_pointer_at_position((fixed_rects[0] as Rect2).position - Vector2(2.0, 2.0), LIVE_VIEW_SIZE).is_empty(), "release outside the armed rect must cancel")
	_expect(not modal.begin_pointer_press(Vector2.ZERO, LIVE_VIEW_SIZE), "press outside every action rect must not arm")
	_expect(modal.release_pointer_at_position(alpha_top_corner, LIVE_VIEW_SIZE).is_empty(), "outside press followed by inside release must not execute")
	modal.set_status_text("상태 보존")
	modal.select_index(1)
	modal.update_hover_at_position(charlie_top_corner, LIVE_VIEW_SIZE)
	modal.begin_pointer_press(alpha_top_corner, LIVE_VIEW_SIZE)
	modal.set_actions([
		{"id": "charlie", "label": "셋째 카드 갱신"},
		{"id": "bravo", "label": "둘째 카드 갱신"},
		{"id": "alpha", "label": "첫 카드 갱신"},
	])
	var refreshed_model := modal.build_view_model(LIVE_VIEW_SIZE)
	var refreshed_actions: Array = refreshed_model.get("actions", [])
	_expect(str(refreshed_actions[int(refreshed_model.get("keyboard_selected_index", -1))].get("id", "")) == "bravo", "set_actions must preserve keyboard focus by action ID")
	_expect(str(refreshed_actions[int(refreshed_model.get("hovered_index", -1))].get("id", "")) == "charlie", "set_actions must preserve hover by action ID")
	_expect(int(refreshed_model.get("pressed_index", 99)) == -1, "set_actions must cancel an in-flight pointer press")
	_expect(str(refreshed_model.get("status_text", "")) == "상태 보존", "set_actions must preserve the current result/status text")
	_expect(str(refreshed_model.get("node_id", "")) == "state-contract", "set_actions must preserve modal identity")
	modal.set_actions([{"id": "charlie", "label": "셋째 카드만"}])
	_expect(str(modal.get_selected_action().get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK, "removed keyboard action must fall back to the same clamped slot deterministically")
	_expect(modal.update_hover_at_position(Vector2.ZERO, LIVE_VIEW_SIZE), "moving outside must clear hover")
	_expect(modal.get_hovered_index() == -1, "outside motion must expose no hovered action")


func _verify_production_release_inside_contract() -> void:
	var flow := TowerAscentFlowOwner.new()
	flow.set("_active", true)
	flow.set("_phase", 1)
	var modal: Object = flow.get("_node_modal_state")
	modal.open("production-pointer", "rest", {}, [{
		"id": "disabled-action",
		"label": "사용 불가",
		"enabled": false,
		"unavailable_reason": "release-confirmed",
	}])
	modal.select_index(1)
	var action_rect := modal.get_action_rects()[0] as Rect2
	var top_corner := action_rect.position + Vector2(2.0, 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = top_corner
	_expect(flow.handle_input(motion), "production NODE_MODAL must consume mouse motion")
	var hovered_model: Dictionary = modal.build_view_model()
	_expect(int(hovered_model.get("hovered_index", -1)) == 0, "production mouse motion must update shared hover state")
	_expect(int(hovered_model.get("keyboard_selected_index", -1)) == 1, "production mouse motion must retain keyboard focus")
	modal.set_status_text("press-not-release")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = top_corner
	flow.handle_input(press)
	_expect(modal.get_pressed_index() == 0, "production press must arm the card at its top corner")
	_expect(str(modal.build_view_model().get("status_text", "")) == "press-not-release", "production press must not execute before release")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = top_corner
	flow.handle_input(release)
	_expect(str(modal.build_view_model().get("status_text", "")) == "release-confirmed", "production release-inside must execute the armed action")
	modal.set_status_text("single-release")
	flow.handle_input(release)
	_expect(str(modal.build_view_model().get("status_text", "")) == "single-release", "production repeated release must execute zero additional actions")
	modal.set_status_text("drag-cancelled")
	flow.handle_input(press)
	release.position = action_rect.position - Vector2(2.0, 2.0)
	flow.handle_input(release)
	_expect(str(modal.build_view_model().get("status_text", "")) == "drag-cancelled", "production drag outside must cancel without executing")
	modal.set_status_text("keyboard-cancelled")
	flow.handle_input(press)
	var keyboard_move := InputEventKey.new()
	keyboard_move.keycode = KEY_DOWN
	keyboard_move.pressed = true
	flow.handle_input(keyboard_move)
	_expect(modal.get_pressed_index() == -1, "keyboard input must cancel an in-flight pointer press")
	release.position = top_corner
	flow.handle_input(release)
	_expect(str(modal.build_view_model().get("status_text", "")) == "keyboard-cancelled", "release after keyboard cancellation must execute zero pointer actions")
	modal.update_hover_at_position(Vector2.ZERO)
	modal.set_status_text("touch-press")
	var touch := InputEventScreenTouch.new()
	touch.position = top_corner
	touch.pressed = true
	flow.handle_input(touch)
	_expect(modal.get_hovered_index() == -1, "touch press must not synthesize mouse hover")
	_expect(str(modal.build_view_model().get("status_text", "")) == "touch-press", "touch press must wait for release")
	touch.pressed = false
	flow.handle_input(touch)
	_expect(str(modal.build_view_model().get("status_text", "")) == "release-confirmed", "touch release-inside must execute the armed action")


func _verify_physical_modal_lifecycle_contract() -> void:
	var flow := TowerAscentFlowOwner.new()
	var owner := FakeOwner.new()
	var runtime_state := FakeModalRuntimeState.new()
	var audio := FakeModalAudio.new()
	var registry := FakeModalRegistry.new(runtime_state, audio)
	var lifecycle: Object = flow.get("_modal_lifecycle")
	var enter_result: Dictionary = lifecycle.enter(owner, registry)
	_expect(bool(enter_result.get("accepted", false)) and bool(enter_result.get("changed", false)), "GRT-058 entry must activate the shared modal lifecycle")
	_expect(runtime_state.capture_calls == 1 and runtime_state.pause_calls == 1, "GRT-058 entry must capture and pause exactly once")
	_expect(audio.stop_calls == 1, "GRT-058 entry must stop registered loop audio exactly once")
	var repeated_enter: Dictionary = lifecycle.enter(owner, registry)
	_expect(bool(repeated_enter.get("accepted", false)) and not bool(repeated_enter.get("changed", true)), "GRT-058 repeated entry must be idempotent")
	_expect(runtime_state.capture_calls == 1 and runtime_state.pause_calls == 1, "GRT-058 repeated entry must not duplicate capture or pause")
	var route_serve := FakeRouteServeRuntime.new()
	flow.set("_route_serve_runtime", route_serve)
	flow.set("_active", true)
	flow.set("_active_owner", owner)
	flow.set("_active_registry", registry)
	flow.set("_phase", 1)
	var modal: Object = flow.get("_node_modal_state")
	modal.open("lifecycle-node", "rest", {}, [{"id": "rest", "label": "휴식"}])
	_expect(flow.blocks_battle_physics(), "active NODE_MODAL must physically block battle simulation")
	flow.call("_finish_vertical_slice")
	_expect(route_serve.cancel_calls == 1, "production close must cancel route presentation once")
	_expect(runtime_state.resume_calls == 1 and runtime_state.safety_calls == 1, "GRT-058 production close must resume and arm safety exactly once")
	_expect(not flow.is_active() and not flow.blocks_battle_physics(), "production close must release the physical battle block")
	_expect(str(modal.build_view_model().get("node_id", "sentinel")) == "", "production close must clear shared node-modal state")
	var repeated_leave: Dictionary = lifecycle.leave()
	_expect(bool(repeated_leave.get("accepted", false)) and not bool(repeated_leave.get("changed", true)), "GRT-058 repeated leave must be idempotent")
	_expect(runtime_state.resume_calls == 1 and runtime_state.safety_calls == 1, "GRT-058 repeated leave must not duplicate resume or safety")


func _verify_balance_row_is_horizontal_unboxed_and_not_clickable() -> void:
	var flow := FakeFlow.new()
	var screen_layout := flow.modal.build_screen_layout(LIVE_VIEW_SIZE)
	var content_scale := float(screen_layout.get("content_scale", 1.0))
	var content_offset: Vector2 = screen_layout.get("content_offset", Vector2.ZERO)
	var renderer := TowerAscentFlowRenderer.new()
	var balance_layout: Dictionary = renderer.build_balance_row_layout(content_scale, content_offset)
	var entries: Array = balance_layout.get("entries", [])
	_expect(entries.size() == 2, "balance row must append exactly two currency entries")
	if entries.size() != 2:
		return
	var muhon_rect: Rect2 = (entries[0] as Dictionary).get("rect", Rect2())
	var gold_rect: Rect2 = (entries[1] as Dictionary).get("rect", Rect2())
	_expect(is_equal_approx(muhon_rect.position.y, gold_rect.position.y), "Muhon and gold must share one horizontal baseline")
	_expect(is_equal_approx(muhon_rect.size.y, gold_rect.size.y), "currency entries must share one row height")
	_expect(gold_rect.position.x > muhon_rect.end.x, "currency entries must retain a positive horizontal gap")
	_expect(not bool(balance_layout.get("uses_background_box", true)), "balance row contract must remove the surrounding box")
	for entry_value in entries:
		var entry := entry_value as Dictionary
		var rect: Rect2 = entry.get("rect", Rect2())
		var icon_center: Vector2 = entry.get("icon_center", Vector2.ZERO)
		var text_rect: Rect2 = entry.get("text_rect", Rect2())
		_expect(rect.has_point(icon_center), "currency icon center must be derived inside its entry")
		_expect(text_rect.position.x > icon_center.x, "currency text must follow its icon on the same row")
		var top_corner := rect.position + Vector2(2.0, 2.0)
		_expect(not flow.modal.select_at_position(top_corner, LIVE_VIEW_SIZE), "balance top corner must not enter the action hit-test path")
	var source := FileAccess.get_file_as_string("res://scripts/tower_ascent/tower_ascent_flow_renderer.gd")
	var start := source.find("func _draw_balance_entry(")
	var finish := source.find("func _draw_gold_coin_icon(", start)
	_expect(start >= 0 and finish > start, "balance drawer source contract must remain inspectable")
	if start >= 0 and finish > start:
		var drawer_source := source.substr(start, finish - start)
		_expect(not drawer_source.contains("draw_rect("), "balance entry drawer must not restore a fill or border box")


func _verify_playfield_phase_keeps_coordinate_projection() -> void:
	var owner := FakeOwner.new()
	var flow := FakeFlow.new()
	flow.phase = "ROUTE_AIM"
	var holder := ModuleHolder.new()
	var screen_position := Vector2(1000.0, 620.0)
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_position
	BattleSceneInputController.new().handle_unhandled_input(
		event,
		owner,
		FakeRegistry.new(flow),
		Callable(holder, "get_module"),
		{}
	)
	var expected_playfield := (screen_position - Vector2(700.0, 120.0)) / 2.0
	_expect(flow.received_position.is_equal_approx(expected_playfield), "playfield-owned tower phases must retain screen-to-game projection")


func _verify_reward_pick_uses_screen_coordinates_and_view_size() -> void:
	var owner := FakeOwner.new()
	var loot := FakeLoot.new()
	var registry := FakeRegistry.new(null, loot)
	var holder := ModuleHolder.new()
	holder.loot = loot
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(1510.0, 310.0)
	var handled := bool(BattleSceneInputController.new().call(
		"_handle_victory_loot_input",
		event,
		owner,
		registry,
		Callable(holder, "get_module")
	))
	_expect(handled and loot.input_calls == 1, "active reward pick must consume input through the production victory-loot route")
	_expect(loot.received_position.is_equal_approx(event.position), "fullscreen reward cards must receive raw screen coordinates")
	_expect(loot.received_view_size.is_equal_approx(LIVE_VIEW_SIZE), "reward rect generation and hit testing must share the live viewport size")


func _verify_six_card_grid_top_corners_match_hit_test() -> void:
	for node_kind in ["shop", "training", "fallen_monk"]:
		var modal := TowerAscentNodeModalState.new()
		var actions: Array[Dictionary] = []
		var card_count := 8 if node_kind == "shop" else 6
		for index in range(card_count):
			actions.append({"id": "%s-card-%d" % [node_kind, index], "label": "card %d" % index})
		modal.open("six-card-node", node_kind, {"muhon": 20}, actions)
		var model: Dictionary = modal.build_view_model()
		var layout_flags: Dictionary = model.get("layout_flags", {})
		var layout: Dictionary = modal.build_screen_layout(Vector2(760.0, 750.0), layout_flags)
		var rects: Array = model.get("action_rects", [])
		_expect(rects.size() == card_count + 1, "%s must expose every card plus the end-work action" % node_kind)
		if node_kind == "shop":
			var stock_panel: Rect2 = layout.get("shop_stock_panel_rect", Rect2())
			var exact_stock_rects: Array = model.get("shop_stock_card_rects", [])
			_expect(exact_stock_rects.size() == 8, "stacked shop must publish exactly eight stock rects")
			_expect(not modal.select_at_position(stock_panel.position + Vector2(2.0, 2.0)), "stock-panel label corner must not purchase the first product")
			for index in range(8):
				var rect := rects[index] as Rect2
				_expect(rect.is_equal_approx(exact_stock_rects[index] as Rect2), "shop stock %d must use the exact published card rect" % index)
				_expect(modal.select_at_position(rect.position + Vector2(2.0, 2.0)), "shop stock %d top corner must be selectable" % index)
				_expect(str(modal.get_selected_action().get("id", "")) == "shop-card-%d" % index, "shop stock %d hit test must select its drawn cell" % index)
			var eighth_rect := rects[7] as Rect2
			_expect(modal.select_at_position(Vector2(eighth_rect.end.x - 0.5, eighth_rect.get_center().y)), "eighth card right edge must remain selectable")
			_expect(str(modal.get_selected_action().get("id", "")) == "shop-card-7", "eighth-card edge hit must select the eighth product")
			var prewarm_probe := RuntimePerkOverlayRenderer.new().prewarm_tower_shop_cells(
				model.get("actions", []),
				[],
				model,
				null
			)
			var prewarm_stock_rects: Array = prewarm_probe.get("stock_rects", [])
			_expect(prewarm_stock_rects.size() == 8, "shop prewarm must visit exactly eight occupied stock cards")
			for index in range(prewarm_stock_rects.size()):
				_expect((prewarm_stock_rects[index] as Rect2).is_equal_approx(rects[index] as Rect2), "shop prewarm cell %d must match draw/hit geometry" % index)
			for slot_capacity in [3, 5, 8]:
				var owned_items: Array[Dictionary] = []
				for slot_index in range(slot_capacity):
					owned_items.append(
						{
							"id": "owned-probe",
							"name": "owned probe",
							"item_data": {"name": "owned-probe"},
						}
						if slot_index == 0
						else {"empty_slot": true, "slot_index": slot_index}
					)
				modal.set_shop_owned_items(owned_items)
				var owned_model: Dictionary = modal.build_view_model()
				var owned_rects: Array = owned_model.get("shop_owned_slot_rects", [])
				_expect(owned_rects.size() == slot_capacity, "shop must publish %d capacity-owned slot rects" % slot_capacity)
				var owned_panel: Rect2 = owned_model.get("shop_owned_panel_rect", Rect2())
				for slot_index in range(owned_rects.size()):
					var owned_rect := owned_rects[slot_index] as Rect2
					_expect(owned_panel.encloses(owned_rect), "owned slot %d/%d must stay inside its panel" % [slot_index, slot_capacity])
					if slot_index > 0:
						_expect(not owned_rect.intersects(owned_rects[slot_index - 1] as Rect2), "owned slots must never overlap")
				var last_owned_rect := owned_rects[slot_capacity - 1] as Rect2
				var owned_corner := last_owned_rect.position + Vector2(2.0, 2.0)
				_expect(modal.get_owned_cell_index_at(owned_corner) == slot_capacity - 1, "final owned slot must resolve through the shared slot rect")
				_expect(not modal.select_at_position(owned_corner), "owned read-only slot must not enter the action selection route")
				_expect(not modal.begin_pointer_press(owned_corner), "owned read-only click must never arm a purchase")
				var owned_prewarm := RuntimePerkOverlayRenderer.new().prewarm_tower_shop_cells(
					owned_model.get("actions", []),
					owned_model.get("shop_owned_items", []),
					owned_model,
					null
				)
				var prewarm_owned_rects: Array = owned_prewarm.get("player_rects", [])
				_expect(prewarm_owned_rects == owned_rects, "owned prewarm must consume the exact %d-slot draw/hit rect array" % slot_capacity)
			_expect(not modal.select_at_position(TowerAscentNodeModalState.SHOP_CARD_GRID_RECT.position + Vector2(2.0, 2.0)), "retired compact-card top corner must not purchase stock")
			var end_work_rect := rects[8] as Rect2
			_expect(end_work_rect.is_equal_approx(TowerAscentNodeModalState.SHOP_STACKED_END_WORK_RECT), "shop end-work action must use its flagged footer rect")
			_expect(modal.select_at_position(end_work_rect.position + Vector2(2.0, 2.0)), "shop end-work top corner must be selectable")
			_expect(str(modal.get_selected_action().get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK, "shop footer hit test must select end-work")
			continue
		var card_grid_rect: Rect2 = layout.get("card_grid_rect", Rect2())
		var column_gap := float(layout.get("grid_column_gap", TowerAscentNodeModalState.GRID_COLUMN_GAP))
		var row_gap := float(layout.get("grid_row_gap", TowerAscentNodeModalState.GRID_ROW_GAP))
		# S5 수련 1x6 레일과 피드백3 상점 compact 3x2 모두 생산 레이아웃
		# 플래그를 따라야 한다. 상단 모서리 표본이 GRT-022 반증 정본이다.
		var is_training_grid := str(node_kind) == "training"
		var grid_columns := TowerAscentNodeModalState.CARD_GRID_COLUMNS
		var grid_rows := TowerAscentNodeModalState.CARD_GRID_ROWS
		if is_training_grid:
			grid_columns = TowerAscentNodeModalState.TRAINING_CARD_GRID_COLUMNS
			grid_rows = TowerAscentNodeModalState.TRAINING_CARD_GRID_ROWS
		var card_width := (
			card_grid_rect.size.x
			- column_gap
			* float(grid_columns - 1)
		) / float(grid_columns)
		var card_height := (
			card_grid_rect.size.y
			- row_gap
			* float(grid_rows - 1)
		) / float(grid_rows)
		for index in range(6):
			var rect := rects[index] as Rect2
			var expected_column := index % grid_columns
			var expected_row := index / grid_columns
			var expected_rect := Rect2(
				card_grid_rect.position + Vector2(
					float(expected_column) * (
						card_width + column_gap
					),
					float(expected_row) * (
						card_height + row_gap
					)
				),
				Vector2(card_width, card_height)
			)
			_expect(rect.is_equal_approx(expected_rect), "%s card %d must occupy its exact flagged grid cell" % [node_kind, index])
			_expect(card_grid_rect.encloses(rect), "%s card %d must remain inside the flagged card grid" % [node_kind, index])
			_expect(modal.select_at_position(rect.position + Vector2(2.0, 2.0)), "%s action %d top corner must be selectable" % [node_kind, index])
			_expect(str(modal.get_selected_action().get("id", "")) == str((modal.build_view_model().get("actions", []) as Array)[index].get("id", "")), "%s action %d hit test must select its drawn card" % [node_kind, index])
		var end_work_rect := rects[card_count] as Rect2
		_expect(end_work_rect.is_equal_approx(layout.get("end_work_rect", Rect2())), "%s end-work action must use its flagged footer rect" % node_kind)
		_expect(modal.select_at_position(end_work_rect.position + Vector2(2.0, 2.0)), "%s end-work top corner must be selectable" % node_kind)
		_expect(str(modal.get_selected_action().get("id", "")) == TowerAscentNodeModalState.ACTION_END_WORK, "%s footer hit test must select end-work" % node_kind)
		_expect(TowerAscentNodeModalState.MODAL_RECT.encloses(card_grid_rect), "%s card grid must stay inside the playfield-owned modal" % node_kind)


func _verify_tower_node_card_description_rows() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var action := {
		"id": "training_stat:long-description",
		"label": "최장 설명 수련",
		"payload": {
			"choice": {
				"id": "long-description",
				"name": "최장 설명 수련",
				"description": "아주 긴 수련 설명이 카드 폭을 넘어가더라도 실제 카드에 추가되는 설명 행만 남기고 마지막 행은 말줄임표로 닫혀야 합니다 반복 검증 문장입니다",
				"level_text": "Lv.7",
			}
		},
	}
	var card_rect := Rect2(Vector2.ZERO, Vector2(216.0, 212.0))
	var layout: Dictionary = renderer.build_tower_node_card_text_layout(action, card_rect)
	var rows: Array = layout.get("description_rows", [])
	_expect(rows.size() == 3, "longest node-card description must append exactly three visible rows")
	_expect(int(layout.get("appended_description_row_count", -1)) == rows.size(), "GRT-021 count must equal the rows consumed by the card drawer")
	_expect(not rows.is_empty() and str(rows.back()).ends_with("..."), "the last appended description row must carry truncation evidence")


func _verify_screen_space_render_routing_and_viewport_priority() -> void:
	_expect(
		TowerAscentScreenSpaceSurfacePolicy.FLOW_PHASES
		== ["MAP_OVERLAY", "MAP_TRANSITION", "NODE_MODAL"],
		"both draw passes must share one authoritative fullscreen phase list"
	)
	var canvas := Node2D.new()
	var flow := FakeFlow.new()
	var loot := FakeLoot.new()
	var registry := FakeRegistry.new(flow, loot)
	var scene_drawer := BattleSceneDrawer.new()
	scene_drawer.call(
		"_draw_tower_ascent_fullscreen_map",
		canvas,
		registry,
		LIVE_VIEW_SIZE
	)
	_expect(flow.fullscreen_draw_calls == 1, "NODE_MODAL must draw exactly once in the screen-space pass")
	_expect(not BattlePlayfieldSceneDrawer.should_draw_tower_flow_in_playfield("NODE_MODAL"), "NODE_MODAL must not double-render in the transformed playfield pass")
	_expect(flow.fullscreen_fallback.size.is_equal_approx(LIVE_VIEW_SIZE), "screen-space flow must receive the full live view rect")

	flow.phase = "ROUTE_AIM"
	scene_drawer.call("_draw_tower_ascent_fullscreen_map", canvas, registry, LIVE_VIEW_SIZE)
	_expect(
		flow.fullscreen_draw_calls == 1
		and BattlePlayfieldSceneDrawer.should_draw_tower_flow_in_playfield("ROUTE_AIM"),
		"ROUTE_AIM must remain exclusively in the transformed playfield pass"
	)

	scene_drawer.call("_draw_tower_reward_pick", canvas, registry, LIVE_VIEW_SIZE)
	_expect(
		not BattlePlayfieldSceneDrawer.should_draw_victory_loot_in_playfield(true)
		and loot.fullscreen_draw_calls == 1,
		"tower reward pick must move from playfield draw to one screen-space draw"
	)
	loot.reward_pick_active = false
	scene_drawer.call("_draw_tower_reward_pick", canvas, registry, LIVE_VIEW_SIZE)
	_expect(
		BattlePlayfieldSceneDrawer.should_draw_victory_loot_in_playfield(false)
		and loot.fullscreen_draw_calls == 1,
		"legacy victory loot must stay in the playfield and never enter the fullscreen pass"
	)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(LIVE_VIEW_SIZE)
	get_root().add_child(viewport)
	var tree_canvas := Node2D.new()
	viewport.add_child(tree_canvas)
	var renderer := TowerAscentFlowRenderer.new()
	var resolved := renderer.resolve_fullscreen_rect(
		tree_canvas,
		Rect2(Vector2.ZERO, Vector2(760.0, 750.0))
	)
	_expect(resolved.size.is_equal_approx(LIVE_VIEW_SIZE), "tree-attached fullscreen surfaces must prefer the viewport over a small game-size fallback")
	var accents: Dictionary = {}
	for node_kind in ["shop", "training", "fallen_monk", "guardian_spring", "rest"]:
		var backdrop: Dictionary = renderer.build_node_modal_backdrop_model(node_kind, resolved)
		_expect((backdrop.get("rect", Rect2()) as Rect2) == resolved, "%s backdrop must cover the entire viewport rect" % node_kind)
		_expect(float((backdrop.get("top_color", Color.TRANSPARENT) as Color).a) >= 1.0, "%s backdrop corners must be opaque" % node_kind)
		accents[str(backdrop.get("accent", Color.TRANSPARENT))] = true
	_expect(accents.size() == 5, "all five non-combat node kinds must expose distinct procedural backdrop identities")
	viewport.remove_child(tree_canvas)
	tree_canvas.queue_free()
	get_root().remove_child(viewport)
	viewport.queue_free()
	canvas.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
