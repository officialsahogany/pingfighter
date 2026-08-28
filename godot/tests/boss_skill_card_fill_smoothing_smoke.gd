extends SceneTree

# Renderer-only boss skill-card fill smoothing seal. GRT-060 authoritative
# progress/ready/trigger payloads remain untouched; only the nine stage rail
# renderers own and advance these display dictionaries.

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")

const DISABLE_SMOOTHING_FIXTURE_ENV := "BOSS_SKILL_CARD_DISABLE_FILL_SMOOTHING_FIXTURE"
const FRAME_DT := 1.0 / 60.0
const STEP_SAMPLE_COUNT := 60
const EPSILON := 0.0001
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
var _motion_sample_count := 0
var _reached_frame := -1


func _init() -> void:
	_verify_sixty_frame_step_converges()
	_verify_decrease_and_time_reset_snap()
	_verify_store_prune_excludes_lingpet()
	_verify_all_renderers_route_through_shared_helper()
	_verify_helper_has_no_catalog_or_resource_scan()

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print(
		"[BossSkillCardFillSmoothing] RENDERERS=%d STEP_SAMPLES=%d MOTION_SAMPLES=%d REACHED_FRAME=%d DURATION=%.3f RESET_SNAP=true PRUNE_REMOVED=true LINGPET_EXCLUDED=true"
		% [RENDERER_PATHS.size(), STEP_SAMPLE_COUNT, _motion_sample_count, _reached_frame, BossSkillCardHudSpec.CARD_FILL_DURATION]
	)
	print(
		"[BossSkillCardFillSmoothing] INCREASE=renderer_only_critical_damping DECREASE=authority_snap PAYLOAD_UNCHANGED=true NO_CATALOG_SCAN=true NEGATIVE_FIXTURE_ENV=%s"
		% DISABLE_SMOOTHING_FIXTURE_ENV
	)
	print("boss_skill_card_fill_smoothing_smoke: ok")
	quit(0)


func _verify_sixty_frame_step_converges() -> void:
	var store := {}
	var time_seconds := 0.0
	var displayed := _advance(store, "alice_rabbit", 0.0, time_seconds)
	_expect(_near(displayed, 0.0), "new cards must initialize at the authoritative fill")

	time_seconds += FRAME_DT
	displayed = _advance(store, "alice_rabbit", 1.0, time_seconds)
	_expect(
		displayed < 1.0 - EPSILON,
		"an authority increase must not render as a one-frame step (counterfactual smoothing disabled)"
	)
	var previous := displayed
	for frame in range(1, STEP_SAMPLE_COUNT + 1):
		time_seconds += FRAME_DT
		displayed = _advance(store, "alice_rabbit", 1.0, time_seconds)
		_expect(is_finite(displayed), "smoothed fill must stay finite at frame %d" % frame)
		_expect(
			displayed + EPSILON >= previous,
			"authority increase must remain monotone at frame %d: %.6f -> %.6f" % [frame, previous, displayed]
		)
		_expect(displayed <= 1.0 + EPSILON, "smoothed fill must not overshoot authority at frame %d" % frame)
		if displayed > previous + EPSILON:
			_motion_sample_count += 1
		if _reached_frame < 0 and _near(displayed, 1.0):
			_reached_frame = frame
		previous = displayed
	_expect(_motion_sample_count >= 10, "a full fill step must expose adjacent subsecond motion samples")
	_expect(_reached_frame > 0 and _reached_frame <= 24, "a fixed authority target must converge in 0.2-0.4 seconds")
	_expect(_near(displayed, 1.0), "+60 samples must end exactly on the authority target")


