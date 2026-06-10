extends SceneTree

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoWeaponController := preload("res://scripts/characters/commando_weapon_controller.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

var _failures: Array[String] = []


class FakeSpecificAudio:
	extends RefCounted

	var calls: Array[String] = []
	var generic_fire_calls: Array[String] = []
	var generic_impact_calls: Array[String] = []

	func play_commando_slingshot_fire() -> void:
		calls.append("slingshot_fire")

	func play_commando_pistol_fire() -> void:
		calls.append("pistol_fire")

	func play_commando_ak47_fire() -> void:
		calls.append("ak47_fire")

	func play_commando_bazooka_fire() -> void:
		calls.append("bazooka_fire")

	func play_commando_net_gun_fire() -> void:
		calls.append("net_gun_fire")

	func play_commando_bowling_trap_install() -> void:
		calls.append("bowling_trap_install")

	func play_commando_suicide_drone_launch() -> void:
		calls.append("suicide_drone_launch")

	func play_commando_bullet_impact() -> void:
		calls.append("bullet_impact")

	func play_commando_slingshot_impact() -> void:
		calls.append("slingshot_impact")

	func play_commando_bazooka_impact() -> void:
		calls.append("bazooka_impact")

	func play_commando_net_gun_capture() -> void:
		calls.append("net_gun_capture")

	func play_commando_net_gun_constrict() -> void:
		calls.append("net_gun_constrict")

	func play_commando_bowling_trap_snap() -> void:
		calls.append("bowling_trap_snap")

	func play_commando_suicide_drone_explosion() -> void:
		calls.append("suicide_drone_explosion")

	func play_commando_fire_support_bomb() -> void:
		calls.append("fire_support_bomb")

	func play_commando_fire_support_radio() -> void:
		calls.append("fire_support_radio")

	func play_commando_weapon_change() -> void:
		calls.append("weapon_change")

	func play_commando_firearm_fire(weapon_id: String) -> void:
		generic_fire_calls.append(weapon_id)

	func play_commando_firearm_impact(weapon_id: String) -> void:
		generic_impact_calls.append(weapon_id)


class FakeGenericAudio:
	extends RefCounted

	var generic_fire_calls: Array[String] = []
	var generic_impact_calls: Array[String] = []

	func play_commando_firearm_fire(weapon_id: String) -> void:
		generic_fire_calls.append(weapon_id)

	func play_commando_firearm_impact(weapon_id: String) -> void:
		generic_impact_calls.append(weapon_id)


class RecordingPlayerFactory:
	extends RefCounted

	var created := {}

	func create(parent: Node, name: String, path: String, volume_db: float) -> AudioStreamPlayer:
		var player := AudioStreamPlayer.new()
		player.name = name
		player.volume_db = volume_db
		player.stream = AudioStreamWAV.new()
		created[name] = {
			"path": path,
			"volume_db": volume_db,
			"player": player,
		}
		if parent != null:
			parent.add_child(player)
		return player


func _init() -> void:
	_verify_specific_fire_and_impact_cues_win()
	_verify_generic_fallback_still_works()
	_verify_fire_support_activation_uses_radio_only()
	_verify_firearm_reset_uses_weapon_change_audio()
	_verify_game_audio_asset_parity()

	if _failures.is_empty():
		print("commando_firearm_audio_routing_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_specific_fire_and_impact_cues_win() -> void:
	var audio := FakeSpecificAudio.new()
	var deps := {"audio": audio}

	CommandoFirearmAudioDispatcher.play_fire_audio("pistol", deps)
	CommandoFirearmAudioDispatcher.play_fire_audio("commando_pistol", deps)
	CommandoFirearmAudioDispatcher.play_fire_audio("ak47", deps)
	CommandoFirearmAudioDispatcher.play_fire_audio("bazooka", deps)
	CommandoFirearmAudioDispatcher.play_fire_audio("net_gun", deps)
	CommandoFirearmAudioDispatcher.play_fire_audio("bowling_trap", deps)
	CommandoFirearmAudioDispatcher.play_fire_audio("suicide_drone", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("pistol", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("commando_pistol", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("bazooka", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("net_gun", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("bowling_trap", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("suicide_drone", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("fire_support", deps)

	_expect(audio.calls == [
		"pistol_fire",
		"pistol_fire",
		"ak47_fire",
		"bazooka_fire",
		"net_gun_fire",
		"bowling_trap_install",
		"suicide_drone_launch",
		"bullet_impact",
		"bullet_impact",
		"bazooka_impact",
		"net_gun_capture",
		"bowling_trap_snap",
		"suicide_drone_explosion",
		"fire_support_bomb",
	], "weapon-specific Commando firearm cues should be preferred")
	_expect(audio.generic_fire_calls.is_empty(), "specific fire cues should not fall through to generic fire")
	_expect(audio.generic_impact_calls.is_empty(), "specific impact cues should not fall through to generic impact")


func _verify_generic_fallback_still_works() -> void:
	var audio := FakeGenericAudio.new()
	var deps := {"audio": audio}

	CommandoFirearmAudioDispatcher.play_fire_audio("experimental_firearm", deps)
	CommandoFirearmAudioDispatcher.play_impact_audio("experimental_firearm", deps)

	_expect(audio.generic_fire_calls == ["experimental_firearm"], "missing specific fire cue should fall back to generic firearm fire")
	_expect(audio.generic_impact_calls == ["experimental_firearm"], "missing specific impact cue should fall back to generic firearm impact")


func _verify_fire_support_activation_uses_radio_only() -> void:
	var skill_config := CommandoSkillConfig.new()
	var skill_state := CommandoSkillState.new()
	var weapon_controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var audio := FakeSpecificAudio.new()
	_expect(bool(skill_config.unlock_and_equip_skill("fire_support")), "fire support should unlock for audio routing smoke")
	weapon_controller.sync_equipped_permanent(skill_config)
	_expect(bool(weapon_controller.set_current_weapon("fire_support")), "fire support should be selectable for audio routing smoke")

	var result: Dictionary = runtime.update_input(
		{"action_pressed": true},
		500.0,
		_fire_config(),
		{
			"audio": audio,
			"commando_weapon_controller": weapon_controller,
			"skill_state": skill_state,
			"skill_config": skill_config,
		}
	)
	_expect(bool(result.get("fired", false)), "fire support activation should still report fired")
	_expect(audio.calls == ["fire_support_radio"], "fire support call frame should use the radio cue only")
	_expect(audio.generic_fire_calls.is_empty(), "fire support should not layer generic firearm fire over the radio cue")


func _verify_firearm_reset_uses_weapon_change_audio() -> void:
	var weapon_controller := CommandoWeaponController.new()
	var runtime := CommandoFirearmRuntime.new()
	var audio := FakeSpecificAudio.new()
	_expect(weapon_controller.unlock_permanent_weapon("net_gun", true), "net gun should unlock for reset audio smoke")
	_expect(weapon_controller.set_current_weapon("net_gun"), "net gun should be selected before reset audio smoke")

	var result: Dictionary = runtime.update_input(
		{"firearm_reset_just_pressed": true},
		500.0,
		_fire_config(),
		{
			"audio": audio,
			"commando_weapon_controller": weapon_controller,
		}
	)
	_expect(bool(result.get("weapon_switched", false)), "firearm reset should report a real weapon switch")
	_expect(audio.calls == ["weapon_change"], "firearm reset should play weapon.wav through the runtime input path")


func _verify_game_audio_asset_parity() -> void:
	var expected_paths := {
		"CommandoWeaponChangeSfx": GameAudio.COMMANDO_WEAPON_CHANGE_SOUND_PATH,
		"CommandoSlingshotFireSfx": GameAudio.COMMANDO_SLINGSHOT_FIRE_SOUND_PATH,
		"CommandoPistolReadySfx": GameAudio.COMMANDO_PISTOL_READY_SOUND_PATH,
		"CommandoPistolFireSfx": GameAudio.COMMANDO_PISTOL_FIRE_SOUND_PATH,
		"CommandoPistolReloadStartSfx": GameAudio.COMMANDO_PISTOL_RELOAD_START_SOUND_PATH,
		"CommandoPistolReloadSfx": GameAudio.COMMANDO_PISTOL_RELOAD_SOUND_PATH,
		"CommandoReloadSfx": GameAudio.COMMANDO_RELOAD_SOUND_PATH,
		"CommandoAk47FireSfx": GameAudio.COMMANDO_AK47_FIRE_SOUND_PATH,
		"CommandoBazookaFireSfx": GameAudio.COMMANDO_BAZOOKA_FIRE_SOUND_PATH,
		"CommandoNetCaptureSfx": GameAudio.COMMANDO_NET_CAPTURE_SOUND_PATH,
		"CommandoNetConstrictSfx": GameAudio.COMMANDO_NET_CONSTRICT_SOUND_PATH,
		"CommandoBowlingTrapInstallSfx": GameAudio.COMMANDO_BOWLING_TRAP_INSTALL_SOUND_PATH,
		"CommandoBowlingTrapSnapSfx": GameAudio.COMMANDO_BOWLING_TRAP_SNAP_SOUND_PATH,
		"CommandoSuicideDroneSfx": GameAudio.COMMANDO_SUICIDE_DRONE_SOUND_PATH,
	}
	var expected_gains := {
		"CommandoWeaponChangeSfx": GameAudio.COMMANDO_WEAPON_CHANGE_GAIN_DB,
		"CommandoSlingshotFireSfx": GameAudio.COMMANDO_SLINGSHOT_FIRE_GAIN_DB,
		"CommandoPistolReadySfx": GameAudio.COMMANDO_PISTOL_READY_GAIN_DB,
		"CommandoPistolFireSfx": GameAudio.COMMANDO_PISTOL_FIRE_GAIN_DB,
		"CommandoPistolReloadStartSfx": GameAudio.COMMANDO_PISTOL_RELOAD_GAIN_DB,
		"CommandoPistolReloadSfx": GameAudio.COMMANDO_PISTOL_RELOAD_GAIN_DB,
		"CommandoReloadSfx": GameAudio.COMMANDO_PISTOL_RELOAD_GAIN_DB,
		"CommandoAk47FireSfx": GameAudio.COMMANDO_AK47_FIRE_GAIN_DB,
		"CommandoBazookaFireSfx": GameAudio.COMMANDO_BAZOOKA_FIRE_GAIN_DB,
		"CommandoNetCaptureSfx": GameAudio.COMMANDO_NET_CAPTURE_GAIN_DB,
		"CommandoNetConstrictSfx": GameAudio.COMMANDO_NET_CONSTRICT_GAIN_DB,
		"CommandoBowlingTrapInstallSfx": GameAudio.COMMANDO_BOWLING_TRAP_GAIN_DB,
		"CommandoBowlingTrapSnapSfx": GameAudio.COMMANDO_BOWLING_TRAP_GAIN_DB,
		"CommandoSuicideDroneSfx": GameAudio.COMMANDO_SUICIDE_DRONE_GAIN_DB,
	}
	for layer_index in range(2, GameAudio.COMMANDO_AK47_FIRE_POOL_SIZE + 1):
		var layer_name := "CommandoAk47FireSfxLayer%d" % layer_index
		expected_paths[layer_name] = GameAudio.COMMANDO_AK47_FIRE_SOUND_PATH
		expected_gains[layer_name] = GameAudio.COMMANDO_AK47_FIRE_GAIN_DB
	for player_name in expected_paths.keys():
		var path: String = str(expected_paths[player_name])
		_expect(FileAccess.file_exists(path), "%s should exist in the Godot audio asset tree" % path)
		_expect(ProjectResourceLoader.load_audio_stream(path) != null, "%s should load as a Godot audio stream" % path)

	var host := Node.new()
	var factory := RecordingPlayerFactory.new()
	var audio: Object = GameAudio.new()
	audio.player_factory = factory
	audio.owner_node = host
	audio._setup_commando_skill_sfx()
	for player_name in expected_paths.keys():
		var created: Dictionary = _as_dict(factory.created.get(player_name, {}))
		_expect(str(created.get("path", "")) == str(expected_paths[player_name]), "%s should be created from the Python reference wav" % player_name)
		_expect(abs(float(created.get("volume_db", 0.0)) - float(expected_gains[player_name])) <= 0.001, "%s should preserve the Python relative gain" % player_name)
	_expect(_as_array(audio.commando_ak47_fire_sfx_layers).size() == GameAudio.COMMANDO_AK47_FIRE_POOL_SIZE - 1, "AK-47 should create extra layered fire players for rapid-fire mixing")

	var source := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(_function_body(source, "func play_commando_ak47_fire() -> void:").find("_play_commando_ak47_fire_layer") >= 0, "AK-47 fire should use the layered rapid-fire mixer")
	_expect(_function_body(source, "func _play_commando_ak47_fire_layer").find("commando_ak47_fire_sfx") >= 0, "AK-47 fire mixer should still use ak47.wav players")
	_expect(_function_body(source, "func play_commando_slingshot_impact() -> void:").find("play_stage2_rockhit") >= 0, "slingshot impact should use the Python metal/rock hit cue")
	_expect(_function_body(source, "func play_commando_bullet_impact() -> void:").find("play_shrapnel_armor_hit") >= 0, "base pistol, Commando pistol, and AK bullet impacts should use the bullet armor hit cue")
	_expect(_function_body(source, "func play_commando_pistol_reload_start() -> void:").find("commando_pistol_reload_start_sfx") >= 0, "pistol reload start should use pistolreloadstart.wav")
	_expect(_function_body(source, "func play_commando_pistol_reload_round() -> void:").find("commando_pistol_reload_sfx") >= 0, "pistol per-round reload should keep using pistolreload.wav")
	_expect(_function_body(source, "func play_commando_reload() -> void:").find("commando_reload_sfx") >= 0, "Emergency Supply reload should use reload.wav")
	_expect(_function_body(source, "func play_commando_bazooka_impact() -> void:").find("play_grenade_explosion") >= 0, "bazooka impact should use the Python grenade explosion cue")
	_expect(_function_body(source, "func play_commando_fire_support_bomb() -> void:").find("play_grenade_explosion") >= 0, "fire-support bombs should use the Python grenade explosion cue")
	_expect(_function_body(source, "func play_commando_net_gun_capture() -> void:").find("commando_net_capture_sfx") >= 0, "net capture should use net.wav")
	_expect(_function_body(source, "func play_commando_net_gun_constrict() -> void:").find("commando_net_constrict_sfx") >= 0, "net constrict should use netcome.wav")
	_expect(_function_body(source, "func play_commando_bowling_trap_snap() -> void:").find("commando_bowling_trap_snap_sfx") >= 0, "bowling trap snap should use ballingtrapgrap.wav")
	_expect(_function_body(source, "func play_commando_suicide_drone_explosion() -> void:").find("stop_commando_suicide_drone_loop") >= 0, "suicide drone explosion should stop the drone loop")
	_expect(_function_body(source, "func play_commando_weapon_change() -> void:").find("commando_weapon_change_sfx") >= 0, "firearm switch/acquire should use weapon.wav")
	var net_field_source := FileAccess.get_file_as_string("res://scripts/characters/commando_firearm_lingering_net_field_state.gd")
	_expect(_function_body(net_field_source, "static func apply_net_constrict_input(").find("play_commando_net_gun_constrict") >= 0, "net constrict input should call the original netcome.wav cue")
	host.free()


func _fire_config() -> Dictionary:
	return {
		"player_pos": Vector2(302.0, 654.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(328.0, 62.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"width": 760.0,
		"height": 750.0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate()
	return []


func _function_body(source: String, marker: String) -> String:
	var start := source.find(marker)
	if start < 0:
		return ""
	var end := source.find("\n\nfunc ", start + marker.length())
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)
