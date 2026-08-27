extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")
const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")
const BattleSceneInputController := preload("res://scripts/core/battle_scene_input_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const BattleSceneOverlayInputController := preload("res://scripts/core/battle_scene_overlay_input_controller.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const GuardianSpringChosikSwapOverlayHost := preload(
	"res://scripts/hud/guardian_spring_chosik_swap_overlay_host.gd"
)
const TowerAscentGuardianSpringNode := preload(
	"res://scripts/tower_ascent/tower_ascent_guardian_spring_node.gd"
)
const TowerAscentNodeActionTransaction := preload(
	"res://scripts/tower_ascent/tower_ascent_node_action_transaction.gd"
)
const TowerAscentNodeModalLocalization := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_localization.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

var _failures: Array[String] = []
var _input_modules: Dictionary = {}


class Owner:
	extends RefCounted
	var selected_character_type := "smasher"
	var tower_ascent_soul_summoning_owned := false

	func _init(character_type: String = "smasher") -> void:
		selected_character_type = character_type

	func set_tower_ascent_guardian_projection(
		_sealed_guardians: Array,
		soul_summoning_owned: bool
	) -> void:
		tower_ascent_soul_summoning_owned = soul_summoning_owned

	func set_tower_ascent_prayer_projection(_count: int, _locked: bool) -> void:
		pass


class LingpetRuntime:
	extends RefCounted
	var snapshot := {
		"state": "none",
		"pet_id": "",
		"owned_pet_ids": [],
		"guardian_run_state": {"pets": {}},
	}

	func build_save_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func apply_save_snapshot(value: Dictionary, _owner: Object, _registry: Object) -> Dictionary:
		snapshot = value.duplicate(true)
		return {"restored": true}

	func capture_tower_spring_replace_rollback_snapshot() -> Dictionary:
		return snapshot.duplicate(true)

	func restore_tower_spring_replace_rollback_snapshot(
		value: Dictionary,
		_owner: Object,
		_registry: Object
	) -> bool:
		snapshot = value.duplicate(true)
		return true


class Registry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


class FlowInputProbe:
	extends RefCounted
	var input_calls := 0

	func is_active() -> bool:
		return true

	func has_pending_guardian_spring_chosik_swap() -> bool:
		return true

	func get_phase_name() -> String:
		return "NODE_MODAL"

	func handle_input(_event: InputEvent) -> void:
		input_calls += 1


class CountingRuntimePerkOverlayRenderer:
	extends RefCounted
	var draw_calls := 0
	var standalone_draw_calls := 0
	var unlock_swap_dialog_draw_calls := 0

	func has_visible_effects(
		_runtime_state: Object,
		_mythic_item_runtime: Object = null
	) -> bool:
		return true

	func draw(
		_canvas: CanvasItem,
		runtime_state: Object,
		_catalog: Object,
		_view_size: Vector2,
		_icon_renderer: Object = null,
		_mythic_item_runtime: Object = null,
		_perf_logger: Object = null
	) -> void:
		draw_calls += 1
		if runtime_state.has_pending_unlock_swap():
			_draw_unlock_swap_dialog()

	func draw_standalone_unlock_swap_dialog(
		_canvas: CanvasItem,
		runtime_state: Object,
		_snapshot: Dictionary,
		_view_size: Vector2,
		_icon_renderer: Object = null
	) -> bool:
		standalone_draw_calls += 1
		if not runtime_state.has_pending_unlock_swap():
			return false
		_draw_unlock_swap_dialog()
		return true

	func _draw_unlock_swap_dialog() -> void:
		unlock_swap_dialog_draw_calls += 1


