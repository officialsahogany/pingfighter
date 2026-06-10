extends SceneTree

# One-off visual QA harness for the Farukiras Dragon Wing skill.
# Renders the skill onto a SubViewport and saves PNG frames so the effect can be
# eyeballed without launching a full battle. Run WITHOUT --headless (the dummy
# rendering driver returns a blank image). Not a smoke test -- safe to delete.

const DragonWingSkill := preload("res://scripts/lingpet/lingpet_dragon_wing_skill.gd")

const FIELD := Vector2i(760, 750)
const OUT_DIR := "d:/tmp"
const TAG := "step5"


class FakeOwner:
	extends RefCounted
	var ball_active := true
	var ball_pos := Vector2(380.0, 455.0)
	var ball_vel := Vector2(3.0, 8.0)
	var ball_size := 28.6


class SkillCanvas:
	extends Node2D
	var skill: Object = null

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD.x, FIELD.y)), Color(0.05, 0.06, 0.10, 1.0))
		if skill != null:
			skill.draw(self)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("dragon_wing_preview_capture must run WITHOUT --headless")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = FIELD
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := SkillCanvas.new()
	viewport.add_child(canvas)

	var skill: Object = DragonWingSkill.new()
	skill.prewarm()
	var owner := FakeOwner.new()
	skill.launch(Vector2(380.0, 460.0), owner)

	var capture_frames := {18: "early", 54: "mid", 84: "hit", 100: "late"}
	var max_step := 110
	for step in range(max_step + 1):
		if capture_frames.has(step):
			canvas.skill = skill
			canvas.queue_redraw()
			await process_frame
			await process_frame
			var image: Image = viewport.get_texture().get_image()
			var out_path := "%s/dragon_wing_%s_%s.png" % [OUT_DIR, TAG, str(capture_frames[step])]
			image.save_png(out_path)
			print("[DragonWingPreview] %s -> %s" % [str(capture_frames[step]), out_path])
		skill.update(1.0 / 60.0, owner, null, {})
	print("[DragonWingPreview] done")
	quit(0)
