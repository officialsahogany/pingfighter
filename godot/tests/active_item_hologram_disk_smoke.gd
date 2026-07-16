extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemDebugSpawnMenu := preload("res://scripts/items/active_item_debug_spawn_menu.gd")
const ActiveItemEffectRouter := preload("res://scripts/items/active_item_effect_router.gd")
const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemTimerGaugeRenderer := preload("res://scripts/items/active_item_timer_gauge_renderer.gd")
const BossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BallMotionStepper := preload("res://scripts/ball/ball_motion_stepper.gd")
const PaddleBounceController := preload("res://scripts/ball/paddle_bounce_controller.gd")
const PaddleBounceState := preload("res://scripts/ball/paddle_bounce_state.gd")
const ActiveItemRenderFacade := preload("res://scripts/items/active_item_runtime_render_facade.gd")
const ViperPracticeMode := preload("res://scripts/hud/viper_practice_mode.gd")
const ActiveItemEffectRenderer := preload("res://scripts/items/active_item_effect_renderer.gd")
const ActiveItemHologramDiskRuntime := preload("res://scripts/items/active_item_hologram_disk_runtime.gd")
const EnergyBallRendererScript := preload("res://scripts/ball/energy_ball_renderer.gd")
const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var ai_mode := "champion"
	var selected_character_type := "smasher"
	var ball_active := true
	var player_pos := Vector2(300.0, 690.0)
	var ball_pos := Vector2(380.0, 680.0)
	var ball_vel := Vector2(0.0, -12.0)
	var ball_impact_boost := 1.0
	var ball_boost_decay_rate := 1.0
	var ball_min_boost := 1.0


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false
	var player_serves := true

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve

	func does_player_serve() -> bool:
		return player_serves

	func get_snapshot() -> Dictionary:
		return {
			"serve_timer": 0.0,
			"serve_delay": 1.0,
		}


class FakeAudio:
	extends RefCounted

	var hologram_play_count := 0
	var pop_count := 0

	func play_hologram_disk() -> void:
		hologram_play_count += 1

	func play_active_item() -> void:
		hologram_play_count += 1

	func play_hologram_decoy_pop() -> void:
		pop_count += 1


class FakeFanoutRenderer:
	extends RefCounted

	var call_count := 0
	var captured_hologram_context: Dictionary = {}

	# 실 렌더러는 _perf_begin을 가져 facade가 perf-호환 분기(실 production
	# 분기)로 디스패치한다 — Fake에도 표식을 둬야 그 분기의 인자 전달을
	# 봉인한다(없으면 비-perf 분기만 검사돼 공허).
	func _perf_begin() -> int:
		return 0

	func draw_field_effects(
		_canvas, _pickup, _regen_rings, _regen_particles, _stopwatch, _magnet,
		_magnet_particles, _holy, _holy_particles, _brick, _long_boost,
		_vitamin, _strange, _dash, _dash_particles, _shake, _timer_stack,
		_perf_logger, _doping, hologram_context
	) -> void:
		call_count += 1
		if hologram_context is Dictionary:
			captured_hologram_context = hologram_context


# production 배관 spy: BossAiState가 predictor에 넘기는 fps_scale·벽 경계
# 인자를 호출면별로 기록하되 실 계산은 위임한다 — 소스 씰이 못 보는
# "인자 전달" 회귀(fps 인자 제거·경계 원복)를 행동으로 봉인.
class SpyPredictionState:
	extends BossAiPredictionState

	var future_scale_calls: Array = []
	var exact_scale_calls: Array = []

	func predict_future_x(ball_pos: Vector2, ball_vel: Vector2, fps_scale: float, play_left: float, play_right: float, boss_paddle_width: float, context: Dictionary = {}) -> float:
		future_scale_calls.append({"fps_scale": fps_scale, "play_left": play_left, "play_right": play_right})
		return super.predict_future_x(ball_pos, ball_vel, fps_scale, play_left, play_right, boss_paddle_width, context)

	func predict_exact_arrival_x(ball_pos: Vector2, ball_vel: Vector2, play_left: float, play_right: float, boss_paddle_width: float, context: Dictionary = {}, fps_scale: float = 1.0) -> float:
		exact_scale_calls.append({"fps_scale": fps_scale, "play_left": play_left, "play_right": play_right})
		return super.predict_exact_arrival_x(ball_pos, ball_vel, play_left, play_right, boss_paddle_width, context, fps_scale)


class FakePracticeMode:
	extends RefCounted

	var absorb_next := true

	func notify_ball_lost() -> bool:
		return absorb_next


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var cached_instances: Dictionary = {}
	var requested_keys: Array[String] = []
	var cached_requested_keys: Array[String] = []

	func _init() -> void:
		instances["round_flow_state"] = FakeRoundState.new()
		instances["game_audio"] = FakeAudio.new()

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		cached_requested_keys.append(key)
		return cached_instances.get(key, null)


