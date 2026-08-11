extends SceneTree

# expect-zero-object-leaks

const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StoryCinematicProgressStore := preload("res://scripts/core/story_cinematic_progress_store.gd")
const BattleSceneIntroFrameController := preload("res://scripts/core/battle_scene_intro_frame_controller.gd")
const PrologueText := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_text.gd")
const ProloguePresentation := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd")
const PrologueOverlayHost := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd")


class FakeOwner extends Node2D:
	var current_stage := 1
	var selected_runtime_character_id := "smasher"
	var selected_character_type := "smasher"


class FakeReadiness extends RefCounted:
	func is_boot_warmup_finished(_module_getter: Callable) -> bool:
		return true


class FakeLoadingCompletionHold extends RefCounted:
	var hold_calls := 0

	func should_hold_completion(_owner: Object, _module_getter: Callable) -> bool:
		hold_calls += 1
		return true


class FakeLivePrologue extends RefCounted:
	var active := true
	var complete_on_update := false
	var update_calls := 0

	func is_active() -> bool:
		return active

	func update(_delta: float, _owner: Object, _registry: Object) -> void:
		update_calls += 1
		if complete_on_update:
			active = false


class FakeAudio extends RefCounted:
	var opening_drum_calls := 0
	var rays_calls := 0
	var spirit_bell_calls := 0
	var stop_cue_calls := 0
	var gain_values: Array[float] = []
	var clear_gain_calls := 0

	func play_han_miryang_prologue_opening_drum() -> void:
		opening_drum_calls += 1

	func play_han_miryang_prologue_rays() -> void:
		rays_calls += 1

	func play_han_miryang_prologue_spirit_bell() -> void:
		spirit_bell_calls += 1

	func stop_han_miryang_prologue_cues() -> void:
		stop_cue_calls += 1

	func set_story_cinematic_bgm_gain_db(value: float) -> float:
		gain_values.append(value)
		return value

	func clear_story_cinematic_bgm_gain() -> void:
		clear_gain_calls += 1


class FakeRegistry extends RefCounted:
	var audio: Object = null

	func get_instance(key: String) -> Object:
		return audio if key == "game_audio" else null


