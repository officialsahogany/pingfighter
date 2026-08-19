extends SceneTree

const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const Stage7AkamuPlayfieldRenderer := preload("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd")
const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

const CLONE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_clone_state.gd"
const STARPOINT_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_starpoint_state.gd"
const FACADE_STATE_PATH := "res://scripts/stages/stage7/stage7_akamu_state.gd"

var _failures: Array[String] = []


class FakeAuxiliaryBounceController:
	extends RefCounted

	func bounce_auxiliary_boss_paddle(
		paddle_rect: Rect2,
		context: Dictionary,
		_deps: Dictionary
	) -> Dictionary:
		var ball_pos: Vector2 = context.get("ball_pos", Vector2.ZERO)
		ball_pos.y = paddle_rect.end.y + float(context.get("ball_size", 20.0)) * 0.5 + 1.0
		return {
			"ball_pos": ball_pos,
			"ball_vel": Vector2(0.0, 12.0),
		}


class FakeRuntimePerkState:
	extends RefCounted

	var collected := 0

	func collect_star_points(
		amount: int,
		_character_type: String,
		_catalog: Object,
		_owner: Object,
		_registry: Object
	) -> bool:
		collected += amount
		return false


class FakeAudio:
	extends RefCounted

	var collect_calls := 0

	func play_starpoint_collect() -> void:
		collect_calls += 1


class FakeOwner:
	extends RefCounted

	var redraw_calls := 0

	func request_battle_redraw() -> void:
		redraw_calls += 1


class FakeDowsingRuntime:
	extends RefCounted

	func get_dowsing_pendulum_context() -> Dictionary:
		return {
			"active": true,
			"range": 1000.0,
			"min_distance": 30.0,
			"force": 3.5,
			"max_speed": 8.0,
		}


