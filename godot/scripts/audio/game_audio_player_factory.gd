extends RefCounted


func create(parent: Node, name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = name
	player.bus = "Master"
	player.volume_db = volume_db
	if parent == null:
		return player

	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("Missing sound at %s" % path)
		parent.add_child(player)
		return player

	var stream: AudioStream
	if path.get_extension().to_lower() == "wav" and FileAccess.file_exists(path):
		stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	if stream == null and ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream != null:
		player.stream = stream
	else:
		push_warning("Failed to load sound at %s" % path)

	parent.add_child(player)
	return player
