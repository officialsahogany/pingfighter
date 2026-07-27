extends RefCounted

const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillLaunchFeedbackRouter := preload("res://scripts/lingpet/lingpet_skill_launch_feedback_router.gd")
const LingpetSkillCompanionSurfaceRouter := preload("res://scripts/lingpet/lingpet_skill_companion_surface_router.gd")

const HYDRO_SPHERE_SKILL_PATH := "res://scripts/lingpet/lingpet_hydro_sphere_skill.gd"
const HEADBUTT_SKILL_PATH := "res://scripts/lingpet/lingpet_headbutt_skill.gd"
const MOON_ORBIT_SKILL_PATH := "res://scripts/lingpet/lingpet_moon_orbit_skill.gd"
const BUBBLE_TRAP_SKILL_PATH := "res://scripts/lingpet/lingpet_bubble_trap_skill.gd"
const MILK_PRODUCTION_SKILL_PATH := "res://scripts/lingpet/lingpet_milk_production_skill.gd"
const MILK_SHOT_SKILL_PATH := "res://scripts/lingpet/lingpet_milk_shot_skill.gd"
const THUNDER_ORB_SKILL_PATH := "res://scripts/lingpet/lingpet_thunder_orb_skill.gd"
const SOLAR_BOLT_SKILL_PATH := "res://scripts/lingpet/lingpet_solar_bolt_skill.gd"
const BOMB_SURPRISE_SKILL_PATH := "res://scripts/lingpet/lingpet_bomb_surprise_skill.gd"
const GATLING_BURST_SKILL_PATH := "res://scripts/lingpet/lingpet_gatling_burst_skill.gd"
const DRAGON_BREATH_SKILL_PATH := "res://scripts/lingpet/lingpet_dragon_breath_skill.gd"
const DRAGON_WING_SKILL_PATH := "res://scripts/lingpet/lingpet_dragon_wing_skill.gd"
const GHOST_SUMMON_SKILL_PATH := "res://scripts/lingpet/lingpet_ghost_summon_skill.gd"
const SKELETON_ARCHER_SKILL_PATH := "res://scripts/lingpet/lingpet_skeleton_archer_skill.gd"
const BONE_BARRIER_SKILL_PATH := "res://scripts/lingpet/lingpet_bone_barrier_skill.gd"
const SOUL_CLONE_SKILL_PATH := "res://scripts/lingpet/lingpet_soul_clone_skill.gd"
const PUPPET_GRAB_SKILL_PATH := "res://scripts/lingpet/lingpet_puppet_grab_skill.gd"
const DOLL_CURSE_SKILL_PATH := "res://scripts/lingpet/lingpet_doll_curse_skill.gd"
const BANANA_SLICE_SKILL_PATH := "res://scripts/lingpet/lingpet_banana_slice_skill.gd"
const WILD_ROAR_SKILL_PATH := "res://scripts/lingpet/lingpet_wild_roar_skill.gd"
const STAR_COIL_SKILL_PATH := "res://scripts/lingpet/lingpet_star_coil_skill.gd"
const GRAVITY_ACCEL_SKILL_PATH := "res://scripts/lingpet/lingpet_gravity_accel_skill.gd"
const DWARF_MAGIC_SKILL_PATH := "res://scripts/lingpet/lingpet_dwarf_magic_skill.gd"
const SAND_PRISON_SKILL_PATH := "res://scripts/lingpet/lingpet_sand_prison_skill.gd"

const SKELETON_ARCHER_DRAW_COUNTERS := [
	{"counter_name": "lingpet.skeleton_archer.archers", "snapshot_key": "skeleton_archer_archer_count"},
	{"counter_name": "lingpet.skeleton_archer.arrows", "snapshot_key": "skeleton_archer_arrow_count"},
	{"counter_name": "lingpet.skeleton_archer.dying", "snapshot_key": "skeleton_archer_dying_count"},
	{"counter_name": "lingpet.skeleton_archer.particles", "snapshot_key": "skeleton_archer_particle_count"},
]
const BONE_BARRIER_DRAW_COUNTERS := [
	{"counter_name": "lingpet.bone_barrier.barriers", "snapshot_key": "bone_barrier_barrier_count"},
	{"counter_name": "lingpet.bone_barrier.dying", "snapshot_key": "bone_barrier_dying_count"},
	{"counter_name": "lingpet.bone_barrier.particles", "snapshot_key": "bone_barrier_particle_count"},
]
const MILK_SHOT_DRAW_COUNTERS := [
	{"counter_name": "lingpet.milk_shot.projectiles", "snapshot_key": "milk_shot_projectile_count"},
	{"counter_name": "lingpet.milk_shot.particles", "snapshot_key": "milk_shot_particle_count"},
]
const STAR_COIL_DRAW_COUNTERS := [
	{"counter_name": "lingpet.star_coil.trail", "snapshot_key": "star_coil_trail_count"},
	{"counter_name": "lingpet.star_coil.sparks", "snapshot_key": "star_coil_spark_count"},
]

var _hydro_sphere_skill: Object = null
var _headbutt_skill: Object = null
var _moon_orbit_skill: Object = null
var _bubble_trap_skill: Object = null
var _milk_production_skill: Object = null
var _milk_shot_skill: Object = null
var _thunder_orb_skill: Object = null
var _solar_bolt_skill: Object = null
var _bomb_surprise_skill: Object = null
var _gatling_burst_skill: Object = null
var _dragon_breath_skill: Object = null
var _dragon_wing_skill: Object = null
var _ghost_summon_skill: Object = null
var _skeleton_archer_skill: Object = null
var _bone_barrier_skill: Object = null
var _soul_clone_skill: Object = null
var _puppet_grab_skill: Object = null
var _doll_curse_skill: Object = null
var _banana_slice_skill: Object = null
var _wild_roar_skill: Object = null
var _star_coil_skill: Object = null
var _gravity_accel_skill: Object = null
var _dwarf_magic_skill: Object = null
var _sand_prison_skill: Object = null
var _launch_feedback_router := LingpetSkillLaunchFeedbackRouter.new()
var _companion_surface_router := LingpetSkillCompanionSurfaceRouter.new()


