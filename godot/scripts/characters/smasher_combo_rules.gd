extends RefCounted

const SMASHER_COMBO_MAX_GAUGE_BONUS_PCT := 100.0


func get_gauge_bonus_pct(combo_count: int, min_skill_count: int) -> float:
	if combo_count < min_skill_count:
		return 0.0
	return min(SMASHER_COMBO_MAX_GAUGE_BONUS_PCT, float(combo_count - 1) * 20.0)


func get_gauge_gain(base_gain: float, combo_count: int, min_skill_count: int) -> float:
	if combo_count < min_skill_count:
		return base_gain
	var bonus_pct: float = get_gauge_bonus_pct(combo_count, min_skill_count)
	return base_gain * (1.0 + bonus_pct / 100.0)


func get_combo_color(combo_count: int) -> Color:
	if combo_count <= 2:
		return Color(1.0, 1.0, 100.0 / 255.0)
	if combo_count == 3:
		return Color(1.0, 180.0 / 255.0, 50.0 / 255.0)
	if combo_count == 4:
		return Color(1.0, 100.0 / 255.0, 100.0 / 255.0)
	if combo_count == 5:
		return Color(1.0, 50.0 / 255.0, 150.0 / 255.0)
	var t: float = float(Time.get_ticks_msec()) * 0.006 + float(combo_count) * 0.35
	return Color(
		0.82 + 0.18 * sin(t),
		0.65 + 0.35 * sin(t + 2.1),
		0.82 + 0.18 * sin(t + 4.2)
	)


func get_combo_glow_color(combo_count: int) -> Color:
	if combo_count >= 8:
		return Color(1.0, 130.0 / 255.0, 90.0 / 255.0)
	if combo_count >= 5:
		return Color(1.0, 200.0 / 255.0, 100.0 / 255.0)
	if combo_count >= 3:
		return Color(1.0, 245.0 / 255.0, 170.0 / 255.0)
	return Color.WHITE
