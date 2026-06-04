extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleUpdateBossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const CleanseState := preload("res://scripts/characters/smasher_cleanse_state.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")
const Stage3CurseControlInputProxy := preload("res://scripts/stages/stage3/stage3_curse_control_input_proxy.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

var _failures: Array[String] = []


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class FakeActiveItemRuntime:
	extends RefCounted

	func get_boss_ai_context() -> Dictionary:
		return {
			"active_item_grenade_stun_active": false,
			"active_item_flare_confusion_active": false,
			"active_item_spider_mine_slow_active": false,
		}

	func get_actor_draw_context() -> Dictionary:
		return {
			"active_item_boss_stun_active": false,
			"active_item_boss_confusion_active": false,
			"active_item_boss_spider_slow_active": false,
		}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var ai_mode := "champion"
	var ball_active := true
	var player_pos := Vector2(300.0, 700.0)
	var boss_pos := Vector2(330.0, 25.0)
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2.ZERO


class FakeSkillConfig:
	extends RefCounted

	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "cleanse"

	func get_skill_cost(skill_name: String) -> float:
		return 100.0 if skill_name == "cleanse" else 0.0


class FakeSkillState:
	extends RefCounted

	func get_configured_cooldown_remaining(_skill_name: String, _current_msec: int, _skill_config: Object) -> float:
		return 0.0

	func trigger_configured_cooldown(_skill_name: String, _current_msec: int, _skill_config: Object) -> void:
		pass


func _init() -> void:
	_verify_registry_exposes_status_module()
	_verify_status_context_keys_and_decay()
	_verify_boss_stun_knockback_can_end_before_stun()
	_verify_slow_stacks_by_strongest_multiplier()
	_verify_reverse_status_drives_input_proxy()
	_verify_stun_status_locks_player_control()
	_verify_burn_status_exports_stage4_draw_context()
	_verify_stage2_immunity_clears_disable_statuses()
	_verify_context_builders_merge_shared_status_after_legacy_false_keys()
	_verify_cleanse_reads_and_clears_shared_player_status()

	if _failures.is_empty():
		print("status_effect_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_registry_exposes_status_module() -> void:
	var registry := GameplayModuleRegistry.new()
	var status_state: Object = registry.get_instance("status_effect_state")
	_expect(status_state != null, "gameplay registry should expose shared status effect state")
	_expect(status_state.has_method("apply_status"), "shared status effect state should expose apply_status")


func _verify_status_context_keys_and_decay() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "스턴", 12.0, {"knockback_vel": -7.5}, "test_stun")
	var actor_context: Dictionary = status.get_actor_draw_context()
	var boss_context: Dictionary = status.get_boss_ai_context()
	_expect(bool(actor_context.get("active_item_boss_stun_active", false)), "boss stun should emit legacy actor stun key")
	_expect(bool(boss_context.get("active_item_grenade_stun_active", false)), "boss stun should emit legacy AI stun key")
	_expect(is_equal_approx(float(boss_context.get("active_item_grenade_knockback_vel", 0.0)), -7.5), "boss stun should preserve knockback velocity")
	status.update(6.0)
	_expect(status.has_status("boss", "stun"), "status should remain active while timer has frames")
	status.update(6.0)
	_expect(not status.has_status("boss", "stun"), "status should expire when timer reaches zero")


func _verify_boss_stun_knockback_can_end_before_stun() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "stun", 90.0, {
		"knockback_vel": 40.0,
		"knockback_active": true,
		"knockback_frames": 18.0,
		"knockback_decay_per_frame": 0.85,
	}, "bazooka_like")
	var initial_context: Dictionary = status.get_boss_ai_context()
	_expect(bool(initial_context.get("active_item_grenade_knockback_active", false)), "timed boss knockback should start active")
	_expect(is_equal_approx(float(initial_context.get("active_item_grenade_knockback_vel", 0.0)), 40.0), "timed boss knockback should expose the initial velocity")
	status.update(9.0)
	var mid_context: Dictionary = status.get_boss_ai_context()
	_expect(status.has_status("boss", "stun"), "timed boss knockback should keep the stun while knockback decays")
	_expect(bool(mid_context.get("active_item_grenade_knockback_active", false)), "timed boss knockback should still be active before its motion window ends")
	_expect(abs(float(mid_context.get("active_item_grenade_knockback_vel", 0.0))) < 40.0, "timed boss knockback should decay instead of staying constant")
	status.update(9.0)
	var end_context: Dictionary = status.get_boss_ai_context()
	_expect(status.has_status("boss", "stun"), "timed boss knockback should leave the stun active after motion ends")
	_expect(not bool(end_context.get("active_item_grenade_knockback_active", true)), "timed boss knockback should stop before stun expiry")
	_expect(is_equal_approx(float(end_context.get("active_item_grenade_knockback_vel", -1.0)), 0.0), "inactive timed knockback should expose zero boss velocity")


