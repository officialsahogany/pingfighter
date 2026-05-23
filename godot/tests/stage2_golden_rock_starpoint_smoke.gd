extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")


class FakeAudio:
	var stonebreak_count := 0
	var starpoint_collect_count := 0

	func play_stage2_stonebreak() -> void:
		stonebreak_count += 1

	func play_starpoint_collect() -> void:
		starpoint_collect_count += 1


class FakeMythicRuntime:
	var bonus_roll_count := 0

	func roll_star_detector_bonus_drop_count() -> int:
		bonus_roll_count += 1
		return 1


class FakeRuntimePerkState:
	var collected_star_points := 0

	func collect_star_points(amount: int, _character_type: String, _catalog: Object = null, _owner: Object = null, _registry: Object = null) -> bool:
		collected_star_points += max(0, amount)
		return false


class FakeOwner:
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


func _init() -> void:
	seed(97531)
	var stage2_background: Object = Stage2PillarBackground.new()
	stage2_background.activate_quake(0.5, 1, false, false)
	stage2_background.update(4.0, {"current_stage": 2, "ball_active": true}, {})
	_expect(stage2_background.get_rock_count() == 1, "test setup should land one Stage 2 rock")

	var live_rock: Dictionary = stage2_background.rocks[0]
	live_rock["is_golden"] = true
	live_rock["style_type"] = "golden_rock"
	stage2_background.rocks[0] = live_rock

	var rocks: Array = stage2_background.get_rocks_snapshot()
	var first_rock: Dictionary = rocks[0]
	var rock_pos: Vector2 = _as_vector2(first_rock.get("pos", Vector2.ZERO), Vector2.ZERO)
	var scene := {
		"previous_ball_pos": rock_pos + Vector2(-80.0, 0.0),
		"ball_pos": rock_pos + Vector2(80.0, 0.0),
		"ball_vel": Vector2(9.0, 0.0),
	}
	var context := {
		"current_stage": 2,
		"ball_size": 28.6,
	}
	var audio := FakeAudio.new()
	var mythic_runtime := FakeMythicRuntime.new()
	_expect(stage2_background.resolve_ball_collision(scene, context, {
		"audio": audio,
		"mythic_item_runtime": mythic_runtime,
	}), "golden Stage 2 rock should break on ball collision")
	_expect(audio.stonebreak_count == 1, "golden Stage 2 rock should play break audio")
	_expect(stage2_background.get_starpoint_drop_count() == 2, "golden Stage 2 rock should drop one starpoint plus Star Detector bonus")
	_expect(_count_star_detector_bonus_drops(stage2_background.get_starpoint_drops_snapshot()) == 1, "bonus starpoint should be marked as Star Detector bonus")
	_expect(mythic_runtime.bonus_roll_count == 1, "golden Stage 2 rock should roll Star Detector bonus once")

	var starpoint_snapshot: Array = stage2_background.get_starpoint_drops_snapshot()
	var first_drop: Dictionary = starpoint_snapshot[0]
	var drop_pos: Vector2 = _as_vector2(first_drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	var perk_state := FakeRuntimePerkState.new()
	var owner := FakeOwner.new()
	var collect_context: Dictionary = context.duplicate()
	collect_context["owner"] = owner
	collect_context["selected_character_type"] = "smasher"
	collect_context["player_pos"] = drop_pos - Vector2(90.0, 90.0)
	collect_context["player_paddle_size"] = Vector2(180.0, 180.0)
	stage2_background.update(0.0, collect_context, {
		"runtime_perk_state": perk_state,
		"audio": audio,
	})
	_expect(perk_state.collected_star_points == 2, "player paddle should collect golden-rock starpoints")
	_expect(stage2_background.get_starpoint_drop_count() == 0, "collected starpoints should be removed")
	_expect(audio.starpoint_collect_count == 2, "collecting golden-rock starpoints should play collect audio")
	_expect(owner.redraw_count >= 1, "collecting golden-rock starpoints should request redraw")

	print("stage2_golden_rock_starpoint_smoke: ok")
	quit(0)


func _count_star_detector_bonus_drops(drops: Array) -> int:
	var count := 0
	for drop_value in drops:
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		if bool(drop.get("star_detector_bonus", false)):
			count += 1
	return count


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
