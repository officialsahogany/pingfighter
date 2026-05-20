extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(300.0, 700.0)
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false


class FakeGameAudio:
	extends RefCounted

	var item_get_calls := 0

	func play_item_get() -> void:
		item_get_calls += 1


class FakeSkillConfig:
	extends RefCounted

	var equipped_skills: Array = ["drive", "power_smashing"]
	var unlock_calls := 0
	var runtime_cooldown_multiplier := 1.0

	func get_snapshot() -> Dictionary:
		return {
			"max_slots": 5,
			"equipped_skills": equipped_skills.duplicate(),
		}

	func unlock_and_equip_skill(skill_name: String) -> bool:
		unlock_calls += 1
		if equipped_skills.has(skill_name):
			return true
		if equipped_skills.size() >= 5:
			return false
		equipped_skills.append(skill_name)
		return true

	func set_runtime_cooldown_multiplier(multiplier: float) -> void:
		runtime_cooldown_multiplier = multiplier


class FakeCommandoWeaponController:
	extends RefCounted

	var sync_calls := 0
	var last_skill_config: Object = null

	func sync_equipped_permanent(skill_config: Object) -> void:
		sync_calls += 1
		last_skill_config = skill_config


class FakeRegistry:
	extends RefCounted

	var skill_config := FakeSkillConfig.new()
	var commando_skill_config := FakeSkillConfig.new()
	var commando_weapon_controller := FakeCommandoWeaponController.new()
	var battle_view_layout := BattleViewLayout.new()
	var battle_scene_config := BattleSceneConfig.new()
	var game_audio := FakeGameAudio.new()
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"smasher_skill_config":
				return skill_config
			"commando_skill_config":
				return commando_skill_config
			"commando_weapon_controller":
				return commando_weapon_controller
			"battle_view_layout":
				return battle_view_layout
			"battle_scene_config":
				return battle_scene_config
			"game_audio":
				return game_audio
		return null

	func has_requested_key(key: String) -> bool:
		return requested_keys.has(key)


func _init() -> void:
	_verify_active_unlock_waits_for_orb_flight()
	_verify_soldier_unlock_syncs_commando_controller()
	print("runtime_perk_active_unlock_flight_smoke: ok")
	quit(0)


