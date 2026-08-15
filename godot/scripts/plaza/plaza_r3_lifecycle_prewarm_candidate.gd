extends Control

# R3-C candidate-only lifecycle/prewarm owner. Production remains on the R1
# plaza until R3-D atomically replaces the live route.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapNavigation := preload("res://scripts/plaza/plaza_map_navigation.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")
const PlazaR3EnvironmentLayoutCompiler := preload("res://scripts/plaza/plaza_r3_environment_layout_compiler.gd")
const PlazaR3ExteriorRuntimeCandidate := preload("res://scripts/plaza/plaza_r3_exterior_runtime_candidate.gd")
const PlazaR3NavigationBinding := preload("res://scripts/plaza/plaza_r3_navigation_binding.gd")

const SCHEMA_VERSION := "plaza_r3c_lifecycle_prewarm_candidate_v1"
const EXPECTED_ENVIRONMENT_CATALOG_KEY_COUNT := 25
const REQUIRED_GPU_POST_DRAW_FLUSH_COUNT := 2
const COLD_INSTANTIATE_WARNING_USEC := 60_000
const FIRST_VISIBLE_R3_LIMIT_USEC := 2_000
const GPU_CELL_EXTENT := 28.0
const DEFAULT_WORLD_SIZE := Vector2(2400.0, 1500.0)
const DEFAULT_SPAWN_ANCHOR := Vector2(120.0, 666.0)
const DEFAULT_EXIT_ZONE := Rect2(2250.0, 596.0, 120.0, 92.0)

const PHASE_IDLE := "idle"
const PHASE_RESOURCE_BASE := "resource_base"
const PHASE_COMPILE := "compile"
const PHASE_RESOURCE_ALL := "resource_all"
const PHASE_RUNTIME_BIND := "runtime_bind"
const PHASE_GPU_SUBMIT := "gpu_submit"
const PHASE_READY := "ready"
const PHASE_EXTERIOR := "exterior"
const PHASE_INTERIOR := "interior"
const PHASE_TORN_DOWN := "torn_down"
const PHASE_REJECTED := "rejected"

var _phase := PHASE_IDLE
var _rejection_reason := "not_started"
var _request: Dictionary = {}
var _cache_key := ""
var _current_record: Dictionary = {}
var _compiled_cache_by_key: Dictionary = {}
var _gpu_warm_texture_ids_by_key: Dictionary = {}

var _base_texture_paths: Array[String] = []
var _environment_texture_paths: Array[String] = []
var _building_texture_paths: Array[String] = []
var _actor_texture_paths: Array[String] = []
var _interior_texture_paths: Array[String] = []
var _resource_texture_paths: Array[String] = []
var _gpu_texture_paths: Array[String] = []
var _resource_index := 0
var _requested_texture_paths: Dictionary = {}
var _warmed_texture_ids: Dictionary = {}

var _completed_step_ids: Array[String] = []
var _completed_step_lookup: Dictionary = {}
var _duplicate_step_count := 0

var _runtime: Control = null
var _runtime_instance_id := 0
var _gpu_viewport: SubViewport = null
var _gpu_canvas_layer: CanvasLayer = null
var _gpu_grid_root: Node2D = null
var _gpu_mix_material: CanvasItemMaterial = null
var _gpu_add_material: CanvasItemMaterial = null
var _gpu_sprite_by_path: Dictionary = {}
var _gpu_submitted_texture_ids: Dictionary = {}
var _gpu_in_bounds_path_count := 0
var _gpu_post_draw_flush_count := 0
var _gpu_signal_connected := false
var _gpu_reused := false
var _minimap_pipeline_warmed := false
var _node_pipeline_warmed := false

var _ready := false
var _active := false
var _inside_interior := false
var _return_world_position := Vector2.INF
var _return_portal_id := ""

var _compile_count := 0
var _cache_hit_count := 0
var _cache_miss_count := 0
var _texture_request_count := 0
var _texture_cache_hit_count := 0
var _runtime_build_count := 0
var _cold_warning_count := 0
var _phase_timings_usec: Dictionary = {}
var _prewarm_started_usec := 0
var _prewarm_finished_usec := 0
var _first_visible_activation_usec := -1
var _last_visible_activation_usec := -1
var _activation_count := 0
var _cold_prewarm_usec := -1
var _warm_prewarm_usec := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	set_process(false)


func begin_prewarm(config: Dictionary) -> bool:
	if _active or _inside_interior:
		return _reject("lifecycle_busy")
	_teardown_runtime_only()
	_reset_session_state()
	var validated := _validate_request(config)
	if not bool(validated.get("valid", false)):
		return _reject(str(validated.get("reason", "request_invalid")))
	_request = (validated.get("request", {}) as Dictionary).duplicate(true)
	size = _request.get("render_size", Vector2.ZERO) as Vector2
	_cache_key = _build_cache_key(_request)
	_prewarm_started_usec = Time.get_ticks_usec()
	_build_initial_texture_path_contract()
	if _compiled_cache_by_key.has(_cache_key):
		_current_record = (_compiled_cache_by_key.get(_cache_key, {}) as Dictionary).duplicate(true)
		_cache_hit_count += 1
		_restore_record_path_contract()
		_phase = PHASE_RESOURCE_ALL
	else:
		_cache_miss_count += 1
		_phase = PHASE_RESOURCE_BASE
	_rejection_reason = ""
	return true


func advance_prewarm_step() -> bool:
	match _phase:
		PHASE_READY, PHASE_EXTERIOR, PHASE_INTERIOR:
			return true
		PHASE_RESOURCE_BASE:
			if not _advance_texture_path_list(_base_texture_paths):
				return false
			_phase = PHASE_COMPILE
			return false
		PHASE_COMPILE:
			if not _compile_authoritative_record():
				return false
			_record_step("compile_or_restore")
			_phase = PHASE_RESOURCE_ALL
			_resource_index = 0
			return false
		PHASE_RESOURCE_ALL:
			if not _advance_texture_path_list(_resource_texture_paths):
				return false
			if not _completed_step_lookup.has("compile_or_restore"):
				_record_step("compile_or_restore")
			_phase = PHASE_RUNTIME_BIND
			return false
		PHASE_RUNTIME_BIND:
			if not _build_hidden_runtime():
				return false
			_record_step("runtime_bind")
			if _can_reuse_gpu_warm_contract():
				_gpu_reused = true
				_gpu_post_draw_flush_count = REQUIRED_GPU_POST_DRAW_FLUSH_COUNT
				_gpu_in_bounds_path_count = _gpu_texture_paths.size()
				_gpu_submitted_texture_ids = _current_gpu_texture_ids()
				_record_step("gpu_submit")
				_record_step("gpu_flush:1")
				_record_step("gpu_flush:2")
				return _finish_ready_state()
			if not _start_gpu_submission():
				return false
			_phase = PHASE_GPU_SUBMIT
			return false
		PHASE_GPU_SUBMIT:
			if _gpu_post_draw_flush_count < REQUIRED_GPU_POST_DRAW_FLUSH_COUNT:
				return false
			return _finish_gpu_submission()
		PHASE_REJECTED, PHASE_TORN_DOWN, PHASE_IDLE:
			return false
	return _reject("unknown_prewarm_phase:%s" % _phase)


