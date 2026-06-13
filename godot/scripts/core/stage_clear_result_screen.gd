extends RefCounted

const StageClearRewardResolver := preload("res://scripts/core/stage_clear_reward_resolver.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")
const PlazaScene := preload("res://scripts/plaza/plaza_scene.gd")
const PlazaSaveStore := preload("res://scripts/plaza/plaza_save_store.gd")
const StageClearResultRewardPlanBuilder := preload("res://scripts/core/stage_clear_result_reward_plan_builder.gd")
const StageClearResultStageSnapshotBuilder := preload("res://scripts/core/stage_clear_result_stage_snapshot_builder.gd")

const RESULT_SCENE_PATH := "res://scenes/stage_clear_result.tscn"
const PLAZA_SCENE_PATH := "res://scenes/plaza.tscn"
const STARPOINT_CHOICE_REWARD_DELAY := 0.65

var active: bool = false
var player_score: int = 0
var boss_score: int = 0
var current_stage: int = 1
var _pending_reset_callback: Callable = Callable()
var _pending_exit_callback: Callable = Callable()
var _pending_owner: Object
var _pending_registry: Object
var _scene_node: Control
var _spawn_pending: bool = false
var _reward_resolver: Object = StageClearRewardResolver.new()
var _perk_catalog: Object = RuntimePerkCatalog.new()
var _reward_plan_builder: Object = StageClearResultRewardPlanBuilder.new()
var _stage_snapshot_builder: Object = StageClearResultStageSnapshotBuilder.new()
var _rewards_granted: bool = false
var _last_grant_summary: Dictionary = {}
var _immediate_reward_summaries: Array = []
var _stage_start_snapshot: Dictionary = {}
var _last_stage_reward_snapshot: Dictionary = {}
var _pending_starpoint_choice_delay: float = 0.0
var _pending_starpoint_choice_box_index: int = -1
var _active_starpoint_choice_box_index: int = -1
var _last_recorded_perk_choice_sequence: int = 0
var _result_scene_packed: PackedScene
var _plaza_node: Control
var _plaza_scene_packed: PackedScene
var _plaza_prewarm_complete: bool = false
var _plaza_prewarm_stage: int = -1
var _plaza_save_store: Object = PlazaSaveStore.new()
var _stage_clear_gold_transfer_consumed: bool = false
var _stage_clear_ap_grant_consumed: bool = false
var _last_plaza_progress_summary: Dictionary = {}
var _prewarm_assets_step_index: int = 0
var _prewarm_assets_status: Dictionary = {}


func show_from_scoreboard(
	owner: Object,
	registry: Object,
	reset_game_callback: Callable,
	exit_to_menu_callback: Callable = Callable()
) -> bool:
	var snapshot: Dictionary = _get_score_snapshot(registry)
	player_score = int(snapshot.get("player_score", 0))
	boss_score = int(snapshot.get("boss_score", 0))
	if player_score <= boss_score:
		return false

	current_stage = _get_current_stage(owner)
	_reset_stage5_for_result(registry, current_stage)
	_pending_reset_callback = reset_game_callback
	_pending_exit_callback = exit_to_menu_callback
	_pending_owner = owner
	_pending_registry = registry
	_last_stage_reward_snapshot = _stage_snapshot_builder.build_stage_reward_snapshot(
		owner,
		registry,
		current_stage,
		_stage_start_snapshot
	)
	_rewards_granted = false
	_last_grant_summary = {}
	_immediate_reward_summaries.clear()
	_stage_clear_gold_transfer_consumed = false
	_stage_clear_ap_grant_consumed = false
	_last_plaza_progress_summary = {}
	_clear_pending_starpoint_choice()
	_clear_active_starpoint_choice_tracking()
	active = true
	_spawn_pending = true
	if _are_scene_assets_ready_for_spawn():
		_spawn_pending = false
		if not _spawn_result_scene(owner):
			reset()
			return false
	elif owner != null and owner.has_method("queue_redraw"):
		owner.queue_redraw()
	return true


func is_active() -> bool:
	return active


func is_scene_ready() -> bool:
	return _has_result_scene()


func reset() -> void:
	active = false
	player_score = 0
	boss_score = 0
	current_stage = 1
	_pending_reset_callback = Callable()
	_pending_exit_callback = Callable()
	_pending_owner = null
	_pending_registry = null
	_spawn_pending = false
	_rewards_granted = false
	_last_grant_summary = {}
	_immediate_reward_summaries.clear()
	_last_stage_reward_snapshot = {}
	_stage_clear_gold_transfer_consumed = false
	_stage_clear_ap_grant_consumed = false
	_last_plaza_progress_summary = {}
	_clear_pending_starpoint_choice()
	_clear_active_starpoint_choice_tracking()
	if _scene_node != null and is_instance_valid(_scene_node):
		_scene_node.queue_free()
	_scene_node = null
	_free_plaza_scene()
	_plaza_prewarm_complete = false
	_plaza_prewarm_stage = -1


