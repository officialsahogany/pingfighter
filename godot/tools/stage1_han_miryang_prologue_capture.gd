extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const StoryCinematicProgressStore := preload("res://scripts/core/story_cinematic_progress_store.gd")
const PrologueText := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_text.gd")
const ProloguePresentation := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd")
const PrologueOverlayHost := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd")

const VIEW_SIZES := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
const LOCALES := ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]
const OUT_ROOT := "res://.tmp/qa_evidence"


class CaptureOwner extends Node2D:
	var current_stage := 1
	var selected_runtime_character_id := "smasher"
	var selected_character_type := "smasher"


var _out_dir := ""
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage1_han_miryang_prologue_capture must run without --headless")
		quit(1)
		return
	_out_dir = ProjectSettings.globalize_path("%s/han_miryang_prologue_v3_%d_%d" % [OUT_ROOT, Time.get_ticks_usec(), OS.get_process_id()])
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	_expect(mkdir_error == OK, "evidence directory should be created")
	# Keep the clean visual contact sheet separate from the production A-to-D
	# threaded preflight. The explicit option writes its own metrics artifact so
	# request/residency/cleanup evidence is not inferred from the visual captures.
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--threaded-preflight") or user_args.has("--threaded-preflight-only"):
		await _verify_threaded_presentation_preflight()
	if user_args.has("--threaded-preflight-only"):
		_finish()
		return
	var textures: Dictionary = {}
	for texture_path in ProloguePresentation.get_all_texture_paths():
		var texture := ProjectResourceLoader.load_texture(texture_path)
		textures[texture_path] = texture
		_expect(texture != null, "story plate should load: %s" % texture_path)
	if textures.values().any(func(value: Variant) -> bool: return not (value is Texture2D)):
		_finish()
		return

	for view_size: Vector2i in VIEW_SIZES:
		var prefix := "ko_%dx%d" % [view_size.x, view_size.y]
		var event_times := {
			"a1_coronation": 8.6,
			"a2_tablet": 12.8,
			"a3_spirit": 16.8,
			"b1_resistance": 20.0,
			"b2_orb": 24.0,
			"c1_eight_rays": 28.0,
			"d1_confrontation": 31.0,
			"d2_first_strike": 34.2,
			"elapsed_first": 39.5,
			"chapter": 45.2,
		}
		var previous_image: Image = null
		for event_name in event_times:
			var elapsed := float(event_times[event_name])
			var image := await _capture("%s_%s" % [prefix, event_name], view_size, "ko", elapsed, textures)
			_verify_frame(image, "%s %s" % [prefix, event_name], view_size, _ink_region_for_time(elapsed))
			if previous_image != null and event_name not in ["elapsed_first", "chapter"]:
				_expect(_sampled_difference(previous_image, image) > 0.006, "%s should differ visibly from the preceding story beat" % event_name)
			previous_image = image
		var final_fade := await _capture("%s_final_fade" % prefix, view_size, "ko", 47.99, textures)
		_verify_final_fade(final_fade, "%s final fade" % prefix, view_size)

		for locale in LOCALES:
			var subtitle := await _capture("%s_%dx%d_subtitle" % [locale, view_size.x, view_size.y], view_size, locale, 15.8, textures)
			_verify_frame(subtitle, "%s subtitle" % locale, view_size, "subtitle")
		for locale in ["en", "es", "ru"]:
			var chapter := await _capture("%s_%dx%d_chapter" % [locale, view_size.x, view_size.y], view_size, locale, 45.2, textures)
			_verify_frame(chapter, "%s chapter" % locale, view_size, "chapter")

	_finish()


