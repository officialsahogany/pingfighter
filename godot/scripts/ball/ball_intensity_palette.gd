extends RefCounted


func get_palette(level: int) -> Array[Color]:
	match clampi(level, 0, 5):
		1:
			return [
				Color(180.0 / 255.0, 220.0 / 255.0, 100.0 / 255.0),
				Color(160.0 / 255.0, 200.0 / 255.0, 80.0 / 255.0),
				Color(140.0 / 255.0, 180.0 / 255.0, 60.0 / 255.0),
			]
		2:
			return [
				Color(1.0, 220.0 / 255.0, 100.0 / 255.0),
				Color(1.0, 200.0 / 255.0, 80.0 / 255.0),
				Color(1.0, 180.0 / 255.0, 60.0 / 255.0),
			]
		3:
			return [
				Color(1.0, 160.0 / 255.0, 80.0 / 255.0),
				Color(1.0, 140.0 / 255.0, 60.0 / 255.0),
				Color(1.0, 120.0 / 255.0, 40.0 / 255.0),
			]
		4:
			return [
				Color(1.0, 100.0 / 255.0, 80.0 / 255.0),
				Color(1.0, 80.0 / 255.0, 60.0 / 255.0),
				Color(1.0, 60.0 / 255.0, 40.0 / 255.0),
			]
		5:
			return [
				Color(1.0, 80.0 / 255.0, 150.0 / 255.0),
				Color(1.0, 60.0 / 255.0, 130.0 / 255.0),
				Color(1.0, 40.0 / 255.0, 110.0 / 255.0),
			]
		_:
			return [
				Color(100.0 / 255.0, 180.0 / 255.0, 1.0),
				Color(80.0 / 255.0, 160.0 / 255.0, 1.0),
				Color(60.0 / 255.0, 140.0 / 255.0, 1.0),
			]


func get_glow_color(level: int) -> Color:
	match clampi(level, 0, 5):
		1:
			return Color(100.0 / 255.0, 150.0 / 255.0, 50.0 / 255.0, 40.0 / 255.0)
		2:
			return Color(180.0 / 255.0, 150.0 / 255.0, 30.0 / 255.0, 50.0 / 255.0)
		3:
			return Color(200.0 / 255.0, 100.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0)
		4:
			return Color(200.0 / 255.0, 50.0 / 255.0, 30.0 / 255.0, 70.0 / 255.0)
		5:
			return Color(200.0 / 255.0, 40.0 / 255.0, 100.0 / 255.0, 80.0 / 255.0)
		_:
			return Color(60.0 / 255.0, 100.0 / 255.0, 180.0 / 255.0, 30.0 / 255.0)


func blend_palette(current_level: int, next_level: int, blend_factor: float) -> Array[Color]:
	var current_colors: Array[Color] = get_palette(current_level)
	var next_colors: Array[Color] = get_palette(next_level)
	return [
		current_colors[0].lerp(next_colors[0], blend_factor),
		current_colors[1].lerp(next_colors[1], blend_factor),
		current_colors[2].lerp(next_colors[2], blend_factor),
	]


func blend_glow_color(current_level: int, next_level: int, blend_factor: float) -> Color:
	return get_glow_color(current_level).lerp(get_glow_color(next_level), blend_factor)