func activate_exterior() -> bool:
	if not _ready or _runtime == null or not is_instance_valid(_runtime):
		return _reject("activation_before_ready")
	if _inside_interior:
		return _reject("activation_while_interior")
	var expected_render_size := _request.get("render_size", Vector2.ZERO) as Vector2
	if not size.is_equal_approx(expected_render_size):
		return _reject("lifecycle_render_size_drift")
	var node_count_before := _count_descendants(_runtime)
	var texture_ids_before := _collect_scene_texture_ids(_runtime)
	var started_usec := Time.get_ticks_usec()
	_runtime.call("set_active", true)
	_active = true
	visible = true
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	_last_visible_activation_usec = elapsed_usec
	if _first_visible_activation_usec < 0:
		_first_visible_activation_usec = elapsed_usec
	_activation_count += 1
	if elapsed_usec > FIRST_VISIBLE_R3_LIMIT_USEC:
		_runtime.call("set_active", false)
		_active = false
		visible = false
		return _reject("first_visible_r3_budget_exceeded:%d" % elapsed_usec)
	if _count_descendants(_runtime) != node_count_before:
		return _reject("activation_created_scene_nodes")
	if _collect_scene_texture_ids(_runtime) != texture_ids_before:
		return _reject("activation_changed_scene_textures")
	_phase = PHASE_EXTERIOR
	_rejection_reason = ""
	return true


func enter_interior(interaction: Dictionary) -> bool:
	if not _ready or not _active or _phase != PHASE_EXTERIOR:
		return _reject("interior_entry_outside_exterior")
	if str(interaction.get("interaction_kind", "")) != "building":
		return _reject("interior_interaction_kind_invalid")
	var portal_id := str(interaction.get("portal_id", ""))
	if portal_id == "" or not _layout_has_portal(portal_id):
		return _reject("interior_portal_invalid")
	var runtime_status := _runtime.call("get_debug_status") as Dictionary
	var return_world := runtime_status.get("player_world_position", Vector2.INF) as Vector2
	if not _compiled_navigation_can_occupy(return_world):
		return _reject("interior_return_position_not_walkable")
	_return_world_position = return_world
	_return_portal_id = portal_id
	_runtime.call("set_active", false)
	_active = false
	_inside_interior = true
	visible = false
	_phase = PHASE_INTERIOR
	_rejection_reason = ""
	return true


func return_from_interior(requested_return_world: Variant = null) -> bool:
	if not _ready or not _inside_interior or _runtime == null or not is_instance_valid(_runtime):
		return _reject("interior_return_without_session")
	var return_world := _return_world_position
	if requested_return_world != null:
		if not (requested_return_world is Vector2):
			return _soft_reject("interior_return_type_invalid")
		return_world = requested_return_world as Vector2
	if not return_world.is_finite() or not return_world.is_equal_approx(_return_world_position):
		return _soft_reject("interior_return_position_drift")
	if not _compiled_navigation_can_occupy(return_world):
		return _soft_reject("interior_return_position_not_walkable")
	var runtime_id_before := _runtime.get_instance_id()
	_runtime.call("set_active", true)
	if _runtime.get_instance_id() != runtime_id_before:
		return _soft_reject("interior_return_runtime_replaced")
	_inside_interior = false
	_active = true
	visible = true
	_phase = PHASE_EXTERIOR
	_rejection_reason = ""
	return true


func teardown_scene() -> void:
	_teardown_runtime_only()
	_ready = false
	_active = false
	_inside_interior = false
	visible = false
	_return_world_position = Vector2.INF
	_return_portal_id = ""
	_current_record.clear()
	_phase = PHASE_TORN_DOWN
	_rejection_reason = "torn_down"


func reset_all_for_test() -> void:
	teardown_scene()
	_compiled_cache_by_key.clear()
	_gpu_warm_texture_ids_by_key.clear()
	_compile_count = 0
	_cache_hit_count = 0
	_cache_miss_count = 0
	_texture_request_count = 0
	_texture_cache_hit_count = 0
	_runtime_build_count = 0
	_cold_warning_count = 0
	_phase_timings_usec.clear()
	_phase = PHASE_IDLE
	_rejection_reason = "not_started"


func get_runtime_for_test() -> Control:
	return _runtime


func get_layout_snapshot_for_test() -> Dictionary:
	return (_current_record.get("layout", {}) as Dictionary).duplicate(true)


func get_environment_plan_snapshot_for_test() -> Dictionary:
	return (_current_record.get("plan", {}) as Dictionary).duplicate(true)


func tick_exterior(input_direction: Vector2, delta: float, ticks_msec: int) -> Dictionary:
	if not _ready or not _active or _inside_interior or _phase != PHASE_EXTERIOR:
		return {"valid": false, "rejection_reason": "lifecycle_not_in_exterior"}
	if _runtime == null or not is_instance_valid(_runtime):
		return {"valid": false, "rejection_reason": "runtime_missing"}
	return _runtime.call("tick_candidate", input_direction, delta, ticks_msec) as Dictionary


func try_interact() -> Dictionary:
	if not _ready or not _active or _inside_interior or _phase != PHASE_EXTERIOR:
		return {"valid": false, "rejection_reason": "lifecycle_not_in_exterior"}
	if _runtime == null or not is_instance_valid(_runtime) or not _runtime.has_method("try_interact"):
		return {"valid": false, "rejection_reason": "runtime_interaction_missing"}
	return _runtime.call("try_interact") as Dictionary


func request_guardian_recall(desired_world_position: Vector2) -> Dictionary:
	if not _ready or not _active or _inside_interior or _phase != PHASE_EXTERIOR:
		return {"valid": false, "rejection_reason": "lifecycle_not_in_exterior"}
	if _runtime == null or not is_instance_valid(_runtime) or not _runtime.has_method("request_guardian_recall"):
		return {"valid": false, "rejection_reason": "runtime_guardian_recall_missing"}
	return _runtime.call("request_guardian_recall", desired_world_position) as Dictionary


