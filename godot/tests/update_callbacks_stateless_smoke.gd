extends SceneTree

const UpdateCallbacks := preload("res://scripts/core/battle_scene_update_callbacks.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 3
	var marker := "owner-a"
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeActorDriver:
	extends RefCounted

	var player_delta := 0.0
	var boss_delta := 0.0
	var player_owner_marker := ""
	var boss_owner_marker := ""

	func update_player_control(owner: Object, _registry: Object, delta: float) -> void:
		player_delta = delta
		player_owner_marker = str(owner.marker)

	func update_boss_ai(owner: Object, _registry: Object, delta: float) -> void:
		boss_delta = delta
		boss_owner_marker = str(owner.marker)


class FakeItemDriver:
	extends RefCounted

	var update_delta := 0.0

	func update_items(_owner: Object, _registry: Object, delta: float) -> void:
		update_delta = delta


class FakeRuntimePerkDriver:
	extends RefCounted

	var update_delta := 0.0

	func update_runtime_perk_resume(_owner: Object, _registry: Object, delta: float) -> void:
		update_delta = delta


class FakeSkillTooltipDriver:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0
	var redraw_calls := 0
	var hide_calls := 0

	func pause_skill_cooldowns(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func resume_skill_cooldowns(_owner: Object, _registry: Object) -> void:
		resume_calls += 1

	func queue_tooltip_overlay_redraw(_owner: Object, _registry: Object) -> void:
		redraw_calls += 1

	func hide_tooltip_overlay(_registry: Object) -> void:
		hide_calls += 1


class FakeBallDriver:
	extends RefCounted

	var update_delta := 0.0
	var serve_calls := 0
	var reset_calls := 0
	var drive_reset_calls := 0

	func update_ball(
		_owner: Object,
		_registry: Object,
		delta: float,
		score_callback: Callable,
		round_restart_callback: Callable
	) -> void:
		update_delta = delta
		score_callback.call("player")
		round_restart_callback.call("manual_restart")

	func serve_ball(_owner: Object, _registry: Object) -> void:
		serve_calls += 1

	func reset_ball(_owner: Object, _registry: Object) -> void:
		reset_calls += 1

	func reset_drive_input_frames(_registry: Object) -> void:
		drive_reset_calls += 1


class FakeEffectsDriver:
	extends RefCounted

	var update_delta := 0.0

	func update_effects(_owner: Object, _registry: Object, delta: float) -> void:
		update_delta = delta


class FakeMatchEventDriver:
	extends RefCounted

	var score_side := ""
	var restart_reason := ""
	var scoreboard_delta := 0.0
	var score_owner_marker := ""
	var restart_owner_marker := ""
	var scoreboard_owner_marker := ""

	func handle_score_event(scoring_side: String, owner: Object, _registry: Object) -> void:
		score_side = scoring_side
		score_owner_marker = str(owner.marker)

	func handle_round_restart_event(reason: String, owner: Object, _registry: Object) -> void:
		restart_reason = reason
		restart_owner_marker = str(owner.marker)

	func update_scoreboard(delta: float, owner: Object, _registry: Object) -> void:
		scoreboard_delta = delta
		scoreboard_owner_marker = str(owner.marker)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	var owner := FakeOwner.new()
	var actor := FakeActorDriver.new()
	var item := FakeItemDriver.new()
	var runtime_perk := FakeRuntimePerkDriver.new()
	var skill_tooltip := FakeSkillTooltipDriver.new()
	var ball := FakeBallDriver.new()
	var effects := FakeEffectsDriver.new()
	var match_event := FakeMatchEventDriver.new()
	var registry := FakeRegistry.new({
		"battle_scene_actor_update_driver": actor,
		"battle_scene_item_update_driver": item,
		"battle_scene_runtime_perk_update_driver": runtime_perk,
		"battle_scene_skill_tooltip_driver": skill_tooltip,
		"battle_scene_ball_update_driver": ball,
		"battle_scene_effects_update_driver": effects,
		"battle_scene_match_event_driver": match_event,
	})
	var callback_builder: Object = UpdateCallbacks.new()
	var callbacks: Dictionary = callback_builder.build_frame_callbacks(owner, registry)

	callbacks["update_player_control"].call(0.11)
	callbacks["update_boss_ai"].call(0.12)
	callbacks["update_active_items"].call(0.13)
	callbacks["update_runtime_perk_resume"].call(0.14)
	callbacks["pause_skill_cooldowns"].call()
	callbacks["resume_skill_cooldowns"].call()
	callbacks["queue_skill_orb_tooltip_overlay_redraw"].call()
	callbacks["hide_skill_orb_tooltip_overlay"].call()
	callbacks["serve_ball"].call()
	callbacks["update_effects"].call(0.15)
	callbacks["update_ball"].call(0.16)
	callbacks["update_scoreboard"].call(0.17)
	callbacks["queue_redraw"].call()
	callback_builder.reset_ball(owner, registry)

	_expect(abs(actor.player_delta - 0.11) <= 0.001 and actor.player_owner_marker == "owner-a", "player callback should forward owner and delta")
	_expect(abs(actor.boss_delta - 0.12) <= 0.001 and actor.boss_owner_marker == "owner-a", "boss callback should forward owner and delta")
	_expect(abs(item.update_delta - 0.13) <= 0.001, "item callback should forward delta")
	_expect(abs(runtime_perk.update_delta - 0.14) <= 0.001, "runtime perk callback should forward delta")
	_expect(skill_tooltip.pause_calls == 1 and skill_tooltip.resume_calls == 1, "skill tooltip cooldown callbacks should route")
	_expect(skill_tooltip.redraw_calls == 1 and skill_tooltip.hide_calls == 1, "skill tooltip overlay callbacks should route")
	_expect(ball.serve_calls == 1, "serve callback should route")
	_expect(abs(effects.update_delta - 0.15) <= 0.001, "effects callback should forward delta")
	_expect(abs(ball.update_delta - 0.16) <= 0.001, "ball callback should forward delta")
	_expect(match_event.score_side == "player" and match_event.score_owner_marker == "owner-a", "score callback should route to match event driver")
	_expect(match_event.restart_reason == "manual_restart" and match_event.restart_owner_marker == "owner-a", "round restart callback should route to match event driver")
	_expect(abs(match_event.scoreboard_delta - 0.17) <= 0.001 and match_event.scoreboard_owner_marker == "owner-a", "scoreboard callback should route to match event driver")
	_expect(ball.reset_calls == 1, "public reset-ball callback should route")
	_expect(ball.drive_reset_calls == 0, "stateless callback table should not own reset-game fanout")
	_expect(owner.redraw_count == 1, "queue_redraw callback should route")

	if _failures.is_empty():
		print("update_callbacks_stateless_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