var _failures: Array[String] = []
var _frame_modules: Dictionary = {}
var _frame_landing_started := false
var _frame_begin_landing_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_eligibility_contract()
	_verify_transient_entry_request()
	_verify_seven_locale_copy()
	_verify_runtime_integration_routes()
	_verify_asset_contract_gate()
	_verify_real_audio_transient_gain_contract()
	_verify_discarded_threaded_texture_contract()
	_verify_threaded_owner_ignores_cache_shortcuts()
	_verify_live_intro_frame_advances_before_loading_hold()
	_verify_progress_roundtrip_and_bom_rewrite()
	_verify_startup_asset_failure_releases_gate()
	_verify_repeat_skip_discards_cold_stream()
	_verify_delayed_stream_preserves_fallback()
	_verify_character_select_replay_timeline_and_completion_history()

	if _failures.is_empty():
		print("stage1_han_miryang_prologue_smoke: ok")
		call_deferred("_quit_after_fixture_teardown", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("_quit_after_fixture_teardown", 1)


func _quit_after_fixture_teardown(exit_code: int) -> void:
	# Give queued host frees one idle turn before the zero-leak exit gate runs.
	quit(exit_code)


func _verify_eligibility_contract() -> void:
	_expect(ProloguePresentation.is_entry_eligible(1, "smasher", true, false), "Han Miryang Stage 1 requested unseen entry should be eligible")
	_expect(not ProloguePresentation.is_entry_eligible(2, "smasher", true, false), "later stages should not open the prologue")
	_expect(not ProloguePresentation.is_entry_eligible(1, "viper", true, false), "other characters should not open Han Miryang's prologue")
	_expect(not ProloguePresentation.is_entry_eligible(1, "smasher", false, false), "direct battle launch without a character-select request should not open the prologue")
	_expect(ProloguePresentation.is_entry_eligible(1, "smasher", true, true), "character-select confirmation should replay even after prior viewing")


func _verify_transient_entry_request() -> void:
	var selection := GameSelectionState.new()
	_expect(not selection.peek_character_prologue_entry_request(), "new selection state should not arm a story entry")
	selection.request_character_prologue_entry()
	_expect(selection.peek_character_prologue_entry_request(), "character selection should arm one story entry")
	_expect(selection.consume_character_prologue_entry_request(), "armed story entry should be consumed once")
	_expect(not selection.consume_character_prologue_entry_request(), "story entry request should not replay without another confirmation")
	selection.free()


func _verify_seven_locale_copy() -> void:
	var locales := PrologueText.get_supported_locales()
	_expect(locales.size() == 7, "prologue should provide all seven supported locales")
	for locale in locales:
		var copy := PrologueText.get_copy(locale)
		var segments := PrologueText.get_segments(locale)
		var elapsed_segments := PrologueText.get_elapsed_segments(locale)
		_expect(str(copy.get("title", "")) != "", "%s title should not be empty" % locale)
		_expect(str(copy.get("chapter", "")) != "", "%s chapter should not be empty" % locale)
		_expect(str(copy.get("skip", "")) != "", "%s skip hint should not be empty" % locale)
		_expect(segments.size() == 9, "%s should have the nine approved dialogue beats" % locale)
		_expect(elapsed_segments.size() == 2, "%s should have two sequential elapsed-time cards" % locale)
		for segment_value in segments:
			var segment: Dictionary = segment_value if segment_value is Dictionary else {}
			_expect(float(segment.get("end", 0.0)) > float(segment.get("start", 0.0)), "%s segment timing should advance" % locale)
			_expect(str(segment.get("text", "")) != "", "%s dialogue should not be empty" % locale)
			_expect(not segment.has("voice_id") or segment.get("voice_id") is String, "%s optional voice_id should remain schema-compatible" % locale)
			_verify_cps(locale, str(segment.get("text", "")), float(segment.get("end", 0.0)) - float(segment.get("start", 0.0)), "dialogue")
		for elapsed_value in elapsed_segments:
			var elapsed_segment: Dictionary = elapsed_value if elapsed_value is Dictionary else {}
			_verify_cps(locale, str(elapsed_segment.get("text", "")), float(elapsed_segment.get("end", 0.0)) - float(elapsed_segment.get("start", 0.0)), "elapsed card")
		_verify_cps(locale, str(copy.get("chapter", "")), 2.5, "chapter card")
	_expect(str(PrologueText.get_copy("zh").get("chapter", "")) == "第一章 — 女王体内之物", "Chinese chapter copy should use the approved natural phrasing")
	var zh_last: Dictionary = PrologueText.get_segments("zh")[8]
	_expect(str(zh_last.get("text", "")).find("环击战") >= 0, "Chinese title term should use 环击战, never the generic counterattack spelling")


func _verify_cps(locale: String, text: String, duration: float, row_name: String) -> void:
	var limit := 12.0 if locale in ["ko", "ja", "zh"] else 22.0
	var cps := text.length() / maxf(duration, 0.001)
	_expect(cps <= limit + 0.001, "%s %s exceeds %.0f CPS: %.2f" % [locale, row_name, limit, cps])


func _verify_runtime_integration_routes() -> void:
	var catalog := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	var character_select := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	var intro_lifecycle := FileAccess.get_file_as_string("res://scripts/core/battle_scene_stage_intro_flow_lifecycle.gd")
	var intro_frame := FileAccess.get_file_as_string("res://scripts/core/battle_scene_intro_frame_controller.gd")
	var input_router := FileAccess.get_file_as_string("res://scripts/core/battle_pre_intro_stage_input_router.gd")
	var boot_prewarm := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var entry_prewarm := FileAccess.get_file_as_string("res://scripts/ui/battle_entry_background_prewarm.gd")
	var teardown := FileAccess.get_file_as_string("res://scripts/core/battle_scene_teardown_lifecycle.gd")
	var battle_shell := FileAccess.get_file_as_string("res://scripts/core/battle_scene_shell.gd")
	var game_audio := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	var presentation := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd")
	_expect(catalog.find("stage1_han_miryang_prologue_presentation") >= 0, "stage module catalog should register the prologue presentation")
	_expect(character_select.find("request_character_prologue_entry") >= 0, "character confirmation should arm the prologue entry")
	_expect(intro_lifecycle.find("han_miryang_prologue.begin") >= 0, "stage intro lifecycle should begin the prologue")
	_expect(intro_lifecycle.find("start_battle_bgm(flow, owner, module_getter)") >= 0, "prologue entry should preserve the battle BGM handoff")
	_expect(intro_frame.find("han_miryang_prologue.update") >= 0, "intro frame controller should advance the prologue")
	var prologue_input_index := input_router.find("_handle_han_miryang_prologue_input")
	var force_clear_index := input_router.find("_handle_force_stage_clear_shortcut")
	_expect(prologue_input_index >= 0 and force_clear_index > prologue_input_index, "prologue input gate should run before battle shortcuts")
	_expect(boot_prewarm.find("prewarm_stage_entry_step(owner)") >= 0, "battle boot should prewarm the prologue before first display")
	_expect(entry_prewarm.find("HanMiryangPrologue.get_texture_paths") >= 0, "character-select idle prewarm should include only the three A-family plates")
	_expect(entry_prewarm.find("has_seen(HanMiryangPrologue.CINEMATIC_ID)") < 0, "repeat-view policy should not suppress menu-idle story prewarm")
	_expect(teardown.find("stage1_han_miryang_prologue_presentation") >= 0, "battle teardown should release the detached prologue host")
	_expect(battle_shell.find("poll_detached_threaded_texture_results()") >= 0, "battle frames should nonblockingly collect detached ResourceLoader results")
	_expect(game_audio.find("play_han_miryang_prologue_opening_drum") >= 0, "opening ritual strike should route through GameAudio")
	_expect(game_audio.find("play_han_miryang_prologue_rays") >= 0, "eight-ray layer should route through GameAudio")
	_expect(game_audio.find("play_han_miryang_prologue_spirit_bell") >= 0, "first spirit extraction bell should route through GameAudio")
	_expect(game_audio.find("set_story_cinematic_bgm_gain_db") >= 0, "story BGM gap should route through the shared audio facade")
	_expect(game_audio.find("clear_story_cinematic_bgm_gain") >= 0, "story BGM gap should expose an explicit transient-gain reset")
	_expect(presentation.find("set_bgm_volume") < 0, "story BGM gap must not rewrite the user's saved BGM volume")
	_expect(ProloguePresentation.get_texture_paths().size() == 4, "startup prewarm must contain A1/A2/A3 plus the cropped tablet reveal")
	_expect(ProloguePresentation.get_all_texture_paths().size() == 12, "the complete cinematic should declare eight plates plus four cropped FX layers")
	for texture_path in ProloguePresentation.get_all_texture_paths():
		_expect(str(texture_path).contains("/araul_prologue_v3_"), "every runtime story texture should use the accepted V3 art family: %s" % texture_path)
		_expect(not str(texture_path).contains("_v2_"), "no retired V2 plate should remain in the runtime declaration: %s" % texture_path)
	var request_times: Array[float] = []
	var deadlines: Array[float] = []
	for spec_value in ProloguePresentation.STREAM_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		request_times.append(float(spec.get("request_at", -1.0)))
		deadlines.append(float(spec.get("deadline", -1.0)))
	_expect(request_times == [0.0, 12.6, 12.6, 16.2, 16.2, 19.6, 23.6, 26.25], "live bases and their FX should open only at the approved family request windows; shard waits for the orb release slot")
	_expect(deadlines == [12.0, 20.0, 20.0, 22.0, 22.0, 27.0, 30.0, 30.0], "each live base/FX texture should retain its approved no-sync deadline")
	_expect(is_equal_approx(ProloguePresentation.RAYS_CUE_SECONDS, 26.15), "the rays cue should move to the flash onset")
	_expect(is_equal_approx(PrologueOverlayHost.B2_TO_C1_CUT, 26.25), "B2-to-C1 should be a hard cut under the flash peak")
	_expect(not ProloguePresentation.LIVE_STREAM_ALLOW_SYNC_FALLBACK, "live streaming should opt out of synchronous fallback")
	_expect(presentation.count("LIVE_STREAM_ALLOW_SYNC_FALLBACK") == 2, "the no-sync constant should be declared once and consumed by the live stream call")
	var resource_loader := FileAccess.get_file_as_string("res://scripts/resources/project_resource_loader.gd")
	_expect(resource_loader.find("allow_sync_fallback") >= 0 and resource_loader.find("fallback_blocked") >= 0, "resource loader should expose a no-sync-fallback live path")
	_expect(resource_loader.find("discard_threaded_texture_result") >= 0, "live story teardown should discard late threaded texture results")
	_expect(presentation.find("ProjectResourceLoader.discard_threaded_texture_result(path)") >= 0, "prologue plate release should detach in-flight ownership without caching")
	_expect(presentation.find("_startup_prewarm_index = 0") < 0, "terminal startup failures must not rewind into an infinite loading loop")


func _verify_asset_contract_gate() -> void:
	_run_asset_validator(
		"res://../tools/validate_araul_prologue_asset_contract.ps1",
		"araul_prologue_asset_contract: PASS"
	)
	_run_asset_validator(
		"res://../tools/validate_araul_prologue_rev6_fx_contract.ps1",
		"araul_prologue_rev6_fx_contract: PASS"
	)


func _run_asset_validator(script_resource_path: String, completion_marker: String) -> void:
	var output: Array = []
	var script_path := ProjectSettings.globalize_path(script_resource_path)
	var exit_code := OS.execute(
		"powershell.exe",
		["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_path],
		output,
		true
	)
	var joined_output := "\n".join(PackedStringArray(output))
	_expect(exit_code == 0, "prologue asset contract validator failed: %s" % joined_output)
	_expect(joined_output.find(completion_marker) >= 0, "prologue asset validator must emit its completion marker: %s" % completion_marker)


func _verify_real_audio_transient_gain_contract() -> void:
	var audio := GameAudio.new()
	var user_volume := audio.get_bgm_volume()
	_expect(is_equal_approx(audio.set_story_cinematic_bgm_gain_db(-200.0), -80.0), "story BGM gain should clamp to the silent floor")
	_expect(is_equal_approx(audio.get_story_cinematic_bgm_gain_db(), -80.0), "story BGM gain getter should expose the transient value")
	_expect(is_equal_approx(audio.get_bgm_volume(), user_volume), "story BGM gain must preserve the user's saved BGM volume")
	audio.clear_story_cinematic_bgm_gain()
	_expect(is_zero_approx(audio.get_story_cinematic_bgm_gain_db()), "story BGM gain reset should restore neutral gain")
	var gong := AudioStreamPlayer.new()
	var rays := AudioStreamPlayer.new()
	var bell := AudioStreamPlayer.new()
	audio.han_miryang_prologue_opening_drum_sfx = gong
	audio.han_miryang_prologue_rays_sfx = rays
	audio.stage2_speed_defense_block_sfx = bell
	for player: AudioStreamPlayer in [gong, rays, bell]:
		player.pitch_scale = 0.72
	audio.stop_han_miryang_prologue_cues()
	_expect(is_equal_approx(gong.pitch_scale, 1.0), "prologue cleanup should restore the dedicated opening-drum pitch")
	_expect(is_equal_approx(rays.pitch_scale, 1.0) and is_equal_approx(bell.pitch_scale, 1.0), "prologue cleanup should restore every cue pitch")
	for player: AudioStreamPlayer in [gong, rays, bell]:
		player.free()


func _verify_discarded_threaded_texture_contract() -> void:
	var path := ProloguePresentation.B1_TEXTURE_PATH
	ProjectResourceLoader.force_threaded_texture_prewarm_in_progress_for_tests(path)
	ProjectResourceLoader.discard_threaded_texture_result(path)
	_expect(ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests() == "", "discard must detach an in-flight live plate from the shared slot immediately")
	_expect(ProjectResourceLoader.is_threaded_texture_detached_for_tests(path), "discarded owner should remain observable only in the nonblocking terminal-result collector")
	_expect(ProjectResourceLoader.get_cached_texture(path) == null, "discarded live plates must leave no explicit cache reference")
	ProjectResourceLoader.poll_detached_threaded_texture_results()
	_expect(not ProjectResourceLoader.is_threaded_texture_detached_for_tests(path), "an invalid simulated worker should leave the detached collector without blocking")
	ProjectResourceLoader.force_threaded_texture_prewarm_in_progress_for_tests(ProloguePresentation.C1_TEXTURE_PATH)
	_expect(ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests() == ProloguePresentation.C1_TEXTURE_PATH, "the detached slot must be reusable without waiting for the abandoned worker")
	ProjectResourceLoader.discard_threaded_texture_result(ProloguePresentation.C1_TEXTURE_PATH)
	ProjectResourceLoader.poll_detached_threaded_texture_results()


func _verify_threaded_owner_ignores_cache_shortcuts() -> void:
	var path := ProloguePresentation.B2_TEXTURE_PATH
	var cached_owner_texture := ProjectResourceLoader.load_imported_texture(path)
	_expect(cached_owner_texture is Texture2D, "owner-cache reverse fixture should decode B2")
	if not (cached_owner_texture is Texture2D):
		return
	ProjectResourceLoader.force_threaded_texture_prewarm_in_progress_for_tests(path)
	ProjectResourceLoader.store_texture(path, cached_owner_texture)
	ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"",
		"",
		5000,
		600,
		false,
		true,
		false
	)
	_expect(ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests() == "", "a current threaded owner must close its terminal slot instead of returning either cached texture shortcut")
	ProjectResourceLoader.evict_cached_texture(path)
	cached_owner_texture = null


func _verify_live_intro_frame_advances_before_loading_hold() -> void:
	var frame := BattleSceneIntroFrameController.new()
	var owner := FakeOwner.new()
	var prologue := FakeLivePrologue.new()
	var loading_hold := FakeLoadingCompletionHold.new()
	_frame_modules = {
		"battle_scene_readiness_controller": FakeReadiness.new(),
		"battle_loading_screen_renderer": loading_hold,
		"stage1_han_miryang_prologue_presentation": prologue,
	}
	_frame_landing_started = false
	_frame_begin_landing_calls = 0
	var callbacks := {
		"is_stage_landing_intro_started": Callable(self, "_is_frame_landing_started"),
		"is_battle_initialized": Callable(self, "_is_frame_battle_initialized"),
		"begin_stage_landing_intro": Callable(self, "_begin_frame_landing_intro"),
	}
	var blocked := frame.process_idle(
		0.25,
		owner,
		null,
		Callable(self, "_get_frame_module"),
		callbacks
	)
	_expect(blocked, "active live prologue should keep the battle intro blocked")
	_expect(prologue.update_calls == 1, "active live prologue should advance even when loading completion wants to hold")
	_expect(loading_hold.hold_calls == 0, "loading completion must not reset its timer over an active prologue")

	prologue.complete_on_update = true
	frame.process_idle(
		0.25,
		owner,
		null,
		Callable(self, "_get_frame_module"),
		callbacks
	)
	_expect(prologue.update_calls == 2, "live prologue should receive its completion frame")
	_expect(_frame_begin_landing_calls == 1, "completed prologue should hand off to the landing intro in the same frame")
	_expect(loading_hold.hold_calls == 0, "completed prologue handoff should not resurrect the loading completion gate")
	_frame_modules = {}
	owner.free()


func _get_frame_module(key: String) -> Object:
	var value: Variant = _frame_modules.get(key, null)
	return value as Object if typeof(value) == TYPE_OBJECT else null


func _is_frame_landing_started() -> bool:
	return _frame_landing_started


func _is_frame_battle_initialized() -> bool:
	return true


func _begin_frame_landing_intro() -> void:
	_frame_landing_started = true
	_frame_begin_landing_calls += 1


func _verify_progress_roundtrip_and_bom_rewrite() -> void:
	var path := _test_path("progress")
	_cleanup(path)
	var store := StoryCinematicProgressStore.new()
	store.set_save_path(path)
	_expect(not store.has_seen(ProloguePresentation.CINEMATIC_ID), "fresh progress should be unseen")
	_expect(store.mark_seen(ProloguePresentation.CINEMATIC_ID), "mark_seen should persist the cinematic")
	var loaded := StoryCinematicProgressStore.new()
	loaded.set_save_path(path)
	_expect(loaded.has_seen(ProloguePresentation.CINEMATIC_ID), "seen cinematic should survive a new store instance")
	var original_bytes := FileAccess.get_file_as_bytes(path)
	var with_bom := PackedByteArray([0xEF, 0xBB, 0xBF])
	with_bom.append_array(original_bytes)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(with_bom)
		file.close()
	var bom_loaded := StoryCinematicProgressStore.new()
	bom_loaded.set_save_path(path)
	_expect(bom_loaded.has_seen(ProloguePresentation.CINEMATIC_ID), "BOM-prefixed progress should still parse")
	_expect(not _file_starts_with_bom(path), "BOM-prefixed progress should be rewritten without BOM")
	_cleanup(path)


func _verify_startup_asset_failure_releases_gate() -> void:
	var owner := FakeOwner.new()
	root.add_child(owner)
	var presentation := ProloguePresentation.new()
	presentation.set_entry_request_override_for_test(true)
	var startup_fixture := {
		PrologueOverlayHost.PLATE_A1: ProjectResourceLoader.load_imported_texture(ProloguePresentation.A1_TEXTURE_PATH),
		PrologueOverlayHost.PLATE_A2: ProjectResourceLoader.load_imported_texture(ProloguePresentation.A2_TEXTURE_PATH),
		PrologueOverlayHost.PLATE_A3: ProjectResourceLoader.load_imported_texture(ProloguePresentation.A3_TEXTURE_PATH),
		PrologueOverlayHost.FX_TABLET: ProjectResourceLoader.load_imported_texture(ProloguePresentation.FX_TABLET_TEXTURE_PATH),
	}
	_expect(startup_fixture.values().all(func(value: Variant) -> bool: return value is Texture2D), "startup failure fixture should decode the three A-family plates and tablet FX")
	presentation.seed_startup_textures_for_test(startup_fixture)
	_expect(presentation.prewarm_runtime_nodes_step(owner), "startup failure fixture should prebuild its fullscreen host")
	presentation.remove_startup_texture_for_test(PrologueOverlayHost.PLATE_A2)
	_expect(presentation.prewarm_assets_step(), "a terminal missing startup plate should finish prewarm instead of rewinding forever")
	_expect(not presentation.begin(owner, null), "a missing startup plate should decline the prologue and release battle entry")
	_expect(presentation.get_completion_reason() == "asset_unavailable", "startup failure should expose the asset_unavailable completion reason")
	_expect(not presentation.is_active(), "startup asset failure must not leave a loading/input gate active")
	_expect(presentation.get_host_for_test() == null, "startup asset failure must release its prebuilt fullscreen host")
	_expect((presentation.get_asset_status().get("startup_ready", {}) as Dictionary).is_empty(), "startup asset failure must release every successfully loaded A-family plate")
	for path_value in ProloguePresentation.get_texture_paths():
		_expect(ProjectResourceLoader.get_cached_texture(str(path_value)) == null, "startup asset failure must evict its A-family project-cache references")
	presentation.tear_down()
	startup_fixture.clear()
	presentation = null
	owner.free()
	owner = null


func _verify_repeat_skip_discards_cold_stream() -> void:
	var path := _test_path("cold_repeat_skip")
	_cleanup(path)
	ProjectResourceLoader.clear_caches()
	var deterministic_fixture := _build_headless_texture_fixture()
	var store := StoryCinematicProgressStore.new()
	store.set_save_path(path)
	_expect(store.mark_seen(ProloguePresentation.CINEMATIC_ID), "cold repeat-skip fixture should begin as previously viewed")
	var owner := FakeOwner.new()
	root.add_child(owner)
	var presentation := ProloguePresentation.new()
	presentation.set_progress_path_for_test(path)
	presentation.set_entry_request_override_for_test(true)
	_seed_headless_texture_fixture(presentation, deterministic_fixture)
	var guard := 0
	while not presentation.prewarm_stage_entry_step(owner) and guard < 240:
		guard += 1
		OS.delay_msec(1)
	_expect(guard < 240, "cold repeat-skip fixture should prewarm A family")
	ProjectResourceLoader.evict_cached_texture(ProloguePresentation.B1_TEXTURE_PATH)
	_expect(presentation.begin(owner, null), "previously viewed prologue should begin the cold repeat-skip fixture")
	_expect(is_zero_approx(presentation.get_skip_lock_seconds()), "previously viewed prologue should allow first-frame skip")
	if _is_headless_runtime():
		var headless_status: Dictionary = presentation.get_asset_status()
		_expect(int(headless_status.get("stream_completed_count", 0)) == 1, "headless repeat-skip should materialize only due B1 on its first frame")
		_expect(int(headless_status.get("resident_count", 0)) == 4, "headless first frame should own only A1/A2/A3/B1")
		_expect(int(headless_status.get("resident_peak", 0)) == 4, "headless staged fixture should seal the four-plate logical peak")
		_expect(int(headless_status.get("fx_resident_count", 0)) == 1, "headless first frame should retain only the tablet reveal FX")
		_expect(int(headless_status.get("total_resident_peak", 0)) == 5, "headless first frame should own four bases plus one cropped FX layer")
	else:
		_expect(ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests() == ProloguePresentation.B1_TEXTURE_PATH, "cold repeat begin should own a threaded B1 request")
	var skip_event := InputEventKey.new()
	skip_event.pressed = true
	skip_event.keycode = KEY_SPACE
	_expect(presentation.handle_input(skip_event, owner, null), "cold repeat fixture should accept first-frame Space")
	presentation.update(ProloguePresentation.SKIP_FADE_SECONDS + 0.05, owner, null)
	_expect(ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests() == "", "first-frame skip must leave no shared threaded owner")
	_expect(ProjectResourceLoader.get_cached_texture(ProloguePresentation.B1_TEXTURE_PATH) == null, "skipped B1 must leave no explicit cache reference")
	if not _is_headless_runtime():
		_expect(ProjectResourceLoader.is_threaded_texture_detached_for_tests(ProloguePresentation.B1_TEXTURE_PATH), "first-frame skip should route B1 to the detached result collector")
		var detached_guard := 0
		while ProjectResourceLoader.is_threaded_texture_detached_for_tests(ProloguePresentation.B1_TEXTURE_PATH) and detached_guard < 240:
			ProjectResourceLoader.poll_detached_threaded_texture_results()
			detached_guard += 1
			OS.delay_msec(1)
		_expect(detached_guard < 240, "detached B1 should reach a terminal state without occupying the shared slot")
	_expect(ProjectResourceLoader.get_cached_texture(ProloguePresentation.B1_TEXTURE_PATH) == null, "collected skipped B1 must not re-enter the explicit cache")
	presentation.tear_down()
	presentation = null
	store = null
	deterministic_fixture.clear()
	owner.free()
	owner = null
	_cleanup(path)


func _verify_delayed_stream_preserves_fallback() -> void:
	if not _is_headless_runtime():
		return
	var path := _test_path("delayed_stream")
	_cleanup(path)
	var owner := FakeOwner.new()
	root.add_child(owner)
	var fixture := _build_headless_texture_fixture()
	var presentation := ProloguePresentation.new()
	presentation.set_progress_path_for_test(path)
	presentation.set_entry_request_override_for_test(true)
	presentation.seed_startup_textures_for_test(fixture.get("startup", {}))
	presentation.set_stream_texture_factory_for_test(Callable(self, "_make_delayed_stream_texture_for_test"))
	_expect(presentation.prewarm_runtime_nodes_step(owner), "delayed stream fixture should prebuild its host")
	_expect(presentation.begin(owner, null), "delayed stream fixture should begin")
	_advance_presentation_to(presentation, 19.7, owner, null)
	var delayed_status: Dictionary = presentation.get_asset_status()
	var delayed_misses: Dictionary = delayed_status.get("deadline_misses", {})
	var delayed_host := presentation.get_host_for_test()
	_expect(delayed_misses.size() == 1 and delayed_misses.has(PrologueOverlayHost.PLATE_B1), "only delayed B1 should miss its deadline")
	_expect(int(delayed_status.get("stream_completed_count", 0)) == 0, "a nonterminal B1 must block later sequential requests")
	_expect(int(delayed_status.get("resident_count", 0)) == 1, "A3 should be the sole fallback after the first two blends finish")
	if delayed_host != null:
		var delayed_ready: Dictionary = delayed_host.get_snapshot().get("plate_ready", {})
		_expect(bool(delayed_ready.get("a3", false)) and not bool(delayed_ready.get("b1", false)), "late B1 must keep A3 visible instead of producing a black frame")
	_advance_presentation_to(presentation, 20.1, owner, null)
	var recovered_status: Dictionary = presentation.get_asset_status()
	_expect(int(recovered_status.get("stream_completed_count", 0)) == 6, "one catch-up update should materialize every due base/FX texture through D1")
	_expect(int(recovered_status.get("resident_count", 0)) == 4, "late recovery should still respect the four-plate resident ceiling")
	_expect(int(recovered_status.get("resident_peak", 0)) <= 4, "late recovery must never create a transient fifth resident plate")
	_expect(int(recovered_status.get("fx_resident_count", 0)) == 2 and int(recovered_status.get("fx_resident_peak", 0)) <= 2, "late recovery should keep at most the orb and ray FX resident together")
	_expect(int(recovered_status.get("total_resident_peak", 0)) <= 6, "late recovery should keep the combined base-plus-FX resident peak at six")
	_expect((recovered_status.get("deadline_misses", {}) as Dictionary).size() == 1, "late recovery should retain only B1's diagnostic miss")
	if delayed_host != null:
		var recovered_ready: Dictionary = delayed_host.get_snapshot().get("plate_ready", {})
		_expect(not bool(recovered_ready.get("a3", true)) and bool(recovered_ready.get("b1", false)), "late B1 readiness should release the obsolete A3 fallback")
	presentation.tear_down()
	delayed_host = null
	presentation = null
	fixture.clear()
	owner.free()
	owner = null
	_cleanup(path)


func _verify_character_select_replay_timeline_and_completion_history() -> void:
	var path := _test_path("presentation")
	_cleanup(path)
	ProjectResourceLoader.clear_caches()
	for texture_path in ProloguePresentation.get_all_texture_paths():
		var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
		_expect(image != null and not image.is_empty(), "prologue texture source should decode: %s" % texture_path)
		if image != null and not image.is_empty():
			if texture_path in [
				ProloguePresentation.A1_TEXTURE_PATH,
				ProloguePresentation.A2_TEXTURE_PATH,
				ProloguePresentation.A3_TEXTURE_PATH,
				ProloguePresentation.B1_TEXTURE_PATH,
				ProloguePresentation.B2_TEXTURE_PATH,
				ProloguePresentation.C1_TEXTURE_PATH,
				ProloguePresentation.D1_TEXTURE_PATH,
				ProloguePresentation.D2_TEXTURE_PATH,
			]:
				_expect(image.get_size() == Vector2i(3344, 1882), "prologue plate should use the accepted 2x cinematic resolution: %s" % texture_path)
			else:
				_expect(image.get_width() < 3344 or image.get_height() < 1882, "rev6 FX should remain bbox-cropped instead of duplicating a fullscreen plate: %s" % texture_path)
	var deterministic_fixture := _build_headless_texture_fixture()

	var owner := FakeOwner.new()
	root.add_child(owner)
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.audio = audio
	var presentation := ProloguePresentation.new()
	presentation.set_progress_path_for_test(path)
	presentation.set_entry_request_override_for_test(true)
	_seed_headless_texture_fixture(presentation, deterministic_fixture)
	var guard := 0
	while not presentation.prewarm_stage_entry_step(owner) and guard < 240:
		guard += 1
		OS.delay_msec(1)
	_expect(guard < 240, "A-family assets and host should prewarm within the bounded smoke loop")
	_expect(presentation.begin(owner, registry), "character-selected Han Miryang entry should begin the prologue")
	_expect(presentation.is_active(), "begun prologue should block the battle")
	_expect(audio.opening_drum_calls == 1, "the prologue should open with one ceremonial strike")
	_expect(is_equal_approx(presentation.get_skip_lock_seconds(), ProloguePresentation.FIRST_VIEW_SKIP_LOCK_SECONDS), "first viewing should protect the opening input for 1.2 seconds")
	var host := presentation.get_host_for_test()
	_expect(host != null, "prologue should attach a viewport overlay host")
	if host != null:
		var start_snapshot: Dictionary = host.get_snapshot()
		_expect(bool(start_snapshot.get("visible", false)), "prologue host should be visible")
		_expect(not bool(start_snapshot.get("process_enabled", true)), "prologue host should remain controller-driven")
		var plate_ready: Dictionary = start_snapshot.get("plate_ready", {})
		_expect(bool(plate_ready.get("a1", false)), "A1 should be bound before playback")
		_expect(bool(plate_ready.get("a2", false)), "A2 should be bound before playback")
		_expect(bool(plate_ready.get("a3", false)), "A3 should be bound before playback")
		_expect(bool(plate_ready.get("fx_tablet", false)), "the cropped tablet reveal should be bound before playback")
		_expect(bool(plate_ready.get("b1", false)), "only due B1 should materialize beside the startup family")
		_expect(not bool(plate_ready.get("b2", false)), "future B2 must not materialize before its 12.6-second request gate")
		_expect(not bool(start_snapshot.get("skip_allowed", true)), "first frame should hide the skip affordance during the first-view lock")
	var start_asset_status: Dictionary = presentation.get_asset_status()
	_expect(int(start_asset_status.get("resident_count", 0)) == 4, "playback should begin with exactly four logical resident plates")
	_expect(int(start_asset_status.get("resident_peak", 0)) == 4, "first-frame B1 materialization should establish, not exceed, the four-plate peak")
	_expect(int(start_asset_status.get("fx_resident_count", 0)) == 1, "playback should begin with one cropped tablet FX layer")
	_expect(int(start_asset_status.get("total_resident_peak", 0)) == 5, "playback should begin with four bases plus one cropped FX layer")

	var skip_event := InputEventKey.new()
	skip_event.pressed = true
	skip_event.keycode = KEY_SPACE
	_expect(not presentation.handle_input(skip_event, owner, registry), "first-frame Space should not accidentally skip an unseen prologue")
	presentation.update(ProloguePresentation.FIRST_VIEW_SKIP_LOCK_SECONDS + 0.01, owner, registry)
	_expect(presentation.handle_input(skip_event, owner, registry), "Space should unlock after the first-view guard")
	# Return to a clean active fixture for timeline/audio verification.
	presentation.tear_down()
	presentation = ProloguePresentation.new()
	presentation.set_progress_path_for_test(path)
	_cleanup(path)
	presentation.set_entry_request_override_for_test(true)
	_seed_headless_texture_fixture(presentation, deterministic_fixture)
	guard = 0
	while not presentation.prewarm_stage_entry_step(owner) and guard < 240:
		guard += 1
		OS.delay_msec(1)
	_expect(presentation.begin(owner, registry), "fresh first-view fixture should restart after the input-lock leg")
	host = presentation.get_host_for_test()
	var a_camera_start := float(host.get_snapshot().get("camera_source_width_ratio", 0.0)) if host != null else 0.0
	_advance_presentation_to(presentation, 11.40, owner, registry)
	if host != null:
		var tablet_snapshot: Dictionary = host.get_snapshot()
		_expect(str(tablet_snapshot.get("base_plate_key", "")) == PrologueOverlayHost.PLATE_A1, "tablet wipe should keep A1 as its base until the reveal completes")
		_expect(float(tablet_snapshot.get("flash_alpha", -1.0)) == 0.0, "tablet wipe should not leak the later flash state")
	_advance_presentation_to(presentation, 12.54, owner, registry)
	_expect(not audio.gain_values.is_empty() and audio.gain_values.min() <= -9.9, "tablet reveal should apply the first BGM duck stage")
	_advance_presentation_to(presentation, 18.30, owner, registry)
	if host != null:
		var a_camera_end := float(host.get_snapshot().get("camera_source_width_ratio", 0.0))
		_expect(absf(a_camera_end - a_camera_start) / maxf(a_camera_start, 0.001) >= 0.04, "A-family camera source width should change by at least four percent")
	_advance_presentation_to(presentation, 19.60, owner, registry)
	var b_camera_start := float(host.get_snapshot().get("camera_source_width_ratio", 0.0)) if host != null else 0.0
	_advance_presentation_to(presentation, 21.64, owner, registry)
	_expect(audio.gain_values.min() <= -79.0, "queen's resistance should create the 21.6–23.4 full-silence window")
	_advance_presentation_to(presentation, 26.05, owner, registry)
	if host != null:
		var preflash_snapshot: Dictionary = host.get_snapshot()
		_expect(str(preflash_snapshot.get("base_plate_key", "")) == PrologueOverlayHost.PLATE_B2, "the flash ramp should begin over B2")
		_expect(float(preflash_snapshot.get("flash_alpha", 0.0)) > 0.0, "26.05 should be inside the flash ramp")
		var b_camera_end := float(preflash_snapshot.get("camera_source_width_ratio", 0.0))
		_expect(absf(b_camera_end - b_camera_start) / maxf(b_camera_start, 0.001) >= 0.04, "B-family camera source width should change by at least four percent")
	_advance_presentation_to(presentation, 26.20, owner, registry)
	if host != null:
		_expect(str(host.get_snapshot().get("base_plate_key", "")) == PrologueOverlayHost.PLATE_B2, "26.20 should remain on B2 immediately before the hard cut")
	_advance_presentation_to(presentation, 26.30, owner, registry)
	var ray_growth_early := 0.0
	var c_camera_start := 0.0
	if host != null:
		var cut_snapshot: Dictionary = host.get_snapshot()
		_expect(str(cut_snapshot.get("base_plate_key", "")) == PrologueOverlayHost.PLATE_C1, "26.30 should be on C1 immediately after the 26.25 hard cut")
		_expect(float(cut_snapshot.get("flash_alpha", 0.0)) >= 0.8, "the hard cut should remain hidden under the flash peak")
		ray_growth_early = float(cut_snapshot.get("ray_growth", 0.0))
		_expect(ray_growth_early > 0.0 and float(cut_snapshot.get("ray_additive_alpha", 0.0)) > 0.0, "the ray layer should begin growing immediately after the cut")
		c_camera_start = float(cut_snapshot.get("camera_source_width_ratio", 0.0))
	_advance_presentation_to(presentation, 27.00, owner, registry)
	if host != null:
		_expect(float(host.get_snapshot().get("ray_growth", 0.0)) > ray_growth_early, "ray growth should increase monotonically through the reveal window")
	_expect(audio.rays_calls == 1, "the eight-ray expansion should fire one separate spiritual layer")
	_advance_presentation_to(presentation, 28.80, owner, registry)
	if host != null:
		var rays_handed_off: Dictionary = host.get_snapshot()
		_expect(is_equal_approx(float(rays_handed_off.get("ray_growth", 0.0)), 1.0), "ray growth should reach one before handing off to the baked C1 rays")
		_expect(is_zero_approx(float(rays_handed_off.get("ray_additive_alpha", -1.0))), "additive rays should be zero after the 28.6 handoff")
	_advance_presentation_to(presentation, 29.50, owner, registry)
	if host != null:
		var c_camera_end := float(host.get_snapshot().get("camera_source_width_ratio", 0.0))
		_expect(absf(c_camera_end - c_camera_start) / maxf(c_camera_start, 0.001) >= 0.04, "C1 camera pullback should change source width by at least four percent")
	_advance_presentation_to(presentation, 30.90, owner, registry)
	var d_camera_start := float(host.get_snapshot().get("camera_source_width_ratio", 0.0)) if host != null else 0.0
	var subtitle_position_before_shake: Vector2 = host.get_snapshot().get("subtitle_position", Vector2.ZERO) if host != null else Vector2.ZERO
	_advance_presentation_to(presentation, 33.05, owner, registry)
	if host != null:
		var impact_snapshot: Dictionary = host.get_snapshot()
		_expect(float(impact_snapshot.get("flash_alpha", 0.0)) > 0.0, "33.05 should render the impact flash")
		_expect(float(impact_snapshot.get("shake_magnitude", 0.0)) > 0.0, "33.05 should drive nonzero plate shake")
		_expect(impact_snapshot.get("subtitle_position", Vector2.ZERO) == subtitle_position_before_shake, "plate shake must not move the subtitle label")
		_expect(int(impact_snapshot.get("additive_blend_mode", -1)) == CanvasItemMaterial.BLEND_MODE_ADD, "ray/shard/ring FX should use a dedicated additive CanvasItem")
		_expect(bool(impact_snapshot.get("additive_interpolation_off", false)), "the additive FX child should disable physics interpolation")
	_advance_presentation_to(presentation, 33.60, owner, registry)
	_expect(audio.spirit_bell_calls == 1, "the first extraction should fire one fixed-pitch bell")
	if host != null:
		var shard_snapshot: Dictionary = host.get_snapshot()
		_expect(float(shard_snapshot.get("shard_progress", 0.0)) > 0.0, "33.60 should be inside the shard absorption path")
		_expect(is_zero_approx(float(shard_snapshot.get("shake_magnitude", -1.0))), "shake should decay to zero after 33.35")
	var asset_status := presentation.get_asset_status()
	var streamed: Dictionary = asset_status.get("stream_ready", {})
	_expect(int(asset_status.get("stream_completed_count", 0)) == 8, "the deterministic controller fixture should materialize five streamed bases plus three streamed FX layers by D2")
	_expect((asset_status.get("deadline_misses", {}) as Dictionary).is_empty(), "the on-time staged fixture should meet every live plate deadline")
	_expect(int(asset_status.get("resident_peak", 0)) == 4, "staged materialization should never exceed four logical resident plates")
	_expect(int(asset_status.get("resident_count", 0)) == 2, "D1 and D2 alone should remain during their final blend")
	_expect(int(asset_status.get("fx_resident_peak", 0)) <= 2 and int(asset_status.get("fx_resident_count", 0)) == 1, "only the shard FX should remain during the final blend and the FX peak must stay at two")
	_expect(int(asset_status.get("total_resident_peak", 0)) <= 6, "combined base and cropped FX residency should peak at six textures")
	var released_keys: Dictionary = asset_status.get("released_plate_keys", {})
	_expect(released_keys.size() == 6 and released_keys.has(PrologueOverlayHost.PLATE_C1), "every plate through C1 should release immediately after its completed replacement blend")
	_advance_presentation_to(presentation, 33.90, owner, registry)
	if host != null:
		var d_camera_end := float(host.get_snapshot().get("camera_source_width_ratio", 0.0))
		_expect(absf(d_camera_end - d_camera_start) / maxf(d_camera_start, 0.001) >= 0.04, "D-family camera source width should change by at least four percent")
	_advance_presentation_to(presentation, 34.50, owner, registry)
	if host != null:
		var settled_snapshot: Dictionary = host.get_snapshot()
		_expect(str(settled_snapshot.get("base_plate_key", "")) == PrologueOverlayHost.PLATE_D2, "D2 should become the settled base after the impact blend")
		_expect(is_zero_approx(float(settled_snapshot.get("flash_alpha", -1.0))) and is_zero_approx(float(settled_snapshot.get("shard_progress", -1.0))) and is_zero_approx(float(settled_snapshot.get("shake_magnitude", -1.0))), "all transient impact FX should return to zero after 34.0")
	host = presentation.get_host_for_test()
	if host != null:
		var extraction_snapshot: Dictionary = host.get_snapshot()
		_expect(str(extraction_snapshot.get("speaker", "")) == "여왕 해원", "post-strike beat should return to Queen Haewon")
		_expect(str(extraction_snapshot.get("subtitle", "")).find("사람은 남겨라") >= 0, "post-strike subtitle should state the host-saving rule")
		var ready_after_stream: Dictionary = extraction_snapshot.get("plate_ready", {})
		_expect(not bool(ready_after_stream.get("a1", true)), "A1 should release after the A2 blend")
		_expect(not bool(ready_after_stream.get("a3", true)), "A3 should release after the B1 blend")
		_expect(not bool(ready_after_stream.get("b1", true)), "B1 should release after the B2 blend")
		_expect(not bool(ready_after_stream.get("c1", true)), "C1 should release after the D1 blend")
		_expect(not bool(ready_after_stream.get("d1", true)) and bool(ready_after_stream.get("d2", false)), "D2 alone should remain after the impact blend settles")
		_expect(not bool(ready_after_stream.get("fx_shard", true)), "the cropped shard layer should release after its absorption window")

	_expect(presentation.handle_input(skip_event, owner, registry), "Space should request a prologue skip after the guard")
	presentation.update(ProloguePresentation.SKIP_FADE_SECONDS + 0.05, owner, registry)
	_expect(not presentation.is_active(), "skip fade should complete and release the battle gate")
	_expect(presentation.get_completion_reason() == "skip", "manual skip should retain its completion reason")
	_expect(audio.clear_gain_calls > 0 and audio.stop_cue_calls > 0, "skip should restore the BGM bus and stop every story cue")
	if host != null:
		var skipped_snapshot: Dictionary = host.get_snapshot()
		_expect(is_zero_approx(float(skipped_snapshot.get("flash_alpha", -1.0))) and is_zero_approx(float(skipped_snapshot.get("ray_additive_alpha", -1.0))) and is_zero_approx(float(skipped_snapshot.get("shard_progress", -1.0))) and is_zero_approx(float(skipped_snapshot.get("shake_magnitude", -1.0))), "skip completion should zero every motion state immediately")
	var persisted := StoryCinematicProgressStore.new()
	persisted.set_save_path(path)
	_expect(persisted.has_seen(ProloguePresentation.CINEMATIC_ID), "manual skip should retain completion history")

	var replay := ProloguePresentation.new()
	replay.set_progress_path_for_test(path)
	replay.set_entry_request_override_for_test(true)
	_seed_headless_texture_fixture(replay, deterministic_fixture)
	guard = 0
	while not replay.prewarm_stage_entry_step(owner) and guard < 240:
		guard += 1
		OS.delay_msec(1)
	_expect(replay.begin(owner, registry), "a new character-select confirmation should replay the viewed prologue")
	_expect(is_zero_approx(replay.get_skip_lock_seconds()), "repeat viewing should allow an immediate skip")
	_expect(replay.handle_input(skip_event, owner, registry), "repeat viewing should accept Space on its first frame")
	replay.update(ProloguePresentation.SKIP_FADE_SECONDS + 0.05, owner, registry)

	var natural := ProloguePresentation.new()
	natural.set_progress_path_for_test(path)
	natural.set_entry_request_override_for_test(true)
	_seed_headless_texture_fixture(natural, deterministic_fixture)
	guard = 0
	while not natural.prewarm_stage_entry_step(owner) and guard < 240:
		guard += 1
		OS.delay_msec(1)
	_expect(natural.begin(owner, registry), "viewed prologue should still support a full natural replay")
	_advance_presentation_to(natural, 39.5, owner, registry)
	var natural_host := natural.get_host_for_test()
	if natural_host != null:
		var first_elapsed_snapshot: Dictionary = natural_host.get_snapshot()
		_expect(bool(first_elapsed_snapshot.get("elapsed_card_visible", false)), "39.4-second mark should show the first elapsed-time card")
		_expect(str(first_elapsed_snapshot.get("subtitle", "")).find("여덟 줄기") >= 0, "first elapsed-time card should state where the eight beams went")
	_advance_presentation_to(natural, 42.3, owner, registry)
	if natural_host != null:
		_expect(str(natural_host.get_snapshot().get("subtitle", "")).find("세 해 뒤") >= 0, "42.2-second mark should replace, not stack, the elapsed card")
	_advance_presentation_to(natural, 45.1, owner, registry)
	if natural_host != null:
		var chapter_snapshot: Dictionary = natural_host.get_snapshot()
		_expect(str(chapter_snapshot.get("title", "")).find("제1장") >= 0, "45-second mark should reveal the chapter card")
		_expect(bool(chapter_snapshot.get("title_centered", false)), "chapter card should be centered")
		_expect(bool(chapter_snapshot.get("title_wrap_enabled", false)), "long localized chapter cards should support two-line wrapping")
		_expect(str(chapter_snapshot.get("subtitle", "")) == "", "chapter card should begin after both elapsed cards end")
	_advance_presentation_to(natural, 47.7, owner, registry)
	if natural_host != null:
		var fade_snapshot: Dictionary = natural_host.get_snapshot()
		_expect(float(fade_snapshot.get("fade_alpha", 0.0)) > 0.0, "natural completion should fade during the final half-second")
		_expect(float(fade_snapshot.get("fade_cover_alpha", 0.0)) > 0.0, "natural fade should use the screen-level cover")
		_expect(bool(fade_snapshot.get("fade_cover_above_title", false)), "natural fade cover should sit above the chapter label")
	_advance_presentation_to(natural, 48.2, owner, registry)
	_expect(not natural.is_active() and natural.get_completion_reason() == "natural", "48-second natural completion should release the battle gate")

	var startup_fixture := {
		PrologueOverlayHost.PLATE_A1: ProjectResourceLoader.load_imported_texture(ProloguePresentation.A1_TEXTURE_PATH),
		PrologueOverlayHost.PLATE_A2: ProjectResourceLoader.load_imported_texture(ProloguePresentation.A2_TEXTURE_PATH),
		PrologueOverlayHost.PLATE_A3: ProjectResourceLoader.load_imported_texture(ProloguePresentation.A3_TEXTURE_PATH),
	}
	if startup_fixture.values().all(func(value: Variant) -> bool: return value is Texture2D):
		var font_host: Control = PrologueOverlayHost.new()
		owner.add_child(font_host)
		font_host.sync_layout(Vector2(1920.0, 1080.0))
		_expect(font_host.begin(startup_fixture, PrologueText.get_copy("ja")), "Japanese font fixture should begin")
		_expect(bool(font_host.get_snapshot().get("uses_fallback_font", false)), "Japanese labels should use ThemeDB fallback glyphs")
		font_host.sync_layout(Vector2(2560.0, 1440.0))
		_expect(font_host.begin(startup_fixture, PrologueText.get_copy("zh")), "Chinese font fixture should begin")
		_expect(bool(font_host.get_snapshot().get("uses_fallback_font", false)), "Chinese labels should use ThemeDB fallback glyphs")
		font_host.tear_down(true)

	natural.tear_down()
	replay.tear_down()
	presentation.tear_down()
	persisted = null
	skip_event = null
	host = null
	natural_host = null
	start_asset_status.clear()
	asset_status.clear()
	streamed.clear()
	released_keys.clear()
	startup_fixture.clear()
	deterministic_fixture.clear()
	natural = null
	replay = null
	presentation = null
	registry.audio = null
	registry = null
	audio = null
	owner.free()
	owner = null
	_cleanup(path)


func _build_headless_texture_fixture() -> Dictionary:
	if not _is_headless_runtime():
		return {}
	var startup: Dictionary = {}
	for spec_value in ProloguePresentation.STARTUP_TEXTURE_SPECS:
		var spec: Dictionary = spec_value
		var path := str(spec.get("path", ""))
		var texture := ProjectResourceLoader.load_imported_texture(path)
		_expect(texture != null, "headless startup fixture should decode %s" % path)
		if texture != null:
			startup[str(spec.get("key", ""))] = texture
	return {"startup": startup}


func _seed_headless_texture_fixture(presentation: Object, fixture: Dictionary) -> void:
	if not _is_headless_runtime() or presentation == null:
		return
	presentation.seed_startup_textures_for_test(fixture.get("startup", {}))
	presentation.set_stream_texture_factory_for_test(Callable(self, "_make_stream_texture_for_test"))


func _make_stream_texture_for_test(_plate_key: String, _elapsed: float) -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.16, 0.28, 0.34, 1.0))
	return ImageTexture.create_from_image(image)


func _make_delayed_stream_texture_for_test(plate_key: String, elapsed: float) -> Dictionary:
	if plate_key == PrologueOverlayHost.PLATE_B1 and elapsed < 20.0:
		return {"done": false}
	return {"done": true, "texture": _make_stream_texture_for_test(plate_key, elapsed)}


func _advance_presentation_to(presentation: Object, target_elapsed: float, owner: Object, registry: Object) -> void:
	if presentation == null:
		return
	while presentation.is_active() and presentation.get_elapsed() + 0.0001 < target_elapsed:
		var delta := minf(0.1, target_elapsed - presentation.get_elapsed())
		presentation.update(delta, owner, registry)


func _is_headless_runtime() -> bool:
	return OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0


func _test_path(suffix: String) -> String:
	return "res://.tmp/stage1_han_miryang_prologue_smoke_%s_%d.cfg" % [suffix, Time.get_ticks_usec()]


func _cleanup(path: String) -> void:
	for candidate in [path, path.trim_suffix(".cfg") + StoryCinematicProgressStore.BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _file_starts_with_bom(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	return bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
