extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmImpactFlashResolver := preload("res://scripts/characters/commando_firearm_impact_flash_resolver.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoFirearmValueUtils := preload("res://scripts/characters/commando_firearm_value_utils.gd")
const GrenadeExplosionDrawer := preload("res://scripts/effects/grenade_explosion_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_impact_flash_resolver()
	_verify_runtime_uses_impact_flash_resolver()

	if _failures.is_empty():
		print("commando_firearm_impact_flash_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_impact_flash_resolver() -> void:
	var bullet: Dictionary = CommandoFirearmImpactFlashResolver.build_flash(
		{
			"weapon_id": "commando_pistol",
			"kind": "bullet",
			"pos": Vector2(12.0, 34.0),
			"impact_radius": 18.0,
			"color": Color(0.1, 0.2, 0.3),
		},
		{},
		42.0
	)
	_expect(str(bullet.get("weapon_id", "")) == "commando_pistol", "bullet impact flash should preserve weapon id")
	_expect(str(bullet.get("kind", "")) == "bullet", "bullet impact flash should preserve kind")
	_expect(_get_vector2(bullet.get("pos", Vector2.ZERO)) == Vector2(12.0, 34.0), "bullet impact flash should preserve position")
	_expect(is_equal_approx(float(bullet.get("radius", 0.0)), 18.0), "bullet impact flash should use projectile impact radius")
	_expect(is_equal_approx(float(bullet.get("timer_frames", 0.0)), 10.0), "bullet impact flash should use 10 frame timer")
	_expect(is_equal_approx(float(bullet.get("max_timer_frames", 0.0)), 10.0), "bullet impact flash max timer should mirror timer")
	_expect(_get_color(bullet.get("color", Color.WHITE)) == Color(0.1, 0.2, 0.3), "bullet impact flash should preserve color")
	_expect(_get_color(bullet.get("secondary", Color.WHITE)) == Color(1.0, 0.5, 0.2), "bullet impact flash should use secondary fallback")

	var rocket: Dictionary = CommandoFirearmImpactFlashResolver.build_flash(
		{
			"weapon_id": "bazooka",
			"kind": "rocket",
			"pos": Vector2(100.0, 80.0),
			"impact_radius": 18.0,
		},
		{"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS},
		42.0
	)
	_expect(str(rocket.get("kind", "")) == "rocket", "rocket impact flash should preserve kind")
	_expect(is_equal_approx(float(rocket.get("radius", 0.0)), CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS), "rocket impact flash should use explosion radius")
	_expect(is_equal_approx(float(rocket.get("timer_frames", 0.0)), 18.0), "rocket impact flash should use non-bullet timer")

	var fire_support: Dictionary = CommandoFirearmImpactFlashResolver.build_flash(
		{
			"weapon_id": "fire_support",
			"kind": "support",
			"pos": Vector2(120.0, 90.0),
			"color": Color(1.0, 0.34, 0.16),
			"secondary": Color(1.0, 0.82, 0.25),
		},
		{"explosion_radius": 190.0},
		float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES)
	)
	_expect(str(fire_support.get("kind", "")) == "grenade_explosion", "fire-support impact flash should use grenade explosion kind")
	_expect(is_equal_approx(float(fire_support.get("radius", 0.0)), 190.0), "fire-support impact flash should use explosion radius")
	_expect(is_equal_approx(float(fire_support.get("timer_frames", 0.0)), float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES)), "fire-support impact flash should use airstrike duration")
	_expect(is_equal_approx(float(fire_support.get("max_duration_frames", 0.0)), float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES)), "fire-support max duration should mirror airstrike duration")
	_expect(str(fire_support.get("explosion_style", "")) == GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE, "fire-support impact flash should request the airstrike explosion renderer")
	_expect(int(fire_support.get("texture_layer_count", 0)) == GrenadeExplosionDrawer.FIRE_SUPPORT_TEXTURE_LAYER_COUNT, "fire-support impact flash should expose the airstrike texture budget")
	_expect(not fire_support.has("duration_frames"), "fire-support impact flash must not carry a static duration_frames key that overrides the animated timer_frames lookup in GrenadeExplosionDrawer.draw_zone")


func _verify_runtime_uses_impact_flash_resolver() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var support_projectile := {
		"weapon_id": "fire_support",
		"kind": "support",
		"pos": Vector2(120.0, 90.0),
		"color": Color(1.0, 0.34, 0.16),
		"secondary": Color(1.0, 0.82, 0.25),
	}
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(not runtime_source.contains("func _build_impact_flash("), "runtime should not keep impact-flash build bridge")
	_expect(not runtime_source.contains("func _spawn_impact_flash("), "runtime should not keep impact-flash append bridge")

	CommandoFirearmImpactFlashResolver.append_flash(
		runtime.impact_flashes,
		support_projectile,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES),
		CommandoFirearmRuntime.FLASH_LIMIT
	)
	_expect(runtime.impact_flashes.size() == 1, "runtime spawn should append one impact flash")
	var spawned: Dictionary = CommandoFirearmValueUtils.get_dict(runtime.impact_flashes[0])
	_expect(str(spawned.get("kind", "")) == "grenade_explosion", "runtime spawn should preserve fire-support grenade visual kind")
	_expect(is_equal_approx(float(spawned.get("max_timer_frames", 0.0)), float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES)), "runtime spawn should preserve fire-support airstrike duration")
	_expect(str(spawned.get("explosion_style", "")) == GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_STYLE, "runtime spawn should preserve fire-support airstrike style")
	_expect(float(GrenadeExplosionDrawer.FIRE_SUPPORT_EXPLOSION_DURATION_FRAMES) > float(ActiveItemThrowController.GRENADE_EXPLOSION_DURATION_FRAMES), "airstrike duration should outlast grenade duration so the bombing blast can settle")


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