func get_prewarm_progress_snapshot() -> Dictionary:
	var progress := 0.0
	var completed := 0
	var total := 1
	match _phase:
		PHASE_IDLE:
			progress = 0.0
		PHASE_RESOURCE_BASE:
			total = maxi(1, _base_texture_paths.size())
			completed = clampi(_resource_index, 0, total)
			progress = 0.40 * float(completed) / float(total)
		PHASE_COMPILE:
			progress = 0.40
		PHASE_RESOURCE_ALL:
			total = maxi(1, _resource_texture_paths.size())
			completed = clampi(_resource_index, 0, total)
			progress = 0.42 + 0.36 * float(completed) / float(total)
		PHASE_RUNTIME_BIND:
			progress = 0.80
		PHASE_GPU_SUBMIT:
			total = REQUIRED_GPU_POST_DRAW_FLUSH_COUNT
			completed = clampi(_gpu_post_draw_flush_count, 0, total)
			progress = 0.84 + 0.14 * float(completed) / float(total)
		PHASE_READY, PHASE_EXTERIOR, PHASE_INTERIOR:
			progress = 1.0
		PHASE_TORN_DOWN, PHASE_REJECTED:
			progress = 0.0
	return {
		"phase": _phase,
		"progress": clampf(progress, 0.0, 1.0),
		"completed": completed,
		"total": total,
		"ready": _ready,
		"rejection_reason": _rejection_reason,
		"progress_token": "%s:%d:%d:%d:%d" % [
			_phase,
			_resource_index,
			_gpu_post_draw_flush_count,
			_completed_step_ids.size(),
			_runtime_build_count,
		],
	}


func get_readiness_snapshot() -> Dictionary:
	var expected_steps := _expected_step_ids()
	return {
		"schema_version": SCHEMA_VERSION,
		"candidate_only": true,
		"production_connected": false,
		"phase": _phase,
		"ready": _ready,
		"cache_key": _cache_key,
		"catalog_key_count": int(_current_record.get("catalog_key_count", 0)),
		"expected_resource_paths": _resource_texture_paths.duplicate(),
		"warmed_resource_paths": _sorted_dictionary_keys(_warmed_texture_ids),
		"expected_gpu_paths": _gpu_texture_paths.duplicate(),
		"submitted_gpu_paths": _sorted_dictionary_keys(_gpu_submitted_texture_ids),
		"building_texture_paths": _building_texture_paths.duplicate(),
		"environment_texture_paths": _environment_texture_paths.duplicate(),
		"actor_texture_paths": _actor_texture_paths.duplicate(),
		"interior_texture_paths": _interior_texture_paths.duplicate(),
		"warmed_texture_ids": _warmed_texture_ids.duplicate(true),
		"submitted_gpu_texture_ids": _gpu_submitted_texture_ids.duplicate(true),
		"gpu_in_bounds_path_count": _gpu_in_bounds_path_count,
		"gpu_post_draw_flush_count": _gpu_post_draw_flush_count,
		"gpu_required_post_draw_flush_count": REQUIRED_GPU_POST_DRAW_FLUSH_COUNT,
		"gpu_reused": _gpu_reused,
		"node_pipeline_warmed": _node_pipeline_warmed,
		"minimap_pipeline_warmed": _minimap_pipeline_warmed,
		"expected_step_ids": expected_steps,
		"completed_step_ids": _completed_step_ids.duplicate(),
		"duplicate_step_count": _duplicate_step_count,
	}


static func validate_readiness_snapshot(
	snapshot: Dictionary,
	independent_expected_resource_paths: Array[String],
	independent_expected_gpu_paths: Array[String]
) -> Dictionary:
	var violations: Array[String] = []
	var expected_resource := independent_expected_resource_paths.duplicate()
	expected_resource.sort()
	var expected_gpu := independent_expected_gpu_paths.duplicate()
	expected_gpu.sort()
	var snapshot_expected_resource := _static_string_array(snapshot.get("expected_resource_paths", []))
	var warmed_resource := _static_string_array(snapshot.get("warmed_resource_paths", []))
	var snapshot_expected_gpu := _static_string_array(snapshot.get("expected_gpu_paths", []))
	var submitted_gpu := _static_string_array(snapshot.get("submitted_gpu_paths", []))
	snapshot_expected_resource.sort()
	warmed_resource.sort()
	snapshot_expected_gpu.sort()
	submitted_gpu.sort()
	if not bool(snapshot.get("candidate_only", false)) or bool(snapshot.get("production_connected", true)):
		violations.append("candidate_boundary_invalid")
	if not bool(snapshot.get("ready", false)):
		violations.append("readiness_incomplete")
	if int(snapshot.get("catalog_key_count", 0)) != EXPECTED_ENVIRONMENT_CATALOG_KEY_COUNT:
		violations.append("environment_catalog_key_count_mismatch")
	if snapshot_expected_resource != expected_resource:
		violations.append("expected_resource_path_contract_mismatch")
	if warmed_resource != expected_resource:
		violations.append("resource_prewarm_delegation_incomplete")
	if snapshot_expected_gpu != expected_gpu:
		violations.append("expected_gpu_path_contract_mismatch")
	if submitted_gpu != expected_gpu:
		violations.append("gpu_submission_incomplete")
	if int(snapshot.get("gpu_in_bounds_path_count", 0)) != expected_gpu.size():
		violations.append("gpu_in_bounds_submission_mismatch")
	if int(snapshot.get("gpu_post_draw_flush_count", 0)) < REQUIRED_GPU_POST_DRAW_FLUSH_COUNT:
		violations.append("gpu_post_draw_flush_incomplete")
	if not bool(snapshot.get("node_pipeline_warmed", false)):
		violations.append("node_pipeline_prewarm_missing")
	if not bool(snapshot.get("minimap_pipeline_warmed", false)):
		violations.append("minimap_pipeline_prewarm_missing")
	var warmed_ids_value: Variant = snapshot.get("warmed_texture_ids", null)
	var submitted_ids_value: Variant = snapshot.get("submitted_gpu_texture_ids", null)
	if not (warmed_ids_value is Dictionary) or not (submitted_ids_value is Dictionary):
		violations.append("texture_identity_manifest_invalid")
	else:
		var warmed_ids := warmed_ids_value as Dictionary
		var submitted_ids := submitted_ids_value as Dictionary
		for path in expected_resource:
			if int(warmed_ids.get(path, 0)) == 0:
				violations.append("warmed_texture_identity_missing:%s" % path)
		for path in expected_gpu:
			if int(submitted_ids.get(path, 0)) == 0 or int(submitted_ids.get(path, 0)) != int(warmed_ids.get(path, -1)):
				violations.append("gpu_texture_identity_mismatch:%s" % path)
	var expected_steps := _static_string_array(snapshot.get("expected_step_ids", []))
	var completed_steps := _static_string_array(snapshot.get("completed_step_ids", []))
	expected_steps.sort()
	completed_steps.sort()
	if expected_steps != completed_steps:
		violations.append("prewarm_step_completion_mismatch")
	if int(snapshot.get("duplicate_step_count", 0)) != 0:
		violations.append("prewarm_step_completed_twice")
	return {"valid": violations.is_empty(), "violations": violations}


