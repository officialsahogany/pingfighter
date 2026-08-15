extends RefCounted

const StageClearResultPlazaProgressHandler := preload("res://scripts/core/stage_clear_result_plaza_progress_handler.gd")
const StageClearResultPlazaScenePrewarmState := preload("res://scripts/core/stage_clear_result_plaza_scene_prewarm_state.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const PlazaR3ProductionEntryHost := preload("res://scripts/plaza/plaza_r3_production_entry_host.gd")

const PLAZA_SCENE_PATH := "res://scenes/plaza.tscn"

var _plaza_node: Control
var _plaza_scene_packed: PackedScene
var _prewarm_state: Object = StageClearResultPlazaScenePrewarmState.new()
var _r3_entry_host: Control = null
var _r3_entry_owner: Node = null
var _r3_entry_config: Dictionary = {}
var _r3_entry_callbacks: Dictionary = {}
var _r3_entry_commit_count := 0


func reset() -> void:
	free_scene()
	_prewarm_state.reset()


func set_background_prewarm_enabled(enabled: bool) -> void:
	_prewarm_state.set_background_prewarm_enabled(enabled)


func has_scene() -> bool:
	return _plaza_node != null and is_instance_valid(_plaza_node)


func get_status() -> Dictionary:
	var status := {
		"plaza_scene_path": PLAZA_SCENE_PATH,
		"plaza_active": has_scene(),
		"plaza_scene_ready": has_scene(),
		"plaza_status": _plaza_node.get_status() if has_scene() and _plaza_node.has_method("get_status") else {},
		"r3_entry_active": is_entry_transition_active(),
		"r3_entry_commit_count": _r3_entry_commit_count,
		"r3_entry_status": _r3_entry_host.call("get_debug_status") if _r3_entry_host != null and is_instance_valid(_r3_entry_host) else {},
	}
	status.merge(_prewarm_state.get_status(), true)
	return status


func update(delta: float) -> void:
	if is_entry_transition_active() and not has_scene():
		if bool(_r3_entry_host.call("advance_entry", delta)):
			_commit_r3_entry_transition()
		return
	if has_scene() and _plaza_node.has_method("update_plaza"):
		_plaza_node.update_plaza(delta)


func handle_input(event: InputEvent) -> void:
	if has_scene() and _plaza_node.has_method("handle_plaza_input"):
		_plaza_node.handle_plaza_input(event)


func prewarm_assets_step(current_stage: int, owner: Object = null) -> bool:
	# R3-D starts its complete CPU+GPU warm transaction only after the player's
	# click, beneath an opaque progress surface. Warming R1 here would duplicate
	# resources and would make the cold-entry timeline unverifiable.
	return current_stage > 0 and owner != null


func advance_entry_readiness(current_stage: int, owner: Object = null) -> bool:
	return current_stage > 0 and owner != null


func ensure_assets_ready(current_stage: int, owner: Object = null) -> bool:
	return current_stage > 0 and owner != null


func build_scene_config(
	current_stage: int,
	plaza_save_store: Object,
	owner: Object,
	registry: Object,
	selected_character_type: String,
	play_arrival_transition: bool = true
) -> Dictionary:
	var normalized_stage := maxi(1, current_stage)
	var map_seed := _resolve_stage_map_seed(plaza_save_store, normalized_stage)
	var render_size := _resolve_render_size(owner)
	var safe_insets := _build_safe_insets(render_size)
	var minimap_rect := _build_minimap_rect(render_size, safe_insets)
	var guardian_id := _resolve_guardian_id(owner)
	var guardian_style := "ground"
	if guardian_id != "":
		guardian_style = "ground" if LingpetCatalog.get_motion_style(guardian_id) == "patrol" else "flight"
	return {
		"current_stage": normalized_stage,
		"stage_id": normalized_stage,
		"map_seed": map_seed,
		"plaza_save_path": StageClearResultPlazaProgressHandler.get_plaza_save_path(plaza_save_store),
		"runtime_owner": owner,
		"runtime_registry": registry,
		"selected_character_type": selected_character_type,
		"play_arrival_transition": play_arrival_transition,
		"r3_production": true,
		"render_size": render_size,
		"safe_insets": safe_insets,
		"minimap_rect": minimap_rect,
		"camera_zoom": 1.35,
		"guardian_enabled": guardian_id != "",
		"guardian_id": guardian_id if guardian_id != "" else "onimaru",
		"guardian_locomotion_style": guardian_style,
		"force_tavern": _should_force_tavern(plaza_save_store, normalized_stage),
	}


func begin_r3_entry_transition(
	owner: Object,
	config: Dictionary,
	finish_callback: Callable,
	commit_callbacks: Dictionary
) -> bool:
	if not (owner is Node) or has_scene() or is_entry_transition_active():
		return false
	var host := PlazaR3ProductionEntryHost.new()
	_r3_entry_host = host
	_r3_entry_host.name = "PlazaR3ProductionEntry"
	_r3_entry_host.process_mode = Node.PROCESS_MODE_ALWAYS
	_r3_entry_host.position = Vector2.ZERO
	_r3_entry_host.size = config.get("render_size", Vector2(2020.0, 1246.0)) as Vector2
	_r3_entry_owner = owner as Node
	_r3_entry_config = config.duplicate(true)
	_r3_entry_config["r3_entry_host"] = _r3_entry_host
	_r3_entry_callbacks = commit_callbacks.duplicate(false)
	_r3_entry_callbacks["finish_plaza"] = finish_callback
	_r3_entry_owner.add_child(_r3_entry_host)
	if not bool(_r3_entry_host.call("begin_entry", config)):
		return true
	return true


func is_entry_transition_active() -> bool:
	return (
		_r3_entry_host != null
		and is_instance_valid(_r3_entry_host)
		and (
			bool(_r3_entry_host.call("is_entry_in_progress"))
			or bool(_r3_entry_host.call("is_rejected"))
		)
	)


func spawn_scene(owner: Object, config: Dictionary, finish_callback: Callable) -> bool:
	if not (owner is Node):
		return false
	# Texture2D cache completion alone is not spawn readiness. The retained
	# 7x3 MIX/ADD layers must have rendered off-screen and crossed two actual
	# frame_post_draw flushes through BattlePsoPrewarmer first. The one
	# exception is a forced entry click: the bounded texture drain already
	# completed, and blocking here would silently reroute the player past the
	# plaza through finish_plaza_and_continue.
	if not BattlePsoPrewarmer.is_hwangyeok_gpu_prewarm_complete() and not bool(_prewarm_state.was_entry_forced()):
		return false
	free_scene()
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
		_plaza_node.configure(config, finish_callback, true)
	(owner as Node).add_child(_plaza_node)
	return true


func free_scene() -> void:
	if _plaza_node != null and is_instance_valid(_plaza_node):
		# Retained CanvasItems must be hidden synchronously. queue_free() does not
		# flush until the frame boundary and can otherwise conceal a missing
		# plaza-exit cleanup route in state-only tests.
		if _plaza_node.has_method("clear_transient_canvas_items"):
			_plaza_node.clear_transient_canvas_items()
		_plaza_node.queue_free()
	_plaza_node = null
	if _r3_entry_host != null and is_instance_valid(_r3_entry_host):
		_r3_entry_host.call("teardown_scene")
		_r3_entry_host.queue_free()
	_r3_entry_host = null
	_r3_entry_owner = null
	_r3_entry_config.clear()
	_r3_entry_callbacks.clear()


func _get_plaza_scene_packed() -> PackedScene:
	if _plaza_scene_packed != null:
		return _plaza_scene_packed
	_plaza_scene_packed = load(PLAZA_SCENE_PATH) as PackedScene
	return _plaza_scene_packed


func _commit_r3_entry_transition() -> bool:
	if _r3_entry_owner == null or not is_instance_valid(_r3_entry_owner) or _r3_entry_host == null:
		return false
	var packed: PackedScene = _get_plaza_scene_packed()
	if packed == null:
		_r3_entry_host.call("reject_transition", "plaza_scene_missing")
		return false
	var instance: Node = packed.instantiate()
	if not (instance is Control):
		if instance != null:
			instance.queue_free()
		_r3_entry_host.call("reject_transition", "plaza_scene_root_invalid")
		return false
	var plaza := instance as Control
	plaza.name = "PlazaScene"
	plaza.process_mode = Node.PROCESS_MODE_ALWAYS
	plaza.z_index = 1200
	plaza.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plaza.visible = false
	var finish_callback := _r3_entry_callbacks.get("finish_plaza", Callable()) as Callable
	if plaza.has_method("configure"):
		plaza.configure(_r3_entry_config, finish_callback, true)
	_r3_entry_owner.add_child(plaza)
	if not bool(_r3_entry_host.call("activate_under_loading")):
		plaza.queue_free()
		_r3_entry_host.call("reject_transition", "plaza_activation_failed")
		return false
	_plaza_node = plaza
	_call_commit_callback("grant_pending_rewards")
	_call_commit_callback("apply_stage_clear_progress", [true])
	_call_commit_callback("reset_starpoint_choice")
	_call_commit_callback("mark_spawn_not_pending")
	_call_commit_callback("free_result_scene")
	if plaza.has_method("refresh_progress_state_after_entry_commit"):
		plaza.call("refresh_progress_state_after_entry_commit")
	plaza.visible = true
	if not bool(_r3_entry_host.call("finish_atomic_reveal")):
		plaza.visible = false
		_r3_entry_host.call("reject_transition", "atomic_reveal_failed")
		return false
	_r3_entry_commit_count += 1
	_r3_entry_callbacks.clear()
	if _r3_entry_owner.has_method("queue_redraw"):
		_r3_entry_owner.call("queue_redraw")
	return true


func _call_commit_callback(key: String, args: Array = []) -> Variant:
	var callback := _r3_entry_callbacks.get(key, Callable()) as Callable
	return callback.callv(args) if callback.is_valid() else null


func _resolve_stage_map_seed(plaza_save_store: Object, stage_id: int) -> int:
	if plaza_save_store != null and plaza_save_store.has_method("get_or_create_stage_map_seed"):
		return maxi(1, int(plaza_save_store.get_or_create_stage_map_seed(stage_id)))
	return maxi(1, int(abs(hash("plaza_stage_%d" % stage_id))))


func _resolve_render_size(owner: Object) -> Vector2:
	if owner is Node:
		var viewport := (owner as Node).get_viewport()
		if viewport != null:
			var visible_size := viewport.get_visible_rect().size
			if visible_size.is_finite() and visible_size.x > 1.0 and visible_size.y > 1.0:
				return visible_size
	return Vector2(2020.0, 1246.0)


func _build_safe_insets(render_size: Vector2) -> Dictionary:
	return {
		"left": maxf(24.0, render_size.x * 0.03565),
		"top": maxf(24.0, render_size.y * 0.05778),
		"right": maxf(260.0, render_size.x * 0.17822),
		"bottom": maxf(72.0, render_size.y * 0.09631),
	}


func _build_minimap_rect(render_size: Vector2, safe_insets: Dictionary) -> Rect2:
	var right := float(safe_insets.get("right", 360.0))
	var top := float(safe_insets.get("top", 72.0))
	var width := maxf(180.0, right - 110.0)
	var height := minf(174.0, maxf(110.0, render_size.y * 0.14))
	return Rect2(Vector2(render_size.x - right + 40.0, top + 8.0), Vector2(width, height))


func _resolve_guardian_id(owner: Object) -> String:
	if owner == null:
		return ""
	var state := str(owner.get("lingpet_state")).strip_edges().to_lower()
	if state != "" and state not in ["companion", "active", "동행"]:
		return ""
	for key in ["active_lingpet_id", "current_lingpet_id", "lingpet_id"]:
		var value := str(owner.get(key)).strip_edges()
		if value != "":
			return value
	return ""


func _should_force_tavern(plaza_save_store: Object, stage_id: int) -> bool:
	if plaza_save_store == null or not plaza_save_store.has_method("get_summary"):
		return false
	var summary := plaza_save_store.get_summary() as Dictionary
	var quest := summary.get("tavern_active_quest", {}) as Dictionary
	return not quest.is_empty() and int(quest.get("accepted_stage", stage_id)) < stage_id