func reset(owner: Object = null, registry: Object = null) -> void:
	_reset_skill(_hydro_sphere_skill, owner, registry)
	_reset_skill(_headbutt_skill, owner, registry)
	_reset_skill(_moon_orbit_skill, owner, registry)
	_reset_skill(_bubble_trap_skill, owner, registry)
	_reset_skill(_milk_production_skill, owner, registry)
	_reset_skill(_milk_shot_skill, owner, registry)
	_reset_skill(_thunder_orb_skill, owner, registry)
	_reset_skill(_solar_bolt_skill, owner, registry)
	_reset_skill(_bomb_surprise_skill, owner, registry)
	_reset_skill(_gatling_burst_skill, owner, registry)
	_reset_skill(_dragon_breath_skill, owner, registry)
	_reset_skill(_dragon_wing_skill, owner, registry)
	_reset_skill(_ghost_summon_skill, owner, registry)
	_reset_skill(_skeleton_archer_skill, owner, registry)
	_reset_skill(_bone_barrier_skill, owner, registry)
	_reset_skill(_soul_clone_skill, owner, registry)
	_reset_skill(_puppet_grab_skill, owner, registry)
	_reset_skill(_doll_curse_skill, owner, registry)
	_reset_skill(_banana_slice_skill, owner, registry)
	_reset_skill(_wild_roar_skill, owner, registry)
	_reset_skill(_star_coil_skill, owner, registry)
	_reset_skill(_gravity_accel_skill, owner, registry)
	_reset_skill(_dwarf_magic_skill, owner, registry)
	_reset_skill(_sand_prison_skill, owner, registry)


func clear_for_tests(owner: Object = null, registry: Object = null) -> void:
	reset(owner, registry)
	_hydro_sphere_skill = null
	_headbutt_skill = null
	_moon_orbit_skill = null
	_bubble_trap_skill = null
	_milk_production_skill = null
	_milk_shot_skill = null
	_thunder_orb_skill = null
	_solar_bolt_skill = null
	_bomb_surprise_skill = null
	_gatling_burst_skill = null
	_dragon_breath_skill = null
	_dragon_wing_skill = null
	_ghost_summon_skill = null
	_skeleton_archer_skill = null
	_bone_barrier_skill = null
	_soul_clone_skill = null
	_puppet_grab_skill = null
	_doll_curse_skill = null
	_banana_slice_skill = null
	_wild_roar_skill = null
	_star_coil_skill = null
	_gravity_accel_skill = null
	_dwarf_magic_skill = null
	_sand_prison_skill = null


# Per-round reset. Skills that implement reset_round() persist their state
# across the round boundary (e.g. Bone Barrier keeps its installed barriers);
# every other skill takes a full reset, identical to reset().
func reset_round(owner: Object = null, registry: Object = null) -> void:
	_reset_skill_round(_hydro_sphere_skill, owner, registry)
	_reset_skill_round(_headbutt_skill, owner, registry)
	_reset_skill_round(_moon_orbit_skill, owner, registry)
	_reset_skill_round(_bubble_trap_skill, owner, registry)
	_reset_skill_round(_milk_production_skill, owner, registry)
	_reset_skill_round(_milk_shot_skill, owner, registry)
	_reset_skill_round(_thunder_orb_skill, owner, registry)
	_reset_skill_round(_solar_bolt_skill, owner, registry)
	_reset_skill_round(_bomb_surprise_skill, owner, registry)
	_reset_skill_round(_gatling_burst_skill, owner, registry)
	_reset_skill_round(_dragon_breath_skill, owner, registry)
	_reset_skill_round(_dragon_wing_skill, owner, registry)
	_reset_skill_round(_ghost_summon_skill, owner, registry)
	_reset_skill_round(_skeleton_archer_skill, owner, registry)
	_reset_skill_round(_bone_barrier_skill, owner, registry)
	_reset_skill_round(_soul_clone_skill, owner, registry)
	_reset_skill_round(_puppet_grab_skill, owner, registry)
	_reset_skill_round(_doll_curse_skill, owner, registry)
	_reset_skill_round(_banana_slice_skill, owner, registry)
	_reset_skill_round(_wild_roar_skill, owner, registry)
	_reset_skill_round(_star_coil_skill, owner, registry)
	_reset_skill_round(_gravity_accel_skill, owner, registry)
	_reset_skill_round(_dwarf_magic_skill, owner, registry)
	_reset_skill_round(_sand_prison_skill, owner, registry)