func get_debug_status() -> Dictionary:
	var cached_path_count := 0
	for path in _resource_texture_paths:
		if ProjectResourceLoader.get_cached_texture(path) != null:
			cached_path_count += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"candidate_only": true,
		"production_connected": false,
		"phase": _phase,
		"ready": _ready,
		"active": _active,
		"inside_interior": _inside_interior,
		"visible": visible,
		"lifecycle_size": size,
		"rejection_reason": _rejection_reason,
		"cache_key": _cache_key,
		"compiled_cache_count": _compiled_cache_by_key.size(),
		"compile_count": _compile_count,
		"cache_hit_count": _cache_hit_count,
		"cache_miss_count": _cache_miss_count,
		"texture_request_count": _texture_request_count,
		"texture_cache_hit_count": _texture_cache_hit_count,
		"runtime_build_count": _runtime_build_count,
		"runtime_instance_id": _runtime_instance_id if _runtime != null and is_instance_valid(_runtime) else 0,
		"return_world_position": _return_world_position,
		"return_portal_id": _return_portal_id,
		"layout_fingerprint": str((_current_record.get("layout", {}) as Dictionary).get("fingerprint", "")),
		"environment_plan_fingerprint": str((_current_record.get("plan", {}) as Dictionary).get("fingerprint", "")),
		"resource_texture_path_count": _resource_texture_paths.size(),
		"cached_resource_texture_path_count": cached_path_count,
		"gpu_texture_path_count": _gpu_texture_paths.size(),
		"gpu_post_draw_flush_count": _gpu_post_draw_flush_count,
		"cold_warning_count": _cold_warning_count,
		"phase_timings_usec": _phase_timings_usec.duplicate(true),
		"prewarm_usec": _prewarm_finished_usec - _prewarm_started_usec if _prewarm_finished_usec >= _prewarm_started_usec and _prewarm_started_usec > 0 else -1,
		"cold_prewarm_usec": _cold_prewarm_usec,
		"warm_prewarm_usec": _warm_prewarm_usec,
		"first_visible_activation_usec": _first_visible_activation_usec,
		"last_visible_activation_usec": _last_visible_activation_usec,
		"first_visible_limit_usec": FIRST_VISIBLE_R3_LIMIT_USEC,
		"activation_count": _activation_count,
		"scene_owned_node_count": _count_descendants(_runtime) if _runtime != null and is_instance_valid(_runtime) else 0,
		"scene_material_rid_count": _collect_scene_material_rids(_runtime).size() if _runtime != null and is_instance_valid(_runtime) else 0,
		"scene_texture_id_count": _collect_scene_texture_ids(_runtime).size() if _runtime != null and is_instance_valid(_runtime) else 0,
		"scene_audio_player_count": _count_nodes_of_type(_runtime, "AudioStreamPlayer") if _runtime != null and is_instance_valid(_runtime) else 0,
		"readiness": get_readiness_snapshot(),
		"runtime": _runtime.call("get_debug_status") if _runtime != null and is_instance_valid(_runtime) else {},
	}


func _validate_request(config: Dictionary) -> Dictionary:
	var stage_value: Variant = config.get("stage_id", 1)
	var seed_value: Variant = config.get("map_seed", null)
	var render_value: Variant = config.get("render_size", null)
	var insets_value: Variant = config.get("safe_insets", null)
	var minimap_value: Variant = config.get("minimap_rect", null)
	var zoom_value: Variant = config.get("camera_zoom", 1.35)
	if typeof(stage_value) != TYPE_INT or typeof(seed_value) != TYPE_INT:
		return _invalid("stage_or_seed_type_invalid")
	if not (render_value is Vector2) or not (insets_value is Dictionary) or not (minimap_value is Rect2):
		return _invalid("view_contract_type_invalid")
	var safe_insets := insets_value as Dictionary
	for inset_key in ["left", "top", "right", "bottom"]:
		if not safe_insets.has(inset_key) or not _finite_number(safe_insets.get(inset_key)) or float(safe_insets.get(inset_key)) < 0.0:
			return _invalid("safe_insets_invalid:%s" % inset_key)
	if not _finite_number(zoom_value):
		return _invalid("camera_zoom_type_invalid")
	var render_size := render_value as Vector2
	var minimap_rect := minimap_value as Rect2
	if int(stage_value) <= 0 or not render_size.is_finite() or render_size.x <= 1.0 or render_size.y <= 1.0:
		return _invalid("stage_or_render_invalid")
	if float(safe_insets.get("left")) + float(safe_insets.get("right")) >= render_size.x or float(safe_insets.get("top")) + float(safe_insets.get("bottom")) >= render_size.y:
		return _invalid("safe_insets_consume_view")
	if not _finite_rect(minimap_rect) or not minimap_rect.has_area() or not Rect2(Vector2.ZERO, render_size).encloses(minimap_rect):
		return _invalid("minimap_rect_invalid")
	var zoom := float(zoom_value)
	if zoom <= 1.0 or zoom > 2.0:
		return _invalid("camera_zoom_invalid")
	var guardian_enabled_value: Variant = config.get("guardian_enabled", true)
	if typeof(guardian_enabled_value) != TYPE_BOOL:
		return _invalid("guardian_enabled_type_invalid")
	for flag_key in ["full_layout_for_test", "force_tavern"]:
		if config.has(flag_key) and typeof(config.get(flag_key)) != TYPE_BOOL:
			return _invalid("flag_type_invalid:%s" % flag_key)
	var spawn_value: Variant = config.get("spawn_anchor", DEFAULT_SPAWN_ANCHOR)
	var exit_value: Variant = config.get("exit_zone", DEFAULT_EXIT_ZONE)
	if not (spawn_value is Vector2) or not (exit_value is Rect2):
		return _invalid("world_anchor_type_invalid")
	var spawn_anchor := spawn_value as Vector2
	var exit_zone := exit_value as Rect2
	if not spawn_anchor.is_finite() or not _finite_rect(exit_zone) or not exit_zone.has_area():
		return _invalid("world_anchor_invalid")
	if not Rect2(Vector2.ZERO, DEFAULT_WORLD_SIZE).has_point(spawn_anchor) or not Rect2(Vector2.ZERO, DEFAULT_WORLD_SIZE).encloses(exit_zone):
		return _invalid("world_anchor_outside_world")
	var guardian_style_value: Variant = config.get("guardian_locomotion_style", "ground")
	if typeof(guardian_style_value) != TYPE_STRING or str(guardian_style_value) not in ["ground", "patrol", "flight"]:
		return _invalid("guardian_locomotion_style_invalid")
	var character_value: Variant = config.get("selected_character_type", "smasher")
	var guardian_id_value: Variant = config.get("guardian_id", "onimaru")
	if typeof(character_value) != TYPE_STRING or typeof(guardian_id_value) != TYPE_STRING:
		return _invalid("actor_identity_type_invalid")
	var character_type := PlazaAssetLoader.normalize_player_character_type(character_value)
	var guardian_id := str(guardian_id_value)
	if character_type == "" or (bool(guardian_enabled_value) and LingpetCatalog.get_visual_path(guardian_id, "companion_walk") == ""):
		return _invalid("actor_identity_invalid")
	var player_position_value: Variant = config.get("initial_player_world_position", null)
	var guardian_position_value: Variant = config.get("initial_guardian_world_position", null)
	if player_position_value != null and (not (player_position_value is Vector2) or not (player_position_value as Vector2).is_finite()):
		return _invalid("initial_player_position_invalid")
	if guardian_position_value != null and (not (guardian_position_value is Vector2) or not (guardian_position_value as Vector2).is_finite()):
		return _invalid("initial_guardian_position_invalid")
	var player_policy_value: Variant = config.get("initial_player_position_policy", "spawn")
	if typeof(player_policy_value) != TYPE_STRING or str(player_policy_value) not in ["spawn", "first_portal"]:
		return _invalid("initial_player_position_policy_invalid")
	var request := config.duplicate(true)
	request["stage_id"] = int(stage_value)
	request["map_seed"] = int(seed_value)
	request["render_size"] = render_size
	request["safe_insets"] = safe_insets.duplicate(true)
	request["minimap_rect"] = minimap_rect
	request["camera_zoom"] = zoom
	request["selected_character_type"] = character_type
	request["guardian_enabled"] = bool(guardian_enabled_value)
	request["guardian_id"] = guardian_id
	request["guardian_locomotion_style"] = str(guardian_style_value)
	request["full_layout_for_test"] = bool(config.get("full_layout_for_test", false))
	request["force_tavern"] = bool(config.get("force_tavern", false))
	request["spawn_anchor"] = spawn_anchor
	request["exit_zone"] = exit_zone
	request["world_size"] = DEFAULT_WORLD_SIZE
	return {"valid": true, "request": request}


