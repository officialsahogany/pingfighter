extends RefCounted

const CommandoSupplyDropFxHost := preload("res://scripts/characters/commando_supply_drop_fx_host.gd")

const HOST_NODE_NAME := "CommandoSupplyDropFxHost"

var _host: Object = null
var _add_pending := false


static func prewarm_assets() -> void:
	CommandoSupplyDropFxHost.prewarm_assets()


static func build_pipeline_status() -> Dictionary:
	return CommandoSupplyDropFxHost.build_pipeline_status()


func sync(
	canvas: CanvasItem,
	snapshot: Dictionary,
	shake_offset: Vector2,
	visible: bool,
	layout_context: Dictionary = {}
) -> void:
	if not visible:
		tear_down(false)
		return
	var host: Object = get_or_create(canvas)
	if host == null or not host.has_method("sync_state"):
		return
	host.sync_state(snapshot, shake_offset, true, layout_context)


func get_or_create(canvas: CanvasItem) -> Object:
	if canvas == null:
		return null
	if is_valid():
		var retained_node: Node = _host as Node
		if retained_node.get_parent() != null:
			_add_pending = false
		elif canvas is Node:
			_schedule_attach(canvas as Node, retained_node)
		return _host
	_host = null
	_add_pending = false
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(HOST_NODE_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_host = existing
		return _host
	_host = CommandoSupplyDropFxHost.new()
	_host.name = HOST_NODE_NAME
	_host.visible = false
	var host_node: Node = _host as Node
	if host_node == null:
		_host = null
		return null
	_schedule_attach(parent, host_node)
	return _host


func tear_down(free_host: bool = false) -> void:
	if not is_valid():
		_host = null
		_add_pending = false
		return
	if _host.has_method("tear_down"):
		_host.tear_down(free_host)
	elif free_host and _host is Node:
		(_host as Node).queue_free()
	if free_host:
		_host = null
		_add_pending = false
	elif is_attached():
		_add_pending = false


func is_valid() -> bool:
	return _host != null and is_instance_valid(_host) and _host is Node and not (_host as Node).is_queued_for_deletion()


func is_visible() -> bool:
	return is_valid() and _host is CanvasItem and bool((_host as CanvasItem).visible)


func is_attached() -> bool:
	return is_valid() and (_host as Node).get_parent() != null


func get_host() -> Object:
	return _host if is_valid() else null


func get_status() -> Dictionary:
	return {
		"valid": is_valid(),
		"attached": is_attached(),
		"visible": is_visible(),
		"add_pending": _add_pending,
	}


func _schedule_attach(parent: Node, host_node: Node) -> void:
	if parent == null or host_node == null or host_node.get_parent() != null:
		_add_pending = false
		return
	if _add_pending:
		return
	_add_pending = true
	parent.call_deferred("add_child", host_node)
