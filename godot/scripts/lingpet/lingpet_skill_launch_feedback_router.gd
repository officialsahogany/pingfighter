extends RefCounted

## Owns Ringpet active-skill launch cue selection and fallback priority only.
## Skill lifecycle, launch success, and skill-owned delayed cues remain outside.

const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")


func trigger(skill_id: String, registry: Object) -> void:
	match LingpetSkillDispatcher.get_skill_kind(skill_id):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE, LingpetSkillDispatcher.SKILL_KIND_BUBBLE_TRAP:
			_play_first(registry, &"play_stage2_hydro")
		LingpetSkillDispatcher.SKILL_KIND_MILK_PRODUCTION, LingpetSkillDispatcher.SKILL_KIND_STAR_COIL:
			_play_first(registry, &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_THUNDER_ORB:
			_play_first(registry, &"play_thunder_orb_shot", &"play_ragnarok_shot", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_SOLAR_BOLT:
			_play_first(registry, &"play_solar_bolt_strike", &"play_ragnarok_shot", &"play_thunder_orb_boom", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_BOMB_SURPRISE:
			_play_first(registry, &"play_bomb_surprise_attach", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_BREATH:
			_play_dragon_breath(registry)
		LingpetSkillDispatcher.SKILL_KIND_DRAGON_WING:
			_play_dragon_wing(registry)
		LingpetSkillDispatcher.SKILL_KIND_GHOST_SUMMON:
			_play_first(registry, &"play_lingpet_ghost_summon", &"play_stage3_kuromi_tongue", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_SKELETON_ARCHER:
			# bonemake2.wav matches the visible bone-assembly summon animation.
			_play_first(registry, &"play_lingpet_skeleton_archer_summon", &"play_lingpet_ghost_summon", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_BONE_BARRIER:
			_play_first(registry, &"play_lingpet_bone_barrier_build", &"play_lingpet_skeleton_archer_summon", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_SOUL_CLONE:
			_play_first(registry, &"play_lingpet_ghost_summon", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_PUPPET_GRAB:
			_play_first(registry, &"play_lingpet_puppet_grab_cast", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_DOLL_CURSE:
			_play_first(registry, &"play_lingpet_doll_curse", &"play_stage3_dollcurse", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_GRAVITY_ACCEL:
			_play_first(registry, &"play_lingpet_gravity_accel_cast", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_DWARF_MAGIC:
			_play_first(registry, &"play_lingpet_dwarf_magic_cast", &"play_active_item")
		LingpetSkillDispatcher.SKILL_KIND_SAND_PRISON:
			_play_first(registry, &"play_lingpet_sand_prison_cast", &"play_active_item")
		_:
			# Headbutt is silent here; Milk Shot, Gatling Burst, Banana Slice,
			# and Wild Roar emit their cues from the exact runtime event frame.
			pass


func _play_first(
	registry: Object,
	first: StringName,
	second: StringName = &"",
	third: StringName = &"",
	fourth: StringName = &""
) -> void:
	var audio := _get_game_audio(registry)
	if audio == null:
		return
	if first != &"" and audio.has_method(first):
		audio.call(first)
		return
	if second != &"" and audio.has_method(second):
		audio.call(second)
		return
	if third != &"" and audio.has_method(third):
		audio.call(third)
		return
	if fourth != &"" and audio.has_method(fourth):
		audio.call(fourth)


func _play_dragon_breath(registry: Object) -> void:
	var audio := _get_game_audio(registry)
	if audio == null:
		return
	if audio.has_method("play_dragon_breath_fire"):
		audio.play_dragon_breath_fire(false)
	elif audio.has_method("play_molotov_explosion"):
		audio.play_molotov_explosion()
	elif audio.has_method("play_active_item"):
		audio.play_active_item()


func _play_dragon_wing(registry: Object) -> void:
	var audio := _get_game_audio(registry)
	if audio == null:
		return
	if audio.has_method("play_active_item"):
		audio.play_active_item()
	elif audio.has_method("play_dragon_breath_fire"):
		audio.play_dragon_breath_fire(true)


func _get_game_audio(registry: Object) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance("game_audio")
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance("game_audio")
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