func _init() -> void:
	_run_leg("01_catalog_debug_locale_icon", Callable(self, "_leg_catalog_debug_locale_icon"))
	_run_leg("02_router_dispatch_activates_and_refreshes", Callable(self, "_leg_router_dispatch_activates_and_refreshes"))
	_run_leg("03_player_hit_spawn_decoys", Callable(self, "_leg_player_hit_spawn_decoys"))
	_run_leg("04_deception_roll_locks_once_per_ascent", Callable(self, "_leg_deception_roll_locks_once_per_ascent"))
	_run_leg("05_boss_ai_geometric_deception_outcome", Callable(self, "_leg_boss_ai_geometric_deception_outcome"))
	_run_leg("06_fallback_when_roll_fails_or_decoy_dies", Callable(self, "_leg_fallback_when_roll_fails_or_decoy_dies"))
	_run_leg("07_descent_and_serve_wait_clear_deception", Callable(self, "_leg_descent_and_serve_wait_clear_deception"))
	_run_leg("08_freeze_and_skip_do_not_tick_decoys", Callable(self, "_leg_freeze_and_skip_do_not_tick_decoys"))
	_run_leg("09_reset_four_links_and_name_reload", Callable(self, "_leg_reset_four_links_and_name_reload"))
	_run_leg("10_effects_update_expiry_clears_atomically", Callable(self, "_leg_effects_expiry_clears_atomically"))
	_run_leg("11_real_ball_update_path_drives_decoys", Callable(self, "_leg_real_ball_update_path_drives_decoys"))
	_run_leg("12_descent_frame_order_has_no_stale_lock", Callable(self, "_leg_descent_frame_order_has_no_stale_lock"))
	_run_leg("13_render_center_contract_and_visual_margin", Callable(self, "_leg_render_center_contract_and_visual_margin"))
	_run_leg("14_draw_context_remaps_locked_index", Callable(self, "_leg_draw_context_remaps_locked_index"))
	_run_leg("15_paddle_bounce_spawns_same_physics_frame", Callable(self, "_leg_paddle_bounce_spawns_same_physics_frame"))
	_run_leg("16_prediction_model_matches_decoy_motion", Callable(self, "_leg_prediction_model_matches_decoy_motion"))
	_run_leg("17_practice_retry_clears_decoys_and_lock", Callable(self, "_leg_practice_retry_clears_decoys_and_lock"))
	_run_leg("18_production_fps_scale_reaches_predictor", Callable(self, "_leg_production_fps_scale_reaches_predictor"))

	if _failures.is_empty():
		print("active_item_hologram_disk_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _leg_catalog_debug_locale_icon() -> void:
	var catalog := ActiveItemCatalog.new()
	var item: Dictionary = catalog.build_item_by_name("hologram_disk")
	_expect(str(item.get("name", "")) == "hologram_disk", "catalog should build hologram_disk by name")
	_expect(str(item.get("effect", "")) == "hologram_disk", "catalog effect should route as hologram_disk")
	_expect(str(item.get("display_name", "")) == "홀로그램 디스크", "catalog should keep Korean display name")
	_expect(abs(float(item.get("chance", 0.0)) - 0.008) <= 0.0001, "catalog chance should match design")
	_expect(int(item.get("duration", 0)) == 300, "catalog duration should be 300 frames (5s)")
	_expect(int(item.get("cooldown_msec", 0)) == ActiveItemCatalog.DEFAULT_COOLDOWN_MSEC, "catalog cooldown should use active default")
	_expect(not item.has("no_recycle"), "hologram_disk should not opt out of recycle/refresh behavior")
	_expect(str(item.get("icon_path", "")) == ActiveItemCatalog.HOLOGRAM_DISK_ICON_PATH, "catalog icon should use hologram disk path")
	_expect(FileAccess.file_exists(ActiveItemCatalog.HOLOGRAM_DISK_ICON_PATH), "placeholder hologram disk icon file should exist")
	_expect(ActiveItemTimerGaugeRenderer.new().get_hologram_disk_icon_texture() != null, "timer gauge renderer should load hologram disk icon")
	_expect(ActiveItemCatalog.FIELD_SPAWN_ORDER.has("hologram_disk"), "field spawn order should include hologram_disk")
	_expect(ActiveItemDebugSpawnMenu.DEBUG_ENTRY_ORDER.has("hologram_disk"), "debug menu order should include hologram_disk")
	_expect(str(LanguageSettingsData.ITEM_DISPLAY_EN.get("hologram_disk", "")) != "", "EN localization should include hologram_disk")
	_expect(str(LanguageSettingsData.ITEM_DISPLAY_ZH.get("hologram_disk", "")) != "", "ZH localization should include hologram_disk")
	_expect(str(LanguageSettingsData.ITEM_DISPLAY_JA.get("hologram_disk", "")) != "", "JA localization should include hologram_disk")
	_expect(str(LanguageSettingsData.ITEM_DISPLAY_ES.get("hologram_disk", "")) != "", "ES localization should include hologram_disk")
	_expect(str(LanguageSettingsData.ITEM_DISPLAY_PT_BR.get("hologram_disk", "")) != "", "PT_BR localization should include hologram_disk")
	_expect(str(LanguageSettingsData.ITEM_DISPLAY_RU.get("hologram_disk", "")) != "", "RU localization should include hologram_disk")
	_expect(str(LanguageSettingsData.ACTIVE_ITEM_DESCRIPTION_EN.get("hologram_disk", "")) != "", "EN active description should include hologram_disk")


func _leg_router_dispatch_activates_and_refreshes() -> void:
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	var item: Dictionary = ActiveItemCatalog.new().build_item_by_name("hologram_disk")
	var accepted: bool = ActiveItemEffectRouter.new().apply_item_effect(
		item,
		owner,
		registry,
		runtime.effect_controller,
		runtime.throw_controller
	)
	_expect(accepted, "router should accept hologram_disk activation")
	_expect(runtime.effect_controller.hologram_disk_active, "activation should mutate hologram runtime state")
	_expect(is_equal_approx(runtime.effect_controller.hologram_disk_timer_frames, 300.0), "activation should start at base duration")
	runtime.effect_controller.hologram_disk_timer_frames = 120.0
	accepted = ActiveItemEffectRouter.new().apply_item_effect(item, owner, registry, runtime.effect_controller, runtime.throw_controller)
	_expect(accepted, "reuse while active should refresh rather than reject")
	_expect(is_equal_approx(runtime.effect_controller.hologram_disk_timer_frames, 300.0), "reuse should refresh duration")


func _leg_player_hit_spawn_decoys() -> void:
	var controller: Object = _fresh_active_controller(0.0)
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(0.0, -12.0)), {})
	_expect(controller.hologram_decoys.size() == 2, "player-side ascending hit should spawn two decoys")
	var left_decoy: Dictionary = controller.hologram_decoys[0]
	var right_decoy: Dictionary = controller.hologram_decoys[1]
	_expect(bool(left_decoy.get("alive", false)) and bool(right_decoy.get("alive", false)), "spawned decoys should start alive")
	_expect(_get_vector2(left_decoy, "pos", Vector2.ZERO) == Vector2(380.0, 680.0), "left decoy should spawn at real ball")
	_expect(_get_vector2(right_decoy, "pos", Vector2.ZERO) == Vector2(380.0, 680.0), "right decoy should spawn at real ball")
	_expect(_get_vector2(left_decoy, "vel", Vector2.ZERO).y < 0.0, "left decoy should fly upward")
	_expect(_get_vector2(right_decoy, "vel", Vector2.ZERO).y < 0.0, "right decoy should fly upward")
	_expect(_get_vector2(left_decoy, "vel", Vector2.ZERO).x * _get_vector2(right_decoy, "vel", Vector2.ZERO).x < 0.0, "decoy velocities should split sideways")
	_expect(abs(_get_vector2(left_decoy, "vel", Vector2.ZERO).length() - 12.0) < 0.01, "left decoy should preserve ball speed")
	_expect(abs(_get_vector2(right_decoy, "vel", Vector2.ZERO).length() - 12.0) < 0.01, "right decoy should preserve ball speed")

	# 벽 반사는 '중심' 좌표 규약 + '시각 최대 반경' 여백: 우측 벽에서 중심이
	# FIELD_WIDTH-DECOY_WALL_MARGIN에 클램프돼야 글로우가 필드 밖으로 새지
	# 않는다(충돌 반지름 여백이면 ~11px 시각 누출, 좌상단 규약이면 14.3px
	# 위치 어긋남).
	var wall_decoy: Dictionary = controller.hologram_decoys[0]
	wall_decoy["pos"] = Vector2(752.0, 400.0)
	wall_decoy["vel"] = Vector2(9.0, -9.0)
	controller.hologram_decoys[0] = wall_decoy
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(400.0, 620.0), Vector2(0.0, -12.0)), {})
	var clamped: Vector2 = _get_vector2(controller.hologram_decoys[0], "pos", Vector2.ZERO)
	var wall_boundary: float = 760.0 - ActiveItemHologramDiskRuntime.DECOY_WALL_MARGIN
	_expect(abs(clamped.x - (wall_boundary * 2.0 - 761.0)) < 0.01, "the right wall must mirror-reflect the decoy center about the visual boundary (same reflection geometry as the AI prediction)")
	_expect(clamped.x <= wall_boundary + 0.01, "the reflected decoy center must stay inside the visual boundary")
	_expect(_get_vector2(controller.hologram_decoys[0], "vel", Vector2.ZERO).x < 0.0, "right wall should reflect the decoy velocity")
	var max_visual_radius: float = EnergyBallRendererScript.BALL_RENDER_RADIUS * 0.88 * 1.08
	_expect(ActiveItemHologramDiskRuntime.DECOY_WALL_MARGIN >= max_visual_radius, "the wall margin must cover the maximum rendered glow radius (footprint rule)")

	# 최초 '스폰 프레임'도 시각 여백을 지켜야 한다 — 클램프가 다음 advance
	# 틱에만 있으면 벽 근처 패들 히트의 첫 렌더 프레임이 경계를 벗어난다.
	var wall_spawn_controller: Object = _fresh_active_controller(0.0)
	wall_spawn_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(752.0, 680.0), Vector2(0.0, -12.0)), {})
	for spawn_decoy_value in wall_spawn_controller.hologram_decoys:
		var spawn_x: float = _get_vector2(spawn_decoy_value, "pos", Vector2.ZERO).x
		_expect(spawn_x <= 760.0 - ActiveItemHologramDiskRuntime.DECOY_WALL_MARGIN + 0.01, "the spawn frame itself must respect the visual wall margin")


