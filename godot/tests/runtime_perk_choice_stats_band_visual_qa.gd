extends SceneTree

# 승인용 전체 모달 프리뷰 캡처(판정 스모크 아님 -- 눈으로 보라고 뜨는 그림).
# 출하 캔버스(2051x1246)에서 renderer.draw()를 실 CanvasItem 위에 그대로
# 돌려 제목 현판 / 축소된 카드 3장 / 축소된 현재 무공 원장 / 하단 능력치 원장 /
# 선택 힌트가 한 화면에 어떻게 앉는지 한 장으로 확인한다.
#
# 실행: godot --path <project> -s res://tests/runtime_perk_choice_stats_band_visual_qa.gd
# (headless는 픽셀이 안 나오므로 창 모드로 돌린다.)

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const VIEW_SIZE := Vector2(2051.0, 1246.0)
const CAPTURE_DIR := "res://../.tmp/perk_stats_band_capture"

var _viewport: SubViewport = null


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var player_paddle_width := 155.0
	var runtime_paddle_scale := 1.0
	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		return modules.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return modules.get(key, null)


class ModalProbe:
	extends Control

	var renderer: Object = null
	var runtime_state: Object = null
	var catalog: Object = null
	var icon_renderer: Object = null

	func _draw() -> void:
		# 전투 배경 대용: 모달 백드롭이 반투명이라 완전 검정이면 대비가 실제보다
		# 세게 보인다. 중간 톤 회청색으로 깐다.
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.13, 0.14, 0.17, 1.0))
		renderer.draw(self, runtime_state, catalog, VIEW_SIZE, icon_renderer)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("runtime_perk_choice_stats_band_visual_qa: needs a windowed run (headless has no pixels)")
		quit(0)
		return
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(VIEW_SIZE.x), int(VIEW_SIZE.y))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var catalog: Object = RuntimePerkCatalog.new()
	var state: Object = RuntimePerkState.new()
	state.runtime_skill_levels = {
		"common_swiftness": 2,
		"dash_jump": 1,
		"item_luck": 3,
	}
	state.choice_active = true
	state.animation_time = 1.0
	state.pending_skill_choices = 1
	state.gold_from_perks = 644
	state.selected_index = 0
	state.current_choices = _make_choices()
	# 능력치 띠는 owner/registry가 붙은 컨텍스트에서만 켜진다.
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	state._capture_stats_context(owner, registry)

	var probe := ModalProbe.new()
	probe.size = VIEW_SIZE
	probe.renderer = RuntimePerkOverlayRenderer.new()
	probe.renderer.prewarm_assets()
	probe.runtime_state = state
	probe.catalog = catalog
	probe.icon_renderer = RuntimePerkIconRenderer.new()
	_viewport.add_child(probe)
	probe.queue_redraw()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var texture: ViewportTexture = _viewport.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image != null and not image.is_empty():
		var output_path := ProjectSettings.globalize_path("%s/full_modal_%d.png" % [CAPTURE_DIR, OS.get_process_id()])
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		if image.save_png(output_path) == OK:
			print("runtime_perk_choice_stats_band_visual_qa: %s" % output_path)
	else:
		push_error("runtime_perk_choice_stats_band_visual_qa: capture failed")

	_viewport.queue_free()
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _make_choices() -> Array:
	return [
		{
			"id": "physique_taeheo",
			"name": "태허심법 수련",
			"description": "최대 기력 수련 보정 0 → +20",
			"detail": "무공 슬롯을 차지하지 않는 기초 수련입니다.",
			"is_physique_training": true,
			"max_level": 1,
			"icon_color": Color(0.62, 0.79, 0.55),
		},
		{
			"id": "starpoint_drop",
			"name": "낙성결",
			"description": "무혼 보너스 출현 확률 +5%",
			"detail": "무혼이 나타날 때 추가 무혼이 나타날 확률을 얻습니다.",
			"current_level": 0,
			"next_level": 1,
			"max_level": 5,
			"icon_color": Color(0.55, 0.72, 0.86),
		},
		{
			"id": "dash_overdrive",
			"name": "폭혼보",
			"description": "활주 횟수가 없을 때 완전 활주 기력 170",
			"detail": "활주 횟수가 없을 때 기력을 소모해 완전 활주를 발동합니다.",
			"current_level": 0,
			"next_level": 1,
			"max_level": 5,
			"icon_color": Color(0.72, 0.45, 0.78),
		},
	]
