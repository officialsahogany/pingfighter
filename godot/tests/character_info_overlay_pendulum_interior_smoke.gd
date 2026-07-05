extends SceneTree

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayPendulumInterior := preload("res://scripts/hud/character_info_overlay_pendulum_interior.gd")
const LingpetDecoder := preload("res://scripts/lingpet/lingpet_decoder.gd")
const LingpetLanguageRichText := preload("res://scripts/lingpet/lingpet_language_rich_text.gd")
const LingpetLanguageCatalog := preload("res://scripts/lingpet/lingpet_language_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(1280.0, 720.0)
const PANEL_RECT := Rect2(Vector2(210.0, 30.0), Vector2(860.0, 660.0))

var _failures: Array[String] = []


class FakePlazaSaveStore:
	extends RefCounted

	var decoder_level := 0
	var read_count := 0

	func get_decoder_level() -> int:
		read_count += 1
		return decoder_level


class FakeRegistry:
	extends RefCounted

	var plaza_save_store := FakePlazaSaveStore.new()

	func get_instance(key: String) -> Object:
		if key == "plaza_save_store":
			return plaza_save_store
		return null


class FakeOwner:
	extends RefCounted

	var lingpet_id := "maribo"
	var lingpet_state := "companion"
	var lingpet_ring_core_tier := 1
	var lingpet_affinity_level := 2
	var lingpet_affinity_points := 12.0
	var lingpet_affinity_next_requirement := 20.0
	var lingpet_affinity_chip_count := 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))


