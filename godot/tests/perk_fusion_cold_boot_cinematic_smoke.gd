extends SceneTree
# expect-zero-object-leaks

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const PerkFusionColdBootCinematic := preload("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")
const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")
const PerkFusionColdBootParticleFactory := preload("res://scripts/hud/perk_fusion_cold_boot_particle_factory.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")

var _failures: Array[String] = []

var _overlay_draw_ran := false
var _overlay_renderer: Object
var _overlay_state: Object
var _overlay_catalog: Object


class RegistryStub:
	extends RefCounted

	var state: Object
	var catalog: Object
	var audio: Object = null

	func _init(state_value: Object, catalog_value: Object) -> void:
		state = state_value
		catalog = catalog_value

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return state
			"runtime_perk_catalog":
				return catalog
			"game_audio":
				return audio
		return null


class FakeColdBootAudio:
	extends RefCounted

	var calls: Array = []

	func play_cold_boot_chnk_latch() -> void:
		calls.append("chnk")

	func play_cold_boot_post_ramp() -> void:
		calls.append("ramp")

	func play_cold_boot_ignition_thunk() -> void:
		calls.append("thunk")

	func play_cold_boot_awaken_fanfare() -> void:
		calls.append("fanfare")


class ModuleGetterStub:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(name: String) -> Object:
		return modules.get(name, null)


class PerfLabelProbe:
	extends RefCounted

	var labels: Array = []

	func begin_sample() -> int:
		return 0

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	# 코덱스 CB4bv2-P1: SceneTree._init() 시점엔 root.add_child 직후에도
	# 노드 is_inside_tree()가 false라 get_viewport_rect() 계열이 엔진
	# ERROR를 뿜고, 표준 러너(run_smoke_tests.ps1)의 serious-error 게이트가
	# exit 0이어도 실패로 승격한다 — 실제 검증은 트리 진입 후(_run)만.
	call_deferred("_run")


func _run() -> void:
	_verify_prewarm_rides_overlay_prewarm_path()
	_verify_asset_manifest_prewarms_textures()
	_verify_altar_backplate_asset_contract()
	await _verify_altar_backplate_draw_branches()
	_verify_cartridge_plate_measurement_contract()
	_verify_ignition_sheet_cell_content_seal()
	_verify_committed_icon_prepare_on_boot_entry()
	_verify_spark_particle_contract()
	_verify_ignition_haze_contract()
	_verify_transition_audio_contract()
	_verify_real_game_audio_cold_boot_wiring()
	_verify_real_process_idle_drives_host_lifecycle()
	_verify_pulse_decays_before_new_events()
	_verify_reset_closes_host()
	_verify_same_frame_skip_finish_closes_host_without_idle()
	await _verify_degraded_fallback_draws_without_host()
	_verify_lazy_init_and_fallback_source_contracts()
	# Every fixture above releases tree-owned hosts with queue_free(), and the
	# real-audio leg frees its owner while the final one-shot is playing. Drain
	# both the SceneTree deletion queue and one audio mix window before quit();
	# otherwise fast headless exits can race AudioStreamPlayback retirement and
	# nondeterministically report an ObjectDB leak after all assertions pass.
	await process_frame
	await process_frame
	OS.delay_msec(250)
	await process_frame
	await process_frame

	if _failures.is_empty():
		print("perk_fusion_cold_boot_cinematic_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _build_animation_state(outcome_roll: float = 0.0) -> Dictionary:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {
		"item_luck": 5,
		"common_bulk_up": 5,
		"common_swiftness": 5,
		"dash_lightweight": 5,
	}
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [{
		"id": "perk_fusion",
		"name": "퍽 융합",
		"is_perk_fusion": true,
		"eligible_sources": ["item_luck", "common_bulk_up"],
		"offer_lane": "fusion",
		"offer_protected": true,
	}]
	state.selected_index = 0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	state._perk_fusion_modal_flow.confirm_current()
	var commit_result: Dictionary = state._confirm_perk_fusion_modal(null, registry, {
		"outcome": outcome_roll,
		"magnitude": [0.0, 0.0],
		"lane_selection": [0.0],
		"delete": 1.0,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0],
	})
	_expect(bool(commit_result.get("accepted", false)), "cinematic fixture should commit through the real modal path")
	var getter := ModuleGetterStub.new()
	# 실 모달 게이트 컨트롤러를 관통해야 idle 판별이 라이브와 같다.
	getter.modules = {
		"runtime_perk_state": state,
		"battle_scene_modal_gate_controller": BattleSceneModalGateController.new(),
	}
	return {"state": state, "catalog": catalog, "registry": registry, "getter": getter}


func _verify_prewarm_rides_overlay_prewarm_path() -> void:
	RuntimePerkOverlayRenderer.new().prewarm_assets()
	_expect(PerkFusionColdBootCinematic.is_prewarmed(), "the overlay prewarm path should statically prewarm the cold-boot host assets")


# CB4b/§10.1: 에셋 매니페스트 프리움 씰 — repo에 랜딩된 텍스처가
# 이산 시점 프리움으로 캐시에 올라야 하고(부재시 절차 폴백은 degraded
# 계약), 아틀라스 그리드 권위 상수(4x4=16)도 봉인한다.
func _verify_asset_manifest_prewarms_textures() -> void:
	PerkFusionColdBootCinematic.prewarm_assets()
	for texture_key: String in [
		"chassis_off",
		"chassis_on",
		"cartridge_left",
		"cartridge_right",
		"module_shoulder_pod",
		"module_collar_ring",
		"module_gem_plate",
		"ignition_sheet",
		"spark_shard",
		"altar_backplate",
	]:
		_expect(PerkFusionColdBootCinematic._texture(texture_key) != null, "prewarm should cache the %s texture from the landed manifest" % texture_key)
	_expect(
		PerkFusionColdBootCinematic.IGNITION_SHEET_COLS == 4
			and PerkFusionColdBootCinematic.IGNITION_SHEET_ROWS == 4
			and PerkFusionColdBootCinematic.IGNITION_SHEET_FRAMES == 16,
		"the AutoSprite ignition sheet must declare its 4x4=16 atlas grid authority"
	)


