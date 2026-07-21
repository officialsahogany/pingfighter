extends SceneTree

const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")
const ViperInputReader := preload("res://scripts/characters/viper_input_reader.gd")
const SmasherInputReader := preload("res://scripts/characters/smasher_input_reader.gd")
const BlacksmithInputReader := preload("res://scripts/characters/blacksmith_input_reader.gd")
const CommandoInputReader := preload("res://scripts/characters/commando_input_reader.gd")
const MobileTouchControls := preload("res://scripts/core/mobile_touch_controls.gd")
const BattleSceneTeardownLifecycle := preload("res://scripts/core/battle_scene_teardown_lifecycle.gd")
const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")

var _teardown_mobile_touch_controls: Object = null


func _get_teardown_module(key: String) -> Object:
	if key == "mobile_touch_controls":
		return _teardown_mobile_touch_controls
	return null

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var values: Dictionary = {
		"current_stage": 1,
		"selected_character_type": "smasher",
		"equipment_slots": {},
		"passive_item_inventory": [],
		"passive_item_slots": {},
		"equipped_passive_items": {},
		"mythic_item_state": {},
		"active_item_slots": [],
		"special_gauge": 150.0,
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"ball_pos": Vector2(380.0, 375.0),
		"ball_vel": Vector2(6.0, 1.0),
		"ball_active": true,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true

	func request_battle_redraw() -> void:
		values["redraw_requests"] = int(values.get("redraw_requests", 0)) + 1


class FakeInputReader:
	extends RefCounted

	var snapshot: Dictionary = {"mouse_left_just_pressed": false}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeAudio:
	extends RefCounted

	var spirit_calls := 0
	var shadow_calls := 0
	var attack_calls := 0

	func play_odins_eye_spirit() -> void:
		spirit_calls += 1

	func play_odins_eye_shadow() -> void:
		shadow_calls += 1

	func play_odins_eye_attack() -> void:
		attack_calls += 1


class FakeFeedback:
	extends RefCounted

	var gauge_flash_calls := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_calls += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary

	func _init(next_instances: Dictionary) -> void:
		instances = next_instances

	func get_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)


class FakePauseGate:
	extends RefCounted

	var paused := false

	func should_pause_game(_runtime: Object) -> bool:
		return paused


class FakeSuperspeedBossAi:
	extends RefCounted

	var boss_dash_active := false
	var boss_dash_stun_timer_frames := 0.0
	var _stage7_superspeed_was_active := true


class FakeStage7SuperspeedState:
	extends RefCounted

	var _superspeed_active := true


class FakeStage7EscapeState:
	extends RefCounted

	var _superspeed_active := false
	var _escape_active := true


class MobileShimViperReader:
	extends "res://scripts/characters/viper_input_reader.gd"

	func _is_mobile_runtime() -> bool:
		return true


class MobileShimSmasherReader:
	extends "res://scripts/characters/smasher_input_reader.gd"

	func _is_mobile_runtime() -> bool:
		return true


class MobileShimBlacksmithReader:
	extends "res://scripts/characters/blacksmith_input_reader.gd"

	func _is_mobile_runtime() -> bool:
		return true


class PollClockStubOdinsRuntime:
	extends "res://scripts/items/mythic_item_odins_eye_runtime.gd"

	# Headless smokes pin Engine.get_physics_frames() at 0, so the poll-gap
	# window is driven through this stub clock instead.
	var poll_frame_stub: int = 0

	func _get_input_poll_frame() -> int:
		return poll_frame_stub


