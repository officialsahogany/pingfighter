extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkUnlockShowcase := preload("res://scripts/characters/runtime_perk_unlock_showcase.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ai_mode := "junior"
	var selected_character_type := "smasher"
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var arena_mode_enabled := false
	var weather_type := ""
	var ball_vel := Vector2(0.0, 8.0)
	var player_collision_cooldown := 0.0
	var player_pos := Vector2(300.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var runtime_perk_levels := {}
	var runtime_perk_effective_levels := {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var player_paddle_scale := 1.0


class FakeCatalog:
	extends RefCounted

	var choices: Array = []
	var get_choices_calls := 0

	func _init(initial_choices: Array) -> void:
		choices = initial_choices.duplicate(true)

	func get_choices(
		_character_type: String,
		_runtime_skill_levels: Dictionary,
		_exclude_instant: bool,
		_target_choice_count: int,
		_owner: Object,
		_registry: Object
	) -> Array:
		get_choices_calls += 1
		return choices.duplicate(true)

	func get_perk_data(perk_id: String) -> Dictionary:
		for choice in choices:
			var data: Dictionary = choice
			if str(data.get("id", "")) == perk_id:
				return data.duplicate(true)
		return {}


class FakeSkillTooltipDriver:
	extends RefCounted

	var pause_calls := 0
	var resume_calls := 0

	func pause_skill_cooldowns(_owner: Object, _registry: Object) -> void:
		pause_calls += 1

	func resume_skill_cooldowns(_owner: Object, _registry: Object) -> void:
		resume_calls += 1


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func _init(initial_modules: Dictionary = {}) -> void:
		modules = initial_modules.duplicate()

	func get_instance(key: String) -> Object:
		return modules.get(key, null)


class FakeModuleProvider:
	extends RefCounted

	var modules: Dictionary = {}

	func _init(initial_modules: Dictionary) -> void:
		modules = initial_modules.duplicate()

	func get_cached_instance(key: String) -> Object:
		return modules.get(key, null)


class FakeShowcaseState:
	extends RefCounted

	var unlock_showcase: Dictionary = {}


func _init() -> void:
	_verify_showcase_state_application_helper()
	_verify_junior_unlock_showcase_delays_finish_and_blocks_physics()
	_verify_unlock_flight_opens_showcase_after_arrival()
	_verify_non_junior_and_passive_choices_finish_immediately()
	_verify_swap_confirm_showcase_and_cancel_noop()
	_verify_reset_discards_deferred_finish()
	_verify_auto_dismiss_and_keycap_normalization()

	if _failures.is_empty():
		print("runtime_perk_unlock_showcase_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_showcase_state_application_helper() -> void:
	var helper := RuntimePerkUnlockShowcase.new()
	var state := FakeShowcaseState.new()
	var showcase := {
		"active": true,
		"choice_id": "unlock_plasma",
		"skill_id": "plasma",
		"age": 0.0,
	}
	var apply_result: Dictionary = helper.apply_showcase_state_update(state, showcase)
	_expect(bool(apply_result.get("accepted", false)), "unlock showcase helper should apply showcase state")
	_expect(helper.is_active(state.unlock_showcase), "unlock showcase helper should store an active showcase")
	_expect(helper.is_active_from_runtime_state(state), "unlock showcase helper should read active state from runtime-state facade")
	_expect(str(state.unlock_showcase.get("skill_id", "")) == "plasma", "unlock showcase helper should keep skill id")
	showcase["skill_id"] = "mutated_after_apply"
	_expect(str(state.unlock_showcase.get("skill_id", "")) == "plasma", "unlock showcase helper should deep-copy payloads")
	_expect(not helper.is_active_from_runtime_state(null), "unlock showcase runtime-state facade should reject missing state")
	_expect(not bool(helper.apply_showcase_state_update(null, showcase).get("accepted", true)), "unlock showcase helper should reject null state")

	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_showcase.gd")
	var showcase_flow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_showcase_flow.gd")
	var active_body: String = _function_body(state_source, "func is_unlock_showcase_active(")
	_expect(state_source.find("_unlock_showcase_flow.finish_or_open_unlock_showcase") >= 0, "runtime perk state should delegate unlock showcase flow")
	_expect(helper_source.find("func is_active_from_runtime_state(") >= 0, "unlock showcase helper should expose runtime-state active query")
	_expect(active_body.find("_unlock_showcase_controller.is_active_from_runtime_state") >= 0, "runtime perk state should route showcase active query through runtime-state facade")
	_expect(active_body.find("_unlock_showcase_controller.is_active(unlock_showcase)") < 0, "runtime perk state should not pass showcase state directly for active query")
	_expect(state_source.find("_unlock_showcase_controller.apply_showcase_state_update") < 0, "runtime perk state should not apply showcase state directly")
	_expect(state_source.find("unlock_showcase = _unlock_showcase_controller.build") < 0, "runtime perk state should not assign showcase build inline")
	_expect(showcase_flow_source.find("apply_showcase_state_update") >= 0, "unlock showcase flow should apply showcase state through helper")


func _verify_junior_unlock_showcase_delays_finish_and_blocks_physics() -> void:
	var state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	var cooldown_driver := FakeSkillTooltipDriver.new()
	var catalog := FakeCatalog.new([_smasher_unlock_choice()])
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"battle_scene_skill_tooltip_driver": cooldown_driver,
	})
	_open_choice(state, owner, registry, catalog)
	state.choose_selected(owner, registry)

	_expect(state.is_unlock_showcase_active(), "junior unlock choice should open the showcase")
	_expect(state.is_choice_active(), "showcase should keep runtime perk choice active")
	_expect(int(state.pending_skill_choices) == 1, "showcase should delay the successful finish side effects")
	_expect(cooldown_driver.resume_calls == 0, "skill cooldowns should remain paused while showcase is active")
	_expect(_modal_gate_blocks(state), "modal gate should keep blocking battle physics through is_choice_active")

	var early_key := _key_event(KEY_ENTER)
	_expect(state.handle_input(early_key, owner, registry, Vector2(1280.0, 900.0)), "showcase should consume early key input")
	_expect(state.is_unlock_showcase_active(), "showcase should ignore dismiss before the input guard age")

	state.update(0.31, Vector2(1280.0, 900.0), owner, registry)
	state.handle_input(_key_event(KEY_ENTER), owner, registry, Vector2(1280.0, 900.0))
	_expect(not state.is_unlock_showcase_active(), "showcase should dismiss after guard age")
	_expect(not state.is_choice_active(), "last pending choice should fully close after showcase dismiss")
	_expect(int(state.pending_skill_choices) == 0, "dismiss should run the delayed successful finish")
	_expect(str(state.last_selected_id) == "unlock_plasma", "dismiss should commit last_selected_id")
	_expect(cooldown_driver.resume_calls == 1, "cooldowns should resume only after showcase dismiss")


func _verify_unlock_flight_opens_showcase_after_arrival() -> void:
	var state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	var catalog := FakeCatalog.new([_smasher_unlock_choice()])
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"battle_scene_skill_tooltip_driver": FakeSkillTooltipDriver.new(),
	})
	_open_choice(state, owner, registry, catalog)
	state.choose_selected(owner, registry, Vector2(1280.0, 900.0))
	_expect(state.is_choice_flight_active(), "unlock choice with a view size should start the orb flight")
	_expect(not state.is_unlock_showcase_active(), "showcase should wait until the orb flight finishes")

	state.update(1.90, Vector2(1280.0, 900.0), owner, registry)
	_expect(not state.is_choice_flight_active(), "orb flight should finish after its duration")
	_expect(state.is_unlock_showcase_active(), "flight finish should route through the showcase helper")