# §10.1 원판 소스/알파 씰: 1024 마젠타 후처리본의 투명 여백과 런타임
# 520px·2단 알파 계약을 함께 봉인한다.
func _verify_altar_backplate_asset_contract() -> void:
	var altar_image := Image.load_from_file(
		ProjectSettings.globalize_path(PerkFusionColdBootCinematic.ALTAR_BACKPLATE_TEXTURE_PATH)
	)
	_expect(altar_image != null and not altar_image.is_empty(), "the premium altar backplate source must load")
	if altar_image == null or altar_image.is_empty():
		return
	_expect(altar_image.get_size() == Vector2i(1024, 1024), "the altar backplate must keep its accepted 1024px source geometry")
	for corner: Vector2i in [Vector2i.ZERO, Vector2i(1023, 0), Vector2i(0, 1023), Vector2i(1023, 1023)]:
		_expect(altar_image.get_pixelv(corner).a == 0.0, "the altar backplate corner %s must remain transparent" % str(corner))
	var used_rect := altar_image.get_used_rect()
	_expect(
		used_rect.position.x >= 2
			and used_rect.position.y >= 2
			and used_rect.end.x <= altar_image.get_width() - 2
			and used_rect.end.y <= altar_image.get_height() - 2,
		"the altar backplate alpha bounds must not touch the source edge (%s)" % str(used_rect)
	)
	_expect(
		is_equal_approx(PerkFusionColdBootCinematic.ALTAR_BACKPLATE_DRAW_SPAN, 520.0),
		"the altar backplate runtime span must stay at the approved 520px"
	)
	_expect(
		is_equal_approx(
			PerkFusionColdBootCinematic._altar_backplate_alpha_for_beat(PerkFusionColdBootTimelineState.BEAT_DOCK_IN),
			0.22
		)
			and is_equal_approx(
				PerkFusionColdBootCinematic._altar_backplate_alpha_for_beat(PerkFusionColdBootTimelineState.BEAT_TWIST_LOCK),
				0.22
			)
			and is_equal_approx(
				PerkFusionColdBootCinematic._altar_backplate_alpha_for_beat(PerkFusionColdBootTimelineState.BEAT_BOOT_POST),
				0.32
			)
			and is_equal_approx(
				PerkFusionColdBootCinematic._altar_backplate_alpha_for_beat(PerkFusionColdBootTimelineState.BEAT_IGNITION_CREST),
				0.32
			),
		"the altar backplate must use only the approved unlit/lit alpha steps"
	)


# 텍스처 유/무 양쪽을 실제 CanvasItem 드로로 관통한다. 두 분기가 모두
# draw flush를 무크래시로 통과해야 한다. 픽셀 실렌더는
# 비헤드리스 캡처 하니스가 소유한다(RenderingServer.frame_post_draw는 headless
# 러너에서 발화하지 않아 여기서 기다리면 교착한다).
func _verify_altar_backplate_draw_branches() -> void:
	var cached_texture: Texture2D = PerkFusionColdBootCinematic._texture("altar_backplate")
	await _draw_altar_backplate_branch()
	PerkFusionColdBootCinematic._textures.erase("altar_backplate")
	await _draw_altar_backplate_branch()
	if cached_texture != null:
		PerkFusionColdBootCinematic._textures["altar_backplate"] = cached_texture
	_expect(cached_texture != null, "the textured altar branch must start from a prewarmed production texture")


func _draw_altar_backplate_branch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(760, 750)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host: Node2D = PerkFusionColdBootCinematic.new()
	viewport.add_child(host)
	await process_frame
	host.sync_boot({
		"beat": PerkFusionColdBootTimelineState.BEAT_DOCK_IN,
		"beat_progress": 0.25,
		"presentation": {},
	}, [], 0.0)
	for _settle: int in range(3):
		await process_frame
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame


# 주물 의식 무공패 실측 씰: 최종 좌/우 에셋의 크기와 암판 안전영역을
# 함께 봉인한다. 아트가 다시 바뀌면 이 레그가 RED가 되어 frac을 재실측해야
# 하며, 32px 재료 아이콘은 96px 드로 높이에서 암판 밖으로 넘지 않아야 한다.
func _verify_cartridge_plate_measurement_contract() -> void:
	var left_image := Image.load_from_file(
		ProjectSettings.globalize_path(PerkFusionColdBootCinematic.CARTRIDGE_LEFT_TEXTURE_PATH)
	)
	var right_image := Image.load_from_file(
		ProjectSettings.globalize_path(PerkFusionColdBootCinematic.CARTRIDGE_RIGHT_TEXTURE_PATH)
	)
	_expect(left_image != null and not left_image.is_empty(), "the left mugong tablet source must load")
	_expect(right_image != null and not right_image.is_empty(), "the right mugong tablet source must load")
	if left_image == null or left_image.is_empty() or right_image == null or right_image.is_empty():
		return
	_expect(
		left_image.get_size() == Vector2i(742, 1024)
			and right_image.get_size() == left_image.get_size(),
		"the measured mugong-tablet pair must stay at the accepted mirrored 742x1024 source geometry"
	)
	_expect(
		is_equal_approx(PerkFusionColdBootCinematic.CARTRIDGE_PLATE_CENTER_X_FRAC, 0.500)
			and is_equal_approx(PerkFusionColdBootCinematic.CARTRIDGE_PLATE_CENTER_Y_FRAC, 0.587),
		"the runtime face center must match the accepted mugong-tablet plate measurement"
	)
	var draw_size := Vector2(
		PerkFusionColdBootCinematic.CARTRIDGE_DRAW_HEIGHT
			* float(left_image.get_width()) / float(left_image.get_height()),
		PerkFusionColdBootCinematic.CARTRIDGE_DRAW_HEIGHT
	)
	var measured_plate_safe_rect := Rect2(
		Vector2(draw_size.x * 0.247, draw_size.y * 0.323),
		Vector2(draw_size.x * 0.506, draw_size.y * 0.503)
	)
	var left_center := Vector2(
		draw_size.x * PerkFusionColdBootCinematic.CARTRIDGE_PLATE_CENTER_X_FRAC,
		draw_size.y * PerkFusionColdBootCinematic.CARTRIDGE_PLATE_CENTER_Y_FRAC
	)
	var icon_size := Vector2.ONE * PerkFusionColdBootCinematic.CARTRIDGE_PLATE_ICON_SPAN
	var left_icon_rect := Rect2(left_center - icon_size * 0.5, icon_size)
	var right_center := Vector2(
		draw_size.x * (1.0 - PerkFusionColdBootCinematic.CARTRIDGE_PLATE_CENTER_X_FRAC),
		left_center.y
	)
	var right_icon_rect := Rect2(right_center - icon_size * 0.5, icon_size)
	_expect(
		measured_plate_safe_rect.encloses(left_icon_rect)
			and measured_plate_safe_rect.encloses(right_icon_rect),
		"the 32px material icons must stay inside the measured mugong-tablet face plate (%s / %s in %s)"
			% [str(left_icon_rect), str(right_icon_rect), str(measured_plate_safe_rect)]
	)