func update(delta: float, owner: Object, registry: Object = null, skill_id: String = "", launch_context: Dictionary = {}) -> void:
	var safe_delta := maxf(0.0, delta)
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_get_hydro_sphere_skill().update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			_get_headbutt_skill().update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			_get_moon_orbit_skill().update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			_get_bubble_trap_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			_get_milk_production_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			_get_milk_shot_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			_get_thunder_orb_skill().update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			_get_solar_bolt_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			_get_bomb_surprise_skill().update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			_get_gatling_burst_skill().update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			_get_dragon_breath_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			_get_dragon_wing_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			_get_ghost_summon_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			_get_skeleton_archer_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			_get_bone_barrier_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			_get_soul_clone_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			_get_puppet_grab_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			_get_doll_curse_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE:
			_get_banana_slice_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			_get_wild_roar_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			_get_star_coil_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			_get_gravity_accel_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			_get_dwarf_magic_skill().update(safe_delta, owner, registry, launch_context)
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			_get_sand_prison_skill().update(safe_delta, owner, registry, launch_context)
		_:
			pass


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, perf_logger: Object = null) -> void:
	_draw_skill(_hydro_sphere_skill, canvas, shake_offset)
	_draw_skill(_headbutt_skill, canvas, shake_offset)
	_draw_skill(_moon_orbit_skill, canvas, shake_offset)
	_draw_skill(_bubble_trap_skill, canvas, shake_offset)
	_draw_skill(_milk_production_skill, canvas, shake_offset)
	_draw_skill_instrumented(_milk_shot_skill, canvas, shake_offset, "draw.lingpet.milk_shot", perf_logger, MILK_SHOT_DRAW_COUNTERS)
	_draw_skill(_thunder_orb_skill, canvas, shake_offset)
	_draw_skill(_solar_bolt_skill, canvas, shake_offset)
	_draw_skill(_bomb_surprise_skill, canvas, shake_offset)
	_draw_skill(_gatling_burst_skill, canvas, shake_offset)
	_draw_skill(_dragon_breath_skill, canvas, shake_offset)
	_draw_skill(_dragon_wing_skill, canvas, shake_offset)
	_draw_skill(_ghost_summon_skill, canvas, shake_offset)
	_draw_skill_instrumented(_skeleton_archer_skill, canvas, shake_offset, "draw.lingpet.skeleton_archer", perf_logger, SKELETON_ARCHER_DRAW_COUNTERS)
	_draw_skill_instrumented(_bone_barrier_skill, canvas, shake_offset, "draw.lingpet.bone_barrier", perf_logger, BONE_BARRIER_DRAW_COUNTERS)
	_draw_skill(_soul_clone_skill, canvas, shake_offset)
	_draw_skill(_puppet_grab_skill, canvas, shake_offset)
	_draw_skill(_doll_curse_skill, canvas, shake_offset)
	_draw_skill(_banana_slice_skill, canvas, shake_offset)
	_draw_skill(_wild_roar_skill, canvas, shake_offset)
	_draw_skill_instrumented(_star_coil_skill, canvas, shake_offset, "draw.lingpet.star_coil", perf_logger, STAR_COIL_DRAW_COUNTERS)
	_draw_skill(_gravity_accel_skill, canvas, shake_offset)
	_draw_skill(_dwarf_magic_skill, canvas, shake_offset)
	_draw_skill(_sand_prison_skill, canvas, shake_offset)


func has_visible_effects() -> bool:
	return (
		_skill_has_visible_effects(_hydro_sphere_skill)
		or _skill_has_visible_effects(_headbutt_skill)
		or _skill_has_visible_effects(_moon_orbit_skill)
		or _skill_has_visible_effects(_bubble_trap_skill)
		or _skill_has_visible_effects(_milk_production_skill)
		or _skill_has_visible_effects(_milk_shot_skill)
		or _skill_has_visible_effects(_thunder_orb_skill)
		or _skill_has_visible_effects(_solar_bolt_skill)
		or _skill_has_visible_effects(_bomb_surprise_skill)
		or _skill_has_visible_effects(_gatling_burst_skill)
		or _skill_has_visible_effects(_dragon_breath_skill)
		or _skill_has_visible_effects(_dragon_wing_skill)
		or _skill_has_visible_effects(_ghost_summon_skill)
		or _skill_has_visible_effects(_skeleton_archer_skill)
		or _skill_has_visible_effects(_bone_barrier_skill)
		or _skill_has_visible_effects(_soul_clone_skill)
		or _skill_has_visible_effects(_puppet_grab_skill)
		or _skill_has_visible_effects(_doll_curse_skill)
		or _skill_has_visible_effects(_banana_slice_skill)
		or _skill_has_visible_effects(_wild_roar_skill)
		or _skill_has_visible_effects(_star_coil_skill)
		or _skill_has_visible_effects(_gravity_accel_skill)
		or _skill_has_visible_effects(_dwarf_magic_skill)
		or _skill_has_visible_effects(_sand_prison_skill)
	)


