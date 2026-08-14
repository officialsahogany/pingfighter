extends SceneTree

# G9 — 백린 M 베이스 실렌더 QA (계약 브리프 §5-2 G9) + **draw_size 스윕**.
#
# 판정 구조(2026-08-14 승격): 횡방향은 관찰 메모가 아니라 **정식 하위 게이트**다.
#   - 출하 draw_size(카탈로그에서 읽는다) → 세로·횡·안장 전부 PASS 해야 한다.
#   - 음성 대조군 D=240 → **횡에서 반드시 FAIL** 해야 한다. 통과하면 게이트가
#     판별력을 잃은 것이므로 그것도 실패로 본다(draw_size 가 조용히 커지는 회귀 차단).
#   - 그 외 크기는 기록용이며 종료 코드에 영향을 주지 않는다.
#
# 판정:
#   ① 세로 계약: 마운트 픽셀이 y > 762 에 **0개**. (751~762 은 현행 플레이어
#      스프라이트가 이미 쓰는 기존 오버행 대역이라 허용)
#   ② 횡 계약(2026-08-14 신설): 좌·우 벽 끝에서 필드(0..760) 밖으로 나가는
#      마운트 픽셀이 **≤3px**. 일반 플레이어 스프라이트와 같은 수락선이다.
#   ③ 안장 정렬: 마운트 최저 픽셀(=소켓, G3 로 0px 보증)이 라이더 rect 하단
#      762 와 **≤2px**.
#
# 마운트 픽셀 분리는 같은 장면의 M 활성/비활성 **A/B 차분**으로 한다.
# 뷰포트는 필드(760)보다 넓게 잡아 **필드 밖으로 나간 픽셀까지 관측**한다 —
# 760 폭으로 캡처하면 오버행이 잘려서 측정 자체가 불가능하다.
#
# ⚠️ 탑다운 모델은 shipped 카탈로그에 없다(계약 8-10). 이 도구는 테스트
# 오버라이드로만 켜고, 종료 직전 반드시 해제해 미활성 상태를 재확인한다.
#
# 실행: <godot> --path godot --script res://tools/baekrin_mount_base_g9_capture.gd

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const PlayerMountRiderSpriteCatalog := preload("res://scripts/resources/player_mount_rider_sprite_catalog.gd")

const OUT_DIR := "C:/Users/woduq/bosspong_backups/qa_evidence"
const FIELD := Vector2i(760, 750)
const MARGIN_X := 160                       # 필드 밖 관측 여유(좌우 각각)
const VIEW := Vector2i(760 + MARGIN_X * 2, 830)
const MOUNT_PATH := "res://assets/sprites/lingpet/baekrin_companion_mount_base_topdown_v1.png"
const PADDLE_SIZE := Vector2(155.0, 50.0)
const PLAYER_Y := 700.0
const RIDER_DRAW := 94.0
const FLOOR_Y := 750
const OVERHANG_LIMIT := 762
const LATERAL_LIMIT := 3                    # 일반 플레이어 기준 수락선
const SADDLE_TOLERANCE := 2
# 출하 draw_size 는 카탈로그에서 읽는다 — 여기 리터럴을 두면 카탈로그가 조용히
# 커져도 게이트가 옛 값으로 통과한다.
# 음성 대조군: 이 크기는 **반드시 횡에서 실패**해야 한다. 통과해 버리면 횡 게이트가
# 판별력을 잃은 것이므로 그것도 FAIL 로 본다(게이트가 게이트인지 검사).
const NEGATIVE_CONTROL_SIZE := 240.0
# 기록용 스윕(판정에는 관여하지 않는다).
const RECORD_SIZES := [270.0, 300.0, 360.0]


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
	var paddle_x := 0.0
	var rider_texture: Texture2D = null
	var rider_rect := Rect2()

	func _draw() -> void:
		# 필드 밖(letterbox) 은 어둡게, 필드 안은 약간 밝게 — 경계가 보이도록.
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW.x, VIEW.y)), Color(0.03, 0.03, 0.04, 1.0))
		draw_rect(Rect2(Vector2(float(MARGIN_X), 0.0), Vector2(float(FIELD.x), float(FLOOR_Y))), Color(0.06, 0.065, 0.085, 1.0))
		draw_rect(
			Rect2(Vector2(float(MARGIN_X), float(FLOOR_Y)), Vector2(float(FIELD.x), float(VIEW.y - FLOOR_Y))),
			Color(0.11, 0.06, 0.06, 1.0)
		)
		draw_rect(Rect2(Vector2(float(MARGIN_X) + paddle_x, PLAYER_Y), PADDLE_SIZE), Color(0.18, 0.22, 0.30, 1.0))
		if draw_mount and runtime != null:
			runtime.draw_topdown_mount_base(self, rider_rect)
		if rider_texture != null:
			draw_texture_rect(rider_texture, rider_rect, false)
		# 기준선: 필드 좌우 벽 · 바닥 750 · 오버행 한계 762
		var wall := Color(0.35, 0.75, 1.0, 0.9)
		draw_line(Vector2(float(MARGIN_X), 0.0), Vector2(float(MARGIN_X), float(VIEW.y)), wall, 1.0)
		draw_line(Vector2(float(MARGIN_X + FIELD.x), 0.0), Vector2(float(MARGIN_X + FIELD.x), float(VIEW.y)), wall, 1.0)
		draw_line(Vector2(0.0, float(FLOOR_Y)), Vector2(float(VIEW.x), float(FLOOR_Y)), Color(1.0, 0.85, 0.3, 0.9), 1.0)
		draw_line(Vector2(0.0, float(OVERHANG_LIMIT)), Vector2(float(VIEW.x), float(OVERHANG_LIMIT)), Color(1.0, 0.35, 0.35, 0.9), 1.0)


