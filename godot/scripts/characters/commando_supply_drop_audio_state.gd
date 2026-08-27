extends RefCounted

const CommandoFirearmAudioDispatcher := preload("res://scripts/characters/commando_firearm_audio_dispatcher.gd")

var _aircraft_loop_active := false


func reset() -> void:
	_aircraft_loop_active = false


func get_snapshot() -> Dictionary:
	return {"aircraft_audio_active": _aircraft_loop_active}


func restore(snapshot: Dictionary, deps: Dictionary = {}) -> void:
	stop_aircraft_loop(deps)
	if bool(snapshot.get("aircraft_audio_active", false)):
		start_aircraft_loop(deps)


func is_aircraft_loop_active() -> bool:
	return _aircraft_loop_active


func start_aircraft_loop(deps: Dictionary) -> void:
	if _aircraft_loop_active:
		return
	_aircraft_loop_active = true
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["play_commando_supply_aircraft_loop"]
	)


func stop_aircraft_loop(deps: Dictionary) -> void:
	if not _aircraft_loop_active:
		return
	_aircraft_loop_active = false
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["stop_commando_supply_aircraft_loop"]
	)


func play_hold_radio(deps: Dictionary) -> void:
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["play_commando_supply_radio_loop", "play_commando_supply_radio"]
	)


func stop_hold_radio(deps: Dictionary) -> void:
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["stop_commando_supply_radio_loop"]
	)


func play_activation_radio(deps: Dictionary) -> void:
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["play_commando_supply_radio"]
	)


func play_drop(deps: Dictionary) -> void:
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["play_commando_supply_drop"]
	)


func play_crash(deps: Dictionary) -> void:
	CommandoFirearmAudioDispatcher.play_first_audio_method(
		deps,
		["play_grenade_explosion", "play_commando_supply_drop"]
	)
