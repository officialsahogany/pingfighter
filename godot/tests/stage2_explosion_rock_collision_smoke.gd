extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 2
	var boss_pos := Vector2(620.0, 40.0)


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


class FakeFeedback:
	extends RefCounted

	var shake_calls := 0

	func max_screen_shake(_amount: float, _intensity: float) -> void:
		shake_calls += 1


class FakeAudio:
	extends RefCounted

	var grenade_explosion_calls := 0
	var stonebreak_calls := 0
	var rockhit_calls := 0

	func play_grenade_explosion() -> void:
		grenade_explosion_calls += 1

	func play_stage2_stonebreak_for_size(_size: float) -> void:
		stonebreak_calls += 1

	func play_stage2_rockhit() -> void:
		rockhit_calls += 1

	func play_commando_bazooka_impact() -> void:
		pass

	func play_commando_fire_support_bomb() -> void:
		pass


func _init() -> void:
	_verify_explosion_touch_breaks_landed_rock()
	_verify_explosion_collision_guards_stage_and_falling_rocks()
	_verify_grenade_explosion_breaks_stage2_rock()
	_verify_commando_bazooka_explosion_breaks_stage2_rock()
	_verify_commando_fire_support_explosion_breaks_stage2_rock()
	_verify_commando_pistol_bounces_off_stage2_rock()
	_verify_commando_pistol_is_consumed_after_stage2_rock_bounce_limit()

	if _failures.is_empty():
		print("stage2_explosion_rock_collision_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_explosion_touch_breaks_landed_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(1, Vector2(300.0, 300.0))]
	var destroyed: int = background.resolve_explosion_rock_collision(
		Vector2(220.0, 300.0),
		60.0,
		{},
		{"current_stage": 2}
	)
	_expect(destroyed == 1, "explosion circle should destroy rocks when it touches their radius")
	_expect(int(background.get_rock_count()) == 0, "touched rock should be removed")
	_expect(int(background.get_rock_fragment_count()) > 0, "explosion rock destruction should reuse the normal fragment path")


func _verify_explosion_collision_guards_stage_and_falling_rocks() -> void:
	var stage_guard: Object = Stage2PillarBackground.new()
	stage_guard.rocks = [_build_landed_rock(2, Vector2(300.0, 300.0))]
	var ignored_stage: int = stage_guard.resolve_explosion_rock_collision(
		Vector2(300.0, 300.0),
		80.0,
		{},
		{"current_stage": 1}
	)
	_expect(ignored_stage == 0 and int(stage_guard.get_rock_count()) == 1, "explosion rock collision should be Stage 2 only")

	var falling_guard: Object = Stage2PillarBackground.new()
	var falling_rock: Dictionary = _build_landed_rock(3, Vector2(300.0, 300.0))
	falling_rock["falling"] = true
	falling_guard.rocks = [falling_rock]
	var ignored_falling: int = falling_guard.resolve_explosion_rock_collision(
		Vector2(300.0, 300.0),
		80.0,
		{},
		{"current_stage": 2}
	)
	_expect(ignored_falling == 0 and int(falling_guard.get_rock_count()) == 1, "falling rocks should not be destroyed before landing")

	var miss_guard: Object = Stage2PillarBackground.new()
	miss_guard.rocks = [_build_landed_rock(4, Vector2(420.0, 300.0))]
	var missed: int = miss_guard.resolve_explosion_rock_collision(
		Vector2(300.0, 300.0),
		60.0,
		{},
		{"current_stage": 2}
	)
	_expect(missed == 0 and int(miss_guard.get_rock_count()) == 1, "rocks outside the explosion radius should survive")


func _verify_grenade_explosion_breaks_stage2_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(5, Vector2(300.0, 300.0))]
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"stage2_pillar_background": background,
		"battle_feedback_state": FakeFeedback.new(),
		"game_audio": audio,
	}
	ActiveItemThrowController.new()._trigger_grenade_explosion(FakeOwner.new(), registry, Vector2(300.0, 300.0))
	_expect(int(background.get_rock_count()) == 0, "grenade explosion should destroy touched Stage 2 rocks")
	_expect(audio.grenade_explosion_calls == 1, "grenade explosion should keep its own explosion audio")
	_expect(audio.stonebreak_calls == 1, "grenade rock destruction should play the Stage 2 rock break cue")


func _verify_commando_bazooka_explosion_breaks_stage2_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(6, Vector2(40.0, 20.0))]
	var runtime := CommandoFirearmRuntime.new()
	runtime.projectiles.append({
		"id": 600,
		"weapon_id": "bazooka",
		"kind": "rocket",
		"pos": Vector2(40.0, 35.0),
		"prev_pos": Vector2(40.0, 55.0),
		"velocity": Vector2(0.0, -20.0),
		"speed": 20.0,
		"radius": 9.5,
		"impact_radius": 46.0,
		"explosion_radius": CommandoFirearmRuntime.BAZOOKA_EXPLOSION_RADIUS,
		"life_frames": 30.0,
		"target": Vector2(40.0, 80.0),
		"color": Color(1.0, 0.46, 0.18),
	})
	var result: Dictionary = runtime.update_effects(
		1.0,
		Time.get_ticks_msec(),
		_stage2_commando_context(),
		_stage2_commando_deps(background)
	)
	_expect(bool(result.get("commando_firearm_environment_impact", false)), "bazooka setup should resolve as an environment explosion")
	_expect(int(background.get_rock_count()) == 0, "bazooka explosion should destroy touched Stage 2 rocks")


