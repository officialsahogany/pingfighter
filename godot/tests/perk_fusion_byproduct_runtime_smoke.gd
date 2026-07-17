extends SceneTree

const PerkFusionByproductRuntime := preload("res://scripts/characters/perk_fusion_byproduct_runtime.gd")
const BossSlowTiers := preload("res://scripts/status/boss_slow_tiers.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_no_ownership_is_a_noop()
	_verify_overload_is_one_shot_per_dash()
	_verify_reverb_refreshes_and_expires()
	_verify_golden_trajectory_round_cap()
	_verify_point_loss_payload_and_roll_boundary()
	_verify_point_loss_queue_survives_round_reset_and_consumes_once()
	_verify_round_and_full_reset_clear_transients()
	_verify_snapshot_is_detached()

	if _failures.is_empty():
		print("perk_fusion_byproduct_runtime_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_no_ownership_is_a_noop() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	runtime.on_player_dash([])
	_expect_close(runtime.consume_player_paddle_bounce_speed_multiplier(), 1.0, "unowned overload should not arm")
	runtime.on_skill_used([])
	_expect_close(runtime.get_player_move_speed_multiplier(), 1.0, "unowned reverb should not activate")
	_expect(runtime.on_wall_bounce([]) == 0, "unowned golden trajectory should award no gold")
	var result: Dictionary = runtime.on_player_point_lost([], 0.0)
	_expect(not result.has("static_field"), "unowned static field should not emit a slow payload")
	_expect(not bool(result.get("restore_dash_tokens", true)), "unowned recycle protocol should not restore dash tokens")


func _verify_overload_is_one_shot_per_dash() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	var owned := [PerkFusionByproductRuntime.OVERLOAD_CIRCUIT_ID]
	runtime.on_player_dash(owned)
	runtime.on_player_dash(owned)
	_expect_close(runtime.consume_player_paddle_bounce_speed_multiplier(), 1.15, "dash should arm one +15% paddle-bounce speed multiplier")
	_expect_close(runtime.consume_player_paddle_bounce_speed_multiplier(), 1.0, "overload should be consumed by the first paddle bounce only")
	runtime.on_player_dash(owned)
	_expect_close(runtime.consume_player_paddle_bounce_speed_multiplier(), 1.15, "a later dash should re-arm overload")


func _verify_reverb_refreshes_and_expires() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	var owned := [PerkFusionByproductRuntime.REVERB_ID]
	runtime.on_skill_used(owned)
	_expect_close(runtime.get_player_move_speed_multiplier(), 1.25, "skill use should activate the reverb move-speed boost")
	runtime.update(2.5)
	runtime.on_skill_used(owned)
	runtime.update(2.99)
	_expect_close(runtime.get_player_move_speed_multiplier(), 1.25, "retriggering reverb should refresh its full three-second duration")
	runtime.update(0.02)
	_expect_close(runtime.get_player_move_speed_multiplier(), 1.0, "reverb should expire after the refreshed duration")


func _verify_golden_trajectory_round_cap() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	var owned := [PerkFusionByproductRuntime.GOLDEN_TRAJECTORY_ID]
	var awarded_total := 0
	for _bounce_index in range(25):
		awarded_total += runtime.on_wall_bounce(owned)
	_expect(awarded_total == 40, "golden trajectory awards should stop at exactly 40 gold per round")
	_expect(runtime.get_round_golden_trajectory_gold() == 40, "round gold total should expose the capped award")
	_expect(runtime.on_wall_bounce(owned) == 0, "wall bounces after the round cap should award no gold")
	runtime.reset_round()
	_expect(runtime.get_round_golden_trajectory_gold() == 0, "round reset should clear the golden trajectory cap counter")
	_expect(runtime.on_wall_bounce(owned) == 2, "golden trajectory should award gold again in the next round")


func _verify_point_loss_payload_and_roll_boundary() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	var static_result: Dictionary = runtime.on_player_point_lost(
		[PerkFusionByproductRuntime.STATIC_FIELD_ID],
		0.0
	)
	var static_field: Dictionary = static_result.get("static_field", {}) as Dictionary
	_expect_close(float(static_field.get("boss_slow_multiplier", 0.0)), BossSlowTiers.WEAK, "static field should use the shared WEAK boss slow tier")
	_expect_close(float(static_field.get("duration_sec", 0.0)), 4.0, "static field should last four seconds")
	_expect(not bool(static_result.get("restore_dash_tokens", true)), "static field alone should not restore dash tokens")

	var recycle_owned := [PerkFusionByproductRuntime.RECYCLE_PROTOCOL_ID]
	var success: Dictionary = runtime.on_player_point_lost(recycle_owned, 0.2499)
	var failure: Dictionary = runtime.on_player_point_lost(recycle_owned, 0.25)
	_expect(bool(success.get("restore_dash_tokens", false)), "a recycle roll below 0.25 should restore all dash tokens")
	_expect(not bool(failure.get("restore_dash_tokens", true)), "a recycle roll at 0.25 should fail the strict 25% boundary")
	_expect(not success.has("static_field"), "recycle protocol alone should not emit static field data")


func _verify_point_loss_queue_survives_round_reset_and_consumes_once() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	runtime.queue_player_point_lost([
		PerkFusionByproductRuntime.STATIC_FIELD_ID,
		PerkFusionByproductRuntime.RECYCLE_PROTOCOL_ID,
	], 0.0)
	runtime.reset_round()
	var queued: Dictionary = runtime.consume_pending_point_loss_effects()
	_expect(queued.has("static_field"), "queued static field should survive old-round transient cleanup")
	_expect(bool(queued.get("restore_dash_tokens", false)), "queued recycle success should survive old-round transient cleanup")
	_expect(runtime.consume_pending_point_loss_effects().is_empty(), "point-loss effects should be consumed exactly once")
	runtime.queue_player_point_lost([PerkFusionByproductRuntime.STATIC_FIELD_ID], 1.0)
	runtime.reset()
	_expect(runtime.consume_pending_point_loss_effects().is_empty(), "full reset should discard a pending point-loss effect")


func _verify_round_and_full_reset_clear_transients() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	var all_owned := [
		PerkFusionByproductRuntime.OVERLOAD_CIRCUIT_ID,
		PerkFusionByproductRuntime.REVERB_ID,
		PerkFusionByproductRuntime.GOLDEN_TRAJECTORY_ID,
	]
	runtime.on_player_dash(all_owned)
	runtime.on_skill_used(all_owned)
	runtime.on_wall_bounce(all_owned)
	runtime.reset_round()
	_expect_close(runtime.consume_player_paddle_bounce_speed_multiplier(), 1.0, "round reset should clear an armed overload")
	_expect_close(runtime.get_player_move_speed_multiplier(), 1.0, "round reset should clear reverb")
	_expect(runtime.get_round_golden_trajectory_gold() == 0, "round reset should clear earned round gold")

	runtime.on_player_dash(all_owned)
	runtime.on_skill_used(all_owned)
	runtime.on_wall_bounce(all_owned)
	runtime.reset()
	_expect_close(runtime.consume_player_paddle_bounce_speed_multiplier(), 1.0, "full reset should clear an armed overload")
	_expect_close(runtime.get_player_move_speed_multiplier(), 1.0, "full reset should clear reverb")
	_expect(runtime.get_round_golden_trajectory_gold() == 0, "full reset should clear the round gold counter")


func _verify_snapshot_is_detached() -> void:
	var runtime := PerkFusionByproductRuntime.new()
	runtime.on_player_dash([PerkFusionByproductRuntime.OVERLOAD_CIRCUIT_ID])
	runtime.on_skill_used([PerkFusionByproductRuntime.REVERB_ID])
	runtime.on_wall_bounce([PerkFusionByproductRuntime.GOLDEN_TRAJECTORY_ID])
	var snapshot: Dictionary = runtime.get_snapshot()
	snapshot["overload_armed"] = false
	snapshot["reverb_remaining_sec"] = 0.0
	snapshot["golden_trajectory_round_gold"] = 999
	var fresh_snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(fresh_snapshot.get("overload_armed", false)), "mutating a snapshot should not disarm live overload state")
	_expect(float(fresh_snapshot.get("reverb_remaining_sec", 0.0)) > 0.0, "mutating a snapshot should not expire live reverb state")
	_expect(int(fresh_snapshot.get("golden_trajectory_round_gold", 0)) == 2, "mutating a snapshot should not alter the live round gold counter")


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s (actual=%s expected=%s)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
