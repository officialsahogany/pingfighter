extends RefCounted


static func advance_to_node_modal(
	flow: Object,
	expected_kind: String,
	owner: Object = null
) -> bool:
	if flow == null or not flow.has_method("get_phase_name"):
		return false
	if str(flow.get_phase_name()) != "ROUTE_AIM":
		return false
	var target_index := -1
	var targets: Array[Dictionary] = flow.get_route_aim_targets()
	for index in range(targets.size()):
		if str(targets[index].get("kind", "")) == expected_kind:
			target_index = index
			break
	if target_index < 0:
		return false
	flow.debug_launch_at_target(target_index)
	flow.update_selective(1.5, owner)
	if str(flow.get_phase_name()) != "MAP_TRANSITION":
		return false
	flow.update_selective(1.0, owner)
	return (
		str(flow.get_phase_name()) == "NODE_MODAL"
		and str(flow.get_node_modal_kind()) == expected_kind
	)