func _build_cache_key(request: Dictionary) -> String:
	return "%d:%d:%d:%d:%s:%s:%s:%s" % [
		int(request.get("stage_id", 1)),
		int(request.get("map_seed", 0)),
		1 if bool(request.get("full_layout_for_test", false)) else 0,
		1 if bool(request.get("force_tavern", false)) else 0,
		str(request.get("selected_character_type", "")),
		str(request.get("guardian_id", "")) if bool(request.get("guardian_enabled", false)) else "none",
		PlazaMapRoadSkeletonR3.GENERATOR_VERSION,
		PlazaR3EnvironmentLayoutCompiler.SCHEMA_VERSION,
	]


func _build_initial_texture_path_contract() -> void:
	_building_texture_paths = PlazaAssetLoader.get_hwangyeok_building_prewarm_texture_paths()
	_building_texture_paths.sort()
	_actor_texture_paths.clear()
	var player_paths := PlazaAssetLoader.get_player_texture_paths_for_test(_request.get("selected_character_type", "smasher"))
	for key in ["idle", "walk_left", "walk_right"]:
		_append_unique_path(_actor_texture_paths, str(player_paths.get(key, "")))
	if bool(_request.get("guardian_enabled", false)):
		_append_unique_path(_actor_texture_paths, LingpetCatalog.get_visual_path(str(_request.get("guardian_id", "")), "companion_walk"))
	_actor_texture_paths.sort()
	_interior_texture_paths.clear()
	for path_map in [
		PlazaAssetLoader.get_interior_npc_texture_paths_for_test(),
		PlazaAssetLoader.get_interior_room_texture_paths_for_test(),
		PlazaAssetLoader.get_interior_object_texture_paths_for_test(),
	]:
		for path_value in (path_map as Dictionary).values():
			_append_unique_path(_interior_texture_paths, str(path_value))
	_interior_texture_paths.sort()
	_base_texture_paths.clear()
	for path in _building_texture_paths + _actor_texture_paths + _interior_texture_paths:
		_append_unique_path(_base_texture_paths, path)
	_base_texture_paths.sort()
	_resource_texture_paths = _base_texture_paths.duplicate()
	_gpu_texture_paths.clear()
	for path in _building_texture_paths + _actor_texture_paths:
		_append_unique_path(_gpu_texture_paths, path)
	_gpu_texture_paths.sort()


func _restore_record_path_contract() -> void:
	_environment_texture_paths = _string_array(_current_record.get("environment_texture_paths", []))
	_resource_texture_paths = _string_array(_current_record.get("resource_texture_paths", []))
	_gpu_texture_paths = _string_array(_current_record.get("gpu_texture_paths", []))
	_resource_index = 0


func _advance_texture_path_list(paths: Array[String]) -> bool:
	if _resource_index >= paths.size():
		_resource_index = 0
		return true
	var path := paths[_resource_index]
	if _completed_step_lookup.has("texture:%s" % path):
		_resource_index += 1
		return _resource_index >= paths.size()
	var cached := ProjectResourceLoader.get_cached_texture(path)
	if cached != null:
		_texture_cache_hit_count += 1
		_warmed_texture_ids[path] = cached.get_instance_id()
		_record_step("texture:%s" % path)
		_resource_index += 1
		return _resource_index >= paths.size()
	if not _requested_texture_paths.has(path):
		_requested_texture_paths[path] = true
		_texture_request_count += 1
	var result := ProjectResourceLoader.prewarm_texture_threaded_step(
		path,
		"Missing R3-C plaza texture",
		"Failed to prewarm R3-C plaza texture",
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_MSEC,
		ProjectResourceLoader.THREADED_TEXTURE_PREWARM_MAX_POLLS,
		true,
		true,
		false
	)
	if not bool(result.get("done", false)):
		return false
	var texture_value: Variant = result.get("texture", null)
	if not (texture_value is Texture2D):
		return _reject("threaded_texture_prewarm_failed:%s" % path)
	var texture := texture_value as Texture2D
	_warmed_texture_ids[path] = texture.get_instance_id()
	_record_step("texture:%s" % path)
	_resource_index += 1
	return _resource_index >= paths.size()