func _verify_non_junior_and_passive_choices_finish_immediately() -> void:
	var champion_state: Object = RuntimePerkState.new()
	var champion_owner := FakeOwner.new()
	champion_owner.ai_mode = "champion"
	var champion_catalog := FakeCatalog.new([_smasher_unlock_choice()])
	var champion_registry := FakeRegistry.new({
		"runtime_perk_catalog": champion_catalog,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"battle_scene_skill_tooltip_driver": FakeSkillTooltipDriver.new(),
	})
	_open_choice(champion_state, champion_owner, champion_registry, champion_catalog)
	champion_state.choose_selected(champion_owner, champion_registry)
	_expect(not champion_state.is_unlock_showcase_active(), "champion unlock choice should not open showcase")
	_expect(str(champion_state.last_selected_id) == "unlock_plasma", "champion unlock choice should finish immediately")
	_expect(int(champion_state.pending_skill_choices) == 0, "champion unlock choice should consume the pending pick")

	var passive_state: Object = RuntimePerkState.new()
	var passive_owner := FakeOwner.new()
	var passive_choice := {
		"id": "dash_acceleration",
		"name": "대쉬가속",
		"max_level": 5,
		"next_level": 1,
		"icon_color": Color(0.3, 0.8, 1.0),
		"tree": "dash",
	}
	var passive_catalog := FakeCatalog.new([passive_choice])
	var passive_registry := FakeRegistry.new({
		"runtime_perk_catalog": passive_catalog,
		"battle_scene_skill_tooltip_driver": FakeSkillTooltipDriver.new(),
	})
	_open_choice(passive_state, passive_owner, passive_registry, passive_catalog)
	passive_state.choose_selected(passive_owner, passive_registry)
	_expect(not passive_state.is_unlock_showcase_active(), "junior passive choice should not open showcase")
	_expect(str(passive_state.last_selected_id) == "dash_acceleration", "passive choice should finish immediately")


