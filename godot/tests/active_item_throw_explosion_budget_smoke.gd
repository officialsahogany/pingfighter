extends SceneTree

const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_throw_renderer_delegates_grenade_explosion()
	_verify_shared_grenade_explosion_budget()

	if _failures.is_empty():
		print("active_item_throw_explosion_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_throw_renderer_delegates_grenade_explosion() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_renderer.gd")
	var body := _function_body(source, "func _draw_explosion_zones")
	_expect(source.find("const GrenadeExplosionDrawer := preload(\"res://scripts/effects/grenade_explosion_drawer.gd\")") >= 0, "throw renderer should preload shared grenade explosion drawer")
	_expect(body.find("GrenadeExplosionDrawer.draw_zone") >= 0, "throw renderer should delegate grenade explosion zones to the shared drawer")
	_expect(body.find("for step in range(0, 12)") < 0, "throw renderer should not keep the old dense explosion rings inline")
	_expect(body.find("for j in range(6)") < 0, "throw renderer should not keep the old dense smoke puffs inline")
	_expect(body.find("for k in range(10)") < 0, "throw renderer should not keep the old dense sparks inline")


func _verify_shared_grenade_explosion_budget() -> void:
	_expect(GrenadeExplosionDrawer.GRENADE_EXPLOSION_FIRE_RINGS <= 5, "shared grenade explosion should cap fire rings")
	_expect(GrenadeExplosionDrawer.GRENADE_EXPLOSION_SMOKE_PUFFS <= 3, "shared grenade explosion should cap smoke puffs")
	_expect(GrenadeExplosionDrawer.GRENADE_EXPLOSION_SPARKS <= 4, "shared grenade explosion should cap sparks")
	var source := FileAccess.get_file_as_string("res://scripts/effects/grenade_explosion_drawer.gd")
	_expect(source.find("draw_arc(center, shockwave_radius, 0.0, TAU, 28") >= 0, "shared grenade explosion shockwave should use the reduced point count")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
