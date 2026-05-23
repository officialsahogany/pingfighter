extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageLandingIntro := preload("res://scripts/core/stage_landing_intro.gd")

const STAGE_BACKGROUNDS := {
	3: "res://assets/sprites/hud/stage3_landing_zoom_background_imagegen_v1.png",
	4: "res://assets/sprites/hud/stage4_landing_zoom_background_imagegen_v1.png",
}


class FakeOwner:
	extends RefCounted

	var current_stage := 1


class FakeRegistry:
	extends RefCounted

	var serve_flow_controller: Object = null

	func _init(next_serve_flow_controller: Object = null) -> void:
		serve_flow_controller = next_serve_flow_controller

	func get_instance(key: String) -> Object:
		if key == "serve_flow_controller":
			return serve_flow_controller
		return null


class FakeServeFlow:
	extends RefCounted

	var sync_calls := 0

	func sync_current_input_state() -> void:
		sync_calls += 1


var _failures: Array[String] = []


func _init() -> void:
	for stage in STAGE_BACKGROUNDS.keys():
		_verify_stage_background(int(stage), str(STAGE_BACKGROUNDS[stage]))
	_verify_gamepad_skip_finishes_intro()

	if _failures.is_empty():
		print("stage_landing_intro_background_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_stage_background(stage: int, path: String) -> void:
	var texture := ProjectResourceLoader.load_texture(path)
	_expect(texture != null, "landing background should load: %s" % path)
	if texture != null:
		_expect(texture.get_width() == 1254, "landing background should keep expected width: %s" % path)
		_expect(texture.get_height() == 1254, "landing background should keep expected height: %s" % path)

	var owner := FakeOwner.new()
	owner.current_stage = stage
	var intro := StageLandingIntro.new()
	_expect(intro.begin(owner, FakeRegistry.new()), "landing intro should begin for stage %d" % stage)
	_expect(intro.is_active(), "landing intro should become active for stage %d" % stage)
	var background: Variant = intro.get("background_texture")
	_expect(background is Texture2D, "landing intro should cache a Texture2D for stage %d" % stage)
	if background is Texture2D:
		_expect((background as Texture2D).get_width() == 1254, "cached background should keep expected width for stage %d" % stage)
		_expect((background as Texture2D).get_height() == 1254, "cached background should keep expected height for stage %d" % stage)


func _verify_gamepad_skip_finishes_intro() -> void:
	var owner := FakeOwner.new()
	owner.current_stage = 3
	var serve_flow := FakeServeFlow.new()
	var registry := FakeRegistry.new(serve_flow)
	var intro := StageLandingIntro.new()
	_expect(intro.begin(owner, registry), "landing intro should begin before gamepad skip")
	_expect(intro.is_active(), "landing intro should be active before gamepad skip")
	_expect(intro.handle_input(_joy_button(JOY_BUTTON_A), registry), "landing intro should consume gamepad confirm skip")
	_expect(not intro.is_active(), "landing intro should finish on gamepad confirm skip")
	_expect(serve_flow.sync_calls == 2, "landing intro should sync serve input on begin and gamepad finish")


func _joy_button(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index as JoyButton
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
