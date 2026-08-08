extends SceneTree

const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const GameSelectionStateScript := preload("res://scripts/core/game_selection_state.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const OnlineEnetTransport := preload("res://scripts/network/online_enet_transport.gd")
const OnlineMatchInputCollector := preload("res://scripts/network/online_match_input_collector.gd")
const OnlineMatchProtocol := preload("res://scripts/network/online_match_protocol.gd")
const OnlineMatchRenderer := preload("res://scripts/network/online_match_renderer.gd")
const OnlineMatchRuntime := preload("res://scripts/network/online_match_runtime.gd")
const OnlineMatchSession := preload("res://scripts/network/online_match_session.gd")
const OnlineMatchSimulation := preload("res://scripts/network/online_match_simulation.gd")
const OnlinePaddleState := preload("res://scripts/network/online_paddle_state.gd")
const RoundFlowState := preload("res://scripts/core/round_flow_state.gd")

var _failures: Array[String] = []


class FakeOnlineRuntime:
	extends RefCounted

	var physics_calls := 0


	func process_physics(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_callbacks: Dictionary
	) -> bool:
		physics_calls += 1
		return true


class FakePhysicsGate:
	extends RefCounted


	func should_block(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_callbacks: Dictionary,
		_modal_pause_state: Object,
		_perf_logger: Object
	) -> bool:
		return false


class FakeUpdateDriver:
	extends RefCounted

	var update_calls := 0
	var item_spawn_calls := 0
	var perk_modal_calls := 0
	var lingpet_calls := 0


	func update(_owner: Object, _registry: Object, _delta: float) -> void:
		update_calls += 1
		item_spawn_calls += 1
		perk_modal_calls += 1
		lingpet_calls += 1


class FakeActiveSession:
	extends RefCounted


	func is_active() -> bool:
		return true


class FakeModuleMap:
	extends RefCounted

	var modules: Dictionary = {}
	var get_calls := 0


	func _init(driver: Object = null) -> void:
		if driver != null:
			modules["battle_scene_update_driver"] = driver


	func get_module(key: String) -> Object:
		get_calls += 1
		var value: Variant = modules.get(key)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}


	func get_cached_instance(key: String) -> Object:
		var value: Variant = modules.get(key)
		return value as Object if typeof(value) == TYPE_OBJECT else null


class FakeTransport:
	extends RefCounted

	signal peer_joined(peer_id: int)
	signal peer_left(peer_id: int)
	signal packet_received(peer_id: int, packet: PackedByteArray)
	signal transport_error(message: String)

	const INPUT_CHANNEL := 0
	const CONTROL_CHANNEL := 1

	var close_calls := 0
	var remote_peer := false
	var start_error := OK


	func start_host(_port: int, _bind_ip: String) -> int:
		return start_error


	func start_client(_address: String, _port: int) -> int:
		return start_error


	func close() -> void:
		close_calls += 1
		remote_peer = false


	func poll() -> void:
		pass


	func has_remote_peer() -> bool:
		return remote_peer


	func get_remote_peer_id() -> int:
		return 1 if remote_peer else 0


	func get_last_error() -> String:
		return "synthetic start failure" if start_error != OK else ""


class FakeViewLayout:
	extends RefCounted

	var locked := false
	var unlock_calls := 0


	func set_online_simulation_tick_lock(active: bool, _ticks_per_second: int = 60) -> int:
		locked = active
		if not active:
			unlock_calls += 1
		return 60 if active else 0


class SpyVerticalStallGuard:
	extends RefCounted

	var calls := 0


	func apply(
		_ball_velocity: Vector2,
		_bounce_vector: Vector2,
		speed: float,
		vertical_bounce_count: int
	) -> Dictionary:
		calls += 1
		return {
			"ball_vel": Vector2(7.0, -absf(speed)),
			"vertical_bounce_count": vertical_bounce_count + 1,
		}


