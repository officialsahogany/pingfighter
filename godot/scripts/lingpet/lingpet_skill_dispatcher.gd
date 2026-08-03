extends RefCounted

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")

const SKILL_KIND_NONE := "none"
const SKILL_KIND_HYDRO_SPHERE := "hydro_sphere"
const SKILL_KIND_HEADBUTT := "headbutt"
const SKILL_KIND_MOON_ORBIT := "moon_orbit"
const SKILL_KIND_BUBBLE_TRAP := "bubble_trap"
const SKILL_KIND_MILK_PRODUCTION := "milk_production"
const SKILL_KIND_MILK_SHOT := "milk_shot"
const SKILL_KIND_THUNDER_ORB := "thunder_orb"
const SKILL_KIND_SOLAR_BOLT := "solar_bolt"
const SKILL_KIND_BOMB_SURPRISE := "bomb_surprise"
const SKILL_KIND_GATLING_BURST := "gatling_burst"
const SKILL_KIND_DRAGON_BREATH := "dragon_breath"
const SKILL_KIND_DRAGON_WING := "dragon_wing"
const SKILL_KIND_GHOST_SUMMON := "ghost_summon"
const SKILL_KIND_SKELETON_ARCHER := "skeleton_archer"
const SKILL_KIND_BONE_BARRIER := "bone_barrier"
const SKILL_KIND_SOUL_CLONE := "soul_clone"
const SKILL_KIND_PUPPET_GRAB := "puppet_grab"
const SKILL_KIND_DOLL_CURSE := "doll_curse"
const SKILL_KIND_BANANA_SLICE := "banana_slice"
const SKILL_KIND_WILD_ROAR := "wild_roar"
const SKILL_KIND_STAR_COIL := "star_coil"
const SKILL_KIND_GRAVITY_ACCEL := "gravity_accel"
const SKILL_KIND_DWARF_MAGIC := "dwarf_magic"
const SKILL_KIND_SAND_PRISON := "sand_prison"
const SKILL_KIND_MOKRIN_TRANSFORM := "mokrin_transform"
const RESOURCE_CLASS_BALL_OWNER := "ball_owner"
const RESOURCE_CLASS_POS_OVERRIDE := "pos_override"
const HYDRO_SPHERE_SKILL_ID := "maribo_hydro_sphere"
const HEADBUTT_SKILL_ID := "lunabi_headbutt"
const MOON_ORBIT_SKILL_ID := "draft_bat_moon_orbit"
const BUBBLE_TRAP_SKILL_ID := "maribo_bubble_trap"
const MILK_PRODUCTION_SKILL_ID := "milkring_milk_production"
const MILK_SHOT_SKILL_ID := "milkring_milk_shot"
const THUNDER_ORB_SKILL_ID := "lumion_thunder_orb"
const SOLAR_BOLT_SKILL_ID := "lumion_solar_bolt"
const BOMB_SURPRISE_SKILL_ID := "volty_bomb_surprise"
const GATLING_BURST_SKILL_ID := "volty_gatling_burst"
const DRAGON_BREATH_SKILL_ID := "red_dragon_dragon_breath"
const DRAGON_WING_SKILL_ID := "red_dragon_dragon_wing"
const RABI_GHOST_SUMMON_SKILL_ID := "rabi_ghost_summon"
const NEKURING_SKELETON_ARCHER_SKILL_ID := "nekuring_skeleton_archer"
const NEKURING_BONE_BARRIER_SKILL_ID := "nekuring_bone_barrier"
const RABI_SOUL_CLONE_SKILL_ID := "rabi_soul_clone"
const PUPPET_GRAB_SKILL_ID := "koyora_puppet_control"
const DOLL_CURSE_SKILL_ID := "koyora_doll_curse"
const BANANA_SLICE_SKILL_ID := "monkeyring_banana_slice"
const WILD_ROAR_SKILL_ID := "monkeyring_wild_roar"
const STAR_COIL_SKILL_ID := "orosha_star_coil"
const SAND_PRISON_SKILL_ID := "rahoset_sand_prison"
const MOKRIN_TRANSFORM_SKILL_ID := "baekrin_mokrin_transform"
const SUPPORTED_SKILL_KINDS := {
	SKILL_KIND_HYDRO_SPHERE: true,
	SKILL_KIND_HEADBUTT: true,
	SKILL_KIND_MOON_ORBIT: true,
	SKILL_KIND_BUBBLE_TRAP: true,
	SKILL_KIND_MILK_PRODUCTION: true,
	SKILL_KIND_MILK_SHOT: true,
	SKILL_KIND_THUNDER_ORB: true,
	SKILL_KIND_SOLAR_BOLT: true,
	SKILL_KIND_BOMB_SURPRISE: true,
	SKILL_KIND_GATLING_BURST: true,
	SKILL_KIND_DRAGON_BREATH: true,
	SKILL_KIND_DRAGON_WING: true,
	SKILL_KIND_GHOST_SUMMON: true,
	SKILL_KIND_SKELETON_ARCHER: true,
	SKILL_KIND_BONE_BARRIER: true,
	SKILL_KIND_SOUL_CLONE: true,
	SKILL_KIND_PUPPET_GRAB: true,
	SKILL_KIND_DOLL_CURSE: true,
	SKILL_KIND_BANANA_SLICE: true,
	SKILL_KIND_WILD_ROAR: true,
	SKILL_KIND_STAR_COIL: true,
	SKILL_KIND_GRAVITY_ACCEL: true,
	SKILL_KIND_DWARF_MAGIC: true,
	SKILL_KIND_SAND_PRISON: true,
	SKILL_KIND_MOKRIN_TRANSFORM: true,
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
		MILK_SHOT_SKILL_ID:
			return SKILL_KIND_MILK_SHOT
		THUNDER_ORB_SKILL_ID:
			return SKILL_KIND_THUNDER_ORB
		SOLAR_BOLT_SKILL_ID:
			return SKILL_KIND_SOLAR_BOLT
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
		NEKURING_SKELETON_ARCHER_SKILL_ID:
			return SKILL_KIND_SKELETON_ARCHER
		NEKURING_BONE_BARRIER_SKILL_ID:
			return SKILL_KIND_BONE_BARRIER
		RABI_SOUL_CLONE_SKILL_ID:
			return SKILL_KIND_SOUL_CLONE
		PUPPET_GRAB_SKILL_ID:
			return SKILL_KIND_PUPPET_GRAB
		DOLL_CURSE_SKILL_ID:
			return SKILL_KIND_DOLL_CURSE
		BANANA_SLICE_SKILL_ID:
			return SKILL_KIND_BANANA_SLICE
		WILD_ROAR_SKILL_ID:
			return SKILL_KIND_WILD_ROAR
		STAR_COIL_SKILL_ID:
			return SKILL_KIND_STAR_COIL
		SAND_PRISON_SKILL_ID:
			return SKILL_KIND_SAND_PRISON
		MOKRIN_TRANSFORM_SKILL_ID:
			return SKILL_KIND_MOKRIN_TRANSFORM
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


static func is_milk_shot(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_MILK_SHOT


static func is_thunder_orb(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_THUNDER_ORB


static func is_solar_bolt(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_SOLAR_BOLT


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


static func is_skeleton_archer(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_SKELETON_ARCHER


static func is_bone_barrier(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_BONE_BARRIER


static func is_soul_clone(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_SOUL_CLONE


static func is_puppet_grab(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_PUPPET_GRAB


static func is_doll_curse(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_DOLL_CURSE


static func is_banana_slice(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_BANANA_SLICE


static func is_wild_roar(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_WILD_ROAR


static func is_star_coil(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_STAR_COIL


static func is_gravity_accel(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_GRAVITY_ACCEL


static func is_dwarf_magic(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_DWARF_MAGIC


static func is_sand_prison(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_SAND_PRISON


static func is_mokrin_transform(skill_id: String) -> bool:
	return get_skill_kind(skill_id) == SKILL_KIND_MOKRIN_TRANSFORM


static func has_supported_runtime(skill_id: String) -> bool:
	return get_skill_kind(skill_id) != SKILL_KIND_NONE


static func would_share_module(first_skill_id: String, second_skill_id: String) -> bool:
	var first_kind := get_skill_kind(first_skill_id)
	if first_kind == SKILL_KIND_NONE:
		return false
	return first_kind == get_skill_kind(second_skill_id)


static func get_exclusive_resource_classes(skill_id: String) -> Array[String]:
	var classes: Array[String] = []
	match get_skill_kind(skill_id):
		SKILL_KIND_HYDRO_SPHERE, SKILL_KIND_SOLAR_BOLT, SKILL_KIND_GHOST_SUMMON:
			classes.append(RESOURCE_CLASS_BALL_OWNER)
		SKILL_KIND_HEADBUTT, SKILL_KIND_BOMB_SURPRISE, SKILL_KIND_GATLING_BURST, SKILL_KIND_PUPPET_GRAB, SKILL_KIND_DOLL_CURSE, SKILL_KIND_BANANA_SLICE, SKILL_KIND_STAR_COIL, SKILL_KIND_SAND_PRISON:
			classes.append(RESOURCE_CLASS_POS_OVERRIDE)
		SKILL_KIND_WILD_ROAR:
			classes.append(RESOURCE_CLASS_BALL_OWNER)
			classes.append(RESOURCE_CLASS_POS_OVERRIDE)
		_:
			pass
	return classes



static func skills_share_exclusive_resource(first_skill_id: String, second_skill_id: String) -> bool:
	var first_classes := get_exclusive_resource_classes(first_skill_id)
	if first_classes.is_empty():
		return false
	for resource_class in get_exclusive_resource_classes(second_skill_id):
		if first_classes.has(resource_class):
			return true
	return false


static func has_exclusive_resource_class(skill_id: String, resource_class: String) -> bool:
	return get_exclusive_resource_classes(skill_id).has(resource_class)


static func is_supported_kind(skill_kind: String) -> bool:
	return bool(SUPPORTED_SKILL_KINDS.get(skill_kind.strip_edges().to_lower(), false))
