extends RefCounted


static func update_fx_hosts(
	fx_host_pool: Object,
	owner: Node,
	boxes: Array,
	layout_scale: float,
	timer: float,
	scroll_phase: String,
	scroll_timer: float
) -> void:
	if fx_host_pool == null:
		return
	if fx_host_pool.has_method("prewarm_step"):
		fx_host_pool.prewarm_step(owner, boxes)
	if fx_host_pool.has_method("sync"):
		fx_host_pool.sync(
			owner,
			boxes,
			layout_scale,
			timer,
			scroll_phase,
			scroll_timer
		)