class SpySpeedMultiplierResolver:
	extends RefCounted

	var calls := 0
	var last_accel_scale := -1.0


	func apply(
		speed: float,
		_hit_pos: float,
		_is_player: bool,
		_drive_activated: bool,
		accel_scale: float,
		_ball_physics: Object
	) -> float:
		calls += 1
		last_accel_scale = accel_scale
		return speed


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_input_authority_whitelist()
	_verify_malformed_wire_types_fail_closed()
	_verify_snapshot_roundtrip_and_distribution()
	_verify_authoritative_seven_point_deuce_ladder()
	_verify_client_view_mirror_only()
	_verify_online_tick_lock_and_offline_regression()
	_verify_role_neutral_paddle_geometry()
	_verify_canonical_rally_physics_parity()
	_verify_canonical_bounce_side_symmetry_and_angle_reducer()
	_verify_client_reconciliation_step_is_bounded()
	_verify_snapshot_rate_is_independent_from_simulation_tick()
	_verify_remote_input_clock_offset_is_legal()
	_verify_tick_lock_lifecycle_and_connection_timeout()
	_verify_rejoining_peer_resets_remote_state()
	_verify_input_collector_is_same_frame_idempotent()
	_verify_online_runtime_bypasses_normal_physics()
	_verify_online_input_gate_consumes_legacy_routes()
	_verify_all_runtime_scripts_construct()
	_verify_online_lobby_scene_constructs()
	_verify_missing_online_modules_fail_closed()
	_verify_command_line_bootstrap_contract()
	if _failures.is_empty():
		print("online_match_mvp_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_input_authority_whitelist() -> void:
	var malicious := {
		"tick": 42,
		"move_dir": 99,
		"dash_edge": true,
		"serve_edge": false,
		"paddle_x": 999999.0,
		"ball_pos": {"x": 1.0, "y": 2.0},
		"score": {"host": 99},
		"collision_result": "client_wins",
	}
	var bytes := OnlineMatchProtocol.encode_packet(OnlineMatchProtocol.KIND_INPUT, 3, malicious)
	var decoded := OnlineMatchProtocol.decode_packet(bytes)
	var frame: Dictionary = decoded.get("payload", {})
	_expect(int(frame.get("move_dir", 0)) == 1, "input move_dir should be normalized to +1")
	for forbidden in ["paddle_x", "ball_pos", "score", "collision_result"]:
		_expect(not frame.has(forbidden), "authority whitelist must drop client field %s" % forbidden)


func _verify_malformed_wire_types_fail_closed() -> void:
	var malformed_input := var_to_bytes([
		OnlineMatchProtocol.PROTOCOL_VERSION,
		4,
		1,
		[{}, 1, false, false, false, false, false],
	])
	_expect(OnlineMatchProtocol.decode_packet(malformed_input).is_empty(), "dictionary-to-int wire confusion must fail closed")
	var valid_sim := OnlineMatchSimulation.new()
	valid_sim.configure(MatchScoreState.new(), RoundFlowState.new())
	valid_sim.reset_match()
	var valid_packet := OnlineMatchProtocol.encode_packet(
		OnlineMatchProtocol.KIND_SNAPSHOT,
		2,
		valid_sim.build_snapshot(1, "serve_wait", 0)
	)
	var decoded_wire: Variant = bytes_to_var(valid_packet)
	_expect(decoded_wire is Array, "valid snapshot fixture should decode to its wire array")
	if not decoded_wire is Array:
		return
	var malformed_snapshot: Array = decoded_wire as Array
	var snapshot_wire := malformed_snapshot[3] as Array
	var score_wire := snapshot_wire[9] as Array
	score_wire[0] = Color.RED
	_expect(
		OnlineMatchProtocol.decode_packet(var_to_bytes(malformed_snapshot)).is_empty(),
		"nested Color-to-int wire confusion must fail closed"
	)


func _verify_snapshot_roundtrip_and_distribution() -> void:
	var source_score := MatchScoreState.new()
	var source_round := RoundFlowState.new()
	var source_sim := OnlineMatchSimulation.new()
	source_sim.configure(source_score, source_round)
	source_sim.reset_match()
	source_score.force_score(7, 7)
	source_score.deuce_mode = true
	source_score.deuce_goal = MatchScoreState.resolve_deuce_goal(7)
	source_round.waiting_for_serve = true
	source_round.player_serves = false
	source_round.serve_timer = 0.75
	source_sim.ball_pos = Vector2(123.5, 456.25)
	source_sim.ball_vel = Vector2(-7.0, 9.0)
	source_sim.ball_active = true
	var snapshot := source_sim.build_snapshot(88, "countdown", 71, {}, 2.25)
	var packet := OnlineMatchProtocol.encode_packet(OnlineMatchProtocol.KIND_SNAPSHOT, 9, snapshot)
	_expect(packet.size() < 1200, "snapshot packet should remain below the ENet MTU budget (got %d bytes)" % packet.size())
	var decoded := OnlineMatchProtocol.decode_packet(packet)
	var decoded_payload: Dictionary = decoded.get("payload", {})
	var restored_score := MatchScoreState.new()
	var restored_round := RoundFlowState.new()
	var restored_sim := OnlineMatchSimulation.new()
	restored_sim.configure(restored_score, restored_round)
	restored_sim.reset_match()
	restored_sim.apply_authoritative_snapshot(decoded_payload)
	_expect(restored_sim.ball_pos.is_equal_approx(source_sim.ball_pos), "snapshot ball position should round-trip")
	_expect(restored_sim.ball_vel.is_equal_approx(source_sim.ball_vel), "snapshot ball velocity should round-trip")
	_expect(restored_sim.ball_active, "snapshot ball-active flag should distribute")
	_expect(restored_score.player_score == 7 and restored_score.boss_score == 7, "7:7 score should distribute")
	_expect(restored_score.deuce_mode and restored_score.deuce_goal == 9, "7:7 deuce ladder goal should remain 9")
	_expect(restored_round.waiting_for_serve and not restored_round.player_serves, "client serve ownership should distribute")
	_expect(is_equal_approx(restored_round.serve_timer, 0.75), "serve timer should distribute")
	_expect(is_equal_approx(float(decoded_payload.get("countdown_remaining", 0.0)), 2.25), "countdown clock should distribute")


func _verify_authoritative_seven_point_deuce_ladder() -> void:
	var score := MatchScoreState.new()
	var round_flow := RoundFlowState.new()
	var simulation := OnlineMatchSimulation.new()
	simulation.configure(score, round_flow)
	simulation.reset_match()
	for _point in range(6):
		simulation._score_point("host")
		simulation._score_point("client")
	_expect(score.player_score == 6 and score.boss_score == 6, "authoritative simulation should reach 6:6")
	_expect(score.deuce_mode and score.deuce_goal == 8, "6:6 should enter the existing deuce ladder at goal 8")
	simulation._score_point("host")
	simulation._score_point("client")
	_expect(score.player_score == 7 and score.boss_score == 7, "deuce should advance through 7:7")
	_expect(score.deuce_goal == 9, "7:7 should advance the deuce target to 9")
	simulation._score_point("host")
	simulation._score_point("host")
	_expect(simulation.winner_side == "host", "host should win the authoritative match at 9:7")


func _verify_client_view_mirror_only() -> void:
	var world := {
		"tick": 10,
		"ball_pos": {"x": 210.0, "y": 120.0},
		"ball_vel": {"x": 3.0, "y": -8.0},
		"ball_active": true,
		"p_host": {"paddle_x": 100.0, "paddle_vel": 2.0, "dash_state": {}},
		"p_client": {"paddle_x": 440.0, "paddle_vel": -1.0, "dash_state": {}},
		"score": {"host": 3, "client": 5},
		"serve": {"waiting": true, "owner_side": "client"},
		"match_phase": "serve_wait",
		"winner_side": "",
	}
	var client_view := OnlineMatchSession.project_world_state_for_side(world, "client")
	_expect(client_view.get("local_paddle_pos", Vector2.ZERO).y == OnlinePaddleState.HOST_Y, "client local paddle should render at the bottom")
	_expect(client_view.get("opponent_paddle_pos", Vector2.ZERO).y == _field_mirrored_top_y(), "host opponent should render at the top")
	_expect(client_view.get("ball_pos", Vector2.ZERO).is_equal_approx(Vector2(210.0, 630.0)), "client view should mirror ball Y")
	_expect(client_view.get("ball_vel", Vector2.ZERO).is_equal_approx(Vector2(3.0, 8.0)), "client view should invert only ball velocity Y")
	_expect(bool(client_view.get("local_serves", false)), "client serve owner should project as local")
	_expect(int(client_view.get("local_score", 0)) == 5, "client score should project as local score")
	_expect(OnlineMatchProtocol.wire_to_vector(world.get("ball_pos", {})).y == 120.0, "projection must not mutate simulation coordinates")


func _verify_online_tick_lock_and_offline_regression() -> void:
	var original_ticks := Engine.physics_ticks_per_second
	var layout := BattleViewLayout.new()
	layout.set_online_simulation_tick_lock(true, 60)
	var alternate_layout := BattleViewLayout.new()
	for cap_and_engine in [
		[BattleViewLayout.RENDER_FPS_CAP_SMOOTH, 60],
		[BattleViewLayout.RENDER_FPS_CAP_BALANCED, 72],
		[BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR, 90],
	]:
		var applied := int(alternate_layout._apply_physics_ticks_for_render_cap(cap_and_engine[0], cap_and_engine[1]))
		_expect(applied == 60 and Engine.physics_ticks_per_second == 60, "online tick lock must hold 60Hz across render modes")
	layout.set_online_simulation_tick_lock(false, 60)
	var balanced := int(layout._apply_physics_ticks_for_render_cap(BattleViewLayout.RENDER_FPS_CAP_BALANCED, 72))
	_expect(balanced == 72, "offline balanced mode should retain the existing 72Hz physics behavior")
	var smooth := int(layout._apply_physics_ticks_for_render_cap(BattleViewLayout.RENDER_FPS_CAP_SMOOTH, 60))
	_expect(smooth == 60, "offline smooth mode should retain the existing 60Hz physics behavior")
	var stable_monitor := int(layout._apply_physics_ticks_for_render_cap(BattleViewLayout.RENDER_FPS_CAP_STABLE_MONITOR, 90))
	_expect(stable_monitor == 90, "offline stable-monitor mode should restore monitor-derived physics ticks")
	Engine.physics_ticks_per_second = original_ticks


func _verify_role_neutral_paddle_geometry() -> void:
	var host := OnlinePaddleState.new()
	var client := OnlinePaddleState.new()
	host.reset("host")
	client.reset("client")
	_expect(OnlinePaddleState.PADDLE_WIDTH == 155.0, "online paddle width must be 155px")
	_expect(host.get_snapshot().keys() == client.get_snapshot().keys(), "host/client paddle snapshots should be role-neutral")
	var frame := OnlineMatchProtocol.sanitize_input_frame({"tick": 1, "move_dir": 1})
	host.step(1.0 / 60.0, frame)
	client.step(1.0 / 60.0, frame)
	_expect(is_equal_approx(host.position.x, client.position.x), "equal input should produce equal host/client movement")


func _verify_canonical_rally_physics_parity() -> void:
	var simulation := OnlineMatchSimulation.new()
	simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	simulation.reset_match()
	var base_cap := float(simulation.bounce_config["max_ball_speed"])
	var cap_bonus_max := float(simulation.bounce_config["rally_speed_cap_bonus_max"])
	_expect(
		is_equal_approx(float(simulation.bounce_config["max_bounce_angle"]), 60.0),
		"online bounce should read the production 60-degree max-angle config"
	)
	_expect(
		is_equal_approx(float(simulation.bounce_config["max_step_distance"]), 12.0),
		"online substeps should read the production collision-step config"
	)
	for _hit in range(20):
		simulation._apply_canonical_rally_cap_progression()
	_expect(
		is_equal_approx(simulation.max_ball_speed, base_cap + cap_bonus_max),
		"online rally cap should reuse the production 26-to-36 progression"
	)
	simulation._reset_rally_physics_state()
	simulation.ball_vel = Vector2(0.0, 10.0)
	var production_guard: Object = simulation.paddle_bounce_state.velocity_resolver.vertical_stall_guard
	var direct_guard_result: Dictionary = production_guard.apply(
		Vector2(0.0, -10.0),
		Vector2(0.0, -1.0),
		10.0,
		0
	)
	var direct_guard_value: Variant = direct_guard_result.get("ball_vel", Vector2.ZERO)
	var direct_guard_velocity: Vector2 = direct_guard_value if direct_guard_value is Vector2 else Vector2.ZERO
	_expect(absf(direct_guard_velocity.x) > 0.01, "production vertical-stall guard should break a perfectly vertical rally")
	var spy_guard := SpyVerticalStallGuard.new()
	simulation.paddle_bounce_state.velocity_resolver.vertical_stall_guard = spy_guard
	var guarded_velocity := simulation._resolve_canonical_paddle_bounce(0.0, -1.0)
	_expect(spy_guard.calls == 1, "online canonical bounce must invoke the shared vertical-stall guard slot")
	_expect(is_equal_approx(guarded_velocity.x, 7.0), "online bounce must consume the shared stall-guard result")
	simulation.paddle_bounce_state.velocity_resolver.vertical_stall_guard = production_guard
	_expect(
		production_guard != null,
		"online bounce path should own the production vertical-stall resolver"
	)


func _verify_canonical_bounce_side_symmetry_and_angle_reducer() -> void:
	var simulation := OnlineMatchSimulation.new()
	simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	simulation.reset_match()
	simulation.ball_vel = Vector2(0.0, 10.0)
	seed(424242)
	var lower_right := simulation._resolve_canonical_paddle_bounce(1.0, -1.0)
	simulation._reset_rally_physics_state()
	simulation.vertical_bounce_count = 0
	simulation.ball_vel = Vector2(0.0, -10.0)
	seed(424242)
	var upper_right := simulation._resolve_canonical_paddle_bounce(1.0, 1.0)
	_expect(lower_right.x > 0.0 and upper_right.x > 0.0, "right-side contact must launch right for both online paddles")
	var mirrored_upper_right := Vector2(upper_right.x, -upper_right.y).normalized()
	_expect(
		lower_right.normalized().is_equal_approx(mirrored_upper_right),
		"upper/lower right-edge directions should be Y-mirrored (lower=%s upper=%s)" % [lower_right, upper_right]
	)
	simulation._reset_rally_physics_state()
	simulation.vertical_bounce_count = 0
	simulation.ball_vel = Vector2(0.0, 10.0)
	seed(515151)
	var lower_left := simulation._resolve_canonical_paddle_bounce(-1.0, -1.0)
	simulation._reset_rally_physics_state()
	simulation.vertical_bounce_count = 0
	simulation.ball_vel = Vector2(0.0, -10.0)
	seed(515151)
	var upper_left := simulation._resolve_canonical_paddle_bounce(-1.0, 1.0)
	_expect(lower_left.x < 0.0 and upper_left.x < 0.0, "left-side contact must launch left for both online paddles")
	var mirrored_upper_left := Vector2(upper_left.x, -upper_left.y).normalized()
	_expect(
		lower_left.normalized().is_equal_approx(mirrored_upper_left),
		"upper/lower left-edge directions should be Y-mirrored (lower=%s upper=%s)" % [lower_left, upper_left]
	)

	var production_speed_resolver: Object = simulation.paddle_bounce_state.velocity_resolver.speed_multiplier_resolver
	var spy_speed_resolver := SpySpeedMultiplierResolver.new()
	simulation.paddle_bounce_state.velocity_resolver.speed_multiplier_resolver = spy_speed_resolver
	simulation._reset_rally_physics_state()
	simulation.vertical_bounce_count = 0
	simulation.ball_vel = Vector2(0.0, 10.0)
	var edge_angle := deg_to_rad(float(simulation.bounce_config["max_bounce_angle"]))
	var production_frame: Dictionary = simulation.paddle_bounce_frame_state.build(
		{"vertical_bounce_count": 0},
		simulation.ball_physics,
		simulation.ball_vel,
		simulation.ball_vel.length(),
		edge_angle
	)
	seed(777)
	simulation._resolve_canonical_paddle_bounce(1.0, -1.0)
	_expect(spy_speed_resolver.calls == 1, "online edge bounce must traverse the production speed-multiplier resolver")
	_expect(
		is_equal_approx(spy_speed_resolver.last_accel_scale, float(production_frame["accel_scale"])),
		"online edge bounce must pass the production angle-reduced accel_scale"
	)
	_expect(
		spy_speed_resolver.last_accel_scale < float(simulation.ball_physics.get_rally_speed_increase_multiplier()),
		"60-degree edge bounce must reduce acceleration below the unreduced rally multiplier"
	)
	simulation.paddle_bounce_state.velocity_resolver.speed_multiplier_resolver = production_speed_resolver


func _verify_client_reconciliation_step_is_bounded() -> void:
	var score := MatchScoreState.new()
	var round_flow := RoundFlowState.new()
	var simulation := OnlineMatchSimulation.new()
	simulation.configure(score, round_flow)
	simulation.reset_match()
	simulation.client_paddle.position.x = 200.0
	var snapshot := simulation.build_snapshot(1, "serve_wait", 0)
	var session := OnlineMatchSession.new()
	session.role = "client"
	session._simulation = simulation
	session._client_render_x = 100.0
	session._client_render_initialized = true
	session._receive_snapshot(snapshot)
	var previous_render_x := session._client_render_x
	for tick in range(1, 19):
		session._process_client_tick(
			1.0 / float(OnlineMatchSession.SIMULATION_HZ),
			OnlineMatchProtocol.sanitize_input_frame({"tick": tick})
		)
		var correction_step := absf(session._client_render_x - previous_render_x)
		_expect(correction_step <= OnlineMatchSession.CLIENT_CORRECTION_MAX_PX_PER_TICK + 0.001, "client correction step must stay bounded")
		previous_render_x = session._client_render_x
	_expect(is_equal_approx(session._client_render_x, 200.0), "delayed authoritative snapshot correction should converge")


func _verify_snapshot_rate_is_independent_from_simulation_tick() -> void:
	var session := OnlineMatchSession.new()
	session.snapshot_hz = 24
	var scheduled := 0
	for _tick in range(OnlineMatchSession.SIMULATION_HZ):
		if session._advance_snapshot_schedule():
			scheduled += 1
	_expect(scheduled == 24, "24Hz snapshot setting should schedule 24 sends across 60 simulation ticks")


func _verify_remote_input_clock_offset_is_legal() -> void:
	var session := OnlineMatchSession.new()
	session.simulation_tick = 10
	session._receive_remote_input({"tick": 777, "move_dir": 1})
	_expect(session._last_remote_input_tick_received == 777, "host must accept a legal initial client-clock offset")
	session._receive_remote_input({"tick": 778, "move_dir": 1})
	_expect(session._last_remote_input_tick_received == 778, "host should advance on the remote clock without host-clock comparison")
	session._receive_remote_input({"tick": 2000, "move_dir": -1})
	_expect(session._last_remote_input_tick_received == 2000, "long packet gaps must not create a permanent remote-input lock")
	session._receive_remote_input({"tick": 1999, "move_dir": 0})
	_expect(int(session._latest_remote_input.get("move_dir", 0)) == -1, "stale movement must not roll the remote clock backward")
	var malicious := {"tick": 2001, "move_dir": 1, "paddle_x": 999999.0, "score": {"client": 99}}
	session._receive_remote_input(malicious)
	_expect(not session._latest_remote_input.has("paddle_x"), "session authority boundary must strip client paddle position")
	_expect(not session._latest_remote_input.has("score"), "session authority boundary must strip client score")
	var reordered_session := OnlineMatchSession.new()
	reordered_session.simulation_tick = 20
	reordered_session._receive_remote_input({"tick": 22, "move_dir": -1})
	reordered_session._receive_remote_input({"tick": 21, "move_dir": 1, "dash_edge": true})
	_expect(int(reordered_session._latest_remote_input.get("move_dir", 0)) == -1, "late reliable edge must not roll movement backward")
	_expect(bool(reordered_session._latest_remote_input.get("dash_edge", false)), "late reliable dash edge should survive cross-channel reordering")


func _verify_tick_lock_lifecycle_and_connection_timeout() -> void:
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 72
	var fallback_session := OnlineMatchSession.new()
	var fallback_simulation := OnlineMatchSimulation.new()
	fallback_simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	fallback_session.begin({"role": "host"}, FakeTransport.new(), fallback_simulation, null)
	_expect(Engine.physics_ticks_per_second == 60, "null-layout online begin should acquire the 60Hz fallback lock")
	fallback_session.stop()
	_expect(Engine.physics_ticks_per_second == 72, "null-layout online stop should restore the previous physics tick")
	Engine.physics_ticks_per_second = original_ticks
	var failure_layout := FakeViewLayout.new()
	var failure_transport := FakeTransport.new()
	failure_transport.start_error = ERR_CANT_CONNECT
	var failure_simulation := OnlineMatchSimulation.new()
	failure_simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	var failure_session := OnlineMatchSession.new()
	var failure_error := failure_session.begin(
		{"role": "client", "address": "bad.invalid"},
		failure_transport,
		failure_simulation,
		failure_layout
	)
	_expect(failure_error == ERR_CANT_CONNECT and failure_session.match_phase == "error", "immediate transport failure should enter visible error state")
	_expect(not failure_layout.locked and failure_layout.unlock_calls == 1, "begin failure should release the acquired tick lock")
	failure_session.stop(failure_layout)

	var timeout_layout := FakeViewLayout.new()
	var timeout_transport := FakeTransport.new()
	var timeout_simulation := OnlineMatchSimulation.new()
	timeout_simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	var timeout_session := OnlineMatchSession.new()
	timeout_session.begin(
		{"role": "client", "address": "192.0.2.1"},
		timeout_transport,
		timeout_simulation,
		timeout_layout
	)
	timeout_session.advance_idle(OnlineMatchSession.CONNECT_TIMEOUT_SECONDS + 0.1)
	_expect(timeout_session.match_phase == "error", "unreachable client connection should enter a bounded timeout error")
	_expect(timeout_transport.close_calls > 0, "connection timeout should close the transport")
	_expect(not timeout_layout.locked and timeout_layout.unlock_calls == 1, "connection timeout should release the 60Hz lock exactly once")
	timeout_session.stop(timeout_layout)

	var ready_layout := FakeViewLayout.new()
	var ready_transport := FakeTransport.new()
	var ready_simulation := OnlineMatchSimulation.new()
	ready_simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	var ready_session := OnlineMatchSession.new()
	ready_session.begin({"role": "host"}, ready_transport, ready_simulation, ready_layout)
	ready_session._on_transport_peer_joined(2)
	ready_session.advance_idle(OnlineMatchSession.READY_TIMEOUT_SECONDS + 0.1)
	_expect(
		ready_session.match_phase == "waiting_ready",
		"peer-ready timeout must pause while the local battle is still loading"
	)
	ready_session.mark_local_ready()
	ready_session.advance_idle(OnlineMatchSession.READY_TIMEOUT_SECONDS + 0.1)
	_expect(
		ready_session.match_phase == "error",
		"peer-ready timeout must remain bounded after local loading completes"
	)
	ready_session.stop(ready_layout)


func _verify_rejoining_peer_resets_remote_state() -> void:
	var simulation := OnlineMatchSimulation.new()
	simulation.configure(MatchScoreState.new(), RoundFlowState.new())
	simulation.reset_match()
	simulation.match_score_state.force_score(4, 3)
	var session := OnlineMatchSession.new()
	session.role = "host"
	session._simulation = simulation
	session._remote_ready = true
	session._handshake_received = true
	session._remote_input_clock_initialized = true
	session._last_remote_input_tick_received = 900
	session._latest_remote_input = OnlineMatchProtocol.sanitize_input_frame({"tick": 900, "move_dir": 1})
	session._on_transport_peer_joined(2)
	_expect(not session._remote_ready and not session._handshake_received, "new peer must provide a fresh handshake and READY")
	_expect(not session._remote_input_clock_initialized and session._last_remote_input_tick_received == -1, "new peer must receive a fresh remote clock baseline")
	_expect(simulation.match_score_state.player_score == 0 and simulation.match_score_state.boss_score == 0, "new peer must start from a clean authoritative match")
	session.stop()


func _verify_input_collector_is_same_frame_idempotent() -> void:
	var collector := OnlineMatchInputCollector.new()
	var first := collector.collect(31)
	first["dash_edge"] = not bool(first.get("dash_edge", false))
	var second := collector.collect(32)
	_expect(int(second.get("tick", 0)) == 31, "same physics frame should reuse the first online input frame")
	_expect(bool(second.get("dash_edge", false)) != bool(first.get("dash_edge", false)), "same-frame snapshot callers must receive defensive copies")


func _verify_online_runtime_bypasses_normal_physics() -> void:
	var online_runtime := FakeOnlineRuntime.new()
	var update_driver := FakeUpdateDriver.new()
	var module_map := FakeModuleMap.new(update_driver)
	var controller := BattleSceneFrameController.new()
	controller._online_match_runtime = online_runtime
	_inject_fake_physics_gate_if_supported(controller)
	controller.process_physics(
		1.0 / float(OnlineMatchSession.SIMULATION_HZ),
		RefCounted.new(),
		null,
		Callable(module_map, "get_module"),
		{}
	)
	_expect(online_runtime.physics_calls == 1, "online runtime should own the active physics frame")
	_expect(update_driver.update_calls == 0, "normal battle update must stay bypassed during online play")
	_expect(update_driver.item_spawn_calls == 0, "online feature gate must suppress item spawning")
	_expect(update_driver.perk_modal_calls == 0, "online feature gate must suppress perk modal entry")
	_expect(update_driver.lingpet_calls == 0, "online feature gate must suppress Lingpet updates")
	var offline_driver := FakeUpdateDriver.new()
	var offline_modules := FakeModuleMap.new(offline_driver)
	var offline_controller := BattleSceneFrameController.new()
	_inject_fake_physics_gate_if_supported(offline_controller)
	offline_controller.process_physics(
		1.0 / float(OnlineMatchSession.SIMULATION_HZ),
		RefCounted.new(),
		null,
		Callable(offline_modules, "get_module"),
		{
			"is_battle_initialized": Callable(self, "_return_true"),
			"is_stage_landing_intro_started": Callable(self, "_return_true"),
		}
	)
	_expect(offline_driver.item_spawn_calls == 1, "offline leg must retain normal item update routing")
	_expect(offline_driver.perk_modal_calls == 1, "offline leg must retain normal perk update routing")
	_expect(offline_driver.lingpet_calls == 1, "offline leg must retain normal Lingpet update routing")


func _inject_fake_physics_gate_if_supported(controller: Object) -> void:
	for property: Dictionary in controller.get_property_list():
		if String(property.get("name", "")) == "_physics_gate_coordinator":
			controller.set("_physics_gate_coordinator", FakePhysicsGate.new())
			return


func _return_true() -> bool:
	return true


func _verify_online_input_gate_consumes_legacy_routes() -> void:
	var module_map := FakeModuleMap.new(FakeUpdateDriver.new())
	var registry := FakeRegistry.new()
	registry.modules["online_match_session"] = FakeActiveSession.new()
	var controller := BattleSceneInputController.new()
	var input_event := InputEventMouseButton.new()
	input_event.button_index = MOUSE_BUTTON_LEFT
	input_event.pressed = true
	_expect(
		controller._handle_online_match_input(
			input_event,
			RefCounted.new(),
			registry,
			Callable(module_map, "get_module")
		),
		"active online input gate should consume legacy feature routes"
	)
	registry.modules["online_match_session"] = OnlineMatchSession.new()
	var get_calls_before := module_map.get_calls
	_expect(
		not controller._handle_online_match_input(
			input_event,
			RefCounted.new(),
			registry,
			Callable(module_map, "get_module")
		),
		"offline input should continue through the existing single-player routes"
	)
	_expect(module_map.get_calls == get_calls_before, "offline input hot path must not instantiate the online session module")


func _verify_all_runtime_scripts_construct() -> void:
	_expect(OnlineEnetTransport.new() != null, "ENet adapter should construct")
	_expect(OnlineMatchInputCollector.new() != null, "input collector should construct")
	_expect(OnlineMatchRenderer.new() != null, "online renderer should construct")
	_expect(OnlineMatchRuntime.new() != null, "online runtime should construct")
	_expect(OnlineMatchSession.new() != null, "online session should construct")


func _verify_online_lobby_scene_constructs() -> void:
	var resource: Resource = load("res://scenes/online_lobby.tscn")
	_expect(resource is PackedScene, "online lobby should load as a PackedScene")
	if not resource is PackedScene:
		return
	var lobby: Node = (resource as PackedScene).instantiate()
	_expect(lobby.get_node_or_null("CenterPanel/Margin/VBox/AddressInput") != null, "online lobby should expose host address input")
	_expect(lobby.get_node_or_null("CenterPanel/Margin/VBox/ActionRow/HostButton") != null, "online lobby should expose host action")
	_expect(lobby.get_node_or_null("CenterPanel/Margin/VBox/ActionRow/JoinButton") != null, "online lobby should expose join action")
	lobby.free()


func _verify_missing_online_modules_fail_closed() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	var selection_state: Object = null
	if main_loop is SceneTree:
		selection_state = (main_loop as SceneTree).root.get_node_or_null("GameSelectionState")
	_expect(selection_state != null, "online fail-closed leg requires the production selection autoload")
	if selection_state == null:
		return
	selection_state.request_online_match({"role": "host"})
	var runtime := OnlineMatchRuntime.new()
	var empty_modules := FakeModuleMap.new()
	runtime._ensure_started(null, Callable(empty_modules, "get_module"))
	_expect(runtime._startup_failed and runtime.is_active(), "missing required online modules must block the normal battle path")
	_expect(selection_state.has_pending_online_match_request(), "module validation must occur before consuming the online request")
	runtime.stop()
	_expect(not selection_state.has_pending_online_match_request(), "leaving a startup error must cancel the unconsumed request")


func _verify_command_line_bootstrap_contract() -> void:
	var host_request := GameSelectionStateScript.parse_online_command_line(PackedStringArray([
		"--online-host",
		"--online-port=27888",
		"--online-snapshot-hz=24",
	]))
	_expect(str(host_request.get("role", "")) == "host", "CLI host flag should create a host request")
	_expect(int(host_request.get("port", 0)) == 27888, "CLI host port should be parsed")
	_expect(int(host_request.get("snapshot_hz", 0)) == 24, "CLI snapshot rate should be independent")
	var client_request := GameSelectionStateScript.parse_online_command_line(PackedStringArray([
		"--online-join=100.64.0.9",
	]))
	_expect(str(client_request.get("role", "")) == "client", "CLI join flag should create a client request")
	_expect(str(client_request.get("address", "")) == "100.64.0.9", "CLI join address should preserve Tailscale IP")
	_expect(
		GameSelectionStateScript.is_direct_online_battle_launch(PackedStringArray(["res://scenes/main.tscn"])),
		"explicit production battle-scene CLI launch should arm online bootstrap"
	)
	_expect(
		not GameSelectionStateScript.is_direct_online_battle_launch(PackedStringArray(["res://scenes/boot_flow.tscn"])),
		"normal boot/menu launch must not arm a pending online match from user args alone"
	)
	var selection_state := GameSelectionStateScript.new()
	selection_state.request_online_match({"role": "host"})
	_expect(selection_state.skip_battle_logo_once, "online request should arm its one-shot battle-logo skip")
	selection_state.cancel_online_match_request()
	_expect(
		not selection_state.has_pending_online_match_request() and not selection_state.skip_battle_logo_once,
		"cancelled online request must not leak its logo-skip flag into the next single-player battle"
	)
	selection_state.free()


func _field_mirrored_top_y() -> float:
	return 750.0 - OnlinePaddleState.HOST_Y - OnlinePaddleState.PADDLE_HEIGHT


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
