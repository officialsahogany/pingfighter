extends SceneTree

const CommandoFirearmProjectileImpactState := preload("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")

var _failures: Array[String] = []


class FakeImpactEffects:
	extends RefCounted

	var particles: Array = []

	func spawn_hit_particles(pos: Vector2, color: Color, velocity: Vector2, intensity: float, speed: float) -> void:
		particles.append({
			"pos": pos,
			"color": color,
			"velocity": velocity,
			"intensity": intensity,
			"speed": speed,
		})


class FakeFeedback:
	extends RefCounted

	var calls: Array = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		calls.append({"amount": amount, "intensity": intensity})


class FakeAnimationState:
	extends RefCounted

	var calls: Array = []

	func trigger_boss_hit(boss_vel: float, has_hit_sprite: bool) -> void:
		calls.append({"boss_vel": boss_vel, "has_hit_sprite": has_hit_sprite})


class FakeBallEffects:
	extends RefCounted

	var pulses: Array = []

	func register_hit_pulse(pos: Vector2, velocity: Vector2, intensity: float, kind: String) -> void:
		pulses.append({
			"pos": pos,
			"velocity": velocity,
			"intensity": intensity,
			"kind": kind,
		})


class FakeAudio:
	extends RefCounted

	var impact_calls: Array[String] = []

	func play_commando_firearm_impact(weapon_id: String) -> void:
		impact_calls.append(weapon_id)


class FakeRuntimeOwner:
	extends RefCounted

	var boss_hits: Array = []
	var lingering_calls: Array = []

	func _register_projectile_hit(projectile: Dictionary, context: Dictionary, deps: Dictionary) -> void:
		boss_hits.append({
			"projectile": projectile,
			"context": context,
			"deps": deps,
		})

	func _spawn_lingering_effect(weapon_id: String, projectile: Dictionary, context: Dictionary) -> Dictionary:
		lingering_calls.append({
			"weapon_id": weapon_id,
			"projectile": projectile,
			"context": context,
		})
		return {"source": "fake_lingering"}


