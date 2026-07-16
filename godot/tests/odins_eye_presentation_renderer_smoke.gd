extends SceneTree

const OdinsEyePresentationRenderer := preload("res://scripts/items/odins_eye_presentation_renderer.gd")
const OdinsEyeState := preload("res://scripts/items/odins_eye_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_transformed_player_gate_and_layout()
	_verify_revival_hides_final_body()
	_verify_death_and_dark_swamp_plan()
	_verify_audio_sync_timeline()
	_verify_dark_swamp_crystal_geometry()

	if _failures.is_empty():
		print("odins_eye_presentation_renderer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_transformed_player_gate_and_layout() -> void:
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var context := {
		"player_paddle_scale": 1.0,
		"odins_eye_context": {
			"transformed": true,
			"penalty_active": true,
			"revival_animation_active": false,
			"death_animation_active": false,
		},
	}
	var player_pos := Vector2(300.0, 700.0)
	var paddle_size := Vector2(155.0, 50.0)
	var shake_offset := Vector2(4.0, -3.0)
	var plan: Dictionary = renderer.build_presentation_plan(context, player_pos, paddle_size, shake_offset)
	var visual_rect: Rect2 = plan.get("player_rect", Rect2())
	_expect(bool(plan.get("draw_player", false)), "transformed Odin should replace the normal player")
	_expect(not bool(plan.get("draw_revival", true)), "settled transformed Odin should not draw revival")
	_expect_close(visual_rect.size.x, 180.0, "base transformed width should match the legacy silhouette budget")
	_expect_close(visual_rect.size.y, 185.0, "base transformed height should match the legacy silhouette budget")
	_expect_close(visual_rect.get_center().x, 381.5, "visual center should track paddle center plus shake")
	_expect_close(visual_rect.get_center().y, 667.0, "visual center should keep the legacy Odin vertical anchor")


func _verify_revival_hides_final_body() -> void:
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var context := {
		"odins_eye_context": {
			# Odin marks penalty/transformed immediately when revival starts. The
			# renderer must still withhold the settled final body until the burst.
			"transformed": true,
			"penalty_active": true,
			"revival_animation_active": true,
			# 0.75 remaining-fraction of the 3.75s clock (2.8125 = 3.75 * 0.75),
			# so revival_progress still maps to 0.25.
			"revival_timer_sec": 2.8125,
			"death_animation_active": false,
		},
	}
	var plan: Dictionary = renderer.build_presentation_plan(
		context,
		Vector2(300.0, 700.0),
		Vector2(155.0, 50.0)
	)
	_expect(not bool(plan.get("draw_player", true)), "revival should hide the settled Odin body despite transformed=true")
	_expect(bool(plan.get("draw_revival", false)), "revival should route through the overlay cinematic")
	_expect_close(float(plan.get("revival_progress", -1.0)), 0.25, "revival timer should map to the authoritative 3.75-second clock")


func _verify_dark_swamp_crystal_geometry() -> void:
	# The lurker-spike main crystal is a faceted 7-point polygon (upgraded from
	# line strokes). It must stay triangulable across the whole animation range
	# (width, height, jag wobble, apex sway) or draw_colored_polygon silently
	# skips the fill and the crystal drops back to the line fallback.
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var checked := 0
	for width in [6.0, 8.0, 10.0]:
		for height in [6.0, 20.0, 38.0, 63.0]:
			for jag_sign in [-1.0, 0.0, 1.0]:
				for sway in [-1.0, 0.0, 1.0]:
					var cx := 380.0
					var by := 700.0
					var jag: float = width * 0.15 * jag_sign
					var apex := Vector2(cx + sway * width * 0.22, by - height)
					var points: PackedVector2Array = renderer._build_swamp_crystal_points(cx, by, height, width, jag, apex)
					checked += 1
					if points.size() != 7:
						_failures.append("swamp crystal must be a 7-point facet, got %d" % points.size())
						return
					if Geometry2D.triangulate_polygon(points).is_empty():
						_failures.append(
							"swamp crystal must triangulate (w=%.0f h=%.0f jag=%.1f sway=%.1f)"
							% [width, height, jag, sway]
						)
						return
	_expect(checked == 108, "crystal triangulation sweep must cover 108 cases, ran %d" % checked)


func _verify_audio_sync_timeline() -> void:
	# odinchange.wav (5.87s, played at t=0) has its explosion BANG at 3.20s. The
	# two duration clocks MUST match (a mismatch clamps safe_progress and freezes
	# the burst), and the explosion must FIRE at 3.0s so the flash lands on the
	# 3.2s bang. These are the load-bearing sync anchors — see the retiming plan.
	_expect_close(
		OdinsEyePresentationRenderer.REVIVAL_DURATION_SEC,
		OdinsEyeState.REVIVAL_EVENT_SEC,
		"renderer REVIVAL_DURATION_SEC must equal state REVIVAL_EVENT_SEC (drift = frozen burst)"
	)
	_expect_close(
		OdinsEyePresentationRenderer.REVIVAL_DURATION_SEC,
		3.75,
		"revival event must be 3.75s (3.0s anim + 0.75s dark-burst reveal)"
	)
	_expect_close(
		OdinsEyePresentationRenderer.REVIVAL_BURST_PREP_END * OdinsEyePresentationRenderer.REVIVAL_DURATION_SEC,
		3.0,
		"explosion must FIRE at 3.0s (REVIVAL_BURST_PREP_END boundary) to land on the audio bang"
	)
	# The gather/form cuts must still land on the original 1.5s / 2.5s beats.
	_expect_close(
		OdinsEyePresentationRenderer.REVIVAL_GATHER_END * OdinsEyePresentationRenderer.REVIVAL_DURATION_SEC,
		1.5,
		"gather must end at 1.5s"
	)
	_expect_close(
		OdinsEyePresentationRenderer.REVIVAL_FORM_END * OdinsEyePresentationRenderer.REVIVAL_DURATION_SEC,
		2.5,
		"form must end at 2.5s"
	)

	# The audio-latency-compensated bang must land at the odinchange.wav bang
	# (3.20s) PLUS the output latency, so the visual "팡" coincides with the
	# audible sound (user reported the visual leading the sound).
	var bang_t: float = OdinsEyeState.REVIVAL_BANG_T
	_expect_close(
		3.0 + bang_t * 0.75,
		3.20 + OdinsEyeState.BANG_LATENCY_SEC,
		"transform visual bang must land on the audio bang (3.20s) + output latency"
	)

	# The silhouette must SNAP to full AT the (latency-compensated) bang, mirroring
	# the original's instant reveal — not a slow ramp finishing at 3.75s.
	var renderer: Object = OdinsEyePresentationRenderer.new()
	_expect(renderer._revival_reveal_alpha(0.0, bang_t) <= 0.02, "body hidden at explosion fire (3.0s)")
	_expect(renderer._revival_reveal_alpha(bang_t, bang_t) >= 0.99, "body must SNAP to full by the bang")
	_expect(renderer._revival_reveal_alpha(1.0, bang_t) >= 0.99, "body stays full through finalize (3.75s)")

	# Transform screen shake must SPIKE at the (latency-compensated) bang so the
	# scene jolts exactly when the sound cracks.
	var bang_progress: float = OdinsEyeState.REVIVAL_BURST_PREP_FRAC + bang_t * (1.0 - OdinsEyeState.REVIVAL_BURST_PREP_FRAC)
	var shake_state: Object = OdinsEyeState.new()
	shake_state.set_equipped(true)
	shake_state.begin_revival("round")
	_expect(shake_state.get_revival_shake_intensity() < 1.0, "no shake at transform start")
	shake_state.revival_timer_sec = OdinsEyeState.REVIVAL_EVENT_SEC * (1.0 - bang_progress)
	_expect(shake_state.get_revival_shake_intensity() > 11.0, "shake must spike (~12) at the bang")
	shake_state.revival_timer_sec = OdinsEyeState.REVIVAL_EVENT_SEC * 0.01
	_expect(shake_state.get_revival_shake_intensity() < 5.0, "shake decays by the reveal end")


func _verify_death_and_dark_swamp_plan() -> void:
	var renderer: Object = OdinsEyePresentationRenderer.new()
	var spikes := [
		{"x": 260.0, "y": 620.0, "height": 42.0, "width": 7.0, "phase": "rising"},
		{"x": 310.0, "y": 580.0, "height": 58.0, "width": 9.0, "phase": "hold"},
	]
	var context := {
		"odins_eye_context": {
			"transformed": true,
			"death_animation_active": true,
			"death_phase": "disintegrate",
			"death_phase_progress": 0.72,
			"death_overall_progress": 0.91,
			"death_disintegrate_progress": 0.72,
			"hide_player_paddle": true,
			"dark_swamp_context": {"spikes": spikes},
		},
	}
	var plan: Dictionary = renderer.build_presentation_plan(
		context,
		Vector2(300.0, 700.0),
		Vector2(155.0, 50.0)
	)
	_expect(bool(plan.get("draw_death", false)), "death state should route through the death overlay")
	_expect(str(plan.get("death_phase", "")) == "disintegrate", "death plan should preserve the authoritative phase")
	_expect(bool(plan.get("hide_player", false)), "late disintegration should hide the base body")
	_expect(int(plan.get("dark_swamp_spike_count", -1)) == 2, "nested Dark Swamp spikes should be discoverable without actor-context duplication")
	var direct_plan: Dictionary = renderer.build_presentation_plan(
		context["odins_eye_context"],
		Vector2(300.0, 700.0),
		Vector2(155.0, 50.0)
	)
	_expect(int(direct_plan.get("dark_swamp_spike_count", -1)) == 2, "the public API should also accept the Odin sub-context directly")


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (got %.4f, expected %.4f)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
