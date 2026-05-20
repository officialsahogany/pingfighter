extends SceneTree

const ScoreboardLedDigits := preload("res://scripts/hud/scoreboard_led_digits.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_number_width_cache()
	_verify_center_cache()

	if _failures.is_empty():
		print("scoreboard_led_digits_cache_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_number_width_cache() -> void:
	var digits: Object = ScoreboardLedDigits.new()
	var first_width: float = digits.get_number_width(12, 100.0)
	var second_width: float = digits.get_number_width(99, 100.0)
	_expect(is_equal_approx(first_width, second_width), "same digit count and size should reuse width math")
	_expect(digits.number_width_cache.size() == 1, "number width cache should keep one entry for matching digit count and spacing")
	digits.get_number_width(100, 100.0)
	_expect(digits.number_width_cache.size() == 2, "number width cache should split entries by digit count")


func _verify_center_cache() -> void:
	var digits: Object = ScoreboardLedDigits.new()
	var pattern: Array = digits.digit_patterns.get_pattern("8")
	var centers: Array[Vector2] = digits._get_lit_centers("8", pattern, 9.0)
	var repeated_centers: Array[Vector2] = digits._get_lit_centers("8", pattern, 9.0)
	_expect(not centers.is_empty(), "lit center cache should produce visible centers")
	_expect(centers.size() == repeated_centers.size(), "repeated lit center lookup should preserve point count")
	_expect(digits.lit_center_cache.size() == 1, "lit center cache should reuse digit and spacing entry")
	digits._get_lit_centers("8", pattern, 10.0)
	_expect(digits.lit_center_cache.size() == 2, "lit center cache should split entries by spacing")
	_expect(digits.lit_point_cache.has("8"), "lit point cache should keep digit topology")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
