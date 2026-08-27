extends RefCounted

# The live wetness host is attached directly to the battle canvas by
# Stage1PlayerActorRenderer. Keep lifecycle routing independent from the
# renderer's dirty implementation layer so score/map/scene owners can retire
# the detached node before their own state disappears.
const HOST_NAME := "PlayerRainWetnessFxHost"


static func tear_down_from_canvas(canvas: Object, free_self: bool = false) -> bool:
	if canvas == null or not is_instance_valid(canvas):
		return false
	if not canvas.has_method("get_node_or_null"):
		return false
	var host: Node = canvas.get_node_or_null(HOST_NAME)
	if host == null or not is_instance_valid(host) or not host.has_method("tear_down"):
		return false
	host.tear_down(free_self)
	return true
