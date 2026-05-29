extends SceneTree

const CommandoFirearmProjectileMotionState := preload("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
const Stage1BalloonEvent := preload("res://scripts/stages/stage1/stage1_balloon_event.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var pop_calls := 0

	func play_stage1_balloon_pop() -> void:
		pop_calls += 1


class FakeRegistry:
	extends RefCounted

	var stage1_balloon_event: Object

	func get_instance(key: String) -> Object:
		if key == "stage1_balloon_event":
			return stage1_balloon_event
		return null


func _init() -> void:
	seed(97531)
	_verify_commando_bullets_pop_stage1_balloons()
	_verify_non_bullet_or_wrong_stage_does_not_pop()
	_verify_projectile_motion_consumes_bullet_on_balloon_pop()
	_verify_registry_target_is_supported()

	if _failures.is_empty():
		print("commando_firearm_stage1_balloon_interaction_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_commando_bullets_pop_stage1_balloons() -> void:
	for weapon_id in ["pistol", "commando_pistol", "ak47"]:
		var event := Stage1BalloonEvent.new()
		var audio := FakeAudio.new()
		event.balloons.append(_make_balloon(Vector2(120.0, 160.0), false))
		var result: Dictionary = event.resolve_commando_bullet_collision(
			_make_projectile(weapon_id, Vector2(90.0, 160.0), Vector2(150.0, 160.0)),
			{"current_stage": 1},
			{"audio": audio}
		)
		_expect(bool(result.get("commando_firearm_balloon_popped", false)), "%s bullet should pop a Stage 1 balloon" % weapon_id)
		_expect(event.balloons.is_empty(), "%s bullet should remove the popped balloon" % weapon_id)
		_expect(not event.pop_effects.is_empty(), "%s bullet should leave the balloon pop effect" % weapon_id)
		_expect(audio.pop_calls == 1, "%s bullet pop should play the Stage 1 balloon pop cue" % weapon_id)

	var special_event := Stage1BalloonEvent.new()
	special_event.balloons.append(_make_balloon(Vector2(200.0, 210.0), true))
	var special_result: Dictionary = special_event.resolve_commando_bullet_collision(
		_make_projectile("ak47", Vector2(200.0, 250.0), Vector2(200.0, 180.0)),
		{"current_stage": 1},
		{}
	)
	_expect(bool(special_result.get("commando_firearm_balloon_special", false)), "special balloon hit should be reported")
	_expect(special_event.starpoint_drops.size() == 1, "special balloon popped by a bullet should still spawn one starpoint drop")


func _verify_non_bullet_or_wrong_stage_does_not_pop() -> void:
	var weapon_event := Stage1BalloonEvent.new()
	weapon_event.balloons.append(_make_balloon(Vector2(100.0, 100.0), false))
	var weapon_result: Dictionary = weapon_event.resolve_commando_bullet_collision(
		_make_projectile("bazooka", Vector2(80.0, 100.0), Vector2(120.0, 100.0)),
		{"current_stage": 1},
		{}
	)
	_expect(weapon_result.is_empty(), "non-requested Commando weapons should not use the bullet balloon pop path")
	_expect(weapon_event.balloons.size() == 1, "ignored weapon should leave the balloon alive")

	var stage_event := Stage1BalloonEvent.new()
	stage_event.balloons.append(_make_balloon(Vector2(100.0, 100.0), false))
	var stage_result: Dictionary = stage_event.resolve_commando_bullet_collision(
		_make_projectile("pistol", Vector2(80.0, 100.0), Vector2(120.0, 100.0)),
		{"current_stage": 2},
		{}
	)
	_expect(stage_result.is_empty(), "Commando bullets should only pop balloons in Stage 1")
	_expect(stage_event.balloons.size() == 1, "wrong-stage bullet should leave the balloon alive")


func _verify_projectile_motion_consumes_bullet_on_balloon_pop() -> void:
	var event := Stage1BalloonEvent.new()
	event.balloons.append(_make_balloon(Vector2(120.0, 150.0), false))
	var projectiles: Array = [
		_make_projectile("ak47", Vector2(90.0, 150.0), Vector2(105.0, 150.0), Vector2(20.0, 0.0)),
	]
	var impact_flashes: Array = []
	var result: Dictionary = CommandoFirearmProjectileMotionState.advance_runtime_projectiles(
		projectiles,
		impact_flashes,
		null,
		1.0,
		_base_context(),
		{"stage1_balloon_event": event},
		_base_options()
	)
	_expect(bool(result.get("commando_firearm_balloon_popped", false)), "projectile update should report a Stage 1 balloon pop")
	_expect(projectiles.is_empty(), "bullet should be consumed when it pops a Stage 1 balloon")
	_expect(event.balloons.is_empty(), "projectile update should remove the popped Stage 1 balloon")
	_expect(impact_flashes.is_empty(), "balloon pop should rely on the balloon pop effect, not a boss-impact flash")


func _verify_registry_target_is_supported() -> void:
	var event := Stage1BalloonEvent.new()
	event.balloons.append(_make_balloon(Vector2(140.0, 150.0), false))
	var registry := FakeRegistry.new()
	registry.stage1_balloon_event = event
	var projectiles: Array = [
		_make_projectile("commando_pistol", Vector2(110.0, 150.0), Vector2(125.0, 150.0), Vector2(20.0, 0.0)),
	]
	var result: Dictionary = CommandoFirearmProjectileMotionState.advance_runtime_projectiles(
		projectiles,
		[],
		null,
		1.0,
		_base_context(),
		{"registry": registry},
		_base_options()
	)
	_expect(bool(result.get("commando_firearm_balloon_popped", false)), "projectile update should find Stage 1 balloons through the registry target")
	_expect(projectiles.is_empty(), "registry-routed balloon hit should consume the bullet")


func _make_balloon(pos: Vector2, special: bool) -> Dictionary:
	return {
		"pos": pos,
		"vel": Vector2.ZERO,
		"radius": 22.0,
		"color": Color(1.0, 0.45, 0.3, 1.0),
		"is_special": special,
	}


func _make_projectile(
	weapon_id: String,
	prev_pos: Vector2,
	pos: Vector2,
	velocity: Vector2 = Vector2.ZERO
) -> Dictionary:
	return {
		"id": hash(weapon_id),
		"weapon_id": weapon_id,
		"kind": "bullet",
		"prev_pos": prev_pos,
		"pos": pos,
		"velocity": velocity,
		"radius": 4.0,
		"life_frames": 30.0,
	}


func _base_context() -> Dictionary:
	return {
		"current_stage": 1,
		"width": 760.0,
		"height": 750.0,
		"boss_pos": Vector2(330.0, 60.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}


func _base_options() -> Dictionary:
	return {
		"base_weapon_id": "pistol",
		"field_width": 760.0,
		"field_height": 750.0,
		"weapon_profiles": {},
		"weapon_profile_overrides": {},
		"weapon_hit_feedback": {},
		"hit_feedback_profile_overrides": {},
		"pistol_wall_bounce_margin": 10.0,
		"pistol_wall_bounce_max": 1,
		"pistol_wall_bounce_damping": 0.85,
		"flash_limit": 24,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
