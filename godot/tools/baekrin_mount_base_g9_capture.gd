extends SceneTree

# G9 — 백린 M 베이스 실렌더 QA (계약 브리프 §5-2 G9).
#
# 판정 두 가지를 **실 렌더러 관통 픽셀**로 닫는다:
#   ① 바닥 계약: 마운트 픽셀이 y > 762 에 **0개**. (751~762 은 현행 플레이어
#      스프라이트가 이미 쓰는 기존 오버행 대역이라 허용)
#   ② 좌우 끝 압박: 중앙 / 좌벽 / 우벽 세 패들 위치에서 안장 정렬과 화면 가장자리
#      압박을 눈으로 볼 수 있게 캡처한다(G6 0.75 완화의 시각 확인, 수치 게이트 아님).
#
# 마운트 픽셀 분리는 **같은 장면의 M 활성 / 비활성 A/B 차분**으로 한다 — 배경·패들·
# 라이더가 동일하므로 차분에 남는 건 마운트뿐이다.
#
# ⚠️ 탑다운 모델은 shipped 카탈로그에 없다(계약 8-10). 이 도구는 **테스트
# 오버라이드로만** 켜고, 종료 직전 반드시 해제해 미활성 상태를 재확인한다.
#
# 실행: <godot> --path godot --script res://tools/baekrin_mount_base_g9_capture.gd

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const BattlePlayfieldSceneDrawer := preload("res://scripts/core/battle_playfield_scene_drawer.gd")
const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")

const OUT_DIR := "C:/Users/woduq/bosspong_backups/qa_evidence"
const FIELD := Vector2i(760, 750)
const VIEW := Vector2i(760, 820)   # 750 아래 70px 을 함께 굽는다(오버행 관측용)
const MOUNT_PATH := "res://assets/sprites/lingpet/baekrin_companion_mount_base_topdown_v1.png"
const PADDLE_SIZE := Vector2(155.0, 50.0)
const PLAYER_Y := 700.0
const RIDER_DRAW := 94.0
const FLOOR_Y := 750
const OVERHANG_LIMIT := 762


class SpySpriteRenderer:
	extends RefCounted

	var last_rect := Rect2()

	func draw(_canvas: CanvasItem, _context: Dictionary, player_visual_rect: Rect2, _m: bool, _p: Vector2, _s: Vector2, _sh: Vector2) -> void:
		last_rect = player_visual_rect

	func clear_transient_canvas_items() -> void:
		pass


class NoopGauge:
	extends RefCounted

	func draw(_c: CanvasItem, _ctx: Dictionary, _p: Vector2, _s: Vector2, _sh: Vector2) -> void:
		pass


class FakeInputProbe:
	extends RefCounted

	var rmb := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return false


class Owner:
	extends RefCounted

	var player_pos := Vector2(302.5, PLAYER_Y)
	var player_paddle_width := PADDLE_SIZE.x
	var player_speed := 0.0
	var selected_character_type := "smasher"
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6


class Resources:
	extends RefCounted

	var resource_cache: Dictionary = {}

	func get_resource_cache() -> Dictionary:
		return resource_cache


class Registry:
	extends RefCounted

	var cached: Dictionary = {}

	func get_cached_instance(key: String) -> Variant:
		return cached.get(key, null)

	func get_instance(key: String) -> Variant:
		return cached.get(key, null)


class Scene:
	extends Node2D

	var draw_mount := true
	var runtime: Object = null
	var actor_context: Dictionary = {}
	var rider_texture: Texture2D = null
	var rider_rect := Rect2()

	func _draw() -> void:
		# 필드 바닥선/오버행 대역 가이드
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW.x, VIEW.y)), Color(0.05, 0.055, 0.07, 1.0))
		draw_rect(Rect2(Vector2(0.0, float(FLOOR_Y)), Vector2(float(VIEW.x), float(VIEW.y - FLOOR_Y))), Color(0.10, 0.06, 0.06, 1.0))
		# 패들(플레이어 물리 몸집)
		draw_rect(Rect2(Vector2(actor_context.get("player_pos", Vector2.ZERO).x, PLAYER_Y), PADDLE_SIZE), Color(0.18, 0.22, 0.30, 1.0))
		if draw_mount and runtime != null:
			runtime.draw_topdown_mount_base(self, rider_rect)
		if rider_texture != null:
			draw_texture_rect(rider_texture, rider_rect, false)
		# 기준선
		draw_line(Vector2(0.0, float(FLOOR_Y)), Vector2(float(VIEW.x), float(FLOOR_Y)), Color(1.0, 0.85, 0.3, 0.9), 1.0)
		draw_line(Vector2(0.0, float(OVERHANG_LIMIT)), Vector2(float(VIEW.x), float(OVERHANG_LIMIT)), Color(1.0, 0.35, 0.35, 0.9), 1.0)


func _init() -> void:
	call_deferred("_run")


func _make_rider_texture() -> Texture2D:
	# N 시트는 아직 없다(8-10). 착석 라이더 자리를 같은 규격의 실루엣 박스로 세워
	# **안장 정렬**만 관측한다 — 아트 판정이 아니라 좌표 판정용이다.
	var img := Image.create(int(RIDER_DRAW), int(RIDER_DRAW), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.80, 0.70, 0.0))
	for y in range(int(RIDER_DRAW)):
		for x in range(int(RIDER_DRAW)):
			var edge: bool = x < 2 or y < 2 or x >= int(RIDER_DRAW) - 2 or y >= int(RIDER_DRAW) - 2
			var body: bool = y >= int(RIDER_DRAW) * 0.25 and x >= 18 and x < int(RIDER_DRAW) - 18
			if edge:
				img.set_pixel(x, y, Color(0.20, 0.90, 1.0, 0.95))
			elif body:
				img.set_pixel(x, y, Color(0.55, 0.62, 0.72, 0.85))
	return ImageTexture.create_from_image(img)


