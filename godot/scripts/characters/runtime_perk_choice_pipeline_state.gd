extends RefCounted

const RuntimePerkChoiceSelection := preload("res://scripts/characters/runtime_perk_choice_selection.gd")
const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")
const RuntimePerkChoiceDispatch := preload("res://scripts/characters/runtime_perk_choice_dispatch.gd")
const RuntimePerkChoiceActionRunner := preload("res://scripts/characters/runtime_perk_choice_action_runner.gd")
const RuntimePerkChoiceStandardPath := preload("res://scripts/characters/runtime_perk_choice_standard_path.gd")
const RuntimePerkChoiceOpenFlow := preload("res://scripts/characters/runtime_perk_choice_open_flow.gd")
const RuntimePerkChoiceApplyFlow := preload("res://scripts/characters/runtime_perk_choice_apply_flow.gd")
const RuntimePerkChoiceConfirmFlow := preload("res://scripts/characters/runtime_perk_choice_confirm_flow.gd")
const RuntimePerkChoiceFinishFlow := preload("res://scripts/characters/runtime_perk_choice_finish_flow.gd")

var _selection: Object = RuntimePerkChoiceSelection.new()
var _completion: Object = RuntimePerkChoiceCompletion.new()
var _dispatch: Object = RuntimePerkChoiceDispatch.new()
var _action_runner: Object = RuntimePerkChoiceActionRunner.new()
var _standard_path: Object = RuntimePerkChoiceStandardPath.new()
var _open_flow: Object = RuntimePerkChoiceOpenFlow.new()
var _apply_flow: Object = RuntimePerkChoiceApplyFlow.new()
var _confirm_flow: Object = RuntimePerkChoiceConfirmFlow.new()
var _finish_flow: Object = RuntimePerkChoiceFinishFlow.new()


func get_selection() -> Object:
	return _selection


func set_selection(value: Object) -> void:
	_selection = value


func get_completion() -> Object:
	return _completion


func set_completion(value: Object) -> void:
	_completion = value


func get_dispatch() -> Object:
	return _dispatch


func set_dispatch(value: Object) -> void:
	_dispatch = value


func get_action_runner() -> Object:
	return _action_runner


func set_action_runner(value: Object) -> void:
	_action_runner = value


func get_standard_path() -> Object:
	return _standard_path


func set_standard_path(value: Object) -> void:
	_standard_path = value


func get_open_flow() -> Object:
	return _open_flow


func set_open_flow(value: Object) -> void:
	_open_flow = value


func get_apply_flow() -> Object:
	return _apply_flow


func set_apply_flow(value: Object) -> void:
	_apply_flow = value


func get_confirm_flow() -> Object:
	return _confirm_flow


func set_confirm_flow(value: Object) -> void:
	_confirm_flow = value


func get_finish_flow() -> Object:
	return _finish_flow


func set_finish_flow(value: Object) -> void:
	_finish_flow = value