func _verify_slow_stacks_by_strongest_multiplier() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "slow", 60.0, {"multiplier": 0.70}, "soft_slow")
	status.apply_status("boss", "둔화", 30.0, {"multiplier": 0.40}, "hard_slow")
	var slow_status: Dictionary = status.get_status("boss", "slow")
	_expect(is_equal_approx(float(slow_status.get("multiplier", 0.0)), 0.40), "slow should choose the strongest active multiplier")
	var boss_context: Dictionary = status.get_boss_ai_context()
	_expect(is_equal_approx(float(boss_context.get("active_item_spider_mine_slow_factor", 0.0)), 0.40), "boss AI context should receive strongest slow multiplier")
	status.update(31.0)
	slow_status = status.get_status("boss", "slow")
	_expect(is_equal_approx(float(slow_status.get("multiplier", 0.0)), 0.70), "slow should fall back to weaker source after strongest expires")


func _verify_reverse_status_drives_input_proxy() -> void:
	var status := StatusEffectState.new()
	status.apply_status("player", "반전", 60.0, {}, "test_reverse")
	var input := FakeInputReader.new()
	input.snapshot = {
		"left_pressed": false,
		"right_pressed": true,
		"direction": 1.0,
		"power_smash_direction": 1,
	}
	var proxy: Object = Stage3CurseControlInputProxy.new().configure(input, null, status)
	var reversed_snapshot: Dictionary = proxy.get_snapshot()
	_expect(bool(reversed_snapshot.get("left_pressed", false)), "shared reverse should expose raw right input as left")
	_expect(not bool(reversed_snapshot.get("right_pressed", true)), "shared reverse should clear right when input is flipped")
	_expect(is_equal_approx(float(reversed_snapshot.get("direction", 0.0)), -1.0), "shared reverse should flip horizontal direction")
	_expect(int(reversed_snapshot.get("power_smash_direction", 0)) == -1, "shared reverse should flip power-smash direction")


func _verify_stun_status_locks_player_control() -> void:
	var status := StatusEffectState.new()
	status.apply_status("player", "stun", 48.0, {}, "test_stun")
	var control_context: Dictionary = status.get_player_control_context()
	_expect(bool(control_context.get("player_stun_active", false)), "shared player stun should be exposed to player control context")
	_expect(float(control_context.get("player_stun_ratio", 0.0)) > 0.0, "shared player stun control context should include a remaining ratio")
	var actor_context: Dictionary = status.get_actor_draw_context()
	_expect(bool(actor_context.get("status_player_stun_active", false)), "shared player stun should be exposed to actor draw context")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/status/status_effect_overlay_renderer.gd")
	_expect(overlay_source.find("draw_player_status_overlays") >= 0 and overlay_source.find("_draw_player_stun_stars") >= 0, "shared status overlay should provide player stun star drawing")
	var player_renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
	_expect(player_renderer_source.find("draw_player_status_overlays") >= 0, "shared player renderer should call player stun status overlays")

	var input := FakeInputReader.new()
	input.snapshot = {
		"left_pressed": false,
		"right_pressed": true,
		"up_pressed": true,
		"down_pressed": true,
		"action_pressed": true,
		"action_just_pressed": true,
		"direction": 1.0,
		"power_smash_direction": 1,
	}
	var proxy: Object = Stage3CurseControlInputProxy.new().configure(input, null, status)
	var locked_snapshot: Dictionary = proxy.get_snapshot()
	_expect(not bool(locked_snapshot.get("left_pressed", true)), "shared stun should clear left input")
	_expect(not bool(locked_snapshot.get("right_pressed", true)), "shared stun should clear right input")
	_expect(not bool(locked_snapshot.get("down_pressed", true)), "shared stun should clear dash input")
	_expect(not bool(locked_snapshot.get("action_pressed", true)), "shared stun should clear action input")
	_expect(is_equal_approx(float(locked_snapshot.get("direction", 1.0)), 0.0), "shared stun should zero horizontal direction")
	_expect(int(locked_snapshot.get("power_smash_direction", 1)) == 0, "shared stun should zero power-smash direction")

	var controller := SmasherPlayerController.new()
	var result: Dictionary = controller.update(
		1.0 / 60.0,
		0,
		Vector2(300.0, 700.0),
		6.0,
		{
			"play_left": 0.0,
			"play_right": 760.0,
			"paddle_width": 155.0,
			"paddle_height": 50.0,
			"paddle_max_speed": 6.0,
			"paddle_accel": 0.5,
			"paddle_decel": 0.5,
			"paddle_turn_decel": 1.0,
			"special_gauge": 0.0,
		},
		{
			"input_reader": input,
			"movement_state": PlayerMovementState.new(),
			"status_effect_state": status,
		}
	)
	var moved_pos: Vector2 = result.get("player_pos", Vector2.ZERO)
	_expect(is_equal_approx(moved_pos.x, 300.0), "shared stun should stop player drift from the current speed")
	_expect(is_equal_approx(float(result.get("player_speed", -1.0)), 0.0), "shared stun should return zero player speed")

	status.update(48.0)
	var raw_snapshot: Dictionary = proxy.get_snapshot()
	_expect(bool(raw_snapshot.get("right_pressed", false)), "expired shared stun should restore raw right input")
	_expect(is_equal_approx(float(raw_snapshot.get("direction", 0.0)), 1.0), "expired shared stun should restore raw direction")


