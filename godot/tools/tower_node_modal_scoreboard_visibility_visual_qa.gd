extends SceneTree

const ScoreboardRenderer := preload("res://scripts/hud/scoreboard_renderer.gd")
const Stage1TopMiniScoreboardSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentNodeModalState := preload(
	"res://scripts/tower_ascent/tower_ascent_node_modal_state.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkIconRenderer := preload(
	"res://scripts/hud/runtime_perk_icon_renderer.gd"
)

const VIEW_SIZE := Vector2i(2020, 1246)
const GAMEPLAY_WIDTH := 760.0
const GAMEPLAY_HEIGHT := 750.0
const OUTPUT_DIR := "res://.godot/codex_captures/tower_node_modal_scoreboard_s4"


class QaScoreState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {"player_score": 7, "boss_score": 2, "deuce_mode": false}

	func would_score_finish(_side: String) -> bool:
		return false

	func is_player_in_danger() -> bool:
		return false


class QaFlow:
	extends RefCounted

	var active := false
	var phase := "NODE_MODAL"
	var modal_state: Object
	var card_renderer: Object
	var icon_renderer: Object

	func _init(state_value: Object, card_value: Object, icon_value: Object) -> void:
		modal_state = state_value
		card_renderer = card_value
		icon_renderer = icon_value

	func is_active() -> bool:
		return active

	func get_phase_name() -> String:
		return phase

	func get_node_modal_view_model(view_size: Vector2) -> Dictionary:
		return modal_state.build_view_model(view_size)

	func get_node_modal_kind() -> String:
		return "training"

	func get_node_modal_render_context() -> Dictionary:
		return {"card_renderer": card_renderer, "icon_renderer": icon_renderer}


class QaRegistry:
	extends RefCounted

	var scoreboard_renderer := ScoreboardRenderer.new()
	var score_state := QaScoreState.new()
	var flow_owner: Object

	func _init(flow_value: Object) -> void:
		flow_owner = flow_value

	func get_instance(key: String) -> Object:
		if key == "scoreboard_renderer":
			return scoreboard_renderer
		if key == "match_score_state":
			return score_state
		return null

	func get_cached_instance(key: String) -> Object:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return null


class CaptureCanvas:
	extends Node2D

	var flow: Object
	var registry: Object
	var scoreboard_drawer := Stage1TopMiniScoreboardSceneDrawer.new()
	var flow_renderer := TowerAscentFlowRenderer.new()
	var game_scale := float(VIEW_SIZE.y) / GAMEPLAY_HEIGHT
	var game_size := Vector2(GAMEPLAY_WIDTH * game_scale, float(VIEW_SIZE.y))
	# 생산 top-mini는 상단 레터박스가 20px 이상일 때만 존재한다. 80px은
	# 2020x1246 라이브 신고의 모달 제목과 겹치는 상단 배치를 재현한다.
	var game_offset := Vector2((float(VIEW_SIZE.x) - game_size.x) * 0.5, 80.0)

	func _init(flow_value: Object, registry_value: Object) -> void:
		flow = flow_value
		registry = registry_value

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("080c17"))
		if str(flow.get_phase_name()) == "COMBAT":
			_draw_combat_surface()
		scoreboard_drawer.draw(
			self,
			{"width": GAMEPLAY_WIDTH, "top_mini_score_sparkle_duration": 0.35},
			registry,
			{},
			game_offset,
			game_size,
			2.0
		)
		if str(flow.get_phase_name()) == "NODE_MODAL":
			flow_renderer.draw_fullscreen_node_modal(
				self,
				flow,
				Rect2(Vector2.ZERO, Vector2(VIEW_SIZE))
			)

	func _draw_combat_surface() -> void:
		draw_rect(Rect2(game_offset, game_size), Color("111d2a"))
		var inner := Rect2(game_offset + Vector2(16.0, 16.0), game_size - Vector2(32.0, 32.0))
		draw_rect(inner, Color("182b38"), false, 3.0)
		draw_string(
			ThemeDB.fallback_font,
			game_offset + Vector2(42.0, game_size.y - 42.0),
			"COMBAT RETURN",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			28,
			Color(0.72, 0.79, 0.82, 0.72)
		)


