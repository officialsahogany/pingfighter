extends SceneTree

const SmasherShieldKitingRenderer := preload("res://scripts/characters/smasher_shield_kiting_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	var renderer: Object = SmasherShieldKitingRenderer.new()
	var status: Dictionary = renderer.get_asset_status()

	_expect(str(status.get("shield_kiting_render_mode", "")) == "procedural_pentagon_v2", "Shield Kiting should use the upgraded procedural pentagon render mode")
	_expect(not bool(status.get("shield_kiting_uses_imagegen_texture", true)), "Shield Kiting projectile should not depend on an imagegen texture")
	_expect(not bool(status.get("shield_kiting_projectile_png_slot", true)), "Shield Kiting procedural renderer should not report a PNG projectile slot")
	_expect(int(status.get("shield_kiting_projectile_points", 0)) == 5, "Shield Kiting projectile should keep a five-point pentagon silhouette")
	_expect(int(status.get("shield_kiting_inner_panel_points", 0)) == 5, "Shield Kiting inner panel should keep a pentagon motif")
	_expect(int(status.get("shield_kiting_circuit_paths", 0)) >= 8, "Shield Kiting projectile should include circuit-line detail paths")
	_expect(is_equal_approx(float(status.get("shield_kiting_projectile_visual_scale", 0.0)), 0.70), "Shield Kiting projectile image should render at 70% of the previous visual size")
	_expect(float(status.get("shield_kiting_outer_glow_line_width", 0.0)) >= 8.0, "Shield Kiting projectile should keep a strong outer glow bevel")
	_expect(SmasherShieldKitingRenderer.TRAIL_ALPHA_BASE < 0.40, "Shield Kiting trail ghosts should be lighter than the live shield")

	if _failures.is_empty():
		print("smasher_shield_kiting_projectile_design_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