func _init() -> void:
	_verify_runtime_finalize_input_collision_and_cleanup()
	_verify_pause_gate_blocks_cast_and_freezes_tick()
	_verify_superspeed_dash_ownership_lifecycle()
	_verify_stage2_immunity_refuses_and_clears_cc()
	_verify_poll_gap_suppresses_synthesized_edge()
	_verify_viper_reader_edge_contract_and_routing()
	_verify_all_character_readers_publish_cast_channel_and_cast()
	if _failures.is_empty():
		print("odins_eye_dark_swamp_runtime_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_runtime_finalize_input_collision_and_cleanup() -> void:
	var owner := FakeOwner.new()
	var input_reader := FakeInputReader.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"smasher_input_reader": input_reader,
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"Odin's Eye should equip before runtime Dark Swamp smoke"
	)
	_expect(
		not runtime.try_activate_odins_eye_dark_swamp(owner, registry),
		"Dark Swamp must reject input before revival finalize"
	)
	_expect_close(float(owner.get("special_gauge")), 150.0, "pre-finalize rejection must not spend gauge")
	_expect(runtime.try_trigger_odins_eye_revival("round", 0.0), "revival should trigger at a deterministic zero roll")
	# The LIVE armed timer must be 3.75s (the audio-sync length), not a stale
	# hardcoded 3.0 literal in try_trigger_revival. Reading the raw state here
	# catches a caller that overrides REVIVAL_EVENT_SEC.
	_expect_close(
		float(runtime.odins_eye_state.revival_timer_sec),
		3.75,
		"try_trigger must arm the 3.75s revival timer (not a hardcoded 3.0)"
	)
	# 220 frames (3.667s < 3.75s) must NOT yet finalize — proves the window is
	# genuinely longer than the old 3.0s (180f) event. The old timeline would
	# have finalized ~40 frames earlier.
	runtime.odins_eye_runtime.update_runtime(runtime, 220.0, owner, registry)
	_expect(
		runtime.is_odins_eye_revival_animation_active(),
		"revival must still be animating at 220f (3.667s < 3.75s) — the window really extended"
	)
	runtime.odins_eye_runtime.update_runtime(runtime, 231.0, owner, registry)
	_expect(
		not bool(runtime.get_odins_eye_dark_swamp_context().get("enabled", true)),
		"animation completion alone must not enable Dark Swamp before finalize edge consumption"
	)
	_expect(runtime.consume_odins_eye_revival_finalize_ready(), "revival finalize edge should be consumable once")
	_expect(
		bool(runtime.get_odins_eye_dark_swamp_context().get("enabled", false)),
		"revival finalize must enable Dark Swamp"
	)

	# Python contract: keyboard Space / X / ui_accept (the action_just_pressed
	# family) must NOT cast — only the left-click / gamepad-primary edge does.
	# Checked BEFORE the real cast so a full 150 gauge proves the rejection.
	input_reader.snapshot = {"action_just_pressed": true}
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		not bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
		"keyboard action edge must not cast (left-click only contract)"
	)
	_expect_close(float(owner.get("special_gauge")), 150.0, "keyboard action edge must not spend gauge")

	input_reader.snapshot = {"mouse_left_just_pressed": true}
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	input_reader.snapshot = {"mouse_left_just_pressed": false}
	var swamp_context: Dictionary = runtime.get_odins_eye_dark_swamp_context()
	_expect(bool(swamp_context.get("active", false)), "raw transformed left-click edge should activate Dark Swamp")
	_expect_close(float(owner.get("special_gauge")), 50.0, "runtime activation must spend exactly 100 gauge")
	_expect(audio.shadow_calls == 1, "activation should use the documented odinshadow substitute cue once")
	_expect(feedback.gauge_flash_calls == 1, "activation should flash the special gauge")

	# Keep one extra rise tick in the runtime integration fixture so the later
	# second-spike boss check clears the 20px threshold at every random height.
	for _frame_index in range(9):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	swamp_context = runtime.get_odins_eye_dark_swamp_context()
	var spikes: Array = swamp_context.get("spikes", []) as Array
	_expect(not spikes.is_empty(), "runtime update should publish the first sequential spike")
	_expect(audio.spirit_calls >= 1, "spike spawn should route odinspirit audio")
	if spikes.is_empty():
		return
	var first_spike: Dictionary = spikes[0] as Dictionary
	owner.set("ball_pos", Vector2(
		float(first_spike.get("x", 0.0)),
		float(first_spike.get("y", 0.0)) - float(first_spike.get("height", 0.0)) * 0.5
	))
	owner.set("ball_vel", Vector2(6.0, 0.0))
	runtime.odins_eye_runtime.update_runtime(runtime, 0.0, owner, registry)
	var reflected_velocity: Vector2 = owner.get("ball_vel") as Vector2
	_expect(reflected_velocity.y < 0.0, "runtime spike collision should reflect the ball upward")
	_expect(audio.attack_calls >= 1, "runtime spike collision should route odinattack audio")

	# Spawn another spike, move the ball away, and overlap the boss with its tip.
	for _frame_index in range(8):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	swamp_context = runtime.get_odins_eye_dark_swamp_context()
	spikes = swamp_context.get("spikes", []) as Array
	var boss_target: Dictionary = {}
	for spike_value in spikes:
		var spike := spike_value as Dictionary
		if not bool(spike.get("consumed", false)):
			boss_target = spike
			break
	_expect(not boss_target.is_empty(), "runtime boss collision setup needs an unconsumed spike")
	if boss_target.is_empty():
		return
	owner.set("ball_active", false)
	owner.set("boss_pos", Vector2(
		float(boss_target.get("x", 0.0)) - 20.0,
		float(boss_target.get("y", 0.0)) - float(boss_target.get("height", 0.0)) - 8.0
	))
	owner.set("boss_paddle_width", 40.0)
	owner.set("boss_hitbox_height", 16.0)
	runtime.odins_eye_runtime.update_runtime(runtime, 0.0, owner, registry)
	var boss_context: Dictionary = runtime.get_boss_ai_context()
	_expect(bool(boss_context.get("odins_eye_boss_stun_active", false)), "boss spike hit should reach the shared boss AI context")
	_expect(bool(boss_context.get("odins_eye_boss_knockback_active", false)), "boss spike hit should publish knockback to boss AI")

	# OUTCOME seal: feed the published context into the real BossAiState
	# consumer every frame and assert geometry, not flags. Python parity
	# (pingfighter.py:178178 knockback branch, :178654 stun branch): the CC
	# consumes SEQUENTIALLY — exactly 24 knockback frames traveling
	# sum(25*0.85^k, k=0..23) ≈ 163.3px in the SIGNED hit direction, then 60
	# stun-only frames applying the decaying residual (~3.4px tail, total
	# ≈166.7px) with the boss otherwise frozen. The rejected 0.88 constant
	# would travel ≈199px, and parallel timer consumption would leave only 36
	# stun-only frames.
	runtime.odins_eye_dark_swamp_state.wave_active = false
	runtime.odins_eye_dark_swamp_state._spikes.clear()
	# Park the OWNER boss mid-field: the spike-relative placement above can land
	# near a wall, where the Python wall-stop rule would legitimately zero the
	# residual and corrupt the travel measurement below.
	owner.set("boss_pos", Vector2(360.0, 25.0))
	# The travel must carry the SIGN the hit published (which lane spike wins
	# depends on fixture layout; the spike-left/right => direction contract
	# itself is sealed in odins_eye_dark_swamp_state_smoke.gd).
	var cc_direction: float = signf(float(
		runtime.get_odins_eye_dark_swamp_context().get("boss_knockback_vel", 0.0)
	))
	_expect(absf(cc_direction) > 0.0, "boss hit must publish a signed knockback velocity")
	var boss_ai := BossAiState.new()
	var sim_boss_pos := Vector2(400.0, 25.0)
	var knockback_phase_frames := 0
	var knockback_phase_travel := 0.0
	var stun_phase_frames := 0
	var stun_phase_travel := 0.0
	var final_stun_frame_dx := 1.0
	for _cc_frame in range(95):
		var cc_context: Dictionary = runtime.get_boss_ai_context()
		var knockback_active: bool = bool(cc_context.get("odins_eye_boss_knockback_active", false))
		var stun_active: bool = bool(cc_context.get("odins_eye_boss_stun_active", false))
		if knockback_active or stun_active:
			var motion_context: Dictionary = cc_context.duplicate(true)
			motion_context["width"] = 760.0
			motion_context["play_left"] = -100000.0
			motion_context["play_right"] = 100000.0
			motion_context["boss_paddle_width"] = 40.0
			var ai_result: Dictionary = boss_ai.update(1.0 / 60.0, sim_boss_pos, 0.0, motion_context)
			var next_pos: Vector2 = ai_result.get("boss_pos", sim_boss_pos) as Vector2
			var frame_dx: float = next_pos.x - sim_boss_pos.x
			if knockback_active:
				knockback_phase_frames += 1
				knockback_phase_travel += frame_dx
			else:
				stun_phase_frames += 1
				stun_phase_travel += frame_dx
				final_stun_frame_dx = frame_dx
			sim_boss_pos = next_pos
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		knockback_phase_frames == 24,
		"knockback phase must last exactly 24 frames (got %d)" % knockback_phase_frames
	)
	_expect(
		stun_phase_frames == 60,
		"stun-only phase must last exactly 60 frames AFTER the knockback window (got %d)" % stun_phase_frames
	)
	var signed_knockback_travel: float = knockback_phase_travel * cc_direction
	_expect(
		signed_knockback_travel >= 160.0 and signed_knockback_travel <= 166.0,
		"knockback travel must be ~163px IN the published hit direction (got %.1f)" % signed_knockback_travel
	)
	var signed_stun_travel: float = stun_phase_travel * cc_direction
	_expect(
		signed_stun_travel >= 0.5 and signed_stun_travel <= 8.0,
		"stun phase must apply the decaying residual tail ~3.4px in the same direction (got %.2f)" % signed_stun_travel
	)
	var total_cc_travel: float = (knockback_phase_travel + stun_phase_travel) * cc_direction
	_expect(
		total_cc_travel >= 164.0 and total_cc_travel <= 170.0,
		"total CC travel must match Python parity ~166.7px in the hit direction (got %.1f)" % total_cc_travel
	)
	_expect(
		absf(final_stun_frame_dx) < 0.01,
		"the boss must be effectively frozen by the stun tail (last dx %.4f)" % final_stun_frame_dx
	)
	_expect(
		not bool(runtime.get_boss_ai_context().get("odins_eye_boss_stun_active", true)),
		"boss stun must expire naturally after its own 60-frame window"
	)
	var clamp_result: Dictionary = boss_ai.update(1.0 / 60.0, Vector2(30.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"odins_eye_boss_stun_active": true,
		"odins_eye_boss_knockback_active": true,
		"odins_eye_boss_knockback_vel": -500.0,
	})
	var clamped_pos: Vector2 = clamp_result.get("boss_pos", Vector2.ZERO) as Vector2
	_expect(clamped_pos.x >= 0.0, "odin knockback must clamp at play_left (got %.1f)" % clamped_pos.x)

	# Dash-interaction seals (Python: knockback runs ABOVE dash/후딜 —
	# pingfighter.py:178177 "대쉬/후딜보다 우선 처리" — while the stun branch
	# sits BELOW them at :178654, so a live dash finishes before the stun
	# consumes). CC fields are re-armed white-box here; the real spike-hit
	# path is already sealed above, these legs isolate branch PRIORITY.
	var swamp_state: Object = runtime.odins_eye_dark_swamp_state
	swamp_state.boss_knockback_timer_frames = 24.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = -25.0
	var dashing_ai := BossAiState.new()
	dashing_ai.boss_dash_active = true
	dashing_ai.boss_dash_timer_frames = 30.0
	dashing_ai.boss_dash_duration_frames = 30.0
	dashing_ai.boss_dash_direction = 1
	dashing_ai.boss_dash_target_x = 700.0
	var dash_context: Dictionary = runtime.get_boss_ai_context()
	dash_context["width"] = 760.0
	dash_context["play_left"] = 0.0
	dash_context["play_right"] = 760.0
	dash_context["boss_paddle_width"] = 40.0
	var knockback_vs_dash: Dictionary = dashing_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, dash_context)
	_expect_close(
		float(knockback_vs_dash.get("boss_vel", 0.0)),
		-25.0,
		"knockback must preempt a live dash and move the boss by the knockback velocity"
	)
	_expect(
		dashing_ai.boss_dash_timer_frames >= 30.0 - 0.0001,
		"the interrupted dash timer must FREEZE during the knockback window"
	)

	swamp_state.boss_knockback_timer_frames = 0.0
	swamp_state.boss_knockback_vel = -0.5
	dash_context = runtime.get_boss_ai_context()
	dash_context["width"] = 760.0
	dash_context["play_left"] = 0.0
	dash_context["play_right"] = 760.0
	dash_context["boss_paddle_width"] = 40.0
	var dash_vs_stun: Dictionary = dashing_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, dash_context)
	_expect(
		float(dash_vs_stun.get("boss_vel", 0.0)) > 0.0,
		"a live dash must preempt the stun branch (stun waits below dash in Python)"
	)

	# While the dash runs, the stun timer must FREEZE (not drain unapplied):
	# the runtime peeks the dashing boss AI through the registry dash gate.
	registry.instances["boss_ai_state"] = dashing_ai
	var stun_frames_before_dash_wait: float = float(swamp_state.boss_stun_timer_frames)
	for _dash_wait_frame in range(5):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		stun_frames_before_dash_wait,
		"a live dash must FREEZE the stun timer instead of draining it"
	)
	dashing_ai.boss_dash_active = false
	dashing_ai.boss_dash_timer_frames = 0.0
	# One-frame release grace: mythic ticks run BEFORE the AI phase, so the
	# first post-dash tick must pass through untouched — the AI consumes the
	# preserved frame that same frame; mutation resumes on the next tick.
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		stun_frames_before_dash_wait,
		"the release frame must pass through untouched (grace) so the AI can consume it"
	)
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		stun_frames_before_dash_wait - 1.0,
		"the stun resumes consuming its own frames after the release grace"
	)

	# OUTCOME: after a dash window releases, the real BossAiState must consume
	# ALL 60 stun frames and apply the full decaying residual
	# (-0.5 * (1-0.85^60)/0.15 ≈ -3.33px) — not 59 frames / a pre-decayed tail.
	swamp_state.boss_knockback_timer_frames = 0.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = -0.5
	dashing_ai.boss_dash_active = true
	dashing_ai.boss_dash_timer_frames = 30.0
	for _release_wait_frame in range(3):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	dashing_ai.boss_dash_active = false
	dashing_ai.boss_dash_timer_frames = 0.0
	var release_ai := BossAiState.new()
	var release_applications := 0
	var release_travel := 0.0
	var release_boss_pos := Vector2(400.0, 25.0)
	for _release_frame in range(70):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var release_context: Dictionary = runtime.get_boss_ai_context()
		if bool(release_context.get("odins_eye_boss_stun_active", false)):
			var release_motion_context: Dictionary = release_context.duplicate(true)
			release_motion_context["width"] = 760.0
			release_motion_context["play_left"] = -100000.0
			release_motion_context["play_right"] = 100000.0
			release_motion_context["boss_paddle_width"] = 40.0
			var release_result: Dictionary = release_ai.update(1.0 / 60.0, release_boss_pos, 0.0, release_motion_context)
			var next_release_pos: Vector2 = release_result.get("boss_pos", release_boss_pos) as Vector2
			release_travel += next_release_pos.x - release_boss_pos.x
			release_boss_pos = next_release_pos
			release_applications += 1
	_expect(
		release_applications == 60,
		"post-release stun must be consumed by the AI exactly 60 times (got %d)" % release_applications
	)
	_expect(
		release_travel <= -3.0 and release_travel >= -3.6,
		"post-release residual travel must match Python ~-3.33px (got %.2f)" % release_travel
	)
	registry.instances.erase("boss_ai_state")

	# 극정호신 (stage-7 superspeed) parity: knockback outranks the superspeed
	# return (Python :178176 vs :178379), and the stun timer freezes behind it
	# through the item-side gate (Python :178654 sits below the return).
	var superspeed_ai := BossAiState.new()
	var superspeed_result: Dictionary = superspeed_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"stage7_akamu_superspeed_active": true,
		"odins_eye_boss_stun_active": true,
		"odins_eye_boss_knockback_active": true,
		"odins_eye_boss_knockback_vel": -25.0,
	})
	_expect_close(
		float(superspeed_result.get("boss_vel", 0.0)),
		-25.0,
		"knockback must preempt the stage7 superspeed return"
	)
	_expect(
		not runtime.odins_eye_runtime._is_boss_dash_gate_active(FakeRegistry.new({
			"boss_ai_state": FakeSuperspeedBossAi.new(),
		})),
		"the one-AI-phase-stale boss-AI superspeed mirror must NOT gate (61-application overlap)"
	)
	_expect(
		runtime.odins_eye_runtime._is_boss_dash_gate_active(FakeRegistry.new({
			"stage7_akamu_state": FakeStage7SuperspeedState.new(),
		})),
		"the stage7 state superspeed flag must freeze the stun timer gate"
	)

	# 극정호신 END transition: superspeed freezes the stun, the flag drops, and
	# the AI must then consume EXACTLY 60 frames (the stale-mirror + grace
	# overlap used to produce 61 applications / -3.833px).
	var stage7_stub := FakeStage7SuperspeedState.new()
	registry.instances["stage7_akamu_state"] = stage7_stub
	swamp_state.boss_knockback_timer_frames = 0.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = -0.5
	for _superspeed_frame in range(4):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		60.0,
		"superspeed must freeze the stun timer while active"
	)
	stage7_stub._superspeed_active = false
	var superspeed_release_ai := BossAiState.new()
	var superspeed_release_applications := 0
	var superspeed_release_travel := 0.0
	var superspeed_release_pos := Vector2(400.0, 25.0)
	for _superspeed_release_frame in range(70):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var superspeed_release_context: Dictionary = runtime.get_boss_ai_context()
		if bool(superspeed_release_context.get("odins_eye_boss_stun_active", false)):
			var superspeed_motion_context: Dictionary = superspeed_release_context.duplicate(true)
			superspeed_motion_context["width"] = 760.0
			superspeed_motion_context["play_left"] = -100000.0
			superspeed_motion_context["play_right"] = 100000.0
			superspeed_motion_context["boss_paddle_width"] = 40.0
			var superspeed_release_result: Dictionary = superspeed_release_ai.update(
				1.0 / 60.0, superspeed_release_pos, 0.0, superspeed_motion_context
			)
			var next_superspeed_pos: Vector2 = superspeed_release_result.get("boss_pos", superspeed_release_pos) as Vector2
			superspeed_release_travel += next_superspeed_pos.x - superspeed_release_pos.x
			superspeed_release_pos = next_superspeed_pos
			superspeed_release_applications += 1
	_expect(
		superspeed_release_applications == 60,
		"post-superspeed stun must be consumed exactly 60 times, not 61 (got %d)" % superspeed_release_applications
	)
	_expect(
		superspeed_release_travel <= -3.0 and superspeed_release_travel >= -3.6,
		"post-superspeed residual travel must stay ~-3.33px, not -3.83 (got %.2f)" % superspeed_release_travel
	)
	registry.instances.erase("stage7_akamu_state")

	# ZOMBIE combination (live-order probe): the SAME live AI sits in the
	# registry (drives the gate) and consumes the CC. The superspeed-OWNED
	# dash is still armed when the stage7 flag drops; that AI cancels it and
	# applies the FIRST stun frame in the same update. The stale dash gate
	# must hold that frame WITHOUT keeping the grace — the old code produced
	# 61 applications / -3.833px here.
	var zombie_stage7 := FakeStage7SuperspeedState.new()
	var zombie_ai := BossAiState.new()
	registry.instances["stage7_akamu_state"] = zombie_stage7
	registry.instances["boss_ai_state"] = zombie_ai
	swamp_state.boss_knockback_timer_frames = 0.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = -0.5
	zombie_ai._stage7_superspeed_was_active = true
	zombie_ai.boss_dash_active = true
	zombie_ai.boss_dash_timer_frames = 30.0
	zombie_ai.boss_dash_duration_frames = 30.0
	zombie_ai.boss_dash_direction = 1
	zombie_ai.boss_dash_target_x = 700.0
	for _zombie_warm_frame in range(3):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		60.0,
		"the superspeed-owned dash must freeze the stun while superspeed runs"
	)
	zombie_stage7._superspeed_active = false
	var zombie_applications := 0
	var zombie_travel := 0.0
	var zombie_pos := Vector2(400.0, 25.0)
	for _zombie_frame in range(70):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var zombie_context: Dictionary = runtime.get_boss_ai_context()
		var zombie_stun_active: bool = bool(zombie_context.get("odins_eye_boss_stun_active", false))
		var zombie_motion_context: Dictionary = zombie_context.duplicate(true)
		zombie_motion_context["width"] = 760.0
		zombie_motion_context["play_left"] = -100000.0
		zombie_motion_context["play_right"] = 100000.0
		zombie_motion_context["boss_paddle_width"] = 40.0
		var zombie_result: Dictionary = zombie_ai.update(1.0 / 60.0, zombie_pos, 0.0, zombie_motion_context)
		var zombie_residual: float = float(zombie_context.get("odins_eye_boss_knockback_vel", 0.0))
		if (
			zombie_stun_active
			and absf(float(zombie_result.get("boss_vel", 999.0)) - zombie_residual) < 0.0001
		):
			var next_zombie_pos: Vector2 = zombie_result.get("boss_pos", zombie_pos) as Vector2
			zombie_travel += next_zombie_pos.x - zombie_pos.x
			zombie_pos = next_zombie_pos
			zombie_applications += 1
		else:
			zombie_pos = zombie_result.get("boss_pos", zombie_pos) as Vector2
	_expect(
		zombie_applications == 60,
		"the zombie-dash release must consume exactly 60 stun applications, not 61 (got %d)" % zombie_applications
	)
	_expect(
		zombie_travel <= -3.0 and zombie_travel >= -3.6,
		"the zombie-dash release travel must stay ~-3.33px, not -3.83 (got %.3f)" % zombie_travel
	)
	registry.instances.erase("stage7_akamu_state")
	registry.instances.erase("boss_ai_state")

	# Generic CC clears must drop the release grace with the timers, or the
	# next spike hit skips a frame on stale grace.
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state._boss_gate_release_grace = true
	swamp_state.clear_boss_status()
	_expect_close(float(swamp_state.boss_stun_timer_frames), 0.0, "clear_boss_status must clear the stun timer")
	_expect(
		not swamp_state._boss_gate_release_grace,
		"clear_boss_status must drop the release grace with the timers"
	)
	swamp_state.boss_stun_timer_frames = 60.0
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		59.0,
		"a fresh stun after a generic clear must not skip a frame on stale grace"
	)
	swamp_state.boss_stun_timer_frames = 0.0

	# Stage7 scripted-motion priority split: a clone/shuriken casting pin
	# yields to the knockback (Python :178178 above :178265), while 영체탈주
	# escape stays authoritative above it (:178172).
	var scripted_ai := BossAiState.new()
	var casting_result: Dictionary = scripted_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"stage7_akamu_boss_ai_frozen": true,
		"stage7_akamu_scripted_motion_active": true,
		"stage7_akamu_clone_casting": true,
		"stage7_akamu_scripted_boss_pos": Vector2(500.0, 25.0),
		"odins_eye_boss_stun_active": true,
		"odins_eye_boss_knockback_active": true,
		"odins_eye_boss_knockback_vel": -25.0,
	})
	_expect_close(
		float(casting_result.get("boss_vel", 0.0)),
		-25.0,
		"knockback must interrupt a clone-casting pin"
	)
	# frozen 넉백도 정상 이동과 같은 몰로토프 장벽·모래감옥 후처리를 통과해야
	# 한다(조기 반환 우회=캐스팅 중 늪 넉백이 화염 관통/감옥 이탈).
	var frozen_barrier_result: Dictionary = scripted_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"stage7_akamu_boss_ai_frozen": true,
		"stage7_akamu_scripted_motion_active": true,
		"stage7_akamu_clone_casting": true,
		"stage7_akamu_scripted_boss_pos": Vector2(500.0, 25.0),
		"odins_eye_boss_stun_active": true,
		"odins_eye_boss_knockback_active": true,
		"odins_eye_boss_knockback_vel": -25.0,
		"active_item_molotov_fire_barriers": [{"center_x": 410.0, "center_y": 45.0}],
	})
	var frozen_barrier_pos: Vector2 = frozen_barrier_result.get("boss_pos", Vector2.ZERO) as Vector2
	_expect(
		frozen_barrier_pos.x >= 390.0,
		"frozen 늪 넉백은 몰로토프 장벽을 관통할 수 없다 (got %.2f)" % frozen_barrier_pos.x
	)
	_expect_close(
		float(frozen_barrier_result.get("boss_vel", -25.0)),
		0.0,
		"장벽에 막힌 frozen 넉백은 진입 속도를 죽인다"
	)
	var frozen_cage_result: Dictionary = scripted_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"stage7_akamu_boss_ai_frozen": true,
		"stage7_akamu_scripted_motion_active": true,
		"stage7_akamu_clone_casting": true,
		"stage7_akamu_scripted_boss_pos": Vector2(500.0, 25.0),
		"odins_eye_boss_stun_active": true,
		"odins_eye_boss_knockback_active": true,
		"odins_eye_boss_knockback_vel": -25.0,
		"lingpet_sand_prison_clamp_active": true,
		"lingpet_sand_prison_cage_left": 380.0,
		"lingpet_sand_prison_cage_right": 760.0,
	})
	_expect_close(
		(frozen_cage_result.get("boss_pos", Vector2.ZERO) as Vector2).x,
		380.0,
		"frozen 늪 넉백은 모래감옥 케이지 밖으로 나갈 수 없다"
	)
	# 저작 frozen 좌표(넉백 없는 캐스팅 핀)는 기존대로 후처리를 우회한다 —
	# 연출 좌표를 공유 클램프가 밀면 워프/분신 연출이 찢어진다.
	var frozen_pin_result: Dictionary = scripted_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"stage7_akamu_boss_ai_frozen": true,
		"stage7_akamu_scripted_motion_active": true,
		"stage7_akamu_clone_casting": true,
		"stage7_akamu_scripted_boss_pos": Vector2(500.0, 25.0),
		"lingpet_sand_prison_clamp_active": true,
		"lingpet_sand_prison_cage_left": 0.0,
		"lingpet_sand_prison_cage_right": 300.0,
	})
	_expect_close(
		(frozen_pin_result.get("boss_pos", Vector2.ZERO) as Vector2).x,
		500.0,
		"저작 frozen 캐스팅 핀 좌표는 후처리 우회를 유지한다"
	)

	var escape_result: Dictionary = scripted_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
		"stage7_akamu_boss_ai_frozen": true,
		"stage7_akamu_scripted_motion_active": true,
		"stage7_akamu_escape_active": true,
		"stage7_akamu_clone_casting": true,
		"stage7_akamu_scripted_boss_pos": Vector2(500.0, 25.0),
		"odins_eye_boss_stun_active": true,
		"odins_eye_boss_knockback_active": true,
		"odins_eye_boss_knockback_vel": -25.0,
	})
	_expect_close(
		float(escape_result.get("boss_vel", 0.0)),
		0.0,
		"영체탈주 escape must stay authoritative above the knockback"
	)
	_expect_close(
		(escape_result.get("boss_pos", Vector2.ZERO) as Vector2).x,
		500.0,
		"escape must keep the scripted boss position"
	)

	# INTEGRATION (corrected oracle): drive the REAL Stage7AkamuState.update()
	# with REAL cast begins. Python captures the pin ONCE at cast start and
	# never refreshes it, so the two casts DIVERGE:
	# - 분신 (30f cast) outlives the 24f knockback: the pin snaps the boss
	#   back for its remaining frames -> final ≈ 398.x.
	# - 표창 (18f cast) ends inside the knockback: no pin remains -> the full
	#   ~166.7px travel holds -> final ≈ 233.33.
	# Both consume 84 real CC frames.
	for casting_setup in [["clone", 396.0, 400.5], ["shuriken", 230.0, 236.5]]:
		var casting_kind: String = casting_setup[0]
		var casting_band_min: float = casting_setup[1]
		var casting_band_max: float = casting_setup[2]
		swamp_state.boss_knockback_timer_frames = 24.0
		swamp_state.boss_stun_timer_frames = 60.0
		swamp_state.boss_knockback_vel = -25.0
		var stage7_live := Stage7AkamuState.new()
		stage7_live.boss_special_gauge = 999.0
		var cast_begin_context := {
			"boss_pos": Vector2(400.0, 25.0),
			"boss_paddle_width": 40.0,
			"boss_hitbox_height": 16.0,
		}
		if casting_kind == "clone":
			_expect(
				stage7_live._try_start_clone_cast(cast_begin_context, true, true, "smoke", true),
				"fixture: the real clone cast must begin"
			)
		else:
			stage7_live._start_shuriken_cast(cast_begin_context)
			_expect(stage7_live._shuriken_casting, "fixture: the real shuriken cast must begin")
		# Escape must not fire spontaneously mid-seal: drain the gauge AFTER
		# the (free) cast began.
		stage7_live.boss_special_gauge = 0.0
		var integration_ai := BossAiState.new()
		var integration_pos := Vector2(400.0, 25.0)
		var integration_cc_frames := 0
		var clone_spawn_centers: Array = []
		for _integration_frame in range(120):
			var integration_context: Dictionary = runtime.get_boss_ai_context()
			var stun_live: bool = bool(integration_context.get("odins_eye_boss_stun_active", false))
			var kb_live: bool = bool(integration_context.get("odins_eye_boss_knockback_active", false))
			if not stun_live and not kb_live:
				# CC fully consumed: stop before the normal boss AI resumes its
				# home movement and walks the final position away.
				break
			integration_cc_frames += 1
			var integration_motion: Dictionary = integration_context.duplicate(true)
			integration_motion["width"] = 760.0
			integration_motion["play_left"] = -100000.0
			integration_motion["play_right"] = 100000.0
			integration_motion["boss_paddle_width"] = 40.0
			integration_motion.merge(stage7_live.get_boss_ai_context(), true)
			var integration_result: Dictionary = integration_ai.update(1.0 / 60.0, integration_pos, 0.0, integration_motion)
			integration_pos = integration_result.get("boss_pos", integration_pos) as Vector2
			# REAL Stage7 effects update applies LAST in the frame order.
			var stage7_result: Dictionary = stage7_live.update(1.0 / 60.0, {
				"current_stage": 7,
				"boss_pos": integration_pos,
				"boss_paddle_width": 40.0,
				"boss_hitbox_height": 16.0,
				"ball_active": true,
				"ball_pos": Vector2(380.0, 700.0),
			}, {
				"mythic_item_runtime": runtime,
			})
			if stage7_result.has("boss_pos"):
				integration_pos = stage7_result.get("boss_pos", integration_pos) as Vector2
			if (
				casting_kind == "clone"
				and clone_spawn_centers.is_empty()
				and not stage7_live._clones.is_empty()
			):
				for clone_value in stage7_live._clones:
					clone_spawn_centers.append(
						(clone_value as Dictionary).get("center", Vector2.ZERO) as Vector2
					)
			owner.set("boss_pos", Vector2(integration_pos.x, 25.0))
			runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		_expect(
			integration_cc_frames == 84,
			"%s integration must span 84 real CC frames (got %d)" % [casting_kind, integration_cc_frames]
		)
		_expect(
			integration_pos.x >= casting_band_min and integration_pos.x <= casting_band_max,
			"%s integration final position out of parity band (got %.3f)" % [casting_kind, integration_pos.x]
		)
		if casting_kind == "clone":
			_expect(not clone_spawn_centers.is_empty(), "the real clone cast must spawn clones")
			var clone_center_sum := 0.0
			for clone_center_value in clone_spawn_centers:
				clone_center_sum += (clone_center_value as Vector2).x
			var clone_center_avg: float = clone_center_sum / maxf(1.0, float(clone_spawn_centers.size()))
			_expect(
				clone_center_avg >= 340.0 and clone_center_avg <= 500.0,
				"clones must spawn around the ORIGINAL captured pin (~420), not the knocked position (~237) (avg %.1f)" % clone_center_avg
			)
		owner.set("boss_pos", Vector2(360.0, 25.0))

	# 영체탈주 (escape) freeze: BOTH CC timers hold in full while the escape
	# runs (Python's escape return sits above the knockback branch), then the
	# release applies the complete 24+60 sequence.
	var escape_stub := FakeStage7EscapeState.new()
	registry.instances["stage7_akamu_state"] = escape_stub
	swamp_state.boss_knockback_timer_frames = 24.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = -25.0
	for _escape_frame in range(30):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(float(swamp_state.boss_knockback_timer_frames), 24.0, "escape must freeze the knockback timer in full")
	_expect_close(float(swamp_state.boss_stun_timer_frames), 60.0, "escape must freeze the stun timer in full")
	_expect_close(float(swamp_state.boss_knockback_vel), -25.0, "escape must freeze the knockback velocity")
	escape_stub._escape_active = false
	var escape_release_ai := BossAiState.new()
	var escape_release_pos := Vector2(400.0, 25.0)
	var escape_kb_applications := 0
	var escape_stun_applications := 0
	for _escape_release_frame in range(95):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var escape_context: Dictionary = runtime.get_boss_ai_context()
		var escape_motion: Dictionary = escape_context.duplicate(true)
		escape_motion["width"] = 760.0
		escape_motion["play_left"] = -100000.0
		escape_motion["play_right"] = 100000.0
		escape_motion["boss_paddle_width"] = 40.0
		var escape_release_result: Dictionary = escape_release_ai.update(1.0 / 60.0, escape_release_pos, 0.0, escape_motion)
		if bool(escape_context.get("odins_eye_boss_knockback_active", false)):
			escape_kb_applications += 1
			escape_release_pos = escape_release_result.get("boss_pos", escape_release_pos) as Vector2
		elif bool(escape_context.get("odins_eye_boss_stun_active", false)):
			escape_stun_applications += 1
			escape_release_pos = escape_release_result.get("boss_pos", escape_release_pos) as Vector2
	_expect(
		escape_kb_applications == 24,
		"post-escape release must apply all 24 knockback frames (got %d)" % escape_kb_applications
	)
	_expect(
		escape_stun_applications == 60,
		"post-escape release must apply all 60 stun frames (got %d)" % escape_stun_applications
	)
	_expect(
		escape_release_pos.x >= 229.0 and escape_release_pos.x <= 238.0,
		"post-escape release travel must match the full ~166.7px CC (got %.3f)" % escape_release_pos.x
	)
	registry.instances.erase("stage7_akamu_state")
	owner.set("boss_pos", Vector2(360.0, 25.0))

	# REAL escape trigger (seeded RNG): the existing Odin stun feeds the mythic
	# disable context and triggers 영체탈주. The successful escape must rewind
	# this frame's applied knockback (Python attempts the escape BEFORE the
	# movement applies), consume stun+velocity, and PRESERVE the knockback
	# window — not wipe it through the generic clear.
	var trigger_stage7 := Stage7AkamuState.new()
	swamp_state.boss_knockback_timer_frames = 24.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = -25.0
	var trigger_context := {
		"current_stage": 7,
		"boss_pos": Vector2(375.0, 25.0),
		"boss_paddle_width": 40.0,
		"boss_hitbox_height": 16.0,
		"ball_active": true,
		"ball_pos": Vector2(380.0, 700.0),
	}
	var escape_triggered := false
	for trigger_seed in range(64):
		trigger_stage7.boss_special_gauge = 999.0
		trigger_stage7._rng.seed = trigger_seed
		trigger_stage7._escape_episode_active = false
		trigger_stage7._escape_attempted = false
		trigger_stage7.update(1.0 / 60.0, trigger_context, {"mythic_item_runtime": runtime})
		if trigger_stage7._escape_active:
			escape_triggered = true
			break
	_expect(escape_triggered, "seeded RNG must trigger the real 영체탈주 from the Odin stun")
	if escape_triggered:
		_expect_close(
			trigger_stage7._escape_start_boss_pos.x,
			400.0,
			"escape start must rewind this frame's applied knockback (pre-AI position)"
		)
	_expect_close(float(swamp_state.boss_stun_timer_frames), 0.0, "the escape must consume the Odin stun")
	_expect_close(float(swamp_state.boss_knockback_vel), 0.0, "the escape must consume the residual velocity")
	_expect_close(
		float(swamp_state.boss_knockback_timer_frames),
		24.0,
		"the escape must PRESERVE the knockback window (source-split clear)"
	)
	swamp_state.clear_boss_status()

	# A spike landing on the LAST escape tick (the collision resolves after
	# this frame's status tick) must still arm the release grace, or the fresh
	# knockback loses its first 25px (166.7 -> 141.7).
	var last_tick_escape_stub := FakeStage7EscapeState.new()
	registry.instances["stage7_akamu_state"] = last_tick_escape_stub
	swamp_state.cooldown_remaining_frames = 10.0
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	swamp_state._spikes.append({
		"id": 990,
		"x": 500.0,
		"y": 120.0,
		"width": 8.0,
		"height": 40.0,
		"phase": "hold",
		"consumed": false,
	})
	var last_tick_hit: Dictionary = swamp_state.check_boss_collision(
		Rect2(Vector2(480.0, 72.0), Vector2(40.0, 16.0))
	)
	_expect(bool(last_tick_hit.get("hit", false)), "fixture: the post-status-tick collision must land")
	_expect(
		swamp_state._boss_gate_release_grace,
		"a fresh hit under a full freeze must arm the release grace"
	)
	swamp_state._spikes.clear()
	registry.instances.erase("stage7_akamu_state")
	var last_tick_ai := BossAiState.new()
	var last_tick_pos := Vector2(400.0, 25.0)
	var last_tick_kb_applications := 0
	var first_release_dx := 0.0
	for _last_tick_frame in range(30):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		var last_tick_context: Dictionary = runtime.get_boss_ai_context()
		if not bool(last_tick_context.get("odins_eye_boss_knockback_active", false)):
			break
		var last_tick_motion: Dictionary = last_tick_context.duplicate(true)
		last_tick_motion["width"] = 760.0
		last_tick_motion["play_left"] = -100000.0
		last_tick_motion["play_right"] = 100000.0
		last_tick_motion["boss_paddle_width"] = 40.0
		var last_tick_result: Dictionary = last_tick_ai.update(1.0 / 60.0, last_tick_pos, 0.0, last_tick_motion)
		var next_last_tick_pos: Vector2 = last_tick_result.get("boss_pos", last_tick_pos) as Vector2
		if last_tick_kb_applications == 0:
			first_release_dx = next_last_tick_pos.x - last_tick_pos.x
		last_tick_kb_applications += 1
		last_tick_pos = next_last_tick_pos
	_expect_close(
		first_release_dx,
		-25.0,
		"the first released knockback frame must apply the full -25 (grace preserved through the hit)"
	)
	_expect(
		last_tick_kb_applications == 24,
		"the fresh knockback must apply all 24 frames after the freeze ends (got %d)" % last_tick_kb_applications
	)
	swamp_state.clear_boss_status()
	owner.set("boss_pos", Vector2(360.0, 25.0))

	# Python parity: the wall stop zeroes the residual velocity so a later dash
	# cannot drag the boss off the wall and re-apply a stale residual.
	swamp_state.boss_stun_timer_frames = 30.0
	swamp_state.boss_knockback_vel = -2.0
	owner.set("boss_pos", Vector2(0.0, 25.0))
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_knockback_vel),
		0.0,
		"a wall-pinned residual pointing INTO the wall must zero"
	)
	swamp_state.boss_stun_timer_frames = 30.0
	swamp_state.boss_knockback_vel = 2.0
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		float(swamp_state.boss_knockback_vel) > 0.0,
		"a residual pointing AWAY from the wall must survive"
	)
	# The knockback WINDOW must survive the wall stop: Python gates the branch
	# on the timer alone (:178178), so the remaining frames still hold the boss
	# and block a dash even with velocity zeroed.
	swamp_state.boss_knockback_timer_frames = 23.0
	swamp_state.boss_stun_timer_frames = 60.0
	swamp_state.boss_knockback_vel = 0.0
	var wall_window_context: Dictionary = runtime.get_boss_ai_context()
	_expect(
		bool(wall_window_context.get("odins_eye_boss_knockback_active", false)),
		"the knockback window must stay ACTIVE on the timer alone after a wall stop"
	)
	wall_window_context["width"] = 760.0
	wall_window_context["play_left"] = 0.0
	wall_window_context["play_right"] = 760.0
	wall_window_context["boss_paddle_width"] = 40.0
	var wall_dash_ai := BossAiState.new()
	wall_dash_ai.boss_dash_active = true
	wall_dash_ai.boss_dash_timer_frames = 30.0
	wall_dash_ai.boss_dash_duration_frames = 30.0
	wall_dash_ai.boss_dash_direction = 1
	wall_dash_ai.boss_dash_target_x = 700.0
	var wall_window_result: Dictionary = wall_dash_ai.update(1.0 / 60.0, Vector2(0.0, 25.0), 0.0, wall_window_context)
	_expect_close(
		float(wall_window_result.get("boss_vel", 1.0)),
		0.0,
		"a wall-stopped knockback window holds the boss (velocity 0), not the dash"
	)
	_expect(
		wall_dash_ai.boss_dash_timer_frames >= 30.0 - 0.0001,
		"the dash stays frozen through the remaining wall-stopped knockback frames"
	)
	owner.set("boss_pos", Vector2(360.0, 25.0))
	swamp_state.boss_knockback_timer_frames = 0.0
	swamp_state.boss_stun_timer_frames = 0.0
	swamp_state.boss_knockback_vel = 0.0

	runtime.clear_odins_eye_after_victory()
	swamp_context = runtime.get_odins_eye_dark_swamp_context()
	_expect(not bool(swamp_context.get("enabled", true)), "victory cleanup must disable Dark Swamp")
	_expect((swamp_context.get("spikes", []) as Array).is_empty(), "victory cleanup must clear all spike hazards")
	_expect(not bool(runtime.get_boss_ai_context().get("odins_eye_boss_stun_active", true)), "victory cleanup must clear boss CC")