func _verify_active_unlock_waits_for_orb_flight() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	var choice := {
		"id": "unlock_plasma",
		"name": "플라즈마",
		"unlocks_skill": "plasma",
		"character_restriction": "smasher",
		"icon_color": Color(0.0, 0.78, 1.0),
		"tree": "unlock",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
	}
	state.pending_skill_choices = 1
	state.choice_active = true
	state.current_choices = [choice]
	state.selected_index = 0
	state.animation_time = 0.5

	state.choose_selected(owner, registry, view_size)

	_expect(state.is_choice_active(), "active unlock choice should keep the modal alive during orb-flight")
	_expect(state.is_choice_flight_active(), "active unlock choice should start the skill-orb flight animation")
	_expect(registry.skill_config.unlock_calls == 0, "skill should not equip until the flight lands")
	_expect(not registry.skill_config.equipped_skills.has("plasma"), "plasma should not appear in the orb list before landing")
	_expect(registry.game_audio.item_get_calls == 1, "skill-orb flight should play the original item-get style cue once")
	var flight: Dictionary = state.get_snapshot().get("choice_flight_effect", {})
	_expect(str(flight.get("skill_id", "")) == "plasma", "flight payload should target the unlocked skill id")
	_expect(int(flight.get("target_slot_index", -1)) == 2, "flight should target the first empty skill orb slot")
	_expect(_get_vector2(flight.get("source_pos", Vector2.ZERO)) != Vector2.ZERO, "flight should keep the selected card source point")
	_expect(_get_vector2(flight.get("target_pos", Vector2.ZERO)) != Vector2.ZERO, "flight should resolve a visible skill-orb target point")
	var flight_particles_value: Variant = flight.get("particles", [])
	var flight_particles: Array = flight_particles_value if flight_particles_value is Array else []
	_expect(RuntimePerkState.PARTICLE_COUNT <= 20, "choice modal ambient particles should stay within the tightened post-select render budget")
	_expect(RuntimePerkState.ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT <= 18, "active unlock flight particles should stay within the tightened post-select render budget")
	_expect(RuntimePerkOverlayRenderer.CHOICE_MODAL_PARTICLE_DRAW_LIMIT <= 10, "choice modal particle draw should stay capped")
	_expect(RuntimePerkOverlayRenderer.CHOICE_MODAL_PARTICLE_COMPACT_LIFE_RATIO >= 0.68, "choice modal particles should keep compact halo work late in lifetime")
	_expect(RuntimePerkOverlayRenderer.CHOICE_FLIGHT_PARTICLE_DRAW_LIMIT <= 6, "active unlock flight should draw a tighter particle subset")
	_expect(RuntimePerkOverlayRenderer.CHOICE_FLIGHT_SOURCE_RING_COUNT <= 1, "choice flight source burst should stay compact")
	_expect(RuntimePerkOverlayRenderer.CHOICE_FLIGHT_ARRIVAL_RING_COUNT <= 1, "choice flight arrival burst should stay compact")
	_expect(RuntimePerkOverlayRenderer.FLIGHT_SOURCE_ARC_SEGMENTS <= 10, "choice flight source arcs should stay within budget")
	_expect(RuntimePerkOverlayRenderer.FLIGHT_CORE_ARC_SEGMENTS <= 8, "choice flight core arc should stay within budget")
	_expect(RuntimePerkOverlayRenderer.FLIGHT_ARRIVAL_ARC_SEGMENTS <= 10, "choice flight arrival arcs should stay within budget")
	_expect(flight_particles.size() <= RuntimePerkState.ACTIVE_UNLOCK_FLIGHT_PARTICLE_COUNT, "flight payload should respect the active unlock particle cap")

	state.update(0.50, view_size, owner, registry)
	_expect(registry.skill_config.unlock_calls == 0, "mid-flight should still be pre-equip")
	_expect(state.is_choice_flight_active(), "flight should still be active before its landing window")

	state.update(2.0, view_size, owner, registry)
	_expect(registry.skill_config.unlock_calls == 1, "flight landing should equip the unlocked skill")
	_expect(registry.skill_config.equipped_skills.has("plasma"), "plasma should be registered into the skill orb list after landing")
	_expect(not state.is_choice_active(), "modal should close after the landing applies the unlock")
	_expect(not state.is_choice_flight_active(), "flight state should clear after landing")
	_expect(state.pending_skill_choices == 0, "successful unlock should consume one pending perk choice")
	_expect(int(state.runtime_skill_levels.get("unlock_plasma", 0)) == 1, "unlock perk level should be committed after landing")
	_expect(not registry.has_requested_key("commando_weapon_controller"), "smasher unlock should not instantiate or sync the commando weapon controller")


func _verify_soldier_unlock_syncs_commando_controller() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	var registry := FakeRegistry.new()
	registry.commando_skill_config.equipped_skills = ["commando_pistol"]
	var choice := {
		"id": "soldier_unlock_ak47",
		"name": "AK-47",
		"unlocks_skill": "ak47",
		"character_restriction": "soldier",
		"icon_color": Color(1.0, 0.7, 0.2),
		"tree": "unlock",
		"max_level": 1,
		"current_level": 0,
		"next_level": 1,
	}

	_expect(state.apply_choice(choice, owner, registry), "soldier unlock should apply")
	_expect(registry.commando_skill_config.unlock_calls == 1, "soldier unlock should equip through the commando skill config")
	_expect(registry.commando_skill_config.equipped_skills.has("ak47"), "soldier unlock should enter the shared firearm slots")
	_expect(registry.commando_weapon_controller.sync_calls == 1, "soldier unlock should still sync the commando weapon controller")
	_expect(registry.commando_weapon_controller.last_skill_config == registry.commando_skill_config, "commando sync should receive the soldier skill config")
	_expect(int(state.runtime_skill_levels.get("soldier_unlock_ak47", 0)) == 1, "soldier unlock level should be committed")


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
