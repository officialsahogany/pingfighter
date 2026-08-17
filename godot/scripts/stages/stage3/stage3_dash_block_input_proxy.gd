extends RefCounted

var source_reader: Object = null
var stage3_boss_skill_state: Object = null


func configure(input_reader: Object, skill_state: Object) -> Object:
	source_reader = input_reader
	stage3_boss_skill_state = skill_state
	return self


func get_snapshot() -> Dictionary:
	var snapshot := _read_source_snapshot()
	if not _is_deadly_hug_dash_blocked():
		return snapshot
	# This proxy is supplied only through the dedicated dash_input_reader lane.
	# Preserve movement/action input while suppressing the down-edge consumed by dash.
	snapshot["down_pressed"] = false
	snapshot["dash_blocked"] = true
	return snapshot


func _read_source_snapshot() -> Dictionary:
	if source_reader == null or not source_reader.has_method("get_snapshot"):
		return {}
	var value: Variant = source_reader.get_snapshot()
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _is_deadly_hug_dash_blocked() -> bool:
	return (
		stage3_boss_skill_state != null
		and stage3_boss_skill_state.has_method("is_deadly_hug_dash_blocked")
		and bool(stage3_boss_skill_state.is_deadly_hug_dash_blocked())
	)
