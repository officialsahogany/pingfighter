extends SceneTree

# expect-zero-object-leaks

const OWNER_PATH := "res://scripts/lingpet/lingpet_skill_launch_feedback_router.gd"
const HOST_PATH := "res://scripts/lingpet/lingpet_skill_runtime_host.gd"

var _failures: Array[String] = []


class FakeRegistry:
	extends RefCounted

	var cached_audio: Object = null
	var resolved_audio: Object = null
	var cached_queries := 0
	var instance_queries := 0

	func _init(cached_value: Object = null, resolved_value: Object = null) -> void:
		cached_audio = cached_value
		resolved_audio = resolved_value

	func get_cached_instance(key: String) -> Object:
		cached_queries += 1
		return cached_audio if key == "game_audio" else null

	func get_instance(key: String) -> Object:
		instance_queries += 1
		return resolved_audio if key == "game_audio" else null


class PrimaryAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_stage2_hydro() -> void:
		calls.append("stage2_hydro")

	func play_active_item() -> void:
		calls.append("active_item")

	func play_thunder_orb_shot() -> void:
		calls.append("thunder_orb_shot")

	func play_solar_bolt_strike() -> void:
		calls.append("solar_bolt_strike")

	func play_bomb_surprise_attach() -> void:
		calls.append("bomb_surprise_attach")

	func play_dragon_breath_fire(low_volume: bool = false) -> void:
		calls.append("dragon_breath_fire:%s" % str(low_volume))

	func play_lingpet_ghost_summon() -> void:
		calls.append("lingpet_ghost_summon")

	func play_lingpet_skeleton_archer_summon() -> void:
		calls.append("lingpet_skeleton_archer_summon")

	func play_lingpet_bone_barrier_build() -> void:
		calls.append("lingpet_bone_barrier_build")

	func play_lingpet_puppet_grab_cast() -> void:
		calls.append("lingpet_puppet_grab_cast")

	func play_lingpet_doll_curse() -> void:
		calls.append("lingpet_doll_curse")

	func play_lingpet_gravity_accel_cast() -> void:
		calls.append("lingpet_gravity_accel_cast")

	func play_lingpet_dwarf_magic_cast() -> void:
		calls.append("lingpet_dwarf_magic_cast")

	func play_lingpet_sand_prison_cast() -> void:
		calls.append("lingpet_sand_prison_cast")


class ActiveOnlyAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_active_item() -> void:
		calls.append("active_item")


class RagnarokAudio:
	extends ActiveOnlyAudio

	func play_ragnarok_shot() -> void:
		calls.append("ragnarok_shot")


class ThunderBoomAudio:
	extends ActiveOnlyAudio

	func play_thunder_orb_boom() -> void:
		calls.append("thunder_orb_boom")


class MolotovAudio:
	extends ActiveOnlyAudio

	func play_molotov_explosion() -> void:
		calls.append("molotov_explosion")


class DragonBreathOnlyAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_dragon_breath_fire(low_volume: bool = false) -> void:
		calls.append("dragon_breath_fire:%s" % str(low_volume))


class TongueAudio:
	extends ActiveOnlyAudio

	func play_stage3_kuromi_tongue() -> void:
		calls.append("stage3_kuromi_tongue")


class GhostAudio:
	extends ActiveOnlyAudio

	func play_lingpet_ghost_summon() -> void:
		calls.append("lingpet_ghost_summon")


class SkeletonAudio:
	extends ActiveOnlyAudio

	func play_lingpet_skeleton_archer_summon() -> void:
		calls.append("lingpet_skeleton_archer_summon")


class DollCurseAudio:
	extends ActiveOnlyAudio

	func play_stage3_dollcurse() -> void:
		calls.append("stage3_dollcurse")


