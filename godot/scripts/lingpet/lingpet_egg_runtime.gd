extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const LingpetAcquireCutinState := preload("res://scripts/lingpet/lingpet_acquire_cutin_state.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCollectionState := preload("res://scripts/lingpet/lingpet_collection_state.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetEggFieldState := preload("res://scripts/lingpet/lingpet_egg_field_state.gd")
const LingpetEggFieldRenderer := preload("res://scripts/lingpet/lingpet_egg_field_renderer.gd")
const LingpetHydroSphereSkill := preload("res://scripts/lingpet/lingpet_hydro_sphere_skill.gd")
const LingpetRuntimeSnapshotBuilder := preload("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetVisualTextureCache := preload("res://scripts/lingpet/lingpet_visual_texture_cache.gd")
const MARIBO_EGG_TEXTURE := preload("res://assets/sprites/lingpet/maribo_egg_v002.png")
const MARIBO_EGG_TEXTURE_CRACK_1 := preload("res://assets/sprites/lingpet/maribo_egg_v002_crack1.png")
const MARIBO_EGG_TEXTURE_CRACK_2 := preload("res://assets/sprites/lingpet/maribo_egg_v002_crack2.png")
# AutoSprite back-view walk sheet (player-side view). Runtime-ready 640x640 PNG,
# 5 cols x 5 rows = 25 frames, 128px cells. Source provenance:
# godot/lingpet/maribo/maribo_walk_back_autosprite_v001.png (256px native cells).
# Idle is DERIVED from this sheet (no separate idle asset): the patrol-paused
# state holds the animator's idle frame and the breathing bob is code-driven.
const MARIBO_COMPANION_WALK_SHEET := preload("res://assets/sprites/lingpet/maribo_companion_walk.png")
# Back-view ball-hit strike (AutoSprite animate_asset one-shot, same 5x5/25 grid
# as the walk sheet). Started anticipatorily before contact (see the strike
# constants + _maybe_arm_companion_strike), overriding walk/idle while playing.
const MARIBO_COMPANION_STRIKE_SHEET := preload("res://assets/sprites/lingpet/maribo_companion_strike.png")
# Back-view hydro-spear cast wind-up (AutoSprite animate_asset, same 5x5/25 grid).
# Played while _companion_skill_state.windup_active over COMPANION_SKILL_WINDUP_SECONDS;
# the final frame (throw release) lands as the projectile launches.
const MARIBO_COMPANION_HYDRO_CAST_SHEET := preload("res://assets/sprites/lingpet/maribo_companion_hydro_cast.png")

const PET_ID := LingpetCatalog.DEFAULT_PET_ID
const STATE_NONE := "none"
const STATE_EGG := "egg"
const STATE_COMPANION := "companion"
const REQUIRED_HITS := 2
const BALL_RADIUS_FALLBACK := 14.3
const SAVE_SNAPSHOT_VERSION := 1
const MARIBO_GAUGE_GAIN_BONUS_PCT := 10.0
const COMPANION_RADIUS := 16.0
# Anticipatory strike (mirrors player/boss _maybe_trigger_anticipated_hit): the
# swing is started BEFORE the ball arrives by predicting time-to-contact and
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
var _companion_renderer: Object = LingpetCompanionRenderer.new()
var _companion_sprite_animator: Object = LingpetCompanionSpriteAnimator.new()
var _companion_skill_state: Object = LingpetCompanionSkillState.new()
var _hydro_sphere_skill: Object = LingpetHydroSphereSkill.new()
var _snapshot_builder: Object = LingpetRuntimeSnapshotBuilder.new()
var _visual_texture_cache: Object = LingpetVisualTextureCache.new()
var _acquire_cutin_state: Object = LingpetAcquireCutinState.new()
var _has_synced_none := false
var _switch_transition_timer := 0.0
var _switch_transition_from_pet_id := ""
var _switch_transition_to_pet_id := ""
var _switch_transition_trigger_count := 0


func update(delta: float, owner: Object, registry: Object = null) -> bool:
	if owner == null:
		return false
	_advance_companion_switch_transition(delta)
	_egg_state.advance(delta)
	_companion_body_hit_state.advance(delta)
	_companion_skill_state.advance(delta)
	_hatch_flash_timer = maxf(0.0, _hatch_flash_timer - maxf(0.0, delta))
	_companion_sprite_animator.advance(delta)

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
		_hydro_sphere_skill.draw(canvas, shake_offset)
		_draw_companion(canvas, _companion_pos + shake_offset)
		if _hatch_flash_timer > 0.0:
			_draw_hatch_flash(canvas, _egg_state.pos + shake_offset)


func has_visible_effects() -> bool:
	return (
		_state == STATE_EGG
		or _state == STATE_COMPANION
		or _hatch_flash_timer > 0.0
		or _acquire_cutin_state.active
		or _hydro_sphere_skill.has_visible_effects()
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


func get_lingpet_slots() -> Array[String]:
	return _collection_state.get_battle_slots()


func get_active_lingpet_slot_index() -> int:
	return _collection_state.get_active_slot_index()


func switch_lingpet_slot(slot_index: int, owner: Object = null) -> bool:
	var next_pet_id: String = _collection_state.select_active_slot(slot_index, owner)
	if next_pet_id == "":
		return false
	if _state != STATE_COMPANION:
		_adopt_owned_pet(owner, next_pet_id)
		return true
	if next_pet_id == _pet_id:
		_sync_owner(owner)
		return true
	_begin_companion_switch_transition(_pet_id, next_pet_id)
	_pet_id = next_pet_id
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	_companion_sprite_animator.reset_all()
	_companion_body_hit_state.reset_all()
	_companion_skill_state.reset_all()
	_reset_companion_defense()
	_reset_hydro_sphere_transients()
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
	return _hydro_sphere_skill.get_particle_count_for_tests()


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
		COMPANION_SKILL_FLASH_SECONDS,
		_hydro_sphere_skill
	)
	var switch_ratio := _get_companion_switch_transition_ratio()
	snapshot["companion_switch_transition"] = switch_ratio
	snapshot["companion_switch_from_pet_id"] = _switch_transition_from_pet_id if switch_ratio > 0.0 else ""
	snapshot["companion_switch_to_pet_id"] = _switch_transition_to_pet_id if switch_ratio > 0.0 else ""
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

	_pet_id = _normalize_pet_id(str(snapshot.get("pet_id", PET_ID)))
	if _pet_id == "":
		_pet_id = PET_ID
	_collection_state.set_owned_pet_ids(snapshot.get("owned_pet_ids", []))
	_collection_state.set_battle_slots(snapshot.get("battle_slot_pet_ids", snapshot.get("lingpet_slots", [])))
	_collection_state.set_active_slot_index(int(snapshot.get("active_slot_index", 0)))
	var active_pet_id := _normalize_pet_id(str(snapshot.get("active_pet_id", "")))
	if active_pet_id != "":
		_collection_state.add_pet(null, active_pet_id)
		if _collection_state.get_battle_slots()[_collection_state.get_active_slot_index()] == "":
			_collection_state.set_battle_slots([active_pet_id, "", ""])
			_collection_state.set_active_slot_index(0)

	var restored_state: String = _normalize_lingpet_state(str(snapshot.get("state", STATE_NONE)))
	var owned_pet_id := _find_active_slot_pet_id(owner)
	if restored_state == STATE_COMPANION or _collection_state.get_owned_pet_ids().has(_pet_id) or not active_pet_id.is_empty() or not owned_pet_id.is_empty():
		_state = STATE_COMPANION
		if not active_pet_id.is_empty():
			_pet_id = active_pet_id
		elif not owned_pet_id.is_empty():
			_pet_id = owned_pet_id
		_egg_state.set_hatched(_get_current_required_hits())
		var companion_fallback := Vector2.ZERO
		_companion_pos = _get_vector2_from_variant(snapshot.get("companion_pos", companion_fallback), companion_fallback)
		_companion_motion_state.pos = _companion_pos
		_restore_companion_patrol(snapshot)
		if owner != null:
			_initialize_companion_patrol(owner, _companion_pos == Vector2.ZERO)
	elif restored_state == STATE_EGG:
		restore_reason = "egg_reset_on_entry"
		if owner != null and _should_spawn_lingpet_egg(owner):
			_spawn_egg(owner)
		else:
			_state = STATE_NONE
			_pet_id = PET_ID
			_egg_state.reset_all()
			_companion_pos = Vector2.ZERO
			_reset_companion_patrol()
	else:
		_state = STATE_NONE
		_pet_id = PET_ID
		_egg_state.reset_all()
		_companion_pos = Vector2.ZERO
		_reset_companion_patrol()
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
	_pet_id = PET_ID
	_egg_state.reset_all()
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_collection_state.reset()
	_hatch_flash_timer = 0.0
	_companion_sprite_animator.reset_all()
	_companion_body_hit_state.reset_all()
	_companion_skill_state.reset_all()
	_reset_companion_defense()
	_reset_hydro_sphere_transients()
	_acquire_cutin_state.reset()
	_reset_companion_switch_transition()
	_has_synced_none = false


func reset_round(_deps: Dictionary = {}) -> void:
	_reset_hydro_sphere_transients()
	_reset_companion_defense()
	_reset_companion_switch_transition()
	_companion_skill_state.reset_round_transients()
	_companion_body_hit_state.reset_round_transients()


func _reset_hydro_sphere_transients() -> void:
	_companion_skill_state.cancel_windup()
	_hydro_sphere_skill.reset()


func _begin_companion_switch_transition(from_pet_id: String, to_pet_id: String) -> void:
	_switch_transition_from_pet_id = _normalize_pet_id(from_pet_id)
	_switch_transition_to_pet_id = _normalize_pet_id(to_pet_id)
	_switch_transition_trigger_count += 1
	_switch_transition_timer = COMPANION_SWITCH_TRANSITION_SECONDS


func _advance_companion_switch_transition(delta: float) -> void:
	if _switch_transition_timer <= 0.0:
		return
	_switch_transition_timer = maxf(0.0, _switch_transition_timer - maxf(0.0, delta))
	if _switch_transition_timer <= 0.0:
		_switch_transition_from_pet_id = ""
		_switch_transition_to_pet_id = ""


func _reset_companion_switch_transition() -> void:
	_switch_transition_timer = 0.0
	_switch_transition_from_pet_id = ""
	_switch_transition_to_pet_id = ""
	_switch_transition_trigger_count = 0


func _get_companion_switch_transition_ratio() -> float:
	if _switch_transition_timer <= 0.0 or COMPANION_SWITCH_TRANSITION_SECONDS <= 0.0:
		return 0.0
	return clampf(_switch_transition_timer / COMPANION_SWITCH_TRANSITION_SECONDS, 0.0, 1.0)


func _spawn_egg(owner: Object) -> void:
	_state = STATE_EGG
	_pet_id = _pick_hatch_pet_id(owner)
	if _pet_id == "":
		_pet_id = PET_ID
	_egg_state.spawn(owner)
	_companion_pos = Vector2.ZERO
	_reset_companion_patrol()
	_hatch_flash_timer = 0.0
	_companion_sprite_animator.reset_all()
	_companion_body_hit_state.reset_all()
	_companion_skill_state.reset_all()
	_reset_companion_defense()
	_reset_hydro_sphere_transients()
	_acquire_cutin_state.reset()
	_reset_companion_switch_transition()
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
		_companion_sprite_animator.reset_all()
		_companion_body_hit_state.reset_all()
		_companion_skill_state.reset_all()
		_reset_hydro_sphere_transients()
		_reset_companion_switch_transition()
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
	_pet_id = _normalize_pet_id(pet_id)
	if _pet_id == "":
		_pet_id = PET_ID
	_egg_state.set_hatched(_get_current_required_hits())
	_companion_pos = Vector2.ZERO
	_initialize_companion_patrol(owner, true)
	_companion_sprite_animator.reset_all()
	_companion_body_hit_state.reset_all()
	_companion_skill_state.reset_all()
	_reset_companion_defense()
	_reset_hydro_sphere_transients()
	_reset_companion_switch_transition()
	_hatch_flash_timer = 0.0
	_prewarm_current_visuals()
	_mark_current_pet_owned(owner)
	_sync_owner(owner)


func _mark_current_pet_owned(owner: Object) -> void:
	_mark_pet_owned(owner, _pet_id)


func _mark_pet_owned(owner: Object, pet_id: String) -> void:
	_collection_state.add_pet(owner, pet_id)


func _get_effect_text() -> String:
	if _state == STATE_EGG:
		return "공에 %d회 맞히면 공명으로 %s가 깨어납니다." % [_get_current_required_hits(), _get_current_display_name()]
	if _state == STATE_COMPANION:
		return LingpetCatalog.get_effect_text(_pet_id)
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
	return LingpetCatalog.get_display_name(_pet_id)


func _get_current_required_hits() -> int:
	return LingpetCatalog.get_required_hits(_pet_id, REQUIRED_HITS)


func _get_current_stat(stat_name: String, fallback: float) -> float:
	return LingpetCatalog.get_stat(_pet_id, stat_name, fallback)


func _get_current_active_skill() -> Dictionary:
	return LingpetCatalog.get_active_skill(_pet_id)


func _get_current_skill_id() -> String:
	return str(_get_current_active_skill().get("id", ""))


func _get_current_gauge_gain_bonus_pct() -> float:
	return _get_current_stat("gauge_gain_bonus_pct", MARIBO_GAUGE_GAIN_BONUS_PCT)


func _get_current_hit_gauge_gain() -> float:
	return _get_current_stat("hit_gauge_gain", COMPANION_HIT_GAUGE_GAIN)


func _get_current_defense_rate() -> float:
	return _get_current_stat("defense_rate", COMPANION_DEFENSE_RATE)


func _normalize_pet_id(value: String) -> String:
	return _collection_state.normalize_pet_id(value)


func _prewarm_current_visuals() -> void:
	_visual_texture_cache.prewarm_pet(_pet_id)


func _get_current_visual_texture(visual_key: String, fallback: Texture2D) -> Texture2D:
	return _visual_texture_cache.get_texture(_pet_id, visual_key, fallback)


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
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX)
	)
	_companion_pos = _companion_motion_state.pos