class FakeStage2ImmuneSkillState:
	extends RefCounted

	var immune := true

	func is_boss_status_immune() -> bool:
		return immune


# 극정호신 대쉬 소유 미러 lifecycle: 극정호신 대쉬가 정상 종료된 뒤 시작한
# 일반 대쉬가 첫 업데이트에서 "플래그 드랍 좀비"로 오인·즉시 취소되면 안
# 된다 — 소유권은 대쉬 시작 시 래치되고 모든 종료 경로에서 해제된다.
func _verify_superspeed_dash_ownership_lifecycle() -> void:
	var lifecycle_ai := BossAiState.new()
	var base_context := {
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 40.0,
	}
	# 극정호신 대쉬 시작(소유 래치) 후 자연 종료.
	var superspeed_start := base_context.duplicate(true)
	superspeed_start["stage7_akamu_superspeed_active"] = true
	lifecycle_ai._start_boss_dash(1, 700.0, 200.0, superspeed_start)
	_expect(lifecycle_ai._stage7_superspeed_was_active, "극정호신 대쉬 시작은 소유권을 래치해야 한다")
	lifecycle_ai._finish_boss_dash(Vector2(400.0, 25.0), superspeed_start, 1.0)
	_expect(
		not lifecycle_ai._stage7_superspeed_was_active,
		"대쉬 정상 종료는 극정호신 소유 미러를 해제해야 한다"
	)
	# 이후 일반 대쉬: 첫 업데이트에서 취소되지 않고 전진해야 한다.
	lifecycle_ai.boss_dash_stun_timer_frames = 0.0
	var normal_start := base_context.duplicate(true)
	lifecycle_ai._start_boss_dash(1, 700.0, 200.0, normal_start)
	_expect(not lifecycle_ai._stage7_superspeed_was_active, "일반 대쉬 시작은 소유권을 래치하지 않는다")
	var normal_result: Dictionary = lifecycle_ai.update(1.0 / 60.0, Vector2(400.0, 25.0), 0.0, base_context)
	_expect(
		lifecycle_ai.boss_dash_active,
		"극정호신 이력 뒤의 일반 대쉬가 첫 업데이트에서 좀비로 오인·취소되면 안 된다"
	)
	_expect(
		float(normal_result.get("boss_vel", 0.0)) > 0.0,
		"일반 대쉬 첫 업데이트는 정상 전진해야 한다"
	)
	# 화염 차단 취소 경로도 소유 미러를 해제한다.
	var fire_ai := BossAiState.new()
	fire_ai._start_boss_dash(1, 700.0, 200.0, superspeed_start)
	fire_ai.cancel_dash_for_fire_block()
	_expect(
		not fire_ai._stage7_superspeed_was_active,
		"화염 차단 대쉬 취소도 극정호신 소유 미러를 해제해야 한다"
	)
	# reset 경로.
	var reset_ai := BossAiState.new()
	reset_ai._start_boss_dash(1, 700.0, 200.0, superspeed_start)
	reset_ai._reset_boss_dash()
	_expect(
		not reset_ai._stage7_superspeed_was_active,
		"대쉬 reset도 극정호신 소유 미러를 해제해야 한다"
	)


