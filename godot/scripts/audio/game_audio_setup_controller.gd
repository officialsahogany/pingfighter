extends RefCounted

const ProjectResourceLoader := preload(
	"res://scripts/resources/project_resource_loader.gd"
)

const STREAM_PREWARM_PROGRESS_SHARE := 0.92
const READY_GROUP_PROGRESS := 0.96
const MAX_CONCURRENT_STREAM_REQUESTS := 12
const MAX_STREAM_COMPLETIONS_PER_STEP := 2

var _audio_setup_step := 0
var _audio_setup_stream_prewarm_group := -1
var _audio_setup_stream_prewarm_index := 0
var _bgm_setup_step := 0
var _stream_paths: Array[String] = []
var _audio_setup_stream_request_index := 0
var _audio_setup_stream_in_flight: Dictionary = {}
var _audio_setup_stream_completed: Dictionary = {}


func reset() -> void:
	_release_stream_group()
	_audio_setup_step = 0
	_bgm_setup_step = 0


func get_audio_setup_step() -> int:
	return _audio_setup_step


func set_audio_setup_step(value: int) -> void:
	if _audio_setup_step == value:
		return
	_audio_setup_step = value
	_release_stream_group()


func advance_audio_setup_step() -> void:
	_audio_setup_step += 1
	_release_stream_group()


func get_audio_setup_stream_prewarm_group() -> int:
	return _audio_setup_stream_prewarm_group


func set_audio_setup_stream_prewarm_group(value: int) -> void:
	_audio_setup_stream_prewarm_group = value
	if value != _audio_setup_step:
		_stream_paths.clear()


func get_audio_setup_stream_prewarm_index() -> int:
	return _audio_setup_stream_prewarm_index


func set_audio_setup_stream_prewarm_index(value: int) -> void:
	_audio_setup_stream_prewarm_index = maxi(value, 0)


func get_bgm_setup_step() -> int:
	return _bgm_setup_step


func set_bgm_setup_step(value: int) -> void:
	_bgm_setup_step = maxi(value, 0)


func advance_bgm_setup_step() -> void:
	_bgm_setup_step += 1


func needs_stream_paths(step: int) -> bool:
	return _audio_setup_stream_prewarm_group != step


func set_stream_paths(step: int, stream_paths: Array[String]) -> void:
	_release_stream_group()
	_audio_setup_stream_prewarm_group = step
	_audio_setup_stream_prewarm_index = 0
	var seen_paths: Dictionary = {}
	for path in stream_paths:
		if path == "" or seen_paths.has(path):
			continue
		seen_paths[path] = true
		_stream_paths.append(path)


func prewarm_streams_step(step: int, stream_paths: Array[String] = []) -> bool:
	if needs_stream_paths(step):
		set_stream_paths(step, stream_paths)

	var completions_this_step := 0
	var in_flight_indices: Array = _audio_setup_stream_in_flight.keys()
	in_flight_indices.sort()
	for index_value in in_flight_indices:
		if completions_this_step >= MAX_STREAM_COMPLETIONS_PER_STEP:
			break
		var stream_index := int(index_value)
		var path := str(_audio_setup_stream_in_flight.get(stream_index, ""))
		var result: Dictionary = ProjectResourceLoader.poll_audio_stream_threaded_batch(path)
		if not bool(result.get("done", false)):
			continue
		_audio_setup_stream_in_flight.erase(stream_index)
		_audio_setup_stream_completed[stream_index] = true
		completions_this_step += 1

	_advance_contiguous_stream_progress()
	while (
		_audio_setup_stream_request_index < _stream_paths.size()
		and _audio_setup_stream_in_flight.size() < MAX_CONCURRENT_STREAM_REQUESTS
		and completions_this_step < MAX_STREAM_COMPLETIONS_PER_STEP
	):
		var stream_index := _audio_setup_stream_request_index
		_audio_setup_stream_request_index += 1
		var path := str(_stream_paths[stream_index])
		if not _should_prewarm_audio_stream(path):
			_audio_setup_stream_completed[stream_index] = true
			continue
		if ProjectResourceLoader.get_cached_audio_stream(path) != null:
			_audio_setup_stream_completed[stream_index] = true
			continue
		var result: Dictionary = ProjectResourceLoader.request_audio_stream_threaded_batch(path)
		if bool(result.get("done", false)):
			_audio_setup_stream_completed[stream_index] = true
			completions_this_step += 1
			continue
		_audio_setup_stream_in_flight[stream_index] = path

	_advance_contiguous_stream_progress()
	return (
		_audio_setup_stream_prewarm_index >= _stream_paths.size()
		and _audio_setup_stream_in_flight.is_empty()
	)


