extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")
const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 4
	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var ball_active := true
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(0.0, -4.0)
	var player_pos := Vector2(302.5, 690.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var values: Dictionary = {}

	func _get(property: StringName) -> Variant:
		return values.get(String(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[String(property)] = value
		return true

	func queue_redraw() -> void:
		values["redraw_queued"] = true

	func request_battle_redraw() -> void:
		values["redraw_requested"] = true


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false
	var player_serves := false
	var reset_wait_calls := 0
	var score_wait_calls := 0
	var restart_notice_calls := 0

	func set_player_serves(value: bool) -> void:
		player_serves = value

	func reset_round_wait() -> void:
		waiting_for_serve = true
		reset_wait_calls += 1

	func start_scoreboard_wait() -> void:
		waiting_for_serve = true
		score_wait_calls += 1

	func start_round_restart_notice() -> void:
		restart_notice_calls += 1

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeAudio:
	extends RefCounted

	var foul_whistle_count := 0
	var round_set_count := 0

	func play_foul_whistle() -> void:
		foul_whistle_count += 1

	func play_round_set() -> void:
		round_set_count += 1


class FakeActiveItemRuntime:
	extends RefCounted

	var defense_scan_calls := 0
	var recovery_scan_calls := 0
	var recovery_result := ""
	var defense_result := ""

	func is_stopwatch_active() -> bool:
		return false

	func is_holy_barrier_active() -> bool:
		return false

	func try_smartphone_auto_defense(_owner: Object, _registry: Object) -> String:
		defense_scan_calls += 1
		return defense_result

	func try_smartphone_auto_recovery(_owner: Object, _registry: Object, _threshold: float) -> String:
		recovery_scan_calls += 1
		return recovery_result


class FakeRegistry:
	extends RefCounted

	var mythic_item_runtime: Object
	var runtime_perk_state: Object
	var active_item_runtime: Object
	var game_audio: Object
	var round_flow_state: Object

	func _init(
		runtime_ref: Object,
		state_ref: Object = null,
		active_ref: Object = null,
		audio_ref: Object = null,
		round_ref: Object = null
	) -> void:
		mythic_item_runtime = runtime_ref
		runtime_perk_state = state_ref
		active_item_runtime = active_ref
		game_audio = audio_ref
		round_flow_state = round_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return mythic_item_runtime
			"runtime_perk_state":
				return runtime_perk_state
			"active_item_runtime":
				return active_item_runtime
			"game_audio":
				return game_audio
			"round_flow_state":
				return round_flow_state
		return null


func _init() -> void:
	seed(44044)
	PerkConversionFlags.debug_set_enabled(false)
	_verify_off_flag_keeps_item_gates()
	_verify_on_flag_uses_perk_levels()
	_verify_on_flag_level_zero_and_item_only_are_inactive()
	_verify_on_flag_perk_replaces_item_without_max()
	_verify_retired_revival_is_runtime_neutral()
	_verify_runtime_consumers_use_batch4_gates()
	PerkConversionFlags.debug_set_enabled(false)

	if _failures.is_empty():
		print("perk_conversion_gate_batch4_smoke: ok")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_off_flag_keeps_item_gates() -> void:
	PerkConversionFlags.debug_set_enabled(false)

	var foul_env := _make_env({})
	var foul_runtime: Object = foul_env["runtime"]
	_expect(_equip_item(foul_env, "foul_whistle", {"negate_chance_pct": 8.0}), "OFF Foul Whistle fixture should equip")
	_expect(foul_runtime.is_foul_whistle_equipped(), "OFF Foul Whistle should still expose equipped state")
	_expect(foul_runtime.is_foul_whistle_active(), "OFF Foul Whistle active gate should follow equipped state")
	_expect_close(foul_runtime.get_foul_whistle_negate_chance_pct(), 8.0, "OFF Foul Whistle should keep rolled negate pct")

	var revival_env := _make_env({})
	var revival_runtime: Object = revival_env["runtime"]
	_expect(_equip_item(revival_env, "revival", {}), "OFF Revival fixture should equip")
	_expect(revival_runtime.is_revival_equipped(), "OFF Revival should still expose equipped state")
	_expect(revival_runtime.is_revival_active(), "OFF Revival active gate should follow equipped state")
	_expect(revival_runtime.is_revival_available(), "OFF Revival should be available when equipped and unused")

	var phone_env := _make_env({})
	var phone_runtime: Object = phone_env["runtime"]
	_expect(_equip_item(phone_env, "smartphone", {}), "OFF Smartphone fixture should equip")
	_expect(phone_runtime.is_smartphone_equipped(), "OFF Smartphone should still expose equipped state")
	_expect(phone_runtime.is_smartphone_active(), "OFF Smartphone active gate should follow equipped state")
	_expect(phone_runtime.is_smartphone_effect_active(), "OFF Smartphone effect gate alias should follow equipped state")


func _verify_on_flag_uses_perk_levels() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	for level in [1, 5]:
		var env := _make_env({"foul_whistle": level})
		var runtime: Object = env["runtime"]
		_expect(runtime.is_foul_whistle_active(), "ON Lv%d Foul Whistle active gate should use perk level" % level)
		_expect_close(
			runtime.get_foul_whistle_negate_chance_pct(),
			PerkConversionValues.get_value("foul_whistle", "negate_chance_pct", level),
			"ON Lv%d Foul Whistle should use perk negate pct" % level
		)

	var revival_env := _make_env({"revival": 1})
	_expect(not revival_env["runtime"].is_revival_active(), "ON retired Revival should ignore stale perk levels")
	_expect(not revival_env["runtime"].is_revival_available(), "ON retired Revival should stay unavailable")

	var phone_env := _make_env({"smartphone": 1})
	_expect(phone_env["runtime"].is_smartphone_active(), "ON perk-only Smartphone active gate should use perk level")
	_expect(phone_env["runtime"].is_smartphone_effect_active(), "ON perk-only Smartphone effect gate alias should use perk level")


func _verify_on_flag_level_zero_and_item_only_are_inactive() -> void:
	PerkConversionFlags.debug_set_enabled(true)

	var zero_env := _make_env({})
	var zero_runtime: Object = zero_env["runtime"]
	_expect(not zero_runtime.is_foul_whistle_active(), "ON level 0 Foul Whistle should be inactive")
	_expect_close(zero_runtime.get_foul_whistle_negate_chance_pct(), 0.0, "ON level 0 Foul Whistle should expose 0 pct")
	_expect(not zero_runtime.is_revival_active(), "ON level 0 Revival active gate should be inactive")
	_expect(not zero_runtime.is_revival_available(), "ON level 0 Revival should not be available")
	_expect(not zero_runtime.is_smartphone_active(), "ON level 0 Smartphone should be inactive")

	var item_env := _make_env({})
	var item_runtime: Object = item_env["runtime"]
	_expect(_equip_item(item_env, "foul_whistle", {"negate_chance_pct": 100.0}), "ON item-only Foul Whistle should equip")
	_expect(_equip_item(item_env, "revival", {}), "ON item-only Revival should equip")
	_expect(_equip_item(item_env, "smartphone", {}), "ON item-only Smartphone should equip")
	_expect(item_runtime.is_foul_whistle_equipped(), "ON item-only Foul Whistle should still expose equipped state")
	_expect(not item_runtime.is_foul_whistle_active(), "ON item-only Foul Whistle active gate should be inactive")
	_expect_close(item_runtime.get_foul_whistle_negate_chance_pct(), 0.0, "ON item-only Foul Whistle should not leak item roll")
	_expect(item_runtime.is_revival_equipped(), "ON item-only Revival should still expose equipped state")
	_expect(not item_runtime.is_revival_active(), "ON item-only Revival active gate should be inactive")
	_expect(not item_runtime.is_revival_available(), "ON item-only Revival should not be available")
	_expect(item_runtime.is_smartphone_equipped(), "ON item-only Smartphone should still expose equipped state")
	_expect(not item_runtime.is_smartphone_active(), "ON item-only Smartphone active gate should be inactive")


func _verify_on_flag_perk_replaces_item_without_max() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var env := _make_env({"foul_whistle": 1})
	var runtime: Object = env["runtime"]
	_expect(_equip_item(env, "foul_whistle", {"negate_chance_pct": 100.0}), "ON high-roll Foul Whistle should equip")
	_expect(runtime.is_foul_whistle_active(), "ON item+perk Foul Whistle should be active through the perk")
	_expect_close(runtime.get_foul_whistle_negate_chance_pct(), 3.0, "ON Foul Whistle should replace high item roll with Lv1 value")


func _verify_retired_revival_is_runtime_neutral() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	var env := _make_env({"revival": 1})
	var runtime: Object = env["runtime"]
	_expect(not runtime.is_revival_active(), "ON retired Revival should be inactive even with a stale raw level")
	_expect(not runtime.is_revival_available(), "ON retired Revival should be unavailable even with a stale raw level")
	_expect(not runtime.try_trigger_revival("round", {"owner": env["owner"], "registry": env["registry"]}), "ON retired Revival should never trigger")
	_expect(not runtime.has_revival_used(), "blocked retired Revival should not mutate used state")


func _verify_runtime_consumers_use_batch4_gates() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_verify_revival_match_flow_consumer()
	_verify_foul_whistle_match_flow_consumer()
	_verify_smartphone_update_consumer()


func _verify_revival_match_flow_consumer() -> void:
	var env := _make_env({"revival": 1})
	var runtime: Object = env["runtime"]
	var score_state: Object = MatchScoreState.new()
	# GRT-054: 치명 점수는 정본 WIN_GOAL에서 파생 (5점제 리터럴 잔재 금지).
	for _i in range(MatchScoreState.WIN_GOAL - 1):
		score_state.score_for("boss")
	_expect(score_state.would_score_finish("boss"), "Revival consumer fixture should be at fatal boss score")

	var round_state := FakeRoundState.new()
	MatchFlowController.new().handle_score_event("boss", {
		"score_state": score_state,
		"round_state": round_state,
		"mythic_item_runtime": runtime,
		"audio": env["audio"],
		"owner": env["owner"],
		"registry": env["registry"],
	}, {})
	var snapshot: Dictionary = score_state.get_snapshot()
	_expect(
		int(snapshot.get("boss_score", -1)) == MatchScoreState.WIN_GOAL,
		"ON retired Revival must not reset a fatal boss score"
	)
	_expect(round_state.restart_notice_calls == 0, "ON retired Revival must not start the Revival restart notice")
	_expect(not runtime.has_revival_used(), "ON retired Revival match-flow query must not mark used")


func _verify_foul_whistle_match_flow_consumer() -> void:
	var triggered := false
	for _attempt in range(600):
		var env := _make_env({"foul_whistle": 5})
		var runtime: Object = env["runtime"]
		var score_state: Object = MatchScoreState.new()
		var round_state := FakeRoundState.new()
		MatchFlowController.new().handle_score_event("boss", {
			"score_state": score_state,
			"round_state": round_state,
			"mythic_item_runtime": runtime,
			"audio": env["audio"],
			"owner": env["owner"],
			"registry": env["registry"],
		}, {})
		var snapshot: Dictionary = score_state.get_snapshot()
		if int(snapshot.get("boss_score", -1)) == 0 and env["audio"].foul_whistle_count > 0:
			_expect(round_state.waiting_for_serve and round_state.player_serves, "ON Foul Whistle should keep the existing round-restart hold")
			_expect(round_state.restart_notice_calls == 1, "ON Foul Whistle should keep the existing restart notice")
			triggered = true
			break
	_expect(triggered, "ON Lv5 Foul Whistle should enter the real score-cancel trigger path under deterministic RNG")


func _verify_smartphone_update_consumer() -> void:
	var off_env := _make_env({})
	PerkConversionFlags.debug_set_enabled(false)
	_expect(_equip_item(off_env, "smartphone", {}), "OFF Smartphone consumer fixture should equip")
	off_env["runtime"].auto_defense_runtime.update_smartphone_runtime(
		off_env["runtime"],
		off_env["owner"],
		off_env["registry"],
		1.0
	)
	_expect(off_env["active_item_runtime"].recovery_scan_calls == 1, "OFF Smartphone should enter the auto-use scan when equipped")

	PerkConversionFlags.debug_set_enabled(true)
	var item_only_env := _make_env({})
	_expect(_equip_item(item_only_env, "smartphone", {}), "ON item-only Smartphone consumer fixture should equip")
	item_only_env["runtime"].auto_defense_runtime.update_smartphone_runtime(
		item_only_env["runtime"],
		item_only_env["owner"],
		item_only_env["registry"],
		1.0
	)
	_expect(item_only_env["active_item_runtime"].recovery_scan_calls == 0, "ON item-only Smartphone should not enter the auto-use scan")

	var perk_env := _make_env({"smartphone": 1})
	perk_env["runtime"].auto_defense_runtime.update_smartphone_runtime(
		perk_env["runtime"],
		perk_env["owner"],
		perk_env["registry"],
		1.0
	)
	_expect(perk_env["active_item_runtime"].recovery_scan_calls == 1, "ON perk-only Smartphone should enter the auto-use scan")


func _make_env(levels: Dictionary) -> Dictionary:
	var runtime := MythicItemRuntime.new()
	runtime.get_snapshot()
	var state := RuntimePerkState.new()
	for id_value in levels.keys():
		state.runtime_skill_levels[str(id_value)] = int(levels[id_value])
	var owner := FakeOwner.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(runtime, state, active_runtime, audio)
	runtime.owner_syncer.sync_runtime_perk_state_ref(runtime, registry)
	return {
		"runtime": runtime,
		"state": state,
		"owner": owner,
		"active_item_runtime": active_runtime,
		"audio": audio,
		"registry": registry,
	}


func _equip_item(env: Dictionary, item_name: String, rolls: Dictionary) -> bool:
	return bool(env["runtime"].equip_item(item_name, env["owner"], env["registry"], rolls, false))


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
