extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")

var _failures: Array[String] = []
var _host: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_host = Node.new()
	_host.name = "GameAudioPannerSmokeHost"
	get_root().add_child(_host)
	await process_frame

	var audio: Object = GameAudio.new()
	audio.owner_node = _host
	audio._setup_core_ball_sfx()
	audio._apply_audio_buses_and_volumes()

	_verify_hit_players_are_regular_players(audio)
	_verify_hit_players_use_panner_buses(audio)
	_verify_panner_buses_send_to_sfx()
	_verify_default_pan_is_centered(audio)
	_verify_source_x_maps_to_pan(audio)
	_verify_non_hit_players_unchanged(audio)

	_cleanup_host_audio_nodes()
	_cleanup_pan_bus(GameAudio.SFX_PAN_WALL_BUS_NAME)
	_cleanup_pan_bus(GameAudio.SFX_PAN_PADDLE_BUS_NAME)
	audio.paddle_hit_panner = null
	audio.wall_hit_panner = null
	audio = null
	await process_frame
	if _host != null:
		_host.queue_free()
		_host = null
	await process_frame
	await process_frame
	await process_frame

	if _failures.is_empty():
		print("game_audio_positional_pan_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_hit_players_are_regular_players(audio: Object) -> void:
	_expect(audio.paddle_hit_sfx is AudioStreamPlayer, "paddle hit SFX should use AudioStreamPlayer")
	_expect(audio.wall_hit_sfx is AudioStreamPlayer, "wall hit SFX should use AudioStreamPlayer")
	_expect(not (audio.paddle_hit_sfx is AudioStreamPlayer2D), "paddle hit SFX should not use AudioStreamPlayer2D")
	_expect(not (audio.wall_hit_sfx is AudioStreamPlayer2D), "wall hit SFX should not use AudioStreamPlayer2D")


func _verify_hit_players_use_panner_buses(audio: Object) -> void:
	var paddle_player: AudioStreamPlayer = audio.paddle_hit_sfx
	var wall_player: AudioStreamPlayer = audio.wall_hit_sfx
	_expect(paddle_player != null and paddle_player.bus == GameAudio.SFX_PAN_PADDLE_BUS_NAME, "paddle hit player should route through the paddle panner bus")
	_expect(wall_player != null and wall_player.bus == GameAudio.SFX_PAN_WALL_BUS_NAME, "wall hit player should route through the wall panner bus")
	_expect(audio.paddle_hit_panner is AudioEffectPanner, "paddle hit panner effect should exist")
	_expect(audio.wall_hit_panner is AudioEffectPanner, "wall hit panner effect should exist")


func _verify_panner_buses_send_to_sfx() -> void:
	_verify_pan_bus(GameAudio.SFX_PAN_PADDLE_BUS_NAME)
	_verify_pan_bus(GameAudio.SFX_PAN_WALL_BUS_NAME)


func _verify_pan_bus(bus_name: String) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	_expect(bus_index >= 0, "%s bus should exist" % bus_name)
	if bus_index < 0:
		return
	_expect(str(AudioServer.get_bus_send(bus_index)) == GameAudio.SFX_BUS_NAME, "%s should send to SFX" % bus_name)
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus_index), 0.0), "%s should stay at unity volume and let the SFX bus own loudness" % bus_name)
	var has_panner := false
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectPanner:
			has_panner = true
			break
	_expect(has_panner, "%s should own an AudioEffectPanner" % bus_name)


func _verify_default_pan_is_centered(audio: Object) -> void:
	audio.paddle_sound_cooldown = 0.0
	audio.play_paddle_hit()
	_expect(is_equal_approx(audio.paddle_hit_panner.get_pan(), 0.0), "default paddle hit should remain centered")
	_stop_player(audio.paddle_hit_sfx)


func _verify_source_x_maps_to_pan(audio: Object) -> void:
	audio.paddle_sound_cooldown = 0.0
	audio.play_paddle_hit(120.0)
	_expect(audio.paddle_hit_panner.get_pan() < 0.0, "left-side paddle hit should set a negative pan")
	_expect(is_equal_approx(audio.paddle_hit_panner.get_pan(), audio._get_hit_pan_from_source_x(120.0)), "paddle hit panner should use the shared source-X pan mapper")
	_stop_player(audio.paddle_hit_sfx)

	audio.play_rally_tier_accent(3, 250.0)
	_expect(audio.wall_hit_panner.get_pan() < 0.0, "left-side rally accent should set a negative wall panner pan")
	_expect(is_equal_approx(audio.wall_hit_panner.get_pan(), audio._get_hit_pan_from_source_x(250.0)), "rally tier accent should use the shared source-X pan mapper")
	_stop_player(audio.wall_hit_sfx)

	audio.wall_sound_cooldown = 0.0
	audio.play_wall_hit(20.0, 700.0)
	_expect(audio.wall_hit_panner.get_pan() > 0.0, "right-side wall hit should set a positive pan")
	_expect(is_equal_approx(audio.wall_hit_panner.get_pan(), audio._get_hit_pan_from_source_x(700.0)), "wall hit panner should use the shared source-X pan mapper")
	_stop_player(audio.wall_hit_sfx)

	audio.wall_sound_cooldown = 0.0
	audio.play_wall_hit(20.0)
	_expect(is_equal_approx(audio.wall_hit_panner.get_pan(), 0.0), "wall hit without source X should fall back to centered pan")
	_stop_player(audio.wall_hit_sfx)


func _verify_non_hit_players_unchanged(audio: Object) -> void:
	var serve_player: Variant = audio.serve_sfx
	_expect(serve_player is AudioStreamPlayer, "serve SFX should remain a regular AudioStreamPlayer")
	_expect(not (serve_player is AudioStreamPlayer2D), "serve SFX should not be converted to AudioStreamPlayer2D")
	_expect((serve_player as AudioStreamPlayer).bus == GameAudio.SFX_BUS_NAME, "serve SFX should still route directly through SFX")


func _cleanup_host_audio_nodes() -> void:
	if _host == null:
		return
	for child in _host.get_children():
		if child is AudioStreamPlayer:
			_stop_player(child as AudioStreamPlayer)
			(child as AudioStreamPlayer).stream = null
			child.queue_free()


func _cleanup_pan_bus(bus_name: String) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_index, effect_index)
	AudioServer.remove_bus(bus_index)


func _stop_player(player: Object) -> void:
	if player == null:
		return
	if bool(player.get("playing")):
		player.call("stop")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
