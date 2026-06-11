extends RefCounted

const LEVEL_UP_FLASH_SECONDS := 0.78

var level_up_timer := 0.0
var trigger_count := 0
var label := ""
var title_label := ""
var heart_tint_unlocked := false


func advance(delta: float) -> void:
	level_up_timer = maxf(0.0, level_up_timer - maxf(0.0, delta))


func reset_all() -> void:
	reset_transients()
	heart_tint_unlocked = false


func reset_transients() -> void:
	level_up_timer = 0.0
	label = ""
	title_label = ""


func sync_for_level(level: int, max_level: int) -> void:
	heart_tint_unlocked = level >= max_level


func trigger_level_up(level: int, max_level: int, max_title: String = "") -> void:
	var safe_level: int = maxi(0, level)
	level_up_timer = LEVEL_UP_FLASH_SECONDS
	trigger_count += 1
	label = "교감 Lv.%d!" % safe_level
	title_label = max_title.strip_edges() if safe_level >= max_level else ""
	if safe_level >= max_level:
		heart_tint_unlocked = true


func get_flash_ratio(companion_active: bool = true) -> float:
	if not companion_active:
		return 0.0
	return clampf(level_up_timer / LEVEL_UP_FLASH_SECONDS, 0.0, 1.0)


func has_visible_effects(companion_active: bool = true) -> bool:
	return get_flash_ratio(companion_active) > 0.0


func get_snapshot(companion_active: bool = true) -> Dictionary:
	var flash_ratio := get_flash_ratio(companion_active)
	return {
		"affinity_feedback_flash_ratio": flash_ratio,
		"affinity_feedback_label": label if flash_ratio > 0.0 else "",
		"affinity_feedback_title": title_label,
		"affinity_feedback_heart_tint": heart_tint_unlocked,
		"affinity_feedback_trigger_count": trigger_count,
	}
