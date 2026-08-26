extends RefCounted

const TowerAscentFeatureFlags := preload("res://scripts/tower_ascent/tower_ascent_feature_flags.gd")


func should_block_battle_physics(module_getter: Callable) -> bool:
	return _should_block_battle_physics(module_getter, null)


func should_block_battle_physics_with_perf(module_getter: Callable, perf_logger: Object = null) -> bool:
	return _should_block_battle_physics(module_getter, perf_logger)


func should_block_mobile_controls(module_getter: Callable) -> bool:
	return (
		should_block_battle_physics(module_getter)
		or is_active_item_debug_spawn_menu_open(module_getter)
	)


func is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "runtime_perk_state", "is_choice_active")


func is_angel_blessing_modal_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "runtime_perk_state", "is_angel_blessing_modal_active")


func has_angel_blessing_modal_work(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "runtime_perk_state", "has_angel_blessing_modal_work")


func is_runtime_perk_feedback_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "runtime_perk_state", "has_feedback")


func is_character_debug_picker_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "character_debug_picker", "is_open")


func is_perk_debug_picker_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "runtime_perk_debug_picker", "is_open")


func is_stage_debug_picker_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "stage_debug_picker", "is_open")


func is_weather_debug_picker_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "weather_debug_picker", "is_open")


func is_lingpet_debug_picker_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "lingpet_debug_picker", "is_open")


func is_mythic_management_menu_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "mythic_item_runtime", "is_debug_management_menu_open")


func is_pandora_legacy_selection_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "mythic_item_runtime", "is_pandora_legacy_selection_active")


func is_mythic_acquisition_cinematic_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "mythic_item_runtime", "is_acquisition_cinematic_active")


func is_character_info_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "character_info_overlay", "is_active")


func is_pause_menu_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "pause_menu_overlay", "is_active")


func is_defeat_chance_gems_continue_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "defeat_chance_gems_continue_screen", "is_active")


func does_defeat_chance_gems_continue_block_battle(module_getter: Callable) -> bool:
	var screen := _get_module(module_getter, "defeat_chance_gems_continue_screen")
	if screen != null and screen.has_method("blocks_battle_physics"):
		return bool(screen.blocks_battle_physics())
	return _module_bool(module_getter, "defeat_chance_gems_continue_screen", "is_active")


func is_defeat_settlement_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "defeat_settlement_screen", "is_active")


func is_grip_style_selection_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "grip_style_selection_overlay", "is_active")


func is_skill_orb_tooltip_tutorial_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "skill_orb_tooltip_tutorial_hint", "blocks_battle_physics")


func is_active_item_debug_spawn_menu_open(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "active_item_runtime", "is_debug_spawn_menu_open")


func is_elixir_cinematic_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "active_item_runtime", "is_elixir_cinematic_active")


func is_lingpet_acquire_cutin_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "lingpet_egg_runtime", "is_acquire_cutin_active")


func is_lingpet_hatch_break_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "lingpet_egg_runtime", "is_hatch_break_active")


func is_lingpet_overflow_choice_active(module_getter: Callable) -> bool:
	return _module_bool(module_getter, "lingpet_egg_runtime", "is_overflow_choice_active")


func is_guardian_spring_chosik_swap_active(module_getter: Callable) -> bool:
	return (
		_module_bool(
			module_getter,
			"tower_ascent_flow_owner",
			"has_pending_guardian_spring_chosik_swap"
		)
		and _module_bool(module_getter, "runtime_perk_state", "has_pending_unlock_swap")
	)


func is_guardian_spring_confirmation_active(module_getter: Callable) -> bool:
	return _module_bool(
		module_getter,
		"tower_ascent_flow_owner",
		"has_pending_guardian_spring_confirmation"
	)


func is_lingpet_guardian_enhance_cutin_active(module_getter: Callable) -> bool:
	return _module_bool(
		module_getter,
		"lingpet_egg_runtime",
		"is_guardian_enhance_cutin_active"
	)


func is_tower_ascent_flow_active(module_getter: Callable) -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and _module_bool(module_getter, "tower_ascent_flow_owner", "is_active")
	)


func is_tower_start_card_active(module_getter: Callable) -> bool:
	return (
		TowerAscentFeatureFlags.is_vertical_slice_enabled()
		and _module_bool(module_getter, "tower_start_card_state", "is_active")
	)


