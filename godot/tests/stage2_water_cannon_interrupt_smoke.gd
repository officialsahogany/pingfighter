extends SceneTree

const PaddleBounceBossPostHitHandler := preload("res://scripts/ball/paddle_bounce_boss_post_hit_handler.gd")
const Stage2BossSkillState := preload("res://scripts/stages/stage2/stage2_boss_skill_state.gd")
const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")


class FakeAudio:
	var hydro_count := 0

	func play_stage2_hydro() -> void:
		hydro_count += 1


func _init() -> void:
	var background: Object = Stage2PillarBackground.new()
	var skill_state: Object = Stage2BossSkillState.new()
	var audio := FakeAudio.new()
	var context := {
		"current_stage": 2,
		"ball_active": true,
		"waiting_for_serve": false,
		"player_score": 3,
		"ai_mode": "champion",
		"boss_pos": Vector2(320.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
	}

	background.activate_quake(0.5, 2)
	_expect(background.activate_water_cannon(context, {"audio": audio}), "water cannon should start from available Stage 2 rocks")
	_expect(background.get_water_cannon_phase() == "charging", "water cannon should begin in charge phase")
	_expect(background.interrupt_water_cannon_charge_on_boss_hit(), "water cannon charge should be interruptible")
	_expect(background.get_water_cannon_phase() == "idle", "interrupted water cannon charge should return to idle")
	_expect(_max_water_target_flash(background.get_rocks_snapshot()) <= 0.001, "interrupted water cannon should clear the target marker")
	background.update(0.9, context, {"audio": audio})
	_expect(background.get_water_cannon_phase() == "idle", "interrupted water cannon should not fire after its old charge time")
	_expect(audio.hydro_count == 0, "interrupted water cannon should not play hydro audio")

	background.reset()
	skill_state.reset()
	audio = FakeAudio.new()
	background.activate_quake(0.5, 2)
	background.update(4.0, context, {"audio": audio})
	skill_state.set("water_cannon_delay", 0.0)
	var deps := {
		"stage_background": background,
		"stage2_boss_skill_state": skill_state,
		"audio": audio,
	}
	skill_state.update(0.1, context, deps)
	_expect(background.get_water_cannon_phase() == "charging", "scheduler should start water cannon charge")

	var hit_context: Dictionary = context.duplicate()
	hit_context["boss_y"] = 25.0
	hit_context["ball_size"] = 28.6
	var boss_hit_handler := PaddleBounceBossPostHitHandler.new()
	boss_hit_handler.apply(
		Vector2(330.0, 60.0),
		Vector2(4.0, 8.0),
		0.0,
		0.0,
		false,
		false,
		false,
		hit_context,
		deps,
		null
	)
	_expect(background.get_water_cannon_phase() == "idle", "boss paddle hit should interrupt water cannon charge")
	var ai_context: Dictionary = skill_state.get_boss_ai_context(background)
	_expect(not bool(ai_context.get("stage2_boss_movement_locked", true)), "interrupted water cannon should release boss movement")
	_expect(skill_state.get_water_cannon_delay() > 29.0, "interrupted water cannon should keep the spent cooldown")
	var hud_context: Dictionary = skill_state.get_hud_context(background, context)
	_expect(str(hud_context.get("stage2_boss_skill_hud_status", "")) != "water_cannon", "interrupted water cannon should not leave a stale casting HUD status")

	print("stage2_water_cannon_interrupt_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _max_water_target_flash(rocks: Array) -> float:
	var max_flash := 0.0
	for rock_value in rocks:
		if rock_value is Dictionary:
			max_flash = max(max_flash, float((rock_value as Dictionary).get("water_target_flash", 0.0)))
	return max_flash
