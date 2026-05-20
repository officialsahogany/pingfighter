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
	_expect(not bool(skill_state.get("fx_hosts_prewarmed")), "Stage 4 inactive draw should not mark FX hosts as prewarmed")
	_expect(magnetic_host == null, "Stage 4 inactive draw should not create the magnetic FX host")
	_expect(meditation_host == null, "Stage 4 inactive draw should not create the meditation FX host")
	_expect(canvas.get_node_or_null("PonkMagneticFxHost") == null, "Stage 4 inactive draw should not attach a magnetic host")
	_expect(canvas.get_node_or_null("PonkMeditationFxHost") == null, "Stage 4 inactive draw should not attach a meditation host")

	var active_context := _build_context(true, false)
	skill_state.call("_sync_magnetic_fx_host", canvas, active_context, Vector2.ZERO, true)
	await process_frame

	magnetic_host = skill_state.get("magnetic_fx_host") as Node
	meditation_host = skill_state.get("meditation_fx_host") as Node
	_expect(magnetic_host != null, "Stage 4 magnetic FX host should be created on first magnetic activation")
	_expect(meditation_host == null, "Stage 4 magnetic activation should not create the meditation FX host")
	_expect(canvas.get_node_or_null("PonkMagneticFxHost") == magnetic_host, "Stage 4 magnetic FX host should attach on the activation frame")

	if magnetic_host != null:
		_expect(magnetic_host.get_node_or_null("PonkMagneticLatticeBackplate") != null, "Stage 4 magnetic prewarm should build the lattice sprite")
		_expect(magnetic_host.get_node_or_null("PonkMagneticPrismShardParticles") != null, "Stage 4 magnetic prewarm should build prism particles")

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