func get_setup_progress(
	audio_setup_step_count: int,
	bgm_setup_step_count: int,
	setup_complete: bool
) -> float:
	if setup_complete:
		return 1.0
	var step_progress := get_audio_setup_step_progress(
		_audio_setup_step,
		audio_setup_step_count,
		bgm_setup_step_count
	)
	return clampf(
		(float(_audio_setup_step) + step_progress) / float(audio_setup_step_count),
		0.0,
		1.0
	)


func get_audio_setup_step_progress(
	step: int,
	audio_setup_step_count: int,
	bgm_setup_step_count: int,
	stream_path_count: int = -1
) -> float:
	if step >= audio_setup_step_count:
		return 1.0
	if step < 0:
		return 0.0
	var resolved_stream_path_count := maxi(stream_path_count, 0)
	var stream_progress := 0.0
	if _audio_setup_stream_prewarm_group == step:
		resolved_stream_path_count = _stream_paths.size()
		if resolved_stream_path_count > 0:
			stream_progress = clampf(
				float(_audio_setup_stream_prewarm_index) / float(resolved_stream_path_count),
				0.0,
				1.0
			)
	if resolved_stream_path_count > 0:
		if stream_progress < 1.0:
			return stream_progress * STREAM_PREWARM_PROGRESS_SHARE
	if step == audio_setup_step_count - 1:
		return STREAM_PREWARM_PROGRESS_SHARE + (
			(1.0 - STREAM_PREWARM_PROGRESS_SHARE)
			* clampf(float(_bgm_setup_step) / float(bgm_setup_step_count), 0.0, 1.0)
		)
	return READY_GROUP_PROGRESS


func is_setup_complete(
	audio_setup_step_count: int,
	bgm_setup_step_count: int,
	all_bgm_players_ready: bool,
	required_bgm_player_ready: bool
) -> bool:
	if _bgm_setup_step >= bgm_setup_step_count and all_bgm_players_ready:
		return true
	return (
		_audio_setup_step >= audio_setup_step_count
		and _bgm_setup_step >= bgm_setup_step_count
		and required_bgm_player_ready
	)


func _release_stream_group() -> void:
	var in_flight_paths: Array[String] = []
	for path_value in _audio_setup_stream_in_flight.values():
		in_flight_paths.append(str(path_value))
	ProjectResourceLoader.release_audio_stream_threaded_batch(in_flight_paths)
	_audio_setup_stream_prewarm_group = -1
	_audio_setup_stream_prewarm_index = 0
	_audio_setup_stream_request_index = 0
	_audio_setup_stream_in_flight.clear()
	_audio_setup_stream_completed.clear()
	_stream_paths.clear()


func _advance_contiguous_stream_progress() -> void:
	while _audio_setup_stream_completed.has(_audio_setup_stream_prewarm_index):
		_audio_setup_stream_completed.erase(_audio_setup_stream_prewarm_index)
		_audio_setup_stream_prewarm_index += 1


func _should_prewarm_audio_stream(path: String) -> bool:
	return (
		path != ""
		and (FileAccess.file_exists(path) or ProjectResourceLoader.audio_resource_exists(path))
	)
