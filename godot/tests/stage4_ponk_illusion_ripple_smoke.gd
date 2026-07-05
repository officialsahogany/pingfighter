extends SceneTree

const Stage4MapState := preload("res://scripts/stages/stage4/stage4_map_state.gd")
const Stage4PonkBossActorRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd")
const Stage4PonkBossSkillHudRenderer := preload("res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd")
const Stage4PonkIllusionRippleFxHost := preload("res://scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd")
const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")
const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")
const StageClearResultRuntimeContextHandler := preload("res://scripts/core/stage_clear_result_runtime_context_handler.gd")

const PIXEL_QA_VIEW_SIZE := Vector2i(320, 180)

var _failures: Array[String] = []


class CheckerboardCanvas:
	extends Node2D

	func _draw() -> void:
		for y in range(0, 180, 8):
			for x in range(0, 320, 8):
				var parity: int = (int(x / 8) + int(y / 8)) % 4
				var color := Color(0.10, 0.12, 0.24, 1.0)
				if parity == 1:
					color = Color(0.92, 0.26, 0.58, 1.0)
				elif parity == 2:
					color = Color(0.20, 0.88, 0.96, 1.0)
				elif parity == 3:
					color = Color(0.96, 0.82, 0.18, 1.0)
				draw_rect(Rect2(float(x), float(y), 8.0, 8.0), color)


