extends RefCounted

const TowerAscentSettlementLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_settlement_localization.gd"
)

const RESULT_STANDARD_CLEAR := "standard_clear"
const RESULT_DEFEAT := "defeat"
const RESULT_TRUE_ENDING := "true_ending"
const VALID_RESULT_KINDS := [RESULT_STANDARD_CLEAR, RESULT_DEFEAT, RESULT_TRUE_ENDING]

var _state: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_state = {
		"active": false,
		"result_kind": "",
		"resolution_id": "",
		"floor": 0,
		"lost_build": {},
		"persistent_income": {},
		"assembly_order": [],
		"dismissed": false,
	}


func open(
	result_kind: String,
	resolution_id: String,
	floor: int,
	lost_build: Dictionary,
	persistent_income: Dictionary
) -> Dictionary:
	var normalized_kind := result_kind.strip_edges().to_lower()
	var normalized_id := resolution_id.strip_edges()
	if normalized_kind not in VALID_RESULT_KINDS:
		return _result(false, false, "invalid_result_kind")
	if normalized_id.is_empty() or floor <= 0:
		return _result(false, false, "invalid_settlement_identity")
	if bool(_state.get("active", false)) or bool(_state.get("dismissed", false)):
		if (
			str(_state.get("resolution_id", "")) == normalized_id
			and str(_state.get("result_kind", "")) == normalized_kind
		):
			return _result(true, false, "already_committed")
		return _result(false, false, "settlement_already_committed")
	_state = {
		"active": true,
		"result_kind": normalized_kind,
		"resolution_id": normalized_id,
		"floor": floor,
		"lost_build": lost_build.duplicate(true),
		"persistent_income": persistent_income.duplicate(true),
		"assembly_order": ["lost_build", "persistent_income"],
		"dismissed": false,
	}
	return _result(true, true, "opened")


func confirm() -> Dictionary:
	if not bool(_state.get("active", false)):
		return _result(false, false, "settlement_inactive")
	_state["active"] = false
	_state["dismissed"] = true
	return _result(true, true, "dismissed")


func is_active() -> bool:
	return bool(_state.get("active", false))


func export_state() -> Dictionary:
	return _state.duplicate(true)


func restore_state(value: Variant) -> bool:
	reset()
	if not (value is Dictionary):
		return false
	var source := value as Dictionary
	var result_kind := str(source.get("result_kind", ""))
	var resolution_id := str(source.get("resolution_id", ""))
	var floor := int(source.get("floor", 0))
	if result_kind not in VALID_RESULT_KINDS or resolution_id.is_empty() or floor <= 0:
		return false
	var order := _string_array(source.get("assembly_order", []))
	if order != ["lost_build", "persistent_income"]:
		return false
	_state = {
		"active": bool(source.get("active", false)),
		"result_kind": result_kind,
		"resolution_id": resolution_id,
		"floor": floor,
		"lost_build": _dictionary(source.get("lost_build", {})),
		"persistent_income": _dictionary(source.get("persistent_income", {})),
		"assembly_order": order,
		"dismissed": bool(source.get("dismissed", false)),
	}
	return bool(_state.get("active", false)) != bool(_state.get("dismissed", false))


func build_view_model() -> Dictionary:
	var result_kind := str(_state.get("result_kind", RESULT_DEFEAT))
	var clear := result_kind == RESULT_STANDARD_CLEAR
	var true_ending := result_kind == RESULT_TRUE_ENDING
	var lost_build := _dictionary(_state.get("lost_build", {}))
	var persistent_income := _dictionary(_state.get("persistent_income", {}))
	return {
		"title": TowerAscentSettlementLocalization.text(_settlement_title_key(clear, true_ending)),
		"body": TowerAscentSettlementLocalization.text(_settlement_body_key(clear, true_ending)),
		"floor_text": "%d층" % int(_state.get("floor", 0)),
		"lost_build_title": TowerAscentSettlementLocalization.text(
			TowerAscentSettlementLocalization.KEY_LOST_BUILD_TITLE
		),
		"lost_build_rows": _string_array(lost_build.get("rows", [])),
		"persistent_income_title": TowerAscentSettlementLocalization.text(
			TowerAscentSettlementLocalization.KEY_PERSISTENT_INCOME_TITLE
		),
		"persistent_income_rows": _string_array(persistent_income.get("rows", [])),
		"prompt": TowerAscentSettlementLocalization.text(
			TowerAscentSettlementLocalization.KEY_PROMPT
		),
		"result_kind": result_kind,
	}


