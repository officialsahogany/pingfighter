extends RefCounted

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const CharacterSelectPreviewVfxHost := preload("res://scripts/ui/character_select_preview_vfx_host.gd")

const CHARACTER_SELECT_BGM_PATH := "res://assets/bgm/character select.wav"

var jobs: Array = []
var current_job: Dictionary = {}
var current_path: String = ""
var current_progress: float = 0.0
var completed_count: int = 0
var total_count: int = 0
var loaded_character_select_scene: PackedScene = null
var failed_paths: Array = []
var active: bool = false
var finished: bool = false


func begin(character_select_scene_path: String) -> void:
	if active or current_path != "":
		cancel_and_drain_current_request()
	jobs.clear()
	current_job = {}
	current_path = ""
	current_progress = 0.0
	completed_count = 0
	loaded_character_select_scene = null
	failed_paths.clear()
	active = true
	finished = false

	_add_job(character_select_scene_path, "PackedScene", "캐릭터 선택 화면")
	_add_job(CHARACTER_SELECT_BGM_PATH, "AudioStream", "캐릭터 선택 BGM")
	_add_character_select_assets()
	_add_character_select_vfx_assets()
	CharacterSelectPreviewVfxHost.prewarm_materials()
	total_count = jobs.size()
	_request_next_job()


func cancel_and_drain_current_request() -> void:
	jobs.clear()
	if current_path != "":
		var status := ResourceLoader.load_threaded_get_status(current_path)
		if status in [
			ResourceLoader.THREAD_LOAD_IN_PROGRESS,
			ResourceLoader.THREAD_LOAD_LOADED,
		]:
			# Godot has no threaded-load cancellation API. Claiming the current
			# request is the only safe way to release it before its owner dies.
			ResourceLoader.load_threaded_get(current_path)
	current_job = {}
	current_path = ""
	current_progress = 0.0
	completed_count = total_count
	loaded_character_select_scene = null
	failed_paths.clear()
	active = false
	finished = true


func update() -> bool:
	if finished:
		return true
	if current_path == "":
		_request_next_job()
		return finished

	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(current_path, progress_values)
	if progress_values.size() > 0:
		current_progress = clamp(float(progress_values[0]), 0.0, 1.0)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_finish_threaded_job(ResourceLoader.load_threaded_get(current_path))
			_request_next_job()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			failed_paths.append(current_path)
			_load_job_synchronously(current_job)
			_finish_current_job()
			_request_next_job()

	return finished


func get_progress() -> float:
	if total_count <= 0:
		return 1.0
	return clamp((float(completed_count) + current_progress) / float(total_count), 0.0, 1.0)


func get_status_text() -> String:
	if finished:
		return LanguageSettings.translate_text("준비 완료")
	if current_job.is_empty():
		return LanguageSettings.translate_text("목록 준비 중")
	return LanguageSettings.translate_text(str(current_job.get("label", "리소스 준비 중")))


func get_loaded_scene() -> PackedScene:
	return loaded_character_select_scene


func collect_retained_cache_paths() -> Dictionary:
	# Warm-set contract for battle teardown: these are the ProjectResourceLoader
	# cache paths that must SURVIVE the teardown clear_caches wipe, so every
	# post-battle exit (F10 booth reset, true-defeat settlement, stage-clear
	# exit) reaches character select warm without replaying the boot loading
	# screen. PackedScene jobs are excluded -- the scene lives in the engine
	# ResourceCache, not in the ProjectResourceLoader caches.
	var previous_jobs := jobs
	jobs = []
	_add_job(CHARACTER_SELECT_BGM_PATH, "AudioStream", "캐릭터 선택 BGM")
	_add_character_select_assets()
	_add_character_select_vfx_assets()
	var texture_paths: Array[String] = []
	var audio_paths: Array[String] = []
	for job_value in jobs:
		if not (job_value is Dictionary):
			continue
		var job: Dictionary = job_value
		var path := str(job.get("path", ""))
		if path == "":
			continue
		match str(job.get("type", "")):
			"Texture2D":
				texture_paths.append(path)
			"AudioStream":
				audio_paths.append(path)
	jobs = previous_jobs
	return {"textures": texture_paths, "audio": audio_paths}