# CB4b v2 [P2]: 이그니션 시트 실내용 봉인 — 상수(4x4=16)만이 아니라 실제
# 치수(정사각 셀 그리드), 셀별 2px 경계 알파 0(region 슬라이스 블리드
# 가드), 셀별 실콘텐츠 존재, 초/중/후반 프레임 상이(정지 스틸 시트
# 가드)를 파일 내용에서 직접 검사한다.
func _verify_ignition_sheet_cell_content_seal() -> void:
	var image: Image = Image.load_from_file(
		ProjectSettings.globalize_path(PerkFusionColdBootCinematic.IGNITION_SHEET_TEXTURE_PATH)
	)
	_expect(image != null and not image.is_empty(), "the ignition sheet source file must load")
	if image == null or image.is_empty():
		return
	var cols: int = PerkFusionColdBootCinematic.IGNITION_SHEET_COLS
	var rows: int = PerkFusionColdBootCinematic.IGNITION_SHEET_ROWS
	_expect(
		image.get_width() % cols == 0 and image.get_height() % rows == 0,
		"the sheet dimensions must divide evenly into the declared %dx%d grid" % [cols, rows]
	)
	var cell_w: int = image.get_width() / cols
	var cell_h: int = image.get_height() / rows
	_expect(cell_w == cell_h, "ignition cells must be square (%dx%d)" % [cell_w, cell_h])
	var frame_signatures: Array = []
	for frame_index: int in range(PerkFusionColdBootCinematic.IGNITION_SHEET_FRAMES):
		var origin_x: int = (frame_index % cols) * cell_w
		var origin_y: int = (frame_index / cols) * cell_h
		var border_alpha_max := 0.0
		for x in range(cell_w):
			for edge_y: int in [0, 1, cell_h - 2, cell_h - 1]:
				border_alpha_max = maxf(border_alpha_max, image.get_pixel(origin_x + x, origin_y + edge_y).a)
		for y in range(cell_h):
			for edge_x: int in [0, 1, cell_w - 2, cell_w - 1]:
				border_alpha_max = maxf(border_alpha_max, image.get_pixel(origin_x + edge_x, origin_y + y).a)
		_expect(border_alpha_max == 0.0, "frame %d must keep its 2px cell border fully transparent (slice-bleed guard, max a=%.3f)" % [frame_index, border_alpha_max])
		var content_pixels := 0
		for y in range(2, cell_h - 2, 4):
			for x in range(2, cell_w - 2, 4):
				if image.get_pixel(origin_x + x, origin_y + y).a > 0.03:
					content_pixels += 1
		_expect(content_pixels > 50, "frame %d must carry real pulse content (%d sampled px)" % [frame_index, content_pixels])
		if frame_index in [0, 8, 15]:
			frame_signatures.append(
				image.get_region(Rect2i(origin_x, origin_y, cell_w, cell_h)).get_data()
			)
	_expect(
		frame_signatures[0] != frame_signatures[1]
			and frame_signatures[1] != frame_signatures[2]
			and frame_signatures[0] != frame_signatures[2],
		"early/mid/late ignition frames must differ (frozen-still sheet guard)"
	)