func _init() -> void:
	call_deferred("_run")


func _make_rider_texture() -> Texture2D:
	# N 시트는 아직 없다(8-10). 착석 라이더 자리를 같은 규격의 실루엣 박스로 세워
	# 안장 정렬만 관측한다 — 아트 판정이 아니라 좌표 판정용이다.
	# 실제 착석 라이더는 셀을 꽉 채우지 않는다(웅크린 상반신 + 어깨). 판정이 과장
	# 되지 않도록 셀의 약 70% 만 차지하는 실루엣으로 세운다: 머리 원 + 어깨 사다리꼴.
	# 셀 경계는 얇은 가이드선으로만 남긴다.
	var size := int(RIDER_DRAW)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cx: float = size * 0.5
	var head_cy: float = size * 0.34
	var head_r: float = size * 0.20
	for y in range(size):
		for x in range(size):
			var fx: float = float(x) + 0.5
			var fy: float = float(y) + 0.5
			var on_guide: bool = (x < 1 or y < 1 or x >= size - 1 or y >= size - 1)
			var in_head: bool = Vector2(fx - cx, fy - head_cy).length() <= head_r
			var t: float = clampf((fy - size * 0.48) / (size * 0.52), 0.0, 1.0)
			var half: float = size * lerpf(0.22, 0.31, t)
			var in_body: bool = fy >= size * 0.48 and absf(fx - cx) <= half
			if in_head or in_body:
				img.set_pixel(x, y, Color(0.58, 0.65, 0.76, 0.92))
			elif on_guide:
				img.set_pixel(x, y, Color(0.20, 0.90, 1.0, 0.55))
	return ImageTexture.create_from_image(img)


func _install_override(draw_size: float) -> void:
	LingpetCatalog.set_mount_presentation_override_for_tests(
		"baekrin",
		LingpetCatalog.MOUNT_PRESENTATION_TOPDOWN,
		MOUNT_PATH,
		{
			"companion_mount_base_cols": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_cols", 1.0),
			"companion_mount_base_rows": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_rows", 1.0),
			"companion_mount_base_frame_count": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_frame_count", 1.0),
			"companion_mount_base_draw_size": draw_size,
			"companion_mount_base_saddle_x": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_saddle_x", 256.0),
			"companion_mount_base_saddle_y": LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_saddle_y", 508.0),
		}
	)