func _init() -> void:
	_verify_direct_projectile_impact_state()
	_verify_environment_impact_state()
	_verify_fire_support_impact_screen_shake()

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

	var hit_events: Array = [{"id": 1}, {"id": 2}]
	var appended_event: Dictionary = CommandoFirearmProjectileImpactState.append_runtime_hit_event(
		hit_events,
		{"id": 8},
		"net_gun",
		"net",
		Vector2(40.0, 50.0),
		Vector2(1.0, -2.0),
		0.62,
		{"slow_multiplier": 0.35},
		2
	)
	_expect(int(appended_event.get("id", 0)) == 8, "runtime hit-event append should return appended event")
	_expect(hit_events.size() == 2, "runtime hit-event append should enforce bounded event history")
	var oldest_hit_event: Dictionary = hit_events[0] as Dictionary
	var newest_hit_event: Dictionary = hit_events[1] as Dictionary
	_expect(int(oldest_hit_event.get("id", 0)) == 2, "runtime hit-event append should drop oldest event over the limit")
	_expect(str(newest_hit_event.get("weapon_id", "")) == "net_gun", "runtime hit-event append should preserve weapon id")

	var impact_effects := FakeImpactEffects.new()
	var feedback := FakeFeedback.new()
	var animation_state := FakeAnimationState.new()
	var ball_effects := FakeBallEffects.new()
	var audio := FakeAudio.new()
	var boss_hit_events: Array = []
	var boss_event: Dictionary = CommandoFirearmProjectileImpactState.append_runtime_boss_hit(
		boss_hit_events,
		{
			"id": 9,
			"weapon_id": "net_gun",
			"kind": "net",
			"pos": Vector2(60.0, 70.0),
			"velocity": Vector2(3.0, 4.0),
			"color": Color.RED,
		},
		"net_gun",
		{"intensity": 0.62, "shake_amount": 0.09, "shake_intensity": 1.7},
		{"damage_units": 1},
		{"boss_vel": -12.0, "boss_has_hit_sprite": true},
		{
			"impact_effects": impact_effects,
			"feedback": feedback,
			"animation_state": animation_state,
			"ball_effects": ball_effects,
			"audio": audio,
		},
		"pistol",
		4
	)
	_expect(int(boss_event.get("id", 0)) == 9, "runtime boss-hit helper should return appended hit event")
	_expect(boss_hit_events.size() == 1, "runtime boss-hit helper should append hit-event history")
	_expect(impact_effects.particles.size() == 1, "runtime boss-hit helper should spawn impact particles")
	_expect(feedback.calls.size() == 1, "runtime boss-hit helper should trigger hit feedback")
	_expect(animation_state.calls.size() == 1, "runtime boss-hit helper should trigger boss hit animation")
	_expect(ball_effects.pulses.size() == 1, "runtime boss-hit helper should register ball hit pulse")
	_expect(audio.impact_calls == ["net_gun"], "runtime boss-hit helper should play impact audio")

	var impact_owner := FakeRuntimeOwner.new()
	var runtime_impact_flashes: Array = []
	var wall_impact_effects := FakeImpactEffects.new()
	var wall_feedback := FakeFeedback.new()
	var wall_audio := FakeAudio.new()
	var wall_result: Dictionary = CommandoFirearmProjectileImpactState.dispatch_runtime_impact(
		runtime_impact_flashes,
		impact_owner,
		{
			"id": 10,
			"weapon_id": "bazooka",
			"kind": "rocket",
			"pos": Vector2(20.0, 30.0),
			"velocity": Vector2(0.0, -1.0),
			"color": Color(1.0, 0.5, 0.0),
		},
		"wall",
		"bazooka",
		{},
		{
			"impact_effects": wall_impact_effects,
			"feedback": wall_feedback,
			"audio": wall_audio,
		},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		24.0,
		4
	)
	_expect(runtime_impact_flashes.size() == 1, "runtime impact dispatcher should append impact flash")
	_expect(bool(wall_result.get("commando_firearm_environment_impact", false)), "runtime impact dispatcher should return wall impact result")
	_expect(wall_impact_effects.particles.size() == 1, "runtime impact dispatcher should route wall particles")
	_expect(wall_feedback.calls.size() >= 2 and _has_bazooka_explosion_shake(wall_feedback.calls), "runtime impact dispatcher should route wall hit feedback plus bazooka explosion shake")
	_expect(wall_audio.impact_calls == ["bazooka"], "runtime impact dispatcher should route wall audio")
	CommandoFirearmProjectileImpactState.dispatch_runtime_impact(
		runtime_impact_flashes,
		impact_owner,
		{
			"id": 11,
			"weapon_id": "ak47",
			"kind": "bullet",
			"pos": Vector2(330.0, 70.0),
			"velocity": Vector2(0.0, -10.0),
		},
		"target",
		"ak47",
		{},
		{},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		24.0,
		4
	)
	_expect(impact_owner.boss_hits.size() == 1, "runtime impact dispatcher should call boss-hit bridge for target impacts")
	CommandoFirearmProjectileImpactState.dispatch_runtime_impact(
		runtime_impact_flashes,
		impact_owner,
		{
			"id": 12,
			"weapon_id": "net_gun",
			"kind": "net",
			"pos": Vector2(330.0, 90.0),
			"velocity": Vector2(0.0, -10.0),
		},
		"expired",
		"net_gun",
		{},
		{},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		24.0,
		4
	)
	_expect(impact_owner.lingering_calls.size() == 1, "runtime impact dispatcher should spawn net dissolve lingering effects")

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
	var motion_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_projectile_motion_state.gd")
	_expect(runtime_source.find("func _get_projectile_impact_reason(") == -1, "runtime should not keep projectile impact reason bridge")
	_expect(runtime_source.find("func _register_projectile_environment_impact(") == -1, "runtime should not keep projectile environment-impact bridge")
	_expect(runtime_source.find("CommandoFirearmProjectileImpactState.register_runtime_projectile_hit") != -1, "runtime should delegate projectile-hit registration to projectile impact owner")
	_expect(runtime_source.find("CommandoFirearmProjectileMotionState.advance_runtime_projectiles") != -1, "runtime should delegate projectile update orchestration to motion owner")
	_expect(motion_source.find("CommandoFirearmProjectileImpactState.dispatch_runtime_impact") != -1, "projectile motion owner should delegate projectile impact side effects to projectile impact owner")
	var impact_source: String = FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_projectile_impact_state.gd")
	_expect(impact_source.find("CommandoFirearmProjectileImpactState.append_runtime_boss_hit") == -1, "projectile impact owner should call boss-hit append directly")
	_expect(impact_source.find("append_runtime_boss_hit") != -1, "projectile impact owner should own boss-hit append and feedback")
	_expect(runtime_source.find("CommandoFirearmProjectileImpactState.append_runtime_hit_event") == -1, "runtime should not call the lower-level hit-event append helper directly")
	_expect(runtime_source.find("CommandoFirearmProjectileImpactState.register_environment_impact") == -1, "runtime should not call the lower-level environment-impact helper directly")
	_expect(runtime_source.find("CommandoFirearmProjectileImpactState.build_hit_event(") == -1, "runtime should not build projectile hit events inline")
	_expect(runtime_source.find("CommandoFirearmStage2RockInteractionResolver") == -1, "runtime should not own projectile impact rock cleanup")
	_expect(runtime_source.find("CommandoFirearmHitGeometry.is_net_gun_weapon") == -1, "runtime should not own net-gun impact dissolve branching")