func _add_character_select_assets() -> void:
	var characters: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
	for character_value in characters:
		if not (character_value is Dictionary):
			continue
		var character: Dictionary = character_value
		var character_name := str(character.get("character_name", character.get("name", "캐릭터")))
		_add_job(str(character.get("portrait_path", "")), "Texture2D", _format_asset_label(character_name, "card"))
		_add_job(str(character.get("live2d_preview_still_path", "")), "Texture2D", _format_asset_label(character_name, "still"))
		var fullframe_path := _primary_fullframe_path(character)
		if fullframe_path != "":
			_add_job(fullframe_path, "Texture2D", _format_asset_label(character_name, "animation"))
		elif character.has("live2d_layers"):
			_add_layer_jobs(character, character_name)
		var full_body_path := _primary_full_body_path(character)
		if full_body_path != "":
			_add_job(full_body_path, "Texture2D", "%s full-body Live2D" % character_name)
		var confirm_intro_path := str(character.get("confirm_intro_sheet_path", ""))
		if confirm_intro_path != "":
			_add_job(confirm_intro_path, "Texture2D", "%s confirm intro" % character_name)
		var confirm_intro_voice_path := str(character.get("confirm_intro_voice_path", ""))
		if confirm_intro_voice_path != "":
			_add_job(confirm_intro_voice_path, "AudioStream", "%s confirm voice" % character_name)
		var click_motion_voice_path := str(character.get("click_motion_voice_path", ""))
		if click_motion_voice_path != "":
			_add_job(click_motion_voice_path, "AudioStream", "%s click voice" % character_name)


func _add_character_select_vfx_assets() -> void:
	for texture_path in CharacterSelectPreviewVfxHost.get_vfx_texture_paths():
		_add_job(str(texture_path), "Texture2D", "character select VFX")


func _primary_fullframe_path(character: Dictionary) -> String:
	var candidates_value: Variant = character.get("live2d_fullframe_sheet_candidates", [])
	if candidates_value is Array:
		for candidate_value in candidates_value:
			if not (candidate_value is Dictionary):
				continue
			var candidate: Dictionary = candidate_value
			var path := str(candidate.get("path", ""))
			if _path_exists(path, "Texture2D"):
				return path
	var fallback_path := str(character.get("live2d_fullframe_sheet_path", ""))
	return fallback_path if _path_exists(fallback_path, "Texture2D") else ""


func _primary_full_body_path(character: Dictionary) -> String:
	var sheet_path := str(character.get("full_body_live2d_sheet_path", ""))
	if _path_exists(sheet_path, "Texture2D"):
		return sheet_path
	var fallback_path := str(character.get("full_body_live2d_path", ""))
	return fallback_path if _path_exists(fallback_path, "Texture2D") else ""


func _add_layer_jobs(character: Dictionary, character_name: String) -> void:
	var layers_value: Variant = character.get("live2d_layers", {})
	if not (layers_value is Dictionary):
		return
	var layers: Dictionary = layers_value
	for key in layers.keys():
		var path := str(layers.get(key, ""))
		if _path_exists(path, "Texture2D"):
			_add_job(path, "Texture2D", _format_asset_label(character_name, "parts"))


func _add_job(path: String, type_hint: String, label: String) -> void:
	if path == "" or not _path_exists(path, type_hint):
		return
	for job_value in jobs:
		if job_value is Dictionary and str(job_value.get("path", "")) == path:
			return
	jobs.append({
		"path": path,
		"type": type_hint,
		"label": label,
	})


