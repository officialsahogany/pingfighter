extends SceneTree

const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage2CollisionGeometry := preload("res://scripts/stages/stage2/stage2_collision_geometry.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2PlayfieldBounds := preload("res://scripts/stages/stage2/stage2_playfield_bounds.gd")
const Stage2StarpointCoordinator := preload("res://scripts/stages/stage2/stage2_starpoint_coordinator.gd")
const Stage2StarpointRuntimeState := preload("res://scripts/stages/stage2/stage2_starpoint_runtime_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")

var _failures: Array[String] = []


class FakeMythicRuntime:
	extends RefCounted

	var calls := 0

	func roll_star_detector_bonus_drop_count() -> int:
		calls += 1
		return 2


class FakeRuntimePerkState:
	extends RefCounted

	var trace: Array[String]
	var collect_calls := 0

	func _init(trace_ref: Array[String]) -> void:
		trace = trace_ref

	func collect_star_points(
		_amount: int,
		_character_type: String,
		_catalog: Object,
		_owner: Object = null,
		_registry: Object = null,
		_defer_choice_open: bool = false
	) -> bool:
		collect_calls += 1
		trace.append("reward")
		return true


class FakeAudio:
	extends RefCounted

	var trace: Array[String]

	func _init(trace_ref: Array[String]) -> void:
		trace = trace_ref

	func play_starpoint_collect() -> void:
		trace.append("audio")


class FakeOwner:
	extends RefCounted

	var trace: Array[String]

	func _init(trace_ref: Array[String]) -> void:
		trace = trace_ref

	func queue_redraw() -> void:
		trace.append("redraw")


class FakeStarpointState:
	extends RefCounted

	var trace: Array[String]
	var drops: Array = []
	var particles: Array = []

	func _init(trace_ref: Array[String]) -> void:
		trace = trace_ref

	func clear() -> bool:
		var had_state := not drops.is_empty() or not particles.is_empty()
		drops.clear()
		particles.clear()
		trace.append("clear")
		return had_state

	func append_drop(drop: Dictionary) -> void:
		drops.append(drop)

	func append_particles(entries: Array) -> void:
		particles.append_array(entries)
		trace.append("particles")


class FakeObstacleRenderer:
	extends RefCounted

	var trace: Array[String]

	func _init(trace_ref: Array[String]) -> void:
		trace = trace_ref

	func hide_all_starpoint_drops() -> void:
		trace.append("hide")


func _init() -> void:
	_verify_spawn_preserves_shared_rng_and_bonus_order()
	_verify_modal_collection_and_stage_exit_order()
	_verify_background_delegation_and_catalog()

	if _failures.is_empty():
		print("stage2_starpoint_coordinator_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_spawn_preserves_shared_rng_and_bonus_order() -> void:
	var context := {
		"current_stage": 2,
		"play_left": 0.0,
		"play_right": 760.0,
		"height": 750.0,
	}
	var spawn_pos := Vector2(18.0, 20.0)
	var expected: Dictionary = _build_expected_spawn(20260727, spawn_pos, context)
	var state := Stage2StarpointRuntimeState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260727
	var mythic_runtime := FakeMythicRuntime.new()
	var coordinator := _configured_coordinator(state, rng, FakeObstacleRenderer.new([]))
	coordinator.spawn_drop_at(spawn_pos, {"mythic_item_runtime": mythic_runtime}, context)

	_expect(state.drops == expected.get("drops", []), "Stage 2 starpoint spawn should preserve primary then bonus payload order")
	_expect(state.particles == expected.get("particles", []), "Stage 2 starpoint spawn should preserve per-drop particle payload order")
	_expect(rng.state == int(expected.get("rng_state", -1)), "Stage 2 starpoint spawn should preserve the final shared RNG state")
	_expect(mythic_runtime.calls == 1, "Star Detector bonus count should roll exactly once per primary drop")
	_expect(state.drops.size() == 3, "one primary plus two Star Detector drops should be retained")
	_expect(not bool((state.drops[0] as Dictionary).get("star_detector_bonus", true)), "primary drop should remain first and untagged")
	_expect(bool((state.drops[1] as Dictionary).get("star_detector_bonus", false)), "bonus drops should retain their Star Detector tag")


func _verify_modal_collection_and_stage_exit_order() -> void:
	var trace: Array[String] = []
	var state := FakeStarpointState.new(trace)
	state.drops = [_make_drop(Vector2(100.0, 100.0)), _make_drop(Vector2(110.0, 100.0))]
	var renderer := FakeObstacleRenderer.new(trace)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260728
	var coordinator := _configured_coordinator(state, rng, renderer)
	var runtime := FakeRuntimePerkState.new(trace)
	var owner := FakeOwner.new(trace)
	coordinator.update_drops(0.0, _collection_context(owner), {
		"runtime_perk_state": runtime,
		"audio": FakeAudio.new(trace),
	})
	_expect(runtime.collect_calls == 1, "modal collection should stop after exactly one Stage 2 starpoint")
	_expect(state.drops.size() == 1 and _drop_pos(state.drops[0]) == Vector2(110.0, 100.0), "modal collection should preserve the unprocessed tail drop")
	_expect(trace == ["reward", "particles", "audio", "redraw"], "collection should preserve reward, particles, audio, and redraw order")

	trace.clear()
	state.particles.append({"life": 1.0})
	coordinator.update_drops(0.0, {"current_stage": 1}, {})
	_expect(state.drops.is_empty() and state.particles.is_empty(), "leaving Stage 2 should clear retained drops and particles atomically")
	_expect(trace == ["clear", "hide"], "stage exit should clear retained state before hiding detached visual hosts")


func _verify_background_delegation_and_catalog() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	var coordinator_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_starpoint_coordinator.gd")
	_expect(source.find("var starpoint_coordinator: Object = Stage2StarpointCoordinator.new()") >= 0, "Stage 2 background should retain one starpoint coordinator")
	_expect(source.find("starpoint_coordinator.configure(") >= 0, "Stage 2 background should configure starpoint collaborators once")
	_expect(_method_source(source, "_spawn_starpoint_drop_at").find("starpoint_coordinator.spawn_drop_at") >= 0, "starpoint spawn facade should delegate")
	_expect(_method_source(source, "_update_starpoint_drops").find("starpoint_coordinator.update_drops") >= 0, "starpoint update facade should delegate")
	_expect(_method_source(source, "_collect_starpoint_drop").find("starpoint_coordinator.collect_drop") >= 0, "starpoint collection facade should delegate")
	_expect(_method_source(source, "_spawn_starpoint_particles").find("starpoint_coordinator.spawn_particles") >= 0, "starpoint particle facade should delegate")
	_expect(_method_source(source, "_update_starpoint_particles").find("starpoint_coordinator.update_particles") >= 0, "starpoint particle update facade should delegate")
	for contract in [
		"StarpointPayloadFactory.build_drop",
		"StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count",
		"StarpointDowsingAttraction.apply_to_drop",
		"LingpetStarlightTrackingBridge.update_drop",
		"StarpointCollectionCompaction.finish_in_place",
		"StarpointCollectionRewardPolicy.collect_starpoint_reward",
	]:
		_expect(coordinator_source.find(contract) >= 0, "Stage 2 starpoint coordinator should consume %s" % contract)
	_expect(GameplayStageModuleCatalog.MODULES.has("stage2_starpoint_coordinator"), "stage module catalog should register the starpoint coordinator")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("stage2_starpoint_coordinator")
	_expect(str(spec.get("path", "")) == "res://scripts/stages/stage2/stage2_starpoint_coordinator.gd", "top-level gameplay catalog should resolve the starpoint coordinator")

	var background := Stage2PillarBackground.new()
	background._spawn_starpoint_drop_at(Vector2(200.0, 220.0), {}, {}, false)
	_expect(background.starpoint_drops.size() == 1 and not background.starpoint_particles.is_empty(), "production spawn facade should retain one drop and its particles")


func _configured_coordinator(state: Object, rng: RandomNumberGenerator, renderer: Object) -> Object:
	var coordinator := Stage2StarpointCoordinator.new()
	coordinator.configure(
		state,
		rng,
		Stage2CollisionGeometry.new(),
		Stage2PlayfieldBounds.new(),
		renderer
	)
	return coordinator


func _build_expected_spawn(seed_value: int, pos: Vector2, context: Dictionary) -> Dictionary:
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = seed_value
	var drops: Array = []
	var particles: Array = []
	drops.append(StarpointPayloadFactory.build_drop(
		pos,
		expected_rng,
		false,
		Stage2StarpointCoordinator.DROP_SIZE,
		Stage2StarpointCoordinator.DROP_LIFETIME
	))
	particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		Stage2StarpointCoordinator.PARTICLE_COUNT,
		1.0,
		expected_rng,
		Stage2StarpointCoordinator.PARTICLE_LIFE
	))
	for _index in range(2):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(Stage2StarpointCoordinator.BONUS_DROP_OFFSET_CHOICES[expected_rng.randi() % Stage2StarpointCoordinator.BONUS_DROP_OFFSET_CHOICES.size()]),
				float(context.get("play_left", 0.0)) + Stage2StarpointCoordinator.DROP_SIZE,
				float(context.get("play_right", 760.0)) - Stage2StarpointCoordinator.DROP_SIZE
			),
			clamp(
				pos.y + float(Stage2StarpointCoordinator.BONUS_DROP_OFFSET_CHOICES[expected_rng.randi() % Stage2StarpointCoordinator.BONUS_DROP_OFFSET_CHOICES.size()]),
				Stage2StarpointCoordinator.DROP_SIZE,
				float(context.get("height", 750.0)) - Stage2StarpointCoordinator.DROP_SIZE
			)
		)
		drops.append(StarpointPayloadFactory.build_drop(
			bonus_pos,
			expected_rng,
			true,
			Stage2StarpointCoordinator.DROP_SIZE,
			Stage2StarpointCoordinator.DROP_LIFETIME
		))
		particles.append_array(StarpointPayloadFactory.build_particles(
			bonus_pos,
			Stage2StarpointCoordinator.PARTICLE_COUNT + 6,
			1.2,
			expected_rng,
			Stage2StarpointCoordinator.PARTICLE_LIFE
		))
	return {"drops": drops, "particles": particles, "rng_state": expected_rng.state}


func _collection_context(owner: Object) -> Dictionary:
	return {
		"current_stage": 2,
		"player_pos": Vector2(92.0, 92.0),
		"player_paddle_size": Vector2(32.0, 32.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"height": 750.0,
		"selected_character_type": "smasher",
		"owner": owner,
	}


func _make_drop(pos: Vector2) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector2.ZERO,
		"size": 12.0,
		"rotation": 0.0,
		"rotation_speed": 0.0,
		"glow_intensity": 1.0,
		"glow_timer": 0.0,
		"life": 600.0,
		"float_timer": 0.0,
	}


func _drop_pos(value: Variant) -> Vector2:
	if value is Dictionary:
		var pos_value: Variant = (value as Dictionary).get("pos", Vector2.ZERO)
		if pos_value is Vector2:
			return pos_value
	return Vector2.ZERO


func _method_source(source: String, method_name: String) -> String:
	var marker := "func %s(" % method_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
