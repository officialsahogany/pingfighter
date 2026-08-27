extends SceneTree

# expect-zero-object-leaks
const DefeatContinueAmbientRenderer := preload("res://scripts/core/defeat_continue_ambient_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_status_contract()
	_verify_source_ownership()
	if _failures.is_empty():
		print("defeat_continue_ambient_renderer_owner_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_status_contract() -> void:
	var view_size := Vector2(1280.0, 720.0)
	var inactive := DefeatContinueAmbientRenderer.get_status(false, false, 1.25, 0.0, view_size)
	_expect(not bool(inactive.get("active", true)), "inactive continue state must hide ambient presentation")
	_expect(is_zero_approx(float(inactive.get("strength", -1.0))), "inactive ambient strength must be zero")

	var visible := DefeatContinueAmbientRenderer.get_status(true, false, 1.25, 0.0, view_size)
	_expect(bool(visible.get("active", false)), "active readable continue state must show ambient presentation")
	_expect(int(visible.get("mote_count", 0)) == 34, "ambient renderer must preserve the bounded mote count")
	_expect(int(visible.get("ray_count", 0)) == 9, "ambient renderer must preserve the bounded ray count")
	_expect(is_equal_approx(float(visible.get("clock_sec", 0.0)), 1.25), "ambient renderer must use the caller's single elapsed clock")

	var boosted := DefeatContinueAmbientRenderer.get_status(true, false, 1.25, 0.22, view_size)
	_expect(float(boosted.get("strength", 0.0)) > float(visible.get("strength", 0.0)), "consume buildup must boost ambient presentation strength")
	var resetting := DefeatContinueAmbientRenderer.get_status(true, true, 1.25, 0.22, view_size)
	_expect(not bool(resetting.get("active", true)), "hidden reset handoff must stop the ambient layer")
	var invalid_view := DefeatContinueAmbientRenderer.get_status(true, false, 1.25, 0.0, Vector2.ZERO)
	_expect(not bool(invalid_view.get("active", true)), "degenerate view size must not emit ambient presentation")


func _verify_source_ownership() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/core/defeat_continue_ambient_renderer.gd")
	var screen_source := FileAccess.get_file_as_string("res://scripts/core/defeat_chance_gems_continue_screen.gd")
	_expect(renderer_source.contains("func draw_ambient_divine_motion"), "ambient renderer must own the draw entrypoint")
	_expect(renderer_source.contains("func _draw_ambient_divine_motes"), "ambient renderer must own mote drawing")
	_expect(renderer_source.contains("func _draw_ambient_light_shafts"), "ambient renderer must own light-shaft drawing")
	_expect(renderer_source.contains("func _draw_ambient_portal_glow"), "ambient renderer must own portal-glow drawing")
	_expect(screen_source.contains("DefeatContinueAmbientRenderer.draw_ambient_divine_motion"), "continue screen must delegate ambient drawing")
	_expect(not screen_source.contains("func _draw_ambient_divine_motes"), "continue screen must not retain mote drawing policy")
	_expect(not screen_source.contains("func _draw_ambient_light_shafts"), "continue screen must not retain light-shaft drawing policy")
	_expect(not screen_source.contains("func _draw_ambient_portal_glow"), "continue screen must not retain portal-glow drawing policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
