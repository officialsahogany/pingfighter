extends SceneTree

const PlazaTransactionSummaryStore := preload("res://scripts/plaza/plaza_transaction_summary_store.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_scene_finalizer_contract()
	var store := PlazaTransactionSummaryStore.new()
	var source := {"changed": true, "nested": {"value": 3}}
	store.record(PlazaTransactionSummaryStore.SHOP, source)
	(source["nested"] as Dictionary)["value"] = 99
	_expect(int((store.get_summary(PlazaTransactionSummaryStore.SHOP).get("nested", {}) as Dictionary).get("value", 0)) == 3, "record should deep-copy")
	var returned := store.get_summary(PlazaTransactionSummaryStore.SHOP)
	(returned["nested"] as Dictionary)["value"] = 77
	_expect(int((store.get_summary(PlazaTransactionSummaryStore.SHOP).get("nested", {}) as Dictionary).get("value", 0)) == 3, "get should deep-copy")
	store.record("unknown", {"value": 1})
	_expect(store.get_summary("unknown").is_empty(), "unknown facility should be ignored")

	for facility in PlazaTransactionSummaryStore.FACILITY_KEYS:
		store.record(str(facility), {"facility": facility})
	store.clear_on_menu_close()
	_expect(not store.get_summary(PlazaTransactionSummaryStore.BANK).is_empty(), "bank summary should survive menu close")
	_expect(not store.get_summary(PlazaTransactionSummaryStore.ACADEMY).is_empty(), "academy summary should survive overlay handoff")
	for facility in PlazaTransactionSummaryStore.CLEAR_ON_MENU_CLOSE:
		_expect(store.get_summary(str(facility)).is_empty(), "%s summary should clear on menu close" % facility)

	store.clear_all()
	for facility in PlazaTransactionSummaryStore.FACILITY_KEYS:
		_expect(store.get_summary(str(facility)).is_empty(), "%s summary should clear for a new visit" % facility)

	if _failures.is_empty():
		print("plaza_transaction_summary_store_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_scene_finalizer_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(source.count("_apply_facility_transaction_outcome(") == 8, "seven facilities should share one transaction finalizer")
	_expect(source.count("mark_visit_ap_consumed()") == 1, "visit AP state should be finalized in one place")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
