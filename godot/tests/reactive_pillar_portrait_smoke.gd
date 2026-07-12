extends SceneTree

# Seals the Phase 1 reactive pillar portrait wiring:
#  (1) stage1_pillar_hud_scene_drawer._resolve_portrait_expressions — live stun +
#      per-point score state -> boss/player face, with result outranking stun and
#      the score pulse gated on scoreboard.is_active().
#  (2) right_pillar_portrait_renderer.compute_boxes — two non-overlapping boxes that
#      sit inside the band between the boss orb (top) and player orb (bottom), and
#      ok=false when the band is too short (draw-time capacity discipline).

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const RightPillarPortraitRenderer := preload("res://scripts/hud/right_pillar_portrait_renderer.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_expression_resolver()
	_verify_box_geometry()

	if _failures.is_empty():
		print("reactive_pillar_portrait_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_expression_resolver() -> void:
	var drawer: Object = Stage1PillarHudSceneDrawer.new()

	# Neutral baseline: no status, scoreboard idle.
	var idle: Dictionary = drawer._resolve_portrait_expressions(StatusEffectState.new(), ScoreboardState.new())
	_expect(str(idle.get("boss")) == "neutral", "idle boss should be neutral")
	_expect(str(idle.get("player")) == "neutral", "idle player should be neutral")

	# Boss stun -> pained (player unaffected).
	var boss_stun := StatusEffectState.new()
	boss_stun.apply_status("boss", "stun", 60.0)
	var r_boss_stun: Dictionary = drawer._resolve_portrait_expressions(boss_stun, ScoreboardState.new())
	_expect(str(r_boss_stun.get("boss")) == "pained", "boss stun should be pained")
	_expect(str(r_boss_stun.get("player")) == "neutral", "boss stun should leave player neutral")

	# Player stun -> pained (boss unaffected).
	var player_stun := StatusEffectState.new()
	player_stun.apply_status("player", "stun", 60.0)
	var r_player_stun: Dictionary = drawer._resolve_portrait_expressions(player_stun, ScoreboardState.new())
	_expect(str(r_player_stun.get("player")) == "pained", "player stun should be pained")
	_expect(str(r_player_stun.get("boss")) == "neutral", "player stun should leave boss neutral")

	# Player scored (scoreboard active) -> boss sad, player happy.
	var sb_player := ScoreboardState.new()
	sb_player.start(1, 0, false, "player", 5)
	var r_player_score: Dictionary = drawer._resolve_portrait_expressions(StatusEffectState.new(), sb_player)
	_expect(str(r_player_score.get("boss")) == "sad", "player score should make boss sad")
	_expect(str(r_player_score.get("player")) == "happy", "player score should make player happy")

	# Boss scored (scoreboard active) -> boss happy, player sad.
	var sb_boss := ScoreboardState.new()
	sb_boss.start(0, 1, false, "boss", 5)
	var r_boss_score: Dictionary = drawer._resolve_portrait_expressions(StatusEffectState.new(), sb_boss)
	_expect(str(r_boss_score.get("boss")) == "happy", "boss score should make boss happy")
	_expect(str(r_boss_score.get("player")) == "sad", "boss score should make player sad")

	# Result outranks stun: player scored while boss also stunned -> boss sad, not pained.
	var sb_player2 := ScoreboardState.new()
	sb_player2.start(1, 0, false, "player", 5)
	var both := StatusEffectState.new()
	both.apply_status("boss", "stun", 60.0)
	var r_both: Dictionary = drawer._resolve_portrait_expressions(both, sb_player2)
	_expect(str(r_both.get("boss")) == "sad", "score result should outrank stun on boss")

	# Stale scoring side but scoreboard INACTIVE -> neutral (gated on is_active).
	var sb_stale := ScoreboardState.new()
	sb_stale.last_scoring_side = "player"
	sb_stale.active = false
	var r_stale: Dictionary = drawer._resolve_portrait_expressions(StatusEffectState.new(), sb_stale)
	_expect(str(r_stale.get("boss")) == "neutral", "inactive scoreboard should not drive boss face")
	_expect(str(r_stale.get("player")) == "neutral", "inactive scoreboard should not drive player face")


func _verify_box_geometry() -> void:
	var renderer: Object = RightPillarPortraitRenderer.new()

	# Realistic Stage 1 layout at scale 1.0: game canvas 760x750 at origin.
	var layout := _build_layout(Vector2.ZERO, Vector2(760.0, 750.0))
	var boss_center: Vector2 = layout["boss_right_top_center"]
	var player_center: Vector2 = layout["right_center"]
	var orb_radius: float = float(layout["orb_radius"])

	var boxes: Dictionary = renderer.compute_boxes(layout)
	_expect(bool(boxes.get("ok", false)), "boxes should fit the full-height band")
	if bool(boxes.get("ok", false)):
		var boss_rect: Rect2 = boxes["boss_rect"]
		var player_rect: Rect2 = boxes["player_rect"]
		# Non-overlapping stack (boss above player).
		_expect(boss_rect.end.y <= player_rect.position.y + 0.01, "boss box must sit above player box")
		# Below the boss orb, above the player orb (no orb collision).
		_expect(boss_rect.position.y >= boss_center.y + orb_radius, "boss box must clear the boss orb")
		_expect(player_rect.end.y <= player_center.y - orb_radius, "player box must clear the player orb")
		# Both columns centered on the orb x.
		_expect(is_equal_approx(boss_rect.get_center().x, boss_center.x), "boss box centered on orb x")
		_expect(is_equal_approx(player_rect.get_center().x, player_center.x), "player box centered on orb x")
		# Positive extents.
		_expect(boss_rect.size.x > 0.0 and boss_rect.size.y > 0.0, "boss box has positive size")

	# Degenerate band (orbs almost touching) -> refuse to draw (capacity discipline).
	var tight := {
		"scale_factor": 1.0,
		"orb_radius": 55.0,
		"boss_right_top_center": Vector2(900.0, 100.0),
		"right_center": Vector2(900.0, 200.0),
	}
	var tight_boxes: Dictionary = renderer.compute_boxes(tight)
	_expect(not bool(tight_boxes.get("ok", true)), "too-short band must refuse (ok=false)")


func _build_layout(game_offset: Vector2, game_size: Vector2) -> Dictionary:
	var helper: Object = Stage1PillarUiLayout.new()
	return helper.build_layout(game_offset, game_size, {"height": 750.0})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