func _initialize_companion_patrol(owner: Object, randomize_x: bool) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.initialize(
		owner,
		randomize_x,
		_companion_skill_state.trigger_count,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX)
	)
	_companion_pos = _companion_motion_state.pos


func _restore_companion_patrol(snapshot: Dictionary) -> void:
	_companion_motion_state.pos = _companion_pos
	_companion_motion_state.restore(
		snapshot,
		_get_current_stat("patrol_speed_min", COMPANION_PATROL_SPEED_MIN),
		_get_current_stat("patrol_speed_max", COMPANION_PATROL_SPEED_MAX)
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
	match LingpetSkillDispatcher.get_skill_kind(_get_current_skill_id()):
		LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
			_update_hydro_sphere_skill(delta, owner, registry)
		_:
			_companion_skill_state.cancel_windup()


func _update_hydro_sphere_skill(delta: float, owner: Object, registry: Object = null) -> void:
	var safe_delta: float = maxf(0.0, delta)
	_hydro_sphere_skill.update(safe_delta, owner, registry)
	_advance_companion_skill_windup(safe_delta, owner, registry)
	if (
		_state == STATE_COMPANION
		and not _companion_skill_state.windup_active
		and _companion_skill_state.cooldown <= 0.0
		and not _hydro_sphere_skill.is_projectile_active()
	):
		_try_activate_companion_skill(owner, registry)


func _try_activate_companion_skill(owner: Object, _registry: Object = null) -> bool:
	if not LingpetSkillDispatcher.is_hydro_sphere(_get_current_skill_id()):
		return false
	if (
		_state != STATE_COMPANION
		or _companion_skill_state.cooldown > 0.0
		or _hydro_sphere_skill.is_projectile_active()
		or _companion_skill_state.windup_active
		or not bool(_get_owner_value(owner, "ball_active", false))
	):
		return false
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	# Wind-up gives ~1s lead, so prewarm before the first puddle frame.
	_hydro_sphere_skill.prewarm()
	# Arm the telegraphed throw wind-up. The projectile launches when the wind-up
	# completes (_advance_companion_skill_windup); cooldown is set then, not here.
	_companion_skill_state.arm_windup()
	return true


func _advance_companion_skill_windup(delta: float, owner: Object, registry: Object) -> void:
	if _companion_skill_state.advance_windup(delta, COMPANION_SKILL_WINDUP_SECONDS):
		match LingpetSkillDispatcher.get_skill_kind(_get_current_skill_id()):
			LingpetSkillDispatcher.SKILL_KIND_HYDRO_SPHERE:
				_launch_hydro_sphere_projectile(owner, registry)
			_:
				_companion_skill_state.cancel_windup()


func _launch_hydro_sphere_projectile(owner: Object, registry: Object) -> void:
	if _companion_pos == Vector2.ZERO:
		_initialize_companion_patrol(owner, true)
	var origin: Vector2 = _companion_pos + Vector2(0.0, -COMPANION_RADIUS - 8.0)
	_hydro_sphere_skill.launch(origin)
	_companion_skill_state.complete_launch(
		origin,
		float(_get_current_active_skill().get("cooldown", COMPANION_SKILL_COOLDOWN_SECONDS)),
		COMPANION_SKILL_FLASH_SECONDS
	)
	_trigger_companion_skill_feedback(registry)


func _trigger_companion_skill_feedback(registry: Object) -> void:
	if registry == null:
		return
	var audio: Object = _get_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_stage2_hydro"):
		audio.play_stage2_hydro()


func _get_companion_hit_flash_ratio() -> float:
	return _companion_body_hit_state.get_hit_flash_ratio(_state == STATE_COMPANION)


func _get_companion_hit_gauge_flash_ratio() -> float:
	return _companion_body_hit_state.get_gauge_flash_ratio(_state == STATE_COMPANION)


func _get_companion_skill_flash_ratio() -> float:
	if _state != STATE_COMPANION or COMPANION_SKILL_FLASH_SECONDS <= 0.0:
		return 0.0
	return _companion_skill_state.get_flash_ratio(COMPANION_SKILL_FLASH_SECONDS)


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
			return _get_current_visual_texture("egg_crack_2", MARIBO_EGG_TEXTURE_CRACK_2)
		"egg_crack_1":
			return _get_current_visual_texture("egg_crack_1", MARIBO_EGG_TEXTURE_CRACK_1)
		_:
			return _get_current_visual_texture("egg", MARIBO_EGG_TEXTURE)


func _draw_companion(canvas: CanvasItem, center: Vector2) -> void:
	# Priority: hydro-cast wind-up > ball-hit strike > walk/idle. The committed
	# skill cast takes the top visual slot while it is telegraphing the throw.
	var casting_windup: bool = _companion_skill_state.windup_active and LingpetSkillDispatcher.is_hydro_sphere(_get_current_skill_id())
	var attacking: bool = _companion_sprite_animator.strike_active
	_companion_renderer.draw_companion(canvas, center, {
		"radius": COMPANION_RADIUS,
		"burst_particles": COMPANION_SKILL_BURST_PARTICLES,
		"hit_flash": _get_companion_hit_flash_ratio(),
		"gauge_flash": _get_companion_hit_gauge_flash_ratio(),
		"skill_flash": _get_companion_skill_flash_ratio(),
		"switch_transition": _get_companion_switch_transition_ratio(),
		"switch_particles": COMPANION_SWITCH_TRANSITION_PARTICLES,
		"switch_trigger_count": _switch_transition_trigger_count,
		"gauge_trigger_count": _companion_body_hit_state.gauge_trigger_count,
		"skill_trigger_count": _companion_skill_state.trigger_count,
		"animator": _companion_sprite_animator,
		"patrol_pause": _companion_motion_state.patrol_pause,
		"windup_elapsed": _companion_skill_state.windup_elapsed,
		"windup_seconds": COMPANION_SKILL_WINDUP_SECONDS,
		"casting_windup": casting_windup,
		"attacking": attacking,
		"walk_texture": _get_current_visual_texture("companion_walk", MARIBO_COMPANION_WALK_SHEET),
		"strike_texture": _get_current_visual_texture("companion_strike", MARIBO_COMPANION_STRIKE_SHEET),
		"cast_texture": _get_current_visual_texture("companion_cast", MARIBO_COMPANION_HYDRO_CAST_SHEET),
	})


# Anticipatory predictor: mirrors player_actor_animation_state._maybe_trigger_
# anticipated_hit. Each frame, if the ball is descending toward the companion's
# lane within reach, predict frames-to-contact and start the strike at an entry
# frame so the thrust apex lands on the ball -- the swing thus begins BEFORE
# contact, like the other characters. Visual-only: the real bounce/gauge still
# fire on overlap in _resolve_companion_ball_hit.
func _maybe_arm_companion_strike(owner: Object) -> void:
	if not bool(_get_owner_value(owner, "ball_active", false)):
		_companion_sprite_animator.reset_latch()
		return
	var ball_vel: Vector2 = _get_owner_vector2(owner, "ball_vel", Vector2.ZERO)
	if ball_vel.y <= 0.0:
		# Ball not descending toward the companion lane -> allow a fresh arm later.
		_companion_sprite_animator.reset_latch()
		return
	if _companion_sprite_animator.strike_latched or _companion_sprite_animator.strike_active:
		return
	if _companion_body_hit_state.cooldown > 0.0:
		_companion_sprite_animator.reset_latch()
		return
	if _companion_pos == Vector2.ZERO:
		return

	var ball_pos: Vector2 = _get_owner_vector2(owner, "ball_pos", Vector2.ZERO)
	var ball_radius: float = maxf(1.0, float(_get_owner_value(owner, "ball_size", BALL_RADIUS_FALLBACK * 2.0)) * 0.5)
	var vertical_gap: float = (_companion_pos.y - COMPANION_HIT_HALF_HEIGHT) - (ball_pos.y + ball_radius)
	if vertical_gap < 0.0:
		return
	if vertical_gap > LingpetCompanionSpriteAnimator.STRIKE_MAX_GAP:
		return

	var impact_boost: float = maxf(0.01, float(_get_owner_value(owner, "ball_impact_boost", 1.0)))
	var downward_speed: float = maxf(0.01, ball_vel.y * impact_boost)
	var frames_to_contact: float = vertical_gap / downward_speed
	var start_frame: int = _companion_sprite_animator.get_strike_start_frame(frames_to_contact)
	if start_frame < 0:
		return

	var future_ball_x: float = ball_pos.x + ball_vel.x * impact_boost * frames_to_contact
	var x_tolerance: float = COMPANION_HIT_HALF_WIDTH + ball_radius + LingpetCompanionSpriteAnimator.STRIKE_X_TOLERANCE
	if absf(future_ball_x - _companion_pos.x) > x_tolerance:
		return

	_companion_sprite_animator.begin_strike(start_frame)
	_companion_sprite_animator.strike_latched = true


func _draw_hatch_flash(canvas: CanvasItem, center: Vector2) -> void:
	_egg_renderer.draw_hatch_flash(canvas, center, _hatch_flash_timer)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(owner, key, fallback)


func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	if registry.has_method("get_cached_instance"):
		var cached: Variant = registry.get_cached_instance(key)
		if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
			return cached as Object
	if registry.has_method("get_instance"):
		var value: Variant = registry.get_instance(key)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
	return null
