extends RefCounted

const PlayerCharacterRuntime := preload(
	"res://scripts/characters/player_character_runtime.gd"
)
const Stage1PlayerSpriteRenderer := preload(
	"res://scripts/stages/stage1/stage1_player_sprite_renderer.gd"
)
const TowerTrainingTimingJudgmentPolicy := preload(
	"res://scripts/tower_ascent/tower_training_timing_judgment_policy.gd"
)

const SHEET_ATTACK_DURATION_MSEC := 720
const SHEET_CONTACT_MSEC := 360
const OPTIMUS_APPROACH_MSEC := 90
const HITSTOP_MSEC := 45
const OPTIMUS_RETURN_MSEC := 150
const OPTIMUS_LUNGE_PX := 14.0
const DUMMY_AWAY_MSEC := 55
const DUMMY_REBOUND_MSEC := 65
const DUMMY_RETURN_MSEC := 120
const DUMMY_REACTION_MSEC := DUMMY_AWAY_MSEC + DUMMY_REBOUND_MSEC + DUMMY_RETURN_MSEC
const DUMMY_AWAY_DEGREES := 7.0
const DUMMY_REBOUND_DEGREES := -2.0
const STAGE_SHAKE_MSEC := 90
const STAGE_SHAKE_MAX_PX := 3.0
const IMPACT_EFFECT_MSEC := 150
const CRITICAL_PRELUDE_HITSTOP_MSEC := 200
const CRITICAL_AURA_LEAD_MSEC := 60
const AURA_EFFECT_MSEC := 320
const MESSAGE_DELAY_AFTER_CONTACT_MSEC := DUMMY_AWAY_MSEC
# 피드백2 3항: 520ms left under 0.3s of fully readable copy once the fade
# envelope was subtracted; 1000ms holds the judgment promise readable.
const MESSAGE_EFFECT_MSEC := 1000
const PADDLE_HIT_AUDIO_SOURCE_X := 504.0

var _character_runtime: Object = PlayerCharacterRuntime.new()
var _sprite_renderer: Object = null
var _audio: Object = null
var _character_type := PlayerCharacterRuntime.SMASHER
var _sprite_spec: Dictionary = {}
var _idle_model: Dictionary = {}
var _visual_model: Dictionary = {}
var _configured := false
var _active := false
var _started_msec := 0
var _clock_override_msec := -1
var _contact_audio_emitted := false
var _audio_active := false
var _configure_count := 0
var _start_count := 0
var _active_update_count := 0
var _active_model_build_count := 0
var _contact_event_count := 0
var _cleanup_count := 0
var _presentation_rng: RandomNumberGenerator = null
var _presentation_rng_seed_override := 0
var _presentation_rng_preconsume_for_tests := 0
var _presentation_rng_roll_count := 0
var _impact_directions: Array[Vector2] = []
var _impact_point_offsets: Array[Vector2] = []
var _judgment_kind := TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
var _message_text := ""


func configure(
	character_type: Variant,
	texture_cache: Dictionary,
	audio: Object = null
) -> void:
	clear()
	_character_type = _character_runtime.normalize(character_type)
	_sprite_spec = _build_sprite_spec(_character_type, texture_cache)
	_sprite_renderer = Stage1PlayerSpriteRenderer.new()
	_audio = audio
	_configured = true
	_configure_count += 1
	_idle_model = _build_visual_model(0, false)
	_visual_model = _idle_model


func clear() -> void:
	if _active or _contact_audio_emitted or _audio_active:
		_cleanup_count += 1
	_active = false
	_stop_audio()
	_configured = false
	_sprite_renderer = null
	_audio = null
	_sprite_spec.clear()
	_idle_model.clear()
	_visual_model.clear()
	_contact_audio_emitted = false
	_judgment_kind = TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
	_message_text = ""
	_clear_presentation_rolls()


func start(judgment_kind: String = "", message_text: String = "") -> bool:
	if not _configured:
		return false
	if _active or _contact_audio_emitted or _audio_active:
		_cleanup_count += 1
		_stop_audio()
	_active = true
	_contact_audio_emitted = false
	_audio_active = false
	_judgment_kind = judgment_kind.strip_edges()
	if _judgment_kind.is_empty():
		# Legacy S3 callers had the approved 7-degree / 3-pixel profile. That is
		# now the middle timing tier, so no-argument test and compatibility calls
		# retain the same presentation instead of silently becoming the weak tier.
		_judgment_kind = TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT
	if _judgment_kind not in [
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL,
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT,
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE,
	]:
		_judgment_kind = TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
	_message_text = message_text.strip_edges()
	_started_msec = _now_msec()
	_start_count += 1
	_prepare_presentation_rolls()
	_visual_model = _build_visual_model(0, true)
	_active_model_build_count += 1
	return true