# CB4b v2 [P1-1]: 부트 진입 에지에서 커밋 record.sources(정렬 2종)의
# 아이콘이 정확히 프리웜된다 — draw 핫패스는 캐시 히트만 타는 계약의
# 배선 씰(실 process_idle 관통).
func _verify_committed_icon_prepare_on_boot_entry() -> void:
	var fixture: Dictionary = _build_animation_state()
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var getter: Object = fixture["getter"]
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()
	controller.process_idle(0.016, owner_node, registry, Callable(getter, "get_module"))
	var host: Object = state._cold_boot_cinematic_host
	_expect(host != null and is_instance_valid(host), "icon-prepare fixture should create a cinematic host")
	var cold_boot_snapshot: Dictionary = state.get_perk_fusion_modal_snapshot().get("cold_boot", {}) as Dictionary
	var committed_sources: Array = (cold_boot_snapshot.get("committed_record", {}) as Dictionary).get("sources", []) as Array
	_expect(committed_sources.size() == 2, "the committed record should carry exactly two sorted sources")
	_expect(
		host.get_prepared_icon_ids() == committed_sources,
		"boot entry must prewarm exactly the committed source icons 1:1 (%s vs %s)" % [str(host.get_prepared_icon_ids()), str(committed_sources)]
	)
	# CB4c-1: B4 코어 페이스 대각 합성쌍도 같은 에지에서 프리웜된다 —
	# 키는 record(fusion_id@revision|sources) 파생과 정확히 일치해야 한다.
	var committed_record: Dictionary = (cold_boot_snapshot.get("committed_record", {}) as Dictionary)
	var expected_pair_id: String = PerkFusionIconKey.build(
		str(committed_record.get("fusion_id", "")),
		int(committed_record.get("created_revision", 0)),
		committed_sources
	)
	_expect(
		expected_pair_id.begins_with(PerkFusionIconKey.PREFIX),
		"the fixture record should yield a valid fusion pair icon key"
	)
	_expect(
		str(host.get_prepared_pair_icon_id()) == expected_pair_id,
		"boot entry must prewarm the B4 core-face fusion pair icon with the record-derived key (%s vs %s)" % [str(host.get_prepared_pair_icon_id()), expected_pair_id]
	)
	# CB4c-1 v2 [P2]: "프리웜 완료"의 실증 — 합성/텍스처 카운터가 실제로
	# 올라가야 하고, 같은 record의 재-prepare는 캐시 히트만 내야 한다
	# (재합성 0). id는 prepare 성공 시에만 게시된다(소스씰).
	var icon_renderer: Object = PerkFusionColdBootCinematic._icon_renderer
	var pair_stats: Dictionary = icon_renderer.get_fusion_pair_cache_stats()
	_expect(
		int(pair_stats.get("compositions", 0)) >= 1 and int(pair_stats.get("textures", 0)) >= 1,
		"boot-entry prepare must actually compose and cache the pair texture (%s)" % str(pair_stats)
	)
	var hits_before: int = int(pair_stats.get("hits", 0))
	var compositions_before: int = int(pair_stats.get("compositions", 0))
	host.prepare_committed_icons(committed_record)
	var repeat_stats: Dictionary = icon_renderer.get_fusion_pair_cache_stats()
	_expect(
		int(repeat_stats.get("hits", 0)) == hits_before + 1
			and int(repeat_stats.get("compositions", 0)) == compositions_before,
		"re-preparing the same record must cache-hit without recomposition (%s -> %s)" % [str(pair_stats), str(repeat_stats)]
	)
	_expect(
		str(host.get_prepared_pair_icon_id()) == expected_pair_id,
		"a cache-hit re-prepare must keep publishing the same pair id"
	)
	var host_pair_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")
	_expect(
		host_pair_source.contains("and bool(_icon_renderer.prepare_fusion_pair_icon("),
		"the pair id must only be published when prepare succeeds (publish-on-success gate)"
	)
	owner_node.queue_free()