class FakeLingpetRuntime:
	extends RefCounted

	var update_calls := 0

	func update_starlight_tracking_for_starpoint_drop(
		_drop: Dictionary,
		_delta: float,
		_context: Dictionary
	) -> Dictionary:
		update_calls += 1
		return {"claimed": true, "delivered": true}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_modular_owner_boundary()
	_verify_creation_time_roll_and_rng_stream()
	_verify_drop_spawn_conditions_and_double_hit_guard()
	_verify_collection_fail_loud_floor_and_accessories()
	_verify_freeze_serve_wait_round_and_runtime_detection()
	_verify_coordinate_contract_and_host_cleanup()
	_verify_cap_truncation_and_visual_contract()

	if _failures.is_empty():
		print("stage7_akamu_golden_clone_starpoint_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_modular_owner_boundary() -> void:
	var clone_source := FileAccess.get_file_as_string(CLONE_STATE_PATH)
	var starpoint_source := FileAccess.get_file_as_string(STARPOINT_STATE_PATH)
	var facade_source := FileAccess.get_file_as_string(FACADE_STATE_PATH)
	_expect(not clone_source.is_empty(), "golden clone behavior should have a readable focused owner")
	_expect(not starpoint_source.is_empty(), "Muhon lifecycle should have a readable focused owner")
	_expect(
		clone_source.find("const TEMP_GOLDEN_CHANCE := 0.50") >= 0
			and clone_source.find("const TEMP_GOLDEN_MUHON_DROPS := 1") >= 0,
		"the clone owner should retain the locked golden chance and one-drop contract"
	)
	_expect(
		clone_source.find("var golden: bool = rng.randf() < TEMP_GOLDEN_CHANCE") >= 0,
		"the clone owner should consume the authoritative golden roll at entity creation"
	)
	_expect(
		clone_source.find("\"golden\": bool(nearest_clone.get(\"golden\", false))") >= 0
			and clone_source.find("\"clone_center\": clone_rect.get_center()") >= 0,
		"the clone collision result should capture reward identity and geometry"
	)
	_expect(
		starpoint_source.find("func spawn(pos: Vector2) -> void:") >= 0
			and starpoint_source.find("func update(") >= 0
			and starpoint_source.find("func clear() -> void:") >= 0,
		"the starpoint owner should own Muhon spawn, lifecycle, and round cleanup"
	)
	_expect(
		facade_source.find("const Stage7AkamuStarpointState := preload(\"%s\")" % STARPOINT_STATE_PATH) >= 0
			and facade_source.find("var _starpoint_state: Object = Stage7AkamuStarpointState.new(_rng)") >= 0,
		"the Stage 7 facade should compose one focused starpoint owner"
	)
	var golden_capture_index := facade_source.find(
		"var golden: bool = bool(clone_hit.get(\"golden\", false))"
	)
	var dying_index := facade_source.find("_clone_state.begin_dying(clone_index, deps)")
	_expect(
		golden_capture_index >= 0 and dying_index > golden_capture_index,
		"the facade should capture collision reward data before begin_dying mutates the clone"
	)
	_expect(
		facade_source.find("const TEMP_GOLDEN_CHANCE") < 0
			and facade_source.find("rng.randf() < TEMP_GOLDEN_CHANCE") < 0,
		"the orchestration facade must not retain the golden roll or its tuning constant"
	)


func _verify_creation_time_roll_and_rng_stream() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_seed_rng(73001)
	state.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
	var initial_snapshot: Dictionary = state.debug_get_clone_snapshot()
	var initial_vector: String = str(initial_snapshot.get("golden_vector", []))
	_expect_close(
		float(initial_snapshot.get("golden_chance", -1.0)),
		0.50,
		"golden clones should use the locked per-entity 50% TEMP chance"
	)
	_expect(
		int(initial_snapshot.get("golden_muhon_drops", -1)) == 1,
		"one golden clone kill should own exactly one Muhon drop"
	)
	var first_clone: Dictionary = (
		state.get_actor_draw_context().get("stage7_akamu_clones", []) as Array
	)[0]
	_expect_close(
		float(first_clone.get("velocity_x", 0.0)),
		-9.006541252,
		"the first entity velocity must retain its pre-golden RNG baseline",
		0.000001
	)
	_expect(
		int(first_clone.get("motion_noise_state", 0)) == 801639750,
		"the first entity motion-noise seed must retain its pre-golden RNG baseline"
	)
	for _frame in range(300):
		state.update(1.0 / 60.0, _base_context())
	_expect(
		str(state.debug_get_clone_snapshot().get("golden_vector", [])) == initial_vector,
		"golden flags must remain byte-for-byte stable across 300 update frames"
	)

	var repeated: Object = Stage7AkamuState.new()
	repeated.debug_seed_rng(73001)
	repeated.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
	_expect(
		str(repeated.debug_get_clone_snapshot().get("golden_vector", [])) == initial_vector,
		"the same authoritative seed should reproduce the same golden vector"
	)
	var found_different_vector := false
	for seed_value in range(73002, 73033):
		var different: Object = Stage7AkamuState.new()
		different.debug_seed_rng(seed_value)
		different.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
		if str(different.debug_get_clone_snapshot().get("golden_vector", [])) != initial_vector:
			found_different_vector = true
			break
	_expect(
		found_different_vector,
		"at least one fixed alternate authoritative seed should produce a different golden vector"
	)


func _verify_drop_spawn_conditions_and_double_hit_guard() -> void:
	var deps := {"paddle_bounce_controller": FakeAuxiliaryBounceController.new()}
	var context: Dictionary = _base_context()

	var golden_state: Object = Stage7AkamuState.new()
	golden_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	_expect(golden_state.debug_set_clone_golden(0, true), "golden collision setup should address clone zero")
	_expect(golden_state.debug_set_clone_golden(1, false), "golden collision setup should keep clone one normal")
	_expect(
		golden_state.resolve_ball_collision(_clone_collision_scene(), context, deps),
		"a player-owned swept ball should kill the golden clone"
	)
	var golden_drop_snapshot: Dictionary = golden_state.debug_get_starpoint_snapshot()
	_expect(
		int(golden_drop_snapshot.get("drop_count", 0)) == 1,
		"a ball-killed golden clone should spawn exactly one Muhon"
	)
	var drops: Array = golden_drop_snapshot.get("drops", [])
	_expect_vector(
		(drops[0] as Dictionary).get("pos", Vector2.ZERO),
		Vector2(380.0, 200.0),
		"Muhon should spawn at clone_rect.get_center()"
	)
	golden_state.resolve_ball_collision(_clone_collision_scene(), context, deps)
	_expect(
		int(golden_state.debug_get_starpoint_snapshot().get("drop_count", 0)) == 1,
		"a second frame cannot spawn a second reward from the already-dying clone"
	)

	var normal_state: Object = Stage7AkamuState.new()
	normal_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	normal_state.debug_set_clone_golden(0, false)
	normal_state.debug_set_clone_golden(1, false)
	_expect(
		normal_state.resolve_ball_collision(_clone_collision_scene(), context, deps),
		"normal clone collision setup should still resolve the bounce"
	)
	_expect(
		int(normal_state.debug_get_starpoint_snapshot().get("drop_count", -1)) == 0,
		"a normal clone kill must not spawn Muhon"
	)

	var natural_state: Object = Stage7AkamuState.new()
	natural_state.debug_spawn_shadow_clones(Vector2(380.0, 200.0))
	natural_state.debug_set_clone_golden(0, true)
	_advance(natural_state, 10.1, context)
	_expect(
		int(natural_state.debug_get_starpoint_snapshot().get("drop_count", -1)) == 0,
		"natural ten-second expiry must never grant a free golden-clone reward"
	)

	var boss_hit_state: Object = Stage7AkamuState.new()
	boss_hit_state.handle_boss_paddle_hit(
		{"ball_pos": Vector2(380.0, 70.0), "ball_vel": Vector2(0.0, 12.0)},
		context
	)
	_expect(
		int(boss_hit_state.debug_get_starpoint_snapshot().get("drop_count", -1)) == 0,
		"ordinary boss hits must not gain a second probability-drop route"
	)


func _verify_collection_fail_loud_floor_and_accessories() -> void:
	var collect_pos := Vector2(377.5, 715.0)
	var context: Dictionary = _base_context()
	var runtime := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()
	var owner := FakeOwner.new()
	context["owner"] = owner
	var collected_state: Object = Stage7AkamuState.new()
	collected_state.debug_spawn_starpoint_drop_at(collect_pos)
	collected_state.update(1.0 / 60.0, context, {
		"runtime_perk_state": runtime,
		"audio": audio,
	})
	_expect(runtime.collected == 1, "circular player overlap should award exactly one Muhon")
	_expect(
		int(collected_state.debug_get_starpoint_snapshot().get("drop_count", -1)) == 0,
		"an accepted Muhon should leave the carrier"
	)
	_expect(audio.collect_calls == 1, "accepted collection should play the shared collection cue")
	_expect(owner.redraw_calls == 1, "accepted collection should request a battle redraw")

	var missing_deps_state: Object = Stage7AkamuState.new()
	missing_deps_state.debug_spawn_starpoint_drop_at(collect_pos)
	missing_deps_state.update(1.0 / 60.0, _base_context(), {})
	_expect(
		int(missing_deps_state.debug_get_starpoint_snapshot().get("drop_count", 0)) == 1,
		"missing reward dependencies must keep the overlapping drop alive fail-loud"
	)

	var floor_state: Object = Stage7AkamuState.new()
	floor_state.debug_spawn_starpoint_drop_at(Vector2(100.0, 700.0))
	floor_state.debug_patch_starpoint_drop(0, {
		"pos": Vector2(100.0, 739.0),
		"vel": Vector2.ZERO,
		"life": 600.0,
	})
	floor_state.update(1.0 / 60.0, _base_context(), {"runtime_perk_state": runtime})
	_expect(
		int(floor_state.debug_get_starpoint_snapshot().get("drop_count", 1)) == 0,
		"a drop below play_height - size should expire without collection"
	)
	_expect(runtime.collected == 1, "floor expiry must not award Muhon")

	var dowsing_state: Object = Stage7AkamuState.new()
	dowsing_state.debug_spawn_starpoint_drop_at(Vector2(100.0, 300.0))
	dowsing_state.debug_patch_starpoint_drop(0, {"vel": Vector2.ZERO})
	dowsing_state.update(1.0 / 60.0, _base_context(), {
		"mythic_item_runtime": FakeDowsingRuntime.new(),
	})
	var dowsing_drop: Dictionary = (
		dowsing_state.debug_get_starpoint_snapshot().get("drops", []) as Array
	)[0]
	_expect(
		(_vector(dowsing_drop.get("vel", Vector2.ZERO))).x > 0.0,
		"the Stage 7 carrier should apply the shared dowsing attraction"
	)

	var lingpet_state: Object = Stage7AkamuState.new()
	var lingpet := FakeLingpetRuntime.new()
	var lingpet_runtime := FakeRuntimePerkState.new()
	lingpet_state.debug_spawn_starpoint_drop_at(Vector2(100.0, 300.0))
	lingpet_state.update(1.0 / 60.0, _base_context(), {
		"lingpet_egg_runtime": lingpet,
		"runtime_perk_state": lingpet_runtime,
	})
	_expect(lingpet.update_calls == 1, "the guardian-spirit starlight bridge should receive Stage 7 drops")
	_expect(lingpet_runtime.collected == 1, "a delivered starlight claim should award one Muhon")
	_expect(
		int(lingpet_state.debug_get_starpoint_snapshot().get("drop_count", 1)) == 0,
		"a delivered guardian-spirit claim should compact the accepted drop"
	)


func _verify_freeze_serve_wait_round_and_runtime_detection() -> void:
	var state: Object = Stage7AkamuState.new()
	state.debug_spawn_starpoint_drop_at(Vector2(100.0, 100.0))
	state.debug_patch_starpoint_drop(0, {"vel": Vector2(0.0, 4.0)})
	_expect(state.debug_has_runtime_state(), "a drop-only Stage 7 state should be detected as live runtime state")
	var before: Vector2 = _first_drop_pos(state)
	state.debug_begin_gameplay_freeze(0.2)
	state.update(0.1, _base_context())
	_expect_vector(
		_first_drop_pos(state),
		before,
		"the explicit Awakening gameplay freeze should stop Muhon motion"
	)
	state.update(0.1, _base_context())
	var after_freeze: Vector2 = _first_drop_pos(state)
	state.update(1.0 / 60.0, _base_context())
	var after_resume: Vector2 = _first_drop_pos(state)
	_expect(
		after_resume.distance_to(after_freeze) > 0.01,
		"Muhon motion should resume after the gameplay freeze completes"
	)

	var serve_context: Dictionary = _base_context()
	serve_context["waiting_for_serve"] = true
	serve_context["ball_active"] = false
	var before_serve: Vector2 = _first_drop_pos(state)
	state.update(1.0 / 60.0, serve_context)
	_expect(
		_first_drop_pos(state).distance_to(before_serve) > 0.01,
		"already-falling Muhon should continue through serve wait"
	)
	state.clear_round_transients()
	var cleared: Dictionary = state.debug_get_starpoint_snapshot()
	_expect(
		int(cleared.get("drop_count", -1)) == 0 and int(cleared.get("particle_count", -1)) == 0,
		"the score-round boundary should clear uncollected drops and their particles"
	)
	var drop_only_state: Object = Stage7AkamuState.new()
	drop_only_state.debug_spawn_starpoint_drop_at(Vector2(100.0, 100.0))
	_expect(drop_only_state.debug_has_runtime_state(), "drop-only runtime detection setup should be live")
	drop_only_state.clear_round_transients()
	_expect(
		not drop_only_state.debug_has_runtime_state(),
		"round cleanup should clear a drop-only runtime owner"
	)


func _verify_coordinate_contract_and_host_cleanup() -> void:
	var renderer: Object = Stage7AkamuPlayfieldRenderer.new()
	var payload: Dictionary = renderer.get_debug_starpoint_coordinate_payload(
		{"pos": Vector2(100.0, 200.0), "size": 12.0},
		{"game_offset": Vector2(30.0, 40.0), "render_scale": 1.5},
		Vector2(4.0, -2.0)
	)
	_expect_vector(
		payload.get("gpu_pos", Vector2.ZERO),
		Vector2(186.0, 337.0),
		"GPU Muhon slots should receive game_offset + (playfield_pos + shake) * render_scale"
	)
	_expect_close(float(payload.get("gpu_size", 0.0)), 18.0, "GPU Muhon size should scale once")
	_expect_vector(
		payload.get("fallback_pos", Vector2.ZERO),
		Vector2(104.0, 198.0),
		"CPU fallback should keep untransformed playfield coordinates"
	)
	_expect_close(float(payload.get("fallback_size", 0.0)), 12.0, "CPU fallback size should stay unscaled")

	var host: Node2D = CommonStarpointVisualHost.new()
	root.add_child(host)
	host.begin_frame()
	host.sync_drop({
		"pos": Vector2(100.0, 100.0),
		"size": 12.0,
		"life": 600.0,
		"glow_intensity": 1.0,
	})
	host.end_frame()
	_expect(host.visible, "host cleanup setup should expose one visible Muhon slot")
	var state: Object = Stage7AkamuState.new()
	state.debug_spawn_starpoint_drop_at(Vector2(100.0, 100.0))
	state.clear_round_transients()
	_expect(not host.visible, "round cleanup should hide every existing common Muhon host")
	host.free()


func _verify_cap_truncation_and_visual_contract() -> void:
	var state: Object = Stage7AkamuState.new()
	for _spawn_index in range(3):
		state.debug_spawn_shadow_clones(Vector2(380.0, 200.0), true)
	var snapshot: Dictionary = state.debug_get_clone_snapshot()
	_expect(
		int(snapshot.get("entity_count", 0)) == 8,
		"three awakened four-clone attempts should observe four hard-cap truncations"
	)
	_expect(
		int(snapshot.get("max_entities", 0)) == 8,
		"golden clones should share the unchanged eight-entity hard cap"
	)

	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd"
	)
	_expect(
		renderer_source.find("TEMP_GOLDEN_CLONE_TINT := Color(1.0, 0.82, 0.32)") >= 0,
		"golden sprite tint should retain the locked TEMP value"
	)
	_expect(
		renderer_source.find("TEMP_GOLDEN_CLONE_GLOW_ALPHA := 0.35") >= 0
			and renderer_source.find("TEMP_GOLDEN_CLONE_GLOW_RADIUS_SCALE := 1.15") >= 0,
		"golden bright-core underlay should retain both locked TEMP values"
	)
	_expect(
		renderer_source.find("VfxTextureCache.KEY_FLAT_DISC") >= 0
			and renderer_source.find("VfxTextureCache.KEY_AURA_GLOW_STACK") >= 0,
		"golden underlay should reuse existing baked textures without a new asset"
	)
	_expect(
		renderer_source.find("CommonStarpointVisualHost.draw_muhon_fallback") >= 0,
		"the CPU path should reuse the common Muhon flame fallback"
	)
	_expect(
		renderer_source.find("canvas.material") < 0,
		"the immediate renderer must not attempt a no-op canvas.material blend swap"
	)
	_expect(
		renderer_source.find("randf") < 0
			and renderer_source.find("randi") < 0
			and renderer_source.find("randomize") < 0,
		"golden presentation and Muhon drawing must not consume RNG"
	)


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"player_pos": Vector2(300.0, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_size": 20.0,
		"max_bounce_angle": 60.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 20.0,
		"last_hit_by": "player",
		"width": 760.0,
		"height": 750.0,
	}


