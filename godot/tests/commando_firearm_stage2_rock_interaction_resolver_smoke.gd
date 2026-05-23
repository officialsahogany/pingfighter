extends SceneTree

const CommandoFirearmStage2RockInteractionResolver := preload("res://scripts/characters/commando_firearm_stage2_rock_interaction_resolver.gd")

var _failures: Array[String] = []


class FakeRockTarget:
	extends RefCounted

	var explosion_calls := 0
	var bounce_calls := 0
	var explosion_result := 2
	var should_bounce := true
	var should_consume := false
	var last_center := Vector2.ZERO
	var last_radius := 0.0
	var last_context: Dictionary = {}

	func resolve_explosion_rock_collision(center: Vector2, radius: float, _deps: Dictionary = {}, context: Dictionary = {}) -> int:
		explosion_calls += 1
		last_center = center
		last_radius = radius
		last_context = context.duplicate(true)
		return explosion_result

	func resolve_pistol_projectile_rock_bounce(projectile: Dictionary, _deps: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
		bounce_calls += 1
		last_context = context.duplicate(true)
		if should_consume:
			return {"consumed": true}
		if not should_bounce:
			return {"bounced": false}
		var bounced_projectile: Dictionary = projectile.duplicate(true)
		bounced_projectile["rock_bounces"] = int(bounced_projectile.get("rock_bounces", 0)) + 1
		bounced_projectile["velocity"] = Vector2(0.0, -22.0)
		return {"bounced": true, "projectile": bounced_projectile}


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


class FakeRouter:
	extends RefCounted

	var routed: Object = null

	func get_instance(_registry: Object, _stage: int, _role: String) -> Object:
		return routed


func _init() -> void:
	_verify_explosion_rock_targets_are_deduped()
	_verify_pistol_rock_bounce_mutates_projectile()
	_verify_guards_ignore_wrong_stage_or_weapon()

	if _failures.is_empty():
		print("commando_firearm_stage2_rock_interaction_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_explosion_rock_targets_are_deduped() -> void:
	var target := FakeRockTarget.new()
	var router := FakeRouter.new()
	router.routed = target
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage2_pillar_background": target,
		"stage_runtime_router": router,
	}
	var deps := {
		"stage_background": target,
		"stage2_pillar_background": target,
		"registry": registry,
		"current_stage": 2,
	}
	var projectile := {"pos": Vector2(123.0, 45.0)}
	var hits: int = CommandoFirearmStage2RockInteractionResolver.destroy_projectile_impact_rocks(
		projectile,
		{"current_stage": 2},
		deps,
		"bazooka",
		77.0
	)
	_expect(hits == 2, "explosion helper should return the Stage 2 rock hit count")
	_expect(target.explosion_calls == 1, "explosion helper should dedupe deps / registry / router targets")
	_expect(target.last_center == Vector2(123.0, 45.0), "explosion helper should pass projectile impact center")
	_expect(is_equal_approx(target.last_radius, 77.0), "explosion helper should pass resolved explosion radius")
	_expect(str(target.last_context.get("source", "")) == "commando_firearm_bazooka", "explosion helper should stamp the Commando weapon source")


func _verify_pistol_rock_bounce_mutates_projectile() -> void:
	var target := FakeRockTarget.new()
	var projectile := {
		"weapon_id": "commando_pistol",
		"velocity": Vector2(0.0, 20.0),
	}
	var result: Dictionary = CommandoFirearmStage2RockInteractionResolver.apply_pistol_rock_bounce(
		projectile,
		{"current_stage": 2},
		{"stage_background": target},
		true
	)
	_expect(bool(result.get("bounced", false)), "pistol rock helper should report bounced projectiles")
	_expect(target.bounce_calls == 1, "pistol rock helper should call the first valid bounce target")
	_expect(int(projectile.get("rock_bounces", 0)) == 1, "pistol rock helper should merge bounced projectile payloads back into the live dictionary")
	_expect(Vector2(projectile.get("velocity", Vector2.ZERO)).y < 0.0, "pistol rock helper should preserve returned ricochet velocity")
	_expect(int(target.last_context.get("current_stage", 0)) == 2, "pistol rock helper should force the routed context to Stage 2")


func _verify_guards_ignore_wrong_stage_or_weapon() -> void:
	var target := FakeRockTarget.new()
	var ignored_explosion: int = CommandoFirearmStage2RockInteractionResolver.destroy_projectile_impact_rocks(
		{"pos": Vector2.ZERO},
		{"current_stage": 2},
		{"stage_background": target},
		"commando_pistol",
		40.0
	)
	_expect(ignored_explosion == 0 and target.explosion_calls == 0, "explosion helper should ignore non-explosive Commando weapons")
	var ignored_bounce: Dictionary = CommandoFirearmStage2RockInteractionResolver.apply_pistol_rock_bounce(
		{"velocity": Vector2.DOWN},
		{"current_stage": 1},
		{"stage_background": target},
		true
	)
	_expect(ignored_bounce.is_empty() and target.bounce_calls == 0, "pistol rock helper should ignore non-Stage 2 contexts")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
