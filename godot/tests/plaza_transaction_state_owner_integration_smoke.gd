extends SceneTree

const SCENE_PATH := "res://scripts/plaza/plaza_scene.gd"

const FACILITY_TRIGGERS := {
	"_trigger_bank_menu_action": "BANK",
	"_trigger_shop_trade_action": "SHOP",
	"_trigger_gacha_menu_action": "GACHA",
	"_trigger_lingpet_store_menu_action": "LINGPET_STORE",
	"_trigger_blacksmith_menu_action": "BLACKSMITH",
	"_trigger_academy_menu_action": "ACADEMY",
	"_trigger_tavern_menu_action": "TAVERN",
}

var _failures: Array[String] = []


func _init() -> void:
	var source := FileAccess.get_file_as_string(SCENE_PATH)
	_expect(source.contains("var _menu_session: PlazaBuildingMenuSessionState"), "menu session should be statically owned")
	_expect(source.contains("var _transaction_summaries: PlazaTransactionSummaryStore"), "transaction summaries should be statically owned")
	for legacy_field in [
		"var _menu_open",
		"var _active_menu_type",
		"var _active_menu_title",
		"var _active_menu_subtitle",
		"var _active_menu_actions",
		"var _active_menu_last_message",
		"var _active_menu_visit_ap_consumed",
		"var _last_bank_transaction_summary",
		"var _last_shop_transaction_summary",
		"var _last_blacksmith_transaction_summary",
		"var _last_gacha_transaction_summary",
		"var _last_lingpet_store_transaction_summary",
		"var _last_academy_transaction_summary",
		"var _last_tavern_transaction_summary",
	]:
		_expect(not source.contains(legacy_field), "scene should not restore mirror field %s" % legacy_field)
	var finalizer_body := _function_body(source, "_apply_facility_transaction_outcome")
	_expect(finalizer_body.contains("_transaction_summaries.record(facility, summary)"), "shared finalizer should record the facility summary")
	_expect(finalizer_body.contains("_menu_session.mark_visit_ap_consumed()"), "shared finalizer should own the visit AP edge")
	for raw_method in FACILITY_TRIGGERS:
		var method := str(raw_method)
		var facility := str(FACILITY_TRIGGERS[raw_method])
		var body := _function_body(source, method)
		_expect(body.contains("_apply_facility_transaction_outcome("), "%s should use the shared finalizer" % method)
		_expect(body.contains("PlazaTransactionSummaryStore.%s" % facility), "%s should record under %s" % [method, facility])

	if _failures.is_empty():
		print("plaza_transaction_state_owner_integration_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _function_body(source: String, method: String) -> String:
	var start := source.find("func %s(" % method)
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + method.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
