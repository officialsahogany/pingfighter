extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")
const LingpetCompanionClickReactionState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetCompanionSkillController := preload("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
const LingpetCompanionStrikeAnticipator := preload("res://scripts/lingpet/lingpet_companion_strike_anticipator.gd")
const LingpetCompanionSwitchState := preload("res://scripts/lingpet/lingpet_companion_switch_state.gd")
const LingpetEggFieldState := preload("res://scripts/lingpet/lingpet_egg_field_state.gd")
const LingpetEggFieldRenderer := preload("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
const LingpetRuntimeSnapshotBuilder := preload("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
const LingpetSaveRestorePlanner := preload("res://scripts/lingpet/lingpet_save_restore_planner.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
# Lingpet field/cutin/companion visuals are resolved through LingpetCurrentProfile,
# which routes every visual key through the catalog-backed visual texture cache.

const PET_ID := LingpetCurrentProfile.DEFAULT_PET_ID
const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"
const REQUIRED_HITS := 2
const BALL_RADIUS_FALLBACK := 14.3
const SAVE_SNAPSHOT_VERSION := 1
const COMPANION_RADIUS := 16.0
# Anticipatory strike helper mirrors player/boss _maybe_trigger_anticipated_hit:
# the swing is started BEFORE the ball arrives by predicting time-to-contact and
# choosing an entry frame so the spear-thrust APEX lands at contact -- exactly
# how the other characters' attack sheets fire. The sheet's first ~8 cells (0-7)
# are dead-air, the wind-up/coil is ~8-19, the thrust apex is ~22 (held 22-23),
# recovery ~24. A far ball enters near START_FRAME (full wind-up shown ahead of
# contact); a close ball enters deeper so the apex still lands on the ball. The
# real overlap bounce stays the gameplay trigger + a reactive fallback if the
# prediction missed. Tunables: FRAME_TIME (swing speed; higher = slower/weighty),
# START_FRAME (how much wind-up), MAX_GAP/X_TOLERANCE (how eagerly it predicts).
const COMPANION_PATROL_SPEED := 120.0
const COMPANION_PATROL_SPEED_MIN := 70.0
const COMPANION_PATROL_SPEED_MAX := 135.0
const COMPANION_DEFENSE_RATE := 0.30
# Paddle-like hit footprint: a wide axis-aligned box centered on the companion,
# so it catches the ball over a ~100px horizontal span like a mini player paddle
# (replacing the old 44px circle). Ball radius is added per-axis (paddle parity).
const COMPANION_HIT_HALF_WIDTH := 50.0   # -> ~100px wide catch footprint
const COMPANION_HIT_HALF_HEIGHT := 22.0  # vertical reach (≈ the old circle radius)
# Ball-hit reflection: launch toward the boss exactly like a player paddle.
# hit_pos (horizontal offset on the companion) maps to the launch angle via
# Vector2(0,-1).rotated(hit_pos * max_angle), matching MAX_BOUNCE_ANGLE so the
# physics is identical to a player paddle bounce. Speed preserves the incoming
# ball speed (paddle parity, no soft slowdown).
const COMPANION_HIT_GAUGE_GAIN := 40.0
const COMPANION_SKILL_COOLDOWN_SECONDS := 40.0
const COMPANION_SKILL_FLASH_SECONDS := 0.45
# Telegraphed spear-throw wind-up: when the skill arms, Maribo cocks the spear
# back for this long BEFORE the hydro projectile actually launches. The cooldown
# is set at LAUNCH (not arm), so the wind-up reads as a clear "about to throw"
# tell rather than eating into the displayed cooldown. Patrol freezes during it.
const COMPANION_SKILL_WINDUP_SECONDS := 1.0
const COMPANION_SKILL_BURST_PARTICLES := 8
const COMPANION_SWITCH_TRANSITION_SECONDS := 0.62
const COMPANION_SWITCH_TRANSITION_PARTICLES := 12
# Click-reaction popup timing, hit zone, draw math, and prewarm keys live in
# LingpetCompanionClickReactionState. The runtime only exposes the public
# battle-input API and feeds the current pet texture into the state renderer.
# Fullscreen acquisition cut-in state lives in LingpetAcquireCutinState. The
# runtime keeps the public API because modal/input/draw controllers call it.
# The HUD host owns the artwork and restoration / exit-action rendering.

var _state := STATE_NONE
var _pet_id := PET_ID
var _egg_state: Object = LingpetEggFieldState.new()
var _egg_renderer: Object = LingpetEggFieldRenderer.new()
var _companion_pos := Vector2.ZERO
var _companion_motion_state: Object = LingpetCompanionMotionState.new()
var _hatch_flash_timer := 0.0
var _companion_body_hit_state: Object = LingpetCompanionBodyHitState.new()
var _collection_state: Object = LingpetCollectionState.new()
var _current_profile: Object = LingpetCurrentProfile.new()
var _companion_draw_context_builder: Object = LingpetCompanionDrawContextBuilder.new()
var _companion_renderer: Object = LingpetCompanionRenderer.new()
var _companion_sprite_animator: Object = LingpetCompanionSpriteAnimator.new()
var _companion_strike_anticipator: Object = LingpetCompanionStrikeAnticipator.new()
var _companion_skill_state: Object = LingpetCompanionSkillState.new()
var _companion_skill_controller: Object = LingpetCompanionSkillController.new()
var _skill_runtime_host: Object = LingpetSkillRuntimeHost.new()
var _snapshot_builder: Object = LingpetRuntimeSnapshotBuilder.new()
var _save_restore_planner: Object = LingpetSaveRestorePlanner.new()
var _acquire_cutin_state: Object = LingpetAcquireCutinState.new()
var _switch_transition_state: Object = LingpetCompanionSwitchState.new()
var _companion_click_reaction_state: Object = LingpetCompanionClickReactionState.new()
var _companion_skill_state_by_pet_id: Dictionary = {}
var _has_synced_none := false


func update(delta: float, owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	_switch_transition_state.advance(delta)
	_egg_state.advance(delta)
	_companion_body_hit_state.advance(delta)
	_companion_skill_state.advance(delta)
	_hatch_flash_timer = maxf(0.0, _hatch_flash_timer - maxf(0.0, delta))
	_companion_sprite_animator.advance(delta)
	_companion_click_reaction_state.advance(delta)

	if _state == STATE_NONE:
		var owned_pet_id := _find_active_slot_pet_id(owner)
		if owned_pet_id != "":
			_adopt_owned_pet(owner, owned_pet_id)
			return true
		if _should_spawn_lingpet_egg(owner):
			_spawn_egg(owner)
			return true
		if not _has_synced_none:
			_sync_owner(owner)
			_has_synced_none = true
			return false
		return false

	if _state == STATE_EGG:
		_egg_state.update_player_contact(delta, owner)
		var changed: bool = _resolve_ball_hit(owner)
		_sync_owner(owner)
		return changed

	if _state == STATE_COMPANION:
		_update_companion_motion(delta, owner)
		_maybe_arm_companion_strike(owner)
		_resolve_companion_ball_hit(owner, registry)
		_update_companion_skill_effects(delta, owner, registry)
		_sync_owner(owner)
	return false


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO, _draw_context: Dictionary = {}) -> void:
	if canvas == null:
		return
	if _state == STATE_EGG:
		_draw_egg(canvas, _egg_state.pos + shake_offset)
	elif _state == STATE_COMPANION:
		_skill_runtime_host.draw(canvas, shake_offset)
		_draw_companion(canvas, _companion_pos + shake_offset)
		if _companion_click_reaction_state.is_active():
			_companion_click_reaction_state.draw(
				canvas,
				_companion_pos + shake_offset,
				_get_current_visual_texture("click_reaction_anim", null)
			)
		if _hatch_flash_timer > 0.0:
			_draw_hatch_flash(canvas, _egg_state.pos + shake_offset)


func has_visible_effects() -> bool:
	return (
		_state == STATE_EGG
		or _state == STATE_COMPANION
		or _hatch_flash_timer > 0.0
		or _acquire_cutin_state.active
		or _skill_runtime_host.has_visible_effects()
	)


func is_acquire_cutin_active() -> bool:
	return _acquire_cutin_state.active


# Advanced from the ungated idle pump (process_idle), so the reveal AND the exit
# action keep animating while the gated update driver is paused by the modal gate.
func advance_acquire_cutin(delta: float) -> void:
	_acquire_cutin_state.advance(delta)


func get_acquire_cutin_progress() -> float:
	return _acquire_cutin_state.get_progress()


# The reveal has finished playing and the cut-in is holding for a click/confirm.
# Excludes the dismissing phase so a click cannot re-trigger the exit action once
# it has started. Input is swallowed before this point so an early click cannot
# skip the reveal or leak into gameplay.
func is_acquire_cutin_awaiting_dismiss() -> bool:
	return _acquire_cutin_state.is_awaiting_dismiss()


# Begin the animated exit action (does NOT close immediately). The cut-in stays
# active (gameplay paused) until advance_acquire_cutin finishes the action+fade.
func begin_acquire_cutin_dismiss() -> bool:
	return _acquire_cutin_state.begin_dismiss()


func is_acquire_cutin_dismissing() -> bool:
	return _acquire_cutin_state.is_dismissing()


func get_acquire_cutin_dismiss_progress() -> float:
	return _acquire_cutin_state.get_dismiss_progress()


# Immediate hard close (cleanup / state-reset paths). The click handler uses
# begin_acquire_cutin_dismiss() instead so players see the exit action.
func dismiss_acquire_cutin() -> bool:
	return _acquire_cutin_state.dismiss_immediate()


func is_maribo_companion_active() -> bool:
	return _pet_id == PET_ID and _state == STATE_COMPANION


func is_companion_active(pet_id: String = "") -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	return _state == STATE_COMPANION and (normalized_pet_id == "" or _pet_id == normalized_pet_id)


func debug_grant_and_activate_pet(pet_id: String, owner: Object = null, show_acquire_cutin: bool = false) -> bool:
	var normalized_pet_id := _normalize_pet_id(pet_id)
	if normalized_pet_id == "":
		return false
	_save_current_companion_skill_state()
	_state = STATE_COMPANION
	_set_current_pet_id(normalized_pet_id)
	_egg_state.set_hatched(_get_current_required_hits())
	_companion_pos = Vector2.ZERO
	_reset_companion_runtime_state()
	_restore_current_companion_skill_state()
	_switch_transition_state.reset()
	_hatch_flash_timer = 0.0
	_acquire_cutin_state.reset()
	_prewarm_current_visuals()
	if owner != null:
		var owner_slots: Array[String] = _collection_state.get_battle_slots_from_owner(owner)
		_collection_state.set_battle_slots(owner_slots)
		_collection_state.set_active_slot_index(_collection_state.get_active_slot_index_from_owner(owner))
	_mark_current_pet_owned(owner)
	var slots: Array[String] = _collection_state.get_battle_slots()
	var slot_index: int = slots.find(normalized_pet_id)
	if slot_index >= 0:
		_collection_state.select_active_slot(slot_index, owner)
	else:
		var active_slot_index: int = _collection_state.get_active_slot_index()
		if active_slot_index >= 0 and active_slot_index < slots.size():
			slots[active_slot_index] = normalized_pet_id
			_collection_state.set_battle_slots(slots)
			_collection_state.set_active_slot_index(active_slot_index)
	_initialize_companion_patrol(owner, true)
	if show_acquire_cutin:
		_acquire_cutin_state.start()
	_sync_owner(owner)
	return true


func get_lingpet_slots() -> Array[String]:
	return _collection_state.get_battle_slots()


func get_active_lingpet_slot_index() -> int:
	return _collection_state.get_active_slot_index()


func _set_current_pet_id(value: String) -> void:
	_pet_id = _current_profile.set_pet_id(value, PET_ID)


func switch_lingpet_slot(slot_index: int, owner: Object = null) -> bool:
	_save_current_companion_skill_state()
	var next_pet_id: String = _collection_state.select_active_slot(slot_index, owner)
	if next_pet_id == "":
		return false
	if _state != STATE_COMPANION:
		_adopt_owned_pet(owner, next_pet_id)
		return true
	if next_pet_id == _pet_id:
		_sync_owner(owner)
		return true
	_switch_transition_state.begin(_pet_id, next_pet_id, COMPANION_SWITCH_TRANSITION_SECONDS)
	_set_current_pet_id(next_pet_id)
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	_reset_companion_runtime_state()
	_restore_current_companion_skill_state()
	_prewarm_current_visuals()
	_mark_current_pet_owned(owner)
	_sync_owner(owner)
	return true


func cycle_lingpet_slot(direction: int = 1, owner: Object = null) -> bool:
	var next_slot_index: int = _collection_state.find_next_occupied_slot_index(direction, owner)
	if next_slot_index < 0:
		return false
	if next_slot_index == _collection_state.get_active_slot_index_from_owner(owner):
		return false
	return switch_lingpet_slot(next_slot_index, owner)


# Test-only accessors: the strike state is transient visual state that is
# intentionally NOT persisted in get_snapshot()/save schema, so the smoke reads
# it directly to assert the anticipatory pre-contact timing.
func is_companion_striking_for_tests() -> bool:
	return _companion_sprite_animator.strike_active


func get_companion_strike_frame_for_tests() -> int:
	return _companion_sprite_animator.get_strike_frame()


func get_hydro_puddle_particle_count_for_tests() -> int:
	return _skill_runtime_host.get_hydro_puddle_particle_count_for_tests()


func get_headbutt_hit_count_for_tests() -> int:
	return _skill_runtime_host.get_headbutt_hit_count_for_tests()


func get_headbutt_miss_count_for_tests() -> int:
	return _skill_runtime_host.get_headbutt_miss_count_for_tests()


func configure_companion_motion_for_tests(test_pos: Vector2, test_seed: int, test_decision_timer: float, test_intercept_active: bool) -> void:
	_companion_pos = test_pos
	_companion_motion_state.configure_for_tests(test_pos, test_seed, test_decision_timer, test_intercept_active)


func get_gauge_gain_per_hit(base_gain: float) -> float:
	var gain: float = maxf(0.0, base_gain)
	var bonus_pct := _get_current_gauge_gain_bonus_pct()
	if _state != STATE_COMPANION or bonus_pct <= 0.0:
		return gain
	return floor(gain * (1.0 + bonus_pct / 100.0))


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = _snapshot_builder.build_runtime_snapshot(
		_pet_id,
		_state,
		_get_current_required_hits(),
		_companion_pos,
		_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
		_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0),
		_get_current_active_skill(),
		_hatch_flash_timer,
		_collection_state.get_owned_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_get_current_gauge_gain_bonus_pct(),
		_egg_state,
		_companion_motion_state,
		_get_current_stat("patrol_speed_default", COMPANION_PATROL_SPEED),
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_defense_rate(),
		_companion_body_hit_state,
		_get_current_hit_gauge_gain(),
		_companion_skill_state,
		_get_current_skill_windup_seconds(),
		COMPANION_SKILL_FLASH_SECONDS,
		_skill_runtime_host
	)
	snapshot.merge(_switch_transition_state.get_snapshot(COMPANION_SWITCH_TRANSITION_SECONDS), true)
	return snapshot


func get_save_snapshot() -> Dictionary:
	return _snapshot_builder.build_save_snapshot(
		SAVE_SNAPSHOT_VERSION,
		_pet_id,
		_state,
		_egg_state.hatch_hits,
		_get_current_required_hits(),
		_egg_state.pos,
		_companion_pos,
		_collection_state.get_owned_pet_ids(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_get_current_gauge_gain_bonus_pct(),
		_companion_motion_state
	)


func build_save_snapshot() -> Dictionary:
	return get_save_snapshot()


func apply_save_snapshot(snapshot: Dictionary, owner: Object = null) -> Dictionary:
	reset_for_tests()
	var restore_reason := "ok"
	if snapshot.is_empty():
		if owner != null:
			_sync_owner(owner)
		return {
			"restored": false,
			"reason": "empty_snapshot",
		}

	_set_current_pet_id(str(snapshot.get("pet_id", PET_ID)))
	var restored_state: String = _normalize_lingpet_state(str(snapshot.get("state", STATE_NONE)))
	var restore_plan: Dictionary = _save_restore_planner.build_plan(snapshot, owner, _collection_state, _pet_id, restored_state)
	restore_reason = str(restore_plan.get("restore_reason", "ok"))
	_set_current_pet_id(str(restore_plan.get("pet_id", _pet_id)))
	var target_state := str(restore_plan.get("target_state", STATE_NONE))
	if target_state == STATE_COMPANION:
		_state = STATE_COMPANION
		_egg_state.set_hatched(_get_current_required_hits())
		var companion_fallback := Vector2.ZERO
		_companion_pos = _get_vector2_from_variant(snapshot.get("companion_pos", companion_fallback), companion_fallback)
		_companion_motion_state.pos = _companion_pos
		_restore_companion_patrol(snapshot)
		if owner != null:
			_initialize_companion_patrol(owner, _companion_pos == Vector2.ZERO)
	elif target_state == STATE_EGG and bool(restore_plan.get("spawn_fresh_egg", false)):
		_spawn_egg(owner)
	else:
		_clear_lingpet_field_state()
	if owner != null:
		if _state == STATE_COMPANION:
			_mark_current_pet_owned(owner)
		_sync_owner(owner)
	return {
		"restored": true,
		"reason": restore_reason,
		"state": _state,
		"owned_pet_ids": _collection_state.get_owned_pet_ids(),
	}


func restore_save_snapshot(snapshot: Dictionary, owner: Object = null) -> Dictionary:
	return apply_save_snapshot(snapshot, owner)


func reset_for_tests() -> void:
	_state = STATE_NONE
	_set_current_pet_id(PET_ID)
	_egg_state.reset_all()
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_collection_state.reset()
	_hatch_flash_timer = 0.0
	_reset_companion_runtime_state()
	_companion_skill_state_by_pet_id.clear()
	_acquire_cutin_state.reset()
	_switch_transition_state.reset()
	_has_synced_none = false


func reset_round(_deps: Dictionary = {}) -> void:
	_reset_skill_runtime_transients()
	_reset_companion_defense()
	_switch_transition_state.reset()
	_companion_skill_state.reset_round_transients()
	_companion_body_hit_state.reset_round_transients()


func _reset_skill_runtime_transients() -> void:
	_companion_skill_state.cancel_windup()
	_skill_runtime_host.reset()


func _clear_lingpet_field_state() -> void:
	_state = STATE_NONE
	_set_current_pet_id(PET_ID)
	_egg_state.reset_all()
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()


func _reset_companion_runtime_state(reset_defense: bool = true) -> void:
	_companion_sprite_animator.reset_all()
	_companion_body_hit_state.reset_all()
	_companion_skill_state.reset_all()
	if reset_defense:
		_reset_companion_defense()
	_reset_skill_runtime_transients()


func _spawn_egg(owner: Object) -> void:
	_state = STATE_EGG
	_set_current_pet_id(_pick_hatch_pet_id(owner))
	_egg_state.spawn(owner)
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_hatch_flash_timer = 0.0
	_reset_companion_runtime_state()
	_acquire_cutin_state.reset()
	_switch_transition_state.reset()
	_has_synced_none = false
	_prewarm_current_visuals()
	_sync_owner(owner)


func _resolve_ball_hit(owner: Object) -> bool:
	var hit_result: Dictionary = _egg_state.resolve_ball_hit(owner, _get_current_required_hits())
	if not bool(hit_result.get("changed", false)):
		return false

	if bool(hit_result.get("hatched", false)):
		_state = STATE_COMPANION
		_companion_pos = _egg_state.pos
		_initialize_companion_patrol(owner, false)
		_egg_state.reset_contact_motion()
		_reset_companion_runtime_state(false)
		_switch_transition_state.reset()
		_hatch_flash_timer = LingpetEggFieldRenderer.HATCH_FLASH_SECONDS
		_acquire_cutin_state.start()
		_prewarm_current_visuals()
		_mark_current_pet_owned(owner)
	return true


func _sync_owner(owner: Object) -> void:
	_snapshot_builder.sync_owner(
		owner,
		_pet_id,
		_state,
		_egg_state.hatch_hits,
		_get_current_required_hits(),
		_egg_state.pos,
		_companion_pos,
		_get_current_stat("patrol_speed_default", COMPANION_PATROL_SPEED),
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
		_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0),
		_get_current_defense_rate(),
		_collection_state.get_battle_slots(),
		_collection_state.get_active_slot_index(),
		_companion_motion_state,
		_companion_body_hit_state,
		_get_current_hit_gauge_gain(),
		_get_current_active_skill(),
		_companion_skill_state,
		_get_current_gauge_gain_bonus_pct(),
		_get_effect_text()
	)


func _adopt_owned_pet(owner: Object, pet_id: String) -> void:
	_state = STATE_COMPANION
	_set_current_pet_id(pet_id)
	_egg_state.set_hatched(_get_current_required_hits())
	_companion_pos = Vector2.ZERO
	_initialize_companion_patrol(owner, true)
	_reset_companion_runtime_state()
	_restore_current_companion_skill_state()
	_switch_transition_state.reset()
	_hatch_flash_timer = 0.0
	_prewarm_current_visuals()
	_mark_current_pet_owned(owner)
	_sync_owner(owner)


func _save_current_companion_skill_state() -> void:
	if _pet_id == "" or _companion_skill_state == null or not _companion_skill_state.has_method("get_persistent_snapshot"):
		return
	_companion_skill_state_by_pet_id[_pet_id] = _companion_skill_state.get_persistent_snapshot()


func _restore_current_companion_skill_state() -> void:
	if _pet_id == "" or not _companion_skill_state_by_pet_id.has(_pet_id):
		return
	var snapshot: Variant = _companion_skill_state_by_pet_id.get(_pet_id, {})
	if snapshot is Dictionary and _companion_skill_state != null and _companion_skill_state.has_method("apply_persistent_snapshot"):
		_companion_skill_state.apply_persistent_snapshot(snapshot as Dictionary)


func _mark_current_pet_owned(owner: Object) -> void:
	_mark_pet_owned(owner, _pet_id)


func _mark_pet_owned(owner: Object, pet_id: String) -> void:
	_collection_state.add_pet(owner, pet_id)


func _get_effect_text() -> String:
	if _state == STATE_EGG:
		return "공에 %d회 맞히면 미확인 알이 깨어납니다." % _get_current_required_hits()
	if _state == STATE_COMPANION:
		return _current_profile.get_effect_text()
	return ""


func _should_spawn_lingpet_egg(owner: Object) -> bool:
	return _collection_state.should_spawn_egg(owner)


func _find_first_owned_pet_id(owner: Object) -> String:
	return _collection_state.find_first_owned_pet_id(owner)


func _find_active_slot_pet_id(owner: Object) -> String:
	return _collection_state.find_active_slot_pet_id(owner)


func _pick_hatch_pet_id(owner: Object) -> String:
	return _collection_state.pick_hatch_pet_id(owner)


func _get_current_display_name() -> String:
	return _current_profile.get_display_name()


func _get_current_required_hits() -> int:
	return _current_profile.get_required_hits(REQUIRED_HITS)


func _get_current_stat(stat_name: String, fallback: float) -> float:
	return _current_profile.get_stat(stat_name, fallback)


func _get_current_active_skill() -> Dictionary:
	return _current_profile.get_active_skill()


func _get_current_motion_style() -> String:
	return _current_profile.get_motion_style()


func _get_current_skill_id() -> String:
	return _current_profile.get_skill_id()


func _get_current_skill_windup_seconds() -> float:
	return _current_profile.get_skill_windup_seconds(COMPANION_SKILL_WINDUP_SECONDS)


func _get_current_gauge_gain_bonus_pct() -> float:
	return _current_profile.get_gauge_gain_bonus_pct(0.0)


func _get_current_hit_gauge_gain() -> float:
	return _current_profile.get_hit_gauge_gain(COMPANION_HIT_GAUGE_GAIN)


func _get_current_defense_rate() -> float:
	return _current_profile.get_defense_rate(COMPANION_DEFENSE_RATE)


func _get_current_hit_half_width() -> float:
	return _current_profile.get_hit_half_width(COMPANION_HIT_HALF_WIDTH * 2.0)


func _get_current_hit_half_height() -> float:
	return _current_profile.get_hit_half_height(COMPANION_HIT_HALF_HEIGHT * 2.0)


func _normalize_pet_id(value: String) -> String:
	return _current_profile.normalize_pet_id(value)


func _prewarm_current_visuals() -> void:
	_current_profile.prewarm_visuals()
	if _companion_renderer != null and _companion_renderer.has_method("prewarm_assets"):
		_companion_renderer.prewarm_assets()
	if _state == STATE_COMPANION:
		_current_profile.prewarm_visual_keys(LingpetCompanionClickReactionState.PREWARM_VISUAL_KEYS)


func _get_current_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _current_profile.get_visual_texture(visual_key, fallback)


func _normalize_lingpet_state(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == STATE_EGG or normalized == "hatching" or normalized == "알":
		return STATE_EGG
	if normalized == STATE_COMPANION or normalized == "active" or normalized == "owned" or normalized == "hatched" or normalized == "동행":
		return STATE_COMPANION
	return STATE_NONE


func _get_vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _update_companion_motion(delta: float, owner: Object) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.update(
		delta,
		owner,
		_companion_skill_state.windup_active,
		_get_current_defense_rate(),
		_companion_skill_state.trigger_count,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style()
	)
	_companion_pos = _companion_motion_state.pos


func _initialize_companion_patrol(owner: Object, randomize_x: bool) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.initialize(
		owner,
		randomize_x,
		_companion_skill_state.trigger_count,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style()
	)
	_companion_pos = _companion_motion_state.pos


func _restore_companion_patrol(snapshot: Dictionary) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.restore(
		snapshot,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX),
		_get_current_motion_style()
	)
	_companion_pos = _companion_motion_state.pos


func _reset_companion_patrol() -> void:
	_companion_motion_state.reset()
	_companion_pos = Vector2.ZERO


func _reset_companion_defense() -> void:
	_companion_motion_state.reset_defense()


func _resolve_companion_ball_hit(owner: Object, registry: Object = null) -> bool:
	if not bool(_get_owner_value(owner, "ball_active", false)):
		_companion_body_hit_state.ball_was_inside = false
		return false
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)

	var hit_result: Dictionary = _companion_body_hit_state.resolve_ball_hit(
		owner,
		registry,
		_companion_pos,
		_get_current_stat("catch_width", COMPANION_HIT_HALF_WIDTH * 2.0),
		_get_current_stat("catch_height", COMPANION_HIT_HALF_HEIGHT * 2.0),
		_get_current_hit_gauge_gain(),
		_state == STATE_COMPANION,
		_companion_sprite_animator.strike_active
	)
	if not bool(hit_result.get("hit", false)):
		return false

	# If the anticipatory predictor already started the swing for this approach,
	# leave it running (do NOT restart -- mirrors boss trigger_hit's hit_active
	# early-return). Only if the prediction missed do we fall back to a reactive
	# strike entering at the thrust apex so the spear still snaps on contact.
	if bool(hit_result.get("should_begin_strike", false)):
		_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_IMPACT_FRAME)
	# Guard against a boss skill that owns the ball each frame (e.g. Dalji's
	# 상모돌리기 whip forces the ball downward via update_ball_motion). Notify it
	# like a player-paddle guard so it stops controlling the ball; otherwise the
	# whip re-forces the ball down next frame and the companion bounce is ignored.
	return true


func _update_companion_skill_effects(delta: float, owner: Object, registry: Object = null) -> void:
	var skill_id := _get_current_skill_id()
	var decision: Dictionary = _companion_skill_controller.update(delta, {
		"state": _state,
		"companion_state": STATE_COMPANION,
		"owner": owner,
		"registry": registry,
		"skill_id": skill_id,
		"skill_state": _companion_skill_state,
		"skill_runtime_host": _skill_runtime_host,
		"windup_seconds": _get_current_skill_windup_seconds(),
		"ball_active": bool(_get_owner_value(owner, "ball_active", false)),
		"companion_visible": _companion_motion_state.motion_visible,
		"companion_pos": _companion_pos,
	})
	match str(decision.get("action", LingpetCompanionSkillController.ACTION_NONE)):
		LingpetCompanionSkillController.ACTION_ARM:
			_arm_companion_skill(owner, skill_id)
		LingpetCompanionSkillController.ACTION_LAUNCH:
			_launch_companion_skill(owner, registry)
		_:
			pass
	_trigger_companion_skill_strike_if_requested(skill_id)
	_apply_companion_skill_position_override(skill_id)


func _arm_companion_skill(owner: Object, skill_id: String) -> bool:
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	return _companion_skill_controller.arm_windup(_companion_skill_state, _skill_runtime_host, skill_id)


func _launch_companion_skill(owner: Object, registry: Object) -> void:
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	var skill_id := _get_current_skill_id()
	var origin: Vector2 = _skill_runtime_host.get_launch_origin(skill_id, _companion_pos, COMPANION_RADIUS)
	var launched: bool = _companion_skill_controller.complete_launch(
		_companion_skill_state,
		_skill_runtime_host,
		skill_id,
		origin,
		float(_get_current_active_skill().get("cooldown", COMPANION_SKILL_COOLDOWN_SECONDS)),
		COMPANION_SKILL_FLASH_SECONDS,
		registry,
		owner
	)
	if launched and _skill_runtime_host.has_companion_position_override(skill_id):
		_apply_companion_skill_position_override(skill_id)


func _trigger_companion_skill_strike_if_requested(skill_id: String) -> void:
	if not _skill_runtime_host.has_method("consume_companion_strike_request"):
		return
	if bool(_skill_runtime_host.consume_companion_strike_request(skill_id)):
		_companion_sprite_animator.begin_strike(LingpetCompanionSpriteAnimator.STRIKE_START_FRAME)


func _apply_companion_skill_position_override(skill_id: String) -> void:
	if not _skill_runtime_host.has_companion_position_override(skill_id):
		return
	_companion_pos = _skill_runtime_host.get_companion_position_override(skill_id, _companion_pos)
	_companion_motion_state.pos = _companion_pos


func _draw_egg(canvas: CanvasItem, center: Vector2) -> void:
	_egg_renderer.draw_egg(
		canvas,
		center,
		_egg_state.hatch_hits,
		_get_current_required_hits(),
		_egg_state.wobble_angle,
		_get_egg_texture_for_hits()
	)


func _get_egg_texture_for_hits() -> Texture2D:
	var visual_key: String = _egg_renderer.get_visual_key_for_hits(_egg_state.hatch_hits, _get_current_required_hits())
	match visual_key:
		"egg_crack_2":
			return _get_current_visual_texture("egg_crack_2", null)
		"egg_crack_1":
			return _get_current_visual_texture("egg_crack_1", null)
		_:
			return _get_current_visual_texture("egg", null)


func _draw_companion(canvas: CanvasItem, center: Vector2) -> void:
	_companion_renderer.draw_companion(canvas, center, _companion_draw_context_builder.build_config({
		"companion_active": _state == STATE_COMPANION,
		"radius": COMPANION_RADIUS,
		"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
		"body_hit_state": _companion_body_hit_state,
		"skill_state": _companion_skill_state,
		"switch_state": _switch_transition_state,
		"skill_runtime_host": _skill_runtime_host,
		"current_profile": _current_profile,
		"skill_id": _get_current_skill_id(),
		"skill_flash_seconds": COMPANION_SKILL_FLASH_SECONDS,
		"switch_transition_seconds": COMPANION_SWITCH_TRANSITION_SECONDS,
		"switch_particles": COMPANION_SWITCH_TRANSITION_PARTICLES,
		"animator": _companion_sprite_animator,
		"patrol_pause": _companion_motion_state.patrol_pause,
		"motion_speed_ratio": 1.0 if _skill_runtime_host.has_companion_position_override(_get_current_skill_id()) else (_companion_motion_state.motion_speed_ratio if _get_current_motion_style() == "sortie_flight" else 0.0),
		"companion_visible": _companion_motion_state.motion_visible or _skill_runtime_host.has_companion_position_override(_get_current_skill_id()),
		"windup_seconds": _get_current_skill_windup_seconds(),
	}))


# Begin the in-battle click-reaction popup if the click landed on the patrolling
# companion. Battle is NOT paused -- the reaction plays as a large popup above
# the SD companion and fades out on its own. playfield_pos is in game/playfield
# coordinates (caller converts the viewport click via the layout render_scale /
# game_offset). Returns true when the click was consumed by the companion.
func try_begin_companion_click_reaction(playfield_pos: Vector2) -> bool:
	if _state != STATE_COMPANION:
		return false
	if _companion_pos == Vector2.ZERO:
		return false
	if _companion_click_reaction_state.is_active():
		return true
	if not _companion_click_reaction_state.can_start_at(playfield_pos, _companion_pos):
		return false
	_companion_click_reaction_state.start()
	return true


func is_companion_click_reaction_active() -> bool:
	return _companion_click_reaction_state.is_active()


func _maybe_arm_companion_strike(owner: Object) -> void:
	_companion_strike_anticipator.maybe_arm(
		owner,
		_companion_pos,
		_get_current_hit_half_width(),
		_get_current_hit_half_height(),
		_companion_body_hit_state.cooldown,
		_companion_sprite_animator,
		BALL_RADIUS_FALLBACK
	)


func _draw_hatch_flash(canvas: CanvasItem, center: Vector2) -> void:
	_egg_renderer.draw_hatch_flash(canvas, center, _hatch_flash_timer)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)
