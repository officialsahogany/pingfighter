extends SceneTree

const Stage7AkamuPlayfieldRenderer := preload("res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd")
const Stage7AkamuBossActorRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd")
const Stage7AkamuBossSkillHudRenderer := preload("res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd")
const Stage7AkamuVfxTextureCache := preload("res://scripts/stages/stage7/stage7_akamu_vfx_texture_cache.gd")

const VIEW_SIZE := Vector2i(760, 750)

var _failures: Array[String] = []


class Slice5DrawProbe:
	extends Node2D

	var playfield_renderer: Object = null
	var boss_renderer: Object = null
	var context: Dictionary = {}
	var draw_count := 0
	var underlay_count := 0
	var actor_count := 0
	var overlay_count := 0

	func _draw() -> void:
		draw_count += 1
		playfield_renderer.draw_underlay(self, context, Vector2.ZERO)
		underlay_count += 1
		boss_renderer.draw(self, context, Vector2.ZERO)
		actor_count += 1
		playfield_renderer.draw_overlay(self, context, Vector2.ZERO)
		overlay_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_source_contracts()
	_verify_hud_copy()
	_verify_vfx_texture_bake_steps()

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var probe := Slice5DrawProbe.new()
	probe.playfield_renderer = Stage7AkamuPlayfieldRenderer.new()
	probe.boss_renderer = Stage7AkamuBossActorRenderer.new()
	probe.context = _slice5_context()
	viewport.add_child(probe)

	# 레그 1: 프리웜 전 벡터 폴백 (correctness-identical fallback 계약).
	Stage7AkamuVfxTextureCache.debug_clear()
	probe.queue_redraw()
	for _frame in range(4):
		await process_frame
	_expect(probe.draw_count > 0, "Slice 5 visual payloads should execute in a real CanvasItem draw pass")
	_expect(probe.underlay_count == probe.draw_count, "superspeed trails, ghosts, and dark particles should complete the underlay pass")
	_expect(probe.actor_count == probe.draw_count, "wind-aura durability should complete the boss actor pass")
	_expect(probe.overlay_count == probe.draw_count, "wind aura, burst, and superspeed timer should complete the overlay pass")
	_verify_pixels_when_available(viewport, "vector-fallback")

	# 레그 2: bake-once 텍스처 블릿 경로 — 같은 픽셀 앵커가 그대로 살아야 한다.
	Stage7AkamuVfxTextureCache.prewarm()
	probe.queue_redraw()
	for _frame in range(4):
		await process_frame
	_expect(probe.underlay_count == probe.draw_count, "baked-path underlay pass should complete without draw errors")
	_expect(probe.overlay_count == probe.draw_count, "baked-path overlay pass should complete without draw errors")
	_verify_pixels_when_available(viewport, "baked")

	viewport.queue_free()
	if _failures.is_empty():
		print("stage7_akamu_slice5_visual_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _slice5_context() -> Dictionary:
	return {
		"current_stage": 7,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_hitbox_height": 40.0,
		"boss_paddle_shrink_scale": 0.45,
		"stage7_akamu_awakened": true,
		"stage7_akamu_superspeed_active": true,
		"stage7_akamu_superspeed_remaining": 8.4,
		"stage7_akamu_superspeed_duration": 10.0,
		"stage7_akamu_superspeed_text_remaining": 1.0,
		"stage7_akamu_superspeed_dash_direction": 1,
		"stage7_akamu_superspeed_trails": [
			{"center": Vector2(310.0, 90.0), "size": Vector2(100.0, 40.0), "visual_scale": 0.45, "alpha": 0.45, "kind": "superspeed_trail"},
		],
		"stage7_akamu_superspeed_afterimages": [
			{"center": Vector2(340.0, 90.0), "size": Vector2(100.0, 40.0), "visual_scale": 0.45, "alpha": 0.55, "delay_remaining_sec": 0.0, "kind": "superspeed_ghost"},
		],
		"stage7_akamu_superspeed_dark_particles": [
			{"pos": Vector2(380.0, 90.0), "radius": 7.0, "life_frames": 30.0, "max_life_frames": 60.0, "color": Color(0.12, 0.03, 0.14, 1.0)},
		],
		"stage7_akamu_wind_burst_particles": [
			{"pos": Vector2(460.0, 210.0), "size": 8.0, "rotation": 0.4, "alpha": 0.8, "color": Color(0.45, 0.90, 1.0, 1.0)},
		],
		"stage7_akamu_wind_aura": {
			"active": true,
			"center": Vector2(380.0, 90.0),
			"radius": 90.0,
			# 0.9: 궤도 파티클 visible_count = int(n*strength)가 1 이상이 되어
			# 꼬리/코어/림 블릿 경로가 실제 실행되도록 (0.2였을 땐 0개).
			"strength": 0.9,
			"hit_count": 4,
			"max_hits": 5,
			"remaining_hits": 1,
			"depleted": false,
			"recharge_remaining": 0.0,
			"recharge_total": 10.0,
			"ripple_intensity": 0.8,
			"superspeed": true,
			"elapsed_sec": 0.5,
			"particles": [
				{"angle": 0.2, "radius": 68.0, "size": 6.0, "color": Color(0.50, 0.92, 1.0, 0.8)},
				{"angle": 2.4, "radius": 62.0, "size": 4.0, "color": Color(0.59, 1.0, 0.78, 0.7)},
			],
		},
		"stage7_akamu_afterimages": [],
		"stage7_akamu_clones": [],
		"stage7_akamu_shurikens": [],
		"stage7_akamu_particles": [],
		"stage7_akamu_aura": {},
		"stage7_akamu_cloud": {},
		"stage7_akamu_hologram": {},
	}


func _verify_source_contracts() -> void:
	var playfield_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage7/stage7_akamu_playfield_renderer.gd"
	)
	var underlay_source := _source_section(playfield_source, "func draw_underlay(", "func draw_overlay(")
	var overlay_source := _source_section(playfield_source, "func draw_overlay(", "func get_asset_status(")
	var dark_particle_source := _source_section(
		playfield_source,
		"func _draw_superspeed_dark_particle(",
		"func _draw_superspeed_dark_flame_vector("
	)
	var dark_flame_vector_source := _source_section(
		playfield_source,
		"func _draw_superspeed_dark_flame_vector(",
		"func _draw_afterimage("
	)
	_expect(underlay_source.find("stage7_akamu_superspeed_trails") >= 0, "underlay should consume superspeed movement trails")
	_expect(underlay_source.find("stage7_akamu_superspeed_afterimages") >= 0, "underlay should consume superspeed ghosts")
	_expect(underlay_source.find("stage7_akamu_superspeed_dark_particles") >= 0, "underlay should consume superspeed dark particles")
	_expect(underlay_source.find("_draw_superspeed_dash_wake") >= 0, "underlay should consume the predictive dash direction")
	_expect(overlay_source.find("stage7_akamu_cloud") < overlay_source.find("stage7_akamu_wind_aura"), "foreground cloud should draw before the persistent wind aura")
	_expect(overlay_source.find("stage7_akamu_wind_burst_particles") >= 0, "overlay should consume awakening and depletion bursts")
	_expect(overlay_source.find("_draw_slice5_cinematic_overlay") >= 0, "overlay should render awakening and superspeed text inside the 760x750 field")
	# 2026-07-11 프레임드랍 수정(의식적 예산 갱신): 어두운 불꽃(글로우 2겹+
	# 코어)은 bake-once 텍스처 1블릿으로 합성하고 스파크는 공용 _fill_circle
	# 블릿을 쓴다 — max 200개 핫패스에 직접 AA 서클/아크 금지. 원본 3서클
	# 프로파일은 프리웜 전 전용 벡터 폴백(_draw_superspeed_dark_flame_vector)
	# 에만 산다.
	_expect(
		dark_particle_source.find("KEY_DARK_FLAME") >= 0,
		"dark particle hot path should blit the baked composite flame texture"
	)
	_expect(
		dark_particle_source.count("canvas.draw_circle") == 0,
		"dark particle hot path must not issue direct AA circles (max-200 budget)"
	)
	_expect(
		dark_particle_source.find("_fill_circle(") >= 0,
		"dark particle deterministic spark should route through the shared disc blit helper"
	)
	_expect(dark_particle_source.find("canvas.draw_arc") < 0, "max-200 dark particles should not add per-particle glow arcs")
	_expect(
		dark_flame_vector_source.count("canvas.draw_circle") == 2,
		"vector fallback should keep the legacy glow-loop + core circle profile (prewarm-only)"
	)

	var actor_source := FileAccess.get_file_as_string(
		"res://scripts/stages/stage7/stage7_akamu_boss_actor_renderer.gd"
	)
	var actor_draw_source := _source_section(actor_source, "func draw(", "func get_asset_status(")
	_expect(actor_draw_source.find("stage7_akamu_wind_aura") >= 0, "boss ring should be driven by the wind-aura payload")
	_expect(actor_draw_source.find("wind_aura_active and not wind_aura_depleted") >= 0, "depleted wind aura should suppress the always-on awakened ring")
	# 2026-07-11 원본 파리티: 내구 피드백은 점 카운터가 아니라 오라 자체의
	# strength 약화다. 점 5개 + 재충전 바 오버레이는 제거됐고 재등장하면 안
	# 된다. 소진 중 재충전 진행은 playfield 오라(회색 링 + 진행 아크)가 담당.
	_expect(
		actor_source.find("_draw_wind_aura_durability") < 0,
		"legacy-absent durability pips must not return to the boss actor overlay"
	)
	var playfield_aura_source := _source_section(playfield_source, "func _draw_wind_aura(", "func _draw_wind_burst_particle(")
	_expect(
		playfield_aura_source.find("recharge_remaining") >= 0,
		"depleted wind aura recharge feedback should live on the playfield aura ring"
	)
	_verify_legacy_parity_visual_contract(playfield_source, underlay_source)


