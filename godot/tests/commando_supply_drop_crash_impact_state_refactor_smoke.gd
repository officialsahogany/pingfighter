extends SceneTree

const IMPACT_STATE_PATH := "res://scripts/characters/commando_supply_drop_crash_impact_state.gd"
const CRASH_RESPONSE_PATH := "res://scripts/characters/commando_supply_drop_crash_response.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_arm_and_blast_window()
	_verify_ball_impulse_is_consumed_once()
	_verify_player_knockback_gate()
	_verify_snapshot_restore_and_reset()

	if _failures.is_empty():
		print("commando_supply_drop_crash_impact_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(IMPACT_STATE_PATH), "Commando Supply Drop crash impact should have a focused state owner")
	if not FileAccess.file_exists(IMPACT_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(IMPACT_STATE_PATH)
	var response_source := FileAccess.get_file_as_string(CRASH_RESPONSE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropCrashImpactState := preload(\"%s\")" % IMPACT_STATE_PATH) >= 0,
		"Supply Drop host should preload the focused crash-impact state"
	)
	_expect(
		host_source.find("var _crash_impact_state: Object = CommandoSupplyDropCrashImpactState.new()") >= 0,
		"Supply Drop host should retain one crash-impact state instance"
	)
	for marker in [
		"func reset(",
		"func arm(",
		"func advance(",
		"func has_active_blast(",
		"func is_player_knockback_pending(",
		"func mark_player_knocked(",
		"func consume_ball_impulse(",
		"func build_blast_zone(",
		"func get_snapshot(",
		"func restore(",
	]:
		_expect(owner_source.find(marker) >= 0, "crash-impact owner should implement %s" % marker)
	for moved_marker in [
		"var _pending_crash_ball_impulse",
		"var _crash_ball_impulse_center",
		"var crash_blast_timer",
		"var crash_blast_center",
		"var _crash_blast_player_knocked",
		"func _arm_crash_ball_impulse(",
		"func _build_crash_blast_zone(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain crash-impact state marker %s" % moved_marker)
	_expect(
		host_source.find("_crash_impact_state.arm(impact_pos, AIRCRAFT_CRASH_BLAST_SECONDS)") >= 0,
		"crash completion should arm the focused impact state"
	)
	_expect(
		host_source.find("_crash_response.apply_pending_ball_impulse(") >= 0,
		"ball update should delegate the focused one-shot impulse response"
	)
	_expect(
		response_source.find("_impact_state.consume_ball_impulse()") >= 0,
		"crash response should consume the focused one-shot impulse state"
	)


func _verify_arm_and_blast_window() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	var center := Vector2(320.0, 680.0)
	state.arm(center, 0.6)
	_expect(state.has_active_blast(), "armed crash should open its blast window")
	var snapshot: Dictionary = state.get_snapshot()
	_expect(snapshot.get("crash_blast_center", Vector2.ZERO) == center, "armed crash should retain its impact center")
	_expect(is_equal_approx(float(snapshot.get("crash_blast_timer", 0.0)), 0.6), "armed crash should retain its blast duration")
	var zone: Dictionary = state.build_blast_zone(
		160.0,
		GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE,
		36.0
	)
	_expect(bool(zone.get("active", false)), "active crash state should project an active blast zone")
	_expect(zone.get("position", Vector2.ZERO) == center, "blast projection should use the impact center")
	_expect(is_equal_approx(float(zone.get("radius", 0.0)), 160.0), "blast projection should preserve its gameplay radius")
	_expect(
		str(zone.get("explosion_style", "")) == GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE,
		"blast projection should preserve the requested visual style"
	)
	state.advance(0.59)
	_expect(state.has_active_blast(), "blast should remain active before the duration edge")
	state.advance(0.02)
	_expect(not state.has_active_blast(), "blast should close after its duration elapses")
	_expect(
		not bool(state.build_blast_zone(
			160.0,
			GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE,
			36.0
		).get("active", true)),
		"expired state should project an inactive blast zone"
	)


func _verify_ball_impulse_is_consumed_once() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	var center := Vector2(280.0, 670.0)
	state.arm(center, 0.6)
	var first: Dictionary = state.consume_ball_impulse()
	_expect(bool(first.get("pending", false)), "armed crash should expose one pending ball impulse")
	_expect(first.get("center", Vector2.ZERO) == center, "pending ball impulse should retain its crash center")
	_expect(state.consume_ball_impulse().is_empty(), "first ball frame should consume the impulse even when collision math later misses")
	_expect(state.has_active_blast(), "consuming the ball impulse should not close the visual/player blast window")


func _verify_player_knockback_gate() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.arm(Vector2(300.0, 660.0), 0.6)
	_expect(state.is_player_knockback_pending(), "new blast should allow one player knockback")
	state.mark_player_knocked()
	_expect(not state.is_player_knockback_pending(), "successful player knockback should close its one-shot gate")
	_expect(bool(state.get_snapshot().get("crash_blast_player_knocked", false)), "snapshot should retain the consumed player gate")
	state.arm(Vector2(300.0, 660.0), 0.0)
	_expect(not state.is_player_knockback_pending(), "zero-duration blast should never offer player knockback")


func _verify_snapshot_restore_and_reset() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.restore({
		"crash_blast_timer": 0.25,
		"crash_blast_center": Vector2(123.0, 456.0),
		"crash_blast_player_knocked": true,
	})
	var restored: Dictionary = state.get_snapshot()
	_expect(is_equal_approx(float(restored.get("crash_blast_timer", 0.0)), 0.25), "restore should retain normalized blast time")
	_expect(restored.get("crash_blast_center", Vector2.ZERO) == Vector2(123.0, 456.0), "restore should retain the blast center")
	_expect(not state.is_player_knockback_pending(), "restored consumed player gate should stay closed")
	_expect(state.consume_ball_impulse().is_empty(), "save restore should not invent an unpersisted ball impulse")
	state.reset()
	var cleared: Dictionary = state.get_snapshot()
	_expect(is_zero_approx(float(cleared.get("crash_blast_timer", -1.0))), "reset should clear blast time")
	_expect(cleared.get("crash_blast_center", Vector2.ONE) == Vector2.ZERO, "reset should clear blast center")
	_expect(not bool(cleared.get("crash_blast_player_knocked", true)), "reset should reopen the next blast's player gate")


func _new_state() -> Object:
	if not FileAccess.file_exists(IMPACT_STATE_PATH):
		return null
	var state_script: Script = load(IMPACT_STATE_PATH)
	return state_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
