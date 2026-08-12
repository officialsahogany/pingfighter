extends SceneTree

# S3-b 슬라이스 B 씰 — 탑다운 합성 렌더 배선.
#
# 봉인 범위(§9-b B):
#  - P16② 완결: A 가 보존한 readiness 의 rider_texture **객체**가 scene context →
#    actor context 까지 재조회 없이 그대로 전달된다(동일 객체 ===).
#  - defer 의미론(§C-1): 탑다운 플래그만 false 를 만들고, 비탑다운(목말)은 종전
#    lift > 0 그대로 — 홉 시작 lift=0 프레임·하차 잔여 lift 프레임 픽셀 보존.
#  - P9: 탑다운 탑승 중 early hook 은 메인 본체를 그리지 않고(억제), 공존 아이템
#    알은 보존된다. P1: 비탑승이면 본체가 종전대로 그려진다(대조군).
#  - P12: M exact-dest — dest 가 §B-3 배치식과 정확히 일치(−6 오프셋·bob 무가산).
#  - P13: 게이지가 M 중심 기하(Y 오프셋 0)로 그려진다.
#  - defer/P11 레그는 플레이어 렌더러 재구성(미커밋 WIP) 랜딩과 함께 B-1b 에서
#    합류한다 — 이 파일 기준 HEAD 에는 그 심볼이 아직 없다.
#
# P3/P8(z 순서·숨김 3경로 픽셀)과 P15(오라·플래시 중심/반경 실측)는 프로토타입
# 픽셀 QA 하네스(§7) 소관 — 여기는 에셋 0장 인메모리 골격 씰이다.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const LingpetDurationFieldGaugeRenderer := preload("res://scripts/lingpet/lingpet_duration_field_gauge_renderer.gd")

const MOUNT_FIXTURE_PATH := "res://__fixture__/topdown_render_mount_base.png"

var _failed := false
var _mount_fixture_texture: Texture2D = null
var _probe: Node2D = null
var _draw_requests: Array = []


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


# 컴패니언 렌더러 스파이: 본체/합성 draw 호출을 세고 합성 인자를 캡처한다.
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


class SpyEggRenderer:
	extends RefCounted

	var profile_egg_calls := 0

	func draw_profile_egg(_canvas: CanvasItem, _pos: Vector2, _hits: int, _required: int, _wobble: float, _color_index: int, _roll: float) -> void:
		profile_egg_calls += 1

	func draw_egg(_canvas: CanvasItem, _pos: Vector2, _hits: int, _required: int, _wobble: float, _color_index: int, _roll: float, _flash: float = 0.0) -> void:
		pass

	func draw_hatch_break_egg(_canvas: CanvasItem, _pos: Vector2, _progress: float, _wobble: float, _color_index: int, _roll: float) -> void:
		pass


# _draw 컨텍스트 프로브: 즉시모드 draw(게이지 실그리기)는 _draw 안에서만 합법이다.
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
	await _test_p12_geometry()

	LingpetCatalog.clear_mount_presentation_test_overrides()
	_probe.queue_free()
	if _failed:
		printerr("lingpet_topdown_mount_render_smoke: FAILED")
		quit(1)
		return
	print("lingpet_topdown_mount_render_smoke: ok")
	quit(0)


func _make_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _ensure_mount_fixture_texture() -> void:
	if _mount_fixture_texture == null:
		_mount_fixture_texture = _make_texture()
		ProjectResourceLoader.store_texture(MOUNT_FIXTURE_PATH, _mount_fixture_texture)