func _verify_threaded_presentation_preflight() -> void:
	var failure_count_before := _failures.size()
	var progress_path := "res://.tmp/stage1_han_miryang_prologue_capture_%d.cfg" % Time.get_ticks_usec()
	_cleanup_progress_path(progress_path)
	ProjectResourceLoader.clear_caches()
	var owner := CaptureOwner.new()
	root.add_child(owner)
	await process_frame
	var presentation := ProloguePresentation.new()
	presentation.set_progress_path_for_test(progress_path)
	presentation.set_entry_request_override_for_test(true)
	var observed_thread_paths: Dictionary = {}
	var first_observed_elapsed: Dictionary = {}
	var startup_guard := 0
	var startup_done := false
	while not startup_done and startup_guard < 600:
		startup_done = presentation.prewarm_stage_entry_step(owner)
		_record_threaded_texture_owner(observed_thread_paths, first_observed_elapsed, -1.0)
		startup_guard += 1
		if not startup_done:
			await process_frame
	_expect(startup_done and startup_guard < 600, "windowed production preflight should finish the real threaded A-family prewarm")
	_expect(presentation.begin(owner, null), "windowed production preflight should begin the character-selected prologue")
	_record_threaded_texture_owner(observed_thread_paths, first_observed_elapsed, presentation.get_elapsed())
	var stream_guard := 0
	while int(presentation.get_asset_status().get("stream_completed_count", 0)) < ProloguePresentation.STREAM_TEXTURE_SPECS.size() and stream_guard < 2400:
		presentation.update(0.016, owner, null)
		_record_threaded_texture_owner(observed_thread_paths, first_observed_elapsed, presentation.get_elapsed())
		stream_guard += 1
		await process_frame
	var asset_status: Dictionary = presentation.get_asset_status()
	_expect(stream_guard < 2400 and int(asset_status.get("stream_completed_count", 0)) == 5, "windowed production preflight should complete all five staged B/C/D requests without sync fallback")
	_expect((asset_status.get("deadline_misses", {}) as Dictionary).is_empty(), "windowed production preflight should meet every live plate deadline")
	_expect(int(asset_status.get("resident_peak", 0)) == 4, "windowed production preflight should prove the exact four-plate runtime peak")
	for expected_path in ProloguePresentation.get_all_texture_paths():
		_expect(observed_thread_paths.has(expected_path), "windowed production preflight should observe the real threaded owner for %s" % expected_path)
	_expect(observed_thread_paths.size() == ProloguePresentation.get_all_texture_paths().size(), "windowed production preflight should observe exactly the declared eight threaded paths")
	for stream_spec_value in ProloguePresentation.STREAM_TEXTURE_SPECS:
		var stream_spec: Dictionary = stream_spec_value
		var stream_path := str(stream_spec.get("path", ""))
		var first_elapsed := float(first_observed_elapsed.get(stream_path, -1.0))
		_expect(first_elapsed + 0.0001 >= float(stream_spec.get("request_at", 0.0)), "threaded request must not start before request_at: %s" % stream_path)
	var skip_event := InputEventKey.new()
	skip_event.pressed = true
	skip_event.keycode = KEY_SPACE
	_expect(presentation.handle_input(skip_event, owner, null), "windowed production preflight should accept skip after the first-view lock")
	presentation.update(ProloguePresentation.SKIP_FADE_SECONDS + 0.05, owner, null)
	_expect(presentation.get_completion_reason() == "skip" and not presentation.is_active(), "windowed production preflight skip should release the battle gate")
	var released_status: Dictionary = presentation.get_asset_status()
	_expect(int(released_status.get("resident_count", -1)) == 0, "windowed production preflight skip should release every presentation plate reference")
	_expect(ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests() == "", "windowed production preflight should leave no shared threaded texture owner")
	for texture_path in ProloguePresentation.get_all_texture_paths():
		_expect(not ProjectResourceLoader.is_threaded_texture_detached_for_tests(texture_path), "completed preflight path should not remain detached: %s" % texture_path)
		_expect(ProjectResourceLoader.get_cached_texture(texture_path) == null, "completed preflight path should leave no explicit project cache reference: %s" % texture_path)
	presentation.tear_down()
	presentation = null
	skip_event = null
	owner.queue_free()
	for _frame in range(12):
		await process_frame
	await create_timer(0.05).timeout
	_cleanup_progress_path(progress_path)
	var observed_path_list: Array = observed_thread_paths.keys()
	observed_path_list.sort()
	var preflight_summary := {
		"result": "PASS" if _failures.size() == failure_count_before else "FAIL",
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"observed_threaded_paths": observed_path_list,
		"first_observed_elapsed": first_observed_elapsed,
		"resident_plate_peak": int(asset_status.get("resident_peak", 0)),
		"stream_paths_completed": int(asset_status.get("stream_completed_count", 0)),
		"deadline_misses": asset_status.get("deadline_misses", {}),
		"final_presentation_resident_count": int(released_status.get("resident_count", -1)),
		"shared_threaded_owner_after_cleanup": ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests(),
	}
	var summary_path := _out_dir.path_join("threaded_preflight_result.json")
	var summary_file := FileAccess.open(summary_path, FileAccess.WRITE)
	_expect(summary_file != null, "windowed production preflight should preserve its metrics artifact")
	if summary_file != null:
		summary_file.store_string(JSON.stringify(preflight_summary, "  ") + "\n")
		summary_file.close()
	print(
		"[HanMiryangPrologueQA] threaded_streaming: %s peak=%d observed=%d completed=%d deadline_misses=%d"
		% [
			"PASS" if _failures.size() == failure_count_before else "FAIL",
			int(asset_status.get("resident_peak", 0)),
			observed_thread_paths.size(),
			int(asset_status.get("stream_completed_count", 0)),
			(asset_status.get("deadline_misses", {}) as Dictionary).size(),
		]
	)


