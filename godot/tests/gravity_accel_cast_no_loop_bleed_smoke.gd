extends SceneTree

# Regression seal for the Serabi 중력가속 (Gravity Accel) cast cue looping forever
# and bleeding into the next round.
#
# Root cause: gravityaccel.wav backs BOTH chaos_spear_blackhole_sfx (a skill that
# legitimately loops) AND lingpet_gravity_accel_cast_sfx (a one-shot cast cue).
# ProjectResourceLoader.load_audio_stream caches by path and the player factory
# assigns that cached AudioStream RAW, so both players shared one AudioStreamWAV
# instance. _enable_loop(chaos_spear_blackhole_sfx) then flipped loop_mode on that
# shared instance at boot, so the gravity-accel one-shot played a LOOPING stream
# that nothing ever stopped.
#
# The fix duplicates the stream inside _enable_loop before flipping loop_mode, so
# only the blackhole player loops and the gravity-accel cast keeps the untouched
# one-shot cache instance.
#
# Reverse-verified: with the pre-fix _enable_loop (mutating player.stream in place)
# _verify_gravity_accel_cast_stream_is_not_looping FAILS
# (loop_mode == LOOP_FORWARD, bled from the blackhole) and
# _verify_cast_stream_is_not_shared_with_blackhole FAILS (same cached instance).

const GameAudio := preload("res://scripts/audio/game_audio.gd")

var _failures: Array[String] = []


func _init() -> void:
	var parent := Node.new()
	parent.name = "GameAudioSmokeHost"
	get_root().add_child(parent)

	var audio: Object = GameAudio.new()
	# Drive the step-based setup until BOTH players exist. The blackhole player is
	# created + looped in step 1; the gravity-accel cast cue in step 4. Bounded so a
	# stalled prewarm can never hang the smoke.
	var guard := 0
	while (
		(audio.lingpet_gravity_accel_cast_sfx == null or audio.chaos_spear_blackhole_sfx == null)
		and guard < 20000
	):
		audio.setup_step(parent)
		guard += 1

	_verify_players_created(audio)
	_verify_cast_stream_is_not_shared_with_blackhole(audio)
	_verify_gravity_accel_cast_stream_is_not_looping(audio)
	_verify_blackhole_stream_still_loops(audio)

	parent.queue_free()

	if _failures.is_empty():
		print("gravity_accel_cast_no_loop_bleed_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_players_created(audio: Object) -> void:
	_expect(audio.chaos_spear_blackhole_sfx != null, "chaos_spear_blackhole_sfx should be created during audio setup")
	_expect(audio.lingpet_gravity_accel_cast_sfx != null, "lingpet_gravity_accel_cast_sfx should be created during audio setup")
	if audio.chaos_spear_blackhole_sfx != null:
		_expect(audio.chaos_spear_blackhole_sfx.stream is AudioStreamWAV, "blackhole cue should load a WAV stream")
	if audio.lingpet_gravity_accel_cast_sfx != null:
		_expect(audio.lingpet_gravity_accel_cast_sfx.stream is AudioStreamWAV, "gravity-accel cast cue should load a WAV stream")


func _verify_cast_stream_is_not_shared_with_blackhole(audio: Object) -> void:
	# Both players load the SAME file (gravityaccel.wav). After the fix, the looping
	# blackhole player gets its own duplicated stream, so the two players must NOT
	# share one AudioStream instance -- otherwise a loop-mode flip on one bleeds onto
	# the other.
	if audio.chaos_spear_blackhole_sfx == null or audio.lingpet_gravity_accel_cast_sfx == null:
		return
	_expect(
		audio.lingpet_gravity_accel_cast_sfx.stream != audio.chaos_spear_blackhole_sfx.stream,
		"gravity-accel cast and blackhole must NOT share one AudioStream instance (shared cache resource loop bleed)"
	)


func _verify_gravity_accel_cast_stream_is_not_looping(audio: Object) -> void:
	# The decisive assertion: the one-shot cast cue must not loop.
	if audio.lingpet_gravity_accel_cast_sfx == null:
		return
	var stream: Variant = audio.lingpet_gravity_accel_cast_sfx.stream
	if stream is AudioStreamWAV:
		_expect(
			(stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"gravity-accel cast cue stream must NOT loop (loop_mode should stay LOOP_DISABLED, not bleed LOOP_FORWARD from the blackhole)"
		)


func _verify_blackhole_stream_still_loops(audio: Object) -> void:
	# Regression guard: the fix must not break Chaos Spear's legitimately-looping
	# blackhole cue.
	if audio.chaos_spear_blackhole_sfx == null:
		return
	var stream: Variant = audio.chaos_spear_blackhole_sfx.stream
	if stream is AudioStreamWAV:
		_expect(
			(stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"chaos-spear blackhole cue should still loop (LOOP_FORWARD) after the fix"
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