func _verify_burn_status_exports_stage4_draw_context() -> void:
	var status := StatusEffectState.new()
	status.apply_status("player", "burn", 30.0, {"cleansable": true}, "stage4_moon_fragment")
	_expect(status.has_status("player", "burn"), "player burn should be tracked by the shared status state")
	_expect(status.has_status_effect("player", true), "player burn should count as a cleansable status")
	var actor_context: Dictionary = status.get_actor_draw_context()
	_expect(bool(actor_context.get("status_player_burn_active", false)), "player burn should emit shared draw context")
	_expect(bool(actor_context.get("stage4_player_burn_active", false)), "player burn should emit Stage 4 burn draw context")
	status.clear_player_status_effects()
	_expect(not status.has_status("player", "burn"), "cleanse should clear player burn through shared status cleanup")


func _verify_stage2_immunity_clears_disable_statuses() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "stun", 60.0, {}, "stun")
	status.apply_status("boss", "confusion", 60.0, {}, "confusion")
	status.apply_status("boss", "slow", 60.0, {"multiplier": 0.55}, "slow")
	status.update(1.0, {
		"current_stage": 2,
		"stage2_speed_defense_status_immunity_active": true,
	}, {})
	_expect(not status.has_status("boss", "stun"), "Stage 2 speed defense should clear shared boss stun")
	_expect(not status.has_status("boss", "confusion"), "Stage 2 speed defense should clear shared boss confusion")
	_expect(status.has_status("boss", "slow"), "Stage 2 speed defense should preserve slow parity with existing item behavior")


func _verify_context_builders_merge_shared_status_after_legacy_false_keys() -> void:
	var status := StatusEffectState.new()
	status.apply_status("boss", "confusion", 60.0, {}, "test_confusion")
	status.apply_status("boss", "slow", 60.0, {"multiplier": 0.35}, "test_slow")
	status.apply_status("player", "reverse", 60.0, {}, "test_reverse")

	var registry := FakeRegistry.new()
	registry.instances = {
		"active_item_runtime": FakeActiveItemRuntime.new(),
		"status_effect_state": status,
	}
	var owner := FakeOwner.new()
	var ai_builder := BattleUpdateBossAiContextBuilder.new()
	var ai_context: Dictionary = ai_builder.build_context(owner, registry)
	_expect(bool(ai_context.get("active_item_flare_confusion_active", false)), "boss AI builder should keep shared confusion after legacy false active-item context")
	_expect(is_equal_approx(float(ai_context.get("active_item_spider_mine_slow_factor", 0.0)), 0.35), "boss AI builder should merge shared slow multiplier")

	var draw_builder := BattleDrawActorContext.new()
	var actor_context: Dictionary = draw_builder.build({
		"current_stage": 3,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
	}, {
		"active_item_runtime": FakeActiveItemRuntime.new(),
		"status_effect_state": status,
	})
	_expect(bool(actor_context.get("active_item_boss_confusion_active", false)), "actor context should keep shared boss confusion after legacy false draw context")
	_expect(bool(actor_context.get("stage3_curse_reverse_active", false)), "actor context should expose shared player reverse through Stage 3 draw key")


func _verify_cleanse_reads_and_clears_shared_player_status() -> void:
	var status := StatusEffectState.new()
	status.apply_status("player", "reverse", 60.0, {}, "cleanse_test")
	var cleanse := CleanseState.new()
	var result: Dictionary = cleanse.update_input(
		{"up_pressed": true},
		1000,
		150.0,
		Vector2(300.0, 640.0),
		{"paddle_width": 155.0, "paddle_height": 50.0},
		{
			"status_effect_state": status,
			"skill_config": FakeSkillConfig.new(),
			"skill_state": FakeSkillState.new(),
		}
	)
	_expect(bool(result.get("activated", false)), "cleanse should activate from shared player status")
	_expect(not status.has_status("player", "reverse"), "cleanse should clear shared player status")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