func _verify_legacy_parity_visual_contract(playfield_source: String, underlay_source: String) -> void:
	# 2026-07-11 원본 파리티 + Godot 강화 계약. 각 항목은 원본
	# draw_stage8_* 대응 요소가 플레이스홀더로 회귀하지 않도록 봉인한다.
	var aura_source := _source_section(playfield_source, "func _draw_wind_aura(", "func _draw_wind_burst_particle(")
	_expect(
		aura_source.find("draw_polyline_colors") >= 0,
		"wind aura should render the rotating stream curves with per-point alpha gradients"
	)
	_expect(
		aura_source.find("tail_count") >= 0 and aura_source.find("orbit_speed") >= 0,
		"wind aura orbit particles should keep their legacy trailing tails"
	)
	_expect(
		aura_source.find("ripple > 0.1") >= 0,
		"wind aura should keep the legacy white shockwave ring on ripple hits"
	)
	# 2026-07-11 프레임드랍 수정: 각성 후 상시 오라(파티클 24개 기준 ~134
	# AA 드로/프레임)가 실측 주범이라 글로우 스택은 1블릿, 파티클/링은
	# 텍스처 블릿 헬퍼로 강등. 핫 바디의 직접 draw_arc는 소진(depleted)
	# 분기 2개(회색 링 + 부분 진행 아크 — 부분 아크는 블릿 불가)만 허용.
	var aura_hot_source := _source_section(
		playfield_source,
		"func _draw_wind_aura(",
		"func _draw_wind_aura_glow_stack_vector("
	)
	_expect(
		aura_hot_source.find("KEY_AURA_GLOW_STACK") >= 0,
		"wind aura glow stack should blit the baked six-ring texture in one call"
	)
	_expect(
		aura_hot_source.count("canvas.draw_circle") == 0,
		"wind aura hot body should route particle fills through the shared disc blit helper"
	)
	_expect(
		aura_hot_source.count("canvas.draw_arc") == 2,
		"wind aura direct arcs must stay confined to the two depleted-branch rings"
	)
	_expect(
		aura_hot_source.find("_fill_circle(") >= 0 and aura_hot_source.find("_particle_rim(") >= 0,
		"aura orbit particles should blit discs plus the white rim texture"
	)
	_expect(
		Stage7AkamuPlayfieldRenderer.WIND_AURA_GLOW_CYAN.is_equal_approx(
			Color(100.0 / 255.0, 220.0 / 255.0, 1.0)
		),
		"wind aura glow should keep the legacy cyan (100,220,255) palette"
	)
	var burst_source := _source_section(playfield_source, "func _draw_wind_burst_particle(", "func _draw_slice5_cinematic_overlay(")
	_expect(
		burst_source.find("draw_colored_polygon") >= 0,
		"awakening burst particles should render the legacy rotating diamond polygons"
	)
	var overlay_cinematic_source := _source_section(playfield_source, "func _draw_slice5_cinematic_overlay(", "func _draw_centered_text(")
	_expect(
		Stage7AkamuPlayfieldRenderer.SUPERSPEED_TITLE_COLOR.is_equal_approx(
			Color(1.0, 230.0 / 255.0, 80.0 / 255.0)
		)
			and overlay_cinematic_source.find("SUPERSPEED_TITLE_COLOR") >= 0,
		"superspeed title should keep the legacy yellow (255,230,80) palette"
	)
	_expect(
		overlay_cinematic_source.find("120.0 / 255.0") >= 0,
		"superspeed activation freeze should keep the legacy black-120 blackout"
	)
	_expect(
		overlay_cinematic_source.find("FIELD_SIZE.x - bar_size.x") >= 0,
		"superspeed timer bar should sit at the legacy top-right anchor"
	)
	_expect(
		underlay_source.find("_ghost_frame_spec = _resolve_clone_frame_spec(context)") >= 0
			and playfield_source.find("func _draw_boss_frame_ghost(") >= 0,
		"boss-frame ghosts (trail/afterimage/escape/hologram) should resolve the sprite spec once per frame"
	)


