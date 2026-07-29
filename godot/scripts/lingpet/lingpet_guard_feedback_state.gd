extends RefCounted

# The former affinity flash, level-up label, and point-popup channels are
# retired; this focused owner keeps only the cosmetic guard contact label.
const GUARD_LABEL_SECONDS := 0.8
const GUARD_LABEL_TEXT := "방어"

var guard_label_timer := 0.0
var guard_label_pos := Vector2.ZERO


func advance(delta: float) -> void:
	guard_label_timer = maxf(0.0, guard_label_timer - maxf(0.0, delta))


func reset_all() -> void:
	reset_round_transients()


func reset_transients() -> void:
	reset_round_transients()


func reset_round_transients() -> void:
	guard_label_timer = 0.0
	guard_label_pos = Vector2.ZERO


func trigger_guard_label(contact_pos: Vector2) -> void:
	guard_label_pos = contact_pos
	guard_label_timer = GUARD_LABEL_SECONDS


func get_guard_label(companion_active: bool = true) -> Dictionary:
	if not companion_active or guard_label_timer <= 0.0:
		return {}
	return {
		"text": GUARD_LABEL_TEXT,
		"position": guard_label_pos,
		"ratio": clampf(1.0 - guard_label_timer / GUARD_LABEL_SECONDS, 0.0, 1.0),
	}


func has_visible_effects(companion_active: bool = true) -> bool:
	return companion_active and guard_label_timer > 0.0


func get_snapshot(companion_active: bool = true) -> Dictionary:
	return {"guardian_guard_label": get_guard_label(companion_active)}
