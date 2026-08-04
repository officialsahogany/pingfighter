extends SceneTree

# 백린 A5 카탈로그 활성화 씰 — S1 정적 정면 프레젠테이션 + 묵린변신 액티브.
#
# Commit A(정적 모델 인프라)에서 "정적 펫 실존 필요"로 이월된 관통 레그를 여기서
# 봉인한다:
#  - A5 엔트리 검증(파일 실재 포함) · 정적 모델 판정 · 스킬/디스패처 계약
#  - 페이로드 화이트리스트: transform_duration이 카탈로그→launch payload로 전달
#  - D5a/D5c 레이아웃 메타 · 별칭 1×1·1f 메타
#  - 호스트 dismiss 로드 게이트: 정적 펫은 외래(마리보) 폴백 시트를 로드하지 않음
#  - 전투 클릭: false + 무음(스파이 오디오 0콜) — 98f 키 자체가 카탈로그에 없음
#  - Y1: 정보창 Live2D 맵 미등재(정적 원화 자연 폴백 유지)
#  - D15: 백린 활성 상태에서 launch → is_mokrin_transform_active 왕복
#
# 잔여(비봉인, 명시): 클릭 false가 "요약 게이트 중 어느 것"에서 떨어지는지는
# 세분하지 않는다(무음·false 결과 계약만 봉인). 운영 complete_launch 전체 프레임
# 플로는 별도 운영 QA에서 확인.

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const PayloadBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
const AcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")
const PanelTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleUpdatePlayerControlDepsBuilder := preload("res://scripts/core/battle_update_player_control_deps_builder.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

var _failed := false


class StubCutinRuntime:
	extends RefCounted

	var pet_id := "baekrin"

	func is_acquire_cutin_active() -> bool:
		return true

	func is_acquire_cutin_dismissing() -> bool:
		return true

	func get_acquire_cutin_dismiss_progress() -> float:
		return 0.5

	func get_snapshot() -> Dictionary:
		return {"cutin_pet_id": pet_id, "active_pet_id": pet_id, "pet_id": pet_id}


class HostDrawProbe:
	extends Node2D

	var host: RefCounted = null
	var runtime: RefCounted = null

	func _draw() -> void:
		if host != null and runtime != null:
			host.draw(self, runtime, Vector2(400.0, 300.0))


class SpyAudio:
	extends RefCounted

	var click_calls := 0

	func play_lingpet_click_reaction(_pet_id: String) -> void:
		click_calls += 1


class SpyRegistry:
	extends RefCounted

	var audio: SpyAudio = SpyAudio.new()
	var instances: Dictionary = {}

	func get_cached_instance(key: String) -> Variant:
		if key == "game_audio":
			return audio
		return instances.get(key, null)

	func get_instance(key: String) -> Variant:
		return get_cached_instance(key)


# egg.update()를 운영 형태로 구동하기 위한 owner 픽스처 — lingpet_egg_runtime_smoke의
# FakeOwner와 동일 형태(그 스모크가 운영 update 관통의 선례).
class FakeOwner:
	extends RefCounted

	var ai_mode := "junior league"
	var current_stage := 1
	var selected_character_type := "smasher"
	var player_pos := Vector2(263.75, 675.0)
	var player_paddle_width := 232.5
	var player_paddle_height := 75.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var lingpet_puppet_grab_active := false
	var lingpet_star_coil_boss_slow_active := false
	var lingpet_star_coil_boss_slow_multiplier := 1.0
	var lingpet_star_coil_block_boss_dash := false
	var lingpet_star_coil_freeze_boss_skill_cd := false
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_pos_prev := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_serve_origin := ""
	var ball_size := 28.6
	var rally_speed_cap_bonus := 0.0
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var lingpet_id := ""
	var active_lingpet_id := ""
	var current_lingpet_id := ""
	var lingpet_state := "none"
	var ringpet_state := "none"
	var lingpet_hatch_hits := 0
	var ringpet_hatch_hits := 0
	var lingpet_hatch_required_hits := 3
	var ringpet_hatch_required_hits := 3
	var lingpet_egg_pos := Vector2.ZERO
	var lingpet_companion_pos := Vector2.ZERO
	var ringpet_companion_pos := Vector2.ZERO
	var lingpet_companion_patrol_speed_default := 120.0
	var ringpet_companion_patrol_speed_default := 120.0
	var lingpet_companion_patrol_speed_min := 70.0
	var ringpet_companion_patrol_speed_min := 70.0
	var lingpet_companion_patrol_speed_max := 135.0
	var ringpet_companion_patrol_speed_max := 135.0
	var lingpet_companion_catch_width := 100.0
	var ringpet_companion_catch_width := 100.0
	var lingpet_companion_catch_height := 44.0
	var ringpet_companion_catch_height := 44.0
	var lingpet_companion_defense_rate := 0.0
	var ringpet_companion_defense_rate := 0.0
	var lingpet_companion_appearance_rate := 0.0
	var ringpet_companion_appearance_rate := 0.0
	var lingpet_companion_defense_intercept_active := false
	var ringpet_companion_defense_intercept_active := false
	var lingpet_companion_defense_intercept_target_x := 0.0
	var ringpet_companion_defense_intercept_target_x := 0.0
	var lingpet_companion_contact_count := 0
	var ringpet_companion_contact_count := 0
	var lingpet_companion_last_contact_pos := Vector2.ZERO
	var ringpet_companion_last_contact_pos := Vector2.ZERO
	var lingpet_companion_hit_cooldown := 0.0
	var ringpet_companion_hit_cooldown := 0.0
	var lingpet_companion_hit_gauge_gain := 0.0
	var ringpet_companion_hit_gauge_gain := 0.0
	var lingpet_companion_hit_gauge_last_gain := 0.0
	var ringpet_companion_hit_gauge_last_gain := 0.0
	var lingpet_companion_hit_gauge_trigger_count := 0
	var ringpet_companion_hit_gauge_trigger_count := 0
	var lingpet_skill_id := ""
	var ringpet_skill_id := ""
	var lingpet_active_skill_id := ""
	var ringpet_active_skill_id := ""
	var lingpet_active_skill_level := 0
	var ringpet_active_skill_level := 0
	var lingpet_second_active_skill_id := ""
	var ringpet_second_active_skill_id := ""
	var lingpet_second_active_skill_level := 0
	var ringpet_second_active_skill_level := 0
	var lingpet_active_skill_max_level := 0
	var ringpet_active_skill_max_level := 0
	var lingpet_skill_name := ""
	var ringpet_skill_name := ""
	var lingpet_skill_cooldown := 0.0
	var ringpet_skill_cooldown := 0.0
	var lingpet_skill_cooldown_duration := 40.0
	var ringpet_skill_cooldown_duration := 40.0
	var lingpet_skill_ready := false
	var ringpet_skill_ready := false
	var lingpet_skill_last_gain := 0.0
	var ringpet_skill_last_gain := 0.0
	var lingpet_skill_trigger_count := 0
	var ringpet_skill_trigger_count := 0
	var lingpet_second_skill_id := ""
	var ringpet_second_skill_id := ""
	var lingpet_second_skill_name := ""
	var ringpet_second_skill_name := ""
	var lingpet_second_skill_max_level := 0
	var ringpet_second_skill_max_level := 0
	var lingpet_second_skill_cooldown := 0.0
	var ringpet_second_skill_cooldown := 0.0
	var lingpet_second_skill_cooldown_duration := 0.0
	var ringpet_second_skill_cooldown_duration := 0.0
	var lingpet_second_skill_ready := false
	var ringpet_second_skill_ready := false
	var lingpet_second_skill_winding_up := false
	var ringpet_second_skill_winding_up := false
	var lingpet_second_skill_windup_ratio := 0.0
	var ringpet_second_skill_windup_ratio := 0.0
	var lingpet_skill_icon_path := ""
	var ringpet_skill_icon_path := ""
	var lingpet_passive_skill_id := ""
	var ringpet_passive_skill_id := ""
	var lingpet_passive_skill_level := 0
	var ringpet_passive_skill_level := 0
	var lingpet_passive_skill_max_level := 0
	var ringpet_passive_skill_max_level := 0
	var lingpet_passive_skill_name := ""
	var ringpet_passive_skill_name := ""
	var lingpet_passive_skill_description := ""
	var ringpet_passive_skill_description := ""
	var lingpet_passive_skill_icon_path := ""
	var ringpet_passive_skill_icon_path := ""
	var lingpet_gauge_gain_bonus_pct := 0.0
	var ringpet_gauge_gain_bonus_pct := 0.0
	var lingpet_player_speed_bonus_pct := 0.0
	var ringpet_player_speed_bonus_pct := 0.0
	var lingpet_starpoint_tracking_chance_pct := 0.0
	var ringpet_starpoint_tracking_chance_pct := 0.0
	var lingpet_ring_dash_chance_pct := 0.0
	var ringpet_ring_dash_chance_pct := 0.0
	var lingpet_ring_dash_force_roll_pct := -1.0
	var lingpet_effect_text := ""
	var lingpet_owned_pet_ids: Array = []
	var owned_lingpet_ids: Array = []
	var owned_ringpet_ids: Array = []
	var lingpet_collection: Dictionary = {}
	var ringpet_collection: Dictionary = {}
	var owned_lingpets: Dictionary = {}
	var owned_ringpets: Dictionary = {}
	var lingpet_loadouts: Dictionary = {}
	var ringpet_loadouts: Dictionary = {}
	var owned_lingpet_loadouts: Dictionary = {}
	var owned_ringpet_loadouts: Dictionary = {}
	var lingpet_slots: Array = ["", "", ""]
	var ringpet_slots: Array = ["", "", ""]
	var lingpet_slot_pet_ids: Array = ["", "", ""]
	var ringpet_slot_pet_ids: Array = ["", "", ""]
	var lingpet_active_slot_index := 0
	var ringpet_active_slot_index := 0


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_test_catalog_entry_valid()
	_test_static_model_and_skill_contract()
	_test_payload_whitelist()
	_test_layout_meta()
	_test_panel_live2d_map_unregistered()
	await _test_host_dismiss_load_gate()
	_test_click_sealed_silent()
	_test_launch_roundtrip()
	_test_p1_production_frame_flow()
	await _test_p2_static_ready_gates_on_art()
	_test_real_hatch_path_reaches_baekrin()
	ProjectResourceLoader.clear_caches()
	if _failed:
		printerr("lingpet_baekrin_static_activation_smoke: FAILED")
		quit(1)
		return
	print("lingpet_baekrin_static_activation_smoke: ok")
	quit(0)


func _test_catalog_entry_valid() -> void:
	var entry := LingpetCatalog.get_entry("baekrin")
	_expect("baekrin 엔트리 존재", str(entry.get("id", "")) == "baekrin")
	var issues := LingpetCatalog.validate_entry("baekrin", entry, true)
	_expect("baekrin 검증 이슈 0 (파일 실재 포함): %s" % str(issues), issues.is_empty())


func _test_static_model_and_skill_contract() -> void:
	_expect("baekrin은 static 모델", LingpetCatalog.is_front_presentation_static("baekrin"))
	var skill := LingpetCatalog.get_active_skill("baekrin")
	_expect("스킬 id", str(skill.get("id", "")) == "baekrin_mokrin_transform")
	_expect("runtime_kind = mokrin_transform", str(skill.get("runtime_kind", "")) == "mokrin_transform")
	_expect("쿨다운 40초", is_equal_approx(float(skill.get("cooldown", 0.0)), 40.0))
	_expect("flash style = mokrin_ink", str(skill.get("companion_skill_flash_style", "")) == "mokrin_ink")
	_expect("카드 경로 등재", str(skill.get("card_texture_path", "")).contains("baekrin_mokrin_transform_skillcard"))
	_expect("디스패처 지원", LingpetSkillDispatcher.has_supported_runtime("baekrin_mokrin_transform"))
	_expect(
		"동적 정면 키 부재 (cutin_anim)",
		LingpetCatalog.get_visual_path("baekrin", "cutin_anim") == ""
	)
	_expect(
		"전투 클릭 98f 키 부재",
		LingpetCatalog.get_visual_path("baekrin", "companion_click_reaction_anim") == ""
	)


func _test_payload_whitelist() -> void:
	var skill := LingpetCatalog.get_active_skill("baekrin")
	var payload: Dictionary = PayloadBuilder.new().build(
		skill, "baekrin_mokrin_transform", 1, Vector2(100.0, 600.0), 26.0, null
	)
	_expect(
		"payload.transform_duration = 5.0 (화이트리스트 전달)",
		is_equal_approx(float(payload.get("transform_duration", -1.0)), 5.0)
	)


func _test_layout_meta() -> void:
	var checks := {
		"companion_puppet_control_cols": 6.0,
		"companion_puppet_control_rows": 2.0,
		"companion_puppet_control_frame_count": 12.0,
		"companion_puppet_control_draw_size": 92.0,
		"companion_puppet_control_y_offset_delta": 6.0,
		"companion_walk_cols": 1.0,
		"companion_walk_frame_count": 1.0,
		"companion_strike_frame_count": 1.0,
		"companion_cast_frame_count": 1.0,
		"companion_idle_frame_count": 1.0,
		"companion_move_left_frame_count": 1.0,
		"companion_move_right_frame_count": 1.0,
	}
	for key in checks.keys():
		var got := LingpetCatalog.get_visual_layout_value("baekrin", str(key), -999.0)
		_expect(
			"layout %s = %s (실측 %s)" % [str(key), str(checks[key]), str(got)],
			is_equal_approx(got, float(checks[key]))
		)


func _test_panel_live2d_map_unregistered() -> void:
	var map: Dictionary = PanelTextureLoader.PANEL_LIVE2D_VISUAL_KEYS_BY_PET_ID
	_expect("Y1: 패널 Live2D 맵에 baekrin 미등재 (정적 원화 자연 폴백)", not map.has("baekrin"))


func _test_host_dismiss_load_gate() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 300)
	root.add_child(viewport)

	# 정적 펫: dismiss 시트가 null로 남아야 한다 (외래 마리보 폴백 차단).
	var host := AcquireCutinOverlayHost.new()
	var runtime := StubCutinRuntime.new()
	var probe := HostDrawProbe.new()
	probe.host = host
	probe.runtime = runtime
	viewport.add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect("정적 펫(baekrin): dismiss 시트 미로드 (null 유지)", host._cutin_dismiss_sheet == null)

	# 대조군(dynamic 마리보): 같은 경로에서 폴백/시트 로드가 일어난다. 스파스 검증
	# 환경에서 imported 텍스처가 없으면 판별 불가라 명시 SKIP.
	var maribo_path := LingpetCatalog.get_visual_path("maribo", "cutin_dismiss_anim")
	var maribo_loadable: bool = ProjectResourceLoader.load_imported_texture(maribo_path, "", "") != null
	if maribo_loadable:
		runtime.pet_id = "maribo"
		host._cutin_dismiss_sheet = null
		probe.queue_redraw()
		await process_frame
		await process_frame
		_expect("대조군(maribo): dismiss 시트 로드됨 (게이트 판별력)", host._cutin_dismiss_sheet != null)
	else:
		print("SKIP: maribo dismiss 시트 임포트 부재(스파스 환경) — 대조군 레그는 풀 저장소에서만")

	viewport.queue_free()
	await process_frame


