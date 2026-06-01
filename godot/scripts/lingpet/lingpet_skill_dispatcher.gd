extends RefCounted

const SKILL_KIND_NONE := "none"
const SKILL_KIND_HYDRO_SPHERE := "hydro_sphere"
const HYDRO_SPHERE_SKILL_ID := "maribo_hydro_sphere"


static func get_skill_kind(skill_id: String) -> String:
	match skill_id.strip_edges().to_lower():
		HYDRO_SPHERE_SKILL_ID:
			return SKILL_KIND_HYDRO_SPHERE
		_:
			return SKILL_KIND_NONE


static func is_hydro_sphere(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_HYDRO_SPHERE


static func has_supported_runtime(skill_id: String) -> bool:
	return get_skill_kind(skill_id) != SKILL_KIND_NONE
