extends RefCounted


func prewarm_current(
	profile: Object,
	companion_renderer: Object,
	runtime_state: String,
	companion_state: String,
	pet_id: String,
	click_reaction_visual_prewarm_state: Object
) -> void:
	if profile != null:
		profile.prewarm_visuals()
	if companion_renderer != null:
		companion_renderer.prewarm_assets()
	if runtime_state == companion_state and click_reaction_visual_prewarm_state != null:
		click_reaction_visual_prewarm_state.queue_if_companion(true, pet_id)
