extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaR3LifecyclePrewarmCandidate := preload("res://scripts/plaza/plaza_r3_lifecycle_prewarm_candidate.gd")

const VIEW_SIZE := Vector2(2020.0, 1246.0)
const SAFE_INSETS := {"left": 72.0, "top": 72.0, "right": 360.0, "bottom": 120.0}
const MINIMAP_RECT := Rect2(1690.0, 80.0, 250.0, 174.0)
const EXPECTED_COMPLETED_LEGS := 6
const MAX_PREWARM_STEPS := 12_000
const MIN_ASSERTIONS_BY_LEG := {
	"cold_prewarm": 28,
	"counterproofs": 18,
	"roundtrip_lifecycle": 55,
	"reentry_determinism": 18,
	"owner_cadence": 700,
	"teardown_isolation": 16,
}

var _failures: Array[String] = []
var _assertion_count := 0
var _legs_completed := 0
var _leg_assertion_counts: Dictionary = {}
var _visual_expected_resource_paths: Array[String] = []
var _visual_expected_gpu_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectResourceLoader.clear_caches()
	PlazaAssetLoader.reset_for_test()
	var lifecycle := PlazaR3LifecyclePrewarmCandidate.new()
	lifecycle.name = "PlazaR3CLifecyclePrewarmSmoke"
	root.add_child(lifecycle)
	await _verify_cold_prewarm(lifecycle)
	var cold_status := lifecycle.call("get_debug_status") as Dictionary
	if not bool(cold_status.get("ready", false)):
		if is_instance_valid(lifecycle):
			lifecycle.free()
		_finish()
		return
	_verify_counterproofs(lifecycle)
	_verify_roundtrip_lifecycle(lifecycle)
	await _verify_reentry_determinism(lifecycle)
	_verify_owner_cadence(lifecycle)
	await _verify_teardown_isolation(lifecycle)
	if is_instance_valid(lifecycle):
		lifecycle.free()
		lifecycle = null
	await process_frame
	await process_frame
	PlazaAssetLoader.reset_for_test()
	ProjectResourceLoader.clear_caches()
	for _dispose_frame in range(120):
		await process_frame
	_finish()