func update(delta: float) -> void:
	if not is_active():
		return
	if _has_plaza_scene():
		if _plaza_node.has_method("update_plaza"):
			_plaza_node.update_plaza(delta)
		return
	if _spawn_pending:
		_update_pending_scene_spawn()
		if _spawn_pending or not _has_result_scene():
			return
	if not _has_result_scene():
		return
	_sync_result_scene_visibility()
	if _scene_node.has_method("update_result_scene"):
		_scene_node.update_result_scene(delta)
	_prewarm_plaza_assets_step()
	_update_mythic_acquisition_cinematic(delta)
	_update_runtime_perk_choice(delta)
	_update_pending_starpoint_choice(delta)


func handle_input(event: InputEvent, _owner: Object, _registry: Object, _view_size: Vector2) -> bool:
	if not is_active():
		return false
	if _has_plaza_scene():
		if _plaza_node.has_method("handle_plaza_input"):
			_plaza_node.handle_plaza_input(event)
		return true
	if _spawn_pending or not _has_result_scene():
		return true
	if _handle_mythic_acquisition_input(event):
		return true
	if _scene_node.has_method("handle_result_input"):
		_scene_node.handle_result_input(event)
		_sync_box_perk_choice_rewards()
	return true


func draw(canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
	if not active or _has_result_scene() or _has_plaza_scene() or canvas == null:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.015, 0.018, 0.028, 0.94))


func get_reward_plan() -> Dictionary:
	return _reward_plan_builder.build_reward_plan(player_score, boss_score)


func get_status() -> Dictionary:
	return {
		"active": is_active(),
		"player_score": player_score,
		"boss_score": boss_score,
		"current_stage": current_stage,
		"reward_plan": get_reward_plan(),
		"scene_path": RESULT_SCENE_PATH,
		"scene_ready": _has_result_scene(),
		"plaza_scene_path": PLAZA_SCENE_PATH,
		"plaza_active": _has_plaza_scene(),
		"plaza_scene_ready": _has_plaza_scene(),
		"plaza_prewarm_complete": _plaza_prewarm_complete,
		"plaza_prewarm_stage": _plaza_prewarm_stage,
		"plaza_status": _plaza_node.get_status() if _has_plaza_scene() and _plaza_node.has_method("get_status") else {},
		"spawn_pending": _spawn_pending,
		"rewards_granted": _rewards_granted,
		"last_grant_summary": _last_grant_summary.duplicate(true),
		"last_plaza_progress_summary": _last_plaza_progress_summary.duplicate(true),
		"immediate_reward_summaries": _immediate_reward_summaries.duplicate(true),
		"stage_start_snapshot": _stage_start_snapshot.duplicate(true),
		"stage_reward_snapshot": _last_stage_reward_snapshot.duplicate(true),
		"pending_starpoint_choice_delay": _pending_starpoint_choice_delay,
		"pending_starpoint_choice_box_index": _pending_starpoint_choice_box_index,
	}


func prepare_stage_start(owner: Object, registry: Object, stage_id: int = -1) -> void:
	var next_stage: int = stage_id
	if next_stage <= 0:
		next_stage = _get_current_stage(owner)
	_stage_start_snapshot = _stage_snapshot_builder.build_progress_snapshot(owner, registry, next_stage)


func set_plaza_save_path_for_test(path: String) -> void:
	if _plaza_save_store != null and _plaza_save_store.has_method("set_save_path"):
		_plaza_save_store.set_save_path(path)


func get_plaza_save_summary() -> Dictionary:
	if _plaza_save_store == null or not _plaza_save_store.has_method("get_summary"):
		return {}
	return _plaza_save_store.get_summary()


func prewarm_assets(_owner: Object = null, _registry: Object = null) -> Dictionary:
	while not prewarm_assets_step(_owner, _registry):
		pass
	return _prewarm_assets_status.duplicate()


func prewarm_scene_shell() -> bool:
	_prewarm_assets_status["result_scene_packed"] = _get_result_scene_packed() != null
	return bool(_prewarm_assets_status["result_scene_packed"])


func prewarm_assets_step(_owner: Object = null, _registry: Object = null) -> bool:
	return _prewarm_assets_step_impl(false, _owner)


func prewarm_assets_threaded_step(_owner: Object = null, _registry: Object = null) -> bool:
	return _prewarm_assets_step_impl(true, _owner)


