extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	_verify_shared_projectile_trail_budget()

	if _failures.is_empty():
		print("active_item_throw_renderer_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shared_projectile_trail_budget() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_renderer.gd")
	var flare_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_flare_renderer.gd")
	var dynamite_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_dynamite_renderer.gd")
	var tear_gas_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_tear_gas_renderer.gd")
	var molotov_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_molotov_renderer.gd")
	var boomerang_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_boomerang_renderer.gd")
	var spider_mine_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_spider_mine_renderer.gd")
	var slip_source := FileAccess.get_file_as_string("res://scripts/items/active_item_throw_slip_renderer.gd")
	_expect(source != "", "active item throw renderer source should be readable")
	_expect(flare_source != "", "active item throw flare renderer source should be readable")
	_expect(dynamite_source != "", "active item throw dynamite renderer source should be readable")
	_expect(tear_gas_source != "", "active item throw tear gas renderer source should be readable")
	_expect(molotov_source != "", "active item throw molotov renderer source should be readable")
	_expect(boomerang_source != "", "active item throw boomerang renderer source should be readable")
	_expect(spider_mine_source != "", "active item throw spider mine renderer source should be readable")
	_expect(slip_source != "", "active item throw slip renderer source should be readable")
	var grenade_body := _function_body(source, "func _draw_grenades")
	var flare_body := _function_body(flare_source, "func draw_flares")
	var trail_body := _function_body(source, "func _draw_projectile_trail")
	var dynamite_body := _function_body(dynamite_source, "func draw_dynamite_explosions")
	var tear_gas_body := _function_body(tear_gas_source, "func draw_tear_gas_zones")
	var molotov_body := _function_body(molotov_source, "func draw_molotov_fire_zones")
	var boomerang_body := _function_body(boomerang_source, "func draw_boomerangs")
	var spider_mine_body := _function_body(spider_mine_source, "func draw_spider_mines")
	var slip_trail_body := _function_body(slip_source, "func _draw_projectile_trail")
	_expect(grenade_body.find("_draw_projectile_trail(") >= 0, "grenade draw should use the shared trail budget helper")
	_expect(flare_body.find("_draw_projectile_trail(") >= 0, "flare draw should use the shared trail budget helper")
	_expect(trail_body.find("var stride: int = 2 if trail_count > 5 else 1") >= 0, "projectile trail helper should thin long trails")
	_expect(trail_body.find("for i in range(0, trail_count, stride):") >= 0, "projectile trail helper should apply the stride")
	_expect(
		_function_body(source, "func draw").find("_flare_renderer.draw_flares") >= 0,
		"throw renderer should delegate flare projectile drawing to the flare renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_flare_renderer.draw_flare_zones") >= 0,
		"throw renderer should delegate flare zone drawing to the flare renderer"
	)
	_expect(
		_function_body(source, "func _draw_grenade_throw_windups").find("_flare_renderer.draw_flare_fallback") >= 0,
		"throw renderer should delegate flare windup fallback drawing to the flare renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_slip_renderer.draw_bananas") >= 0,
		"throw renderer should delegate banana projectile drawing to the slip renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_slip_renderer.draw_soaps") >= 0,
		"throw renderer should delegate soap projectile drawing to the slip renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_dynamite_renderer.draw_dynamites") >= 0,
		"throw renderer should delegate dynamite projectile drawing to the dynamite renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_dynamite_renderer.draw_placed_dynamites") >= 0,
		"throw renderer should delegate placed dynamite drawing to the dynamite renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_dynamite_renderer.draw_dynamite_explosions") >= 0,
		"throw renderer should delegate dynamite explosion drawing to the dynamite renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_tear_gas_renderer.draw_tear_gas_zones") >= 0,
		"throw renderer should delegate tear gas zone drawing to the tear gas renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_tear_gas_renderer.draw_tear_gas_projectiles") >= 0,
		"throw renderer should delegate tear gas projectile drawing to the tear gas renderer"
	)
	_expect(
		_function_body(source, "func _draw_grenade_throw_windups").find("_tear_gas_renderer.draw_tear_gas_fallback") >= 0,
		"throw renderer should delegate tear gas windup fallback drawing to the tear gas renderer"
	)
	_expect(
		_function_body(source, "func _draw_grenade_throw_windups").find("_dynamite_renderer.draw_dynamite_fallback") >= 0,
		"throw renderer should delegate dynamite windup fallback drawing to the dynamite renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_molotov_renderer.draw_molotov_fire_zones") >= 0,
		"throw renderer should delegate molotov fire zone drawing to the molotov renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_molotov_renderer.draw_molotovs") >= 0,
		"throw renderer should delegate molotov projectile drawing to the molotov renderer"
	)
	_expect(
		_function_body(source, "func _draw_grenade_throw_windups").find("_molotov_renderer.draw_molotov_fallback") >= 0,
		"throw renderer should delegate molotov windup fallback drawing to the molotov renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_boomerang_renderer.draw_boomerangs") >= 0,
		"throw renderer should delegate boomerang projectile drawing to the boomerang renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_boomerang_renderer.draw_boomerang_particles") >= 0,
		"throw renderer should delegate boomerang particle drawing to the boomerang renderer"
	)
	_expect(
		_function_body(source, "func _draw_grenade_throw_windups").find("_boomerang_renderer.draw_boomerang_fallback") >= 0,
		"throw renderer should delegate boomerang windup fallback drawing to the boomerang renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_spider_mine_renderer.draw_spider_mines") >= 0,
		"throw renderer should delegate spider mine drawing to the spider mine renderer"
	)
	_expect(
		_function_body(source, "func draw").find("_spider_mine_renderer.draw_spider_mine_particles") >= 0,
		"throw renderer should delegate spider mine particle drawing to the spider mine renderer"
	)
	_expect(
		_function_body(source, "func _draw_grenade_throw_windups").find("_spider_mine_renderer.draw_spider_mine_windup_fallback") >= 0,
		"throw renderer should delegate spider mine windup fallback drawing to the spider mine renderer"
	)
	_expect(dynamite_body.find("_draw_dynamite_smoke_clouds") >= 0, "dynamite renderer should own smoke cloud drawing")
	_expect(dynamite_body.find("_draw_dynamite_fire_particles") >= 0, "dynamite renderer should own fire particle drawing")
	_expect(tear_gas_body.find("remaining_particle_budget") >= 0, "tear gas renderer should own shared gas particle budget")
	_expect(tear_gas_body.find("_draw_tear_gas_base_haze") >= 0, "tear gas renderer should own gas haze drawing")
	_expect(molotov_body.find("_sync_molotov_fx_hosts") >= 0, "molotov renderer should own fire-zone host syncing")
	_expect(molotov_body.find("_draw_filled_ellipse") >= 0, "molotov renderer should own fire-zone fallback ellipses")
	_expect(molotov_body.find("_draw_molotov_flame") >= 0, "molotov renderer should own fire-zone flame drawing")
	_expect(boomerang_body.find("draw_boomerang_fallback") >= 0, "boomerang renderer should retain the fallback boomerang shape")
	_expect(boomerang_body.find("_get_boomerang_icon_texture(gauntlet_equipped)") >= 0, "boomerang renderer should own normal and metal boomerang texture lookup")
	_expect(spider_mine_body.find("_draw_spider_mine_sheet") >= 0, "spider mine renderer should own sheet-backed drawing")
	_expect(spider_mine_body.find("_draw_spider_mine_explosion") >= 0, "spider mine renderer should own explosion drawing")
	_expect(slip_trail_body.find("var stride: int = 2 if trail_count > 5 else 1") >= 0, "slip projectile trail helper should thin long trails")
	_expect(slip_trail_body.find("for i in range(0, trail_count, stride):") >= 0, "slip projectile trail helper should apply the stride")


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
