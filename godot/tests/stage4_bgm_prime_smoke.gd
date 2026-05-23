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
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage4bgm.ogg") != null,
		"Stage 4 primary BGM should load"
	):
		return
	if not _expect(
		ProjectResourceLoader.load_audio_stream("res://assets/bgm/stage4bgm-phase2.mp3") != null,
		"Stage 4 phase 2 BGM should load"
	):
		return

	host = Node.new()
	get_root().add_child(host)
	audio = GameAudio.new()
	audio.owner_node = host
	audio._setup_bgm_players()
	if not _expect(audio._is_setup_complete(), "Stage 4 BGM players should set up"):
		return


func _process(_delta: float) -> bool:
	if cleanup_pending:
		cleanup_frames_remaining -= 1
		if cleanup_frames_remaining > 0:
			return false
		print("stage4_bgm_prime_smoke: ok")
		quit(0)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
	if audio == null:
		quit(1)
		return true

	if not _expect(not audio.set_bgm_muted(false), "Stage 4 BGM smoke should use audible prime mode"):
		return true
	if not _expect(audio.prime_stage_bgm(4), "Stage 4 BGM should prime"):
		return true
	if not _expect(audio.primed_bgm_volumes.has("stage4"), "Stage 4 primary BGM should be primed"):
		return true
	if not _expect(audio.primed_bgm_volumes.has("stage4_phase2"), "Stage 4 phase 2 BGM should be primed"):
		return true
	if not _expect(audio.stage4_bgm.playing, "Stage 4 primary BGM should start muted during prime"):
		return true
	if not _expect(audio.stage4_phase2_bgm.playing, "Stage 4 phase 2 BGM should start muted during prime"):
		return true
	if not _expect(audio.get_current_bgm_name() == "stage4_phase2", "Stage 4 prime should leave phase 2 as the latest primed BGM"):
		return true
	if not _expect(audio.play_stage_bgm(4), "Stage 4 primary BGM should play after prime"):
		return true
	if not _expect(audio.get_current_bgm_name() == "stage4", "Stage 4 play should restore primary BGM ownership"):
		return true
	if not _expect(not audio.stage4_phase2_bgm.playing, "Stage 4 primary play should stop the primed phase 2 BGM"):
		return true
	if not _expect(audio.play_stage4_phase2_bgm(), "Stage 4 phase 2 BGM should play after prime"):
		return true
	if not _expect(audio.get_current_bgm_name() == "stage4_phase2", "Stage 4 phase 2 should become active on demand"):
		return true

	audio.stop_bgm()
	_clear_player(audio.stage1_bgm)
	_clear_player(audio.stage2_bgm)
	_clear_player(audio.stage2_alt_bgm)
	_clear_player(audio.stage3_bgm)
	_clear_player(audio.stage4_bgm)
	_clear_player(audio.stage4_phase2_bgm)
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


func _clear_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
	player.stream = null