func _prewarm_assets_step_impl(use_threaded_texture_loads: bool, owner: Object = null) -> bool:
	var prewarm_owner: Object = owner if owner != null else _pending_owner
	var selected_character_type: String = _get_result_victory_character_type(prewarm_owner)
	var stage_id: int = _get_current_stage(prewarm_owner) if prewarm_owner != null else current_stage
	if (
		str(_prewarm_assets_status.get("selected_character_type", "")) != selected_character_type
		or int(_prewarm_assets_status.get("current_stage", stage_id)) != stage_id
	):
		_prewarm_assets_step_index = 0
		_prewarm_assets_status.clear()
	if _prewarm_assets_step_index == 0:
		_prewarm_assets_status["selected_character_type"] = selected_character_type
		_prewarm_assets_status["current_stage"] = stage_id
		_prewarm_assets_status["result_scene_packed"] = _get_result_scene_packed() != null
		_prewarm_assets_step_index = 1
		return false

	var scene_step_done := false
	if use_threaded_texture_loads:
		scene_step_done = bool(StageClearResultScene.prewarm_assets_threaded_step(selected_character_type, stage_id))
	else:
		scene_step_done = bool(StageClearResultScene.prewarm_assets_step(selected_character_type, stage_id))
	if not scene_step_done:
		return false
	var scene_status: Dictionary = StageClearResultScene.get_prewarm_asset_status()
	for key in scene_status.keys():
		_prewarm_assets_status[key] = scene_status[key]
	_prewarm_assets_step_index = 0
	return true


func _spawn_result_scene(owner: Object) -> bool:
	if not (owner is Node):
		return false
	if _scene_node != null and is_instance_valid(_scene_node):
		_scene_node.queue_free()
		_scene_node = null

	var packed: PackedScene = _get_result_scene_packed()
	if packed == null:
		push_warning("Missing stage clear result scene at %s" % RESULT_SCENE_PATH)
		return false

	var instance: Node = packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		push_warning("Stage clear result scene root must be Control: %s" % RESULT_SCENE_PATH)
		return false

	_scene_node = instance as Control
	_scene_node.name = "StageClearResultScene"
	_scene_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_scene_node.z_index = 1200
	_scene_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _scene_node.has_method("configure"):
		_scene_node.configure({
			"player_score": player_score,
			"boss_score": boss_score,
			"current_stage": current_stage,
			"selected_character_type": _get_result_victory_character_type(_pending_owner),
			"reward_plan": get_reward_plan(),
			"stage_reward_snapshot": _last_stage_reward_snapshot.duplicate(true),
			"runtime_perk_state": _get_instance(_pending_registry, "runtime_perk_state"),
			"runtime_perk_catalog": _get_instance(_pending_registry, "runtime_perk_catalog"),
			"runtime_perk_icon_renderer": _get_instance(_pending_registry, "runtime_perk_icon_renderer"),
			"runtime_perk_owner": _pending_owner,
			"runtime_perk_registry": _pending_registry,
			"mythic_item_runtime": _get_instance(_pending_registry, "mythic_item_runtime"),
			"treasure_hunt_runtime": _get_instance(_pending_registry, "treasure_hunt_runtime"),
			"game_audio": _get_instance(_pending_registry, "game_audio"),
		},
		Callable(self, "_finish_next_stage"),
		Callable(self, "_finish_exit_to_menu"),
		Callable(self, "_roll_box_reward"),
		Callable(self, "_grant_immediate_box_reward"),
		Callable(self, "_finish_enter_plaza")
		)
	(owner as Node).add_child(_scene_node)
	return true


func _update_pending_scene_spawn() -> void:
	if not _spawn_pending:
		return
	if not prewarm_assets_step(_pending_owner, _pending_registry):
		if _pending_owner != null and _pending_owner.has_method("queue_redraw"):
			_pending_owner.queue_redraw()
		return
	_spawn_pending = false
	if not _spawn_result_scene(_pending_owner):
		reset()
		return
	if _pending_owner != null and _pending_owner.has_method("queue_redraw"):
		_pending_owner.queue_redraw()


func _has_result_scene() -> bool:
	return _scene_node != null and is_instance_valid(_scene_node)


func _has_plaza_scene() -> bool:
	return _plaza_node != null and is_instance_valid(_plaza_node)


func _are_scene_assets_ready_for_spawn() -> bool:
	var scene_status: Dictionary = StageClearResultScene.get_prewarm_asset_status()
	if str(scene_status.get("selected_character_type", "")) != _get_result_victory_character_type(_pending_owner):
		return false
	if int(scene_status.get("current_stage", 0)) != current_stage:
		return false
	for key in _get_required_scene_asset_keys(current_stage):
		if not bool(scene_status.get(key, false)):
			return false
	return true


func _get_required_scene_asset_keys(stage_id: int) -> Array[String]:
	var keys: Array[String] = [
		"background_texture",
		"player_victory_sheet",
		"player_victory_click_reaction_sheet",
		"scroll_texture",
		"result_box_sheet_common",
		"result_box_sheet_mythic",
		"result_box_sheet_guaranteed_mythic",
		"result_box_fx",
	]
	if stage_id == 2:
		keys.append("stage2_boss_defeat_live2d_sheet")
		keys.append("stage2_boss_defeat_click_reaction_sheet")
	else:
		keys.append("dalji_defeat_sheet")
		keys.append("dalji_click_reaction_sheet")
		keys.append("dalji_click_voice")
	return keys


