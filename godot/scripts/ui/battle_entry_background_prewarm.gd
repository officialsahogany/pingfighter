extends RefCounted

# Menu-idle background prewarm for battle entry loading.
#
# The battle entry loading screen is dominated by threaded texture waits
# (stage-clear result sheets, stage pillar backplates, core battle textures)
# that are worker-bound, so the loading screen cannot shrink them. All of
# those loads land in ProjectResourceLoader's process-lifetime static texture
# cache, and every boot prewarm step resolves a cached path as an instant
# cache hit. So while the player idles on the character select screen, walk
# the same path lists through the shared threaded prewarm slot ahead of time,
# targeting the same (character, stage) the battle startup will use
# (GameSelectionState.stage_id; debug/progress entries can start at stage 2+).
#
# Slot manners: at most ONE threaded load in flight, polled once per update
# (per frame). If the scene changes mid-load, the orphaned slot is harvested
# by the next shared-slot caller and resolved once per frame by the boot
# budgeted warmup (see prewarm_texture_threaded_step's cross-path harvest and
# try_resolve_finished_threaded_prewarm), so no drain/cancel is needed here.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const StageClearResultAssetLoader := preload("res://scripts/ui/stage_clear_result_asset_loader.gd")
const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const SkillCutinDriveRenderer := preload("res://scripts/hud/skill_cutin_drive_renderer.gd")
const MythicAcquisitionCinematicV2 := preload("res://scripts/items/mythic_item_acquisition_cinematic_v2.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const StageLandingIntro := preload("res://scripts/core/stage_landing_intro.gd")

# Opt-in long bounds: menu idle prefers keeping a slow giant sheet threaded
# over a synchronous main-thread fallback hitching the menu. Do NOT copy these
# bounds to loading-screen callers (see AGENTS.md "Bounded threaded texture
# prewarm" -- the short default is correct there).
const ENTRY_PREWARM_MAX_MSEC := 30000
const ENTRY_PREWARM_MAX_POLLS := 4000
const ENTRY_PREWARM_MAX_JOB_ADVANCES_PER_UPDATE := 4
const ENTRY_PREWARM_DEFAULT_STAGE := 1
# Result asset path dicts mix texture sheets with audio (stage 1 carries
# "dalji_click_voice" = an mp3), and ResourceLoader.exists' "Texture2D" hint
# does NOT reject imported audio — without this filter the mp3 wastes a
# threaded slot step and logs a decode ERROR every session.
const TEXTURE_PATH_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg"]

var _jobs: Array = []
var _job_index: int = 0
var _built_for_character := ""
var _built_for_stage: int = 0
var _character_runtime: Object = PlayerCharacterRuntime.new()
var _battle_resources: Object = BattleResources.new()


func clear_runtime_state() -> void:
	_jobs.clear()
	_job_index = 0
	_built_for_character = ""
	_built_for_stage = 0
	_character_runtime = null
	_battle_resources = null


func is_finished() -> bool:
	return _built_for_character != "" and _job_index >= _jobs.size()


func get_job_count() -> int:
	return _jobs.size()


# Advances background prewarm by at most one in-flight threaded load and a
# small number of already-cached job skips. Returns true when every job for
# the current character + entry stage is cached. The stage must follow the
# real battle startup source (GameSelectionState.stage_id) -- a fixed Stage 1
# target wastes IO and static cache whenever the entry stage is 2+.
func update(character_type: String, stage_id: int = ENTRY_PREWARM_DEFAULT_STAGE) -> bool:
	var normalized: String = _character_runtime.normalize(character_type)
	var normalized_stage: int = max(1, stage_id)
	if _built_for_character != normalized or _built_for_stage != normalized_stage:
		_build_jobs(normalized, normalized_stage)
	var advances := ENTRY_PREWARM_MAX_JOB_ADVANCES_PER_UPDATE
	while _job_index < _jobs.size() and advances > 0:
		var job_value: Variant = _jobs[_job_index]
		var job: Dictionary = job_value if job_value is Dictionary else {}
		# Pass real warning templates: a harvested path that fails to decode
		# (engine "Failed to load image. Error 15") is otherwise anonymous —
		# the backtrace shows this call site but never the asset path, so the
		# broken/unsupported file cannot be identified from the log.
		var result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
			str(job.get("path", "")),
			"Entry background prewarm: missing texture at %s",
			"Entry background prewarm: failed to load texture at %s",
			ENTRY_PREWARM_MAX_MSEC,
			ENTRY_PREWARM_MAX_POLLS,
			false,
			bool(job.get("prefer_imported", false))
		)
		if not bool(result.get("done", true)):
			return false
		_job_index += 1
		advances -= 1
	return _job_index >= _jobs.size()


