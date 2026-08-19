extends RefCounted

const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)
const VERTICAL_SLICE_ENV_KEY := "TOWER_ASCENT_VERTICAL_SLICE"

static var _vertical_slice_override: int = -1


static func is_vertical_slice_enabled() -> bool:
	if _vertical_slice_override >= 0:
		return _vertical_slice_override == 1
	var raw_value := OS.get_environment(VERTICAL_SLICE_ENV_KEY).strip_edges().to_lower()
	return resolve_vertical_slice_enabled(
		raw_value,
		OS.has_feature(TowerAuditionBuildConfig.TEMP_AUDITION_EXPORT_FEATURE)
	)


static func resolve_vertical_slice_enabled(
	raw_value: String,
	has_audition_export_feature: bool
) -> bool:
	var normalized := raw_value.strip_edges().to_lower()
	if normalized in ["1", "true", "yes", "on"]:
		return true
	if normalized in ["0", "false", "no", "off"]:
		return false
	return TowerAuditionBuildConfig.is_enabled_for_export_feature(
		has_audition_export_feature
	)


static func debug_set_vertical_slice_enabled(enabled: bool) -> void:
	_vertical_slice_override = 1 if enabled else 0


static func debug_clear_vertical_slice_override() -> void:
	_vertical_slice_override = -1
