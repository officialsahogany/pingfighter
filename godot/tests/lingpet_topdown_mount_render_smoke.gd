extends SceneTree

# S3-b 슬라이스 B 씰 — 탑다운 합성 렌더 배선.
#
# 봉인 범위(§9-b B):
#  - P16② 완결: A 가 보존한 readiness 의 rider_texture **객체**가 scene context 까지
#    재조회 없이 그대로 전달된다(동일 객체 ===, 캐시 교체 분기 포함).
#  - P15: L1~L4 가 **공용 레이어 헬퍼** 진입 정확히 1회씩이고 중심이 전부 M exact
#    center 다(lane 중심 진입 0회). 비탑승 대조군이 lane 중심 진입을 실제로 잡는다.
#  - P12: M exact-dest — 선언된 draw_size 그대로, 안장 소켓이 seat point 와 일치,
#    시간 경과 dest 불변(bob·−6 무가산). 레이아웃 결손은 fail-closed(그리기 0회).
#  - P13: 게이지가 **visible=true** 로 M 중심·M draw_size 기하(Y 오프셋 0)를 쓴다.
#  - P9/P1: 탑승 중 메인 본체 억제 + 공존 아이템 알 보존, 비탑승 대조군은 종전대로.
#
# defer(§C-1)·P11(착석 셀 rect)·actor context 전달 레그는 플레이어 렌더러 재구성(병행 WIP) 랜딩과
# 함께 B-1b 에서 합류한다. P3/P8(z 순서·숨김 3경로 픽셀)은 프로토타입 픽셀 QA
# 하네스(§7) 소관 — 이 파일은 에셋 0장 인메모리 골격 씰이다.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetDurationFieldGaugeRenderer := preload("res://scripts/lingpet/lingpet_duration_field_gauge_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")

const MOUNT_FIXTURE_PATH := "res://__fixture__/topdown_render_mount_base.png"

# 실 M 규격(§B-2 6키). 1px·5×5 기본값 보정은 런타임에서 제거됐으므로 씰도 실제
# 시트 규격과 안장 소켓을 그대로 공급한다 — 그래야 P12/P13 이 진짜 기하를 잰다.
const MOUNT_CELL_PX := 64.0
const MOUNT_COLS := 1.0
const MOUNT_ROWS := 1.0
const MOUNT_FRAMES := 1.0
const MOUNT_DRAW_SIZE := 112.0
const MOUNT_SADDLE_X := 32.0
const MOUNT_SADDLE_Y := 52.0

var _failed := false
var _mount_fixture_texture: Texture2D = null
var _probe: Node2D = null


class FakeInputProbe:
	extends RefCounted

	var rmb := false
	var down := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return down


class OperationalOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 675.0)
	var player_paddle_width := 155.0
	var player_speed := 0.0
	var selected_character_type := "smasher"
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6


class SpyBattleResources:
	extends RefCounted

	var resource_cache: Dictionary = {}

	func get_resource_cache() -> Dictionary:
		return resource_cache


class SpyRegistry:
	extends RefCounted

	var cached: Dictionary = {}

	func get_cached_instance(key: String) -> Variant:
		return cached.get(key, null)

	func get_instance(key: String) -> Variant:
		return cached.get(key, null)


# 본체/합성 draw 호출을 세고 합성 인자를 캡처한다.
class SpyCompanionRenderer:
	extends RefCounted

	var body_draw_calls := 0
	var composite_calls := 0
	var last_dest := Rect2()
	var last_source := Rect2()
	var last_radius := 0.0

	func draw_companion(_canvas: CanvasItem, _center: Vector2, _config: Dictionary) -> void:
		body_draw_calls += 1

	func draw_topdown_mount_composite(_canvas: CanvasItem, dest_rect: Rect2, _texture: Texture2D, source_rect: Rect2, radius: float, _config: Dictionary) -> void:
		composite_calls += 1
		last_dest = dest_rect
		last_source = source_rect
		last_radius = radius

	func draw_guard_feedback(_canvas: CanvasItem, _center: Vector2, _config: Dictionary) -> void:
		pass

	func prewarm_assets() -> void:
		pass


