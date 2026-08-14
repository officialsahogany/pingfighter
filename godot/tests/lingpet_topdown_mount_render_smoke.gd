extends SceneTree

# S3-b 슬라이스 B 씰 — 탑다운 합성 렌더 배선.
#
# 봉인 범위(§9-b B):
#  - P16② 완결: A 가 보존한 readiness 의 rider_texture **객체**가 scene context 까지
#    재조회 없이 그대로 전달된다(동일 객체 ===, 캐시 교체 분기 포함).
#  - P15: L1~L4 가 **공용 레이어 헬퍼** 진입 정확히 1회씩이고 중심이 전부 M exact
#    center 다(lane 중심 진입 0회). 비탑승 대조군이 lane 중심 진입을 실제로 잡는다.
#  - P12: M exact-dest — 선언된 draw_size 그대로, 안장 소켓이 seat point 와 일치,
#    시간 경과 dest 불변(bob·−6 무가산). 레이아웃 결손·소수 그리드·비유한·용량
#    초과는 fail-closed(그리기 0회), 근사 정수는 roundi 정규화.
#  - P13: 게이지가 **visible=true** 로 M 중심·M draw_size 기하(Y 오프셋 0)를 쓴다.
#  - P9/P1: 탑승 중 메인 본체 억제 + 공존 아이템 알 보존, 비탑승 대조군은 종전대로.
#  - P11: 착석 셀 rect 가 **N spec 그리드**에서 나오고(이미지 추론 금지), 라이더
#    draw size 가 착석 시트 규격으로 교체된다.
#  - §C-1 defer: 탑다운은 지연 안 함 / 목말은 종전 lift > 0 (홉 시작·하차 잔여
#    프레임 픽셀 보존).
#  - §B-3 배선: 실 훅 주입 헬퍼가 본체·M 두 훅을 심고, actor context 가 탑다운
#    2키를 **객체 그대로** 통과시킨다.
#  - §B-5 리프트 0: 탑다운은 진입·정착·하차 잔여 전 구간 rider lift 가 0 이다
#    (판정 기준 = 표현 모델). 온이마루는 종전 양수 리프트 대조군.
#  - 사슬: 실 scene context → actor context build → 실 actor draw() → sprite
#    수신까지 한 줄로 이어 N 페이로드 동일 객체와 무-리프트 배치를 함께 잰다.
#
# P3/P8(z 순서·숨김 3경로 픽셀)은 프로토타입 픽셀 QA 하네스(§7) 소관 — 이 파일은
# 에셋 0장 인메모리 골격 씰이다.

