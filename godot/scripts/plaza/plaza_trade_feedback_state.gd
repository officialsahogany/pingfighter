extends RefCounted

const DEFAULT_DURATION := 0.92
const MAX_FEEDBACKS := 4

var feedbacks: Array[Dictionary] = []
var last_signature := ""


func record(summary_value: Variant) -> bool:
	if not summary_value is Dictionary:
		return false
	var summary: Dictionary = summary_value
	if not bool(summary.get("changed", false)):
		return false
	var action := str(summary.get("action", ""))
	if not ["purchase", "sale"].has(action):
		return false
	var signature := "%s|%s|%s|%s|%s" % [
		action,
		str(summary.get("item_name", "")),
		str(summary.get("display_name", "")),
		str(summary.get("delta_gold", 0)),
		str(summary.get("plaza_gold", "")),
	]
	if signature == last_signature:
		return false
	last_signature = signature
	var delta_gold := int(summary.get("delta_gold", 0))
	var gold_text := "+%dG" % delta_gold if delta_gold >= 0 else "-%dG" % abs(delta_gold)
	var display_name := str(summary.get("display_name", ""))
	var feedback_text := gold_text if display_name == "" else "%s  %s" % [gold_text, display_name]
	feedbacks.append({
		"action": action,
		"text": feedback_text,
		"age": 0.0,
		"duration": DEFAULT_DURATION,
	})
	while feedbacks.size() > MAX_FEEDBACKS:
		feedbacks.pop_front()
	return true


func advance(delta: float) -> bool:
	if feedbacks.is_empty():
		return false
	for index in range(feedbacks.size() - 1, -1, -1):
		var feedback: Dictionary = feedbacks[index]
		var next_age := float(feedback.get("age", 0.0)) + delta
		if next_age >= float(feedback.get("duration", DEFAULT_DURATION)):
			feedbacks.remove_at(index)
		else:
			feedback["age"] = next_age
			feedbacks[index] = feedback
	return true


func reset() -> void:
	feedbacks.clear()
	last_signature = ""