func _leg_deception_roll_locks_once_per_ascent() -> void:
	var controller: Object = _fresh_active_controller(1.0)
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(4.0, -12.0)), {})
	var locked_index: int = int(controller.hologram_locked_decoy_index)
	_expect(locked_index >= 0, "forced chance should lock one decoy")
	_expect(controller.hologram_deception_roll_count == 1, "first ascending opportunity should roll once")
	for _index in range(8):
		controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(410.0, 620.0), Vector2(4.0, -12.0)), {})
	_expect(controller.hologram_deception_roll_count == 1, "same ascending flight must not reroll per frame")
	_expect(controller.hologram_locked_decoy_index == locked_index, "same ascending flight should keep the locked decoy")

	# 하강이 기회를 닫은 뒤의 '두 번째 상승'은 새 기회로 재무장돼야 하고,
	# 이때 살아있던 기존 분신은 무음 삭제가 아니라 글리치 팝(VFX+SFX)으로
	# 교체돼야 한다(설계 §5.2 계약).
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(420.0, 560.0), Vector2(4.0, 10.0)), {})
	_expect(not bool(controller.hologram_deception_roll_locked), "descent should re-arm the per-ascent roll")
	var survivors_before_respawn: int = 0
	var survivor_centers: Array[Vector2] = []
	for decoy_value in controller.hologram_decoys:
		if decoy_value is Dictionary and bool(decoy_value.get("alive", false)):
			survivors_before_respawn += 1
			# 재스폰 tick은 advance(1프레임 전진) 후 교체 팝을 만들므로,
			# 기대 팝 중심 = 지금 위치 + 자기 vel × 1프레임.
			survivor_centers.append(_get_vector2(decoy_value, "pos", Vector2.ZERO) + _get_vector2(decoy_value, "vel", Vector2.ZERO))
	_expect(survivors_before_respawn == 2, "both decoys should still be alive through the descent (respawn-replacement precondition)")
	# sentinel 팝 fixture: 진행 중이던 기존 팝이 재스폰에서 삭제되지 않고,
	# 새 팝이 분신당 정확히 1개(중복 금지)씩 기존 분신 중심에서 생성되는지
	# '정확 수 + sentinel 보존 + 위치 일치'로 봉인한다.
	var sentinel_seed := 777.125
	controller.hologram_decoy_pop_particles.append({
		"pos": Vector2(111.0, 222.0),
		"flicker_seed": sentinel_seed,
		"age_frames": 2.0,
		"lifetime_frames": 12.0,
	})
	var pops_before_respawn: int = controller.hologram_decoy_pop_particles.size()
	var respawn_audio := FakeAudio.new()
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(420.0, 640.0), Vector2(-4.0, -12.0)), {"audio": respawn_audio})
	_expect(controller.hologram_decoys.size() == 2, "second ascent after descent should respawn decoys")
	_expect(controller.hologram_deception_roll_count == 2, "second ascent should roll exactly one more time")
	_expect(respawn_audio.pop_count == survivors_before_respawn, "replaced live decoys must each fire the glitch-pop SFX (no silent deletion)")
	_expect(controller.hologram_decoy_pop_particles.size() == pops_before_respawn + survivors_before_respawn, "respawn must add exactly one pop per replaced decoy while keeping in-flight pops (no clear, no duplicates)")
	var sentinel_survived := false
	var matched_pop_centers := 0
	for pop_value in controller.hologram_decoy_pop_particles:
		if not (pop_value is Dictionary):
			continue
		if is_equal_approx(float(pop_value.get("flicker_seed", 0.0)), sentinel_seed):
			sentinel_survived = true
			continue
		var pop_pos: Vector2 = _get_vector2(pop_value, "pos", Vector2.ZERO)
		# multiset 일대일 소비: 매칭된 중심은 제거해, 두 팝이 같은 분신
		# 중심에 겹쳐도 통과하지 못하게 한다.
		for center_index in range(survivor_centers.size()):
			if pop_pos == survivor_centers[center_index]:
				survivor_centers.remove_at(center_index)
				matched_pop_centers += 1
				break
	_expect(sentinel_survived, "an in-flight pop particle must survive the respawn (clear() regression class)")
	_expect(matched_pop_centers == survivors_before_respawn and survivor_centers.is_empty(), "replacement pops must consume the replaced decoy centers one-to-one (no doubled center, none missing)")


func _leg_boss_ai_geometric_deception_outcome() -> void:
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.ball_pos = Vector2(120.0, 520.0)
	owner.ball_vel = Vector2(0.0, -10.0)
	_register_runtime(registry, runtime)
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	_force_locked_decoy(runtime.effect_controller, Vector2(640.0, 520.0), Vector2(0.0, -10.0))

	var context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	context["boss_mistake_chance"] = 0.0
	_expect(bool(context.get("hologram_deception_active", false)), "boss AI context should mark active hologram deception")
	_expect(_get_vector2(context, "ball_pos", Vector2.ZERO) == Vector2(640.0, 520.0), "boss AI context should substitute decoy position")
	_expect(registry.cached_requested_keys.has("active_item_runtime"), "boss AI context should use cache-only active item peek")

	var decoy_arrival: float = BossAiPredictionState.new().predict_exact_arrival_x(
		_get_vector2(context, "ball_pos", Vector2.ZERO),
		_get_vector2(context, "ball_vel", Vector2.ZERO),
		0.0,
		760.0,
		100.0,
		context
	)
	var real_arrival: float = BossAiPredictionState.new().predict_exact_arrival_x(
		owner.ball_pos,
		owner.ball_vel,
		0.0,
		760.0,
		100.0,
		context
	)
	_expect(decoy_arrival > 610.0, "substituted prediction should target the decoy arrival x")
	_expect(real_arrival < 180.0, "real ball prediction should stay far from the decoy target")
	var boss_result: Dictionary = BossAiState.new().update(1.0 / 60.0, Vector2(220.0, 25.0), 0.0, context)
	_expect(_get_vector2(boss_result, "boss_pos", Vector2.ZERO).x > 220.0, "boss movement should head toward the decoy, not the real ball")


func _leg_fallback_when_roll_fails_or_decoy_dies() -> void:
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	_register_runtime(registry, runtime)
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 0.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	var failed_roll_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	_expect(not bool(failed_roll_context.get("hologram_deception_active", false)), "failed deception roll should fall back to real ball")
	_expect(_get_vector2(failed_roll_context, "ball_pos", Vector2.ZERO) == owner.ball_pos, "failed roll context should keep real ball position")

	runtime.effect_controller.clear_hologram_disk_runtime()
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	_force_locked_decoy(runtime.effect_controller, Vector2(500.0, 62.0), Vector2(0.0, -3.0))
	var pop_audio := FakeAudio.new()
	runtime.effect_controller.apply_hologram_decoy_tick(
		1.0,
		_ascending_context(Vector2(400.0, 620.0), Vector2(0.0, -12.0)),
		{"audio": pop_audio}
	)
	_expect(pop_audio.pop_count == 1, "decoy death should fire pop audio through the ball-path deps audio key")
	var dead_decoy_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	_expect(not bool(dead_decoy_context.get("hologram_deception_active", false)), "dead locked decoy should clear deception")
	_expect(_get_vector2(dead_decoy_context, "ball_pos", Vector2.ZERO) == owner.ball_pos, "dead locked decoy should fall back to real ball")


func _leg_descent_and_serve_wait_clear_deception() -> void:
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	_register_runtime(registry, runtime)
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "setup should lock decoy before descent")
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(390.0, 500.0), Vector2(0.0, 6.0)), {})
	var descent_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	_expect(not bool(descent_context.get("hologram_deception_active", false)), "descent should clear deception lock")

	runtime.effect_controller.clear_hologram_disk_runtime()
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	var round_state: Object = registry.instances["round_flow_state"]
	round_state.waiting_for_serve = true
	var serve_context := _ascending_context(owner.ball_pos, owner.ball_vel)
	serve_context["waiting_for_serve"] = true
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, serve_context, {})
	var serve_ai_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	_expect(runtime.effect_controller.hologram_decoys.is_empty(), "serve wait should clear decoys")
	_expect(not bool(serve_ai_context.get("hologram_deception_active", false)), "serve wait should disable deception")


func _leg_freeze_and_skip_do_not_tick_decoys() -> void:
	var controller: Object = _fresh_active_controller(1.0)
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(4.0, -12.0)), {})
	var before_pos: Vector2 = _get_vector2(controller.hologram_decoys[0], "pos", Vector2.ZERO)
	var before_roll_count: int = controller.hologram_deception_roll_count
	var skip_context := _ascending_context(Vector2(410.0, 620.0), Vector2(4.0, -12.0))
	skip_context["skip_ball_motion_step"] = true
	controller.apply_hologram_decoy_tick(1.0, skip_context, {})
	_expect(_get_vector2(controller.hologram_decoys[0], "pos", Vector2.ZERO) == before_pos, "skip frame should not move decoys")
	_expect(controller.hologram_deception_roll_count == before_roll_count, "skip frame should not roll deception")

	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(410.0, 620.0), Vector2.ZERO), {})
	_expect(_get_vector2(controller.hologram_decoys[0], "pos", Vector2.ZERO) == before_pos, "zero velocity freeze should not move decoys")
	_expect(controller.hologram_deception_roll_count == before_roll_count, "zero velocity freeze should not roll deception")


