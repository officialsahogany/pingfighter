extends SceneTree

# S1a registration seal — 묵린변신 (mokrin_transform) runtime_kind 등재 + D15 브리지.
#
# Scope (docs/lingpet_mokrin_runtime_kind_registration_matrix.md, S1a slice):
#   A1/A2/A3 dispatcher registration, B1~B9 host lifecycle fanout, C1 launch,
#   C2 relaunch block, C4 liveness through the REAL effect-update gate,
#   E2 aggregate snapshot merge, D14 reset boundaries, and the D15 bridge
#   (egg-runtime narrow predicate -> fail-closed deps Callable -> smasher
#   consumption + viper early-return yield).
#
# Deliberately NOT here (S1b): catalog entry (A5), render surfaces (D5/D5a/D5c/D7),
# ink flash palette (E1-3), guard notify (E' X1~X4), and the FULL frame-flow
# activation seal ("운영 launch가 update_lingpet에서 성립한 뒤 다음
# update_player_control이 처음 소비") — that leg needs a catalog-enabled baekrin
# profile, so this file seals the same ordering at the controller/host level and
# S1b upgrades it to the real frame flow.

const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LingpetCompanionSkillController := preload("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
const LingpetCompanionSkillState := preload("res://scripts/lingpet/lingpet_companion_skill_state.gd")
const LingpetCompanionSkillEffectUpdateGate := preload("res://scripts/lingpet/lingpet_companion_skill_effect_update_gate.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const BattleUpdatePlayerControlDepsBuilder := preload("res://scripts/core/battle_update_player_control_deps_builder.gd")
const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")
const ViperPlayerController := preload("res://scripts/characters/viper_player_controller.gd")

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


class SpyViperSkillRuntime:
	extends RefCounted
	var call_count := 0

	func try_activate_before_movement(_delta: float, player_pos: Vector2, _gauge: float, _config: Dictionary, _deps: Dictionary) -> Dictionary:
		call_count += 1
		return {"handled": true, "player_pos": player_pos}


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  ok: %s" % label)
	else:
		_failed = true
		printerr("  FAIL: %s" % label)


func _run() -> void:
	_test_dispatcher_registration()
	_test_host_launch_and_relaunch_block()
	_test_controller_arm_gate_and_launch_order()
	_test_liveness_through_real_effect_gate()
	_test_natural_expiry_timing()
	_test_reset_boundaries()
	_test_production_reset_boundaries()
	_test_aggregate_snapshot_merge()
	_test_d15_predicate_and_fail_closed()
	_test_d15_smasher_consumption_chain()
	_test_d15_viper_early_return_yields()
	if _failed:
		printerr("lingpet_mokrin_transform_registration_smoke: FAILED")
		quit(1)
		return
	print("lingpet_mokrin_transform_registration_smoke: ok")
	quit(0)


# ---- A1/A2/A3 ---------------------------------------------------------------
func _test_dispatcher_registration() -> void:
	print("[dispatcher registration]")
	_expect(
		LingpetSkillDispatcher.get_skill_kind(SKILL_ID) == LingpetSkillDispatcher.SKILL_KIND_MOKRIN_TRANSFORM,
		"skill id resolves to the mokrin_transform kind (A1/A3)"
	)
	_expect(
		LingpetSkillDispatcher.is_supported_kind(LingpetSkillDispatcher.SKILL_KIND_MOKRIN_TRANSFORM),
		"kind is in SUPPORTED_SKILL_KINDS (A2 — unlisted would demote to NONE)"
	)
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "has_supported_runtime true")
	_expect(LingpetSkillDispatcher.is_mokrin_transform(SKILL_ID), "is_mokrin_transform helper")
	_expect(
		LingpetSkillDispatcher.get_exclusive_resource_classes(SKILL_ID).is_empty(),
		"no exclusive resource class (A6 N/A — no ball owner, no pos override)"
	)
	_expect(
		not LingpetSkillDispatcher.would_share_module(SKILL_ID, "monkeyring_banana_slice"),
		"unique kind shares no module with siblings (A4)"
	)


# ---- C1 / C2 (host surface) -------------------------------------------------
func _test_host_launch_and_relaunch_block() -> void:
	print("[host launch + relaunch block]")
	var host: Object = LingpetSkillRuntimeHost.new()
	_expect(not bool(host.is_launch_blocked(SKILL_ID)), "fresh host: launch not blocked")
	_expect(not bool(host.is_mokrin_transform_active()), "fresh host: peek inactive (no instantiation)")
	_expect(bool(host.launch(SKILL_ID, Vector2.ZERO, null, {})), "first launch succeeds (C1)")
	_expect(bool(host.is_mokrin_transform_active()), "peek active after launch")
	_expect(bool(host.is_launch_blocked(SKILL_ID)), "relaunch blocked while active (C2)")
	_expect(not bool(host.launch(SKILL_ID, Vector2.ZERO, null, {})), "module-level relaunch also fails")
	host.reset()
	_expect(not bool(host.is_launch_blocked(SKILL_ID)), "after reset: unblocked again")


# ---- C2 through the REAL controller gate + launch ordering ------------------
func _test_controller_arm_gate_and_launch_order() -> void:
	print("[controller arm gate + launch order]")
	var host: Object = LingpetSkillRuntimeHost.new()
	var controller: Object = LingpetCompanionSkillController.new()
	var skill_state: Object = LingpetCompanionSkillState.new()
	var registry := FakeRegistry.new()
	var audio := FakeAudio.new()
	registry.instances["game_audio"] = audio

	var params := _build_controller_params(host, skill_state, registry)
	var decision: Dictionary = controller.update(DT, params)
	_expect(str(decision.get("action", "")) == "arm", "idle module + clean gates -> ARM (positive control)")

	controller.arm_windup(skill_state, host, SKILL_ID)
	_expect(bool(skill_state.windup_active), "windup armed")
	decision = controller.update(1.0, params)
	_expect(str(decision.get("action", "")) == "launch", "windup elapsed -> LAUNCH action")
	var launched: bool = controller.complete_launch(
		skill_state, host, SKILL_ID, Vector2.ZERO, 40.0, 0.25, registry, null, {}
	)
	_expect(launched, "complete_launch succeeds through the host (C1)")
	_expect(bool(host.is_mokrin_transform_active()), "module active after production launch path")
	_expect(float(skill_state.cooldown) > 0.0, "cooldown started by persistence state (host does not own it)")

	# C2 through the REAL _should_arm chain: while active, no new ARM even with
	# cooldown zeroed (isolates the is_launch_blocked gate from the cooldown gate).
	skill_state.cooldown = 0.0
	decision = controller.update(DT, params)
	_expect(str(decision.get("action", "")) != "arm", "active window blocks re-arm through _should_arm (C2)")

	# Cooldown non-refund at the ownership boundary: the host teardown must not
	# touch the persistence-owned skill state (D14 쿨다운 비환불의 모듈 측 절반 —
	# per-pet preservation itself is companion_skill_persistence's own seal).
	skill_state.cooldown = 33.0
	host.reset()
	_expect(is_equal_approx(float(skill_state.cooldown), 33.0),
		"host reset leaves the persistence-owned cooldown untouched")


# ---- C4 liveness through the REAL effect-update gate ------------------------
func _test_liveness_through_real_effect_gate() -> void:
	print("[liveness through real can_skip_idle gate]")
	var host: Object = LingpetSkillRuntimeHost.new()
	var gate: Object = LingpetCompanionSkillEffectUpdateGate.new()
	var skill_state: Object = LingpetCompanionSkillState.new()
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	skill_state.cooldown = 40.0
	_expect(
		not bool(host.has_visible_effects_for_skill(SKILL_ID)),
		"active module has ZERO visible effects (the trap precondition)"
	)
	_expect(
		not bool(gate.can_skip_idle(SKILL_ID, skill_state, false, host)),
		"gate must NOT skip while the invisible window is live (C4 via is_active)"
	)
	# Tick to expiry THROUGH the host update entry (B6), then the gate may skip.
	for i in range(310):
		host.update(DT, null, null, SKILL_ID, {})
	_expect(not bool(host.is_mokrin_transform_active()), "window expired after ~5.17s of host ticks")
	_expect(
		bool(gate.can_skip_idle(SKILL_ID, skill_state, false, host)),
		"gate skips again once the window is gone (cooldown-idle frames)"
	)


# ---- natural expiry timing --------------------------------------------------
func _test_natural_expiry_timing() -> void:
	print("[natural expiry timing]")
	var host: Object = LingpetSkillRuntimeHost.new()
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	var elapsed := 0.0
	while elapsed < 4.9:
		host.update(DT, null, null, SKILL_ID, {})
		elapsed += DT
	_expect(bool(host.is_mokrin_transform_active()), "still active at ~4.9s")
	while elapsed < 5.2:
		host.update(DT, null, null, SKILL_ID, {})
		elapsed += DT
	_expect(not bool(host.is_mokrin_transform_active()), "expired shortly after 5.0s")
	# Timer advances only via update(): parked module must not decay on its own.
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	_expect(bool(host.is_mokrin_transform_active()), "relaunch after expiry succeeds (no cooldown in module)")


# ---- D14 boundaries through the host fanout ---------------------------------
func _test_reset_boundaries() -> void:
	print("[D14 reset boundaries]")
	var host: Object = LingpetSkillRuntimeHost.new()

	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	host.reset()
	_expect(not bool(host.is_mokrin_transform_active()), "full reset clears the window (B2)")

	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	host.reset_round()
	_expect(not bool(host.is_mokrin_transform_active()), "round reset clears the window (B5 — no reset_round persistence)")

	# Default-signature stow only: the preserve_nekuring_deployments parameter is
	# uncommitted Nekuring WIP, and this seal must stay self-contained against the
	# S1a commit tree. The "preserve branch still clears mokrin" leg belongs to the
	# Nekuring integration seal that lands WITH that parameter.
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	host.end_for_stow()
	_expect(
		not bool(host.is_mokrin_transform_active()),
		"stow boundary clears mokrin (B3 delegation)"
	)

	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	host.clear_for_tests()
	_expect(not bool(host.is_mokrin_transform_active()), "clear_for_tests nulls the field (B4)")


# ---- D14 PRODUCTION boundaries through the egg runtime ----------------------
# The direct host calls above prove the fanout lines; these legs prove the REAL
# ownership chains reach them: round reset (egg reset_round -> round resetter ->
# persistence.reset_runtime_transients -> host), forced stow (soul-summon-art
# removal -> _set_guardian_stowed(forced) -> _end_guardian_runtime_for_stow ->
# host.end_for_stow) and pet swap (switch_lingpet_slot -> companion activation
# reset chain). The mokrin window is opened through the internal host's
# production launch entry each time (never a state-flag injection).
func _test_production_reset_boundaries() -> void:
	print("[D14 production boundary chains]")

	# 1) Round reset — works without a summoned pet.
	var round_runtime: Object = LingpetEggRuntime.new()
	round_runtime.launch_mokrin_transform_for_tests()
	_expect(bool(round_runtime.is_mokrin_transform_active()), "round leg: window open")
	round_runtime.reset_round({})
	_expect(not bool(round_runtime.is_mokrin_transform_active()),
		"REAL round reset chain clears the window (egg reset_round -> resetter -> host)")

	# 2) Forced stow — needs a summoned guardian; use the debug grant fixture to
	# reach STATE_COMPANION, then drive the PRODUCTION forced-stow entry.
	var stow_runtime: Object = LingpetEggRuntime.new()
	var granted: bool = bool(stow_runtime.debug_grant_and_activate_pet("maribo"))
	_expect(granted, "stow leg: fixture pet granted and activated")
	stow_runtime.launch_mokrin_transform_for_tests()
	_expect(bool(stow_runtime.is_mokrin_transform_active()), "stow leg: window open")
	stow_runtime.on_soul_summon_art_removed(null)
	_expect(not bool(stow_runtime.is_mokrin_transform_active()),
		"REAL forced-stow chain clears the window (soul art removal -> forced stow -> host)")

	# 3) Pet swap — two owned pets, then the production slot-switch entry.
	var swap_runtime: Object = LingpetEggRuntime.new()
	swap_runtime.debug_grant_and_activate_pet("maribo")
	swap_runtime.debug_grant_and_activate_pet("lunabi")
	swap_runtime.launch_mokrin_transform_for_tests()
	_expect(bool(swap_runtime.is_mokrin_transform_active()), "swap leg: window open")
	var switched: bool = bool(swap_runtime.switch_lingpet_slot(0))
	_expect(switched, "swap leg: production slot switch accepted")
	_expect(not bool(swap_runtime.is_mokrin_transform_active()),
		"REAL pet-swap chain clears the window (switch -> activation reset -> host)")


# ---- E2 aggregate snapshot --------------------------------------------------
func _test_aggregate_snapshot_merge() -> void:
	print("[E2 aggregate snapshot merge]")
	var host: Object = LingpetSkillRuntimeHost.new()
	host.launch(SKILL_ID, Vector2.ZERO, null, {})
	var snapshot: Dictionary = host.get_snapshot()
	_expect(bool(snapshot.get("mokrin_transform_active", false)), "aggregate snapshot carries the active flag (E2)")
	_expect(snapshot.has("mokrin_transform_remaining_seconds"), "remaining-seconds key merged")
	var per_skill: Dictionary = host.get_snapshot_for_skill_id(SKILL_ID)
	_expect(bool(per_skill.get("mokrin_transform_active", false)), "per-skill snapshot path also live (E3 auto)")


# ---- D15: predicate + fail-closed deps --------------------------------------
func _test_d15_predicate_and_fail_closed() -> void:
	print("[D15 predicate + fail-closed deps]")
	var builder: Object = BattleUpdatePlayerControlDepsBuilder.new()

	# No egg runtime registered -> invalid Callable -> engaged() false.
	var empty_registry := FakeRegistry.new()
	var deps_without: Dictionary = builder.build_deps(empty_registry)
	var predicate_without: Variant = deps_without.get("mokrin_transform_active", null)
	# NOTE: the runner promotes any output matching "Invalid call" to a failure,
	# so these labels must say "unbound Callable" — never the i-word + Call…
	_expect(predicate_without is Callable and not (predicate_without as Callable).is_valid(),
		"no runtime -> fail-closed unbound Callable")
	_expect(not SmasherPlayerController.is_mokrin_transform_engaged(deps_without),
		"engaged() treats an unbound Callable as false")

	# Real egg runtime registered: Callable valid, false on a fresh runtime, and
	# flips true when the INTERNAL host launches through its production entry.
	var egg_runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances["lingpet_egg_runtime"] = egg_runtime
	var deps_with: Dictionary = builder.build_deps(registry)
	var predicate_with: Variant = deps_with.get("mokrin_transform_active", null)
	_expect(predicate_with is Callable and (predicate_with as Callable).is_valid(),
		"real runtime -> valid narrow Callable")
	_expect(not SmasherPlayerController.is_mokrin_transform_engaged(deps_with),
		"fresh runtime -> predicate false")
	_expect(bool(egg_runtime.launch_mokrin_transform_for_tests()),
		"internal host launch through the production entry")
	_expect(SmasherPlayerController.is_mokrin_transform_engaged(deps_with),
		"predicate flips true after the internal launch")


# ---- D15: smasher consumption over the full chain ---------------------------
func _test_d15_smasher_consumption_chain() -> void:
	print("[D15 smasher consumption chain]")
	var builder: Object = BattleUpdatePlayerControlDepsBuilder.new()
	var egg_runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances["lingpet_egg_runtime"] = egg_runtime
	var deps: Dictionary = builder.build_deps(registry)
	var controller: Object = SmasherPlayerController.new()
	var config := _build_player_control_config()
	var start_pos := Vector2(100.0, 675.0)

	# Ordering half A: BEFORE the launch the same frame does NOT consume automation.
	var before: Dictionary = controller.update(DT, 0, start_pos, 0.0, config, deps)
	var before_pos: Vector2 = before.get("player_pos", start_pos)
	_expect(is_equal_approx(before_pos.x, start_pos.x),
		"before launch: no automation (position held sans input)")

	# Ordering half B: the frame AFTER the launch consumes it for the first time.
	egg_runtime.launch_mokrin_transform_for_tests()
	var after: Dictionary = controller.update(DT, 0, start_pos, 0.0, config, deps)
	var after_pos: Vector2 = after.get("player_pos", start_pos)
	var target_x: float = 380.0 - float(config.get("paddle_width", 155.0)) * 0.5
	_expect(after_pos.x > start_pos.x and after_pos.x <= target_x + 1.0,
		"after launch: paddle tracks toward the ball (AIPill math reused)")
	_expect(absf(after_pos.x - start_pos.x) > 0.5, "movement is real, not epsilon")


# ---- D15: viper early return must yield -------------------------------------
func _test_d15_viper_early_return_yields() -> void:
	print("[D15 viper early-return yield]")
	var builder: Object = BattleUpdatePlayerControlDepsBuilder.new()
	var egg_runtime: Object = LingpetEggRuntime.new()
	var registry := FakeRegistry.new()
	registry.instances["lingpet_egg_runtime"] = egg_runtime
	var deps: Dictionary = builder.build_deps(registry)
	var spy := SpyViperSkillRuntime.new()
	deps["viper_skill_runtime"] = spy
	var controller: Object = ViperPlayerController.new()
	var config := _build_player_control_config()
	var start_pos := Vector2(100.0, 675.0)

	# Control leg: transform off -> the viper skill early-return runs as shipped.
	controller.update(DT, 0, start_pos, 0.0, config, deps)
	_expect(spy.call_count == 1, "transform off: viper skill path consulted (control)")

	# Transform on -> the early return must NOT preempt; automation reaches the
	# shared controller and moves the paddle.
	egg_runtime.launch_mokrin_transform_for_tests()
	var result: Dictionary = controller.update(DT, 0, start_pos, 0.0, config, deps)
	_expect(spy.call_count == 1, "transform on: viper skill early-return skipped")
	var moved_pos: Vector2 = result.get("player_pos", start_pos)
	_expect(moved_pos.x > start_pos.x, "transform on: automation moved the paddle through the shared path")


# ---- fixtures ---------------------------------------------------------------
func _build_controller_params(host: Object, skill_state: Object, registry: Object) -> Dictionary:
	# _should_arm casts this with `as Array[String]`, so the fixture must supply a
	# genuinely TYPED array — an untyped literal would cast to null and void the leg.
	var active_ids: Array[String] = [SKILL_ID]
	return {
		"state": "companion",
		"companion_state": "companion",
		"owner": null,
		"registry": registry,
		"skill_id": SKILL_ID,
		"skill_state": skill_state,
		"skill_runtime_host": host,
		"windup_seconds": 0.5,
		"ball_active": true,
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(0.0, 12.0),
		"ball_size": 28.6,
		"switch_transition_active": false,
		"companion_visible": true,
		"companion_pos": Vector2(380.0, 640.0),
		"companion_radius": 24.0,
		"companion_catch_height": 48.0,
		"active_skill": {},
		"active_skill_level_fallback": 1,
		"slot_index": 0,
		"active_skill_ids": active_ids,
		"skill_states": [skill_state],
		"companion_exhausted": false,
	}


func _build_player_control_config() -> Dictionary:
	return {
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"paddle_speed": 6.0,
		"paddle_max_speed": 6.0,
		"paddle_accel": 0.5,
		"paddle_decel": 0.5,
		"paddle_turn_decel": 1.0,
		"special_gauge": 0.0,
		"ball_pos": Vector2(380.0, 375.0),
		"selected_character_type": "smasher",
	}
