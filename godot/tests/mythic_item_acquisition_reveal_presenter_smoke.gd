extends SceneTree

const RevealPresenter := preload("res://scripts/items/mythic_item_acquisition_reveal_presenter.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_animated_source_rects()
	_verify_icon_node_application()
	_verify_reveal_text_layout()
	_verify_content_and_localization_ownership()
	if _failures.is_empty():
		print("mythic_item_acquisition_reveal_presenter_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_animated_source_rects() -> void:
	var texture_size := Vector2(800.0, 100.0)
	_expect(
		RevealPresenter.compute_icon_source_rect(texture_size, 8, 110, 2.0, 0) == Rect2(2.0, 2.0, 96.0, 96.0),
		"animated icon should start at the first inset frame"
	)
	_expect(
		RevealPresenter.compute_icon_source_rect(texture_size, 8, 110, 2.0, 220) == Rect2(202.0, 2.0, 96.0, 96.0),
		"animated icon should select frame two at 220ms"
	)
	_expect(
		RevealPresenter.compute_icon_source_rect(texture_size, 8, 110, 2.0, 880) == Rect2(2.0, 2.0, 96.0, 96.0),
		"animated icon frame selection should wrap"
	)
	_expect(
		RevealPresenter.compute_icon_source_rect(texture_size, 8, 110, 100.0, 0) == Rect2(42.0, 42.0, 16.0, 16.0),
		"source inset should retain the 42-percent safety clamp"
	)
	_expect(
		RevealPresenter.compute_icon_source_rect(Vector2.ZERO, 8, 110, 0.0, 0) == Rect2(),
		"empty texture size should return an empty source rect"
	)
	_expect_close(RevealPresenter.compute_icon_fit(Vector2(96.0, 96.0), 0.5), 0.5, "half-scale 96px icon fit")


func _verify_icon_node_application() -> void:
	var image := Image.create(800, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var icon := Sprite2D.new()
	var presenter := RevealPresenter.new()
	presenter.apply_icon_texture(icon, texture, 8, 110, 2.0, 220)
	_expect(icon.texture == texture and icon.region_enabled, "animated icon application should bind texture and enable region")
	_expect(icon.region_rect == Rect2(202.0, 2.0, 96.0, 96.0), "animated icon application should bind injected-time source rect")
	presenter.apply_icon_visual(
		icon,
		texture,
		8,
		110,
		2.0,
		220,
		0.5,
		0.4,
		Vector2(380.0, 370.0),
		true
	)
	_expect(icon.scale.is_equal_approx(Vector2(0.5, 0.5)), "icon visual should fit the inset frame to 48px")
	_expect_close(icon.modulate.a, 0.4, "icon visual alpha")
	_expect(icon.position == Vector2(380.0, 370.0), "reveal icon visual should apply its floating position")
	presenter.apply_icon_texture(icon, null, 1, 33, 0.0, 0)
	_expect(icon.texture == null and not icon.region_enabled, "missing icon texture should clear sprite and region")
	icon.free()


func _verify_reveal_text_layout() -> void:
	var band := ColorRect.new()
	var name_label := Label.new()
	var description_label := Label.new()
	var presenter := RevealPresenter.new()
	presenter.sync_text_content(name_label, description_label, true, "오딘의 눈", "첫 번째 설명")
	presenter.apply_text_state(
		band,
		name_label,
		description_label,
		true,
		RevealPresenter.REVEAL_PHASE,
		0.225,
		760.0,
		5.0
	)
	_expect(band.position == Vector2(100.0, 461.0) and band.size == Vector2(560.0, 112.0), "text band should preserve centered reveal placement")
	_expect(name_label.position == Vector2(116.0, 467.0) and name_label.size == Vector2(528.0, 36.0), "name label should preserve padded layout")
	_expect(description_label.position == Vector2(116.0, 501.0) and description_label.size == Vector2(528.0, 56.0), "description should preserve the 528x56 wrapped lane")
	_expect(band.visible and name_label.visible and description_label.visible, "half-reveal text should be visible")
	_expect_close(band.modulate.a, 0.5, "reveal text alpha")
	_expect_close(RevealPresenter.compute_text_alpha(RevealPresenter.ABSORB_PHASE, 0.175), 0.5, "absorb text fade alpha")
	_expect_close(RevealPresenter.compute_text_alpha("impact", 0.0), 0.0, "non-text phase alpha")
	presenter.sync_text_content(name_label, description_label, false, "ignored", "ignored")
	presenter.apply_text_alpha(band, name_label, description_label, false, 1.0)
	_expect(name_label.text == "" and description_label.text == "", "disabled reveal should clear text content")
	_expect(not band.visible and not name_label.visible and not description_label.visible, "disabled reveal should hide every text node")
	band.free()
	name_label.free()
	description_label.free()


func _verify_content_and_localization_ownership() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_reveal_presenter.gd")
	var host_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
	var factory_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_acquisition_presentation_factory.gd")
	_expect(presenter_source.find("Time.get_ticks_msec") < 0, "presenter frame math should use injected time")
	_expect(presenter_source.find("LanguageSettings") < 0 and presenter_source.find("ProjectResourceLoader") < 0, "presenter should not own localization or texture loading")
	var display_name_body := SourceContractFunctionBody.extract(host_source, "func _resolve_display_name(")
	var description_body := SourceContractFunctionBody.extract(host_source, "func _resolve_reveal_description(")
	_expect(display_name_body.find("LanguageSettings.translate_text") >= 0, "host should retain localized display-name resolution")
	_expect(description_body.find("LanguageSettings.translate_text") >= 0, "host should retain localized reveal-description resolution")
	_expect(host_source.find("RevealPresenter.compute_icon_source_rect(") >= 0, "host source-rect wrapper should delegate presenter math")
	_expect(host_source.find("_reveal_presenter.apply_icon_visual(") >= 0, "host should delegate per-frame icon presentation")
	_expect(host_source.find("_reveal_presenter.apply_text_state(") >= 0, "host should delegate reveal text layout")
	_expect(host_source.find("var frame_width") < 0 and host_source.find("REVEAL_TEXT_BAND_SIZE") < 0, "host should not retain extracted frame or text-layout formulas")
	_expect(factory_source.find("description_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY") >= 0, "description label should retain wrap-aware rendering")


func _expect_close(actual: float, expected: float, label: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s should remain exact (expected %.6f, found %.6f)" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