func cancel() -> void:
	if _active or _contact_audio_emitted or _audio_active:
		_cleanup_count += 1
	_active = false
	_stop_audio()
	_contact_audio_emitted = false
	_judgment_kind = TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
	_message_text = ""
	_clear_presentation_rolls()
	_visual_model = _idle_model


func update_wall_clock() -> bool:
	if not _active:
		return false
	var elapsed_msec := maxi(0, _now_msec() - _started_msec)
	var contact_msec := _contact_wall_msec()
	if elapsed_msec >= contact_msec and not _contact_audio_emitted:
		_emit_contact_audio()
	if elapsed_msec >= _total_wall_msec():
		_active = false
		_stop_audio()
		_contact_audio_emitted = false
		_clear_presentation_rolls()
		_visual_model = _idle_model
		return false
	_active_update_count += 1
	_visual_model = _build_visual_model(elapsed_msec, true)
	_active_model_build_count += 1
	return true


func is_configured() -> bool:
	return _configured


func is_active() -> bool:
	return _active


func get_visual_model() -> Dictionary:
	# GRT-043: this is a retained reference. The idle draw path performs no
	# detail lookup, sprite resolution, layout assembly, or dynamic-node work.
	return _visual_model


func set_clock_msec_for_tests(value: int) -> void:
	_clock_override_msec = value


func clear_clock_msec_for_tests() -> void:
	_clock_override_msec = -1


func get_debug_state() -> Dictionary:
	return {
		"configured": _configured,
		"active": _active,
		"started_msec": _started_msec,
		"character_type": _character_type,
		"motion_kind": str(_sprite_spec.get("motion_kind", "fallback")),
		"weapon_kind": str(_sprite_spec.get("weapon_kind", "fallback")),
		"sprite_source_key": str(_sprite_spec.get("sprite_source_key", "")),
		"asset_present": bool(_sprite_spec.get("asset_present", false)),
		"configure_count": _configure_count,
		"start_count": _start_count,
		"active_update_count": _active_update_count,
		"active_model_build_count": _active_model_build_count,
		"contact_event_count": _contact_event_count,
		"cleanup_count": _cleanup_count,
		"audio_active": _audio_active,
		"host_node_count": 0,
		"dynamic_layer_count": 0,
		"presentation_rng_roll_count": _presentation_rng_roll_count,
		"presentation_rng_seed": (
			int(_presentation_rng.seed) if _presentation_rng != null else 0
		),
		"judgment_kind": _judgment_kind,
		"prelude_hitstop_msec": _prelude_hitstop_msec(),
		"message_text": _message_text,
	}


