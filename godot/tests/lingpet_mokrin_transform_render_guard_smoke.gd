extends SceneTree

# S1b-a seal — 묵린변신 렌더 표면 + 가드 통지.
#
# Scope: D7 (surface-router cast-pose registration), D5 (module cast-pose
# progress through the REAL host+router chain), D5c (WALK -6 -> CAST -12
# 6px pop absorption via the per-profile positive delta), E1-③ (launch-flash
# ink palette by style string, shipped cyan byte-identical for everyone else),
# E' X1~X3 (base-paddle guard notify through the REAL paddle-bounce event
# router, placed BEFORE the AIPill early return, thor-shield / clone bounces
# filtered) and ㉯ (guard stage ladder 1/2/3, entry SFX exactly once).
#
# NOT here (S1b-b): the baekrin catalog entry, asset promotion, and the live
# normal->f1 / f12->normal pixel QA (운영 렌더 필요).

const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LingpetMokrinTransformSkill := preload("res://scripts/lingpet/lingpet_mokrin_transform_skill.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")

const SKILL_ID := "baekrin_mokrin_transform"
const DT := 1.0 / 60.0

var _failed := false


class FakeAudio:
	extends RefCounted
	var active_item_count := 0

	func play_active_item() -> void:
		active_item_count += 1


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeAipillRuntime:
	extends RefCounted
	var drain_calls := 0

	func is_aipill_active() -> bool:
		return true

	func apply_aipill_guard_drain(special_gauge: float, _context: Dictionary, _deps: Dictionary) -> float:
		drain_calls += 1
		return maxf(0.0, special_gauge - 90.0)


class StubProfile:
	extends RefCounted
	var layout: Dictionary = {}
	var textures: Dictionary = {}

	func get_visual_texture(visual_key: String, fallback: Texture2D = null) -> Texture2D:
		return textures.get(visual_key, fallback)

	func get_visual_layout_value(layout_key: String, fallback: float = 0.0) -> float:
		return float(layout.get(layout_key, fallback))

	func get_display_name() -> String:
		return "baekrin"


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  ok: %s" % label)
	else:
		_failed = true
		printerr("  FAIL: %s" % label)


func _run() -> void:
	_test_cast_pose_chain()
	_test_draw_context_threading()
	_test_puppet_y_offset_delta()
	_test_flash_palette()
	_test_guard_notify_through_router()
	_test_guard_stage_ladder()
	if _failed:
		printerr("lingpet_mokrin_transform_render_guard_smoke: FAILED")
		quit(1)
		return
	print("lingpet_mokrin_transform_render_guard_smoke: ok")
	quit(0)


# ---- D7 + D5: cast pose progress through host + surface router --------------
func _test_cast_pose_chain() -> void:
	print("[D7/D5 cast pose chain]")
	var host: Object = LingpetSkillRuntimeHost.new()
	_expect(
		is_equal_approx(float(host.get_companion_cast_pose_progress(SKILL_ID)), -1.0),
		"inactive module -> cast pose -1 (normal body)"
	)
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	_expect(
		is_equal_approx(float(host.get_companion_cast_pose_progress(SKILL_ID)), 0.0),
		"launch frame -> progress 0.0"
	)
	for i in range(18):  # 0.30s
		host.update(DT, null, null, SKILL_ID, {})
	var mid: float = float(host.get_companion_cast_pose_progress(SKILL_ID))
	_expect(mid > 0.40 and mid < 0.60, "0.30s -> progress ~0.5 (got %.3f)" % mid)
	for i in range(30):  # +0.50s => 0.80s total
		host.update(DT, null, null, SKILL_ID, {})
	_expect(
		is_equal_approx(float(host.get_companion_cast_pose_progress(SKILL_ID)), 1.0),
		"past 0.60s -> progress held at 1.0 (f12 hold, ㉮)"
	)
	for i in range(280):  # push past 5.0s expiry
		host.update(DT, null, null, SKILL_ID, {})
	_expect(
		is_equal_approx(float(host.get_companion_cast_pose_progress(SKILL_ID)), -1.0),
		"expiry -> cast pose off again"
	)