func _test_click_sealed_silent() -> void:
	var egg := LingpetEggRuntime.new()
	egg.debug_grant_and_activate_pet("baekrin")
	var registry := SpyRegistry.new()
	var began: bool = egg.try_begin_companion_click_reaction(Vector2(100.0, 600.0), registry)
	_expect("전투 클릭: false (정적 모델 — 98f 텍스처 자체가 없음)", began == false)
	_expect("전투 클릭: 무음 (스파이 오디오 0콜, 실측 %d)" % registry.audio.click_calls, registry.audio.click_calls == 0)
	_expect("클릭 상태 비활성 유지", not egg.is_companion_click_reaction_active())


func _test_launch_roundtrip() -> void:
	var egg := LingpetEggRuntime.new()
	egg.debug_grant_and_activate_pet("baekrin")
	_expect("발동 전 비활성", not egg.is_mokrin_transform_active())
	var launched: bool = egg.launch_mokrin_transform_for_tests()
	_expect("백린 활성 상태에서 묵린변신 launch 성공", launched)
	_expect("D15: is_mokrin_transform_active true", egg.is_mokrin_transform_active())


func _test_p1_production_frame_flow() -> void:
	# P1 씰 (2026-08-04 리뷰): 테스트 훅 없이 운영 경로만으로 —
	# ① update_player_control: 발동 전 무동작 (비활성 대조군)
	# ② 실제 입력(하강 공)을 넣은 egg.update()가 컨트롤러 ARM/LAUNCH를 발동
	# ③ 다음 update_player_control이 자동조작을 최초 소비.
	var egg := LingpetEggRuntime.new()
	var owner := FakeOwner.new()
	var registry := SpyRegistry.new()
	registry.instances["lingpet_egg_runtime"] = egg
	# 디버그 grant는 액티브 스킬을 자동 장착하지 않는다(companion_skill_id="") —
	# 운영 arm 경로를 열려면 명시 장착이 필요.
	egg.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_mokrin_transform")
	owner.ball_active = true
	owner.ball_pos = Vector2(380.0, 300.0)
	owner.ball_pos_prev = Vector2(380.0, 290.0)
	owner.ball_vel = Vector2(0.0, 10.0)

	var deps: Dictionary = BattleUpdatePlayerControlDepsBuilder.new().build_deps(registry)
	var controller: Object = SmasherPlayerController.new()
	var config := {
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
		"paddle_decel": 0.5,
		"paddle_turn_decel": 1.0,
		"special_gauge": 0.0,
		"ball_pos": Vector2(380.0, 375.0),
		"selected_character_type": "smasher",
	}
	var start := Vector2(100.0, 675.0)

	var before: Dictionary = controller.update(0.016, 0, start, 0.0, config, deps)
	var before_pos: Vector2 = before.get("player_pos", start)
	_expect("P1①: 발동 전 update_player_control 무동작 (대조군)", is_equal_approx(before_pos.x, start.x))

	var became := false
	var frames := 0
	for i in range(600):
		egg.update(0.016, owner, registry)
		frames += 1
		if egg.is_mokrin_transform_active():
			became = true
			break
	_expect("P1②: 운영 egg.update()만으로 ARM/LAUNCH 발동 (%d프레임)" % frames, became)

	var after: Dictionary = controller.update(0.016, 0, start, 0.0, config, deps)
	var after_pos: Vector2 = after.get("player_pos", start)
	_expect("P1③: 다음 update_player_control이 자동조작 최초 소비 (Δx=%.2f)" % (after_pos.x - start.x),
		after_pos.x > start.x + 0.5)