func _get_result_scene_packed() -> PackedScene:
	if _result_scene_packed != null:
		return _result_scene_packed
	_result_scene_packed = load(RESULT_SCENE_PATH) as PackedScene
	return _result_scene_packed


func _get_plaza_scene_packed() -> PackedScene:
	if _plaza_scene_packed != null:
		return _plaza_scene_packed
	_plaza_scene_packed = load(PLAZA_SCENE_PATH) as PackedScene
	return _plaza_scene_packed


func _prewarm_plaza_assets_step() -> bool:
	if _plaza_prewarm_complete and _plaza_prewarm_stage == current_stage:
		return true
	_plaza_prewarm_stage = current_stage
	_plaza_prewarm_complete = bool(PlazaScene.prewarm_assets_threaded_step(current_stage))
	return _plaza_prewarm_complete


func _ensure_plaza_assets_ready() -> bool:
	if _plaza_prewarm_complete and _plaza_prewarm_stage == current_stage:
		return true
	_plaza_prewarm_stage = current_stage
	var guard := 0
	while not bool(PlazaScene.prewarm_assets_blocking_step(current_stage)):
		guard += 1
		if guard > 256:
			push_warning("Timed out while prewarming plaza assets for stage %d" % current_stage)
			return false
	_plaza_prewarm_complete = true
	return true


func _roll_box_reward(box_kind: String) -> Dictionary:
	if _reward_resolver == null or not _reward_resolver.has_method("roll_reward"):
		return {}
	return _reward_resolver.roll_reward(box_kind, _pending_owner, _pending_registry)


func _sync_result_scene_visibility() -> void:
	if _scene_node == null or not is_instance_valid(_scene_node):
		return
	_scene_node.visible = true


func _is_runtime_perk_choice_active() -> bool:
	var runtime_perk_state: Object = _get_instance(_pending_registry, "runtime_perk_state")
	return runtime_perk_state != null and runtime_perk_state.has_method("is_choice_active") and bool(runtime_perk_state.is_choice_active())


func _grant_pending_rewards() -> Dictionary:
	if _rewards_granted:
		return _last_grant_summary.duplicate(true)
	_rewards_granted = true
	var resolved_rewards: Array = []
	if _scene_node != null and is_instance_valid(_scene_node) and _scene_node.has_method("get_resolved_rewards"):
		var rewards_value: Variant = _scene_node.get_resolved_rewards()
		if rewards_value is Array:
			resolved_rewards = rewards_value
	var pending_rewards: Array = []
	for reward_value in resolved_rewards:
		if not (reward_value is Dictionary):
			continue
		var reward: Dictionary = reward_value
		if bool(reward.get("immediate_granted", false)):
			continue
		pending_rewards.append(reward.duplicate(true))
	if pending_rewards.is_empty():
		if _last_grant_summary.is_empty():
			_last_grant_summary = _empty_grant_summary(0)
		return _last_grant_summary.duplicate(true)
	if _reward_resolver != null and _reward_resolver.has_method("grant_rewards"):
		_merge_grant_summary(_reward_resolver.grant_rewards(
			pending_rewards,
			_pending_owner,
			_pending_registry
		))
	else:
		_merge_grant_summary({
			"attempted": pending_rewards.size(),
			"granted": 0,
			"failed": pending_rewards.duplicate(true),
		})
	return _last_grant_summary.duplicate(true)


func _grant_immediate_box_reward(reward: Dictionary, _box_index: int) -> bool:
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == StageClearRewardResolver.REWARD_MYTHIC:
		return _grant_immediate_mythic_box_reward(reward)
	if reward_type != StageClearRewardResolver.REWARD_STARPOINT:
		return false
	if _reward_resolver == null or not _reward_resolver.has_method("grant_rewards"):
		return false
	var reward_copy: Dictionary = reward.duplicate(true)
	var defer_choice: bool = _can_defer_starpoint_choice()
	if defer_choice:
		reward_copy["defer_choice_open"] = true
	var summary_value: Variant = _reward_resolver.grant_rewards(
		[reward_copy],
		_pending_owner,
		_pending_registry
	)
	if not (summary_value is Dictionary):
		return false
	var summary: Dictionary = summary_value
	if int(summary.get("granted", 0)) <= 0:
		return false
	_immediate_reward_summaries.append(summary.duplicate(true))
	_merge_grant_summary(summary)
	if defer_choice:
		_schedule_deferred_starpoint_choice(_box_index)
	_sync_result_scene_visibility()
	return true