func _build_visual_model(elapsed_msec: int, strike_active: bool) -> Dictionary:
	var prelude_msec := _prelude_hitstop_msec()
	var aura_elapsed_msec := maxi(0, elapsed_msec - prelude_msec)
	var strike_lead_msec := _strike_lead_msec()
	var strike_visible := strike_active and aura_elapsed_msec >= strike_lead_msec
	var strike_elapsed_msec := maxi(0, aura_elapsed_msec - strike_lead_msec)
	var local_msec := _local_timeline_msec(strike_elapsed_msec) if strike_visible else 0
	var contact_msec := _contact_msec()
	var dummy_elapsed := maxi(0, local_msec - contact_msec) if strike_visible else 0
	var impact_elapsed := maxi(0, strike_elapsed_msec - contact_msec) if strike_visible else 0
	var sprite_context := _build_sprite_context(local_msec, strike_visible)
	var resolved_sprite: Dictionary = {}
	if _sprite_renderer != null:
		resolved_sprite = _sprite_renderer.resolve_current_sprite(
			sprite_context,
			Rect2(Vector2.ZERO, _sprite_spec.get("draw_size", Vector2(160.0, 160.0))),
			false,
			Vector2.ZERO,
			Vector2(84.0, 16.0),
			Vector2.ZERO
		)
	return {
		"configured": _configured,
		"active": strike_active,
		"strike_visible": strike_visible,
		"character_type": _character_type,
		"motion_kind": str(_sprite_spec.get("motion_kind", "fallback")),
		"weapon_kind": str(_sprite_spec.get("weapon_kind", "fallback")),
		"sprite_source_key": str(_sprite_spec.get("sprite_source_key", "")),
		"asset_present": bool(_sprite_spec.get("asset_present", false)),
		"sprite": resolved_sprite,
		"draw_size": _sprite_spec.get("draw_size", Vector2(160.0, 160.0)),
		"frame_index": _resolved_sprite_frame_index(sprite_context, strike_visible),
		"character_offset_x": _character_offset_x(local_msec, strike_visible),
		"dummy_rotation_radians": deg_to_rad(_dummy_rotation_degrees(dummy_elapsed)),
		"dummy_elapsed_msec": dummy_elapsed,
		"stage_shake_offset": _stage_shake_offset(strike_elapsed_msec, strike_visible),
		"impact_active": (
			strike_visible
			and strike_elapsed_msec >= contact_msec
			and impact_elapsed < IMPACT_EFFECT_MSEC
		),
		"impact_progress": clampf(
			float(impact_elapsed) / float(IMPACT_EFFECT_MSEC),
			0.0,
			1.0
		),
		"impact_directions": _impact_directions,
		"impact_point_offsets": _impact_point_offsets,
		"judgment_kind": _judgment_kind,
		"aura_active": (
			strike_active
			and elapsed_msec >= prelude_msec
			and _judgment_kind != TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE
			and aura_elapsed_msec < AURA_EFFECT_MSEC
		),
		"aura_progress": clampf(
			float(aura_elapsed_msec) / float(AURA_EFFECT_MSEC),
			0.0,
			1.0
		),
		"message_active": (
			strike_visible
			and not _message_text.is_empty()
			and strike_elapsed_msec >= contact_msec + HITSTOP_MSEC + MESSAGE_DELAY_AFTER_CONTACT_MSEC
			and strike_elapsed_msec < contact_msec + HITSTOP_MSEC + MESSAGE_DELAY_AFTER_CONTACT_MSEC + MESSAGE_EFFECT_MSEC
		),
		"message_progress": clampf(
			float(strike_elapsed_msec - contact_msec - HITSTOP_MSEC - MESSAGE_DELAY_AFTER_CONTACT_MSEC)
			/ float(MESSAGE_EFFECT_MSEC),
			0.0,
			1.0
		),
		"message_text": _message_text,
		"hitstop_active": (
			strike_active
			and (
				elapsed_msec < prelude_msec
				or (
					strike_visible
					and strike_elapsed_msec >= contact_msec
					and strike_elapsed_msec < contact_msec + HITSTOP_MSEC
				)
			)
		),
		"wall_elapsed_msec": elapsed_msec,
		"local_timeline_msec": local_msec,
		"contact_msec": _contact_wall_msec(),
		"prelude_hitstop_msec": prelude_msec,
		"total_wall_msec": _total_wall_msec(),
	}


func _resolved_sprite_frame_index(sprite_context: Dictionary, strike_active: bool) -> int:
	var motion_kind := str(_sprite_spec.get("motion_kind", "fallback"))
	if not strike_active or motion_kind == "optimus_idle_tween":
		return int(sprite_context.get("player_idle_frame", 0))
	if motion_kind == "commando_pistol_fire":
		return int(sprite_context.get("commando_pistol_fire_frame", 0))
	return int(sprite_context.get("player_hit_frame", 0))


