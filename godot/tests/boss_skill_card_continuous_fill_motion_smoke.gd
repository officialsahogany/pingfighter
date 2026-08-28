extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

const FRAME_DELTA_SEC := 1.0 / 60.0
const FRAME_COUNT := 72
const WARMUP_FRAME := 12
const TARGET_STEP := 0.003
const CARD_WIDTH_PX := 38.0
const MIN_CONTINUOUS_STEP_RATIO := 0.15
const RENDERER_PATHS := [
	"res://scripts/stages/stage1/stage1_dalji_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage1/stage1_gaksital_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage1/stage1_pododaejang_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage4/stage4_ponk_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage5/stage5_hongryun_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd",
	"res://scripts/stages/stage7/stage7_akamu_boss_skill_hud_renderer.gd",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_all_production_renderers_use_shared_fill_owner()
	_verify_continuous_authority_never_periodically_stalls()
	_verify_jump_smoothing_and_reverse_snap()

	if _failures.is_empty():
		print("boss_skill_card_continuous_fill_motion_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_all_production_renderers_use_shared_fill_owner() -> void:
	for path in RENDERER_PATHS:
		var source := FileAccess.get_file_as_string(path)
		_expect(
			source.contains("BossSkillCardHudSpec.advance_card_fill("),
			"production renderer must use the shared card-fill owner: %s" % path
		)


func _verify_continuous_authority_never_periodically_stalls() -> void:
	# This deliberately isolates the three suspects. It uses one synthetic,
	# monotonic time source and calls the shared owner every frame without a
	# renderer or draw-budget gate. A periodic stall here can only come from the
	# fill interpolation state being restarted while its target keeps advancing.
	var store := {}
	var samples: Array[Dictionary] = []
	var previous_display := BossSkillCardHudSpec.advance_card_fill(
		store,
		"linear_cooldown",
		0.10,
		0.0
	)
	var min_step := INF
	var max_step := 0.0
	for frame in range(1, FRAME_COUNT + 1):
		var time_seconds := float(frame) * FRAME_DELTA_SEC
		var target := 0.10 + float(frame) * TARGET_STEP
		var displayed := BossSkillCardHudSpec.advance_card_fill(
			store,
			"linear_cooldown",
			target,
			time_seconds
		)
		var step := displayed - previous_display
		var sample := {
			"frame": frame,
			"time": snappedf(time_seconds, 0.000001),
			"target": snappedf(target, 0.000001),
			"display": snappedf(displayed, 0.000001),
			"edge_x": snappedf(displayed * CARD_WIDTH_PX, 0.000001),
			"step": snappedf(step, 0.000001),
		}
		samples.append(sample)
		if frame >= WARMUP_FRAME:
			min_step = minf(min_step, step)
			max_step = maxf(max_step, step)
		previous_display = displayed

	print(
		"Z6_CONTINUOUS_FILL single_time_source=true draw_budget_gate=false frames=%d min_step=%.8f max_step=%.8f samples=%s"
		% [FRAME_COUNT, min_step, max_step, JSON.stringify(samples)]
	)
	_expect(samples.size() >= 10, "continuous motion seal must log at least 10 adjacent frames")
	_expect(
		min_step >= TARGET_STEP * MIN_CONTINUOUS_STEP_RATIO,
		"continuous authority should not periodically ease to a stop (min %.8f, target step %.8f)"
		% [min_step, TARGET_STEP]
	)
	_expect(
		max_step <= TARGET_STEP * 1.05,
		"displayed fill should not overshoot the monotonic authority step"
	)


func _verify_jump_smoothing_and_reverse_snap() -> void:
	var store := {}
	var initial := BossSkillCardHudSpec.advance_card_fill(store, "jump", 0.0, 0.0)
	var first := BossSkillCardHudSpec.advance_card_fill(
		store,
		"jump",
		0.80,
		FRAME_DELTA_SEC
	)
	_expect(is_equal_approx(initial, 0.0), "jump fixture should start at zero")
	_expect(first > 0.0 and first < 0.80, "authority jump should be visibly smoothed")
	var previous := first
	var samples: Array[float] = [first]
	for frame in range(2, 20):
		var displayed := BossSkillCardHudSpec.advance_card_fill(
			store,
			"jump",
			0.80,
			float(frame) * FRAME_DELTA_SEC
		)
		_expect(displayed >= previous, "smoothed jump should remain monotonic")
		samples.append(displayed)
		previous = displayed
	print("Z6_JUMP_FILL frames=%d samples=%s" % [samples.size(), JSON.stringify(samples)])
	_expect(previous >= 0.79, "0.30-second jump smoothing should settle within 1% of authority")
	var reset := BossSkillCardHudSpec.advance_card_fill(store, "jump", 0.20, 0.35)
	_expect(is_equal_approx(reset, 0.20), "decreasing authority should still snap immediately")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
