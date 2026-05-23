extends RefCounted

const TRACE_NODE_LIMIT := 10
const PROCESS_SCAN_VERSION := 2
const STALE_LOADING_HOST_NAME := "BattleLoadingStainedGlassHost"
const STALE_LOADING_HOST_SCRIPT := "battle_loading_stained_glass_host.gd"


func build(scene_owner: Node) -> String:
	if scene_owner == null or not is_instance_valid(scene_owner):
		return "process_nodes=unavailable"
	var root: Node = scene_owner
	var result: Dictionary = {
		"scan_scope": "owner",
		"nodes_scanned": 0,
		"script_count": 0,
		"process_count": 0,
		"physics_count": 0,
		"process_callback_count": 0,
		"physics_callback_count": 0,
		"process_callback_active_count": 0,
		"physics_callback_active_count": 0,
		"process_callback_outside_count": 0,
		"physics_callback_outside_count": 0,
		"process_callback_inactive_count": 0,
		"physics_callback_inactive_count": 0,
		"process_outside_count": 0,
		"physics_outside_count": 0,
		"ignored_stale_count": 0,
		"ignored_stale_labels": [],
		"process_callback_outside_labels": [],
		"physics_callback_outside_labels": [],
		"process_callback_inactive_labels": [],
		"physics_callback_inactive_labels": [],
		"process_outside_labels": [],
		"physics_outside_labels": [],
	}
	if scene_owner.is_inside_tree():
		var tree := scene_owner.get_tree()
		if tree != null and tree.root != null:
			root = tree.root
			result["scan_scope"] = "root"
	_collect_process_nodes(root, scene_owner, result)
	return (
		"scan=%s nodes=%d script_nodes=%d"
		+ " ignored_stale=%d [%s] scan_v=%d"
		+ " | process_nodes=%d outside_shell=%d [%s]"
		+ " callbacks=%d active=%d callback_outside=%d [%s] inactive=%d [%s]"
		+ " | physics_nodes=%d outside_shell=%d [%s]"
		+ " callbacks=%d active=%d callback_outside=%d [%s] inactive=%d [%s]"
	) % [
		str(result.get("scan_scope", "owner")),
		int(result.get("nodes_scanned", 0)),
		int(result.get("script_count", 0)),
		int(result.get("ignored_stale_count", 0)),
		_format_label_list(result.get("ignored_stale_labels", [])),
		PROCESS_SCAN_VERSION,
		int(result.get("process_count", 0)),
		int(result.get("process_outside_count", 0)),
		_format_label_list(result.get("process_outside_labels", [])),
		int(result.get("process_callback_count", 0)),
		int(result.get("process_callback_active_count", 0)),
		int(result.get("process_callback_outside_count", 0)),
		_format_label_list(result.get("process_callback_outside_labels", [])),
		int(result.get("process_callback_inactive_count", 0)),
		_format_label_list(result.get("process_callback_inactive_labels", [])),
		int(result.get("physics_count", 0)),
		int(result.get("physics_outside_count", 0)),
		_format_label_list(result.get("physics_outside_labels", [])),
		int(result.get("physics_callback_count", 0)),
		int(result.get("physics_callback_active_count", 0)),
		int(result.get("physics_callback_outside_count", 0)),
		_format_label_list(result.get("physics_callback_outside_labels", [])),
		int(result.get("physics_callback_inactive_count", 0)),
		_format_label_list(result.get("physics_callback_inactive_labels", [])),
	]


func _collect_process_nodes(node: Node, scene_owner: Node, result: Dictionary) -> void:
	result["nodes_scanned"] = int(result.get("nodes_scanned", 0)) + 1
	if _is_stale_loading_host(node):
		result["ignored_stale_count"] = int(result.get("ignored_stale_count", 0)) + 1
		var ignored_labels: Array = result.get("ignored_stale_labels", [])
		if ignored_labels.size() < TRACE_NODE_LIMIT:
			ignored_labels.append(_format_node_label(node))
		result["ignored_stale_labels"] = ignored_labels
		return
	if node.get_script() != null:
		result["script_count"] = int(result.get("script_count", 0)) + 1
	if _script_defines_callback(node, "_process"):
		_record_callback_node(result, "process", node, scene_owner)
	if _script_defines_callback(node, "_physics_process"):
		_record_callback_node(result, "physics", node, scene_owner)
	if node.is_processing():
		_record_process_node(result, "process", node, scene_owner)
	if node.is_physics_processing():
		_record_process_node(result, "physics", node, scene_owner)
	for child in node.get_children():
		if child is Node:
			_collect_process_nodes(child as Node, scene_owner, result)