# P15 전용: 실 렌더러를 상속해 **레이어 헬퍼 진입만** 가로챈다. 스파이 dict 가
# 아니라 진짜 렌더러이므로 draw_companion / draw_topdown_mount_composite 의 실
# 제어흐름(가시성 게이트·중심 계산)을 그대로 통과한다.
class SpyLayerRenderer:
	extends LingpetCompanionRenderer

	var entries: Array = []
	var body_alphas: Array = []
	var body_dests: Array = []

	func _draw_mount_base_body(_canvas: CanvasItem, dest_rect: Rect2, _texture: Texture2D, _source_rect: Rect2, alpha: float) -> void:
		body_alphas.append(alpha)
		body_dests.append(dest_rect)

	func _draw_soft_aura(_canvas: CanvasItem, center: Vector2, _radius: float, _now_ms: float, _alpha_mult: float = 1.0, _heart_tint: bool = false, _guard_aura_ratio: float = 0.0) -> void:
		entries.append({"layer": "L1_aura", "center": center})

	func _draw_gauge_flash_layer(_canvas: CanvasItem, draw_center: Vector2, _radius: float, _config: Dictionary) -> void:
		entries.append({"layer": "L2_gauge", "center": draw_center})

	func _draw_skill_flash_layer(_canvas: CanvasItem, draw_center: Vector2, _radius: float, _config: Dictionary) -> void:
		entries.append({"layer": "L3_skill", "center": draw_center})

	func _draw_hit_flash_layer(_canvas: CanvasItem, draw_center: Vector2, _radius: float, _config: Dictionary) -> void:
		entries.append({"layer": "L4_hit", "center": draw_center})

	func layer_counts() -> Dictionary:
		var counts: Dictionary = {}
		for entry in entries:
			var key := str((entry as Dictionary).get("layer", ""))
			counts[key] = int(counts.get(key, 0)) + 1
		return counts


class SpyEggRenderer:
	extends RefCounted

	var profile_egg_calls := 0

	func draw_profile_egg(_canvas: CanvasItem, _pos: Vector2, _hits: int, _required: int, _wobble: float, _color_index: int, _roll: float) -> void:
		profile_egg_calls += 1

	func draw_egg(_canvas: CanvasItem, _pos: Vector2, _hits: int, _required: int, _wobble: float, _color_index: int, _roll: float, _flash: float = 0.0) -> void:
		pass

	func draw_hatch_break_egg(_canvas: CanvasItem, _pos: Vector2, _progress: float, _wobble: float, _color_index: int, _roll: float) -> void:
		pass


# 즉시모드 draw 는 _draw 안에서만 합법이다.
class DrawProbe:
	extends Node2D

	var pending: Array = []

	func _draw() -> void:
		for request in pending:
			(request as Callable).call(self)
		pending.clear()


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	_probe = DrawProbe.new()
	get_root().add_child(_probe)

	_test_p16_object_identity_chain()
	_test_p13_gauge_topdown_layout()
	await _test_p9_suppression_and_item_egg_preserved()
	await _test_p12_geometry_and_fail_closed()
	await _test_p15_layer_transfer()
	await _test_alpha_and_visibility()

	LingpetCatalog.clear_mount_presentation_test_overrides()
	_probe.queue_free()
	if _failed:
		printerr("lingpet_topdown_mount_render_smoke: FAILED")
		quit(1)
		return
	print("lingpet_topdown_mount_render_smoke: ok")
	quit(0)


func _make_texture(size: int = 1) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _ensure_mount_fixture_texture() -> void:
	if _mount_fixture_texture == null:
		_mount_fixture_texture = _make_texture(int(MOUNT_CELL_PX))
		ProjectResourceLoader.store_texture(MOUNT_FIXTURE_PATH, _mount_fixture_texture)


func _mount_layout(omit_key: String = "") -> Dictionary:
	var layout := {
		"companion_mount_base_cols": MOUNT_COLS,
		"companion_mount_base_rows": MOUNT_ROWS,
		"companion_mount_base_frame_count": MOUNT_FRAMES,
		"companion_mount_base_draw_size": MOUNT_DRAW_SIZE,
		"companion_mount_base_saddle_x": MOUNT_SADDLE_X,
		"companion_mount_base_saddle_y": MOUNT_SADDLE_Y,
	}
	if omit_key != "":
		layout.erase(omit_key)
	return layout


