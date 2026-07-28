extends SceneTree

# Regression: dash_boost (active item) discounts the dash cost to zero, so every
# dash while it is active must be FREE. When Soul Burst (passive knee item) is also
# equipped, an empty-token dash used to route to the Soul Burst special-gauge spend
# even while dash_boost was active, draining the gauge on a dash the player expects
# to be free. The mode decision in smasher_player_dash_controller.handle_dash_input
# must honor the same free-cost condition that smasher_dash_state uses to skip the
# token consume, so a free dash never spends the gauge.
#
# Two live paths reproduce it:
#   A) fresh input with zero tokens  -> free full dash, gauge preserved
#   B) chain dash (max 1 token, no chain token) -> free chain, gauge preserved
#
# Both assert the gauge is NOT spent and Soul Burst audio never fires.
# Reverse-check: toggle `_is_dash_cost_free` to `return false` in the controller;
# this smoke fails because both paths spend the Soul Burst gauge (200 -> 60).

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")

# `quit()` inside SceneTree is DEFERRED -- it does not stop the running function.
# Without this flag the trailing unconditional `print(... ok)` + `quit(0)` overwrote
# every `_expect` failure's `quit(1)`, so the smoke exited 0 while pushing errors
# (a hollow GREEN for any gate that judges by exit code alone).
var _failed := false