func _build_sprite_context(local_msec: int, strike_active: bool) -> Dictionary:
	var frame_count := maxi(1, int(_sprite_spec.get("frame_count", 8)))
	var frame_index := 0
	if strike_active:
		var attack_duration := maxi(1, int(_sprite_spec.get(
			"attack_duration_msec",
			SHEET_ATTACK_DURATION_MSEC
		)))
		frame_index = mini(
			frame_count - 1,
			int(floor(float(local_msec) / float(attack_duration) * float(frame_count)))
		)
	else:
		frame_index = 0
	var context := {
		"selected_character_type": _character_type,
		"player_sprite_modulate": Color.WHITE,
		"player_walk_direction": 1,
		"player_hit_side": 1,
		"player_hit_frame": frame_index,
		"player_hit_frame_count": frame_count,
		"player_directional_attack_grid_cols": int(_sprite_spec.get("grid_cols", 4)),
		"player_directional_attack_grid_rows": int(_sprite_spec.get("grid_rows", 2)),
		"player_directional_attack_cell_width": 160.0,
		"player_directional_attack_cell_height": 160.0,
		"player_idle_sprite_texture": _sprite_spec.get("idle_texture", null),
		"player_idle_frame": 0,
		"player_idle_frame_count": 8,
		"player_idle_grid_cols": 4,
		"player_idle_grid_rows": 2,
		"player_idle_cell_width": 160.0,
		"player_idle_cell_height": 160.0,
	}
	var motion_kind := str(_sprite_spec.get("motion_kind", "fallback"))
	if not strike_active or motion_kind == "optimus_idle_tween":
		if strike_active:
			context["player_idle_frame"] = int(floor(float(local_msec) / 110.0)) % 8
		return context
	if motion_kind == "commando_pistol_fire":
		context["commando_pistol_fire_active"] = true
		context["commando_pistol_fire_sheet"] = _sprite_spec.get("attack_texture", null)
		context["commando_pistol_fire_frame"] = frame_index
		context["commando_pistol_fire_grid_cols"] = 4
		context["commando_pistol_fire_grid_rows"] = 2
		context["commando_pistol_fire_frame_count"] = 8
		return context
	if motion_kind == "commando_attack_fallback":
		context["commando_attack_active"] = true
		context["commando_attack_sheet"] = _sprite_spec.get("attack_texture", null)
		context["commando_attack_frame_count"] = 8
		context["commando_attack_grid_cols"] = 4
		context["commando_attack_grid_rows"] = 2
		context["commando_attack_cell_width"] = 160.0
		context["commando_attack_cell_height"] = 160.0
		return context
	context["player_hit_active"] = true
	context["player_attack_right_sheet"] = _sprite_spec.get("attack_texture", null)
	if motion_kind == "smasher_legacy_attack":
		context.erase("player_attack_right_sheet")
		context["player_attack_sheet"] = _sprite_spec.get("attack_texture", null)
		context["player_attack_cell_width"] = 344.0
		context["player_attack_cell_height"] = 384.0
	return context


func _build_sprite_spec(character_type: String, texture_cache: Dictionary) -> Dictionary:
	var idle_key := "player_idle_back_sheet"
	var attack_key := "player_attack_right_sheet"
	var fallback_attack_key := "player_attack_sheet"
	var motion_kind := "directional_attack"
	var weapon_kind := "paddle"
	var frame_count := 16
	var grid_rows := 4
	var draw_size := Vector2(160.0, 160.0)
	match character_type:
		PlayerCharacterRuntime.VIPER:
			idle_key = "viper_player_idle_sheet"
			attack_key = "viper_player_attack_right_sheet"
			fallback_attack_key = ""
			weapon_kind = "arm_blade"
			frame_count = 8
			grid_rows = 2
		PlayerCharacterRuntime.COMMANDO:
			idle_key = "commando_player_idle_sheet"
			attack_key = "commando_player_pistol_fire_sheet"
			fallback_attack_key = "commando_player_attack_sheet"
			motion_kind = "commando_pistol_fire"
			weapon_kind = "firearm"
			frame_count = 8
			grid_rows = 2
		PlayerCharacterRuntime.OPTIMUS:
			idle_key = "optimus_player_idle_sheet"
			attack_key = ""
			fallback_attack_key = ""
			motion_kind = "optimus_idle_tween"
			weapon_kind = "energy_paddle"
			frame_count = 8
			grid_rows = 2
		PlayerCharacterRuntime.BLACKSMITH:
			idle_key = "blacksmith_player_idle_sheet"
			attack_key = "blacksmith_player_attack_right_sheet"
			fallback_attack_key = ""
			weapon_kind = "hammer"
			frame_count = 16
			grid_rows = 4
			draw_size = Vector2(128.0, 128.0)
	var idle_texture: Variant = texture_cache.get(idle_key, null)
	var attack_texture: Variant = texture_cache.get(attack_key, null) if not attack_key.is_empty() else null
	var source_key := attack_key
	if not (attack_texture is Texture2D) and not fallback_attack_key.is_empty():
		attack_texture = texture_cache.get(fallback_attack_key, null)
		if attack_texture is Texture2D:
			source_key = fallback_attack_key
			if character_type == PlayerCharacterRuntime.SMASHER:
				motion_kind = "smasher_legacy_attack"
				frame_count = 8
				grid_rows = 2
			elif character_type == PlayerCharacterRuntime.COMMANDO:
				motion_kind = "commando_attack_fallback"
	var asset_present := (
		idle_texture is Texture2D
		if character_type == PlayerCharacterRuntime.OPTIMUS
		else attack_texture is Texture2D
	)
	return {
		"motion_kind": motion_kind,
		"weapon_kind": weapon_kind,
		"sprite_source_key": idle_key if character_type == PlayerCharacterRuntime.OPTIMUS else source_key,
		"idle_texture": idle_texture,
		"attack_texture": attack_texture,
		"asset_present": asset_present,
		"frame_count": frame_count,
		"grid_cols": 4,
		"grid_rows": grid_rows,
		"draw_size": draw_size,
		"attack_duration_msec": (
			OPTIMUS_APPROACH_MSEC + OPTIMUS_RETURN_MSEC
			if character_type == PlayerCharacterRuntime.OPTIMUS
			else SHEET_ATTACK_DURATION_MSEC
		),
	}


