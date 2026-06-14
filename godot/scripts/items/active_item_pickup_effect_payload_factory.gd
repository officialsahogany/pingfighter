extends RefCounted


static func build_pickup_effect(
	item_data: Dictionary,
	display_name: String,
	start_pos: Vector2,
	duration: float,
	initial_alpha: float,
	use_hint_text: String = ""
) -> Dictionary:
	var pickup_effect := {
		"item_data": item_data.duplicate(true),
		"display_name": display_name,
		"timer": duration,
		"alpha": initial_alpha,
		"position": start_pos,
		"start_position": start_pos,
	}
	if use_hint_text != "":
		pickup_effect["use_hint_text"] = use_hint_text
	return pickup_effect


static func build_balloon_pop_particle(center: Vector2, item_color: Color) -> Dictionary:
	var angle: float = randf_range(0.0, TAU)
	var speed: float = randf_range(90.0, 250.0)
	var color := item_color.lerp(Color.WHITE, randf_range(0.15, 0.55))
	return {
		"position": center,
		"velocity": Vector2(cos(angle), sin(angle)) * speed,
		"radius": randf_range(2.0, 4.5),
		"age": 0.0,
		"lifetime": randf_range(0.28, 0.62),
		"color": color,
	}