func _grant_immediate_mythic_box_reward(reward: Dictionary) -> bool:
	if _reward_resolver == null or not _reward_resolver.has_method("grant_rewards"):
		return false
	var reward_copy: Dictionary = reward.duplicate(true)
	reward_copy["show_acquisition_cinematic"] = true
	var summary_value: Variant = _reward_resolver.grant_rewards(
		[reward_copy],
		_pending_owner,
		_pending_registry
	)
	if not (summary_value is Dictionary):
		return false
	var summary: Dictionary = summary_value
	if int(summary.get("granted", 0)) <= 0:
		return false
	_immediate_reward_summaries.append(summary.duplicate(true))
	_merge_grant_summary(summary)
	_raise_result_mythic_acquisition_cinematic()
	_sync_result_scene_visibility()
	return true


func _can_defer_starpoint_choice() -> bool:
	var runtime_perk_state: Object = _get_instance(_pending_registry, "runtime_perk_state")
	var runtime_perk_catalog: Object = _get_instance(_pending_registry, "runtime_perk_catalog")
	return (
		runtime_perk_state != null
		and runtime_perk_catalog != null
		and runtime_perk_state.has_method("open_next_choice")
	)


func _schedule_deferred_starpoint_choice(box_index: int) -> void:
	_pending_starpoint_choice_delay = STARPOINT_CHOICE_REWARD_DELAY
	_pending_starpoint_choice_box_index = box_index
	if _scene_node != null and is_instance_valid(_scene_node) and _scene_node.has_method("set_starpoint_choice_gate_active"):
		_scene_node.set_starpoint_choice_gate_active(true, box_index)


func _update_pending_starpoint_choice(delta: float) -> void:
	if _pending_starpoint_choice_delay <= 0.0:
		return
	if _is_runtime_perk_choice_active():
		return
	_pending_starpoint_choice_delay = max(0.0, _pending_starpoint_choice_delay - max(0.0, delta))
	if _pending_starpoint_choice_delay > 0.0:
		return
	_open_deferred_starpoint_choice()


func _open_deferred_starpoint_choice() -> void:
	var runtime_perk_state: Object = _get_instance(_pending_registry, "runtime_perk_state")
	var runtime_perk_catalog: Object = _get_instance(_pending_registry, "runtime_perk_catalog")
	var box_index: int = _pending_starpoint_choice_box_index
	_clear_pending_starpoint_choice()
	if runtime_perk_state == null or runtime_perk_catalog == null:
		return
	if not runtime_perk_state.has_method("open_next_choice"):
		return
	_active_starpoint_choice_box_index = box_index
	_last_recorded_perk_choice_sequence = _get_runtime_perk_choice_sequence(runtime_perk_state)
	runtime_perk_state.open_next_choice(
		_get_selected_character_type(_pending_owner),
		runtime_perk_catalog,
		false,
		_pending_owner,
		_pending_registry,
		null,
		{
			"source": "result_box_starpoint_choice",
			"defer_instant_dimension_gate_until_spawn_intro_end": true,
			"defer_instant_full_gauge_until_spawn_intro_end": true,
		}
	)
	if (
		runtime_perk_state.has_method("is_choice_active")
		and bool(runtime_perk_state.is_choice_active())
	):
		_play_runtime_perk_choice_open_audio()
	else:
		_clear_active_starpoint_choice_tracking()
	if _scene_node != null and is_instance_valid(_scene_node):
		_scene_node.queue_redraw()


func _update_runtime_perk_choice(delta: float) -> void:
	var runtime_perk_state: Object = _get_instance(_pending_registry, "runtime_perk_state")
	if runtime_perk_state == null or not runtime_perk_state.has_method("update"):
		return
	var view_size := Vector2.ZERO
	if _scene_node != null and is_instance_valid(_scene_node):
		view_size = _scene_node.get_viewport_rect().size
	runtime_perk_state.update(delta, view_size, _pending_owner, _pending_registry)
	_sync_box_perk_choice_rewards()


func _play_runtime_perk_choice_open_audio() -> void:
	var game_audio: Object = _get_instance(_pending_registry, "game_audio")
	if game_audio == null:
		return
	if game_audio.has_method("play_runtime_perk_choice_open"):
		game_audio.play_runtime_perk_choice_open()
	elif game_audio.has_method("play_starpoint_collect"):
		game_audio.play_starpoint_collect()


func _update_mythic_acquisition_cinematic(delta: float) -> void:
	var mythic_item_runtime: Object = _get_instance(_pending_registry, "mythic_item_runtime")
	if not _is_mythic_acquisition_cinematic_active(mythic_item_runtime):
		return
	if mythic_item_runtime.has_method("update"):
		mythic_item_runtime.update(_pending_owner, _pending_registry, delta)
	_raise_result_mythic_acquisition_cinematic(mythic_item_runtime)


