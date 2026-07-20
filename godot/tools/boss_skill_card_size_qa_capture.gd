extends SceneTree

# 왼쪽 필러 보스 스킬카드 사이즈 QA 캡처(2026-07-21 "복원 후 카드 작아짐" 리포트).
# 실 stage5/stage1 렌더러 + 실 카드 아트를 현실적인 pillar_w로 렌더해
# 카드 rect·아트 크롭 상태를 픽셀로 확인한다. windowed 실행 전용.

const Stage5Renderer := preload("res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd")
const Stage1Renderer := preload("res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd")
const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

const EVIDENCE_DIR := "C:/Users/woduq/bosspong_backups/qa_evidence"
const PILLAR_W := 550.0
const VIEW_SIZE := Vector2(2560.0, 1440.0)
const GAME_OFFSET := Vector2(PILLAR_W, 60.0)
const GAME_SIZE := Vector2(1460.0, 1320.0)


class QaCanvas:
	extends Node2D

	var stage5_renderer: Object
	var stage1_renderer: Object

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(720.0, 1400.0)), Color(0.07, 0.08, 0.11, 1.0))
		# 필러 경계선(=game_offset.x)
		draw_line(Vector2(PILLAR_W, 0.0), Vector2(PILLAR_W, 1400.0), Color(0.3, 0.8, 0.3, 0.8), 2.0)
		var s5_context := {
			"current_stage": 5,
			"stage5_boss_skill_hud_active": true,
			"stage5_boss_skill_hud_skills": [
				{"id": "hongryun_fireball", "status": "charging", "progress": 0.62, "next_activation_sec": 3.0},
				{"id": "hongryun_inferno", "status": "ready", "ready": true, "render_kind": "dragon_orb_gauge", "gauge": 3.0, "gauge_max": 5, "next_activation_sec": 9.0},
			],
			"view_size": VIEW_SIZE,
			"game_offset": GAME_OFFSET,
			"game_size": GAME_SIZE,
			"time_seconds": 10.0,
		}
		stage5_renderer.draw(self, s5_context)
		var layout: Dictionary = stage5_renderer.build_card_layout(s5_context)
		for rect_value in layout.get("rects", []):
			var r: Rect2 = rect_value
			draw_rect(r.grow(2.0), Color(1.0, 1.0, 0.2, 0.9), false, 1.0)
		var metrics: Dictionary = BossSkillCardHudSpec.get_card_metrics(PILLAR_W)
		print("QA metrics pillar_w=", PILLAR_W, " -> ", metrics)
		print("QA rects=", layout.get("rects", []))
		# 복원 전(스트레치) 비교: 같은 rect에 구 방식 draw_texture_rect 스트레치.
		var rects: Array = layout.get("rects", [])
		if not rects.is_empty():
			var base_rect: Rect2 = rects[0]
			var legacy_rect := Rect2(base_rect.position + Vector2(0.0, 240.0), base_rect.size)
			var fireball_tex: Texture2D = stage5_renderer._get_skill_texture("hongryun_fireball")
			if fireball_tex != null:
				draw_texture_rect(fireball_tex, legacy_rect, false)
				draw_rect(legacy_rect.grow(2.0), Color(0.4, 0.8, 1.0, 0.9), false, 1.0)
			var inferno_tex: Texture2D = stage5_renderer._get_skill_texture("hongryun_inferno")
			if inferno_tex != null:
				var legacy_rect2 := Rect2(legacy_rect.position + Vector2(0.0, 76.0), base_rect.size)
				draw_texture_rect(inferno_tex, legacy_rect2, false)
				draw_rect(legacy_rect2.grow(2.0), Color(0.4, 0.8, 1.0, 0.9), false, 1.0)
			# 3쌍: 현행 cover를 fill 1.0(풀조명)으로 — 크롭만 분리 비교.
			if fireball_tex != null:
				var cover_rect := Rect2(legacy_rect.position + Vector2(0.0, 180.0), base_rect.size)
				BossSkillCardHudSpec.draw_skillcard_gauge_fill(
					self, cover_rect, fireball_tex,
					Rect2(Vector2.ZERO, fireball_tex.get_size()),
					1.0, Color(0.18, 0.16, 0.18, 1.0), Color(1.0, 1.0, 1.0, 1.0)
				)
				draw_rect(cover_rect.grow(2.0), Color(1.0, 0.5, 1.0, 0.9), false, 1.0)
			if inferno_tex != null:
				var cover_rect2 := Rect2(legacy_rect.position + Vector2(0.0, 256.0), base_rect.size)
				BossSkillCardHudSpec.draw_skillcard_gauge_fill(
					self, cover_rect2, inferno_tex,
					Rect2(Vector2.ZERO, inferno_tex.get_size()),
					1.0, Color(0.18, 0.16, 0.18, 1.0), Color(1.0, 1.0, 1.0, 1.0)
				)
				draw_rect(cover_rect2.grow(2.0), Color(1.0, 0.5, 1.0, 0.9), false, 1.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var window := root
	window.size = Vector2i(720, 1400)
	var canvas := QaCanvas.new()
	canvas.stage5_renderer = Stage5Renderer.new()
	canvas.stage1_renderer = Stage1Renderer.new()
	root.add_child(canvas)
	await process_frame
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	var out_path := "%s/boss_skill_card_size_qa_%d.png" % [EVIDENCE_DIR, Time.get_ticks_msec()]
	var err := image.save_png(out_path)
	print("QA capture saved=", out_path, " err=", err)
	quit(0)