func _leg_reset_four_links_and_name_reload() -> void:
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = _new_runtime()
	_register_runtime(registry, runtime)
	_dirty_hologram_runtime(runtime, owner, registry)
	runtime.reset_round()
	_expect(_hologram_cleared(runtime.effect_controller), "round reset should clear hologram runtime")

	_dirty_hologram_runtime(runtime, owner, registry)
	runtime.reset()
	_expect(_hologram_cleared(runtime.effect_controller), "full game reset should clear hologram runtime")

	_dirty_hologram_runtime(runtime, owner, registry)
	runtime.reset_for_stage_transition(owner, registry)
	_expect(_hologram_cleared(runtime.effect_controller), "stage transition reset should clear hologram runtime")

	# reset 직후 재활성화한 첫 상승에서 분신 생성이 정상 재무장돼야 한다
	# (last_ball_ascending 잔존 시 첫 상승 에지가 침묵하는 leak 클래스).
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	_expect(runtime.effect_controller.hologram_decoys.size() == 2, "first ascent right after reset should spawn decoys again")
	runtime.reset()

	var saved_item_name := "hologram_disk"
	var reloaded_item: Dictionary = ActiveItemCatalog.new().build_item_by_name(saved_item_name)
	_expect(str(reloaded_item.get("name", "")) == saved_item_name, "save/load name route should rebuild hologram_disk by item name")
	_expect(_hologram_cleared(runtime.effect_controller), "save/load name rebuild should not persist transient hologram state")


func _leg_effects_expiry_clears_atomically() -> void:
	# 실 frame-flow는 모달 포즈 중 active item update driver를 돌리지 않아
	# 타이머가 정지한다(모달 중 만료 없음). 이 레그의 실제 보장은 effects
	# 경로에서 만료가 일어난 그 틱에 락·분신·파티클이 '원자적으로' 정리되는
	# 것이다.
	var controller: Object = _fresh_active_controller(1.0)
	var owner := FakeOwner.new()
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	controller.hologram_disk_timer_frames = 1.0
	controller.hologram_disk_initial_timer_frames = 300.0
	controller.update(owner, 1.0 / 60.0)
	_expect(not controller.hologram_disk_active, "effects-path expiry should clear the active flag")
	_expect(controller.hologram_decoys.is_empty(), "effects-path expiry should clear decoys atomically")
	_expect(controller.hologram_decoy_pop_particles.is_empty(), "effects-path expiry should clear pop particles atomically")
	_expect(controller.hologram_locked_decoy_index == -1, "effects-path expiry should clear the locked decoy atomically")


func _leg_real_ball_update_path_drives_decoys() -> void:
	# 컨트롤러 직접 호출이 아니라 실 배선(BallUpdateController.update ->
	# frame_motion_controller.apply_active_item_hologram_decoys -> runtime의
	# apply_hologram_decoy_tick)을 관통 봉인한다 — 배선 라인을 지우면 이
	# 레그가 RED가 된다.
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	var ball_controller: Object = BallUpdateController.new()
	var deps := {"active_item_runtime": runtime, "motion_stepper": BallMotionStepper.new()}

	ball_controller.update(1.0 / 60.0, _ball_update_context(Vector2(380.0, 600.0), Vector2(0.0, 8.0)), deps)
	_expect(runtime.effect_controller.hologram_decoys.is_empty(), "descending real-path frame should not spawn decoys")

	ball_controller.update(1.0 / 60.0, _ball_update_context(Vector2(380.0, 600.0), Vector2(2.0, -9.0)), deps)
	_expect(runtime.effect_controller.hologram_decoys.size() == 2, "real BallUpdateController path should spawn decoys on the descent-to-ascent edge")
	_expect(runtime.effect_controller.hologram_deception_roll_count == 1, "real path ascent should roll deception exactly once")
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "forced chance through the real path should lock a decoy")

	var before_pos: Vector2 = _get_vector2(runtime.effect_controller.hologram_decoys[0], "pos", Vector2.ZERO)
	ball_controller.update(1.0 / 60.0, _ball_update_context(Vector2(382.0, 591.0), Vector2(2.0, -9.0)), deps)
	_expect(_get_vector2(runtime.effect_controller.hologram_decoys[0], "pos", Vector2.ZERO) != before_pos, "real path frames should advance decoy positions")
	_expect(runtime.effect_controller.hologram_deception_roll_count == 1, "real path must not reroll during the same ascent")


func _leg_descent_frame_order_has_no_stale_lock() -> void:
	# 실 물리 프레임 순서는 active item → boss AI → ball update: 보스 반사로
	# 공이 하강 전환한 프레임에는 ball tick(락 해제)이 아직 안 돌았다 — 그
	# 프레임의 boss AI 컨텍스트가 stale 분신을 한 틱 더 추적하면 안 된다.
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	_register_runtime(registry, runtime)
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "setup should lock a decoy while ascending")
	owner.ball_vel = Vector2(3.0, 9.0)
	var stale_frame_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "the ball tick has not run yet in this frame (stale lock precondition)")
	_expect(not bool(stale_frame_context.get("hologram_deception_active", false)), "the descent frame must fall back to the real ball before the ball tick releases the lock")
	_expect(_get_vector2(stale_frame_context, "ball_pos", Vector2.ZERO) == owner.ball_pos, "the descent frame context must carry the real ball position")


func _leg_render_center_contract_and_visual_margin() -> void:
	# 렌더 경로 씰: 분신/팝의 화면 중심은 저장 pos 그대로여야 한다(+half
	# 재도입 시 여기서 RED). 두 draw 함수 본문이 공용 중심 헬퍼를 지나고
	# 좌상단 보정 상수를 되살리지 않는 것까지 본문 한정 소스 씰로 봉인.
	var decoy := {"pos": Vector2(700.0, 300.0), "flicker_seed": 1.0}
	var resolved: Vector2 = ActiveItemEffectRenderer.resolve_hologram_render_center(decoy, Vector2(2.0, -1.0))
	_expect(resolved == Vector2(702.0, 299.0), "render center must be the stored center position plus shake only (no top-left +half offset)")
	var renderer_script: Script = ActiveItemEffectRenderer as Script
	var decoy_body: String = SourceContractFunctionBody.extract(renderer_script.source_code, "func _draw_hologram_decoy(")
	var pop_body: String = SourceContractFunctionBody.extract(renderer_script.source_code, "func _draw_hologram_pop_particle(")
	_expect(decoy_body.contains("resolve_hologram_render_center("), "decoy draw body must resolve its center through the shared helper")
	_expect(pop_body.contains("resolve_hologram_render_center("), "pop draw body must resolve its center through the shared helper")
	_expect(not decoy_body.contains("BALL_SIZE"), "decoy draw body must not reintroduce a top-left ball-size offset")
	_expect(not pop_body.contains("BALL_SIZE"), "pop draw body must not reintroduce a top-left ball-size offset")

	# 실 렌더 팬아웃 씰: 내부 draw 함수가 살아 있어도 (a) 메인
	# draw_field_effects가 홀로그램 브랜치를 부르지 않거나 (b) facade가
	# hologram_disk_context를 수집·전달하지 않으면 화면에서 효과가 통째로
	# 사라진다. 텍스트 씰은 지역변수 선언만으로 공허 통과하므로, 실제 인자
	# 전달은 Fake renderer 캡처로, 실제 수집은 활성 컨트롤러의 bulk
	# context '값'으로 봉인한다.
	var main_draw_body: String = SourceContractFunctionBody.extract(renderer_script.source_code, "func draw_field_effects(")
	_expect(main_draw_body.contains("_draw_hologram_disk_effect("), "the main field draw body must dispatch the hologram effect")

	var fanout_controller: Object = _fresh_active_controller(1.0)
	fanout_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(4.0, -12.0)), {})
	var bulk_context: Dictionary = fanout_controller.get_field_effect_draw_context()
	var bulk_hologram: Dictionary = bulk_context.get("hologram_disk_context", {})
	_expect(bool(bulk_hologram.get("active", false)), "the controller bulk draw context must carry a live hologram context (deleting the bulk key must fail here)")
	_expect(not (bulk_hologram.get("decoys", []) as Array).is_empty(), "the bulk hologram context must carry the live decoys")

	var facade: Object = ActiveItemRenderFacade.new()
	var fanout_renderer := FakeFanoutRenderer.new()
	facade.effect_renderer = fanout_renderer
	facade._call_effect_renderer_draw_field_effects(null, FakeRegistry.new(), fanout_controller, Vector2.ZERO, null)
	_expect(fanout_renderer.call_count == 1, "the facade must invoke the effect renderer exactly once")
	_expect(bool(fanout_renderer.captured_hologram_context.get("active", false)), "the facade must pass the live hologram context as the renderer argument (a dropped argument must fail here)")
	_expect(not (fanout_renderer.captured_hologram_context.get("decoys", []) as Array).is_empty(), "the renderer argument must carry the live decoys through the production (perf-capable) branch")


