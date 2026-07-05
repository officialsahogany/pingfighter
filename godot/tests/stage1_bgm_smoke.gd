extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const STAGE1_TRACK_NAMES := ["stage1", "stage1_alt", "stage1_alt2"]

var host: Node = null
var audio: Object = null
var frame_count := 0
var cleanup_pending := false
var cleanup_frames_remaining := 0


func _init() -> void:
	if not _expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage1bgm.mp3") != null,
		"Stage 1 primary BGM should load"
	):
		return
	if not _expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage1bgm2.ogg") != null,
		"Stage 1 alternate BGM should load"
	):
		return
	if not _expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage1bgm3.ogg") != null,
		"Stage 1 second alternate BGM should load"
	):
		return
	var primary_len := _get_file_length("res://assets/bgm/stage1bgm.mp3")
	var alt_len := _get_file_length("res://assets/bgm/stage1bgm2.ogg")
	var alt2_len := _get_file_length("res://assets/bgm/stage1bgm3.ogg")
	if not _expect(
		primary_len != alt_len and primary_len != alt2_len and alt_len != alt2_len,
		"Stage 1 BGM source files should each be distinct audio (no duplicate pool members)"
	):
		return
	if not _verify_cold_stage1_bgm_selection():
		return
	if not _verify_stage1_bgm_seeded_random_can_select_all():
		return

	host = Node.new()
	get_root().add_child(host)
	audio = GameAudio.new()
	audio.owner_node = host
	audio._setup_bgm_players()
	if not _expect(audio._is_setup_complete(), "Stage 1 BGM players should set up"):
		return


func _process(_delta: float) -> bool:
	if cleanup_pending:
		cleanup_frames_remaining -= 1
		if cleanup_frames_remaining > 0:
			return false
		print("stage1_bgm_smoke: ok")
		quit(0)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
	if audio == null:
		quit(1)
		return true

	if not _expect(audio.set_bgm_muted(true), "Stage 1 BGM smoke should enter muted mode"):
		return true
	if not _expect(audio.prime_stage_bgm(1), "Stage 1 BGM should prime"):
		return true
	var primed_name: String = audio.get_current_bgm_name()
	if not _expect(
		primed_name in STAGE1_TRACK_NAMES,
		"Stage 1 primed BGM should be one of the three Stage 1 tracks"
	):
		return true
	if not _expect(audio.play_stage_bgm(1), "Stage 1 BGM should play"):
		return true
	var played_name: String = audio.get_current_bgm_name()
	if not _expect(
		played_name in STAGE1_TRACK_NAMES,
		"Stage 1 played BGM should be one of the three Stage 1 tracks"
	):
		return true
	if not _expect(played_name == primed_name, "Stage 1 play should reuse the primed track"):
		return true

	audio.stop_bgm()
	_clear_player(audio.stage1_bgm)
	_clear_player(audio.stage1_alt_bgm)
	_clear_player(audio.stage1_alt2_bgm)
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


func _verify_cold_stage1_bgm_selection() -> bool:
	var cold_host := Node.new()
	get_root().add_child(cold_host)
	var cold_audio: Object = GameAudio.new()
	cold_audio.owner_node = cold_host
	cold_audio.set_bgm_muted(true)
	if not _expect(cold_audio.prime_stage_bgm(1), "Cold Stage 1 BGM should prime"):
		return false
	var selected_name: String = cold_audio.get_current_bgm_name()
	if not _expect(
		selected_name in STAGE1_TRACK_NAMES,
		"Cold Stage 1 BGM should select one of the three tracks"
	):
		return false
	if not _expect(
		cold_audio.stage1_bgm != null and cold_audio.stage1_bgm.stream != null,
		"Cold Stage 1 BGM selection should prepare the primary track as a candidate"
	):
		return false
	if not _expect(
		cold_audio.stage1_alt_bgm != null and cold_audio.stage1_alt_bgm.stream != null,
		"Cold Stage 1 BGM selection should prepare the alternate track as a candidate"
	):
		return false
	if not _expect(
		cold_audio.stage1_alt2_bgm != null and cold_audio.stage1_alt2_bgm.stream != null,
		"Cold Stage 1 BGM selection should prepare the second alternate track as a candidate"
	):
		return false
	if not _expect(
		bool(cold_audio.stage1_bgm_rng_ready),
		"Stage 1 BGM selection should seed its own RNG before boot lifecycle randomize"
	):
		return false
	cold_audio.stop_bgm()
	_clear_player(cold_audio.stage1_bgm)
	_clear_player(cold_audio.stage1_alt_bgm)
	_clear_player(cold_audio.stage1_alt2_bgm)
	cold_host.queue_free()
	return true


func _verify_stage1_bgm_seeded_random_can_select_all() -> bool:
	var seeded_host := Node.new()
	get_root().add_child(seeded_host)
	var seeded_audio: Object = GameAudio.new()
	seeded_audio.owner_node = seeded_host
	seeded_audio.set_bgm_muted(true)
	var selected_names := {}
	for seed_value in range(256):
		seeded_audio.stage1_bgm_rng.seed = seed_value
		seeded_audio.stage1_bgm_rng_ready = true
		if not _expect(seeded_audio.prime_stage_bgm(1), "Seeded Stage 1 BGM should prime"):
			return false
		selected_names[seeded_audio.get_current_bgm_name()] = true
		seeded_audio.stop_bgm()
		if selected_names.size() >= STAGE1_TRACK_NAMES.size():
			break
	for track_name in STAGE1_TRACK_NAMES:
		if not _expect(
			selected_names.has(track_name),
			"Seeded Stage 1 random selection should be able to choose every BGM track"
		):
			return false
	_clear_player(seeded_audio.stage1_bgm)
	_clear_player(seeded_audio.stage1_alt_bgm)
	_clear_player(seeded_audio.stage1_alt2_bgm)
	seeded_host.queue_free()
	return true


func _clear_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null