const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetDurationFieldGaugeRenderer := preload("res://scripts/lingpet/lingpet_duration_field_gauge_renderer.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")
const BattleDrawPlayfieldSceneContext := preload("res://scripts/core/battle_draw_playfield_scene_context.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const BattlePlayfieldSceneDrawer := preload("res://scripts/core/battle_playfield_scene_drawer.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")

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


# 실 플레이어 액터 렌더러 관통용 스파이. sprite_renderer / dash 게이지는 인스턴스
# 필드라 교체 가능하다 — 실 draw() 를 그대로 돌리고 최종 rect 만 관측한다.
class SpySpriteRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_rect := Rect2()
	var last_context: Dictionary = {}

	func draw(_canvas: CanvasItem, context: Dictionary, player_visual_rect: Rect2, _move_active: bool, _player_pos: Vector2, _paddle_size: Vector2, _shake_offset: Vector2) -> void:
		draw_calls += 1
		last_rect = player_visual_rect
		last_context = context

	func clear_transient_canvas_items() -> void:
		pass

	func prewarm_wheel_spin_sheet() -> void:
		pass


class SpyDashSideGaugeRenderer:
	extends RefCounted

	func draw(_canvas: CanvasItem, _context: Dictionary, _player_pos: Vector2, _paddle_size: Vector2, _shake_offset: Vector2) -> void:
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
	_test_p11_seated_region()
	_test_defer_semantics()
	_test_seated_draw_size_adoption()
	await _test_hook_wiring_and_context_forward()
	_test_topdown_lift_zero()
	_test_shipped_mount_base_asset()
	await _test_end_to_end_chain()
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


func _mount_layout(omit_key: String = "", overrides: Dictionary = {}) -> Dictionary:
	var layout := {
		"companion_mount_base_cols": MOUNT_COLS,
		"companion_mount_base_rows": MOUNT_ROWS,
		"companion_mount_base_frame_count": MOUNT_FRAMES,
		"companion_mount_base_draw_size": MOUNT_DRAW_SIZE,
		"companion_mount_base_saddle_x": MOUNT_SADDLE_X,
		"companion_mount_base_saddle_y": MOUNT_SADDLE_Y,
	}
	for key in overrides:
		layout[str(key)] = overrides[key]
	if omit_key != "":
		layout.erase(omit_key)
	return layout


func _install_topdown_model(omit_layout_key: String = "", overrides: Dictionary = {}) -> void:
	LingpetCatalog.set_mount_presentation_override_for_tests(
		"baekrin",
		LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		MOUNT_FIXTURE_PATH,
		_mount_layout(omit_layout_key, overrides)
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
func _make_ready_runtime(owner: Object, omit_layout_key: String = "", layout_overrides: Dictionary = {}) -> Dictionary:
	_install_topdown_model(omit_layout_key, layout_overrides)
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


# ── P11(부분): 착석 셀 rect ─────────────────────────────────────────────────

func _test_p11_seated_region() -> void:
	var seated_texture := _make_texture()
	var spec := {"cols": 4, "rows": 2, "frame_count": 8, "draw_size": Vector2(128.0, 128.0)}
	var region: Rect2 = Stage1PlayerSpriteRenderer._get_mount_rider_seated_region(seated_texture, spec)
	_expect(
		"P11: 착석 셀 rect = spec 그리드에서 파생 (frame 0)",
		region.position == Vector2.ZERO and is_equal_approx(region.size.x, 0.25) and is_equal_approx(region.size.y, 0.5)
	)
	var fallback: Rect2 = Stage1PlayerSpriteRenderer._get_mount_rider_seated_region(seated_texture, {})
	_expect(
		"P11: spec 없으면 1×1 전체 셀 (fail-safe)",
		is_equal_approx(fallback.size.x, 1.0) and is_equal_approx(fallback.size.y, 1.0)
	)
	# 그리드 정본은 spec 이다 — 이미지 크기에서 추론하면 64px 시트가 통짜 1셀이 된다.
	var sheet_texture := _make_texture(int(MOUNT_CELL_PX))
	var sheet_region: Rect2 = Stage1PlayerSpriteRenderer._get_mount_rider_seated_region(
		sheet_texture, {"cols": 4, "rows": 2, "frame_count": 8}
	)
	_expect(
		"P11: 64px 시트 × spec 4×2 → 셀 16×32 (이미지 추론이면 64×64)",
		is_equal_approx(sheet_region.size.x, MOUNT_CELL_PX / 4.0)
			and is_equal_approx(sheet_region.size.y, MOUNT_CELL_PX / 2.0)
	)


# ── §C-1 defer 의미론 ───────────────────────────────────────────────────────

func _test_defer_semantics() -> void:
	_expect(
		"defer: 탑다운 활성 + lift>0 이어도 false (M 은 별도 콜백)",
		not Stage1PlayerActorRenderer._is_lingpet_body_deferred({
			"player_mount_topdown_active": true,
			"player_mount_rider_lift_px": 14.0,
		})
	)
	_expect(
		"defer: 목말 lift>0 = true (종전 유지)",
		Stage1PlayerActorRenderer._is_lingpet_body_deferred({
			"player_mount_rider_lift_px": 14.0,
		})
	)
	_expect(
		"defer: 목말 홉 시작 lift=0 = false (mounted 기준 금지 — 전환 픽셀 보존)",
		not Stage1PlayerActorRenderer._is_lingpet_body_deferred({
			"player_mount_rider_lift_px": 0.0,
		})
	)


# ── §B-4 착석 draw size 채택 ────────────────────────────────────────────────

func _test_seated_draw_size_adoption() -> void:
	var walk_size := Vector2(82.0, 82.0)
	var seated_size := Vector2(160.0, 160.0)
	var seated_context := {
		"player_mount_topdown_active": true,
		"player_mount_rider_seated": {"spec": {"draw_size": seated_size}},
	}
	_expect(
		"draw size: 탑다운 착석은 시트 규격 채택",
		Stage1PlayerActorRenderer._resolve_mount_seated_draw_size(seated_context, walk_size).is_equal_approx(seated_size)
	)
	_expect(
		"draw size: 비탑다운은 종전 걷기 규격 유지",
		Stage1PlayerActorRenderer._resolve_mount_seated_draw_size(
			{"player_mount_rider_seated": {"spec": {"draw_size": seated_size}}}, walk_size
		).is_equal_approx(walk_size)
	)
	_expect(
		"draw size: 페이로드/스펙 결손이면 폴백 (0 크기 승격 금지)",
		Stage1PlayerActorRenderer._resolve_mount_seated_draw_size(
			{"player_mount_topdown_active": true}, walk_size
		).is_equal_approx(walk_size)
			and Stage1PlayerActorRenderer._resolve_mount_seated_draw_size(
				{
					"player_mount_topdown_active": true,
					"player_mount_rider_seated": {"spec": {"draw_size": Vector2.ZERO}},
				}, walk_size
			).is_equal_approx(walk_size)
	)


# ── §B-3 배선: 훅 주입 + actor context 통과 ────────────────────────────────

func _test_hook_wiring_and_context_forward() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	var companion_spy := SpyCompanionRenderer.new()
	runtime._companion_renderer = companion_spy
	_expect("배선 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))

	# 실 주입 헬퍼(생산 경로)로 두 훅을 심는다.
	var actor_context: Dictionary = {"existing": true}
	BattlePlayfieldSceneDrawer.install_lingpet_draw_hooks(actor_context, runtime, Vector2.ZERO)
	_expect(
		"배선: 본체 훅 + M 훅이 함께 주입된다 (형제 훅 누락 금지)",
		actor_context.get("lingpet_body_draw", null) is Callable
			and actor_context.get("lingpet_mount_base_draw", null) is Callable
	)
	# 주입된 M 훅이 실제로 egg 의 합성 draw 로 관통하는지 — 렌더러가 부르는 방식
	# (canvas, final_rider_rect) 그대로 호출한다.
	var rider_rect := Rect2(Vector2(310.0, 560.0), Vector2(160.0, 160.0))
	var mount_hook: Callable = actor_context["lingpet_mount_base_draw"]
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		mount_hook.call(canvas, rider_rect))
	_expect(
		"배선: M 훅 호출이 합성 draw 로 관통 + dest 는 전달받은 rect 기준",
		companion_spy.composite_calls == 1
			and companion_spy.last_dest.position.distance_to(_expected_mount_dest(rider_rect).position) <= 0.01
	)
	# 렌더러 호출 정본: 유효 Callable 일 때만 발화하고 rect 를 그대로 넘긴다.
	var received: Array = []
	var probe_context := {
		"lingpet_mount_base_draw": func(_canvas: CanvasItem, rect: Rect2) -> void:
			received.append(rect),
	}
	var fired: bool = Stage1PlayerActorRenderer._call_lingpet_mount_base_hook(_probe, probe_context, rider_rect)
	_expect(
		"배선: 렌더러 호출 헬퍼가 최종 rect 를 그대로 전달 (재계산 금지)",
		fired and received.size() == 1 and (received[0] as Rect2) == rider_rect
	)
	_expect(
		"배선: 훅 없음/무효면 비발화 (본체 훅만 있는 프레임 안전)",
		not Stage1PlayerActorRenderer._call_lingpet_mount_base_hook(_probe, {}, rider_rect)
			and not Stage1PlayerActorRenderer._call_lingpet_mount_base_hook(
				_probe, {"lingpet_mount_base_draw": "not-a-callable"}, rider_rect
			)
	)
	# ── 실 액터 렌더러 관통: 착석 draw size 채택 + M 훅 호출이 **같은 프레임의
	# 같은 rect** 로 이어지는지. 정적 헬퍼만 재면 호출부 배선이 빠져도 GREEN 이다.
	var seated_sheet := _make_texture(int(MOUNT_CELL_PX))
	var mount_rects: Array = []
	var actor_renderer: Object = Stage1PlayerActorRenderer.new()
	var sprite_spy := SpySpriteRenderer.new()
	actor_renderer.sprite_renderer = sprite_spy
	actor_renderer.dash_side_gauge_renderer = SpyDashSideGaugeRenderer.new()
	var live_context := {
		"player_pos": Vector2(300.0, 675.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_paddle_scale": 1.0,
		"paddle_hologram_should_draw": true,
		"player_mount_topdown_active": true,
		"player_mount_rider_seated": {
			"texture": seated_sheet,
			"spec": {"cols": 1, "rows": 1, "frame_count": 1, "draw_size": Vector2(160.0, 160.0)},
		},
		"lingpet_mount_base_draw": func(_canvas: CanvasItem, rect: Rect2) -> void:
			mount_rects.append(rect),
	}
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		actor_renderer.draw(canvas, live_context, Vector2.ZERO))
	_expect(
		"관통: 실 렌더러 draw 가 M 훅을 1회 호출한다 (호출부 배선)",
		mount_rects.size() == 1
	)
	if mount_rects.size() == 1:
		var live_rect: Rect2 = mount_rects[0]
		_expect(
			"관통: 라이더 rect 크기 == 착석 시트 규격 160 (채택 누락이면 걷기 규격)",
			live_rect.size.is_equal_approx(Vector2(160.0, 160.0))
		)
		_expect(
			"관통: 스프라이트가 받은 rect 와 M 훅이 받은 rect 가 동일 (같은 프레임 좌표)",
			sprite_spy.draw_calls >= 1 and sprite_spy.last_rect == live_rect
		)

	# 링펫 런타임이 없으면 두 훅 모두 심지 않는다(fail-closed).
	var empty_context: Dictionary = {}
	BattlePlayfieldSceneDrawer.install_lingpet_draw_hooks(empty_context, null, Vector2.ZERO)
	_expect("배선: 런타임 없으면 훅 0개", empty_context.is_empty())

	# actor context 통과 — scene context 가 실어온 **그 객체**가 그대로 간다.
	var seated_texture := _make_texture()
	var seated_payload := {"texture": seated_texture, "spec": {"cols": 4, "rows": 2, "draw_size": Vector2(160.0, 160.0)}}
	var built: Dictionary = BattleDrawActorContext.new().build({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"player_pos": Vector2(40.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"textures": {},
		"player_mount_topdown_active": true,
		"player_mount_rider_seated": seated_payload,
	}, {})
	_expect(
		"통과: actor context 가 탑다운 플래그를 싣는다",
		bool(built.get("player_mount_topdown_active", false))
	)
	var forwarded: Dictionary = built.get("player_mount_rider_seated", {}) as Dictionary
	_expect(
		"통과: 착석 페이로드의 texture 가 **동일 객체** (재조회·복사 금지)",
		forwarded.get("texture", null) == seated_texture
	)
	_expect(
		"통과: 페이로드 dict 자체도 무복사 통과 (draw 경로 프레임당 딥카피 금지)",
		is_same(forwarded, seated_payload)
	)
	var plain: Dictionary = BattleDrawActorContext.new().build({
		"selected_character_type": "smasher",
		"current_stage": 1,
		"player_pos": Vector2(40.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"textures": {},
	}, {})
	_expect(
		"통과: 비탑승 기본값은 false + 빈 dict (fail-closed)",
		not bool(plain.get("player_mount_topdown_active", true))
			and (plain.get("player_mount_rider_seated", {}) as Dictionary).is_empty()
	)


# ── 출하 M 자산 등재 상태 (계약 8-10 가드) ─────────────────────────────────

func _test_shipped_mount_base_asset() -> void:
	# 이 레그는 **테스트 오버라이드를 쓰지 않는다** — shipped 카탈로그 자체를 본다.
	LingpetCatalog.clear_mount_presentation_test_overrides()
	var base_path: String = LingpetCatalog.get_visual_path("baekrin", LingpetCatalog.MOUNT_BASE_VISUAL_KEY)
	_expect(
		"출하 M: 백린 companion_mount_base 경로 등재 + 파일 존재",
		base_path.begins_with("res://assets/sprites/lingpet/baekrin_companion_mount_base_topdown_v1")
			and ResourceLoader.exists(base_path)
	)
	var expected := {
		"companion_mount_base_cols": 1.0,
		"companion_mount_base_rows": 1.0,
		"companion_mount_base_frame_count": 1.0,
		"companion_mount_base_draw_size": 360.0,
		"companion_mount_base_saddle_x": 256.0,
		"companion_mount_base_saddle_y": 508.0,
	}
	var layout_ok := true
	for key in expected:
		if not is_equal_approx(LingpetCatalog.get_visual_layout_value("baekrin", str(key), -1.0), float(expected[key])):
			layout_ok = false
	_expect("출하 M: 레이아웃 6키가 승인 값과 일치(360 / 소켓 256·508)", layout_ok)
	# ★ 8-10 가드: N 착석 시트 5종이 완비될 때까지 topdown 모델은 **미등재**여야
	# 한다. 여기서 true 가 되면 준비도 게이트가 매 프레임 N 부재로 거부하는
	# 무의미한 경로가 열린다.
	_expect(
		"출하 M: mount_presentation_model 미등재 유지 (8-10)",
		not LingpetCatalog.is_mount_presentation_topdown("baekrin")
	)
	# N 시트는 아직 한 장도 없다 — 경로 공백 = fail-closed 유지.
	# 경로가 비어 있으면 소비용 조회는 **빈 dict**(fail-closed)이고, 규격 조회만
	# 선언값을 돌려준다 — 두 계약을 함께 잰다.
	var rider: Dictionary = PlayerMountRiderSpriteCatalog.get_rider_from_canonical("smasher")
	var spec: Dictionary = PlayerMountRiderSpriteCatalog.get_rider_spec("smasher")
	_expect(
		"출하 N: 소비 조회는 빈 dict(fail-closed) + 규격 draw_size 94 예약",
		rider.is_empty()
			and str(spec.get("path", "x")) == ""
			and (spec.get("draw_size", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(94.0, 94.0))
	)


# ── §B-5: 탑다운 리프트 0 ───────────────────────────────────────────────────

func _test_topdown_lift_zero() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	_expect("리프트 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))

	# 진입(홉 상승 중): mount_state 는 여전히 목말용 리프트를 **계산**하지만,
	# 표현 모델이 탑다운이면 소비자에게 나가는 값은 0 이어야 한다. 두 값을 함께
	# 재야 "상태가 죽어서 0"인 공허 GREEN 과 구분된다.
	# 홉 t=0 프레임의 리프트는 목말에서도 0 이다(그래서 defer 근거로 못 쓴다) —
	# 상승 구간으로 몇 프레임 진행시켜야 "내부는 양수" 대조가 성립한다.
	for i in range(3):
		runtime._update_companion_motion(0.016, owner, registry)
	var raw_hop: float = float(runtime._mount_state.get_rider_lift_px())
	_expect(
		"리프트 진입: 내부 상태는 양수인데 공개 값은 0 (모델 기준 차단)",
		raw_hop > 0.0 and is_zero_approx(runtime.get_mount_rider_lift_px())
	)
	# 정착: 홉이 끝난 뒤에도 0.
	for i in range(30):
		runtime._update_companion_motion(0.016, owner, registry)
	_expect(
		"리프트 정착: 홉 완료 후에도 0 (바운스 누출 없음)",
		float(runtime._mount_state.get_rider_lift_px()) > 0.0
			and is_zero_approx(runtime.get_mount_rider_lift_px())
	)
	# 하차 직후 잔여: dismount 램프가 진행 중이어도 0 — 활성 기준으로 막으면
	# 여기서 되살아난다(이 레그가 "활성 게이트" 오답의 판별점).
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = false
	var residual_raw: float = float(runtime._mount_state.get_rider_lift_px())
	_expect(
		"리프트 하차 잔여: 내부 감쇠 리프트는 양수인데 공개 값은 0",
		not bool(runtime._mount_state.is_mounted())
			and residual_raw > 0.0
			and is_zero_approx(runtime.get_mount_rider_lift_px())
	)

	# 온이마루 대조군: 목말은 종전 그대로 양수 리프트를 내보낸다.
	var oni_owner := OperationalOwner.new()
	var oni_registry := SpyRegistry.new()
	var oni_runtime: Object = LingpetEggRuntime.new()
	oni_runtime.debug_grant_and_activate_pet("onimaru", oni_owner, false)
	oni_runtime._state = "companion"
	oni_runtime._guardian_stowed = false
	oni_runtime._companion_motion_coordinator.set_position(
		Vector2(oni_owner.player_pos.x + oni_owner.player_paddle_width * 0.5, 655.0)
	)
	var oni_mounted: bool = _mount(oni_runtime, oni_owner, oni_registry)
	for i in range(20):
		oni_runtime._update_companion_motion(0.016, oni_owner, oni_registry)
	_expect(
		"리프트 대조군: 온이마루(목말)는 양수 리프트 유지",
		oni_mounted and oni_runtime.get_mount_rider_lift_px() > 0.0
	)


# ── 사슬: scene context → actor context → 실 actor draw() → sprite 수신 ────

func _test_end_to_end_chain() -> void:
	var owner := OperationalOwner.new()
	var fixture := _make_ready_runtime(owner)
	var runtime: Object = fixture["runtime"]
	var registry: Object = fixture["registry"]
	_expect("사슬 사전: 탑다운 탑승 성립", _mount(runtime, owner, registry))
	var stored_texture: Variant = runtime.get_topdown_mount_readiness().get("rider_texture", null)

	# 1) 실 scene context 생산자(헬퍼 3종)가 만드는 값으로 시작한다.
	var scene_builder: Object = BattleDrawPlayfieldSceneContext.new()
	var scene_slice := {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"player_pos": Vector2(300.0, 675.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"player_paddle_scale": 1.0,
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"textures": {},
		"paddle_hologram_should_draw": true,
		"player_mount_rider_lift_px": scene_builder._get_mount_rider_lift(registry),
		"player_mount_topdown_active": scene_builder._is_mount_topdown_active(registry),
		"player_mount_rider_seated": scene_builder._get_mount_rider_seated_payload(registry),
	}
	_expect(
		"사슬 1: scene 생산자의 리프트가 0 (탑다운 §B-5)",
		is_zero_approx(float(scene_slice["player_mount_rider_lift_px"]))
	)

	# 2) 실 actor context 빌더 → 3) 실 훅 주입 → 4) 실 actor draw().
	var actor_context: Dictionary = BattleDrawActorContext.new().build(scene_slice, {})
	BattlePlayfieldSceneDrawer.install_lingpet_draw_hooks(actor_context, runtime, Vector2.ZERO)
	var chain_spy := SpySpriteRenderer.new()
	var actor_renderer: Object = Stage1PlayerActorRenderer.new()
	actor_renderer.sprite_renderer = chain_spy
	actor_renderer.dash_side_gauge_renderer = SpyDashSideGaugeRenderer.new()
	var companion_spy := SpyCompanionRenderer.new()
	runtime._companion_renderer = companion_spy
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		actor_renderer.draw(canvas, actor_context, Vector2.ZERO))

	_expect(
		"사슬 2: actor context 리프트도 0 (중간 단계 재주입 없음)",
		is_zero_approx(float(actor_context.get("player_mount_rider_lift_px", -1.0)))
	)
	var received_payload: Dictionary = (chain_spy.last_context.get("player_mount_rider_seated", {}) as Dictionary)
	_expect(
		"사슬 3: sprite 렌더러가 받은 N 텍스처 == readiness 보존 객체 (P16② 전 구간)",
		chain_spy.draw_calls == 1 and received_payload.get("texture", null) == stored_texture
	)
	# 리프트 0 이므로 라이더 rect 하단은 패들 하단 기준 베이스라인에 붙는다.
	var expected_top: float = 675.0 + 50.0 - chain_spy.last_rect.size.y + 12.0
	_expect(
		"사슬 4: 라이더 rect 가 리프트 없이 패들 베이스라인에 앉는다 (14~17px 부양 금지)",
		absf(chain_spy.last_rect.position.y - expected_top) <= 0.01
	)
	_expect(
		"사슬 5: 같은 프레임에 M 합성이 라이더 rect 기준으로 1회 그려진다",
		companion_spy.composite_calls == 1
			and companion_spy.last_dest.position.distance_to(
				_expected_mount_dest(chain_spy.last_rect).position
			) <= 0.01
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

	# 정수 계약 — 소수 그리드는 draw 관통에서 기각된다(int() 절단 승인 금지).
	var fractional_cases := [
		{"label": "cols=2.5", "overrides": {"companion_mount_base_cols": 2.5, "companion_mount_base_frame_count": 1.0}},
		{"label": "rows=1.4", "overrides": {"companion_mount_base_rows": 1.4}},
		{"label": "frame_count=1.5", "overrides": {"companion_mount_base_cols": 2.0, "companion_mount_base_frame_count": 1.5}},
	]
	for fractional in fractional_cases:
		var fr_owner := OperationalOwner.new()
		var fr_fixture := _make_ready_runtime(fr_owner, "", (fractional as Dictionary)["overrides"])
		var fr_runtime: Object = fr_fixture["runtime"]
		var fr_spy := SpyCompanionRenderer.new()
		fr_runtime._companion_renderer = fr_spy
		var fr_mounted: bool = _mount(fr_runtime, fr_owner, fr_fixture["registry"])
		await _draw_on_probe(func(canvas: CanvasItem) -> void:
			fr_runtime.draw_topdown_mount_base(canvas, rider_rect))
		_expect(
			"P12 정수 계약: %s 는 draw 0회 (2.5→2 조용한 절단 금지)" % str((fractional as Dictionary)["label"]),
			fr_mounted and fr_spy.composite_calls == 0
		)

	# 카탈로그 ±0.001 을 통과하는 근사 정수는 **정규화**되어야 한다 —
	# int() 절단이면 1.9995 가 1 이 되어 검증이 승인한 그리드와 슬라이싱이 갈린다.
	var near_owner := OperationalOwner.new()
	var near_fixture := _make_ready_runtime(near_owner, "", {
		"companion_mount_base_cols": 1.9995,
		"companion_mount_base_frame_count": 1.0,
	})
	var near_runtime: Object = near_fixture["runtime"]
	var near_spy := SpyCompanionRenderer.new()
	near_runtime._companion_renderer = near_spy
	var near_mounted: bool = _mount(near_runtime, near_owner, near_fixture["registry"])
	await _draw_on_probe(func(canvas: CanvasItem) -> void:
		near_runtime.draw_topdown_mount_base(canvas, rider_rect))
	_expect(
		"P12 정수 계약: 1.9995 cols 는 2 로 정규화되어 셀 폭 = 텍스처/2 (절단이면 /1)",
		near_mounted
			and near_spy.composite_calls == 1
			and absf(near_spy.last_source.size.x - MOUNT_CELL_PX * 0.5) <= 0.01
	)

	# 런타임 해석기 직접 레그 — draw 관통으로 만들기 번거로운 값 범위.
	var helper_owner := OperationalOwner.new()
	var helper_fixture := _make_ready_runtime(helper_owner)
	var helper_runtime: Object = helper_fixture["runtime"]
	var resolved: Dictionary = helper_runtime._resolve_topdown_mount_layout()
	_expect(
		"해석기: 정상 레이아웃은 6키 전부 + 그리드 정수 정규화",
		resolved.size() == LingpetCatalog.MOUNT_TOPDOWN_REQUIRED_LAYOUT_KEYS.size()
			and is_equal_approx(float(resolved.get("companion_mount_base_cols", 0.0)), MOUNT_COLS)
			and is_equal_approx(float(resolved.get("companion_mount_base_draw_size", 0.0)), MOUNT_DRAW_SIZE)
	)
	var reject_cases := [
		{"label": "cols=INF", "overrides": {"companion_mount_base_cols": INF}},
		{"label": "draw_size=0", "overrides": {"companion_mount_base_draw_size": 0.0}},
		{"label": "draw_size=-1", "overrides": {"companion_mount_base_draw_size": -1.0}},
		{"label": "saddle_x=NAN", "overrides": {"companion_mount_base_saddle_x": NAN}},
		{"label": "frame_count > cols×rows", "overrides": {"companion_mount_base_cols": 2.0, "companion_mount_base_rows": 1.0, "companion_mount_base_frame_count": 3.0}},
		{"label": "cols=0", "overrides": {"companion_mount_base_cols": 0.0, "companion_mount_base_frame_count": 1.0}},
	]
	for reject in reject_cases:
		_install_topdown_model("", (reject as Dictionary)["overrides"])
		_expect(
			"해석기 fail-closed: %s → 빈 dict" % str((reject as Dictionary)["label"]),
			(helper_runtime._resolve_topdown_mount_layout() as Dictionary).is_empty()
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