func _install_topdown_model() -> void:
	LingpetCatalog.set_mount_presentation_override_for_tests(
		"baekrin",
		LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		MOUNT_FIXTURE_PATH
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
func _make_ready_runtime(owner: Object) -> Dictionary:
	_install_topdown_model()
	_ensure_mount_fixture_texture()
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_saddle")
	runtime._state = "companion"
	runtime._guardian_stowed = false
	var center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	runtime._companion_motion_coordinator.set_position(Vector2(center_x, 655.0))
	runtime._current_profile.get_visual_texture(LingpetCatalog.MOUNT_BASE_VISUAL_KEY, null)
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


# ── P16②: 동일 객체 사슬 ────────────────────────────────────────────────────

func _test_p16_object_identity_chain() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	_expect("P16② 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))

	var stored_texture: Variant = runtime.get_topdown_mount_readiness().get("rider_texture", null)
	_expect("P16② 사전: readiness 에 rider_texture 보존", stored_texture is Texture2D)

	# scene context 생산 경로(실 빌더 메서드) — battle_resources 재조회가 아니라
	# 보존된 readiness 객체를 그대로 실어야 한다.
	var scene_context_builder: Object = BattleDrawPlayfieldSceneContext.new()
	var payload: Dictionary = scene_context_builder._get_mount_rider_seated_payload(registry)
	_expect("P16②: scene payload 의 texture === readiness 의 그 객체", payload.get("texture", null) == stored_texture)
	_expect(
		"P16②: 발행 캐시의 사본이 아니라 보존 객체 (재조회였다면 다른 인스턴스)",
		payload.get("texture", null) is Texture2D and (payload.get("texture") as Object) == (stored_texture as Object)
	)
	_expect(
		"P16②: topdown 활성 플래그 생산",
		bool(scene_context_builder._is_mount_topdown_active(registry))
	)
	# 비공허화 레그: 탑승 뒤 발행 캐시를 **다른 객체**로 갈아끼운다. 재조회
	# 구현이면 새 객체가 나와 게이트가 본 객체와 갈라진다(리뷰 지적의 실체) —
	# 보존 구현만 원 객체를 유지한다.
	var resources: Object = fixture["resources"]
	var replaced_texture := _make_texture()
	resources.resource_cache[PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")] = replaced_texture
	var diverged_payload: Dictionary = scene_context_builder._get_mount_rider_seated_payload(registry)
	_expect(
		"P16② 분기: 캐시 교체 후에도 payload == 보존 객체 (재조회였다면 새 객체)",
		diverged_payload.get("texture", null) == stored_texture
			and diverged_payload.get("texture", null) != replaced_texture
	)
	# 비탑승이면 페이로드 빈 dict (fail-closed).
	runtime._mount_state.reset()
	_expect(
		"P16②: 하차 후 페이로드 빈 dict",
		(scene_context_builder._get_mount_rider_seated_payload(registry) as Dictionary).is_empty()
	)


# ── P9 / P1: 자기억제 + 아이템 알 보존 + 비탑승 대조군 ─────────────────────

func _draw_on_probe(request: Callable) -> void:
	# 게이지 등 실 정적 draw 는 _draw 컨텍스트에서만 합법 — 프로브에 예약한다.
	_probe.pending.append(request)
	_probe.queue_redraw()
	await process_frame
	await process_frame


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


# ── P13: 게이지 탑다운 기하 (14b — 캔버스 불필요 정적 레이아웃) ─────────────

func _test_p13_gauge_topdown_layout() -> void:
	var center := Vector2(380.0, 640.0)
	var base_config := {
		"duration_gauge_enabled": true,
		"duration_pool_current": 30.0,
		"duration_pool_max": 60.0,
		"walk_draw_size": 82.0,
	}
	var walk_layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(center, base_config)
	# walk 키(82)와 topdown 키(128)를 다르게 둬야 X 레그가 "topdown 키가 body_px
	# 정본" 자체를 검증한다 — 같으면 walk 폴백 구현도 통과한다(공허).
	var topdown_config: Dictionary = base_config.duplicate()
	topdown_config["topdown_mount_draw_size"] = 128.0
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
	# 크기 축: topdown_mount_draw_size 가 body_px 정본 — walk 82 대비 128 몸통은
	# 게이지가 몸 좌단에서 더 왼쪽에 선다.
	_expect(
		"P13: 게이지 X 가 M draw_size(128) 기준 (walk 82 기준이면 어긋남)",
		topdown_track.position.x < walk_track.position.x - 0.01
	)


# ── P12: M exact-dest 기하 (실 draw 관통) ───────────────────────────────────

func _test_p12_geometry() -> void:
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
	# §B-3 배치식 재계산 — 기본 saddle(셀 중앙=0.5,0.5) × draw_size 1(레이아웃 미선언
	# fallback maxf(1.0, 0)) 은 자명하므로, 검증력을 위해 실제 캡처 dest 에서 seat
	# point 방정식을 역검산한다: saddle_screen == seat_point.
	var dest: Rect2 = companion_spy.last_dest
	var source: Rect2 = companion_spy.last_source
	var seat_point := Vector2(rider_rect.position.x + rider_rect.size.x * 0.5, rider_rect.end.y)
	var cell_size := Vector2(maxf(1.0, source.size.x), maxf(1.0, source.size.y))
	var saddle_local := Vector2(
		float(runtime._current_profile.get_visual_layout_value("companion_mount_base_saddle_x", cell_size.x * 0.5)),
		float(runtime._current_profile.get_visual_layout_value("companion_mount_base_saddle_y", cell_size.y * 0.5))
	)
	var saddle_screen := dest.position + (saddle_local / cell_size) * dest.size
	_expect(
		"P12: 안장 소켓 == seat point (오차 ≤0.01 — −6 오프셋·bob 이 끼면 즉시 어긋남)",
		saddle_screen.distance_to(seat_point) <= 0.01
	)
	# bob 무가산 확증: 두 번째 draw(시간 경과 후)의 dest 가 완전 동일해야 한다.
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		runtime.draw_topdown_mount_base(canvas, rider_rect))
	_expect("P12: 시간 경과 후 dest 불변 (bob 무가산)", companion_spy.last_dest == dest)

	# 게이지 이관 통합 확인: 실 draw 가 레이아웃 정본을 갱신했고, 보이면 M 중심.
	var gauge_layout: Dictionary = runtime.get_last_duration_gauge_layout_for_tests()
	if bool(gauge_layout.get("visible", false)):
		var track: Rect2 = gauge_layout.get("track_rect", Rect2())
		_expect(
			"P13 통합: 게이지 세로 중심 == M 중심 y (walk −6 미사용)",
			absf((track.position.y + track.size.y * 0.5) - dest.get_center().y) <= 0.01
		)
	else:
		# M draw_size fallback(1px)에서는 몸 침범/풀 미형성 판정으로 숨을 수 있다 —
		# hidden 레이아웃 정본이 기록됐는지만 확인(이관 누락과 구분).
		_expect("P13 통합: 비표시면 hidden 레이아웃 기록 (walk 기하 잔재 없음)", gauge_layout.get("color_key", "") == "hidden")
