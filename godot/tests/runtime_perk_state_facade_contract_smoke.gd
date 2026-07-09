extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const RUNTIME_PERK_SCRIPT_DIR := "res://scripts/characters"
const RUNTIME_PERK_SCRIPT_PREFIX := "runtime_perk"
const RUNTIME_PERK_SCRIPT_SUFFIX := ".gd"
const RUNTIME_PERK_STATE_SCRIPT := "runtime_perk_state.gd"

const FIELD_REFERENCE_PREFIXES := [
	"runtime_state.get(\"",
	"runtime_state.set(\"",
	"state.get(\"",
	"state.set(\"",
	"_get_runtime_state_object(runtime_state, \"",
	"_get_runtime_state_dict(runtime_state, \"",
	"_get_runtime_state_array(runtime_state, \"",
	"_get_runtime_state_int(runtime_state, \"",
	"_get_runtime_state_float(runtime_state, \"",
	"_get_runtime_state_bool(runtime_state, \"",
	"_get_runtime_state_string(runtime_state, \"",
	"_get_state_object(runtime_state, \"",
	"_get_state_dict(runtime_state, \"",
	"_get_state_int(runtime_state, \"",
	"_get_state_bool(runtime_state, \"",
	"_clear_array_field(runtime_state, \"",
	"_clear_dictionary_field(runtime_state, \"",
	"_apply_latch_update(runtime_state, \"",
	"_consume_navigation_from_runtime_state(runtime_state, \"",
	"_is_runtime_payload_active(runtime_state, \"",
]

const METHOD_REFERENCE_PREFIXES := [
	"Callable(runtime_state, \"",
	"Callable(state, \"",
	"runtime_state.has_method(\"",
	"_build_runtime_state_callable(runtime_state, \"",
	"_call_dict(state, \"",
	"_call_int(state, \"",
	"_call_bool(state, \"",
	"_call_state_dict(runtime_state, \"",
	"_call_state_int(runtime_state, \"",
	"_call_state_float(runtime_state, \"",
	"_call_state_bool(runtime_state, \"",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_runtime_state_facade_references()

	if _failures.is_empty():
		print("runtime_perk_state_facade_contract_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_state_facade_references() -> void:
	var state := RuntimePerkState.new()
	var property_names: Dictionary = _collect_property_names(state)
	var method_names: Dictionary = _collect_method_names(state)
	var field_refs: Dictionary = {}
	var method_refs: Dictionary = {}
	var script_paths: Array[String] = _collect_runtime_perk_script_paths()
	for path in script_paths:
		var source := FileAccess.get_file_as_string(path)
		_collect_literal_refs(source, path, FIELD_REFERENCE_PREFIXES, field_refs)
		_collect_literal_refs(source, path, METHOD_REFERENCE_PREFIXES, method_refs)

	_expect(script_paths.size() >= 40, "facade contract smoke should scan the split runtime-perk helper set")
	_expect(field_refs.size() >= 24, "facade contract smoke should capture runtime-state field references")
	_expect(method_refs.size() >= 30, "facade contract smoke should capture runtime-state method references")
	_expect(field_refs.has("_active_unlock_flight"), "facade field scan should include helper-object fields")
	_expect(field_refs.has("runtime_skill_levels"), "facade field scan should include public data fields")
	_expect(field_refs.has("choice_flight_effect"), "facade field scan should include payload fields")
	_expect(method_refs.has("_get_instance"), "facade method scan should include registry lookup callbacks")
	_expect(method_refs.has("_sync_owner"), "facade method scan should include owner sync callbacks")
	_expect(method_refs.has("choose_selected"), "facade method scan should include state-named modal callbacks")
	_expect(method_refs.has("_apply_convert_to_gold_choice"), "facade method scan should include state-named choice action callbacks")
	_expect(method_refs.has("get_viper_ignition_aura_gold_bonus"), "facade method scan should include state-named snapshot callbacks")
	_expect(method_refs.has("get_player_skill_cooldown_multiplier"), "facade method scan should include public query callbacks")

	for field_name in field_refs.keys():
		_expect(
			property_names.has(field_name),
			"RuntimePerkState field '%s' referenced by helpers but missing on facade: %s" % [
				field_name,
				_join_refs(_get_array(field_refs.get(field_name, []))),
			]
		)
	for method_name in method_refs.keys():
		_expect(
			method_names.has(method_name),
			"RuntimePerkState method '%s' referenced by helpers but missing on facade: %s" % [
				method_name,
				_join_refs(_get_array(method_refs.get(method_name, []))),
			]
		)


func _collect_runtime_perk_script_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(RUNTIME_PERK_SCRIPT_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			if (
				entry.begins_with(RUNTIME_PERK_SCRIPT_PREFIX)
				and entry.ends_with(RUNTIME_PERK_SCRIPT_SUFFIX)
				and entry != RUNTIME_PERK_STATE_SCRIPT
			):
				paths.append(RUNTIME_PERK_SCRIPT_DIR.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func _collect_property_names(state: Object) -> Dictionary:
	var names: Dictionary = {}
	for property_value in state.get_property_list():
		var property: Dictionary = property_value
		var property_name := str(property.get("name", ""))
		if property_name != "":
			names[property_name] = true
	return names


func _collect_method_names(state: Object) -> Dictionary:
	var names: Dictionary = {}
	for method_value in state.get_method_list():
		var method: Dictionary = method_value
		var method_name := str(method.get("name", ""))
		if method_name != "":
			names[method_name] = true
	return names


func _collect_literal_refs(source: String, path: String, prefixes: Array, refs: Dictionary) -> void:
	for prefix_value in prefixes:
		var prefix := str(prefix_value)
		var search_from := 0
		while search_from < source.length():
			var prefix_index := source.find(prefix, search_from)
			if prefix_index < 0:
				break
			if not _has_receiver_boundary(source, prefix_index):
				search_from = prefix_index + prefix.length()
				continue
			if not _should_collect_prefix(source, prefix):
				search_from = prefix_index + prefix.length()
				continue
			var value_start := prefix_index + prefix.length()
			var value_end := source.find("\"", value_start)
			if value_end < 0:
				break
			var ref_name := source.substr(value_start, value_end - value_start)
			if ref_name != "":
				_add_ref(refs, ref_name, path)
			search_from = value_end + 1


func _add_ref(refs: Dictionary, ref_name: String, path: String) -> void:
	if not refs.has(ref_name):
		refs[ref_name] = []
	var entries: Array = _get_array(refs.get(ref_name, []))
	if not entries.has(path):
		entries.append(path)
	refs[ref_name] = entries


func _should_collect_prefix(source: String, prefix: String) -> bool:
	if prefix == "state.get(\"" or prefix == "state.set(\"":
		return source.find("state: Object") >= 0
	return true


func _has_receiver_boundary(source: String, prefix_index: int) -> bool:
	if prefix_index <= 0:
		return true
	return not _is_identifier_char(source.substr(prefix_index - 1, 1))


func _is_identifier_char(value: String) -> bool:
	if value == "_":
		return true
	if value.length() != 1:
		return false
	var code := value.unicode_at(0)
	return (
		(code >= 48 and code <= 57)
		or (code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
	)


func _join_refs(refs: Array) -> String:
	if refs.is_empty():
		return "<no source>"
	var out: Array[String] = []
	for ref_value in refs:
		out.append(str(ref_value))
	return ", ".join(out)


func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
