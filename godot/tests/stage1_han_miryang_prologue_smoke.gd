extends SceneTree

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
	var missing_beat_calls := 0
	var missing_beat_stop_calls := 0
	var gain_values: Array[float] = []
	var clear_gain_calls := 0

	func play_han_miryang_prologue_missing_beat() -> void:
		missing_beat_calls += 1

	func stop_han_miryang_prologue_missing_beat() -> void:
		missing_beat_stop_calls += 1

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
	_verify_real_audio_transient_gain_contract()
	_verify_live_intro_frame_advances_before_loading_hold()
	_verify_progress_roundtrip_and_bom_rewrite()
	await _verify_character_select_replay_timeline_and_completion_history()

	if _failures.is_empty():
		print("stage1_han_miryang_prologue_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


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
		_expect(str(copy.get("title", "")) != "", "%s title should not be empty" % locale)
		_expect(str(copy.get("chapter", "")) != "", "%s chapter should not be empty" % locale)
		_expect(str(copy.get("skip", "")) != "", "%s skip hint should not be empty" % locale)
		_expect(segments.size() == 9, "%s should have the nine approved dialogue beats" % locale)
		for segment_value in segments:
			var segment: Dictionary = segment_value if segment_value is Dictionary else {}
			_expect(float(segment.get("end", 0.0)) > float(segment.get("start", 0.0)), "%s segment timing should advance" % locale)
			_expect(str(segment.get("text", "")) != "", "%s dialogue should not be empty" % locale)


func _verify_runtime_integration_routes() -> void:
	var catalog := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	var character_select := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	var intro_lifecycle := FileAccess.get_file_as_string("res://scripts/core/battle_scene_stage_intro_flow_lifecycle.gd")
	var intro_frame := FileAccess.get_file_as_string("res://scripts/core/battle_scene_intro_frame_controller.gd")
	var input_router := FileAccess.get_file_as_string("res://scripts/core/battle_pre_intro_stage_input_router.gd")
	var boot_prewarm := FileAccess.get_file_as_string("res://scripts/core/battle_boot_resource_prewarm_controller.gd")
	var entry_prewarm := FileAccess.get_file_as_string("res://scripts/ui/battle_entry_background_prewarm.gd")
	var teardown := FileAccess.get_file_as_string("res://scripts/core/battle_scene_teardown_lifecycle.gd")
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
	_expect(entry_prewarm.find("HanMiryangPrologue.get_texture_paths") >= 0, "character-select idle prewarm should include all three story plates on every Han Miryang Stage 1 entry")
	_expect(entry_prewarm.find("has_seen(HanMiryangPrologue.CINEMATIC_ID)") < 0, "repeat-view policy should not suppress menu-idle story prewarm")
	_expect(teardown.find("stage1_han_miryang_prologue_presentation") >= 0, "battle teardown should release the detached prologue host")
	_expect(game_audio.find("play_han_miryang_prologue_missing_beat") >= 0, "missing-beat chime should route through GameAudio")
	_expect(game_audio.find("set_story_cinematic_bgm_gain_db") >= 0, "story BGM gap should route through the shared audio facade")
	_expect(game_audio.find("clear_story_cinematic_bgm_gain") >= 0, "story BGM gap should expose an explicit transient-gain reset")
	_expect(presentation.find("set_bgm_volume") < 0, "story BGM gap must not rewrite the user's saved BGM volume")


func _verify_real_audio_transient_gain_contract() -> void:
	var audio := GameAudio.new()
	var user_volume := audio.get_bgm_volume()
	_expect(is_equal_approx(audio.set_story_cinematic_bgm_gain_db(-200.0), -80.0), "story BGM gain should clamp to the silent floor")
	_expect(is_equal_approx(audio.get_story_cinematic_bgm_gain_db(), -80.0), "story BGM gain getter should expose the transient value")
	_expect(is_equal_approx(audio.get_bgm_volume(), user_volume), "story BGM gain must preserve the user's saved BGM volume")
	audio.clear_story_cinematic_bgm_gain()
	_expect(is_zero_approx(audio.get_story_cinematic_bgm_gain_db()), "story BGM gain reset should restore neutral gain")


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


func _verify_character_select_replay_timeline_and_completion_history() -> void:
	var path := _test_path("presentation")
	_cleanup(path)
	var first_texture := ProjectResourceLoader.load_texture(ProloguePresentation.FIRST_TEXTURE_PATH)
	var strike_texture := ProjectResourceLoader.load_texture(ProloguePresentation.STRIKE_TEXTURE_PATH)
	var second_texture := ProjectResourceLoader.load_texture(ProloguePresentation.SECOND_TEXTURE_PATH)
	_expect(first_texture != null, "coronation key art should load")
	_expect(strike_texture != null, "post-strike key art without the tablet should load")
	_expect(second_texture != null, "missing-beat key art should load")
	if first_texture != null:
		_expect(first_texture.get_size() == Vector2(3344.0, 1882.0), "coronation key art should use the accepted 2x cinematic resolution")
	if strike_texture != null:
		_expect(strike_texture.get_size() == Vector2(3344.0, 1882.0), "post-strike key art should use the accepted 2x cinematic resolution")
	if second_texture != null:
		_expect(second_texture.get_size() == Vector2(3344.0, 1882.0), "missing-beat key art should use the accepted 2x cinematic resolution")

	var owner := FakeOwner.new()
	root.add_child(owner)
	await process_frame
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.audio = audio
	var presentation := ProloguePresentation.new()
	presentation.set_progress_path_for_test(path)
	presentation.set_entry_request_override_for_test(true)
	var guard := 0
	while not presentation.prewarm_stage_entry_step(owner) and guard < 12:
		guard += 1
		await process_frame
	_expect(guard < 12, "three prologue assets and host should prewarm within the bounded smoke loop")
	_expect(presentation.begin(owner, registry), "character-selected Han Miryang entry should begin the prologue")
	_expect(presentation.is_active(), "begun prologue should block the battle")
	_expect(is_equal_approx(presentation.get_skip_lock_seconds(), ProloguePresentation.FIRST_VIEW_SKIP_LOCK_SECONDS), "first viewing should protect the opening input for 1.2 seconds")
	var host := presentation.get_host_for_test()
	_expect(host != null, "prologue should attach a viewport overlay host")
	if host != null:
		var start_snapshot: Dictionary = host.get_snapshot()
		_expect(bool(start_snapshot.get("visible", false)), "prologue host should be visible")
		_expect(not bool(start_snapshot.get("process_enabled", true)), "prologue host should remain controller-driven")
		_expect(bool(start_snapshot.get("first_texture_ready", false)), "first cinematic texture should be bound")
		_expect(bool(start_snapshot.get("strike_texture_ready", false)), "post-strike cinematic texture should be bound")
		_expect(bool(start_snapshot.get("second_texture_ready", false)), "second cinematic texture should be bound")
		_expect(not bool(start_snapshot.get("skip_allowed", true)), "first frame should hide the skip affordance during the first-view lock")

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
	guard = 0
	while not presentation.prewarm_stage_entry_step(owner) and guard < 12:
		guard += 1
		await process_frame
	_expect(presentation.begin(owner, registry), "fresh first-view fixture should restart after the input-lock leg")
	presentation.update(1.21, owner, registry)
	presentation.update(14.84, owner, registry)
	presentation.update(0.95, owner, registry)
	host = presentation.get_host_for_test()
	if host != null:
		var missing_beat_snapshot: Dictionary = host.get_snapshot()
		_expect(str(missing_beat_snapshot.get("speaker", "")) == "한미량", "17-second beat should show Han Miryang's missing-beat line")
		_expect(str(missing_beat_snapshot.get("subtitle", "")).find("한 박") >= 0, "missing-beat subtitle should contain the core mystery")
	_expect(audio.missing_beat_calls == 1, "the missing beat should fire one fixed-pitch chime through GameAudio")
	_expect(not audio.gain_values.is_empty() and audio.gain_values.min() <= -79.0, "the missing beat should create an audible BGM gap")

	_expect(presentation.handle_input(skip_event, owner, registry), "Space should request a prologue skip after the guard")
	presentation.update(ProloguePresentation.SKIP_FADE_SECONDS + 0.05, owner, registry)
	_expect(not presentation.is_active(), "skip fade should complete and release the battle gate")
	_expect(presentation.get_completion_reason() == "skip", "manual skip should retain its completion reason")
	_expect(audio.clear_gain_calls > 0 and audio.missing_beat_stop_calls > 0, "skip should restore the BGM bus and stop the story chime")
	var persisted := StoryCinematicProgressStore.new()
	persisted.set_save_path(path)
	_expect(persisted.has_seen(ProloguePresentation.CINEMATIC_ID), "manual skip should retain completion history")

	presentation.set_entry_request_override_for_test(true)
	_expect(presentation.begin(owner, registry), "a new character-select confirmation should replay the viewed prologue")
	_expect(is_zero_approx(presentation.get_skip_lock_seconds()), "repeat viewing should allow an immediate skip")
	_expect(presentation.handle_input(skip_event, owner, registry), "repeat viewing should accept Space on its first frame")
	presentation.update(ProloguePresentation.SKIP_FADE_SECONDS + 0.05, owner, registry)

	var natural := ProloguePresentation.new()
	natural.set_progress_path_for_test(path)
	natural.set_entry_request_override_for_test(true)
	guard = 0
	while not natural.prewarm_stage_entry_step(owner) and guard < 12:
		guard += 1
		await process_frame
	_expect(natural.begin(owner, registry), "viewed prologue should still support a full natural replay")
	natural.update(35.0, owner, registry)
	var natural_host := natural.get_host_for_test()
	if natural_host != null:
		var chapter_snapshot: Dictionary = natural_host.get_snapshot()
		_expect(str(chapter_snapshot.get("title", "")).find("제1장") >= 0, "35-second mark should reveal the chapter card")
		_expect(bool(chapter_snapshot.get("title_centered", false)), "chapter card should be centered")
		_expect(str(chapter_snapshot.get("subtitle", "")) == "", "chapter card should begin after the final dialogue ends")
	natural.update(2.6, owner, registry)
	if natural_host != null:
		_expect(float(natural_host.get_snapshot().get("fade_alpha", 0.0)) > 0.0, "natural completion should fade during the final half-second")
	natural.update(0.4, owner, registry)
	_expect(not natural.is_active() and natural.get_completion_reason() == "natural", "38-second natural completion should release the battle gate")

	if first_texture != null and strike_texture != null and second_texture != null:
		var font_host: Control = PrologueOverlayHost.new()
		owner.add_child(font_host)
		font_host.sync_layout(Vector2(1920.0, 1080.0))
		_expect(font_host.begin(first_texture, strike_texture, second_texture, PrologueText.get_copy("ja")), "Japanese font fixture should begin")
		_expect(bool(font_host.get_snapshot().get("uses_fallback_font", false)), "Japanese labels should use ThemeDB fallback glyphs")
		_expect(font_host.begin(first_texture, strike_texture, second_texture, PrologueText.get_copy("zh")), "Chinese font fixture should begin")
		_expect(bool(font_host.get_snapshot().get("uses_fallback_font", false)), "Chinese labels should use ThemeDB fallback glyphs")
		font_host.tear_down(true)

	natural.tear_down()
	presentation.tear_down()
	registry.audio = null
	registry = null
	audio = null
	owner.queue_free()
	await process_frame
	_cleanup(path)


func _test_path(suffix: String) -> String:
	return "user://stage1_han_miryang_prologue_smoke_%s_%d.cfg" % [suffix, Time.get_ticks_usec()]


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