func _handle_mythic_acquisition_input(event: InputEvent) -> bool:
	var mythic_item_runtime: Object = _get_instance(_pending_registry, "mythic_item_runtime")
	if not _is_mythic_acquisition_cinematic_active(mythic_item_runtime):
		return false
	if mythic_item_runtime.has_method("handle_acquisition_cinematic_input"):
		mythic_item_runtime.handle_acquisition_cinematic_input(event, _pending_registry)
	if _pending_owner != null and _pending_owner.has_method("queue_redraw"):
		_pending_owner.queue_redraw()
	if _scene_node != null and is_instance_valid(_scene_node):
		_scene_node.queue_redraw()
	return true


func _is_mythic_acquisition_cinematic_active(mythic_item_runtime: Object) -> bool:
	return (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_acquisition_cinematic_active")
		and bool(mythic_item_runtime.is_acquisition_cinematic_active())
	)


func _raise_result_mythic_acquisition_cinematic(mythic_item_runtime: Object = null) -> void:
	if mythic_item_runtime == null:
		mythic_item_runtime = _get_instance(_pending_registry, "mythic_item_runtime")
	if mythic_item_runtime == null:
		return
	var cinematic_value: Variant = mythic_item_runtime.get("acquisition_cinematic")
	if not (cinematic_value is CanvasItem):
		return
	var cinematic := cinematic_value as CanvasItem
	cinematic.z_as_relative = false
	cinematic.z_index = max(cinematic.z_index, 1305)
	if cinematic is Node:
		(cinematic as Node).process_mode = Node.PROCESS_MODE_ALWAYS


func _clear_pending_starpoint_choice() -> void:
	_pending_starpoint_choice_delay = 0.0
	_pending_starpoint_choice_box_index = -1
	if _scene_node != null and is_instance_valid(_scene_node) and _scene_node.has_method("set_starpoint_choice_gate_active"):
		_scene_node.set_starpoint_choice_gate_active(false, -1)


func _clear_active_starpoint_choice_tracking() -> void:
	_active_starpoint_choice_box_index = -1
	_last_recorded_perk_choice_sequence = 0


func _sync_box_perk_choice_rewards() -> void:
	if _active_starpoint_choice_box_index < 0:
		return
	var runtime_perk_state: Object = _get_instance(_pending_registry, "runtime_perk_state")
	if runtime_perk_state == null:
		_clear_active_starpoint_choice_tracking()
		return
	var snapshot: Dictionary = _get_runtime_perk_snapshot(runtime_perk_state)
	var sequence: int = int(snapshot.get("selected_choice_sequence", _get_runtime_perk_choice_sequence(runtime_perk_state)))
	if sequence > _last_recorded_perk_choice_sequence:
		var reward: Dictionary = _build_box_perk_choice_reward(snapshot)
		if not reward.is_empty() and _scene_node != null and is_instance_valid(_scene_node) and _scene_node.has_method("append_box_resolved_perk_reward"):
			_scene_node.append_box_resolved_perk_reward(_active_starpoint_choice_box_index, reward)
		_last_recorded_perk_choice_sequence = sequence
	if not _is_runtime_perk_choice_active() and int(snapshot.get("pending_skill_choices", 0)) <= 0:
		_clear_active_starpoint_choice_tracking()


func _build_box_perk_choice_reward(snapshot: Dictionary) -> Dictionary:
	var choice_value: Variant = snapshot.get("last_selected_choice", {})
	var choice: Dictionary = choice_value if choice_value is Dictionary else {}
	var perk_id: String = str(choice.get("id", snapshot.get("last_selected_id", "")))
	if perk_id == "":
		return {}
	var runtime_levels: Dictionary = _get_dictionary(snapshot.get("runtime_skill_levels", {}))
	var current_level: int = max(0, int(choice.get("current_level", 0)))
	var next_level: int = int(choice.get("next_level", runtime_levels.get(perk_id, 0)))
	if next_level > 0 and current_level <= 0:
		current_level = max(0, next_level - 1)
	var perk_data: Dictionary = {}
	if _perk_catalog != null and _perk_catalog.has_method("get_perk_data"):
		var perk_value: Variant = _perk_catalog.get_perk_data(perk_id)
		if perk_value is Dictionary:
			perk_data = (perk_value as Dictionary).duplicate(true)
	for key in ["id", "name", "description", "detail", "icon_color", "character_restriction"]:
		if str(perk_data.get(key, "")) == "" and choice.has(key):
			perk_data[key] = choice.get(key)
	if str(perk_data.get("id", "")) == "":
		perk_data["id"] = perk_id
	var perk_name: String = str(perk_data.get("name", choice.get("name", perk_id)))
	var label: String = perk_name
	if next_level > 0:
		label = "%s Lv.%d" % [perk_name, next_level]
	return {
		"type": "perk",
		"label": label,
		"perk_id": perk_id,
		"id": perk_id,
		"current_level": current_level,
		"next_level": max(1, next_level),
		"level_delta": max(1, int(choice.get("level_delta", max(1, next_level - current_level)))),
		"source": "box_starpoint_choice",
		"perk_data": perk_data,
	}


