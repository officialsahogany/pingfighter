extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleEntryBackgroundPrewarm := preload("res://scripts/ui/battle_entry_background_prewarm.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const MythicAcquisitionCinematicV2 := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const StageLandingIntro := preload("res://scripts/core/stage_landing_intro.gd")

# Real repo textures that are NOT part of the battle-entry job lists, so the
# orphan-harvest case can exercise genuine threaded loads before any cache
# faking happens.
const HARVEST_PATH_A := "res://assets/ui/loading/loading_energy_wave_loop64_autosprite_v1.png"
const HARVEST_PATH_B := "res://assets/ui/loading/loading_energy_wave_anchor_imagegen_v1.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_cross_path_harvest_resolves_orphaned_slot()
	_verify_orphan_resolve_frees_slot_without_new_owner()
	_verify_job_list_covers_entry_loading_sources()
	_verify_stage_aware_job_list()
	_verify_cached_jobs_finish_in_batches()
	_verify_character_switch_rebuilds_jobs()
	_verify_character_select_screen_wires_idle_prewarm()

	if _failures.is_empty():
		print("battle_entry_background_prewarm_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


# The menu-idle prewarmer abandons its in-flight threaded load on scene change.
# The next shared-slot caller must harvest the finished foreign load (store +
# clear) instead of waiting for the expiry bound; drain discards the texture,
# so "A landed in the cache without its owner ever polling again" proves the
# harvest path specifically.
func _verify_cross_path_harvest_resolves_orphaned_slot() -> void:
	_expect(ResourceLoader.exists(HARVEST_PATH_A, "Texture2D"), "harvest test path A should exist in the repo")
	_expect(ResourceLoader.exists(HARVEST_PATH_B, "Texture2D"), "harvest test path B should exist in the repo")
	var first: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		HARVEST_PATH_A, "", "", 30000, 100000, false, true
	)
	if bool(first.get("done", true)):
		_expect(false, "harvest test path A resolved immediately; pick a heavier asset so the orphan case is exercised")
		return
	var b_done := false
	var guard := 0
	while not b_done and guard < 20000:
		var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
			HARVEST_PATH_B, "", "", 30000, 100000, false, true
		)
		b_done = bool(result.get("done", true))
		if not b_done:
			OS.delay_msec(1)
		guard += 1
	_expect(b_done, "cross-path caller should complete after harvesting the orphaned slot")
	_expect(
		ProjectResourceLoader.get_cached_texture(HARVEST_PATH_A) != null,
		"harvest must store the orphaned finished load into the texture cache"
	)
	_expect(
		ProjectResourceLoader.get_cached_texture(HARVEST_PATH_B) != null,
		"the cross-path caller's own load should land in the texture cache"
	)


# The boot budgeted loop runs this resolve once per frame, so a slot orphaned
# by the menu prewarmer (scene changed mid-load) cannot throttle the whole
# loading batch to one step per frame after the worker finishes.
func _verify_orphan_resolve_frees_slot_without_new_owner() -> void:
	var orphan_path := Stage1PillarBackground.HANJI_TEXTURE_PATH
	_expect(ResourceLoader.exists(orphan_path, "Texture2D"), "orphan resolve test path should exist in the repo")
	var first: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		orphan_path, "", "", 30000, 100000, false, true
	)
	if bool(first.get("done", true)):
		_expect(false, "orphan resolve test path resolved immediately; pick a heavier asset")
		return
	_expect(ProjectResourceLoader.has_threaded_prewarm_in_flight(), "slot should be in flight after the orphaned request")
	var guard := 0
	var progress_values: Array = []
	while ResourceLoader.load_threaded_get_status(orphan_path, progress_values) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and guard < 20000:
		OS.delay_msec(1)
		guard += 1
	ProjectResourceLoader.try_resolve_finished_threaded_prewarm()
	_expect(
		not ProjectResourceLoader.has_threaded_prewarm_in_flight(),
		"try_resolve_finished_threaded_prewarm should free the finished orphaned slot"
	)
	_expect(
		ProjectResourceLoader.get_cached_texture(orphan_path) != null,
		"resolved orphan load should land in the texture cache"
	)


