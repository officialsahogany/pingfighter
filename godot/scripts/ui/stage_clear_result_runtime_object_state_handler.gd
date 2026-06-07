extends RefCounted

const RUNTIME_OBJECT_KEYS := [
	"runtime_perk_state",
	"runtime_perk_catalog",
	"runtime_perk_icon_renderer",
	"runtime_perk_owner",
	"runtime_perk_registry",
	"mythic_item_runtime",
	"treasure_hunt_runtime",
	"game_audio",
]


static func get_runtime_object_state(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for object_key in RUNTIME_OBJECT_KEYS:
		var key: String = str(object_key)
		var object_value: Variant = data.get(key, null)
		result[key] = _valid_object_or_null(object_value)
	return result


static func get_runtime_object_apply_result(runtime_object_state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for object_key in RUNTIME_OBJECT_KEYS:
		var key: String = str(object_key)
		result["_" + key] = _valid_object_or_null(runtime_object_state.get(key, null))
	return result


static func get_runtime_object_scene_apply_result(runtime_object_state: Dictionary) -> Dictionary:
	return {
		"field_payload": get_runtime_object_apply_result(runtime_object_state),
	}


static func _valid_object_or_null(value: Variant) -> Object:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null
