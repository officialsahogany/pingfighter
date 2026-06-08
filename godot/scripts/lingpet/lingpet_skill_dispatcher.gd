extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const SKILL_KIND_NONE := "none"
const SKILL_KIND_HYDRO_SPHERE := "hydro_sphere"
const SKILL_KIND_HEADBUTT := "headbutt"
const SKILL_KIND_MOON_ORBIT := "moon_orbit"
const SKILL_KIND_BUBBLE_TRAP := "bubble_trap"
const SKILL_KIND_MILK_PRODUCTION := "milk_production"
const SKILL_KIND_THUNDER_ORB := "thunder_orb"
const SKILL_KIND_BOMB_SURPRISE := "bomb_surprise"
const SKILL_KIND_GATLING_BURST := "gatling_burst"
const SKILL_KIND_DRAGON_BREATH := "dragon_breath"
const SKILL_KIND_DRAGON_WING := "dragon_wing"
const SKILL_KIND_GHOST_SUMMON := "ghost_summon"
const SKILL_KIND_SOUL_CLONE := "soul_clone"
const SKILL_KIND_PUPPET_GRAB := "puppet_grab"
const HYDRO_SPHERE_SKILL_ID := "maribo_hydro_sphere"
const HEADBUTT_SKILL_ID := "lunabi_headbutt"
const MOON_ORBIT_SKILL_ID := "draft_bat_moon_orbit"
const BUBBLE_TRAP_SKILL_ID := "maribo_bubble_trap"
const MILK_PRODUCTION_SKILL_ID := "milkring_milk_production"
const THUNDER_ORB_SKILL_ID := "lumion_thunder_orb"
const BOMB_SURPRISE_SKILL_ID := "volty_bomb_surprise"
const GATLING_BURST_SKILL_ID := "volty_gatling_burst"
const DRAGON_BREATH_SKILL_ID := "red_dragon_dragon_breath"
const DRAGON_WING_SKILL_ID := "red_dragon_dragon_wing"
const RABI_GHOST_SUMMON_SKILL_ID := "rabi_ghost_summon"
const RABI_SOUL_CLONE_SKILL_ID := "rabi_soul_clone"
const PUPPET_GRAB_SKILL_ID := "koyora_puppet_control"
const SUPPORTED_SKILL_KINDS := {
	SKILL_KIND_HYDRO_SPHERE: true,
	SKILL_KIND_HEADBUTT: true,
	SKILL_KIND_MOON_ORBIT: true,
	SKILL_KIND_BUBBLE_TRAP: true,
	SKILL_KIND_MILK_PRODUCTION: true,
	SKILL_KIND_THUNDER_ORB: true,
	SKILL_KIND_BOMB_SURPRISE: true,
	SKILL_KIND_GATLING_BURST: true,
	SKILL_KIND_DRAGON_BREATH: true,
	SKILL_KIND_DRAGON_WING: true,
	SKILL_KIND_GHOST_SUMMON: true,
	SKILL_KIND_SOUL_CLONE: true,
	SKILL_KIND_PUPPET_GRAB: true,
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
		BUBBLE_TRAP_SKILL_ID:
			return SKILL_KIND_BUBBLE_TRAP
		MILK_PRODUCTION_SKILL_ID:
			return SKILL_KIND_MILK_PRODUCTION
		THUNDER_ORB_SKILL_ID:
			return SKILL_KIND_THUNDER_ORB
		BOMB_SURPRISE_SKILL_ID:
			return SKILL_KIND_BOMB_SURPRISE
		GATLING_BURST_SKILL_ID:
			return SKILL_KIND_GATLING_BURST
		DRAGON_BREATH_SKILL_ID:
			return SKILL_KIND_DRAGON_BREATH
		DRAGON_WING_SKILL_ID:
			return SKILL_KIND_DRAGON_WING
		RABI_GHOST_SUMMON_SKILL_ID:
			return SKILL_KIND_GHOST_SUMMON
		RABI_SOUL_CLONE_SKILL_ID:
			return SKILL_KIND_SOUL_CLONE
		PUPPET_GRAB_SKILL_ID:
			return SKILL_KIND_PUPPET_GRAB
		_:
			return SKILL_KIND_NONE


static func is_hydro_sphere(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_HYDRO_SPHERE


static func is_headbutt(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_HEADBUTT


static func is_moon_orbit(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_MOON_ORBIT


static func is_bubble_trap(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_BUBBLE_TRAP


static func is_milk_production(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_MILK_PRODUCTION


static func is_thunder_orb(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_THUNDER_ORB


static func is_bomb_surprise(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_BOMB_SURPRISE


static func is_gatling_burst(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_GATLING_BURST


static func is_dragon_breath(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_DRAGON_BREATH


static func is_dragon_wing(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_DRAGON_WING


static func is_ghost_summon(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_GHOST_SUMMON


static func is_soul_clone(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_SOUL_CLONE


static func is_puppet_grab(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_PUPPET_GRAB


static func has_supported_runtime(skill_id: String) -> bool:
	return get_skill_kind(skill_id) != SKILL_KIND_NONE


static func is_supported_kind(skill_kind: String) -> bool:
	return bool(SUPPORTED_SKILL_KINDS.get(skill_kind.strip_edges().to_lower(), false))
