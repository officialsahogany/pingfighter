extends RefCounted

const FLOW_PHASES := ["MAP_OVERLAY", "MAP_TRANSITION", "NODE_MODAL"]


static func uses_screen_space_flow_phase(phase_name: String) -> bool:
	return phase_name in FLOW_PHASES


static func uses_playfield_flow_phase(phase_name: String) -> bool:
	return not uses_screen_space_flow_phase(phase_name)
