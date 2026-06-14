extends RefCounted

const LingpetAffinityFeedbackPayloadFactory := preload("res://scripts/lingpet/lingpet_affinity_feedback_payload_factory.gd")

const LEVEL_UP_FLASH_SECONDS := 0.78
# Rising "+N" point popups above the companion. Rapid gains inside the
# coalesce window merge into one popup instead of stacking spam.
const POINT_POPUP_SECONDS := 0.9
const POINT_POPUP_COALESCE_SECONDS := 0.25
const MAX_POINT_POPUPS := 3
const GUARD_LABEL_SECONDS := 0.8
const GUARD_LABEL_TEXT := "방어"

var level_up_timer := 0.0
var trigger_count := 0
var label := ""
var title_label := ""
var heart_tint_unlocked := false
var point_popups: Array[Dictionary] = []
var guard_label_timer := 0.0
var guard_label_pos := Vector2.ZERO


func advance(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	level_up_timer = maxf(0.0, level_up_timer - safe_delta)
	guard_label_timer = maxf(0.0, guard_label_timer - safe_delta)
	for i in range(point_popups.size() - 1, -1, -1):
		var age := float(point_popups[i].get("age", 0.0)) + safe_delta
		if age >= POINT_POPUP_SECONDS:
			point_popups.remove_at(i)
		else:
			point_popups[i]["age"] = age


func reset_all() -> void:
	reset_transients()
	heart_tint_unlocked = false


func reset_transients() -> void:
	level_up_timer = 0.0
	label = ""
	title_label = ""
	point_popups.clear()
	reset_round_transients()


func reset_round_transients() -> void:
	guard_label_timer = 0.0
	guard_label_pos = Vector2.ZERO


func trigger_point_gain(amount: float) -> void:
	var safe_amount := maxf(0.0, amount)
	if safe_amount <= 0.0:
		return
	if not point_popups.is_empty():
		var newest: Dictionary = point_popups[point_popups.size() - 1]
		if float(newest.get("age", 0.0)) <= POINT_POPUP_COALESCE_SECONDS:
			newest["amount"] = float(newest.get("amount", 0.0)) + safe_amount
			newest["age"] = 0.0
			return
	point_popups.append(LingpetAffinityFeedbackPayloadFactory.build_point_popup(safe_amount))
	while point_popups.size() > MAX_POINT_POPUPS:
		point_popups.remove_at(0)


func trigger_guard_label(contact_pos: Vector2) -> void:
	guard_label_pos = contact_pos
	guard_label_timer = GUARD_LABEL_SECONDS


func get_point_popups(companion_active: bool = true) -> Array[Dictionary]:
	var popups: Array[Dictionary] = []
	if not companion_active:
		return popups
	for popup in point_popups:
		popups.append(LingpetAffinityFeedbackPayloadFactory.build_draw_popup(popup, POINT_POPUP_SECONDS))
	return popups


func get_guard_label(companion_active: bool = true) -> Dictionary:
	if not companion_active or guard_label_timer <= 0.0:
		return {}
	return {
		"text": GUARD_LABEL_TEXT,
		"position": guard_label_pos,
		"ratio": clampf(1.0 - guard_label_timer / GUARD_LABEL_SECONDS, 0.0, 1.0),
	}


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
	if get_flash_ratio(companion_active) > 0.0:
		return true
	return companion_active and (not point_popups.is_empty() or guard_label_timer > 0.0)


func get_snapshot(companion_active: bool = true) -> Dictionary:
	var flash_ratio := get_flash_ratio(companion_active)
	return {
		"affinity_feedback_flash_ratio": flash_ratio,
		"affinity_feedback_label": label if flash_ratio > 0.0 else "",
		"affinity_feedback_title": title_label,
		"affinity_feedback_heart_tint": heart_tint_unlocked,
		"affinity_feedback_trigger_count": trigger_count,
		"affinity_point_popups": get_point_popups(companion_active),
		"affinity_guard_label": get_guard_label(companion_active),
	}
