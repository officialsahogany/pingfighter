extends SceneTree

# expect-zero-object-leaks
const DefeatContinueUiRenderer := preload("res://scripts/core/defeat_continue_ui_renderer.gd")
const DefeatContinueVisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_status_and_button_contract()
	_verify_source_ownership_and_draw_order()
	if _failures.is_empty():
		print("defeat_continue_ui_renderer_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_status_and_button_contract() -> void:
	_expect(
		DefeatContinueUiRenderer.resolve_status_mode(true, false, false) == DefeatContinueUiRenderer.StatusMode.PRESENT,
		"present phase must select the confirm status copy"
	)
	_expect(
		DefeatContinueUiRenderer.resolve_status_mode(false, false, false) == DefeatContinueUiRenderer.StatusMode.SHAKING,
		"pre-shatter consuming phase must select the shaking status copy"
	)
	_expect(
		DefeatContinueUiRenderer.resolve_status_mode(false, true, false) == DefeatContinueUiRenderer.StatusMode.CONSUMED,
		"active shatter window must select the consumed status copy"
	)
	_expect(
		DefeatContinueUiRenderer.resolve_status_mode(false, false, true) == DefeatContinueUiRenderer.StatusMode.CONSUMED,
		"completed shatter must keep the consumed status copy"
	)
	var view_size := Vector2(1280.0, 720.0)
	var ui_rect := DefeatContinueUiRenderer.get_button_rect(view_size)
	var projection_rect := DefeatContinueVisualProjection.get_button_rect(view_size)
	_expect(ui_rect == projection_rect, "UI renderer and input projection must share one button rectangle")
	_expect(ui_rect.has_point(Vector2(640.0, 669.0)), "shipped confirm click point must remain inside the button")


func _verify_source_ownership_and_draw_order() -> void:
	var ui_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_ui_renderer.gd")
	var projection_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_visual_projection.gd")
	var cinematic_state_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_cinematic_state.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	var gem_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_gem_renderer.gd")
	var scene_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_scene_renderer.gd")
	var ambient_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_ambient_renderer.gd")
	_expect(ui_source.contains("func draw_header_and_status"), "UI renderer must own header/status drawing")
	_expect(ui_source.contains("func draw_footer"), "UI renderer must own guide/button drawing")
	_expect(ui_source.contains("func _draw_broken_ward_sigil"), "defeat header must use the Hwangyeokjeon broken-ward crest")
	_expect(ui_source.contains("func _draw_cloud_title_rule"), "defeat header must use cloud-scroll title rules")
	_expect(ui_source.contains("HANJI_BAND_TEXTURE_PATH"), "status and gems must sit on the shared Hwangyeokjeon hanji chrome")
	_expect(ui_source.contains("SELECT_BUTTON_TEXTURE_PATH"), "confirm action must reuse the Hwangyeokjeon lacquer button chrome")
	_expect(not ui_source.contains("func _draw_compass_sigil"), "legacy compass ornament must not return to the Hwangyeokjeon defeat screen")
	_expect(not ui_source.contains("func _draw_diamond_marker"), "legacy cyan diamond ornaments must not return to the Hwangyeokjeon defeat screen")
	_expect(ui_source.contains("기회의 보석이 흔들립니다..."), "UI renderer must own shaking copy")
	_expect(ui_source.contains("이번이 마지막 기회입니다."), "UI renderer must own last-chance copy")
	_expect(not ui_source.contains("Dictionary"), "UI renderer must not allocate segment dictionaries per draw")
	_expect(not ui_source.contains("func _process"), "UI renderer must remain caller-clocked")
	_expect(projection_source.contains("func get_button_rect"), "pure projection must own button geometry")
	_expect(cinematic_state_source.contains("DefeatContinueVisualProjection.get_whiteout_alpha"), "cinematic state must delegate timeline projection")
	_expect(gem_source.contains("DefeatContinueVisualProjection.fit_size_rect"), "gem renderer must reuse shared fit geometry")
	_expect(scene_source.contains("DefeatContinueVisualProjection.get_boss_victory_source_rect"), "scene renderer must reuse shared sheet projection")
	_expect(ambient_source.contains("DefeatContinueVisualProjection.scaled_y"), "ambient renderer must reuse shared vertical scaling")
	_expect(screen_source.contains("DefeatContinueUiRenderer.draw_header_and_status"), "screen must delegate header/status drawing")
	_expect(screen_source.contains("DefeatContinueUiRenderer.draw_footer"), "screen must delegate footer drawing")
	_expect(not screen_source.contains("func _draw_compass_sigil"), "screen must not retain compass drawing")
	_expect(not screen_source.contains("func _draw_continue_status_text"), "screen must not retain status-copy drawing")
	_expect(not screen_source.contains("func _draw_button_frame"), "screen must not retain confirm-button drawing")
	var header_index := screen_source.find("DefeatContinueUiRenderer.draw_header_and_status")
	var gem_index := screen_source.find("_gem_renderer.draw_gem_sequence")
	var footer_index := screen_source.find("DefeatContinueUiRenderer.draw_footer")
	var reveal_index := screen_source.find("DefeatContinueSceneRenderer.draw_reveal_veil")
	_expect(header_index >= 0 and header_index < gem_index, "header/status must remain behind the gem sequence")
	_expect(gem_index < footer_index, "guide/button must remain after the gem sequence")
	_expect(footer_index < reveal_index, "entry reveal veil must remain above all continue UI")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