func _leg_draw_context_remaps_locked_index() -> void:
	# draw 배열은 alive만 남겨 압축된다 — [dead0, locked1]에서 저장 인덱스
	# 1을 그대로 넘기면 잠금 강조가 사라진다(압축 후 0으로 재매핑돼야 함).
	var controller: Object = _fresh_active_controller(1.0)
	controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(4.0, -12.0)), {})
	var dead_decoy: Dictionary = controller.hologram_decoys[0]
	dead_decoy["alive"] = false
	controller.hologram_decoys[0] = dead_decoy
	controller.hologram_locked_decoy_index = 1
	var draw_context: Dictionary = controller.get_hologram_disk_context()
	var draw_decoys: Array = draw_context.get("decoys", [])
	_expect(draw_decoys.size() == 1, "draw context should compact dead decoys away")
	_expect(int(draw_context.get("locked_decoy_index", -1)) == 0, "locked index must be remapped to the compacted draw array")


func _leg_paddle_bounce_spawns_same_physics_frame() -> void:
	# 실제 패들 충돌을 step_motion이 만들어내는 프레임-flow 검증: 하강 공이
	# 그 프레임 안에서 반사→상승 전환되고, 같은 update() 안에서 분신
	# 스폰·롤까지 끝나야 한다(훅이 motion 앞이면 다음 틱으로 밀려 보스
	# AI가 진짜 공을 1틱 먼저 본다).
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	var ball_controller: Object = BallUpdateController.new()
	var deps := {
		"active_item_runtime": runtime,
		"motion_stepper": BallMotionStepper.new(),
		"paddle_bounce_controller": PaddleBounceController.new(),
		"paddle_bounce_state": PaddleBounceState.new(),
	}
	var bounce_context := _ball_update_context(Vector2(380.0, 688.0), Vector2(0.0, 9.0))
	bounce_context["player_pos"] = Vector2(302.5, 700.0)
	bounce_context["player_collision_cooldown"] = 0.0
	var result: Dictionary = ball_controller.update(1.0 / 60.0, bounce_context, deps)
	var snapshot: Dictionary = result.get("snapshot", {})
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO).y < 0.0, "the paddle must reflect the ball upward inside this physics frame (leg precondition)")
	_expect(runtime.effect_controller.hologram_decoys.size() == 2, "decoys must spawn in the same physics frame as the real paddle bounce")
	_expect(runtime.effect_controller.hologram_deception_roll_count == 1, "the deception roll must land in the bounce frame too")
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "forced chance should lock a decoy in the bounce frame")
	# 정밀 씰: 훅이 pre/post 중복 배선되면 분신이 한 프레임에 두 번
	# 전진한다 — bounce 프레임의 age 0과 다음 틱의 '정확 1프레임 변위'로
	# 훅 1회 호출을 봉인한다.
	var bounce_frame_decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
	_expect(is_equal_approx(float(bounce_frame_decoy.get("age_frames", -1.0)), 0.0), "bounce-frame decoys must not have been advanced yet (duplicate-hook guard)")
	var spawn_frame_pos: Vector2 = _get_vector2(bounce_frame_decoy, "pos", Vector2.ZERO)
	var spawn_frame_vel: Vector2 = _get_vector2(bounce_frame_decoy, "vel", Vector2.ZERO)
	ball_controller.update(1.0 / 60.0, _ball_update_context(Vector2(380.0, 640.0), Vector2(2.0, -9.0)), deps)
	var advanced_decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
	_expect(_get_vector2(advanced_decoy, "pos", Vector2.ZERO).is_equal_approx(spawn_frame_pos + spawn_frame_vel), "the next tick must advance decoys by exactly one frame of velocity (a duplicated hook would advance twice)")
	_expect(is_equal_approx(float(advanced_decoy.get("age_frames", -1.0)), 1.0), "the next tick must age decoys by exactly one frame")


