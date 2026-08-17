extends RefCounted

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)

const MAP_OVERLAY_KEY := KEY_M


func handle_open_shortcut(
	event: InputEvent,
	owner: Object,
	registry: Object
) -> bool:
	if not _is_map_toggle_event(event):
		return false
	if not TowerAscentFeatureFlags.is_vertical_slice_enabled():
		return false
	var flow_owner := _get_instance(registry, "tower_ascent_flow_owner")
	if flow_owner == null or not flow_owner.has_method("open_map_overlay"):
		return false
	var opened := bool(flow_owner.call(
		"open_map_overlay",
		owner,
		registry,
		{"current_stage": _get_owner_int(owner, "current_stage", 1)}
	))
	if opened:
		_mark_handled(owner)
	return opened


func _is_map_toggle_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and (
			key_event.keycode == MAP_OVERLAY_KEY
			or key_event.physical_keycode == MAP_OVERLAY_KEY
		)
	)


func _get_owner_int(owner: Object, property_name: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(property_name)
	return fallback if value == null else int(value)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null


func _mark_handled(owner: Object) -> void:
	if owner == null or not owner.has_method("get_viewport"):
		return
	var viewport: Viewport = owner.call("get_viewport")
	if viewport != null:
		viewport.set_input_as_handled()