func _record_threaded_texture_owner(observed_paths: Dictionary, first_elapsed_by_path: Dictionary, elapsed: float) -> void:
	var path := ProjectResourceLoader.get_threaded_texture_prewarm_path_for_tests()
	if path == "":
		return
	observed_paths[path] = true
	if not first_elapsed_by_path.has(path):
		first_elapsed_by_path[path] = elapsed


func _capture(name: String, view_size: Vector2i, locale: String, elapsed: float, textures: Dictionary) -> Image:
	LanguageSettings.set_test_locale_override(locale)
	var viewport := SubViewport.new()
	viewport.size = view_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Control.new()
	stage.size = Vector2(view_size)
	viewport.add_child(stage)
	var host: Control = PrologueOverlayHost.new()
	stage.add_child(host)
	host.sync_layout(Vector2(view_size))
	var startup := {
		PrologueOverlayHost.PLATE_A1: textures.get(ProloguePresentation.A1_TEXTURE_PATH),
		PrologueOverlayHost.PLATE_A2: textures.get(ProloguePresentation.A2_TEXTURE_PATH),
		PrologueOverlayHost.PLATE_A3: textures.get(ProloguePresentation.A3_TEXTURE_PATH),
	}
	_expect(host.begin(startup, PrologueText.get_copy(locale)), "%s host should begin" % name)
	for stream_spec_value in ProloguePresentation.STREAM_TEXTURE_SPECS:
		var stream_spec: Dictionary = stream_spec_value
		var path := str(stream_spec.get("path", ""))
		var texture_value: Variant = textures.get(path, null)
		if texture_value is Texture2D:
			host.set_plate_texture(str(stream_spec.get("key", "")), texture_value)
	var segment := PrologueText.get_segment_at(PrologueText.get_segments(locale), elapsed)
	if segment.is_empty():
		segment = PrologueText.get_segment_at(PrologueText.get_elapsed_segments(locale), elapsed)
	var fade_alpha := 0.0
	if elapsed >= ProloguePresentation.NATURAL_FADE_START_SECONDS:
		fade_alpha = clampf(
			(elapsed - ProloguePresentation.NATURAL_FADE_START_SECONDS)
			/ (ProloguePresentation.DURATION_SECONDS - ProloguePresentation.NATURAL_FADE_START_SECONDS),
			0.0,
			1.0
		)
	host.sync_timeline(elapsed, fade_alpha, segment, true)
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("visible", false)), "%s host should be visible" % name)
	if fade_alpha > 0.0:
		_expect(is_equal_approx(float(snapshot.get("fade_cover_alpha", -1.0)), fade_alpha), "%s should project the final fade through the screen cover" % name)
		_expect(bool(snapshot.get("fade_cover_above_title", false)), "%s fade cover should render above localized labels" % name)
	if elapsed >= 45.0:
		_expect(str(snapshot.get("subtitle", "")) == "", "%s chapter should hide dialogue" % name)
		_expect(bool(snapshot.get("title_centered", false)), "%s chapter should be centered" % name)
		_expect(bool(snapshot.get("title_wrap_enabled", false)), "%s chapter should allow two-line wrapping" % name)
	elif not segment.is_empty():
		_expect(str(snapshot.get("subtitle", "")) != "", "%s should show localized text" % name)
	else:
		_expect(str(snapshot.get("subtitle", "")) == "", "%s is an intentional silent visual beat" % name)
	if locale in ["ja", "zh"]:
		_expect(bool(snapshot.get("uses_fallback_font", false)), "%s should use ThemeDB fallback glyph outlines" % name)
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var save_path := "%s/%s.png" % [_out_dir, name]
	var save_error := image.save_png(save_path)
	_expect(save_error == OK, "%s PNG should save" % name)
	host.tear_down()
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame
	return image


