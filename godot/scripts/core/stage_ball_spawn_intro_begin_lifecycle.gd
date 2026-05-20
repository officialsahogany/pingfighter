extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func begin_intro(intro: Object, owner: Object, registry: Object, config: Dictionary) -> bool:
	if intro == null or owner == null:
		return false
	var tutorial_stage: int = int(config.get("tutorial_stage", 50))
	var game_width: float = float(config.get("game_width", 760.0))
	var game_height: float = float(config.get("game_height", 750.0))
	var current_stage: int = int(BattleSceneOwnerReader.get_value(owner, "current_stage", 1))
	intro.current_stage = current_stage
	if current_stage <= 0 or current_stage == tutorial_stage:
		return false

	intro._get_glow_texture()
	intro._get_ball_texture()
	intro._get_ball_body_texture()

	var round_state: Object = _get_instance(registry, "round_flow_state")
	intro.player_serves = (
		round_state == null
		or not round_state.has_method("does_player_serve")
		or bool(round_state.does_player_serve())
	)
	intro.start_pos = Vector2(game_width * 0.5, game_height * 0.5)
	intro.target_pos = intro._get_serve_target(owner)
	intro.elapsed_sec = 0.0
	intro.active = true
	intro.overlay_active = true
	intro.serve_handoff_done = false

	intro.rng.seed = int(91823 + current_stage * 1493)
	intro._reset_state()
	intro._spawn_initial_entities()
	intro._begin_fx_host(owner)
	if intro.has_method("_begin_pillar_overlay_host"):
		intro._begin_pillar_overlay_host(owner, registry)
	intro._apply_owner_spawn_snapshot(owner, intro.start_pos)
	_play_intro_audio(registry)

	if round_state != null and round_state.has_method("pause_serve_for_intro"):
		round_state.pause_serve_for_intro()
	intro._sync_serve_input(registry)
	return true


func _play_intro_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_ball_spawn_intro"):
		audio.play_ball_spawn_intro()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
