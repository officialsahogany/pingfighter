extends SceneTree

const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_projectile_impact_state()
	_verify_runtime_delegates_environment_impact_state()

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


func _verify_runtime_delegates_environment_impact_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	var result: Dictionary = runtime._register_projectile_environment_impact(
		{
			"weapon_id": "bazooka",
			"pos": Vector2(20.0, 30.0),
			"velocity": Vector2(0.0, -1.0),
		},
		"wall",
		{},
		{}
	)
	_expect(str(result.get("commando_firearm_environment_impact_weapon_id", "")) == "bazooka", "runtime environment impact wrapper should preserve weapon id")
	_expect(str(result.get("commando_firearm_environment_impact_reason", "")) == "wall", "runtime environment impact wrapper should preserve reason")
	_expect(result.get("commando_firearm_environment_impact_pos", Vector2.ZERO) == Vector2(20.0, 30.0), "runtime environment impact wrapper should preserve position")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
