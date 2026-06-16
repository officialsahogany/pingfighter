extends SceneTree

const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var current_stage := 1
	var special_gauge := 0.0
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
	var weapon_change_calls := 0

	func play_item_get() -> void:
		item_get_calls += 1

	func play_commando_weapon_change() -> void:
		weapon_change_calls += 1


class FakeActiveItemRuntime:
	extends RefCounted

	var dimension_gate_calls := 0

	func activate_dimension_gate(_registry: Object = null) -> bool:
		dimension_gate_calls += 1
		return true


class FakeRuntimePerkCatalog:
	extends RefCounted

	var choices: Array = []

	func get_choices(
		_character_type: String,
		_levels: Dictionary,
		_exclude_instant: bool,
		_target_count: int,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return choices.duplicate(true)


class FakeSkillConfig:
	extends RefCounted

	var equipped_skills: Array = ["drive", "power_smashing"]
	var unlock_calls := 0
	var reset_cooldown_calls := 0
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

	func reset_cooldowns() -> void:
		reset_cooldown_calls += 1


class FakeDashState:
	extends RefCounted

	var refill_calls := 0

	func refill_tokens() -> void:
		refill_calls += 1


class FakeCommandoWeaponController:
	extends RefCounted

	var sync_calls := 0
	var last_skill_config: Object = null
	var highlight_calls := 0
	var last_highlight_skill := ""

	func sync_equipped_permanent(skill_config: Object) -> void:
		sync_calls += 1
		last_skill_config = skill_config

	func trigger_hud_highlight(skill_name: String) -> void:
		highlight_calls += 1
		last_highlight_skill = skill_name


class FakeStarpointStage:
	extends RefCounted

	var starpoint_drops: Array = [{"pos": Vector2(1.0, 2.0)}]
	var starpoint_particles: Array = [{"pos": Vector2(3.0, 4.0)}]


class FakeRegistry:
	extends RefCounted

	var runtime_perk_catalog := FakeRuntimePerkCatalog.new()
	var skill_config := FakeSkillConfig.new()
	var commando_skill_config := FakeSkillConfig.new()
	var commando_weapon_controller := FakeCommandoWeaponController.new()
	var smasher_dash_state := FakeDashState.new()
	var active_item_runtime := FakeActiveItemRuntime.new()
	var battle_view_layout := BattleViewLayout.new()
	var battle_scene_config := BattleSceneConfig.new()
	var game_audio := FakeGameAudio.new()
	var stage1_balloon_event := FakeStarpointStage.new()
	var stage2_pillar_background := FakeStarpointStage.new()
	var stage3_boss_skill_state := FakeStarpointStage.new()
	var stage4_bird_event := FakeStarpointStage.new()
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		match key:
			"runtime_perk_catalog":
				return runtime_perk_catalog
			"smasher_skill_config":
				return skill_config
			"smasher_skill_state":
				return skill_config
			"smasher_dash_state":
				return smasher_dash_state
			"commando_skill_config":
				return commando_skill_config
			"commando_weapon_controller":
				return commando_weapon_controller
			"active_item_runtime":
				return active_item_runtime
			"battle_view_layout":
				return battle_view_layout
			"battle_scene_config":
				return battle_scene_config
			"game_audio":
				return game_audio
			"stage1_balloon_event":
				return stage1_balloon_event
			"stage2_pillar_background":
				return stage2_pillar_background
			"stage3_boss_skill_state":
				return stage3_boss_skill_state
			"stage4_bird_event":
				return stage4_bird_event
		return null

	func has_requested_key(key: String) -> bool:
		return requested_keys.has(key)


func _init() -> void:
	_verify_active_unlock_waits_for_orb_flight()
	_verify_soldier_unlock_syncs_commando_controller()
	_verify_result_box_dimension_gate_waits_for_next_spawn_intro_finish()
	_verify_result_box_full_gauge_waits_for_next_spawn_intro_finish()
	_verify_collect_starpoints_preserves_in_flight_drops()
	_verify_starpoint_absorption_tracks_player_after_choice()
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
	_expect(registry.game_audio.weapon_change_calls == 0, "non-Commando active unlocks should not play the firearm weapon.wav cue")
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
	_expect(registry.commando_weapon_controller.highlight_calls == 1, "soldier firearm unlock should pulse the firearm HUD highlight")
	_expect(registry.commando_weapon_controller.last_highlight_skill == "ak47", "soldier firearm HUD highlight should target the unlocked weapon")
	_expect(registry.game_audio.weapon_change_calls == 1, "soldier firearm unlock should play weapon.wav")
	_expect(int(state.runtime_skill_levels.get("soldier_unlock_ak47", 0)) == 1, "soldier unlock level should be committed")


func _verify_result_box_dimension_gate_waits_for_next_spawn_intro_finish() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	registry.runtime_perk_catalog.choices = [{
		"id": "instant_dimension_gate",
		"name": "차원개방",
		"is_instant": true,
		"icon_color": Color(0.52, 0.86, 1.0),
	}]
	state.pending_skill_choices = 1
	state.open_next_choice(
		"smasher",
		registry.runtime_perk_catalog,
		false,
		owner,
		registry,
		null,
		{RuntimePerkState.CHOICE_CONTEXT_DEFER_DIMENSION_GATE_UNTIL_SPAWN_END: true}
	)
	state.animation_time = 0.30

	state.choose_selected(owner, registry, view_size)

	_expect(not state.is_choice_active(), "deferred dimension-gate choice should close the modal after selection")
	_expect(state.has_pending_dimension_gate_after_spawn_intro(), "result-box dimension gate should queue after the selection")
	_expect(registry.active_item_runtime.dimension_gate_calls == 0, "dimension gate should not activate on the result screen")

	var same_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(same_stage_result.get("wait_for_stage_advance", false)), "queued dimension gate should wait until the stage has advanced")
	_expect(registry.active_item_runtime.dimension_gate_calls == 0, "same-stage intro finish should not consume result-box dimension gate")
	_expect(state.has_pending_dimension_gate_after_spawn_intro(), "same-stage intro finish should keep the queued dimension gate")

	owner.current_stage = 2
	var next_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(next_stage_result.get("dimension_gate_activated", false)), "next-stage spawn intro finish should activate queued dimension gate")
	_expect(registry.active_item_runtime.dimension_gate_calls == 1, "dimension gate should activate exactly once after the next spawn intro")
	_expect(not state.has_pending_dimension_gate_after_spawn_intro(), "activated dimension gate should clear the queued effect")


