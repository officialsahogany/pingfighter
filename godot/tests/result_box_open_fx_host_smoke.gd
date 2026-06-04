extends SceneTree

const ResultBoxOpenFxHost := preload("res://scripts/effects/result_box_open_fx_host.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")


func _initialize() -> void:
	var status: Dictionary = ResultBoxOpenFxHost.build_pipeline_status()
	var source := FileAccess.get_file_as_string("res://scripts/effects/result_box_open_fx_host.gd")
	var ok: bool = true
	for key in [
		"result_box_open_fx_shader_pipeline",
		"result_box_open_fx_texture_pieces_ready",
		"result_box_open_fx_backplate_common_png_slot",
		"result_box_open_fx_backplate_mythic_png_slot",
		"result_box_open_fx_ribbon_trail_png_slot",
	]:
		if not bool(status.get(key, false)):
			push_error("result_box_open_fx pipeline check failed at key: %s (status=%s)" % [key, status])
			ok = false
	if not WritheEmber.has_preset("result_box_burst_common"):
		push_error("WritheEmber missing preset: result_box_burst_common")
		ok = false
	if not WritheEmber.has_preset("result_box_burst_mythic"):
		push_error("WritheEmber missing preset: result_box_burst_mythic")
		ok = false
	if source.find("func _process") >= 0:
		push_error("Result box open host should stay controller-driven without its own _process callback")
		ok = false
	if ResultBoxOpenFxHost.LIGHT_ENVELOPE_HOLD_DURATION + ResultBoxOpenFxHost.LIGHT_ENVELOPE_FADE_DURATION > 0.80:
		push_error("Result box open light envelope should clear quickly so rewards are readable")
		ok = false
	if ResultBoxOpenFxHost.EMERGE_GLOW_FADE_DURATION > ResultBoxOpenFxHost.LIGHT_ENVELOPE_FADE_DURATION:
		push_error("Result box emerge glow should not outlive the main light fade")
		ok = false
	var host: Node2D = ResultBoxOpenFxHost.new()
	host.name = "ResultBoxOpenFxHostSmoke"
	root.add_child(host)
	var state := {
		"position": Vector2(960.0, 540.0),
		"scale": 1.0,
		"phase": "opening",
		"open_progress": 0.30,
		"reward_emerge": 0.0,
		"alpha": 1.0,
		"is_mythic": false,
		"lid_open_id": -1,
	}
	host.sync_state(state, true)
	if host.is_processing():
		push_error("Result box open host should not enable process during sync_state")
		ok = false
	state["open_progress"] = 0.70
	state["lid_open_id"] = 1
	host.sync_state(state, true)
	state["phase"] = "opened"
	state["open_progress"] = 1.0
	state["reward_emerge"] = 0.6
	state["is_mythic"] = true
	host.sync_state(state, true)
	var backplate: Sprite2D = host.get_node_or_null("ResultBoxOpenBackplate")
	var ribbon: Sprite2D = host.get_node_or_null("ResultBoxOpenRibbonTrail")
	var inner_glow: Sprite2D = host.get_node_or_null("ResultBoxOpenInnerGlow")
	var spark_particles: GPUParticles2D = host.get_node_or_null("ResultBoxOpenSparkParticles")
	if not host.z_as_relative or host.z_index != 0:
		push_error("Result box open host must inherit the result scene Control z-index")
		ok = false
	if backplate == null or not backplate.visible or backplate.modulate.a < 0.45:
		push_error("Result box open backplate should be visibly active")
		ok = false
	elif backplate.z_index != 1:
		push_error("Result box open backplate should render above the result scene draw pass")
		ok = false
	if ribbon == null or not ribbon.visible or ribbon.modulate.a < 0.35:
		push_error("Result box open ribbon trail should be visibly active")
		ok = false
	elif ribbon.z_index != 2:
		push_error("Result box open ribbon trail should render above the result scene draw pass")
		ok = false
	if inner_glow == null or not inner_glow.visible or inner_glow.modulate.a < 0.12:
		push_error("Result box open inner glow should persist after lid open")
		ok = false
	elif inner_glow.z_index != 2:
		push_error("Result box open inner glow should render above the result scene draw pass")
		ok = false
	if spark_particles == null or spark_particles.z_index != 3:
		push_error("Result box open spark particles should render on top of the result box burst")
		ok = false
	elif spark_particles.lifetime > 0.40:
		push_error("Result box open spark particles should clear before they hide the reward")
		ok = false
	host.tear_down(true)
	if ok:
		print("result_box_open_fx_host_smoke: ok")
		quit(0)
	else:
		quit(1)