func has_visible_effects_for_skill(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return _skill_has_visible_effects(_hydro_sphere_skill)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _skill_has_visible_effects(_headbutt_skill)
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return _skill_has_visible_effects(_moon_orbit_skill)
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return _skill_has_visible_effects(_bubble_trap_skill)
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return _skill_has_visible_effects(_milk_production_skill)
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			return _skill_has_visible_effects(_milk_shot_skill)
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return _skill_has_visible_effects(_thunder_orb_skill)
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return _skill_has_visible_effects(_solar_bolt_skill)
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _skill_has_visible_effects(_bomb_surprise_skill)
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _skill_has_visible_effects(_gatling_burst_skill)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			return _skill_has_visible_effects(_dragon_breath_skill)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			return _skill_has_visible_effects(_dragon_wing_skill)
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return _skill_has_visible_effects(_ghost_summon_skill)
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			return _skill_has_visible_effects(_skeleton_archer_skill)
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			return _skill_has_visible_effects(_bone_barrier_skill)
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return _skill_has_visible_effects(_soul_clone_skill)
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			return _skill_has_visible_effects(_puppet_grab_skill)
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			return _skill_has_visible_effects(_doll_curse_skill)
		LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE:
			return _skill_has_visible_effects(_banana_slice_skill)
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			return _skill_has_visible_effects(_wild_roar_skill)
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return _skill_has_visible_effects(_star_coil_skill)
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return _skill_has_visible_effects(_gravity_accel_skill)
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return _skill_has_visible_effects(_dwarf_magic_skill)
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return _skill_has_visible_effects(_sand_prison_skill)
		_:
			return false


func needs_runtime_update_for_skill(skill_id: String) -> bool:
	# LIVENESS, deliberately independent of relaunch policy. `is_launch_blocked`
	# looks similar but answers a DIFFERENT question and intentionally returns
	# false for nest-allowed skills (skeleton_archer / bone_barrier) whose
	# archers / barriers are still alive, so it must not be reused as the tick
	# gate's liveness source. Non-instantiating peek: this runs on the per-frame
	# companion slot tick.
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill: Object = _peek_skill_for_kind(skill_kind)
	if skill == null:
		return false
	if _skill_has_visible_effects(skill):
		return true
	if skill.has_method("is_active") and bool(skill.is_active()):
		return true
	# The few skills that expose no is_active() publish their own liveness surfaces.
	match skill_kind:
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return bool(skill.is_projectile_active())
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return bool(skill.is_projectile_active()) or bool(skill.is_orbit_field_active())
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return (
				bool(skill.is_projectile_active())
				or bool(skill.is_capture_active())
				or bool(skill.is_shot_sequence_active())
			)
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return bool(skill.is_producing())
	return false


func prewarm(skill_id: String) -> void:
	var skill: Object = _get_skill_for_kind(LingpetSkillDispatcher.get_skill_kind(skill_id))
	if skill != null and skill.has_method("prewarm"):
		skill.prewarm()


func prewarm_many(skill_ids: Array[String]) -> void:
	for skill_id in skill_ids:
		if skill_id != "":
			prewarm(skill_id)


func would_share_module(first_skill_id: String, second_skill_id: String) -> bool:
	return LingpetSkillDispatcher.would_share_module(first_skill_id, second_skill_id)


func skills_share_exclusive_resource(first_skill_id: String, second_skill_id: String) -> bool:
	return LingpetSkillDispatcher.skills_share_exclusive_resource(first_skill_id, second_skill_id)


func get_exclusive_resource_classes(skill_id: String) -> Array[String]:
	return LingpetSkillDispatcher.get_exclusive_resource_classes(skill_id)


func is_launch_blocked(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return _hydro_sphere_skill != null and bool(_hydro_sphere_skill.is_projectile_active())
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill != null and bool(_headbutt_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return _moon_orbit_skill != null and (bool(_moon_orbit_skill.is_projectile_active()) or bool(_moon_orbit_skill.is_orbit_field_active()))
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return _bubble_trap_skill != null and (bool(_bubble_trap_skill.is_projectile_active()) or bool(_bubble_trap_skill.is_capture_active()) or bool(_bubble_trap_skill.is_shot_sequence_active()))
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return _milk_production_skill != null and bool(_milk_production_skill.is_producing())
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			return _milk_shot_skill != null and bool(_milk_shot_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return _thunder_orb_skill != null and bool(_thunder_orb_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return _solar_bolt_skill != null and bool(_solar_bolt_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _bomb_surprise_skill != null and bool(_bomb_surprise_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _gatling_burst_skill != null and bool(_gatling_burst_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			return _dragon_breath_skill != null and bool(_dragon_breath_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			return _dragon_wing_skill != null and bool(_dragon_wing_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return _ghost_summon_skill != null and bool(_ghost_summon_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			return false
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			return false
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return _soul_clone_skill != null and bool(_soul_clone_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			return _puppet_grab_skill != null and bool(_puppet_grab_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			return _doll_curse_skill != null and bool(_doll_curse_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE:
			return _banana_slice_skill != null and bool(_banana_slice_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			return _wild_roar_skill != null and bool(_wild_roar_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return _star_coil_skill != null and bool(_star_coil_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return _gravity_accel_skill != null and bool(_gravity_accel_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return _dwarf_magic_skill != null and bool(_dwarf_magic_skill.is_active())
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return _sand_prison_skill != null and bool(_sand_prison_skill.is_active())
		_:
			return false


func can_arm(skill_id: String, params: Dictionary) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return bool(_get_headbutt_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			return bool(_get_dragon_breath_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			return true
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			return bool(_get_wild_roar_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return bool(_get_solar_bolt_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return bool(_get_star_coil_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return bool(_get_gravity_accel_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return bool(_get_dwarf_magic_skill().can_arm(params))
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return bool(_get_sand_prison_skill().can_arm(params))
		_:
			return true


func launch(skill_id: String, origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_get_hydro_sphere_skill().launch(origin, launch_context)
			return true
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return bool(_get_headbutt_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			_get_moon_orbit_skill().launch(origin)
			return true
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			_get_bubble_trap_skill().launch(origin, owner, launch_context)
			return true
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return bool(_get_milk_production_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			return bool(_get_milk_shot_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			_get_thunder_orb_skill().launch(origin, owner, launch_context)
			return true
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return bool(_get_solar_bolt_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return bool(_get_bomb_surprise_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return bool(_get_gatling_burst_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			_get_dragon_breath_skill().launch(origin, owner)
			return true
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			_get_dragon_wing_skill().launch(origin, owner, launch_context)
			return true
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return bool(_get_ghost_summon_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			return bool(_get_skeleton_archer_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			return bool(_get_bone_barrier_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return bool(_get_soul_clone_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			return bool(_get_puppet_grab_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			return bool(_get_doll_curse_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE:
			return bool(_get_banana_slice_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			return bool(_get_wild_roar_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return bool(_get_star_coil_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return bool(_get_gravity_accel_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return bool(_get_dwarf_magic_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return bool(_get_sand_prison_skill().launch(origin, owner, launch_context))
		_:
			return false


func get_launch_origin(skill_id: String, companion_pos: Vector2, companion_radius: float) -> Vector2:
	return _companion_surface_router.get_launch_origin(skill_id, companion_pos, companion_radius)


func has_companion_position_override(skill_id: String) -> bool:
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill := _peek_skill_for_kind(skill_kind)
	return _companion_surface_router.has_companion_position_override(skill_kind, skill)


func get_companion_position_override(skill_id: String, fallback: Vector2) -> Vector2:
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill := _peek_skill_for_kind(skill_kind)
	return _companion_surface_router.get_companion_position_override(skill_kind, skill, fallback)


func get_active_position_override_owner(skill_ids: Array, fallback: Vector2) -> Dictionary:
	for index in range(skill_ids.size()):
		var skill_id := str(skill_ids[index])
		if has_companion_position_override(skill_id):
			return {
				"has": true,
				"slot_index": index,
				"skill_id": skill_id,
				"pos": get_companion_position_override(skill_id, fallback),
			}
	return {
		"has": false,
		"slot_index": -1,
		"skill_id": "",
		"pos": fallback,
	}


func suppresses_companion_body_hit(skill_id: String) -> bool:
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill := _peek_skill_for_kind(skill_kind)
	return _companion_surface_router.suppresses_companion_body_hit(skill_kind, skill)


func suppresses_companion_body_draw(skill_id: String) -> bool:
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill := _peek_skill_for_kind(skill_kind)
	return _companion_surface_router.suppresses_companion_body_draw(skill_kind, skill)


func consume_companion_strike_request(skill_id: String) -> bool:
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill := _peek_skill_for_kind(skill_kind)
	return _companion_surface_router.consume_companion_strike_request(skill_kind, skill)


func should_show_cast_windup(skill_id: String) -> bool:
	return _companion_surface_router.should_show_cast_windup(skill_id)


func get_companion_cast_pose_progress(skill_id: String) -> float:
	var skill_kind := LingpetSkillDispatcher.get_skill_kind(skill_id)
	var skill := _peek_skill_for_kind(skill_kind)
	return _companion_surface_router.get_companion_cast_pose_progress(skill_kind, skill)


func trigger_launch_feedback(skill_id: String, registry: Object) -> void:
	_launch_feedback_router.trigger(skill_id, registry)


func get_boss_ai_context() -> Dictionary:
	if _banana_slice_skill == null or not _banana_slice_skill.has_method("get_boss_ai_context"):
		return {}
	var context: Variant = _banana_slice_skill.get_boss_ai_context()
	if context is Dictionary:
		return context
	return {}


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	_merge_skill_snapshot(snapshot, _hydro_sphere_skill)
	_merge_skill_snapshot(snapshot, _headbutt_skill)
	_merge_skill_snapshot(snapshot, _moon_orbit_skill)
	_merge_skill_snapshot(snapshot, _bubble_trap_skill)
	_merge_skill_snapshot(snapshot, _milk_production_skill)
	_merge_skill_snapshot(snapshot, _milk_shot_skill)
	_merge_skill_snapshot(snapshot, _thunder_orb_skill)
	_merge_skill_snapshot(snapshot, _solar_bolt_skill)
	_merge_skill_snapshot(snapshot, _bomb_surprise_skill)
	_merge_skill_snapshot(snapshot, _gatling_burst_skill)
	_merge_skill_snapshot(snapshot, _dragon_breath_skill)
	_merge_skill_snapshot(snapshot, _dragon_wing_skill)
	_merge_skill_snapshot(snapshot, _ghost_summon_skill)
	_merge_skill_snapshot(snapshot, _skeleton_archer_skill)
	_merge_skill_snapshot(snapshot, _bone_barrier_skill)
	_merge_skill_snapshot(snapshot, _soul_clone_skill)
	_merge_skill_snapshot(snapshot, _puppet_grab_skill)
	_merge_skill_snapshot(snapshot, _doll_curse_skill)
	_merge_skill_snapshot(snapshot, _banana_slice_skill)
	_merge_skill_snapshot(snapshot, _wild_roar_skill)
	_merge_skill_snapshot(snapshot, _star_coil_skill)
	_merge_skill_snapshot(snapshot, _gravity_accel_skill)
	_merge_skill_snapshot(snapshot, _dwarf_magic_skill)
	_merge_skill_snapshot(snapshot, _sand_prison_skill)
	return snapshot


func get_snapshot_for_skill_id(skill_id: String) -> Dictionary:
	return get_snapshot_for_kind(LingpetSkillDispatcher.get_skill_kind(skill_id))


func get_snapshot_for_kind(skill_kind: String) -> Dictionary:
	var skill: Object = _peek_skill_for_kind(skill_kind)
	if skill == null or not skill.has_method("get_snapshot"):
		return {}
	var raw_snapshot: Variant = skill.get_snapshot()
	if raw_snapshot is Dictionary:
		return raw_snapshot as Dictionary
	return {}


func get_hydro_puddle_particle_count_for_tests() -> int:
	return int(_get_hydro_sphere_skill().get_particle_count_for_tests())


func get_headbutt_hit_count_for_tests() -> int:
	return int(_get_headbutt_skill().get_hit_count_for_tests())


func set_headbutt_force_mega_roll_for_tests(value: float) -> void:
	_get_headbutt_skill().set_force_mega_roll_for_tests(value)


func get_headbutt_miss_count_for_tests() -> int:
	return int(_get_headbutt_skill().get_miss_count_for_tests())


func get_moon_orbit_particle_count_for_tests() -> int:
	return int(_get_moon_orbit_skill().get_particle_count_for_tests())


func get_bubble_trap_capture_count_for_tests() -> int:
	return int(_get_bubble_trap_skill().get_capture_count_for_tests())


func get_bubble_trap_pop_count_for_tests() -> int:
	return int(_get_bubble_trap_skill().get_pop_count_for_tests())


func get_milk_production_spawn_count_for_tests() -> int:
	return int(_get_milk_production_skill().get_spawn_count_for_tests())


func get_milk_shot_shot_count_for_tests() -> int:
	return int(_get_milk_shot_skill().get_shot_count_for_tests())


func get_milk_shot_hit_count_for_tests() -> int:
	return int(_get_milk_shot_skill().get_hit_count_for_tests())


func get_milk_shot_projectile_count_for_tests() -> int:
	return int(_get_milk_shot_skill().get_projectile_count_for_tests())


func get_milk_shot_snapshot_for_tests() -> Dictionary:
	return _get_milk_shot_skill().get_snapshot()


func get_thunder_orb_shock_count_for_tests() -> int:
	return int(_get_thunder_orb_skill().get_shock_applied_count_for_tests())


func get_solar_bolt_strike_count_for_tests() -> int:
	return int(_get_solar_bolt_skill().get_strike_count_for_tests())


func get_solar_bolt_scheduled_refires_for_tests() -> int:
	return int(_get_solar_bolt_skill().get_scheduled_refires_for_tests())


func get_solar_bolt_snapshot_for_tests() -> Dictionary:
	return _get_solar_bolt_skill().get_snapshot()


func set_solar_bolt_force_roll_for_tests(value: float) -> void:
	_get_solar_bolt_skill().set_force_roll_for_tests(value)


func set_solar_bolt_force_rolls_for_tests(values: Array) -> void:
	_get_solar_bolt_skill().set_force_rolls_for_tests(values)


func set_solar_bolt_jitter_degrees_for_tests(values: Array) -> void:
	_get_solar_bolt_skill().set_jitter_degrees_for_tests(values)


func get_bomb_surprise_explosion_count_for_tests() -> int:
	return int(_get_bomb_surprise_skill().get_explosion_count_for_tests())


func get_gatling_burst_hit_count_for_tests() -> int:
	return int(_get_gatling_burst_skill().get_hit_count_for_tests())


func get_gatling_burst_shot_count_for_tests() -> int:
	return int(_get_gatling_burst_skill().get_shot_count_for_tests())


func get_dragon_breath_ball_hit_count_for_tests() -> int:
	return int(_get_dragon_breath_skill().get_ball_hit_count_for_tests())


func get_dragon_breath_fire_zone_spawn_count_for_tests() -> int:
	return int(_get_dragon_breath_skill().get_fire_zone_spawn_count_for_tests())


func get_dragon_wing_ball_hit_count_for_tests() -> int:
	return int(_get_dragon_wing_skill().get_ball_hit_count_for_tests())


func get_dragon_wing_wind_tick_count_for_tests() -> int:
	return int(_get_dragon_wing_skill().get_wind_tick_count_for_tests())


func get_ghost_summon_catch_count_for_tests() -> int:
	return int(_get_ghost_summon_skill().get_catch_count_for_tests())


func get_ghost_summon_release_count_for_tests() -> int:
	return int(_get_ghost_summon_skill().get_release_count_for_tests())


func get_skeleton_archer_archer_count_for_tests() -> int:
	return int(_get_skeleton_archer_skill().get_archer_count_for_tests())


func get_skeleton_archer_arrow_count_for_tests() -> int:
	return int(_get_skeleton_archer_skill().get_arrow_count_for_tests())


func get_skeleton_archer_arrow_hit_count_for_tests() -> int:
	return int(_get_skeleton_archer_skill().get_arrow_hit_count_for_tests())


func get_skeleton_archer_death_count_for_tests() -> int:
	return int(_get_skeleton_archer_skill().get_archer_death_count_for_tests())


func get_skeleton_archer_snapshot_for_tests() -> Dictionary:
	return _get_skeleton_archer_skill().get_snapshot()


func get_bone_barrier_barrier_count_for_tests() -> int:
	return int(_get_bone_barrier_skill().get_barrier_count_for_tests())


func get_bone_barrier_reflect_count_for_tests() -> int:
	return int(_get_bone_barrier_skill().get_reflect_count_for_tests())


func get_bone_barrier_build_break_count_for_tests() -> int:
	return int(_get_bone_barrier_skill().get_build_break_count_for_tests())


func get_bone_barrier_snapshot_for_tests() -> Dictionary:
	return _get_bone_barrier_skill().get_snapshot()


func set_bone_barrier_x_values_for_tests(values: Array) -> void:
	_get_bone_barrier_skill().set_barrier_x_values_for_tests(values)


func get_ball_collision_context() -> Dictionary:
	var context: Dictionary = {}
	if _bone_barrier_skill != null and _bone_barrier_skill.has_method("get_ball_collision_context"):
		context.merge(_bone_barrier_skill.get_ball_collision_context(), true)
	return context


func notify_lingpet_bone_barrier_hit(
	barrier_id: int,
	impact_pos: Vector2,
	next_ball_vel: Vector2,
	built: bool = true,
	registry: Object = null
) -> bool:
	if _bone_barrier_skill == null or not _bone_barrier_skill.has_method("notify_ball_collision"):
		return false
	return bool(_bone_barrier_skill.notify_ball_collision(barrier_id, impact_pos, next_ball_vel, built, registry))


func get_soul_clone_hit_count_for_tests() -> int:
	return int(_get_soul_clone_skill().get_hit_count_for_tests())


func get_puppet_grab_count_for_tests() -> int:
	return int(_get_puppet_grab_skill().get_grab_count_for_tests())


func get_puppet_grab_kiss_count_for_tests() -> int:
	return int(_get_puppet_grab_skill().get_kiss_count_for_tests())


func get_doll_curse_destroyed_count_for_tests() -> int:
	return int(_get_doll_curse_skill().get_doll_destroyed_count_for_tests())


func get_doll_curse_confusion_apply_count_for_tests() -> int:
	return int(_get_doll_curse_skill().get_confusion_apply_count_for_tests())


func get_banana_slice_slip_state_for_tests() -> Dictionary:
	return _get_banana_slice_skill().get_slip_state_for_tests()


func get_banana_slice_projectile_count_for_tests() -> int:
	return int(_get_banana_slice_skill().get_projectile_count_for_tests())


func get_banana_slice_landed_count_for_tests() -> int:
	return int(_get_banana_slice_skill().get_landed_count_for_tests())


func get_wild_roar_reflect_count_for_tests() -> int:
	return int(_get_wild_roar_skill().get_reflect_count_for_tests())


func get_wild_roar_whiff_count_for_tests() -> int:
	return int(_get_wild_roar_skill().get_whiff_count_for_tests())


func get_wild_roar_snapshot_for_tests() -> Dictionary:
	return _get_wild_roar_skill().get_snapshot()


func get_star_coil_snapshot_for_tests() -> Dictionary:
	return _get_star_coil_skill().get_snapshot()


func get_star_coil_phase_for_tests() -> String:
	return str(_get_star_coil_skill().get_phase_for_tests())


func _get_skill_for_kind(skill_kind: String) -> Object:
	match skill_kind:
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return _get_hydro_sphere_skill()
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _get_headbutt_skill()
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return _get_moon_orbit_skill()
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return _get_bubble_trap_skill()
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return _get_milk_production_skill()
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			return _get_milk_shot_skill()
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return _get_thunder_orb_skill()
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return _get_solar_bolt_skill()
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _get_bomb_surprise_skill()
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _get_gatling_burst_skill()
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			return _get_dragon_breath_skill()
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			return _get_dragon_wing_skill()
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return _get_ghost_summon_skill()
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			return _get_skeleton_archer_skill()
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			return _get_bone_barrier_skill()
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return _get_soul_clone_skill()
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			return _get_puppet_grab_skill()
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			return _get_doll_curse_skill()
		LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE:
			return _get_banana_slice_skill()
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			return _get_wild_roar_skill()
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return _get_star_coil_skill()
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return _get_gravity_accel_skill()
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return _get_dwarf_magic_skill()
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return _get_sand_prison_skill()
		_:
			return null


func _peek_skill_for_kind(skill_kind: String) -> Object:
	match skill_kind:
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return _hydro_sphere_skill
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return _moon_orbit_skill
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return _bubble_trap_skill
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return _milk_production_skill
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			return _milk_shot_skill
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return _thunder_orb_skill
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			return _solar_bolt_skill
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _bomb_surprise_skill
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _gatling_burst_skill
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			return _dragon_breath_skill
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			return _dragon_wing_skill
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return _ghost_summon_skill
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			return _skeleton_archer_skill
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			return _bone_barrier_skill
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return _soul_clone_skill
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			return _puppet_grab_skill
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			return _doll_curse_skill
		LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE:
			return _banana_slice_skill
		LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR:
			return _wild_roar_skill
		LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			return _star_coil_skill
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			return _gravity_accel_skill
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return _dwarf_magic_skill
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return _sand_prison_skill
		_:
			return null


func _get_hydro_sphere_skill() -> Object:
	if _hydro_sphere_skill == null:
		_hydro_sphere_skill = _new_skill(HYDRO_SPHERE_SKILL_PATH)
	return _hydro_sphere_skill


func _get_headbutt_skill() -> Object:
	if _headbutt_skill == null:
		_headbutt_skill = _new_skill(HEADBUTT_SKILL_PATH)
	return _headbutt_skill


func _get_moon_orbit_skill() -> Object:
	if _moon_orbit_skill == null:
		_moon_orbit_skill = _new_skill(MOON_ORBIT_SKILL_PATH)
	return _moon_orbit_skill


func _get_bubble_trap_skill() -> Object:
	if _bubble_trap_skill == null:
		_bubble_trap_skill = _new_skill(BUBBLE_TRAP_SKILL_PATH)
	return _bubble_trap_skill


func _get_milk_production_skill() -> Object:
	if _milk_production_skill == null:
		_milk_production_skill = _new_skill(MILK_PRODUCTION_SKILL_PATH)
	return _milk_production_skill


func _get_milk_shot_skill() -> Object:
	if _milk_shot_skill == null:
		_milk_shot_skill = _new_skill(MILK_SHOT_SKILL_PATH)
	return _milk_shot_skill


func _get_thunder_orb_skill() -> Object:
	if _thunder_orb_skill == null:
		_thunder_orb_skill = _new_skill(THUNDER_ORB_SKILL_PATH)
	return _thunder_orb_skill


func _get_solar_bolt_skill() -> Object:
	if _solar_bolt_skill == null:
		_solar_bolt_skill = _new_skill(SOLAR_BOLT_SKILL_PATH)
	return _solar_bolt_skill


func _get_bomb_surprise_skill() -> Object:
	if _bomb_surprise_skill == null:
		_bomb_surprise_skill = _new_skill(BOMB_SURPRISE_SKILL_PATH)
	return _bomb_surprise_skill


func _get_gatling_burst_skill() -> Object:
	if _gatling_burst_skill == null:
		_gatling_burst_skill = _new_skill(GATLING_BURST_SKILL_PATH)
	return _gatling_burst_skill


func _get_dragon_breath_skill() -> Object:
	if _dragon_breath_skill == null:
		_dragon_breath_skill = _new_skill(DRAGON_BREATH_SKILL_PATH)
	return _dragon_breath_skill


func _get_dragon_wing_skill() -> Object:
	if _dragon_wing_skill == null:
		_dragon_wing_skill = _new_skill(DRAGON_WING_SKILL_PATH)
	return _dragon_wing_skill


func _get_ghost_summon_skill() -> Object:
	if _ghost_summon_skill == null:
		_ghost_summon_skill = _new_skill(GHOST_SUMMON_SKILL_PATH)
	return _ghost_summon_skill


func _get_skeleton_archer_skill() -> Object:
	if _skeleton_archer_skill == null:
		_skeleton_archer_skill = _new_skill(SKELETON_ARCHER_SKILL_PATH)
	return _skeleton_archer_skill


func _get_bone_barrier_skill() -> Object:
	if _bone_barrier_skill == null:
		_bone_barrier_skill = _new_skill(BONE_BARRIER_SKILL_PATH)
	return _bone_barrier_skill


func _get_soul_clone_skill() -> Object:
	if _soul_clone_skill == null:
		_soul_clone_skill = _new_skill(SOUL_CLONE_SKILL_PATH)
	return _soul_clone_skill


func _get_puppet_grab_skill() -> Object:
	if _puppet_grab_skill == null:
		_puppet_grab_skill = _new_skill(PUPPET_GRAB_SKILL_PATH)
	return _puppet_grab_skill


func _get_doll_curse_skill() -> Object:
	if _doll_curse_skill == null:
		_doll_curse_skill = _new_skill(DOLL_CURSE_SKILL_PATH)
	return _doll_curse_skill


func _get_banana_slice_skill() -> Object:
	if _banana_slice_skill == null:
		_banana_slice_skill = _new_skill(BANANA_SLICE_SKILL_PATH)
	return _banana_slice_skill


func _get_wild_roar_skill() -> Object:
	if _wild_roar_skill == null:
		_wild_roar_skill = _new_skill(WILD_ROAR_SKILL_PATH)
	return _wild_roar_skill


func _get_star_coil_skill() -> Object:
	if _star_coil_skill == null:
		_star_coil_skill = _new_skill(STAR_COIL_SKILL_PATH)
	return _star_coil_skill


func _get_gravity_accel_skill() -> Object:
	if _gravity_accel_skill == null:
		_gravity_accel_skill = _new_skill(GRAVITY_ACCEL_SKILL_PATH)
	return _gravity_accel_skill


func _get_dwarf_magic_skill() -> Object:
	if _dwarf_magic_skill == null:
		_dwarf_magic_skill = _new_skill(DWARF_MAGIC_SKILL_PATH)
	return _dwarf_magic_skill


func _get_sand_prison_skill() -> Object:
	if _sand_prison_skill == null:
		_sand_prison_skill = _new_skill(SAND_PRISON_SKILL_PATH)
	return _sand_prison_skill


func get_dwarf_magic_hit_count_for_tests() -> int:
	return int(_get_dwarf_magic_skill().get_hit_count_for_tests())


func get_dwarf_magic_snapshot_for_tests() -> Dictionary:
	return _get_dwarf_magic_skill().get_snapshot()


func set_dwarf_magic_force_hit_next_for_tests(value: bool) -> void:
	_get_dwarf_magic_skill().set_force_hit_next_for_tests(value)


func get_sand_prison_snapshot_for_tests() -> Dictionary:
	return _get_sand_prison_skill().get_snapshot()


func set_sand_prison_retry_roll_queue_for_tests(values: Array) -> void:
	_get_sand_prison_skill().set_retry_roll_queue_for_tests(values)


# Companion-renderer hook: when Star Coil is in its BIND phase, the orosha body sheet replaces
# the rolling-hoop sprite (the bind motion IS orosha wrapping the boss). Peeks the existing module
# only (no lazy create from the draw/config path); returns {} when not binding.
func get_companion_bind_sheet_state(skill_id: String) -> Dictionary:
	if LingpetSkillDispatcher.get_skill_kind(skill_id) != LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
		return {}
	if _star_coil_skill == null:
		return {}
	var snap: Dictionary = _star_coil_skill.get_snapshot()
	if not bool(snap.get("star_coil_bind_active", false)):
		return {}
	return {
		"active": true,
		"frame": int(snap.get("star_coil_bind_frame", 0)),
	}


func _new_skill(path: String) -> Object:
	var script_resource: Variant = load(path)
	if script_resource == null:
		push_warning("Failed to load lingpet skill script: %s" % path)
		return null
	return script_resource.new()


func _reset_skill(skill: Object, owner: Object = null, registry: Object = null) -> void:
	if skill == null:
		return
	if skill.has_method("cancel"):
		skill.cancel(owner, registry)
	elif skill.has_method("reset"):
		skill.reset()


func _reset_skill_round(skill: Object, owner: Object = null, registry: Object = null) -> void:
	if skill == null:
		return
	if skill.has_method("reset_round"):
		skill.reset_round()
	else:
		_reset_skill(skill, owner, registry)


func _draw_skill(skill: Object, canvas: CanvasItem, shake_offset: Vector2) -> void:
	if skill != null and skill.has_method("draw"):
		skill.draw(canvas, shake_offset)


func _draw_skill_instrumented(
	skill: Object,
	canvas: CanvasItem,
	shake_offset: Vector2,
	label: String,
	perf_logger: Object = null,
	counter_specs: Array = []
) -> void:
	if skill == null or not skill.has_method("draw"):
		return
	if not _skill_has_visible_effects(skill):
		return
	_record_draw_counters(skill, perf_logger, counter_specs)
	var sample_start: int = _perf_begin(perf_logger)
	skill.draw(canvas, shake_offset)
	_perf_end(perf_logger, label, sample_start)


func _record_draw_counters(skill: Object, perf_logger: Object, counter_specs: Array) -> void:
	if perf_logger == null or not perf_logger.has_method("record_counter_sample"):
		return
	if skill == null or not skill.has_method("get_snapshot"):
		return
	if counter_specs.is_empty():
		return
	var raw_snapshot: Variant = skill.get_snapshot()
	if not (raw_snapshot is Dictionary):
		return
	var snapshot: Dictionary = raw_snapshot as Dictionary
	for raw_spec in counter_specs:
		if not (raw_spec is Dictionary):
			continue
		var spec: Dictionary = raw_spec as Dictionary
		var counter_name := str(spec.get("counter_name", ""))
		var snapshot_key := str(spec.get("snapshot_key", ""))
		if counter_name == "" or snapshot_key == "":
			continue
		perf_logger.record_counter_sample(counter_name, float(snapshot.get(snapshot_key, 0)))


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _skill_has_visible_effects(skill: Object) -> bool:
	return skill != null and skill.has_method("has_visible_effects") and bool(skill.has_visible_effects())


func _merge_skill_snapshot(snapshot: Dictionary, skill: Object) -> void:
	if skill == null or not skill.has_method("get_snapshot"):
		return
	var skill_snapshot: Variant = skill.get_snapshot()
	if skill_snapshot is Dictionary:
		snapshot.merge(skill_snapshot as Dictionary, true)
