extends SceneTree

const Stage4PonkSkillState := preload("res://scripts/stages/stage4/stage4_ponk_skill_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canvas := Node2D.new()
	get_root().add_child(canvas)

	var skill_state := Stage4PonkSkillState.new()
	_expect(skill_state.has_method("prewarm_assets_step"), "Stage 4 Ponk skill state should expose staged asset prewarm")
	var prewarm_calls := 0
	while not bool(skill_state.prewarm_assets_step()) and prewarm_calls < 80:
		prewarm_calls += 1
	_expect(prewarm_calls > 2, "Stage 4 Ponk skill prewarm should split FX assets across multiple chunks")

	skill_state.draw(canvas, _build_context(false, false), Vector2.ZERO)
	await process_frame

	var magnetic_host: Node = skill_state.get("magnetic_fx_host") as Node
	var meditation_host: Node = skill_state.get("meditation_fx_host") as Node
	var illusion_host: Node = skill_state.get("illusion_fx_host") as Node
	var aura_host: Node = skill_state.get("awaken_aura_fx_host") as Node
	_expect(not bool(skill_state.get("fx_hosts_prewarmed")), "Stage 4 inactive draw should not mark FX hosts as prewarmed")
	_expect(magnetic_host == null, "Stage 4 inactive draw should not create the magnetic FX host")
	_expect(meditation_host == null, "Stage 4 inactive draw should not create the meditation FX host")
	_expect(illusion_host == null, "Stage 4 inactive draw should not create the illusion ripple FX host")
	_expect(aura_host == null, "Stage 4 inactive draw should not create the awaken aura FX host")
	_expect(canvas.get_node_or_null("PonkMagneticFxHost") == null, "Stage 4 inactive draw should not attach a magnetic host")
	_expect(canvas.get_node_or_null("PonkMeditationFxHost") == null, "Stage 4 inactive draw should not attach a meditation host")
	_expect(canvas.get_node_or_null("PonkIllusionRippleFxHost") == null, "Stage 4 inactive draw should not attach an illusion ripple host")
	_expect(canvas.get_node_or_null("PonkAwakenAuraFxHost") == null, "Stage 4 inactive draw should not attach an awaken aura host")

	_expect(skill_state.has_method("prewarm_runtime_hosts_step"), "Stage 4 Ponk skill state should expose staged FX host runtime prewarm")
	_expect(not bool(skill_state.prewarm_runtime_hosts_step(canvas)), "Stage 4 runtime FX prewarm should stage the magnetic host first")
	await process_frame

	magnetic_host = skill_state.get("magnetic_fx_host") as Node
	meditation_host = skill_state.get("meditation_fx_host") as Node
	illusion_host = skill_state.get("illusion_fx_host") as Node
	aura_host = skill_state.get("awaken_aura_fx_host") as Node
	_expect(magnetic_host != null, "Stage 4 magnetic FX host should be created during runtime prewarm")
	_expect(meditation_host == null, "Stage 4 meditation FX host should wait for its own runtime prewarm step")
	_expect(illusion_host == null, "Stage 4 illusion ripple FX host should wait for its own runtime prewarm step")
	_expect(aura_host == null, "Stage 4 awaken aura FX host should wait for its own runtime prewarm step")
	_expect(canvas.get_node_or_null("PonkMagneticFxHost") == magnetic_host, "Stage 4 prewarmed magnetic FX host should attach before activation")
	if magnetic_host != null:
		_expect(magnetic_host.get_node_or_null("PonkMagneticLatticeBackplate") != null, "Stage 4 magnetic prewarm should build the lattice sprite")
		_expect(magnetic_host.get_node_or_null("PonkMagneticPrismShardParticles") != null, "Stage 4 magnetic prewarm should build prism particles")

	_expect(not bool(skill_state.prewarm_runtime_hosts_step(canvas)), "Stage 4 runtime FX prewarm should stage the meditation host before illusion")
	await process_frame

	meditation_host = skill_state.get("meditation_fx_host") as Node
	illusion_host = skill_state.get("illusion_fx_host") as Node
	aura_host = skill_state.get("awaken_aura_fx_host") as Node
	_expect(not bool(skill_state.get("fx_hosts_prewarmed")), "Stage 4 runtime FX prewarm should wait for illusion after meditation")
	_expect(meditation_host != null, "Stage 4 meditation FX host should be created during runtime prewarm")
	_expect(illusion_host == null, "Stage 4 illusion ripple FX host should not be created before its own step")
	_expect(aura_host == null, "Stage 4 awaken aura FX host should not be created before its own step")
	_expect(canvas.get_node_or_null("PonkMeditationFxHost") == meditation_host, "Stage 4 prewarmed meditation FX host should attach before activation")
	if meditation_host != null:
		_expect(meditation_host.get_node_or_null("PonkMeditationMandalaShader") != null, "Stage 4 meditation prewarm should build the mandala shader node")
		_expect(meditation_host.get_node_or_null("PonkMeditationReleaseBurst") != null, "Stage 4 meditation prewarm should build release burst sprite")

	_expect(not bool(skill_state.prewarm_runtime_hosts_step(canvas)), "Stage 4 runtime FX prewarm should stage the illusion ripple host before aura")
	await process_frame

	illusion_host = skill_state.get("illusion_fx_host") as Node
	aura_host = skill_state.get("awaken_aura_fx_host") as Node
	_expect(not bool(skill_state.get("fx_hosts_prewarmed")), "Stage 4 runtime FX prewarm should wait for the awaken aura after ripple")
	_expect(illusion_host != null, "Stage 4 illusion ripple FX host should be created during runtime prewarm")
	_expect(aura_host == null, "Stage 4 awaken aura FX host should wait until the fourth runtime prewarm step")
	_expect(canvas.get_node_or_null("PonkIllusionRippleFxHost") == illusion_host, "Stage 4 prewarmed illusion ripple FX host should attach before activation")
	if illusion_host != null:
		_expect(illusion_host.get_node_or_null("BackBufferCopy") != null, "Stage 4 illusion prewarm should build the BackBufferCopy")
		_expect(illusion_host.get_node_or_null("PonkIllusionRippleRect") != null, "Stage 4 illusion prewarm should build the fullscreen ripple rect")

	_expect(bool(skill_state.prewarm_runtime_hosts_step(canvas)), "Stage 4 runtime FX prewarm should finish with the awaken aura host")
	await process_frame

	aura_host = skill_state.get("awaken_aura_fx_host") as Node
	_expect(bool(skill_state.get("fx_hosts_prewarmed")), "Stage 4 runtime FX prewarm should mark host setup complete")
	_expect(aura_host != null, "Stage 4 awaken aura FX host should be created during runtime prewarm")
	_expect(canvas.get_node_or_null("PonkAwakenAuraFxHost") == aura_host, "Stage 4 prewarmed awaken aura FX host should attach before activation")
	if aura_host != null:
		_expect(aura_host.get_node_or_null("PonkAwakenAuraBackplate") != null, "Stage 4 awaken aura prewarm should build the backplate sprite")
		_expect(aura_host.get_node_or_null("PonkAwakenAuraArc1") != null, "Stage 4 awaken aura prewarm should build orbit arc sprites")
		_expect(aura_host.get_node_or_null("PonkAwakenAuraMoteParticles") != null, "Stage 4 awaken aura prewarm should build mote particles")
		var aura_status: Dictionary = aura_host.get_debug_status()
		_expect(bool(aura_status.get("backplate_blend_add", false)), "Stage 4 awaken aura backplate should use additive shader blending")
		_expect(bool(aura_status.get("arc_blend_add", false)), "Stage 4 awaken aura arcs should use additive shader blending")
		_expect(bool(aura_status.get("particles_blend_add", false)), "Stage 4 awaken aura particles should use additive material blending")
		_expect(not bool(aura_status.get("visible", true)), "Stage 4 prewarmed awaken aura host should stay hidden while inactive")

	var active_context := _build_context(true, false)
	var prewarmed_magnetic_host := magnetic_host
	skill_state.call("_sync_magnetic_fx_host", canvas, active_context, Vector2.ZERO, true)
	await process_frame

	magnetic_host = skill_state.get("magnetic_fx_host") as Node
	meditation_host = skill_state.get("meditation_fx_host") as Node
	_expect(magnetic_host == prewarmed_magnetic_host, "Stage 4 magnetic activation should reuse the prewarmed FX host")
	_expect(meditation_host != null, "Stage 4 magnetic activation should keep the prewarmed meditation FX host available")
	_expect(canvas.get_node_or_null("PonkMagneticFxHost") == magnetic_host, "Stage 4 magnetic FX host should attach on the activation frame")

	canvas.queue_free()

	if _failures.is_empty():
		print("stage4_ponk_fx_host_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _build_context(magnetic_active: bool, meditation_active: bool) -> Dictionary:
	return {
		"current_stage": 4,
		"width": 760.0,
		"game_size": Vector2(760.0, 750.0),
		"game_offset": Vector2.ZERO,
		"render_scale": 1.0,
		"boss_pos": Vector2(330.0, 54.0),
		"boss_paddle_size": Vector2(100.0, 18.0),
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 280.0),
		"stage4_magnetic_active": magnetic_active,
		"stage4_magnetic_projectile_active": false,
		"stage4_meditation_active": meditation_active,
		"stage4_meditation_release_fx_active": false,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
