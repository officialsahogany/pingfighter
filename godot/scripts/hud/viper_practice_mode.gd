extends RefCounted
# 바이퍼(테스트/주니어리그) 연습모드 튜토리얼 — 상태머신 코어 (Slice 1).
# 진입 시 정지된 공을 쉐도우 백스텝으로 맞추고 마샬킥까지 연계 성공해야 본게임에
# 진입한다(무한 재시도, 스킵 없음 — D1). 이 모듈은 순수 로직만 소유한다:
#   - viper_skill_runtime.get_snapshot() 폴링으로 콤보 전이 감지
#     (shadow_hit_consumed 상승엣지 → marshal_ball_hit 상승엣지)
#   - wants_ball_hold() / has_completed_required_tutorials() desired-action 인터페이스
# 공 소유형 홀드(skip_ball_motion_step)와 라운드 게이트는 후속 슬라이스(S2/S4/S5)가
# 이 인터페이스를 소비한다. SSOT: docs/viper_practice_mode_slice_plan.md.
#
# 엣지 감지 트랩: shadow_hit_consumed / marshal_ball_hit 는 재캐스트마다 리셋되는
# 래치라서, 페이즈 진입 시 이전값을 true로 오염시켜(poison) "false를 한 번 관찰한 뒤의
# false→true"만 전이로 인정한다. 이전 시도의 잔여 true가 즉시 재전이시키는 것을 막는다.

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneConfig := preload("res://scripts/core/battle_scene_config.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const TutorialHintKeycapRenderer := preload("res://scripts/hud/tutorial_hint_keycap_renderer.gd")

const PHASE_INACTIVE := "inactive"
const PHASE_AWAIT_SHADOW := "await_shadow"
const PHASE_AWAIT_MARSHAL := "await_marshal"
const PHASE_COMPLETE := "complete"

# 마샬킥 연계 시도 제한시간: 쉐백 명중 후 이 시간 안에 마샬킥이 착지하지 않으면
# (윈도우 만료 90f=1.5s + 시전/비행 여유) 재시도로 되돌린다.
const MARSHAL_ATTEMPT_TIMEOUT_SECONDS := 8.0

# 정지공 홀드 위치: "지상" 쉐도우 백스텝으로 반드시 닿는 높이(라이브 QA 2회 하향
# 545→620→685). 지상 캐스트의 웨이브/홀로그램 히트 밴드는 패들 중심 y=725
# (PLAYER_Y 700 + 패들높이/2)에서 수평 이동하며 웨이브 밴드는 y 680~770 —
# 620은 46px 미달로 공중 캐스트를 강제했다. 685는 공 rect(671~699)가 밴드와
# 19px 겹치고 패들 라인(700) 위에 머문다. 재튜닝 시
# viper_practice_mode_smoke._verify_ground_shadow_step_reach 씰이 지상 도달성을 지킨다.
const HOLD_BALL_POS := Vector2(380.0, 685.0)
const HOLD_COLLISION_COOLDOWN_FRAMES := 6.0

const FADE_SECONDS := 0.65
const FONT_SIZE := 24
const MIN_FONT_SIZE := 18

# 주의: 연결자로 "→"를 쓰면 키캡 토크나이저가 방향키 키캡으로 렌더하므로 단어를 쓴다.
const SHADOW_MESSAGE := "A / D 이동 중 S ( 대쉬 ) 후 다시 S - 쉐도우 백스텝으로 공 맞추기"
const MARSHAL_MESSAGE := "이어서 S - 마샬킥 연계!"
const SHADOW_MESSAGE_KEY := "tutorial.viper.practice.shadow.keyboard"
const MARSHAL_MESSAGE_KEY := "tutorial.viper.practice.marshal.keyboard"
const SHADOW_GAMEPAD_MESSAGE_KEY := "tutorial.viper.practice.shadow.gamepad"
const MARSHAL_GAMEPAD_MESSAGE_KEY := "tutorial.viper.practice.marshal.gamepad"

var _character_runtime: Object = PlayerCharacterRuntime.new()
var _phase := PHASE_INACTIVE
var _completed := false
var _grip_style := ""
var _last_language := ""
var _marshal_attempt_elapsed := 0.0
var _retry_count := 0
# 래치 오염 방지용 이전 프레임 값(페이즈 진입 시 true로 poison).
var _prev_shadow_hit := true
var _prev_marshal_hit := true
# 공 소유형 홀드 토큰: 이번 어템트에서 skip_ball_motion_step 을 우리가 올렸는지.
var _hold_owned := false
# 안내 문구 페이드인 시계(페이즈 진입마다 리셋).
var _phase_fade_elapsed := 0.0


func update(delta: float, owner: Object, registry: Object = null, module_getter: Callable = Callable()) -> bool:
	var changed: bool = _refresh_language_state()
	if is_active():
		# 연습 중에는 서브 플로우를 계속 잠근다. 득점/리셋 경로(reset_round_wait)가
		# waiting_for_serve 를 되살려도 다음 프레임에 재차 내려 연습 도중 서브가
		# 절대 발사되지 않게 한다(S4). 완료 후에는 건드리지 않는다 — 마샬킥이 발사한
		# 공으로 랠리가 이미 라이브이고, 이후 첫 득점의 정상 리셋이 서브를 복원한다.
		_hold_round_serve(registry)
		_sustain_practice_resources(owner, registry)
		_phase_fade_elapsed += max(0.0, delta)
	match _phase:
		PHASE_INACTIVE:
			return _update_inactive(owner, module_getter) or changed
		PHASE_AWAIT_SHADOW:
			return _update_await_shadow(owner, registry) or changed
		PHASE_AWAIT_MARSHAL:
			return _update_await_marshal(delta, owner, registry) or changed
	return changed


func draw(canvas: CanvasItem, _owner: Object, _registry: Object, view_size: Vector2) -> void:
	if canvas == null or not is_active():
		return
	var alpha: float = get_alpha()
	if alpha <= 0.001:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var message: String = get_message()
	if message == "":
		return
	var font_size: int = TutorialHintKeycapRenderer.fit_font_size(font, message, view_size.x - 48.0, FONT_SIZE, MIN_FONT_SIZE)
	TutorialHintKeycapRenderer.draw_centered_line(canvas, font, message, get_draw_center(view_size), font_size, alpha)


func get_draw_center(view_size: Vector2) -> Vector2:
	# 홀드된 공(게임 y≈545/750)과 마샬 비행 경로를 피해 중앙보다 약간 위에 띄운다.
	return Vector2(view_size.x * 0.5, view_size.y * 0.42)


func get_alpha() -> float:
	if not is_active():
		return 0.0
	# 성공할 때까지 유지되는 안내라 페이드아웃은 없다(페이즈 전환 시 다시 페이드인).
	if _phase_fade_elapsed < FADE_SECONDS:
		return _smooth_step(_phase_fade_elapsed / FADE_SECONDS)
	return 1.0


func is_active() -> bool:
	return _phase == PHASE_AWAIT_SHADOW or _phase == PHASE_AWAIT_MARSHAL


# 공 소유형 홀드 슬라이스(S2)가 소비: AWAIT_SHADOW 동안만 공을 정지 홀드한다.
# AWAIT_MARSHAL은 쉐백이 공을 발사한 라이브 구간이라 홀드하지 않는다.
func wants_ball_hold() -> bool:
	return _phase == PHASE_AWAIT_SHADOW


# 아이템/캐릭터정보 안내의 캐릭터별 중간튜토리얼 게이트가 소비(S6).
func has_completed_required_tutorials() -> bool:
	return _completed


# 공 상실 인터셉트 슬라이스(S5)가 호출: AWAIT_MARSHAL 중 공이 바닥/득점 경로로
# 빠지면 점수 대신 재시도로 되돌린다.
func notify_ball_lost() -> bool:
	if _phase != PHASE_AWAIT_MARSHAL:
		return false
	_begin_await_shadow(true)
	return true


func get_message() -> String:
	var gamepad: bool = _grip_style == "gamepad"
	match _phase:
		PHASE_AWAIT_SHADOW:
			return LanguageSettings.translate(SHADOW_GAMEPAD_MESSAGE_KEY, "이동 중 B ( 대쉬 ) 후 A / X - 쉐도우 백스텝으로 공 맞추기") if gamepad else LanguageSettings.translate(SHADOW_MESSAGE_KEY, SHADOW_MESSAGE)
		PHASE_AWAIT_MARSHAL:
			return LanguageSettings.translate(MARSHAL_GAMEPAD_MESSAGE_KEY, "이어서 A / X - 마샬킥 연계!") if gamepad else LanguageSettings.translate(MARSHAL_MESSAGE_KEY, MARSHAL_MESSAGE)
	return ""


func get_snapshot() -> Dictionary:
	return {
		"phase": _phase,
		"active": is_active(),
		"completed": _completed,
		"wants_ball_hold": wants_ball_hold(),
		"message": get_message(),
		"grip_style": _grip_style,
		"retry_count": _retry_count,
		"marshal_attempt_elapsed": _marshal_attempt_elapsed,
		"alpha": get_alpha(),
	}


func _update_inactive(owner: Object, module_getter: Callable) -> bool:
	if _completed:
		return false
	if not _prerequisites_met(owner):
		return false
	# 기본 조작 안내 체인(이동→대쉬→체공)이 끝난 뒤에만 시작한다. 체공 안내가
	# 대쉬 완료를 자기 게이트로 갖고 있어, 여기서는 체공 완료 하나만 본다.
	if not _is_jetpack_tutorial_complete(module_getter):
		return false
	_grip_style = _get_grip_style(owner)
	if _grip_style == "":
		return false
	_begin_await_shadow(false)
	return true


# 체공 안내(viper_jetpack_tutorial_hint) 완료 게이트. 모듈이 없는 환경(테스트
# 픽스처)에서는 대기하지 않는다 — 실게임에서는 카탈로그에 항상 등록돼 있다.
func _is_jetpack_tutorial_complete(module_getter: Callable) -> bool:
	var jetpack_hint: Object = _get_module(module_getter, "viper_jetpack_tutorial_hint")
	if jetpack_hint == null or not jetpack_hint.has_method("has_completed_jetpack_tutorial"):
		return true
	return bool(jetpack_hint.has_completed_jetpack_tutorial())


func _get_module(module_getter: Callable, key: String) -> Object:
	if not module_getter.is_valid():
		return null
	var value: Variant = module_getter.call(key)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _update_await_shadow(owner: Object, registry: Object) -> bool:
	_grip_style = _get_grip_style(owner)
	_stage_held_ball(owner)
	var snapshot: Dictionary = _get_skill_snapshot(registry)
	if snapshot.is_empty():
		return false
	return _observe_skill_flags(
		bool(snapshot.get("shadow_hit_consumed", false)),
		bool(snapshot.get("marshal_ball_hit", false))
	)


func _update_await_marshal(delta: float, owner: Object, registry: Object) -> bool:
	_grip_style = _get_grip_style(owner)
	var snapshot: Dictionary = _get_skill_snapshot(registry)
	if not snapshot.is_empty():
		if _observe_skill_flags(
			bool(snapshot.get("shadow_hit_consumed", false)),
			bool(snapshot.get("marshal_ball_hit", false))
		):
			return true
	_marshal_attempt_elapsed += max(0.0, delta)
	if _marshal_attempt_elapsed >= MARSHAL_ATTEMPT_TIMEOUT_SECONDS:
		_begin_await_shadow(true)
		return true
	return false


# 콤보 래치 관찰(엣지 감지 + 페이즈 전이)의 단일 소유자. HUD 업데이트(스냅샷)와
# 공 경로(라이브 멤버, apply_ball_hold_motion)가 같은 prev 래치를 공유하므로 한
# 프레임에 양쪽이 호출돼도 두 번째 호출은 엣지가 없어 안전하다. 공 경로가 먼저
# 관찰하면 히트 프레임의 동일-프레임 홀드 해제가 보장된다(HUD 폴링 레이스 차단).
func _observe_skill_flags(shadow_hit: bool, marshal_hit: bool) -> bool:
	match _phase:
		PHASE_AWAIT_SHADOW:
			var shadow_edge: bool = shadow_hit and not _prev_shadow_hit
			_prev_shadow_hit = shadow_hit
			if shadow_edge:
				_begin_await_marshal()
				return true
		PHASE_AWAIT_MARSHAL:
			var marshal_edge: bool = marshal_hit and not _prev_marshal_hit
			_prev_marshal_hit = marshal_hit
			if marshal_edge:
				_phase = PHASE_COMPLETE
				_completed = true
				return true
	return false


# 공 경로 훅 (S2): 바이퍼 모션 패스 직후, skip 단축 평가 전에 매 물리 프레임 호출.
# 반환 dict는 _apply_viper_motion_result 형식. 홀드 중엔 위치 고정 + vel ZERO +
# skip=true 를 매 프레임 재assert(라운드경계 정규화가 skip 을 내려도 자가 복구).
# 쉐백이 이번 프레임에 공을 맞추면(라이브 래치 관찰) 즉시 해제 — skip=false 만
# 내리고 ball_vel 은 건드리지 않아 히트가 쓴 발사 속도를 보존한다(CLAUDE.md
# 공-소유 스킬 해제 규칙: 모든 해제 경로에서 skip=false + 실제 속도).
func apply_ball_hold_motion(_scene: Dictionary, viper_skill_runtime: Object) -> Dictionary:
	if viper_skill_runtime != null:
		var shadow_value: Variant = viper_skill_runtime.get("shadow_hit_consumed")
		var marshal_value: Variant = viper_skill_runtime.get("marshal_ball_hit")
		if shadow_value != null and marshal_value != null:
			_observe_skill_flags(bool(shadow_value), bool(marshal_value))
	if wants_ball_hold():
		_hold_owned = true
		return {
			"ball_pos": HOLD_BALL_POS,
			"ball_vel": Vector2.ZERO,
			"skip_ball_motion_step": true,
			"player_collision_cooldown": HOLD_COLLISION_COOLDOWN_FRAMES,
		}
	if _hold_owned:
		_hold_owned = false
		return {
			"skip_ball_motion_step": false,
			"ball_impact_boost": 1.0,
		}
	return {}


# AWAIT_SHADOW 동안 비활성 공을 홀드 지점에 실체화한다. 공이 비활성이면
# ball_update_controller 가 바이퍼 패스 전에 early-return 하므로(48행 ball_active
# 게이트) 홀드 훅이 돌 수 없다 — HUD 경로에서 1회 staging 해 물리 경로를 연다.
# ball_active 가 true 인 동안은 물리 경로(홀드 훅)가 단독 소유자라 겹쳐 쓰지 않는다.
func _stage_held_ball(owner: Object) -> void:
	if owner == null:
		return
	if bool(BattleSceneOwnerReader.get_value(owner, "ball_active", false)):
		return
	owner.set("ball_pos", HOLD_BALL_POS)
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", true)


func _begin_await_shadow(is_retry: bool) -> void:
	_phase = PHASE_AWAIT_SHADOW
	_marshal_attempt_elapsed = 0.0
	_phase_fade_elapsed = 0.0
	# 래치 poison: 이전 시도의 잔여 true로 즉시 재전이하지 않도록 true에서 시작.
	_prev_shadow_hit = true
	if is_retry:
		_retry_count += 1


func _begin_await_marshal() -> void:
	_phase = PHASE_AWAIT_MARSHAL
	_marshal_attempt_elapsed = 0.0
	_phase_fade_elapsed = 0.0
	_prev_marshal_hit = true


# 연습 자원 유지(라이브 QA 피드백): 성공 전까지 게이지를 항상 최대(500)로 채우고,
# 쉐도우 백스텝/마샬킥 쿨타임을 0으로 유지해 무한 재시도를 막지 않는다. 다른 스킬
# 쿨타임은 건드리지 않으며, 완료 후에는 정상 게이지/쿨타임 규칙으로 복귀한다
# (마지막 시전의 쿨타임은 본게임에 자연스럽게 남는다).
func _sustain_practice_resources(owner: Object, registry: Object) -> void:
	if owner != null:
		owner.set("special_gauge", float(BattleSceneOwnerReader.get_value(owner, "special_gauge_max", 500.0)))
	if registry == null or not registry.has_method("get_instance"):
		return
	var skill_state: Variant = registry.get_instance("viper_skill_state")
	if typeof(skill_state) != TYPE_OBJECT or not is_instance_valid(skill_state):
		return
	# cooldowns 는 스킬명 키 Dictionary(레퍼런스) — 연습 대상 두 스킬만 지운다.
	var cooldowns: Variant = (skill_state as Object).get("cooldowns")
	if cooldowns is Dictionary:
		(cooldowns as Dictionary).erase("shadow_step")
		(cooldowns as Dictionary).erase("marshal_kick")


# S4: 연습 중 서브 플로우 잠금. pause_serve_for_intro 는 waiting_for_serve 플래그와
# 서브 타이머만 내리는 순수 상태 리셋이라 매 프레임 재호출이 안전하다.
func _hold_round_serve(registry: Object) -> void:
	if registry == null or not registry.has_method("get_instance"):
		return
	var round_state: Variant = registry.get_instance("round_flow_state")
	if typeof(round_state) != TYPE_OBJECT or not is_instance_valid(round_state):
		return
	var round_object: Object = round_state as Object
	if not round_object.has_method("is_waiting_for_serve") or not round_object.has_method("pause_serve_for_intro"):
		return
	if bool(round_object.is_waiting_for_serve()):
		round_object.pause_serve_for_intro()


func _smooth_step(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _prerequisites_met(owner: Object) -> bool:
	if owner == null:
		return false
	return (
		BattleSceneConfig.normalize_league_mode(
			str(BattleSceneOwnerReader.get_value(owner, "ai_mode", "champion"))
		) == "junior"
		and _character_runtime.is_viper(BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher"))
		and _get_grip_style(owner) != ""
	)


func _get_skill_snapshot(registry: Object) -> Dictionary:
	if registry == null or not registry.has_method("get_instance"):
		return {}
	var runtime: Variant = registry.get_instance("viper_skill_runtime")
	if typeof(runtime) != TYPE_OBJECT or not is_instance_valid(runtime):
		return {}
	if not (runtime as Object).has_method("get_snapshot"):
		return {}
	var snapshot: Variant = (runtime as Object).get_snapshot()
	if snapshot is Dictionary:
		return snapshot
	return {}


func _get_grip_style(owner: Object) -> String:
	if owner == null:
		return ""
	for key in ["tutorial_grip_style", "junior_mika_grip_style"]:
		if owner.has_meta(key):
			var normalized: String = _normalize_grip_style(str(owner.get_meta(key)))
			if normalized != "":
				return normalized
	return ""


func _normalize_grip_style(value: String) -> String:
	var normalized := value.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized in ["wasd_mouse", "wasd", "keyboard_mouse"]:
		return "wasd_mouse"
	if normalized in ["space_arrows", "space_arrow", "arrows", "arrow_keys", "arrows_space"]:
		return "space_arrows"
	if normalized in ["gamepad", "xbox", "controller", "pad"]:
		return "gamepad"
	return ""


func _refresh_language_state() -> bool:
	var language := LanguageSettings.get_language()
	if language == _last_language:
		return false
	_last_language = language
	return is_active()