func _leg_prediction_model_matches_decoy_motion() -> void:
	# 분신 운동 모델(raw velocity + 시각 여백 벽 반사)과 보스 AI 예측
	# 모델이 일치해야 한다: 기만 프레임의 컨텍스트는 부스트 계약을
	# 무력화하고 홀로그램 전용 예측 벽 경계를 실어야 하며, 그 경계로 돌린
	# 예측 도착 x가 분신을 실제로 진행시킨 도착 x와 일치해야 한다(전역
	# 0..760 벽+impact boost 예측이면 벽 반사 후 최대 ~53px 어긋난다).
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	owner.ball_impact_boost = 1.6
	owner.ball_boost_decay_rate = 0.975
	owner.ball_min_boost = 0.70
	_register_runtime(registry, runtime)
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	# 벽 반사 파리티: 분신은 반사 후 반전된 vel.x를 유지하므로, 기만
	# 프레임의 예측도 prediction_reflect_velocity 계약으로 같은 모델을
	# 써야 한다(구 근사면 우벽에 눌어붙어 ~683 vs 실궤적 ~316).
	_force_locked_decoy(runtime.effect_controller, Vector2(700.0, 520.0), Vector2(10.0, -10.0))

	var context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	var margin: float = ActiveItemHologramDiskRuntime.DECOY_WALL_MARGIN
	_expect(is_equal_approx(float(context.get("ball_impact_boost", -1.0)), 1.0), "deception frames must neutralize the impact-boost contract (decoys fly at raw velocity)")
	_expect(is_equal_approx(float(context.get("prediction_play_left", -1.0)), margin), "deception frames must carry the hologram prediction left bound")
	_expect(is_equal_approx(float(context.get("prediction_play_right", -1.0)), 760.0 - margin), "deception frames must carry the hologram prediction right bound")
	_expect(bool(context.get("prediction_reflect_velocity", false)), "deception frames must opt into reflected-velocity prediction")

	var predicted_x: float = BossAiPredictionState.new().predict_exact_arrival_x(
		_get_vector2(context, "ball_pos", Vector2.ZERO),
		_get_vector2(context, "ball_vel", Vector2.ZERO),
		float(context.get("prediction_play_left", 0.0)),
		float(context.get("prediction_play_right", 760.0)),
		100.0,
		context
	)
	var intercept_y: float = 25.0 + 40.0 + 5.0 + 28.6 * 0.5
	var simulated_x: float = -1000.0
	for _frame in range(400):
		runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(120.0, 500.0), Vector2(0.0, -10.0)), {})
		var decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
		var decoy_pos: Vector2 = _get_vector2(decoy, "pos", Vector2.ZERO)
		if decoy_pos.y <= intercept_y:
			simulated_x = decoy_pos.x
			break
		if not bool(decoy.get("alive", false)):
			simulated_x = decoy_pos.x
			break
	_expect(simulated_x > -999.0, "the locked decoy simulation must reach the boss intercept band")
	_expect(abs(predicted_x - simulated_x) <= 1.0, "the substituted prediction must match the decoy's actual integer-tick arrival x (reflected-velocity model parity; the legacy approximation would stick near the wall)")
	_expect(simulated_x < 500.0, "the wall-bounce scenario must actually cross back left (seal precondition)")

	# 실 BossAiState 관통(수렴 위치 정밀 씰): 예측 경계 소비를 제거해도
	# 전역 벽(760) 반사가 좌향 이동은 만들어내므로 '방향' 검사로는 공허 —
	# 보스가 수렴한 중심 위치가 분신 실도착 x와 일치해야 한다(전역 벽
	# 모델이면 ~53px 우측으로 벗어나 RED).
	context["boss_mistake_chance"] = 0.0
	context["boss_dash_enabled"] = false
	var boss_state: Object = BossAiState.new()
	var converge_boss_pos := Vector2(600.0, 25.0)
	var converge_boss_vel := 0.0
	for _step in range(300):
		var step_result: Dictionary = boss_state.update(1.0 / 60.0, converge_boss_pos, converge_boss_vel, context)
		converge_boss_pos = _get_vector2(step_result, "boss_pos", converge_boss_pos)
		converge_boss_vel = float(step_result.get("boss_vel", converge_boss_vel))
	var converged_center: float = converge_boss_pos.x + 50.0
	_expect(abs(converged_center - simulated_x) <= 25.0, "the real BossAiState path must converge on the decoy's reflected arrival x (a global-wall prediction settles ~53px off)")

	# 클램프 분리 씰: 반사 경계는 좁아져도 보스 '목표 중심' 클램프는 전역
	# play 기준이어야 한다 — 우벽 직선 도착(x=720) 예측이 683.4로 깎이면
	# 반사 경계가 목표 클램프까지 오염된 것.
	_force_locked_decoy(runtime.effect_controller, Vector2(720.0, 300.0), Vector2(0.0, -10.0))
	var clamp_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	var clamp_predicted_x: float = BossAiPredictionState.new().predict_exact_arrival_x(
		_get_vector2(clamp_context, "ball_pos", Vector2.ZERO),
		_get_vector2(clamp_context, "ball_vel", Vector2.ZERO),
		float(clamp_context.get("prediction_play_left", 0.0)),
		float(clamp_context.get("prediction_play_right", 760.0)),
		100.0,
		clamp_context
	)
	_expect(clamp_predicted_x > 683.5, "the boss target clamp must stay on the global play bounds (a reflection-bound clamp would cap the target at 683.4)")

	# BossAiState 소비 3곳 중 행동 fixture는 일반 추적(수렴 씰)만 커버 —
	# whip-deactivation과 chained-dash의 전용 경계 소비는 본문 call-site
	# 씰로 봉인한다(전역 경계로 되돌리면 여기서 RED).
	var boss_ai_script: Script = load("res://scripts/ai/boss_ai_state.gd") as Script
	# 인자 '순서'까지 봉인: 단순 count는 left/right를 서로 바꿔도 통과한다 —
	# 공백을 접은 정렬된 쌍 시퀀스(left 다음 right)로 검사한다.
	var ordered_bounds_pair := "float(context.get(\"prediction_play_left\",play_left)),float(context.get(\"prediction_play_right\",play_right)),"
	var motion_body: String = SourceContractFunctionBody.extract(boss_ai_script.source_code, "func _update_motion(")
	var motion_flat: String = motion_body.replace("\t", "").replace("\n", "").replace(" ", "")
	_expect(motion_flat.count(ordered_bounds_pair) == 2, "boss AI motion body must pass the hologram bounds as an ordered left,right pair at exactly its two call sites (a swap, one-sided revert, or dead duplicate must fail)")
	var dash_body: String = SourceContractFunctionBody.extract(boss_ai_script.source_code, "func _try_start_chained_boss_dash(")
	var dash_flat: String = dash_body.replace("\t", "").replace("\n", "").replace(" ", "")
	_expect(dash_flat.count(ordered_bounds_pair) == 1, "the chained-dash targeting body must pass the hologram bounds as exactly one ordered left,right pair")

	# [P1] 다중 반사·얕은 각 장거리 궤적: 120프레임 컷+4회-반사 fallback이면
	# 크게 오예측한다(도착 ~167프레임). 확장 시뮬로 실궤적과 일치해야 한다.
	_force_locked_decoy(runtime.effect_controller, Vector2(380.0, 690.0), Vector2(25.75, -3.62))
	var long_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	var long_predicted_x: float = BossAiPredictionState.new().predict_exact_arrival_x(
		_get_vector2(long_context, "ball_pos", Vector2.ZERO),
		_get_vector2(long_context, "ball_vel", Vector2.ZERO),
		float(long_context.get("prediction_play_left", 0.0)),
		float(long_context.get("prediction_play_right", 760.0)),
		100.0,
		long_context
	)
	var long_simulated_x: float = -1000.0
	for _long_frame in range(1400):
		runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(120.0, 500.0), Vector2(0.0, -10.0)), {})
		var long_decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
		var long_pos: Vector2 = _get_vector2(long_decoy, "pos", Vector2.ZERO)
		if long_pos.y <= intercept_y or not bool(long_decoy.get("alive", false)):
			long_simulated_x = long_pos.x
			break
	_expect(long_simulated_x > -999.0, "the shallow-angle decoy simulation must reach the boss intercept band")
	_expect(abs(long_predicted_x - long_simulated_x) <= 1.0, "the multi-bounce shallow-angle prediction must match the decoy's actual integer-tick arrival x (the 120-frame cut plus 4-bounce fallback drifts to the clamp edge)")

	# >1200프레임·다수(홀수) 반사 극단: 도착까지 ~1514프레임 — 프레임 컷이
	# 있으면 컷 시점 위치+최종 반사 부호로 오예측한다. O(1) 닫힌형은 남은
	# 시간과 최초 signed vx를 정확히 접어야 한다.
	_force_locked_decoy(runtime.effect_controller, Vector2(380.0, 690.0), Vector2(25.0, -0.4))
	var extreme_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	var extreme_predicted_x: float = BossAiPredictionState.new().predict_exact_arrival_x(
		_get_vector2(extreme_context, "ball_pos", Vector2.ZERO),
		_get_vector2(extreme_context, "ball_vel", Vector2.ZERO),
		float(extreme_context.get("prediction_play_left", 0.0)),
		float(extreme_context.get("prediction_play_right", 760.0)),
		100.0,
		extreme_context
	)
	var extreme_simulated_x: float = -1000.0
	for _extreme_frame in range(1700):
		runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(120.0, 500.0), Vector2(0.0, -10.0)), {})
		var extreme_decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
		var extreme_pos: Vector2 = _get_vector2(extreme_decoy, "pos", Vector2.ZERO)
		if extreme_pos.y <= intercept_y or not bool(extreme_decoy.get("alive", false)):
			extreme_simulated_x = extreme_pos.x
			break
	_expect(extreme_simulated_x > -999.0, "the extreme shallow-angle decoy simulation must reach the boss intercept band")
	_expect(abs(extreme_predicted_x - extreme_simulated_x) <= 1.0, "the beyond-1200-frame prediction must fold the full remaining flight (a frame cap returns the cap-time position instead)")

	# 최대속도 경계 × 실 fps_scale: 실 분신은 vel×fps_scale로 이동한다
	# (프로젝트 기본 72Hz = 5/6). 명목 프레임 ceil이면 60Hz만 맞고 live
	# scale에서 parity가 깨진다 — 60Hz(1.0)와 72Hz(5/6) 두 배율 모두 봉인.
	_expect(abs(_predict_vs_simulated_arrival_gap(runtime, owner, registry, Vector2(380.0, 690.0), Vector2(34.13, -7.7), 1.0)) <= 1.0, "a top-speed 60Hz fixture must keep integer-tick parity (fractional frames overshoot by up to one tick of vx)")
	_expect(abs(_predict_vs_simulated_arrival_gap(runtime, owner, registry, Vector2(380.0, 690.0), Vector2(34.13, -7.7), 5.0 / 6.0)) <= 1.0, "the live 72Hz (5/6 scale) fixture must keep integer-tick parity (a nominal-frame ceil drifts ~5.7px)")

	# 음수 vx + 실제 '홀수' 벽 교차 + >1200틱: parity fixture가 전부 양수
	# vx거나 짝수 교차면 abs(vx) 변조·부호 결함이 샌다 — 전제(부호·틱 수·
	# 교차 홀짝)를 fixture 안에서 직접 assert해 공허화를 차단한다.
	var odd_pos := Vector2(380.0, 690.3)
	var odd_vel := Vector2(-24.75, -0.4)
	var odd_intercept_y: float = 25.0 + 40.0 + 5.0 + 28.6 * 0.5
	var odd_ticks: float = ceilf((odd_pos.y - odd_intercept_y) / (0.4 * 1.0))
	var odd_span: float = (760.0 - margin) - margin
	var odd_first_crossing_distance: float = odd_pos.x - margin
	var odd_total_travel: float = abs(odd_vel.x) * odd_ticks
	var odd_crossings: int = 0
	if odd_total_travel > odd_first_crossing_distance:
		odd_crossings = 1 + int(floor((odd_total_travel - odd_first_crossing_distance) / odd_span))
	_expect(odd_vel.x < 0.0, "odd-crossing fixture precondition: vx must be negative")
	_expect(odd_ticks > 1200.0, "odd-crossing fixture precondition: flight must exceed the legacy 1200-frame cap")
	_expect(odd_crossings % 2 == 1, "odd-crossing fixture precondition: the wall-crossing count must actually be odd")
	_expect(abs(_predict_vs_simulated_arrival_gap(runtime, owner, registry, odd_pos, odd_vel, 1.0)) <= 1.0, "a negative-vx odd-crossing fixture must keep parity (folding abs(vx) instead of the signed vx must fail)")


