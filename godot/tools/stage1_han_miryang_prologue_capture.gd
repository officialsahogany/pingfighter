extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PrologueText := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_text.gd")
const ProloguePresentation := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_presentation.gd")
const PrologueOverlayHost := preload("res://scripts/stages/stage1/stage1_han_miryang_prologue_overlay_host.gd")

const VIEW_SIZES := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
const OUT_ROOT := "C:/Users/woduq/bosspong_backups/qa_evidence"

var _out_dir := ""
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("stage1_han_miryang_prologue_capture must run without --headless")
		quit(1)
		return
	_out_dir = "%s/han_miryang_prologue_%d_%d" % [OUT_ROOT, Time.get_ticks_usec(), OS.get_process_id()]
	var mkdir_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	_expect(mkdir_error == OK, "evidence directory should be created")
	var first_texture := ProjectResourceLoader.load_texture(ProloguePresentation.FIRST_TEXTURE_PATH)
	var strike_texture := ProjectResourceLoader.load_texture(ProloguePresentation.STRIKE_TEXTURE_PATH)
	var second_texture := ProjectResourceLoader.load_texture(ProloguePresentation.SECOND_TEXTURE_PATH)
	_expect(first_texture != null and strike_texture != null and second_texture != null, "all three generated prologue key arts should load")
	if first_texture == null or strike_texture == null or second_texture == null:
		_finish()
		return

	for view_size: Vector2i in VIEW_SIZES:
		var prefix := "ko_%dx%d" % [view_size.x, view_size.y]
		var coronation := await _capture(prefix + "_coronation", view_size, "ko", 8.6, first_texture, strike_texture, second_texture, true)
		var strike := await _capture(prefix + "_strike_no_tablet", view_size, "ko", 18.0, first_texture, strike_texture, second_texture, true)
		var tablet := await _capture(prefix + "_tablet_reveal", view_size, "ko", 21.1, first_texture, strike_texture, second_texture, true)
		var chapter := await _capture(prefix + "_chapter", view_size, "ko", 35.5, first_texture, strike_texture, second_texture, false)
		_verify_frame(coronation, prefix + " coronation", view_size, true)
		_verify_frame(strike, prefix + " strike", view_size, true)
		_verify_frame(tablet, prefix + " tablet", view_size, true)
		_verify_frame(chapter, prefix + " chapter", view_size, false)
		_expect(_sampled_difference(coronation, strike) > 0.05, "%s strike should differ visibly from coronation" % prefix)
		_expect(_sampled_difference(strike, tablet) > 0.012, "%s tablet should materialize over the stable strike plate" % prefix)

	for locale in ["ja", "zh"]:
		var view_size: Vector2i = VIEW_SIZES[0]
		var localized := await _capture(
			"%s_%dx%d_subtitle" % [locale, view_size.x, view_size.y],
			view_size,
			locale,
			17.0,
			first_texture,
			strike_texture,
			second_texture,
			true
		)
		_verify_frame(localized, locale + " subtitle", view_size, true)
	_finish()


func _capture(
	name: String,
	view_size: Vector2i,
	locale: String,
	elapsed: float,
	first_texture: Texture2D,
	strike_texture: Texture2D,
	second_texture: Texture2D,
	expect_subtitle: bool
) -> Image:
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
	host.begin(first_texture, strike_texture, second_texture, PrologueText.get_copy(locale))
	host.sync_timeline(elapsed, 0.0, PrologueText.get_segment_at(PrologueText.get_segments(locale), elapsed), true)
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("visible", false)), "%s host should be visible" % name)
	if expect_subtitle:
		_expect(str(snapshot.get("subtitle", "")) != "", "%s should show a localized subtitle" % name)
	else:
		_expect(str(snapshot.get("subtitle", "")) == "", "%s chapter card should hide dialogue" % name)
		_expect(bool(snapshot.get("title_centered", false)), "%s chapter card should be centered" % name)
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


func _verify_frame(image: Image, label: String, view_size: Vector2i, expect_subtitle: bool) -> void:
	_expect(image != null and image.get_size() == view_size, "%s capture should match its requested resolution" % label)
	if image == null or image.is_empty():
		return
	var lit_samples := 0
	var subtitle_bright_samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var pixel := image.get_pixel(x, y)
			if pixel.v > 0.08:
				lit_samples += 1
			if y >= int(float(image.get_height()) * 0.76) and pixel.v > 0.72:
				subtitle_bright_samples += 1
	var sample_scale := float(view_size.x * view_size.y) / float(1600 * 900)
	_expect(lit_samples > int(9000.0 * sample_scale), "%s should contain the painted scene rather than a black frame" % label)
	if expect_subtitle:
		_expect(subtitle_bright_samples > int(12.0 * sample_scale), "%s should contain rendered subtitle glyphs" % label)


func _sampled_difference(first: Image, second: Image) -> float:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0.0
	var total := 0.0
	var count := 0
	var start_x := int(float(first.get_width()) * 0.22)
	var end_x := int(float(first.get_width()) * 0.78)
	var start_y := int(float(first.get_height()) * 0.04)
	var end_y := int(float(first.get_height()) * 0.72)
	for y in range(start_y, end_y, 12):
		for x in range(start_x, end_x, 12):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			count += 3
	return total / float(maxi(1, count))


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
