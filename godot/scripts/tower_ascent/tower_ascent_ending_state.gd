extends RefCounted

const TowerAscentEndingLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_ending_localization.gd"
)
const TowerAscentRecordStore := preload(
	"res://scripts/tower_ascent/tower_ascent_record_store.gd"
)

const JUDGMENT_NONE := ""
const JUDGMENT_STANDARD_CLEAR := "standard_clear"
const JUDGMENT_CHOICE_REQUIRED := "choice_required"
const CHOICE_DESCEND := "descend"
const CHOICE_CONTINUE := "continue"

var _resolution_id := ""
var _judgment := JUDGMENT_NONE
var _teaser_required := false
var _teaser_presented := false
var _choice_required := false
var _choice := ""
var _route_unlocked := false
var _terminal_committed := false
var _selected_choice_index := 0


func reset() -> void:
	_resolution_id = ""
	_judgment = JUDGMENT_NONE
	_teaser_required = false
	_teaser_presented = false
	_choice_required = false
	_choice = ""
	_route_unlocked = false
	_terminal_committed = false
	_selected_choice_index = 0


func resolve_floor_nine(
	run_id: String,
	resolution_id: String,
	record_store: Object
) -> Dictionary:
	var normalized_run_id := run_id.strip_edges()
	var normalized_resolution_id := resolution_id.strip_edges()
	if normalized_run_id.is_empty():
		return _result(false, false, "invalid_run_id")
	if normalized_resolution_id.is_empty():
		return _result(false, false, "invalid_resolution_id")
	if not _resolution_id.is_empty():
		if _resolution_id != normalized_resolution_id:
			return _result(false, false, "resolution_id_conflict")
		return _result(true, false, "already_resolved")
	if (
		record_store == null
		or not record_store.has_method("has_fake_ending_clear")
		or not record_store.has_method("record_clear")
	):
		return _result(false, false, "record_store_unavailable")

	_resolution_id = normalized_resolution_id
	if bool(record_store.call("has_fake_ending_clear")):
		_judgment = JUDGMENT_CHOICE_REQUIRED
		_choice_required = true
		return _result(true, true, "choice_required")

	var record_result: Dictionary = record_store.call(
		"record_clear",
		9,
		TowerAscentRecordStore.ENDING_STANDARD,
		false,
		"%s:standard_clear" % normalized_resolution_id
	)
	if not bool(record_result.get("accepted", false)):
		reset()
		return _result(false, false, str(record_result.get("reason", "record_commit_failed")))
	_judgment = JUDGMENT_STANDARD_CLEAR
	_teaser_required = true
	_terminal_committed = true
	return _result(true, true, "standard_clear_committed")


func mark_teaser_presented() -> Dictionary:
	if _judgment != JUDGMENT_STANDARD_CLEAR or not _teaser_required:
		return _result(false, false, "teaser_not_required")
	if _teaser_presented:
		return _result(true, false, "already_presented")
	_teaser_presented = true
	return _result(true, true, "teaser_presented")


func move_choice_selection(direction: int) -> void:
	if direction != 0:
		_selected_choice_index = posmod(_selected_choice_index + signi(direction), 2)


func select_choice_index(index: int) -> bool:
	if index < 0 or index >= 2:
		return false
	_selected_choice_index = index
	return true


func get_selected_choice() -> String:
	return CHOICE_DESCEND if _selected_choice_index <= 0 else CHOICE_CONTINUE


func commit_choice(choice: String, record_store: Object) -> Dictionary:
	var normalized_choice := choice.strip_edges().to_lower()
	if _judgment != JUDGMENT_CHOICE_REQUIRED:
		return _result(false, false, "choice_not_available")
	if normalized_choice not in [CHOICE_DESCEND, CHOICE_CONTINUE]:
		return _result(false, false, "invalid_choice")
	if not _choice.is_empty():
		if _choice != normalized_choice:
			return _result(false, false, "choice_is_irreversible")
		return _result(true, false, "already_committed")
	if normalized_choice == CHOICE_DESCEND:
		if record_store == null or not record_store.has_method("record_clear"):
			return _result(false, false, "record_store_unavailable")
		var record_result: Dictionary = record_store.call(
			"record_clear",
			9,
			TowerAscentRecordStore.ENDING_STANDARD,
			false,
			"%s:standard_clear" % _resolution_id
		)
		if not bool(record_result.get("accepted", false)):
			return _result(false, false, str(record_result.get("reason", "record_commit_failed")))
	_choice = normalized_choice
	_choice_required = false
	_route_unlocked = normalized_choice == CHOICE_CONTINUE
	_terminal_committed = normalized_choice == CHOICE_DESCEND
	return _result(true, true, "choice_committed")


func is_teaser_pending() -> bool:
	return _teaser_required and not _teaser_presented


func export_state() -> Dictionary:
	return {
		"resolution_id": _resolution_id,
		"judgment": _judgment,
		"teaser_required": _teaser_required,
		"teaser_presented": _teaser_presented,
		"choice_required": _choice_required,
		"choice": _choice,
		"route_unlocked": _route_unlocked,
		"terminal_committed": _terminal_committed,
		"selected_choice_index": _selected_choice_index,
	}


func restore_state(value: Variant) -> bool:
	reset()
	if not (value is Dictionary):
		return true
	var source := value as Dictionary
	var judgment := str(source.get("judgment", JUDGMENT_NONE))
	if judgment not in [JUDGMENT_NONE, JUDGMENT_STANDARD_CLEAR, JUDGMENT_CHOICE_REQUIRED]:
		return false
	_resolution_id = str(source.get("resolution_id", "")).strip_edges()
	_judgment = judgment
	_teaser_required = bool(source.get("teaser_required", false))
	_teaser_presented = bool(source.get("teaser_presented", false))
	_choice_required = bool(source.get("choice_required", false))
	_choice = str(source.get("choice", "")).strip_edges()
	_route_unlocked = bool(source.get("route_unlocked", false))
	_terminal_committed = bool(source.get("terminal_committed", false))
	_selected_choice_index = clampi(int(source.get("selected_choice_index", 0)), 0, 1)
	if _judgment == JUDGMENT_NONE:
		return _resolution_id.is_empty()
	if _resolution_id.is_empty():
		return false
	if _judgment == JUDGMENT_STANDARD_CLEAR:
		return _teaser_required and _terminal_committed and not _choice_required
	if _choice.is_empty():
		return _choice_required and not _terminal_committed and not _route_unlocked
	if _choice == CHOICE_DESCEND:
		return not _choice_required and _terminal_committed and not _route_unlocked
	if _choice == CHOICE_CONTINUE:
		return not _choice_required and not _terminal_committed and _route_unlocked
	return false


func build_teaser_view_model() -> Dictionary:
	return {
		"title": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_TEASER_TITLE),
		"body": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_TEASER_BODY),
		"prompt": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_TEASER_PROMPT),
	}


func build_choice_view_model() -> Dictionary:
	return {
		"title": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_CHOICE_TITLE),
		"body": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_CHOICE_BODY),
		"prompt": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_CHOICE_PROMPT),
		"selected_index": _selected_choice_index,
		"actions": [
			{
				"id": CHOICE_DESCEND,
				"label": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_CHOICE_DESCEND),
			},
			{
				"id": CHOICE_CONTINUE,
				"label": TowerAscentEndingLocalization.text(TowerAscentEndingLocalization.KEY_CHOICE_CONTINUE),
			},
		],
	}


func _result(accepted: bool, changed: bool, reason: String) -> Dictionary:
	return {
		"accepted": accepted,
		"changed": changed,
		"reason": reason,
		"state": export_state(),
	}