func _script_defines_callback(node: Node, callback_name: String) -> bool:
	var script_resource: Variant = node.get_script()
	if not (script_resource is Script):
		return false
	for method_value in (script_resource as Script).get_script_method_list():
		if not (method_value is Dictionary):
			continue
		if str((method_value as Dictionary).get("name", "")) == callback_name:
			return true
	return false


func _is_stale_loading_host(node: Node) -> bool:
	if node.name != STALE_LOADING_HOST_NAME:
		return false
	var script_resource: Variant = node.get_script()
	if not (script_resource is Script):
		return false
	var script_path: String = str((script_resource as Script).resource_path)
	if script_path.get_file() != STALE_LOADING_HOST_SCRIPT:
		return false
	var canvas_item := node as CanvasItem
	var visible := canvas_item != null and canvas_item.visible
	return not visible and not node.is_processing() and not node.is_physics_processing()


func _record_callback_node(result: Dictionary, kind: String, node: Node, scene_owner: Node) -> void:
	var count_key := kind + "_callback_count"
	var active_count_key := kind + "_callback_active_count"
	var inactive_count_key := kind + "_callback_inactive_count"
	var outside_count_key := kind + "_callback_outside_count"
	var outside_labels_key := kind + "_callback_outside_labels"
	var inactive_labels_key := kind + "_callback_inactive_labels"
	var active := node.is_processing() if kind == "process" else node.is_physics_processing()
	result[count_key] = int(result.get(count_key, 0)) + 1
	if active:
		result[active_count_key] = int(result.get(active_count_key, 0)) + 1
	else:
		result[inactive_count_key] = int(result.get(inactive_count_key, 0)) + 1
		var inactive_labels: Array = result.get(inactive_labels_key, [])
		if inactive_labels.size() < TRACE_NODE_LIMIT:
			inactive_labels.append(_format_node_label(node))
		result[inactive_labels_key] = inactive_labels
	if node == scene_owner or not active:
		return
	result[outside_count_key] = int(result.get(outside_count_key, 0)) + 1
	var outside_labels: Array = result.get(outside_labels_key, [])
	if outside_labels.size() < TRACE_NODE_LIMIT:
		outside_labels.append(_format_node_label(node))
	result[outside_labels_key] = outside_labels


func _record_process_node(result: Dictionary, kind: String, node: Node, scene_owner: Node) -> void:
	var count_key := kind + "_count"
	var outside_count_key := kind + "_outside_count"
	var outside_labels_key := kind + "_outside_labels"
	result[count_key] = int(result.get(count_key, 0)) + 1
	if node == scene_owner:
		return
	result[outside_count_key] = int(result.get(outside_count_key, 0)) + 1
	var labels: Array = result.get(outside_labels_key, [])
	if labels.size() < TRACE_NODE_LIMIT:
		labels.append(_format_node_label(node))
	result[outside_labels_key] = labels


func _format_node_label(node: Node) -> String:
	var script_name := "no-script"
	var script_resource: Variant = node.get_script()
	if script_resource is Script:
		var script_path: String = str((script_resource as Script).resource_path)
		if script_path != "":
			script_name = script_path.get_file()
	var node_path: String = str(node.get_path()) if node.is_inside_tree() else str(node.name)
	return "%s<%s>" % [node_path, script_name]


func _format_label_list(labels_value: Variant) -> String:
	if not (labels_value is Array):
		return "-"
	var labels: Array = labels_value
	if labels.is_empty():
		return "-"
	var parts: Array[String] = []
	for label in labels:
		parts.append(str(label))
	return ", ".join(parts)
