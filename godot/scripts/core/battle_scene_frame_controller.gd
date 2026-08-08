extends RefCounted

const DriveCutinFxHost := preload("res://scripts/hud/drive_cutin_fx_host.gd")
const GameplayLoopAudioCleanup := preload("res://scripts/audio/gameplay_loop_audio_cleanup.gd")
const DRIVE_CUTIN_FX_HOST_NAME := "SmasherDriveCutinFxHost"
const RESULT_TEXTURE_PREWARM_SCOREBOARD_MIN_TIMER := 15.0 / 60.0

var _drive_cutin_fx_host: Node = null
var _drive_cutin_fx_host_add_pending := false
var _modal_active_item_cooldown_pause_active := false
var _online_match_runtime: Object = null


func process_idle(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary
) -> void:
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var online_runtime := _get_online_match_runtime(module_getter)
	if online_runtime != null and bool(online_runtime.process_idle(delta, owner, registry, module_getter, callbacks)):
		_perf_end(perf_logger, "process.frame.online_match", total_start)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return
	var sample_start: int = _perf_begin(perf_logger)
	_call(callbacks, "sync_mobile_touch_controls_enabled")
	_perf_end(perf_logger, "process.frame.sync_mobile_touch", sample_start)
	var match_event_driver: Object = _get_match_event_driver(module_getter)
	if _is_stage_transition_loading_active(match_event_driver):
		if match_event_driver.has_method("update_stage_transition_loading"):
			sample_start = _perf_begin(perf_logger)
			match_event_driver.update_stage_transition_loading(delta, owner, registry)
			_perf_end(perf_logger, "process.frame.stage_transition_loading", sample_start)
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return
	var intro_frame: Object = _get_intro_frame_controller(module_getter)
	if intro_frame != null and intro_frame.has_method("process_idle"):
		sample_start = _perf_begin(perf_logger)
		if bool(intro_frame.process_idle(delta, owner, registry, module_getter, callbacks)):
			_perf_end(perf_logger, "process.frame.intro", sample_start)
			_perf_end(perf_logger, "process.frame.total", total_start)
			return
		_perf_end(perf_logger, "process.frame.intro", sample_start)

	if _is_intro_or_warmup_blocking(module_getter, callbacks):
		_perf_end(perf_logger, "process.frame.total", total_start)
		return

	# The lingpet acquisition cut-in pauses battle physics via the modal gate, so
	# its reveal clock must advance from this ungated idle pump (not the gated
	# update driver) and keep the scene repainting while it holds for a click.
	var lingpet_acquire_runtime: Object = _get_module(module_getter, "lingpet_egg_runtime")
	# The shell-break sequence between the final egg hit and the cut-in pauses
	# battle physics the same way, so its clock is pumped here too. It runs
	# BEFORE the cut-in branch: the break's commit is what opens the cut-in.
	if (
		lingpet_acquire_runtime != null
		and lingpet_acquire_runtime.has_method("is_hatch_break_active")
		and bool(lingpet_acquire_runtime.is_hatch_break_active())
	):
		if lingpet_acquire_runtime.has_method("advance_hatch_break"):
			lingpet_acquire_runtime.advance_hatch_break(delta, owner, registry)
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return
	if (
		lingpet_acquire_runtime != null
		and lingpet_acquire_runtime.has_method("is_acquire_cutin_active")
		and bool(lingpet_acquire_runtime.is_acquire_cutin_active())
	):
		if lingpet_acquire_runtime.has_method("advance_acquire_cutin"):
			# Pass registry so the reveal can gate on the heavy Live2D sheet being cached
			# (and keep streaming it), instead of locking solid on the static 원화 first.
			lingpet_acquire_runtime.advance_acquire_cutin(delta, registry)
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return
	if (
		lingpet_acquire_runtime != null
		and lingpet_acquire_runtime.has_method("is_overflow_choice_active")
		and bool(lingpet_acquire_runtime.is_overflow_choice_active())
	):
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return
	if (
		lingpet_acquire_runtime != null
		and lingpet_acquire_runtime.has_method("is_guardian_enhance_cutin_active")
		and bool(lingpet_acquire_runtime.is_guardian_enhance_cutin_active())
	):
		if lingpet_acquire_runtime.has_method("advance_guardian_enhance_cutin"):
			lingpet_acquire_runtime.advance_guardian_enhance_cutin(delta, registry)
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return

	var grip_overlay: Object = _get_module(module_getter, "grip_style_selection_overlay")
	if grip_overlay != null and grip_overlay.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		var grip_redraw: bool = bool(grip_overlay.update(delta, owner, registry, module_getter))
		_perf_end(perf_logger, "process.frame.grip_style_selection", sample_start)
		if grip_redraw:
			_queue_redraw(owner)
		if grip_overlay.has_method("is_active") and bool(grip_overlay.is_active()):
			_perf_end(perf_logger, "process.frame.total", total_start)
			return

	var result_screen: Object = _get_stage_clear_result_screen(module_getter)
	if _is_stage_clear_result_active(result_screen):
		if result_screen.has_method("update"):
			sample_start = _perf_begin(perf_logger)
			result_screen.update(delta)
			_perf_end(perf_logger, "process.frame.result_screen", sample_start)
		if _is_runtime_perk_choice_active(module_getter):
			var runtime_perk_overlay_frame: Object = _get_overlay_frame_controller(module_getter)
			if runtime_perk_overlay_frame != null and runtime_perk_overlay_frame.has_method("process_idle"):
				sample_start = _perf_begin(perf_logger)
				runtime_perk_overlay_frame.process_idle(delta, owner, registry, module_getter)
				_perf_end(perf_logger, "process.frame.runtime_perk_overlay", sample_start)
			_queue_redraw(owner)
			_perf_end(perf_logger, "process.frame.total", total_start)
			return
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return

	var defeat_continue_screen: Object = _get_defeat_chance_gems_continue_screen(module_getter)
	if _is_defeat_chance_gems_continue_active(defeat_continue_screen):
		if defeat_continue_screen.has_method("update"):
			sample_start = _perf_begin(perf_logger)
			defeat_continue_screen.update(delta)
			_perf_end(perf_logger, "process.frame.defeat_chance_gems_continue", sample_start)
		_queue_redraw(owner)
		if _does_defeat_chance_gems_continue_block_battle(defeat_continue_screen):
			_perf_end(perf_logger, "process.frame.total", total_start)
			return

	var defeat_settlement_screen: Object = _get_defeat_settlement_screen(module_getter)
	if _is_defeat_settlement_active(defeat_settlement_screen):
		if defeat_settlement_screen.has_method("update"):
			sample_start = _perf_begin(perf_logger)
			defeat_settlement_screen.update(delta)
			_perf_end(perf_logger, "process.frame.defeat_settlement", sample_start)
		_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.total", total_start)
		return

	var overlay_frame: Object = _get_overlay_frame_controller(module_getter)
	if overlay_frame != null and overlay_frame.has_method("process_idle"):
		sample_start = _perf_begin(perf_logger)
		if bool(overlay_frame.process_idle(delta, owner, registry, module_getter)):
			_perf_end(perf_logger, "process.frame.overlay", sample_start)
			_perf_end(perf_logger, "process.frame.total", total_start)
			return
		_perf_end(perf_logger, "process.frame.overlay", sample_start)

	var update_driver: Object = _get_module(module_getter, "battle_scene_update_driver")
	if update_driver != null:
		sample_start = _perf_begin(perf_logger)
		update_driver.update_scoreboard_visuals(owner, registry, delta)
		_perf_end(perf_logger, "process.frame.scoreboard_visuals", sample_start)
	var junior_mika_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_mika_hint != null and junior_mika_hint.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(junior_mika_hint.update(delta, owner, registry)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.junior_mika_hint", sample_start)
	var skill_tooltip_hint: Object = _get_module(module_getter, "skill_orb_tooltip_tutorial_hint")
	if skill_tooltip_hint != null and skill_tooltip_hint.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(skill_tooltip_hint.update(delta, owner, registry, module_getter)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.skill_orb_tooltip_tutorial", sample_start)
	var commando_firearm_hint: Object = _get_module(module_getter, "commando_firearm_tutorial_hint")
	if commando_firearm_hint != null and commando_firearm_hint.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(commando_firearm_hint.update(delta, owner, registry, module_getter)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.commando_firearm_tutorial", sample_start)
	var viper_jetpack_hint: Object = _get_module(module_getter, "viper_jetpack_tutorial_hint")
	if viper_jetpack_hint != null and viper_jetpack_hint.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(viper_jetpack_hint.update(delta, owner, registry, module_getter)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.viper_jetpack_tutorial", sample_start)
	var viper_practice: Object = _get_module(module_getter, "viper_practice_mode")
	if viper_practice != null and viper_practice.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(viper_practice.update(delta, owner, registry, module_getter)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.viper_practice_mode", sample_start)
	var active_item_use_hint: Object = _get_module(module_getter, "active_item_use_tutorial_hint")
	if active_item_use_hint != null and active_item_use_hint.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(active_item_use_hint.update(delta, owner, registry, module_getter)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.active_item_use_tutorial", sample_start)
	var character_info_hint: Object = _get_module(module_getter, "character_info_tutorial_hint")
	if character_info_hint != null and character_info_hint.has_method("update"):
		sample_start = _perf_begin(perf_logger)
		if bool(character_info_hint.update(delta, owner, registry, module_getter)):
			_queue_redraw(owner)
		_perf_end(perf_logger, "process.frame.character_info_tutorial", sample_start)
	if _is_safe_result_prewarm_window(module_getter):
		_update_result_texture_prewarm(module_getter, perf_logger)
		if _is_stage_clear_result_prewarm_window(module_getter):
			_update_stage_clear_result_prewarm(owner, module_getter, perf_logger)
	# Manual render interpolation needs a fresh draw on render frames, not only
	# on 60 Hz physics frames.
	_queue_redraw(owner)
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	if scoreboard_state == null or not scoreboard_state.is_active():
		_perf_end(perf_logger, "process.frame.total", total_start)
		return
	if update_driver != null:
		sample_start = _perf_begin(perf_logger)
		update_driver.update_scoreboard_overlay(owner, registry, delta)
		_perf_end(perf_logger, "process.frame.scoreboard_overlay_update", sample_start)
	_perf_end(perf_logger, "process.frame.total", total_start)


func process_physics(
	delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary
) -> void:
	var total_start: int = Time.get_ticks_usec()
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	_perf_end(perf_logger, "physics.frame.perf_logger_lookup", total_start)
	var online_runtime := _get_online_match_runtime(module_getter)
	if online_runtime != null and bool(online_runtime.process_physics(delta, owner, registry, module_getter, callbacks)):
		_perf_end(perf_logger, "physics.frame.online_match", total_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	var sample_start: int = _perf_begin(perf_logger)
	if _is_logo_intro_active(module_getter):
		_perf_end(perf_logger, "physics.frame.gate.logo_intro", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.logo_intro", sample_start)

	sample_start = _perf_begin(perf_logger)
	if not _call_bool(callbacks, "is_battle_initialized"):
		_perf_end(perf_logger, "physics.frame.gate.battle_initialized", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.battle_initialized", sample_start)

	sample_start = _perf_begin(perf_logger)
	if not _is_boot_warmup_finished(module_getter):
		_perf_end(perf_logger, "physics.frame.gate.boot_warmup", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.boot_warmup", sample_start)

	sample_start = _perf_begin(perf_logger)
	if not _call_bool(callbacks, "is_stage_landing_intro_started"):
		_perf_end(perf_logger, "physics.frame.gate.stage_landing_started", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.stage_landing_started", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _is_stage_landing_intro_active(module_getter):
		_perf_end(perf_logger, "physics.frame.gate.stage_landing_intro", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.stage_landing_intro", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _is_ball_spawn_intro_active(module_getter):
		_perf_end(perf_logger, "physics.frame.gate.ball_spawn_intro", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.ball_spawn_intro", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _is_stage_transition_loading_active(_get_match_event_driver(module_getter)):
		_perf_end(perf_logger, "physics.frame.gate.stage_transition_loading", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.stage_transition_loading", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _is_stage_clear_result_active(_get_stage_clear_result_screen(module_getter)):
		_perf_end(perf_logger, "physics.frame.gate.stage_clear_result", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.stage_clear_result", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _does_defeat_chance_gems_continue_block_battle(_get_defeat_chance_gems_continue_screen(module_getter)):
		_perf_end(perf_logger, "physics.frame.gate.defeat_chance_gems_continue", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.defeat_chance_gems_continue", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _is_defeat_settlement_active(_get_defeat_settlement_screen(module_getter)):
		_perf_end(perf_logger, "physics.frame.gate.defeat_settlement", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.defeat_settlement", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _process_grip_selection_physics_gate(delta, owner, registry, module_getter):
		_perf_end(perf_logger, "physics.frame.gate.grip_style_selection", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.grip_style_selection", sample_start)

	sample_start = _perf_begin(perf_logger)
	if _should_block_battle_physics(module_getter, perf_logger):
		_pause_modal_active_item_cooldowns(owner, registry, module_getter)
		_stop_modal_blocked_gameplay_loop_audio(module_getter)
		_perf_end(perf_logger, "physics.frame.gate.modal_block", sample_start)
		_perf_end(perf_logger, "physics.frame.total", total_start)
		return
	_perf_end(perf_logger, "physics.frame.gate.modal_block", sample_start)
	_resume_modal_active_item_cooldowns(owner, registry, module_getter)

	sample_start = _perf_begin(perf_logger)
	var update_driver: Object = _get_module(module_getter, "battle_scene_update_driver")
	_perf_end(perf_logger, "physics.frame.update_driver_lookup", sample_start)
	if update_driver != null:
		sample_start = _perf_begin(perf_logger)
		update_driver.update(owner, registry, delta)
		_perf_end(perf_logger, "physics.frame.update_driver", sample_start)
	_perf_end(perf_logger, "physics.frame.total", total_start)


func draw(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	module_getter: Callable,
	callbacks: Dictionary
) -> void:
	var perf_logger: Object = _get_module(module_getter, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var view_size: Vector2 = _get_view_size(owner)
	var online_runtime := _get_online_match_runtime(module_getter)
	if online_runtime != null and bool(online_runtime.draw(canvas, registry, view_size, callbacks)):
		_perf_end(perf_logger, "draw.frame.online_match", total_start)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return
	var match_event_driver: Object = _get_match_event_driver(module_getter)
	if _is_stage_transition_loading_active(match_event_driver):
		if match_event_driver.has_method("draw_stage_transition_loading"):
			var transition_start: int = _perf_begin(perf_logger)
			if bool(match_event_driver.draw_stage_transition_loading(
				canvas,
				owner,
				registry,
				module_getter,
				view_size
			)):
				_perf_end(perf_logger, "draw.frame.stage_transition_loading", transition_start)
				_perf_end(perf_logger, "draw.frame.total", total_start)
				return
			_perf_end(perf_logger, "draw.frame.stage_transition_loading", transition_start)
		var black_start: int = _perf_begin(perf_logger)
		_draw_black(canvas, view_size)
		_perf_end(perf_logger, "draw.frame.black", black_start)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return

	var intro_frame: Object = _get_intro_frame_controller(module_getter)
	if intro_frame != null and intro_frame.has_method("draw_intro_or_boot"):
		var intro_start: int = _perf_begin(perf_logger)
		if bool(intro_frame.draw_intro_or_boot(canvas, owner, registry, module_getter, callbacks, view_size)):
			_perf_end(perf_logger, "draw.frame.intro_or_boot", intro_start)
			_perf_end(perf_logger, "draw.frame.total", total_start)
			return
		_perf_end(perf_logger, "draw.frame.intro_or_boot", intro_start)
	elif _is_intro_or_warmup_blocking(module_getter, callbacks):
		var black_start: int = _perf_begin(perf_logger)
		_draw_black(canvas, view_size)
		_perf_end(perf_logger, "draw.frame.black", black_start)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return

	var result_screen: Object = _get_stage_clear_result_screen(module_getter)
	if _is_stage_clear_result_active(result_screen):
		if result_screen.has_method("draw"):
			var result_start: int = _perf_begin(perf_logger)
			result_screen.draw(canvas, owner, registry, view_size)
			_perf_end(perf_logger, "draw.frame.result_screen", result_start)
		_draw_lingpet_acquire_cutin_if_active(canvas, registry, view_size, perf_logger)
		_draw_lingpet_overflow_choice_if_active(canvas, registry, view_size, perf_logger)
		_draw_lingpet_guardian_enhance_cutin_if_active(canvas, registry, view_size, perf_logger)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return

	var ball_spawn_overlay_active := (
		intro_frame != null
		and intro_frame.has_method("is_ball_spawn_overlay_active")
		and bool(intro_frame.is_ball_spawn_overlay_active(module_getter))
	)
	var should_restore_spawn_pillars := (
		ball_spawn_overlay_active
		and (
			not intro_frame.has_method("should_restore_ball_spawn_pillar_overlay")
			or bool(intro_frame.should_restore_ball_spawn_pillar_overlay(module_getter))
		)
	)
	var split_spawn_overlay_pass := (
		should_restore_spawn_pillars
		and _has_callback(callbacks, "draw_battle_pillar_overlay")
	)
	if split_spawn_overlay_pass:
		var battle_scene_start: int = _perf_begin(perf_logger)
		_call(callbacks, "draw_battle_scene")
		_perf_end(perf_logger, "draw.frame.battle_scene", battle_scene_start)
		if intro_frame != null and intro_frame.has_method("draw_ball_spawn_overlay"):
			var ball_spawn_start: int = _perf_begin(perf_logger)
			intro_frame.draw_ball_spawn_overlay(canvas, owner, registry, module_getter, view_size)
			_perf_end(perf_logger, "draw.frame.ball_spawn_overlay", ball_spawn_start)
		var pillar_start: int = _perf_begin(perf_logger)
		_call(callbacks, "draw_battle_pillar_overlay")
		_perf_end(perf_logger, "draw.frame.pillar_overlay", pillar_start)
	else:
		var battle_scene_start: int = _perf_begin(perf_logger)
		_call(callbacks, "draw_battle_scene")
		_perf_end(perf_logger, "draw.frame.battle_scene", battle_scene_start)
		if intro_frame != null and intro_frame.has_method("draw_ball_spawn_overlay"):
			var ball_spawn_start: int = _perf_begin(perf_logger)
			intro_frame.draw_ball_spawn_overlay(canvas, owner, registry, module_getter, view_size)
			_perf_end(perf_logger, "draw.frame.ball_spawn_overlay", ball_spawn_start)
	var mobile_touch_start: int = _perf_begin(perf_logger)
	_call(callbacks, "draw_mobile_touch_controls")
	_perf_end(perf_logger, "draw.frame.mobile_touch", mobile_touch_start)

	var grip_overlay: Object = _get_module(module_getter, "grip_style_selection_overlay")
	if grip_overlay != null and grip_overlay.has_method("is_active") and bool(grip_overlay.is_active()):
		var grip_start: int = _perf_begin(perf_logger)
		if grip_overlay.has_method("draw"):
			grip_overlay.draw(canvas, owner, view_size)
		_perf_end(perf_logger, "draw.frame.grip_style_selection", grip_start)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return

	var junior_mika_hint: Object = _get_module(module_getter, "junior_mika_tutorial_hint")
	if junior_mika_hint != null and junior_mika_hint.has_method("draw"):
		var hint_start: int = _perf_begin(perf_logger)
		junior_mika_hint.draw(canvas, owner, view_size)
		_perf_end(perf_logger, "draw.frame.junior_mika_hint", hint_start)

	var skill_tooltip_hint: Object = _get_module(module_getter, "skill_orb_tooltip_tutorial_hint")
	if skill_tooltip_hint != null and skill_tooltip_hint.has_method("draw"):
		var tooltip_hint_start: int = _perf_begin(perf_logger)
		skill_tooltip_hint.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.skill_orb_tooltip_tutorial", tooltip_hint_start)

	var commando_firearm_hint: Object = _get_module(module_getter, "commando_firearm_tutorial_hint")
	if commando_firearm_hint != null and commando_firearm_hint.has_method("draw"):
		var commando_firearm_hint_start: int = _perf_begin(perf_logger)
		commando_firearm_hint.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.commando_firearm_tutorial", commando_firearm_hint_start)

	var viper_jetpack_hint: Object = _get_module(module_getter, "viper_jetpack_tutorial_hint")
	if viper_jetpack_hint != null and viper_jetpack_hint.has_method("draw"):
		var viper_jetpack_hint_start: int = _perf_begin(perf_logger)
		viper_jetpack_hint.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.viper_jetpack_tutorial", viper_jetpack_hint_start)

	var viper_practice: Object = _get_module(module_getter, "viper_practice_mode")
	if viper_practice != null and viper_practice.has_method("draw"):
		var viper_practice_start: int = _perf_begin(perf_logger)
		viper_practice.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.viper_practice_mode", viper_practice_start)

	var active_item_use_hint: Object = _get_module(module_getter, "active_item_use_tutorial_hint")
	if active_item_use_hint != null and active_item_use_hint.has_method("draw"):
		var active_item_hint_start: int = _perf_begin(perf_logger)
		active_item_use_hint.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.active_item_use_tutorial", active_item_hint_start)

	var character_info_hint: Object = _get_module(module_getter, "character_info_tutorial_hint")
	if character_info_hint != null and character_info_hint.has_method("draw"):
		var character_info_hint_start: int = _perf_begin(perf_logger)
		character_info_hint.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.character_info_tutorial", character_info_hint_start)

	_draw_skill_cutin_if_active(canvas, registry, module_getter, view_size, perf_logger)
	_draw_drive_cutin_if_active(canvas, registry, module_getter, view_size, perf_logger)
	_draw_lingpet_acquire_cutin_if_active(canvas, registry, view_size, perf_logger)
	_draw_lingpet_overflow_choice_if_active(canvas, registry, view_size, perf_logger)
	_draw_lingpet_guardian_enhance_cutin_if_active(canvas, registry, view_size, perf_logger)

	var defeat_continue_screen: Object = _get_defeat_chance_gems_continue_screen(module_getter)
	if _is_defeat_chance_gems_continue_active(defeat_continue_screen):
		var defeat_continue_start: int = _perf_begin(perf_logger)
		if defeat_continue_screen.has_method("draw"):
			defeat_continue_screen.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.defeat_chance_gems_continue", defeat_continue_start)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return

	var defeat_settlement_screen: Object = _get_defeat_settlement_screen(module_getter)
	if _is_defeat_settlement_active(defeat_settlement_screen):
		var defeat_settlement_start: int = _perf_begin(perf_logger)
		if defeat_settlement_screen.has_method("draw"):
			defeat_settlement_screen.draw(canvas, owner, registry, view_size)
		_perf_end(perf_logger, "draw.frame.defeat_settlement", defeat_settlement_start)
		_perf_end(perf_logger, "draw.frame.total", total_start)
		return

	var overlay_frame: Object = _get_overlay_frame_controller(module_getter)
	if overlay_frame != null and overlay_frame.has_method("draw"):
		var overlay_start: int = _perf_begin(perf_logger)
		overlay_frame.draw(canvas, owner, registry, module_getter, view_size)
		_perf_end(perf_logger, "draw.frame.overlay", overlay_start)
	_perf_end(perf_logger, "draw.frame.total", total_start)


func _is_logo_intro_active(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_logo_intro_active")


func _is_boot_warmup_finished(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_boot_warmup_finished", true)


func _is_stage_landing_intro_active(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_stage_landing_intro_active")


func _is_ball_spawn_intro_active(module_getter: Callable) -> bool:
	return _call_readiness_bool(module_getter, "is_ball_spawn_intro_active")


func _is_intro_or_warmup_blocking(module_getter: Callable, callbacks: Dictionary) -> bool:
	var readiness: Object = _get_readiness_controller(module_getter)
	if readiness == null or not readiness.has_method("is_intro_or_warmup_blocking"):
		return true
	return bool(readiness.is_intro_or_warmup_blocking(
		module_getter,
		_call_bool(callbacks, "is_battle_initialized"),
		_call_bool(callbacks, "is_stage_landing_intro_started")
	))


func _process_grip_selection_physics_gate(
	_delta: float,
	owner: Object,
	registry: Object,
	module_getter: Callable
) -> bool:
	var grip_overlay: Object = _get_module(module_getter, "grip_style_selection_overlay")
	if grip_overlay == null or not grip_overlay.has_method("update"):
		return false
	if bool(grip_overlay.update(0.0, owner, registry, module_getter)):
		_queue_redraw(owner)
	return grip_overlay.has_method("is_active") and bool(grip_overlay.is_active())


func _draw_skill_cutin_if_active(
	canvas: CanvasItem,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	if registry == null or not registry.has_method("get_cached_instance"):
		return
	var cutin_state: Object = _get_active_skill_cutin_state(registry)
	if cutin_state == null:
		return
	var overlay_frame: Object = _get_overlay_frame_controller(module_getter)
	if overlay_frame != null and overlay_frame.has_method("has_blocking_activity"):
		if bool(overlay_frame.has_blocking_activity(module_getter)):
			return
	var cutin_host: Variant = registry.get_cached_instance("skill_cutin_overlay_host")
	if typeof(cutin_host) != TYPE_OBJECT or cutin_host == null:
		return
	var cutin_start: int = _perf_begin(perf_logger)
	cutin_host.draw(canvas, cutin_state, view_size)
	_perf_end(perf_logger, "draw.frame.skill_cutin", cutin_start)


func _get_active_skill_cutin_state(registry: Object) -> Object:
	for module_key in ["smasher_power_smash_state", "viper_skill_runtime"]:
		var module: Variant = registry.get_cached_instance(module_key)
		if typeof(module) != TYPE_OBJECT or module == null:
			continue
		if not module.has_method("is_cutin_active") or not bool(module.is_cutin_active()):
			continue
		var state: Variant = module.get("cutin_state")
		if typeof(state) == TYPE_OBJECT and state != null:
			return state
	return null


func _draw_drive_cutin_if_active(
	canvas: CanvasItem,
	registry: Object,
	module_getter: Callable,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	if registry == null or not registry.has_method("get_cached_instance"):
		return
	var power_state: Variant = registry.get_cached_instance("smasher_power_smash_state")
	var has_power_state: bool = typeof(power_state) == TYPE_OBJECT and power_state != null
	var shield_state: Variant = registry.get_cached_instance("smasher_shield_kiting_state")
	var has_shield_state: bool = typeof(shield_state) == TYPE_OBJECT and shield_state != null
	if not has_power_state and not has_shield_state:
		return
	var drive_active: bool = (
		has_power_state
		and power_state.has_method("is_drive_cutin_active")
		and bool(power_state.is_drive_cutin_active())
	)
	var shield_cutin_state: Object = null
	if has_shield_state:
		var shield_cutin_value: Variant = shield_state.get("cutin_state")
		if typeof(shield_cutin_value) == TYPE_OBJECT and shield_cutin_value != null:
			shield_cutin_state = shield_cutin_value
	var shield_active: bool = (
		shield_cutin_state != null
		and shield_cutin_state.has_method("is_active")
		and bool(shield_cutin_state.is_active())
	)
	var blocking: bool = false
	var overlay_frame: Object = _get_overlay_frame_controller(module_getter)
	if overlay_frame != null and overlay_frame.has_method("has_blocking_activity"):
		blocking = bool(overlay_frame.has_blocking_activity(module_getter))
	var draw_drive_now: bool = drive_active and not blocking
	var draw_shield_now: bool = (not draw_drive_now) and shield_active and not blocking
	var draw_now: bool = draw_drive_now or draw_shield_now

	var cutin_host: Variant = registry.get_cached_instance("skill_cutin_overlay_host")
	var has_cutin_host: bool = typeof(cutin_host) == TYPE_OBJECT and cutin_host != null

	# Immediate-mode pieces (triangle/backplate/arc behind, portrait or symbol +
	# title) draw in the shell's _draw so the ADD-light pieces layer correctly
	# behind the MIX-blend subject.
	if draw_drive_now and has_cutin_host and cutin_host.has_method("draw_drive_cutin"):
		var drive_start: int = _perf_begin(perf_logger)
		cutin_host.draw_drive_cutin(canvas, power_state.drive_cutin_state, view_size)
		_perf_end(perf_logger, "draw.frame.drive_cutin", drive_start)
	elif draw_shield_now and has_cutin_host and cutin_host.has_method("draw_shield_kiting_cutin"):
		var shield_start: int = _perf_begin(perf_logger)
		cutin_host.draw_shield_kiting_cutin(canvas, shield_cutin_state, shield_state, view_size)
		_perf_end(perf_logger, "draw.frame.shield_kiting_cutin", shield_start)

	# Particle layer node (piece 3), rendered IN FRONT of the portrait. Sync every
	# reachable frame so it hides (single cleanup) the moment the cut-in ends or a
	# blocking overlay opens; the host also self-times-out if sync stops. slide_px
	# is shared with the immediate-mode pieces so the whole cut-in slides as one
	# (enter from the left, exit back to the left).
	var fx_host: Node = _get_or_create_drive_cutin_fx_host(canvas, draw_now)
	if fx_host != null and fx_host.has_method("sync_state"):
		var partial_state: Object = null
		if draw_drive_now and has_power_state:
			partial_state = power_state.drive_cutin_state
		elif draw_shield_now:
			partial_state = shield_cutin_state
		var progress: float = partial_state.get_progress() if partial_state != null and partial_state.has_method("get_progress") else 0.0
		var slide_px: float = 0.0
		if draw_shield_now and has_cutin_host and cutin_host.has_method("compute_shield_kiting_slide_px"):
			slide_px = float(cutin_host.compute_shield_kiting_slide_px(progress, view_size.x))
		elif has_cutin_host and cutin_host.has_method("compute_drive_slide_px"):
			slide_px = float(cutin_host.compute_drive_slide_px(progress, view_size.x))
		# Combo-charged drive => enraged particle tint (brighter cyan-white). The
		# immediate-mode backplate/arc read the same flag straight off drive_cutin_state.
		var enraged: bool = (
			draw_drive_now
			and has_power_state
			and power_state.has_method("is_drive_cutin_enraged")
			and bool(power_state.is_drive_cutin_enraged())
		)
		var fx_start: int = _perf_begin(perf_logger)
		fx_host.sync_state({
			"view_size": view_size,
			"progress": progress,
			"slide_px": slide_px,
			"enraged": enraged,
			"quality_scale": 1.0,
		}, draw_now)
		_perf_end(perf_logger, "draw.frame.drive_cutin_fx_sync", fx_start)


func _get_or_create_drive_cutin_fx_host(canvas: CanvasItem, allow_create: bool) -> Node:
	if _is_valid_drive_cutin_fx_host(_drive_cutin_fx_host):
		return _drive_cutin_fx_host
	if not allow_create or not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null(DRIVE_CUTIN_FX_HOST_NAME)
	if _is_valid_drive_cutin_fx_host(existing):
		_drive_cutin_fx_host = existing
		_drive_cutin_fx_host_add_pending = false
		return _drive_cutin_fx_host
	_drive_cutin_fx_host = DriveCutinFxHost.new()
	_drive_cutin_fx_host.name = DRIVE_CUTIN_FX_HOST_NAME
	_drive_cutin_fx_host.visible = false
	if not _drive_cutin_fx_host_add_pending:
		_drive_cutin_fx_host_add_pending = true
		parent.call_deferred("add_child", _drive_cutin_fx_host)
	return _drive_cutin_fx_host


func _is_valid_drive_cutin_fx_host(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


func _draw_lingpet_acquire_cutin_if_active(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	if registry == null:
		return
	# The lingpet runtime is instantiated + cached earlier this frame by the
	# playfield scene drawer in normal battle draws. Result-screen and freshly
	# opened F7 debug paths may skip that drawer, so fall back to get_instance().
	var runtime: Variant = null
	if registry.has_method("get_cached_instance"):
		runtime = registry.get_cached_instance("lingpet_egg_runtime")
	if (typeof(runtime) != TYPE_OBJECT or runtime == null) and registry.has_method("get_instance"):
		runtime = registry.get_instance("lingpet_egg_runtime")
	if typeof(runtime) != TYPE_OBJECT or runtime == null:
		return
	if not runtime.has_method("is_acquire_cutin_active") or not bool(runtime.is_acquire_cutin_active()):
		return
	var host: Variant = null
	if registry.has_method("get_cached_instance"):
		host = registry.get_cached_instance("lingpet_acquire_cutin_overlay_host")
	if (typeof(host) != TYPE_OBJECT or host == null) and registry.has_method("get_instance"):
		host = registry.get_instance("lingpet_acquire_cutin_overlay_host")
	if typeof(host) != TYPE_OBJECT or host == null:
		return
	var start: int = _perf_begin(perf_logger)
	host.draw(canvas, runtime, view_size)
	_perf_end(perf_logger, "draw.frame.lingpet_acquire_cutin", start)


func _draw_lingpet_overflow_choice_if_active(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	if registry == null:
		return
	var runtime: Variant = null
	if registry.has_method("get_cached_instance"):
		runtime = registry.get_cached_instance("lingpet_egg_runtime")
	if (typeof(runtime) != TYPE_OBJECT or runtime == null) and registry.has_method("get_instance"):
		runtime = registry.get_instance("lingpet_egg_runtime")
	if typeof(runtime) != TYPE_OBJECT or runtime == null:
		return
	if not runtime.has_method("is_overflow_choice_active") or not bool(runtime.is_overflow_choice_active()):
		return
	var host: Variant = null
	if registry.has_method("get_cached_instance"):
		host = registry.get_cached_instance("lingpet_overflow_choice_overlay_host")
	if (typeof(host) != TYPE_OBJECT or host == null) and registry.has_method("get_instance"):
		host = registry.get_instance("lingpet_overflow_choice_overlay_host")
	if typeof(host) != TYPE_OBJECT or host == null or not host.has_method("draw"):
		return
	var start: int = _perf_begin(perf_logger)
	host.draw(canvas, runtime, view_size)
	_perf_end(perf_logger, "draw.frame.lingpet_overflow_choice", start)


func _draw_lingpet_guardian_enhance_cutin_if_active(
	canvas: CanvasItem,
	registry: Object,
	view_size: Vector2,
	perf_logger: Object
) -> void:
	if registry == null:
		return
	var runtime: Variant = null
	if registry.has_method("get_cached_instance"):
		runtime = registry.get_cached_instance("lingpet_egg_runtime")
	if (typeof(runtime) != TYPE_OBJECT or runtime == null) and registry.has_method("get_instance"):
		runtime = registry.get_instance("lingpet_egg_runtime")
	if typeof(runtime) != TYPE_OBJECT or runtime == null:
		return
	if not runtime.has_method("is_guardian_enhance_cutin_active") or not bool(runtime.is_guardian_enhance_cutin_active()):
		return
	var host: Variant = null
	if registry.has_method("get_cached_instance"):
		host = registry.get_cached_instance("lingpet_guardian_enhance_cutin_overlay_host")
	if (typeof(host) != TYPE_OBJECT or host == null) and registry.has_method("get_instance"):
		host = registry.get_instance("lingpet_guardian_enhance_cutin_overlay_host")
	if typeof(host) != TYPE_OBJECT or host == null or not host.has_method("draw"):
		return
	var start: int = _perf_begin(perf_logger)
	host.draw(canvas, runtime, view_size)
	_perf_end(perf_logger, "draw.frame.lingpet_guardian_enhance_cutin", start)


func _get_readiness_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_readiness_controller")


func _get_intro_frame_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_intro_frame_controller")


func _get_overlay_frame_controller(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_overlay_frame_controller")


func _get_match_event_driver(module_getter: Callable) -> Object:
	return _get_module(module_getter, "battle_scene_match_event_driver")


func _get_stage_clear_result_screen(module_getter: Callable) -> Object:
	return _get_module(module_getter, "stage_clear_result_screen")


func _get_defeat_chance_gems_continue_screen(module_getter: Callable) -> Object:
	return _get_module(module_getter, "defeat_chance_gems_continue_screen")


func _get_defeat_settlement_screen(module_getter: Callable) -> Object:
	return _get_module(module_getter, "defeat_settlement_screen")


func _is_stage_clear_result_active(result_screen: Object) -> bool:
	return result_screen != null and result_screen.has_method("is_active") and bool(result_screen.is_active())


func _is_defeat_chance_gems_continue_active(screen: Object) -> bool:
	return screen != null and screen.has_method("is_active") and bool(screen.is_active())


func _does_defeat_chance_gems_continue_block_battle(screen: Object) -> bool:
	if screen == null:
		return false
	if screen.has_method("blocks_battle_physics"):
		return bool(screen.blocks_battle_physics())
	return _is_defeat_chance_gems_continue_active(screen)


func _is_defeat_settlement_active(screen: Object) -> bool:
	return screen != null and screen.has_method("is_active") and bool(screen.is_active())


func _is_runtime_perk_choice_active(module_getter: Callable) -> bool:
	return _call_modal_gate_bool(module_getter, "is_runtime_perk_choice_active")


func _is_safe_result_prewarm_window(module_getter: Callable) -> bool:
	# Result sheets can finish a threaded load with a large one-frame upload;
	# keep that work inside the score pause, away from live rallies and serve input.
	# The first scoreboard frame must appear before fallback round-result prewarm
	# starts, otherwise first-use texture work can look like a pre-scoreboard hitch.
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	return (
		scoreboard_state != null
		and scoreboard_state.has_method("is_active")
		and bool(scoreboard_state.is_active())
		and _has_visible_scoreboard_frame(scoreboard_state)
	)


func _has_visible_scoreboard_frame(scoreboard_state: Object) -> bool:
	if scoreboard_state == null or not scoreboard_state.has_method("get_timer"):
		return true
	return float(scoreboard_state.get_timer()) >= RESULT_TEXTURE_PREWARM_SCOREBOARD_MIN_TIMER


func _is_stage_clear_result_prewarm_window(module_getter: Callable) -> bool:
	var scoreboard_state: Object = _get_module(module_getter, "scoreboard_state")
	if (
		scoreboard_state == null
		or not scoreboard_state.has_method("is_active")
		or not bool(scoreboard_state.is_active())
	):
		return false
	if scoreboard_state.has_method("has_pending_game_reset") and not bool(scoreboard_state.has_pending_game_reset()):
		return false
	return _scoreboard_snapshot_is_player_match_win(scoreboard_state)


func _scoreboard_snapshot_is_player_match_win(scoreboard_state: Object) -> bool:
	if (
		scoreboard_state == null
		or not scoreboard_state.has_method("get_player_points")
		or not scoreboard_state.has_method("get_boss_points")
	):
		return false
	var player_points: int = int(scoreboard_state.get_player_points())
	var boss_points: int = int(scoreboard_state.get_boss_points())
	if scoreboard_state.has_method("get_win_goal"):
		var win_goal: int = max(1, int(scoreboard_state.get_win_goal()))
		return player_points >= win_goal and player_points > boss_points
	return player_points > boss_points


func _is_stage_transition_loading_active(match_event_driver: Object) -> bool:
	return (
		match_event_driver != null
		and match_event_driver.has_method("is_stage_transition_loading_active")
		and bool(match_event_driver.is_stage_transition_loading_active())
	)


func _update_result_texture_prewarm(module_getter: Callable, perf_logger: Object) -> void:
	var resources: Object = _get_module(module_getter, "battle_resources")
	if resources == null or not resources.has_method("update_result_texture_prewarm"):
		return
	if resources.has_method("has_result_texture_prewarm_work") and not bool(resources.has_result_texture_prewarm_work()):
		return
	var sample_start: int = _perf_begin(perf_logger)
	resources.update_result_texture_prewarm()
	_perf_end(perf_logger, "process.frame.result_texture_prewarm", sample_start)


func _update_stage_clear_result_prewarm(owner: Object, module_getter: Callable, perf_logger: Object) -> void:
	var result_screen: Object = _get_stage_clear_result_screen(module_getter)
	if _is_stage_clear_result_active(result_screen):
		return
	var prewarm_controller: Object = _get_module(module_getter, "battle_boot_resource_prewarm_controller")
	if prewarm_controller == null or not prewarm_controller.has_method("prewarm_stage_clear_result_resources_step"):
		return
	if (
		prewarm_controller.has_method("has_stage_clear_result_resource_prewarm_work")
		and not bool(prewarm_controller.has_stage_clear_result_resource_prewarm_work(owner))
	):
		return
	var sample_start: int = _perf_begin(perf_logger)
	prewarm_controller.prewarm_stage_clear_result_resources_step(module_getter, owner)
	_perf_end(perf_logger, "process.frame.stage_clear_result_prewarm", sample_start)


func _call_readiness_bool(module_getter: Callable, method_name: String, fallback: bool = false) -> bool:
	var readiness: Object = _get_readiness_controller(module_getter)
	if readiness == null or not readiness.has_method(method_name):
		return fallback
	return bool(readiness.call(method_name, module_getter))


func _should_block_battle_physics(module_getter: Callable, perf_logger: Object = null) -> bool:
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate == null:
		return false
	if modal_gate.has_method("should_block_battle_physics_with_perf"):
		return bool(modal_gate.should_block_battle_physics_with_perf(module_getter, perf_logger))
	if modal_gate.has_method("should_block_battle_physics"):
		return bool(modal_gate.should_block_battle_physics(module_getter))
	return false


func _pause_modal_active_item_cooldowns(owner: Object, registry: Object, module_getter: Callable) -> void:
	if _modal_active_item_cooldown_pause_active:
		return
	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("pause_cooldowns"):
		return
	active_item_runtime.pause_cooldowns(owner, registry)
	_modal_active_item_cooldown_pause_active = true


func _stop_modal_blocked_gameplay_loop_audio(module_getter: Callable) -> void:
	# Physics-blocking modals (character info via TAB, pause menu, debug pickers)
	# return here BEFORE the update driver runs, so update_effects -- the only
	# place that syncs / stops gameplay loop audio -- never fires while the modal
	# is open. Any loop still playing when the modal opened would otherwise drone
	# or repeat for the whole modal: the dash-delay 후딜 loop (force-looped in
	# game_audio._enable_loop) is the common trigger (dash then TAB), but warp
	# gate, magnum grip, plasma, and chaos blackhole share the trap. Stop them
	# here; update_effects re-syncs any still-active loop on the frame physics
	# resumes, so a recovery that is still in progress simply resumes its sound.
	var audio: Object = _get_module(module_getter, "game_audio")
	if audio != null:
		GameplayLoopAudioCleanup.stop_all(audio)


func _resume_modal_active_item_cooldowns(owner: Object, registry: Object, module_getter: Callable) -> void:
	if not _modal_active_item_cooldown_pause_active:
		return
	_modal_active_item_cooldown_pause_active = false
	var active_item_runtime: Object = _get_module(module_getter, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("resume_cooldowns"):
		active_item_runtime.resume_cooldowns(owner, registry)


func _call_modal_gate_bool(module_getter: Callable, method_name: String, fallback: bool = false) -> bool:
	var modal_gate: Object = _get_module(module_getter, "battle_scene_modal_gate_controller")
	if modal_gate == null or not modal_gate.has_method(method_name):
		return fallback
	return bool(modal_gate.call(method_name, module_getter))


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _get_online_match_runtime(module_getter: Callable) -> Object:
	if _online_match_runtime != null and is_instance_valid(_online_match_runtime):
		return _online_match_runtime
	if not _has_pending_online_match_request():
		return null
	_online_match_runtime = _get_module(module_getter, "online_match_runtime")
	return _online_match_runtime


func _has_pending_online_match_request() -> bool:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return false
	var root: Window = (main_loop as SceneTree).root
	if root == null:
		return false
	var selection_state: Node = root.get_node_or_null("GameSelectionState")
	return (
		selection_state != null
		and selection_state.has_method("has_pending_online_match_request")
		and bool(selection_state.has_pending_online_match_request())
	)


func _call(callbacks: Dictionary, key: String) -> void:
	var callback: Callable = callbacks.get(key, Callable())
	if callback.is_valid():
		callback.call()


func _has_callback(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	return callback.is_valid()


func _call_bool(callbacks: Dictionary, key: String) -> bool:
	var callback: Callable = callbacks.get(key, Callable())
	if not callback.is_valid():
		return false
	return bool(callback.call())


func _draw_black(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas != null:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color.BLACK)


func _queue_redraw(owner: Object) -> void:
	if owner == null:
		return
	if owner.has_method("request_battle_redraw"):
		owner.request_battle_redraw()
	elif owner.has_method("queue_redraw"):
		owner.queue_redraw()


func _get_view_size(owner: Object) -> Vector2:
	if owner != null and owner.has_method("get_viewport_rect"):
		return owner.get_viewport_rect().size
	return Vector2.ZERO


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
