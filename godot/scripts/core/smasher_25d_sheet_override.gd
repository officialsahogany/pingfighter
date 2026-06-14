extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const ENV_KEY := "PINGFIGHTER_SMASHER_25D"
const FLAG_PATH := "res://smasher_25d_sheets.flag"

const IDLE_SHEET_PATH := "res://assets/sprites/characters/smasher/25d/smasher_25d_idle_4x2_160.png"
const WALK_LEFT_SHEET_PATH := "res://assets/sprites/characters/smasher/25d/smasher_25d_walk_left_4x2_160.png"
const WALK_RIGHT_SHEET_PATH := "res://assets/sprites/characters/smasher/25d/smasher_25d_walk_right_4x2_160.png"
const ATTACK_LEFT_SHEET_PATH := "res://assets/sprites/characters/smasher/25d/smasher_25d_attack_left_4x4_160.png"

const REQUIRED_SHEET_PATHS := {
	"idle": IDLE_SHEET_PATH,
	"walk_left": WALK_LEFT_SHEET_PATH,
	"walk_right": WALK_RIGHT_SHEET_PATH,
	"attack_left": ATTACK_LEFT_SHEET_PATH,
}

static var _checked: bool = false
static var _toggle_requested: bool = false
static var _active_sheet_paths: Dictionary = {}
static var _required_sheet_paths_for_test: Dictionary = {}


static func is_toggle_requested() -> bool:
	_ensure_checked()
	return _toggle_requested


static func is_active() -> bool:
	return not get_active_sheet_paths().is_empty()


static func get_active_sheet_paths() -> Dictionary:
	_ensure_checked()
	return _active_sheet_paths.duplicate(true)


static func get_required_sheet_paths() -> Dictionary:
	return _get_required_sheet_paths().duplicate(true)


static func get_missing_required_sheet_paths() -> Array[String]:
	_ensure_checked()
	var missing: Array[String] = []
	for path_value in _get_required_sheet_paths().values():
		var path := str(path_value)
		if not _is_sheet_path_available(path):
			missing.append(path)
	return missing


static func set_required_sheet_paths_for_test(paths: Dictionary) -> void:
	_required_sheet_paths_for_test = paths.duplicate(true)
	reset_cache_for_test()


static func clear_required_sheet_paths_for_test() -> void:
	_required_sheet_paths_for_test = {}
	reset_cache_for_test()


static func reset_cache_for_test() -> void:
	_checked = false
	_toggle_requested = false
	_active_sheet_paths = {}


static func _ensure_checked() -> void:
	if _checked:
		return
	_checked = true
	_toggle_requested = _read_toggle_requested()
	_active_sheet_paths = {}
	if not _toggle_requested:
		return
	var required_paths := _get_required_sheet_paths()
	for path_value in required_paths.values():
		if not _is_sheet_path_available(str(path_value)):
			return
	_active_sheet_paths = required_paths.duplicate(true)


static func _get_required_sheet_paths() -> Dictionary:
	if not _required_sheet_paths_for_test.is_empty():
		return _required_sheet_paths_for_test
	return REQUIRED_SHEET_PATHS


static func _read_toggle_requested() -> bool:
	var value := OS.get_environment(ENV_KEY).strip_edges().to_lower()
	return value in ["1", "true", "yes", "on"] or FileAccess.file_exists(FLAG_PATH)


static func _is_sheet_path_available(path: String) -> bool:
	return (
		ProjectResourceLoader.get_cached_texture(path) != null
		or FileAccess.file_exists(path)
		or ProjectResourceLoader.texture_resource_exists(path)
	)
