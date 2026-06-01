extends SceneTree

const ScoreboardLedDigits := preload("res://scripts/hud/scoreboard_led_digits.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_number_width_cache()
	_verify_center_cache()
	_verify_matrix_center_cache()
	_verify_unlit_center_cache()

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


func _verify_matrix_center_cache() -> void:
	var digits: Object = ScoreboardLedDigits.new()
	var pattern: Array = digits.digit_patterns.get_pattern("0")
	var centers: Array[Vector2] = digits._get_matrix_centers(pattern, 9.0)
	var repeated_centers: Array[Vector2] = digits._get_matrix_centers(pattern, 9.0)
	_expect(centers.size() == 77, "matrix center cache should include every 7x11 LED socket")
	_expect(centers.size() == repeated_centers.size(), "repeated matrix center lookup should preserve socket count")
	_expect(digits.matrix_center_cache.size() == 1, "matrix center cache should reuse pattern dimensions and spacing")
	digits._get_matrix_centers(pattern, 10.0)
	_expect(digits.matrix_center_cache.size() == 2, "matrix center cache should split entries by spacing")


func _verify_unlit_center_cache() -> void:
	var digits: Object = ScoreboardLedDigits.new()
	var pattern: Array = digits.digit_patterns.get_pattern("8")
	var lit_centers: Array[Vector2] = digits._get_lit_centers("8", pattern, 9.0)
	var unlit_centers: Array[Vector2] = digits._get_unlit_centers("8", pattern, 9.0)
	var repeated_unlit_centers: Array[Vector2] = digits._get_unlit_centers("8", pattern, 9.0)
	_expect(lit_centers.size() + unlit_centers.size() == 77, "lit and unlit LED centers should cover the 7x11 matrix without overdraw")
	_expect(unlit_centers.size() == repeated_unlit_centers.size(), "repeated unlit center lookup should preserve socket count")
	_expect(digits.unlit_center_cache.size() == 1, "unlit center cache should reuse digit and spacing entry")
	digits._get_unlit_centers("8", pattern, 10.0)
	_expect(digits.unlit_center_cache.size() == 2, "unlit center cache should split entries by spacing")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
