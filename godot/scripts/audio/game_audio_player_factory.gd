extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const POSITIONAL_MAX_DISTANCE := 100000.0


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


func create_positional(
	parent: Node,
	name: String,
	path: String,
	volume_db: float,
	position: Vector2,
	panning_strength: float
) -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	player.name = name
	player.bus = "Master"
	player.volume_db = volume_db
	player.position = position
	player.panning_strength = panning_strength
	player.attenuation = 0.0
	player.max_distance = POSITIONAL_MAX_DISTANCE
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