func _ink_region_for_time(elapsed: float) -> String:
	if elapsed >= 45.0:
		return "chapter"
	if elapsed >= 39.4:
		return "elapsed"
	return "subtitle" if not PrologueText.get_segment_at(PrologueText.get_segments("ko"), elapsed).is_empty() else "none"


func _verify_frame(image: Image, label: String, view_size: Vector2i, ink_region: String) -> void:
	_expect(image != null and image.get_size() == view_size, "%s capture should match its requested resolution" % label)
	if image == null or image.is_empty():
		return
	var lit_samples := 0
	var ink_samples := 0
	var y_start := int(float(image.get_height()) * 0.76)
	var y_end := image.get_height()
	if ink_region == "elapsed":
		y_start = int(float(image.get_height()) * 0.68)
		y_end = int(float(image.get_height()) * 0.90)
	elif ink_region == "chapter":
		y_start = int(float(image.get_height()) * 0.32)
		y_end = int(float(image.get_height()) * 0.68)
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var pixel := image.get_pixel(x, y)
			if pixel.v > 0.08:
				lit_samples += 1
			if y >= y_start and y < y_end and pixel.v > 0.72:
				ink_samples += 1
	var sample_scale := float(view_size.x * view_size.y) / float(1600 * 900)
	_expect(lit_samples > int(9000.0 * sample_scale), "%s should contain the painted scene rather than a black frame" % label)
	if ink_region != "none":
		_expect(ink_samples > int(12.0 * sample_scale), "%s should contain rendered localized glyphs" % label)


func _verify_final_fade(image: Image, label: String, view_size: Vector2i) -> void:
	_expect(image != null and image.get_size() == view_size, "%s capture should match its requested resolution" % label)
	if image == null or image.is_empty():
		return
	var bright_chapter_samples := 0
	var y_start := int(float(image.get_height()) * 0.32)
	var y_end := int(float(image.get_height()) * 0.68)
	for y in range(y_start, y_end, 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).v > 0.08:
				bright_chapter_samples += 1
	_expect(bright_chapter_samples == 0, "%s should fully obscure chapter glyphs before the host disappears" % label)


func _sampled_difference(first: Image, second: Image) -> float:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0.0
	var total := 0.0
	var count := 0
	var start_x := int(float(first.get_width()) * 0.08)
	var end_x := int(float(first.get_width()) * 0.92)
	var start_y := int(float(first.get_height()) * 0.04)
	var end_y := int(float(first.get_height()) * 0.72)
	for y in range(start_y, end_y, 12):
		for x in range(start_x, end_x, 12):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			count += 3
	return total / float(maxi(1, count))


func _cleanup_progress_path(path: String) -> void:
	for candidate in [path, path.trim_suffix(".cfg") + StoryCinematicProgressStore.BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _finish() -> void:
	LanguageSettings.set_test_locale_override("")
	for failure in _failures:
		push_error(failure)
	print("[HanMiryangPrologueQA] evidence: %s" % _out_dir)
	print("[HanMiryangPrologueQA] result: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
