extends RefCounted

const ROCK_GOLDEN_STYLE := "golden_rock"
const ROCK_STYLE_NAMES := [
	"dark_granite",
	"light_granite",
	"reddish_stone",
	"yellowish_stone",
	"gray_stone",
	"mixed_stone",
]
const ROCK_STYLE_COLOR_DATA := {
	"dark_granite": [[35, 35, 40], [55, 55, 60], [75, 75, 80]],
	"light_granite": [[120, 115, 110], [140, 135, 130], [160, 155, 150]],
	"reddish_stone": [[85, 65, 55], [105, 85, 75], [125, 105, 95]],
	"yellowish_stone": [[140, 120, 85], [160, 140, 105], [180, 160, 125]],
	"gray_stone": [[70, 70, 75], [90, 90, 95], [110, 110, 115]],
	"mixed_stone": [[95, 85, 80], [115, 105, 100], [135, 125, 120]],
	"golden_rock": [[255, 215, 0], [255, 223, 100], [255, 230, 150]],
}


func build_visual_data(size: float, is_golden: bool, seed_value: int, rng: RandomNumberGenerator) -> Dictionary:
	var style_type := ROCK_GOLDEN_STYLE
	if not is_golden:
		style_type = _select_style(seed_value, rng)
	return {
		"style_type": style_type,
		"style_colors": get_style_colors(style_type),
		"fixed_points": generate_fixed_points(seed_value),
		"rock_seed": seed_value,
		"visual_radius": size,
		"rotation": _select_rotation(seed_value, rng),
	}


func get_style_colors(style_type: String) -> Array:
	var color_data: Array = ROCK_STYLE_COLOR_DATA.get(style_type, ROCK_STYLE_COLOR_DATA["gray_stone"])
	var colors: Array = []
	for rgb in color_data:
		var values: Array = rgb
		colors.append(Color(
			float(values[0]) / 255.0,
			float(values[1]) / 255.0,
			float(values[2]) / 255.0,
			1.0
		))
	return colors


func generate_fixed_points(seed_value: int) -> Array:
	var count: int = 12 + int(floor(_seeded_unit(float(seed_value) + 0.37) * 9.0))
	var points: Array = []
	for idx in range(count):
		var angle: float = TAU * float(idx) / float(count)
		var base_radius := 0.80
		var wave1: float = sin(angle * 2.3) * 0.15
		var wave2: float = sin(angle * 3.7) * 0.10
		var noise: float = _seeded_unit(float(seed_value) + float(idx) * 17.13) * 0.20 - 0.10
		var radius_ratio: float = clamp(base_radius + wave1 + wave2 + noise, 0.50, 1.0)
		points.append(Vector2(cos(angle) * radius_ratio, sin(angle) * radius_ratio))
	return points


func _select_style(seed_value: int, rng: RandomNumberGenerator) -> String:
	if ROCK_STYLE_NAMES.is_empty():
		return "gray_stone"
	if rng != null:
		return str(ROCK_STYLE_NAMES[rng.randi_range(0, ROCK_STYLE_NAMES.size() - 1)])
	return str(ROCK_STYLE_NAMES[abs(seed_value) % ROCK_STYLE_NAMES.size()])


func _select_rotation(seed_value: int, rng: RandomNumberGenerator) -> float:
	if rng != null:
		return rng.randf_range(-PI, PI)
	return -PI + TAU * _seeded_unit(float(seed_value) + 91.17)


func _seeded_unit(seed_value: float) -> float:
	return fposmod(sin(seed_value * 12.9898 + 78.233) * 43758.5453, 1.0)