var _frames: Dictionary = {}
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().contains("headless"):
		push_error("tower_node_modal_scoreboard_visibility_visual_qa requires a real window")
		quit(1)
		return
	if RenderingServer.get_rendering_device() == null:
		push_error("tower_node_modal_scoreboard_visibility_visual_qa requires Vulkan")
		quit(1)
		return

	var card_renderer := RuntimePerkOverlayRenderer.new()
	var icon_renderer := RuntimePerkIconRenderer.new()
	card_renderer.prewarm_assets()
	icon_renderer.prewarm_assets()
	var modal_state := TowerAscentNodeModalState.new()
	modal_state.open(
		"scoreboard-visibility-qa",
		"training",
		{"gold": 30, "muhon": 8},
		_actions()
	)
	modal_state.set_clock_msec_for_tests(2000)
	var flow := QaFlow.new(modal_state, card_renderer, icon_renderer)
	var registry := QaRegistry.new(flow)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := CaptureCanvas.new(flow, registry)
	viewport.add_child(canvas)

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		_fail("scoreboard capture directory creation failed")
		return

	# 같은 수련장 픽셀에서 suppression 조건만 끄는 반증 프레임. 점수판이
	# 실제로 7|2를 그릴 수 있는 위치임을 먼저 남긴다.
	flow.active = false
	flow.phase = "NODE_MODAL"
	if not await _capture(viewport, canvas, output_dir, "node_modal_control_visible"):
		return
	var host := canvas.get_node_or_null("TopMiniScoreboardRetainedHost")
	_expect(host != null and host.visible, "control modal must have a visible retained host")

	# 생산 조건: 활성 탑 NODE_MODAL은 같은 retained host를 숨긴다.
	flow.active = true
	flow.phase = "NODE_MODAL"
	if not await _capture(viewport, canvas, output_dir, "node_modal_hidden"):
		return
	_expect(host != null and not host.visible, "active NODE_MODAL capture must hide the retained host")

	# 모달 종료 뒤 전투 복귀에는 동일한 7|2가 즉시 돌아온다.
	flow.phase = "COMBAT"
	if not await _capture(viewport, canvas, output_dir, "combat_restored"):
		return
	_expect(host != null and host.visible, "COMBAT return capture must restore the retained host")

	# 비탑 일반 캠페인의 공용 HUD 부정 레그.
	flow.active = false
	flow.phase = "COMBAT"
	if not await _capture(viewport, canvas, output_dir, "non_tower_visible"):
		return
	_expect(host != null and host.visible, "non-tower capture must keep the mini scoreboard visible")

	var control: Image = _frames.get("node_modal_control_visible", null)
	var hidden: Image = _frames.get("node_modal_hidden", null)
	_expect(
		_sampled_difference_count(control, hidden) >= 30,
		"control/hidden modal frames must have a visible scoreboard pixel difference"
	)
	_expect(_save_strip(output_dir), "visibility comparison strip must save")

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.remove_child(viewport)
	viewport.free()
	await process_frame
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("tower_node_modal_scoreboard_visibility_visual_qa: evidence=%s" % output_dir)
	print("tower_node_modal_scoreboard_visibility_visual_qa: captures=4 strips=1")
	print("tower_node_modal_scoreboard_visibility_visual_qa: ok")
	quit(0)


func _actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var names := ["철산공", "유운보", "태허심법", "격기심법", "순환결", "비천보"]
	for index in range(names.size()):
		actions.append({
			"id": "training:scoreboard_qa_%d" % index,
			"label": str(names[index]),
			"cost_text": "2 무혼",
			"enabled": true,
			"payload": {
				"choice": {
					"id": "scoreboard_qa_%d" % index,
					"name": str(names[index]),
					"description": "몸을 단련해 전투 능력과 생존 능력을 함께 높입니다.",
					"current_level": 2,
					"next_level": 3,
					"level_text": "Lv.2 → Lv.3",
					"icon_color": Color(0.72, 0.39 + float(index) * 0.035, 0.18),
				},
				"presentation": {
					"current": "Lv.2",
					"result": "Lv.3",
					"target": str(names[index]),
				},
			},
		})
	return actions


func _capture(
	viewport: SubViewport,
	canvas: CanvasItem,
	output_dir: String,
	frame_name: String
) -> bool:
	canvas.queue_redraw()
	for _frame_index in range(4):
		await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEW_SIZE:
		_fail("invalid scoreboard visibility frame: %s" % frame_name)
		return false
	var output_path := output_dir.path_join("%s.png" % frame_name)
	if image.save_png(output_path) != OK:
		_fail("failed to save scoreboard visibility frame: %s" % output_path)
		return false
	_frames[frame_name] = image.duplicate()
	print("[TowerNodeModalScoreboardVisibilityVisualQA] %s" % output_path)
	return true


func _save_strip(output_dir: String) -> bool:
	var names := ["node_modal_control_visible", "node_modal_hidden", "combat_restored", "non_tower_visible"]
	var cell_size := Vector2i(VIEW_SIZE.x / 2, VIEW_SIZE.y / 2)
	var strip := Image.create(cell_size.x * names.size(), cell_size.y, false, Image.FORMAT_RGBA8)
	for index in range(names.size()):
		var frame: Image = (_frames.get(str(names[index]), null) as Image).duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(Vector2i.ZERO, cell_size), Vector2i(index * cell_size.x, 0))
	var output_path := output_dir.path_join("visibility_strip.png")
	if strip.save_png(output_path) != OK:
		return false
	print("[TowerNodeModalScoreboardVisibilityVisualQA] %s" % output_path)
	return true


func _sampled_difference_count(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var changed := 0
	for y in range(0, first.get_height(), 3):
		for x in range(0, first.get_width(), 3):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) > 0.04:
				changed += 1
	return changed


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
