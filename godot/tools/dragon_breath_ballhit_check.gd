extends SceneTree

const DragonBreathSkill := preload("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")


class FakeOwner:
	extends RefCounted
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := true
	var ball_pos := Vector2(380.0, 150.0)
	var ball_vel := Vector2(0.0, 280.0)  # heading DOWN toward the player
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
	var skill: Object = DragonBreathSkill.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var comp := Vector2(380.0, 300.0)
	skill.launch(comp, owner)
	owner.ball_pos = Vector2(380.0, 150.0)
	owner.ball_vel = Vector2(0.0, 280.0)
	var reversed_at := -1
	var prev_hits := 0
	for frame in range(150):
		# Ball moves first (update_ball runs before update_lingpet).
		var p: Vector2 = owner.ball_pos + owner.ball_vel * (1.0 / 60.0)
		var v: Vector2 = owner.ball_vel
		if p.y < 45.0:
			p.y = 45.0
			v.y = absf(v.y)
		elif p.y > 705.0:
			p.y = 705.0
			v.y = -absf(v.y)
		owner.ball_pos = p
		owner.ball_vel = v
		# Dragon breath update (reflects if the ball is in the heat cone).
		skill.update(1.0 / 60.0, owner, registry, {"companion_pos": comp, "companion_radius": 16.0})
		var hits := int(skill.get_ball_hit_count_for_tests())
		if hits > prev_hits:
			print("  HIT @f%d  ball_y=%.0f  vel_before_y=%.0f  vel_after=(%.0f,%.0f)  reversed=%s" % [
				frame, owner.ball_pos.y, v.y, owner.ball_vel.x, owner.ball_vel.y, str(owner.ball_vel.y < 0.0)])
			if owner.ball_vel.y < 0.0 and reversed_at < 0:
				reversed_at = frame
			prev_hits = hits
	print("total_hits=%d  reversed_at_frame=%d" % [skill.get_ball_hit_count_for_tests(), reversed_at])
	if int(skill.get_ball_hit_count_for_tests()) >= 1 and reversed_at >= 0:
		print("RESULT: HIT WORKS - downward ball was struck and reversed toward the boss")
		quit(0)
	else:
		print("RESULT: NO HIT - the breath did not strike the ball")
		quit(1)
