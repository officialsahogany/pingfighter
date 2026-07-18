extends SceneTree

const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const PerkFusionColdBootCinematic := preload("res://scripts/hud/perk_fusion_cold_boot_cinematic.gd")

var _failures: Array[String] = []

var _overlay_draw_ran := false
var _overlay_renderer: Object
var _overlay_state: Object
var _overlay_catalog: Object


class RegistryStub:
	extends RefCounted

	var state: Object
	var catalog: Object

	func _init(state_value: Object, catalog_value: Object) -> void:
		state = state_value
		catalog = catalog_value

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_state":
				return state
			"runtime_perk_catalog":
				return catalog
		return null


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
	_verify_ignition_sheet_cell_content_seal()
	_verify_committed_icon_prepare_on_boot_entry()
	_verify_real_process_idle_drives_host_lifecycle()
	_verify_pulse_decays_before_new_events()
	_verify_reset_closes_host()
	_verify_same_frame_skip_finish_closes_host_without_idle()
	await _verify_degraded_fallback_draws_without_host()
	_verify_lazy_init_and_fallback_source_contracts()

	if _failures.is_empty():
		print("perk_fusion_cold_boot_cinematic_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _build_animation_state() -> Dictionary:
	var state := RuntimePerkState.new()
	var catalog := RuntimePerkCatalog.new()
	var registry := RegistryStub.new(state, catalog)
	state.runtime_skill_levels = {"item_luck": 5, "common_bulk_up": 5}
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
		"outcome": 0.0,
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


# CB4b: §5 에셋 매니페스트 프리움 씰 — repo에 랜딩된 8종 텍스처가
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
	]:
		_expect(PerkFusionColdBootCinematic._texture(texture_key) != null, "prewarm should cache the %s texture from the landed manifest" % texture_key)
	_expect(
		PerkFusionColdBootCinematic.IGNITION_SHEET_COLS == 4
			and PerkFusionColdBootCinematic.IGNITION_SHEET_ROWS == 4
			and PerkFusionColdBootCinematic.IGNITION_SHEET_FRAMES == 16,
		"the AutoSprite ignition sheet must declare its 4x4=16 atlas grid authority"
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
	owner_node.queue_free()


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
	_expect(idle_source.contains("_cold_boot_cinematic_runtime.sync_from_runtime_state(runtime_perk_state, owner, delta)"), "the host sync must live on the idle overlay path right after the runtime-perk update")
	var driver_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")
	_expect(not driver_source.contains("cold_boot"), "the physics-gated update driver must not re-own the host sync (unreachable during the fusion modal)")
	var host_probe: Node2D = PerkFusionColdBootCinematic.new()
	root.add_child(host_probe)
	_expect(host_probe.z_index == 110 and host_probe.top_level and not host_probe.z_as_relative, "the host must pin its global canvas ordering (z=110, top-level, absolute z)")
	host_probe.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
