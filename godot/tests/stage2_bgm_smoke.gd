extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var host: Node = null
var audio: Object = null
var frame_count := 0
var cleanup_pending := false
var cleanup_frames_remaining := 0


func _init() -> void:
	if not _expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage2bgm.ogg") != null,
		"Stage 2 primary BGM should load"
	):
		return
	if not _expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage2bgm2.mp3") != null,
		"Stage 2 alternate BGM should load"
	):
		return
	if not _expect(
		_get_file_length("res://assets/bgm/stage2bgm.ogg") != _get_file_length("res://assets/bgm/stage2bgm2.mp3"),
		"Stage 2 primary and alternate BGM source files should not be duplicate audio"
	):
		return
	if not _verify_cold_stage2_bgm_selection():
		return
	if not _verify_stage2_bgm_seeded_random_can_select_both():
		return

	host = Node.new()
	get_root().add_child(host)
	audio = GameAudio.new()
	audio.owner_node = host
	audio._setup_bgm_players()
	if not _expect(audio._is_setup_complete(), "Stage 2 BGM players should set up"):
		return


func _process(_delta: float) -> bool:
	if cleanup_pending:
		cleanup_frames_remaining -= 1
		if cleanup_frames_remaining > 0:
			return false
		print("stage2_bgm_smoke: ok")
		quit(0)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
	if audio == null:
		quit(1)
		return true

	if not _expect(audio.set_bgm_muted(true), "Stage 2 BGM smoke should enter muted mode"):
		return true
	if not _expect(audio.prime_stage_bgm(2), "Stage 2 BGM should prime"):
		return true
	var primed_name: String = audio.get_current_bgm_name()
	if not _expect(
		primed_name in ["stage2", "stage2_alt"],
		"Stage 2 primed BGM should be one of the two Stage 2 tracks"
	):
		return true
	if not _expect(audio.play_stage_bgm(2), "Stage 2 BGM should play"):
		return true
	var played_name: String = audio.get_current_bgm_name()
	if not _expect(
		played_name in ["stage2", "stage2_alt"],
		"Stage 2 played BGM should be one of the two Stage 2 tracks"
	):
		return true
	if not _expect(played_name == primed_name, "Stage 2 play should reuse the primed track"):
		return true

	audio.stop_bgm()
	_clear_player(audio.stage1_bgm)
	_clear_player(audio.stage2_bgm)
	_clear_player(audio.stage2_alt_bgm)
	host.queue_free()
	audio = null
	host = null
	cleanup_pending = true
	cleanup_frames_remaining = 8
	return false


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _get_file_length(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	return file.get_length()


func _verify_cold_stage2_bgm_selection() -> bool:
	var cold_host := Node.new()
	get_root().add_child(cold_host)
	var cold_audio: Object = GameAudio.new()
	cold_audio.owner_node = cold_host
	cold_audio.set_bgm_muted(true)
	if not _expect(cold_audio.prime_stage_bgm(2), "Cold Stage 2 BGM should prime"):
		return false
	var selected_name: String = cold_audio.get_current_bgm_name()
	if not _expect(
		selected_name in ["stage2", "stage2_alt"],
		"Cold Stage 2 BGM should select one of the two tracks"
	):
		return false
	if not _expect(
		cold_audio.stage2_bgm != null and cold_audio.stage2_bgm.stream != null,
		"Cold Stage 2 BGM selection should prepare the primary track as a candidate"
	):
		return false
	if not _expect(
		cold_audio.stage2_alt_bgm != null and cold_audio.stage2_alt_bgm.stream != null,
		"Cold Stage 2 BGM selection should prepare the alternate track as a candidate"
	):
		return false
	if not _expect(
		bool(cold_audio.stage2_bgm_rng_ready),
		"Stage 2 BGM selection should seed its own RNG before boot lifecycle randomize"
	):
		return false
	cold_audio.stop_bgm()
	_clear_player(cold_audio.stage2_bgm)
	_clear_player(cold_audio.stage2_alt_bgm)
	cold_host.queue_free()
	return true


func _verify_stage2_bgm_seeded_random_can_select_both() -> bool:
	var seeded_host := Node.new()
	get_root().add_child(seeded_host)
	var seeded_audio: Object = GameAudio.new()
	seeded_audio.owner_node = seeded_host
	seeded_audio.set_bgm_muted(true)
	var selected_names := {}
	for seed_value in range(64):
		seeded_audio.stage2_bgm_rng.seed = seed_value
		seeded_audio.stage2_bgm_rng_ready = true
		if not _expect(seeded_audio.prime_stage_bgm(2), "Seeded Stage 2 BGM should prime"):
			return false
		selected_names[seeded_audio.get_current_bgm_name()] = true
		seeded_audio.stop_bgm()
		if selected_names.has("stage2") and selected_names.has("stage2_alt"):
			break
	if not _expect(
		selected_names.has("stage2") and selected_names.has("stage2_alt"),
		"Seeded Stage 2 random selection should be able to choose both BGM tracks"
	):
		return false
	_clear_player(seeded_audio.stage2_bgm)
	_clear_player(seeded_audio.stage2_alt_bgm)
	seeded_host.queue_free()
	return true


func _clear_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null
