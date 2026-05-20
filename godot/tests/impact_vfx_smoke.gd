extends SceneTree

const ImpactEffects := preload("res://scripts/effects/impact_effects.gd")


func _init() -> void:
	var effects: Object = ImpactEffects.new()
	effects.spawn_paddle_hit_particles(Vector2(320.0, 690.0), true, Vector2(6.0, -18.0), 0.75)
	_expect(effects.has_visible_effects(), "paddle hit should create visible impact effects")
	_expect(effects.get_hit_particles().size() > 0, "paddle hit should create spark particles")
	_expect(effects.get_hit_rings().size() > 0, "paddle hit should create expanding rings")
	_expect(effects.get_hit_streaks().size() > 0, "paddle hit should create directional streaks")
	_expect(effects.get_hit_flashes().size() > 0, "paddle hit should create a core flash")

	effects.spawn_wall_impact(Vector2(0.0, 360.0), "left", 28.0)
	_expect(effects.get_wall_impact_particles().size() > 0, "wall hit should create wall sparks")
	_expect(effects.get_wall_impact_rings().size() > 0, "wall hit should create a wall ripple")

	effects.create_energy_explosion(Vector2(380.0, 375.0), 1.0, 1.25)
	_expect(effects.get_energy_explosion_particles().size() > 0, "energy explosion should create particles")

	for _i in range(70):
		effects.update(1.0 / 60.0)
	_expect(not effects.has_visible_effects(), "impact effects should expire after their lifetimes")

	effects.spawn_hit_particles(Vector2(200.0, 200.0), Color(0.62, 0.90, 1.0, 1.0), Vector2(1.0, 0.0), 0.8, 18.0)
	_expect(effects.has_visible_effects(), "generic hit particles should use the same visible impact stack")
	effects.clear_all()
	_expect(not effects.has_visible_effects(), "clear_all should reset every impact layer")

	print("impact_vfx_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
