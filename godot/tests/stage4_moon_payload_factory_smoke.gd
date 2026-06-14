extends SceneTree

const Stage4MoonPayloadFactory := preload("res://scripts/stages/stage4/stage4_moon_payload_factory.gd")
const Stage4MoonEvent := preload("res://scripts/stages/stage4/stage4_moon_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_fragment_payload()
	_verify_zero_distance_target_fallback()
	_verify_event_delegates_fragment_payload()

	if _failures.is_empty():
		print("stage4_moon_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fragment_payload() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4001
	var fragment: Dictionary = Stage4MoonPayloadFactory.build_fragment(
		Vector2(784.0, 96.0),
		Vector2(360.0, 705.0),
		rng,
		123456,
		Stage4MoonEvent.FRAGMENT_ROTATION_SPEED_MIN,
		Stage4MoonEvent.FRAGMENT_ROTATION_SPEED_MAX,
		Stage4MoonEvent.FRAGMENT_IMAGE_SCALE_MIN,
		Stage4MoonEvent.FRAGMENT_IMAGE_SCALE_MAX,
		Stage4MoonEvent.FIELD_WIDTH + 30.0,
		Stage4MoonEvent.FRAGMENT_ATLAS_COLUMNS * Stage4MoonEvent.FRAGMENT_ATLAS_ROWS
	)
	_expect(int(fragment.get("fragment_id", 0)) >= 123456000, "fragment id should include caller timestamp")
	_expect(is_equal_approx(float(fragment.get("target_x", 0.0)), 360.0), "fragment should preserve target x")
	_expect(is_equal_approx(float(fragment.get("target_y", 0.0)), 705.0), "fragment should preserve target y")
	_expect(float(fragment.get("size", 0.0)) >= 8.0 and float(fragment.get("size", 0.0)) <= 15.0, "fragment size should stay in reference range")
	var rotation_speed: float = absf(float(fragment.get("rotation_speed", 0.0)))
	_expect(rotation_speed >= Stage4MoonEvent.FRAGMENT_ROTATION_SPEED_MIN, "rotation speed should respect min")
	_expect(rotation_speed <= Stage4MoonEvent.FRAGMENT_ROTATION_SPEED_MAX, "rotation speed should respect max")
	_expect(is_equal_approx(float(fragment.get("lifetime", 0.0)), 300.0), "fragment should preserve lifetime")
	_expect(_as_array(fragment.get("trail", [])).size() == 1, "fragment should start with origin trail point")
	_expect(not bool(fragment.get("impact", true)), "fragment should start non-impacting")
	_expect(not bool(fragment.get("deflected", true)), "fragment should start non-deflected")
	_expect(int(fragment.get("sprite_index", -1)) >= 0 and int(fragment.get("sprite_index", -1)) < 16, "fragment sprite index should stay inside atlas")
	_expect(float(fragment.get("visual_scale", 0.0)) >= Stage4MoonEvent.FRAGMENT_IMAGE_SCALE_MIN, "visual scale should respect min")
	_expect(float(fragment.get("visual_scale", 99.0)) <= Stage4MoonEvent.FRAGMENT_IMAGE_SCALE_MAX, "visual scale should respect max")
	_expect(bool(fragment.get("entered_field", false)), "origin inside entry margin should mark fragment as entered")


func _verify_zero_distance_target_fallback() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4002
	var fragment: Dictionary = Stage4MoonPayloadFactory.build_fragment(
		Vector2(100.0, 100.0),
		Vector2(100.0, 100.0),
		rng,
		1,
		0.15,
		2.4,
		2.8,
		5.5,
		90.0,
		16
	)
	_expect(absf(float(fragment.get("vx", 0.0))) > 0.0, "zero-distance target should fall back to a nonzero x velocity")
	_expect(absf(float(fragment.get("vy", 0.0))) > 0.0, "zero-distance target should fall back to a nonzero y velocity")
	_expect(not bool(fragment.get("entered_field", true)), "origin outside entry margin should start outside field")


func _verify_event_delegates_fragment_payload() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_moon_event.gd")
	_expect(source.find("Stage4MoonPayloadFactory.build_fragment") >= 0, "moon event should delegate fragment payload construction")
	_expect(source.find("func _get_random_fragment_rotation_speed") < 0, "moon event should not keep private fragment rotation helper")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("stage4_moon_payload_factory") >= 0, "module catalog should expose Stage 4 moon payload factory")


func _as_array(value: Variant) -> Array:
	return value if value is Array else []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
