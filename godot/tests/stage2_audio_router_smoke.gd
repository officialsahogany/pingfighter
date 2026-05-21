extends SceneTree

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var quake_start_count := 0
	var quake_stop_count := 0
	var boss_cry_count := 0

	func play_stage2_quake_loop() -> void:
		quake_start_count += 1

	func stop_stage2_quake_loop() -> void:
		quake_stop_count += 1

	func play_stage2_boss_cry() -> void:
		boss_cry_count += 1


func _init() -> void:
	_verify_audio_resolution()
	_verify_quake_loop_routing()
	_verify_boss_cry_routing()
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


func _verify_background_delegates_audio_router() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stages/stage2/stage2_pillar_background.gd")
	_expect(source.find("Stage2AudioRouter.sync_quake_loop") >= 0, "Stage 2 background should delegate quake loop sync")
	_expect(source.find("Stage2AudioRouter.play_quake_loop") >= 0, "Stage 2 background should delegate quake loop start")
	_expect(source.find("Stage2AudioRouter.stop_quake_loop") >= 0, "Stage 2 background should delegate quake loop stop")
	_expect(source.find("Stage2AudioRouter.play_boss_cry") >= 0, "Stage 2 background should delegate boss cry audio")
	_expect(source.find("func _resolve_rage_audio") < 0, "Stage 2 background should not keep the old rage audio resolver")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