func _local_timeline_msec(elapsed_msec: int) -> int:
	var contact_msec := _contact_msec()
	if elapsed_msec <= contact_msec:
		return elapsed_msec
	if elapsed_msec < contact_msec + HITSTOP_MSEC:
		return contact_msec
	return elapsed_msec - HITSTOP_MSEC


func _contact_msec() -> int:
	return (
		OPTIMUS_APPROACH_MSEC
		if _character_type == PlayerCharacterRuntime.OPTIMUS
		else SHEET_CONTACT_MSEC
	)


func _total_wall_msec() -> int:
	var local_end := _contact_msec() + DUMMY_REACTION_MSEC
	if not _message_text.is_empty():
		local_end = maxi(
			local_end,
			_contact_msec() + MESSAGE_DELAY_AFTER_CONTACT_MSEC + MESSAGE_EFFECT_MSEC
		)
	if _character_type != PlayerCharacterRuntime.OPTIMUS:
		local_end = maxi(local_end, SHEET_ATTACK_DURATION_MSEC)
	else:
		local_end = maxi(local_end, OPTIMUS_APPROACH_MSEC + OPTIMUS_RETURN_MSEC)
	return _prelude_hitstop_msec() + _strike_lead_msec() + local_end + HITSTOP_MSEC


func _prelude_hitstop_msec() -> int:
	return (
		CRITICAL_PRELUDE_HITSTOP_MSEC
		if _judgment_kind == TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL
		else 0
	)


func _strike_lead_msec() -> int:
	return (
		CRITICAL_AURA_LEAD_MSEC
		if _judgment_kind == TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL
		else 0
	)


func _contact_wall_msec() -> int:
	return _prelude_hitstop_msec() + _strike_lead_msec() + _contact_msec()


func _character_offset_x(local_msec: int, strike_active: bool) -> float:
	if not strike_active:
		return 0.0
	if _character_type != PlayerCharacterRuntime.OPTIMUS:
		return 0.0
	if local_msec <= OPTIMUS_APPROACH_MSEC:
		return OPTIMUS_LUNGE_PX * _ease_out_cubic(
			clampf(float(local_msec) / float(OPTIMUS_APPROACH_MSEC), 0.0, 1.0)
		)
	var return_progress := clampf(
		float(local_msec - OPTIMUS_APPROACH_MSEC) / float(OPTIMUS_RETURN_MSEC),
		0.0,
		1.0
	)
	return OPTIMUS_LUNGE_PX * (1.0 - _ease_in_out_sine(return_progress))


func _dummy_rotation_degrees(dummy_elapsed_msec: int) -> float:
	if dummy_elapsed_msec <= 0:
		return 0.0
	var away_degrees := DUMMY_AWAY_DEGREES
	var rebound_degrees := DUMMY_REBOUND_DEGREES
	match _judgment_kind:
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_CRITICAL:
			away_degrees = 12.0
			rebound_degrees = -3.0
		TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE:
			away_degrees = 3.5
			rebound_degrees = -1.0
	if dummy_elapsed_msec < DUMMY_AWAY_MSEC:
		return lerpf(
			0.0,
			away_degrees,
			_ease_out_cubic(float(dummy_elapsed_msec) / float(DUMMY_AWAY_MSEC))
		)
	if dummy_elapsed_msec < DUMMY_AWAY_MSEC + DUMMY_REBOUND_MSEC:
		return lerpf(
			away_degrees,
			rebound_degrees,
			_ease_in_out_sine(
				float(dummy_elapsed_msec - DUMMY_AWAY_MSEC) / float(DUMMY_REBOUND_MSEC)
			)
		)
	if dummy_elapsed_msec < DUMMY_REACTION_MSEC:
		return lerpf(
			rebound_degrees,
			0.0,
			_ease_out_cubic(
				float(dummy_elapsed_msec - DUMMY_AWAY_MSEC - DUMMY_REBOUND_MSEC)
				/ float(DUMMY_RETURN_MSEC)
			)
		)
	return 0.0


