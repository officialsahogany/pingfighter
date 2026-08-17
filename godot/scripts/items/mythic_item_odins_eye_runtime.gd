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
	if state == null or not state.consume_revival_finalize_ready():
		return false
	# 부활 finalize가 페널티 폼을 확정하는 프레임이 어둠의 늪 해금 지점이다 —
	# 연출 종료(타이머 소진)만으로 해금하면 finalize 이전 프레임에 시전이 샌다.
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.enable()
	return true


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
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.clear_after_victory()
	OdinsEyePresentationFxHost.hide_all()


func clear_after_death(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.clear_after_death()
	_clear_afterimage_state(runtime)
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.clear_after_death()
	OdinsEyePresentationFxHost.hide_all()


func get_move_speed_multiplier(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 1.0 if state == null else state.get_move_speed_multiplier()


func get_dash_token_limit_override(runtime: Object) -> Variant:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return null
	return state.get_dash_token_limit_override()


func get_dash_distance_multiplier(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 1.0 if state == null else state.get_dash_distance_multiplier()


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
	# 렌더러의 늪 스핀(_resolve_spin)·가시 드로우가 중첩 "dark_swamp" 키를
	# 소비한다 — 잔상과 같은 중첩-키 관통 계약.
	var dark_swamp: Object = runtime.odins_eye_dark_swamp_state
	if dark_swamp != null:
		context["dark_swamp"] = dark_swamp.get_context(-1.0)
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
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.reset_all()
	# owner-null cancel 계약: unequip은 owner 없이도 호스트를 직접 숨긴다.
	OdinsEyePresentationFxHost.hide_all()


func reset(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.reset_all()
	_clear_afterimage_state(runtime)
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.reset_all()
	OdinsEyePresentationFxHost.hide_all()


func reset_round(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.reset_round()
	# Python parity: go_to_next_round가 잔상을, reset_for_new_round가 다이브
	# 잔여물을 함께 지운다.
	if runtime.odins_eye_afterimage_state != null:
		runtime.odins_eye_afterimage_state.reset_round()
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.reset_round()
	OdinsEyePresentationFxHost.hide_all()


func on_stage_advance(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return
	sync_equipment_state(runtime)
	state.on_stage_advance()
	_clear_afterimage_state(runtime)
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.on_stage_advance()
	OdinsEyePresentationFxHost.hide_all()


func clear_runtime(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.on_stage_advance()
	_clear_afterimage_state(runtime)
	if runtime.odins_eye_dark_swamp_state != null:
		runtime.odins_eye_dark_swamp_state.on_stage_advance()
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
	_update_dark_swamp_runtime(runtime, fps_scale, owner, registry)
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


# 늪 시전 에지의 poll-gap 억제용 물리 프레임 시계. 물리-차단 모달
# (스코어보드/TAB 정보)은 update_mythic_items를 통째로 건너뛰어 리더 에지가
# 스테일해지고, 재개 첫 프레임이 "모달 내내 누르고 있던 버튼"에서 합성
# just-pressed를 만들 수 있다 — 직전 poll과의 프레임 간격이 1을 넘으면 그
# 에지를 버린다(Python은 모달 종료 후 새 MOUSEBUTTONDOWN 이벤트가 없었다).
func _get_input_poll_frame() -> int:
	return int(Engine.get_physics_frames())


# 스턴/넉백 타이머 동결 게이트. active = 극정호신(stage7 state의
# _superspeed_active 단독 소스 — boss_ai의 1-AI페이즈 스테일 미러를 읽으면
# 61회 적용 겹침) OR 살아 있는 보스 대쉬. arm_grace = 좀비 대쉬(극정호신
# 소유 대쉬가 플래그 드랍 후 잔존)면 false — 같은 update에서 AI가 취소·낙하
# 적용하므로 release grace를 남기면 중복 적용이 된다.
func _resolve_boss_gate(registry: Object) -> Dictionary:
	var stage7_state: Object = _peek_registry_instance(registry, "stage7_akamu_state")
	if _object_flag(stage7_state, "_superspeed_active"):
		return {"active": true, "arm_grace": true}
	var boss_ai: Object = _peek_registry_instance(registry, "boss_ai_state")
	if _object_flag(boss_ai, "boss_dash_active"):
		var zombie: bool = (
			_object_flag(boss_ai, "_stage7_superspeed_was_active")
			and not _object_flag(stage7_state, "_superspeed_active")
		)
		return {"active": true, "arm_grace": not zombie}
	return {"active": false, "arm_grace": true}


func _is_boss_dash_gate_active(registry: Object) -> bool:
	return bool(_resolve_boss_gate(registry).get("active", false))


func _is_stage7_escape_freeze_active(registry: Object) -> bool:
	return _object_flag(_peek_registry_instance(registry, "stage7_akamu_state"), "_escape_active")


# Object.get()은 미선언 프로퍼티에 null을 돌려주고 bool(null)은 생성자
# 에러다 — 진성 true만 참으로 취급하는 null-safe 플래그 읽기.
func _object_flag(target: Object, property: String) -> bool:
	if target == null:
		return false
	return target.get(property) == true


# 어둠의 늪 시전: 페널티 폼의 유일한 공격 수단(legendary_items.py 원본 —
# 게이지 100/쿨 2s/좌클릭 전용/스파이크 순차 발사/볼 반사/보스 넉백+스턴).
func try_activate_dark_swamp(runtime: Object, owner: Object, registry: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	var swamp: Object = runtime.odins_eye_dark_swamp_state
	if state == null or swamp == null or owner == null:
		return false
	swamp.set_activation_blocked(state.is_revival_animation_active(), state.is_death_animation_active())
	var gauge: float = float(owner.get("special_gauge"))
	var player_pos: Vector2 = _as_vector2(owner.get("player_pos"))
	var paddle_size := Vector2(
		float(owner.get("player_paddle_width") if owner.get("player_paddle_width") != null else 155.0),
		float(owner.get("player_paddle_height") if owner.get("player_paddle_height") != null else 50.0)
	)
	var boss_pos: Vector2 = _as_vector2(owner.get("boss_pos"))
	var boss_width: float = float(owner.get("boss_paddle_width") if owner.get("boss_paddle_width") != null else 100.0)
	var boss_height: float = float(owner.get("boss_hitbox_height") if owner.get("boss_hitbox_height") != null else 40.0)
	if not swamp.activate(
		player_pos + paddle_size * 0.5,
		boss_pos + Vector2(boss_width, boss_height) * 0.5,
		gauge
	):
		return false
	owner.set("special_gauge", maxf(0.0, gauge - float(swamp.consume_activation_gauge_cost())))
	# 시전 큐는 문서화된 odinshadow 대용 큐(전용 시전음 미보유).
	var audio: Object = _peek_registry_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_odins_eye_shadow"):
		audio.play_odins_eye_shadow()
	var feedback: Object = _peek_registry_instance(registry, "battle_feedback_state")
	if feedback != null and feedback.has_method("trigger_gauge_flash"):
		feedback.trigger_gauge_flash()
	return true


func _update_dark_swamp_runtime(runtime: Object, fps_scale: float, owner: Object, registry: Object) -> void:
	var state: Object = runtime.odins_eye_state
	var swamp: Object = runtime.odins_eye_dark_swamp_state
	if state == null or swamp == null or owner == null:
		return
	# 부활/사망 연출 중 시전 차단 동기화(연출이 몸을 소유하는 동안 늪 금지).
	swamp.set_activation_blocked(state.is_revival_animation_active(), state.is_death_animation_active())
	var paused: bool = (
		runtime.pause_gate != null
		and runtime.pause_gate.has_method("should_pause_game")
		and bool(runtime.pause_gate.should_pause_game(runtime))
	)

	# 시전 에지 리스너: 좌클릭 계열 전용(키보드 Space/X의 action 에지는
	# Python 계약상 시전하지 않는다). poll-gap이 1을 넘으면 물리-차단 모달을
	# 통과한 홀드가 합성한 에지이므로 버린다.
	var poll_frame: int = _get_input_poll_frame()
	var previous_poll_frame: int = int(runtime.odins_eye_dark_swamp_last_poll_frame)
	runtime.odins_eye_dark_swamp_last_poll_frame = poll_frame
	var synthesized_edge: bool = previous_poll_frame >= 0 and poll_frame - previous_poll_frame > 1
	if bool(state.penalty_active) and not paused and not synthesized_edge:
		var input_reader_key: String = _character_runtime.get_input_reader_key(owner.get("selected_character_type"))
		var input_reader: Object = _peek_registry_instance(registry, input_reader_key)
		if input_reader != null and input_reader.has_method("get_snapshot"):
			var input_snapshot: Dictionary = input_reader.get_snapshot()
			var viper_runtime: Object = _peek_registry_instance(registry, "viper_skill_runtime")
			var wall_leap_owns_input := (
				viper_runtime != null
				and viper_runtime.has_method("is_wall_leap_input_owned")
				and bool(viper_runtime.is_wall_leap_input_owned())
			)
			if not wall_leap_owns_input and bool(input_snapshot.get("mouse_left_just_pressed", false)):
				try_activate_dark_swamp(runtime, owner, registry)

	if paused or not swamp.has_runtime_update_work():
		return

	# 벽 스톱(Python 파리티): 벽에 붙은 보스의 잔여 속도가 벽 쪽을 향하면
	# 0으로 — 이후의 대쉬가 보스를 벽에서 떼어내며 스테일 잔여를 재적용하지
	# 못하게 한다. 창(타이머)은 살아남는다.
	if swamp.boss_stun_timer_frames > 0.0 or swamp.boss_knockback_timer_frames > 0.0:
		var boss_x: float = _as_vector2(owner.get("boss_pos")).x
		var wall_boss_width: float = float(owner.get("boss_paddle_width") if owner.get("boss_paddle_width") != null else 100.0)
		var residual: float = float(swamp.boss_knockback_vel)
		if (boss_x <= 0.0 and residual < 0.0) or (boss_x >= 760.0 - wall_boss_width and residual > 0.0):
			swamp.boss_knockback_vel = 0.0

	# 웨이브/스파이크/CC 틱: 대쉬·극정호신 게이트와 영체탈주 전량 동결을
	# state에 전달한다(순차 소비·release grace·감쇠는 state 소유).
	var gate: Dictionary = _resolve_boss_gate(registry)
	swamp.update(
		max(0.0, fps_scale) / 60.0,
		bool(gate.get("active", false)),
		bool(gate.get("arm_grace", true)),
		_is_stage7_escape_freeze_active(registry)
	)
	var audio: Object = _peek_registry_instance(registry, "game_audio")
	if int(swamp.consume_spawned_spike_count()) > 0:
		if audio != null and audio.has_method("play_odins_eye_spirit"):
			audio.play_odins_eye_spirit()

	# 볼 반사: 필드의 늪 가시는 공을 위로 튕긴다(±45° 1.4~1.7× — state 소유).
	if _object_flag(owner, "ball_active"):
		var ball_pos: Vector2 = _as_vector2(owner.get("ball_pos"))
		var ball_vel: Vector2 = _as_vector2(owner.get("ball_vel"))
		var ball_rect := Rect2(ball_pos - Vector2(AFTERIMAGE_BALL_RADIUS_PX, AFTERIMAGE_BALL_RADIUS_PX), Vector2(AFTERIMAGE_BALL_RADIUS_PX * 2.0, AFTERIMAGE_BALL_RADIUS_PX * 2.0))
		var ball_hit: Dictionary = swamp.check_ball_collision(ball_rect, ball_vel)
		if bool(ball_hit.get("hit", false)):
			owner.set("ball_vel", ball_hit.get("new_velocity", ball_vel))
			if audio != null and audio.has_method("play_odins_eye_attack"):
				audio.play_odins_eye_attack()

	# 보스 충돌: 히트 시 CC(넉백 24f+스턴 60f)는 state가 기록하고 boss AI
	# context로 관통한다. 공 비활성이어도 가시는 보스를 때린다. 스테이지2
	# 상태면역 중에는 무장 자체를 거부하고(ragnarok 계약과 동일) 남아 있던
	# 오딘 CC도 정리한다 — 타이머만 남으면 면역 종료 뒤 지연 넉백·스턴이
	# 발동한다.
	var stage2_immune: bool = (
		runtime.stage_immunity != null
		and runtime.stage_immunity.is_stage2_speed_defense_boss_immune(runtime, registry)
	)
	if stage2_immune:
		if swamp.boss_stun_timer_frames > 0.0 or swamp.boss_knockback_timer_frames > 0.0:
			swamp.clear_boss_status()
		return
	var boss_pos: Vector2 = _as_vector2(owner.get("boss_pos"))
	var hit_boss_width: float = float(owner.get("boss_paddle_width") if owner.get("boss_paddle_width") != null else 100.0)
	var hit_boss_height: float = float(owner.get("boss_hitbox_height") if owner.get("boss_hitbox_height") != null else 40.0)
	var boss_hit: Dictionary = swamp.check_boss_collision(Rect2(boss_pos, Vector2(hit_boss_width, hit_boss_height)))
	if bool(boss_hit.get("hit", false)):
		if audio != null and audio.has_method("play_odins_eye_attack"):
			audio.play_odins_eye_attack()


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
	var dark_swamp_state: Object = runtime.odins_eye_dark_swamp_state
	if (
		dark_swamp_state != null
		and dark_swamp_state.has_method("has_runtime_update_work")
		and bool(dark_swamp_state.has_runtime_update_work())
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
