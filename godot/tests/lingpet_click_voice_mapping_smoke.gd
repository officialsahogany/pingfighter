extends SceneTree

# Seals GameAudio.play_lingpet_click_reaction() per-pet routing.
#
# Every wired pet id must dispatch to ITS OWN click-voice player, and that
# player's stream must actually load from disk (import present). An unwired pet
# id must stay silent (no player played) so the mapping never degrades into a
# catch-all. This guards against: a path-const typo, a missing / unimported
# asset, a mapping branch calling the wrong _ensure_* method, and a dropped
# branch that silently falls through to no sound.

const GameAudio := preload("res://scripts/audio/game_audio.gd")

# pet_id -> expected member field holding that pet's click-voice player.
const WIRED_PETS := {
	"lunabi": "lingpet_lunabi_click_voice_sfx",
	"volty": "lingpet_volty_click_voice_sfx",
	"milkring": "lingpet_milkring_click_voice_sfx",
	"red_dragon": "lingpet_red_dragon_click_voice_sfx",
	"maribo": "lingpet_maribo_click_voice_sfx",
	"rabi": "lingpet_rabi_click_voice_sfx",
	"lumion": "lingpet_lumion_click_voice_sfx",
	"monkeyring": "lingpet_monkeyring_click_voice_sfx",
	"onimaru": "lingpet_onimaru_click_voice_sfx",
	"orosha": "lingpet_orosha_click_voice_sfx",
	"koyora": "lingpet_koyora_click_voice_sfx",
}

var _failures: Array[String] = []


# Spy that records which player a click-reaction dispatch would have played,
# without touching the audio hardware.
class SpyAudio:
	extends GameAudio

	var last_player: AudioStreamPlayer = null

	func _play_with_pitch(player: AudioStreamPlayer, _pitch: float) -> bool:
		last_player = player
		return player != null


func _init() -> void:
	var host := Node.new()
	get_root().add_child(host)

	var spy := SpyAudio.new()
	spy.owner_node = host

	# Each wired pet routes to its own player, and that player loads a stream.
	for pet_id in WIRED_PETS:
		var field: String = WIRED_PETS[pet_id]
		spy.last_player = null
		spy.play_lingpet_click_reaction(pet_id)
		var routed: AudioStreamPlayer = spy.last_player
		_expect(routed != null, "pet '%s' should route to a click-voice player, got null (branch missing?)" % pet_id)
		if routed == null:
			continue
		var expected: AudioStreamPlayer = spy.get(field)
		_expect(routed == expected,
			"pet '%s' routed to the wrong player (expected member %s)" % [pet_id, field])
		_expect(routed.stream != null and routed.stream is AudioStream,
			"pet '%s' click voice asset failed to load (import missing / bad path)" % pet_id)

	# Case-insensitive + trimmed ids must still route (call site passes raw ids).
	spy.last_player = null
	spy.play_lingpet_click_reaction("  Maribo ")
	_expect(spy.last_player == spy.lingpet_maribo_click_voice_sfx,
		"normalized pet id ('  Maribo ') should route to maribo click voice")

	# Reverse verification: an id with no dedicated voice stays silent.
	spy.last_player = null
	spy.play_lingpet_click_reaction("nekuring")
	_expect(spy.last_player == null,
		"unwired pet 'nekuring' should stay silent, not route to a player")

	spy.last_player = null
	spy.play_lingpet_click_reaction("")
	_expect(spy.last_player == null, "empty pet id should stay silent")

	host.queue_free()

	if _failures.is_empty():
		print("lingpet_click_voice_mapping_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