func _verify_commando_fire_support_explosion_breaks_stage2_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(7, Vector2(300.0, 120.0))]
	var runtime := CommandoFirearmRuntime.new()
	runtime.projectiles.append({
		"id": 700,
		"weapon_id": "fire_support",
		"kind": "support",
		"pos": Vector2(300.0, 120.0),
		"prev_pos": Vector2(300.0, 100.0),
		"velocity": Vector2.ZERO,
		"radius": 7.0,
		"life_frames": 120.0,
		"target": Vector2(300.0, 120.0),
		"target_y": 120.0,
		"color": Color(1.0, 0.34, 0.16),
	})
	runtime.update_effects(
		1.0,
		Time.get_ticks_msec(),
		_stage2_commando_context(),
		_stage2_commando_deps(background)
	)
	_expect(int(background.get_rock_count()) == 0, "fire-support bomb explosion should destroy touched Stage 2 rocks")


func _verify_commando_pistol_bounces_off_stage2_rock() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(8, Vector2(300.0, 300.0))]
	var runtime := CommandoFirearmRuntime.new()
	runtime.projectiles.append({
		"id": 800,
		"weapon_id": "commando_pistol",
		"kind": "bullet",
		"pos": Vector2(300.0, 260.0),
		"prev_pos": Vector2(300.0, 260.0),
		"velocity": Vector2(0.0, 25.0),
		"speed": 25.0,
		"radius": 5.0,
		"life_frames": 30.0,
		"target": Vector2(300.0, 80.0),
		"color": Color(1.0, 0.86, 0.40),
	})
	var audio := FakeAudio.new()
	var result: Dictionary = runtime.update_effects(
		1.0,
		Time.get_ticks_msec(),
		_stage2_commando_context(),
		_stage2_commando_deps(background, audio)
	)
	_expect(not bool(result.get("commando_firearm_environment_impact", false)), "pistol rock ricochet should not become an environment impact")
	_expect(runtime.projectiles.size() == 1, "pistol should keep flying after the first Stage 2 rock bounce")
	_expect(int(background.get_rock_count()) == 1, "pistol rock ricochet should not destroy the rock")
	_expect(audio.rockhit_calls == 1, "pistol rock ricochet should play the rock-hit cue")
	var bullet: Dictionary = runtime.projectiles[0]
	var velocity: Vector2 = bullet.get("velocity", Vector2.ZERO)
	_expect(velocity.y < 0.0, "pistol should ricochet upward after striking the top of a rock")
	_expect(is_equal_approx(abs(velocity.y), 22.0), "pistol rock ricochet should use the original 0.88 damping")
	_expect(int(bullet.get("rock_bounces", 0)) == 1, "pistol rock ricochet should increment its bounce count")
	_expect(str(bullet.get("stage2_rock_bounce_side", "")) == "top", "pistol ricochet should record the contacted rock side")


func _verify_commando_pistol_is_consumed_after_stage2_rock_bounce_limit() -> void:
	var background: Object = Stage2PillarBackground.new()
	background.rocks = [_build_landed_rock(9, Vector2(300.0, 300.0))]
	var runtime := CommandoFirearmRuntime.new()
	runtime.projectiles.append({
		"id": 900,
		"weapon_id": "commando_pistol",
		"kind": "bullet",
		"pos": Vector2(300.0, 260.0),
		"prev_pos": Vector2(300.0, 260.0),
		"velocity": Vector2(0.0, 25.0),
		"speed": 25.0,
		"radius": 5.0,
		"life_frames": 30.0,
		"target": Vector2(300.0, 80.0),
		"rock_bounces": 2,
		"color": Color(1.0, 0.86, 0.40),
	})
	var audio := FakeAudio.new()
	runtime.update_effects(
		1.0,
		Time.get_ticks_msec(),
		_stage2_commando_context(),
		_stage2_commando_deps(background, audio)
	)
	_expect(runtime.projectiles.is_empty(), "pistol should disappear when it hits a rock after two ricochets")
	_expect(int(background.get_rock_count()) == 1, "bounce-limit consumption should still leave the rock intact")
	_expect(audio.rockhit_calls == 0, "bounce-limit consumption should not play a fresh ricochet cue")


func _stage2_commando_context() -> Dictionary:
	return {
		"current_stage": 2,
		"boss_pos": Vector2(620.0, 62.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_vel": 0.0,
		"width": 760.0,
		"height": 750.0,
	}


func _stage2_commando_deps(background: Object, audio: Object = null) -> Dictionary:
	var resolved_audio: Object = audio if audio != null else FakeAudio.new()
	return {
		"current_stage": 2,
		"stage_background": background,
		"feedback": FakeFeedback.new(),
		"audio": resolved_audio,
	}


func _build_landed_rock(rock_id: int, center: Vector2) -> Dictionary:
	return {
		"id": rock_id,
		"pos": center,
		"target_pos": center,
		"quake_offset": Vector2.ZERO,
		"falling": false,
		"drop_delay": 0.0,
		"radius": 20.0,
		"visual_radius": 40.0,
		"hp": 1,
		"life": -1.0,
		"flash": 0.0,
		"water_target_flash": 0.0,
		"phase": 0.0,
		"seed": rock_id,
		"style_type": "gray_stone",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
