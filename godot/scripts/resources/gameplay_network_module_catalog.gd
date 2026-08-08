extends RefCounted

const MODULES := {
	"online_enet_transport": {
		"path": "res://scripts/network/online_enet_transport.gd",
		"label": "online ENet transport adapter",
	},
	"online_match_protocol": {
		"path": "res://scripts/network/online_match_protocol.gd",
		"label": "online match packet protocol",
	},
	"online_paddle_state": {
		"path": "res://scripts/network/online_paddle_state.gd",
		"label": "role-neutral online paddle state",
	},
	"online_match_simulation": {
		"path": "res://scripts/network/online_match_simulation.gd",
		"label": "host-authoritative online match simulation",
	},
	"online_match_session": {
		"path": "res://scripts/network/online_match_session.gd",
		"label": "online match session owner",
	},
	"online_match_input_collector": {
		"path": "res://scripts/network/online_match_input_collector.gd",
		"label": "online match input-frame collector",
	},
	"online_match_renderer": {
		"path": "res://scripts/network/online_match_renderer.gd",
		"label": "online match renderer",
	},
	"online_match_runtime": {
		"path": "res://scripts/network/online_match_runtime.gd",
		"label": "online match battle runtime bridge",
	},
}


func get_spec(key: String) -> Dictionary:
	return MODULES.get(key, {})
