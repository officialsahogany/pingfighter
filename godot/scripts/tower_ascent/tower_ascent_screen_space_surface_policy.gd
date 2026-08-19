extends RefCounted

const FLOW_PHASES := ["MAP_OVERLAY", "MAP_TRANSITION", "NODE_MODAL"]


static func uses_screen_space_flow_phase(
	phase_name: String,
	transition_visual_model: Dictionary = {}
) -> bool:
	if phase_name != "MAP_TRANSITION":
		return phase_name in FLOW_PHASES
	# MAP_TRANSITION owns the screen pass for all five beats. During the first
	# beat the map itself stays hidden, but this pass still draws the blackout
	# over the live battle scene.
	return (
		transition_visual_model.is_empty()
		or str(transition_visual_model.get("segment", "")) in [
			"battle_fade_out",
			"map_fade_in",
			"travel",
			"arrive_vanish",
			"map_fade_out",
		]
	)


static func uses_playfield_flow_phase(
	phase_name: String,
	transition_visual_model: Dictionary = {}
) -> bool:
	return not uses_screen_space_flow_phase(phase_name, transition_visual_model)


static func transition_keeps_battle_visible(
	phase_name: String,
	transition_visual_model: Dictionary = {}
) -> bool:
	return (
		phase_name == "MAP_TRANSITION"
		and str(transition_visual_model.get("segment", "")) == "battle_fade_out"
	)
