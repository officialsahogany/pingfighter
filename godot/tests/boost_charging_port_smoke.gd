extends SceneTree

const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherDashTokenState := preload("res://scripts/characters/smasher_dash_token_state.gd")


class FullBoostPerkState:
	func get_boost_charge_chance_pct() -> float:
		return 100.0


class FakeAudio:
	var boost_charging_count := 0

	func play_boost_charging() -> void:
		boost_charging_count += 1


class FakeRegistry:
	var audio := FakeAudio.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	var token_state: Object = SmasherDashTokenState.new()
	token_state.reset_full(1)
	_expect(token_state.consume_full_dash_token(300.0), "first full dash should consume the real token")
	_expect(int(token_state.get_last_consumed_token_index()) == 0, "the consumed token index should be exposed for boost-charging HUD sync")
	_expect(token_state.try_arm_boost_charging(100.0, token_state.get_last_consumed_token_index()), "100% boost charging should arm the refund")

	var token_snapshot: Dictionary = token_state.get_snapshot()
	_expect(bool(token_snapshot.get("boost_charging_pending_dash_refund", false)), "boost charging should grant one pending free dash")
	_expect(bool(token_snapshot.get("boost_charging_active", false)), "boost charging should start the rainbow ball visual timer")
	_expect(int(token_snapshot.get("boost_charging_token_index", -1)) == 0, "boost charging should mark the recharging dash token")
	_expect(float(token_snapshot.get("boost_charging_effect_timer", 0.0)) > 0.0, "boost charging should start the player burst timer")
	_expect(is_equal_approx(float(token_snapshot.get("charge_timer", 0.0)), 30.0), "boost charging should reduce the active token recharge timer by 90%")
	_expect(token_state.has_full_dash_token(), "pending boost charging should satisfy full-dash gates with zero real tokens")
	_expect(token_state.has_chain_dash_token(), "pending boost charging should satisfy chain-dash gates with one max token")

	_expect(not token_state.consume_full_dash_token(300.0), "the next dash should consume the pending refund instead of a token")
	token_snapshot = token_state.get_snapshot()
	_expect(not bool(token_snapshot.get("boost_charging_pending_dash_refund", true)), "the free dash should clear the pending refund")
	_expect(int(token_snapshot.get("boost_charging_token_index", 99)) == -1, "the free dash should clear the HUD boost token marker")
	_expect(int(token_snapshot.get("consecutive_count", 0)) == 2, "the free boost dash should still count as a consecutive dash")

	token_state.reset_full(1)
	_expect(token_state.consume_full_dash_token(300.0), "token consume should work after reset")
	_expect(token_state.try_arm_boost_charging(100.0, token_state.get_last_consumed_token_index()), "boost charging should arm again after reset")
	for _i in range(30):
		token_state.update_recharge(1.0, 300.0)
	token_snapshot = token_state.get_snapshot()
	_expect(not bool(token_snapshot.get("boost_charging_active", true)), "rainbow ball visual should expire after 30 frames")
	_expect(bool(token_snapshot.get("boost_charging_pending_dash_refund", false)), "visual expiry should not consume the stored free dash")
	_expect(int(token_snapshot.get("tokens", 0)) == 1, "90% recharge reduction should complete one dash token after 30 frames")

	var dash_state: Object = SmasherDashState.new()
	var perk_state := FullBoostPerkState.new()
	var registry := FakeRegistry.new()
	dash_state.reset_full(1)
	_expect(dash_state.start(1.0, false, perk_state, registry), "dash state should start the first full dash")
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(dash_snapshot.get("boost_charging_pending_dash_refund", false)), "dash state should arm boost charging through the token state")
	_expect(int(dash_snapshot.get("boost_charging_token_index", -1)) == 0, "dash state should preserve the boost token index")
	_expect(is_equal_approx(float(dash_snapshot.get("charge_timer", 0.0)), 30.0), "dash state boost charging should apply the recharge reduction")
	_expect(registry.audio.boost_charging_count == 1, "boost charging should play its sound once when the real token procs")

	dash_state.update(12.0 / 60.0, Vector2(300.0, 700.0), 0.0, 760.0, 155.0, perk_state)
	_expect(dash_state.can_chain_dash(true, -1.0), "pending boost charging should unlock an immediate chain dash even with one max token")
	_expect(dash_state.start(-1.0, false, perk_state, registry), "chain dash should start by consuming the boost refund")
	dash_snapshot = dash_state.get_snapshot()
	_expect(not bool(dash_snapshot.get("boost_charging_pending_dash_refund", true)), "chain dash should consume the pending boost refund")
	_expect(registry.audio.boost_charging_count == 1, "free boost dash should not re-roll or replay boost charging audio")

	print("boost_charging_port_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