func _test_p2_static_ready_gates_on_art() -> void:
	# P2 씰 (2026-08-04 리뷰): 정적 모델의 리빌 준비 판정은 cutin_art 캐시를
	# 게이트한다 — 콜드 상태에서 ready=false, 프리웜 스텝 후 true.
	var host := AcquireCutinOverlayHost.new()
	ProjectResourceLoader.clear_caches()
	var art_path := LingpetCatalog.get_visual_path("baekrin", "cutin_art")
	_expect("P2 전제: baekrin cutin_art 경로 등재", art_path != "")
	var cold_ready: bool = host.is_pet_cutin_anim_ready("baekrin")
	# 준비 판정 자체가 프리웜 스텝을 밟지만 로드는 스레드 기반이라 프레임 대기가
	# 필요하다. 임포트 캐시가 있는 환경에서는 수 프레임 안에 true로 수렴해야 하고,
	# 첫 콜드 호출은 false여야 한다. 임포트 산출물이 없는 스파스 검증 환경에서는
	# 영원히 준비되지 않으므로 명시 SKIP.
	var became_ready := cold_ready
	for i in range(120):
		if became_ready:
			break
		await process_frame
		became_ready = host.is_pet_cutin_anim_ready("baekrin")
	if became_ready:
		_expect("P2: 콜드 첫 판정은 false (원화 캐시 게이트)", not cold_ready)
		_expect("P2: 프리웜 스텝 경유 후 ready=true 수렴", became_ready)
	else:
		print("SKIP: baekrin cutin_art 임포트 산출물 부재(스파스 환경) — P2 수렴 레그는 풀 저장소에서만")
		_expect("P2: 콜드 판정 false (게이트 자체는 스파스에서도 증명)", not cold_ready)
	ProjectResourceLoader.clear_caches()


