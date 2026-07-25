extends SceneTree

const PlazaScenePacked := preload("res://scenes/plaza.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_legacy_fallback_removed()
	_verify_typed_interior_collaborators()
	await _verify_interior_owner_and_recovery()
	if _failures.is_empty():
		print("plaza_interior_single_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_legacy_fallback_removed() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(source.find("func _draw_building_menu") < 0, "plaza shell should not retain the unreachable legacy building-menu renderer")
	_expect(source.find("func _draw_interior_npc_panel") < 0, "plaza shell should not retain the duplicate legacy NPC renderer")
	_expect(source.find("INTERIOR_GREETING_LINES") < 0, "plaza shell should not retain greetings used only by the removed fallback")
	_expect(source.find("MENU_PANEL_RECT") < 0, "plaza shell should not retain fallback-only menu geometry")
	_expect(source.find("_open_interior_view()") >= 0, "plaza shell should keep the dedicated interior owner wiring")


func _verify_typed_interior_collaborators() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_interior_view.gd")
	var owners := {
		"_object_hover_state": "PlazaInteriorObjectHoverState",
		"_object_selection_state": "PlazaInteriorObjectSelectionState",
		"_shop_click_animation": "PlazaShopClickAnimationState",
		"_trade_hover_state": "PlazaTradeHoverState",
		"_trade_scroll_state": "PlazaTradeScrollState",
		"_trade_drag_state": "PlazaTradeDragState",
		"_trade_sell_confirm_state": "PlazaTradeSellConfirmState",
		"_trade_feedback_state": "PlazaTradeFeedbackState",
		"_trade_action_dispatcher": "PlazaTradeActionDispatcher",
		"_trade_item_icon_cache": "PlazaTradeItemIconCache",
	}
	for field_name in owners:
		var type_name := str(owners[field_name])
		_expect(
			source.find("var %s: %s = %s.new()" % [field_name, type_name, type_name]) >= 0,
			"%s should retain its concrete owner type" % field_name
		)


func _verify_interior_owner_and_recovery() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var scene := PlazaScenePacked.instantiate() as Control
	_expect(scene != null, "plaza scene should instantiate")
	if scene == null:
		viewport.queue_free()
		return
	viewport.add_child(scene)
	var save_path := _smoke_save_path()
	_cleanup_save(save_path)
	scene.configure({"current_stage": 1, "plaza_save_path": save_path, "full_layout_for_test": true}, Callable(), true)
	scene.size = Vector2(760.0, 750.0)
	scene.update_plaza(1.0 / 60.0)
	_expect(str(scene.get_status().get("flow_gate", "")) == "street", "configured Plaza should begin on the street gate")
	var bank := _find_building(scene.get_building_specs_for_test(), "bank")
	_expect(not bank.is_empty(), "full Plaza layout should expose the bank")
	if not bank.is_empty():
		var interaction_rect: Rect2 = bank.get("interaction_rect", Rect2())
		var ground_y := float(scene.get_status().get("ground_y", 0.0))
		scene.set_player_pos_for_test(Vector2(interaction_rect.get_center().x, ground_y))
		_expect(scene.trigger_interaction_for_test(), "bank interaction should complete into its interior")
		var status: Dictionary = scene.get_status()
		_expect(bool(status.get("menu_open", false)), "building interaction should open menu state")
		_expect(str(status.get("flow_gate", "")) == "interior_menu", "open building should expose the interior-menu gate")
		_expect(bool(status.get("interior_view_active", false)), "dedicated interior view should own the open menu")
		_expect(_count_interior_views(scene) == 1, "open menu should have exactly one interior owner")

		var old_view := scene.get_node_or_null("PlazaInteriorView")
		var old_instance_id := old_view.get_instance_id() if old_view != null else 0
		if old_view != null:
			old_view.free()
		_expect(not bool(scene.get_status().get("interior_view_active", true)), "forced owner loss should be observable before recovery")
		scene.update_plaza(0.0)
		var recovered_view := scene.get_node_or_null("PlazaInteriorView")
		_expect(recovered_view != null, "menu update should recreate a missing interior owner")
		_expect(recovered_view == null or recovered_view.get_instance_id() != old_instance_id, "recovery should create a fresh interior owner")
		_expect(bool(scene.get_status().get("interior_view_active", false)), "recovered interior should return to active status")
		_expect(str(scene.get_status().get("flow_gate", "")) == "interior_menu", "recovery should preserve the interior-menu gate")
		_expect(_count_interior_views(scene) == 1, "recovery should not duplicate interior owners")

	viewport.queue_free()
	_cleanup_save(save_path)
	await process_frame


func _count_interior_views(scene: Node) -> int:
	var count := 0
	for child in scene.get_children():
		if child.name == &"PlazaInteriorView":
			count += 1
	return count


func _find_building(specs: Array, building_type: String) -> Dictionary:
	for spec_value in specs:
		if spec_value is Dictionary and str((spec_value as Dictionary).get("type", "")) == building_type:
			return spec_value as Dictionary
	return {}


func _smoke_save_path() -> String:
	return "res://.tmp/plaza_interior_single_owner_smoke_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]


func _cleanup_save(path: String) -> void:
	var backup_path := path.trim_suffix(".cfg") + ".last_good.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
