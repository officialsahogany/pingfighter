extends RefCounted

static var _texture_cache: Dictionary = {}
static var _audio_cache: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _threaded_texture_prewarm_path: String = ""
static var _threaded_texture_prewarm_started_msec: int = 0
static var _threaded_texture_prewarm_poll_count: int = 0
static var _threaded_texture_prewarm_stale_warning_sent: bool = false
static var _threaded_audio_prewarm_path: String = ""
static var _threaded_audio_prewarm_started_msec: int = 0
static var _threaded_audio_prewarm_poll_count: int = 0

const THREADED_TEXTURE_PREWARM_STALE_WARNING_MSEC := 15000
const THREADED_TEXTURE_PREWARM_STALE_WARNING_POLLS := 1200
# Hard upper bound: a threaded load that never reaches LOADED/FAILED (stuck
# status, evicted request, or an unrelated path that permanently owns the
# shared slot) is abandoned at this bound and resolved synchronously, so the
# prewarm loop -- and any caller waiting on done == true, including a different
# path blocked behind the shared slot -- can never hang.
#
# This DEFAULT is intentionally short. Every shipped caller runs behind a
# loading / stage-transition / acquisition-cinematic screen where the caller
# blocks the visible progress bar on done == true. There, a stuck threaded
# load just freezes the bar (the 81% / 86% / 92% plateaus players reported),
# while a sub-2s sync fallback is invisible behind the same screen. So a short
# bound + fast sync recovery is correct for the loading path. A long
# "keep slow-but-progressing loads threaded" behavior (warn tier above, then
# bail near 30s) is OPT-IN only -- pass an explicit larger max_msec / max_polls
# from a genuine live-gameplay caller that would rather defer art than hitch
# the main thread. Do NOT raise this default to suit one such caller; it
# silently regresses every loading-screen prewarm back into multi-minute
# plateaus. See AGENTS.md "Bounded threaded texture prewarm".
const THREADED_TEXTURE_PREWARM_MAX_MSEC := 1800
const THREADED_TEXTURE_PREWARM_MAX_POLLS := 240
const THREADED_AUDIO_PREWARM_MAX_MSEC := 1800
const THREADED_AUDIO_PREWARM_MAX_POLLS := 240


# True while either shared threaded prewarm slot (texture or audio) has a load
# in flight. Frame-budgeted warmup batching must yield the frame instead of
# re-polling within the same frame: the bounded-fallback counters above assume
# ~1 poll per frame, so same-frame spin-polling would hit MAX_POLLS early and
# demote a healthy threaded load to a synchronous main-thread fallback.
static func has_threaded_prewarm_in_flight() -> bool:
	return _threaded_texture_prewarm_path != "" or _threaded_audio_prewarm_path != ""


