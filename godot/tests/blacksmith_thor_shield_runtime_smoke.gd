extends SceneTree

const BallMotionCollisionDetector := preload("res://scripts/ball/ball_motion_collision_detector.gd")
const BlacksmithThorShieldState := preload("res://scripts/characters/blacksmith_thor_shield_state.gd")
const BlacksmithPlayerController := preload("res://scripts/characters/blacksmith_player_controller.gd")
const PlayerMovementState := preload("res://scripts/characters/player_movement_state.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PaddleBouncePlayerPostHitHandler := preload("res://scripts/ball/paddle_bounce_player_post_hit_handler.gd")

var _failures: Array[String] = []


class AudioStub:
	var calls: Array[String] = []

	func play_thor_shield_open() -> void:
		calls.append("open")

	func play_thor_shield_close() -> void:
		calls.append("close")

	func play_thor_shield_swing() -> void:
		calls.append("swing")

	func play_thor_shield_block() -> void:
		calls.append("block")


class InputReaderStub:
	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


func _init() -> void:
	_verify_runtime_routing()
	_verify_imagegen_stretch_draw_path()
	_verify_stretch_texture_in_prewarm_specs()
	_verify_shield_open_close_visual_states()
	_verify_shield_open_swing_and_speed()
	_verify_shield_collision_and_hit_reward()
	_verify_hitbox_tracks_visible_shield()
	_verify_shield_hit_repositions_to_shield_surface()
	_verify_single_tick_per_dual_path_frame()
	_verify_mid_open_input_and_forced_close_continuity()
	_verify_durability_recharge_and_zero_gauge_refusal()
	_verify_deploy_anim_locks_movement()
	_verify_dedicated_audio_cues()
	_verify_shield_root_stops_residual_speed()
	_verify_repeat_contact_keeps_block_feedback()
	_verify_folded_hitbox_tracks_tilted_art()

	if _failures.is_empty():
		print("blacksmith_thor_shield_runtime_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_runtime_routing() -> void:
	var runtime: Object = PlayerCharacterRuntime.new()
	_expect(runtime.normalize("blacksmith") == "blacksmith", "Blacksmith should normalize to blacksmith")
	_expect(runtime.normalize("baltor") == "blacksmith", "Baltor alias should normalize to blacksmith")
	_expect(runtime.normalize("kohaku") == "blacksmith", "Kohaku alias should normalize to blacksmith")
	_expect(runtime.get_player_controller_key("blacksmith") == "blacksmith_player_controller", "Blacksmith should route to its player controller")
	_expect(runtime.get_input_reader_key("blacksmith") == "blacksmith_input_reader", "Blacksmith should route to its input reader")
	_expect(runtime.get_skill_state_key("blacksmith") == "blacksmith_skill_state", "Blacksmith should expose its skill-state compatibility shell")
	_expect(runtime.get_combo_state_key("blacksmith") == "", "Blacksmith should not inherit Smasher combo state")


func _verify_imagegen_stretch_draw_path() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/characters/blacksmith_thor_shield_state.gd")
	var draw_body: String = _function_body(source, "func draw(")
	_expect(draw_body.find("_draw_integrated_thor_shield_stretch_texture") >= 0, "Thor Shield draw should use the imagegen stretch texture path")
	_expect(draw_body.find("_draw_original_thor_shield_plate") < 0, "Thor Shield draw must not fall back to the legacy procedural canopy")
	# The shield body must gate on the stretch texture, NOT on the overhead deploy
	# sheet. Coupling the body render to `has_blacksmith_thor_shield_deploy_sheet`
	# silently hid the shield whenever the stretch texture was missing from the cache.
	_expect(draw_body.find("has_blacksmith_thor_shield_deploy_sheet") < 0, "Thor Shield draw body must not gate the stretch render on the overhead deploy sheet")


func _verify_stretch_texture_in_prewarm_specs() -> void:
	# Regression guard for the "shield never appears" bug: the stretch-shield PNG
	# must live in the blacksmith texture SPEC list, not only in the direct
	# `_load_blacksmith_player_textures` loader. The runtime boot / stage-transition
	# prewarm path (`prewarm_transition_textures_step` -> `_get_player_texture_specs`)
	# is what fills `_resource_cache` in normal gameplay; a spec omission leaves
	# `blacksmith_thor_shield_stretch_texture` null at runtime even though the PNG is
	# on disk and `load_all` would have loaded it on the synchronous fallback path.
	var resources: Object = BattleResources.new()
	var specs: Variant = resources.call("_get_blacksmith_player_texture_specs", false, false)
	var found := false
	if specs is Array:
		for spec in specs:
			if not (spec is Dictionary):
				continue
			var keys_value: Variant = spec.get("keys", [])
			if keys_value is Array and (keys_value as Array).has("blacksmith_thor_shield_stretch_texture"):
				found = true
				break
	_expect(found, "Blacksmith prewarm texture specs must include blacksmith_thor_shield_stretch_texture so the shield body loads in normal gameplay")


func _verify_shield_open_swing_and_speed() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_skill_input_locked": false,
	}
	var open_result: Dictionary = state.update_input(
		0.016,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		90.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(bool(open_result.get("blacksmith_umbrella_open", false)), "Up input should open Thor Shield")
	_expect(float(state.get_player_speed_multiplier()) < 0.26, "Open Thor Shield should slow movement to the legacy guard rate")
	state.update_input(
		0.80,
		{"up_just_pressed": false, "action_just_pressed": true, "blacksmith_swing_direction": -1},
		1800,
		90.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	var swing_snapshot: Dictionary = state.get_snapshot()
	_expect(bool(swing_snapshot.get("blacksmith_umbrella_swing_active", false)), "Action plus horizontal input should start Thor Shield swing")
	_expect(int(swing_snapshot.get("blacksmith_umbrella_swing_direction", 0)) == -1, "Swing direction should preserve the exclusive horizontal input")


func _verify_shield_open_close_visual_states() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_skill_input_locked": false,
	}
	var closed_snapshot: Dictionary = state.get_snapshot()
	_expect(str(closed_snapshot.get("blacksmith_umbrella_visual_state", "")) == "closed", "Thor Shield should start in the folded visual state")
	_expect(bool(closed_snapshot.get("blacksmith_umbrella_folded", false)), "Closed Thor Shield snapshot should mark folded=true")
	_expect(is_zero_approx(float(closed_snapshot.get("blacksmith_umbrella_open_ratio", -1.0))), "Closed Thor Shield open ratio should be 0")
	_expect(int(closed_snapshot.get("blacksmith_umbrella_anim_direction", 0)) == 1, "Closed Thor Shield should reset to the opening/default direction")

	var opening_snapshot: Dictionary = state.update_input(
		0.0,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		75.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(bool(opening_snapshot.get("blacksmith_umbrella_open", false)), "Opening Thor Shield should keep the umbrella-open flag")
	_expect(str(opening_snapshot.get("blacksmith_umbrella_visual_state", "")) == "opening", "Up input should publish the opening Thor Shield visual state")
	_expect(int(opening_snapshot.get("blacksmith_umbrella_anim_direction", 0)) == 1, "Opening Thor Shield should use the original +1 animation direction")
	_expect(is_zero_approx(float(opening_snapshot.get("blacksmith_umbrella_open_ratio", -1.0))), "Opening starts from the original folded progress")

	var raising_snapshot: Dictionary = state.update_input(
		0.30,
		{"up_just_pressed": false, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1300,
		75.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(float(raising_snapshot.get("blacksmith_umbrella_raise_amount", 0.0)) > 0.90, "Original Thor Shield raise phase should finish before the plate fully opens")
	_expect(float(raising_snapshot.get("blacksmith_umbrella_shield_open_amount", 0.0)) < 0.25, "Original Thor Shield plate opening should lag behind the raise phase")

	var deployed_snapshot: Dictionary = state.update_input(
		0.50,
		{"up_just_pressed": false, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1800,
		75.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(str(deployed_snapshot.get("blacksmith_umbrella_visual_state", "")) == "open", "Thor Shield should publish the fully-open visual state after the deploy timer")
	_expect(bool(deployed_snapshot.get("blacksmith_umbrella_deployed", false)), "Fully opened Thor Shield should mark deployed=true")
	_expect(is_equal_approx(float(deployed_snapshot.get("blacksmith_umbrella_shield_open_amount", 0.0)), 1.0), "Fully opened Thor Shield should expose open_amount=1")
	var integrated_metrics: Dictionary = state.call("_get_integrated_thor_shield_overlay_metrics", Vector2.ZERO)
	var visual_width: float = float(integrated_metrics.get("shield_width", 0.0))
	var visual_height: float = float(integrated_metrics.get("shield_height", 0.0))
	var hand_value: Variant = integrated_metrics.get("hand_anchor", Vector2.ZERO)
	var grip_value: Variant = integrated_metrics.get("grip_anchor", Vector2.ZERO)
	var hand_anchor: Vector2 = hand_value if hand_value is Vector2 else Vector2.ZERO
	var grip_anchor: Vector2 = grip_value if grip_value is Vector2 else Vector2.ZERO
	_expect(visual_width >= 290.0 and visual_width <= 330.0, "Integrated Thor Shield should lengthen the Kohaku shield without becoming screen-sized")
	_expect(visual_height >= 110.0 and visual_height <= 135.0, "Integrated Thor Shield should keep a compact imagegen shield height")
	# hand_anchor must seat ONTO Kohaku's raised hand, not float ~66px overhead like
	# the first pass did. With player_pos.y=700 the sprite top is ~634 and her raised
	# shield/hand sits ~666; the anchor should land in that band, above the paddle
	# baseline (700) but well below the old floating-overhead position (~578).
	_expect(hand_anchor.y > 615.0 and hand_anchor.y < 685.0, "Integrated Thor Shield hand anchor should seat onto the raised hand, not float overhead")
	_expect(hand_anchor.distance_to(grip_anchor) <= 70.0, "Integrated Thor Shield stretch prop should stay visually connected to the raised hand")

	var closing_snapshot: Dictionary = state.update_input(
		0.0,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1900,
		75.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(bool(closing_snapshot.get("blacksmith_umbrella_open", false)), "Closing Thor Shield should preserve the original open flag until retract completes")
	_expect(bool(closing_snapshot.get("blacksmith_umbrella_retracting", false)), "Closing Thor Shield should mark retracting=true")
	_expect(str(closing_snapshot.get("blacksmith_umbrella_visual_state", "")) == "closing", "Closing Thor Shield should publish the closing visual state")
	_expect(int(closing_snapshot.get("blacksmith_umbrella_anim_direction", 0)) == -1, "Closing Thor Shield should use the original -1 animation direction")

	var closing_collision_context: Dictionary = state.get_ball_collision_context({
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	_expect(bool(closing_collision_context.get("blacksmith_thor_shield_active", false)), "Closing Thor Shield should keep the original retract grace collision context")
	_expect(str(closing_collision_context.get("blacksmith_umbrella_visual_state", "")) == "closing", "Collision context should include the closing Thor Shield visual state")

	var final_snapshot: Dictionary = state.update_input(
		0.80,
		{"up_just_pressed": false, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		2700,
		75.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	_expect(not bool(final_snapshot.get("blacksmith_umbrella_open", true)), "Retracted Thor Shield should clear the open flag")
	_expect(not bool(final_snapshot.get("blacksmith_umbrella_retracting", true)), "Retracted Thor Shield should clear retracting")
	_expect(str(final_snapshot.get("blacksmith_umbrella_visual_state", "")) == "closed", "Retracted Thor Shield should return to the closed visual state")
	_expect(bool(final_snapshot.get("blacksmith_umbrella_folded", false)), "Retracted Thor Shield should mark folded=true again")
	_expect(is_zero_approx(float(final_snapshot.get("blacksmith_umbrella_open_ratio", -1.0))), "Retracted Thor Shield open ratio should return to 0")
	_expect(is_equal_approx(float(state.get_player_speed_multiplier()), 1.0), "Retracted Thor Shield should restore normal movement speed")


func _verify_shield_collision_and_hit_reward() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}
	state.update_input(
		0.80,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		100.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	var collision_context: Dictionary = state.get_ball_collision_context({
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	_expect(bool(collision_context.get("blacksmith_thor_shield_active", false)), "Open Thor Shield should publish a ball collision context")
	var shield_rect: Rect2 = collision_context.get("blacksmith_thor_shield_rect", Rect2())
	var detector: Object = BallMotionCollisionDetector.new()
	var result: Dictionary = detector.check_paddles(
		shield_rect.get_center(),
		Vector2(0.0, 12.0),
		20.0,
		{
			"player_pos": Vector2(302.5, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
			"hitbox_padding": 5.0,
			"player_collision_cooldown": 0.0,
			"boss_collision_cooldown": 0.0,
			"blacksmith_thor_shield_active": true,
			"blacksmith_thor_shield_rect": shield_rect,
			"blacksmith_umbrella_gauge_gain": 60.0,
		}
	)
	_expect(str(result.get("event", "")) == "player_paddle", "Thor Shield hitbox should resolve through the player paddle event")
	_expect(bool(result.get("blacksmith_thor_shield_hit", false)), "Thor Shield collision should mark the shield-hit flag")

	var hit_result: Dictionary = state.notify_ball_hit(
		shield_rect.get_center(),
		Vector2(0.0, 12.0),
		100.0,
		130.0,
		{"current_msec": 2000, "gauge_max": 500.0, "blacksmith_umbrella_gauge_gain": 60.0},
		{}
	)
	_expect(is_equal_approx(float(hit_result.get("special_gauge", 0.0)), 160.0), "Thor Shield hit should raise base paddle gauge gain to 60")
	_expect(int(hit_result.get("blacksmith_umbrella_gauge", 0)) == 4, "Thor Shield hit should consume one shield durability")
	_expect(bool(hit_result.get("suppress_paddle_hit_knockback", false)), "Thor Shield hit should suppress normal paddle knockback")


func _verify_hitbox_tracks_visible_shield() -> void:
	# Regression guard for the "shield image and Thor Shield hitbox don't line up"
	# bug: the ball-collision rect must be derived from the same integrated overlay
	# metrics the renderer draws the stretch shield with, NOT the old paddle-baseline
	# formula. Open the shield fully, then compare the published collision rect
	# against the visual metrics.
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_skill_input_locked": false,
	}
	state.update_input(
		0.80,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		90.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	var metrics: Dictionary = state.call("_get_integrated_thor_shield_overlay_metrics", Vector2.ZERO)
	var visual_center_value: Variant = metrics.get("shield_center", Vector2.ZERO)
	var visual_center: Vector2 = visual_center_value if visual_center_value is Vector2 else Vector2.ZERO
	var visual_width: float = float(metrics.get("shield_width", 0.0))
	var collision_context: Dictionary = state.get_ball_collision_context({
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	var rect: Rect2 = collision_context.get("blacksmith_thor_shield_rect", Rect2())
	var rect_center: Vector2 = rect.get_center()
	_expect(rect_center.distance_to(visual_center) <= 4.0, "Thor Shield hitbox center should track the visible stretch-shield center")
	_expect(absf(rect.size.x - visual_width) <= 2.0, "Thor Shield hitbox width should match the drawn stretch-shield width")
	_expect(rect.size.y < rect.size.x, "Thor Shield hitbox should stay shield-shaped (wider than tall), not paddle-square")
	# player_pos.y = 700; the lifted overhead shield judges well above the paddle
	# baseline. The old paddle-baseline rect centered near y~683, so this also guards
	# against silently reverting to that formula.
	_expect(rect_center.y < 650.0, "Thor Shield hitbox should follow the raised shield above the paddle baseline")


func _verify_shield_hit_repositions_to_shield_surface() -> void:
	# Regression guard for "the ball teleports to the player when it hits the shield":
	# a Thor Shield hit must seat the ball just above the shield's TOP surface, NOT
	# snap down to the player paddle baseline (player_y).
	var state: Object = BlacksmithThorShieldState.new()
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_skill_input_locked": false,
	}
	state.update_input(
		0.80,
		{"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0},
		1000,
		90.0,
		Vector2(302.5, 700.0),
		config,
		{}
	)
	var collision_context: Dictionary = state.get_ball_collision_context({
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	var shield_rect: Rect2 = collision_context.get("blacksmith_thor_shield_rect", Rect2())
	var ball_size := 28.6
	var player_y := 700.0
	var handler: Object = PaddleBouncePlayerPostHitHandler.new()
	var shield_center: Vector2 = shield_rect.get_center()
	var snapped: Vector2 = handler.call("_snap_player_hit_ball_pos", shield_center, {
		"blacksmith_thor_shield_hit": true,
		"blacksmith_thor_shield_rect": shield_rect,
		"player_y": player_y,
		"ball_size": ball_size,
	})
	var expected_y: float = shield_rect.position.y - ball_size
	_expect(absf(snapped.y - expected_y) <= 0.5, "Thor Shield hit should seat the ball above the shield top surface")
	_expect(snapped.y < player_y - 60.0, "Thor Shield hit must not snap the ball down to the player paddle baseline")
	# Control: a normal player hit (no shield flag) still snaps to the paddle surface.
	var normal: Vector2 = handler.call("_snap_player_hit_ball_pos", Vector2(380.0, 560.0), {
		"player_y": player_y,
		"ball_size": ball_size,
	})
	_expect(absf(normal.y - (player_y - ball_size)) <= 0.5, "Non-shield player hit should still snap to the player paddle surface")


func _default_config() -> Dictionary:
	return {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_skill_input_locked": false,
	}


func _idle_input() -> Dictionary:
	return {"up_just_pressed": false, "action_just_pressed": false, "blacksmith_swing_direction": 0}


func _up_input() -> Dictionary:
	return {"up_just_pressed": true, "action_just_pressed": false, "blacksmith_swing_direction": 0}


func _tick_dual_path_frame(state: Object, delta: float, input_snapshot: Dictionary, msec: int) -> void:
	# Reproduce the REAL integrated frame flow: battle_frame_flow_controller
	# calls update_player_control (-> update_input) AND update_effects in the
	# SAME physics frame. The state object must advance its timers exactly once
	# per frame under this dual-path drive.
	state.update_input(delta, input_snapshot, msec, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	state.update_effects(delta * 60.0, {
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"special_gauge": 75.0,
	}, {})


func _verify_single_tick_per_dual_path_frame() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var frame_delta: float = 1.0 / 60.0
	_tick_dual_path_frame(state, frame_delta, _up_input(), 1000)
	# 21 more dual-path frames = 0.35s of game time. With the old double tick
	# (input path + effects path both decremented the timer) the nominal 0.70s
	# deploy already finished here; the fixed single tick must sit near 50%.
	for frame_index in range(21):
		_tick_dual_path_frame(state, frame_delta, _idle_input(), 1100 + frame_index * 16)
	var mid_ratio: float = float(state.get_open_ratio())
	_expect(mid_ratio > 0.40 and mid_ratio < 0.65, "Dual-path frame drive must advance the deploy timer once per frame (0.35s in => ~50%% open, got %.2f)" % mid_ratio)
	_expect(not bool(state.is_deployed()), "Thor Shield must NOT be fully deployed after 0.35s of dual-path frames (double-tick regression)")
	for frame_index in range(24):
		_tick_dual_path_frame(state, frame_delta, _idle_input(), 1600 + frame_index * 16)
	_expect(bool(state.is_deployed()), "Thor Shield should finish deploying after ~0.75s of dual-path frames")


func _verify_mid_open_input_and_forced_close_continuity() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	state.update_input(0.0, _up_input(), 1000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	state.update_input(0.20, _idle_input(), 1200, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	var ratio_before_press: float = float(state.get_open_ratio())
	# Original parity: a manual fold press while the deploy animation still runs
	# must be IGNORED (no retract, no pose snap).
	state.update_input(0.0, _up_input(), 1250, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(not bool(state.get_snapshot().get("blacksmith_umbrella_retracting", true)), "Manual fold input during the deploy animation must be ignored (original anim_timer==0 gate)")
	_expect(absf(float(state.get_open_ratio()) - ratio_before_press) <= 0.02, "Ignored mid-open fold press must not change the open ratio")
	# Forced close (durability depletion mid-deploy) must fold from the CURRENT
	# ratio instead of snapping to fully-open first.
	state.set("umbrella_gauge", 1)
	var ratio_before_forced_close: float = float(state.get_open_ratio())
	state.notify_ball_hit(
		Vector2(302.5, 620.0),
		Vector2(0.0, 12.0),
		75.0,
		75.0,
		{"current_msec": 5000, "gauge_max": 500.0},
		{}
	)
	_expect(bool(state.get_snapshot().get("blacksmith_umbrella_retracting", false)), "Durability depletion must start the forced fold")
	var ratio_after_forced_close: float = float(state.get_open_ratio())
	_expect(absf(ratio_after_forced_close - ratio_before_forced_close) <= 0.02, "Forced fold must keep the open ratio continuous (got %.2f -> %.2f)" % [ratio_before_forced_close, ratio_after_forced_close])


func _verify_durability_recharge_and_zero_gauge_refusal() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	state.set("umbrella_gauge", 0)
	var refusal_snapshot: Dictionary = state.update_input(0.0, _up_input(), 1000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(not bool(refusal_snapshot.get("blacksmith_umbrella_open", true)), "Deploy must be refused at 0 durability (original parity)")
	_expect(float(refusal_snapshot.get("blacksmith_umbrella_damage_flash_timer", 0.0)) > 0.0, "Refused deploy should trigger the damage flash feedback")
	_expect(int(refusal_snapshot.get("blacksmith_umbrella_gauge", -1)) == 0, "Refused deploy must NOT instantly refill durability")
	# Folded recharge: 6 seconds per durability point.
	for _second in range(6):
		state.update_input(1.0, _idle_input(), 2000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(int(state.get_snapshot().get("blacksmith_umbrella_gauge", 0)) == 1, "Folded shield should recover one durability point after 6 seconds")
	var reopen_snapshot: Dictionary = state.update_input(0.0, _up_input(), 9000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(bool(reopen_snapshot.get("blacksmith_umbrella_open", false)), "Deploy should be accepted again once durability recovered")


func _verify_deploy_anim_locks_movement() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	_expect(is_equal_approx(float(state.get_player_speed_multiplier()), 1.0), "Folded Thor Shield should not slow movement")
	state.update_input(0.0, _up_input(), 1000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(is_zero_approx(float(state.get_player_speed_multiplier())), "Deploy animation must fully root the paddle (original umbrella_lock_active)")
	state.update_input(0.80, _idle_input(), 1800, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(is_equal_approx(float(state.get_player_speed_multiplier()), 0.25), "Fully deployed guard should move at the 25% crawl")
	state.update_input(0.0, _up_input(), 1900, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(is_zero_approx(float(state.get_player_speed_multiplier())), "Retract animation must fully root the paddle")
	state.update_input(0.80, _idle_input(), 2700, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	_expect(is_equal_approx(float(state.get_player_speed_multiplier()), 1.0), "Completed retract should restore normal movement")


func _verify_dedicated_audio_cues() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	var audio: AudioStub = AudioStub.new()
	var deps: Dictionary = {"audio": audio}
	state.update_input(0.0, _up_input(), 1000, 75.0, Vector2(302.5, 700.0), _default_config(), deps)
	_expect(audio.calls.has("open"), "Deploy should play the dedicated umbopen cue")
	state.update_input(0.80, _idle_input(), 1800, 75.0, Vector2(302.5, 700.0), _default_config(), deps)
	state.update_input(
		0.0,
		{"up_just_pressed": false, "action_just_pressed": true, "blacksmith_swing_direction": -1},
		1900,
		75.0,
		Vector2(302.5, 700.0),
		_default_config(),
		deps
	)
	_expect(not audio.calls.has("swing"), "Swing cue must wait for the 0.5s prep phase (original sound delay)")
	state.update_input(0.60, _idle_input(), 2500, 75.0, Vector2(302.5, 700.0), _default_config(), deps)
	_expect(audio.calls.has("swing"), "Swing cue should fire when the main swing phase starts")
	state.notify_ball_hit(
		Vector2(302.5, 620.0),
		Vector2(0.0, 12.0),
		75.0,
		75.0,
		{"current_msec": 9000, "gauge_max": 500.0},
		deps
	)
	_expect(audio.calls.has("block"), "Shield block should play the dedicated blocking cue")
	state.update_input(1.20, _idle_input(), 10000, 75.0, Vector2(302.5, 700.0), _default_config(), deps)
	state.update_input(0.0, _up_input(), 10100, 75.0, Vector2(302.5, 700.0), _default_config(), deps)
	_expect(audio.calls.has("close"), "Manual fold should play the dedicated umbclose cue")


func _verify_shield_root_stops_residual_speed() -> void:
	# Integration guard for the "multiplier 0 zeroes decel so move_toward
	# preserves the carried speed" hole: drive the REAL blacksmith controller +
	# movement state with a paddle already sliding at 6 px/frame, deploy the
	# shield, and require an actual stop (position unchanged, speed 0).
	var controller: Object = BlacksmithPlayerController.new()
	var shield: Object = BlacksmithThorShieldState.new()
	var reader: InputReaderStub = InputReaderStub.new()
	reader.snapshot = {
		"up_just_pressed": true,
		"action_just_pressed": false,
		"blacksmith_swing_direction": 0,
		"left_pressed": false,
		"right_pressed": false,
		"action_pressed": false,
		"direction": 0.0,
	}
	var deps := {
		"input_reader": reader,
		"blacksmith_thor_shield_state": shield,
		"movement_state": PlayerMovementState.new(),
	}
	var config := {
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 1.2,
		"paddle_decel": 0.8,
		"paddle_turn_decel": 1.5,
		"special_gauge": 75.0,
		"player_skill_input_locked": false,
	}
	var start_pos := Vector2(302.5, 700.0)
	var result: Dictionary = controller.update(1.0 / 60.0, 0, start_pos, 6.0, config, deps)
	_expect(bool(result.get("blacksmith_umbrella_open", false)), "Root-stop leg: shield should have opened")
	_expect(is_zero_approx(float(result.get("player_speed", -1.0))), "Deploy must zero the carried player speed, not just the speed config keys")
	var result_pos: Vector2 = result.get("player_pos", start_pos)
	_expect(absf(result_pos.x - start_pos.x) <= 0.01, "Deploying paddle must not slide on residual speed (moved %.2fpx)" % absf(result_pos.x - start_pos.x))
	# Second frame while still deploying: held horizontal input must not move it either.
	reader.snapshot = {
		"up_just_pressed": false,
		"action_just_pressed": false,
		"blacksmith_swing_direction": 0,
		"left_pressed": false,
		"right_pressed": true,
		"action_pressed": false,
		"direction": 1.0,
	}
	var second: Dictionary = controller.update(1.0 / 60.0, 1, result_pos, float(result.get("player_speed", 0.0)), config, deps)
	var second_pos: Vector2 = second.get("player_pos", result_pos)
	_expect(absf(second_pos.x - result_pos.x) <= 0.01, "Held input during the deploy animation must not move the rooted paddle")


func _verify_repeat_contact_keeps_block_feedback() -> void:
	var state: Object = BlacksmithThorShieldState.new()
	state.update_input(0.80, _up_input(), 1000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	var first: Dictionary = state.notify_ball_hit(
		Vector2(302.5, 620.0), Vector2(0.0, 12.0), 75.0, 75.0,
		{"current_msec": 2000, "gauge_max": 500.0, "last_hit_by": "boss"}, {}
	)
	_expect(int(first.get("blacksmith_umbrella_gauge", -1)) == 4, "First boss-ball contact should consume one durability")
	# Re-contact INSIDE the 0.5s durability cooldown: guard feedback (knockback
	# suppression, gauge gain) must still process; only durability is protected.
	var second: Dictionary = state.notify_ball_hit(
		Vector2(302.5, 620.0), Vector2(0.0, 12.0), 75.0, 75.0,
		{"current_msec": 2100, "gauge_max": 500.0, "last_hit_by": "boss", "blacksmith_umbrella_gauge_gain": 60.0}, {}
	)
	_expect(not second.is_empty(), "Re-contact within the durability cooldown must still return a block result")
	_expect(bool(second.get("suppress_paddle_hit_knockback", false)), "Re-contact within the cooldown must still suppress paddle knockback")
	_expect(int(second.get("blacksmith_umbrella_gauge", -1)) == 4, "Re-contact within the cooldown must NOT consume extra durability")
	_expect(is_equal_approx(float(second.get("special_gauge", 0.0)), 135.0), "Re-contact within the cooldown should still grant the shield gauge gain")
	# A ball whose PREVIOUS hitter was the player never consumes durability
	# (original last_hit_by != "player" gate), but block feedback remains.
	var player_ball: Dictionary = state.notify_ball_hit(
		Vector2(302.5, 620.0), Vector2(0.0, 12.0), 75.0, 75.0,
		{"current_msec": 3000, "gauge_max": 500.0, "last_hit_by": "player"}, {}
	)
	_expect(int(player_ball.get("blacksmith_umbrella_gauge", -1)) == 4, "Player-last-hit ball must not consume durability")
	_expect(bool(player_ball.get("suppress_paddle_hit_knockback", false)), "Player-last-hit ball still gets shield block feedback")
	var boss_ball_later: Dictionary = state.notify_ball_hit(
		Vector2(302.5, 620.0), Vector2(0.0, 12.0), 75.0, 75.0,
		{"current_msec": 3100, "gauge_max": 500.0, "last_hit_by": "boss"}, {}
	)
	_expect(int(boss_ball_later.get("blacksmith_umbrella_gauge", -1)) == 3, "Boss ball after the cooldown should consume durability again")


func _verify_folded_hitbox_tracks_tilted_art() -> void:
	# The folded/closing shield PNG is drawn tilted ~75 degrees; the judged rect
	# must be the AABB of that rotated visible quad (taller than wide), not the
	# untilted folded rectangle (wider than tall).
	var state: Object = BlacksmithThorShieldState.new()
	state.update_input(0.0, _up_input(), 1000, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	state.update_input(0.05, _idle_input(), 1100, 75.0, Vector2(302.5, 700.0), _default_config(), {})
	var collision_context: Dictionary = state.get_ball_collision_context({
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	})
	_expect(bool(collision_context.get("blacksmith_thor_shield_active", false)), "Opening shield should already publish a collision context")
	var rect: Rect2 = collision_context.get("blacksmith_thor_shield_rect", Rect2())
	_expect(rect.size.y > rect.size.x, "Folded-state hitbox must track the tilted art (AABB taller than wide), got %.0fx%.0f" % [rect.size.x, rect.size.y])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next_func: int = source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)