func _compile_authoritative_record() -> bool:
	var started_usec := Time.get_ticks_usec()
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(
		int(_request.get("stage_id", 1)),
		int(_request.get("map_seed", 0)),
		bool(_request.get("full_layout_for_test", false)),
		bool(_request.get("force_tavern", false))
	)
	if specs.is_empty():
		return _reject("building_specs_empty")
	var layout := PlazaMapRoadSkeletonR3.generate(
		int(_request.get("stage_id", 1)),
		int(_request.get("map_seed", 0)),
		DEFAULT_WORLD_SIZE,
		specs,
		_request.get("spawn_anchor", DEFAULT_SPAWN_ANCHOR) as Vector2,
		_request.get("exit_zone", DEFAULT_EXIT_ZONE) as Rect2
	)
	var layout_validation := PlazaMapRoadSkeletonR3.validate_layout(layout)
	if not bool(layout_validation.get("valid", false)):
		return _reject("r3_layout_compile_failed")
	var plan := PlazaR3EnvironmentLayoutCompiler.compile_layout(layout)
	var plan_validation := PlazaR3EnvironmentLayoutCompiler.validate_plan(plan, layout, true)
	if not bool(plan_validation.get("valid", false)):
		return _reject("environment_plan_compile_failed")
	var catalog := PlazaR3EnvironmentLayoutCompiler.load_asset_catalog()
	if not bool(catalog.get("valid", false)):
		return _reject("environment_catalog_invalid")
	var catalog_key_count := (catalog.get("assets", {}) as Dictionary).size()
	if catalog_key_count != EXPECTED_ENVIRONMENT_CATALOG_KEY_COUNT:
		return _reject("environment_catalog_key_count_mismatch:%d" % catalog_key_count)
	_environment_texture_paths = _derive_environment_texture_paths(plan)
	_resource_texture_paths = _base_texture_paths.duplicate()
	for path in _environment_texture_paths:
		_append_unique_path(_resource_texture_paths, path)
	_resource_texture_paths.sort()
	_gpu_texture_paths.clear()
	for path in _building_texture_paths + _actor_texture_paths + _environment_texture_paths:
		_append_unique_path(_gpu_texture_paths, path)
	_gpu_texture_paths.sort()
	var visual_config := _build_visual_config()
	if not bool(visual_config.get("valid", false)):
		return _reject("visual_config_compile_failed")
	_current_record = {
		"layout": layout.duplicate(true),
		"plan": plan.duplicate(true),
		"visual_config": visual_config.duplicate(false),
		"environment_texture_paths": _environment_texture_paths.duplicate(),
		"resource_texture_paths": _resource_texture_paths.duplicate(),
		"gpu_texture_paths": _gpu_texture_paths.duplicate(),
		"catalog_key_count": catalog_key_count,
	}
	_compiled_cache_by_key[_cache_key] = _current_record.duplicate(true)
	_compile_count += 1
	_phase_timings_usec["layout_environment_compile"] = Time.get_ticks_usec() - started_usec
	return true


func _build_visual_config() -> Dictionary:
	for path in _building_texture_paths + _actor_texture_paths:
		if ProjectResourceLoader.get_cached_texture(path) == null:
			return _invalid("visual_texture_not_cached:%s" % path)
	var player_textures := PlazaAssetLoader.load_player_textures(_request.get("selected_character_type", "smasher"))
	if not bool(player_textures.get("has_sprite", false)):
		return _invalid("player_texture_set_invalid")
	var result := {
		"valid": true,
		"player_textures": player_textures,
		"guardian_enabled": bool(_request.get("guardian_enabled", false)),
	}
	if bool(_request.get("guardian_enabled", false)):
		var guardian_id := str(_request.get("guardian_id", ""))
		var guardian_path := LingpetCatalog.get_visual_path(guardian_id, "companion_walk")
		var guardian_texture := ProjectResourceLoader.get_cached_texture(guardian_path)
		if guardian_texture == null:
			return _invalid("guardian_texture_not_cached")
		result["guardian_texture"] = guardian_texture
		result["guardian_grid_cols"] = roundi(LingpetCatalog.get_visual_layout_value(guardian_id, "companion_walk_cols", 5.0))
		result["guardian_grid_rows"] = roundi(LingpetCatalog.get_visual_layout_value(guardian_id, "companion_walk_rows", 5.0))
		result["guardian_frame_count"] = roundi(LingpetCatalog.get_visual_layout_value(guardian_id, "companion_walk_frame_count", 25.0))
		result["guardian_draw_size_world"] = LingpetCatalog.get_visual_layout_value(guardian_id, "companion_walk_draw_size", 92.0)
	return result


func _build_hidden_runtime() -> bool:
	for path in _resource_texture_paths:
		var texture := ProjectResourceLoader.get_cached_texture(path)
		if texture == null:
			return _reject("runtime_bind_texture_not_cached:%s" % path)
		_warmed_texture_ids[path] = texture.get_instance_id()
	var started_new_usec := Time.get_ticks_usec()
	_runtime = PlazaR3ExteriorRuntimeCandidate.new()
	_record_cold_module_timing("plaza_r3_exterior_runtime_candidate", Time.get_ticks_usec() - started_new_usec)
	_runtime.name = "R3ExteriorRuntime"
	_runtime_instance_id = _runtime.get_instance_id()
	_ensure_gpu_viewport()
	_gpu_viewport.add_child(_runtime)
	var layout := _current_record.get("layout", {}) as Dictionary
	var initial_player := _resolve_initial_player_world(layout)
	var initial_guardian := initial_player
	if _request.get("initial_guardian_world_position", null) is Vector2:
		initial_guardian = _request.get("initial_guardian_world_position") as Vector2
	var runtime_config := {
		"composition_approval_id": PlazaR3ExteriorRuntimeCandidate.ENVIRONMENT_COMPOSITION_APPROVAL_ID,
		"layout": layout,
		"environment_plan": _current_record.get("plan", {}),
		"render_size": _request.get("render_size", Vector2.ZERO),
		"safe_insets": _request.get("safe_insets", {}),
		"minimap_rect": _request.get("minimap_rect", Rect2()),
		"camera_zoom": _request.get("camera_zoom", 1.35),
		"ticks_msec": int(_request.get("ticks_msec", 0)),
		"initial_player_world_position": initial_player,
		"initial_guardian_world_position": initial_guardian,
		"guardian_locomotion_style": str(_request.get("guardian_locomotion_style", "ground")),
		"visual_config": _current_record.get("visual_config", {}),
	}
	var started_bind_usec := Time.get_ticks_usec()
	if not bool(_runtime.call("bind_candidate", runtime_config)):
		var runtime_status := _runtime.call("get_debug_status") as Dictionary
		return _reject("hidden_runtime_bind_failed:%s" % str(runtime_status.get("rejection_reason", "")))
	_phase_timings_usec["hidden_runtime_bind"] = Time.get_ticks_usec() - started_bind_usec
	var runtime_status := _runtime.call("get_debug_status") as Dictionary
	var minimap_status := runtime_status.get("minimap", {}) as Dictionary
	_node_pipeline_warmed = _count_descendants(_runtime) > 0
	_minimap_pipeline_warmed = int(minimap_status.get("successful_sync_count", 0)) > 0
	_runtime.call("set_active", false)
	_runtime_build_count += 1
	return true