# CB4c-2: 스파크 파티클 계약 — 생성은 호스트 _ready 1회(전 노드
# one_shot·fixed seed·emitting=false), 발화는 실 idle 경로의 전이 이벤트
# 소비가 소유하며 record 파생 카운트로 게이트된다(부작용=벤트 팬,
# 부산물=골드 샤워, 성공=침묵). finish는 방출을 내린다.
func _verify_spark_particle_contract() -> void:
	# side_effect record(outcome 0.60): B3 진입 시 벤트 발화, 골드 침묵.
	var side_fixture: Dictionary = _build_animation_state(0.60)
	var side_state: Object = side_fixture["state"]
	var side_registry: Object = side_fixture["registry"]
	var side_getter: Object = side_fixture["getter"]
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()
	controller.process_idle(0.016, owner_node, side_registry, Callable(side_getter, "get_module"))
	var host: Object = side_state._cold_boot_cinematic_host
	_expect(host != null and is_instance_valid(host), "spark fixture should create a cinematic host")
	var vents: Array = host._vent_spark_nodes
	var shower: Object = host._gold_shower_node
	_expect(vents.size() == 2 and shower != null, "the host should build two vent fans and one gold shower at ready time")
	for vent_value: Variant in vents:
		var vent := vent_value as GPUParticles2D
		_expect(vent != null and vent.one_shot and vent.use_fixed_seed and not vent.emitting, "vent fans must start armed-but-silent (one_shot, fixed seed, not emitting)")
	_expect((shower as GPUParticles2D).one_shot and (shower as GPUParticles2D).use_fixed_seed and not (shower as GPUParticles2D).emitting, "the gold shower must start armed-but-silent")
	var side_plan: Dictionary = (side_state.get_perk_fusion_modal_snapshot().get("cold_boot", {}) as Dictionary).get("presentation", {}) as Dictionary
	_expect(int(side_plan.get("brown_out_lane_count", 0)) + int(side_plan.get("ejected_module_count", 0)) > 0, "the side-effect fixture must carry real penalty volume (vent gate precondition)")
	controller.process_idle(1.84, owner_node, side_registry, Callable(side_getter, "get_module"))
	_expect((vents[0] as GPUParticles2D).emitting and (vents[1] as GPUParticles2D).emitting, "entering B3 with penalty volume must fire both vent fans")
	_expect(not (shower as GPUParticles2D).emitting, "a side-effect record must not fire the gold shower")
	side_state._confirm_perk_fusion_modal(null, side_registry)
	side_state._confirm_perk_fusion_modal(null, side_registry)
	_expect(not (vents[0] as GPUParticles2D).emitting, "finishing the modal must stop vent emission")

	# CB4c-2 v2 [P2-1]: 발화 티어 finish → 같은 호스트로 "무발화 success"
	# 모달 즉시 재개 — 잔존 파티클은 하드 클리어(false→restart→false)돼야
	# 하고(emitting=false 단독은 0.85/1.1s 생존자를 남긴다), 재개 후에도
	# 전 이미터가 침묵을 유지한다.
	_rearm_fusion_modal(side_state, side_registry, ["common_swiftness", "dash_lightweight"], 0.0)
	controller.process_idle(0.016, owner_node, side_registry, Callable(side_getter, "get_module"))
	_expect(side_state._cold_boot_cinematic_host == host, "the second modal must reuse the same host instance")
	_expect(bool(host.is_boot_active()), "the reused host should boot for the second modal")
	_expect(
		not (vents[0] as GPUParticles2D).emitting
			and not (vents[1] as GPUParticles2D).emitting
			and not (shower as GPUParticles2D).emitting,
		"a no-fire success reopen on the reused host must keep every emitter silent"
	)
	var host_clear_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")
	_expect(
		host_clear_source.contains("particles.emitting = false
	particles.restart()
	particles.emitting = false"),
		"finish must hard-clear live particles (false->restart->false, mythic v2 precedent)"
	)

	# CB4c-2 v2 [P2-2]: 파티클 앵커는 매 sync 현재 viewport 중심+팩토리
	# 오프셋으로 재정렬된다(모달 도중 창 리사이즈 분리 방지) — 스테일
	# 위치 강제 후 다음 idle이 되돌리는지 검증.
	var expected_center: Vector2 = (host as Node2D).get_viewport_rect().size * 0.5
	_expect(
		((vents[0] as GPUParticles2D).position - (expected_center + PerkFusionColdBootParticleFactory.VENT_LEFT_OFFSET)).length() < 0.5,
		"the left vent anchor should sit at viewport center + factory offset"
	)
	(vents[0] as GPUParticles2D).position = Vector2(11.0, 22.0)
	(shower as GPUParticles2D).position = Vector2(33.0, 44.0)
	controller.process_idle(0.016, owner_node, side_registry, Callable(side_getter, "get_module"))
	_expect(
		((vents[0] as GPUParticles2D).position - (expected_center + PerkFusionColdBootParticleFactory.VENT_LEFT_OFFSET)).length() < 0.5,
		"a later sync must re-align a displaced vent anchor (window-resize contract)"
	)
	_expect(
		((shower as GPUParticles2D).position - (expected_center + PerkFusionColdBootParticleFactory.SHOWER_OFFSET)).length() < 0.5,
		"a later sync must re-align the shower anchor"
	)

	# byproduct record(outcome 0.90): B4 진입 시 골드 샤워 발화, 벤트 침묵.
	var gold_fixture: Dictionary = _build_animation_state(0.90)
	var gold_state: Object = gold_fixture["state"]
	var gold_registry: Object = gold_fixture["registry"]
	var gold_getter: Object = gold_fixture["getter"]
	controller.process_idle(0.016, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	var gold_host: Object = gold_state._cold_boot_cinematic_host
	controller.process_idle(2.10, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	_expect(bool((gold_host._gold_shower_node as GPUParticles2D).emitting), "entering B4 with deployed modules must fire the gold shower")
	var gold_vents: Array = gold_host._vent_spark_nodes
	_expect(not (gold_vents[0] as GPUParticles2D).emitting, "a byproduct record (no penalties) must keep the vent fans silent")

	# success record: 어느 비트에서도 침묵.
	var success_fixture: Dictionary = _build_animation_state(0.0)
	var success_state: Object = success_fixture["state"]
	var success_registry: Object = success_fixture["registry"]
	var success_getter: Object = success_fixture["getter"]
	controller.process_idle(0.016, owner_node, success_registry, Callable(success_getter, "get_module"))
	var success_host: Object = success_state._cold_boot_cinematic_host
	controller.process_idle(2.10, owner_node, success_registry, Callable(success_getter, "get_module"))
	var success_vents: Array = success_host._vent_spark_nodes
	_expect(not (success_vents[0] as GPUParticles2D).emitting and not (success_host._gold_shower_node as GPUParticles2D).emitting, "a clean success must keep every spark emitter silent")
	owner_node.queue_free()


# CB4c-3: 용융/열 아지랑이 계약 — 재질은 WRITHE 공유 패밀리 셰이더
# (인라인 신설 금지), 프리셋 2종 등록, B3에서만 가시+intensity 아치,
# 부작용 record는 surge 프리셋으로 데이터 구동 스왑, finish로 소등.
func _verify_ignition_haze_contract() -> void:
	_expect(
		WritheEmberMaterial.has_preset("cold_boot_ignition_haze")
			and WritheEmberMaterial.has_preset("cold_boot_ignition_haze_surge"),
		"both cold-boot haze presets must be registered in the shared writhe family"
	)
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()

	# side_effect record: B3에서 surge 프리셋 + 가시 + intensity>0.
	var side_fixture: Dictionary = _build_animation_state(0.60)
	var side_state: Object = side_fixture["state"]
	var side_registry: Object = side_fixture["registry"]
	var side_getter: Object = side_fixture["getter"]
	controller.process_idle(0.016, owner_node, side_registry, Callable(side_getter, "get_module"))
	var host: Object = side_state._cold_boot_cinematic_host
	var haze: Sprite2D = host._ignition_haze_sprite
	_expect(haze != null and is_instance_valid(haze), "the host should build the ignition haze layer at ready time")
	_expect(not haze.visible, "the haze must stay dark outside the ignition crest (B0)")
	_expect(
		WritheEmberMaterial.is_material_using_shader(haze.material as ShaderMaterial),
		"the haze material must reuse the shared writhe-ember shader (no one-off inline shader)"
	)
	controller.process_idle(1.84, owner_node, side_registry, Callable(side_getter, "get_module"))
	_expect(haze.visible, "the haze must light during the B3 ignition crest")
	_expect(float((haze.material as ShaderMaterial).get_shader_parameter("intensity")) > 0.0, "the crest envelope must drive a positive intensity")
	var surge_hot: Color = (haze.material as ShaderMaterial).get_shader_parameter("hot_color")
	_expect(
		surge_hot.is_equal_approx(Color(1.00, 0.42, 0.28, 1.0)),
		"a side-effect record must swap to the surge preset (red-shift tell)"
	)
	side_state._confirm_perk_fusion_modal(null, side_registry)
	side_state._confirm_perk_fusion_modal(null, side_registry)
	_expect(not haze.visible, "finishing the modal must extinguish the haze")

	# success record: B3에서 기본 프리셋(골드), B4 후반에서 소등.
	var success_fixture: Dictionary = _build_animation_state(0.0)
	var success_state: Object = success_fixture["state"]
	var success_registry: Object = success_fixture["registry"]
	var success_getter: Object = success_fixture["getter"]
	controller.process_idle(0.016, owner_node, success_registry, Callable(success_getter, "get_module"))
	var success_host: Object = success_state._cold_boot_cinematic_host
	var success_haze: Sprite2D = success_host._ignition_haze_sprite
	controller.process_idle(1.84, owner_node, success_registry, Callable(success_getter, "get_module"))
	_expect(success_haze.visible, "a success record still lights the base haze at B3")
	var base_hot: Color = (success_haze.material as ShaderMaterial).get_shader_parameter("hot_color")
	_expect(
		base_hot.is_equal_approx(Color(1.00, 0.80, 0.34, 1.0)),
		"a success record must keep the base gold haze preset"
	)
	controller.process_idle(0.75, owner_node, success_registry, Callable(success_getter, "get_module"))
	_expect(not success_haze.visible, "the haze must go dark after the B4 residual window"
	)
	owner_node.queue_free()


# CB4c-4: §9 전이 오디오 계약 — 실 idle 경로에서 비트 전이마다 도착점
# 소리 하나(B1 CHNK/B2 램프/B3 THUNK), 저프레임 다중-이벤트 배치는
# 마지막 이벤트 소리만, 각성 팡파르는 부산물 전개 record에서만, 종료
# 프레임의 잔여 이벤트 폐기는 오디오도 침묵.
func _verify_transition_audio_contract() -> void:
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()

	# byproduct record: 비트별 단일 소리 + 리빌 팡파르.
	var gold_fixture: Dictionary = _build_animation_state(0.90)
	var gold_state: Object = gold_fixture["state"]
	var gold_registry: Object = gold_fixture["registry"]
	var gold_getter: Object = gold_fixture["getter"]
	var gold_audio := FakeColdBootAudio.new()
	gold_registry.audio = gold_audio
	controller.process_idle(0.016, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	_expect(gold_audio.calls.is_empty(), "B0 dock-in must play no transition audio yet")
	controller.process_idle(0.6, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	_expect(gold_audio.calls == ["chnk"], "entering B1 must play exactly the CHNK latch (%s)" % str(gold_audio.calls))
	controller.process_idle(0.4, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	_expect(gold_audio.calls == ["chnk", "ramp"], "entering B2 must add exactly the POST ramp (%s)" % str(gold_audio.calls))
	controller.process_idle(0.95, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	_expect(gold_audio.calls == ["chnk", "ramp", "thunk"], "entering B3 must add exactly the ignition thunk (%s)" % str(gold_audio.calls))
	controller.process_idle(0.3, owner_node, gold_registry, Callable(gold_getter, "get_module"))
	_expect(gold_audio.calls == ["chnk", "ramp", "thunk", "fanfare"], "a byproduct record entering B4 must add the awaken fanfare (%s)" % str(gold_audio.calls))

	# success record: 저프레임 배치=마지막 이벤트 소리만 + 팡파르 없음 +
	# 종료 프레임 잔여 이벤트=침묵.
	var success_fixture: Dictionary = _build_animation_state(0.0)
	var success_state: Object = success_fixture["state"]
	var success_registry: Object = success_fixture["registry"]
	var success_getter: Object = success_fixture["getter"]
	var success_audio := FakeColdBootAudio.new()
	success_registry.audio = success_audio
	controller.process_idle(0.016, owner_node, success_registry, Callable(success_getter, "get_module"))
	controller.process_idle(1.0, owner_node, success_registry, Callable(success_getter, "get_module"))
	_expect(success_audio.calls == ["ramp"], "a low-frame tick batching B1+B2 must play only the arrival sound (%s)" % str(success_audio.calls))
	controller.process_idle(1.2, owner_node, success_registry, Callable(success_getter, "get_module"))
	_expect(success_audio.calls == ["ramp"], "a success record crossing into B4 must stay silent (no fanfare, %s)" % str(success_audio.calls))
	controller.process_idle(2.0, owner_node, success_registry, Callable(success_getter, "get_module"))
	_expect(success_audio.calls == ["ramp"], "the finish-frame event discard must stay silent too (%s)" % str(success_audio.calls))
	owner_node.queue_free()


# CB4c-4 v2 [P2]: Fake 관통만으로는 실 GameAudio 회귀(플레이어 미생성·
# WAV 미연결·루프 모드·facade 1:1 배선·볼륨 그룹 누락·teardown 누수)가
# 전부 GREEN — 실 인스턴스를 setup하고 네 facade를 각각 호출해 봉인한다.
func _verify_real_game_audio_cold_boot_wiring() -> void:
	var audio_owner := Node.new()
	root.add_child(audio_owner)
	var audio: Object = GameAudio.new()
	audio.setup(audio_owner)
	var players: Array = [
		audio.cold_boot_chnk_latch_sfx,
		audio.cold_boot_post_ramp_sfx,
		audio.cold_boot_ignition_thunk_sfx,
		audio.cold_boot_awaken_fanfare_sfx,
	]
	var sfx_group: Array = audio._get_sfx_players()
	for player_value: Variant in players:
		var player := player_value as AudioStreamPlayer
		_expect(player != null and player.stream != null, "each cold-boot facade must own a real player with a loaded WAV stream")
		if player == null or player.stream == null:
			continue
		_expect(
			player.stream is AudioStreamWAV and (player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED,
			"cold-boot SFX must be one-shot (LOOP_DISABLED)"
		)
		_expect(player.bus == "SFX", "cold-boot players must be routed onto the SFX bus by setup (global SFX volume/effects)")
		_expect(sfx_group.has(player), "cold-boot players must be enrolled in the _get_sfx_players volume group")
	var facade_names := [
		"play_cold_boot_chnk_latch",
		"play_cold_boot_post_ramp",
		"play_cold_boot_ignition_thunk",
		"play_cold_boot_awaken_fanfare",
	]
	for facade_index: int in range(facade_names.size()):
		for player_value: Variant in players:
			(player_value as AudioStreamPlayer).stop()
		audio.call(facade_names[facade_index])
		for player_index: int in range(players.size()):
			var expected: bool = player_index == facade_index
			_expect(
				(players[player_index] as AudioStreamPlayer).playing == expected,
				"%s must drive exactly its own player (1:1, player %d)" % [facade_names[facade_index], player_index]
			)
	# teardown: owner free로 전 플레이어가 해제돼야 한다(객체 누수 없음).
	var player_refs: Array = []
	for player_value: Variant in players:
		player_refs.append(weakref(player_value))
	audio_owner.free()
	for ref_value: Variant in player_refs:
		_expect((ref_value as WeakRef).get_ref() == null, "teardown must free the cold-boot players (no leaked nodes)")


# 같은 state 위에 두 번째 융합 모달을 재무장한다(호스트 재사용 시나리오
# 전용 — 첫 모달의 재료는 소비됐으므로 남은 만렙 쌍을 쓴다).
func _rearm_fusion_modal(state: Object, registry: Object, eligible_sources: Array, outcome_roll: float) -> void:
	state.pending_skill_choices = 1
	state.choice_active = true
	state.animation_time = 10.0
	state.current_choice_context = {"source": "battle_starpoint"}
	state.current_choices = [{
		"id": "perk_fusion",
		"name": "퍽 융합",
		"is_perk_fusion": true,
		"eligible_sources": eligible_sources,
		"offer_lane": "fusion",
		"offer_protected": true,
	}]
	state.selected_index = 0
	state.choose_selected(null, registry, Vector2(760.0, 750.0))
	state._perk_fusion_modal_flow.select_source_at(0)
	state._perk_fusion_modal_flow.select_source_at(1)
	state._perk_fusion_modal_flow.confirm_current()
	state._confirm_perk_fusion_modal(null, registry, {
		"outcome": outcome_roll,
		"magnitude": [0.0, 0.0],
		"lane_selection": [0.0],
		"delete": 1.0,
		"byproduct_count": 0.0,
		"byproduct_selection": [0.0],
	})


# 코덱스 CB3-P1: 물리 flow는 choice_active에서 조기 반환하므로, 실 idle
# 경로(process_idle)가 flow 틱 직후 호스트를 생성·동기화해야 라이브에서
# 시네마틱이 표시된다 — 실 process_idle() 관통 씰.
func _verify_real_process_idle_drives_host_lifecycle() -> void:
	var fixture: Dictionary = _build_animation_state()
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var getter: Object = fixture["getter"]
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()

	var handled: bool = controller.process_idle(0.016, owner_node, registry, Callable(getter, "get_module"))
	_expect(handled, "the real idle path should claim the active fusion modal frame")
	var host: Object = state._cold_boot_cinematic_host
	_expect(host != null and is_instance_valid(host), "the real idle path should create the cinematic host during animation")
	_expect(bool(host.is_boot_active()), "the host should be booting during the animation beats")
	_expect(str(host.get_debug_boot_state().get("beat", "")) == "dock_in", "the first idle sync should mirror B0 DOCK_IN")
	_expect(bool(state.get_perk_fusion_modal_snapshot().get("cold_boot_host_live", false)), "the modal snapshot should report a live host")

	# 코덱스 CB3-P2: 같은 0.6s 실 idle 호출(저프레임)이 flow를 B1로 넘기고,
	# 그 전이 펄스가 같은 호출의 감쇠에 소멸하지 않아야 한다.
	controller.process_idle(0.6, owner_node, registry, Callable(getter, "get_module"))
	_expect(state._cold_boot_cinematic_host == host, "the idle path must reuse the existing host (no per-frame instantiation)")
	var boot_state: Dictionary = host.get_debug_boot_state()
	_expect(str(boot_state.get("beat", "")) == "twist_lock", "the same idle call should mirror the flow's B1 TWIST_LOCK")
	_expect(int(boot_state.get("consumed_event_count", 0)) == 1, "exactly the enter_twist_lock event should have reached the host")
	_expect((boot_state.get("last_events", []) as Array) == ["enter_twist_lock"], "the host should consume the ordered transition stream")
	_expect(float(boot_state.get("event_pulse", 0.0)) > 0.0, "a low-frame (0.6s) idle call must not decay the freshly arrived transition pulse to zero")
	_expect((state.consume_perk_fusion_cold_boot_events() as Array).is_empty(), "the host drain must leave the queue empty (exactly-once)")

	# 자연 완주: reveal 진입 프레임의 실 idle 호출이 호스트를 닫고 잔여
	# 이벤트를 폐기한다(다음 모달 stale 이월 금지).
	controller.process_idle(3.0, owner_node, registry, Callable(getter, "get_module"))
	_expect(not bool(host.is_boot_active()), "leaving the animation phase should finish the host through the real idle path")
	_expect(not bool(state.get_perk_fusion_modal_snapshot().get("cold_boot_host_live", true)), "a finished host must not report live to the renderer")
	_expect((state.consume_perk_fusion_cold_boot_events() as Array).is_empty(), "the finish path must discard queued final-frame events")

	owner_node.queue_free()


# 펄스 감쇠 순서 단위 계약: 기존 펄스 감쇠가 먼저, 신규 이벤트 펄스가 나중.
func _verify_pulse_decays_before_new_events() -> void:
	var host: Node2D = PerkFusionColdBootCinematic.new()
	root.add_child(host)
	host.sync_boot({"beat": "boot_post"}, ["enter_boot_post"], 0.6)
	_expect(is_equal_approx(float(host.get_debug_boot_state().get("event_pulse", 0.0)), 1.0), "a fresh transition pulse must survive its own low-frame delta at full strength")
	host.sync_boot({"beat": "boot_post"}, [], 0.1)
	var decayed: float = float(host.get_debug_boot_state().get("event_pulse", 0.0))
	_expect(decayed > 0.0 and decayed < 1.0, "an event-free tick should decay the pulse without killing it")
	host.sync_boot({"beat": "boot_post"}, [], 1.0)
	_expect(is_equal_approx(float(host.get_debug_boot_state().get("event_pulse", 0.0)), 0.0), "a long event-free tick should fully settle the pulse")
	host.queue_free()


func _verify_reset_closes_host() -> void:
	var fixture: Dictionary = _build_animation_state()
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var getter: Object = fixture["getter"]
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()
	controller.process_idle(0.016, owner_node, registry, Callable(getter, "get_module"))
	var host: Object = state._cold_boot_cinematic_host
	_expect(host != null and bool(host.is_boot_active()), "reset fixture should hold a booting host")
	state.reset()
	_expect(not bool(host.is_boot_active()), "new-run reset() must close a booting cinematic host")
	owner_node.queue_free()


# 코덱스 CB3v2-P1: 애니메이션 중 같은 프레임의 스킵→확정(연속 confirm
# 2회, 사이에 idle 없음)은 choice_active=false라 다음 idle이 조기 반환한다
# — finish가 detached 호스트를 직접 닫아야 풀스크린 잔존이 없다.
func _verify_same_frame_skip_finish_closes_host_without_idle() -> void:
	var fixture: Dictionary = _build_animation_state()
	var state: Object = fixture["state"]
	var registry: Object = fixture["registry"]
	var getter: Object = fixture["getter"]
	var owner_node := Node2D.new()
	root.add_child(owner_node)
	var controller := BattleSceneOverlayFrameController.new()
	controller.process_idle(0.016, owner_node, registry, Callable(getter, "get_module"))
	var host: Object = state._cold_boot_cinematic_host
	_expect(host != null and bool(host.is_boot_active()), "skip-finish fixture should hold a booting host mid-animation")
	state._confirm_perk_fusion_modal(null, registry)
	state._confirm_perk_fusion_modal(null, registry)
	_expect(not bool(state.is_choice_active()), "two consecutive confirms should fully close the modal")
	_expect(not bool(host.is_boot_active()), "the finish path must close the host directly (no idle frame will reach the cleanup sync)")
	_expect(not bool((host as Node2D).visible), "the detached fullscreen host must not stay visible after the modal closes")
	_expect((state.consume_perk_fusion_cold_boot_events() as Array).is_empty(), "the finish path must leave no stale transition events")
	owner_node.queue_free()


# degraded 폴백: 호스트가 전혀 없어도 실 오버레이 draw(애니메이션 phase)가
# 무크래시로 즉시모드를 그린다.
func _verify_degraded_fallback_draws_without_host() -> void:
	var fixture: Dictionary = _build_animation_state()
	var state: Object = fixture["state"]
	_expect(not bool(state.get_perk_fusion_modal_snapshot().get("cold_boot_host_live", true)), "without an idle-created host the snapshot must report host-not-live")
	_overlay_state = state
	_overlay_catalog = fixture["catalog"]
	_overlay_renderer = RuntimePerkOverlayRenderer.new()
	var perf_probe := PerfLabelProbe.new()
	var probe := Control.new()
	root.add_child(probe)
	probe.draw.connect(_on_overlay_probe_draw.bind(probe, perf_probe))
	for _redraw_attempt in range(4):
		if _overlay_draw_ran:
			break
		probe.queue_redraw()
		await process_frame
	probe.queue_free()
	_expect(_overlay_draw_ran, "the live overlay draw pass should have executed")
	_expect(perf_probe.labels.has("hud.perk_overlay.perk_fusion_modal"), "the hostless animation frame should still route through the fusion renderer (degraded immediate mode, no crash)")


func _on_overlay_probe_draw(probe: Control, perf_probe: Object) -> void:
	_overlay_draw_ran = true
	_overlay_renderer.draw(
		probe,
		_overlay_state,
		_overlay_catalog,
		Vector2(760.0, 750.0),
		null,
		null,
		null,
		perf_probe
	)


func _verify_lazy_init_and_fallback_source_contracts() -> void:
	var host_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")
	var draw_start: int = host_source.find("func _draw()")
	_expect(draw_start >= 0, "the host should own a _draw pass")
	var draw_body: String = host_source.substr(draw_start)
	_expect(not draw_body.contains(".new(") and not draw_body.contains("load("), "the host draw path must not lazy-instantiate or load anything (hot-path lazy-init trap)")
	var wrapper_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_cold_boot_cinematic_runtime.gd")
	_expect(wrapper_source.contains("PerkFusionColdBootCinematic.prewarm_assets()"), "host creation must prewarm at the discrete ensure moment")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/perk_fusion_overlay_renderer.gd")
	_expect(renderer_source.contains("if bool(snapshot.get(\"cold_boot_host_live\", false)):"), "the immediate-mode renderer must yield to a live host (no same-frame double draw)")
	# 배선 위치 소스씰: 물리 flow 게이트에 막히지 않는 실 idle 경로의
	# runtime_perk_update 직후에서만 sync한다(드라이버 재배선 드리프트 방지).
	var idle_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	_expect(idle_source.contains("_cold_boot_cinematic_runtime.sync_from_runtime_state(runtime_perk_state, owner, delta, _registry)"), "the host sync must live on the idle overlay path right after the runtime-perk update")
	var driver_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")
	_expect(not driver_source.contains("cold_boot"), "the physics-gated update driver must not re-own the host sync (unreachable during the fusion modal)")
	var host_probe: Node2D = PerkFusionColdBootCinematic.new()
	root.add_child(host_probe)
	_expect(host_probe.z_index == 110 and host_probe.top_level and not host_probe.z_as_relative, "the host must pin its global canvas ordering (z=110, top-level, absolute z)")
	host_probe.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