func _leg_practice_retry_clears_decoys_and_lock() -> void:
	# 바이퍼 연습모드 재시도: 점수 경로가 post-motion 훅보다 먼저 반환되고
	# 공만 비활성화하므로, 인터셉트 지점에서 분신·락·비행 상태를 명시적으로
	# 정리하지 않으면 홀드 중 분신이 남고 재상승 첫 프레임의 보스 AI가
	# 오래된 락을 재사용한다.
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(4.0, -12.0)), {})
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "setup should lock a decoy before the practice ball loss")
	var ball_controller: Object = BallUpdateController.new()
	var deps := {
		"active_item_runtime": runtime,
		"motion_stepper": BallMotionStepper.new(),
		"viper_practice_mode": FakePracticeMode.new(),
	}
	var loss_context := _ball_update_context(Vector2(380.0, 744.0), Vector2(0.0, 12.0))
	loss_context["player_pos"] = Vector2(100.0, 700.0)
	runtime.effect_controller.hologram_decoy_pop_particles.append({
		"pos": Vector2(50.0, 60.0), "flicker_seed": 555.5, "age_frames": 1.0, "lifetime_frames": 12.0,
	})
	var result: Dictionary = ball_controller.update(1.0 / 60.0, loss_context, deps)
	_expect(str(result.get("score_event", "")) == "", "the practice intercept must absorb the score event (leg precondition)")
	_expect(runtime.effect_controller.hologram_decoys.is_empty(), "practice retry must clear stale decoys")
	_expect(runtime.effect_controller.hologram_decoy_pop_particles.is_empty(), "practice retry must clear in-flight pop particles too (held-screen leftovers)")
	_expect(runtime.effect_controller.hologram_locked_decoy_index == -1, "practice retry must clear the stale deception lock")
	_expect(not bool(runtime.effect_controller.hologram_deception_flight_active), "practice retry must clear the flight state")
	_expect(not bool(runtime.effect_controller.hologram_deception_roll_locked), "practice retry must re-arm the per-ascent roll lock")
	_expect(not bool(runtime.effect_controller.hologram_last_ball_ascending), "practice retry must clear the ascent edge memory")
	_expect(runtime.effect_controller.hologram_disk_active, "practice retry must keep the item effect timer running (decoy-only cleanup)")
	# 즉시 재상승: 정리 직후 첫 상승에서 스폰·롤이 정상 재무장돼야 한다.
	var roll_count_before_rearm: int = runtime.effect_controller.hologram_deception_roll_count
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(Vector2(380.0, 680.0), Vector2(4.0, -12.0)), {})
	_expect(runtime.effect_controller.hologram_decoys.size() == 2, "the first ascent after a practice retry must respawn decoys")
	_expect(runtime.effect_controller.hologram_deception_roll_count == roll_count_before_rearm + 1, "the first ascent after a practice retry must roll exactly once more")

	# timeout 재시도(8초 경과)도 같은 정리 계약을 타야 한다 — 이 경로는
	# hold/skip 조기 반환 때문에 공-경로 훅·score 인터셉트 어디에도 닿지
	# 않는다(카페인 지속 보너스로 효과가 8초를 넘기는 실경로).
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	_expect(runtime.effect_controller.hologram_locked_decoy_index >= 0, "timeout leg setup should hold a locked decoy")
	runtime.effect_controller.hologram_decoy_pop_particles.append({
		"pos": Vector2(70.0, 80.0), "flicker_seed": 556.5, "age_frames": 1.0, "lifetime_frames": 12.0,
	})
	var practice: Object = ViperPracticeMode.new()
	practice._phase = ViperPracticeMode.PHASE_AWAIT_MARSHAL
	var timeout_registry := FakeRegistry.new()
	timeout_registry.cached_instances["active_item_runtime"] = runtime
	var timeout_advanced: bool = bool(practice._update_await_marshal(9.0, owner, timeout_registry))
	_expect(timeout_advanced, "the 8s marshal timeout must switch back to the hold phase (leg precondition)")
	_expect(runtime.effect_controller.hologram_decoys.is_empty(), "the timeout retry must clear stale decoys through the shared cleanup contract")
	_expect(runtime.effect_controller.hologram_decoy_pop_particles.is_empty(), "the timeout retry must clear in-flight pop particles")
	_expect(runtime.effect_controller.hologram_locked_decoy_index == -1, "the timeout retry must clear the stale deception lock")
	_expect(not bool(runtime.effect_controller.hologram_last_ball_ascending), "the timeout retry must clear the ascent edge memory")


