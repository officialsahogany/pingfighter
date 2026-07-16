extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
# 오버레이 FX 호스트는 detached 노드라 상태 전이가 스스로에게 전파되지
# 않는다 — 모든 스코어/스테이지/장착 경계 전이가 정적 hide_all()로 직접
# 숨긴다(pending/미부착 호스트까지 정적 _live_hosts 리스트가 커버).
const OdinsEyePresentationFxHost := preload("res://scripts/items/odins_eye_presentation_fx_host.gd")
# 잔상 이동 intent는 선택 캐릭터의 실제 입력 리더에서 읽는다 — 스매셔 키로
# 고정하면 Viper/Commando/Blacksmith 변신에서 이동 잔상이 영구 불발된다.
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

# 잔상 실경로 계약(legendary_items.py 원본): 하강 공 반사 히트 반경(공
# 지름 28.6의 절반), 반사 게이지 +50(캡). 10px 최소이동·6f 간격 게이트는
# afterimage_state.create_afterimage가 소유한다.
const AFTERIMAGE_BALL_RADIUS_PX := 14.3
const AFTERIMAGE_REFLECT_GAUGE_GAIN := 50.0
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_ODINS_EYE := "odins_eye"
const ROLL_REVIVAL_CHANCE := "revival_chance"


func sync_equipment_state(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return
	state.set_equipped(is_active(runtime))


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_ODINS_EYE)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func is_available(runtime: Object) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	return state != null and state.can_revive(is_active(runtime))