func _should_block_battle_physics(module_getter: Callable, perf_logger: Object = null) -> bool:
	if _timed_bool(perf_logger, "physics.modal_gate.tower_start_card", Callable(self, "is_tower_start_card_active").bind(module_getter)):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.stage1_han_miryang_prologue", module_getter, "stage1_han_miryang_prologue_presentation", "blocks_battle_physics"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.stage7_akamu_prebattle", module_getter, "stage7_akamu_prebattle_presentation", "blocks_battle_physics"):
		return true
	if _timed_bool(perf_logger, "physics.modal_gate.tower_ascent_flow", Callable(self, "is_tower_ascent_flow_active").bind(module_getter)):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.runtime_perk_choice", module_getter, "runtime_perk_state", "is_choice_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.angel_blessing", module_getter, "runtime_perk_state", "is_angel_blessing_modal_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.character_debug", module_getter, "character_debug_picker", "is_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.perk_debug", module_getter, "runtime_perk_debug_picker", "is_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.stage_debug", module_getter, "stage_debug_picker", "is_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.weather_debug", module_getter, "weather_debug_picker", "is_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.lingpet_debug", module_getter, "lingpet_debug_picker", "is_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.mythic_management", module_getter, "mythic_item_runtime", "is_debug_management_menu_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.pandora_legacy", module_getter, "mythic_item_runtime", "is_pandora_legacy_selection_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.mythic_acquisition", module_getter, "mythic_item_runtime", "is_acquisition_cinematic_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.active_item_debug", module_getter, "active_item_runtime", "is_debug_spawn_menu_open"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.pause_menu", module_getter, "pause_menu_overlay", "is_active"):
		return true
	if _timed_bool(perf_logger, "physics.modal_gate.defeat_chance_gems_continue", Callable(self, "does_defeat_chance_gems_continue_block_battle").bind(module_getter)):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.defeat_settlement", module_getter, "defeat_settlement_screen", "is_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.grip_style_selection", module_getter, "grip_style_selection_overlay", "is_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.skill_orb_tooltip_tutorial", module_getter, "skill_orb_tooltip_tutorial_hint", "blocks_battle_physics"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.character_info", module_getter, "character_info_overlay", "is_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.elixir_cinematic", module_getter, "active_item_runtime", "is_elixir_cinematic_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.lingpet_hatch_break", module_getter, "lingpet_egg_runtime", "is_hatch_break_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.lingpet_acquire_cutin", module_getter, "lingpet_egg_runtime", "is_acquire_cutin_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.lingpet_overflow_choice", module_getter, "lingpet_egg_runtime", "is_overflow_choice_active"):
		return true
	if _timed_module_bool(perf_logger, "physics.modal_gate.lingpet_guardian_enhance_cutin", module_getter, "lingpet_egg_runtime", "is_guardian_enhance_cutin_active"):
		return true
	return false


func _timed_module_bool(
	perf_logger: Object,
	label: String,
	module_getter: Callable,
	key: String,
	method_name: String
) -> bool:
	var sample_start: int = _perf_begin(perf_logger)
	var result: bool = _module_bool(module_getter, key, method_name)
	_perf_end(perf_logger, label, sample_start)
	return result


func _timed_bool(perf_logger: Object, label: String, callback: Callable) -> bool:
	var sample_start: int = _perf_begin(perf_logger)
	var result := false
	if callback.is_valid():
		result = bool(callback.call())
	_perf_end(perf_logger, label, sample_start)
	return result


func _module_bool(module_getter: Callable, key: String, method_name: String) -> bool:
	var module: Object = _get_module(module_getter, key)
	return module != null and module.has_method(method_name) and bool(module.call(method_name))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var callable_owner: Object = module_getter.get_object()
	if callable_owner != null and is_instance_valid(callable_owner):
		if callable_owner.has_method("_get_cached_module"):
			return _as_object(callable_owner.call("_get_cached_module", key))
		if callable_owner.has_method("get_cached_instance"):
			return _as_object(callable_owner.call("get_cached_instance", key))
	var value: Variant = module_getter.call(key)
	return _as_object(value)


func _as_object(value: Variant) -> Object:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
