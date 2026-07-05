extends SceneTree

# Verifies the post-AI molotov fire barrier in boss_ai_state. The molotov's own
# contact bounce runs in update_active_items, a frame BEFORE update_boss_ai, so a
# fast movement decided inside the boss AI (notably the 40px/frame dash, which
# also skips the 화염 감속) would cross the fire before the molotov ever reacts.
# The barrier closes that hole: applied to the FINAL boss position regardless of
# which movement path produced it, the boss can never end a frame on the far side
# of an active fire zone's midline relative to the side it entered on.
#
# Regression here = the reported "boss bounces once then walks/dashes through the
# fire" bug coming back.

const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_fast_motion_through_update_is_clamped()
	_verify_barrier_blocks_crossing_from_left()
	_verify_barrier_blocks_crossing_from_right()
	_verify_barrier_allows_same_side_movement()
	_verify_no_barrier_is_noop()
	_verify_off_y_band_zone_is_not_a_wall()
	_verify_real_dash_is_clamped_and_cancelled()
	_verify_blocked_side_persists_retreat_allowed_crossing_denied()

	if _failures.is_empty():
		print("boss_ai_molotov_fire_barrier_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# End-to-end through update(): a strong grenade-knockback fling (a fast position
# move that, like a dash, bypasses the molotov's per-frame bounce) must be
# clamped at the fire midline instead of crossing to the far side.
func _verify_fast_motion_through_update_is_clamped() -> void:
	var ai := BossAiState.new()
	var entry := Vector2(100.0, 25.0)  # boss center 150, LEFT of the fire (center 380)
	var context := {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		# Fast fling to the right that would shoot the boss center to ~450 (past 380).
		"active_item_grenade_stun_active": true,
		"active_item_grenade_knockback_active": true,
		"active_item_grenade_knockback_vel": 300.0,
		"active_item_molotov_fire_barriers": [{"center_x": 380.0}],
	}

	var result: Dictionary = ai.update(1.0 / 60.0, entry, 0.0, context)
	var boss_center: float = float(result.get("boss_pos", entry).x) + 50.0
	_expect(
		boss_center <= 380.0 + 0.01,
		"a fast fling must be clamped at the fire midline, not cross to the far side (center=%.1f)" % boss_center
	)
	_expect(
		is_equal_approx(float(result.get("boss_vel", -1.0)), 0.0),
		"a boss stopped by the fire barrier should have its velocity zeroed so it stops ramming"
	)


func _verify_barrier_blocks_crossing_from_left() -> void:
	var ai := BossAiState.new()
	var entry := Vector2(280.0, 25.0)  # center 330, left of fire 380
	# Any movement path could produce this crossing result (dash, knockback, …).
	var result := {"boss_pos": Vector2(450.0, 25.0), "boss_vel": 40.0}  # center 500, far side
	var context := {
		"boss_paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		"active_item_molotov_fire_barriers": [{"center_x": 380.0}],
	}
	var clamped: Dictionary = ai._apply_molotov_fire_barrier(result, entry, context)
	_expect(
		float(clamped.get("boss_pos").x) + 50.0 <= 380.0 + 0.01,
		"left-approaching boss must be clamped at the fire midline"
	)
	_expect(is_equal_approx(float(clamped.get("boss_vel", -1.0)), 0.0), "blocked boss velocity should be zeroed")


func _verify_barrier_blocks_crossing_from_right() -> void:
	var ai := BossAiState.new()
	var entry := Vector2(480.0, 25.0)  # center 530, right of fire 380
	var result := {"boss_pos": Vector2(200.0, 25.0), "boss_vel": -40.0}  # center 250, far side
	var context := {
		"boss_paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		"active_item_molotov_fire_barriers": [{"center_x": 380.0}],
	}
	var clamped: Dictionary = ai._apply_molotov_fire_barrier(result, entry, context)
	_expect(
		float(clamped.get("boss_pos").x) + 50.0 >= 380.0 - 0.01,
		"right-approaching boss must be clamped at the fire midline from the other side"
	)


func _verify_barrier_allows_same_side_movement() -> void:
	var ai := BossAiState.new()
	var entry := Vector2(150.0, 25.0)  # center 200, left
	# Boss moves further right but stays on its own side of the midline — allowed.
	var result := {"boss_pos": Vector2(250.0, 25.0), "boss_vel": 6.0}  # center 300, still < 380
	var context := {
		"boss_paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		"active_item_molotov_fire_barriers": [{"center_x": 380.0}],
	}
	var out: Dictionary = ai._apply_molotov_fire_barrier(result, entry, context)
	_expect(
		is_equal_approx(float(out.get("boss_pos").x), 250.0),
		"movement that stays on the boss's own side of the fire must be untouched"
	)
	_expect(is_equal_approx(float(out.get("boss_vel", 0.0)), 6.0), "same-side movement should keep its velocity")


func _verify_off_y_band_zone_is_not_a_wall() -> void:
	# A molotov fire zone reused by the suicide drone can spawn low on the field.
	# When the boss (at the top) does NOT share its y-band, the zone must NOT act
	# as a full-height vertical wall on the boss's x movement.
	var ai := BossAiState.new()
	var entry := Vector2(280.0, 25.0)  # boss center 330 / center_y 45 (top of field)
	var result := {"boss_pos": Vector2(450.0, 25.0), "boss_vel": 40.0}  # would cross x=380
	var context := {
		"boss_paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		# Fire zone far BELOW the boss (drone-dropped mid-field): same x midline,
		# but center_y 520 is way outside the boss's y-band.
		"active_item_molotov_fire_barriers": [{"center_x": 380.0, "center_y": 520.0}],
	}
	var out: Dictionary = ai._apply_molotov_fire_barrier(result, entry, context)
	_expect(
		is_equal_approx(float(out.get("boss_pos").x), 450.0),
		"a fire zone outside the boss's y-band must NOT block the boss's x movement (no full-height wall)"
	)


func _verify_real_dash_is_clamped_and_cancelled() -> void:
	# Drive the ACTUAL boss dash state machine (40px/frame, line 213 → 630), not a
	# stand-in fling: a dash aimed across the fire must be clamped at the midline
	# AND the dash must be cancelled into its recovery stun, or boss_dash_active
	# stays true and re-rams the midline every frame for the rest of the dash.
	var ai := BossAiState.new()
	ai.boss_dash_active = true
	ai.boss_dash_direction = 1
	ai.boss_dash_target_x = 700.0  # far-right target, beyond the fire
	ai.boss_dash_duration_frames = 30.0
	ai.boss_dash_timer_frames = 30.0
	ai.boss_dash_tokens = 0

	var entry := Vector2(300.0, 25.0)  # center 350, just LEFT of the fire midline 380
	var context := {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"active_item_molotov_fire_barriers": [{"center_x": 380.0, "center_y": 45.0}],
	}

	var result: Dictionary = ai.update(1.0 / 60.0, entry, 0.0, context)
	var boss_center: float = float(result.get("boss_pos", entry).x) + 50.0
	_expect(
		boss_center <= 380.0 + 0.01,
		"a real dash must be clamped at the fire midline, not cross (center=%.1f)" % boss_center
	)
	_expect(not ai.boss_dash_active, "a dash blocked by the fire must be cancelled, not left active to re-ram")
	_expect(
		ai.boss_dash_stun_timer_frames > 0.0,
		"a fire-blocked dash should drop into its recovery stun so it actually stops"
	)
	_expect(is_equal_approx(float(result.get("boss_vel", -1.0)), 0.0), "a blocked dash should report zero velocity")


func _verify_blocked_side_persists_retreat_allowed_crossing_denied() -> void:
	# A boss blocked from the RIGHT must stay on the right side: from the clamped
	# position a retreat further right is allowed, while a cross to the left stays
	# denied. The bug was clamping the center exactly onto the midline, which made
	# the next frame read it as the LEFT side (entry_center == bc, <=), flipping
	# the allowed/denied directions.
	var ai := BossAiState.new()
	var context := {
		"boss_paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		"active_item_molotov_fire_barriers": [{"center_x": 380.0, "center_y": 45.0}],
	}

	# Frame 1 — boss is on the RIGHT and tries to cross LEFT through the fire.
	var entry1 := Vector2(480.0, 25.0)  # center 530, right side
	var crossing_left := {"boss_pos": Vector2(200.0, 25.0), "boss_vel": -40.0}  # center 250
	var out1: Dictionary = ai._apply_molotov_fire_barrier(crossing_left, entry1, context)
	var blocked_pos: Vector2 = out1.get("boss_pos")
	_expect(blocked_pos.x + 50.0 >= 380.0, "right-approach cross-left must be clamped to the right side of the midline")

	# Frame 2 — from the clamped position, retreating further RIGHT must be allowed.
	var retreat_right := {"boss_pos": Vector2(blocked_pos.x + 30.0, 25.0), "boss_vel": 10.0}
	var out2: Dictionary = ai._apply_molotov_fire_barrier(retreat_right, blocked_pos, context)
	_expect(
		is_equal_approx(float(out2.get("boss_pos").x), blocked_pos.x + 30.0),
		"after a right-side block, retreating right must be allowed (side must persist)"
	)

	# Frame 3 — from the clamped position, crossing LEFT must stay denied.
	var out3: Dictionary = ai._apply_molotov_fire_barrier(crossing_left, blocked_pos, context)
	_expect(
		float(out3.get("boss_pos").x) + 50.0 >= 380.0,
		"after a right-side block, crossing left must stay denied (no flip to left side)"
	)


func _verify_no_barrier_is_noop() -> void:
	var ai := BossAiState.new()
	var entry := Vector2(150.0, 25.0)
	var result := {"boss_pos": Vector2(600.0, 25.0), "boss_vel": 40.0}
	var context := {
		"boss_paddle_width": 100.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"width": 760.0,
		"active_item_molotov_fire_barriers": [],
	}
	var out: Dictionary = ai._apply_molotov_fire_barrier(result, entry, context)
	_expect(
		is_equal_approx(float(out.get("boss_pos").x), 600.0),
		"with no active fire zones the barrier must be a no-op"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
