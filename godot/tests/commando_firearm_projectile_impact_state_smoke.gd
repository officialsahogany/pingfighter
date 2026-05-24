extends SceneTree

const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_projectile_impact_state()
	_verify_environment_impact_state()

	if _failures.is_empty():
		print("commando_firearm_projectile_impact_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_projectile_impact_state() -> void:
	var combat_result := {"damage_units": 1}
	var hit_event: Dictionary = CommandoFirearmProjectileImpactState.build_hit_event(
		{"id": 7},
		"bazooka",
		"rocket",
		Vector2(100.0, 80.0),
		Vector2(0.0, -12.0),
		0.75,
		combat_result
	)
	_expect(int(hit_event.get("id", 0)) == 7, "hit event should preserve projectile id")
	_expect(str(hit_event.get("weapon_id", "")) == "bazooka", "hit event should preserve weapon id")
	_expect(str(hit_event.get("kind", "")) == "rocket", "hit event should preserve projectile kind")
	_expect(str(hit_event.get("target", "")) == "boss", "hit event should target the boss")
	_expect(hit_event.get("pos", Vector2.ZERO) == Vector2(100.0, 80.0), "hit event should preserve impact position")
	_expect((hit_event.get("result", {}) as Dictionary).get("damage_units", 0) == 1, "hit event should preserve combat result")

	var environment: Dictionary = CommandoFirearmProjectileImpactState.build_environment_impact_result(
		"bazooka",
		"wall",
		Vector2(20.0, 30.0)
	)
	_expect(bool(environment.get("commando_firearm_environment_impact", false)), "environment impact result should expose impact flag")
	_expect(str(environment.get("commando_firearm_environment_impact_reason", "")) == "wall", "environment impact result should preserve reason")
	_expect(environment.get("commando_firearm_environment_impact_pos", Vector2.ZERO) == Vector2(20.0, 30.0), "environment impact result should preserve position")

	var context := {
		"boss_pos": Vector2(330.0, 50.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}
	var impact_reason: String = CommandoFirearmProjectileImpactState.get_impact_reason(
		{
			"weapon_id": "ak47",
			"pos": Vector2(328.0, 70.0),
			"radius": 3.0,
		},
		context,
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		Vector2(CommandoFirearmRuntime.FIELD_WIDTH, CommandoFirearmRuntime.FIELD_HEIGHT),
		CommandoFirearmRuntime.FIELD_WIDTH
	)
	_expect(impact_reason == "target", "impact owner should route runtime projectiles through hit geometry")


func _verify_environment_impact_state() -> void:
	var result: Dictionary = CommandoFirearmProjectileImpactState.register_environment_impact(
		{
			"weapon_id": "bazooka",
			"pos": Vector2(20.0, 30.0),
			"velocity": Vector2(0.0, -1.0),
		},
		"wall",
		{},
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID
	)
	_expect(str(result.get("commando_firearm_environment_impact_weapon_id", "")) == "bazooka", "environment impact owner should preserve weapon id")
	_expect(str(result.get("commando_firearm_environment_impact_reason", "")) == "wall", "environment impact owner should preserve reason")
	_expect(result.get("commando_firearm_environment_impact_pos", Vector2.ZERO) == Vector2(20.0, 30.0), "environment impact owner should preserve position")
	var runtime_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_runtime.gd")
	_expect(runtime_source.find("func _get_projectile_impact_reason(") == -1, "runtime should not keep projectile impact reason bridge")
	_expect(runtime_source.find("func _register_projectile_environment_impact(") == -1, "runtime should not keep projectile environment-impact bridge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
