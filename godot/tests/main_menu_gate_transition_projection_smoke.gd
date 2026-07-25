extends SceneTree

const MainMenuGateTransitionProjection := preload(
	"res://scripts/ui/main_menu_gate_transition_projection.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	_verify_projection_envelope()
	_verify_scene_ownership_contract()
	if _failures.is_empty():
		print("main_menu_gate_transition_projection_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_projection_envelope() -> void:
	var view_size := Vector2(1920.0, 1080.0)
	var closed := MainMenuGateTransitionProjection.build_frame(0.0, view_size)
	var opening := MainMenuGateTransitionProjection.build_frame(0.5, view_size)
	var opened := MainMenuGateTransitionProjection.build_frame(1.0, view_size)
	_expect(closed.get("beam_rect", Rect2()).size.x <= 12.0, "closed gate should start from a narrow spirit-light seam")
	_expect(opening.get("beam_rect", Rect2()).size.x > closed.get("beam_rect", Rect2()).size.x, "opening gate should expand the spirit-light seam")
	_expect(opened.get("beam_rect", Rect2()).size.x >= view_size.x * 0.68, "opened gate should reveal a broad spirit-light field")
	for frame in [closed, opening, opened]:
		var beam_rect: Rect2 = frame.get("beam_rect", Rect2())
		_expect(is_equal_approx(beam_rect.get_center().x, view_size.x * 0.5), "gate opening should stay centered on the baked door seam")
		_expect(beam_rect.position.y >= view_size.y * 0.34, "gate light should begin below the title lockup")
		_expect(beam_rect.end.y >= view_size.y, "gate light should reach the lower fog and start prompt")
	_expect(float(closed.get("whitewash_alpha", 1.0)) == 0.0, "closed gate should not start with a white flash")
	_expect(float(opened.get("whitewash_alpha", 0.0)) > 0.70, "opened gate should finish in a scene-change whitewash")
	_expect(float(closed.get("start_light_scale", 0.0)) >= 0.80 and float(closed.get("start_light_scale", 0.0)) <= 0.85, "transition should inherit the restrained idle gate light")
	_expect(float(opening.get("start_light_scale", 0.0)) > 1.0, "start input should amplify the gate light above its idle level")
	for frame in [closed, opening, opened]:
		var feather_px := float(frame.get("edge_feather_px", 0.0))
		_expect(feather_px >= 24.0 and feather_px <= 48.0, "gate-light clip should expose a 24-48px edge feather")
		var light_peak_y := float(frame.get("light_peak_y", 0.0))
		_expect(light_peak_y >= view_size.y * 0.56 and light_peak_y <= view_size.y * 0.64, "R7 opening light should peak around the demon-face knocker")
		_expect(float(frame.get("light_top_weight", 1.0)) < 0.45, "R7 opening light should stay restrained above the knocker")
		_expect(float(frame.get("light_bottom_weight", 1.0)) >= 0.45 and float(frame.get("light_bottom_weight", 1.0)) < 0.80, "R7 opening light should diffuse below the knocker")


func _verify_scene_ownership_contract() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scripts/ui/main_menu_scene.gd")
	_expect(scene_source.find("MainMenuGateTransitionProjection") >= 0, "main-menu scene should delegate gate-opening geometry")
	_expect(scene_source.find("_draw_gate_light_vertical_gradient_rect") >= 0, "R7 gate light should combine the R6 top-edge feather with a vertical intensity gradient")
	_expect(scene_source.find("_draw_gate_shadow_panel") >= 0, "R6 gate shadow should feather both vertical opening boundaries")
	_expect(scene_source.find("_start_background_zoom_tween") < 0, "gate-opening transition should replace the legacy background zoom")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
