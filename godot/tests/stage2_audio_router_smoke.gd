extends SceneTree

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var quake_start_count := 0
	var quake_stop_count := 0
	var boss_cry_count := 0
	var hydro_count := 0
	var rock_spawn_count := 0
	var rock_hit_count := 0
	var stonebreak_count := 0
	var sized_stonebreak_values: Array[float] = []
	var starpoint_collect_count := 0

	func play_stage2_quake_loop() -> void:
		quake_start_count += 1

	func stop_stage2_quake_loop() -> void:
		quake_stop_count += 1

	func play_stage2_boss_cry() -> void:
		boss_cry_count += 1

	func play_stage2_hydro() -> void:
		hydro_count += 1

	func play_stage2_rock_spawn() -> void:
		rock_spawn_count += 1

	func play_stage2_rockhit() -> void:
		rock_hit_count += 1

	func play_stage2_stonebreak() -> void:
		stonebreak_count += 1

	func play_stage2_stonebreak_for_size(size: float) -> void:
		sized_stonebreak_values.append(size)

	func play_starpoint_collect() -> void:
		starpoint_collect_count += 1


func _init() -> void:
	_verify_audio_resolution()
	_verify_quake_loop_routing()
	_verify_boss_cry_routing()
	_verify_stage2_effect_cues()
	_verify_background_delegates_audio_router()

	if _failures.is_empty():
		print("stage2_audio_router_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_audio_resolution() -> void:
	var fallback := FakeAudio.new()
	var primary := FakeAudio.new()
	_expect(Stage2AudioRouter.resolve_audio({"audio": primary}, fallback) == primary, "audio router should prefer deps audio")
	_expect(Stage2AudioRouter.resolve_audio({}, fallback) == fallback, "audio router should fall back to cached rage audio")


func _verify_quake_loop_routing() -> void:
	var audio := FakeAudio.new()
	var active := Stage2AudioRouter.play_quake_loop({"audio": audio}, null, false)
	_expect(active, "audio router should mark quake loop active after play")
	_expect(audio.quake_start_count == 1, "audio router should play the quake loop")
	active = Stage2AudioRouter.sync_quake_loop(0.5, active, {}, audio)
	_expect(active, "audio router should keep quake loop active from fallback audio")
	_expect(audio.quake_start_count == 2, "audio router should sync active quake loop through fallback audio")
	active = Stage2AudioRouter.sync_quake_loop(0.0, active, {}, audio)
	_expect(not active, "audio router should clear active state after stop")
	_expect(audio.quake_stop_count == 1, "audio router should stop the quake loop")
	_expect(not Stage2AudioRouter.play_quake_loop({}, null, false), "audio router should keep inactive state without audio")


func _verify_boss_cry_routing() -> void:
	var audio := FakeAudio.new()
	Stage2AudioRouter.play_boss_cry({}, audio)
	_expect(audio.boss_cry_count == 1, "audio router should play boss cry through fallback audio")


func _verify_stage2_effect_cues() -> void:
	var audio := FakeAudio.new()
	var deps := {"audio": audio}
	Stage2AudioRouter.play_hydro(deps)
	Stage2AudioRouter.play_rock_spawn(deps)
	Stage2AudioRouter.play_rock_hit(deps)
	Stage2AudioRouter.play_rock_break({"visual_radius": 42.0}, deps)
	Stage2AudioRouter.play_starpoint_collect(deps)
	_expect(audio.hydro_count == 1, "audio router should play water cannon hydro cues")
	_expect(audio.rock_spawn_count == 1, "audio router should play rock spawn cues")
	_expect(audio.rock_hit_count == 1, "audio router should play rock hit cues")
	_expect(audio.sized_stonebreak_values == [42.0], "audio router should prefer sized stonebreak cues")
	_expect(audio.starpoint_collect_count == 1, "audio router should play starpoint collect cues")


func _verify_background_delegates_audio_router() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(source.find("Stage2AudioRouter.sync_quake_loop") >= 0, "Stage 2 background should delegate quake loop sync")
	_expect(source.find("Stage2AudioRouter.play_quake_loop") >= 0, "Stage 2 background should delegate quake loop start")
	_expect(source.find("Stage2AudioRouter.stop_quake_loop") >= 0, "Stage 2 background should delegate quake loop stop")
	_expect(source.find("Stage2AudioRouter.play_boss_cry") >= 0, "Stage 2 background should delegate boss cry audio")
	_expect(source.find("Stage2AudioRouter.play_rock_spawn") >= 0, "Stage 2 background should delegate rock spawn audio")
	_expect(source.find("Stage2AudioRouter.play_rock_break") >= 0, "Stage 2 background should delegate rock break audio")
	_expect(source.find("Stage2AudioRouter.play_rock_hit") >= 0, "Stage 2 background should delegate rock hit audio")
	_expect(source.find("Stage2AudioRouter.play_hydro") >= 0, "Stage 2 background should delegate hydro audio")
	_expect(source.find("Stage2AudioRouter.play_starpoint_collect") >= 0, "Stage 2 background should delegate starpoint audio")
	_expect(source.find("func _resolve_rage_audio") < 0, "Stage 2 background should not keep the old rage audio resolver")
	_expect(source.find("func _play_boss_rage_cry") < 0, "Stage 2 background should not keep the old boss cry audio wrapper")
	_expect(source.find("func _play_rock_break_audio") < 0, "Stage 2 background should not keep the old rock break audio wrapper")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
