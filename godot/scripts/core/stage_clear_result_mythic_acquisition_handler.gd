extends RefCounted


func update_cinematic(delta: float, mythic_item_runtime: Object, owner: Object, registry: Object) -> bool:
	if not is_acquisition_cinematic_active(mythic_item_runtime):
		return false
	if mythic_item_runtime.has_method("update"):
		mythic_item_runtime.update(owner, registry, delta)
	raise_cinematic(mythic_item_runtime)
	return true


func handle_input(
	event: InputEvent,
	mythic_item_runtime: Object,
	owner: Object,
	registry: Object,
	scene: Control
) -> bool:
	if not is_acquisition_cinematic_active(mythic_item_runtime):
		return false
	if mythic_item_runtime.has_method("handle_acquisition_cinematic_input"):
		mythic_item_runtime.handle_acquisition_cinematic_input(event, registry)
	if owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	if scene != null and is_instance_valid(scene):
		scene.queue_redraw()
	return true


func is_acquisition_cinematic_active(mythic_item_runtime: Object) -> bool:
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_acquisition_cinematic_active")
		and bool(mythic_item_runtime.is_acquisition_cinematic_active())
	)


func raise_cinematic(mythic_item_runtime: Object) -> void:
	if mythic_item_runtime == null:
		return
	var cinematic_value: Variant = mythic_item_runtime.get("acquisition_cinematic")
	if not (cinematic_value is CanvasItem):
		return
	var cinematic := cinematic_value as CanvasItem
	cinematic.z_as_relative = false
	cinematic.z_index = maxi(cinematic.z_index, 1305)
	if cinematic is Node:
		(cinematic as Node).process_mode = Node.PROCESS_MODE_ALWAYS
