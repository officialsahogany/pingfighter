extends SceneTree

const PlazaBuildingMenuSessionState := preload("res://scripts/plaza/plaza_building_menu_session_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	var state := PlazaBuildingMenuSessionState.new()
	_expect(not state.is_open and state.needs_visit_ap(), "new session defaults")
	state.open_menu("bank", "은행", "금고", ["입금", 2])
	_expect(state.is_open and state.building_type == "bank", "open identity")
	_expect(state.title == "은행" and state.subtitle == "금고", "open copy")
	_expect(state.actions == ["입금", "2"], "action normalization")
	_expect(state.last_message == "" and state.needs_visit_ap(), "open should reset per-visit state")

	state.set_message("입금했습니다.")
	state.mark_visit_ap_consumed()
	_expect(state.last_message == "입금했습니다.", "message update")
	_expect(state.visit_ap_consumed and not state.needs_visit_ap(), "AP consumption update")
	state.set_actions(["출금"])
	_expect(state.actions == ["출금"], "dynamic action replacement")

	state.open_menu("shop", "상점", "거래", ["구매"])
	_expect(state.building_type == "shop" and state.actions == ["구매"], "reopen should replace identity")
	_expect(state.last_message == "" and state.needs_visit_ap(), "reopen should reset visit state")
	state.reset()
	_expect(not state.is_open and state.building_type == "", "reset identity")
	_expect(state.actions.is_empty() and state.last_message == "", "reset presentation")
	_expect(state.needs_visit_ap(), "reset AP state")

	if _failures.is_empty():
		print("plaza_building_menu_session_state_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
