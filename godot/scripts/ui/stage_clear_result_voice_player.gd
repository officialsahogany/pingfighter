extends RefCounted

const DALJI_CLICK_VOICE_VOLUME_DB := -4.5
const DALJI_CLICK_VOICE_PLAYER_NAME := "DaljiClickCryVoice"


static func play_voice(
	parent: Node,
	player: AudioStreamPlayer,
	stream: AudioStream,
	volume_db: float = DALJI_CLICK_VOICE_VOLUME_DB,
	player_name: String = DALJI_CLICK_VOICE_PLAYER_NAME,
	deferred_method: StringName = &""
) -> AudioStreamPlayer:
	if stream == null:
		return player
	var target: AudioStreamPlayer = player
	if target == null:
		target = AudioStreamPlayer.new()
		target.name = player_name
		if parent != null:
			parent.add_child(target)
	elif target.get_parent() == null and parent != null:
		parent.add_child(target)
	target.stream = stream
	target.volume_db = volume_db
	target.stop()
	if parent == null:
		return target
	if not parent.is_inside_tree() or not target.is_inside_tree():
		if deferred_method != &"":
			parent.call_deferred(deferred_method)
		return target
	target.play()
	return target


static func play_deferred(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	if not player.is_inside_tree():
		return
	player.stop()
	player.play()


static func stop_voice(player: AudioStreamPlayer) -> void:
	if player != null and player.playing:
		player.stop()
