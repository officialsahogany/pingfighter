extends RefCounted

const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")

const HYDRO_SPHERE_SKILL_PATH := "res://scripts/lingpet/lingpet_hydro_sphere_skill.gd"
const HEADBUTT_SKILL_PATH := "res://scripts/lingpet/lingpet_headbutt_skill.gd"
const MOON_ORBIT_SKILL_PATH := "res://scripts/lingpet/lingpet_moon_orbit_skill.gd"
const BUBBLE_TRAP_SKILL_PATH := "res://scripts/lingpet/lingpet_bubble_trap_skill.gd"
const MILK_PRODUCTION_SKILL_PATH := "res://scripts/lingpet/lingpet_milk_production_skill.gd"
const THUNDER_ORB_SKILL_PATH := "res://scripts/lingpet/lingpet_thunder_orb_skill.gd"
const BOMB_SURPRISE_SKILL_PATH := "res://scripts/lingpet/lingpet_bomb_surprise_skill.gd"
const GATLING_BURST_SKILL_PATH := "res://scripts/lingpet/lingpet_gatling_burst_skill.gd"
const DRAGON_BREATH_SKILL_PATH := "res://scripts/lingpet/lingpet_dragon_breath_skill.gd"
const DRAGON_WING_SKILL_PATH := "res://scripts/lingpet/lingpet_dragon_wing_skill.gd"
const GHOST_SUMMON_SKILL_PATH := "res://scripts/lingpet/lingpet_ghost_summon_skill.gd"
const SOUL_CLONE_SKILL_PATH := "res://scripts/lingpet/lingpet_soul_clone_skill.gd"

var _hydro_sphere_skill: Object = null
var _headbutt_skill: Object = null
var _moon_orbit_skill: Object = null
var _bubble_trap_skill: Object = null
var _milk_production_skill: Object = null
var _thunder_orb_skill: Object = null
var _bomb_surprise_skill: Object = null
var _gatling_burst_skill: Object = null
var _dragon_breath_skill: Object = null
var _dragon_wing_skill: Object = null
var _ghost_summon_skill: Object = null
var _soul_clone_skill: Object = null


func reset(owner: Object = null, registry: Object = null) -> void:
	_reset_skill(_hydro_sphere_skill, owner, registry)
	_reset_skill(_headbutt_skill, owner, registry)
	_reset_skill(_moon_orbit_skill, owner, registry)
	_reset_skill(_bubble_trap_skill, owner, registry)
	_reset_skill(_milk_production_skill, owner, registry)
	_reset_skill(_thunder_orb_skill, owner, registry)
	_reset_skill(_bomb_surprise_skill, owner, registry)
	_reset_skill(_gatling_burst_skill, owner, registry)
	_reset_skill(_dragon_breath_skill, owner, registry)
	_reset_skill(_dragon_wing_skill, owner, registry)
	_reset_skill(_ghost_summon_skill, owner, registry)
	_reset_skill(_soul_clone_skill, owner, registry)


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
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			_get_thunder_orb_skill().update(safe_delta, owner, registry)
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
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			_get_soul_clone_skill().update(safe_delta, owner, registry, launch_context)
		_:
			pass


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	_draw_skill(_hydro_sphere_skill, canvas, shake_offset)
	_draw_skill(_headbutt_skill, canvas, shake_offset)
	_draw_skill(_moon_orbit_skill, canvas, shake_offset)
	_draw_skill(_bubble_trap_skill, canvas, shake_offset)
	_draw_skill(_milk_production_skill, canvas, shake_offset)
	_draw_skill(_thunder_orb_skill, canvas, shake_offset)
	_draw_skill(_bomb_surprise_skill, canvas, shake_offset)
	_draw_skill(_gatling_burst_skill, canvas, shake_offset)
	_draw_skill(_dragon_breath_skill, canvas, shake_offset)
	_draw_skill(_dragon_wing_skill, canvas, shake_offset)
	_draw_skill(_ghost_summon_skill, canvas, shake_offset)
	_draw_skill(_soul_clone_skill, canvas, shake_offset)