func _verify_swap_confirm_showcase_and_cancel_noop() -> void:
	var state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	owner.selected_character_type = "soldier"
	var commando_config := CommandoSkillConfig.new()
	commando_config.equipped_permanent = ["net_gun", "bazooka", "ak47"]
	var choice := _soldier_unlock_choice()
	var catalog := FakeCatalog.new([choice])
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"commando_skill_config": commando_config,
		"battle_scene_skill_tooltip_driver": FakeSkillTooltipDriver.new(),
	})
	_open_choice(state, owner, registry, catalog, "soldier")
	state.choose_selected(owner, registry)
	_expect(state.has_pending_unlock_swap(), "full soldier shared slot should open the swap dialog")
	_expect(not state.is_unlock_showcase_active(), "swap should not open showcase before confirm")

	state.cancel_pending_unlock_swap(owner)
	_expect(not state.has_pending_unlock_swap(), "cancel should close pending swap")
	_expect(not state.is_unlock_showcase_active(), "cancel should not open showcase")
	_expect(not state.runtime_skill_levels.has("soldier_unlock_bowling_trap"), "cancel should not grant the unlock perk")
	_expect(commando_config.equipped_permanent == ["net_gun", "bazooka", "ak47"], "cancel should leave equipped permanent weapons unchanged")

	state.animation_time = 0.30
	state.choose_selected(owner, registry)
	_expect(state.has_pending_unlock_swap(), "choice should be selectable again after cancel")
	state.confirm_pending_unlock_swap(owner, registry)
	_expect(state.is_unlock_showcase_active(), "swap confirm should open exactly one showcase")
	_expect(state.runtime_skill_levels.has("soldier_unlock_bowling_trap"), "swap confirm should grant the unlock perk")
	_expect(commando_config.equipped_permanent.has("bowling_trap"), "swap confirm should equip the new permanent weapon")


func _verify_reset_discards_deferred_finish() -> void:
	var state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	var catalog := FakeCatalog.new([_smasher_unlock_choice()])
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"battle_scene_skill_tooltip_driver": FakeSkillTooltipDriver.new(),
	})
	_open_choice(state, owner, registry, catalog)
	state.choose_selected(owner, registry)
	_expect(state.is_unlock_showcase_active(), "setup should have active showcase before reset")
	state.reset()
	_expect(not state.is_unlock_showcase_active(), "reset should clear the active showcase")
	_expect(str(state.last_selected_id) == "", "reset should not run the delayed finish")
	_expect(int(state.pending_skill_choices) == 0, "reset should clear pending choices")

	state.collect_star_points(1, "smasher", catalog, owner, registry)
	_expect(state.is_choice_active(), "state should open a new choice normally after reset")


func _verify_auto_dismiss_and_keycap_normalization() -> void:
	var state: Object = RuntimePerkState.new()
	var owner := FakeOwner.new()
	var catalog := FakeCatalog.new([_smasher_unlock_choice()])
	var registry := FakeRegistry.new({
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": SmasherSkillConfig.new(),
		"battle_scene_skill_tooltip_driver": FakeSkillTooltipDriver.new(),
	})
	_open_choice(state, owner, registry, catalog)
	state.choose_selected(owner, registry)
	state.update(6.01, Vector2(1280.0, 900.0), owner, registry)
	_expect(not state.is_unlock_showcase_active(), "showcase should auto-dismiss after max age")
	_expect(str(state.last_selected_id) == "unlock_plasma", "auto-dismiss should run delayed finish")

	var renderer: Object = RuntimePerkOverlayRenderer.new()
	_expect(
		str(renderer._normalize_keycap_message("W/↑ 홀드 후 손을 떼면 발동")) == "W / ↑ 홀드 후 손을 떼면 발동",
		"W/arrow slash token should be promoted to separated keycaps"
	)
	_expect(
		str(renderer._normalize_keycap_message("0.6초 내 A-W-D 또는 D-W-A 입력")) == "0.6초 내 A - W - D 또는 D - W - A 입력",
		"A-W-D sequence should be promoted without touching the time token"
	)
	_expect(
		str(renderer._normalize_keycap_message("←/→ + 좌클릭 동시 입력")) == "← / → + 좌클릭 동시 입력",
		"arrow slash should promote while mouse prose remains text"
	)


func _open_choice(
	state: Object,
	owner: Object,
	registry: Object,
	catalog: Object,
	character_type: String = "smasher"
) -> void:
	state.collect_star_points(1, character_type, catalog, owner, registry)
	state.animation_time = 0.30


func _modal_gate_blocks(state: Object) -> bool:
	var provider := FakeModuleProvider.new({"runtime_perk_state": state})
	var gate: Object = BattleSceneModalGateController.new()
	return bool(gate.should_block_battle_physics(Callable(provider, "get_cached_instance")))


func _smasher_unlock_choice() -> Dictionary:
	return {
		"id": "unlock_plasma",
		"name": "플라즈마",
		"max_level": 1,
		"next_level": 1,
		"unlocks_skill": "plasma",
		"character_restriction": "smasher",
		"icon_color": Color(0.0, 0.78, 1.0),
		"tree": "unlock",
	}


func _soldier_unlock_choice() -> Dictionary:
	return {
		"id": "soldier_unlock_bowling_trap",
		"name": "볼링트랩",
		"max_level": 1,
		"next_level": 1,
		"unlocks_skill": "bowling_trap",
		"character_restriction": "soldier",
		"icon_color": Color(0.68, 0.78, 0.52),
		"tree": "unlock",
	}


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)
