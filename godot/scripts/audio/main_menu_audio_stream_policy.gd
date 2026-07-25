extends RefCounted

# Shared main-menu/boot-flow policy for cached audio resources. Loop flags are
# player-local state and must never be written onto ProjectResourceLoader's
# path-cached AudioStream instance.


static func duplicate_for_looping_player(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var player_stream := stream.duplicate() as AudioStream
	if player_stream == null:
		return null
	enable_loop(player_stream)
	return player_stream


static func enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = max(0, int(round(wav_stream.get_length() * float(wav_stream.mix_rate))))
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


static func ensure_bus(bus_name: String, default_volume: float) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_volume_db(bus_index, volume_to_db(default_volume))
	return bus_index


static func volume_to_db(volume: float) -> float:
	var clamped := clampf(volume, 0.0, 1.0)
	return -80.0 if clamped <= 0.0 else linear_to_db(clamped)
