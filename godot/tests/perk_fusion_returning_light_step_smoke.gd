extends SceneTree

const ReturningLightStepState := preload("res://scripts/characters/perk_fusion_returning_light_step_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkFusionRuntimeState := preload("res://scripts/characters/runtime_perk_fusion_runtime_state.gd")
const RuntimePerkUpdateDriver := preload("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")

var _failures: Array[String] = []


class OwnerFixture:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(650.0, 620.0)
	var ball_vel := Vector2(0.0, 12.0)
	var ball_size := 28.6
	var ball_impact_boost := 1.0
	var player_pos := Vector2(100.0, 690.0)
	var player_speed := 0.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var perk_fusion_returning_light_step_roll_unit := 0.0
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class DashFixture:
	extends RefCounted

	var tokens := 0
	var pending_refund := false
	var active := false
	var direction := 1.0
	var timer := 15.0
	var distance_multiplier := 1.0
	var cancel_count := 0

	func has_full_dash_token() -> bool:
		return tokens > 0 or pending_refund

	func is_active() -> bool:
		return active

	func get_snapshot() -> Dictionary:
		return {
			"active": active,
			"direction": direction,
			"timer": timer,
			"dash_distance_multiplier": distance_multiplier,
			"tokens": tokens,
			"boost_charging_pending_dash_refund": pending_refund,
		}

	func cancel_active_without_recovery() -> bool:
		if not active:
			return false
		active = false
		cancel_count += 1
		return true


class AudioFixture:
	extends RefCounted

	var linkport_calls := 0

	func play_lingpet_ring_dash() -> void:
		linkport_calls += 1


class RegistryFixture:
	extends RefCounted

	var runtime_state: Object
	var dash_state: Object
	var audio: Object

	func _init(runtime_value: Object, dash_value: Object, audio_value: Object) -> void:
		runtime_state = runtime_value
		dash_state = dash_value
		audio = audio_value

	func get_instance(key: String) -> Object:
		return runtime_state if key == "runtime_perk_state" else null

	func get_cached_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return runtime_state
			"smasher_dash_state":
				return dash_state
			"game_audio":
				return audio
		return null


class RuntimeFacadeFixture:
	extends RefCounted

	var fusion_runtime: Object = RuntimePerkFusionRuntimeState.new()

	func update_perk_fusion_byproducts(
		delta: float,
		owner: Object = null,
		registry: Object = null
	) -> Dictionary:
		return fusion_runtime.update_byproducts(delta, owner, registry)

	func has_perk_fusion_byproduct_visible_effects() -> bool:
		return fusion_runtime.has_byproduct_visible_effects()


func _init() -> void:
	_verify_exact_success_boundary_and_teleport()
	_verify_one_roll_per_descent()
	_verify_usable_token_and_guard_gates()
	_verify_existing_defense_projections()
	_verify_active_dash_projection_and_cancel()
	_verify_side_wall_reflection_prediction()
	_verify_round_reset_clears_visuals()
	_verify_production_runtime_driver_path()
	_verify_playfield_draw_fanout()
	if _failures.is_empty():
		print("perk_fusion_returning_light_step_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_exact_success_boundary_and_teleport() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	owner.perk_fusion_returning_light_step_roll_unit = 0.299999
	var result: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(result.get("rolled", false)), "eligible emergency should consume exactly one roll")
	_expect(bool(result.get("triggered", false)), "a roll strictly below 30 percent should trigger")
	_expect(is_equal_approx(owner.player_pos.x, 572.5), "success should center the paddle on the predicted ball contact")
	_expect(is_equal_approx(owner.player_pos.y, 690.0), "success should preserve the player's guard-lane Y")
	_expect(is_zero_approx(owner.player_speed), "success should clear carried movement speed")
	_expect(state.has_visible_effects(), "success should start the reused Linkport portal VFX")

	state.reset_all()
	owner = OwnerFixture.new()
	owner.perk_fusion_returning_light_step_roll_unit = 0.30
	result = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(result.get("rolled", false)) and not bool(result.get("triggered", false)), "the exact 30-percent boundary should fail the strict probability check")


func _verify_one_roll_per_descent() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	owner.perk_fusion_returning_light_step_roll_unit = 0.90
	var first: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	owner.perk_fusion_returning_light_step_roll_unit = 0.0
	var same_descent: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(first.get("rolled", false)) and not bool(same_descent.get("rolled", false)), "a failed roll must not reroll every frame in the same descent")
	owner.ball_vel = Vector2.ZERO
	var frozen_descent: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(not bool(frozen_descent.get("rolled", false)), "a Stopwatch-style zero velocity must preserve the descent roll lock")
	owner.ball_vel = Vector2(0.0, -12.0)
	state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	owner.ball_vel = Vector2(0.0, 12.0)
	var next_descent: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(next_descent.get("triggered", false)), "genuine upward travel should rearm the next descent")


