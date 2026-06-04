extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class FakeCharacterInfo:
	extends RefCounted

	var active := true
	var input_redraw_requested := false
	var handle_count := 0

	func is_active() -> bool:
		return active

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
		handle_count += 1
		return true

	func consume_input_redraw_request() -> bool:
		var requested: bool = input_redraw_requested
		input_redraw_requested = false
		return requested


class FakeMythicRuntime:
	extends RefCounted

	var toggle_calls := 0
	var toggle_result := true
	var unequip_calls := 0
	var unequip_result := true
	var last_unequip_slot := ""

	func toggle_inventory_item(index: int, _owner: Object, _registry: Object = null) -> bool:
		toggle_calls += 1
		return index == 0 and toggle_result

	func unequip_slot(slot_key: String, _owner: Object, _registry: Object = null) -> bool:
		unequip_calls += 1
		last_unequip_slot = slot_key
		return slot_key == "head" and unequip_result


class FakeRegistry:
	extends RefCounted

	var mythic_item_runtime: Object = null

	func get_instance(key: String) -> Object:
		if key == "mythic_item_runtime":
			return mythic_item_runtime
		return null


func _init() -> void:
	_verify_input_controller_respects_character_info_redraw_gate()
	_verify_character_info_mouse_motion_is_throttled()
	_verify_character_info_hover_signature_is_section_gated()
	_verify_character_info_open_animation_consumes_pending_redraw()
	_verify_character_info_context_click_queues_single_redraw()
	_verify_character_info_equipment_context_click_is_section_gated()
	_verify_character_info_equipment_context_click_uses_index_cache()

	if _failures.is_empty():
		print("character_info_input_redraw_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_input_controller_respects_character_info_redraw_gate() -> void:
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()
	var character_info := FakeCharacterInfo.new()
	_modules = {
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"character_info_overlay": character_info,
	}

	_expect(_motion(input, owner, Vector2(100.0, 100.0)), "active character info should consume mouse motion")
	_expect(character_info.handle_count == 1, "character info should receive the first input event")
	_expect(owner.redraw_count == 0, "handled character info input should not redraw without an input redraw request")

	character_info.input_redraw_requested = true
	_expect(_motion(input, owner, Vector2(112.0, 100.0)), "active character info should consume redraw-worthy input")
	_expect(character_info.handle_count == 2, "character info should receive the second input event")
	_expect(owner.redraw_count == 1, "input redraw request should queue exactly one redraw")
	_expect(not character_info.input_redraw_requested, "input redraw request should be consumed")


func _verify_character_info_mouse_motion_is_throttled() -> void:
	var overlay := CharacterInfoOverlay.new()
	overlay.open()

	var first_motion := _make_motion(Vector2(20.0, 20.0))
	_expect(overlay.handle_input(first_motion, null, null, Vector2(1280.0, 720.0)), "first character info mouse motion should be handled")
	_expect(not overlay.consume_input_redraw_request(), "empty character info mouse motion should not redraw without a hover visual")

	var nearby_motion := _make_motion(Vector2(28.0, 24.0))
	_expect(overlay.handle_input(nearby_motion, null, null, Vector2(1280.0, 720.0)), "nearby character info mouse motion should still be handled")
	_expect(not overlay.consume_input_redraw_request(), "nearby same-hover mouse motion should not redraw")

	var distant_motion := _make_motion(Vector2(80.0, 20.0))
	_expect(overlay.handle_input(distant_motion, null, null, Vector2(1280.0, 720.0)), "distant character info mouse motion should be handled")
	_expect(not overlay.consume_input_redraw_request(), "distant empty mouse motion should still avoid redraw")

	overlay.set("_last_perk_grid_rect", Rect2(Vector2.ZERO, Vector2(140.0, 90.0)))
	overlay._set_perk_grid_hover_layout(Vector2(10.0, 10.0), 44.0, 52.0, 1, 1)
	overlay.set("_last_hover_signature", "perk_grid")
	var perk_hover_motion := _make_motion(Vector2(20.0, 20.0))
	_expect(overlay.handle_input(perk_hover_motion, null, null, Vector2(1280.0, 720.0)), "perk hover mouse motion should be handled")
	_expect(overlay.consume_input_redraw_request(), "entering a perk icon from the perk grid background should redraw")
	overlay._reset_mouse_hover_tracking()
	overlay.set("_last_perk_grid_rect", Rect2())

	overlay.set("_last_skill_rect", Rect2(Vector2.ZERO, Vector2(140.0, 90.0)))
	overlay._set_skill_slot_hover_layout(Vector2(10.0, 10.0), 60.0, 66.0, 1)
	var hover_motion := _make_motion(Vector2(20.0, 20.0))
	_expect(overlay.handle_input(hover_motion, null, null, Vector2(1280.0, 720.0)), "skill hover mouse motion should be handled")
	_expect(overlay.consume_input_redraw_request(), "entering a character info hover visual should redraw")

	var nearby_hover_motion := _make_motion(Vector2(26.0, 24.0))
	_expect(overlay.handle_input(nearby_hover_motion, null, null, Vector2(1280.0, 720.0)), "nearby hover mouse motion should be handled")
	_expect(not overlay.consume_input_redraw_request(), "nearby same-visual hover motion should not redraw")

	var distant_hover_motion := _make_motion(Vector2(58.0, 20.0))
	_expect(overlay.handle_input(distant_hover_motion, null, null, Vector2(1280.0, 720.0)), "distant hover mouse motion should be handled")
	_expect(overlay.consume_input_redraw_request(), "distant same-visual hover motion should redraw to refresh tooltip placement")

	var leave_hover_motion := _make_motion(Vector2(120.0, 20.0))
	_expect(overlay.handle_input(leave_hover_motion, null, null, Vector2(1280.0, 720.0)), "leaving hover visual should be handled")
	_expect(overlay.consume_input_redraw_request(), "leaving a character info hover visual should redraw once to clear it")


func _verify_character_info_hover_signature_is_section_gated() -> void:
	var overlay := CharacterInfoOverlay.new()
	overlay.set("_last_equipment_rect", Rect2(Vector2.ZERO, Vector2(80.0, 80.0)))
	overlay.set("_last_equipment_slot_rects", {"head": Rect2(Vector2(10.0, 10.0), Vector2(20.0, 20.0))})
	overlay.set("_last_skill_rect", Rect2(Vector2(100.0, 0.0), Vector2(80.0, 80.0)))
	overlay._set_skill_slot_hover_layout(Vector2(110.0, 10.0), 20.0, 26.0, 1)
	overlay.set("_last_active_items_rect", Rect2(Vector2(200.0, 0.0), Vector2(80.0, 80.0)))
	overlay._set_active_slot_hover_layout(Vector2(210.0, 10.0), 20.0, 26.0, 1)
	overlay.set("_last_passive_inventory_rect", Rect2(Vector2(0.0, 100.0), Vector2(160.0, 100.0)))
	overlay.set("_last_passive_inventory_grid_rect", Rect2(Vector2(0.0, 100.0), Vector2(160.0, 100.0)))
	overlay._set_passive_grid_hover_layout(Vector2(10.0, 110.0), 20.0, 26.0, 1, 1)
	overlay.set("_last_perk_grid_rect", Rect2(Vector2(200.0, 100.0), Vector2(160.0, 100.0)))
	overlay._set_perk_grid_hover_layout(Vector2(210.0, 110.0), 20.0, 26.0, 1, 1)
	var source := _character_info_overlay_source()
	var hover_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_hover_geometry.gd")
	var value_utils_source := _character_info_value_utils_contract_source()
	var skill_slot_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_skill_slot_presenter.gd")
	var active_item_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_active_item_presenter.gd")
	var passive_item_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_passive_item_presenter.gd")
	var perk_presenter_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_perk_presenter.gd")
	var equipment_drawer_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_equipment_drawer.gd")
	var skill_layout_body := _function_body(value_utils_source, "static func refresh_skill_slot_layout_arrays(")
	var active_layout_body := _function_body(value_utils_source, "static func refresh_active_slot_layout_arrays(")
	var skill_overlay_layout_body := _function_body(skill_slot_presenter_source, "static func update_overlay_layout(")
	var active_overlay_layout_body := _function_body(active_item_presenter_source, "static func update_overlay_slot_layout(")
	var passive_grid_layout_body := _function_body(value_utils_source, "static func refresh_passive_inventory_grid_layout_arrays(")
	var perk_grid_layout_body := _function_body(value_utils_source, "static func refresh_perk_grid_layout_arrays(")
	var passive_overlay_grid_body := _function_body(passive_item_presenter_source, "static func update_overlay_grid_layout(")
	var perk_overlay_grid_body := _function_body(perk_presenter_source, "static func update_overlay_grid_layout(")
	_expect(_function_body(hover_source, "static func overlay_hover_signature(").find("get_cached_grid_hover_signature(") >= 0, "character info hover should use cached grid metrics before rect scans")
	_expect(_function_body(hover_source, "static func overlay_hover_signature(").find("get_cached_linear_hover_signature(") >= 0, "character info slot hover should use cached linear metrics before rect scans")
	_expect(source.find("func _get_cached_grid_hover_signature(") < 0, "character info hover should not keep overlay grid hover wrapper")
	_expect(source.find("func _get_cached_linear_hover_signature(") < 0, "character info hover should not keep overlay linear hover wrapper")
	_expect(_function_body(hover_source, "static func get_cached_grid_hover_signature(").find("% [prefix, index]") < 0, "grid hover signature should avoid format arrays")
	_expect(_function_body(hover_source, "static func get_cached_linear_hover_signature(").find("% [prefix, index]") < 0, "linear hover signature should avoid format arrays")
	_expect(_function_body(hover_source, "static func get_rect_map_hover_signature(").find("% [prefix, str(key_value)]") < 0, "rect-map hover fallback should avoid format arrays")
	_expect(
		skill_overlay_layout_body.find("target.set(\"_last_skill_slot_start\", layout_state.get(\"start\", Vector2.ZERO))") >= 0
		and skill_overlay_layout_body.find("target.set(\"_last_skill_slot_count\", max_slots)") >= 0
		and skill_layout_body.find("\"start\": Vector2(start_x, slot_y)") >= 0,
		"skill slot hover metrics should be cached during draw"
	)
	_expect(
		active_overlay_layout_body.find("target.set(\"_last_active_slot_start\", layout_state.get(\"start\", Vector2.ZERO))") >= 0
		and active_overlay_layout_body.find("target.set(\"_last_active_slot_count\", max_slots)") >= 0
		and active_layout_body.find("\"start\": Vector2(active_slot_start_x, y)") >= 0,
		"active-item slot hover metrics should be cached during draw"
	)
	_expect(source.find("_last_skill_slot_rects") < 0, "skill slot draw should not keep rect dictionaries after linear hover metrics are cached")
	_expect(source.find("_last_active_item_slot_rects") < 0, "active-item slot draw should not keep rect dictionaries after linear hover metrics are cached")
	_expect(source.find("func _get_equipment_hover_signature(mouse_pos: Vector2) -> String:") >= 0, "equipment hover signature should use an indexed helper before dictionary fallback")
	_expect(source.find("func _equipment_signature_contains_mouse(key_text: String, mouse_pos: Vector2) -> bool:") >= 0, "equipment hover reuse should use indexed slot rects before dictionary fallback")
	_expect(source.find("var _equipment_hover_uses_indexed_layout := false") >= 0, "equipment hover should track when indexed slot layout is the active source")
	_expect(source.find("func _has_indexed_equipment_hover_layout() -> bool:") >= 0, "equipment hover should gate stale rect-map fallback behind indexed layout state")
	_expect(_function_body(source, "func _get_hover_signature(").find("CharacterInfoOverlayHoverGeometry.overlay_hover_signature(") >= 0, "equipment hover should avoid scanning the slot rect dictionary on the hot path")
	_expect(_function_body(hover_source, "static func overlay_hover_signature(").find("var equipment_signature: String = str(equipment_signature_callable.call(mouse_pos))") >= 0, "equipment hover should delegate equipment signature resolution through the cached helper")
	_expect(_function_body(source, "func _hover_signature_contains_mouse(").find("CharacterInfoOverlayHoverGeometry.overlay_signature_contains_mouse(") >= 0, "equipment hover reuse should avoid dictionary lookup on the hot path")
	_expect(_function_body(hover_source, "static func overlay_signature_contains_mouse(").find("equipment_contains_callable.call(key_text, mouse_pos)") >= 0, "equipment hover reuse should delegate equipment checks through the cached helper")
	_expect(_function_body(source, "func _get_equipment_hover_signature(").find("var slot_index: int = _find_hovered_equipment_slot_index(mouse_pos)") >= 0, "equipment hover signature should resolve the cached slot index first")
	_expect(_function_body(source, "func _get_equipment_hover_signature(").find("CharacterInfoOverlayHoverGeometry.equipment_hover_signature(") >= 0, "equipment hover signature should delegate indexed fallback gating to hover geometry")
	_expect(_function_body(hover_source, "static func equipment_hover_signature(").find("if has_indexed_layout:\n\t\treturn \"\"") >= 0, "equipment hover signature should skip rect-map fallback after indexed misses")
	_expect(_function_body(source, "func _equipment_signature_contains_mouse(").find("CharacterInfoOverlayHoverGeometry.equipment_signature_contains_mouse(") >= 0, "equipment hover reuse should delegate indexed rect checks to hover geometry")
	_expect(_function_body(hover_source, "static func equipment_signature_contains_mouse(").find("index_cache.get(key_text, -1)") >= 0, "equipment hover reuse should map slot keys through the cached index table")
	_expect(_function_body(hover_source, "static func equipment_signature_contains_mouse(").find("if has_indexed_layout:\n\t\treturn false") >= 0, "equipment hover reuse should skip stale rect-map checks after indexed misses")
	_expect(_function_body(equipment_drawer_source, "static func slot_key_at_index_or_mouse(").find("if has_indexed_layout:\n\t\treturn \"\"") >= 0, "equipment context lookup should skip rect-map fallback after indexed misses")
	_expect(source.find("_update_passive_inventory_grid_layout(grid_rect, cell_size, stride, columns, inventory_items.size(), passive_inventory_scroll)") >= 0, "passive inventory hover metrics should be cached during draw")
	_expect(
		passive_overlay_grid_body.find("target.set(\"_last_passive_grid_start\", layout_state.get(\"start\", Vector2.ZERO))") >= 0
		and passive_overlay_grid_body.find("target.set(\"_last_passive_grid_item_count\", item_count)") >= 0
		and passive_grid_layout_body.find("\"start\": Vector2(start_x, start_y)") >= 0,
		"passive inventory layout helper should publish cached hover metrics"
	)
	_expect(source.find("_update_perk_grid_layout(grid_rect, cell_size, stride, columns, acquired.size(), perk_scroll)") >= 0, "perk grid hover metrics should be cached during draw")
	_expect(
		perk_overlay_grid_body.find("target.set(\"_last_perk_grid_start\", layout_state.get(\"start\", Vector2.ZERO))") >= 0
		and perk_overlay_grid_body.find("target.set(\"_last_perk_grid_item_count\", item_count)") >= 0
		and perk_grid_layout_body.find("\"start\": Vector2(start_x, start_y)") >= 0,
		"perk grid layout helper should publish cached hover metrics"
	)
	_expect(source.find("_last_passive_inventory_item_rects") < 0, "passive inventory draw should not keep rect dictionaries after grid hover metrics are cached")
	_expect(source.find("_last_perk_item_rects") < 0, "perk grid draw should not keep rect dictionaries after grid hover metrics are cached")

	_expect(overlay._get_hover_signature(Vector2(12.0, 12.0)) == "equipment:head", "equipment hover signature should remain available inside the equipment section")
	_expect(overlay._get_hover_signature(Vector2(112.0, 12.0)) == "skill:0", "skill hover signature should remain available inside the skill section")
	_expect(overlay._get_hover_signature(Vector2(212.0, 12.0)) == "active_item:0", "active item hover signature should remain available inside the active-item section")
	_expect(overlay._get_hover_signature(Vector2(12.0, 112.0)) == "passive_item:0", "passive inventory item hover signature should remain available inside the inventory section")
	_expect(overlay._get_hover_signature(Vector2(212.0, 112.0)) == "perk:0", "perk hover signature should remain available inside the perk section")
	overlay.set("_last_hover_signature", "perk:0")
	_expect(overlay._get_hover_signature(Vector2(214.0, 114.0)) == "perk:0", "unchanged hover signature should reuse the previous rect before scanning sections")
	overlay.set("_last_equipment_slot_rects", {"head": Rect2(Vector2(320.0, 20.0), Vector2(20.0, 20.0))})
	_expect(overlay._get_hover_signature(Vector2(322.0, 22.0)) == "", "equipment slots outside the equipment section should not force a hover scan")

	var indexed_overlay := CharacterInfoOverlay.new()
	var indexed_slot_keys: Array[String] = ["head"]
	var indexed_slot_rects: Array[Rect2] = [Rect2(Vector2(10.0, 10.0), Vector2(20.0, 20.0))]
	indexed_overlay.set("_last_equipment_rect", Rect2(Vector2.ZERO, Vector2(80.0, 80.0)))
	indexed_overlay.set("_equipment_slot_keys", indexed_slot_keys)
	indexed_overlay.set("_equipment_slot_rect_list_cache", indexed_slot_rects)
	indexed_overlay.set("_last_equipment_slot_rects", {"stale": Rect2(Vector2(40.0, 40.0), Vector2(20.0, 20.0))})
	indexed_overlay.set("_equipment_hover_uses_indexed_layout", true)
	indexed_overlay.set("_last_hover_signature", "equipment:stale")
	_expect(indexed_overlay._get_hover_signature(Vector2(45.0, 45.0)) == "", "indexed equipment hover should ignore stale rect-map fallback inside the section")


func _verify_character_info_open_animation_consumes_pending_redraw() -> void:
	var overlay := CharacterInfoOverlay.new()
	var lifecycle_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lifecycle.gd")
	_expect(_function_body(lifecycle_source, "static func update(").find("if next_animation_time >= open_animation_duration:\n\t\t\ttarget.set(\"_redraw_requested\", false)") >= 0, "character info open animation should consume the pending open redraw on its final frame")
	overlay.open()
	_expect(overlay.update(1.0), "character info open animation should request its final redraw")
	_expect(not overlay.update(0.016), "settled character info overlay should not queue one extra redraw after the open animation")
	overlay.set("_lingpet_panel_live2d_redraw_active", true)
	var live2d_time_before: float = float(overlay.get("lingpet_panel_live2d_time"))
	_expect(overlay.update(0.125), "settled character info overlay should redraw while a lingpet panel Live2D is visible")
	_expect(float(overlay.get("lingpet_panel_live2d_time")) > live2d_time_before, "lingpet panel Live2D timer should advance only through the overlay lifecycle")
	overlay.close()
	_expect(not bool(overlay.get("_lingpet_panel_live2d_redraw_active")), "closing character info should stop lingpet panel Live2D redraws")


func _verify_character_info_context_click_queues_single_redraw() -> void:
	var input := BattleSceneOverlayInputController.new()
	var owner := FakeOwner.new()
	var overlay := CharacterInfoOverlay.new()
	var runtime := FakeMythicRuntime.new()
	var registry := FakeRegistry.new()
	registry.mythic_item_runtime = runtime
	overlay.open()
	overlay.consume_input_redraw_request()
	overlay.set("_last_passive_inventory_rect", Rect2(Vector2.ZERO, Vector2(120.0, 120.0)))
	overlay.set("_last_passive_inventory_grid_rect", Rect2(Vector2.ZERO, Vector2(120.0, 120.0)))
	overlay._set_passive_grid_hover_layout(Vector2(8.0, 8.0), 44.0, 52.0, 1, 1)
	_modules = {
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"character_info_overlay": overlay,
	}

	_expect(
		bool(input.handle_input(_mouse_button(Vector2(24.0, 24.0), MOUSE_BUTTON_RIGHT), owner, registry, Callable(self, "_get_module"), {})),
		"character info context click should be consumed"
	)
	_expect(runtime.toggle_calls == 1, "character info context click should reach the inventory runtime once")
	_expect(owner.redraw_count == 1, "changed character info context click should queue exactly one redraw")
	_expect(not overlay.consume_input_redraw_request(), "input controller should consume the context-click redraw request")


func _verify_character_info_equipment_context_click_is_section_gated() -> void:
	var overlay := CharacterInfoOverlay.new()
	var owner := FakeOwner.new()
	var runtime := FakeMythicRuntime.new()
	var registry := FakeRegistry.new()
	registry.mythic_item_runtime = runtime
	overlay.open()
	overlay.consume_input_redraw_request()
	overlay.set("_last_equipment_rect", Rect2(Vector2.ZERO, Vector2(80.0, 80.0)))
	overlay.set("_last_equipment_slot_rects", {"head": Rect2(Vector2(120.0, 10.0), Vector2(40.0, 40.0))})

	_expect(
		overlay.handle_input(_mouse_button(Vector2(130.0, 20.0), MOUSE_BUTTON_RIGHT), owner, registry, Vector2(1280.0, 720.0)),
		"character info equipment context click outside the section should still be consumed"
	)
	_expect(runtime.unequip_calls == 0, "equipment context click outside the equipment section should not scan or unequip stale slots")
	_expect(not overlay.consume_input_redraw_request(), "unchanged equipment context click should not request redraw")


func _verify_character_info_equipment_context_click_uses_index_cache() -> void:
	var overlay := CharacterInfoOverlay.new()
	var owner := FakeOwner.new()
	var runtime := FakeMythicRuntime.new()
	var registry := FakeRegistry.new()
	var slot_keys: Array[String] = ["head"]
	var slot_rects: Array[Rect2] = [Rect2(Vector2(10.0, 10.0), Vector2(40.0, 40.0))]
	registry.mythic_item_runtime = runtime
	overlay.open()
	overlay.consume_input_redraw_request()
	overlay.set("_last_equipment_rect", Rect2(Vector2.ZERO, Vector2(80.0, 80.0)))
	overlay.set("_equipment_slot_keys", slot_keys)
	overlay.set("_equipment_slot_rect_list_cache", slot_rects)
	overlay.set("_last_equipment_slot_rects", {})

	_expect(
		overlay.handle_input(_mouse_button(Vector2(20.0, 20.0), MOUSE_BUTTON_RIGHT), owner, registry, Vector2(1280.0, 720.0)),
		"character info equipment context click should be consumed"
	)
	_expect(runtime.unequip_calls == 1, "equipment context click should unequip through the cached slot index")
	_expect(runtime.last_unequip_slot == "head", "equipment context click should resolve the cached slot key without a rect dictionary")
	_expect(overlay.consume_input_redraw_request(), "changed equipment context click should request redraw")


func _motion(input: Object, owner: Object, position: Vector2) -> bool:
	return bool(input.handle_input(_make_motion(position), owner, null, Callable(self, "_get_module"), {}))


func _make_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _mouse_button(position: Vector2, button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = button_index
	event.pressed = true
	return event


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _character_info_overlay_source() -> String:
	return FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_state.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_core.gd")


func _character_info_value_utils_contract_source() -> String:
	return FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_layout_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_text_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_slot_cache_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_misc_value_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_prewarm_text_utils.gd") + "\n" + FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_value_utils.gd")


func _function_body(source: String, marker: String) -> String:
	var start: int = source.find(marker)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + marker.length())
	var next_static_func: int = source.find("\nstatic func ", start + marker.length())
	var next: int = next_func
	if next < 0 or (next_static_func >= 0 and next_static_func < next):
		next = next_static_func
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
