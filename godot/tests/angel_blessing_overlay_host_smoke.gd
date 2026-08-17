extends SceneTree

const AngelBlessingRollOverlayHost := preload("res://scripts/hud/angel_blessing_roll_overlay_host.gd")

const GAME_SIZE := Vector2(760.0, 750.0)
const VIEW_SIZE := Vector2i(960, 800)
const GAME_OFFSET := Vector2(100.0, 25.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var host: Node2D = AngelBlessingRollOverlayHost.new()
	viewport.add_child(host)
	host.prepare()
	await process_frame

	_verify_pipeline_and_clip_contract(host)
	_verify_phase_boundaries(host)
	_verify_hwangyeokjeon_omen_reading(host)
	_verify_omen_modular_layers(host)
	_verify_absorption_projection(host)
	await _verify_letterbox_clip_when_available(viewport, host)
	_verify_explicit_and_static_cleanup(viewport, host)

	viewport.queue_free()
	_finish()


func _verify_pipeline_and_clip_contract(host: Node2D) -> void:
	var pipeline: Dictionary = AngelBlessingRollOverlayHost.build_pipeline_status()
	_expect(bool(pipeline.get("icon_ready", false)), "Angel overlay should prewarm its dedicated icon texture")
	_expect(bool(pipeline.get("omen_identity_ready", false)), "천운삼괘 overlay should prewarm its static seal and 8-frame omen sheet")
	_expect(str(pipeline.get("style_family", "")) == "hwangyeokjeon_divination", "천운삼괘 overlay should declare the 환격전 divination style family")
	_expect(not bool(pipeline.get("legacy_dice_assets_required", true)), "환격전 천운삼괘 presentation must not require dice or angel-wing assets")
	_expect(bool(pipeline.get("texture_layers_ready", false)), "Angel overlay should prewarm its modular texture layers")
	_expect(bool(pipeline.get("particle_texture_ready", false)), "Angel overlay should prewarm its particle texture")
	_expect(bool(pipeline.get("shader_ready", false)), "Angel overlay should prewarm its halo shader")
	_expect(int(pipeline.get("texture_layer_count", 0)) >= 3, "Angel overlay should expose at least three texture pieces")
	_expect(int(pipeline.get("gpu_particle_layer_count", 0)) >= 2, "Angel overlay should expose its ambient and absorb particle layers")
	var source := FileAccess.get_file_as_string("res://scripts/hud/angel_blessing_roll_overlay_host.gd")
	_expect(source.find("angel_blessing_perk_icon_sheet.png") >= 0, "천운삼괘 live host should use the rebranded 8-frame omen seal sheet")
	for retired_asset: String in ["angel_dice_backplate", "angel_dice_arc", "angel_dice_die", "angel_dice_wing"]:
		_expect(source.find(retired_asset) < 0, "천운삼괘 live host must not load retired Ringpia asset %s" % retired_asset)

	var status: Dictionary = host.get_debug_status()
	_expect(not bool(status.get("process_enabled", true)), "controller-driven Angel overlay host must keep its own process disabled")
	_expect(bool(status.get("playfield_clip_active", false)), "Angel overlay must clip to the full 760x750 game canvas")
	_expect(bool(status.get("draw_bridge_inside_clip", false)), "Angel draw bridge must be a child of the full-game clip")
	_expect(bool(status.get("particle_layers_inside_clip", false)), "both Angel particle layers must remain inside the full-game clip")


func _verify_phase_boundaries(host: Node2D) -> void:
	var cases := [
		{"elapsed": 0.0, "phase": "unseal"},
		{"elapsed": 0.599, "phase": "unseal"},
		{"elapsed": 0.60, "phase": "divination"},
		{"elapsed": 2.249, "phase": "divination"},
		{"elapsed": 2.25, "phase": "settle"},
		{"elapsed": 2.699, "phase": "settle"},
		{"elapsed": 2.70, "phase": "reveal"},
		{"elapsed": 2.999, "phase": "reveal"},
		{"elapsed": 3.0, "phase": "wait_confirm"},
	]
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		host.sync_state(
			_modal_snapshot(float(case.get("elapsed", 0.0))),
			Vector2(380.0, 690.0),
			_layout()
		)
		_expect(
			host.get_phase_name() == str(case.get("phase", "")),
			"Angel modal elapsed %.3f should project phase %s" % [
				float(case.get("elapsed", 0.0)),
				str(case.get("phase", "")),
			]
		)


func _verify_hwangyeokjeon_omen_reading(host: Node2D) -> void:
	var pipeline: Dictionary = AngelBlessingRollOverlayHost.build_pipeline_status()
	_expect(bool(pipeline.get("omen_identity_ready", false)), "천운삼괘 should load the rebranded divination seal identity")

	# 새 8프레임 괘문 시트는 점괘를 읽는 동안 순환하고, 결과 공개 뒤에는 마지막
	# 인장 프레임에 안착한다. 날개 시트나 주사위 텀블이 다시 들어오지 못하게 봉인한다.
	var frame_a := int(host._omen_sheet_frame(0.80))
	var frame_b := int(host._omen_sheet_frame(1.20))
	var frame_settled := int(host._omen_sheet_frame(3.20))
	_expect(frame_a >= 0 and frame_a < 8 and frame_b >= 0 and frame_b < 8, "omen sheet frame must stay within the 8-frame seal sheet")
	_expect(frame_a != frame_b, "omen seal should animate while the three omens are being read")
	_expect(frame_settled == 7, "omen seal should settle on its final frame after the result reveal")

	# 세 괘패는 점괘를 읽는 동안 중심을 공전하다 settle에서 안쪽으로 모인다.
	var orbiting := host._omen_token_position(1.20, 0) as Vector2
	var settled := host._omen_token_position(2.60, 0) as Vector2
	_expect(orbiting.distance_to(Vector2(380.0, 302.0)) > 100.0, "omen token should orbit clearly outside the center seal during divination")
	_expect(settled.distance_to(Vector2(380.0, 302.0)) < orbiting.distance_to(Vector2(380.0, 302.0)), "omen token should gather inward during settle")


func _verify_omen_modular_layers(host: Node2D) -> void:
	var pipeline: Dictionary = AngelBlessingRollOverlayHost.build_pipeline_status()
	_expect(bool(pipeline.get("omen_aura_ready", false)), "천운삼괘 should prewarm the ritual aura texture layer")
	_expect(int(pipeline.get("gpu_particle_layer_count", 0)) >= 3, "천운삼괘 should expose the dedicated omen burst particle layer")

	# rolling 진입: 서지 프리셋 + 호 가시화 + 버스트 원샷.
	host.sync_state(_modal_snapshot(0.30), Vector2(380.0, 690.0), _layout())
	host.sync_state(_modal_snapshot(0.80), Vector2(380.0, 690.0), _layout())
	var rolling_status: Dictionary = host.get_debug_status()
	_expect(bool(rolling_status.get("omen_aura_visible", false)), "ritual aura should be visible while the omens are being read")
	_expect(bool(rolling_status.get("omen_aura_above_bridge", false)), "ritual aura must sit above the draw bridge so the opaque panel cannot bury it")
	_expect(bool(rolling_status.get("omen_burst_emitting", false)), "entering divination should fire the omen burst particles")
	_expect(str(rolling_status.get("style_family", "")) == "hwangyeokjeon_divination", "live host status should identify the 환격전 divination style")
	var rolling_rotation := float(rolling_status.get("omen_aura_rotation", 0.0))

	# 텀블 리듬: rolling 중 회전이 계속 진행되어야 한다(엔진측 모션).
	host.sync_state(_modal_snapshot(1.60), Vector2(380.0, 690.0), _layout())
	var later_status: Dictionary = host.get_debug_status()
	_expect(
		absf(float(later_status.get("omen_aura_rotation", 0.0)) - rolling_rotation) > 0.15,
		"ritual aura rotation should advance while the three omens are being read"
	)

	# 호 크기 회귀 가드: TextureRect는 texture 지정으로 min_size가 원본(768)이 되면
	# 이후 size 축소가 되돌려져 네이티브로 렌더되는 함정이 있다(라이브 픽셀 QA에서
	# 발견). Sprite2D + 명시 scale이라 실측 span이 DICE_ARC_SIZE 근처여야 한다.
	# settle_pop(최대 1.12배)까지 감안해 상한을 잡고, 네이티브 768 폭은 반드시 배제.
	var aura_span := float(rolling_status.get("omen_aura_span_px", 0.0))
	_expect(aura_span > 0.0, "omen aura should report a measurable on-screen span")
	_expect(aura_span <= 360.0, "omen aura must stay inside the intended ritual seal area")
	_expect(aura_span >= 220.0, "omen aura should remain large enough to frame the central divination seal")

	# 엔벨로프 연속성 회귀 가드(적대 리뷰에서 발견): settle(끝값 0.66) -> wait_confirm
	# 호흡 밴드가 2.70 경계에서 C0 연속이어야 한다. 불연속이면 ADD 호+백플레이트가
	# 한 프레임 침침해지는 팝으로 읽힌다. 경계 좌우극한 차이를 직접 잰다.
	var env_before := float(host._omen_envelope(2.6999))
	var env_after := float(host._omen_envelope(2.70))
	_expect(
		absf(env_before - env_after) < 0.01,
		"omen envelope must be continuous across the settle->reveal boundary (2.70s), got %.4f -> %.4f" % [env_before, env_after]
	)

	# wait_confirm: 서지 해제 + calm 프리셋 복귀, 호는 숨쉬며 유지.
	host.sync_state(_modal_snapshot(3.2), Vector2(380.0, 690.0), _layout())
	var calm_status: Dictionary = host.get_debug_status()
	_expect(bool(calm_status.get("omen_aura_visible", false)), "ritual aura should keep breathing through wait_confirm")


func _verify_absorption_projection(host: Node2D) -> void:
	var trajectories: Array[Dictionary] = []
	for index: int in range(3):
		trajectories.append({
			"index": index,
			"buff_id": ["paddle_size", "gauge_max", "move_speed"][index],
			"delay": float(index) * 0.25,
			"travel_duration": 1.8,
			"arrival_time": 1.8 + float(index) * 0.25,
		})
	host.sync_state({
		"modal_active": false,
		"absorption": {
			"active": true,
			"elapsed": 0.55,
			"glow_duration": 0.35,
			"trajectories": trajectories,
		},
	}, Vector2(410.0, 690.0), _layout())
	var status: Dictionary = host.get_debug_status()
	_expect(bool(status.get("active", false)), "post-confirm absorption should keep the detached host visible")
	_expect(str(status.get("phase", "")) == "absorb", "post-confirm visual work should project the absorb phase")
	_expect(not bool(status.get("ambient_emitting", true)), "modal ambient particles should stop once only absorption remains")
	_expect(bool(status.get("absorb_emitting", false)), "absorption should start its one-shot particle layer")
	_expect(host.position == GAME_OFFSET, "Angel overlay host should follow the game-canvas offset")
	_expect(host.scale == Vector2.ONE, "Angel overlay host should follow the game-canvas render scale")


func _verify_letterbox_clip_when_available(viewport: SubViewport, host: Node2D) -> void:
	if OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0:
		return
	host.sync_state(_modal_snapshot(1.25), Vector2(380.0, 690.0), _layout())
	for _frame: int in range(5):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "windowed Angel overlay QA should capture a viewport image")
	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_expect(image.get_pixel(480, 400).a > 0.10, "Angel modal should render opaque content inside the game canvas")
	for point: Vector2i in [Vector2i(24, 400), Vector2i(936, 400), Vector2i(480, 8), Vector2i(480, 792)]:
		_expect(
			image.get_pixelv(point).a <= 0.02,
			"Angel overlay must not leak opaque pixels into letterbox sample %s" % point
		)


