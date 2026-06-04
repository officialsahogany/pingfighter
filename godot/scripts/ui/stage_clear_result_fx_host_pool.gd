extends RefCounted

const ResultBoxOpenFxHost := preload("res://scripts/effects/result_box_open_fx_host.gd")
const StageClearResultBoxData := preload("res://scripts/ui/stage_clear_result_box_data.gd")
const StageClearResultLayoutHelper := preload("res://scripts/ui/stage_clear_result_layout_helper.gd")
const StageClearResultScrollState := preload("res://scripts/ui/stage_clear_result_scroll_state.gd")

var _hosts: Array = []
var _prewarm_next_index: int = 0


func reset_prewarm() -> void:
	_prewarm_next_index = 0


func prewarm_step(owner: Node, boxes: Array) -> void:
	if _prewarm_next_index < 0 or _prewarm_next_index >= boxes.size():
		return
	var host: Node2D = ensure_host(owner, _prewarm_next_index)
	if host != null:
		set_host_active(_prewarm_next_index, false)
	_prewarm_next_index += 1


func sync(
	owner: Node,
	boxes: Array,
	layout_scale: float,
	timer: float,
	scroll_phase: String,
	scroll_timer: float,
	scroll_unfurl_duration: float,
	box_float_amplitude: float,
	box_float_speed: float
) -> void:
	if boxes.is_empty():
		deactivate_all()
		return
	var global_alpha: float = StageClearResultScrollState.get_box_global_alpha(scroll_phase, scroll_timer, scroll_unfurl_duration)
	for i in range(boxes.size()):
		var box: Dictionary = boxes[i] if boxes[i] is Dictionary else {}
		var state: String = str(box.get("state", "idle"))
		if state != "opening" and state != "opened":
			set_host_active(i, false)
			continue
		var host: Node2D = ensure_host(owner, i)
		if host == null:
			continue
		host.sync_state(
			_build_fx_state(box, state, layout_scale, timer, global_alpha, box_float_amplitude, box_float_speed),
			global_alpha > 0.02
		)


func ensure_host(owner: Node, index: int) -> Node2D:
	if owner == null or index < 0:
		return null
	while _hosts.size() <= index:
		_hosts.append(null)
	var existing: Variant = _hosts[index]
	if existing is Node2D and is_instance_valid(existing):
		return existing
	var host: Node2D = ResultBoxOpenFxHost.new()
	host.name = "ResultBoxOpenFxHost_%d" % index
	host.visible = false
	owner.add_child(host)
	_hosts[index] = host
	return host


func set_host_active(index: int, active: bool) -> void:
	if index < 0 or index >= _hosts.size():
		return
	var host: Variant = _hosts[index]
	if host == null or not (host is Node) or not is_instance_valid(host):
		return
	if host.has_method("set_active"):
		host.set_active(active)


func deactivate_all() -> void:
	for i in range(_hosts.size()):
		set_host_active(i, false)


func tear_down() -> void:
	for host_variant in _hosts:
		if host_variant is Node and is_instance_valid(host_variant):
			if host_variant.has_method("tear_down"):
				host_variant.tear_down(true)
			else:
				host_variant.queue_free()
	_hosts.clear()
	_prewarm_next_index = 0


func get_status() -> Dictionary:
	var host_count: int = 0
	for host_variant in _hosts:
		if host_variant is Node and is_instance_valid(host_variant):
			host_count += 1
	return {
		"host_count": host_count,
		"prewarm_next_index": _prewarm_next_index,
	}


func _build_fx_state(
	box: Dictionary,
	state: String,
	layout_scale: float,
	timer: float,
	global_alpha: float,
	box_float_amplitude: float,
	box_float_speed: float
) -> Dictionary:
	return {
		"position": StageClearResultLayoutHelper.get_box_draw_center(
			box,
			layout_scale,
			timer,
			box_float_amplitude,
			box_float_speed
		),
		"scale": layout_scale,
		"phase": state,
		"open_progress": float(box.get("open_progress", 0.0)),
		"reward_emerge": float(box.get("reward_emerge", 0.0)),
		"alpha": global_alpha,
		"is_mythic": StageClearResultBoxData.is_mythic_visual_box_kind(str(box.get("kind", StageClearResultBoxData.BOX_KIND_NORMAL))),
		"lid_open_id": int(box.get("lid_open_id", -1)),
	}