func _leg_production_fps_scale_reaches_predictor() -> void:
	# 72Hz production 배관 관통: predictor 내부 수학 fixture만으로는
	# BossAiState→predictor 호출면의 fps 인자 전달을 지우거나 whip의
	# 마지막 fps_scale 인자를 빼도 GREEN이다 — spy predictor로 실
	# update(1/72) 구동에서 세 호출면(일반 추적·whip·chained-dash)이
	# 전부 live scale(5/6)과 홀로그램 경계를 함께 전달하는 것을 봉인한다.
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	_register_runtime(registry, runtime)
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	_force_locked_decoy(runtime.effect_controller, Vector2(400.0, 520.0), Vector2(3.0, -10.0))
	var context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	context["boss_mistake_chance"] = 0.0
	context["boss_dash_enabled"] = false
	var margin: float = ActiveItemHologramDiskRuntime.DECOY_WALL_MARGIN
	var live_scale: float = 60.0 / 72.0

	# (1) 일반 추적: 실 update(1/72) 구동 — future 호출이 live scale+경계.
	var spy := SpyPredictionState.new()
	var boss_state: Object = BossAiState.new()
	boss_state.prediction_state = spy
	boss_state.update(1.0 / 72.0, Vector2(300.0, 25.0), 0.0, context)
	_expect(not spy.future_scale_calls.is_empty(), "the 72Hz tracking update must reach the predictor (leg precondition)")
	var tracking_call: Dictionary = spy.future_scale_calls[spy.future_scale_calls.size() - 1]
	_expect(abs(float(tracking_call.get("fps_scale", -1.0)) - live_scale) <= 0.0001, "the tracking call site must forward the live 72Hz fps_scale (5/6) to the predictor")
	_expect(is_equal_approx(float(tracking_call.get("play_left", -1.0)), margin), "the tracking call site must forward the hologram left bound together with the scale")
	_expect(is_equal_approx(float(tracking_call.get("play_right", -1.0)), 760.0 - margin), "the tracking call site must forward the hologram right bound together with the scale")

	# (2) whip-deactivation 분기: exact 호출이 live scale+경계.
	var whip_context: Dictionary = context.duplicate(true)
	whip_context["stage1_dalji_whip_deactivation_active"] = true
	var whip_spy := SpyPredictionState.new()
	var whip_boss_state: Object = BossAiState.new()
	whip_boss_state.prediction_state = whip_spy
	whip_boss_state.update(1.0 / 72.0, Vector2(300.0, 25.0), 0.0, whip_context)
	_expect(not whip_spy.exact_scale_calls.is_empty(), "the 72Hz whip-deactivation update must reach the exact-arrival predictor (leg precondition)")
	var whip_call: Dictionary = whip_spy.exact_scale_calls[whip_spy.exact_scale_calls.size() - 1]
	_expect(abs(float(whip_call.get("fps_scale", -1.0)) - live_scale) <= 0.0001, "the whip call site must forward the live 72Hz fps_scale as its trailing argument (dropping it falls back to 1.0)")
	_expect(is_equal_approx(float(whip_call.get("play_left", -1.0)), margin), "the whip call site must forward the hologram left bound together with the scale")
	_expect(is_equal_approx(float(whip_call.get("play_right", -1.0)), 760.0 - margin), "the whip call site must forward the hologram right bound together with the scale")

	# (3) chained-dash: 함수 직접 구동으로 future 호출의 scale 전달 봉인.
	var dash_spy := SpyPredictionState.new()
	var dash_boss_state: Object = BossAiState.new()
	dash_boss_state.prediction_state = dash_spy
	dash_boss_state.boss_dash_max_tokens = 2
	dash_boss_state.boss_dash_tokens = 2
	var dash_context: Dictionary = context.duplicate(true)
	dash_context["boss_dash_chain_enabled"] = true
	dash_boss_state._try_start_chained_boss_dash(Vector2(300.0, 25.0), dash_context, live_scale)
	_expect(not dash_spy.future_scale_calls.is_empty(), "the chained-dash targeting must reach the predictor (leg precondition)")
	var dash_call: Dictionary = dash_spy.future_scale_calls[dash_spy.future_scale_calls.size() - 1]
	_expect(abs(float(dash_call.get("fps_scale", -1.0)) - live_scale) <= 0.0001, "the chained-dash call site must forward its fps_scale argument to the predictor")
	_expect(is_equal_approx(float(dash_call.get("play_left", -1.0)), margin), "the chained-dash call site must forward the hologram left bound together with the scale")

	# (4) future 경로 내부 전파: predict_future_x가 받은 scale을 O(1)
	# 도착 계산까지 내려보내는지 — 72Hz future 결과가 실 분신(5/6 tick)
	# 도착 x와 일치해야 한다(내부에서 scale을 버리면 ceil 잔차만큼 이탈).
	_force_locked_decoy(runtime.effect_controller, Vector2(380.0, 690.0), Vector2(34.13, -7.7))
	var future_context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	future_context["boss_mistake_chance"] = 0.0
	var future_predicted_x: float = BossAiPredictionState.new().predict_future_x(
		_get_vector2(future_context, "ball_pos", Vector2.ZERO),
		_get_vector2(future_context, "ball_vel", Vector2.ZERO),
		live_scale,
		float(future_context.get("prediction_play_left", 0.0)),
		float(future_context.get("prediction_play_right", 760.0)),
		100.0,
		future_context
	)
	var future_intercept_y: float = 25.0 + 40.0 + 5.0 + 28.6 * 0.5
	var future_simulated_x: float = -100000.0
	for _future_frame in range(2100):
		runtime.effect_controller.apply_hologram_decoy_tick(live_scale, _ascending_context(Vector2(120.0, 500.0), Vector2(0.0, -10.0)), {})
		var future_decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
		var future_pos: Vector2 = _get_vector2(future_decoy, "pos", Vector2.ZERO)
		if future_pos.y <= future_intercept_y or not bool(future_decoy.get("alive", false)):
			future_simulated_x = future_pos.x
			break
	_expect(future_simulated_x > -99999.0, "the future-path 72Hz decoy simulation must reach the boss intercept band")
	_expect(abs(future_predicted_x - future_simulated_x) <= 1.0, "predict_future_x must propagate its fps_scale into the O(1) arrival fold (dropping it inside the chain drifts by the ceil residue)")


# 락 분신을 주어진 pos/vel로 강제하고, 기만 컨텍스트 예측 x와 실 분신
# 정수-tick 시뮬 도착 x의 차이를 돌려준다(파리티 fixture 공용).
func _predict_vs_simulated_arrival_gap(runtime: Object, owner: Object, registry: FakeRegistry, decoy_pos: Vector2, decoy_vel: Vector2, fps_scale: float = 1.0) -> float:
	_force_locked_decoy(runtime.effect_controller, decoy_pos, decoy_vel)
	var context: Dictionary = BossAiContextBuilder.new().build_context(owner, registry)
	var predicted_x: float = BossAiPredictionState.new().predict_exact_arrival_x(
		_get_vector2(context, "ball_pos", Vector2.ZERO),
		_get_vector2(context, "ball_vel", Vector2.ZERO),
		float(context.get("prediction_play_left", 0.0)),
		float(context.get("prediction_play_right", 760.0)),
		100.0,
		context,
		fps_scale
	)
	var intercept_y: float = 25.0 + 40.0 + 5.0 + 28.6 * 0.5
	var simulated_x: float = -100000.0
	for _frame in range(2100):
		runtime.effect_controller.apply_hologram_decoy_tick(fps_scale, _ascending_context(Vector2(120.0, 500.0), Vector2(0.0, -10.0)), {})
		var decoy: Dictionary = runtime.effect_controller.hologram_decoys[0]
		var decoy_position: Vector2 = _get_vector2(decoy, "pos", Vector2.ZERO)
		if decoy_position.y <= intercept_y or not bool(decoy.get("alive", false)):
			simulated_x = decoy_position.x
			break
	if simulated_x < -99999.0:
		return 100000.0
	return predicted_x - simulated_x


func _ball_update_context(ball_pos: Vector2, ball_vel: Vector2) -> Dictionary:
	return {
		"selected_character_type": "smasher",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"ball_size": 28.6,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_impact_boost": 1.0,
		"player_collision_cooldown": 10.0,
		"boss_collision_cooldown": 10.0,
		"min_ball_speed": 3.0,
		"max_ball_speed": 30.0,
		"max_bounce_angle": 60.0,
		"special_gauge": 0.0,
		"waiting_for_serve": false,
		"skip_ball_motion_step": false,
	}


func _new_runtime() -> Object:
	var runtime: Object = ActiveItemRuntime.new()
	var guard := 0
	while not bool(runtime.prewarm_initialization_step(true)) and guard < 64:
		guard += 1
	_expect(guard < 64, "active item runtime prewarm should complete")
	return runtime


func _register_runtime(registry: FakeRegistry, runtime: Object) -> void:
	registry.instances["active_item_runtime"] = runtime
	registry.cached_instances["active_item_runtime"] = runtime


func _fresh_active_controller(chance_override: float) -> Object:
	var runtime: Object = _new_runtime()
	var registry := FakeRegistry.new()
	var owner := FakeOwner.new()
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = chance_override
	return runtime.effect_controller


func _dirty_hologram_runtime(runtime: Object, owner: Object, registry: FakeRegistry) -> void:
	runtime.effect_controller.activate_hologram_disk(owner, registry)
	runtime.effect_controller.hologram_disk_deception_chance_override = 1.0
	runtime.effect_controller.apply_hologram_decoy_tick(1.0, _ascending_context(owner.ball_pos, owner.ball_vel), {})
	runtime.effect_controller.hologram_last_ball_ascending = true
	runtime.effect_controller.hologram_disk_timer_frames = 240.0


func _ascending_context(pos: Vector2, vel: Vector2) -> Dictionary:
	return {
		"ball_pos": pos,
		"ball_vel": vel,
		"waiting_for_serve": false,
		"skip_ball_motion_step": false,
	}


func _force_locked_decoy(controller: Object, pos: Vector2, vel: Vector2) -> void:
	_expect(controller.hologram_decoys.size() > 0, "setup should have at least one hologram decoy")
	var decoy: Dictionary = controller.hologram_decoys[0]
	decoy["pos"] = pos
	decoy["vel"] = vel
	decoy["alive"] = true
	controller.hologram_decoys[0] = decoy
	controller.hologram_locked_decoy_index = 0
	controller.hologram_deception_flight_active = true
	controller.hologram_deception_roll_locked = true


func _hologram_cleared(controller: Object) -> bool:
	return (
		not bool(controller.hologram_disk_active)
		and is_equal_approx(float(controller.hologram_disk_timer_frames), 0.0)
		and controller.hologram_decoys.is_empty()
		and controller.hologram_decoy_pop_particles.is_empty()
		and int(controller.hologram_locked_decoy_index) == -1
		and not bool(controller.hologram_deception_flight_active)
		and not bool(controller.hologram_deception_roll_locked)
		and not bool(controller.hologram_last_ball_ascending)
	)


func _run_leg(leg_name: String, callback: Callable) -> void:
	var failure_count_before: int = _failures.size()
	callback.call()
	if _failures.size() == failure_count_before:
		print("active_item_hologram_disk_smoke: PASS %s" % leg_name)
	else:
		print("active_item_hologram_disk_smoke: FAIL %s" % leg_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
