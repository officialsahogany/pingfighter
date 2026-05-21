extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const Stage2WaterVisualState := preload("res://scripts/stages/stage2/stage2_water_visual_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_trail_life_compaction()
	_verify_splash_motion()
	_verify_background_delegates_water_visuals()

	if _failures.is_empty():
		print("stage2_water_visual_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_trail_life_compaction() -> void:
	var trail := [
		{"life": 0.5, "pos": Vector2.ZERO},
		{"life": 0.05, "pos": Vector2.ONE},
	]
	Stage2WaterVisualState.update_trail(trail, 0.1)
	_expect(trail.size() == 1, "water trail state should compact expired trail entries")
	_expect(is_equal_approx(float((trail[0] as Dictionary).get("life", 0.0)), 0.4), "water trail state should decrement survivor life")


func _verify_splash_motion() -> void:
	var splash := {
		"life": 1.0,
		"pos": Vector2(10.0, 20.0),
		"vel": Vector2(30.0, 40.0),
		"gravity": 300.0,
		"rot": 0.2,
		"spin": 1.5,
	}
	var alive := Stage2WaterVisualState.update_splash(splash, 0.1)
	_expect(alive, "water splash state should keep live splashes")
	_expect(Vector2(splash.get("pos", Vector2.ZERO)).y > 20.0, "water splash state should advance y position")
	_expect(Vector2(splash.get("vel", Vector2.ZERO)).y > 40.0, "water splash state should apply gravity before drag")
	_expect(is_equal_approx(float(splash.get("life", 0.0)), 0.9), "water splash state should decrement life")
	_expect(float(splash.get("rot", 0.0)) > 0.2, "water splash state should advance rotation")


func _verify_background_delegates_water_visuals() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(
		source.find("Stage2WaterVisualState.update_trail") >= 0,
		"Stage 2 background source should delegate water trail state"
	)
	_expect(
		source.find("Stage2WaterVisualState.update_splashes") >= 0,
		"Stage 2 background source should delegate water splash state"
	)
	_expect(
		source.find("water_cannon_payload_config_builder.build_config") >= 0
			and source.find("func _get_water_cannon_payload_config") < 0,
		"Stage 2 water cannon fragments should build payload config at the spawn site without a pass-through wrapper"
	)
	var background := Stage2PillarBackground.new()
	background.water_trail = [
		{"life": 0.5, "pos": Vector2.ZERO},
		{"life": 0.05, "pos": Vector2.ONE},
	]
	background.water_splashes = [{
		"life": 1.0,
		"pos": Vector2(10.0, 20.0),
		"vel": Vector2(30.0, 40.0),
		"gravity": 300.0,
	}]
	background._update_water_visuals(0.1)
	_expect(background.water_trail.size() == 1, "Stage 2 background should compact delegated water trail")
	_expect(background.water_splashes.size() == 1, "Stage 2 background should keep delegated live splash")
	_expect(
		Vector2((background.water_splashes[0] as Dictionary).get("pos", Vector2.ZERO)).y > 20.0,
		"Stage 2 background should use delegated water splash motion"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