func _verify_job_list_covers_entry_loading_sources() -> void:
	var prewarmer := BattleEntryBackgroundPrewarm.new()
	prewarmer.call("_build_jobs", "smasher", 1)
	var jobs: Array = prewarmer.get("_jobs")
	_expect(jobs.size() >= 12, "entry prewarm should enumerate a meaningful Stage 1 job list")
	var paths: Dictionary = {}
	for job_value in jobs:
		if job_value is Dictionary:
			paths[str((job_value as Dictionary).get("path", ""))] = true
	_expect(paths.size() == jobs.size(), "entry prewarm job list should be deduplicated")
	_expect(
		paths.has(Stage1PillarBackground.HANJI_TEXTURE_PATH),
		"entry prewarm should cover the stage1 pillar backplate textures (boot step 10)"
	)
	var result_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 1)
	var victory_path := str(result_paths.get("player_victory_sheet", ""))
	_expect(
		victory_path != "" and paths.has(victory_path),
		"entry prewarm should cover the stage-clear result victory sheet (boot step 18)"
	)
	_expect(
		paths.has(SkillCutinOverlayHost.POWER_SMASHING_CUTIN_SHEET_PATH),
		"smasher entry prewarm should cover the smasher cut-in sheets (boot step 17)"
	)
	_expect(
		paths.has(MythicAcquisitionCinematicV2.BACKPLATE_TEXTURE_PATH),
		"entry prewarm should cover the mythic acquisition cinematic textures (boot step 17)"
	)
	_expect(
		paths.has(str(StageLandingIntro.STAGE_BACKGROUND_PATHS.get(1, ""))),
		"entry prewarm should cover the stage1 landing intro background (boot step 16)"
	)

	var viper_probe := BattleEntryBackgroundPrewarm.new()
	viper_probe.call("_build_jobs", "viper", 1)
	var viper_paths: Dictionary = {}
	for viper_job_value in viper_probe.get("_jobs"):
		if viper_job_value is Dictionary:
			viper_paths[str((viper_job_value as Dictionary).get("path", ""))] = true
	_expect(
		viper_paths.has(SkillCutinOverlayHost.VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH),
		"viper entry prewarm should cover the viper cut-in sheet"
	)
	_expect(
		not viper_paths.has(SkillCutinOverlayHost.POWER_SMASHING_CUTIN_SHEET_PATH),
		"viper entry prewarm should not waste IO on smasher-only cut-in sheets"
	)


# The real battle startup reads its entry stage from GameSelectionState, so a
# stage-2 entry must not warm Stage 1 pillar/result assets.
func _verify_stage_aware_job_list() -> void:
	var prewarmer := BattleEntryBackgroundPrewarm.new()
	prewarmer.call("_build_jobs", "smasher", 2)
	var paths: Dictionary = {}
	for job_value in prewarmer.get("_jobs"):
		if job_value is Dictionary:
			paths[str((job_value as Dictionary).get("path", ""))] = true
	_expect(
		not paths.has(Stage1PillarBackground.HANJI_TEXTURE_PATH),
		"stage-2 entry prewarm should not warm Stage 1 pillar backplates"
	)
	var stage2_landing_path := str(StageLandingIntro.STAGE_BACKGROUND_PATHS.get(2, ""))
	if ResourceLoader.exists(stage2_landing_path, "Texture2D"):
		_expect(
			paths.has(stage2_landing_path),
			"stage-2 entry prewarm should warm the stage-2 landing background"
		)
	else:
		# The stage-2 landing background asset is currently absent from the
		# repo; the existence filter must skip it instead of queueing a job
		# that would sync-fallback with a missing-file warning.
		_expect(
			not paths.has(stage2_landing_path),
			"missing landing background should be skipped by the existence filter"
		)
	var stage1_landing_path := str(StageLandingIntro.STAGE_BACKGROUND_PATHS.get(1, ""))
	_expect(
		not paths.has(stage1_landing_path),
		"stage-2 entry prewarm should not warm the stage-1 landing background"
	)
	var stage2_result_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths("smasher", 2)
	var stage2_victory_path := str(stage2_result_paths.get("player_victory_sheet", ""))
	_expect(
		stage2_victory_path != "" and paths.has(stage2_victory_path),
		"stage-2 entry prewarm should warm the stage-2 result sheets"
	)
	prewarmer.call("_build_jobs", "smasher", 1)
	_expect(
		int(prewarmer.get("_built_for_stage")) == 1,
		"stage change should rebuild the entry prewarm job list"
	)


