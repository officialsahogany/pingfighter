extends RefCounted

const StageBallSpawnIntroFxHost := preload("res://scripts/core/stage_ball_spawn_intro_fx_host.gd")

var host_factory: Variant = StageBallSpawnIntroFxHost


func begin_fx_host(
	owner: Object,
	current_host: Node,
	start_pos: Vector2,
	target_pos: Vector2,
	ball_render_radius: float,
	phase_1_duration: float,
	phase_2_duration: float,
	phase_3_duration: float,
	player_serves: bool
) -> Node:
	tear_down(current_host)
	if owner == null or not (owner is Node):
		return null
	var host: Node = _make_host()
	if host == null:
		return null
	host.name = "StageBallSpawnIntroFxHost"
	(owner as Node).add_child(host)
	if host.has_method("begin_fx"):
		host.begin_fx(
			start_pos,
			target_pos,
			ball_render_radius,
			phase_1_duration,
			phase_2_duration,
			phase_3_duration,
			player_serves
		)
	return host


func sync_state(host: Node, ball_state: Dictionary, current_phase: int, elapsed_sec: float) -> Node:
	if host == null or not is_instance_valid(host):
		return null
	if host.has_method("sync_state"):
		host.sync_state(ball_state, current_phase, elapsed_sec)
	return host


func sync_layout(host: Node, layout: Dictionary) -> Node:
	if host == null or not is_instance_valid(host):
		return null
	if host.has_method("sync_layout"):
		host.sync_layout(layout)
	return host


func tear_down(host: Node) -> Node:
	if host == null:
		return null
	if is_instance_valid(host) and host.has_method("tear_down"):
		host.tear_down(true)
	return null


func _make_host() -> Node:
	var host: Variant = host_factory.new()
	if typeof(host) == TYPE_OBJECT and host is Node:
		return host as Node
	return null
