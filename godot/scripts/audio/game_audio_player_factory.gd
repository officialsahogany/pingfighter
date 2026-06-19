extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


func create(parent: Node, name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = name
	player.bus = "Master"
	player.volume_db = volume_db
	if parent == null:
		return player

	var stream: AudioStream = ProjectResourceLoader.load_audio_stream(
		path,
		"Missing sound at %s",
		"Failed to load sound at %s"
	)
	if stream != null:
		player.stream = stream

	parent.add_child(player)
	return player