func _verify_result_box_full_gauge_waits_for_next_spawn_intro_finish() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	owner.special_gauge = 120.0
	registry.runtime_perk_catalog.choices = [{
		"id": "instant_gauge_full",
		"name": "풀게이징",
		"is_instant": true,
		"icon_color": Color(1.0, 0.9, 0.25),
	}]
	state.pending_skill_choices = 1
	state.open_next_choice(
		"smasher",
		registry.runtime_perk_catalog,
		false,
		owner,
		registry,
		null,
		{RuntimePerkState.CHOICE_CONTEXT_DEFER_FULL_GAUGE_UNTIL_SPAWN_END: true}
	)
	state.animation_time = 0.30

	state.choose_selected(owner, registry, view_size)

	_expect(not state.is_choice_active(), "deferred full-gauge choice should close the modal after selection")
	_expect(state.has_pending_full_gauge_after_spawn_intro(), "result-box full gauge should queue after the selection")
	_expect(is_equal_approx(owner.special_gauge, 120.0), "full gauge should not fill gauge on the result screen")
	_expect(registry.smasher_dash_state.refill_calls == 0, "full gauge should not refill dash tokens on the result screen")
	_expect(registry.skill_config.reset_cooldown_calls == 0, "full gauge should not reset cooldowns on the result screen")

	var same_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(same_stage_result.get("wait_for_stage_advance", false)), "queued full gauge should wait until the stage has advanced")
	_expect(is_equal_approx(owner.special_gauge, 120.0), "same-stage intro finish should not consume queued full gauge")
	_expect(state.has_pending_full_gauge_after_spawn_intro(), "same-stage intro finish should keep the queued full gauge")

	owner.current_stage = 2
	var next_stage_result: Dictionary = state.on_ball_spawn_intro_finished(owner, registry)
	_expect(bool(next_stage_result.get("full_gauge_activated", false)), "next-stage spawn intro finish should activate queued full gauge")
	_expect(is_equal_approx(owner.special_gauge, 500.0), "queued full gauge should fill special gauge after the next spawn intro")
	_expect(registry.smasher_dash_state.refill_calls == 1, "queued full gauge should refill dash tokens after the next spawn intro")
	_expect(registry.skill_config.reset_cooldown_calls == 1, "queued full gauge should reset cooldowns after the next spawn intro")
	_expect(not state.has_pending_full_gauge_after_spawn_intro(), "activated full gauge should clear the queued effect")