func _resolve_initial_player_world(layout: Dictionary) -> Vector2:
	if _request.get("initial_player_world_position", null) is Vector2:
		return _request.get("initial_player_world_position") as Vector2
	if str(_request.get("initial_player_position_policy", "spawn")) == "first_portal":
		var portals := _dictionary_array(layout.get("interaction_portals", []))
		if not portals.is_empty():
			var polygon := _packed_polygon(portals[0].get("polygon_world", []))
			var candidate := _polygon_average(polygon)
			var binding := PlazaR3NavigationBinding.bind_layout(layout, str(layout.get("fingerprint", "")))
			if bool(binding.get("valid", false)):
				if PlazaMapNavigation.can_occupy(binding, candidate, true):
					return candidate
				var aabb := _polygon_aabb(polygon)
				for y in range(ceili(aabb.position.y), floori(aabb.end.y) + 1, 2):
					for x in range(ceili(aabb.position.x), floori(aabb.end.x) + 1, 2):
						var point := Vector2(float(x), float(y))
						if Geometry2D.is_point_in_polygon(point, polygon) and PlazaMapNavigation.can_occupy(binding, point, true):
							return point
	return layout.get("spawn_anchor", DEFAULT_SPAWN_ANCHOR) as Vector2


func _ensure_gpu_viewport() -> void:
	if _gpu_viewport != null and is_instance_valid(_gpu_viewport):
		return
	_gpu_viewport = SubViewport.new()
	_gpu_viewport.name = "R3GpuPrewarmViewport"
	var requested_size := _request.get("render_size", Vector2(2020.0, 1246.0)) as Vector2
	_gpu_viewport.size = Vector2i(maxi(512, roundi(requested_size.x)), maxi(512, roundi(requested_size.y)))
	_gpu_viewport.transparent_bg = true
	_gpu_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_gpu_viewport)


func _start_gpu_submission() -> bool:
	if _runtime == null or not is_instance_valid(_runtime) or _gpu_viewport == null:
		return _reject("gpu_submission_runtime_missing")
	_gpu_reused = false
	_gpu_canvas_layer = CanvasLayer.new()
	_gpu_canvas_layer.name = "TextureSubmissionLayer"
	_gpu_canvas_layer.layer = 100
	_gpu_viewport.add_child(_gpu_canvas_layer)
	_gpu_grid_root = Node2D.new()
	_gpu_grid_root.name = "TextureSubmissionGrid"
	_gpu_canvas_layer.add_child(_gpu_grid_root)
	_gpu_mix_material = CanvasItemMaterial.new()
	_gpu_mix_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_gpu_add_material = CanvasItemMaterial.new()
	_gpu_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_gpu_sprite_by_path.clear()
	_gpu_submitted_texture_ids.clear()
	_gpu_in_bounds_path_count = 0
	var columns := maxi(1, floori(float(_gpu_viewport.size.x) / 36.0))
	for index in range(_gpu_texture_paths.size()):
		var path := _gpu_texture_paths[index]
		var texture := ProjectResourceLoader.get_cached_texture(path)
		if texture == null:
			return _reject("gpu_submission_texture_not_cached:%s" % path)
		var sprite := Sprite2D.new()
		sprite.name = "Warm_%03d" % index
		sprite.texture = texture
		sprite.centered = true
		var extent := maxf(1.0, maxf(float(texture.get_width()), float(texture.get_height())))
		sprite.scale = Vector2.ONE * (GPU_CELL_EXTENT / extent)
		var column := index % columns
		var row := floori(float(index) / float(columns))
		sprite.position = Vector2(18.0 + float(column) * 36.0, 18.0 + float(row) * 36.0)
		sprite.material = _gpu_add_material if ("emissive" in path or "glow" in path) else _gpu_mix_material
		sprite.set_meta("texture_path", path)
		_gpu_grid_root.add_child(sprite)
		_gpu_sprite_by_path[path] = sprite
		if Rect2(Vector2.ZERO, Vector2(_gpu_viewport.size)).has_point(sprite.position):
			_gpu_in_bounds_path_count += 1
	_runtime.call("set_active", true)
	_gpu_post_draw_flush_count = 0
	_record_step("gpu_submit")
	if not RenderingServer.frame_post_draw.is_connected(_on_gpu_frame_post_draw):
		RenderingServer.frame_post_draw.connect(_on_gpu_frame_post_draw)
		_gpu_signal_connected = true
	return true


func _on_gpu_frame_post_draw() -> void:
	if _phase != PHASE_GPU_SUBMIT:
		return
	if _gpu_post_draw_flush_count >= REQUIRED_GPU_POST_DRAW_FLUSH_COUNT:
		return
	_gpu_post_draw_flush_count += 1
	_record_step("gpu_flush:%d" % _gpu_post_draw_flush_count)


func _finish_gpu_submission() -> bool:
	for path in _gpu_texture_paths:
		var sprite_value: Variant = _gpu_sprite_by_path.get(path, null)
		if not (sprite_value is Sprite2D):
			return _reject("gpu_submission_sprite_missing:%s" % path)
		var sprite := sprite_value as Sprite2D
		if sprite.texture == null:
			return _reject("gpu_submission_texture_missing:%s" % path)
		_gpu_submitted_texture_ids[path] = sprite.texture.get_instance_id()
	var gpu_ids := _current_gpu_texture_ids()
	if _gpu_submitted_texture_ids != gpu_ids:
		return _reject("gpu_submission_texture_identity_mismatch")
	_gpu_warm_texture_ids_by_key[_cache_key] = gpu_ids.duplicate(true)
	return _finish_ready_state()


func _finish_ready_state() -> bool:
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.call("set_active", false)
		if _runtime.get_parent() == _gpu_viewport:
			_gpu_viewport.remove_child(_runtime)
			add_child(_runtime)
	_cleanup_gpu_viewport()
	_ready = true
	_active = false
	_inside_interior = false
	visible = false
	_phase = PHASE_READY
	_prewarm_finished_usec = Time.get_ticks_usec()
	var elapsed := _prewarm_finished_usec - _prewarm_started_usec
	if _gpu_reused:
		_warm_prewarm_usec = elapsed
	else:
		_cold_prewarm_usec = elapsed
	var snapshot := get_readiness_snapshot()
	var validation := validate_readiness_snapshot(snapshot, _resource_texture_paths, _gpu_texture_paths)
	if not bool(validation.get("valid", false)):
		_ready = false
		return _reject("readiness_evidence_invalid:%s" % ",".join(_static_string_array(validation.get("violations", []))))
	_rejection_reason = ""
	return true


func _can_reuse_gpu_warm_contract() -> bool:
	if not _gpu_warm_texture_ids_by_key.has(_cache_key):
		return false
	var stored_value: Variant = _gpu_warm_texture_ids_by_key.get(_cache_key, null)
	if not (stored_value is Dictionary):
		return false
	return (stored_value as Dictionary) == _current_gpu_texture_ids()


func _current_gpu_texture_ids() -> Dictionary:
	var ids: Dictionary = {}
	for path in _gpu_texture_paths:
		var texture := ProjectResourceLoader.get_cached_texture(path)
		if texture != null:
			ids[path] = texture.get_instance_id()
	return ids