func _build_runtime(owner: Object, registry: Object) -> Object:
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

	var positions := {
		"left_wall": 0.0,
		"center": (float(FIELD.x) - PADDLE_SIZE.x) * 0.5,
		"right_wall": float(FIELD.x) - PADDLE_SIZE.x,
	}

	var shipped_size: float = LingpetCatalog.get_visual_layout_value("baekrin", "companion_mount_base_draw_size", 0.0)
	if shipped_size <= 0.0:
		print("G9 | 출하 draw_size 미등재 — 카탈로그 배선 확인 필요")
		quit(1)
		return
	var control_tripped := false
	var judged: Array[float] = [shipped_size, NEGATIVE_CONTROL_SIZE]
	var sizes: Array = judged.duplicate()
	for extra in RECORD_SIZES:
		if not sizes.has(float(extra)):
			sizes.append(float(extra))

	for draw_size in sizes:
		for label in positions:
			var paddle_x: float = float(positions[label])
			_install_override(float(draw_size))
			var owner := Owner.new()
			owner.player_pos = Vector2(paddle_x, PLAYER_Y)
			var registry := Registry.new()
			var runtime: Object = _build_runtime(owner, registry)
			if not _mount(runtime, owner, registry):
				report.append("D=%3d %-11s MOUNT FAILED" % [int(draw_size), label])
				failed = true
				continue

			var scene := Scene.new()
			get_root().add_child(scene)
			scene.runtime = runtime
			scene.rider_texture = rider_texture
			scene.paddle_x = paddle_x
			var rider_x: float = float(MARGIN_X) + paddle_x + PADDLE_SIZE.x * 0.5 - RIDER_DRAW * 0.5
			var rider_y: float = PLAYER_Y + PADDLE_SIZE.y - RIDER_DRAW + 12.0
			scene.rider_rect = Rect2(Vector2(rider_x, rider_y), Vector2(RIDER_DRAW, RIDER_DRAW))

			scene.draw_mount = true
			var with_mount: Image = await _capture(scene)
			scene.draw_mount = false
			var without_mount: Image = await _capture(scene)

			var count: int = 0
			var min_x: int = VIEW.x
			var max_x: int = -1
			var lowest: int = -1
			var below_limit: int = 0
			for y in range(VIEW.y):
				for x in range(VIEW.x):
					var a: Color = with_mount.get_pixel(x, y)
					var b: Color = without_mount.get_pixel(x, y)
					if abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) > 0.02:
						count += 1
						min_x = mini(min_x, x)
						max_x = maxi(max_x, x)
						lowest = maxi(lowest, y)
						if y > OVERHANG_LIMIT:
							below_limit += 1
			# 필드 좌표계로 환산(MARGIN_X 만큼 이동돼 있다)
			var field_min: int = min_x - MARGIN_X
			var field_max: int = max_x - MARGIN_X
			var over_left: int = maxi(0, -field_min)
			var over_right: int = maxi(0, field_max - (FIELD.x - 1))
			var over_lat: int = maxi(over_left, over_right)
			var saddle_err: int = absi(lowest - OVERHANG_LIMIT)
			var ok: bool = below_limit == 0 and over_lat <= LATERAL_LIMIT and saddle_err <= SADDLE_TOLERANCE
			var role := "기록"
			if is_equal_approx(float(draw_size), shipped_size):
				role = "출하"
				failed = failed or not ok
			elif is_equal_approx(float(draw_size), NEGATIVE_CONTROL_SIZE):
				role = "음성"
				# ⚠️ 대조군 판정은 **크기 단위**다 — 중앙에서는 어떤 크기든 오버행이
				# 0 이므로 지점마다 "초과해야 한다"고 요구하면 중앙이 항상 실패한다.
				# 여기서는 세로·정렬만 지점 판정하고, "벽에서 초과했는가"는 루프
				# 뒤에서 크기 단위로 집계한다.
				ok = below_limit == 0 and saddle_err <= SADDLE_TOLERANCE
				failed = failed or not ok
				if over_lat > LATERAL_LIMIT:
					control_tripped = true
			report.append(
				"D=%3d(%s) %-11s px %6d | x %5d..%-5d | 횡오버행 %4d (<=%d) | 최저y %4d (안장오차 %d) | y>762 %4d -> %s"
				% [int(draw_size), role, label, count, field_min, field_max, over_lat, LATERAL_LIMIT,
				   lowest, saddle_err, below_limit,
				   ("PASS" if ok else "FAIL") if role != "기록" else ("ok" if ok else "over")]
			)
			if label == "center" or over_lat > LATERAL_LIMIT:
				with_mount.save_png("%s/baekrin_mount_g9_d%d_%s.png" % [OUT_DIR, int(draw_size), label])
			scene.queue_free()

	# 음성 대조군 집계: 더 큰 draw_size 는 **벽에서 반드시 횡 게이트를 밟아야** 한다.
	# 밟지 않으면 게이트가 판별력을 잃은 것이므로 실패로 본다.
	report.append("음성 대조군 D=%d 가 벽에서 횡 게이트를 밟았는가: %s (기대 true)"
		% [int(NEGATIVE_CONTROL_SIZE), str(control_tripped)])
	failed = failed or not control_tripped

	# ★ 종료 전 오버라이드 해제 + shipped 미활성 재확인
	LingpetCatalog.clear_mount_presentation_test_overrides()
	var shipped_active: bool = LingpetCatalog.is_mount_presentation_topdown("baekrin")
	report.append("shipped mount_presentation_model active after test: %s (기대 false)" % str(shipped_active))
	failed = failed or shipped_active

	for line in report:
		print("G9 | %s" % line)
	print("G9 RESULT: %s" % ("FAILED" if failed else "ok"))
	quit(1 if failed else 0)
