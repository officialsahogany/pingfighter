extends SceneTree

const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")
const BattleBootResourcePrewarmController := preload("res://scripts/core/battle_boot_resource_prewarm_controller.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node

	var current_stage: int = 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_prewarmer_lifecycle()
	_verify_prewarmer_offscreen_position()
	_verify_second_pass_warmup_scope()
	_verify_prewarmer_uses_imported_texture_resources()
	_verify_attach_helper_idempotence()
	await _verify_stage_step_waits_for_draw_warmup()
	await _verify_prewarmer_self_destructs()

	if _failures.is_empty():
		print("battle_pso_prewarmer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_prewarmer_lifecycle() -> void:
	var prewarmer := BattlePsoPrewarmer.new()
	_expect(prewarmer is Node2D, "BattlePsoPrewarmer should extend Node2D so it can issue canvas draw calls")
	_expect(prewarmer._frames_remaining == BattlePsoPrewarmer.LIFETIME_FRAMES, "BattlePsoPrewarmer should arm a finite lifetime so it does not stay alive forever")
	_expect(prewarmer._warmup_step_index == 0, "BattlePsoPrewarmer should begin at the first staged draw warmup step")
	_expect(
		BattlePsoPrewarmer.LIFETIME_FRAMES >= BattlePsoPrewarmer.WARMUP_DRAW_STEPS + BattlePsoPrewarmer.POST_WARMUP_FLUSH_FRAMES,
		"BattlePsoPrewarmer should keep enough frames to spread PSO warmup draws and flush after them"
	)
	prewarmer.free()


func _verify_prewarmer_offscreen_position() -> void:
	var prewarmer := BattlePsoPrewarmer.new()
	get_root().add_child(prewarmer)
	_expect(prewarmer.position == BattlePsoPrewarmer.OFFSCREEN_POSITION, "prewarmer should park itself off-screen so the warmup draws never touch on-screen pixels")
	_expect(prewarmer.z_index == -4096, "prewarmer should sit below every gameplay layer so it cannot occlude real draws if its position is overridden")
	_expect(prewarmer.modulate.a > 0.0 and prewarmer.modulate.a < 0.1, "prewarmer alpha should be slightly above zero so the GPU driver cannot early-out before issuing the draw")
	_expect(
		prewarmer._boost_fx_host != null and is_instance_valid(prewarmer._boost_fx_host),
		"prewarmer should own a boost FX host child so dash_token_boost_ring shader compiles off-screen"
	)
	if prewarmer._boost_fx_host != null and is_instance_valid(prewarmer._boost_fx_host):
		_expect(
			prewarmer._boost_fx_host.get_parent() == prewarmer,
			"prewarmer's boost FX host must be a direct child so its slot quads inherit the offscreen modulate"
		)
	_expect(
		prewarmer._starpoint_fx_host != null and is_instance_valid(prewarmer._starpoint_fx_host),
		"prewarmer should own a starpoint FX host child so starpoint_drop shader compiles off-screen"
	)
	if prewarmer._starpoint_fx_host != null and is_instance_valid(prewarmer._starpoint_fx_host):
		_expect(
			prewarmer._starpoint_fx_host.get_parent() == prewarmer,
			"prewarmer's starpoint FX host must be a direct child so its slot quads inherit the offscreen modulate"
		)
	prewarmer.queue_free()


func _verify_second_pass_warmup_scope() -> void:
	var prewarmer := BattlePsoPrewarmer.new()
	_expect(prewarmer.has_method("_prewarm_pillar_overlay_primitives"), "prewarmer should cover pillar overlay primitives and frame textures")
	_expect(prewarmer.has_method("_prewarm_skill_icon_textures"), "prewarmer should cover real skill icon texture draws")
	_expect(prewarmer.has_method("_prewarm_timer_stack_primitives"), "prewarmer should cover timer-stack first-use primitives")
	_expect(prewarmer.has_method("_prewarm_weather_primitives"), "prewarmer should cover weather draw primitives")
	_expect(prewarmer.has_method("_prewarm_energy_ball_textures"), "prewarmer should cover energy-ball core and ring texture PSOs")
	_expect(prewarmer.has_method("_prewarm_playfield_primitives"), "prewarmer should cover Stage 1 playfield texture and primitive PSOs")
	_expect(prewarmer.has_method("_prewarm_stage2_center_primitives"), "prewarmer should cover Stage 2 center playfield primitives")
	_expect(prewarmer.has_method("_prewarm_stage2_leaf_primitives"), "prewarmer should cover Stage 2 falling-leaf polygon PSOs")
	_expect(prewarmer.has_method("_prewarm_stage2_pillar_background_textures"), "prewarmer should cover Stage 2 pillar background texture draws")
	_expect(prewarmer.has_method("_prewarm_stage3_pillar_background_textures"), "prewarmer should cover Stage 3 pillar background texture draws")
	_expect(prewarmer.has_method("_prewarm_dash_token_boost_shader_states"), "prewarmer should cover dash token boost shader-state PSOs")
	_expect(prewarmer.has_method("_prewarm_common_starpoint_drop_shader"), "prewarmer should cover common starpoint drop shader PSOs")
	_expect(prewarmer.has_method("_prewarm_character_topdown_rim_shader"), "prewarmer should cover the player topdown rim shader PSO")
	_expect(prewarmer.has_method("_prewarm_stage1_result_pose_textures"), "prewarmer should cover Stage 1 round-result pose texture uploads")
	_expect(prewarmer.has_method("_prewarm_draw_step"), "prewarmer should stage warmup families across multiple draw frames")
	_expect(prewarmer._weather_renderer != null, "prewarmer should own a weather renderer for weather PSO warmup")
	_expect(prewarmer._status_orb_renderer != null, "prewarmer should own the pillar status orb renderer for real HUD warmup")
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_pso_prewarmer.gd")
	_expect(source.find("compact_fallback_frame") >= 0, "prewarmer should exercise the compact boss-dash fallback frame")
	_expect(source.find("VIPER_SKILL_ICON_PATHS") >= 0, "prewarmer should draw selected-character skill icon texture families")
	_expect(source.find("draw_mesh") >= 0 and source.find("ActiveItemThrowMolotovRenderer._get_filled_ellipse_mesh") >= 0, "prewarmer should exercise the active-item molotov filled ellipse mesh path")
	_expect(
		source.find("EnergyBallTextureCache.draw_core") >= 0
			and source.find("EnergyBallTextureCache.draw_saturn_ring") >= 0,
		"prewarmer should issue energy-ball core and saturn-ring draws before the first live ball frame"
	)
	# The three live dash-orb boost shader paths must each be exercised so the
	# GPU compiles every branch of dash_token_boost_ring.gdshader before the
	# first real boost event lands in gameplay.
	var boost_body: String = _function_body(source, "func _prewarm_dash_token_boost_shader_states")
	_expect(
		boost_body.find("boost_charging_pending_dash_refund") >= 0,
		"PSO prewarmer should exercise rainbow refund (boost_charging_pending_dash_refund) shader path"
	)
	_expect(
		boost_body.find("boost_charging_active") >= 0
			and boost_body.find("boost_charging_token_index") >= 0,
		"PSO prewarmer should exercise sector boost (boost_charging_active + boost_charging_token_index) shader path"
	)
	_expect(
		boost_body.find("show_half_label") >= 0,
		"PSO prewarmer should exercise half-ready (show_half_label) shader path"
	)
	# Plasma ball state (dash_recovering=true) must be exercised so the new
	# shader branch that replaced the CPU recovery sparks compiles before the
	# first real dash recovery frame.
	_expect(
		boost_body.find("\"dash_recovering\": true") >= 0,
		"PSO prewarmer should exercise plasma ball recovery (dash_recovering=true) shader path"
	)
	_expect(
		boost_body.find("boost_fx_host") >= 0,
		"PSO prewarmer should pass the boost FX host into dash orb contexts so sync_slot fires off-screen"
	)
	_expect(
		source.find("res://shaders/character_topdown_rim.gdshader") >= 0
			and source.find("CharacterTopdownRimShader") >= 0,
		"PSO prewarmer should preload the character topdown rim shader"
	)
	_expect(
		source.find("SMASHER_VICTORY_SHEET_PATH") >= 0
			and source.find("DALJI_BOSS_DEFEAT_PATH") >= 0,
		"PSO prewarmer should draw cached Stage 1 result pose sheets before the first scoreboard"
	)
	# The large skill cut-in sheets must be force-uploaded offscreen at boot so
	# the first Power Smashing / Ghost Smashing / Phantom Kick freeze does not
	# stall on the cut-in sheet's first draw_texture_rect_region.
	_expect(
		prewarmer.has_method("_prewarm_skill_cutin_sheets"),
		"prewarmer should warm the large skill cut-in sheets (power/ghost/phantom) so the first cut-in freeze does not stall on first draw"
	)
	_expect(
		source.find("POWER_SMASHING_CUTIN_SHEET_PATH") >= 0
			and source.find("VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH") >= 0,
		"PSO prewarmer should draw the skill cut-in sheets to force their VRAM upload offscreen at boot"
	)
	prewarmer.free()


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _verify_prewarmer_uses_imported_texture_resources() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_pso_prewarmer.gd")
	_expect(source.find("ProjectResourceLoader.get_cached_texture") >= 0, "prewarmer should only consume already-prewarmed texture resources")
	_expect(source.find("ResourceLoader.load") < 0, "prewarmer should not synchronously import textures during boot draw warmup")
	_expect(source.find("Image.load_from_file") < 0, "prewarmer should not decode source images during boot draw warmup")
	_expect(source.find("ImageTexture.create_from_image") < 0, "prewarmer should not create fresh textures during boot draw warmup")


func _verify_attach_helper_idempotence() -> void:
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	get_root().add_child(owner)
	_expect(not controller.battle_pso_prewarmer_attached, "attach flag should default to false on a fresh controller")
	controller._attach_battle_pso_prewarmer(owner)
	_expect(controller.battle_pso_prewarmer_attached, "first attach call should latch the prewarmer flag")
	_expect(owner.get_node_or_null("BattlePsoPrewarmer") != null, "first attach call should add the prewarmer node to the owner")
	# Calling attach a second time must NOT add a duplicate prewarmer.
	controller._attach_battle_pso_prewarmer(owner)
	var prewarmer_children: int = 0
	for child in owner.get_children():
		if child is BattlePsoPrewarmer:
			prewarmer_children += 1
	_expect(prewarmer_children == 1, "attach helper must be idempotent so repeated stage transitions never duplicate the prewarmer")
	owner.current_stage = 2
	controller._attach_battle_pso_prewarmer(owner)
	prewarmer_children = 0
	for child in owner.get_children():
		if child is BattlePsoPrewarmer:
			prewarmer_children += 1
	_expect(prewarmer_children == 2, "attach helper should re-arm the PSO prewarmer once for a newly entered stage")
	owner.queue_free()


func _verify_stage_step_waits_for_draw_warmup() -> void:
	var controller := BattleBootResourcePrewarmController.new()
	var owner := FakeOwner.new()
	get_root().add_child(owner)
	_expect(
		not controller._run_battle_pso_prewarmer_step(owner),
		"PSO prewarmer stage step should hold the loading warmup while offscreen draw passes are still running"
	)
	var prewarmer := owner.get_node_or_null("BattlePsoPrewarmer")
	_expect(prewarmer != null, "PSO prewarmer stage step should attach the prewarmer node on its first call")
	for _i in range(BattlePsoPrewarmer.LIFETIME_FRAMES + 2):
		await process_frame
	_expect(
		controller._run_battle_pso_prewarmer_step(owner),
		"PSO prewarmer stage step should finish after the staged draw warmup node self-destructs"
	)
	owner.queue_free()


func _verify_prewarmer_self_destructs() -> void:
	var prewarmer := BattlePsoPrewarmer.new()
	get_root().add_child(prewarmer)
	for _i in range(BattlePsoPrewarmer.LIFETIME_FRAMES + 2):
		await process_frame
	_expect(not is_instance_valid(prewarmer) or prewarmer.is_queued_for_deletion(), "prewarmer should free itself after LIFETIME_FRAMES so it does not linger in the scene tree")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