func _derive_environment_texture_paths(plan: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	var ground := plan.get("ground_draw", {}) as Dictionary
	_append_unique_path(paths, str(ground.get("texture_path", "")))
	for key in ["road_draws", "plot_pad_draws", "decor_draws"]:
		for record in _dictionary_array(plan.get(key, [])):
			_append_unique_path(paths, str(record.get("texture_path", "")))
	paths.sort()
	return paths


func _expected_step_ids() -> Array[String]:
	var result: Array[String] = []
	for path in _resource_texture_paths:
		result.append("texture:%s" % path)
	result.append("compile_or_restore")
	result.append("runtime_bind")
	result.append("gpu_submit")
	result.append("gpu_flush:1")
	result.append("gpu_flush:2")
	return result


func _record_step(step_id: String) -> void:
	if _completed_step_lookup.has(step_id):
		_duplicate_step_count += 1
		return
	_completed_step_lookup[step_id] = true
	_completed_step_ids.append(step_id)


func _record_cold_module_timing(module_key: String, elapsed_usec: int) -> void:
	_phase_timings_usec["module:%s" % module_key] = elapsed_usec
	if elapsed_usec < COLD_INSTANTIATE_WARNING_USEC:
		return
	_cold_warning_count += 1
	push_warning("[PrewarmColdInstantiate] module '%s' first-fetch %.1fms" % [module_key, float(elapsed_usec) / 1000.0])


func _layout_has_portal(portal_id: String) -> bool:
	var layout := _current_record.get("layout", {}) as Dictionary
	for portal in _dictionary_array(layout.get("interaction_portals", [])):
		if str(portal.get("id", "")) == portal_id:
			return true
	return false


func _compiled_navigation_can_occupy(world_position: Vector2) -> bool:
	if _runtime == null or not is_instance_valid(_runtime):
		return false
	var compiled_value: Variant = _runtime.call("get_compiled_navigation_for_test")
	return compiled_value is Object and bool((compiled_value as Object).call("can_occupy", world_position, true))


func _teardown_runtime_only() -> void:
	_cleanup_gpu_viewport()
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.call("clear_transient_canvas_items")
		if _runtime.get_parent() != null:
			_runtime.get_parent().remove_child(_runtime)
		_runtime.free()
	_runtime = null
	_runtime_instance_id = 0


func _cleanup_gpu_viewport() -> void:
	if _gpu_signal_connected and RenderingServer.frame_post_draw.is_connected(_on_gpu_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_gpu_frame_post_draw)
	_gpu_signal_connected = false
	_gpu_sprite_by_path.clear()
	_gpu_grid_root = null
	_gpu_canvas_layer = null
	_gpu_mix_material = null
	_gpu_add_material = null
	if _gpu_viewport != null and is_instance_valid(_gpu_viewport):
		if _runtime != null and is_instance_valid(_runtime) and _runtime.get_parent() == _gpu_viewport:
			_gpu_viewport.remove_child(_runtime)
		# The normal ready path reparents the runtime before cleanup. The viewport
		# still owns submission sprites/material RIDs and must be destroyed even
		# when it no longer owns the runtime; otherwise those GPU helper resources
		# can survive until process exit as an intermittent RefCounted leak.
		if _gpu_viewport.get_parent() != null:
			_gpu_viewport.get_parent().remove_child(_gpu_viewport)
		_gpu_viewport.free()
	_gpu_viewport = null


func _reset_session_state() -> void:
	_phase = PHASE_IDLE
	_rejection_reason = ""
	_request.clear()
	_cache_key = ""
	_current_record.clear()
	_base_texture_paths.clear()
	_environment_texture_paths.clear()
	_building_texture_paths.clear()
	_actor_texture_paths.clear()
	_interior_texture_paths.clear()
	_resource_texture_paths.clear()
	_gpu_texture_paths.clear()
	_resource_index = 0
	_requested_texture_paths.clear()
	_warmed_texture_ids.clear()
	_completed_step_ids.clear()
	_completed_step_lookup.clear()
	_duplicate_step_count = 0
	_gpu_submitted_texture_ids.clear()
	_gpu_in_bounds_path_count = 0
	_gpu_post_draw_flush_count = 0
	_gpu_reused = false
	_minimap_pipeline_warmed = false
	_node_pipeline_warmed = false
	_ready = false
	_active = false
	_inside_interior = false
	_return_world_position = Vector2.INF
	_return_portal_id = ""
	_prewarm_started_usec = 0
	_prewarm_finished_usec = 0


func _collect_scene_texture_ids(node: Node) -> Dictionary:
	var result: Dictionary = {}
	if node == null or not is_instance_valid(node):
		return result
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Sprite2D:
			var texture := (current as Sprite2D).texture
			if texture != null:
				result[str(texture.get_instance_id())] = true
		for child in current.get_children():
			if child is Node:
				stack.append(child as Node)
	return result


func _collect_scene_material_rids(node: Node) -> Dictionary:
	var result: Dictionary = {}
	if node == null or not is_instance_valid(node):
		return result
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is CanvasItem:
			var material := (current as CanvasItem).material
			if material != null:
				result[str(material.get_rid().get_id())] = true
		for child in current.get_children():
			if child is Node:
				stack.append(child as Node)
	return result


func _count_descendants(node: Node) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var total := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			if child is Node:
				total += 1
				stack.append(child as Node)
	return total


func _count_nodes_of_type(node: Node, type_name: String) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var total := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current.is_class(type_name):
			total += 1
		for child in current.get_children():
			if child is Node:
				stack.append(child as Node)
	return total


func _append_unique_path(target: Array[String], path: String) -> void:
	if path != "" and not target.has(path):
		target.append(path)


func _sorted_dictionary_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in value.keys():
		result.append(str(key_value))
	result.sort()
	return result


func _string_array(value: Variant) -> Array[String]:
	return _static_string_array(value)


static func _static_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			if item is String:
				result.append(item as String)
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value as Array:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _packed_polygon(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return value as PackedVector2Array
	var result := PackedVector2Array()
	if value is Array:
		for item in value as Array:
			if item is Vector2:
				result.append(item as Vector2)
	return result


func _polygon_average(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.INF
	var total := Vector2.ZERO
	for point in polygon:
		total += point
	return total / float(polygon.size())


func _polygon_aabb(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


func _finite_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite()


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func _soft_reject(reason: String) -> bool:
	_rejection_reason = reason
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.call("set_active", false)
	_active = false
	visible = false
	return false


func _reject(reason: String) -> bool:
	_rejection_reason = reason
	_ready = false
	_active = false
	visible = false
	_phase = PHASE_REJECTED
	if _runtime != null and is_instance_valid(_runtime):
		_runtime.call("set_active", false)
	return false