func has_visible_effects() -> bool:
	return (
		_skill_has_visible_effects(_hydro_sphere_skill)
		or _skill_has_visible_effects(_headbutt_skill)
		or _skill_has_visible_effects(_moon_orbit_skill)
		or _skill_has_visible_effects(_bubble_trap_skill)
		or _skill_has_visible_effects(_milk_production_skill)
		or _skill_has_visible_effects(_thunder_orb_skill)
		or _skill_has_visible_effects(_bomb_surprise_skill)
		or _skill_has_visible_effects(_gatling_burst_skill)
		or _skill_has_visible_effects(_dragon_breath_skill)
		or _skill_has_visible_effects(_dragon_wing_skill)
		or _skill_has_visible_effects(_ghost_summon_skill)
		or _skill_has_visible_effects(_soul_clone_skill)
	)


func prewarm(skill_id: String) -> void:
	var skill: Object = _get_skill_for_kind(LingpetSkillDispatcher.get_skill_kind(skill_id))
	if skill != null and skill.has_method("prewarm"):
		skill.prewarm()


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
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return _thunder_orb_skill != null and bool(_thunder_orb_skill.is_active())
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
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return _soul_clone_skill != null and bool(_soul_clone_skill.is_active())
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
		_:
			return true


func launch(skill_id: String, origin: Vector2, owner: Object = null, launch_context: Dictionary = {}) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_get_hydro_sphere_skill().launch(origin)
			return true
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return bool(_get_headbutt_skill().launch(origin, owner))
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			_get_moon_orbit_skill().launch(origin)
			return true
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			_get_bubble_trap_skill().launch(origin, owner, launch_context)
			return true
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return bool(_get_milk_production_skill().launch(origin, owner, launch_context))
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			_get_thunder_orb_skill().launch(origin, owner, launch_context)
			return true
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
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return bool(_get_soul_clone_skill().launch(origin, owner, launch_context))
		_:
			return false


func get_launch_origin(skill_id: String, companion_pos: Vector2, companion_radius: float) -> Vector2:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return companion_pos + Vector2(0.0, -maxf(0.0, companion_radius) - 8.0)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return companion_pos
		LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT:
			return companion_pos + Vector2(0.0, -maxf(0.0, companion_radius) - 8.0)
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return companion_pos + Vector2(0.0, -maxf(0.0, companion_radius) - 8.0)
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			return companion_pos
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return companion_pos + Vector2(0.0, -maxf(0.0, companion_radius) - 10.0)
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return companion_pos
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return companion_pos
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			return companion_pos + Vector2(0.0, -maxf(0.0, companion_radius) - 10.0)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			return companion_pos
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			return companion_pos
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return companion_pos
		_:
			return companion_pos