func _verify_hud_copy() -> void:
	var tooltip_info: Dictionary = Stage7AkamuBossSkillHudRenderer.TOOLTIP_INFO
	var superspeed: Dictionary = tooltip_info.get("stage7_superspeed", {})
	_expect(str(superspeed.get("name", "")) == "극정호신", "superspeed tooltip should use readable Korean")
	_expect(str(superspeed.get("cooldown", "")).find("25초") >= 0, "superspeed tooltip should publish the implemented 25-second cooldown")
	_expect(str(superspeed.get("description", "")).find("10초") >= 0, "superspeed tooltip should publish the implemented 10-second duration")
	_expect(str(Stage7AkamuBossSkillHudRenderer.DISPLAY_NAMES.get("stage7_cloud", "")) == "구름장막", "Stage 7 cards should override legacy mojibake names")


func _verify_vfx_texture_bake_steps() -> void:
	# bake-once 캐시 계약: 스텝당 1장, 유한 스텝 안에 전 키 준비.
	Stage7AkamuVfxTextureCache.debug_clear()
	_expect(not Stage7AkamuVfxTextureCache.is_ready(), "cleared VFX texture cache should report not ready")
	var steps := 0
	while not Stage7AkamuVfxTextureCache.prewarm_step():
		steps += 1
		if steps > 16:
			break
	_expect(Stage7AkamuVfxTextureCache.is_ready(), "VFX texture prewarm should finish within bounded steps")
	for key_value in Stage7AkamuVfxTextureCache.BAKE_KEYS:
		_expect(
			Stage7AkamuVfxTextureCache.get_texture(str(key_value)) != null,
			"baked VFX texture missing: %s" % str(key_value)
		)