func _build_jobs(character_type: String, stage_id: int) -> void:
	_built_for_character = character_type
	_built_for_stage = stage_id
	_jobs.clear()
	_job_index = 0
	var seen: Dictionary = {}
	# Boot-order priority: transition texture specs (boot step 02) -> stage
	# pillar background (step 10, stage 1 only) -> stage-clear result sheets
	# (step 18).
	if _battle_resources == null:
		_battle_resources = BattleResources.new()
	var transition_jobs: Array = _battle_resources.get_transition_texture_prewarm_jobs({
		"selected_character_type": character_type,
		"current_stage": stage_id,
		"include_result_sheets": false,
	})
	for transition_job_value in transition_jobs:
		_append_job(seen, transition_job_value)
	if stage_id == 1:
		for pillar_path in [
			Stage1PillarBackground.HANJI_TEXTURE_PATH,
			Stage1PillarBackground.TREE_SPRITE_TEXTURE_PATH,
			Stage1PillarBackground.CLOUD_SPRITE_TEXTURE_PATH,
			Stage1PillarBackground.BUTTERFLY_SHEET_TEXTURE_PATH,
		]:
			_append_job(seen, {"path": str(pillar_path), "prefer_imported": false})
	var result_paths: Dictionary = StageClearResultAssetLoader.get_result_asset_paths(
		character_type,
		stage_id
	)
	for result_path_value in result_paths.values():
		_append_job(seen, {"path": str(result_path_value), "prefer_imported": true})
	for extra_path in _get_stage_runtime_threaded_paths(character_type, stage_id):
		_append_job(seen, {"path": str(extra_path), "prefer_imported": true})


# Path consts behind boot step 16 (landing intro) and step 17's threaded
# substeps (skill cut-in sheets, mythic acquisition cinematic, lingpet rail
# card). The stage pillar HUD scene drawer is intentionally absent: its
# prewarm is module-coupled cache building, not an enumerable path list.
func _get_stage_runtime_threaded_paths(character_type: String, stage_id: int) -> Array:
	var paths: Array = [
		str(StageLandingIntro.STAGE_BACKGROUND_PATHS.get(stage_id, "")),
		MythicAcquisitionCinematicV2.BACKPLATE_TEXTURE_PATH,
		MythicAcquisitionCinematicV2.SHARD_TEXTURE_PATH,
		MythicAcquisitionCinematicV2.ARC_TEXTURE_PATH,
		LingpetRailCard.TEXTURE_PATH,
	]
	# Mirror skill_cutin_overlay_host._build_asset_prewarm_steps: only smasher
	# and viper own cut-in sheets; other characters prewarm none.
	if character_type == PlayerCharacterRuntime.VIPER:
		paths.append(SkillCutinOverlayHost.VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH)
	elif character_type == PlayerCharacterRuntime.SMASHER:
		paths.append(SkillCutinOverlayHost.POWER_SMASHING_CUTIN_SHEET_PATH)
		paths.append(SkillCutinOverlayHost.GHOST_SMASHING_CUTIN_SHEET_PATH)
		paths.append(SkillCutinOverlayHost.DRIVE_BACKPLATE_PATH)
		paths.append(SkillCutinOverlayHost.DRIVE_ARC_PATH)
		paths.append(SkillCutinOverlayHost.DRIVE_CHARACTER_PATH)
		paths.append(SkillCutinDriveRenderer.SHIELD_KITING_CHARACTER_PATH)
	return paths


func _append_job(seen: Dictionary, job_value: Variant) -> void:
	if not (job_value is Dictionary):
		return
	var job: Dictionary = job_value
	var path := str(job.get("path", ""))
	if path == "" or seen.has(path):
		return
	if not TEXTURE_PATH_EXTENSIONS.has(path.get_extension().to_lower()):
		return
	if not ResourceLoader.exists(path, "Texture2D"):
		return
	seen[path] = true
	_jobs.append({"path": path, "prefer_imported": bool(job.get("prefer_imported", false))})
