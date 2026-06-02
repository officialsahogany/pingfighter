extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const SKILL_KIND_NONE := "none"
const SKILL_KIND_HYDRO_SPHERE := "hydro_sphere"
const SKILL_KIND_HEADBUTT := "headbutt"
const SKILL_KIND_MOON_ORBIT := "moon_orbit"
const HYDRO_SPHERE_SKILL_ID := "maribo_hydro_sphere"
const HEADBUTT_SKILL_ID := "lunabi_headbutt"
const MOON_ORBIT_SKILL_ID := "draft_bat_moon_orbit"
const SUPPORTED_SKILL_KINDS := {
	SKILL_KIND_HYDRO_SPHERE: true,
	SKILL_KIND_HEADBUTT: true,
	SKILL_KIND_MOON_ORBIT: true,
}


static func get_skill_kind(skill_id: String) -> String:
	var normalized := skill_id.strip_edges().to_lower()
	if normalized == "":
		return SKILL_KIND_NONE
	var catalog_kind := LingpetCatalog.get_active_skill_runtime_kind(normalized)
	if catalog_kind != "":
		return catalog_kind if is_supported_kind(catalog_kind) else SKILL_KIND_NONE
	match normalized:
		HYDRO_SPHERE_SKILL_ID:
			return SKILL_KIND_HYDRO_SPHERE
		HEADBUTT_SKILL_ID:
			return SKILL_KIND_HEADBUTT
		MOON_ORBIT_SKILL_ID:
			return SKILL_KIND_MOON_ORBIT
		_:
			return SKILL_KIND_NONE


static func is_hydro_sphere(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_HYDRO_SPHERE


static func is_headbutt(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_HEADBUTT


static func is_moon_orbit(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_MOON_ORBIT


static func has_supported_runtime(skill_id: String) -> bool:
	return get_skill_kind(skill_id) != SKILL_KIND_NONE


static func is_supported_kind(skill_kind: String) -> bool:
	return bool(SUPPORTED_SKILL_KINDS.get(skill_kind.strip_edges().to_lower(), false))
