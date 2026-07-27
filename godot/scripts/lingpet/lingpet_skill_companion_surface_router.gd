extends RefCounted

## Owns allocation-free companion-facing policy for Ringpet active skills.
## The runtime host retains module lifetime and cross-slot payload priority.

const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")


func get_launch_origin(skill_id: String, companion_pos: Vector2, companion_radius: float) -> Vector2:
	var safe_radius := maxf(0.0, companion_radius)
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE, LingpetSkillDispatcher.SKILL_KIND_MOON_ORBIT, LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			return companion_pos + Vector2(0.0, -safe_radius - 8.0)
		LingpetSkillDispatcher.SKILL_KIND_MILK_SHOT:
			return companion_pos + Vector2(0.0, -safe_radius * 0.35)
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB, LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT, LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH, LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			return companion_pos + Vector2(0.0, -safe_radius - 10.0)
		_:
			return companion_pos


func has_companion_position_override(skill_kind: String, skill: Object) -> bool:
	if not _supports_position_override(skill_kind):
		return false
	return (
		skill != null
		and skill.has_method("has_companion_position_override")
		and bool(skill.has_companion_position_override())
	)


func get_companion_position_override(skill_kind: String, skill: Object, fallback: Vector2) -> Vector2:
	if not _supports_position_override(skill_kind):
		return fallback
	if skill == null or not skill.has_method("get_companion_position_override"):
		return fallback
	var value: Variant = skill.get_companion_position_override(fallback)
	return value as Vector2 if value is Vector2 else fallback


func suppresses_companion_body_hit(skill_kind: String, skill: Object) -> bool:
	match skill_kind:
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT, LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE, LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
			return (
				skill != null
				and skill.has_method("suppresses_companion_body_hit")
				and bool(skill.suppresses_companion_body_hit())
			)
		_:
			return false


func suppresses_companion_body_draw(skill_kind: String, skill: Object) -> bool:
	if skill_kind != LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST:
		return false
	return (
		skill != null
		and skill.has_method("suppresses_companion_body_draw")
		and bool(skill.suppresses_companion_body_draw())
	)


func consume_companion_strike_request(skill_kind: String, skill: Object) -> bool:
	if skill_kind != LingpetSkillDispatcher.SKILL_KIND_HEADBUTT:
		return false
	return (
		skill != null
		and skill.has_method("consume_companion_strike_request")
		and bool(skill.consume_companion_strike_request())
	)


func should_show_cast_windup(skill_id: String) -> bool:
	return LingpetSkillDispatcher.has_supported_runtime(skill_id)


func get_companion_cast_pose_progress(skill_kind: String, skill: Object) -> float:
	if not _supports_cast_pose(skill_kind):
		return -1.0
	if skill == null or not skill.has_method("get_companion_cast_pose_progress"):
		return -1.0
	return float(skill.get_companion_cast_pose_progress())


func _supports_position_override(skill_kind: String) -> bool:
	match skill_kind:
		LingpetSkillDispatcher.SKILL_KIND_HEADBUTT, LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE, LingpetSkillDispatcher.SKILL_KIND_GATLING_BURST, LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB, LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE, LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE, LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR, LingpetSkillDispatcher.SKILL_KIND_STAR_COIL, LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return true
		_:
			return false


func _supports_cast_pose(skill_kind: String) -> bool:
	match skill_kind:
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB, LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE, LingpetSkillDispatcher.SKILL_KIND_BANANA_SLICE, LingpetSkillDispatcher.SKILL_KIND_WILD_ROAR, LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			return true
		_:
			return false
