extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const MISSING_TEXTURE_PATH := "res://assets/__missing_warning_dedup_fixture__.png"
const MISSING_AUDIO_PATH := "res://assets/__missing_warning_dedup_fixture__.wav"
const TEXTURE_WARNING := "dedup texture missing: %s"
const AUDIO_WARNING := "dedup audio missing: %s"

var _failed := false


func _init() -> void:
	ProjectResourceLoader.clear_warning_dedup_for_tests()
	_expect(
		ProjectResourceLoader.claim_path_warning_for_tests(TEXTURE_WARNING, MISSING_TEXTURE_PATH),
		"first missing texture warning should claim the path-warning key"
	)
	_expect(
		not ProjectResourceLoader.claim_path_warning_for_tests(TEXTURE_WARNING, MISSING_TEXTURE_PATH),
		"second matching missing texture warning should be suppressed"
	)
	_expect(
		not ProjectResourceLoader.claim_path_warning_for_tests(TEXTURE_WARNING, MISSING_TEXTURE_PATH),
		"third matching missing texture warning should remain suppressed"
	)
	_expect(
		ProjectResourceLoader.get_warning_dedup_count_for_tests() == 1,
		"repeated missing texture warnings for the same template/path should dedup to one key"
	)
	_expect(
		ProjectResourceLoader.claim_path_warning_for_tests("dedup texture alternate warning: %s", MISSING_TEXTURE_PATH),
		"a different warning template for the same path should claim a distinct warning key"
	)
	_expect(
		ProjectResourceLoader.get_warning_dedup_count_for_tests() == 2,
		"a different warning template for the same path should keep a distinct warning key"
	)
	_expect(
		not ProjectResourceLoader.claim_path_warning_for_tests("", MISSING_TEXTURE_PATH),
		"empty warning templates should be ignored"
	)
	_expect(
		ProjectResourceLoader.get_warning_dedup_count_for_tests() == 2,
		"empty warning templates should not create dedup keys"
	)
	_expect(
		ProjectResourceLoader.claim_path_warning_for_tests(AUDIO_WARNING, MISSING_AUDIO_PATH),
		"first missing audio warning should claim the shared path-warning key"
	)
	_expect(
		not ProjectResourceLoader.claim_path_warning_for_tests(AUDIO_WARNING, MISSING_AUDIO_PATH),
		"repeated missing audio warning should be suppressed"
	)
	_expect(
		ProjectResourceLoader.get_warning_dedup_count_for_tests() == 3,
		"audio missing warnings should share the same path-warning dedup path"
	)

	if _failed:
		quit(1)
		return
	print("project_resource_loader_warning_dedup_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
	quit(1)
