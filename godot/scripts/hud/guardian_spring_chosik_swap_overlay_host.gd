extends RefCounted

const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const RuntimePerkModalInput := preload(
	"res://scripts/characters/runtime_perk_modal_input.gd"
)

var _modal_input: Object = RuntimePerkModalInput.new()


func is_active(flow_owner: Object, runtime_state: Object) -> bool:
	return (
		flow_owner != null
		and flow_owner.has_method("has_pending_guardian_spring_chosik_swap")
		and bool(flow_owner.call("has_pending_guardian_spring_chosik_swap"))
		and runtime_state != null
		and runtime_state.has_method("has_pending_unlock_swap")
		and bool(runtime_state.call("has_pending_unlock_swap"))
	)


func draw(
	canvas: CanvasItem,
	flow_owner: Object,
	runtime_state: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	if not is_active(flow_owner, runtime_state):
		return false
	var renderer := _get_registry_instance(registry, "runtime_perk_overlay_renderer")
	if renderer == null or not renderer.has_method("draw_standalone_unlock_swap_dialog"):
		return false
	var snapshot: Dictionary = runtime_state.get_snapshot().duplicate(true)
	var pending := _dictionary(snapshot.get("pending_unlock_swap", {}))
	pending["dialog_title"] = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CHOSIK_SWAP_TITLE
	)
	pending["dialog_new_label"] = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CHOSIK_SWAP_NEW_LABEL
	)
	pending["dialog_hint"] = TowerAscentNodeModalLocalization.text(
		TowerAscentNodeModalLocalization.KEY_SPRING_CHOSIK_SWAP_HINT
	)
	snapshot["pending_unlock_swap"] = pending
	return bool(renderer.call(
		"draw_standalone_unlock_swap_dialog",
		canvas,
		runtime_state,
		snapshot,
		view_size,
		_get_registry_instance(registry, "runtime_perk_icon_renderer")
	))


func handle_input(
	event: InputEvent,
	flow_owner: Object,
	runtime_state: Object,
	owner: Object,
	registry: Object,
	view_size: Vector2
) -> bool:
	if not is_active(flow_owner, runtime_state):
		return false
	_modal_input.handle_unlock_swap_input(
		event,
		owner,
		registry,
		view_size,
		_modal_input.build_state_callbacks(runtime_state)
	)
	# The Spring modal must never see an event while its five-choice swap owns the
	# screen, including releases, pointer motion, and unsupported buttons.
	return true


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_cached_instance", "get_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if typeof(value) == TYPE_OBJECT and value != null:
			return value as Object
	return null


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