func _stage_shake_offset(elapsed_msec: int, strike_active: bool) -> Vector2:
	if not strike_active:
		return Vector2.ZERO
	var shake_elapsed := elapsed_msec - _contact_msec()
	if shake_elapsed < 0 or shake_elapsed >= STAGE_SHAKE_MSEC:
		return Vector2.ZERO
	var progress := float(shake_elapsed) / float(STAGE_SHAKE_MSEC)
	var strength := 1.0
	if _judgment_kind == TowerTrainingTimingJudgmentPolicy.JUDGMENT_GREAT:
		strength = 0.68
	elif _judgment_kind == TowerTrainingTimingJudgmentPolicy.JUDGMENT_BASE:
		strength = 0.36
	var amplitude := STAGE_SHAKE_MAX_PX * strength * pow(1.0 - progress, 2.0)
	var angle := progress * TAU * 2.25
	return Vector2(cos(angle), sin(angle)) * amplitude


func _emit_contact_audio() -> void:
	_contact_audio_emitted = true
	_contact_event_count += 1
	if _audio != null:
		if _audio.has_method("play_training_strike_hit"):
			_audio.call("play_training_strike_hit", PADDLE_HIT_AUDIO_SOURCE_X)
			_audio_active = true
		elif _audio.has_method("play_paddle_hit"):
			_audio.call("play_paddle_hit", PADDLE_HIT_AUDIO_SOURCE_X)
			_audio_active = true


func _stop_audio() -> void:
	if _audio != null:
		if _audio.has_method("stop_training_strike_audio"):
			_audio.call("stop_training_strike_audio")
		elif _audio.has_method("stop_paddle_hit"):
			_audio.call("stop_paddle_hit")
	_audio_active = false


func set_presentation_rng_for_tests(seed_value: int, preconsume_count: int = 0) -> void:
	_presentation_rng_seed_override = seed_value
	_presentation_rng_preconsume_for_tests = maxi(0, preconsume_count)


func _prepare_presentation_rolls() -> void:
	# Presentation randomness is click-owned and retained for the whole strike.
	# It never reads or writes Tower's authoritative gameplay RNG state.
	_presentation_rng = RandomNumberGenerator.new()
	var seed_value := _presentation_rng_seed_override
	if seed_value == 0:
		seed_value = absi(hash("%s:%d:%d" % [
			_character_type,
			_started_msec,
			_start_count,
		]))
	if seed_value == 0:
		seed_value = 140913
	_presentation_rng.seed = seed_value
	_presentation_rng_roll_count = 0
	for _index in range(_presentation_rng_preconsume_for_tests):
		_presentation_rng.randf()
		_presentation_rng_roll_count += 1
	_impact_directions.clear()
	for base_angle in [-2.94, -2.35, -1.45, -0.65]:
		var angle := float(base_angle) + _presentation_rng.randf_range(-0.14, 0.14)
		_presentation_rng_roll_count += 1
		_impact_directions.append(Vector2.from_angle(angle))
	_impact_point_offsets.clear()
	for base_offset in [
		Vector2(-19.0, -12.0),
		Vector2(15.0, -22.0),
		Vector2(24.0, 7.0),
	]:
		var jitter := Vector2(
			_presentation_rng.randf_range(-3.0, 3.0),
			_presentation_rng.randf_range(-3.0, 3.0)
		)
		_presentation_rng_roll_count += 2
		_impact_point_offsets.append((base_offset as Vector2) + jitter)


func _clear_presentation_rolls() -> void:
	_presentation_rng = null
	_presentation_rng_roll_count = 0
	_impact_directions.clear()
	_impact_point_offsets.clear()


func _now_msec() -> int:
	return _clock_override_msec if _clock_override_msec >= 0 else Time.get_ticks_msec()


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in_out_sine(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return -(cos(PI * t) - 1.0) * 0.5
