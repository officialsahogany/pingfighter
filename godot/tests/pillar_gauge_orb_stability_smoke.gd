extends SceneTree

const PillarGaugeOrbRenderer := preload("res://scripts/hud/pillar_gauge_orb_renderer.gd")
const PillarDashOrbRenderer := preload("res://scripts/hud/pillar_dash_orb_renderer.gd")
const PillarLiquidDrawer := preload("res://scripts/hud/pillar_liquid_drawer.gd")
const OrbHudState := preload("res://scripts/hud/orb_hud_state.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")

var _failures: Array[String] = []


func _init() -> void:
	var gauge_renderer := PillarGaugeOrbRenderer.new()
	var initial_ratio: float = gauge_renderer._update_display_ratio(0.90, 10.0)
	_expect(is_equal_approx(initial_ratio, 0.90), "gauge display should initialize from the current ratio")

	var full_ratio: float = gauge_renderer._update_display_ratio(1.0, 10.016)
	_expect(is_equal_approx(full_ratio, 1.0), "full gauge display should snap to stable full instead of lingering below max")
	_expect(
		is_equal_approx(gauge_renderer._get_frame_spin_angle({"pillar_hud_static_lod": true, "frame_spin_angle": 37.0}), 37.0),
		"static HUD LOD should preserve the gauge frame spin feedback angle"
	)
	var dash_renderer := PillarDashOrbRenderer.new()
	_expect(
		is_equal_approx(dash_renderer._get_frame_spin_angle({"pillar_hud_static_lod": true, "frame_spin_angle": -42.0}), -42.0),
		"static HUD LOD should preserve the dash frame spin feedback angle"
	)
	_verify_dash_spin_feedback_path()

	var liquid_drawer := PillarLiquidDrawer.new()
	_expect(liquid_drawer._is_stable_full_fill_ratio(1.0), "full liquid should use the stable non-animated fill")
	_expect(liquid_drawer._is_stable_full_fill_ratio(0.999), "near-full liquid should use the stable non-animated fill")
	_expect(not liquid_drawer._is_stable_full_fill_ratio(0.998), "non-full liquid should keep the normal animated fill")
	var liquid_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_liquid_drawer.gd")
	_expect(liquid_source.find("LIQUID_FAST_LOD_SCALE") >= 0, "pillar liquid should expose a fast LOD threshold")
	_expect(liquid_source.find("_draw_fast_lod_liquid") >= 0, "pillar liquid should keep the fast LOD fill path")
	_expect(
		_function_body(liquid_source, "func draw_pillar_liquid_fill(").find("_draw_fast_lod_liquid") >= 0,
		"pillar liquid draw should route low-quality fills through the fast LOD path"
	)
	var chrome_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_orb_chrome_drawer.gd")
	_expect(chrome_source.find("func draw_pillar_orb_glass_lod(") >= 0, "pillar orb chrome should implement the static HUD glass LOD path")
	_expect(chrome_source.find("func draw_pillar_text_centered_lod(") >= 0, "pillar orb chrome should implement the static HUD text LOD path")
	var divider_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_token_divider_renderer.gd")
	_expect(
		_function_body(divider_source, "func draw(").find("if max_tokens <= 1:") >= 0,
		"dash token divider draw should skip divider work when there is only one token"
	)
	var fill_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_gauge_orb_fill_renderer.gd")
	_expect(
		_function_body(fill_source, "func draw(").find("pillar_hud_static_lod") >= 0,
		"gauge fill renderer should skip decorative fill glow in static HUD LOD"
	)
	var gauge_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_gauge_orb_renderer.gd")
	_expect(
		_function_body(gauge_source, "func draw(").find("draw_pillar_orb_glass_lod") >= 0,
		"gauge orb draw should use cheap glass in static HUD LOD"
	)
	_expect(
		_function_body(gauge_source, "func draw(").find("draw_pillar_text_centered_lod") >= 0,
		"gauge orb draw should use cheap text in static HUD LOD"
	)
	var dash_source := FileAccess.get_file_as_string("res://scripts/hud/pillar_dash_orb_renderer.gd")
	_expect(
		_function_body(dash_source, "func draw(").find("draw_pillar_orb_glass_lod") >= 0,
		"dash orb draw should use cheap glass in static HUD LOD"
	)
	_expect(
		_function_body(dash_source, "func draw(").find("draw_pillar_text_centered_lod") >= 0,
		"dash orb draw should use cheap text in static HUD LOD"
	)

	if _failures.is_empty():
		print("pillar_gauge_orb_stability_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _verify_dash_spin_feedback_path() -> void:
	var orb_state: Object = OrbHudState.new()
	orb_state.reset_dash_tokens(1)
	orb_state.sync_dash_token_spin(0, 1000)
	_expect(
		float(orb_state.get_dash_token_spin_angle(1100)) > 0.0,
		"dash token drop should produce a visible frame spin angle"
	)

	orb_state.reset_dash_tokens(1)
	var dash_state: Object = SmasherDashState.new()
	dash_state.reset_full(1)
	var controller: Object = SmasherPlayerDashController.new()
	var result: Dictionary = controller.handle_dash_input(
		true,
		1.0,
		Vector2(302.5, 700.0),
		0.0,
		{
			"special_gauge": 0.0,
			"play_left": 0.0,
			"play_right": 760.0,
			"paddle_width": 155.0,
			"paddle_height": 50.0,
		},
		{
			"dash_state": dash_state,
			"orb_hud_state": orb_state,
		}
	)
	_expect(bool(result.get("handled_by_dash", false)), "normal dash input should be handled")
	var spin_start: int = int(orb_state.get_dash_token_spin_start_msec())
	_expect(
		float(orb_state.get_dash_token_spin_angle(spin_start + 100)) > 0.0,
		"normal dash start should trigger the dash orb frame spin"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)
