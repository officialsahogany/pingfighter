extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const DefeatContinueRevivalBeatState := preload("res://scripts/core/defeat_continue_revival_beat_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var player_pos := Vector2(280.0, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var defeat_continue_revival_beat_active := false
	var defeat_continue_revival_beat_phase := ""
	var defeat_continue_revival_beat_elapsed := 0.0
	var defeat_continue_revival_beat_full_pose := false


func _init() -> void:
	_verify_full_pose_beat_blocks_and_tracks_player()
	_verify_fallback_character_glows_without_pose()
	_verify_wall_clock_failsafe_releases_block()
	_verify_actor_context_injects_pose_without_scoreboard()
	_verify_schema_and_source_contracts()

	if _failures.is_empty():
		print("defeat_continue_revival_beat_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_full_pose_beat_blocks_and_tracks_player() -> void:
	var owner := FakeOwner.new()
	var state := DefeatContinueRevivalBeatState.new()
	state.start(owner, Vector2(560.0, 540.0), Vector2(1280.0, 720.0))
	_expect(state.is_active(), "revival beat should become active on start")
	_expect(state.blocks_battle_physics(), "revival beat must block battle physics while active")
	_expect(owner.defeat_continue_revival_beat_active, "revival beat should mirror active state to the owner schema")
	_expect(str(owner.defeat_continue_revival_beat_phase) == "defeat_hold", "revival beat should start in defeat hold")

	var context := state.get_actor_draw_context()
	_expect(bool(context.get("player_defeat_active", false)), "Smasher should use the player defeat pose during the hold/flight")
	_expect(not bool(context.get("player_victory_active", false)), "Smasher should not show victory pose before absorption")
	_expect(not bool(state.get_sacred_overlay_status().get("active", true)), "sacred revival overlay should stay off during the defeat hold")
	var color_restore := state.get_color_restore_status(Vector2(1280.0, 720.0))
	_expect(bool(color_restore.get("active", false)), "color restore postprocess should be active during defeat hold")
	_expect(float(color_restore.get("desaturate_amount", 0.0)) >= 0.99, "defeat hold should already be full grayscale")
	_expect(float(color_restore.get("restore_radius_px", 1.0)) <= 0.001, "defeat hold should not restore color before victory")

	var before_target: Vector2 = state.get_status_for_tests().get("target_screen_pos", Vector2.ZERO)
	owner.player_pos.x += 82.0
	state.update(0.80, owner, Vector2(1280.0, 720.0))
	var after_target: Vector2 = state.get_status_for_tests().get("target_screen_pos", Vector2.ZERO)
	_expect(after_target.x > before_target.x + 20.0, "absorption target should track the moving player center")
	_expect(str(state.get_status_for_tests().get("phase", "")) == "gem_flight", "beat should enter gem flight after defeat hold")
	_expect(float(state.get_actor_draw_context().get("player_continue_absorb_glow_ratio", 0.0)) > 0.0, "gem flight should begin the absorb glow")
	var sacred := state.get_sacred_overlay_status()
	_expect(bool(sacred.get("active", false)), "gem flight should enable the foreground sacred trail")
	_expect(float(sacred.get("trail_strength", 0.0)) > 0.10, "gem flight should carry a faint sacred trail")
	_expect(float(sacred.get("bloom_strength", 1.0)) <= 0.001, "gem flight should not fire the sacred bloom early")
	_expect(float(sacred.get("warm_ratio", 1.0)) < 0.20, "gem flight should remain mostly cold before absorption")
	color_restore = state.get_color_restore_status(Vector2(1280.0, 720.0))
	_expect(bool(color_restore.get("active", false)), "color restore postprocess should stay active during gem flight")
	_expect(float(color_restore.get("desaturate_amount", 0.0)) >= 0.99, "gem flight should remain full grayscale")
	_expect(float(color_restore.get("restore_radius_px", 1.0)) <= 0.001, "gem flight should not restore color before victory")

	state.update(0.54, owner, Vector2(1280.0, 720.0))
	_expect(str(state.get_status_for_tests().get("phase", "")) == "absorb_flash", "beat should enter absorb flash after gem flight")
	_expect(float(state.get_actor_draw_context().get("player_continue_absorb_glow_ratio", 0.0)) > 0.3, "absorb flash should keep a visible player glow")
	var early_color_restore := state.get_color_restore_status(Vector2(1280.0, 720.0))
	state.update(0.18, owner, Vector2(1280.0, 720.0))
	_expect(str(state.get_status_for_tests().get("phase", "")) == "absorb_flash", "beat should stay in absorb flash for the late desaturation sample")
	sacred = state.get_sacred_overlay_status()
	_expect(float(sacred.get("bloom_strength", 0.0)) > 0.55, "absorb flash should peak the sacred revival bloom")
	_expect(float(sacred.get("flash_alpha", 0.0)) > 0.15, "absorb flash should add a bounded white-gold flash")
	_expect(float(sacred.get("ray_alpha", 0.0)) > 0.20, "absorb flash should fire foreground god rays")
	_expect(float(sacred.get("mote_alpha", 0.0)) > 0.30, "absorb flash should lift sacred motes")
	_expect(float(sacred.get("warm_ratio", 0.0)) > 0.20, "absorb flash should transition from cold cyan toward warm gold")
	color_restore = state.get_color_restore_status(Vector2(1280.0, 720.0))
	_expect(bool(color_restore.get("active", false)), "absorb flash should activate the color restore postprocess")
	_expect(float(early_color_restore.get("desaturate_amount", 0.0)) >= 0.99, "early absorb flash should already be full grayscale")
	_expect(
		is_equal_approx(float(color_restore.get("desaturate_amount", 0.0)), float(early_color_restore.get("desaturate_amount", 0.0))),
		"absorb flash desaturation should stay full grayscale instead of ramping late"
	)
	_expect(float(color_restore.get("restore_radius_px", 1.0)) <= 0.001, "absorb flash should not restore color before victory pulse")
	_expect(bool(color_restore.get("single_clock", false)), "color restore postprocess should be driven by the revival beat clock")

	state.update(0.35, owner, Vector2(1280.0, 720.0))
	context = state.get_actor_draw_context()
	_expect(bool(context.get("player_victory_active", false)), "Smasher should pulse the victory pose after absorption")
	_expect(not bool(context.get("player_defeat_active", false)), "victory pulse should clear the defeat pose")
	sacred = state.get_sacred_overlay_status()
	_expect(float(sacred.get("warm_ratio", 0.0)) >= 0.99, "victory pulse sacred overlay should be warm gold")
	_expect(float(sacred.get("bloom_strength", 0.0)) > 0.0, "victory pulse should sustain a fading sacred bloom")
	_expect(float(sacred.get("flash_alpha", 1.0)) <= 0.001, "victory pulse should drop the peak white flash")
	color_restore = state.get_color_restore_status(Vector2(1280.0, 720.0))
	_expect(bool(color_restore.get("active", false)), "victory pulse should keep the color restore postprocess active")
	_expect(float(color_restore.get("desaturate_amount", 0.0)) >= 0.99, "victory pulse should hold full grayscale outside the restore circle")
	_expect(float(color_restore.get("restore_radius_px", 0.0)) > 20.0, "victory pulse should expand the color restore radius from the player")
	var target_pos: Vector2 = state.get_status_for_tests().get("target_screen_pos", Vector2.ZERO)
	_expect((color_restore.get("center_px", Vector2.ZERO) as Vector2).is_equal_approx(target_pos), "color restore circle should stay centered on the tracked player")
	var victory_glow := float(context.get("player_continue_absorb_glow_ratio", 0.0))
	var victory_bloom := float(sacred.get("bloom_strength", 0.0))
	var victory_radius := float(color_restore.get("restore_radius_px", 0.0))
	state.update(0.22, owner, Vector2(1280.0, 720.0))
	_expect(float(state.get_actor_draw_context().get("player_continue_absorb_glow_ratio", 0.0)) < victory_glow, "victory pulse glow should fade instead of staying at the absorb plateau")
	_expect(float(state.get_sacred_overlay_status().get("bloom_strength", 0.0)) < victory_bloom, "victory pulse sacred bloom should fade inside the same beat clock")
	_expect(float(state.get_color_restore_status(Vector2(1280.0, 720.0)).get("restore_radius_px", 0.0)) > victory_radius, "color restore radius should expand monotonically during victory pulse")

	var near_end_delta: float = maxf(0.0, state.get_total_duration() - float(state.get_status_for_tests().get("elapsed", 0.0)) - 0.001)
	state.update(near_end_delta, owner, Vector2(1280.0, 720.0))
	color_restore = state.get_color_restore_status(Vector2(1280.0, 720.0))
	var terminal_center: Vector2 = color_restore.get("center_px", Vector2.ZERO)
	var terminal_corner_distance := _max_corner_distance(terminal_center, Vector2(1280.0, 720.0))
	var terminal_feather := _expected_color_restore_feather(Vector2(1280.0, 720.0))
	_expect(
		float(color_restore.get("max_radius_px", 0.0)) >= terminal_corner_distance + terminal_feather * 0.99,
		"terminal color restore max radius should cover the farthest corner plus feather so no grayscale rim remains"
	)
	_expect(
		float(color_restore.get("restore_radius_px", 0.0)) >= float(color_restore.get("max_radius_px", 0.0)) * 0.99,
		"terminal color restore radius should nearly reach its corner-covering max radius before the beat ends"
	)

	state.update(0.01, owner, Vector2(1280.0, 720.0))
	_expect(not state.is_active(), "revival beat should end by itself after its single clock finishes")
	_expect(not owner.defeat_continue_revival_beat_active, "owner active mirror should clear after beat end")
	_expect(not bool(state.get_color_restore_status(Vector2(1280.0, 720.0)).get("active", true)), "color restore postprocess should shut off when the beat ends")


func _verify_fallback_character_glows_without_pose() -> void:
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	var state := DefeatContinueRevivalBeatState.new()
	state.start(owner, Vector2(560.0, 540.0), Vector2(1280.0, 720.0))
	state.update(0.90, owner, Vector2(1280.0, 720.0))
	var context := state.get_actor_draw_context()
	_expect(bool(context.get("defeat_continue_revival_beat_active", false)), "fallback characters should still expose beat activity")
	_expect(float(context.get("player_continue_absorb_glow_ratio", 0.0)) > 0.0, "fallback characters should still get absorb glow")
	_expect(not bool(context.get("player_defeat_active", false)), "Commando fallback should not require a defeat pose sheet")
	_expect(not bool(context.get("player_victory_active", false)), "Commando fallback should not require a victory pose sheet")
	state.update(0.50, owner, Vector2(1280.0, 720.0))
	_expect(float(state.get_sacred_overlay_status().get("bloom_strength", 0.0)) > 0.30, "fallback characters should still receive the sacred revival bloom")


func _verify_wall_clock_failsafe_releases_block() -> void:
	var owner := FakeOwner.new()
	var state := DefeatContinueRevivalBeatState.new()
	state.start(owner, Vector2(560.0, 540.0), Vector2(1280.0, 720.0))
	state.force_wall_clock_timeout_for_tests()
	_expect(not state.blocks_battle_physics(), "wall-clock failsafe should release physics if the beat update clock is starved")
	_expect(not state.is_active(), "wall-clock failsafe should clear active state when it releases physics")
	_expect(not owner.defeat_continue_revival_beat_active, "wall-clock failsafe should clear the owner active mirror")


func _verify_actor_context_injects_pose_without_scoreboard() -> void:
	var owner := FakeOwner.new()
	var state := DefeatContinueRevivalBeatState.new()
	state.start(owner, Vector2(560.0, 540.0), Vector2(1280.0, 720.0))
	var builder := BattleDrawActorContext.new()
	var actor_context := builder.build(
		{
			"current_stage": 1,
			"selected_character_type": "smasher",
			"player_pos": Vector2(280.0, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
		{
			"defeat_continue_revival_beat_state": state,
		}
	)
	_expect(bool(actor_context.get("player_defeat_active", false)), "actor context should inject defeat pose without an active scoreboard result")

	state.update(1.70, owner, Vector2(1280.0, 720.0))
	actor_context = builder.build(
		{
			"current_stage": 1,
			"selected_character_type": "smasher",
			"player_pos": Vector2(280.0, 700.0),
			"player_paddle_size": Vector2(155.0, 50.0),
		},
		{
			"defeat_continue_revival_beat_state": state,
		}
	)
	_expect(bool(actor_context.get("player_victory_active", false)), "actor context should inject victory pose without an active scoreboard result")


func _verify_schema_and_source_contracts() -> void:
	var defaults: Dictionary = BattleSceneState.DEFAULT_VALUES
	_expect(defaults.has("defeat_continue_revival_beat_active"), "BattleSceneState schema should declare revival beat active")
	_expect(defaults.has("defeat_continue_revival_beat_phase"), "BattleSceneState schema should declare revival beat phase")
	_expect(defaults.has("defeat_continue_revival_beat_elapsed"), "BattleSceneState schema should declare revival beat elapsed")
	_expect(defaults.has("defeat_continue_revival_beat_full_pose"), "BattleSceneState schema should declare revival beat full-pose flag")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_core_module_catalog.gd")
	var scene_deps_source := FileAccess.get_file_as_string("res://scripts/core/battle_draw_scene_context.gd")
	var actor_context_source := FileAccess.get_file_as_string("res://scripts/core/battle_draw_actor_context.gd")
	var continue_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	var glow_source := FileAccess.get_file_as_string("res://scripts/effects/player_state_glow_renderer.gd")
	var beat_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_revival_beat_state.gd")
	_expect(catalog_source.find("defeat_continue_revival_beat_state") >= 0, "module catalog should expose the revival beat state")
	_expect(scene_deps_source.find("defeat_continue_revival_beat_state") >= 0, "draw scene deps should pass the revival beat state to actor context")
	_expect(actor_context_source.find("revival_result_context") >= 0 and actor_context_source.find("combined_result_context") >= 0, "actor context should merge revival pose context into result texture sync")
	_expect(continue_source.find("_start_continue_revival_beat") >= 0, "continue screen should start revival beat after reset_for_continue")
	_expect(continue_source.find("_is_continue_revival_beat_active") >= 0, "continue screen should keep physics blocked while revival beat is active")
	_expect(glow_source.find("STATE_ABSORB") >= 0 and glow_source.find("player_continue_absorb_glow_ratio") >= 0, "player glow renderer should allow absorb glow during defeat pose")
	_expect(beat_source.find("WALL_CLOCK_FAILSAFE_GRACE_SEC") >= 0 and beat_source.find("force_wall_clock_timeout_for_tests") >= 0, "revival beat should have a wall-clock failsafe for starved update clocks")
	_expect(beat_source.find("_draw_sacred_revival_overlay") >= 0 and beat_source.find("SACRED_RAY_COUNT") >= 0, "revival beat should own the foreground sacred revival overlay")
	_expect(beat_source.find("get_sacred_overlay_status") >= 0 and beat_source.find("_get_sacred_warm_ratio") >= 0, "sacred overlay should expose cold-to-gold beat-clock envelopes")
	_expect(beat_source.find("get_color_restore_status") >= 0 and beat_source.find("_get_color_restore_max_radius") >= 0, "revival beat should expose beat-clock color restore postprocess envelopes")
	_expect(beat_source.find("desaturate_amount") >= 0 and beat_source.find("restore_radius_px") >= 0, "color restore status should expose grayscale and radial restore parameters")
	_expect(beat_source.find("draw_colored_polygon") < 0, "revival beat should avoid animated filled polygon geometry")
	_expect(continue_source.find("_animate_backdrop_rect") < 0 and continue_source.find("_draw_portal_breath") < 0, "S-CC3 should not reanimate the static defeat backdrop")
	_expect(continue_source.find("draw_set_transform") < 0, "S-CC3 continue screen path should not add transform-reset drawing")
	_expect(beat_source.find("draw_set_transform") < 0, "S-CC4 sacred overlay should not use transform-reset drawing")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _max_corner_distance(center: Vector2, view_size: Vector2) -> float:
	var corners := [
		Vector2.ZERO,
		Vector2(view_size.x, 0.0),
		Vector2(0.0, view_size.y),
		view_size,
	]
	var max_distance := 0.0
	for corner in corners:
		max_distance = maxf(max_distance, center.distance_to(corner))
	return max_distance


func _expected_color_restore_feather(view_size: Vector2) -> float:
	return maxf(
		DefeatContinueRevivalBeatState.COLOR_RESTORE_FEATHER_MIN,
		minf(view_size.x, view_size.y) * DefeatContinueRevivalBeatState.COLOR_RESTORE_FEATHER_RATIO
	)
