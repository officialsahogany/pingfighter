extends RefCounted


static func get_field_payload_from_apply_result(apply_result: Dictionary) -> Dictionary:
	var field_payload_value: Variant = apply_result.get("field_payload", {})
	return field_payload_value if field_payload_value is Dictionary else {}


static func apply_field_payload(
	target: Object,
	field_payload: Dictionary,
	field_name_lookup: Dictionary,
	error_prefix: String = "Scene"
) -> void:
	if target == null:
		return
	for property_name in field_payload.keys():
		var field_name: String = str(property_name)
		if not is_valid_field(target, field_name_lookup, field_name):
			push_error("%s: ignoring unknown scene field payload key '%s'" % [error_prefix, field_name])
			continue
		target.set(StringName(field_name), field_payload.get(property_name))


static func apply_from_result(
	target: Object,
	apply_result: Dictionary,
	field_name_lookup: Dictionary,
	error_prefix: String = "Scene"
) -> void:
	apply_field_payload(
		target,
		get_field_payload_from_apply_result(apply_result),
		field_name_lookup,
		error_prefix
	)


static func is_valid_field(target: Object, field_name_lookup: Dictionary, field_name: String) -> bool:
	if target == null or field_name == "":
		return false
	if field_name_lookup.is_empty():
		for property_info in target.get_property_list():
			field_name_lookup[str(property_info.get("name", ""))] = true
	return field_name_lookup.has(field_name)