static func build_lost_build_summary(
	run_economy: Dictionary,
	build_state: Dictionary,
	guardian_state: Dictionary
) -> Dictionary:
	var rows: Array[String] = []
	_append_count_row(rows, "무공", build_state.get("mugong", []))
	_append_count_row(rows, "초식", build_state.get("chosik", []))
	_append_count_row(rows, "액티브 아이템", build_state.get("active_items", []))
	var mythic := _static_dictionary(build_state.get("mythic", {}))
	if not mythic.is_empty():
		rows.append("신화 진행 %d종" % mythic.size())
	var active_guardian := _static_dictionary(guardian_state.get("active_guardian", {}))
	if not active_guardian.is_empty():
		rows.append("수호령 1종")
	var muhon := maxi(0, int(run_economy.get("muhon", 0)))
	var gold := maxi(0, int(run_economy.get("gold", 0)))
	if muhon > 0 or gold > 0:
		rows.append(TowerAscentSettlementLocalization.text(
			TowerAscentSettlementLocalization.KEY_LOST_BUILD_CURRENCY_ROW,
			{"muhon": muhon, "gold": gold}
		))
	if rows.is_empty():
		rows.append(TowerAscentSettlementLocalization.text(
			TowerAscentSettlementLocalization.KEY_EMPTY_BUILD
		))
	return {
		"rows": rows,
		"mugong_count": _static_array(build_state.get("mugong", [])).size(),
		"chosik_count": _static_array(build_state.get("chosik", [])).size(),
		"active_item_count": _static_array(build_state.get("active_items", [])).size(),
		"muhon": muhon,
		"gold": gold,
	}


static func build_persistent_income(
	record_snapshot: Dictionary,
	codex_discoveries: Array[Dictionary]
) -> Dictionary:
	var rows: Array[String] = []
	var discovery_names: Array[String] = []
	for discovery in codex_discoveries:
		var name := str(discovery.get("display_name", discovery.get("pet_id", ""))).strip_edges()
		if not name.is_empty() and not discovery_names.has(name):
			discovery_names.append(name)
	if discovery_names.is_empty():
		rows.append(TowerAscentSettlementLocalization.text(
			TowerAscentSettlementLocalization.KEY_NO_NEW_DISCOVERY
		))
	else:
		rows.append("도감 신규 등록 %d종 · %s" % [discovery_names.size(), ", ".join(discovery_names)])
	rows.append("최고 층 기록 %d층" % maxi(0, int(record_snapshot.get("highest_floor", 0))))
	rows.append("클리어 기록 %d회" % maxi(0, int(record_snapshot.get("clear_count", 0))))
	if bool(record_snapshot.get("undefeated_true_ending_medal", false)):
		rows.append("무패 진엔딩 훈장")
	return {
		"rows": rows,
		"codex_new_discoveries": codex_discoveries.duplicate(true),
		"record_snapshot": record_snapshot.duplicate(true),
	}


static func _append_count_row(rows: Array[String], label: String, value: Variant) -> void:
	var count := _static_array(value).size()
	if count > 0:
		rows.append("%s %d종" % [label, count])


static func _static_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


static func _static_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result


func _result(accepted: bool, changed: bool, reason: String) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason": reason,
		"state": export_state(),
	}


func _settlement_title_key(clear: bool, true_ending: bool) -> String:
	if true_ending:
		return TowerAscentSettlementLocalization.KEY_TRUE_ENDING_TITLE
	return (
		TowerAscentSettlementLocalization.KEY_CLEAR_TITLE
		if clear
		else TowerAscentSettlementLocalization.KEY_DEFEAT_TITLE
	)


func _settlement_body_key(clear: bool, true_ending: bool) -> String:
	if true_ending:
		return TowerAscentSettlementLocalization.KEY_TRUE_ENDING_BODY
	return (
		TowerAscentSettlementLocalization.KEY_CLEAR_BODY
		if clear
		else TowerAscentSettlementLocalization.KEY_DEFEAT_BODY
	)