# 스테이지2 상태면역: 면역 중 늪 가시는 CC를 무장하지 못하고(ragnarok 계약),
# 남아 있던 오딘 CC도 정리된다 — 타이머만 남으면 면역 종료 뒤 지연 넉백·
# 스턴이 발동한다.
func _verify_stage2_immunity_refuses_and_clears_cc() -> void:
	var input_reader := FakeInputReader.new()
	var fixture: Dictionary = _build_transformed_fixture("smasher", input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	var swamp_state: Object = runtime.odins_eye_dark_swamp_state
	var immune_state := FakeStage2ImmuneSkillState.new()
	registry.instances["stage2_boss_skill_state"] = immune_state
	# 면역 중 보스 위 가시 → CC 무장 거부.
	owner.set("ball_active", false)
	swamp_state.cooldown_remaining_frames = 10.0
	swamp_state._spikes.append({
		"id": 991,
		"x": 500.0,
		"y": 120.0,
		"width": 8.0,
		"height": 40.0,
		"phase": "hold",
		"consumed": false,
	})
	owner.set("boss_pos", Vector2(480.0, 72.0))
	owner.set("boss_paddle_width", 40.0)
	owner.set("boss_hitbox_height", 16.0)
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(
		float(swamp_state.boss_stun_timer_frames),
		0.0,
		"스테이지2 면역 중 가시 히트는 스턴을 무장하지 못한다"
	)
	_expect_close(
		float(swamp_state.boss_knockback_timer_frames),
		0.0,
		"스테이지2 면역 중 가시 히트는 넉백을 무장하지 못한다"
	)
	# 면역 발동 시점에 남아 있던 기존 CC도 정리된다.
	swamp_state._spikes.clear()
	swamp_state.boss_stun_timer_frames = 40.0
	swamp_state.boss_knockback_timer_frames = 12.0
	swamp_state.boss_knockback_vel = -25.0
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect_close(float(swamp_state.boss_stun_timer_frames), 0.0, "면역 중 기존 오딘 스턴은 정리된다")
	_expect_close(float(swamp_state.boss_knockback_timer_frames), 0.0, "면역 중 기존 오딘 넉백 창은 정리된다")
	_expect_close(float(swamp_state.boss_knockback_vel), 0.0, "면역 중 기존 잔여 속도는 정리된다")
	# 면역 해제 후에는 정상 무장.
	immune_state.immune = false
	swamp_state._spikes.append({
		"id": 992,
		"x": 500.0,
		"y": 120.0,
		"width": 8.0,
		"height": 40.0,
		"phase": "hold",
		"consumed": false,
	})
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		float(swamp_state.boss_stun_timer_frames) > 0.0,
		"면역 해제 후 가시 히트는 정상적으로 스턴을 무장한다"
	)
	swamp_state.clear_boss_status()
	registry.instances.erase("stage2_boss_skill_state")


