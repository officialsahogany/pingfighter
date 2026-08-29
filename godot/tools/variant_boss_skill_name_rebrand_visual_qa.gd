extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const Stage2ArachneBossState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const Stage2MolewangBossState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const Stage3AliceBossState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")
const Stage3TeddyBearBossState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const OUTPUT_PATH := (
	"res://.godot/codex_captures/variant_boss_hwangyeok_rebrand/"
	+ "skill_names_four_variants_ko.png"
)
const EXPECTED_LABELS := {
	"arachne": {"web_trap": "거미줄발사", "web_rescue": "실공묶기", "spider_rage": "연쇄거미줄발사"},
	"molewang": {"tunnel_raid": "지맥잠행", "spinning_claw": "선조율풍", "friend_moles": "지굴원군"},
	"alice": {"mirror_world": "경화수월", "size_shift": "여의변화", "rabbit_projectile": "옥토비탄"},
	"teddy_bear": {"cotton_throw": "면운산화", "cotton_bomb": "면화폭뢰", "deadly_hug": "사혼포옹", "heart_beam": "심광충파"},
}


class CaptureCanvas:
	extends Node2D

	var cases: Array = []

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)), Color("160f12"), true)
		for case_index in range(cases.size()):
			var column: int = case_index % 2
			var row: int = case_index / 2
			var panel_rect := Rect2(
				Vector2(60.0 + float(column) * 970.0, 60.0 + float(row) * 583.0),
				Vector2(930.0, 543.0)
			)
			draw_rect(panel_rect, Color("291d24"), true)
			draw_rect(panel_rect, Color("b77952"), false, 4.0)
			var case_data: Dictionary = cases[case_index]
			font.draw_string(
				get_canvas_item(),
				panel_rect.position + Vector2(30.0, 52.0),
				str(case_data.get("boss_name", "")),
				HORIZONTAL_ALIGNMENT_LEFT,
				300.0,
				28,
				Color("ffe4bd")
			)
			var skills: Array = case_data.get("skills", []) as Array
			for skill_index in range(skills.size()):
				var skill: Dictionary = skills[skill_index]
				var card_rect := Rect2(
					panel_rect.position + Vector2(760.0, 96.0 + float(skill_index) * 105.0),
					Vector2(92.0, 46.0)
				)
				draw_rect(card_rect, Color("3b2833"), true)
				draw_rect(card_rect, Color(skill.get("color", Color("d98f6a"))), false, 3.0)
				font.draw_string(
					get_canvas_item(),
					panel_rect.position + Vector2(30.0, 126.0 + float(skill_index) * 105.0),
					str(skill.get("id", "")),
					HORIZONTAL_ALIGNMENT_LEFT,
					300.0,
					18,
					Color("c9b6be")
				)
				BossSkillCardHudSpec.draw_skill_tooltip(
					self,
					skill,
					card_rect,
					Vector2(VIEW_SIZE),
					0.0,
					{},
					1.15,
					{"max_desc_lines": 1}
				)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	if DisplayServer.get_name().to_lower().contains("headless"):
		_fail("variant boss skill-name visual QA requires a real window")
		return
	if RenderingServer.get_rendering_device() == null:
		_fail("variant boss skill-name visual QA requires a Vulkan rendering device")
		return
	var cases := _build_cases()
	var total_skill_count := 0
	for case_value in cases:
		var case_data: Dictionary = case_value
		var variant_id := str(case_data.get("variant", ""))
		var expected: Dictionary = EXPECTED_LABELS.get(variant_id, {}) as Dictionary
		var skills: Array = case_data.get("skills", []) as Array
		total_skill_count += skills.size()
		for skill_value in skills:
			var skill: Dictionary = skill_value
			var skill_id := str(skill.get("id", ""))
			if str(skill.get("label", "")) != str(expected.get(skill_id, "")):
				_fail("production HUD returned a stale label for %s" % skill_id)
				return
	if total_skill_count != 13:
		_fail("production HUD did not expose all 13 approved skill labels")
		return
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	if DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir()) != OK:
		_fail("could not create variant boss skill-name capture directory")
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := CaptureCanvas.new()
	canvas.cases = cases
	viewport.add_child(canvas)
	canvas.queue_redraw()
	for _frame_index in range(8):
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output_absolute) != OK:
		_fail("failed to save variant boss skill-name capture")
		return
	if _count_changed_pixels(image, Color("160f12")) < 100000:
		_fail("variant boss skill-name capture did not render the production tooltip panels")
		return
	print("[VariantBossSkillNameVisualQA] evidence=%s" % output_absolute)
	print("variant_boss_skill_name_rebrand_visual_qa: ok")
	LanguageSettings.set_test_locale_override("")
	quit(0)


func _build_cases() -> Array:
	return [
		_build_case("arachne", "거미각시", 2, Stage2ArachneBossState.new().get_hud_context()),
		_build_case("molewang", "지굴왕", 2, Stage2MolewangBossState.new().get_hud_context()),
		_build_case("alice", "옥토선자", 3, Stage3AliceBossState.new().get_hud_context()),
		_build_case("teddy_bear", "포웅귀", 3, Stage3TeddyBearBossState.new().get_hud_context()),
	]


func _build_case(variant_id: String, boss_name: String, stage_id: int, context: Dictionary) -> Dictionary:
	return {
		"variant": variant_id,
		"boss_name": boss_name,
		"skills": context.get("stage%d_boss_skill_hud_skills" % stage_id, []),
	}


func _count_changed_pixels(image: Image, background: Color) -> int:
	var changed := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			var distance := absf(pixel.r - background.r) + absf(pixel.g - background.g) + absf(pixel.b - background.b)
			if distance > 0.04:
				changed += 1
	return changed


func _fail(message: String) -> void:
	LanguageSettings.set_test_locale_override("")
	push_error(message)
	quit(1)
