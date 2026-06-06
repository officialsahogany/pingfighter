extends SceneTree

# Dev-only: quantify how often the breath actually hits the ball and how often
# the boss is standing in a fire zone, under realistic mid-field-companion play.

const DragonBreathSkill := preload("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")


class FakeOwner:
	extends RefCounted
	var boss_pos := Vector2(280.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := true
	var ball_pos := Vector2(380.0, 600.0)
	var ball_vel := Vector2(110.0, -320.0)
	var ball_size := 28.6


class FakeStatus:
	extends RefCounted
	func apply_status(_t: String, _s: String, _d: float, _data: Dictionary = {}, _src: String = "") -> Dictionary:
		return {}
	func clear_status(_t: String, _s: String = "", _src: String = "") -> void:
		pass


class FakeRegistry:
	extends RefCounted
	var status_effect_state: Object = FakeStatus.new()
	func get_cached_instance(key: String) -> Object:
		return get_instance(key)
	func get_instance(key: String) -> Object:
		return status_effect_state if key == "status_effect_state" else null


func _init() -> void:
	# Average over several companion x positions + ball phases.
	var total_hits := 0
	var total_boss_in_fire_frames := 0
	var total_zone_frames := 0
	var runs := 0
	for comp_x in [220.0, 320.0, 380.0, 460.0, 540.0]:
		for ball_phase in [0, 35, 70, 110]:
			runs += 1
			var res := _run_one(comp_x, ball_phase)
			total_hits += int(res["hits"])
			total_boss_in_fire_frames += int(res["boss_in_fire_frames"])
			total_zone_frames += int(res["zone_frames"])
	print("runs=%d  avg_ball_hits=%.2f  avg_boss_in_fire_frames=%.1f  avg_zone_active_frames=%.1f" % [
		runs,
		float(total_hits) / float(runs),
		float(total_boss_in_fire_frames) / float(runs),
		float(total_zone_frames) / float(runs),
	])
	quit(0)


func _run_one(comp_x: float, ball_phase: int) -> Dictionary:
	seed(1000 + int(comp_x) + ball_phase)
	var skill: Object = DragonBreathSkill.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	# Ball starting phase: advance it a bit so each run samples a different path.
	owner.ball_pos = Vector2(380.0, 600.0)
	owner.ball_vel = Vector2(110.0, -320.0)
	for _p in range(ball_phase):
		_advance_ball(owner, 1.0 / 60.0)
	skill.launch(Vector2(comp_x, 300.0), owner)
	var boss_in_fire_frames := 0
	var zone_frames := 0
	var boss_dir := 1.0
	# 3.7s of breath life.
	for frame in range(222):
		# Boss patrols the top horizontally.
		var bx := owner.boss_pos.x + boss_dir * 150.0 * (1.0 / 60.0)
		if bx < 80.0:
			bx = 80.0
			boss_dir = 1.0
		elif bx > 580.0:
			bx = 580.0
			boss_dir = -1.0
		owner.boss_pos = Vector2(bx, owner.boss_pos.y)
		_advance_ball(owner, 1.0 / 60.0)
		skill.update(1.0 / 60.0, owner, registry, {"companion_pos": Vector2(comp_x, 300.0), "companion_radius": 16.0})
		var snap: Dictionary = skill.get_snapshot()
		if bool(snap.get("dragon_breath_boss_in_fire", false)):
			boss_in_fire_frames += 1
		if int(snap.get("dragon_breath_fire_zone_count", 0)) > 0:
			zone_frames += 1
	return {
		"hits": skill.get_ball_hit_count_for_tests(),
		"boss_in_fire_frames": boss_in_fire_frames,
		"zone_frames": zone_frames,
	}


func _advance_ball(owner: FakeOwner, dt: float) -> void:
	var p: Vector2 = owner.ball_pos + owner.ball_vel * dt
	var v: Vector2 = owner.ball_vel
	if p.x < 20.0:
		p.x = 20.0
		v.x = absf(v.x)
	elif p.x > 740.0:
		p.x = 740.0
		v.x = -absf(v.x)
	if p.y < 45.0:
		p.y = 45.0
		v.y = absf(v.y)
	elif p.y > 705.0:
		p.y = 705.0
		v.y = -absf(v.y)
	owner.ball_pos = p
	owner.ball_vel = v
