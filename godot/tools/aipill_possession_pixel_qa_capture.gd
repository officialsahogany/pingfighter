extends SceneTree

# 신령환(호신령 빙의) 픽셀 QA 캡처.
#
# 헤드리스 스모크는 플랜 dict 만 증명한다 — "1초 안에 조종당함으로 읽히는가",
# "부적이 뒤통수 스티커로 보이지 않는가", "공 궤적을 가리지 않는가" 는 오직
# 실제 렌더 픽셀로만 판정할 수 있다. 실 한미량 idle 시트 위에 실 렌더러
# 경로(배경판 → 스프라이트 → 오버레이)를 그대로 태워 4개 상태를 나란히 굽는다.
#
# 실행: <godot> --path godot --script res://tools/aipill_possession_pixel_qa_capture.gd

const Stage1PlayerActorRenderer := preload("res://scripts/stages/stage1/stage1_player_actor_renderer.gd")
const BattleSmasherSpritePaths := preload("res://scripts/resources/battle_smasher_sprite_paths.gd")

const OUT_DIR := "C:/Users/woduq/bosspong_backups/qa_evidence"
const CELL := Vector2(230.0, 300.0)
const SPRITE_SIZE := Vector2(160.0, 160.0)
const COLUMNS := 4
const ZOOM := 2


class QaCanvas:
	extends Node2D

	var renderer: Object
	var idle_texture: Texture2D
	var cases: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(CELL.x * COLUMNS, CELL.y)), Color(0.055, 0.06, 0.075, 1.0))
		var font: Font = ThemeDB.fallback_font
		for index in range(cases.size()):
			var entry: Dictionary = cases[index]
			var origin := Vector2(CELL.x * float(index), 0.0)
			var rect := Rect2(
				origin + Vector2((CELL.x - SPRITE_SIZE.x) * 0.5, 96.0),
				SPRITE_SIZE
			)
			var context: Dictionary = entry.get("context", {})
			var plan: Dictionary = Stage1PlayerActorRenderer.build_possession_plan(
				context, rect, float(entry.get("now_msec", 1200.0)), int(entry.get("lod", 0)),
				float(entry.get("lead_dx", 0.0))
			)
			# 실 드로우 순서: 배경판(본체 뒤) → 선행 잔상 → 본체 → 오버레이.
			renderer._draw_possession_backplate(self, plan)
			var lead: Dictionary = plan.get("lead", {})
			if bool(lead.get("enabled", false)) and idle_texture != null:
				var offset: Vector2 = lead.get("offset", Vector2.ZERO)
				draw_texture_rect_region(
					idle_texture,
					Rect2(rect.position + offset, rect.size),
					Rect2(Vector2.ZERO, SPRITE_SIZE),
					lead.get("color", Color.WHITE),
					false,
					true
				)
			if idle_texture != null:
				var modulate: Color = plan.get("sprite_modulate", Color.WHITE) if bool(plan.get("active", false)) else Color.WHITE
				draw_texture_rect_region(
					idle_texture, rect, Rect2(Vector2.ZERO, SPRITE_SIZE), modulate, false, true
				)
			if bool(plan.get("active", false)):
				renderer._draw_possession_overlay(self, plan)
			# 판정 보조선: 스프라이트 rect(회색) + 상시 요소 상한선(초록).
			draw_rect(rect, Color(0.35, 0.38, 0.45, 0.45), false, 1.0)
			var ceiling_y: float = rect.position.y - 40.0
			draw_line(
				Vector2(origin.x + 6.0, ceiling_y), Vector2(origin.x + CELL.x - 6.0, ceiling_y),
				Color(0.25, 0.85, 0.35, 0.45), 1.0
			)
			if font != null:
				draw_string(
					font, origin + Vector2(12.0, 24.0), str(entry.get("label", "")),
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.90, 0.92, 0.96, 0.95)
				)
				draw_string(
					font, origin + Vector2(12.0, 44.0),
					"draw=%d" % int(plan.get("draw_count", 0)),
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.62, 0.70, 0.82, 0.90)
				)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var window := root
	# project.godot 는 canvas_items 스트레치(base 2020x1246)를 쓴다. QA 캡처는
	# 1:1 픽셀이어야 판정이 가능하므로 스트레치를 끄고 노드 스케일로만 확대한다.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.size = Vector2i(int(CELL.x) * COLUMNS * ZOOM, int(CELL.y) * ZOOM)
	var renderer: Object = Stage1PlayerActorRenderer.new()
	renderer.prewarm_runtime_assets()
	var canvas := QaCanvas.new()
	canvas.renderer = renderer
	canvas.idle_texture = load(BattleSmasherSpritePaths.SMASHER_IDLE_SHEET_PATH) as Texture2D
	canvas.cases = [
		{"label": "OFF (기준)", "context": _context(false, 0.0, 130.0)},
		{"label": "빙의 정지", "context": _context(true, 0.0, 360.0)},
		{"label": "빙의 이동", "context": _context(true, 0.0, 590.0), "lead_dx": 16.0},
		{"label": "가드 판정 f11", "context": _context(true, 11.0, 700.0)},
	]
	canvas.scale = Vector2(float(ZOOM), float(ZOOM))
	root.add_child(canvas)
	await process_frame
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out_path := "%s/aipill_possession_pixel_qa_%d.png" % [OUT_DIR, Time.get_ticks_msec()]
	print("QA capture saved=", out_path, " err=", image.save_png(out_path))
	quit(0)


func _context(active: bool, flash_frames: float, ball_x: float) -> Dictionary:
	return {
		"active_item_aipill_active": active,
		"active_item_aipill_phase": 1.1,
		"active_item_aipill_flash_timer_frames": flash_frames,
		"active_item_aipill_flash_initial_frames": 12.0,
		"ball_active": true,
		# 셀마다 다른 x 를 노리게 해 조준선이 자기 셀 안에 그려지도록 한다
		# (모든 셀이 같은 x 를 쓰면 조준선이 1번 셀에 겹쳐 쌓인다).
		"ball_pos": Vector2(ball_x, 380.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"play_left": 0.0,
		"play_right": 760.0,
	}
