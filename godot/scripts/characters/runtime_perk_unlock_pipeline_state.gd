extends RefCounted

const RuntimePerkActiveUnlockFlight := preload("res://scripts/characters/runtime_perk_active_unlock_flight.gd")
const RuntimePerkUnlockShowcase := preload("res://scripts/characters/runtime_perk_unlock_showcase.gd")
const RuntimePerkUnlockShowcaseFlow := preload("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")
const RuntimePerkUnlockSwapLayout := preload("res://scripts/characters/runtime_perk_unlock_swap_layout.gd")
const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const RuntimePerkUnlockChoiceApply := preload("res://scripts/characters/runtime_perk_unlock_choice_apply.gd")

var _active_unlock_flight: Object = RuntimePerkActiveUnlockFlight.new()
var _unlock_showcase_controller: Object = RuntimePerkUnlockShowcase.new()
var _unlock_showcase_flow: Object = RuntimePerkUnlockShowcaseFlow.new()
var _unlock_swap_layout: Object = RuntimePerkUnlockSwapLayout.new()
var _unlock_swap_flow: Object = RuntimePerkUnlockSwapFlow.new()
var _unlock_choice_apply: Object = RuntimePerkUnlockChoiceApply.new()


func get_active_unlock_flight() -> Object:
	return _active_unlock_flight


func set_active_unlock_flight(value: Object) -> void:
	_active_unlock_flight = value


func get_unlock_showcase_controller() -> Object:
	return _unlock_showcase_controller


func set_unlock_showcase_controller(value: Object) -> void:
	_unlock_showcase_controller = value


func get_unlock_showcase_flow() -> Object:
	return _unlock_showcase_flow


func set_unlock_showcase_flow(value: Object) -> void:
	_unlock_showcase_flow = value


func get_unlock_swap_layout() -> Object:
	return _unlock_swap_layout


func set_unlock_swap_layout(value: Object) -> void:
	_unlock_swap_layout = value


func get_unlock_swap_flow() -> Object:
	return _unlock_swap_flow


func set_unlock_swap_flow(value: Object) -> void:
	_unlock_swap_flow = value


func get_unlock_choice_apply() -> Object:
	return _unlock_choice_apply


func set_unlock_choice_apply(value: Object) -> void:
	_unlock_choice_apply = value