# Resolves the shared texture slot WITHOUT becoming a new owner: if the
# in-flight load already finished (or failed), harvest/clear it now. Callers
# that gate frame batching on has_threaded_prewarm_in_flight() should run this
# once per frame first, so a slot orphaned by a caller that will never poll
# again (e.g. the menu-idle entry prewarmer after a scene change) frees on the
# first frame instead of throttling the whole loading batch until a cross-path
# poll expires it.
static func try_resolve_finished_threaded_prewarm() -> void:
	if _threaded_texture_prewarm_path == "":
		return
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(_threaded_texture_prewarm_path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(_threaded_texture_prewarm_path)
			if resource is Texture2D:
				store_texture(_threaded_texture_prewarm_path, resource)
			_clear_threaded_texture_prewarm()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_clear_threaded_texture_prewarm()


static func load_texture(path: String, missing_warning: String = "", failed_warning: String = "") -> Texture2D:
	if _texture_cache.has(path):
		var cached_texture: Variant = _texture_cache[path]
		if cached_texture is Texture2D:
			return cached_texture
		_texture_cache.erase(path)

	var cached_resource: Texture2D = _get_resource_loader_texture(path)
	if cached_resource != null:
		_texture_cache[path] = cached_resource
		return cached_resource

	# Prefer regenerated source files over imported cache artifacts; stale
	# remaps can survive after asset replacement.
	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			var raw_texture: Texture2D = ImageTexture.create_from_image(image)
			if not ResourceLoader.has_cached(path):
				raw_texture.resource_path = path
			_texture_cache[path] = raw_texture
			return raw_texture

	var imported_exists: bool = _can_load_imported_resource(path)
	var resource_exists: bool = ResourceLoader.exists(path, "Texture2D")
	if imported_exists or resource_exists:
		var texture_resource: Resource = ResourceLoader.load(path)
		if texture_resource is Texture2D:
			_texture_cache[path] = texture_resource
			return texture_resource

	if not raw_exists and not imported_exists and not resource_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func load_imported_texture(path: String, missing_warning: String = "", failed_warning: String = "") -> Texture2D:
	if _texture_cache.has(path):
		var cached_texture: Variant = _texture_cache[path]
		if cached_texture is Texture2D:
			return cached_texture
		_texture_cache.erase(path)

	var imported_exists: bool = _can_load_imported_resource(path)
	if imported_exists:
		var texture_resource: Resource = ResourceLoader.load(path)
		if texture_resource is Texture2D:
			_texture_cache[path] = texture_resource
			return texture_resource

	return load_texture(path, missing_warning, failed_warning)


static func get_cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		return null
	var cached_texture: Variant = _texture_cache[path]
	if cached_texture is Texture2D:
		return cached_texture
	_texture_cache.erase(path)
	return null


static func store_texture(path: String, texture: Texture2D) -> void:
	if path == "" or texture == null:
		return
	if texture.resource_path == "":
		texture.resource_path = path
	_texture_cache[path] = texture


static func texture_resource_exists(path: String) -> bool:
	if path == "":
		return false
	return _can_load_imported_resource(path) or ResourceLoader.exists(path, "Texture2D")


static func can_thread_load_texture(path: String) -> bool:
	return texture_resource_exists(path)


static func prewarm_texture_threaded_step(
	path: String,
	missing_warning: String = "",
	failed_warning: String = "",
	max_msec: int = THREADED_TEXTURE_PREWARM_MAX_MSEC,
	max_polls: int = THREADED_TEXTURE_PREWARM_MAX_POLLS,
	emit_timeout_warning: bool = false,
	prefer_imported_fallback: bool = false
) -> Dictionary:
	if path == "":
		return {"done": true, "texture": null}
	var cached_texture: Texture2D = get_cached_texture(path)
	if cached_texture != null:
		return {"done": true, "texture": cached_texture}
	var resource_loader_texture: Texture2D = _get_resource_loader_texture(path)
	if resource_loader_texture != null:
		_texture_cache[path] = resource_loader_texture
		return {"done": true, "texture": resource_loader_texture}
	if not _is_thread_loadable_texture_path(path):
		return {"done": true, "texture": _load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)}

	if _threaded_texture_prewarm_path == "":
		var request_error := ResourceLoader.load_threaded_request(path, "Texture2D", true)
		if request_error != OK and request_error != ERR_BUSY:
			return {"done": true, "texture": _load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)}
		_threaded_texture_prewarm_path = path
		_threaded_texture_prewarm_started_msec = Time.get_ticks_msec()
		_threaded_texture_prewarm_poll_count = 0
		_threaded_texture_prewarm_stale_warning_sent = false
		return {"done": false, "texture": null}
	if _threaded_texture_prewarm_path != path:
		# A different path owns the shared threaded slot. If that foreign load has
		# already finished, harvest it now (store + clear) and retry this path
		# against the freed slot. Without this, an orphaned owner that never polls
		# again (e.g. the menu-idle entry prewarmer after a scene change) keeps the
		# slot occupied until the expiry bound even though the worker is done.
		try_resolve_finished_threaded_prewarm()
		if _threaded_texture_prewarm_path == "":
			return prewarm_texture_threaded_step(path, missing_warning, failed_warning, max_msec, max_polls, emit_timeout_warning, prefer_imported_fallback)
		# Still loading: count the poll so a stuck slot is bounded for cross-path
		# callers too, then bail to a synchronous load once the hard MAX bound is
		# hit -- an unrelated stuck load must never block this path forever.
		_threaded_texture_prewarm_poll_count += 1
		if _is_threaded_texture_prewarm_expired(max_msec, max_polls):
			if emit_timeout_warning:
				_push_threaded_texture_prewarm_stale_warning()
			_drain_threaded_texture_prewarm()
			return {"done": true, "texture": _load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)}
		if _is_threaded_texture_prewarm_stale():
			_push_threaded_texture_prewarm_stale_warning()
		return {"done": false, "texture": null}

	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_clear_threaded_texture_prewarm()
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource is Texture2D:
				var texture: Texture2D = resource
				store_texture(path, texture)
				return {"done": true, "texture": texture}
			return {"done": true, "texture": _load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)}
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_clear_threaded_texture_prewarm()
			return {"done": true, "texture": _load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)}
	_threaded_texture_prewarm_poll_count += 1
	# Bounded fallback: a load stuck in a non-terminal status forever must not hang the
	# prewarm loop. Past the hard MAX bound, abandon the threaded attempt and resolve
	# synchronously. The warn tier below keeps slow-but-progressing loads threaded.
	if _is_threaded_texture_prewarm_expired(max_msec, max_polls):
		if emit_timeout_warning:
			_push_threaded_texture_prewarm_stale_warning()
		_drain_threaded_texture_prewarm()
		return {"done": true, "texture": _load_threaded_texture_fallback(path, missing_warning, failed_warning, prefer_imported_fallback)}
	if _is_threaded_texture_prewarm_stale():
		_push_threaded_texture_prewarm_stale_warning()
	return {"done": false, "texture": null}