func _init() -> void:
	_verify_full_smasher_two_stage_commit()
	_verify_open_and_dynamic_capacity_controls()
	_verify_commando_character_routing()
	_verify_restore_unlock_result_contract()
	_verify_cancel_restores_the_palm()
	_verify_swap_dialog_has_one_frame_owner()
	_verify_overlay_input_never_leaks_to_the_spring_modal()
	_verify_prayer_visit_gate_and_copy()
	if _failures.is_empty():
		print("tower_guardian_spring_slot_and_prayer_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_full_smasher_two_stage_commit() -> void:
	var fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	var spring: Object = fixture.spring
	var config: Object = fixture.config
	var runtime_state: Object = fixture.runtime_state
	var owner: Object = fixture.owner
	var registry: Object = fixture.registry
	var run_state: Object = fixture.run_state
	var resolution_ids: Dictionary = fixture.resolution_ids
	var transaction: Object = fixture.transaction
	_expect(config.equipped_skills.size() == config.get_max_skill_slots(), "Smasher production fixture must be truly full")
	var palm := _find_action(spring.build_actions("spring-full", 8101, run_state, owner, registry), "guardian_spring:palm")
	var first_palm_choice: Dictionary = palm.get("payload", {}).get("choice", {})
	_expect(bool(palm.get("enabled", false)), "a full-slot palm must stay enabled")
	_expect(
		str(first_palm_choice.get("description", ""))
		== "바위가 무엇을 내어줄지는 알 수 없습니다."
		and bool(first_palm_choice.get("hide_hover_detail", false))
		and bool(palm.get("first_visit_spoiler_gate", false)),
		"the first-visit spoiler gate must replace the full-slot Chosik disclosure with safe copy"
	)
	var discarded_skill := str(config.equipped_skills[0])
	var result: Dictionary = spring.execute_action(
		"guardian_spring:palm",
		"spring-full:palm",
		"spring-full",
		8101,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	print(
		"tower_guardian_spring_slot_and_prayer_smoke: palm_probe reason=%s runtime_pending=%s node_pending=%s"
		% [
			str(result.get("reason", "")),
			str(runtime_state.has_pending_unlock_swap()).to_lower(),
			str(spring.has_pending_chosik_swap()).to_lower(),
		]
	)
	_expect(
		bool(result.get("accepted", false))
		and not bool(result.get("applied", true))
		and str(result.get("reason", "")) != "effect_rejected"
		and runtime_state.has_pending_unlock_swap()
		and spring.has_pending_chosik_swap(),
		"the production palm leg must preserve the intentional runtime swap instead of rolling it back"
	)
	_expect(
		(runtime_state.get_pending_unlock_swap().get("candidates", []) as Array).size()
		== config.get_max_skill_slots(),
		"the full Smasher path must expose all equipped Chosik as replacement choices"
	)
	var swap_rects: Array = runtime_state.get_unlock_swap_option_rects(Vector2(760.0, 750.0))
	var overlay_renderer := RuntimePerkOverlayRenderer.new()
	var all_icon_text_gaps_clear: bool = (
		swap_rects.size() == config.get_max_skill_slots()
	)
	for rect_value in swap_rects:
		var content_layout: Dictionary = overlay_renderer.build_unlock_swap_option_content_layout(
			rect_value as Rect2
		)
		all_icon_text_gaps_clear = (
			all_icon_text_gaps_clear
			and float(content_layout.get("icon_text_gap", -1.0)) >= 4.0
		)
	_expect(
		all_icon_text_gaps_clear,
		"the five-choice 760x750 swap layout must keep every icon clear of its skill label"
	)
	_expect(spring.get_history().is_empty(), "the pending leg must not append history before player confirmation")
	_expect(
		runtime_state.confirm_pending_unlock_swap(owner, registry),
		"the runtime five-choice dialog must confirm the selected replacement"
	)
	var commit_result: Dictionary = spring.commit_chosik_swap(
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	var guardian_state: Dictionary = spring.export_state()
	_expect(
		bool(commit_result.get("accepted", false))
		and bool(commit_result.get("applied", false))
		and spring.has_soul_summoning()
		and config.equipped_skills.has(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
		and not config.equipped_skills.has(discarded_skill)
		and config.equipped_skills.size() <= config.get_max_skill_slots()
		and not (guardian_state.get("first_pick_candidates", []) as Array).is_empty()
		and spring.get_history().size() == 1,
		"swap confirmation must atomically finish Soul Summoning, snapshots, first picks, and one history record"
	)


func _verify_open_and_dynamic_capacity_controls() -> void:
	var open_fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
	])
	var open_result := _execute_palm(open_fixture, "spring-open", 8102)
	_expect(
		bool(open_result.get("accepted", false))
		and bool(open_result.get("applied", false))
		and not open_fixture.runtime_state.has_pending_unlock_swap(),
		"a real 4-of-max Smasher config must commit directly without a swap dialog"
	)

	var bonus_fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	bonus_fixture.config.set_item_skill_slot_bonus(1)
	_expect(bonus_fixture.config.get_max_skill_slots() == 6, "the item bonus fixture must derive a six-slot maximum")
	var bonus_result := _execute_palm(bonus_fixture, "spring-bonus", 8103)
	_expect(
		bool(bonus_result.get("accepted", false))
		and bool(bonus_result.get("applied", false))
		and not bonus_fixture.runtime_state.has_pending_unlock_swap(),
		"five equipped Chosik must remain open when the production maximum is six"
	)


func _verify_commando_character_routing() -> void:
	var spring := TowerAscentGuardianSpringNode.new()
	var run_state := _new_run_state("spring-soldier")
	var runtime_state := RuntimePerkState.new()
	var config := CommandoSkillConfig.new()
	config.equipped_permanent = ["net_gun", "fire_support", "bowling_trap"]
	var owner := Owner.new("soldier")
	var registry := Registry.new()
	registry.instances = {
		"lingpet_egg_runtime": LingpetRuntime.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_state": runtime_state,
		"commando_skill_config": config,
	}
	var resolution_ids := {}
	var transaction := TowerAscentNodeActionTransaction.new()
	var discarded_skill := str(config.equipped_permanent[0])
	var result := spring.execute_action(
		"guardian_spring:palm",
		"spring-soldier:palm",
		"spring-soldier",
		8104,
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(
		bool(result.get("accepted", false))
		and runtime_state.has_pending_unlock_swap()
		and runtime_state.confirm_pending_unlock_swap(owner, registry),
		"the character-context route must open and confirm the same common Chosik swap for Commando"
	)
	var committed := spring.commit_chosik_swap(
		run_state,
		resolution_ids,
		transaction,
		owner,
		registry
	)
	_expect(
		bool(committed.get("applied", false))
		and config.get_equipped_permanent().has(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
		and not config.get_equipped_permanent().has(discarded_skill),
		"the non-Smasher route must replace the selected Commando permanent slot"
	)


func _verify_restore_unlock_result_contract() -> void:
	var full_fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	full_fixture.spring.restore_state({"soul_summoning_owned": true})
	var full_restored := bool(full_fixture.spring.call(
		"_restore_soul_unlock_runtime",
		full_fixture.owner,
		full_fixture.registry
	))
	_expect(
		not full_restored
		and not full_fixture.runtime_state.has_pending_unlock_swap()
		and not full_fixture.config.equipped_skills.has(
			CommonSkillCatalog.SOUL_SUMMON_ART_ID
		),
		"snapshot fallback restore must reject a full-slot swap and leave no orphan runtime pending state"
	)

	var open_fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
	])
	open_fixture.spring.restore_state({"soul_summoning_owned": true})
	var open_restored := bool(open_fixture.spring.call(
		"_restore_soul_unlock_runtime",
		open_fixture.owner,
		open_fixture.registry
	))
	_expect(
		open_restored
		and not open_fixture.runtime_state.has_pending_unlock_swap()
		and open_fixture.config.equipped_skills.has(
			CommonSkillCatalog.SOUL_SUMMON_ART_ID
		),
		"snapshot fallback restore must accept a direct unlock and capture its committed state"
	)


func _verify_cancel_restores_the_palm() -> void:
	var fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	var before: Array = fixture.config.equipped_skills.duplicate()
	var result := _execute_palm(fixture, "spring-cancel", 8105)
	_expect(bool(result.get("accepted", false)) and fixture.runtime_state.has_pending_unlock_swap(), "cancel fixture must first open a swap")
	fixture.runtime_state.cancel_pending_unlock_swap(fixture.owner)
	var cancel_result: Dictionary = fixture.spring.cancel_chosik_swap(
		fixture.owner,
		fixture.registry,
		fixture.run_state
	)
	var restored_palm := _find_action(
		fixture.spring.build_actions(
			"spring-cancel",
			8105,
			fixture.run_state,
			fixture.owner,
			fixture.registry
		),
		"guardian_spring:palm"
	)
	_expect(
		bool(cancel_result.get("handled", false))
		and fixture.config.equipped_skills == before
		and not fixture.spring.has_soul_summoning()
		and fixture.spring.get_history().is_empty()
		and bool(restored_palm.get("enabled", false)),
		"Esc cancellation must clear both pending owners and restore the original palm transaction"
	)


func _verify_swap_dialog_has_one_frame_owner() -> void:
	var fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	var result := _execute_palm(fixture, "spring-draw-owner", 8109)
	_expect(
		bool(result.get("accepted", false))
		and fixture.runtime_state.has_pending_unlock_swap(),
		"draw-owner fixture must open the production pending Chosik swap"
	)
	var flow_probe := FlowInputProbe.new()
	var renderer := CountingRuntimePerkOverlayRenderer.new()
	fixture.registry.instances["guardian_spring_chosik_swap_overlay_host"] = (
		GuardianSpringChosikSwapOverlayHost.new()
	)
	fixture.registry.instances["runtime_perk_overlay_renderer"] = renderer
	fixture.registry.instances["tower_ascent_flow_owner"] = flow_probe
	_input_modules = {
		"runtime_perk_state": fixture.runtime_state,
		"tower_ascent_flow_owner": flow_probe,
	}
	var canvas := Node2D.new()
	get_root().add_child(canvas)
	var drawer := BattleSceneDrawer.new()
	var frame_controller := BattleSceneFrameController.new()

	# One production frame reaches both the scene HUD pass and the detached
	# Spring host. Only the detached host may own this exact dialog draw.
	drawer._draw_hud_overlays(canvas, fixture.registry, Vector2(760.0, 750.0), {})
	frame_controller._draw_guardian_spring_chosik_swap_if_active(
		canvas,
		fixture.registry,
		Callable(self, "_get_input_module"),
		Vector2(760.0, 750.0),
		null
	)
	_expect(
		renderer.draw_calls == 0
		and renderer.standalone_draw_calls == 1
		and renderer.unlock_swap_dialog_draw_calls == 1,
		"a pending Spring Chosik swap must execute _draw_unlock_swap_dialog exactly once per frame"
	)
	canvas.free()
	_input_modules.clear()


func _verify_overlay_input_never_leaks_to_the_spring_modal() -> void:
	var fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	var result := _execute_palm(fixture, "spring-input", 8107)
	_expect(bool(result.get("accepted", false)) and fixture.runtime_state.has_pending_unlock_swap(), "input fixture must open the real runtime swap")
	var route := _prepare_input_route(fixture)
	var flow_probe: Object = route.flow
	var input_controller: Object = route.controller
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = Vector2(-10000.0, -10000.0)
	var pointer_handled := bool(input_controller.call(
		"_handle_tower_ascent_flow_input",
		pointer,
		fixture.owner,
		fixture.registry,
		Callable(self, "_get_input_module"),
		{}
	))
	_expect(
		pointer_handled
		and flow_probe.input_calls == 0
		and fixture.runtime_state.has_pending_unlock_swap(),
		"an off-card pointer press must stop at the standalone Chosik overlay without confirming"
	)
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	var confirm_handled := bool(input_controller.call(
		"_handle_tower_ascent_flow_input",
		confirm,
		fixture.owner,
		fixture.registry,
		Callable(self, "_get_input_module"),
		{}
	))
	_expect(confirm_handled, "the Tower whitelist must report the overlay-owned confirm as handled")
	_expect(flow_probe.input_calls == 0, "confirm must not reach the backing Tower node modal")
	_expect(
		not fixture.runtime_state.has_pending_unlock_swap()
		and fixture.config.equipped_skills.has(CommonSkillCatalog.SOUL_SUMMON_ART_ID),
		"confirm must resolve the runtime replacement through the standalone overlay"
	)
	fixture.spring.commit_chosik_swap(
		fixture.run_state,
		fixture.resolution_ids,
		fixture.transaction,
		fixture.owner,
		fixture.registry
	)

	var cancel_fixture := _build_smasher_fixture([
		"drive",
		"power_smashing",
		"plasma",
		"recovery",
		"magnum_grip",
	])
	var cancel_result := _execute_palm(cancel_fixture, "spring-input-cancel", 8108)
	_expect(
		bool(cancel_result.get("accepted", false))
		and cancel_fixture.runtime_state.has_pending_unlock_swap(),
		"Esc fixture must open the real runtime swap"
	)
	var cancel_route := _prepare_input_route(cancel_fixture)
	var cancel_flow_probe: Object = cancel_route.flow
	var cancel_input_controller: Object = cancel_route.controller
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	var escape_handled := bool(cancel_input_controller.call(
		"_handle_tower_ascent_flow_input",
		escape,
		cancel_fixture.owner,
		cancel_fixture.registry,
		Callable(self, "_get_input_module"),
		{}
	))
	_expect(escape_handled, "the Tower whitelist must report the overlay-owned Esc as handled")
	_expect(cancel_flow_probe.input_calls == 0, "Esc must not reach the backing Tower node modal")
	_expect(
		not cancel_fixture.runtime_state.has_pending_unlock_swap(),
		"Esc must cancel the runtime unlock swap"
	)
	cancel_fixture.spring.cancel_chosik_swap(
		cancel_fixture.owner,
		cancel_fixture.registry,
		cancel_fixture.run_state
	)
	_input_modules.clear()


func _prepare_input_route(fixture: Dictionary) -> Dictionary:
	var flow_probe := FlowInputProbe.new()
	var host := GuardianSpringChosikSwapOverlayHost.new()
	fixture.registry.instances["tower_ascent_flow_owner"] = flow_probe
	fixture.registry.instances["guardian_spring_chosik_swap_overlay_host"] = host
	_input_modules = {
		"tower_ascent_flow_owner": flow_probe,
		"runtime_perk_state": fixture.runtime_state,
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
		"battle_scene_overlay_input_controller": BattleSceneOverlayInputController.new(),
	}
	return {
		"flow": flow_probe,
		"controller": BattleSceneInputController.new(),
	}


func _verify_prayer_visit_gate_and_copy() -> void:
	var expected_prayer_copy_by_locale := {
		LanguageSettings.LANGUAGE_KOREAN: "모든 능력치가 3.0%p 상승했다!",
		LanguageSettings.LANGUAGE_ENGLISH: "All stats increased by 3.0 percentage points!",
		LanguageSettings.LANGUAGE_CHINESE: "所有属性提升了3.0个百分点！",
		LanguageSettings.LANGUAGE_JAPANESE: "すべての能力値が3.0ポイント上昇した！",
	}
	for locale in expected_prayer_copy_by_locale:
		var locale_text: Dictionary = TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(
			locale,
			{}
		)
		_expect(
			str(locale_text.get(
				TowerAscentNodeModalLocalization.KEY_SPRING_PRAYER_COMPLETED,
				""
			)).format({"bonus": "3.0"}) == str(expected_prayer_copy_by_locale[locale]),
			"prayer success copy must stay synchronized and respectful for locale %s" % locale
		)
	var first_visit_copy_by_locale := {
		LanguageSettings.LANGUAGE_KOREAN: [
			"바위가 무엇을 내어줄지는 알 수 없습니다.",
			"정성을 들이면 기운이 오릅니다.",
			"샘터를 떠난다",
		],
		LanguageSettings.LANGUAGE_ENGLISH: [
			"What the stone will offer remains unknown.",
			"Devotion causes the energy to rise.",
			"Leave the spring",
		],
		LanguageSettings.LANGUAGE_CHINESE: [
			"无法得知岩石会赐予什么。",
			"虔诚祈祷会提升气息。",
			"离开泉边",
		],
		LanguageSettings.LANGUAGE_JAPANESE: [
			"岩が何を授けるかは分かりません。",
			"祈りを捧げると気が高まります。",
			"泉を離れる",
		],
		LanguageSettings.LANGUAGE_SPANISH: [
			"No se sabe qué concederá la roca.",
			"La devoción eleva la energía.",
			"Abandonar el manantial",
		],
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: [
			"Não se sabe o que a rocha concederá.",
			"A devoção eleva a energia.",
			"Deixar a fonte",
		],
		LanguageSettings.LANGUAGE_RUSSIAN: [
			"Неизвестно, что дарует камень.",
			"Искренняя молитва усиливает энергию.",
			"Покинуть источник",
		],
	}
	for locale in first_visit_copy_by_locale:
		var locale_text: Dictionary = TowerAscentNodeModalLocalization.TEXT_BY_LOCALE.get(
			locale,
			{}
		)
		var expected_copy: Array = first_visit_copy_by_locale[locale]
		_expect(
			str(locale_text.get(TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_VISIT_PALM_DESCRIPTION, "")) == str(expected_copy[0])
			and str(locale_text.get(TowerAscentNodeModalLocalization.KEY_SPRING_FIRST_VISIT_PRAYER_DESCRIPTION, "")) == str(expected_copy[1])
			and str(locale_text.get(TowerAscentNodeModalLocalization.KEY_SPRING_EXIT, "")) == str(expected_copy[2]),
			"first-visit safe copy and Spring exit must be translated directly for locale %s" % locale
		)
	var fixture := _build_smasher_fixture(["drive", "power_smashing"])
	var actions: Array = fixture.spring.build_actions(
		"spring-prayer-a",
		8106,
		fixture.run_state,
		fixture.owner,
		fixture.registry
	)
	var prayer := _find_action_with_prefix(actions, "guardian_spring:prayer:")
	var first_palm := _find_action(actions, "guardian_spring:palm")
	var first_action_contracts := [
		{
			"action": first_palm,
			"label": "손바닥을 대본다",
			"description": "바위가 무엇을 내어줄지는 알 수 없습니다.",
		},
		{
			"action": prayer,
			"label": "기도한다",
			"description": "정성을 들이면 기운이 오릅니다.",
		},
	]
	for contract in first_action_contracts:
		var first_action: Dictionary = contract.action
		var first_payload: Dictionary = first_action.get("payload", {})
		var first_choice: Dictionary = first_payload.get("choice", {})
		_expect(bool(first_action.get("first_visit_spoiler_gate", false)), "empty-run first visit owns the spoiler gate")
		_expect(str(first_action.get("label", "")) == str(contract.label), "first visit reveals the action name")
		_expect(str(first_action.get("cost_text", "")) == "무료", "first visit reveals the actionable cost")
		_expect(str(first_choice.get("name", "")) == str(contract.label), "first visit card title mirrors the safe action name")
		_expect(str(first_choice.get("description", "")) == str(contract.description), "first visit card shows one spoiler-safe explanation")
		_expect(bool(first_choice.get("hide_level_text", false)), "first visit suppresses level fallback copy")
		_expect(bool(first_choice.get("hide_hover_detail", false)), "first visit suppresses hover detail")
		_expect(str(first_choice.get("card_content_kind", "")) == "guardian_spring_mystery", "first visit uses the neutral mystery symbol")
		_expect(str(first_choice.get("guardian_pet_id", "")).is_empty(), "first visit exposes no guardian identity")
		_expect(str(first_choice.get("guardian_portrait_path", "")).is_empty(), "first visit exposes no guardian portrait")
		_expect(str(first_choice.get("icon_id", "")).is_empty(), "first visit exposes no guardian icon")
		_expect((first_payload.get("presentation", {}) as Dictionary).is_empty(), "first visit hides presentation tooltip fields")
	_expect(str(prayer.get("payload", {}).get("operation", "")) == "prayer", "spoiler masking preserves transaction operation")
	_expect(int(prayer.get("payload", {}).get("cost", -1)) == 0, "spoiler masking preserves actual first-prayer cost")
	_expect(bool(prayer.get("enabled", false)), "spoiler masking preserves enabled state")
	var spoiler_renderer := RuntimePerkOverlayRenderer.new()
	var spoiler_text_layout: Dictionary = spoiler_renderer.build_tower_node_card_text_layout(
		first_palm,
		Rect2(0.0, 0.0, 315.0, 114.0)
	)
	var spoiler_hover_layout: Dictionary = spoiler_renderer.build_tower_node_hover_detail_layout(
		first_palm,
		Rect2(0.0, 0.0, 315.0, 114.0)
	)
	_expect(not spoiler_text_layout.has("description_hidden_by_spoiler_gate"), "the relaxed gate must not publish dead hidden-description telemetry")
	_expect(not bool(spoiler_text_layout.get("description_hidden_by_budget", true)), "empty spoiler copy is not misreported as budget overflow")
	_expect((spoiler_text_layout.get("description_rows", []) as Array).has("바위가 무엇을 내어줄지는 알 수 없습니다."), "the card layout must consume the safe first-visit explanation")
	_expect(bool(spoiler_hover_layout.get("hidden_by_spoiler_gate", false)), "hover telemetry identifies the spoiler gate")
	_expect((spoiler_hover_layout.get("rows", []) as Array).is_empty(), "first-visit hover produces zero rows")
	var result: Dictionary = fixture.spring.execute_action(
		str(prayer.get("id", "")),
		"spring-prayer-a:prayer",
		"spring-prayer-a",
		8106,
		fixture.run_state,
		fixture.resolution_ids,
		fixture.transaction,
		fixture.owner,
		fixture.registry
	)
	_expect(
		str(result.get("message", "")) == "모든 능력치가 3.0%p 상승했다!",
		"the committed prayer receipt must use the exact percentage-point copy"
	)
	var same_visit: Array = fixture.spring.build_actions(
		"spring-prayer-a",
		8106,
		fixture.run_state,
		fixture.owner,
		fixture.registry
	)
	_expect(
		not bool(_find_action(same_visit, "guardian_spring:palm").get("enabled", true))
		and not bool(_find_action_with_prefix(same_visit, "guardian_spring:prayer:").get("enabled", true)),
		"one committed prayer must disable palm and prayer symmetrically for that visit"
	)
	var next_prayer := _find_action_with_prefix(
		fixture.spring.build_actions(
			"spring-prayer-b",
			8106,
			fixture.run_state,
			fixture.owner,
			fixture.registry
		),
		"guardian_spring:prayer:"
	)
	var next_palm := _find_action(
		fixture.spring.build_actions(
			"spring-prayer-b",
			8106,
			fixture.run_state,
			fixture.owner,
			fixture.registry
		),
		"guardian_spring:palm"
	)
	_expect(not bool(next_prayer.get("first_visit_spoiler_gate", false)), "one prayer immediately releases the run-scoped spoiler gate")
	_expect(not str(next_prayer.get("cost_text", "")).is_empty(), "post-prayer visit reveals the next cost")
	_expect(not str(next_palm.get("payload", {}).get("choice", {}).get("description", "")).is_empty(), "post-prayer visit reveals Palm details")
	_expect(str(next_palm.get("label", "")) == "손바닥을 대본다" and str(next_prayer.get("label", "")) == "기도한다", "later visits retain unmasked action labels")
	_expect(
		bool(next_prayer.get("enabled", false))
		and int(next_prayer.get("payload", {}).get("cost", -1)) == 2,
		"the next Spring node must reopen prayer at the cumulative two-Muhon cost"
	)
	var modal := TowerAscentNodeModalState.new()
	modal.open("spring-prayer-a", "guardian_spring", {"gold": 0, "muhon": 20}, actions)
	var modal_model: Dictionary = modal.build_view_model()
	var modal_actions: Array = modal_model.get("actions", [])
	_expect(bool((modal_actions[0] as Dictionary).get("first_visit_spoiler_gate", false)), "modal normalization preserves the live first-visit gate")
	_expect(str((modal_actions[0] as Dictionary).get("label", "")) == "손바닥을 대본다", "production modal keeps the restored first action label")
	_expect(str((modal_actions[-1] as Dictionary).get("label", "")) == "샘터를 떠난다", "Guardian Spring owns its node-specific exit copy")
	_expect(str(modal_model.get("description", "")).is_empty(), "the first-visit gate still hides the reward-oriented node description")
	modal.open("shop-copy", "shop", {"gold": 0, "muhon": 0}, [])
	_expect(str((modal.build_view_model().get("actions", []) as Array)[-1].get("label", "")) == "상점 나가기", "Spring exit copy cannot change the shop exit")
	modal.open("training-copy", "training", {"gold": 0, "muhon": 0}, [])
	_expect(str((modal.build_view_model().get("actions", []) as Array)[-1].get("label", "")) == "업무 종료", "Spring exit copy cannot change other node exits")


func _build_smasher_fixture(equipped: Array) -> Dictionary:
	var config := SmasherSkillConfig.new()
	config.equipped_skills = equipped.duplicate()
	var runtime_state := RuntimePerkState.new()
	var owner := Owner.new("smasher")
	var registry := Registry.new()
	registry.instances = {
		"lingpet_egg_runtime": LingpetRuntime.new(),
		"runtime_perk_catalog": RuntimePerkCatalog.new(),
		"runtime_perk_state": runtime_state,
		"smasher_skill_config": config,
	}
	return {
		"spring": TowerAscentGuardianSpringNode.new(),
		"run_state": _new_run_state("slot-prayer-fixture"),
		"runtime_state": runtime_state,
		"config": config,
		"owner": owner,
		"registry": registry,
		"resolution_ids": {},
		"transaction": TowerAscentNodeActionTransaction.new(),
	}


func _new_run_state(run_id: String) -> Object:
	var run_state := TowerAscentRunState.new()
	_expect(run_state.begin(run_id, {"gold": 0, "muhon": 20}), "run-state fixture must begin")
	return run_state


func _execute_palm(fixture: Dictionary, node_id: String, map_seed: int) -> Dictionary:
	return fixture.spring.execute_action(
		"guardian_spring:palm",
		"%s:palm" % node_id,
		node_id,
		map_seed,
		fixture.run_state,
		fixture.resolution_ids,
		fixture.transaction,
		fixture.owner,
		fixture.registry
	)


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for value in actions:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == action_id:
			return value as Dictionary
	return {}


func _get_input_module(key: String) -> Variant:
	return _input_modules.get(key, null)


func _find_action_with_prefix(actions: Array, prefix: String) -> Dictionary:
	for value in actions:
		if value is Dictionary and str((value as Dictionary).get("id", "")).begins_with(prefix):
			return value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