func _build_transformed_fixture(character_type: String, input_reader: Object) -> Dictionary:
	var owner := FakeOwner.new()
	owner.set("selected_character_type", character_type)
	var registry := FakeRegistry.new({
		"%s_input_reader" % character_type: input_reader,
		"game_audio": FakeAudio.new(),
		"battle_feedback_state": FakeFeedback.new(),
	})
	var runtime: Object = MythicItemRuntime.new()
	_expect(
		runtime.equip_item("odins_eye", owner, registry, {"revival_chance": 100.0}, false),
		"fixture: Odin's Eye should equip"
	)
	_expect(runtime.try_trigger_odins_eye_revival("round", 0.0), "fixture: revival should trigger")
	runtime.odins_eye_runtime.update_runtime(runtime, 231.0, owner, registry)
	_expect(runtime.consume_odins_eye_revival_finalize_ready(), "fixture: finalize edge should consume")
	return {"owner": owner, "registry": registry, "runtime": runtime}


func _verify_pause_gate_blocks_cast_and_freezes_tick() -> void:
	var input_reader := FakeInputReader.new()
	var fixture: Dictionary = _build_transformed_fixture("smasher", input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	runtime.should_pause_game()
	var pause_gate := FakePauseGate.new()
	runtime.pause_gate = pause_gate

	# Python parity (`not game_paused`): a click behind a mythic pause window
	# (acquisition cinematic / pandora selection / ...) must not cast and must
	# not spend gauge.
	pause_gate.paused = true
	input_reader.snapshot = {"mouse_left_just_pressed": true}
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		not bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
		"mythic pause must block the dark swamp cast"
	)
	_expect_close(float(owner.get("special_gauge")), 150.0, "paused click must not spend gauge")
	input_reader.snapshot = {"mouse_left_just_pressed": false}
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)

	# A fresh click after resume casts normally.
	pause_gate.paused = false
	input_reader.snapshot = {"mouse_left_just_pressed": true}
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	input_reader.snapshot = {"mouse_left_just_pressed": false}
	_expect(
		bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
		"fresh click after resume should cast dark swamp"
	)
	_expect_close(float(owner.get("special_gauge")), 50.0, "resumed cast must spend exactly 100 gauge")

	# The swamp clock freezes with the rest of the paused world (Python modal
	# loops froze spike/cooldown frame timers).
	for _warm_frame in range(6):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	var progress_before: float = float(runtime.get_odins_eye_dark_swamp_context().get("wave_progress", -1.0))
	pause_gate.paused = true
	for _paused_frame in range(5):
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	var progress_paused: float = float(runtime.get_odins_eye_dark_swamp_context().get("wave_progress", -2.0))
	_expect_close(progress_paused, progress_before, "mythic pause must freeze the dark swamp wave clock")
	pause_gate.paused = false
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	var progress_resumed: float = float(runtime.get_odins_eye_dark_swamp_context().get("wave_progress", -2.0))
	_expect(progress_resumed > progress_paused, "resume must unfreeze the dark swamp wave clock")