func _verify_cold_prewarm(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var config := _build_config(4)
	_expect(bool(lifecycle.call("begin_prewarm", config)), "cold prewarm request must be accepted")
	var completed := await _drive_prewarm(lifecycle)
	_expect(completed, "cold prewarm must complete within the bounded step budget")
	var status := lifecycle.call("get_debug_status") as Dictionary
	var readiness := lifecycle.call("get_readiness_snapshot") as Dictionary
	var layout := lifecycle.call("get_layout_snapshot_for_test") as Dictionary
	var plan := lifecycle.call("get_environment_plan_snapshot_for_test") as Dictionary
	_visual_expected_resource_paths = _derive_expected_resource_paths(plan, config)
	_visual_expected_gpu_paths = _derive_expected_gpu_paths(plan, config)
	var validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(
		readiness,
		_visual_expected_resource_paths,
		_visual_expected_gpu_paths
	)
	_expect(bool(status.get("ready", false)), "cold lifecycle owner must report ready")
	_expect(str(status.get("phase", "")) == "ready", "cold lifecycle phase must stop at ready")
	_expect(not bool(status.get("active", true)), "prewarmed runtime must remain hidden")
	_expect(not bool(status.get("visible", true)), "candidate owner must remain invisible before activation")
	_expect((status.get("lifecycle_size", Vector2.ZERO) as Vector2).is_equal_approx((config.get("render_size", Vector2.ZERO) as Vector2)), "hidden lifecycle owner must already own the full render extent")
	_expect(bool(validation.get("valid", false)), "independent readiness validation must pass: %s" % validation)
	_expect(int(readiness.get("catalog_key_count", 0)) == 25, "environment catalog must retain all 25 keys")
	_expect((readiness.get("building_texture_paths", []) as Array).size() == 21, "building prewarm must cover 21 retained layers")
	_expect((readiness.get("environment_texture_paths", []) as Array).size() > 0, "seed-derived environment path set must be non-empty")
	_expect((readiness.get("actor_texture_paths", []) as Array).size() == 4, "selected player and guardian must contribute four actor textures")
	_expect((readiness.get("interior_texture_paths", []) as Array).size() > 0, "interior roundtrip resources must be included")
	_expect((readiness.get("warmed_resource_paths", []) as Array).size() == _visual_expected_resource_paths.size(), "warm path count must equal the independent resource set")
	_expect((readiness.get("submitted_gpu_paths", []) as Array).size() == _visual_expected_gpu_paths.size(), "GPU submission path count must equal the independent visible set")
	_expect(int(readiness.get("gpu_in_bounds_path_count", 0)) == _visual_expected_gpu_paths.size(), "every GPU texture must be submitted in bounds")
	_expect(int(readiness.get("gpu_post_draw_flush_count", 0)) >= 2, "GPU readiness must wait for two post-draw flushes")
	_expect(not bool(readiness.get("gpu_reused", true)), "first process-local prewarm must perform a real GPU submission")
	_expect(bool(readiness.get("node_pipeline_warmed", false)), "actual R3 runtime node pipeline must be built")
	_expect(bool(readiness.get("minimap_pipeline_warmed", false)), "actual minimap pipeline must sync during prewarm")
	_expect(int(readiness.get("duplicate_step_count", -1)) == 0, "prewarm steps must complete exactly once")
	_expect((readiness.get("completed_step_ids", []) as Array).size() == (readiness.get("expected_step_ids", []) as Array).size(), "prewarm step ledger must be exact")
	_expect(int(status.get("compile_count", 0)) == 1, "cold key must compile exactly once")
	_expect(int(status.get("cache_miss_count", 0)) == 1, "cold key must record exactly one cache miss")
	_expect(int(status.get("cache_hit_count", 0)) == 0, "cold key must not claim a compiled cache hit")
	_expect(int(status.get("texture_request_count", 0)) > 0, "fresh process must issue real threaded texture requests")
	_expect(int(status.get("cached_resource_texture_path_count", 0)) == _visual_expected_resource_paths.size(), "all expected resource paths must be in the project cache")
	_expect(int(status.get("cold_warning_count", -1)) == 0, "60ms module cold-instantiation warning count must remain zero")
	_expect(int(status.get("scene_owned_node_count", 0)) > 0, "hidden retained runtime must own a non-empty node tree")
	_expect(int(status.get("scene_material_rid_count", 0)) > 0, "hidden retained runtime must own material RIDs")
	_expect(int(status.get("scene_texture_id_count", 0)) > 0, "hidden retained runtime must own real textures")
	_expect(int(status.get("scene_audio_player_count", -1)) == 0, "R3 exterior candidate must not allocate detached audio players")
	_expect(str(layout.get("fingerprint", "")).length() == 64, "compiled layout fingerprint must be sealed")
	_expect(str(plan.get("fingerprint", "")).length() == 64, "compiled environment plan fingerprint must be sealed")
	_expect(bool(lifecycle.call("activate_exterior")), "first visible activation must pass")
	status = lifecycle.call("get_debug_status") as Dictionary
	_expect(int(status.get("first_visible_activation_usec", 99_999)) <= 2_000, "first visible R3 work must stay within 2ms")
	_expect(bool(status.get("active", false)) and bool(status.get("visible", false)), "activation must expose the prebuilt runtime")
	_expect((status.get("lifecycle_size", Vector2.ZERO) as Vector2).is_equal_approx((config.get("render_size", Vector2.ZERO) as Vector2)), "activation must preserve the full unclipped render extent")
	_complete_leg("cold_prewarm", assertion_start)


func _verify_counterproofs(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var baseline := lifecycle.call("get_readiness_snapshot") as Dictionary
	var baseline_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(
		baseline,
		_visual_expected_resource_paths,
		_visual_expected_gpu_paths
	)
	_expect(bool(baseline_validation.get("valid", false)), "counterproof baseline must be GREEN")

	var missing_delegation := baseline.duplicate(true)
	var warmed := (missing_delegation.get("warmed_resource_paths", []) as Array).duplicate()
	_expect(not warmed.is_empty(), "delegation counterproof needs a non-empty warm path set")
	warmed.pop_back()
	missing_delegation["warmed_resource_paths"] = warmed
	var missing_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(missing_delegation, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(missing_validation.get("valid", true)), "removing one delegated resource must be RED")
	_expect(_violations_have(missing_validation, "resource_prewarm_delegation_incomplete"), "delegation RED must name the missing delegation")

	var omitted_step := baseline.duplicate(true)
	var steps := (omitted_step.get("completed_step_ids", []) as Array).duplicate()
	_expect(steps.has("runtime_bind"), "step counterproof must begin with runtime_bind evidence")
	steps.erase("runtime_bind")
	omitted_step["completed_step_ids"] = steps
	var step_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(omitted_step, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(step_validation.get("valid", true)), "omitting a completed prewarm step must be RED")
	_expect(_violations_have(step_validation, "prewarm_step_completion_mismatch"), "step omission RED must name the completion mismatch")

	var missing_gpu := baseline.duplicate(true)
	missing_gpu["gpu_post_draw_flush_count"] = 1
	var gpu_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(missing_gpu, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(gpu_validation.get("valid", true)), "one post-draw flush must be RED")
	_expect(_violations_have(gpu_validation, "gpu_post_draw_flush_incomplete"), "GPU omission RED must name the flush")

	var missing_gpu_path := baseline.duplicate(true)
	var submitted := (missing_gpu_path.get("submitted_gpu_paths", []) as Array).duplicate()
	_expect(not submitted.is_empty(), "GPU path counterproof needs a non-empty submission set")
	submitted.pop_back()
	missing_gpu_path["submitted_gpu_paths"] = submitted
	var gpu_path_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(missing_gpu_path, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(gpu_path_validation.get("valid", true)), "omitting one GPU texture submission must be RED")
	_expect(_violations_have(gpu_path_validation, "gpu_submission_incomplete"), "GPU path RED must name submission incompleteness")

	var identity_drift := baseline.duplicate(true)
	var submitted_ids := (identity_drift.get("submitted_gpu_texture_ids", {}) as Dictionary).duplicate(true)
	var first_gpu_path := _visual_expected_gpu_paths[0]
	submitted_ids[first_gpu_path] = 0
	identity_drift["submitted_gpu_texture_ids"] = submitted_ids
	var identity_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(identity_drift, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(identity_validation.get("valid", true)), "GPU texture identity drift must be RED")
	_expect(_violations_have(identity_validation, "gpu_texture_identity_mismatch"), "identity drift RED must name the affected path")

	var duplicate_step := baseline.duplicate(true)
	duplicate_step["duplicate_step_count"] = 1
	var duplicate_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(duplicate_step, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(duplicate_validation.get("valid", true)), "duplicate step completion must be RED")
	_expect(_violations_have(duplicate_validation, "prewarm_step_completed_twice"), "duplicate completion RED must be explicit")

	var boundary_drift := baseline.duplicate(true)
	boundary_drift["production_connected"] = true
	var boundary_validation := PlazaR3LifecyclePrewarmCandidate.validate_readiness_snapshot(boundary_drift, _visual_expected_resource_paths, _visual_expected_gpu_paths)
	_expect(not bool(boundary_validation.get("valid", true)), "candidate production connection must be RED before R3-D")
	_expect(_violations_have(boundary_validation, "candidate_boundary_invalid"), "boundary RED must name candidate isolation")
	_complete_leg("counterproofs", assertion_start)


func _verify_roundtrip_lifecycle(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var status := lifecycle.call("get_debug_status") as Dictionary
	var runtime := lifecycle.call("get_runtime_for_test") as Control
	_expect(runtime != null and is_instance_valid(runtime), "roundtrip fixture must retain the actual runtime")
	var runtime_id := runtime.get_instance_id()
	var baseline_nodes := int(status.get("scene_owned_node_count", 0))
	var baseline_materials := int(status.get("scene_material_rid_count", 0))
	var baseline_textures := int(status.get("scene_texture_id_count", 0))
	for cycle in range(5):
		var interaction := runtime.call("try_interact") as Dictionary
		_expect(bool(interaction.get("valid", false)), "cycle %d must hit a real building portal" % cycle)
		_expect(str(interaction.get("interaction_kind", "")) == "building", "cycle %d must enter a building" % cycle)
		_expect(bool(lifecycle.call("enter_interior", interaction)), "cycle %d interior entry must succeed" % cycle)
		status = lifecycle.call("get_debug_status") as Dictionary
		_expect(bool(status.get("inside_interior", false)) and not bool(status.get("active", true)), "cycle %d must hide exterior during interior" % cycle)
		_expect(int(status.get("runtime_instance_id", 0)) == runtime_id, "cycle %d must preserve runtime identity in interior" % cycle)
		_expect(int(status.get("scene_owned_node_count", 0)) == baseline_nodes, "cycle %d must preserve the retained node plateau" % cycle)
		_expect(not bool(lifecycle.call("return_from_interior", Vector2(-500.0, -500.0))), "cycle %d invalid return must fail closed" % cycle)
		status = lifecycle.call("get_debug_status") as Dictionary
		_expect(bool(status.get("inside_interior", false)) and not bool(status.get("visible", true)), "cycle %d invalid return must remain hidden" % cycle)
		_expect(bool(lifecycle.call("return_from_interior")), "cycle %d valid portal return must reactivate" % cycle)
		status = lifecycle.call("get_debug_status") as Dictionary
		_expect(bool(status.get("active", false)) and not bool(status.get("inside_interior", true)), "cycle %d must return to exterior" % cycle)
		_expect(int(status.get("runtime_instance_id", 0)) == runtime_id, "cycle %d return must keep the same runtime instance" % cycle)
	_expect(int(status.get("scene_owned_node_count", 0)) == baseline_nodes, "five roundtrips must not grow scene nodes")
	_expect(int(status.get("scene_material_rid_count", 0)) == baseline_materials, "five roundtrips must not grow material RIDs")
	_expect(int(status.get("scene_texture_id_count", 0)) == baseline_textures, "five roundtrips must not grow scene texture identities")
	_expect(int(status.get("scene_audio_player_count", -1)) == 0, "five roundtrips must not create detached audio players")
	_complete_leg("roundtrip_lifecycle", assertion_start)


func _verify_reentry_determinism(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var first_status := lifecycle.call("get_debug_status") as Dictionary
	var first_layout_fingerprint := str(first_status.get("layout_fingerprint", ""))
	var first_plan_fingerprint := str(first_status.get("environment_plan_fingerprint", ""))
	var first_compile_count := int(first_status.get("compile_count", 0))
	var first_request_count := int(first_status.get("texture_request_count", 0))
	var first_runtime_id := int(first_status.get("runtime_instance_id", 0))
	lifecycle.call("teardown_scene")
	var torn := lifecycle.call("get_debug_status") as Dictionary
	_expect(int(torn.get("scene_owned_node_count", -1)) == 0, "scene teardown must remove every runtime node")
	_expect(int(torn.get("scene_material_rid_count", -1)) == 0, "scene teardown must release every scene material RID")
	_expect(int(torn.get("scene_texture_id_count", -1)) == 0, "scene teardown must release every scene sprite reference")
	_expect(int(torn.get("scene_audio_player_count", -1)) == 0, "scene teardown must leave no audio players")
	_expect(bool(lifecycle.call("begin_prewarm", _build_config(4))), "same-key reentry request must be accepted")
	_expect(await _drive_prewarm(lifecycle), "same-key warm reentry must complete")
	var warm_status := lifecycle.call("get_debug_status") as Dictionary
	_expect(int(warm_status.get("compile_count", 0)) == first_compile_count, "same key must not recompile layout or environment")
	_expect(int(warm_status.get("texture_request_count", 0)) == first_request_count, "same key must not issue another texture load request")
	_expect(int(warm_status.get("cache_hit_count", 0)) >= 1, "same key must record a compiled cache hit")
	_expect(str(warm_status.get("layout_fingerprint", "")) == first_layout_fingerprint, "same key must reproduce layout fingerprint")
	_expect(str(warm_status.get("environment_plan_fingerprint", "")) == first_plan_fingerprint, "same key must reproduce environment fingerprint")
	_expect(int(warm_status.get("runtime_instance_id", 0)) != first_runtime_id, "full scene teardown must create a new scene-owned runtime")
	_expect(int(warm_status.get("warm_prewarm_usec", -1)) > 0, "warm reentry time must be recorded")
	_expect(int(warm_status.get("cold_prewarm_usec", -1)) > 0, "cold entry time must remain recorded")
	_expect(int(warm_status.get("warm_prewarm_usec", 9_999_999)) <= int(warm_status.get("cold_prewarm_usec", -1)), "warm entry must not be slower than cold entry")
	_expect(bool(lifecycle.call("activate_exterior")), "warm same-key runtime must activate")
	lifecycle.call("teardown_scene")
	var changed_config := _build_config(12)
	_expect(bool(lifecycle.call("begin_prewarm", changed_config)), "changed-key request must be accepted")
	_expect(await _drive_prewarm(lifecycle), "changed-key prewarm must complete")
	var changed_status := lifecycle.call("get_debug_status") as Dictionary
	_expect(int(changed_status.get("compile_count", 0)) == first_compile_count + 1, "changed seed must compile a new authoritative record")
	_expect(int(changed_status.get("cache_miss_count", 0)) >= 2, "changed seed must record a cache miss")
	_expect(str(changed_status.get("layout_fingerprint", "")) != first_layout_fingerprint, "changed seed must not reuse the old layout fingerprint")
	_expect(str(changed_status.get("environment_plan_fingerprint", "")) != first_plan_fingerprint, "changed seed must not reuse the old environment fingerprint")
	_expect(bool(lifecycle.call("activate_exterior")), "changed-key runtime must activate")
	_complete_leg("reentry_determinism", assertion_start)


func _verify_owner_cadence(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	for tick_index in range(720):
		var phase := tick_index % 240
		var direction := Vector2.RIGHT if phase < 60 else Vector2.DOWN if phase < 120 else Vector2.LEFT if phase < 180 else Vector2.UP
		var result := lifecycle.call("tick_exterior", direction, 1.0 / 60.0, tick_index * 17) as Dictionary
		_expect(bool(result.get("valid", false)), "owner cadence tick %d must remain valid" % tick_index)
	var runtime := lifecycle.call("get_runtime_for_test") as Control
	var metrics := runtime.call("get_owner_cadence_metrics") as Dictionary
	_expect(int(metrics.get("sample_count", 0)) == 600, "owner cadence must retain exactly 600 steady samples")
	_expect(float(metrics.get("p95_usec", 99_999.0)) < 2_000.0, "post-roundtrip owner cadence p95 must remain below 2ms: %s" % metrics)
	_expect(bool(metrics.get("within_limit", false)), "owner cadence owner must report the fixed limit as GREEN")
	_complete_leg("owner_cadence", assertion_start)


func _verify_teardown_isolation(lifecycle: Control) -> void:
	var assertion_start := _assertion_count
	var plaza_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var owner_path := "plaza_r3_lifecycle_prewarm_candidate"
	_expect(plaza_source != "", "production plaza source must be readable")
	_expect(project_source != "", "project config must be readable")
	_expect(owner_path not in plaza_source, "plaza_scene.gd must not reference R3-C before R3-D")
	_expect(owner_path not in project_source, "project.godot must not reference R3-C before R3-D")
	var scene_reference_count := 0
	for filename in DirAccess.get_files_at("res://scenes"):
		if filename.ends_with(".tscn"):
			var text := FileAccess.get_file_as_string("res://scenes/%s" % filename)
			if owner_path in text:
				scene_reference_count += 1
	_expect(scene_reference_count == 0, "production scenes must retain zero R3-C references")
	var before := lifecycle.call("get_debug_status") as Dictionary
	_expect(bool(before.get("active", false)), "teardown isolation leg must begin from active exterior")
	lifecycle.call("teardown_scene")
	await process_frame
	var after := lifecycle.call("get_debug_status") as Dictionary
	_expect(str(after.get("phase", "")) == "torn_down", "teardown must publish the terminal phase")
	_expect(not bool(after.get("active", true)) and not bool(after.get("visible", true)), "teardown must hide the lifecycle owner synchronously")
	_expect(int(after.get("runtime_instance_id", -1)) == 0, "teardown must release runtime identity")
	_expect(int(after.get("scene_owned_node_count", -1)) == 0, "teardown must leave zero scene-owned nodes")
	_expect(int(after.get("scene_material_rid_count", -1)) == 0, "teardown must leave zero scene material RIDs")
	_expect(int(after.get("scene_texture_id_count", -1)) == 0, "teardown must leave zero scene texture references")
	_expect(int(after.get("scene_audio_player_count", -1)) == 0, "teardown must leave zero scene audio players")
	_expect(int(after.get("compiled_cache_count", 0)) >= 2, "intentional compiled cache must survive scene teardown at a fixed plateau")
	_expect(int(after.get("compile_count", 0)) == 2, "teardown must not silently regenerate either cached seed")
	_expect(int(after.get("cold_warning_count", -1)) == 0, "lifecycle run must emit no 60ms cold-instantiation warning")
	_expect(not bool(lifecycle.call("activate_exterior")), "activation after teardown must fail closed")
	var rejected := lifecycle.call("get_debug_status") as Dictionary
	_expect(not bool(rejected.get("active", true)), "failed post-teardown activation must remain hidden")
	_complete_leg("teardown_isolation", assertion_start)


func _drive_prewarm(lifecycle: Control) -> bool:
	for _step in range(MAX_PREWARM_STEPS):
		if bool(lifecycle.call("advance_prewarm_step")):
			return true
		var status := lifecycle.call("get_debug_status") as Dictionary
		if str(status.get("phase", "")) == "rejected":
			_expect(false, "prewarm rejected: %s" % status.get("rejection_reason", ""))
			return false
		# The headless renderer does not reliably emit frame_post_draw. Exercise
		# the exact completion callback here; the separate Vulkan QA must prove
		# that two real post-draw emissions complete the same owner state.
		if str(status.get("phase", "")) == "gpu_submit":
			lifecycle.call("_on_gpu_frame_post_draw")
		await process_frame
	_expect(false, "prewarm exceeded %d bounded steps" % MAX_PREWARM_STEPS)
	return false


func _build_config(map_seed: int) -> Dictionary:
	return {
		"stage_id": 1,
		"map_seed": map_seed,
		"render_size": VIEW_SIZE,
		"safe_insets": SAFE_INSETS,
		"minimap_rect": MINIMAP_RECT,
		"camera_zoom": 1.35,
		"selected_character_type": "smasher",
		"guardian_enabled": true,
		"guardian_id": "onimaru",
		"guardian_locomotion_style": "ground",
		"initial_player_position_policy": "first_portal",
	}


func _derive_expected_resource_paths(plan: Dictionary, config: Dictionary) -> Array[String]:
	var paths := _derive_expected_gpu_paths(plan, config)
	for path_map in [
		PlazaAssetLoader.get_interior_npc_texture_paths_for_test(),
		PlazaAssetLoader.get_interior_room_texture_paths_for_test(),
		PlazaAssetLoader.get_interior_object_texture_paths_for_test(),
	]:
		for path_value in (path_map as Dictionary).values():
			_append_unique(paths, str(path_value))
	paths.sort()
	return paths


func _derive_expected_gpu_paths(plan: Dictionary, config: Dictionary) -> Array[String]:
	var paths := PlazaAssetLoader.get_hwangyeok_building_prewarm_texture_paths()
	var player_paths := PlazaAssetLoader.get_player_texture_paths_for_test(config.get("selected_character_type", "smasher"))
	for key in ["idle", "walk_left", "walk_right"]:
		_append_unique(paths, str(player_paths.get(key, "")))
	_append_unique(paths, LingpetCatalog.get_visual_path(str(config.get("guardian_id", "onimaru")), "companion_walk"))
	var ground := plan.get("ground_draw", {}) as Dictionary
	_append_unique(paths, str(ground.get("texture_path", "")))
	for key in ["road_draws", "plot_pad_draws", "decor_draws"]:
		for record in _dictionary_array(plan.get(key, [])):
			_append_unique(paths, str(record.get("texture_path", "")))
	paths.sort()
	return paths


func _append_unique(paths: Array[String], path: String) -> void:
	if path != "" and not paths.has(path):
		paths.append(path)


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value as Array:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _violations_have(validation: Dictionary, prefix: String) -> bool:
	var value: Variant = validation.get("violations", null)
	if value is Array:
		for violation in value as Array:
			if str(violation).begins_with(prefix):
				return true
	return false


func _complete_leg(leg_name: String, assertion_start: int) -> void:
	if _leg_assertion_counts.has(leg_name):
		_failures.append("GRT-040 duplicate completed verification leg: %s" % leg_name)
		return
	_leg_assertion_counts[leg_name] = _assertion_count - assertion_start
	_legs_completed += 1


func _expect(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _legs_completed != EXPECTED_COMPLETED_LEGS:
		_failures.append("GRT-040 completion gate: expected %d completed verification legs, got %d" % [EXPECTED_COMPLETED_LEGS, _legs_completed])
	for leg_name in MIN_ASSERTIONS_BY_LEG.keys():
		var actual := int(_leg_assertion_counts.get(leg_name, 0))
		var required := int(MIN_ASSERTIONS_BY_LEG.get(leg_name, 1))
		if actual < required:
			_failures.append("GRT-040 completion gate: leg %s executed %d assertions, expected at least %d" % [leg_name, actual, required])
	if _assertion_count <= 0:
		_failures.append("GRT-040 completion gate: assertion count must be positive")
	if _failures.is_empty():
		print("plaza_r3c_lifecycle_prewarm_smoke: ok legs=%d assertions=%d" % [_legs_completed, _assertion_count])
		_schedule_quit(0)
		return
	for failure in _failures:
		push_error(failure)
	_schedule_quit(1)


func _schedule_quit(exit_code: int) -> void:
	# Queue native SceneTree quit directly so _finish() and async _run() return
	# before ObjectDB cleanup. The 120-frame disposal drain already completed.
	call_deferred("quit", exit_code)
