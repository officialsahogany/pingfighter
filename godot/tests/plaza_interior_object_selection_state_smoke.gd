extends SceneTree

const PlazaInteriorObjectSelectionState := preload("res://scripts/plaza/plaza_interior_object_selection_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaInteriorObjectSelectionState.new()
	_expect(not state.panel_open, "new selection should have a closed panel")
	_expect(not state.open_panel(""), "blank panel selection should be rejected")
	_expect(not state.start_click(""), "blank click selection should be rejected")

	_expect(state.open_panel("bank_deposit"), "valid object should open its panel")
	_expect(state.panel_open, "open_panel should show the panel")
	_expect(state.selected_object_id == "bank_deposit", "open_panel selected id")
	_expect(state.clicked_object_id == "bank_deposit", "open_panel clicked id")
	state.hide_panel()
	_expect(not state.panel_open, "hide_panel should close the panel")
	_expect(state.selected_object_id == "bank_deposit", "hide_panel should retain selection")
	_expect(state.clicked_object_id == "bank_deposit", "hide_panel should retain click flare identity")

	_expect(state.start_click("shop_strewn_coin_pile"), "valid strewn click should update selection")
	_expect(not state.panel_open, "start_click should keep the panel hidden")
	_expect(state.selected_object_id == "shop_strewn_coin_pile", "start_click selected id")
	_expect(state.clicked_object_id == "shop_strewn_coin_pile", "start_click clicked id")
	_expect(state.open_panel("shop_featured_item"), "selection should reopen another panel")
	state.cancel_panel()
	_expect(not state.panel_open, "cancel_panel should close the panel")
	_expect(state.selected_object_id == "", "cancel_panel should clear current selection")
	_expect(state.clicked_object_id == "shop_featured_item", "cancel_panel should retain last click flare identity")

	state.reset()
	_expect(state.selected_object_id == "" and state.clicked_object_id == "", "reset should clear identities")
	_expect(not state.panel_open, "reset should close the panel")

	if _failures.is_empty():
		print("plaza_interior_object_selection_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