func _init() -> void:
	_verify_owner_boundary()
	if FileAccess.file_exists(OWNER_PATH):
		_verify_primary_routes()
		_verify_no_feedback_routes()
		_verify_fallback_order()
		_verify_active_item_fallbacks()
		_verify_registry_lookup_order()

	if _failures.is_empty():
		print("lingpet_skill_launch_feedback_router_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(OWNER_PATH), "Ringpet launch feedback should have a focused router")
	if not FileAccess.file_exists(OWNER_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var router_source := FileAccess.get_file_as_string(OWNER_PATH)
	_expect(host_source.contains("LingpetSkillLaunchFeedbackRouter"), "skill host should preload the focused launch-feedback router")
	_expect(host_source.contains("_launch_feedback_router.trigger(skill_id, registry)"), "public feedback facade should delegate the unchanged skill id and registry")
	_expect(not host_source.contains("func _play_hydro_feedback"), "skill host should not retain concrete launch-audio helpers")
	_expect(not host_source.contains("func _get_registry_instance"), "registry audio lookup should belong to the focused router")
	_expect(router_source.contains("func trigger(skill_id: String, registry: Object) -> void"), "focused router should expose the launch-feedback policy entrypoint")


func _verify_primary_routes() -> void:
	var router: Object = _new_router()
	var audio := PrimaryAudio.new()
	var registry := FakeRegistry.new(null, audio)
	var cases := [
		["maribo_hydro_sphere", "stage2_hydro"],
		["maribo_bubble_trap", "stage2_hydro"],
		["milkring_milk_production", "active_item"],
		["lumion_thunder_orb", "thunder_orb_shot"],
		["lumion_solar_bolt", "solar_bolt_strike"],
		["volty_bomb_surprise", "bomb_surprise_attach"],
		["red_dragon_dragon_breath", "dragon_breath_fire:false"],
		["red_dragon_dragon_wing", "active_item"],
		["rabi_ghost_summon", "lingpet_ghost_summon"],
		["nekuring_skeleton_archer", "lingpet_skeleton_archer_summon"],
		["nekuring_bone_barrier", "lingpet_bone_barrier_build"],
		["rabi_soul_clone", "lingpet_ghost_summon"],
		["koyora_puppet_control", "lingpet_puppet_grab_cast"],
		["koyora_doll_curse", "lingpet_doll_curse"],
		["orosha_star_coil", "active_item"],
		["orbi_gravity_accel", "lingpet_gravity_accel_cast"],
		["orbi_dwarf_magic", "lingpet_dwarf_magic_cast"],
		["rahoset_sand_prison", "lingpet_sand_prison_cast"],
	]
	for case in cases:
		audio.calls.clear()
		router.trigger(str(case[0]), registry)
		_expect(audio.calls == [str(case[1])], "%s should prefer %s" % [case[0], case[1]])


func _verify_no_feedback_routes() -> void:
	var router: Object = _new_router()
	var audio := PrimaryAudio.new()
	var registry := FakeRegistry.new(audio, ActiveOnlyAudio.new())
	for skill_id in [
		"lunabi_headbutt",
		"draft_bat_moon_orbit",
		"milkring_milk_shot",
		"volty_gatling_burst",
		"monkeyring_banana_slice",
		"monkeyring_wild_roar",
		"unsupported_skill",
		"",
	]:
		router.trigger(skill_id, registry)
	_expect(audio.calls.is_empty(), "runtime-owned/no-feedback skills should not emit a host launch cue")
	_expect(registry.cached_queries == 0 and registry.instance_queries == 0, "no-feedback branches should not query game audio")


func _verify_fallback_order() -> void:
	_expect_route("lumion_thunder_orb", RagnarokAudio.new(), "ragnarok_shot", "Thunder Orb should fall back to Ragnarok before active-item audio")
	_expect_route("lumion_solar_bolt", RagnarokAudio.new(), "ragnarok_shot", "Solar Bolt should prefer Ragnarok as its first fallback")
	_expect_route("lumion_solar_bolt", ThunderBoomAudio.new(), "thunder_orb_boom", "Solar Bolt should use Thunder Orb boom before active-item audio")
	_expect_route("red_dragon_dragon_breath", MolotovAudio.new(), "molotov_explosion", "Dragon Breath should use Molotov before active-item audio")
	_expect_route("red_dragon_dragon_wing", DragonBreathOnlyAudio.new(), "dragon_breath_fire:true", "Dragon Wing should request the low-volume Dragon Breath fallback")
	_expect_route("rabi_ghost_summon", TongueAudio.new(), "stage3_kuromi_tongue", "Ghost Summon should use the tongue cue before active-item audio")
	_expect_route("nekuring_skeleton_archer", GhostAudio.new(), "lingpet_ghost_summon", "Skeleton Archer should use Ghost Summon before active-item audio")
	_expect_route("nekuring_bone_barrier", SkeletonAudio.new(), "lingpet_skeleton_archer_summon", "Bone Barrier should use Skeleton Archer before active-item audio")
	_expect_route("rabi_soul_clone", GhostAudio.new(), "lingpet_ghost_summon", "Soul Clone should prefer the ghost cue")
	_expect_route("koyora_doll_curse", DollCurseAudio.new(), "stage3_dollcurse", "Doll Curse should use the Stage 3 cue before active-item audio")


func _verify_active_item_fallbacks() -> void:
	var active_fallback_ids := [
		"milkring_milk_production",
		"lumion_thunder_orb",
		"lumion_solar_bolt",
		"volty_bomb_surprise",
		"red_dragon_dragon_breath",
		"red_dragon_dragon_wing",
		"rabi_ghost_summon",
		"nekuring_skeleton_archer",
		"nekuring_bone_barrier",
		"rabi_soul_clone",
		"koyora_puppet_control",
		"koyora_doll_curse",
		"orosha_star_coil",
		"orbi_gravity_accel",
		"orbi_dwarf_magic",
		"rahoset_sand_prison",
	]
	for skill_id in active_fallback_ids:
		_expect_route(skill_id, ActiveOnlyAudio.new(), "active_item", "%s should retain its active-item fallback" % skill_id)
	var hydro_audio := ActiveOnlyAudio.new()
	_new_router().trigger("maribo_hydro_sphere", FakeRegistry.new(null, hydro_audio))
	_expect(hydro_audio.calls.is_empty(), "Hydro Sphere should remain silent when the dedicated Stage 2 cue is unavailable")


func _verify_registry_lookup_order() -> void:
	var router: Object = _new_router()
	var cached := PrimaryAudio.new()
	var fallback := ActiveOnlyAudio.new()
	var registry := FakeRegistry.new(cached, fallback)
	router.trigger("lumion_thunder_orb", registry)
	_expect(cached.calls == ["thunder_orb_shot"], "valid cached game audio should receive the launch cue")
	_expect(fallback.calls.is_empty(), "instance lookup should not replace valid cached game audio")
	_expect(registry.cached_queries == 1 and registry.instance_queries == 0, "cached lookup should short-circuit the slower registry query")
	router.trigger("lumion_thunder_orb", null)
	router.trigger("lumion_thunder_orb", RefCounted.new())


func _expect_route(skill_id: String, audio: Object, expected: String, message: String) -> void:
	var router: Object = _new_router()
	router.trigger(skill_id, FakeRegistry.new(null, audio))
	_expect(audio.get("calls") == [expected], message)


func _new_router() -> Object:
	var router_script: Script = load(OWNER_PATH)
	return router_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
