extends SceneTree

const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const BattleSceneBallUpdateDriver := preload("res://scripts/core/battle_scene_ball_update_driver.gd")

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var requested_keys: Array[String] = []
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		if instances.has(key):
			return instances[key]
		var instance := RefCounted.new()
		instances[key] = instance
		return instance


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var selected_character_type := "viper"
	var player_pos := Vector2(10.0, 20.0)
	var boss_pos := Vector2(30.0, 40.0)
	var ball_pos := Vector2.ZERO
	var ball_pos_prev := Vector2.ZERO
	var ball_interp_reset_requested := false
	var ball_interp_last_physics_usec := 0
	var boss_vel := 99.0
	var player_speed := 99.0


class FakeBallRoundState:
	extends RefCounted

	func build_reset_snapshot(width: float, height: float) -> Dictionary:
		return {
			"ball_pos": Vector2(width * 0.5, height * 0.5),
		}

	func build_serve_snapshot(
		_player_is_serving: bool,
		player_pos: Vector2,
		_boss_pos: Vector2,
		_player_y: float,
		_boss_y: float,
		_player_paddle_width: float,
		_boss_paddle_width: float,
		_boss_hitbox_height: float,
		_ball_size: float,
		_ball_render_radius: float,
		_ball_physics: Object
	) -> Dictionary:
		return {
			"ball_pos": player_pos,
			"ball_vel": Vector2(0.0, -1.0),
		}


class FakeContextBuilder:
	extends RefCounted

	var round_context: Dictionary = {}

	func build_reset_config(_owner: Object) -> Dictionary:
		return {
			"width": 760.0,
			"height": 750.0,
			"player_pos": Vector2.ZERO,
			"boss_pos": Vector2.ZERO,
			"player_paddle_width": 155.0,
			"boss_paddle_width": 155.0,
			"player_y": 700.0,
		}

	func build_serve_config(_owner: Object) -> Dictionary:
		return {
			"player_pos": Vector2(10.0, 20.0),
			"boss_pos": Vector2(30.0, 40.0),
			"player_y": 700.0,
			"boss_y": 25.0,
			"player_paddle_width": 155.0,
			"boss_paddle_width": 100.0,
			"boss_hitbox_height": 50.0,
			"ball_size": 14.0,
			"ball_render_radius": 7.0,
			"ball_visual_type": "energy",
		}

	func build_round_deps(_registry: Object, runtime_context: Dictionary = {}) -> Dictionary:
		round_context = runtime_context.duplicate()
		return {
			"ball_round_state": FakeBallRoundState.new(),
		}


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_round_deps_use_current_smasher_stage()
	_verify_round_deps_use_current_viper_stage()
	_verify_round_deps_use_current_stage5()
	_verify_round_deps_cache_reuses_current_context()
	_verify_round_deps_exposes_per_key_perf()
	_verify_empty_context_keeps_legacy_full_deps()
	_verify_ball_update_driver_forwards_owner_context()
	_verify_ball_update_driver_forwards_serve_context()

	if _failures.is_empty():
		print("ball_round_deps_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_round_deps_use_current_smasher_stage() -> void:
	var deps_context := BallDependencyContext.new()
	var registry := FakeRegistry.new()
	deps_context.build_round_deps(registry, {
		"current_stage": 1,
		"selected_character_type": "smasher",
	})

	_expect(registry.requested_keys.has("smasher_power_smash_state"), "smasher round deps should request smasher power state")
	_expect(registry.requested_keys.has("stage1_balloon_event"), "stage 1 round deps should request stage 1 balloon event")
	_expect(not registry.requested_keys.has("viper_skill_runtime"), "smasher round deps should not wake viper runtime")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "smasher round deps should not wake commando runtime")
	_expect(not registry.requested_keys.has("stage4_pillar_background"), "stage 1 round deps should not wake stage 4 background")
	_expect(not registry.requested_keys.has("stage5_hongryun_state"), "stage 1 round deps should not wake stage 5 state")
	_expect(not registry.requested_keys.has("stage5_hongryun_fire_machine_event"), "stage 1 round deps should not wake Stage 5 fire-machine event")


func _verify_round_deps_use_current_viper_stage() -> void:
	var deps_context := BallDependencyContext.new()
	var registry := FakeRegistry.new()
	deps_context.build_round_deps(registry, {
		"current_stage": 4,
		"selected_character_type": "viper",
	})

	_expect(registry.requested_keys.has("viper_skill_runtime"), "viper round deps should request viper runtime")
	_expect(registry.requested_keys.has("stage4_pillar_background"), "stage 4 round deps should request stage 4 background")
	_expect(not registry.requested_keys.has("smasher_power_smash_state"), "viper round deps should not wake smasher power state")
	_expect(not registry.requested_keys.has("commando_firearm_runtime"), "viper round deps should not wake commando runtime")
	_expect(not registry.requested_keys.has("stage1_balloon_event"), "stage 4 round deps should not wake stage 1 balloon event")


