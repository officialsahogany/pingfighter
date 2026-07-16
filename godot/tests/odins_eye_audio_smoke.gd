extends SceneTree

const GameAudio := preload("res://scripts/audio/game_audio.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")

var _failures: Array[String] = []


class RecorderAudio:
	extends RefCounted

	var change_calls := 0
	var death_calls := 0

	func play_odins_eye_change() -> void:
		change_calls += 1

	func play_odins_eye_death() -> void:
		death_calls += 1


class FakeScoreState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {"deuce_mode": false, "player_score": 0, "boss_score": 0}


class FakeScoreOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"special_gauge": 150.0,
		"special_gauge_max": 500.0,
		"player_pos": Vector2(300.0, 700.0),
		"ball_pos": Vector2(380.0, 200.0),
		"ball_vel": Vector2(0.0, 6.0),
		"ball_active": true,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeScoreRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null

	func get_cached_instance(_key: String) -> Object:
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	get_root().add_child(host)
	var audio: Object = GameAudio.new()
	audio.owner_node = host
	audio._setup_item_command_sfx()
	var players: Array = [
		audio.odins_eye_change_sfx,
		audio.odins_eye_death_sfx,
		audio.odins_eye_spirit_sfx,
		audio.odins_eye_attack_sfx,
		audio.odins_eye_shadow_sfx,
	]
	for player_value in players:
		var player := player_value as AudioStreamPlayer
		_expect(player != null and player.stream != null, "every Odin cue should load into a dedicated AudioStreamPlayer")
		if player != null and player.stream is AudioStreamWAV:
			var stream := player.stream as AudioStreamWAV
			_expect(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Odin cues must remain one-shots")
		_expect(audio._get_sfx_players().has(player), "Odin cue should participate in global SFX volume updates")
	audio.play_odins_eye_change()
	audio.play_odins_eye_death()
	audio.play_odins_eye_spirit()
	audio.play_odins_eye_attack()
	audio.play_odins_eye_shadow()
	for player_value in players:
		var player := player_value as AudioStreamPlayer
		_expect(player != null and player.playing, "Odin cue method should start its player")
		if player != null:
			player.stop()
			player.stream = null
	for child in host.get_children():
		child.queue_free()
	players.clear()
	audio = null
	await process_frame
	await process_frame
	await process_frame
	host.queue_free()
	host = null
	await process_frame
	await process_frame
	await process_frame
	_verify_score_path_plays_change_and_death()
	if _failures.is_empty():
		print("odins_eye_audio_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# [P1 실경로 씰] change/death 원샷은 직접 호출 테스트만으로는 미봉인 —
# 실 점수 이벤트 경로(match_score_event_controller.handle_score_event)가
# 부활 트리거/사망 시퀀스 시작 프레임에 재생해야 BANG 타임라인(3.20s/1.92s)이
# 실제 들리는 소리와 정렬된다.
func _verify_score_path_plays_change_and_death() -> void:
	var recorder := RecorderAudio.new()
	var owner := FakeScoreOwner.new()
	var registry := FakeScoreRegistry.new()
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"score fixture: 오딘의 눈 장착"
	)
	var controller: Object = MatchScoreEventController.new()
	var deps := {
		"score_state": FakeScoreState.new(),
		"mythic_item_runtime": runtime,
		"audio": recorder,
		"owner": owner,
		"registry": registry,
	}
	controller.handle_score_event("boss", deps, {})
	_expect(recorder.change_calls == 1, "실 점수 경로: 부활 트리거 프레임에 odinchange 1회, got %d" % recorder.change_calls)
	_expect(recorder.death_calls == 0, "부활 트리거에서 odindeath는 재생되지 않음")
	_expect(bool(runtime.is_odins_eye_penalty_active()), "score fixture: 부활 후 페널티 폼 진입")
	# 페널티 폼 정착 후 두 번째 실점 → 사망 시퀀스 + odindeath 원샷.
	runtime.odins_eye_runtime.update_runtime(runtime, 231.0, owner, registry)
	runtime.consume_odins_eye_revival_finalize_ready()
	controller.handle_score_event("boss", deps, {})
	_expect(recorder.death_calls == 1, "실 점수 경로: 사망 시퀀스 시작 프레임에 odindeath 1회, got %d" % recorder.death_calls)
	_expect(recorder.change_calls == 1, "사망 시퀀스에서 odinchange 재재생 없음")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
