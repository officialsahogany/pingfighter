extends RefCounted

const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")
const Stage4PonkIllusionRippleFxHost := preload("res://scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd")
const Stage4PonkMagneticFxHost := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_fx_host.gd")
const Stage4PonkMeditationFxHost := preload("res://scripts/stages/stage4/stage4_ponk_meditation_fx_host.gd")

const KIND_MAGNETIC := 0
const KIND_MEDITATION := 1
const KIND_ILLUSION := 2
const KIND_AWAKEN_AURA := 3
const HOST_KIND_COUNT := 4

# Owns Stage 4 Ponk's detached FX Node references, staged runtime-node
# prewarm, existing-child adoption, deferred attachment, sync, and immediate
# deactivation. The skill facade retains FX-context construction, fallback
# drawing, static asset prewarm, and cross-effect draw order.

var magnetic_fx_host: Node = null
var meditation_fx_host: Node = null
var illusion_fx_host: Node = null
var awaken_aura_fx_host: Node = null
var fx_hosts_prewarmed := false

var _add_pending: Array[bool] = [false, false, false, false]
var _runtime_prewarmed: Array[bool] = [false, false, false, false]
var _prewarm_step_index := 0


func prewarm_runtime_hosts(canvas: CanvasItem) -> void:
	while not prewarm_runtime_hosts_step(canvas):
		pass


func prewarm_runtime_hosts_step(canvas: CanvasItem) -> bool:
	if fx_hosts_prewarmed:
		return true
	if not (canvas is Node):
		fx_hosts_prewarmed = true
		_prewarm_step_index = 0
		return true
	_get_or_create(_prewarm_step_index, canvas)
	_prewarm_step_index += 1
	if _prewarm_step_index >= HOST_KIND_COUNT:
		fx_hosts_prewarmed = true
		_prewarm_step_index = 0
		return true
	return false


func sync_magnetic(canvas: CanvasItem, fx_context: Dictionary, active: bool) -> bool:
	return _sync(KIND_MAGNETIC, canvas, fx_context, active, true, true)


func sync_meditation(canvas: CanvasItem, fx_context: Dictionary, active: bool) -> bool:
	return _sync(KIND_MEDITATION, canvas, fx_context, active, false, false)


func sync_illusion(canvas: CanvasItem, fx_context: Dictionary, active: bool) -> bool:
	return _sync(KIND_ILLUSION, canvas, fx_context, active, false, false)


func sync_awaken_aura(canvas: CanvasItem, fx_context: Dictionary, active: bool) -> bool:
	return _sync(KIND_AWAKEN_AURA, canvas, fx_context, active, true, true)


func get_or_create_magnetic(canvas: CanvasItem) -> Node:
	return _get_or_create(KIND_MAGNETIC, canvas)


func get_or_create_meditation(canvas: CanvasItem) -> Node:
	return _get_or_create(KIND_MEDITATION, canvas)


func get_or_create_illusion(canvas: CanvasItem) -> Node:
	return _get_or_create(KIND_ILLUSION, canvas)


func get_or_create_awaken_aura(canvas: CanvasItem) -> Node:
	return _get_or_create(KIND_AWAKEN_AURA, canvas)


func stop_magnetic() -> void:
	_stop(KIND_MAGNETIC)


func stop_meditation() -> void:
	_stop(KIND_MEDITATION)


func stop_illusion() -> void:
	_stop(KIND_ILLUSION)


func stop_awaken_aura() -> void:
	_stop(KIND_AWAKEN_AURA)


func is_valid_magnetic() -> bool:
	return _is_valid(KIND_MAGNETIC)


func is_valid_meditation() -> bool:
	return _is_valid(KIND_MEDITATION)


func is_valid_illusion() -> bool:
	return _is_valid(KIND_ILLUSION)


func is_valid_awaken_aura() -> bool:
	return _is_valid(KIND_AWAKEN_AURA)