func _verify_pixels_when_available(viewport: SubViewport, leg: String) -> void:
	if OS.get_cmdline_args().has("--headless") or DisplayServer.get_name().to_lower().find("headless") >= 0:
		return
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "windowed Slice 5 QA should capture the viewport (%s)" % leg)
	if image == null or image.is_empty():
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_expect(
		image.get_pixel(380, 90).a > 0.10,
		"%s: superspeed boss and dark-particle stack should render near the boss" % leg
	)
	# 2026-07-11 파리티: 타이머 바는 원본 우상단 앵커(760-220-16, 16)로 이동.
	_expect(
		image.get_pixel(630, 23).a > 0.10,
		"%s: superspeed timer bar should render at the legacy top-right anchor" % leg
	)
	_expect(
		image.get_pixel(460, 210).a > 0.05,
		"%s: wind burst particles should render in the foreground pass" % leg
	)
	# 리플 충격파 링(반경 90*1.4=126, 오라 중심 380,90) — 폴백 아크와 baked
	# 씬링 블릿 양쪽 모두 같은 앵커에 살아야 한다.
	_expect(
		image.get_pixel(506, 90).a > 0.10,
		"%s: wind aura ripple shockwave ring should render at its legacy radius" % leg
	)


func _source_section(source: String, start_marker: String, end_marker: String) -> String:
	var start_index: int = source.find(start_marker)
	if start_index < 0:
		return ""
	var end_index: int = source.find(end_marker, start_index + start_marker.length())
	if end_index < 0:
		return source.substr(start_index)
	return source.substr(start_index, end_index - start_index)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