func _install_topdown_model(omit_layout_key: String = "") -> void:
	LingpetCatalog.set_mount_presentation_override_for_tests(
		"baekrin",
		LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		MOUNT_FIXTURE_PATH,
		_mount_layout(omit_layout_key)
	)


func _make_rider_spec() -> Dictionary:
	return {
		"path": "res://__fixture__/topdown_render_rider.png",
		"cols": 1,
		"rows": 1,
		"frame_count": 1,
		"draw_size": Vector2(160.0, 160.0),
	}


# 준비 완료 탑다운 egg + registry. mounted=true 까지 실 게이트를 관통한다.
func _make_ready_runtime(owner: Object, omit_layout_key: String = "") -> Dictionary:
	_install_topdown_model(omit_layout_key)
	_ensure_mount_fixture_texture()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_saddle")
	runtime._state = "companion"
	runtime._guardian_stowed = false
	var center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	runtime._companion_motion_coordinator.set_position(Vector2(center_x, 655.0))
	runtime._current_profile.get_visual_texture(LingpetCatalog.MOUNT_BASE_VISUAL_KEY, null)
	runtime._guardian_run_state.set_duration_pool_for_tests(30.0, 60.0)
	runtime._mount_topdown_readiness.rider_spec_provider = func(_character_id: String) -> Dictionary:
		return _make_rider_spec()
	var resources := SpyBattleResources.new()
	resources.resource_cache[PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")] = _make_texture()
	var registry := SpyRegistry.new()
	registry.cached["battle_resources"] = resources
	registry.cached["lingpet_egg_runtime"] = runtime
	return {"runtime": runtime, "registry": registry, "resources": resources}


func _mount(runtime: Object, owner: Object, registry: Object) -> bool:
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = false
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = false
	return bool(runtime._mount_state.is_mounted())


func _draw_on_probe(request: Callable) -> void:
	_probe.pending.append(request)
	_probe.queue_redraw()
	await process_frame
	await process_frame


# §B-3 배치식을 씰이 독립적으로 재계산한다(구현 캡처값 재사용 금지).
func _expected_mount_dest(rider_rect: Rect2) -> Rect2:
	var seat_point := Vector2(rider_rect.position.x + rider_rect.size.x * 0.5, rider_rect.end.y)
	var dest_size := Vector2(MOUNT_DRAW_SIZE, MOUNT_DRAW_SIZE)
	var saddle_ratio := Vector2(MOUNT_SADDLE_X / MOUNT_CELL_PX, MOUNT_SADDLE_Y / MOUNT_CELL_PX)
	return Rect2(seat_point - saddle_ratio * dest_size, dest_size)


# ── P16②: 동일 객체 사슬 ────────────────────────────────────────────────────

func _test_p16_object_identity_chain() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	_expect("P16② 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))

	var stored_texture: Variant = runtime.get_topdown_mount_readiness().get("rider_texture", null)
	_expect("P16② 사전: readiness 에 rider_texture 보존", stored_texture is Texture2D)

	var scene_context_builder: Object = BattleDrawPlayfieldSceneContext.new()
	var payload: Dictionary = scene_context_builder._get_mount_rider_seated_payload(registry)
	_expect("P16②: scene payload 의 texture === readiness 의 그 객체", payload.get("texture", null) == stored_texture)
	_expect(
		"P16②: topdown 활성 플래그 생산",
		bool(scene_context_builder._is_mount_topdown_active(registry))
	)
	# 비공허화 레그: 탑승 뒤 발행 캐시를 **다른 객체**로 갈아끼운다. 재조회 구현이면
	# 새 객체가 나와 게이트가 본 객체와 갈라진다 — 보존 구현만 원 객체를 유지한다.
	var resources: Object = fixture["resources"]
	var replaced_texture := _make_texture()
	resources.resource_cache[PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")] = replaced_texture
	var diverged_payload: Dictionary = scene_context_builder._get_mount_rider_seated_payload(registry)
	_expect(
		"P16② 분기: 캐시 교체 후에도 payload == 보존 객체 (재조회였다면 새 객체)",
		diverged_payload.get("texture", null) == stored_texture
			and diverged_payload.get("texture", null) != replaced_texture
	)
	# 비활성이면 fail-closed.
	runtime._mount_state.reset()
	_expect(
		"P16②: 하차 후 페이로드 빈 dict",
		(scene_context_builder._get_mount_rider_seated_payload(registry) as Dictionary).is_empty()
	)


# ── P13: 게이지 탑다운 기하 (14b — 정적 레이아웃) ───────────────────────────

func _test_p13_gauge_topdown_layout() -> void:
	var center := Vector2(380.0, 640.0)
	var base_config := {
		"duration_gauge_enabled": true,
		"duration_pool_current": 30.0,
		"duration_pool_max": 60.0,
		"walk_draw_size": 82.0,
	}
	var walk_layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(center, base_config)
	# walk 키(82)와 topdown 키(112)를 다르게 둬야 X 레그가 "topdown 키가 body_px
	# 정본" 자체를 검증한다 — 같으면 walk 폴백 구현도 통과한다(공허).
	var topdown_config: Dictionary = base_config.duplicate()
	topdown_config["topdown_mount_draw_size"] = MOUNT_DRAW_SIZE
	var topdown_layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(center, topdown_config)
	_expect("P13 사전: 두 레이아웃 모두 visible", bool(walk_layout.get("visible", false)) and bool(topdown_layout.get("visible", false)))
	var walk_track: Rect2 = walk_layout.get("track_rect", Rect2())
	var topdown_track: Rect2 = topdown_layout.get("track_rect", Rect2())
	_expect(
		"P13: walk 경로는 종전 −6 오프셋 유지 (회귀 대조군)",
		absf((walk_track.position.y + walk_track.size.y * 0.5) - (center.y - 6.0)) <= 0.01
	)
	_expect(
		"P13: 탑다운 경로는 Y 오프셋 0 — 세로 중심 == M 중심",
		absf((topdown_track.position.y + topdown_track.size.y * 0.5) - center.y) <= 0.01
	)
	_expect(
		"P13: 게이지 X 가 M draw_size(112) 기준 (walk 82 기준이면 어긋남)",
		topdown_track.position.x < walk_track.position.x - 0.01
	)


# ── P9 / P1: 자기억제 + 아이템 알 보존 + 비탑승 대조군 ─────────────────────

func _test_p9_suppression_and_item_egg_preserved() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	var companion_spy := SpyCompanionRenderer.new()
	var egg_spy := SpyEggRenderer.new()
	runtime._companion_renderer = companion_spy
	runtime._egg_renderer = egg_spy
	runtime._item_egg_lifecycle_state.active = true
	runtime._item_egg_lifecycle_state.pet_id = "maribo"

	# 대조군(P1): 비탑승 — 본체가 종전대로 그려진다.
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_lingpet_body_behind_actors(canvas, Vector2.ZERO))
	_expect("P1 대조군: 비탑승 시 본체 draw 1회", companion_spy.body_draw_calls == 1)
	_expect("P1 대조군: 아이템 알 draw 1회", egg_spy.profile_egg_calls == 1)

	# 탑승: 메인 본체 억제 + 아이템 알 보존.
	_expect("P9 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_lingpet_body_behind_actors(canvas, Vector2.ZERO))
	_expect("P9: 탑승 중 메인 본체 draw 0회 (lane 이중 드로우 차단)", companion_spy.body_draw_calls == 1)
	_expect("P9: 공존 아이템 알은 보존 (메서드 전체 return 금지)", egg_spy.profile_egg_calls == 2)


# ── P12: M exact-dest 기하 + 레이아웃 결손 fail-closed ──────────────────────

func _test_p12_geometry_and_fail_closed() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	var companion_spy := SpyCompanionRenderer.new()
	runtime._companion_renderer = companion_spy
	_expect("P12 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))

	var rider_rect := Rect2(Vector2(310.0, 560.0), Vector2(160.0, 160.0))
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_topdown_mount_base(canvas, rider_rect))

	_expect("P12: 합성 draw 1회", companion_spy.composite_calls == 1)
	var dest: Rect2 = companion_spy.last_dest
	var source: Rect2 = companion_spy.last_source
	var expected: Rect2 = _expected_mount_dest(rider_rect)
	_expect(
		"P12: dest 크기 == 선언된 draw_size %d (1px 폴백이면 즉시 어긋남)" % int(MOUNT_DRAW_SIZE),
		dest.size.is_equal_approx(Vector2(MOUNT_DRAW_SIZE, MOUNT_DRAW_SIZE))
	)
	_expect(
		"P12: source == 선언 그리드의 frame 0 셀 (%dpx)" % int(MOUNT_CELL_PX),
		source.is_equal_approx(Rect2(Vector2.ZERO, Vector2(MOUNT_CELL_PX, MOUNT_CELL_PX)))
	)
	_expect(
		"P12: dest 위치 == 독립 재계산한 안장 역산 좌표 (−6 오프셋·bob 이 끼면 어긋남)",
		dest.position.distance_to(expected.position) <= 0.01
	)
	var seat_point := Vector2(rider_rect.position.x + rider_rect.size.x * 0.5, rider_rect.end.y)
	var saddle_screen := dest.position + Vector2(MOUNT_SADDLE_X / MOUNT_CELL_PX, MOUNT_SADDLE_Y / MOUNT_CELL_PX) * dest.size
	_expect(
		"P12: 안장 소켓 == seat point",
		saddle_screen.distance_to(seat_point) <= 0.01
	)
	_expect(
		"P12: 반경 = 16 × draw/82 (베이스 비례)",
		absf(companion_spy.last_radius - 16.0 * (MOUNT_DRAW_SIZE / 82.0)) <= 0.001
	)
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_topdown_mount_base(canvas, rider_rect))
	_expect("P12: 시간 경과 후 dest 불변 (bob 무가산)", companion_spy.last_dest == dest)

	# P13 통합: 실 draw 가 게이지를 M 중심·visible 로 남긴다(숨김은 이관 실패 신호).
	var gauge_layout: Dictionary = runtime.get_last_duration_gauge_layout_for_tests()
	_expect("P13 통합: 실 draw 후 게이지 visible", bool(gauge_layout.get("visible", false)))
	var track: Rect2 = gauge_layout.get("track_rect", Rect2())
	_expect(
		"P13 통합: 게이지 세로 중심 == M 중심 y (walk −6 미사용)",
		absf((track.position.y + track.size.y * 0.5) - dest.get_center().y) <= 0.01
	)
	_expect(
		"P13 통합: 게이지가 M 좌측 (M draw_size 기준 배치)",
		track.end.x < dest.get_center().x and track.position.x > 0.0
	)

	# fail-closed: 6키 중 하나만 빠져도 그리지 않는다.
	for omitted in LingpetCatalog.MOUNT_TOPDOWN_REQUIRED_LAYOUT_KEYS:
		var fc_owner := OperationalOwner.new()
		var fc_fixture := _make_ready_runtime(fc_owner, str(omitted))
		var fc_runtime: Object = fc_fixture["runtime"]
		var fc_spy := SpyCompanionRenderer.new()
		fc_runtime._companion_renderer = fc_spy
		var mounted: bool = _mount(fc_runtime, fc_owner, fc_fixture["registry"])
		await _draw_on_probe(func(canvas: CanvasItem) -> void:
			fc_runtime.draw_topdown_mount_base(canvas, rider_rect))
		_expect(
			"P12 fail-closed: %s 결손 시 합성 draw 0회 (기본값 보정 금지)" % str(omitted),
			mounted and fc_spy.composite_calls == 0
		)
	_install_topdown_model()


# ── P15: 오라·플래시 4레이어가 공용 헬퍼로 M 중심에 1회씩 ────────────────────

func _test_p15_layer_transfer() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	var layer_spy := SpyLayerRenderer.new()
	runtime._companion_renderer = layer_spy

	# 대조군: 비탑승 lane 패스가 실제로 4레이어를 lane 중심에 그린다 —
	# 이게 없으면 "lane 진입 0회"가 공허하다(스파이가 애초에 안 잡는 경우).
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_lingpet_body_behind_actors(canvas, Vector2.ZERO))
	var lane_counts: Dictionary = layer_spy.layer_counts()
	var lane_center: Vector2 = runtime._companion_pos
	var lane_hits := 0
	for entry in layer_spy.entries:
		if (entry as Dictionary).get("center", Vector2.ZERO).distance_to(lane_center) <= 4.0:
			lane_hits += 1
	_expect(
		"P15 대조군: 비탑승 lane 패스가 L1~L4 를 lane 중심에 그린다",
		int(lane_counts.get("L1_aura", 0)) == 1
			and int(lane_counts.get("L2_gauge", 0)) == 1
			and int(lane_counts.get("L3_skill", 0)) == 1
			and int(lane_counts.get("L4_hit", 0)) == 1
			and lane_hits == 4
	)

	# 탑다운 프레임: 본체 패스(억제) + M 콜백 한 벌.
	_expect("P15 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))
	layer_spy.entries.clear()
	var rider_rect := Rect2(Vector2(310.0, 560.0), Vector2(160.0, 160.0))
	var expected_center: Vector2 = _expected_mount_dest(rider_rect).get_center()
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_lingpet_body_behind_actors(canvas, Vector2.ZERO)
		runtime.draw_topdown_mount_base(canvas, rider_rect))
	var counts: Dictionary = layer_spy.layer_counts()
	_expect(
		"P15: L1~L4 각각 헬퍼 진입 정확히 1회 (총 4회 — 이중 드로우면 8회)",
		layer_spy.entries.size() == 4
			and int(counts.get("L1_aura", 0)) == 1
			and int(counts.get("L2_gauge", 0)) == 1
			and int(counts.get("L3_skill", 0)) == 1
			and int(counts.get("L4_hit", 0)) == 1
	)
	var off_center := 0
	var lane_residue := 0
	for entry in layer_spy.entries:
		var center: Vector2 = (entry as Dictionary).get("center", Vector2.ZERO)
		if center.distance_to(expected_center) > 0.01:
			off_center += 1
		if center.distance_to(runtime._companion_pos) <= 4.0:
			lane_residue += 1
	_expect("P15: 4레이어 전부 M exact center (bob 가산 0)", off_center == 0)
	_expect("P15: lane 중심 진입 0회", lane_residue == 0)



# ── 알파/가시성: 합성이 lane 패스와 같은 의미론을 쓴다 ──────────────────────

func _test_alpha_and_visibility() -> void:
	# 교체 전환 구간: ghost_alpha 는 1.0 인데 본체 정본 알파는 0.42 바닥으로 내려간다.
	# 두 값이 갈라지는 이 구간이 "M 이 무엇을 먹었는가"의 유일한 판별점이다.
	var transition_config := {"companion_visible": true, "companion_alpha": 1.0, "switch_transition": 0.6}
	var canonical_alpha: float = LingpetCompanionRenderer.resolve_body_draw_alpha(transition_config)
	_expect(
		"알파 사전: 교체 전환 중 정본 알파 < ghost_alpha (판별 가능 구간)",
		canonical_alpha < 0.999 and canonical_alpha > 0.0
	)
	var alpha_spy := SpyLayerRenderer.new()
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		alpha_spy.draw_topdown_mount_composite(
			canvas,
			Rect2(Vector2(100.0, 100.0), Vector2(MOUNT_DRAW_SIZE, MOUNT_DRAW_SIZE)),
			_mount_fixture_texture,
			Rect2(Vector2.ZERO, Vector2(MOUNT_CELL_PX, MOUNT_CELL_PX)),
			16.0,
			transition_config
		))
	_expect(
		"알파: M 본체가 먹은 알파 == resolve_body_draw_alpha (ghost_alpha 직접 사용이면 1.0 로 뜬다)",
		alpha_spy.body_alphas.size() == 1
			and absf(float(alpha_spy.body_alphas[0]) - canonical_alpha) <= 0.0001
	)
	var hidden_spy := SpyLayerRenderer.new()
	var hidden_config := {"companion_visible": false, "companion_alpha": 1.0}
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		hidden_spy.draw_topdown_mount_composite(
			canvas,
			Rect2(Vector2(100.0, 100.0), Vector2(MOUNT_DRAW_SIZE, MOUNT_DRAW_SIZE)),
			_mount_fixture_texture,
			Rect2(Vector2.ZERO, Vector2(MOUNT_CELL_PX, MOUNT_CELL_PX)),
			16.0,
			hidden_config
		))
	_expect(
		"가시성: companion_visible=false 면 합성이 어떤 레이어도 그리지 않는다",
		hidden_spy.entries.is_empty()
	)
