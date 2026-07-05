extends RefCounted

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const StageClearResultStarpointChoiceOpenData := preload("res://scripts/core/stage_clear_result_starpoint_choice_open_data.gd")
const StageClearResultStarpointChoiceState := preload("res://scripts/core/stage_clear_result_starpoint_choice_state.gd")

var _perk_catalog: Object = RuntimePerkCatalog.new()
var _choice_state: Object = StageClearResultStarpointChoiceState.new()


func reset(scene: Control = null) -> void:
	_choice_state.reset(scene)


func get_status() -> Dictionary:
	return _choice_state.get_status()


func can_defer_choice(runtime_perk_state: Object, runtime_perk_catalog: Object) -> bool:
	return StageClearResultStarpointChoiceOpenData.can_defer_choice(runtime_perk_state, runtime_perk_catalog)


func schedule_deferred_choice(scene: Control, box_index: int, delay: float) -> void:
	_choice_state.schedule_deferred_choice(scene, box_index, delay)


func update_pending_choice(
	delta: float,
	scene: Control,
	runtime_perk_state: Object,
	runtime_perk_catalog: Object,
	selected_character_type: String,
	owner: Object,
	registry: Object,
	game_audio: Object
) -> void:
	var pending_result: Dictionary = _choice_state.consume_pending_choice_if_ready(
		delta,
		scene,
		runtime_perk_state
	)
	if not bool(pending_result.get("ready", false)):
		return
	_open_deferred_starpoint_choice(
		scene,
		runtime_perk_state,
		runtime_perk_catalog,
		selected_character_type,
		owner,
		registry,
		game_audio,
		int(pending_result.get("box_index", -1))
	)


func update_runtime_choice(
	delta: float,
	scene: Control,
	runtime_perk_state: Object,
	owner: Object,
	registry: Object
) -> void:
	if runtime_perk_state == null or not runtime_perk_state.has_method("update"):
		return
	var view_size := Vector2.ZERO
	if scene != null and is_instance_valid(scene):
		view_size = scene.get_viewport_rect().size
	runtime_perk_state.update(delta, view_size, owner, registry)
	sync_box_perk_choice_rewards(scene, runtime_perk_state)


func sync_box_perk_choice_rewards(scene: Control, runtime_perk_state: Object) -> void:
	_choice_state.sync_box_perk_choice_rewards(scene, runtime_perk_state, _perk_catalog)


func clear_pending_choice(scene: Control = null) -> void:
	_choice_state.clear_pending_choice(scene)


func clear_active_choice_tracking() -> void:
	_choice_state.clear_active_choice_tracking()


func is_runtime_perk_choice_active(runtime_perk_state: Object) -> bool:
	return StageClearResultStarpointChoiceOpenData.is_runtime_perk_choice_active(runtime_perk_state)


func _open_deferred_starpoint_choice(
	scene: Control,
	runtime_perk_state: Object,
	runtime_perk_catalog: Object,
	selected_character_type: String,
	owner: Object,
	registry: Object,
	game_audio: Object,
	box_index: int
) -> void:
	var result: Dictionary = StageClearResultStarpointChoiceOpenData.open_deferred_starpoint_choice(
		runtime_perk_state,
		runtime_perk_catalog,
		selected_character_type,
		owner,
		registry,
		game_audio
	)
	_choice_state.record_open_result(scene, box_index, result)