func _get_runtime_perk_snapshot(runtime_perk_state: Object) -> Dictionary:
	if runtime_perk_state != null and runtime_perk_state.has_method("get_snapshot"):
		var snapshot_value: Variant = runtime_perk_state.get_snapshot()
		if snapshot_value is Dictionary:
			return (snapshot_value as Dictionary).duplicate(true)
	return {}


func _get_runtime_perk_choice_sequence(runtime_perk_state: Object) -> int:
	var snapshot: Dictionary = _get_runtime_perk_snapshot(runtime_perk_state)
	return int(snapshot.get("selected_choice_sequence", 0))


func _empty_grant_summary(attempted: int) -> Dictionary:
	return {
		"attempted": attempted,
		"granted": 0,
		"active_granted": 0,
		"passive_granted": 0,
		"mythic_granted": 0,
		"starpoint_granted": 0,
		"failed": [],
	}


func _merge_grant_summary(summary: Dictionary) -> void:
	if _last_grant_summary.is_empty():
		_last_grant_summary = _empty_grant_summary(0)
	for key in ["attempted", "granted", "active_granted", "passive_granted", "mythic_granted", "starpoint_granted"]:
		_last_grant_summary[key] = int(_last_grant_summary.get(key, 0)) + int(summary.get(key, 0))
	var failed: Array = _get_array(_last_grant_summary.get("failed", []))
	for failed_value in _get_array(summary.get("failed", [])):
		if failed_value is Dictionary:
			failed.append((failed_value as Dictionary).duplicate(true))
		else:
			failed.append(failed_value)
	_last_grant_summary["failed"] = failed


func _finish_next_stage() -> void:
	if not active:
		return
	_grant_pending_rewards()
	_apply_stage_clear_progress_once(true)
	active = false
	var callback: Callable = _pending_reset_callback
	_pending_reset_callback = Callable()
	_pending_exit_callback = Callable()
	_pending_owner = null
	_pending_registry = null
	_spawn_pending = false
	_free_result_scene()
	_free_plaza_scene()
	if callback.is_valid():
		callback.call()


func _finish_enter_plaza() -> void:
	if not active:
		return
	_grant_pending_rewards()
	_apply_stage_clear_progress_once(true)
	_clear_pending_starpoint_choice()
	_clear_active_starpoint_choice_tracking()
	_spawn_pending = false
	_free_result_scene()
	if not _ensure_plaza_assets_ready() or not _spawn_plaza_scene(_pending_owner):
		_finish_plaza_and_continue()
		return
	if _pending_owner != null and _pending_owner.has_method("queue_redraw"):
		_pending_owner.queue_redraw()


func _spawn_plaza_scene(owner: Object) -> bool:
	if not (owner is Node):
		return false
	_free_plaza_scene()
	var packed: PackedScene = _get_plaza_scene_packed()
	if packed == null:
		push_warning("Missing plaza scene at %s" % PLAZA_SCENE_PATH)
		return false
	var instance: Node = packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		push_warning("Plaza scene root must be Control: %s" % PLAZA_SCENE_PATH)
		return false
	_plaza_node = instance as Control
	_plaza_node.name = "PlazaScene"
	_plaza_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_plaza_node.z_index = 1200
	_plaza_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _plaza_node.has_method("configure"):
		_plaza_node.configure(
			{
				"current_stage": current_stage,
				"plaza_save_path": _get_plaza_save_path(),
				"runtime_owner": _pending_owner,
				"runtime_registry": _pending_registry,
			},
			Callable(self, "_finish_plaza_and_continue"),
			true
		)
	(owner as Node).add_child(_plaza_node)
	return true


func _finish_plaza_and_continue() -> void:
	if not active:
		return
	active = false
	var callback: Callable = _pending_reset_callback
	_pending_reset_callback = Callable()
	_pending_exit_callback = Callable()
	_pending_owner = null
	_pending_registry = null
	_spawn_pending = false
	_free_result_scene()
	_free_plaza_scene()
	if callback.is_valid():
		callback.call()


func _finish_exit_to_menu() -> void:
	if not active:
		return
	_grant_pending_rewards()
	_apply_stage_clear_progress_once(false)
	active = false
	var exit_cb: Callable = _pending_exit_callback
	var reset_cb: Callable = _pending_reset_callback
	_pending_reset_callback = Callable()
	_pending_exit_callback = Callable()
	_pending_owner = null
	_pending_registry = null
	_spawn_pending = false
	_free_result_scene()
	_free_plaza_scene()
	if exit_cb.is_valid():
		exit_cb.call()
	elif reset_cb.is_valid():
		reset_cb.call()


