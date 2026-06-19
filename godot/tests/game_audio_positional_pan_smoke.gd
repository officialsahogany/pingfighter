extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")

var _failures: Array[String] = []
var _host: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_host = Node.new()
	_host.name = "GameAudioPositionalPanSmokeHost"
	get_root().add_child(_host)
	await process_frame

	var audio: Object = GameAudio.new()
	audio.owner_node = _host
	audio._setup_core_ball_sfx()
	audio._apply_audio_buses_and_volumes()

	_verify_hit_players_are_positional(audio)
	_verify_hit_players_on_sfx_bus(audio)
	_verify_listener_present_and_current(audio)
	_verify_distance_attenuation_off(audio)
	_verify_default_is_centered(audio)
	_verify_source_x_maps_to_position(audio)
	_verify_non_hit_players_unchanged(audio)

	_cleanup_host_audio_nodes()
	await process_frame
	if _host != null:
		_host.queue_free()
		_host = null
	await process_frame

	if _failures.is_empty():
		print("game_audio_positional_pan_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_hit_players_are_positional(audio: Object) -> void:
	_expect(audio.paddle_hit_sfx is AudioStreamPlayer2D, "paddle hit SFX should use AudioStreamPlayer2D")
	_expect(audio.wall_hit_sfx is AudioStreamPlayer2D, "wall hit SFX should use AudioStreamPlayer2D")


func _verify_hit_players_on_sfx_bus(audio: Object) -> void:
	var paddle_player: AudioStreamPlayer2D = audio.paddle_hit_sfx
	var wall_player: AudioStreamPlayer2D = audio.wall_hit_sfx
	_expect(paddle_player != null and paddle_player.bus == "SFX", "paddle hit positional player should route through the SFX bus")
	_expect(wall_player != null and wall_player.bus == "SFX", "wall hit positional player should route through the SFX bus")


func _verify_listener_present_and_current(audio: Object) -> void:
	var listener: AudioListener2D = audio.hit_audio_listener
	_expect(listener != null, "hit positional audio should create a central AudioListener2D")
	if listener == null:
		return
	_expect(listener.get_parent() == _host, "hit AudioListener2D should be attached to the audio owner node")
	_expect(_vector2_close(listener.position, Vector2(380.0, 375.0)), "hit AudioListener2D should sit at playfield center")
	_expect(listener.is_current(), "hit AudioListener2D should be the current 2D audio listener")


func _verify_distance_attenuation_off(audio: Object) -> void:
	var paddle_player: AudioStreamPlayer2D = audio.paddle_hit_sfx
	var wall_player: AudioStreamPlayer2D = audio.wall_hit_sfx
	_expect(paddle_player != null and is_equal_approx(paddle_player.attenuation, 0.0), "paddle hit positional player should disable distance attenuation")
	_expect(wall_player != null and is_equal_approx(wall_player.attenuation, 0.0), "wall hit positional player should disable distance attenuation")
	_expect(paddle_player != null and paddle_player.max_distance >= 760.0, "paddle hit positional player should cover the full playfield")
	_expect(wall_player != null and wall_player.max_distance >= 760.0, "wall hit positional player should cover the full playfield")


func _verify_default_is_centered(audio: Object) -> void:
	audio.paddle_sound_cooldown = 0.0
	audio.play_paddle_hit()
	var paddle_player: AudioStreamPlayer2D = audio.paddle_hit_sfx
	_expect(paddle_player != null and is_equal_approx(paddle_player.position.x, 380.0), "default paddle hit should remain centered")
	_stop_player(paddle_player)


func _verify_source_x_maps_to_position(audio: Object) -> void:
	audio.paddle_sound_cooldown = 0.0
	audio.play_paddle_hit(120.0)
	var paddle_player: AudioStreamPlayer2D = audio.paddle_hit_sfx
	_expect(paddle_player != null and is_equal_approx(paddle_player.position.x, 120.0), "paddle hit source X should map to the positional player")
	_stop_player(paddle_player)

	audio.play_rally_tier_accent(3, 250.0)
	var accent_player: AudioStreamPlayer2D = audio.wall_hit_sfx
	_expect(accent_player != null and is_equal_approx(accent_player.position.x, 250.0), "rally tier accent source X should map to the positional player")
	_stop_player(accent_player)

	audio.wall_sound_cooldown = 0.0
	audio.play_wall_hit(20.0, 700.0)
	var wall_player: AudioStreamPlayer2D = audio.wall_hit_sfx
	_expect(wall_player != null and is_equal_approx(wall_player.position.x, 700.0), "wall hit source X should map to the positional player")
	_stop_player(wall_player)


func _verify_non_hit_players_unchanged(audio: Object) -> void:
	var serve_player: Variant = audio.serve_sfx
	_expect(serve_player is AudioStreamPlayer, "serve SFX should remain a non-positional AudioStreamPlayer")
	_expect(not (serve_player is AudioStreamPlayer2D), "serve SFX should not be converted to AudioStreamPlayer2D")


func _cleanup_host_audio_nodes() -> void:
	if _host == null:
		return
	for child in _host.get_children():
		if child is AudioStreamPlayer:
			_stop_player(child as AudioStreamPlayer)
			(child as AudioStreamPlayer).stream = null
			child.queue_free()
		elif child is AudioStreamPlayer2D:
			_stop_player(child as AudioStreamPlayer2D)
			(child as AudioStreamPlayer2D).stream = null
			child.queue_free()
		elif child is AudioListener2D:
			child.queue_free()


func _stop_player(player: Object) -> void:
	if player == null:
		return
	if bool(player.get("playing")):
		player.call("stop")


func _vector2_close(a: Vector2, b: Vector2, epsilon: float = 0.01) -> bool:
	return a.distance_to(b) <= epsilon


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
