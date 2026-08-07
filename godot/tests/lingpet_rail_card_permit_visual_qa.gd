extends SceneTree

# S2-c 레일 카드 상호작용 권한형(백린의안장) 라이브 픽셀 QA.
#
# 운영 draw 패스 관통: 엔트리는 실 egg runtime(debug grant → 실 슬롯 장착 →
# 실 마운트 토글)이 만든 것을 쓰고, 카드/툴팁은 스테이지1 보스 스킬 HUD
# 렌더러의 실제 그리기 함수로 그린다. 캡처만 하고 판정은 사람이 본다.
#
# 실행: godot --path godot --script res://tests/lingpet_rail_card_permit_visual_qa.gd
# (비헤드리스 필요 — 뷰포트 캡처)

const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const Stage1BossSkillHudRenderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")

const VIEW_SIZE := Vector2i(760, 750)
const STATE_COMPANION := "companion"
const LANE_Y := 655.0
const CARD_ORIGIN := Vector2(470.0, 150.0)
const CARD_GAP := 18.0
const CAPTURE_DIR := "res://.godot/codex_captures"

var _steps: Array = []
var _step_index := 0
var _frames_since_step := 0
var _canvas: RailCardCanvas = null


class FakeInputProbe:
	extends RefCounted

	var rmb := false
	var down := false

	func is_rmb_pressed() -> bool:
		return rmb

	func is_down_pressed() -> bool:
		return down


class RuntimeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 675.0)
	var player_paddle_width := 155.0
	var player_speed := 0.0
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_size := 28.6


class NullRegistry:
	extends RefCounted

	func get_cached_instance(_key: String) -> Variant:
		return null

	func get_instance(_key: String) -> Variant:
		return null


class LingpetRegistry:
	extends RefCounted

	var runtime: Object = null

	func get_cached_instance(key: String) -> Variant:
		return runtime if key == "lingpet_egg_runtime" else null

	func get_instance(key: String) -> Variant:
		return runtime if key == "lingpet_egg_runtime" else null


class RailCardCanvas:
	extends Node2D

	var renderer: Object = Stage1BossSkillHudRenderer.new()
	var entries: Array = []
	var caption := ""
	var tooltip_index := 0
	var card_size := Vector2(96.0, 40.0)
	var scale_factor := 1.0

	func _draw() -> void:
		# 실전 필러 대비 배경(어두운 판 + 밝은 밴드 몇 줄)
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color(0.05, 0.055, 0.075, 1.0))
		for band_index in range(9):
			draw_rect(Rect2(0.0, float(band_index) * 84.0, 760.0, 40.0), Color(0.085, 0.10, 0.13, 1.0))
		var font: Font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(24.0, 40.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.92, 0.74, 1.0))
		var rects: Array = []
		for i in range(entries.size()):
			var rect := Rect2(CARD_ORIGIN + Vector2(0.0, float(i) * (card_size.y + CARD_GAP)), card_size)
			rects.append(rect)
			renderer._draw_card(self, rect, entries[i] as Dictionary, scale_factor, 0.42)
		if tooltip_index >= 0 and tooltip_index < entries.size():
			renderer._draw_skill_tooltip(
				self,
				entries[tooltip_index] as Dictionary,
				rects[tooltip_index] as Rect2,
				Vector2(VIEW_SIZE),
				80.0,
				renderer._get_tooltip_scale(scale_factor)
			)