func _verify_decrease_and_time_reset_snap() -> void:
	var store := {}
	BossSkillCardHudSpec.advance_card_fill(store, "cast_reset", 0.0, 2.0)
	BossSkillCardHudSpec.advance_card_fill(store, "cast_reset", 1.0, 2.0 + FRAME_DT)
	var mid := BossSkillCardHudSpec.advance_card_fill(store, "cast_reset", 1.0, 2.15)
	_expect(mid > 0.0 and mid < 1.0, "increase fixture must be mid-tween before cast reset")
	var reset := BossSkillCardHudSpec.advance_card_fill(store, "cast_reset", 0.0, 2.15 + FRAME_DT)
	_expect(_near(reset, 0.0), "cast/decrease reset must snap immediately to authority")

	BossSkillCardHudSpec.advance_card_fill(store, "clock_reset", 0.2, 10.0)
	BossSkillCardHudSpec.advance_card_fill(store, "clock_reset", 0.8, 10.1)
	var rewound := BossSkillCardHudSpec.advance_card_fill(store, "clock_reset", 0.8, 1.0)
	_expect(_near(rewound, 0.8), "a reset timebase must snap instead of leaving a stale tween")


func _verify_store_prune_excludes_lingpet() -> void:
	var store := {
		"keep": {"target_fill": 0.4},
		"removed": {"target_fill": 0.7},
		"maribo_hydro_sphere": {"target_fill": 0.9},
	}
	BossSkillCardHudSpec.prune_card_fill_store(store, [
		{"id": "keep"},
		{"id": "maribo_hydro_sphere", "is_lingpet": true},
	])
	_expect(store.has("keep"), "fill prune must keep present boss cards")
	_expect(not store.has("removed"), "fill prune must remove cards no longer in the rail")
	_expect(not store.has("maribo_hydro_sphere"), "boss fill store must exclude the lingpet rail rider")

	var shuffle_store := {"keep": {}, "removed": {}, "maribo_hydro_sphere": {}}
	var combined_fill_store := {"keep": {}, "removed": {}, "maribo_hydro_sphere": {}}
	BossSkillCardHudSpec.prune_card_stores(shuffle_store, combined_fill_store, [
		{"id": "keep"},
		{"id": "maribo_hydro_sphere", "is_lingpet": true},
	])
	_expect(shuffle_store.has("keep") and shuffle_store.has("maribo_hydro_sphere"), "combined prune must keep every rail rider in shuffle state")
	_expect(not shuffle_store.has("removed"), "combined prune must remove stale shuffle cards")
	_expect(combined_fill_store.has("keep"), "combined prune must keep present boss fill state")
	_expect(not combined_fill_store.has("removed"), "combined prune must remove stale boss fill state")
	_expect(not combined_fill_store.has("maribo_hydro_sphere"), "combined prune must exclude lingpet fill state")


func _verify_all_renderers_route_through_shared_helper() -> void:
	for path in RENDERER_PATHS:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.is_empty(), "renderer source must be readable: %s" % path)
		_expect(source.count("BossSkillCardHudSpec.advance_card_fill(") == 1, "renderer must route fill exactly once: %s" % path)
		_expect(source.find("_card_fills") >= 0, "renderer must own its display-only fill store: %s" % path)
		_expect(
			source.find("prune_card_fill_store") >= 0 or source.find("prune_card_stores") >= 0,
			"renderer must prune its fill store: %s" % path
		)


func _verify_helper_has_no_catalog_or_resource_scan() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
	var start := source.find("static func advance_card_fill(")
	var finish := source.find("static func _snap_card_fill_state", start)
	_expect(start >= 0 and finish > start, "shared fill helper source slice must be discoverable")
	if start < 0 or finish <= start:
		return
	var helper_source := source.substr(start, finish - start)
	for forbidden in ["DirAccess", "FileAccess", "ResourceLoader", "load(", "preload(", "Catalog"]:
		_expect(helper_source.find(forbidden) < 0, "per-frame fill helper must not scan/load resources: %s" % forbidden)


func _advance(store: Dictionary, key: String, target: float, time_seconds: float) -> float:
	if OS.get_environment(DISABLE_SMOOTHING_FIXTURE_ENV) == "1":
		return target
	return BossSkillCardHudSpec.advance_card_fill(store, key, target, time_seconds)


func _near(value: float, target: float) -> bool:
	return absf(value - target) <= EPSILON


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