func _verify_explicit_and_static_cleanup(parent: Node, host: Node2D) -> void:
	host.set_active(false)
	var status: Dictionary = host.get_debug_status()
	_expect(not bool(status.get("active", true)), "set_active(false) should hide the Angel host immediately")
	_expect(not bool(status.get("ambient_emitting", true)), "set_active(false) should stop Angel ambient particles")
	_expect(not bool(status.get("absorb_emitting", true)), "set_active(false) should stop Angel absorb particles")

	var second_host: Node2D = AngelBlessingRollOverlayHost.new()
	parent.add_child(second_host)
	host.sync_state(_modal_snapshot(1.0), Vector2(380.0, 690.0), _layout())
	second_host.sync_state(_modal_snapshot(1.0), Vector2(380.0, 690.0), _layout())
	_expect(bool(host.get_debug_status().get("active", false)), "first registered Angel host should reactivate for static cleanup coverage")
	_expect(bool(second_host.get_debug_status().get("active", false)), "second registered Angel host should activate for static cleanup coverage")
	AngelBlessingRollOverlayHost.hide_all_existing_hosts()
	_expect(not bool(host.get_debug_status().get("active", true)), "static Angel cleanup should hide the first registered host")
	_expect(not bool(second_host.get_debug_status().get("active", true)), "static Angel cleanup should hide every registered host")
	second_host.queue_free()


func _modal_snapshot(elapsed: float) -> Dictionary:
	return {
		"modal_active": true,
		"modal_elapsed": elapsed,
		"active_modal": {
			"roll_result": {
				"rolled": true,
				"active_stage": 3,
				"roll_face": 3,
				"active_buff_ids": ["paddle_size", "gauge_max", "move_speed"],
			},
		},
		"absorption": {"active": false},
	}


func _layout() -> Dictionary:
	return {
		"game_offset": GAME_OFFSET,
		"render_scale": 1.0,
		"game_size": GAME_SIZE,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("angel_blessing_overlay_host_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