class FakeOwner:
	var player_pos := Vector2(300.0, 650.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge := 200.0
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var soul_burst_equipped := false
	var soul_burst_active := false
	var soul_burst_gauge_cost := 0.0
	var soul_burst_dash_active := false
	var redraw_queued := false

	func queue_redraw() -> void:
		redraw_queued = true


class FakeAudio:
	var soul_burst_calls := 0
	var dash_start_calls := 0
	var half_dash_calls := 0

	func play_soul_burst_dash() -> void:
		soul_burst_calls += 1

	func play_dash_start(is_half: bool) -> void:
		dash_start_calls += 1
		if is_half:
			half_dash_calls += 1

	func stop_dash_delay() -> void:
		pass


class FakeFeedback:
	func set_screen_shake(_amount: float, _intensity: float) -> void:
		pass

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		pass


class FakeOrbHudState:
	var dash_spin_count := 0
	var gauge_spin_count := 0

	func trigger_dash_token_spin(_msec: int) -> void:
		dash_spin_count += 1

	func trigger_gauge_spin(_msec: int) -> void:
		gauge_spin_count += 1


# get_dash_cost_multiplier() == 0.0 mirrors active_item_runtime while dash_boost is
# active (DASH_BOOST_COST_DISCOUNT = 1.00 -> 100% discount -> free).
class FakeActiveItemRuntime:
	var cost_multiplier := 0.0

	func get_dash_cost_multiplier() -> float:
		return cost_multiplier


class FakeRegistry:
	var runtime: Object
	var dash_state: Object
	var audio: Object
	var feedback: Object
	var active_item_runtime: Object

	func _init(runtime_ref: Object, dash_ref: Object, audio_ref: Object, feedback_ref: Object, active_ref: Object) -> void:
		runtime = runtime_ref
		dash_state = dash_ref
		audio = audio_ref
		feedback = feedback_ref
		active_item_runtime = active_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return runtime
			"smasher_dash_state":
				return dash_state
			"game_audio":
				return audio
			"battle_feedback_state":
				return feedback
			"active_item_runtime":
				return active_item_runtime
		return null


func _init() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var dash_state: Object = SmasherDashState.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var registry := FakeRegistry.new(runtime, dash_state, audio, feedback, active_item_runtime)
	var dash_controller: Object = SmasherPlayerDashController.new()

	_expect(
		runtime.equip_item("soul_burst", owner, registry, {"soul_burst_gauge_cost": 140.0}, false),
		"Soul Burst should equip through mythic_item_runtime"
	)
	_expect(runtime.can_soul_burst_dash(200.0), "Soul Burst should be able to spend a 200 gauge at cost 140")
	_expect(is_equal_approx(active_item_runtime.get_dash_cost_multiplier(), 0.0), "dash_boost fake should report a free dash cost")

	var dash_config := {
		"special_gauge": 200.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"play_left": 0.0,
		"play_right": 760.0,
	}

	# --- Path A: fresh input, zero tokens, dash_boost active -----------------
	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	dash_state.dash_key_released_since_last = true
	var orb_hud_a := FakeOrbHudState.new()
	var deps_a := {
		"dash_state": dash_state,
		"registry": registry,
		"audio": audio,
		"feedback": feedback,
		"orb_hud_state": orb_hud_a,
		"owner": owner,
		"mythic_item_runtime": runtime,
		"active_item_runtime": active_item_runtime,
	}
	var result_a: Dictionary = dash_controller.handle_dash_input(
		true, 1.0, Vector2(300.0, 650.0), 0.0, dash_config, deps_a
	)
	_expect(bool(result_a.get("handled_by_dash", false)), "A: fresh dash input should be handled")
	_expect(
		is_equal_approx(float(result_a.get("special_gauge", -1.0)), 200.0),
		"A: dash_boost free dash must NOT spend Soul Burst gauge (expected 200), got %s" % str(result_a.get("special_gauge"))
	)
	var snap_a: Dictionary = dash_state.get_snapshot()
	_expect(bool(snap_a.get("active", false)), "A: a real full dash should start")
	_expect(not bool(snap_a.get("is_half", true)), "A: dash_boost should give a full dash, not the half-dash fallback")
	_expect(audio.soul_burst_calls == 0, "A: a free dash must not play Soul Burst audio")
	_expect(orb_hud_a.gauge_spin_count == 0, "A: a free dash must not pulse the special-gauge orb")

	# --- Path B: chain dash, max 1 token (no chain token), dash_boost active --
	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	# Prime an in-flight full dash past the consecutive-dash delay so a chain is legal.
	_expect(dash_state.start(1.0, false, null, registry, false), "B: prime dash should start")
	dash_state.motion_state.dash_elapsed_frames = 20.0
	owner.special_gauge = 200.0
	audio.soul_burst_calls = 0
	var orb_hud_b := FakeOrbHudState.new()
	var deps_b := {
		"dash_state": dash_state,
		"registry": registry,
		"audio": audio,
		"feedback": feedback,
		"orb_hud_state": orb_hud_b,
		"owner": owner,
		"mythic_item_runtime": runtime,
		"active_item_runtime": active_item_runtime,
	}
	var result_b: Dictionary = dash_controller.handle_dash_input(
		true, 1.0, Vector2(300.0, 650.0), 0.0, dash_config, deps_b
	)
	_expect(bool(result_b.get("handled_by_dash", false)), "B: chain dash input should be handled")
	_expect(
		is_equal_approx(float(result_b.get("special_gauge", -1.0)), 200.0),
		"B: dash_boost free chain dash must NOT spend Soul Burst gauge (expected 200), got %s" % str(result_b.get("special_gauge"))
	)
	_expect(bool(dash_state.get_snapshot().get("active", false)), "B: chain dash should keep a dash active")
	_expect(audio.soul_burst_calls == 0, "B: a free chain dash must not play Soul Burst audio")

	# --- Guard: with dash_boost INACTIVE, Soul Burst still spends the gauge ----
	active_item_runtime.cost_multiplier = 1.0
	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	dash_state.dash_key_released_since_last = true
	owner.special_gauge = 200.0
	audio.soul_burst_calls = 0
	var deps_c := {
		"dash_state": dash_state,
		"registry": registry,
		"audio": audio,
		"feedback": feedback,
		"orb_hud_state": FakeOrbHudState.new(),
		"owner": owner,
		"mythic_item_runtime": runtime,
		"active_item_runtime": active_item_runtime,
	}
	var result_c: Dictionary = dash_controller.handle_dash_input(
		true, 1.0, Vector2(300.0, 650.0), 0.0, dash_config, deps_c
	)
	_expect(
		is_equal_approx(float(result_c.get("special_gauge", -1.0)), 60.0),
		"C: without dash_boost, Soul Burst should still spend its gauge (200 - 140 = 60), got %s" % str(result_c.get("special_gauge"))
	)
	_expect(audio.soul_burst_calls == 1, "C: the Soul Burst replacement dash should play its audio when dash_boost is inactive")

	if _failed:
		push_error("soul_burst_dash_boost_free_dash_smoke: FAILED")
		quit(1)
		return
	print("soul_burst_dash_boost_free_dash_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