func _sync(
	kind: int,
	canvas: CanvasItem,
	fx_context: Dictionary,
	active: bool,
	check_can_handle: bool,
	require_runtime_assets: bool
) -> bool:
	if not active and not _is_valid(kind):
		return false
	var host: Node = _get_or_create(kind, canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	if check_can_handle and host.has_method("can_handle_state") and not bool(host.call("can_handle_state", fx_context)):
		host.call("sync_state", fx_context, false)
		return false
	host.call("sync_state", fx_context, active)
	if not active:
		return false
	if require_runtime_assets and host.has_method("has_runtime_assets") and not bool(host.call("has_runtime_assets")):
		return false
	return host.get_parent() != null


func _get_or_create(kind: int, canvas: CanvasItem) -> Node:
	if _is_valid(kind):
		_prewarm_runtime_nodes(kind)
		return _get_host(kind)
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(_host_name(kind))
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_set_host(kind, existing)
		_add_pending[kind] = false
		_runtime_prewarmed[kind] = false
		_register_cleanup_host(kind, existing)
		_prewarm_runtime_nodes(kind)
		return existing
	var host: Node = _new_host(kind)
	if host == null:
		return null
	host.name = _host_name(kind)
	if host is CanvasItem:
		(host as CanvasItem).visible = false
	_set_host(kind, host)
	_runtime_prewarmed[kind] = false
	_register_cleanup_host(kind, host)
	_prewarm_runtime_nodes(kind)
	if not _add_pending[kind]:
		_add_pending[kind] = true
		parent.call_deferred("add_child", host)
	return host


func _prewarm_runtime_nodes(kind: int) -> void:
	if _runtime_prewarmed[kind]:
		return
	var host: Node = _get_host(kind)
	if host != null and is_instance_valid(host) and host.has_method("prewarm_runtime_nodes"):
		host.call("prewarm_runtime_nodes")
		_runtime_prewarmed[kind] = true


func _stop(kind: int) -> void:
	if not _is_valid(kind):
		_set_host(kind, null)
		_add_pending[kind] = false
		_runtime_prewarmed[kind] = false
		return
	var host: Node = _get_host(kind)
	if host.has_method("set_active"):
		host.call("set_active", false)


func _is_valid(kind: int) -> bool:
	var host: Node = _get_host(kind)
	return host != null and is_instance_valid(host) and not host.is_queued_for_deletion()


func _get_host(kind: int) -> Node:
	match kind:
		KIND_MAGNETIC:
			return magnetic_fx_host
		KIND_MEDITATION:
			return meditation_fx_host
		KIND_ILLUSION:
			return illusion_fx_host
		KIND_AWAKEN_AURA:
			return awaken_aura_fx_host
	return null


func _set_host(kind: int, host: Node) -> void:
	match kind:
		KIND_MAGNETIC:
			magnetic_fx_host = host
		KIND_MEDITATION:
			meditation_fx_host = host
		KIND_ILLUSION:
			illusion_fx_host = host
		KIND_AWAKEN_AURA:
			awaken_aura_fx_host = host


func _host_name(kind: int) -> String:
	match kind:
		KIND_MAGNETIC:
			return "PonkMagneticFxHost"
		KIND_MEDITATION:
			return "PonkMeditationFxHost"
		KIND_ILLUSION:
			return "PonkIllusionRippleFxHost"
		KIND_AWAKEN_AURA:
			return "PonkAwakenAuraFxHost"
	return ""


func _new_host(kind: int) -> Node:
	match kind:
		KIND_MAGNETIC:
			return Stage4PonkMagneticFxHost.new()
		KIND_MEDITATION:
			return Stage4PonkMeditationFxHost.new()
		KIND_ILLUSION:
			return Stage4PonkIllusionRippleFxHost.new()
		KIND_AWAKEN_AURA:
			return Stage4PonkAwakenAuraFxHost.new()
	return null


func _register_cleanup_host(kind: int, host: Node) -> void:
	if kind == KIND_AWAKEN_AURA:
		Stage4PonkAwakenAuraFxHost.register_host_for_cleanup(host)
