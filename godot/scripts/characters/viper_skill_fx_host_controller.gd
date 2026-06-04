extends RefCounted

const ChaosSpearFxHost := preload("res://scripts/characters/viper_chaos_spear_fx_host.gd")
const EmpStrikeFxHost := preload("res://scripts/characters/viper_emp_strike_fx_host.gd")


func prewarm_viper_fx_hosts(runtime: Object, owner: Object) -> bool:
	prewarm_viper_fx_host_step(runtime, owner, 0)
	prewarm_viper_fx_host_step(runtime, owner, 1)
	return true


func prewarm_viper_fx_host_step(runtime: Object, owner: Object, step_index: int) -> bool:
	match step_index:
		0:
			ChaosSpearFxHost.prewarm_assets()
			if owner is Node:
				var chaos_parent: Node = owner as Node
				var chaos_host: Node = _get_or_create_chaos_fx_host_for_prewarm(runtime, chaos_parent)
				_prewarm_host_runtime_nodes(chaos_host)
		1:
			EmpStrikeFxHost.prewarm_assets()
			if owner is Node:
				var emp_parent: Node = owner as Node
				var emp_host: Node = _get_or_create_emp_fx_host_for_prewarm(runtime, emp_parent)
				_prewarm_host_runtime_nodes(emp_host)
	return true


func sync_emp_strike_fx(
	runtime: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	visibility_query: Object,
	particle_drawer: Object,
	shockwave_frames: float,
	jetpack_max_height: float,
	hit_text_frames: float
) -> bool:
	if not visibility_query.has_emp_strike_visuals(runtime):
		hide_fx_host(runtime.emp_fx_host)
		return false
	var host: Node = get_or_create_emp_fx_host(runtime, canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	var state: Dictionary = particle_drawer.build_emp_strike_fx_state(
		runtime,
		shake_offset,
		node_fx_layout,
		shockwave_frames,
		jetpack_max_height,
		hit_text_frames
	)
	host.sync_state(state, true)
	return host.is_inside_tree()


func get_or_create_emp_fx_host(runtime: Object, canvas: CanvasItem) -> Node:
	if is_valid_fx_host(runtime.emp_fx_host):
		return runtime.emp_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("ViperEmpStrikeFxHost")
	if is_valid_fx_host(existing):
		runtime.emp_fx_host = existing
		runtime.emp_fx_host_add_pending = false
		return runtime.emp_fx_host
	runtime.emp_fx_host = EmpStrikeFxHost.new()
	runtime.emp_fx_host.name = "ViperEmpStrikeFxHost"
	runtime.emp_fx_host.visible = false
	if not runtime.emp_fx_host_add_pending:
		runtime.emp_fx_host_add_pending = true
		parent.call_deferred("add_child", runtime.emp_fx_host)
	return runtime.emp_fx_host


func sync_chaos_spear_fx(
	runtime: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	chaos_spear_effect_renderer: Object,
	startup_frames: float,
	travel_frames: float,
	impact_frames: float,
	blackhole_frames: float,
	fade_frames: float,
	fx_disk_height: float
) -> bool:
	if runtime.chaos_state == "idle":
		hide_fx_host(runtime.chaos_fx_host)
		return true
	var host: Node = get_or_create_chaos_fx_host(runtime, canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	var phase_total_frames: float = chaos_spear_effect_renderer.get_chaos_phase_total_frames(
		runtime.chaos_state,
		startup_frames,
		travel_frames,
		impact_frames,
		blackhole_frames,
		fade_frames
	)
	var state: Dictionary = chaos_spear_effect_renderer.build_chaos_fx_state(
		runtime,
		shake_offset,
		node_fx_layout,
		phase_total_frames,
		fx_disk_height
	)
	host.sync_state(state, true)
	if host.has_method("can_handle_state") and not bool(host.can_handle_state(state)):
		return false
	return host.is_inside_tree()


func get_or_create_chaos_fx_host(runtime: Object, canvas: CanvasItem) -> Node:
	if is_valid_fx_host(runtime.chaos_fx_host):
		return runtime.chaos_fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("ViperChaosSpearFxHost")
	if is_valid_fx_host(existing):
		runtime.chaos_fx_host = existing
		runtime.chaos_fx_host_add_pending = false
		return runtime.chaos_fx_host
	runtime.chaos_fx_host = ChaosSpearFxHost.new()
	runtime.chaos_fx_host.name = "ViperChaosSpearFxHost"
	runtime.chaos_fx_host.visible = false
	if not runtime.chaos_fx_host_add_pending:
		runtime.chaos_fx_host_add_pending = true
		parent.call_deferred("add_child", runtime.chaos_fx_host)
	return runtime.chaos_fx_host


func _get_or_create_chaos_fx_host_for_prewarm(runtime: Object, parent: Node) -> Node:
	if is_valid_fx_host(runtime.chaos_fx_host):
		return runtime.chaos_fx_host
	var existing: Node = parent.get_node_or_null("ViperChaosSpearFxHost")
	if is_valid_fx_host(existing):
		runtime.chaos_fx_host = existing
		runtime.chaos_fx_host_add_pending = false
		return runtime.chaos_fx_host
	var host: Node = ChaosSpearFxHost.new()
	host.name = "ViperChaosSpearFxHost"
	host.visible = false
	parent.add_child(host)
	runtime.chaos_fx_host = host
	runtime.chaos_fx_host_add_pending = false
	return host


func _get_or_create_emp_fx_host_for_prewarm(runtime: Object, parent: Node) -> Node:
	if is_valid_fx_host(runtime.emp_fx_host):
		return runtime.emp_fx_host
	var existing: Node = parent.get_node_or_null("ViperEmpStrikeFxHost")
	if is_valid_fx_host(existing):
		runtime.emp_fx_host = existing
		runtime.emp_fx_host_add_pending = false
		return runtime.emp_fx_host
	var host: Node = EmpStrikeFxHost.new()
	host.name = "ViperEmpStrikeFxHost"
	host.visible = false
	parent.add_child(host)
	runtime.emp_fx_host = host
	runtime.emp_fx_host_add_pending = false
	return host


func _prewarm_host_runtime_nodes(host: Node) -> void:
	if is_valid_fx_host(host) and host.has_method("prewarm_runtime_nodes"):
		host.prewarm_runtime_nodes()


func hide_fx_host(host: Node) -> void:
	if is_valid_fx_host(host) and host.has_method("set_active"):
		host.set_active(false)


func is_valid_fx_host(host: Node) -> bool:
	return host != null and is_instance_valid(host) and not host.is_queued_for_deletion()