func _verify_round_deps_use_current_stage5() -> void:
	var deps_context := BallDependencyContext.new()
	var registry := FakeRegistry.new()
	deps_context.build_round_deps(registry, {
		"current_stage": 5,
		"selected_character_type": "smasher",
	})

	_expect(registry.requested_keys.has("stage5_hongryun_state"), "stage 5 round deps should request Hongryun state")
	_expect(registry.requested_keys.has("stage5_hongryun_fire_machine_event"), "stage 5 round deps should request Hongryun fire-machine event")
	_expect(registry.requested_keys.has("stage5_hongryun_actor_renderer"), "stage 5 round deps should request Hongryun actor renderer")
	_expect(not registry.requested_keys.has("stage4_ponk_skill_state"), "stage 5 round deps should not wake Stage 4 Ponk state")


func _verify_round_deps_cache_reuses_current_context() -> void:
	var deps_context := BallDependencyContext.new()
	var registry := FakeRegistry.new()
	deps_context.build_round_deps(registry, {
		"current_stage": 1,
		"selected_character_type": "smasher",
	})
	var first_request_count := registry.requested_keys.size()
	deps_context.build_round_deps(registry, {
		"current_stage": 1,
		"selected_character_type": "smasher",
	})
	_expect(registry.requested_keys.size() == first_request_count, "matching round context should reuse cached deps")
	deps_context.build_round_deps(registry, {
		"current_stage": 4,
		"selected_character_type": "smasher",
	})
	_expect(registry.requested_keys.size() > first_request_count, "changed round context should rebuild deps")


func _verify_round_deps_exposes_per_key_perf() -> void:
	var deps_context := BallDependencyContext.new()
	var registry := FakeRegistry.new()
	var perf_logger := FakePerfLogger.new()
	deps_context.build_round_deps(registry, {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"_perf_logger": perf_logger,
		"_perf_prefix": "process.reset_ball.build_deps",
	})

	_expect(
		perf_logger.labels.has("process.reset_ball.build_deps.common.ball_round_state"),
		"round deps should expose common per-key timings"
	)
	_expect(
		perf_logger.labels.has("process.reset_ball.build_deps.character.smasher_power_smash_state"),
		"round deps should expose character per-key timings"
	)
	_expect(
		perf_logger.labels.has("process.reset_ball.build_deps.stage.stage1_balloon_event"),
		"round deps should expose stage per-key timings"
	)


func _verify_empty_context_keeps_legacy_full_deps() -> void:
	var deps_context := BallDependencyContext.new()
	var registry := FakeRegistry.new()
	deps_context.build_round_deps(registry)

	_expect(registry.requested_keys.has("viper_skill_runtime"), "empty round context should keep the legacy full-deps path")
	_expect(registry.requested_keys.has("commando_firearm_runtime"), "empty round context should keep commando legacy deps")
	_expect(registry.requested_keys.has("stage5_hongryun_state"), "empty round context should keep stage 5 legacy deps")
	_expect(registry.requested_keys.has("stage5_hongryun_fire_machine_event"), "empty round context should keep Stage 5 fire-machine cleanup deps")
	_expect(registry.requested_keys.has("stage5_hongryun_actor_renderer"), "empty round context should keep stage 5 actor renderer cleanup deps")

	var perf_only_registry := FakeRegistry.new()
	deps_context.build_round_deps(perf_only_registry, {
		"_perf_logger": FakePerfLogger.new(),
		"_perf_prefix": "process.reset_ball.build_deps",
	})
	_expect(
		perf_only_registry.requested_keys.has("viper_skill_runtime"),
		"perf-only round context should still keep the legacy full-deps path"
	)


func _verify_ball_update_driver_forwards_owner_context() -> void:
	var driver := BattleSceneBallUpdateDriver.new()
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new()
	registry.instances["ball_update_context"] = context_builder
	registry.instances["ball_round_controller"] = BallRoundController.new()
	registry.instances["battle_perf_logger"] = perf_logger

	driver.reset_ball(owner, registry)

	_expect(int(context_builder.round_context.get("current_stage", 0)) == 3, "reset_ball should pass owner stage into round deps")
	_expect(str(context_builder.round_context.get("selected_character_type", "")) == "viper", "reset_ball should pass owner character into round deps")
	_expect(owner.player_speed == 0.0, "reset_ball should still apply reset result to owner")
	_expect(perf_logger.labels.has("process.reset_ball.build_deps"), "reset_ball should expose build_deps timing")
	_expect(perf_logger.labels.has("process.reset_ball.controller"), "reset_ball should expose controller timing")


func _verify_ball_update_driver_forwards_serve_context() -> void:
	var driver := BattleSceneBallUpdateDriver.new()
	var owner := FakeOwner.new()
	var context_builder := FakeContextBuilder.new()
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new()
	registry.instances["ball_update_context"] = context_builder
	registry.instances["ball_round_controller"] = BallRoundController.new()
	registry.instances["battle_perf_logger"] = perf_logger

	driver.serve_ball(owner, registry)

	_expect(int(context_builder.round_context.get("current_stage", 0)) == 3, "serve_ball should pass owner stage into round deps")
	_expect(str(context_builder.round_context.get("selected_character_type", "")) == "viper", "serve_ball should pass owner character into round deps")
	_expect(not context_builder.round_context.is_empty(), "serve_ball should avoid the legacy empty-context round deps path")
	_expect(perf_logger.labels.has("physics.serve_ball.build_deps"), "serve_ball should expose build_deps timing")
	_expect(perf_logger.labels.has("physics.serve_ball.controller"), "serve_ball should expose controller timing")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