func _test_real_hatch_path_reaches_baekrin() -> void:
	# 라이브 QA가 F7 디버그 획득으로 우회했던 유일 관문 — 실제 알 충돌 →
	# 껍질 파괴 → _commit_pending_hatch() — 를 실 기계로 관통한다 (2026-08-04
	# 리뷰 잔여). 부화 룰렛에는 고정 훅이 없으므로 두 층으로 봉인:
	#   결정층 = baekrin이 junior/smasher 실 부화 풀에 등재
	#   관통층 = 반복 추첨으로 baekrin 실부화 도달 — (14/15)^300 ≈ 1e-9라
	#            통계적 RED는 사실상 불가
	var candidates: Array[String] = LingpetCatalog.get_hatch_candidates({
		"league_mode": "junior",
		"character_type": "smasher",
	}, [])
	_expect("실 부화 풀에 baekrin 등재 (결정층)", candidates.has("baekrin"))

	var hatched_baekrin := false
	var attempts := 0
	var mechanics_ok := true
	for i in range(300):
		attempts += 1
		var owner := FakeOwner.new()
		var egg := LingpetEggRuntime.new()
		egg.update(0.0, owner)
		var egg_pos: Vector2 = owner.lingpet_egg_pos
		owner.ball_active = true
		owner.ball_pos = egg_pos + Vector2(0.0, -8.0)
		owner.ball_vel = Vector2(0.0, 12.0)
		egg.update(0.0, owner)
		var guard := 0
		while bool(egg.is_hatch_break_active()) and guard < 300:
			egg.advance_hatch_break(1.0 / 60.0, owner, null)
			guard += 1
		if str(owner.lingpet_state) != "companion":
			mechanics_ok = false
			break
		if str(owner.active_lingpet_id) == "baekrin":
			hatched_baekrin = true
			_expect("실 부화(baekrin): 소유 목록 등재", owner.lingpet_owned_pet_ids.has("baekrin"))
			_expect("실 부화(baekrin): 슬롯 0 활성", str((owner.lingpet_slots as Array)[0]) == "baekrin")
			_expect(
				"실 부화(baekrin): 획득 컷인 활성 (_commit_pending_hatch 경유)",
				bool(egg.is_acquire_cutin_active())
			)
			egg.advance_acquire_cutin(10.0, null)
			break
	_expect("모든 추첨에서 실 부화 기계가 companion까지 도달", mechanics_ok)
	_expect("실 부화 경로로 baekrin 도달 (%d회 추첨)" % attempts, hatched_baekrin)