func _verify_fire_support_impact_screen_shake() -> void:
	var impact_flashes: Array = []
	var feedback := FakeFeedback.new()
	var impact_effects := FakeImpactEffects.new()
	var audio := FakeAudio.new()
	CommandoFirearmProjectileImpactState.dispatch_runtime_impact(
		impact_flashes,
		null,
		{
			"id": 42,
			"weapon_id": "fire_support",
			"kind": "support",
			"pos": Vector2(380.0, 24.0),
			"velocity": Vector2(0.0, 12.0),
			"color": Color(1.0, 0.34, 0.16),
			"secondary": Color(1.0, 0.82, 0.25),
		},
		"wall",
		"fire_support",
		{},
		{
			"feedback": feedback,
			"impact_effects": impact_effects,
			"audio": audio,
		},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		48.0,
		4
	)
	_expect(feedback.calls.size() >= 2, "fire-support wall impact should trigger both the per-hit feedback AND the dedicated airstrike screen shake")
	var has_explosion_shake: bool = false
	for entry_value in feedback.calls:
		var entry: Dictionary = entry_value
		if float(entry.get("amount", 0.0)) >= 1.5 and float(entry.get("intensity", 0.0)) >= 10.0:
			has_explosion_shake = true
			break
	_expect(has_explosion_shake, "fire-support airstrike must apply the dedicated big-bomb screen shake amount/intensity")

	var bazooka_flashes: Array = []
	var bazooka_feedback := FakeFeedback.new()
	CommandoFirearmProjectileImpactState.dispatch_runtime_impact(
		bazooka_flashes,
		null,
		{
			"id": 43,
			"weapon_id": "bazooka",
			"kind": "rocket",
			"pos": Vector2(120.0, 80.0),
			"velocity": Vector2(0.0, -8.0),
		},
		"wall",
		"bazooka",
		{},
		{"feedback": bazooka_feedback},
		CommandoFirearmRuntime.WEAPON_PROFILES,
		CommandoFirearmRuntime.WEAPON_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.WEAPON_HIT_FEEDBACK,
		CommandoFirearmRuntime.HIT_FEEDBACK_PROFILE_OVERRIDES,
		CommandoFirearmRuntime.BASE_WEAPON_ID,
		24.0,
		4
	)
	_expect(bazooka_feedback.calls.size() >= 2, "bazooka wall impact should trigger both the per-hit feedback and a dedicated explosion screen shake")
	_expect(_has_bazooka_explosion_shake(bazooka_feedback.calls), "bazooka explosion screen shake should keep grenade duration with 50 percent intensity")


func _has_bazooka_explosion_shake(calls: Array) -> bool:
	var expected_bazooka_amount: float = ActiveItemThrowController.GRENADE_SCREEN_SHAKE_AMOUNT
	var expected_bazooka_intensity: float = ActiveItemThrowController.GRENADE_SCREEN_SHAKE_INTENSITY * 0.5
	for entry_value in calls:
		var entry: Dictionary = entry_value
		if (
			is_equal_approx(float(entry.get("amount", 0.0)), expected_bazooka_amount)
			and is_equal_approx(float(entry.get("intensity", 0.0)), expected_bazooka_intensity)
		):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