class ActorAuraProbe:
	extends Node2D

	var renderer: Object = null
	var context: Dictionary = {}
	var direct_aura_intensity := 0.0
	var direct_burst_frames := 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(320.0, 180.0)), Color(0.035, 0.025, 0.075, 1.0))
		if direct_burst_frames > 0.0:
			if renderer != null:
				renderer.call("_draw_illusion_awaken_burst", self, Vector2(160.0, 74.0), {
					"stage4_illusion_awaken_burst": direct_burst_frames,
					"stage4_illusion_awaken_burst_total": 90.0,
				})
			return
		if direct_aura_intensity > 0.0:
			if renderer != null:
				renderer.call("_draw_illusion_awaken_aura", self, Vector2(160.0, 74.0), 0.0, direct_aura_intensity)
			return
		if renderer != null and renderer.has_method("draw"):
			renderer.draw(self, context, Vector2.ZERO)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var instance: Variant = instances.get(key, null)
		return instance if instance is Object else null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_locked_before_four_points()
	_test_awaken_staged_next_round_cast()
	_test_countdown_round_interrupt_restarts_delay()
	_test_awaken_burst_once_per_match()
	_test_duration_expiry_then_cooldown_refire()
	_test_cooldown_freeze_and_pause_gates()
	_test_reset_for_result_stops_illusion()
	_test_full_reset_clears_unlock()
	_test_fx_host_pipeline_status()
	_test_awaken_aura_fx_host_pipeline_status()
	_test_illusion_aura_renderer_contract()
	await _test_fx_host_sync_and_round_cleanup()
	await _test_awaken_aura_fx_host_sync_response()
	await _test_awaken_aura_enraged_context_supply()
	await _test_awaken_aura_orphan_host_result_cleanup()
	await _test_fx_host_pixel_distortion()
	await _test_fx_host_color_only_pixel_shift()
	await _test_actor_aura_pixel_signal()
	await _test_awaken_aura_fx_host_pixel_signal()
	await _test_actor_burst_pixel_signal()
	_test_skill_card_contract()

	if _failures.is_empty():
		print("stage4_ponk_illusion_ripple_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_locked_before_four_points() -> void:
	var state := Stage4PonkSkillState.new()
	for score in [1, 2, 3]:
		state.handle_score_event("player", {"player_score": score}, {"current_stage": 4})
		_expect(not bool(state.get("illusion_unlocked")), "illusion should stay locked before player reaches four points")
		_expect(int(state.get("illusion_awaken_stage")) == 0, "illusion should stay at awaken stage 0 before player reaches four points")
	state.set("illusion_cooldown_seconds", 0.0)
	state.update(1.0 / 60.0, _context(), _deps(state))
	_expect(not bool(state.get("illusion_active")), "unawakened illusion should not auto-fire even if cooldown is zero")
	var locked_card: Dictionary = _skill_card(state, "illusion_ripple")
	_expect(str(locked_card.get("status", "")) == "locked", "illusion card should report locked before awakening")


func _test_awaken_staged_next_round_cast() -> void:
	var map_state := Stage4MapState.new()
	var state := Stage4PonkSkillState.new()
	var deps := _deps(state)
	map_state.handle_score_event("player", {"player_score": 4}, deps)
	_expect(bool(state.get("illusion_unlocked")), "player four-point score event should unlock illusion")
	_expect(int(state.get("illusion_awaken_stage")) == 1, "player four-point score event should enter awaken stage 1")
	_expect(not bool(state.get("illusion_active")), "score event should not activate illusion before round cleanup")

	state.update(1.0 / 60.0, _context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 1, "live residual update after the score event must not consume awaken stage 1")
	_expect(not bool(state.get("illusion_active")), "live residual update after the score event must not activate illusion")

	state.reset_round(deps)
	_expect(bool(state.get("illusion_unlocked")), "round reset should keep the permanent illusion unlock")
	_expect(int(state.get("illusion_awaken_stage")) == 1, "round reset should preserve awaken stage 1")
	_expect(not bool(state.get("illusion_active")), "round reset should keep illusion inactive until the next update")

	state.update(1.0 / 60.0, _serve_context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 2, "serve-wait observation should advance illusion to awaken stage 2")
	_expect(not bool(state.get("illusion_active")), "serve-wait observation should not activate illusion")
	var serve_card: Dictionary = _skill_card(state, "illusion_ripple")
	_expect(str(serve_card.get("status", "")) == "charging", "illusion card should unlock as charging once stage 2 begins")

	state.update(1.0 / 60.0, _context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 3, "first post-serve live update should start the first-cast countdown")
	_expect(is_equal_approx(float(state.get("illusion_first_cast_delay_frames")), 180.0), "first-cast countdown should start at 180 frames")
	_expect(not bool(state.get("illusion_active")), "first post-serve live update should not cast before the delay elapses")

	for _idx in range(179):
		state.update(1.0 / 60.0, _context(), deps)
	_expect(not bool(state.get("illusion_active")), "illusion should stay inactive until the 180-frame first-cast delay finishes")
	_expect(is_equal_approx(float(state.get("illusion_first_cast_delay_frames")), 1.0), "first-cast countdown should have one frame left after 179 countdown frames")
	state.update(1.0 / 60.0, _context(), deps)
	_expect(bool(state.get("illusion_active")), "illusion should activate when the first-cast delay elapses")
	_expect(int(state.get("illusion_awaken_stage")) == 4, "first activation should move illusion to awaken stage 4 auto-loop")
	_expect(is_equal_approx(float(state.get("illusion_timer_frames")), 240.0), "fresh illusion activation should start at the full 240-frame duration")
	_expect(is_equal_approx(float(state.get("illusion_cooldown_seconds")), 70.0), "fresh illusion activation should start the 70-second cooldown")


func _test_countdown_round_interrupt_restarts_delay() -> void:
	var state := Stage4PonkSkillState.new()
	var deps := _deps(state)
	state.handle_score_event("player", {"player_score": 4}, deps)
	state.update(1.0 / 60.0, _serve_context(), deps)
	state.update(1.0 / 60.0, _context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 3, "setup should enter awaken stage 3 countdown")
	for _idx in range(60):
		state.update(1.0 / 60.0, _context(), deps)
	_expect(float(state.get("illusion_first_cast_delay_frames")) < 180.0, "setup should spend part of the first-cast delay")

	state.update(1.0 / 60.0, _serve_context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 2, "serve wait during first-cast countdown should return illusion to awaken stage 2")
	_expect(is_equal_approx(float(state.get("illusion_first_cast_delay_frames")), 180.0), "interrupted first-cast countdown should reset to 180 frames")
	_expect(not bool(state.get("illusion_active")), "interrupted first-cast countdown should not activate illusion")

	state.update(1.0 / 60.0, _context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 3, "next live transition after interruption should restart awaken stage 3")
	_expect(is_equal_approx(float(state.get("illusion_first_cast_delay_frames")), 180.0), "restarted first-cast countdown should begin at 180 frames")


func _test_awaken_burst_once_per_match() -> void:
	var state := Stage4PonkSkillState.new()
	var deps := _deps(state)
	state.handle_score_event("player", {"player_score": 4}, deps)
	state.update(1.0 / 60.0, _serve_context(), deps)
	state.update(1.0 / 60.0, _context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 3, "first live transition should enter stage 3 for burst setup")
	_expect(is_equal_approx(float(state.get("illusion_awaken_burst_frames")), 90.0), "first stage 2->3 transition should arm a 90-frame awaken burst")
	_expect(bool(state.get("illusion_awaken_burst_played")), "first stage 2->3 transition should mark the awaken burst as played")
	state.update(1.0 / 60.0, _context(), deps)
	_expect(is_equal_approx(float(state.get("illusion_awaken_burst_frames")), 89.0), "awaken burst should tick down after its armed frame")

	state.update(1.0 / 60.0, _serve_context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 2, "serve wait during countdown should bounce back to stage 2")
	state.update(1.0 / 60.0, _context(), deps)
	_expect(int(state.get("illusion_awaken_stage")) == 3, "second live transition should re-enter stage 3")
	_expect(float(state.get("illusion_awaken_burst_frames")) < 90.0, "stage 3 bounce should not re-arm the one-shot awaken burst")

	state.set("illusion_awaken_burst_frames", 42.0)
	state.reset_round(deps)
	_expect(is_zero_approx(float(state.get("illusion_awaken_burst_frames"))), "round reset should stop the active awaken burst frames")
	_expect(bool(state.get("illusion_awaken_burst_played")), "round reset should preserve the one-shot awaken burst played flag")

	state.reset()
	_expect(is_zero_approx(float(state.get("illusion_awaken_burst_frames"))), "full reset should clear awaken burst frames")
	_expect(not bool(state.get("illusion_awaken_burst_played")), "full reset should clear awaken burst played flag")

	state.handle_score_event("player", {"player_score": 4}, deps)
	state.update(1.0 / 60.0, _serve_context(), deps)
	state.update(1.0 / 60.0, _context(), deps)
	state.reset_for_result()
	_expect(is_zero_approx(float(state.get("illusion_awaken_burst_frames"))), "result reset should clear awaken burst frames")
	_expect(not bool(state.get("illusion_awaken_burst_played")), "result reset should clear awaken burst played flag")


func _test_duration_expiry_then_cooldown_refire() -> void:
	var state := Stage4PonkSkillState.new()
	state.force_activate_illusion()
	state.set("illusion_timer_frames", 1.0)
	state.update(1.0 / 60.0, _context(), _deps(state))
	_expect(not bool(state.get("illusion_active")), "illusion should expire when its duration reaches zero")

	state.set("illusion_cooldown_seconds", 0.01)
	state.update(1.0 / 60.0, _context(), _deps(state))
	_expect(bool(state.get("illusion_active")), "unlocked illusion should auto-refire after cooldown reaches zero")
	_expect(is_equal_approx(float(state.get("illusion_timer_frames")), 240.0), "auto-refired illusion should restart with the full duration")
	_expect(is_equal_approx(float(state.get("illusion_cooldown_seconds")), 70.0), "auto-refired illusion should restart the cooldown")


func _test_cooldown_freeze_and_pause_gates() -> void:
	var state := Stage4PonkSkillState.new()
	state.set("illusion_unlocked", true)
	state.set("illusion_cooldown_seconds", 10.0)
	var frozen_context: Dictionary = _context()
	frozen_context["stopwatch_freeze_active"] = true
	state.update(1.0 / 60.0, frozen_context, _deps(state))
	_expect(is_equal_approx(float(state.get("illusion_cooldown_seconds")), 10.0), "illusion cooldown should stop during stopwatch freeze")

	var paused_context: Dictionary = _context()
	paused_context["active_item_boss_skill_cooldown_paused"] = true
	state.update(1.0 / 60.0, paused_context, _deps(state))
	_expect(is_equal_approx(float(state.get("illusion_cooldown_seconds")), 10.0), "illusion cooldown should stop during boss-skill cooldown pause")

	state.update(1.0 / 60.0, _context(), _deps(state))
	_expect(float(state.get("illusion_cooldown_seconds")) < 10.0, "illusion cooldown should resume when freeze and pause gates clear")


func _test_reset_for_result_stops_illusion() -> void:
	var state := Stage4PonkSkillState.new()
	state.force_activate_illusion()
	state.set("illusion_awaken_stage", 3)
	state.set("illusion_first_cast_delay_frames", 90.0)
	state.set("illusion_awaken_burst_frames", 45.0)
	state.set("illusion_awaken_burst_played", true)
	state.reset_for_result()
	_assert_illusion_clear(state, "direct reset_for_result")

	var registry := FakeRegistry.new()
	var routed_state := Stage4PonkSkillState.new()
	routed_state.force_activate_illusion()
	registry.instances["stage4_ponk_skill_state"] = routed_state
	StageClearResultRuntimeContextHandler.new().reset_stage_for_result(registry, 4)
	_assert_illusion_clear(routed_state, "result handler Stage 4 reset")


func _test_full_reset_clears_unlock() -> void:
	var state := Stage4PonkSkillState.new()
	state.handle_score_event("player", {"player_score": 4}, {"current_stage": 4})
	state.reset()
	_assert_illusion_clear(state, "full reset")


func _test_fx_host_pipeline_status() -> void:
	Stage4PonkIllusionRippleFxHost.prewarm_assets()
	var status: Dictionary = Stage4PonkIllusionRippleFxHost.build_pipeline_status()
	_expect(bool(status.get("illusion_ripple_fx_shader_host_pipeline", false)), "illusion ripple should prewarm its shader host pipeline")
	_expect(bool(status.get("illusion_ripple_uses_screen_texture", false)), "illusion ripple should use hint_screen_texture")
	_expect(bool(status.get("illusion_ripple_uses_back_buffer_copy", false)), "illusion ripple should declare BackBufferCopy ownership")
	_expect(int(status.get("illusion_ripple_z_index", 0)) == 1272, "illusion ripple should use the locked z-index")
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_ponk_illusion_ripple_fx_host.gd")
	for token in ["hue_wave_amp", "hue_wave_freq", "hue_time_speed", "chroma_offset_px", "saturation_boost", "cross(grey_axis, col)"]:
		_expect(source.find(token) >= 0, "illusion ripple shader should include R2 color token '%s'" % token)


func _test_awaken_aura_fx_host_pipeline_status() -> void:
	Stage4PonkAwakenAuraFxHost.prewarm_assets()
	var status: Dictionary = Stage4PonkAwakenAuraFxHost.build_pipeline_status()
	_expect(bool(status.get("awaken_aura_fx_shader_host_pipeline", false)), "awaken aura should prewarm its reusable shader host pipeline")
	_expect(int(status.get("awaken_aura_fx_shader_layers", 0)) >= 2, "awaken aura should expose backplate and arc shader layers")
	_expect(int(status.get("awaken_aura_fx_gpu_particle_layers", 0)) >= 1, "awaken aura should expose a mote GPU particle layer")
	_expect(bool(status.get("awaken_aura_fx_texture_pieces_ready", false)), "awaken aura should prewarm all three generated PNG pieces")
	_expect(bool(status.get("awaken_aura_backplate_png_slot", false)), "awaken aura should use the mandala backplate PNG slot")
	_expect(bool(status.get("awaken_aura_mote_png_slot", false)), "awaken aura should use the lotus mote PNG slot")
	_expect(bool(status.get("awaken_aura_arc_png_slot", false)), "awaken aura should use the crescent arc PNG slot")
	_expect(int(status.get("awaken_aura_z_index", 0)) == 14, "awaken aura should mirror the Stage 4 magnetic host z convention")
	var host_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")
	for token in ["mythic_writhe.gdshader", "mythic_arc_flow.gdshader", "core_dim_strength", "PonkAwakenAuraBackplate", "PonkAwakenAuraMoteParticles"]:
		_expect(host_source.find(token) >= 0, "awaken aura host should include S2d token '%s'" % token)
	var state_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")
	_expect(state_source.find("Stage4PonkAwakenAuraFxHost") >= 0, "Ponk skill state should preload the awaken aura host")
	_expect(state_source.find("_get_or_create_awaken_aura_fx_host") >= 0, "Ponk skill state should own an awaken aura host factory")
	_expect(state_source.find("stage4_illusion_awaken_aura_modular_ready") >= 0, "Ponk skill state should tell the actor renderer when PNG aura is ready")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd")
	_expect(renderer_source.find("stage4_illusion_awaken_aura_modular_ready") >= 0, "Ponk actor renderer should gate procedural aura as a PNG-host fallback")


func _test_illusion_aura_renderer_contract() -> void:
	var renderer := Stage4PonkBossActorRenderer.new()
	var status: Dictionary = renderer.get_asset_status()
	_expect(status.has("ponk_boss_sheet"), "Ponk actor renderer should still expose its asset status contract")
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_ponk_boss_actor_renderer.gd")
	_expect(source.find("_draw_illusion_awaken_aura") >= 0, "Ponk actor renderer should own a procedural illusion awaken aura pass")
	_expect(source.find("_draw_illusion_awaken_burst") >= 0, "Ponk actor renderer should own a procedural illusion awaken burst pass")
	_expect(source.find("_draw_illusion_light_crown") >= 0, "Ponk actor renderer should draw the R2 rotating light crown")
	_expect(source.find("_hash01") >= 0, "Ponk actor burst should use deterministic index hashing for motes")
	_expect(source.find("_get_illusion_awaken_aura_intensity") >= 0, "Ponk actor renderer should derive aura intensity from the awaken state")
	_expect(source.find("stage4_illusion_awaken_stage") >= 0, "Ponk actor aura should read illusion awaken stage from draw context")
	_expect(source.find("stage4_illusion_first_cast_delay") >= 0, "Ponk actor aura should ramp from the first-cast delay")
	_expect(float(renderer.call("_get_illusion_awaken_aura_intensity", _actor_aura_context(false))) == 0.0, "Ponk actor aura should stay off before stage 2")
	_expect(float(renderer.call("_get_illusion_awaken_aura_intensity", _actor_stage_context(2))) >= 0.42, "Ponk actor aura should use the R2 stronger stage 2 baseline")
	_expect(float(renderer.call("_get_illusion_awaken_aura_intensity", _actor_stage_context(4))) >= 0.55, "Ponk actor aura should use the R2 stronger stage 4 baseline")
	_expect(float(renderer.call("_get_illusion_awaken_aura_intensity", _actor_aura_context(true))) > 0.8, "Ponk actor aura should build up during stage 3")


func _test_fx_host_sync_and_round_cleanup() -> void:
	var host := Stage4PonkIllusionRippleFxHost.new()
	get_root().add_child(host)
	await process_frame
	var initial_status: Dictionary = host.get_debug_status()
	_expect(not bool(initial_status.get("visible", true)), "fresh illusion ripple host should start hidden")
	_expect(bool(initial_status.get("has_back_buffer_copy", false)), "illusion ripple host should own BackBufferCopy")
	_expect(bool(initial_status.get("has_color_rect", false)), "illusion ripple host should own a ColorRect")

	host.sync_state({
		"active": true,
		"view_size_px": Vector2(1280.0, 720.0),
		"timer_frames": 120.0,
		"duration_total": 240.0,
		"elapsed_sec": 1.0,
		"hue_wave_amp": 1.1,
		"hue_wave_freq": 4.7,
		"hue_time_speed": 0.6,
		"chroma_offset_px": 4.25,
		"saturation_boost": 0.33,
	}, true)
	var active_status: Dictionary = host.get_debug_status()
	_expect(bool(active_status.get("visible", false)), "active illusion ripple sync should show the host")
	_expect(int(active_status.get("copy_mode", -1)) == BackBufferCopy.COPY_MODE_VIEWPORT, "illusion ripple should capture the viewport")
	_expect((active_status.get("rect_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(1280.0, 720.0)), "illusion ripple rect should cover the viewport")
	_expect(float(active_status.get("strength", 0.0)) > 0.5, "mid-duration illusion ripple should drive a strong envelope")
	_expect(is_equal_approx(float(active_status.get("intensity_px", 0.0)), 12.0), "illusion ripple should use the locked default intensity")
	_expect(is_equal_approx(float(active_status.get("wave_freq_a", 0.0)), 9.0), "illusion ripple should use the locked first wave frequency")
	_expect(is_equal_approx(float(active_status.get("wave_freq_b", 0.0)), 17.0), "illusion ripple should use the locked second wave frequency")
	_expect(is_equal_approx(float(active_status.get("hue_wave_amp", 0.0)), 1.1), "illusion ripple should sync hue wave amplitude")
	_expect(is_equal_approx(float(active_status.get("hue_wave_freq", 0.0)), 4.7), "illusion ripple should sync hue wave frequency")
	_expect(is_equal_approx(float(active_status.get("hue_time_speed", 0.0)), 0.6), "illusion ripple should sync safe hue time speed")
	_expect(is_equal_approx(float(active_status.get("chroma_offset_px", 0.0)), 4.25), "illusion ripple should sync chromatic offset")
	_expect(is_equal_approx(float(active_status.get("saturation_boost", 0.0)), 0.33), "illusion ripple should sync saturation boost")

	host.force_timeout_for_tests()
	_expect(not bool(host.get_debug_status().get("visible", true)), "illusion ripple host should self-hide if owner sync stops")
	host.queue_free()

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var state := Stage4PonkSkillState.new()
	state.force_activate_illusion()
	state.set("illusion_timer_frames", 120.0)
	var draw_context: Dictionary = _context()
	draw_context["view_size"] = Vector2(1280.0, 720.0)
	draw_context.merge(state.get_actor_draw_context(true), true)
	state.draw(canvas, draw_context, Vector2.ZERO)
	await process_frame
	var attached_host: Node = canvas.get_node_or_null("PonkIllusionRippleFxHost")
	_expect(attached_host != null, "active illusion draw should attach the ripple FX host")
	if attached_host != null:
		_expect(bool(attached_host.get_debug_status().get("visible", false)), "active illusion draw should show the attached ripple FX host")
	state.reset_round(_deps(state))
	if attached_host != null and is_instance_valid(attached_host):
		_expect(not bool(attached_host.get_debug_status().get("visible", true)), "round reset should hide the attached illusion ripple FX host")
	canvas.queue_free()


func _test_awaken_aura_fx_host_sync_response() -> void:
	Stage4PonkAwakenAuraFxHost.prewarm_assets()
	var host := Stage4PonkAwakenAuraFxHost.new()
	get_root().add_child(host)
	await process_frame
	host.prewarm_runtime_nodes()
	var initial_status: Dictionary = host.get_debug_status()
	_expect(not bool(initial_status.get("visible", true)), "fresh awaken aura host should start hidden")
	_expect(bool(initial_status.get("texture_pieces_ready", false)), "awaken aura host should have all generated texture pieces")
	_expect(bool(initial_status.get("has_backplate_sprite", false)), "awaken aura host should build the backplate sprite")
	_expect(int(initial_status.get("arc_sprite_count", 0)) >= 3, "awaken aura host should build three orbit arc sprites")
	_expect(bool(initial_status.get("has_mote_particles", false)), "awaken aura host should build the mote particles")
	_expect(bool(initial_status.get("backplate_blend_add", false)), "awaken aura backplate should use additive blending")
	_expect(bool(initial_status.get("arc_blend_add", false)), "awaken aura arcs should use additive blending")
	_expect(bool(initial_status.get("particles_blend_add", false)), "awaken aura particles should use additive blending")

	host.sync_state(_awaken_aura_fx_state(0.42), true)
	await process_frame
	var low_status: Dictionary = host.get_debug_status()
	_expect(bool(low_status.get("visible", false)), "stage 2 awaken aura sync should show the host")
	_expect(int(low_status.get("visible_arc_count", 0)) >= 2, "stage 2 awaken aura should show the first orbit arcs")
	host.sync_state(_awaken_aura_fx_state(1.0), true)
	await process_frame
	var high_status: Dictionary = host.get_debug_status()
	_expect(float(high_status.get("backplate_alpha", 0.0)) > float(low_status.get("backplate_alpha", 0.0)), "casting awaken aura should raise backplate alpha")
	_expect(float(high_status.get("backplate_scale_x", 0.0)) > float(low_status.get("backplate_scale_x", 0.0)), "casting awaken aura should grow the mandala backplate")
	_expect(int(high_status.get("visible_arc_count", 0)) >= int(low_status.get("visible_arc_count", 0)), "casting awaken aura should keep or increase orbit arcs")
	_expect(float(high_status.get("mote_amount_ratio", 0.0)) > float(low_status.get("mote_amount_ratio", 0.0)), "casting awaken aura should raise mote emission")
	host.sync_state(_awaken_aura_fx_state(0.0), false)
	var hidden_status: Dictionary = host.get_debug_status()
	_expect(not bool(hidden_status.get("visible", true)), "inactive awaken aura sync should hide the host")
	_expect(not bool(hidden_status.get("mote_emitting", true)), "inactive awaken aura sync should stop mote emission")
	host.queue_free()

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var state := Stage4PonkSkillState.new()
	state.handle_score_event("player", {"player_score": 4}, {"current_stage": 4})
	state.update(1.0 / 60.0, _serve_context(), _deps(state))
	var draw_context: Dictionary = _context()
	draw_context.merge(state.get_actor_draw_context(true), true)
	state.draw(canvas, draw_context, Vector2.ZERO)
	await process_frame
	var attached_host: Node = canvas.get_node_or_null("PonkAwakenAuraFxHost")
	_expect(attached_host != null, "stage 2 aura draw should attach the awaken aura FX host")
	if attached_host != null:
		_expect(bool(attached_host.get_debug_status().get("visible", false)), "stage 2 aura draw should show the attached awaken aura host")
	state.reset_round(_deps(state))
	if attached_host != null and is_instance_valid(attached_host):
		_expect(not bool(attached_host.get_debug_status().get("visible", true)), "round reset should hide the attached awaken aura host")
	canvas.queue_free()


func _test_awaken_aura_enraged_context_supply() -> void:
	Stage4PonkAwakenAuraFxHost.prewarm_assets()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var state := Stage4PonkSkillState.new()
	state.handle_score_event("player", {"player_score": 4}, {"current_stage": 4})
	var serve_context: Dictionary = _serve_context()
	serve_context["boss_enraged"] = true
	state.update(1.0 / 60.0, serve_context, _deps(state))
	var snapshot: Dictionary = state.get_debug_snapshot()
	_expect(bool(snapshot.get("illusion_aura_enraged", false)), "update should capture the awaken aura enraged state from live context")
	var draw_context: Dictionary = _context()
	draw_context.merge(state.get_actor_draw_context(true), true)
	_expect(bool(draw_context.get("stage4_illusion_awaken_aura_enraged", false)), "actor draw context should expose awaken aura enraged state")
	state.draw(canvas, draw_context, Vector2.ZERO)
	await process_frame
	var attached_host: Node = canvas.get_node_or_null("PonkAwakenAuraFxHost")
	_expect(attached_host != null, "enraged stage 2 aura draw should attach the awaken aura host")
	if attached_host != null:
		_expect(bool(attached_host.get_debug_status().get("enraged", false)), "awaken aura FX context should pass enraged=true to the host")
	canvas.queue_free()


func _test_awaken_aura_orphan_host_result_cleanup() -> void:
	Stage4PonkAwakenAuraFxHost.prewarm_assets()
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var host := Stage4PonkAwakenAuraFxHost.new()
	host.name = "PonkAwakenAuraFxHost"
	canvas.add_child(host)
	await process_frame
	host.prewarm_runtime_nodes()
	host.sync_state(_awaken_aura_fx_state(1.0), true)
	await process_frame
	_expect(bool(host.get_debug_status().get("visible", false)), "setup should leave an orphaned awaken aura host visible before result cleanup")

	var registry := FakeRegistry.new()
	StageClearResultRuntimeContextHandler.new().reset_stage_for_result(registry, 4)
	await process_frame
	_expect(not bool(host.get_debug_status().get("visible", true)), "Stage 4 result cleanup should hide orphaned awaken aura hosts even without a skill-state reference")
	_expect(not bool(host.get_debug_status().get("mote_emitting", true)), "Stage 4 result cleanup should stop orphaned awaken aura particles")

	host.sync_state(_awaken_aura_fx_state(1.0), true)
	await process_frame
	StageClearResultRuntimeContextHandler.new().reset_stage_for_result(registry, 5)
	await process_frame
	_expect(not bool(host.get_debug_status().get("visible", true)), "any result cleanup should hide stale Stage 4 awaken aura hosts if current_stage has already advanced")
	canvas.queue_free()


func _test_fx_host_pixel_distortion() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("stage4_ponk_illusion_ripple_smoke: pixel QA skipped under headless display")
		return
	get_root().size = PIXEL_QA_VIEW_SIZE
	var checkerboard := CheckerboardCanvas.new()
	checkerboard.name = "IllusionRippleCheckerboard"
	get_root().add_child(checkerboard)
	checkerboard.queue_redraw()
	await process_frame
	await process_frame
	var before: Image = get_root().get_texture().get_image()

	var host := Stage4PonkIllusionRippleFxHost.new()
	host.name = "IllusionRipplePixelProbe"
	get_root().add_child(host)
	await process_frame
	host.sync_state({
		"active": true,
		"view_size_px": Vector2(PIXEL_QA_VIEW_SIZE),
		"strength": 1.0,
		"intensity_px": 28.0,
		"wave_freq_a": 9.0,
		"wave_freq_b": 17.0,
		"wave_speed": 2.2,
		"elapsed_sec": 0.85,
	}, true)
	await process_frame
	await process_frame
	var after: Image = get_root().get_texture().get_image()
	var delta: float = _sample_image_delta(before, after)
	_expect(delta > 0.035, "active illusion ripple should visibly distort a high-contrast pattern in pixel QA")

	host.queue_free()
	checkerboard.queue_free()


func _test_fx_host_color_only_pixel_shift() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("stage4_ponk_illusion_ripple_smoke: color pixel QA skipped under headless display")
		return
	get_root().size = PIXEL_QA_VIEW_SIZE
	var checkerboard := CheckerboardCanvas.new()
	checkerboard.name = "IllusionRippleColorCheckerboard"
	get_root().add_child(checkerboard)
	checkerboard.queue_redraw()
	await process_frame
	await process_frame
	var before: Image = get_root().get_texture().get_image()

	var host := Stage4PonkIllusionRippleFxHost.new()
	host.name = "IllusionRippleColorPixelProbe"
	get_root().add_child(host)
	await process_frame
	host.sync_state({
		"active": true,
		"view_size_px": Vector2(PIXEL_QA_VIEW_SIZE),
		"strength": 1.0,
		"intensity_px": 0.0,
		"hue_wave_amp": 2.0,
		"hue_wave_freq": 4.0,
		"hue_time_speed": 0.2,
		"chroma_offset_px": 0.0,
		"saturation_boost": 0.0,
		"elapsed_sec": 0.85,
	}, true)
	await process_frame
	await process_frame
	var after: Image = get_root().get_texture().get_image()
	var delta: float = _sample_image_delta(before, after)
	_expect(delta > 0.018, "illusion hue layer should visibly change checkerboard pixels with UV distortion disabled")

	host.queue_free()
	checkerboard.queue_free()


func _test_actor_aura_pixel_signal() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("stage4_ponk_illusion_ripple_smoke: actor aura pixel QA skipped under headless display")
		return
	var renderer := Stage4PonkBossActorRenderer.new()
	renderer.prewarm_assets()
	var before: Image = await _capture_actor_aura_image(renderer, 0.0)
	var after: Image = await _capture_actor_aura_image(renderer, 1.0)
	var delta: float = _sample_actor_aura_delta(before, after)
	_expect(delta > 0.012, "stage 3 illusion awaken aura should visibly change pixels around Ponk")


func _test_awaken_aura_fx_host_pixel_signal() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("stage4_ponk_illusion_ripple_smoke: awaken aura host pixel QA skipped under headless display")
		return
	Stage4PonkAwakenAuraFxHost.prewarm_assets()
	var before: Image = await _capture_awaken_aura_host_image(0.0)
	var after: Image = await _capture_awaken_aura_host_image(1.0)
	var delta: float = _sample_image_delta(before, after)
	_expect(delta > 0.014, "textured awaken aura host should visibly change pixels around Ponk")


func _test_actor_burst_pixel_signal() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		print("stage4_ponk_illusion_ripple_smoke: actor burst pixel QA skipped under headless display")
		return
	var renderer := Stage4PonkBossActorRenderer.new()
	renderer.prewarm_assets()
	var before: Image = await _capture_actor_burst_image(renderer, 0.0)
	var after: Image = await _capture_actor_burst_image(renderer, 90.0)
	var delta: float = _sample_actor_aura_delta(before, after)
	_expect(delta > 0.018, "stage 2->3 awaken burst should visibly change pixels around Ponk")


func _test_skill_card_contract() -> void:
	var renderer := Stage4PonkBossSkillHudRenderer.new()
	var asset_status: Dictionary = renderer.get_asset_status()
	_expect(bool(asset_status.get("illusion_ripple_card_texture", false)), "illusion ripple skillcard should load the dedicated themed PNG art")

	var state := Stage4PonkSkillState.new()
	var cards: Array = _cards(state)
	_expect(cards.size() == 3, "Ponk skill card HUD should expose exactly three cards")
	var locked_card: Dictionary = _skill_card(state, "illusion_ripple")
	for key in ["id", "name", "short_label", "trigger", "trigger_type", "status", "ready", "active", "progress", "remaining", "total", "cooldown_remaining", "cooldown_total", "duration_remaining", "duration_total", "color", "description"]:
		_expect(locked_card.has(key), "illusion card should expose required field '%s'" % key)
	_expect(str(locked_card.get("name", "")) == "몽환포영", "illusion card should expose the locked Korean display name")
	_expect(str(locked_card.get("status", "")) == "locked", "illusion card should be locked before awakening")

	state.handle_score_event("player", {"player_score": 4}, {"current_stage": 4})
	var stage1_card: Dictionary = _skill_card(state, "illusion_ripple")
	_expect(str(stage1_card.get("status", "")) == "locked", "stage 1 illusion should keep the card locked until serve wait is observed")

	state.update(1.0 / 60.0, _serve_context(), _deps(state))
	var stage2_card: Dictionary = _skill_card(state, "illusion_ripple")
	_expect(str(stage2_card.get("status", "")) == "charging", "stage 2 illusion card should report charging")
	state.update(1.0 / 60.0, _context(), _deps(state))
	var stage3_card: Dictionary = _skill_card(state, "illusion_ripple")
	_expect(str(stage3_card.get("status", "")) == "charging", "stage 3 countdown should keep the illusion card charging")
	_expect(is_equal_approx(float(stage3_card.get("remaining", 0.0)), 3.0), "stage 3 card remaining should expose the three-second first-cast delay")
	for _idx in range(180):
		state.update(1.0 / 60.0, _context(), _deps(state))
	var casting_card: Dictionary = _skill_card(state, "illusion_ripple")
	_expect(str(casting_card.get("status", "")) == "casting", "active illusion card should report casting")
	_expect(bool(casting_card.get("active", false)), "active illusion card should expose active=true")


func _assert_illusion_clear(state: Object, label: String) -> void:
	_expect(not bool(state.get("illusion_unlocked")), "%s should clear illusion unlock" % label)
	_expect(int(state.get("illusion_awaken_stage")) == 0, "%s should clear illusion awaken stage" % label)
	_expect(is_zero_approx(float(state.get("illusion_first_cast_delay_frames"))), "%s should clear illusion first-cast delay" % label)
	_expect(is_zero_approx(float(state.get("illusion_awaken_burst_frames"))), "%s should clear illusion awaken burst frames" % label)
	_expect(not bool(state.get("illusion_awaken_burst_played")), "%s should clear illusion awaken burst played flag" % label)
	_expect(not bool(state.get("illusion_active")), "%s should clear active illusion" % label)
	_expect(is_zero_approx(float(state.get("illusion_timer_frames"))), "%s should clear illusion timer" % label)
	_expect(is_zero_approx(float(state.get("illusion_cooldown_seconds"))), "%s should clear illusion cooldown" % label)


func _cards(state: Object) -> Array:
	return _as_array(state.get_skill_card_hud_context(null, _context()).get("stage4_ponk_boss_skill_hud_skills", []))


func _skill_card(state: Object, skill_id: String) -> Dictionary:
	for card in _cards(state):
		if card is Dictionary and str((card as Dictionary).get("id", "")) == skill_id:
			return card as Dictionary
	return {}


func _context() -> Dictionary:
	return {
		"current_stage": 4,
		"ball_active": true,
		"ball_pos": Vector2(370.0, 82.0),
		"ball_vel": Vector2(0.0, 8.0),
		"boss_pos": Vector2(320.0, 46.0),
		"boss_paddle_size": Vector2(124.0, 46.0),
		"player_pos": Vector2(320.0, 680.0),
		"player_paddle_size": Vector2(120.0, 50.0),
		"ball_base_speed": 7.65,
	}


func _actor_aura_context(active_aura: bool) -> Dictionary:
	var context := _context()
	context["boss_pos"] = Vector2(110.0, 20.0)
	context["boss_paddle_size"] = Vector2(100.0, 32.0)
	context["boss_hitbox_height"] = 40.0
	context["stage4_illusion_unlocked"] = active_aura
	context["stage4_illusion_awaken_stage"] = 3 if active_aura else 0
	context["stage4_illusion_first_cast_delay"] = 24.0
	context["stage4_illusion_first_cast_delay_total"] = 180.0
	context["stage4_illusion_active"] = false
	return context


func _actor_stage_context(stage: int) -> Dictionary:
	var context := _actor_aura_context(stage >= 2)
	context["stage4_illusion_awaken_stage"] = stage
	context["stage4_illusion_first_cast_delay"] = 180.0
	if stage == 3:
		context["stage4_illusion_first_cast_delay"] = 24.0
	return context


func _awaken_aura_fx_state(intensity: float) -> Dictionary:
	return {
		"active": intensity > 0.001,
		"intensity": intensity,
		"boss_center": Vector2(160.0, 82.0),
		"elapsed": 1.25,
		"enraged": false,
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
	}


func _serve_context() -> Dictionary:
	var context := _context()
	context["ball_active"] = false
	context["serve_wait_active"] = true
	context["scoreboard_active"] = true
	return context


func _deps(state: Object) -> Dictionary:
	return {
		"current_stage": 4,
		"stage4_ponk_skill_state": state,
	}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _capture_actor_aura_image(renderer: Object, intensity: float) -> Image:
	var viewport := SubViewport.new()
	viewport.size = PIXEL_QA_VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var probe := ActorAuraProbe.new()
	probe.renderer = renderer
	probe.direct_aura_intensity = intensity
	viewport.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


func _capture_awaken_aura_host_image(intensity: float) -> Image:
	var viewport := SubViewport.new()
	viewport.size = PIXEL_QA_VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var background := CheckerboardCanvas.new()
	viewport.add_child(background)
	var host := Stage4PonkAwakenAuraFxHost.new()
	viewport.add_child(host)
	await process_frame
	host.prewarm_runtime_nodes()
	host.sync_state(_awaken_aura_fx_state(intensity), intensity > 0.001)
	background.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _capture_actor_burst_image(renderer: Object, burst_frames: float) -> Image:
	var viewport := SubViewport.new()
	viewport.size = PIXEL_QA_VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var probe := ActorAuraProbe.new()
	probe.renderer = renderer
	probe.direct_burst_frames = burst_frames
	viewport.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


func _sample_actor_aura_delta(before: Image, after: Image) -> float:
	if before == null or after == null or before.is_empty() or after.is_empty():
		return 0.0
	var max_x: int = mini(before.get_width(), after.get_width()) - 1
	var max_y: int = mini(before.get_height(), after.get_height()) - 1
	if max_x <= 0 or max_y <= 0:
		return 0.0
	var total := 0.0
	var strongest := 0.0
	var count := 0
	for y in range(4, 158, 10):
		for x in range(72, 249, 10):
			if absf(float(x) - 160.0) < 38.0 and absf(float(y) - 74.0) < 48.0:
				continue
			var point := Vector2i(clampi(x, 0, max_x), clampi(y, 0, max_y))
			var a: Color = before.get_pixel(point.x, point.y)
			var b: Color = after.get_pixel(point.x, point.y)
			var delta := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			total += delta
			strongest = maxf(strongest, delta)
			count += 1
	if count <= 0:
		return 0.0
	return maxf(total / float(count), strongest * 0.35)


func _sample_image_delta(before: Image, after: Image) -> float:
	if before == null or after == null or before.is_empty() or after.is_empty():
		return 0.0
	var max_x: int = mini(before.get_width(), after.get_width()) - 1
	var max_y: int = mini(before.get_height(), after.get_height()) - 1
	if max_x <= 0 or max_y <= 0:
		return 0.0
	var samples := [
		Vector2i(32, 24),
		Vector2i(71, 45),
		Vector2i(118, 62),
		Vector2i(163, 87),
		Vector2i(217, 104),
		Vector2i(276, 138),
		Vector2i(302, 161),
	]
	var total := 0.0
	for sample in samples:
		var point: Vector2i = sample
		point.x = clampi(point.x, 0, max_x)
		point.y = clampi(point.y, 0, max_y)
		var a: Color = before.get_pixel(point.x, point.y)
		var b: Color = after.get_pixel(point.x, point.y)
		total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return total / float(samples.size())


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
