extends RefCounted


static func build_heart(center: Vector2, life_seconds: float) -> Dictionary:
	return {
		"pos": center + Vector2(randf_range(-22.0, 22.0), randf_range(-6.0, 14.0)),
		"drift": randf_range(-18.0, 18.0),
		"life": life_seconds,
		"size": randf_range(5.0, 9.0),
	}


static func build_sparkle(center: Vector2, life_seconds: float) -> Dictionary:
	return {
		"pos": center + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0)),
		"life": life_seconds,
		"size": randf_range(2.0, 5.0),
	}


const CUT_FIBERS_PER_END := 5
# Of the fibers above, the last few are LONG streamers: instead of a short
# broom stub they trail out far, drape downward under gravity, and flutter
# slowly — the loose threads that flow and sag after a real cord lets go. The
# rest stay short fast-twanging stubs at the torn cross-section.
const CUT_LONG_FIBERS := 2


# Builds one frayed-thread bundle for a single snapped rope end. Short stubs fan
# out across a wide angle (the torn cross-section reads as several distinct
# strands, not a clean knife cut); a couple of LONG streamers trail out, drape
# down, and flutter so a few threads visibly stretch and flow. Each fiber
# carries its own curl + droop + lash so the bundle whips independently during
# the elastic snap-back. Seeded RNG keeps a given cut's fray geometry stable
# frame-to-frame (the lash animates separately from `_anim_time`); only the
# cross-frame wobble moves, never the strand identity.
static func build_cut_fray_bundle(rng: RandomNumberGenerator) -> Array:
	var fibers: Array = []
	var short_count: int = maxi(1, CUT_FIBERS_PER_END - CUT_LONG_FIBERS)
	for f in range(CUT_FIBERS_PER_END):
		var is_long: bool = f >= short_count
		var spread: float
		if is_long:
			# Narrow fan so the long streamer trails roughly along the rope then
			# drapes, rather than shooting straight out sideways.
			var li: float = float(f - short_count)
			spread = -0.32 + (li + 0.5) / float(CUT_LONG_FIBERS) * 0.64
			spread += rng.randf_range(-0.10, 0.10)
		else:
			# Wide fan for the broken-end stubs (multiple directions).
			spread = -0.95 + (float(f) + 0.5) / float(short_count) * 1.9
			spread += rng.randf_range(-0.12, 0.12)
		fibers.append({
			"long": is_long,
			"splay": spread,                          # radians off the rope's outward tangent
			"len": rng.randf_range(54.0, 104.0) if is_long else rng.randf_range(9.0, 22.0),
			"curl": rng.randf_range(-0.5, 0.5) if is_long else rng.randf_range(-1.25, 1.25),
			"droop": rng.randf_range(0.62, 1.18) if is_long else rng.randf_range(0.0, 0.16),
			"wob_phase": rng.randf_range(0.0, TAU),
			"wob_freq": rng.randf_range(9.0, 16.0) if is_long else rng.randf_range(26.0, 42.0),
			"wob_amp": rng.randf_range(7.0, 14.0) if is_long else rng.randf_range(2.2, 5.5),
			"thick": rng.randf_range(1.1, 1.7) if is_long else rng.randf_range(1.0, 1.8),
		})
	return fibers
