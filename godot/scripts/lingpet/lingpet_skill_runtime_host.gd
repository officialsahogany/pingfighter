extends RefCounted

const LingpetHydroSphereSkill := preload("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
const LingpetHeadbuttSkill := preload("res://scripts/lingpet/lingpet_headbutt_skill.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")

var _hydro_sphere_skill: Object = LingpetHydroSphereSkill.new()
var _headbutt_skill: Object = LingpetHeadbuttSkill.new()


func reset() -> void:
	_hydro_sphere_skill.reset()
	_headbutt_skill.reset()


func update(delta: float, owner: Object, registry: Object = null, skill_id: String = "") -> void:
	var safe_delta := maxf(0.0, delta)
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_hydro_sphere_skill.update(safe_delta, owner, registry)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			_headbutt_skill.update(safe_delta, owner, registry)
		_:
			pass


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	_hydro_sphere_skill.draw(canvas, shake_offset)
	_headbutt_skill.draw(canvas, shake_offset)


func has_visible_effects() -> bool:
	return _hydro_sphere_skill.has_visible_effects() or _headbutt_skill.has_visible_effects()


func prewarm(skill_id: String) -> void:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_hydro_sphere_skill.prewarm()
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			_headbutt_skill.prewarm()
		_:
			pass


func is_launch_blocked(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return _hydro_sphere_skill.is_projectile_active()
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill.is_active()
		_:
			return false


func can_arm(skill_id: String, params: Dictionary) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill.can_arm(params)
		_:
			return true


func launch(skill_id: String, origin: Vector2, owner: Object = null) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_hydro_sphere_skill.launch(origin)
			return true
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill.launch(origin, owner)
		_:
			return false


func get_launch_origin(skill_id: String, companion_pos: Vector2, companion_radius: float) -> Vector2:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			return companion_pos + Vector2(0.0, -maxf(0.0, companion_radius) - 8.0)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return companion_pos
		_:
			return companion_pos


func has_companion_position_override(skill_id: String) -> bool:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill.has_companion_position_override()
		_:
			return false


func get_companion_position_override(skill_id: String, fallback: Vector2) -> Vector2:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			return _headbutt_skill.get_companion_position_override(fallback)
		_:
			return fallback


func should_show_cast_windup(skill_id: String) -> bool:
	return LingpetSkillDispatcher.has_supported_runtime(skill_id)


func trigger_launch_feedback(skill_id: String, registry: Object) -> void:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_play_hydro_feedback(registry)
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
			pass
		_:
			pass


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = _hydro_sphere_skill.get_snapshot()
	snapshot.merge(_headbutt_skill.get_snapshot(), true)
	return snapshot


func get_hydro_puddle_particle_count_for_tests() -> int:
	return _hydro_sphere_skill.get_particle_count_for_tests()


func get_headbutt_hit_count_for_tests() -> int:
	return _headbutt_skill.get_hit_count_for_tests()


func get_headbutt_miss_count_for_tests() -> int:
	return _headbutt_skill.get_miss_count_for_tests()


func _play_hydro_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_stage2_hydro"):
		audio.play_stage2_hydro()


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