# ---- draw-context threading (builder integration) ---------------------------
func _test_draw_context_threading() -> void:
	print("[draw-context threading]")
	var host: Object = LingpetSkillRuntimeHost.new()
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	for i in range(60):  # 1.0s: progress held at 1.0
		host.update(DT, null, null, SKILL_ID, {})
	var profile := StubProfile.new()
	var puppet_tex := ImageTexture.create_from_image(Image.create(12, 4, false, Image.FORMAT_RGBA8))
	profile.textures["companion_puppet_control"] = puppet_tex
	profile.layout = {
		"companion_puppet_control_cols": 6.0,
		"companion_puppet_control_rows": 2.0,
		"companion_puppet_control_frame_count": 12.0,
		"companion_puppet_control_draw_size": 92.0,
		"companion_puppet_control_y_offset_delta": 6.0,
	}
	var builder: Object = LingpetCompanionDrawContextBuilder.new()
	var config: Dictionary = builder.build_config({
		"companion_active": true,
		"skill_runtime_host": host,
		"current_profile": profile,
		"skill_id": SKILL_ID,
		"companion_skill_flash_style": "mokrin_ink",
	})
	_expect(bool(config.get("skill_cast_pose_active", false)), "cast pose active in draw config")
	_expect(config.get("cast_texture", null) == puppet_tex, "puppet_control texture selected (D5a route)")
	_expect(is_equal_approx(float(config.get("windup_elapsed", -9.9)), 1.0), "windup_elapsed carries the held progress")
	_expect(is_equal_approx(float(config.get("windup_seconds", -9.9)), 1.0), "windup_seconds normalized to 1.0")
	_expect(int(config.get("companion_puppet_control_cols", 0)) == 6, "grid meta cols=6 threaded (D5a)")
	_expect(int(config.get("companion_puppet_control_rows", 0)) == 2, "grid meta rows=2 threaded (D5a)")
	_expect(int(config.get("companion_puppet_control_frame_count", 0)) == 12, "grid meta frame_count=12 threaded (D5a)")
	_expect(is_equal_approx(float(config.get("companion_puppet_control_y_offset_delta", 0.0)), 6.0), "positive delta survives the float clamp (D5c)")
	_expect(str(config.get("companion_skill_flash_style", "")) == "mokrin_ink", "flash style string rides the params channel, not visual_layout (E1-3)")
	_expect(is_equal_approx(float(config.get("cast_draw_size", 0.0)), 92.0), "puppet_control draw size override wins")


# ---- D5c: 6px pop absorption -------------------------------------------------
func _test_puppet_y_offset_delta() -> void:
	print("[D5c puppet Y-offset delta]")
	var base := Rect2(Vector2(100.0, 200.0), Vector2(92.0, 92.0))
	var no_key: Rect2 = LingpetCompanionRenderer.apply_puppet_control_y_offset_delta(base, "companion_puppet_control", {})
	_expect(no_key == base, "no delta key -> rect untouched (existing pets preserved)")
	var other_key: Rect2 = LingpetCompanionRenderer.apply_puppet_control_y_offset_delta(
		base, "companion_walk", {"companion_puppet_control_y_offset_delta": 6.0}
	)
	_expect(other_key == base, "delta never leaks onto non-puppet keys")
	var applied: Rect2 = LingpetCompanionRenderer.apply_puppet_control_y_offset_delta(
		base, "companion_puppet_control", {"companion_puppet_control_y_offset_delta": 6.0}
	)
	_expect(is_equal_approx(applied.position.y, 206.0), "puppet key + delta 6 -> +6px down")

	# Composition against the REAL animator offsets: with delta 6 the CAST dest Y
	# must equal the WALK dest Y (-12 + 6 == -6), which is the whole point of D5c.
	var animator: Object = LingpetCompanionSpriteAnimator.new()
	var tex := ImageTexture.create_from_image(Image.create(12, 4, false, Image.FORMAT_RGBA8))
	var center := Vector2(380.0, 640.0)
	var cast_rects: Dictionary = animator.build_draw_rects(
		tex, LingpetCompanionSpriteAnimator.MODE_CAST, center, 0.0, 1.0, 1.0, 0.0, Vector2(92.0, 92.0), {}
	)
	var walk_rects: Dictionary = animator.build_draw_rects(
		tex, LingpetCompanionSpriteAnimator.MODE_WALK, center, 0.0, 0.0, 0.0, 0.0, Vector2(92.0, 92.0), {}
	)
	var cast_dest: Rect2 = LingpetCompanionRenderer.apply_puppet_control_y_offset_delta(
		cast_rects.get("dest", Rect2()),
		"companion_puppet_control",
		{"companion_puppet_control_y_offset_delta": 6.0}
	)
	var walk_dest: Rect2 = walk_rects.get("dest", Rect2())
	_expect(
		is_equal_approx(cast_dest.position.y, walk_dest.position.y),
		"delta 6 makes CAST land on the WALK baseline (no 6px pop at the seam)"
	)