func _verify_collect_starpoints_preserves_in_flight_drops() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.runtime_perk_catalog.choices = [_build_basic_choice("stability_training")]

	var opened: bool = state.collect_star_points(1, "smasher", registry.runtime_perk_catalog, owner, registry)

	_expect(opened, "collecting a full starpoint should open the perk choice modal")
	_expect(state.is_choice_active(), "starpoint collection should activate the perk choice modal")
	_expect(state.pending_skill_choices == 1, "starpoint collection should queue one pending choice")
	_expect(not registry.stage1_balloon_event.starpoint_drops.is_empty(), "Stage 1 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage1_balloon_event.starpoint_particles.is_empty(), "Stage 1 starpoint particles should survive the modal open")
	_expect(not registry.stage2_pillar_background.starpoint_drops.is_empty(), "Stage 2 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage2_pillar_background.starpoint_particles.is_empty(), "Stage 2 starpoint particles should survive the modal open")
	_expect(not registry.stage3_boss_skill_state.starpoint_drops.is_empty(), "Stage 3 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage3_boss_skill_state.starpoint_particles.is_empty(), "Stage 3 starpoint particles should survive the modal open")
	_expect(not registry.stage4_bird_event.starpoint_drops.is_empty(), "Stage 4 in-flight starpoint drops should survive the modal open")
	_expect(not registry.stage4_bird_event.starpoint_particles.is_empty(), "Stage 4 starpoint particles should survive the modal open")


func _verify_starpoint_absorption_tracks_player_after_choice() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var view_size := Vector2(1488.0, 918.0)
	var renderer := RuntimePerkOverlayRenderer.new()

	state.pending_skill_choices = 1
	state.choice_active = true
	state.current_choices = [_build_basic_choice("stability_training")]
	state.selected_index = 0
	state.animation_time = 0.30

	state.choose_selected(owner, registry, view_size)

	_expect(not state.is_choice_active(), "ordinary perk choice should close the modal immediately")
	_expect(state.is_starpoint_absorption_active(), "closing the final perk choice should start the starpoint absorption effect")
	_expect(renderer._runtime_state_has_visible_effects(state), "runtime perk overlay should stay visible for the post-modal absorption effect")
	var snapshot: Dictionary = state.get_snapshot()
	var selected_choice: Dictionary = _get_dict(snapshot.get("last_selected_choice", {}))
	_expect(str(selected_choice.get("id", "")) == "stability_training", "state should remember the last selected perk choice")
	_expect(int(snapshot.get("selected_choice_sequence", 0)) == 1, "state should bump selected choice sequence after a successful choice")

	state.update(0.016, view_size, owner, registry)
	var first_effect: Dictionary = _get_dict(state.get_snapshot().get("starpoint_absorption_effect", {}))
	var first_source: Vector2 = _get_vector2(first_effect.get("source_pos", Vector2.ZERO))
	var first_target: Vector2 = _get_vector2(first_effect.get("target_pos", Vector2.ZERO))
	_expect(first_source != Vector2.ZERO, "absorption update should resolve a visible source point")
	_expect(first_target != Vector2.ZERO, "absorption update should resolve a visible player target point")

	owner.player_pos.x += 40.0
	state.update(0.016, view_size, owner, registry)
	var moved_effect: Dictionary = _get_dict(state.get_snapshot().get("starpoint_absorption_effect", {}))
	var moved_target: Vector2 = _get_vector2(moved_effect.get("target_pos", Vector2.ZERO))
	_expect(moved_target.x > first_target.x, "absorption target should keep tracking the moving player paddle")

	state.update(1.0, view_size, owner, registry)
	_expect(not state.is_starpoint_absorption_active(), "absorption effect should clear after its duration")


func _build_basic_choice(choice_id: String) -> Dictionary:
	return {
		"id": choice_id,
		"name": choice_id,
		"character_restriction": "smasher",
		"icon_color": Color(0.45, 0.75, 1.0),
		"tree": "training",
		"max_level": 5,
		"current_level": 0,
		"next_level": 1,
	}


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