func _format_asset_label(character_name: String, asset_kind: String) -> String:
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_ENGLISH:
		match asset_kind:
			"card":
				return "%s card image" % character_name
			"still":
				return "%s still image" % character_name
			"animation":
				return "%s animation" % character_name
			"parts":
				return "%s parts image" % character_name
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_SPANISH:
		return "%s %s" % [character_name, {
			"card": "imagen de carta",
			"still": "imagen fija",
			"animation": "animación",
			"parts": "imagen de partes",
		}.get(asset_kind, "recurso")]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "%s %s" % [character_name, {
			"card": "imagem de carta",
			"still": "imagem estática",
			"animation": "animação",
			"parts": "imagem de partes",
		}.get(asset_kind, "recurso")]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_RUSSIAN:
		return "%s %s" % [character_name, {
			"card": "изображение карты",
			"still": "статичное изображение",
			"animation": "анимация",
			"parts": "изображение частей",
		}.get(asset_kind, "ресурс")]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_CHINESE:
		return "%s %s" % [character_name, {
			"card": "卡牌图像",
			"still": "静态图像",
			"animation": "动画",
			"parts": "部件图像",
		}.get(asset_kind, "资源")]
	if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_JAPANESE:
		return "%s %s" % [character_name, {
			"card": "カード画像",
			"still": "静止画",
			"animation": "アニメーション",
			"parts": "パーツ画像",
		}.get(asset_kind, "リソース")]
	return "%s %s" % [character_name, {
		"card": "카드 이미지",
		"still": "스틸 이미지",
		"animation": "애니메이션",
		"parts": "파츠 이미지",
	}.get(asset_kind, "리소스")]


func _request_next_job() -> void:
	current_job = {}
	current_path = ""
	current_progress = 0.0

	while not jobs.is_empty():
		var job_value: Variant = jobs.pop_front()
		if not (job_value is Dictionary):
			continue
		current_job = job_value
		current_path = str(current_job.get("path", ""))
		if current_path == "":
			continue
		if _use_cached_job_if_available(current_job):
			_finish_current_job()
			continue
		if not _can_thread_load_job(current_job):
			_load_job_synchronously(current_job)
			_finish_current_job()
			continue
		var type_hint := str(current_job.get("type", ""))
		var request_error := ResourceLoader.load_threaded_request(current_path, type_hint, true)
		if request_error == OK or request_error == ERR_BUSY:
			current_progress = 0.01
			return
		_load_job_synchronously(current_job)
		_finish_current_job()

	finished = true
	active = false
	current_job = {}
	current_path = ""
	current_progress = 1.0


func _finish_threaded_job(resource: Resource) -> void:
	var type_hint := str(current_job.get("type", ""))
	if type_hint == "Texture2D":
		var texture := resource as Texture2D
		if texture != null:
			ProjectResourceLoader.store_texture(current_path, texture)
	elif type_hint == "AudioStream":
		var stream := resource as AudioStream
		if stream != null:
			ProjectResourceLoader.store_audio_stream(current_path, stream)
	elif type_hint == "PackedScene":
		loaded_character_select_scene = resource as PackedScene
	_finish_current_job()


func _use_cached_job_if_available(job: Dictionary) -> bool:
	var type_hint := str(job.get("type", ""))
	var path := str(job.get("path", ""))
	if type_hint == "Texture2D":
		return ProjectResourceLoader.get_cached_texture(path) != null
	if type_hint == "AudioStream":
		return ProjectResourceLoader.get_cached_audio_stream(path) != null
	if type_hint == "PackedScene":
		return loaded_character_select_scene != null
	return false


func _can_thread_load_job(job: Dictionary) -> bool:
	var type_hint := str(job.get("type", ""))
	var path := str(job.get("path", ""))
	if type_hint != "Texture2D":
		return true
	return ProjectResourceLoader.can_thread_load_texture(path)


func _load_job_synchronously(job: Dictionary) -> void:
	var type_hint := str(job.get("type", ""))
	var path := str(job.get("path", ""))
	if type_hint == "Texture2D":
		ProjectResourceLoader.load_imported_texture(path)
	elif type_hint == "AudioStream":
		ProjectResourceLoader.load_audio_stream(path)
	elif type_hint == "PackedScene":
		var resource := load(path)
		loaded_character_select_scene = resource as PackedScene


func _finish_current_job() -> void:
	completed_count += 1
	current_path = ""
	current_progress = 0.0


func _path_exists(path: String, type_hint: String = "") -> bool:
	if path == "":
		return false
	if type_hint == "Texture2D":
		return ProjectResourceLoader.texture_resource_exists(path)
	if type_hint == "AudioStream":
		return ProjectResourceLoader.audio_resource_exists(path)
	if type_hint != "":
		return ResourceLoader.exists(path, type_hint) or ResourceLoader.exists(path)
	return ResourceLoader.exists(path)
