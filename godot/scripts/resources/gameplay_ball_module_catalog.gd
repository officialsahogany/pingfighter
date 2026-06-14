extends RefCounted

const MODULES := {
	"ball_renderer": {
		"path": "res://scripts/ball/ball_renderer.gd",
		"label": "ball renderer",
	},
	"ball_context_reader": {
		"path": "res://scripts/ball/ball_context_reader.gd",
		"label": "ball context reader",
	},
	"ball_effects_renderer": {
		"path": "res://scripts/ball/ball_effects_renderer.gd",
		"label": "ball effects renderer",
	},
	"ball_motion_stepper": {
		"path": "res://scripts/ball/ball_motion_stepper.gd",
		"label": "ball motion stepper",
	},
	"ball_physics": {
		"path": "res://scripts/ball/ball_physics.gd",
		"label": "ball physics",
	},
	"ball_intensity": {
		"path": "res://scripts/ball/ball_intensity.gd",
		"label": "ball intensity",
	},
	"ball_effects": {
		"path": "res://scripts/ball/ball_effects.gd",
		"label": "ball effects state",
	},
	"ball_effect_payload_factory": {
		"path": "res://scripts/ball/ball_effect_payload_factory.gd",
		"label": "ball effect payload factory",
	},
	"ball_round_state": {
		"path": "res://scripts/ball/ball_round_state.gd",
		"label": "ball round state",
	},
	"ball_round_controller": {
		"path": "res://scripts/ball/ball_round_controller.gd",
		"label": "ball round controller",
	},
	"ball_update_controller": {
		"path": "res://scripts/ball/ball_update_controller.gd",
		"label": "ball update controller",
	},
	"ball_update_context": {
		"path": "res://scripts/ball/ball_update_context.gd",
		"label": "ball update context",
	},
	"ball_scene_bridge": {
		"path": "res://scripts/ball/ball_scene_bridge.gd",
		"label": "ball scene bridge",
	},
	"ball_spin_state": {
		"path": "res://scripts/ball/ball_spin_state.gd",
		"label": "ball spin state",
	},
	"wall_bounce_state": {
		"path": "res://scripts/ball/wall_bounce_state.gd",
		"label": "wall bounce state",
	},
	"wall_bounce_controller": {
		"path": "res://scripts/ball/wall_bounce_controller.gd",
		"label": "wall bounce controller",
	},
	"paddle_bounce_state": {
		"path": "res://scripts/ball/paddle_bounce_state.gd",
		"label": "paddle bounce state",
	},
	"paddle_bounce_controller": {
		"path": "res://scripts/ball/paddle_bounce_controller.gd",
		"label": "paddle bounce controller",
	},
}


func get_spec(key: String) -> Dictionary:
	if MODULES.has(key):
		return MODULES[key]
	return {}
