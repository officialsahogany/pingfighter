extends SceneTree

# Verifies the player state-glow plumbing: the match-point danger query, the
# state precedence (danger > transform > none), and that the shared soft-glow
# texture bakes a feathered radial alpha (near-opaque center, ~0 corners). The
# glow is a soft alert aura behind the player body that only lights up on
# danger / transform; a regression here usually means the aura shows at the
# wrong time or the texture lost its falloff (hard disc / invisible).

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")
const PlayerStateGlowRenderer := preload("res://scripts/effects/player_state_glow_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_danger_query()
	_verify_state_precedence()
	_verify_soft_glow_texture()

	if _failures.is_empty():
		print("player_state_glow_renderer_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append("FAIL: " + msg)


func _verify_danger_query() -> void:
	var score: Object = MatchScoreState.new()
	score.reset()
	_expect(not score.is_player_in_danger(), "0-0 should not be danger")
	score.force_score(0, 4)
	_expect(score.is_player_in_danger(), "0-4 (boss at match point) should be danger")
	score.force_score(4, 4)
	_expect(not score.is_player_in_danger(), "4-4 deuce: boss at 4 needs 6, not danger yet")
	score.force_score(4, 5)
	_expect(score.is_player_in_danger(), "4-5 deuce: boss one from deuce goal 6 -> danger")
	score.force_score(5, 5)
	_expect(not score.is_player_in_danger(), "5-5 deuce: goal escalates to 7, boss at 5 not danger")
	score.force_score(5, 6)
	_expect(score.is_player_in_danger(), "5-6 deuce: boss one from goal 7 -> danger")
	score.force_score(3, 3)
	_expect(not score.is_player_in_danger(), "3-3 should not be danger")


func _verify_state_precedence() -> void:
	var renderer: Object = PlayerStateGlowRenderer.new()
	_expect(renderer.resolve_state({}) == PlayerStateGlowRenderer.STATE_NONE, "empty context -> no glow")
	_expect(
		renderer.resolve_state({"horn_strawberry_transformed": true}) == PlayerStateGlowRenderer.STATE_TRANSFORM,
		"transform only -> transform glow"
	)
	_expect(
		renderer.resolve_state({"player_in_danger": true}) == PlayerStateGlowRenderer.STATE_DANGER,
		"danger only -> danger glow"
	)
	_expect(
		renderer.resolve_state({"player_in_danger": true, "horn_strawberry_transformed": true}) == PlayerStateGlowRenderer.STATE_DANGER,
		"danger should take precedence over transform"
	)


func _verify_soft_glow_texture() -> void:
	var tex: Texture2D = SoftGlowTexture.get_texture(48)
	_expect(tex != null, "soft glow texture should build")
	if tex == null:
		return
	_expect(int(tex.get_width()) == 48 and int(tex.get_height()) == 48, "soft glow texture size should match request")
	var img: Image = tex.get_image()
	_expect(img != null, "soft glow texture should expose its image")
	if img == null:
		return
	var center_a: float = img.get_pixel(24, 24).a
	var corner_a: float = img.get_pixel(0, 0).a
	_expect(center_a > 0.85, "center alpha should read near opaque (got %f)" % center_a)
	_expect(corner_a < 0.02, "corner alpha should feather to ~0 (got %f)" % corner_a)
	_expect(SoftGlowTexture.get_texture(48) == tex, "soft glow texture should be cached by size")
