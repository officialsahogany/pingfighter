extends SceneTree

const DragonBreathSkill := preload("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")


class FakeOwner:
	extends RefCounted
	var boss_pos := Vector2(180.0, 45.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := false
	var ball_pos := Vector2(380.0, 700.0)
	var ball_vel := Vector2.ZERO
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
	# Do NOT launch -> no live breath spawning extra zones. Isolate ONE patch.
	skill.call("_spawn_fire_zone", Vector2(380.0, 60.0))

	# Boss tries to march from left (180) across to the right (580). The fire
	# patch is centered at x=380. Each frame: boss AI moves first, then the
	# breath update runs (real order: update_boss_ai -> update_lingpet).
	owner.boss_pos = Vector2(180.0, 45.0)
	var target_x := 580.0
	var max_center := owner.boss_pos.x + 50.0
	var zone_alive_frames := 0
	for _frame in range(240):
		var bx: float = move_toward(owner.boss_pos.x, target_x, 220.0 / 60.0)
		owner.boss_pos = Vector2(bx, owner.boss_pos.y)
		skill.update(1.0 / 60.0, owner, registry)
		# Only measure crossing WHILE the fire patch is alive (it's a 2s patch).
		if int(skill.get_snapshot().get("dragon_breath_fire_zone_count", 0)) > 0:
			zone_alive_frames += 1
			max_center = maxf(max_center, owner.boss_pos.x + 50.0)
	print("zone_alive_frames=%d" % zone_alive_frames)
	var fire_left_edge := 380.0 - (50.0 + 50.0)  # center - (width*0.5 + boss_w*0.5)
	print("fire_center=380  fire_left_edge(center)=%.0f  boss_max_center_while_alive=%.1f" % [fire_left_edge, max_center])
	if max_center < 380.0:
		print("RESULT: BLOCKED - boss held on the near side of the live fire patch (~%.0f)" % max_center)
		quit(0)
	else:
		print("RESULT: PASSED THROUGH - boss crossed to %.0f while patch alive" % max_center)
		quit(1)