func _verify_usable_token_and_guard_gates() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	dash.tokens = 1
	var with_token: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(not bool(with_token.get("rolled", false)), "a full usable dash token should block the emergency roll")
	dash.tokens = 0
	dash.pending_refund = true
	var with_refund: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(not bool(with_refund.get("rolled", false)), "a Boost Charging refund should count as a usable dash token")
	dash.pending_refund = false
	var after_spending: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(after_spending.get("triggered", false)), "eligibility should remain available after the last usable token disappears")

	state.reset_all()
	owner = OwnerFixture.new()
	var unavailable_guard: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash, false)
	_expect(not bool(unavailable_guard.get("rolled", false)), "an unavailable player guard body should not consume the roll")
	var available_guard: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash, true)
	_expect(bool(available_guard.get("triggered", false)), "the same descent may roll once the player guard becomes available")


func _verify_existing_defense_projections() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	owner.player_pos.x = 580.0
	var already_covered: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(not bool(already_covered.get("rolled", false)), "a ball already covered by the paddle must not consume the roll")

	state.reset_all()
	owner = OwnerFixture.new()
	owner.player_speed = 100.0
	var movement_cover: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(not bool(movement_cover.get("rolled", false)), "ordinary movement projected to catch the ball must remain the real defense")


func _verify_active_dash_projection_and_cancel() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	owner.ball_pos.x = 330.0
	dash.active = true
	dash.direction = 1.0
	var committed_catch: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(not bool(committed_catch.get("rolled", false)), "a committed dash projected to catch the ball must block the emergency roll")

	state.reset_all()
	owner = OwnerFixture.new()
	dash = DashFixture.new()
	dash.active = true
	dash.direction = -1.0
	var committed_miss: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(committed_miss.get("triggered", false)), "an opposite committed dash that projects a miss must remain eligible")
	_expect(dash.cancel_count == 1 and not dash.active, "success should cancel the stale dash without recovery")


func _verify_side_wall_reflection_prediction() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	owner.ball_pos.x = 735.0
	owner.ball_vel.x = 30.0
	var result: Dictionary = state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(bool(result.get("triggered", false)), "a near-wall descending ball should still trigger through reflected-X prediction")
	_expect(owner.player_pos.x > 500.0 and owner.player_pos.x < 570.0, "the blink target should fold the future ball X back inside the side wall")


func _verify_round_reset_clears_visuals() -> void:
	var state := ReturningLightStepState.new()
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	state.advance(1.0 / 60.0, ["returning_light_step"], owner, dash)
	_expect(state.has_visible_effects(), "fixture should start with an active portal VFX")
	state.reset_round()
	var snapshot: Dictionary = state.get_snapshot()
	_expect(not state.has_visible_effects(), "round reset should tear down the detached teleport presentation state")
	_expect(not bool(snapshot.get("returning_light_step_rolled_this_descent", true)), "round reset should rearm the descent roll lock")


func _verify_production_runtime_driver_path() -> void:
	var runtime := RuntimeFacadeFixture.new()
	var catalog := RuntimePerkCatalog.new()
	var levels := {"item_luck": 5, "common_bulk_up": 5}
	var record: Dictionary = runtime.fusion_runtime.commit_fusion(
		["item_luck", "common_bulk_up"],
		{"outcome": "byproduct", "byproducts": ["returning_light_step"]},
		catalog,
		levels
	)
	var owner := OwnerFixture.new()
	var dash := DashFixture.new()
	var audio := AudioFixture.new()
	var registry := RegistryFixture.new(runtime, dash, audio)
	RuntimePerkUpdateDriver.new().update_runtime_perk_resume(owner, registry, 1.0 / 60.0)
	_expect(not record.is_empty(), "production fixture should commit the new byproduct through the canonical fusion state")
	_expect(is_equal_approx(owner.player_pos.x, 572.5), "the real runtime-perk update driver should route owner and dash state into the teleport")
	_expect(audio.linkport_calls == 1, "a production-path trigger should play the existing Linkport audio once")
	_expect(owner.redraw_requests == 1, "a production-path trigger should request one coalesced battle redraw")
	_expect(runtime.has_perk_fusion_byproduct_visible_effects(), "the runtime facade should expose the active teleport VFX to the playfield draw pass")


func _verify_playfield_draw_fanout() -> void:
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var runtime_facade_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(scene_drawer_source.contains("_draw_perk_fusion_byproduct_effects(canvas, registry, shake_offset)"), "the real playfield draw fanout should include Superior Martial Art VFX after the player actor pass")
	_expect(runtime_facade_source.contains("func draw_perk_fusion_byproduct_effects("), "the runtime facade should expose the byproduct VFX draw seam")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
