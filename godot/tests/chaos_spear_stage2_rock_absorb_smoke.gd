extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")


class FakeAudio:
	var stonebreak_count := 0
	var rock_spawn_count := 0
	var quake_start_count := 0
	var quake_stop_count := 0

	func play_stage2_stonebreak() -> void:
		stonebreak_count += 1

	func play_stage2_stonebreak_for_size(_size: float) -> void:
		stonebreak_count += 1

	func play_stage2_rock_spawn() -> void:
		rock_spawn_count += 1

	func play_stage2_quake_loop() -> void:
		quake_start_count += 1

	func stop_stage2_quake_loop() -> void:
		quake_stop_count += 1


func _init() -> void:
	var background: Object = Stage2PillarBackground.new()
	var audio := FakeAudio.new()
	var deps := {"audio": audio}
	var context := {"current_stage": 2, "ball_active": true}
	background.reset()
	background.activate_quake(0.5, 1, false, false, deps)
	for _i in range(260):
		background.update(1.0 / 60.0, context, deps)

	var landed_rocks: Array = background.get_rocks_snapshot()
	_expect(landed_rocks.size() == 1, "test setup should leave one Stage 2 rock")
	_expect(not bool(landed_rocks[0].get("falling", true)), "test setup rock should be landed")
	var start_pos: Vector2 = _rock_center_from_snapshot(landed_rocks[0])
	var chaos_center := start_pos + Vector2(190.0, -120.0)

	var entries: Array = background.absorb_chaos_spear_objects(chaos_center, 1.0, deps)
	_expect(entries.is_empty(), "Chaos Spear should start pulling Stage 2 rocks instead of deleting them immediately")
	_expect(background.get_rock_count() == 1, "rock should remain visible while being pulled")
	_expect(bool(background.get_rocks_snapshot()[0].get("chaos_absorbing", false)), "rock should be marked as chaos-absorbing")

	var moved := false
	for frame in range(240):
		if frame % 5 == 0:
			entries.append_array(background.absorb_chaos_spear_objects(chaos_center, 1.0, deps))
		background.update(1.0 / 60.0, context, deps)
		if background.get_rock_count() > 0:
			var current_pos: Vector2 = _rock_center_from_snapshot(background.get_rocks_snapshot()[0])
			if current_pos.distance_to(start_pos) > 2.0:
				moved = true
		else:
			entries.append_array(background.absorb_chaos_spear_objects(chaos_center, 1.0, deps))
			break

	_expect(moved, "Stage 2 rock should visibly spiral toward the Chaos Spear center before breaking")
	_expect(background.get_rock_count() == 0, "Stage 2 rock should break after reaching the Chaos Spear center")
	_expect(background.get_rock_fragment_count() > 0, "Chaos-broken rock should spawn debris fragments")
	_expect(audio.stonebreak_count >= 1, "Chaos-broken rock should play the stone break sound")
	_expect(entries.size() >= 1, "Chaos Spear should receive a destroyed-object entry for skill gold and absorb pulse")

	print("chaos_spear_stage2_rock_absorb_smoke: ok")
	quit(0)


func _rock_center_from_snapshot(rock: Dictionary) -> Vector2:
	var fallback: Vector2 = _as_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	var target: Vector2 = _as_vector2(rock.get("target_pos", fallback), fallback)
	if rock.has("fall_y"):
		var y: float = float(rock.get("fall_y", target.y)) if bool(rock.get("falling", false)) else target.y
		return Vector2(target.x, y) + _as_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
	return fallback + _as_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
