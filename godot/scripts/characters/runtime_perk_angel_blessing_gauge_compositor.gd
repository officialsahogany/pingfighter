extends RefCounted


static func resolve_owner_values(
	previous_unblessed_max: float,
	next_unblessed_max: float,
	previous_angel_multiplier: float,
	next_angel_multiplier: float,
	current_gauge: float
) -> Dictionary:
	var previous_base: float = maxf(1.0, previous_unblessed_max)
	var next_base: float = maxf(1.0, next_unblessed_max)
	var previous_angel: float = maxf(0.0, previous_angel_multiplier)
	var next_angel: float = maxf(0.0, next_angel_multiplier)
	var source_changed: bool = not is_equal_approx(previous_base, next_base)
	var angel_changed: bool = not is_equal_approx(previous_angel, next_angel)

	var next_gauge: float = maxf(0.0, current_gauge)
	if source_changed:
		next_gauge = round(next_gauge * next_base / previous_base)
	var next_max: float = maxf(1.0, next_base * next_angel)
	next_gauge = clampf(next_gauge, 0.0, next_max)

	var preserve_mode := "clamp"
	if source_changed and angel_changed:
		preserve_mode = "source_ratio_then_angel_absolute"
	elif source_changed:
		preserve_mode = "source_ratio"
	elif angel_changed:
		preserve_mode = "angel_absolute"

	return {
		"previous_unblessed_max": previous_base,
		"next_unblessed_max": next_base,
		"previous_angel_multiplier": previous_angel,
		"next_angel_multiplier": next_angel,
		"next_max": next_max,
		"next_gauge": next_gauge,
		"source_changed": source_changed,
		"angel_changed": angel_changed,
		"preserve_mode": preserve_mode,
	}