func has_companion_position_override(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill != null and bool(_headbutt_skill.has_companion_position_override())
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _bomb_surprise_skill != null and bool(_bomb_surprise_skill.has_companion_position_override())
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _gatling_burst_skill != null and bool(_gatling_burst_skill.has_companion_position_override())
		_:
			return false


func get_companion_position_override(skill_id: String, fallback: Vector2) -> Vector2:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill.get_companion_position_override(fallback) if _headbutt_skill != null else fallback
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _bomb_surprise_skill.get_companion_position_override(fallback) if _bomb_surprise_skill != null else fallback
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _gatling_burst_skill.get_companion_position_override(fallback) if _gatling_burst_skill != null else fallback
		_:
			return fallback


func suppresses_companion_body_hit(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			return _bomb_surprise_skill != null and bool(_bomb_surprise_skill.suppresses_companion_body_hit())
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _gatling_burst_skill != null and bool(_gatling_burst_skill.suppresses_companion_body_hit())
		_:
			return false


func suppresses_companion_body_draw(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return _gatling_burst_skill != null and _gatling_burst_skill.has_method("suppresses_companion_body_draw") and bool(_gatling_burst_skill.suppresses_companion_body_draw())
		_:
			return false


func consume_companion_strike_request(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill != null and bool(_headbutt_skill.consume_companion_strike_request())
		_:
			return false


func should_show_cast_windup(skill_id: String) -> bool:
	return LingpetSkillDispatcher.has_supported_runtime(skill_id)


func trigger_launch_feedback(skill_id: String, registry: Object) -> void:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_play_hydro_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			pass
		LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			_play_hydro_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION:
			_play_active_item_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			_play_thunder_orb_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			_play_bomb_surprise_attach_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			pass
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			_play_dragon_breath_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			_play_dragon_wing_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			_play_ghost_summon_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			_play_soul_clone_feedback(registry)
		_:
			pass


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	_merge_skill_snapshot(snapshot, _hydro_sphere_skill)
	_merge_skill_snapshot(snapshot, _headbutt_skill)
	_merge_skill_snapshot(snapshot, _moon_orbit_skill)
	_merge_skill_snapshot(snapshot, _bubble_trap_skill)
	_merge_skill_snapshot(snapshot, _milk_production_skill)
	_merge_skill_snapshot(snapshot, _thunder_orb_skill)
	_merge_skill_snapshot(snapshot, _bomb_surprise_skill)
	_merge_skill_snapshot(snapshot, _gatling_burst_skill)
	_merge_skill_snapshot(snapshot, _dragon_breath_skill)
	_merge_skill_snapshot(snapshot, _dragon_wing_skill)
	_merge_skill_snapshot(snapshot, _ghost_summon_skill)
	_merge_skill_snapshot(snapshot, _soul_clone_skill)
	return snapshot


func get_hydro_puddle_particle_count_for_tests() -> int:
	return int(_get_hydro_sphere_skill().get_particle_count_for_tests())


func get_headbutt_hit_count_for_tests() -> int:
	return int(_get_headbutt_skill().get_hit_count_for_tests())


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


func get_thunder_orb_shock_count_for_tests() -> int:
	return int(_get_thunder_orb_skill().get_shock_applied_count_for_tests())


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


func get_soul_clone_hit_count_for_tests() -> int:
	return int(_get_soul_clone_skill().get_hit_count_for_tests())


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
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			return _get_thunder_orb_skill()
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
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			return _get_soul_clone_skill()
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


func _get_thunder_orb_skill() -> Object:
	if _thunder_orb_skill == null:
		_thunder_orb_skill = _new_skill(THUNDER_ORB_SKILL_PATH)
	return _thunder_orb_skill


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


func _get_soul_clone_skill() -> Object:
	if _soul_clone_skill == null:
		_soul_clone_skill = _new_skill(SOUL_CLONE_SKILL_PATH)
	return _soul_clone_skill


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


func _draw_skill(skill: Object, canvas: CanvasItem, shake_offset: Vector2) -> void:
	if skill != null and skill.has_method("draw"):
		skill.draw(canvas, shake_offset)


func _skill_has_visible_effects(skill: Object) -> bool:
	return skill != null and skill.has_method("has_visible_effects") and bool(skill.has_visible_effects())


func _merge_skill_snapshot(snapshot: Dictionary, skill: Object) -> void:
	if skill == null or not skill.has_method("get_snapshot"):
		return
	var skill_snapshot: Variant = skill.get_snapshot()
	if skill_snapshot is Dictionary:
		snapshot.merge(skill_snapshot as Dictionary, true)


func _play_hydro_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_stage2_hydro"):
		audio.play_stage2_hydro()


func _play_active_item_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_thunder_orb_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_thunder_orb_shot"):
		audio.play_thunder_orb_shot()
	elif audio.has_method("play_ragnarok_shot"):
		audio.play_ragnarok_shot()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_bomb_surprise_attach_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_bomb_surprise_attach"):
		audio.play_bomb_surprise_attach()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_dragon_breath_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_dragon_breath_fire"):
		audio.play_dragon_breath_fire(false)
	elif audio.has_method("play_molotov_explosion"):
		audio.play_molotov_explosion()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_dragon_wing_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_active_item"):
		audio.play_active_item()
	elif audio.has_method("play_dragon_breath_fire"):
		audio.play_dragon_breath_fire(true)


func _play_ghost_summon_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lingpet_ghost_summon"):
		audio.play_lingpet_ghost_summon()
	elif audio.has_method("play_stage3_kuromi_tongue"):
		audio.play_stage3_kuromi_tongue()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_soul_clone_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_lingpet_ghost_summon"):
		audio.play_lingpet_ghost_summon()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