static func _load_threaded_texture_fallback(
	path: String,
	missing_warning: String,
	failed_warning: String,
	prefer_imported_fallback: bool
) -> Texture2D:
	if prefer_imported_fallback:
		return load_imported_texture(path, missing_warning, failed_warning)
	return load_texture(path, missing_warning, failed_warning)


static func load_audio_stream(path: String, missing_warning: String = "", failed_warning: String = "") -> AudioStream:
	if _audio_cache.has(path):
		var cached_stream: Variant = _audio_cache[path]
		if cached_stream is AudioStream:
			return cached_stream
		_audio_cache.erase(path)

	# Keep audio source-first for the same stale imported-cache failure mode.
	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var raw_path: String = ProjectSettings.globalize_path(path)
		match path.get_extension().to_lower():
			"wav":
				var wav_stream := AudioStreamWAV.load_from_file(raw_path)
				if wav_stream != null:
					_audio_cache[path] = wav_stream
					return wav_stream
			"mp3":
				var mp3_stream := AudioStreamMP3.load_from_file(raw_path)
				if mp3_stream != null:
					_audio_cache[path] = mp3_stream
					return mp3_stream
			"ogg":
				var ogg_stream := AudioStreamOggVorbis.load_from_file(raw_path)
				if ogg_stream != null:
					_audio_cache[path] = ogg_stream
					return ogg_stream

	var cached_resource: AudioStream = _get_resource_loader_audio_stream(path)
	if cached_resource != null:
		_audio_cache[path] = cached_resource
		return cached_resource

	var imported_exists: bool = _can_load_imported_resource(path)
	if imported_exists:
		var stream_resource: Resource = ResourceLoader.load(path)
		if stream_resource is AudioStream:
			_audio_cache[path] = stream_resource
			return stream_resource

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func get_cached_audio_stream(path: String) -> AudioStream:
	if not _audio_cache.has(path):
		return null
	var cached_stream: Variant = _audio_cache[path]
	if cached_stream is AudioStream:
		return cached_stream
	_audio_cache.erase(path)
	return null


static func store_audio_stream(path: String, stream: AudioStream) -> void:
	if path == "" or stream == null:
		return
	_audio_cache[path] = stream


