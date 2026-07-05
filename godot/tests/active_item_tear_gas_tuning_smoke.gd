extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowRenderer := preload("res://scripts/items/active_item_throw_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	var catalog: Object = ActiveItemCatalog.new()
	var tear_gas: Dictionary = catalog.build_item_by_name("tear_gas")

	_expect(int(tear_gas.get("duration", 0)) == 960, "tear gas catalog duration should be 16 seconds")
	_expect(is_equal_approx(ActiveItemThrowController.TEAR_GAS_ZONE_DURATION_FRAMES, 960.0), "tear gas runtime duration should be 960 frames")
	_expect(is_equal_approx(ActiveItemThrowController.TEAR_GAS_MAX_RADIUS_X, 240.0), "tear gas runtime horizontal radius should stay localized")
	_expect(is_equal_approx(ActiveItemThrowController.TEAR_GAS_EXPANSION_RATE_X, 6.7), "tear gas horizontal expansion should preserve fill timing")
	_expect(ActiveItemThrowController.TEAR_GAS_MAX_OPACITY >= 0.8, "tear gas runtime opacity should keep the restored smoke readable")
	_expect(ActiveItemThrowController.TEAR_GAS_PARTICLE_CAP <= 32, "tear gas runtime particle cap should stay bounded for frame pacing")
	_expect(ActiveItemThrowController.TEAR_GAS_PARTICLE_SPAWN_COUNT <= 1, "tear gas should avoid multi-particle respawns during sustained smoke")
	_expect(is_equal_approx(ActiveItemThrowRenderer.TEAR_GAS_ZONE_DURATION_FRAMES, 960.0), "tear gas renderer duration fallback should match runtime")
	_expect(is_equal_approx(ActiveItemThrowRenderer.TEAR_GAS_RADIUS_X, 240.0), "tear gas renderer horizontal fallback should match runtime")
	_expect(ActiveItemThrowRenderer.TEAR_GAS_RENDER_PARTICLE_LIMIT <= 16, "tear gas renderer should keep per-zone particle draw count bounded")
	_expect(ActiveItemThrowRenderer.TEAR_GAS_RENDER_TOTAL_PARTICLE_LIMIT <= 24, "tear gas renderer should keep total particle draw count bounded across stacked zones")
	# Contact ellipse must be axis-split: the rendered cloud is flatter vertically
	# than it is wide, so the vertical contact scale has to be tighter than the
	# horizontal one. A shared scale left the vertical reach ~2x the visible body
	# and paused the top-of-field boss while it rendered above the cloud.
	_expect(
		ActiveItemThrowController.TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_Y < ActiveItemThrowController.TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_X,
		"tear gas vertical contact scale must be tighter than horizontal (flat cloud body)"
	)
	_expect(
		ActiveItemThrowController.TEAR_GAS_BOSS_CONTACT_RADIUS_SCALE_Y <= 0.42,
		"tear gas vertical contact scale must match the flat visible cloud body (below the ~0.417 false-trigger threshold)"
	)
	# The ⏸ pause marker must not outlive real gas contact: the gameplay pause is
	# a 2-frame latch (re-armed every frame in contact), so the marker's linger
	# timer is display-only grace. 60f (1s) let a dashing boss carry the icon
	# across the field after leaving the cloud — the "icon with no gas contact"
	# report. Keep the grace at anti-flicker scale (~0.25s max).
	_expect(
		ActiveItemThrowController.TEAR_GAS_TEXT_DURATION_FRAMES <= 15.0,
		"tear gas pause marker linger must stay a short anti-flicker grace, not a 1s trail"
	)
	# Auto-aim must land the cloud close enough that the visible smoke body
	# (upward reach ~= radius_y * 0.32) actually reaches the boss; otherwise the
	# rendered cloud tops out short of the boss and the pause fires with no visual
	# contact — the reported "skill-stop icon without touching the gas" bug.
	_expect(
		ActiveItemThrowController.TEAR_GAS_TARGET_BELOW_BOSS <= ActiveItemThrowController.TEAR_GAS_MAX_RADIUS * 0.32,
		"tear gas auto-aim offset must keep the visible cloud body over the boss"
	)
	var renderer_source: String = FileAccess.get_file_as_string("res://scripts/items/active_item_throw_tear_gas_renderer.gd")
	var tear_gas_zone_body: String = _function_body(renderer_source, "func draw_tear_gas_zones")
	_expect(tear_gas_zone_body.find("draw_arc") < 0, "tear gas renderer should not draw a range outline around the gas zone")
	_expect(tear_gas_zone_body.find("remaining_particle_budget") >= 0, "tear gas renderer should share one particle budget across stacked zones")
	var tear_gas_particle_body: String = _function_body(renderer_source, "func _draw_tear_gas_particle")
	_expect(tear_gas_particle_body.find("_draw_tear_gas_texture_puff") >= 0, "tear gas particles should use cached texture puffs instead of multi-ellipse clouds")
	var ellipse_body: String = _function_body(renderer_source, "func _draw_filled_ellipse")
	_expect(ellipse_body.find("draw_colored_polygon") < 0, "filled ellipse fallback should avoid per-draw polygon allocation")
	_expect(ellipse_body.find("PackedVector2Array") < 0, "filled ellipse fallback should avoid per-draw point array allocation")

	if _failures.is_empty():
		print("active_item_tear_gas_tuning_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)