func _clone_collision_scene() -> Dictionary:
	return {
		"previous_ball_pos": Vector2(380.0, 310.0),
		"ball_pos": Vector2(380.0, 130.0),
		"ball_vel": Vector2(0.0, -20.0),
	}


func _first_drop_pos(state: Object) -> Vector2:
	var drops: Array = state.debug_get_starpoint_snapshot().get("drops", [])
	return _vector((drops[0] as Dictionary).get("pos", Vector2.ZERO)) if not drops.is_empty() else Vector2.ZERO


func _advance(
	state: Object,
	duration_sec: float,
	context: Dictionary,
	deps: Dictionary = {}
) -> void:
	var remaining: float = duration_sec
	while remaining > 0.000001:
		var step: float = minf(0.1, remaining)
		state.update(step, context, deps)
		remaining -= step


func _vector(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect_vector(
	actual_value: Variant,
	expected_value: Variant,
	message: String,
	tolerance: float = 0.0001
) -> void:
	var actual: Vector2 = _vector(actual_value)
	var expected: Vector2 = _vector(expected_value)
	_expect(
		actual.distance_to(expected) <= tolerance,
		"%s (expected %s, got %s)" % [message, expected, actual]
	)


func _expect_close(
	actual: float,
	expected: float,
	message: String,
	tolerance: float = 0.0001
) -> void:
	_expect(
		absf(actual - expected) <= tolerance,
		"%s (expected %.6f, got %.6f)" % [message, expected, actual]
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