func has_revival_used(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and bool(state.revival_used)


func is_penalty_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and bool(state.penalty_active)


func is_transformed(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_transformed()


func is_skills_locked(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_skills_locked()


func is_control_locked(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_control_locked()


func is_revival_animation_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_revival_animation_active()


func is_death_animation_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_death_animation_active()


func is_effect_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_effect_active()


func get_revival_chance_pct(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, ROLL_REVIVAL_CHANCE)
	var item_data: Dictionary = _get_equipped_item_data(runtime)
	if item_data.is_empty():
		return runtime.catalog.get_default_roll_value(ITEM_ODINS_EYE, ROLL_REVIVAL_CHANCE)
	return runtime.roll_query.get_item_roll_value(
		runtime,
		item_data,
		ITEM_ODINS_EYE,
		ROLL_REVIVAL_CHANCE,
		true
	)


func get_revival_chance(runtime: Object) -> float:
	return clamp(get_revival_chance_pct(runtime) / 100.0, 0.0, 1.0)


func try_trigger_revival(runtime: Object, loss_type: String = "round", roll_pct: float = -1.0) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	if state == null or not state.can_revive(is_active(runtime)):
		return false
	var actual_roll: float = roll_pct if roll_pct >= 0.0 else randf() * 100.0
	var chance_pct: float = get_revival_chance_pct(runtime)
	var triggered: bool = actual_roll <= chance_pct
	state.record_roll(actual_roll, triggered)
	if not triggered:
		return false
	# 실 라이브 무장값은 이 호출이 결정한다 — 리터럴을 두면 state 상수와
	# 드리프트하므로 반드시 상수를 참조한다(3.0 하드코딩이 3.75 재타이밍을
	# 무효화했던 회귀 클래스).
	state.begin_revival(loss_type, state.REVIVAL_EVENT_SEC, actual_roll)
	return true


func begin_death_sequence(runtime: Object, loss_type: String = "round") -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	if state == null or not state.penalty_active:
		return false
	state.begin_death_sequence(loss_type)
	return true


func consume_revival_finalize_ready(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_revival_finalize_ready()


func consume_death_finalize_ready(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_death_finalize_ready()


func consume_death_explosion_edge(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_death_explosion_edge()


func consume_disintegration_edge(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_disintegration_edge()


func clear_after_victory(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.clear_after_victory()
	_clear_afterimage_state(runtime)
	OdinsEyePresentationFxHost.hide_all()


func clear_after_death(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.clear_after_death()
	_clear_afterimage_state(runtime)
	OdinsEyePresentationFxHost.hide_all()


func get_move_speed_multiplier(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 1.0 if state == null else state.get_move_speed_multiplier()


func get_dash_token_limit_override(runtime: Object) -> Variant:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return null
	return state.get_dash_token_limit_override()


func get_dash_cooldown_multiplier(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 1.0 if state == null else state.get_dash_cooldown_multiplier()


func get_death_phase(runtime: Object) -> String:
	var state: Object = runtime.odins_eye_state
	return "" if state == null else state.get_death_phase()


func get_death_overall_progress(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_overall_progress()


func get_death_phase_progress(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_phase_progress()


func get_death_energy_buildup(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_energy_buildup()


func get_death_disintegrate_progress(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_disintegrate_progress()


# 부활·사망 시네마틱 화면흔들림 곡선의 단일 소비 지점(px). effects 경로의
# battle_effects_update_controller가 feedback.update 직후 fixed offset으로
# 민다 — mythic 틱에서 밀면 같은 프레임의 feedback.update 리셋에 지워진다.
func get_cinematic_shake_intensity(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return 0.0
	return maxf(
		float(state.get_revival_shake_intensity()),
		float(state.get_death_shake_intensity())
	)


func get_death_shake_intensity(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_shake_intensity()


func should_hide_player_paddle(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.should_hide_player_paddle()


func get_context(runtime: Object) -> Dictionary:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	if state == null:
		return {"equipped": false, "active": false, "state": "idle"}
	var context: Dictionary = state.get_context()
	context["revival_chance_pct"] = get_revival_chance_pct(runtime)
	context["revival_chance"] = get_revival_chance(runtime)
	# 잔상/다이브 payload는 중첩 "afterimage" 키로 관통한다 — 렌더러의
	# 오버레이 활성 판정·다이브 비주얼(지하 비가시)·상시 입자가 이 키를
	# 소비한다.
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	if afterimage_state != null:
		context["afterimage"] = afterimage_state.get_context()
	return context


func clear_on_equip(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.set_equipped(is_active(runtime))
		state.on_stage_advance()


func clear_on_unequip(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.set_equipped(false)
	_clear_afterimage_state(runtime)
	# owner-null cancel 계약: unequip은 owner 없이도 호스트를 직접 숨긴다.
	OdinsEyePresentationFxHost.hide_all()


func reset(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.reset_all()
	_clear_afterimage_state(runtime)
	OdinsEyePresentationFxHost.hide_all()


func reset_round(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.reset_round()
	# Python parity: go_to_next_round가 잔상을, reset_for_new_round가 다이브
	# 잔여물을 함께 지운다.
	if runtime.odins_eye_afterimage_state != null:
		runtime.odins_eye_afterimage_state.reset_round()
	OdinsEyePresentationFxHost.hide_all()


func on_stage_advance(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return
	sync_equipment_state(runtime)
	state.on_stage_advance()
	_clear_afterimage_state(runtime)
	OdinsEyePresentationFxHost.hide_all()


func clear_runtime(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.on_stage_advance()
	_clear_afterimage_state(runtime)
	OdinsEyePresentationFxHost.hide_all()


func _clear_afterimage_state(runtime: Object) -> void:
	if runtime.odins_eye_afterimage_state != null:
		runtime.odins_eye_afterimage_state.clear_all()


func update_runtime(runtime: Object, fps_scale: float, owner: Object = null, registry: Object = null) -> bool:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return false
	var advanced: bool = state.update(max(0.0, fps_scale) / 60.0)
	_update_afterimage_runtime(runtime, fps_scale, owner, registry)
	return advanced


# 잔상/다이브 실경로 틱: 이동 intent+실 위치 델타로 잔상을 스폰하고, 하강
# 공×잔상 반사를 owner ball_vel에 되돌리며(랠리 등록·게이지 +50·odinshadow),
# 대쉬 에지는 공유 dash state를 레지스트리 peek으로 관찰한다(신화 틱이
# 플레이어 컨트롤보다 먼저라 1프레임 지연 — 수용된 계약). 부활/사망
# 시네마틱 중에는 다이브가 취소되고 스폰이 멈춘다.
func _update_afterimage_runtime(runtime: Object, fps_scale: float, owner: Object, registry: Object) -> void:
	var state: Object = runtime.odins_eye_state
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	if state == null or afterimage_state == null or owner == null:
		return
	# 신화 모달 pause(획득 시네마틱 등) 중에는 스폰·틱·반사 전부 동결 —
	# 모달 동안 잔상이 쌓이거나 공이 반사되면 재개 프레임에 유령 입력이 된다.
	if runtime.pause_gate != null and runtime.pause_gate.has_method("should_pause_game") and bool(runtime.pause_gate.should_pause_game(runtime)):
		return
	var transformed: bool = bool(state.penalty_active)
	if not transformed and not afterimage_state.has_runtime_update_work():
		return

	var player_pos: Vector2 = _as_vector2(owner.get("player_pos"))
	var paddle_size: Vector2 = _as_vector2_or(owner.get("player_paddle_size"), Vector2(155.0, 50.0))
	var player_center: Vector2 = player_pos + paddle_size * 0.5
	# 이동 판정은 입력 intent만 — 10px 최소이동·6f 간격 게이트는 state의
	# create_afterimage(last_afterimage_pos·spawn cooldown)가 소유한다.
	# 여기서 위치 델타를 이중으로 걸면 첫 스폰이 한 틱 밀린다.
	var movement_intent: bool = false
	var input_reader_key: String = _character_runtime.get_input_reader_key(owner.get("selected_character_type"))
	var input_reader: Object = _peek_registry_instance(registry, input_reader_key)
	if input_reader != null and input_reader.has_method("get_snapshot"):
		var input_snapshot: Dictionary = input_reader.get_snapshot()
		movement_intent = bool(input_snapshot.get("left_pressed", false)) or bool(input_snapshot.get("right_pressed", false))
	var moving: bool = transformed and movement_intent

	var dash_active: bool = false
	var dash_state: Object = _peek_registry_instance(registry, "smasher_dash_state")
	if dash_state != null and dash_state.has_method("is_active"):
		dash_active = bool(dash_state.is_active())
	var anim_blocked: bool = state.is_revival_animation_active() or state.is_death_animation_active()

	afterimage_state.update(max(0.0, fps_scale) / 60.0, {
		"player_center": player_center,
		"paddle_width": paddle_size.x,
		"paddle_height": paddle_size.y,
		"moving": moving,
		"dash_active": dash_active and transformed,
		"anim_blocked": anim_blocked,
		"revival_active": state.is_revival_animation_active(),
	})

	# 하강 공만 잔상 반사(원본 계약) — owned-ball/상승 공은 건드리지 않는다.
	if not transformed or anim_blocked:
		return
	var ball_vel: Vector2 = _as_vector2(owner.get("ball_vel"))
	if ball_vel.y <= 0.0:
		return
	var ball_pos: Vector2 = _as_vector2(owner.get("ball_pos"))
	var collision: Dictionary = afterimage_state.check_ball_collision(ball_pos, AFTERIMAGE_BALL_RADIUS_PX, ball_vel)
	if not bool(collision.get("hit", false)):
		return
	owner.set("ball_vel", collision.get("new_velocity", ball_vel))
	var ball_intensity: Object = _peek_registry_instance(registry, "ball_intensity")
	if ball_intensity != null and ball_intensity.has_method("register_contact"):
		ball_intensity.register_contact("odin_afterimage", "player")
	var gauge: float = float(owner.get("special_gauge"))
	var gauge_max: float = float(owner.get("special_gauge_max"))
	owner.set("special_gauge", minf(gauge + AFTERIMAGE_REFLECT_GAUGE_GAIN, gauge_max))
	var audio: Object = _peek_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_odins_eye_shadow"):
		audio.play_odins_eye_shadow()


var _character_runtime: Object = PlayerCharacterRuntime.new()


func _peek_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var value: Variant = registry.get_instance(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _as_vector2_or(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func has_runtime_update_work(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return false
	# 변신(페널티) 유지 중에는 잔상 스폰·반사가 매 프레임 돌아야 하고, 폼이
	# 꺼진 뒤에도 잔상 payload가 남아 있으면 페이드 틱이 남는다 — 시네마틱
	# 플래그만 보면 부활 연출 종료 직후 게이트가 닫혀 잔상 실경로가 죽는다.
	if state.is_transformed():
		return true
	var afterimage_state: Object = runtime.odins_eye_afterimage_state
	if (
		afterimage_state != null
		and afterimage_state.has_method("has_runtime_update_work")
		and bool(afterimage_state.has_runtime_update_work())
	):
		return true
	return (
		state.is_effect_active()
		or state.revival_finalize_ready
		or state.death_finalize_ready
		or state.death_explosion_edge_ready
		or state.death_disintegration_edge_ready
	)


func _get_equipped_item_data(runtime: Object) -> Dictionary:
	if not runtime.equipped_items.has(ITEM_ODINS_EYE):
		return {}
	return runtime._get_dict(runtime.equipped_items[ITEM_ODINS_EYE])


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_ODINS_EYE, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_ODINS_EYE)))
	return 0