func _verify_poll_gap_suppresses_synthesized_edge() -> void:
	var input_reader := FakeInputReader.new()
	var fixture: Dictionary = _build_transformed_fixture("smasher", input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]

	# Physics-blocking modals (scoreboard, TAB info, ...) skip update_mythic_items
	# entirely, so the reader's edge state goes stale. The first resumed frame can
	# then synthesize a just-pressed edge from a button merely held through the
	# modal — that edge must not cast (Python's event queue produced no new
	# MOUSEBUTTONDOWN after a modal closed).
	var stub_runtime := PollClockStubOdinsRuntime.new()
	stub_runtime.poll_frame_stub = 100
	input_reader.snapshot = {"mouse_left_just_pressed": false}
	stub_runtime.update_runtime(runtime, 1.0, owner, registry)

	stub_runtime.poll_frame_stub = 106
	input_reader.snapshot = {"mouse_left_just_pressed": true}
	stub_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		not bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
		"synthesized edge on the first resumed frame must not cast"
	)
	_expect_close(float(owner.get("special_gauge")), 150.0, "suppressed edge must not spend gauge")

	stub_runtime.poll_frame_stub = 107
	input_reader.snapshot = {"mouse_left_just_pressed": false}
	stub_runtime.update_runtime(runtime, 1.0, owner, registry)
	stub_runtime.poll_frame_stub = 108
	input_reader.snapshot = {"mouse_left_just_pressed": true}
	stub_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
		"fresh edge after the gap closes must cast"
	)