# ---- E1-③: flash palette -----------------------------------------------------
func _test_flash_palette() -> void:
	print("[E1-3 flash palette]")
	var default_palette: Dictionary = LingpetCompanionRenderer.resolve_skill_flash_palette("")
	_expect(
		default_palette.get("fill", Color()) == Color(0.24, 0.92, 1.0)
		and default_palette.get("arc", Color()) == Color(0.72, 1.0, 1.0)
		and default_palette.get("burst", Color()) == Color(0.54, 1.0, 1.0),
		"empty style == shipped cyan trio, byte-identical"
	)
	var unknown_palette: Dictionary = LingpetCompanionRenderer.resolve_skill_flash_palette("some_future_style")
	_expect(unknown_palette == default_palette, "unknown style falls back to the default trio")
	var ink_palette: Dictionary = LingpetCompanionRenderer.resolve_skill_flash_palette("mokrin_ink")
	_expect(ink_palette != default_palette, "mokrin_ink diverges from cyan")
	var ink_fill: Color = ink_palette.get("fill", Color())
	_expect(
		ink_fill.r < 0.3 and ink_fill.g < 0.3 and ink_fill.b < 0.3,
		"ink fill reads dark (먹빛), not a bright hue"
	)


# ---- E' X1~X3: guard notify through the REAL event router --------------------
func _test_guard_notify_through_router() -> void:
	print("[E' guard notify through the real router]")
	var router: Object = PaddleBounceEventRouter.new()
	var egg_runtime: Object = LingpetEggRuntime.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.instances["game_audio"] = audio
	var deps: Dictionary = {
		"lingpet_egg_runtime": egg_runtime,
		"registry": registry,
	}

	# Transform inactive: a base hit must not count or fire anything.
	router.register_player_hit(Vector2(380.0, 640.0), 0.5, false, false, 100.0, {}, deps)
	_expect(audio.active_item_count == 0, "inactive transform -> no guard SFX")

	egg_runtime.launch_mokrin_transform_for_tests()

	# X3: thor-shield and clone bounces flow through the same path with marker
	# flags — they must NOT count.
	router.register_player_hit(Vector2.ZERO, 0.5, false, false, 100.0, {"blacksmith_thor_shield_hit": true}, deps)
	_expect(audio.active_item_count == 0, "thor shield bounce filtered (X3)")
	router.register_player_hit(Vector2.ZERO, 0.5, false, false, 100.0, {"viper_dual_glitch_clone_hit": true}, deps)
	_expect(audio.active_item_count == 0, "dual-glitch clone bounce filtered (X3)")

	# Base hit counts: stage 1 entry SFX.
	router.register_player_hit(Vector2.ZERO, 0.5, false, false, 100.0, {}, deps)
	_expect(audio.active_item_count == 1, "base-paddle guard #1 -> stage 1 entry SFX")

	# X2: with the AIPill co-active the router early-returns after the drain —
	# the mokrin notify must have run BEFORE that return.
	var aipill := FakeAipillRuntime.new()
	deps["active_item_runtime"] = aipill
	var drained: float = router.register_player_hit(Vector2.ZERO, 0.5, false, false, 100.0, {}, deps)
	_expect(aipill.drain_calls == 1 and drained < 100.0, "aipill path still drains (control)")
	_expect(audio.active_item_count == 2, "guard #2 counted DESPITE the aipill early return (X2)")


# ---- ㉯: guard stage ladder ---------------------------------------------------
func _test_guard_stage_ladder() -> void:
	print("[guard stage ladder]")
	var module: Object = LingpetMokrinTransformSkill.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new()
	registry.instances["game_audio"] = audio

	module.notify_player_guard(registry)
	_expect(int(module.get_guard_count()) == 0 and audio.active_item_count == 0,
		"inactive module ignores guards entirely")

	module.launch(Vector2.ZERO, null, {})
	module.notify_player_guard(registry)
	module.notify_player_guard(registry)
	module.notify_player_guard(registry)
	_expect(int(module.get_guard_count()) == 3 and int(module.get_guard_stage()) == 3,
		"three guards -> stage 3")
	_expect(audio.active_item_count == 3, "stage entries 1/2/3 each fired one SFX")
	module.notify_player_guard(registry)
	module.notify_player_guard(registry)
	_expect(int(module.get_guard_count()) == 5 and int(module.get_guard_stage()) == 3,
		"counts keep rising but the stage caps at 3")
	_expect(audio.active_item_count == 3, "no re-fire at the capped stage (㉯)")
	module.reset()
	_expect(int(module.get_guard_count()) == 0 and int(module.get_guard_stage()) == 0,
		"reset clears the ladder with the window")