static func audio_resource_exists(path: String) -> bool:
	if path == "":
		return false
	return _can_load_imported_resource(path) or ResourceLoader.exists(path, "AudioStream")


static func prewarm_audio_stream_threaded_step(path: String, missing_warning: String = "", failed_warning: String = "") -> Dictionary:
	if path == "":
		return {"done": true, "stream": null}
	var cached_stream: AudioStream = get_cached_audio_stream(path)
	if cached_stream != null:
		return {"done": true, "stream": cached_stream}
	var cached_resource: AudioStream = _get_resource_loader_audio_stream(path)
	if cached_resource != null:
		_audio_cache[path] = cached_resource
		return {"done": true, "stream": cached_resource}
	if not _is_thread_loadable_audio_path(path):
		return {"done": true, "stream": load_audio_stream(path, missing_warning, failed_warning)}

	if _threaded_audio_prewarm_path == "":
		var request_error := ResourceLoader.load_threaded_request(path, "AudioStream", true)
		if request_error != OK and request_error != ERR_BUSY:
			return {"done": true, "stream": load_audio_stream(path, missing_warning, failed_warning)}
		_threaded_audio_prewarm_path = path
		_threaded_audio_prewarm_started_msec = Time.get_ticks_msec()
		_threaded_audio_prewarm_poll_count = 0
		return {"done": false, "stream": null}
	if _threaded_audio_prewarm_path != path:
		_threaded_audio_prewarm_poll_count += 1
		if _is_threaded_audio_prewarm_expired():
			_drain_threaded_audio_prewarm()
			return {"done": true, "stream": load_audio_stream(path, missing_warning, failed_warning)}
		return {"done": false, "stream": null}

	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress_values)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_clear_threaded_audio_prewarm()
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource is AudioStream:
				var stream: AudioStream = resource
				store_audio_stream(path, stream)
				return {"done": true, "stream": stream}
			return {"done": true, "stream": load_audio_stream(path, missing_warning, failed_warning)}
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_clear_threaded_audio_prewarm()
			return {"done": true, "stream": load_audio_stream(path, missing_warning, failed_warning)}
	_threaded_audio_prewarm_poll_count += 1
	if _is_threaded_audio_prewarm_expired():
		_drain_threaded_audio_prewarm()
		return {"done": true, "stream": load_audio_stream(path, missing_warning, failed_warning)}
	return {"done": false, "stream": null}


static func load_font(path: String, missing_warning: String = "", failed_warning: String = "") -> Font:
	if _font_cache.has(path):
		var cached_font: Variant = _font_cache[path]
		if cached_font is Font:
			return cached_font
		_font_cache.erase(path)

	var raw_exists: bool = FileAccess.file_exists(path)
	if raw_exists:
		var font_file := FontFile.new()
		if font_file.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK:
			_font_cache[path] = font_file
			return font_file

	var imported_exists: bool = _can_load_imported_resource(path)
	if imported_exists:
		var font_resource: Resource = load(path)
		if font_resource is Font:
			_font_cache[path] = font_resource
			return font_resource

	if not raw_exists and not imported_exists:
		_push_path_warning(missing_warning, path)
	else:
		_push_path_warning(failed_warning, path)
	return null


static func _push_path_warning(template: String, path: String) -> void:
	if template != "":
		push_warning(template % path)


static func _can_load_imported_resource(path: String) -> bool:
	var import_path := "%s.import" % path
	if not FileAccess.file_exists(import_path):
		return false

	var import_config := ConfigFile.new()
	if import_config.load(import_path) != OK:
		return false

	var remap_path: Variant = import_config.get_value("remap", "path", "")
	if remap_path is String and remap_path != "":
		return _has_non_empty_file(remap_path)

	var dest_files: Variant = import_config.get_value("deps", "dest_files", [])
	if dest_files is Array:
		if dest_files.is_empty():
			return false
		for dest_file in dest_files:
			if not (dest_file is String) or not _has_non_empty_file(dest_file):
				return false
		return true

	return true


static func _has_non_empty_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_length() > 0