func _init() -> void:
	get_root().size = VIEW_SIZE
	LingpetRailCard.prewarm()

	var owner := RuntimeOwner.new()
	var null_registry := NullRegistry.new()

	# ① 권한형: 실 슬롯에 백린의안장 장착 → 비탑승 / 탑승 두 상태
	var permit_runtime: Object = _make_summoned_runtime("baekrin", "baekrin_saddle", owner)
	var permit_registry := LingpetRegistry.new()
	permit_registry.runtime = permit_runtime
	var permit_idle: Array = LingpetRailCard.build_entries(permit_registry)
	var mounted := _mount_via_runtime(permit_runtime, owner, null_registry)
	var permit_mounted: Array = LingpetRailCard.build_entries(permit_registry)

	# ② 대조군: 같은 펫에 발동형(묵린변신) 장착 + 쿨다운 진행 중
	var launch_runtime: Object = _make_summoned_runtime("baekrin", "baekrin_mokrin_transform", owner)
	if launch_runtime._companion_skill_states.size() > 0:
		# `ready`는 state가 소유하지 않는다(쿨다운에서 파생) — 선언된 필드만 만진다.
		var state: Object = launch_runtime._companion_skill_states[0]
		state.cooldown = 20.0
	var launch_registry := LingpetRegistry.new()
	launch_registry.runtime = launch_runtime
	var launch_entries: Array = LingpetRailCard.build_entries(launch_registry)

	print("[qa] permit idle entries=%d / mounted=%s / launch entries=%d" % [permit_idle.size(), str(mounted), launch_entries.size()])
	for label in [["idle", permit_idle], ["mounted", permit_mounted], ["launch", launch_entries]]:
		var arr: Array = label[1]
		if arr.size() > 0:
			var e: Dictionary = arr[0]
			print("[qa] %s: model=%s trigger=%s status=%s progress=%.2f cd_total=%.1f" % [
				str(label[0]),
				str(e.get("activation_model", "")),
				str(e.get("trigger_label", "")),
				str(e.get("status", "")),
				float(e.get("progress", -1.0)),
				float(e.get("cooldown_total", -1.0)),
			])

	_steps = [
		{"caption": "PERMIT / 비탑승 (ready · 게이지 100% · 토글)", "entries": permit_idle, "path": "%s/lingpet_rail_permit_idle.png" % CAPTURE_DIR},
		{"caption": "PERMIT / 탑승 중 (casting)", "entries": permit_mounted, "path": "%s/lingpet_rail_permit_mounted.png" % CAPTURE_DIR},
		{"caption": "LAUNCH 대조군 (charging 50% · 자동 · 쿨타임 40초)", "entries": launch_entries, "path": "%s/lingpet_rail_launch_control.png" % CAPTURE_DIR},
	]

	_canvas = RailCardCanvas.new()
	_canvas.card_size = _resolve_card_size()
	_apply_step()
	get_root().add_child(_canvas)


func _resolve_card_size() -> Vector2:
	var renderer: Object = Stage1BossSkillHudRenderer.new()
	var metrics: Dictionary = renderer.get_debug_card_metrics(80.0)
	var w: float = float(metrics.get("card_width", 0.0))
	var h: float = float(metrics.get("card_height", 0.0))
	if w <= 0.0 or h <= 0.0:
		return Vector2(96.0, 40.0)
	return Vector2(w, h)


func _apply_step() -> void:
	var step: Dictionary = _steps[_step_index]
	_canvas.caption = str(step.get("caption", ""))
	_canvas.entries = step.get("entries", []) as Array
	_canvas.tooltip_index = 0
	_canvas.queue_redraw()


func _make_summoned_runtime(pet_id: String, equipped_skill_id: String, owner: Object) -> Object:
	var runtime: Object = LingpetEggRuntime.new()
	runtime.debug_grant_and_activate_pet(pet_id, owner, false, equipped_skill_id)
	runtime._state = STATE_COMPANION
	runtime._guardian_stowed = false
	var center_x: float = owner.player_pos.x + owner.player_paddle_width * 0.5
	runtime._companion_pos = Vector2(center_x, LANE_Y)
	runtime._companion_motion_state.pos = runtime._companion_pos
	runtime._companion_motion_state.motion_visible = true
	return runtime


func _mount_via_runtime(runtime: Object, owner: Object, registry: Object) -> bool:
	var probe := FakeInputProbe.new()
	runtime._mount_state.set_input_probe(probe)
	probe.rmb = false
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = true
	runtime._update_companion_motion(0.016, owner, registry)
	probe.rmb = false
	return bool(runtime._mount_state.is_mounted())


func _process(_delta: float) -> bool:
	_frames_since_step += 1
	if _frames_since_step < 5:
		_canvas.queue_redraw()
		return false
	var image: Image = get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("lingpet rail permit visual QA could not capture the viewport")
		quit(1)
		return true
	# 프로젝트는 stretch/mode=canvas_items(기준 2020px)라 창 크기가 곧 캔버스 배율이다.
	# 기준 해상도로 띄우면 1:1이 되고, 관심 영역만 잘라야 카드/툴팁 글자가 읽힌다.
	var capture_rect := Rect2i(0, 0, mini(image.get_width(), 700), mini(image.get_height(), 280))
	if capture_rect.size.x > 0 and capture_rect.size.y > 0:
		image = image.get_region(capture_rect)
	var output_path := ProjectSettings.globalize_path(str(_steps[_step_index]["path"]))
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if image.save_png(output_path) != OK:
		push_error("lingpet rail permit visual QA could not save its capture")
		quit(1)
		return true
	print("capture: %s" % output_path)
	_step_index += 1
	if _step_index < _steps.size():
		_frames_since_step = 0
		_apply_step()
		return false
	print("lingpet_rail_card_permit_visual_qa: ok")
	quit(0)
	return true
