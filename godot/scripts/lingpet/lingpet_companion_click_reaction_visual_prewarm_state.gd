extends RefCounted

var queued_pet_id := ""
var done_for_pet_id := ""


func reset() -> void:
	queued_pet_id = ""
	done_for_pet_id = ""


func queue_if_companion(is_companion: bool, pet_id: String) -> void:
	if not is_companion:
		return
	if done_for_pet_id == pet_id:
		return
	queued_pet_id = pet_id


func prewarm_step(
	is_companion: bool,
	pet_id: String,
	profile: Object,
	visual_keys: Array,
	max_msec: int,
	max_polls: int
) -> bool:
	if not is_companion:
		return true
	if done_for_pet_id == pet_id:
		return true
	if queued_pet_id != pet_id:
		queued_pet_id = pet_id
	if profile == null or not profile.has_method("prewarm_visual_key_threaded_step"):
		return false
	for visual_key in visual_keys:
		var done: bool = bool(profile.prewarm_visual_key_threaded_step(str(visual_key), max_msec, max_polls))
		if not done:
			return false
	done_for_pet_id = pet_id
	queued_pet_id = ""
	return true