func _verify_cached_jobs_finish_in_batches() -> void:
	var prewarmer := BattleEntryBackgroundPrewarm.new()
	prewarmer.call("_build_jobs", "smasher", 1)
	var jobs: Array = prewarmer.get("_jobs")
	_fake_cache_paths(jobs)
	var updates := 0
	var finished := false
	while not finished and updates < 64:
		finished = bool(prewarmer.update("smasher"))
		updates += 1
	_expect(finished, "a fully cached job list should finish")
	_expect(bool(prewarmer.is_finished()), "is_finished should report completion")
	var max_updates := int(ceil(float(jobs.size()) / float(BattleEntryBackgroundPrewarm.ENTRY_PREWARM_MAX_JOB_ADVANCES_PER_UPDATE))) + 1
	_expect(
		updates <= max_updates,
		"cached jobs should skip in per-frame batches instead of one job per frame"
	)


func _verify_character_switch_rebuilds_jobs() -> void:
	var viper_probe := BattleEntryBackgroundPrewarm.new()
	viper_probe.call("_build_jobs", "viper", 1)
	_fake_cache_paths(viper_probe.get("_jobs"))
	var optimus_probe := BattleEntryBackgroundPrewarm.new()
	optimus_probe.call("_build_jobs", "optimus", 1)
	_fake_cache_paths(optimus_probe.get("_jobs"))

	var prewarmer := BattleEntryBackgroundPrewarm.new()
	prewarmer.call("_build_jobs", "smasher", 1)
	_fake_cache_paths(prewarmer.get("_jobs"))
	var guard := 0
	while not bool(prewarmer.update("smasher")) and guard < 64:
		guard += 1
	_expect(bool(prewarmer.is_finished()), "smasher jobs should finish before the switch")

	var finished := false
	guard = 0
	while not finished and guard < 64:
		finished = bool(prewarmer.update("viper"))
		guard += 1
	_expect(str(prewarmer.get("_built_for_character")) == "viper", "switching characters should rebuild the job list")
	_expect(finished, "rebuilt viper jobs should finish from the faked cache")

	finished = false
	guard = 0
	while not finished and guard < 64:
		finished = bool(prewarmer.update(" IO "))
		guard += 1
	_expect(str(prewarmer.get("_built_for_character")) == "optimus", "entry prewarm should normalize character aliases through the shared runtime")
	_expect(finished, "rebuilt Optimus alias jobs should finish from the faked cache")


func _verify_character_select_screen_wires_idle_prewarm() -> void:
	var select_source := FileAccess.get_file_as_string("res://scripts/ui/character_select_screen.gd")
	_expect(
		select_source.find("_update_entry_background_prewarm()") >= 0,
		"character select _process should drive the battle-entry background prewarm"
	)
	_expect(
		select_source.find("Engine.is_editor_hint() or confirm_intro_active") >= 0,
		"entry background prewarm must pause in the editor and during the confirm intro"
	)
	_expect(
		select_source.find("_selected_entry_stage_id()") >= 0,
		"character select should target the GameSelectionState entry stage, not a fixed Stage 1"
	)
	var loader_source := FileAccess.get_file_as_string("res://scripts/resources/project_resource_loader.gd")
	_expect(
		loader_source.find("THREAD_LOAD_LOADED") >= 0 and loader_source.find("_clear_threaded_texture_prewarm()") >= 0,
		"shared threaded slot should keep the cross-path harvest path"
	)
	var warmup_source := FileAccess.get_file_as_string("res://scripts/core/battle_boot_warmup_controller.gd")
	_expect(
		warmup_source.find("try_resolve_finished_threaded_prewarm()") >= 0,
		"boot budgeted warmup should resolve an orphaned threaded slot each frame before batching"
	)


func _fake_cache_paths(jobs: Array) -> void:
	var fake := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
	for job_value in jobs:
		if not (job_value is Dictionary):
			continue
		var path := str((job_value as Dictionary).get("path", ""))
		if path != "" and ProjectResourceLoader.get_cached_texture(path) == null:
			ProjectResourceLoader.store_texture(path, fake)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