func _apply_stage_clear_progress_once(grant_ap: bool) -> Dictionary:
	if not _owner_has_runtime_perk_gold(_pending_owner):
		_last_plaza_progress_summary = {
			"transferred_gold": 0,
			"granted_ap": 0,
			"save": "skipped_missing_runtime_perk_gold_owner",
		}
		return _last_plaza_progress_summary.duplicate(true)
	if _plaza_save_store == null or not _plaza_save_store.has_method("apply_stage_clear_progress"):
		_last_plaza_progress_summary = {
			"transferred_gold": 0,
			"granted_ap": 0,
			"save": "missing_plaza_save_store",
		}
		return _last_plaza_progress_summary.duplicate(true)
	var gold_amount := 0
	if not _stage_clear_gold_transfer_consumed:
		gold_amount = _get_owner_runtime_perk_gold(_pending_owner)
		_stage_clear_gold_transfer_consumed = true
		_set_owner_runtime_perk_gold(_pending_owner, 0)
	var should_grant_ap := grant_ap and not _stage_clear_ap_grant_consumed
	if should_grant_ap:
		_stage_clear_ap_grant_consumed = true
	_last_plaza_progress_summary = _plaza_save_store.apply_stage_clear_progress(current_stage, gold_amount, should_grant_ap)
	return _last_plaza_progress_summary.duplicate(true)


func _get_plaza_save_path() -> String:
	if _plaza_save_store == null or not _plaza_save_store.has_method("get_summary"):
		return ""
	var summary: Dictionary = _plaza_save_store.get_summary()
	return str(summary.get("save_path", ""))


func _free_result_scene() -> void:
	if _scene_node != null and is_instance_valid(_scene_node):
		_scene_node.queue_free()
	_scene_node = null


func _free_plaza_scene() -> void:
	if _plaza_node != null and is_instance_valid(_plaza_node):
		_plaza_node.queue_free()
	_plaza_node = null


func _get_score_snapshot(registry: Object) -> Dictionary:
	var score_state: Object = _get_instance(registry, "match_score_state")
	if score_state != null and score_state.has_method("get_snapshot"):
		var snapshot: Variant = score_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot

	var scoreboard_state: Object = _get_instance(registry, "scoreboard_state")
	if scoreboard_state != null:
		return {
			"player_score": _call_int(scoreboard_state, "get_player_points", 0),
			"boss_score": _call_int(scoreboard_state, "get_boss_points", 0),
		}
	return {}


func _call_int(target: Object, method_name: String, fallback: int) -> int:
	if target == null or not target.has_method(method_name):
		return fallback
	return int(target.call(method_name))


func _get_current_stage(owner: Object) -> int:
	if owner != null:
		var value: Variant = owner.get("current_stage")
		if value != null:
			return max(1, int(value))
	return 1


func _get_owner_runtime_perk_gold(owner: Object) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("runtime_perk_gold")
	if value == null:
		return 0
	return maxi(0, int(value))


func _set_owner_runtime_perk_gold(owner: Object, value: int) -> void:
	if not _owner_has_runtime_perk_gold(owner):
		return
	owner.set("runtime_perk_gold", maxi(0, value))


func _owner_has_runtime_perk_gold(owner: Object) -> bool:
	return owner != null and owner.get("runtime_perk_gold") != null


func _get_selected_character_type(owner: Object) -> String:
	if owner == null:
		return "smasher"
	var value: Variant = owner.get("selected_character_type")
	if value == null:
		return "smasher"
	var normalized: String = str(value).strip_edges().to_lower()
	if normalized == "viper":
		return "viper"
	if normalized == "soldier" or normalized == "commando":
		return "soldier"
	if normalized == "optimus" or normalized == "io":
		return "optimus"
	if normalized == "blacksmith" or normalized == "baltor" or normalized == "kohaku":
		return "blacksmith"
	return "smasher"


func _get_result_victory_character_type(owner: Object) -> String:
	if _get_selected_character_type(owner) == "soldier":
		return "soldier"
	if _get_selected_character_type(owner) == "blacksmith":
		return "blacksmith"
	return "smasher"


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _reset_stage5_for_result(registry: Object, stage_id: int) -> void:
	if stage_id != 5:
		return
	var stage5_hongryun_state: Object = _get_instance(registry, "stage5_hongryun_state")
	if stage5_hongryun_state != null and stage5_hongryun_state.has_method("reset_for_result"):
		stage5_hongryun_state.reset_for_result()
	var stage5_hongryun_fire_machine_event: Object = _get_instance(registry, "stage5_hongryun_fire_machine_event")
	if stage5_hongryun_fire_machine_event != null and stage5_hongryun_fire_machine_event.has_method("reset_for_result"):
		stage5_hongryun_fire_machine_event.reset_for_result()
	var stage5_hongryun_actor_renderer: Object = _get_instance(registry, "stage5_hongryun_actor_renderer")
	if stage5_hongryun_actor_renderer != null:
		if stage5_hongryun_actor_renderer.has_method("reset_round_fx"):
			stage5_hongryun_actor_renderer.reset_round_fx()
		elif stage5_hongryun_actor_renderer.has_method("reset"):
			stage5_hongryun_actor_renderer.reset()


func _get_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
