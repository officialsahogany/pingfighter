extends SceneTree

# Seals the Phase 1 reactive pillar portrait wiring:
#  (1) stage1_pillar_hud_scene_drawer._resolve_portrait_expressions — live stun +
#      per-point score state -> boss/player face, with result outranking stun and
#      the score pulse gated on scoreboard.is_active().
#  (2) right_pillar_portrait_renderer.compute_boxes — two non-overlapping boxes that
#      sit inside the band between the boss orb (top) and player orb (bottom), and
#      ok=false when the band is too short (draw-time capacity discipline).
#  (3) the shipped Dalji portrait atlas imports as the expected 2x2 texture size.

const Stage1PillarHudSceneDrawer := preload("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
const RightPillarPortraitRenderer := preload("res://scripts/hud/right_pillar_portrait_renderer.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")
const ScoreboardState := preload("res://scripts/hud/scoreboard_state.gd")
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const DALJI_PORTRAIT_PATH := "res://assets/sprites/stage1/dalji/dalji_boss_portrait_2x2.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_expression_resolver()
	_verify_face_resolution()
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


func _verify_face_resolution() -> void:
	var drawer: Object = Stage1PillarHudSceneDrawer.new()
	var portrait_sheet: Texture2D = PlaceholderTexture2D.new()
	var textures: Dictionary = {
		"boss_portrait_sheet": portrait_sheet,
	}

	_expect(
		FileAccess.file_exists(DALJI_PORTRAIT_PATH),
		"portrait sheet file should exist"
	)
	var loaded_portrait := load(DALJI_PORTRAIT_PATH) as Texture2D
	_expect(loaded_portrait != null, "portrait sheet should import as Texture2D")
	if loaded_portrait != null:
		_expect(loaded_portrait.get_size() == Vector2(1456.0, 1456.0), "portrait sheet should keep four 728x728 cells")

	var neutral: Dictionary = drawer._resolve_portrait_face(textures, "dalji", "neutral")
	_expect(not neutral.is_empty(), "dalji neutral face should resolve")
	_expect(neutral.get("texture") == portrait_sheet, "dalji neutral face should use boss_portrait_sheet")
	_expect(int(neutral.get("frame", -1)) == 0, "neutral should map to frame 0")
	_expect(int(neutral.get("cols", -1)) == 2, "portrait sheet should use cols=2")
	_expect(int(neutral.get("rows", -1)) == 2, "portrait sheet should use rows=2")
	_expect(_rect_equal(_get_rect2(neutral.get("head_source_rect", Rect2())), Rect2(0.11, 0.0, 0.78, 0.89)), "neutral head crop should match expected portrait inset")
	_expect(_is_white_tint(neutral.get("tint", Color())), "neutral tint should be Color.WHITE")

	var pained: Dictionary = drawer._resolve_portrait_face(textures, "dalji", "pained")
	_expect(not pained.is_empty(), "dalji pained face should resolve")
	_expect(int(pained.get("frame", -1)) == 1, "pained should map to frame 1")
	_expect(_is_white_tint(pained.get("tint", Color())), "pained tint should be Color.WHITE")

	var happy: Dictionary = drawer._resolve_portrait_face(textures, "dalji", "happy")
	_expect(not happy.is_empty(), "dalji happy face should resolve")
	_expect(int(happy.get("frame", -1)) == 2, "happy should map to frame 2")
	_expect(_is_white_tint(happy.get("tint", Color())), "happy tint should be Color.WHITE")

	var sad: Dictionary = drawer._resolve_portrait_face(textures, "dalji", "sad")
	_expect(not sad.is_empty(), "dalji sad face should resolve")
	_expect(int(sad.get("frame", -1)) == 3, "sad should map to frame 3")
	_expect(_is_white_tint(sad.get("tint", Color())), "sad tint should be Color.WHITE")

	var missing_identity: Dictionary = drawer._resolve_portrait_face(textures, "smasher", "neutral")
	_expect(missing_identity.is_empty(), "non-dalji identity should not resolve a portrait face")

	var missing_texture: Dictionary = drawer._resolve_portrait_face({}, "dalji", "neutral")
	_expect(missing_texture.is_empty(), "missing portrait texture should produce empty face data")


func _rect_equal(lhs: Rect2, rhs: Rect2) -> bool:
	return is_equal_approx(lhs.position.x, rhs.position.x) \
		and is_equal_approx(lhs.position.y, rhs.position.y) \
		and is_equal_approx(lhs.size.x, rhs.size.x) \
		and is_equal_approx(lhs.size.y, rhs.size.y)


func _get_rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _is_white_tint(value: Variant) -> bool:
	if not (value is Color):
		return false
	var tint := value as Color
	return tint == Color.WHITE


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