static func _get_resource_loader_texture(path: String) -> Texture2D:
	if not ResourceLoader.has_cached(path):
		return null
	var cached_resource: Resource = ResourceLoader.load(path)
	if cached_resource is Texture2D:
		return cached_resource
	return null


static func _get_resource_loader_audio_stream(path: String) -> AudioStream:
	if not ResourceLoader.has_cached(path):
		return null
	var cached_resource: Resource = ResourceLoader.load(path)
	if cached_resource is AudioStream:
		return cached_resource
	return null


static func _is_thread_loadable_texture_path(path: String) -> bool:
	return can_thread_load_texture(path)


static func _is_thread_loadable_audio_path(path: String) -> bool:
	return audio_resource_exists(path)


static func _is_threaded_texture_prewarm_stale() -> bool:
	if _threaded_texture_prewarm_path == "":
		return false
	if _threaded_texture_prewarm_poll_count >= THREADED_TEXTURE_PREWARM_STALE_WARNING_POLLS:
		return true
	var elapsed_msec := Time.get_ticks_msec() - _threaded_texture_prewarm_started_msec
	return elapsed_msec >= THREADED_TEXTURE_PREWARM_STALE_WARNING_MSEC


static func _is_threaded_texture_prewarm_expired(max_msec: int, max_polls: int) -> bool:
	if _threaded_texture_prewarm_path == "":
		return false
	if max_polls > 0 and _threaded_texture_prewarm_poll_count >= max_polls:
		return true
	var elapsed_msec := Time.get_ticks_msec() - _threaded_texture_prewarm_started_msec
	return max_msec > 0 and elapsed_msec >= max_msec


static func _push_threaded_texture_prewarm_stale_warning() -> void:
	if _threaded_texture_prewarm_stale_warning_sent:
		return
	_threaded_texture_prewarm_stale_warning_sent = true
	var warning_message := "Threaded texture prewarm is still loading %s; keeping it off the main thread." % _threaded_texture_prewarm_path
	push_warning(warning_message)


static func _clear_threaded_texture_prewarm() -> void:
	_threaded_texture_prewarm_path = ""
	_threaded_texture_prewarm_started_msec = 0
	_threaded_texture_prewarm_poll_count = 0
	_threaded_texture_prewarm_stale_warning_sent = false


static func _drain_threaded_texture_prewarm() -> void:
	if _threaded_texture_prewarm_path == "":
		return
	var path := _threaded_texture_prewarm_path
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress_values)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(path)
	elif status != ResourceLoader.THREAD_LOAD_FAILED and status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(path)
	_clear_threaded_texture_prewarm()


static func _is_threaded_audio_prewarm_expired() -> bool:
	if _threaded_audio_prewarm_path == "":
		return false
	if _threaded_audio_prewarm_poll_count >= THREADED_AUDIO_PREWARM_MAX_POLLS:
		return true
	var elapsed_msec := Time.get_ticks_msec() - _threaded_audio_prewarm_started_msec
	return elapsed_msec >= THREADED_AUDIO_PREWARM_MAX_MSEC


static func _clear_threaded_audio_prewarm() -> void:
	_threaded_audio_prewarm_path = ""
	_threaded_audio_prewarm_started_msec = 0
	_threaded_audio_prewarm_poll_count = 0


static func _drain_threaded_audio_prewarm() -> void:
	if _threaded_audio_prewarm_path == "":
		return
	var path := _threaded_audio_prewarm_path
	var progress_values: Array = []
	var status := ResourceLoader.load_threaded_get_status(path, progress_values)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(path)
	elif status != ResourceLoader.THREAD_LOAD_FAILED and status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_get(path)
	_clear_threaded_audio_prewarm()


static func clear_caches() -> void:
	_drain_threaded_texture_prewarm()
	_drain_threaded_audio_prewarm()
	_texture_cache.clear()
	_audio_cache.clear()
	_font_cache.clear()
	_clear_threaded_texture_prewarm()
	_clear_threaded_audio_prewarm()