class PendulumLayoutProbe:
	extends Control

	var module: Object
	var probe_font: Font

	func _draw() -> void:
		if module != null:
			module.draw(self, probe_font, PANEL_RECT, VIEW_SIZE)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_module_open_contract()
	_verify_shell_asset_contract()
	_verify_modal_shell_geometry()
	_verify_polish_layout_contract()
	_verify_overlay_click_and_close_flow()
	_verify_locked_ring_core_does_not_open()
	_verify_wander_containment()
	_verify_ground_wander_pauses()
	_verify_flight_wander_is_2d()
	_verify_speech_color_unified()
	_verify_partial_decode_interleaves_korean()
	await _verify_dynamic_draw_hit_rects()

	if _failures.is_empty():
		print("character_info_overlay_pendulum_interior_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_module_open_contract() -> void:
	var snapshot := {
		"state": "companion",
		"pet_id": "maribo",
		"ring_core_tier": 1,
	}
	_expect(CharacterInfoOverlayPendulumInterior.can_open_snapshot(snapshot), "equipped ring core companion should open the pendulum interior")
	_expect(not CharacterInfoOverlayPendulumInterior.can_open_snapshot({"state": "companion", "pet_id": "maribo", "ring_core_tier": 0}), "locked ring core should not open the pendulum interior")
	_expect(not CharacterInfoOverlayPendulumInterior.can_open_snapshot({"state": "egg", "pet_id": "maribo", "ring_core_tier": 1}), "egg state should not open the pendulum interior")

	var registry := FakeRegistry.new()
	registry.plaza_save_store.decoder_level = LingpetDecoder.MAX_DECODER_LEVEL
	var module := CharacterInfoOverlayPendulumInterior.new()
	_expect(module.open(snapshot, FakeOwner.new(), registry), "pendulum interior should open from a valid snapshot")
	_expect(module.is_active(), "opened pendulum interior should be active")
	_expect(module.has_shell_texture_for_tests(), "pendulum shell texture should be prewarmed before draw")
	_expect(module.get_ring_core_tier_for_tests() == 1, "pendulum interior should display the current run ring-core tier")
	_expect(module.get_decoder_level_for_tests() == 1, "T1 ring core should decode at level 1 even if the save decoder is maxed")
	_expect(registry.plaza_save_store.read_count == 0, "pendulum interior should not read the permanent decoder level")
	_expect(module.get_decoder_caption_for_tests().find("T1") >= 0 and module.get_decoder_caption_for_tests().find("20%") >= 0, "T1 caption should show ring-core tier and 20 percent decode")
	var plain_text := module.get_current_plain_text_for_tests()
	_expect(plain_text.strip_edges() != "", "pendulum interior should build an initial Lingpet-language line")
	_expect(plain_text.find("lingpet.language.") < 0, "ring-core decoder should not leak translation keys in generic lines")

	var t5_snapshot := snapshot.duplicate()
	t5_snapshot["ring_core_tier"] = 5
	var t5_module := CharacterInfoOverlayPendulumInterior.new()
	_expect(t5_module.open(t5_snapshot, FakeOwner.new(), registry), "T5 ring core should open the pendulum interior")
	_expect(t5_module.get_decoder_level_for_tests() == LingpetDecoder.MAX_DECODER_LEVEL, "T5 ring core should reach max decoder level")
	_expect(t5_module.get_decoder_caption_for_tests().find("T5") >= 0 and t5_module.get_decoder_caption_for_tests().find("100%") >= 0, "T5 caption should show 100 percent decode")

	var t6_snapshot := snapshot.duplicate()
	t6_snapshot["ring_core_tier"] = 6
	var t6_module := CharacterInfoOverlayPendulumInterior.new()
	_expect(t6_module.open(t6_snapshot, FakeOwner.new(), registry), "T6 ring core should open the pendulum interior")
	_expect(t6_module.get_ring_core_tier_for_tests() == 6, "T6 ring core should keep T6 in the display tier")
	_expect(t6_module.get_decoder_level_for_tests() == LingpetDecoder.MAX_DECODER_LEVEL, "T6 ring core should cap decode at level 5")
	_expect(t6_module.get_decoder_caption_for_tests().find("T6") >= 0 and t6_module.get_decoder_caption_for_tests().find("100%") >= 0, "T6 caption should show T6 while capping decode at 100 percent")

	var phase_before := module.get_walk_phase_for_tests()
	module.advance(0.0)
	_expect(is_equal_approx(module.get_motion_speed_ratio_for_tests(), 0.0), "zero-delta update should not report motion")
	_expect(is_equal_approx(module.get_walk_phase_for_tests(), phase_before), "zero-delta update should not advance the walk phase")
	module.advance(0.25)
	_expect(module.get_motion_speed_ratio_for_tests() > 0.01, "positive movement delta should report real motion")
	_expect(module.get_walk_phase_for_tests() > phase_before, "walk phase should advance only when the pet moves")


func _verify_shell_asset_contract() -> void:
	var shell_path := CharacterInfoOverlayPendulumInterior.get_shell_texture_path_for_tests()
	_expect(shell_path == "res://assets/ui/hud/lingpet_pendulum_shell_imagegen_v1.png", "pendulum shell should use the accepted Godot HUD asset path")
	_expect(FileAccess.file_exists(shell_path), "pendulum shell PNG should exist under godot/assets")
	var shell_texture := ProjectResourceLoader.load_imported_texture(shell_path, "", "")
	_expect(shell_texture != null, "pendulum shell PNG should load through ProjectResourceLoader imported texture path")
	if shell_texture != null:
		_expect(shell_texture.get_width() == 747 and shell_texture.get_height() == 1076, "pendulum shell should preserve the accepted 747x1076 runtime size")
	var import_path := shell_path + ".import"
	_expect(FileAccess.file_exists(import_path), "pendulum shell PNG should have a Godot .import sidecar")
	var import_text := FileAccess.get_file_as_string(import_path) if FileAccess.file_exists(import_path) else ""
	_expect(import_text.find(".ctex") >= 0, "pendulum shell import sidecar should point at a .ctex artifact")

	var source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_pendulum_interior.gd")
	var draw_start := source.find("func draw(")
	var draw_end := source.find("\n\nstatic func build_modal_rect", draw_start)
	if draw_start >= 0 and draw_end > draw_start:
		var draw_body := source.substr(draw_start, draw_end - draw_start)
		_expect(draw_body.find("load_texture") < 0 and draw_body.find("_prewarm_shell_texture") < 0, "pendulum draw path should use the prewarmed shell texture without loading")
		_expect(draw_body.find("_draw_shell_texture") >= 0, "pendulum draw path should blit the accepted shell texture")
	_expect(source.find("ProjectResourceLoader.load_imported_texture(") >= 0, "pendulum shell prewarm should prefer the Godot imported .ctex texture")
	_expect(source.find("TRANSLATIONS_KO") < 0 and source.find("TRANSLATIONS_EN") < 0, "pendulum language tokens should be registered in LanguageSettings instead of inline dictionaries")
	_expect(source.find("translate_text(") < 0, "pendulum chrome should use stable LanguageSettings.translate keys, not raw Korean translate_text")
	_expect(source.find("plaza_save_store") < 0 and source.find(".get_decoder_level(") < 0, "pendulum decoder should derive from the current run ring-core tier, not the permanent save decoder")
	_expect(source.find("decoder_level_for_ring_core_tier") >= 0, "pendulum decoder should keep the ring-core-tier conversion as an explicit helper")
	var frame_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	_expect(frame_source.find("pendulum.draw(canvas, font, panel_rect, view_size, mouse_pos)") >= 0, "pendulum presenter should pass the live mouse position for close-button hover")


func _verify_modal_shell_geometry() -> void:
	var modal_rect := CharacterInfoOverlayPendulumInterior.build_modal_rect(PANEL_RECT, VIEW_SIZE)
	var expected_aspect := CharacterInfoOverlayPendulumInterior.get_shell_aspect_ratio_for_tests()
	_expect_near(modal_rect.size.x / modal_rect.size.y, expected_aspect, 0.001, "pendulum modal should preserve the accepted portrait shell aspect")
	_expect(modal_rect.size.y <= 620.01, "pendulum modal should respect the approved max portrait height")
	_expect(modal_rect.size.y <= VIEW_SIZE.y - 80.0 + 0.01, "pendulum modal should leave the approved vertical viewport margin")

	var screen_rect := CharacterInfoOverlayPendulumInterior.screen_rect_for_tests(modal_rect)
	var walk_band_rect := CharacterInfoOverlayPendulumInterior.walk_band_rect_for_tests(modal_rect)
	_expect_near(screen_rect.position.x, modal_rect.position.x + modal_rect.size.x * (98.0 / 747.0), 0.02, "pendulum screen anchor x should match the approved PNG manifest")
	_expect_near(screen_rect.position.y, modal_rect.position.y + modal_rect.size.y * (310.0 / 1076.0), 0.02, "pendulum screen anchor y should match the approved PNG manifest")
	_expect_near(screen_rect.size.x, modal_rect.size.x * (551.0 / 747.0), 0.02, "pendulum screen width should match the approved PNG manifest")
	_expect_near(screen_rect.size.y, modal_rect.size.y * (475.0 / 1076.0), 0.02, "pendulum screen height should match the approved PNG manifest")
	_expect(walk_band_rect.position.y > screen_rect.position.y and walk_band_rect.end.y <= screen_rect.end.y + 8.0, "pendulum walk band should sit inside the lower glass screen area")
	_expect(walk_band_rect.size.x < screen_rect.size.x, "pendulum walk band should leave side inset for the rounded glass window")


func _verify_polish_layout_contract() -> void:
	var modal_rect := CharacterInfoOverlayPendulumInterior.build_modal_rect(PANEL_RECT, VIEW_SIZE)
	var screen_rect := CharacterInfoOverlayPendulumInterior.screen_rect_for_tests(modal_rect)
	var walk_band_rect := CharacterInfoOverlayPendulumInterior.walk_band_rect_for_tests(modal_rect)
	var left_pet := Vector2(walk_band_rect.position.x + 24.0, walk_band_rect.get_center().y)
	var right_pet := Vector2(walk_band_rect.end.x - 24.0, walk_band_rect.get_center().y)
	var left_speech := CharacterInfoOverlayPendulumInterior.speech_rect_for_tests(screen_rect, left_pet)
	var right_speech := CharacterInfoOverlayPendulumInterior.speech_rect_for_tests(screen_rect, right_pet)
	_expect(right_speech.position.x > left_speech.position.x + 40.0, "speech bubble should track the walking companion horizontally")
	_expect(left_speech.position.x >= screen_rect.position.x + CharacterInfoOverlayPendulumInterior.SPEECH_SCREEN_INSET - 0.01, "left-tracking speech bubble should stay inside the glass inset")
	_expect(right_speech.end.x <= screen_rect.end.x - CharacterInfoOverlayPendulumInterior.SPEECH_SCREEN_INSET + 0.01, "right-tracking speech bubble should stay inside the glass inset")
	_expect(left_speech.position.y >= screen_rect.position.y and left_speech.end.y < left_pet.y, "speech bubble should stay in the upper glass band above the companion")

	var tail := CharacterInfoOverlayPendulumInterior.speech_tail_for_tests(left_speech, screen_rect, left_pet)
	_expect(tail.size() == 3, "speech tail should be a filled triangle")
	if tail.size() == 3:
		_expect_near(tail[2].x, left_pet.x, 0.01, "speech tail tip should track the companion x position")
		_expect_near(tail[2].y, left_pet.y - CharacterInfoOverlayPendulumInterior.COMPANION_RADIUS - 4.0, 0.01, "speech tail tip should point just above the companion head")
		_expect(not Geometry2D.triangulate_polygon(tail).is_empty(), "speech tail should remain triangulable at the patrol edge")

	var close_rect := CharacterInfoOverlayPendulumInterior.close_rect_for_tests(modal_rect)
	var expected_close_center := modal_rect.position + Vector2(
		modal_rect.size.x * CharacterInfoOverlayPendulumInterior.CLOSE_ANCHOR_NORM.x,
		modal_rect.size.y * CharacterInfoOverlayPendulumInterior.CLOSE_ANCHOR_NORM.y
	)
	_expect_near(close_rect.get_center().distance_to(expected_close_center), 0.0, 0.01, "close button should stay docked to its normalized shell anchor")
	_expect_near(close_rect.size.x, CharacterInfoOverlayPendulumInterior.CLOSE_RADIUS * 2.0, 0.01, "close button should use the compact circular diameter")
	_expect(CharacterInfoOverlayPendulumInterior.CLOSE_ANCHOR_NORM.x >= 0.75 and CharacterInfoOverlayPendulumInterior.CLOSE_ANCHOR_NORM.x <= 0.83, "close button x anchor should remain on the upper-right shell rim")
	_expect(CharacterInfoOverlayPendulumInterior.CLOSE_ANCHOR_NORM.y >= 0.25 and CharacterInfoOverlayPendulumInterior.CLOSE_ANCHOR_NORM.y <= 0.31, "close button y anchor should remain on the upper-right shell rim instead of floating above it")

	var fill: Color = CharacterInfoOverlayPendulumInterior.SPEECH_FILL_COLOR
	var decoded: Color = LingpetLanguageRichText.DECODED_COLOR
	_expect(fill.r < 0.10 and fill.g < 0.12 and fill.b < 0.16, "speech fill should use the approved dark slate-teal glass")
	_expect(decoded.get_luminance() - fill.get_luminance() > 0.70, "decoded Lingpet text should have strong luminance contrast on the dark glass")
	_expect(CharacterInfoOverlayPendulumInterior.CLOSE_HOVER_FILL_COLOR.get_luminance() > CharacterInfoOverlayPendulumInterior.CLOSE_FILL_COLOR.get_luminance(), "close hover should brighten the docked button fill")
	_expect(CharacterInfoOverlayPendulumInterior.CLOSE_HOVER_GOLD_COLOR.get_luminance() > CharacterInfoOverlayPendulumInterior.CLOSE_GOLD_COLOR.get_luminance(), "close hover should brighten the gold rim and X")


func _verify_dynamic_draw_hit_rects() -> void:
	var module := CharacterInfoOverlayPendulumInterior.new()
	var snapshot := {
		"state": "companion",
		"pet_id": "maribo",
		"ring_core_tier": 1,
	}
	_expect(module.open(snapshot, FakeOwner.new(), FakeRegistry.new()), "dynamic layout probe should open the pendulum interior")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := PendulumLayoutProbe.new()
	probe.size = VIEW_SIZE
	probe.module = module
	probe.probe_font = ThemeDB.fallback_font
	viewport.add_child(probe)
	probe.queue_redraw()
	for _idx in range(3):
		await process_frame

	var speech_rect := module.get_speech_rect_for_tests()
	var close_rect := module.get_close_rect_for_tests()
	var companion_center := module.get_companion_center_for_tests()
	_expect(speech_rect.has_area(), "draw should publish the dynamic speech hit rect")
	_expect(close_rect.has_area(), "draw should publish the docked close hit rect")
	_expect(companion_center != Vector2.ZERO, "draw should publish the rendered companion center")
	_expect(module.handle_mouse_button(speech_rect.get_center(), MOUSE_BUTTON_LEFT) == &"line", "clicking the drawn speech rect should advance the line")
	_expect(module.handle_mouse_button(close_rect.get_center(), MOUSE_BUTTON_LEFT) == &"closed", "clicking the drawn circular close rect should close the pendulum")
	_expect(not module.is_active(), "docked close button should leave the pendulum inactive")
	viewport.queue_free()


func _verify_overlay_click_and_close_flow() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_ring_core_tier = 3
	var registry := FakeRegistry.new()
	registry.plaza_save_store.decoder_level = LingpetDecoder.MAX_DECODER_LEVEL
	var overlay := CharacterInfoOverlay.new()
	overlay.open(owner, registry)
	var click_rects: Array[Rect2] = [Rect2(Vector2(10.0, 10.0), Vector2(40.0, 40.0))]
	overlay._last_lingpet_ring_core_rects = click_rects
	_expect(_send_click(overlay, owner, registry, Vector2(24.0, 24.0)), "ring core click should be handled")
	_expect(bool(overlay._pendulum_interior.is_active()), "ring core click should activate the pendulum interior")
	_expect(overlay._pendulum_interior.get_ring_core_tier_for_tests() == 3, "overlay-opened pendulum should keep the current run ring-core tier")
	_expect(overlay._pendulum_interior.get_decoder_level_for_tests() == 3, "overlay-opened pendulum should decode from the current run ring-core tier")
	_expect(registry.plaza_save_store.read_count == 0, "overlay-opened pendulum should not read the permanent decoder level")

	_expect(_send_escape(overlay, owner, registry), "first escape should be handled by character info")
	_expect(not bool(overlay._pendulum_interior.is_active()), "first escape should close only the pendulum interior")
	_expect(overlay.is_active(), "closing the pendulum interior should keep character info open")
	_expect(_send_escape(overlay, owner, registry), "second escape should be handled by character info")
	_expect(not overlay.is_active(), "second escape should close the character info overlay")


func _verify_wander_containment() -> void:
	# #1 - the full sprite footprint (half = draw_size * 0.5) must stay inside the
	# glass. draw_size 100 (half 50) exceeds the old flat inset cap (<=46), so this
	# FAILS on the pre-fix flat-inset code and passes only with the footprint-aware inset.
	var modal_rect := CharacterInfoOverlayPendulumInterior.build_modal_rect(PANEL_RECT, VIEW_SIZE)
	var screen_rect := CharacterInfoOverlayPendulumInterior.screen_rect_for_tests(modal_rect)
	var walk_band_rect := CharacterInfoOverlayPendulumInterior.walk_band_rect_for_tests(modal_rect)
	var draw_size := 100.0
	var half := draw_size * 0.5
	var left_center := CharacterInfoOverlayPendulumInterior.resolve_companion_center(false, 0.0, 1.0, walk_band_rect, screen_rect, draw_size)
	var right_center := CharacterInfoOverlayPendulumInterior.resolve_companion_center(false, 1.0, 1.0, walk_band_rect, screen_rect, draw_size)
	_expect(left_center.x - half >= walk_band_rect.position.x - 0.01, "ground companion left edge must stay inside the glass walk band (no wall overflow)")
	_expect(right_center.x + half <= walk_band_rect.end.x + 0.01, "ground companion right edge must stay inside the glass walk band (no wall overflow)")
	var flight_min := CharacterInfoOverlayPendulumInterior.resolve_companion_center(true, 0.0, 0.0, walk_band_rect, screen_rect, draw_size)
	var flight_max := CharacterInfoOverlayPendulumInterior.resolve_companion_center(true, 1.0, 1.0, walk_band_rect, screen_rect, draw_size)
	_expect(flight_min.x - half >= screen_rect.position.x - 0.01 and flight_min.y - half >= screen_rect.position.y - 0.01, "flight companion must stay inside the glass screen at the min corner")
	_expect(flight_max.x + half <= screen_rect.end.x + 0.01 and flight_max.y + half <= screen_rect.end.y + 0.01, "flight companion must stay inside the glass screen at the max corner")


func _verify_ground_wander_pauses() -> void:
	# #2 - ground pet strolls to random spots and PAUSES between them, so the motion
	# ratio must reach ~0 (idle) on some frames and >0 on others. A constant ping-pong
	# would never report a pause frame.
	var module := CharacterInfoOverlayPendulumInterior.new()
	_expect(module.open({"state": "companion", "pet_id": "maribo", "ring_core_tier": 1}, FakeOwner.new(), FakeRegistry.new()), "wander test should open a ground pet pendulum")
	var saw_pause := false
	var saw_move := false
	for _idx in range(400):
		module.advance(0.08)
		if module.get_motion_speed_ratio_for_tests() <= 0.01:
			saw_pause = true
		else:
			saw_move = true
	_expect(saw_move, "ground companion should actually walk during the wander")
	_expect(saw_pause, "ground companion should pause between random strolls (not a constant ping-pong)")


func _verify_flight_wander_is_2d() -> void:
	# #3 - flight pets roam the glass in 2D (Y varies with the vertical wander input);
	# ground pets stay locked to the floor line.
	var modal_rect := CharacterInfoOverlayPendulumInterior.build_modal_rect(PANEL_RECT, VIEW_SIZE)
	var screen_rect := CharacterInfoOverlayPendulumInterior.screen_rect_for_tests(modal_rect)
	var walk_band_rect := CharacterInfoOverlayPendulumInterior.walk_band_rect_for_tests(modal_rect)
	var flight_low := CharacterInfoOverlayPendulumInterior.resolve_companion_center(true, 0.5, 0.0, walk_band_rect, screen_rect, 70.0)
	var flight_high := CharacterInfoOverlayPendulumInterior.resolve_companion_center(true, 0.5, 1.0, walk_band_rect, screen_rect, 70.0)
	_expect(absf(flight_low.y - flight_high.y) > 1.0, "flight companion should roam vertically (2D wander), not lock to the floor line")
	var ground_low := CharacterInfoOverlayPendulumInterior.resolve_companion_center(false, 0.5, 0.0, walk_band_rect, screen_rect, 70.0)
	var ground_high := CharacterInfoOverlayPendulumInterior.resolve_companion_center(false, 0.5, 1.0, walk_band_rect, screen_rect, 70.0)
	_expect(is_equal_approx(ground_low.y, ground_high.y), "ground companion should stay on the floor line regardless of the vertical wander input")
	var flight_module := CharacterInfoOverlayPendulumInterior.new()
	_expect(flight_module.open({"state": "companion", "pet_id": "lunabi", "ring_core_tier": 1}, FakeOwner.new(), FakeRegistry.new()), "flight pet should open the pendulum")
	_expect(flight_module.is_flight_for_tests(), "sortie_flight pet (lunabi) should drive the 2D flight wander")
	var ground_module := CharacterInfoOverlayPendulumInterior.new()
	_expect(ground_module.open({"state": "companion", "pet_id": "maribo", "ring_core_tier": 1}, FakeOwner.new(), FakeRegistry.new()), "ground pet should open the pendulum")
	_expect(not ground_module.is_flight_for_tests(), "patrol pet (maribo) should stay on the ground wander")


func _verify_speech_color_unified() -> void:
	# #4 - Korean (decoded) and Lingpet glyphs render in one unified dialogue color;
	# the emotion seal keeps its own accent. Reverse guard: shared build_runs still
	# differentiates the two, so the pendulum-local override is meaningful.
	var glyph_color := CharacterInfoOverlayPendulumInterior.resolve_speech_run_color_for_tests({"kind": "glyph", "color": LingpetLanguageRichText.GLYPH_COLOR})
	var ko_color := CharacterInfoOverlayPendulumInterior.resolve_speech_run_color_for_tests({"kind": "ko", "color": LingpetLanguageRichText.DECODED_COLOR})
	_expect(glyph_color.is_equal_approx(ko_color), "pendulum speech bubble should render Korean and Lingpet glyphs in one unified color")
	_expect(not LingpetLanguageRichText.GLYPH_COLOR.is_equal_approx(LingpetLanguageRichText.DECODED_COLOR), "reverse guard: shared build_runs still differentiates glyph vs decoded so the pendulum unify is meaningful")
	var emotion_color := CharacterInfoOverlayPendulumInterior.resolve_speech_run_color_for_tests({"kind": "emotion", "color": LingpetLanguageRichText.EMOTION_DECODED_COLOR})
	_expect(emotion_color.is_equal_approx(LingpetLanguageRichText.EMOTION_DECODED_COLOR), "emotion seal keeps its distinct gold accent")


func _verify_partial_decode_interleaves_korean() -> void:
	# The decoded Korean words should be sprinkled AMONG the Lingpet glyphs at partial
	# decode, not clustered at the front. The generic-line token tiers are authored in a
	# scattered (non-ascending) order so a glyph precedes a Korean word at level 2.
	# Reverse guard: ascending-tier authoring makes the decoded tokens a front prefix,
	# so no glyph precedes a Korean word -> this fails.
	var lines := LingpetLanguageCatalog.get_generic_lines("")
	_expect(not lines.is_empty(), "generic pendulum lines should exist for the interleave check")
	for line_value in lines:
		var line: Dictionary = line_value as Dictionary
		var runs := LingpetLanguageRichText.build_runs(line, 2, Callable())
		var seen_glyph := false
		var glyph_before_korean := false
		var ko_count := 0
		var glyph_count := 0
		for run_value in runs:
			var run: Dictionary = run_value as Dictionary
			if not bool(run.get("visible", true)):
				continue
			var kind := str(run.get("kind", ""))
			if kind == "glyph":
				seen_glyph = true
				glyph_count += 1
			elif kind == "ko":
				ko_count += 1
				if seen_glyph:
					glyph_before_korean = true
		var line_id := str(line.get("id", ""))
		_expect(ko_count > 0 and glyph_count > 0, "partial decode (level 2) should mix Korean and glyphs for %s" % line_id)
		_expect(glyph_before_korean, "decoded Korean should be interspersed among glyphs (a glyph precedes a Korean word), not front-loaded, for %s" % line_id)


func _verify_locked_ring_core_does_not_open() -> void:
	var owner := FakeOwner.new()
	owner.lingpet_ring_core_tier = 0
	var registry := FakeRegistry.new()
	var overlay := CharacterInfoOverlay.new()
	overlay.open(owner, registry)
	var click_rects: Array[Rect2] = [Rect2(Vector2(10.0, 10.0), Vector2(40.0, 40.0))]
	overlay._last_lingpet_ring_core_rects = click_rects
	_expect(_send_click(overlay, owner, registry, Vector2(24.0, 24.0)), "locked ring core click should still be consumed by the active overlay")
	_expect(not bool(overlay._pendulum_interior.is_active()), "locked ring core should not activate the pendulum interior")


func _send_click(overlay: Object, owner: Object, registry: Object, position: Vector2) -> bool:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return bool(overlay.handle_input(event, owner, registry, Vector2(1280.0, 720.0)))


func _send_escape(overlay: Object, owner: Object, registry: Object) -> bool:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return bool(overlay.handle_input(event, owner, registry, Vector2(1280.0, 720.0)))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (actual %.4f, expected %.4f)" % [message, actual, expected])