func _verify_viper_reader_edge_contract_and_routing() -> void:
	# Contract seal for the viper-cast regression: the real viper reader used to
	# omit action_just_pressed entirely, so the dark-swamp listener's
	# `.get("action_just_pressed", false)` defaulted false forever.
	var viper_reader := ViperInputReader.new()
	var idle_snapshot: Dictionary = viper_reader.get_snapshot()
	_expect(idle_snapshot.has("action_just_pressed"), "viper snapshot must contain action_just_pressed")
	_expect(idle_snapshot.has("action_just_released"), "viper snapshot must contain action_just_released")
	_expect(idle_snapshot.has("mouse_left_pressed"), "viper snapshot must contain mouse_left_pressed")
	_expect(idle_snapshot.has("mouse_left_just_pressed"), "viper snapshot must contain mouse_left_just_pressed (dark swamp cast edge)")
	_expect(idle_snapshot.has("jetpack_pressed"), "viper snapshot must keep jetpack_pressed")
	_expect(
		not bool(idle_snapshot.get("action_just_pressed", true)),
		"idle viper snapshot must not report a pressed edge"
	)

	# Edge semantics through the live Input singleton; the same-frame cache is
	# reset white-box to emulate successive physics frames inside one script.
	Input.action_press("ui_accept")
	viper_reader._same_frame_snapshot_key = -1
	var pressed_snapshot: Dictionary = viper_reader.get_snapshot()
	_expect(bool(pressed_snapshot.get("action_pressed", false)), "ui_accept press must read as action_pressed")
	_expect(bool(pressed_snapshot.get("action_just_pressed", false)), "first pressed frame must publish the edge")
	viper_reader._same_frame_snapshot_key = -1
	var held_snapshot: Dictionary = viper_reader.get_snapshot()
	_expect(
		not bool(held_snapshot.get("action_just_pressed", true)),
		"held frame must not re-publish the pressed edge"
	)
	Input.action_release("ui_accept")
	viper_reader._same_frame_snapshot_key = -1
	var released_snapshot: Dictionary = viper_reader.get_snapshot()
	_expect(bool(released_snapshot.get("action_just_released", false)), "release frame must publish just_released")
	_expect(
		not bool(released_snapshot.get("action_just_pressed", true)),
		"release frame must not publish a pressed edge"
	)

	# Mobile touch-accept channel: the on-screen ACCEPT button drives the
	# left-click contract ONLY on mobile runtimes (approved v3 contract:
	# desktop ignores the channel and polls raw LMB alone —
	# mobile_touch_accept_channel_smoke owns that negative). The mobile
	# branch is verified through a runtime-shim subclass.
	var mobile_reader := MobileShimViperReader.new()
	MobileTouchControls._touch_accept_pressed_static = true
	mobile_reader._same_frame_snapshot_key = -1
	var touch_snapshot: Dictionary = mobile_reader.get_snapshot()
	_expect(bool(touch_snapshot.get("mouse_left_pressed", false)), "touch-accept must read as mouse_left_pressed")
	_expect(bool(touch_snapshot.get("mouse_left_just_pressed", false)), "touch-accept press must publish the cast edge")
	mobile_reader._same_frame_snapshot_key = -1
	var touch_hold_snapshot: Dictionary = mobile_reader.get_snapshot()
	_expect(
		not bool(touch_hold_snapshot.get("mouse_left_just_pressed", true)),
		"a held touch-accept must not re-publish the cast edge"
	)
	MobileTouchControls._touch_accept_pressed_static = false
	mobile_reader._same_frame_snapshot_key = -1
	_expect(
		not bool(mobile_reader.get_snapshot().get("mouse_left_pressed", true)),
		"touch-accept release must clear mouse_left_pressed"
	)
	# Desktop runtime keeps ignoring the channel (v3 계약과의 정합 확인).
	MobileTouchControls._touch_accept_pressed_static = true
	viper_reader._same_frame_snapshot_key = -1
	_expect(
		not bool(viper_reader.get_snapshot().get("mouse_left_pressed", true)),
		"desktop viper reader must ignore the touch-accept channel (raw LMB only)"
	)
	MobileTouchControls._touch_accept_pressed_static = false
	var touch_controls := MobileTouchControls.new()
	MobileTouchControls._touch_accept_pressed_static = true
	touch_controls.release_all()
	_expect(
		not MobileTouchControls.is_touch_accept_pressed(),
		"release_all must clear the touch-accept channel"
	)

	# REAL event path: a touch pressed on the ACCEPT button drives the channel
	# through handle_input, and the orphan/disabled paths cannot.
	var real_touch_controls := MobileTouchControls.new()
	var touch_view_size := Vector2(1280.0, 720.0)
	var touch_layout: Dictionary = real_touch_controls._build_layout(touch_view_size, {})
	var accept_center: Vector2 = touch_layout.get("ui_accept", Vector2.ZERO)
	_expect(accept_center != Vector2.ZERO, "mobile layout must expose the ACCEPT button center")
	var accept_press := InputEventScreenTouch.new()
	accept_press.index = 0
	accept_press.pressed = true
	accept_press.position = accept_center
	real_touch_controls.handle_input(accept_press, touch_view_size, true, {})
	_expect(
		MobileTouchControls.is_touch_accept_pressed(),
		"a real ACCEPT-button touch must set the touch-accept channel"
	)
	var accept_release := InputEventScreenTouch.new()
	accept_release.index = 0
	accept_release.pressed = false
	accept_release.position = accept_center
	real_touch_controls.handle_input(accept_release, touch_view_size, true, {})
	_expect(
		not MobileTouchControls.is_touch_accept_pressed(),
		"the real ACCEPT release must clear the touch-accept channel"
	)
	# Presses observed during a DISABLED window (modals) must be discarded.
	var disabled_press := InputEventScreenTouch.new()
	disabled_press.index = 1
	disabled_press.pressed = true
	disabled_press.position = accept_center
	real_touch_controls.handle_input(disabled_press, touch_view_size, false, {})
	_expect(
		real_touch_controls.active_touches.is_empty(),
		"presses during a disabled window must be discarded (no phantom finger)"
	)
	# Orphan drags (press never observed while enabled) must be rejected.
	var orphan_drag := InputEventScreenDrag.new()
	orphan_drag.index = 1
	orphan_drag.position = accept_center
	real_touch_controls.handle_input(orphan_drag, touch_view_size, true, {})
	_expect(
		real_touch_controls.active_touches.is_empty(),
		"orphan drags must not register a phantom finger"
	)
	_expect(
		not MobileTouchControls.is_touch_accept_pressed(),
		"an orphan drag over ACCEPT must not fire the touch-accept channel"
	)

	# Battle teardown must release the manually-pressed mobile actions and the
	# touch-accept channel, or a finger held through the scene exit leaks a
	# pressed ACCEPT into the next scene.
	var held_press := InputEventScreenTouch.new()
	held_press.index = 2
	held_press.pressed = true
	held_press.position = accept_center
	real_touch_controls.handle_input(held_press, touch_view_size, true, {})
	_expect(
		MobileTouchControls.is_touch_accept_pressed(),
		"teardown fixture: the held ACCEPT press must be live before teardown"
	)
	_teardown_mobile_touch_controls = real_touch_controls
	BattleSceneTeardownLifecycle.new().exit_tree(null, null, Callable(self, "_get_teardown_module"), {})
	_expect(
		not MobileTouchControls.is_touch_accept_pressed(),
		"battle teardown must release the held mobile ACCEPT channel"
	)
	_expect(
		not Input.is_action_pressed("ui_accept"),
		"battle teardown must release the manually pressed ui_accept action"
	)
	_teardown_mobile_touch_controls = null

	# Null-getter teardown fallback: even without a reachable instance, the
	# manually pressed actions AND the channel must release.
	Input.action_press("ui_accept")
	MobileTouchControls._touch_accept_pressed_static = true
	BattleSceneTeardownLifecycle.new().exit_tree(null, null, Callable(self, "_get_teardown_module"), {})
	_expect(
		not MobileTouchControls.is_touch_accept_pressed(),
		"the null-getter teardown fallback must clear the touch-accept channel"
	)
	_expect(
		not Input.is_action_pressed("ui_accept"),
		"the null-getter teardown fallback must release the manually pressed ui_accept action"
	)

	# End-to-end routing: a viper-selected owner resolves viper_input_reader and
	# the transformed left-click edge casts dark swamp.
	var input_reader := FakeInputReader.new()
	var fixture: Dictionary = _build_transformed_fixture("viper", input_reader)
	var owner: Object = fixture["owner"]
	var registry: Object = fixture["registry"]
	var runtime: Object = fixture["runtime"]
	input_reader.snapshot = {"mouse_left_just_pressed": true}
	runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
	_expect(
		bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
		"viper-selected runtime must cast dark swamp from the viper reader edge"
	)
	_expect_close(float(owner.get("special_gauge")), 50.0, "viper cast must spend exactly 100 gauge")


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (got %.3f, expected %.3f)" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# P1 씰(2026-07-21 코덱스 리뷰): 시전 에지는 mouse_left_just_pressed 단일
# 키인데 viper 리더만 이 채널을 게시해 스매셔/커맨도/대장장이에서 시전이
# 전멸했던 회귀. 4캐릭 실 리더 전부 채널 키를 게시해야 하고, 스매셔·
# 대장장이는 실 리더(모바일 심)로 update_runtime 관통까지 시전을 봉인한다
# (데스크톱 raw LMB 분기는 헤드리스에서 구동 불가 — 같은 채널 코드의
# 모바일 분기로 결정론 봉인, raw LMB는 윈도우드 QA 하니스 몫).
func _verify_all_character_readers_publish_cast_channel_and_cast() -> void:
	for reader_info in [
		["smasher", SmasherInputReader.new()],
		["blacksmith", BlacksmithInputReader.new()],
		["commando", CommandoInputReader.new()],
		["viper", ViperInputReader.new()],
	]:
		var reader_label: String = str(reader_info[0])
		var idle_reader: Object = reader_info[1]
		var idle_snapshot: Dictionary = idle_reader.get_snapshot()
		_expect(
			idle_snapshot.has("mouse_left_pressed"),
			"%s reader snapshot must publish mouse_left_pressed" % reader_label
		)
		_expect(
			idle_snapshot.has("mouse_left_just_pressed"),
			"%s reader snapshot must publish mouse_left_just_pressed (dark swamp cast edge)" % reader_label
		)

	for cast_info in [
		["smasher", MobileShimSmasherReader.new()],
		["blacksmith", MobileShimBlacksmithReader.new()],
	]:
		var character_type: String = str(cast_info[0])
		var shim_reader: Object = cast_info[1]
		var fixture: Dictionary = _build_transformed_fixture(character_type, shim_reader)
		var owner: Object = fixture["owner"]
		var registry: Object = fixture["registry"]
		var runtime: Object = fixture["runtime"]
		owner.set("special_gauge", 500.0)
		MobileTouchControls._touch_accept_pressed_static = true
		shim_reader._same_frame_snapshot_key = -1
		runtime.odins_eye_runtime.update_runtime(runtime, 1.0, owner, registry)
		MobileTouchControls._touch_accept_pressed_static = false
		_expect(
			bool(runtime.get_odins_eye_dark_swamp_context().get("active", false)),
			"%s primary-pointer press must cast the dark swamp through the real reader" % character_type
		)
		_expect(
			is_equal_approx(float(owner.get("special_gauge")), 400.0),
			"%s cast must consume 100 gauge through the real reader (got %s)" % [character_type, str(owner.get("special_gauge"))]
		)