func _build_runtime(owner: Object, registry: Object) -> Object:
	LingpetCatalog.set_mount_presentation_override_for_tests(
		"baekrin",
		LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		MOUNT_PATH,
		{
			"companion_mount_base_cols": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_cols", 0.0),
			"companion_mount_base_rows": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_rows", 0.0),
			"companion_mount_base_frame_count": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_frame_count", 0.0),
			"companion_mount_base_draw_size": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_draw_size", 0.0),
			"companion_mount_base_saddle_x": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_saddle_x", 0.0),
			"companion_mount_base_saddle_y": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_saddle_y", 0.0),
		}
	)
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet("baekrin", owner, false, "baekrin_saddle")
	runtime._state = "companion"
	runtime._guardian_stowed = false
	runtime._companion_motion_coordinator.set_position(
		Vector2(owner.player_pos.x + PADDLE_SIZE.x * 0.5, 655.0)
	)
	runtime._current_profile.get_visual_texture(LingpetCatalog.MOUNT_BASE_VISUAL_KEY, null)
	runtime._guardian_run_state.set_duration_pool_for_tests(30.0, 60.0)
	runtime._mount_topdown_readiness.rider_spec_provider = func(character_id: String) -> Dictionary:
		return PlayerMountRiderSpriteCatalog.get_rider_spec(character_id)
	var resources := Resources.new()
	resources.resource_cache[PlayerMountRiderSpriteCatalog.get_texture_cache_key("smasher")] = _make_rider_texture()
	registry.cached["battle_resources"] = resources
	registry.cached["lingpet_egg_runtime"] = runtime
	return runtime


func _mount(runtime: Object, owner: Object, registry: Object) -> bool:
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = false
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = false
	for i in range(20):
		runtime._update_companion_motion(0.016, owner, registry)
	return bool(runtime._mount_state.is_mounted())


func _capture(scene: Scene) -> Image:
	scene.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	return get_root().get_texture().get_image()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	get_root().set_content_scale_size(VIEW)
	get_root().size = VIEW

	var rider_texture := _make_rider_texture()
	var report: Array[String] = []
	var failed := false

	# 좌벽 / 중앙 / 우벽 — 패들이 실제로 도달하는 x 범위
	var positions := {
		"left_wall": 0.0,
		"center": (float(FIELD.x) - PADDLE_SIZE.x) * 0.5,
		"right_wall": float(FIELD.x) - PADDLE_SIZE.x,
	}

	for label in positions:
		var owner := Owner.new()
		owner.player_pos = Vector2(float(positions[label]), PLAYER_Y)
		var registry := Registry.new()
		var runtime: Object = _build_runtime(owner, registry)
		if not _mount(runtime, owner, registry):
			report.append("%s: MOUNT FAILED" % label)
			failed = true
			continue

		var scene := Scene.new()
		get_root().add_child(scene)
		scene.runtime = runtime
		scene.rider_texture = rider_texture
		scene.actor_context = {"player_pos": owner.player_pos}
		var rider_x: float = owner.player_pos.x + PADDLE_SIZE.x * 0.5 - RIDER_DRAW * 0.5
		var rider_y: float = PLAYER_Y + PADDLE_SIZE.y - RIDER_DRAW + 12.0
		scene.rider_rect = Rect2(Vector2(rider_x, rider_y), Vector2(RIDER_DRAW, RIDER_DRAW))

		scene.draw_mount = true
		var with_mount: Image = await _capture(scene)
		scene.draw_mount = false
		var without_mount: Image = await _capture(scene)

		# A/B 차분 = 마운트 픽셀만
		var diff_rows: int = 0
		var lowest: int = -1
		var below_floor: int = 0
		var below_limit: int = 0
		for y in range(VIEW.y):
			for x in range(VIEW.x):
				var a: Color = with_mount.get_pixel(x, y)
				var b: Color = without_mount.get_pixel(x, y)
				if abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) > 0.02:
					diff_rows += 1
					if y > lowest:
						lowest = y
					if y > FLOOR_Y:
						below_floor += 1
					if y > OVERHANG_LIMIT:
						below_limit += 1
		var ok: bool = below_limit == 0
		failed = failed or not ok
		report.append("%-11s mount px %6d | lowest y %4d | y>750 %5d | y>762 %5d -> %s"
			% [label, diff_rows, lowest, below_floor, below_limit, "PASS" if ok else "FAIL"])
		with_mount.save_png("%s/baekrin_mount_g9_%s.png" % [OUT_DIR, label])
		scene.queue_free()

	# ★ 종료 전 오버라이드 해제 + shipped 미활성 재확인
	LingpetCatalog.clear_mount_presentation_test_overrides()
	var shipped_active: bool = LingpetCatalog.is_mount_presentation_topdown("baekrin")
	report.append("shipped mount_presentation_model active after test: %s (기대 false)" % str(shipped_active))
	failed = failed or shipped_active

	for line in report:
		print("G9 | %s" % line)
	print("G9 RESULT: %s" % ("FAILED" if failed else "ok"))
	quit(1 if failed else 0)
