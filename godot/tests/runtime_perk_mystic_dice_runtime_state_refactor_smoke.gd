extends SceneTree

const RuntimePerkMysticDiceRuntimeState := preload("res://scripts/characters/runtime_perk_mystic_dice_runtime_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_direct_state_and_runtime_facade()
	if _failures.is_empty():
		print("runtime_perk_mystic_dice_runtime_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_mystic_dice_runtime_state.gd")
	_expect(RuntimePerkMysticDiceRuntimeState != null, "Mystic Dice runtime-state owner should preload")
	_expect(
		runtime_source.find("RuntimePerkMysticDiceRuntimeState") >= 0
		and runtime_source.find("var _mystic_dice_runtime_state: Object = RuntimePerkMysticDiceRuntimeState.new()") >= 0,
		"runtime perk facade should construct one Mystic Dice feature-state owner"
	)
	for removed_storage: String in [
		"var _mystic_dice_state: Object = null",
		"var _mystic_dice_roller: Object = null",
		"var _mystic_dice_offer_planner: Object = null",
		"var _mystic_dice_paddle_effect: Object = null",
		"var _mystic_dice_paddle_effect_pending := false",
	]:
		_expect(runtime_source.find(removed_storage) < 0, "runtime facade should not retain Mystic Dice storage %s" % removed_storage)
	_expect(
		runtime_source.find("var _mystic_dice_offer_planner: Object:") >= 0
		and runtime_source.find("_mystic_dice_runtime_state.set_offer_planner(value)") >= 0
		and runtime_source.find("var _mystic_dice_paddle_effect_pending: bool:") >= 0
		and runtime_source.find("_mystic_dice_runtime_state.set_paddle_effect_pending(value)") >= 0,
		"dirty-test injection seams should remain computed compatibility properties, not duplicate storage"
	)
	_expect(
		runtime_source.find("var _mystic_dice_modal_flow: Object:") >= 0
		and runtime_source.find("return _mystic_dice_runtime_state.peek_modal_flow()") >= 0
		and runtime_source.find("_mystic_dice_runtime_state.set_modal_flow(value)") >= 0
		and runtime_source.find("var _mystic_dice_modal_input: Object:") >= 0
		and runtime_source.find("return _mystic_dice_runtime_state.peek_modal_input()") >= 0
		and runtime_source.find("_mystic_dice_runtime_state.set_modal_input(value)") >= 0,
		"modal flow/input lookup seams should be writable owner-backed properties"
	)
	_expect(
		owner_source.find("func commit_roll(") >= 0
		and owner_source.find("func roll(") >= 0
		and owner_source.find("func can_plan_offer(") >= 0
		and owner_source.find("func queue_paddle_effect(") >= 0
		and owner_source.find("func update_paddle_effect(") >= 0
		and owner_source.find("func reset_state(") >= 0,
		"Mystic Dice owner should contain core, roller, offer, paddle, and reset responsibilities"
	)
	_expect(
		owner_source.find("func begin_modal_from_runtime_state(") >= 0
		and owner_source.find("func handle_modal_input_from_runtime_state(") >= 0
		and owner_source.find("func activate_selected_action_from_runtime_state(") >= 0
		and owner_source.find("func finish_modal_from_runtime_state(") >= 0,
		"Mystic Dice owner should own the complete modal transaction"
	)
	var begin_body := _function_body(runtime_source, "func _begin_mystic_dice_modal(")
	var input_body := _function_body(runtime_source, "func _handle_mystic_dice_modal_input(")
	var activate_body := _function_body(runtime_source, "func _activate_mystic_dice_selected_action(")
	var finish_body := _function_body(runtime_source, "func _finish_mystic_dice_modal(")
	_expect(
		begin_body.find("_mystic_dice_runtime_state.begin_modal_from_runtime_state") >= 0
		and begin_body.find(".start(") < 0,
		"runtime begin wrapper should delegate without owning modal start logic"
	)
	_expect(
		input_body.find("_mystic_dice_runtime_state.handle_modal_input_from_runtime_state") >= 0
		and input_body.find(".resolve(") < 0,
		"runtime input wrapper should delegate without interpreting modal actions"
	)
	_expect(
		activate_body.find("_mystic_dice_runtime_state.activate_selected_action_from_runtime_state") >= 0
		and activate_body.find("request_selected_action") < 0,
		"runtime activation wrapper should delegate reroll/commit routing"
	)
	_expect(
		finish_body.find("_mystic_dice_runtime_state.finish_modal_from_runtime_state") >= 0
		and finish_body.find("commit_mystic_dice_roll") < 0
		and finish_body.find("_owner_sync_flow") < 0
		and finish_body.find("_finish_successful_choice") < 0,
		"runtime finish wrapper should not retain Mystic Dice transaction ordering"
	)


func _verify_direct_state_and_runtime_facade() -> void:
	var owner := RuntimePerkMysticDiceRuntimeState.new()
	var units: Array = []
	for _index: int in range(7):
		units.append(1.0)
	var roll_payload: Dictionary = owner.roll(units)
	_expect(bool(roll_payload.get("accepted", false)), "owner should roll through the canonical seven-stat roller")
	var guarded_owner := RuntimePerkMysticDiceRuntimeState.new()
	var missing_runtime_finish: Dictionary = guarded_owner.finish_modal_from_runtime_state(
		null,
		null,
		null,
		{"raw": (roll_payload.get("raw", {}) as Dictionary).duplicate(true)}
	)
	_expect(
		not bool(missing_runtime_finish.get("accepted", false))
		and str(missing_runtime_finish.get("blocked_reason", "")) == "missing_runtime_state",
		"modal finish should fail closed before raw commit when the runtime transaction owner is missing"
	)
	_expect(guarded_owner.get_snapshot().get("use_count", -1) == 0, "failed dependency preflight must not consume a Dice use")
	var commit: Dictionary = owner.commit_roll(roll_payload.get("raw", {}) as Dictionary)
	_expect(bool(commit.get("accepted", false)), "owner should commit through the canonical Mystic Dice state")
	_expect(owner.get_raw("player_speed") == 3, "owner should expose committed raw values")
	_expect(is_equal_approx(owner.get_multiplier("player_speed"), 1.03), "owner should expose committed multipliers")
	var revision_before_reset := owner.get_revision()
	owner.reset_state()
	_expect(owner.get_revision() == revision_before_reset + 1, "owner reset should advance the Dice revision exactly once")
	_expect(owner.get_raw("player_speed") == 0, "owner reset should clear permanent Dice raw values")

	owner.queue_paddle_effect()
	var pending_snapshot: Dictionary = owner.get_paddle_effect_snapshot()
	_expect(bool(pending_snapshot.get("pending_start", false)), "owner should preserve the modal-to-physics pending boundary")
	_expect(not bool(pending_snapshot.get("active", true)), "pending paddle effect should not start while modal physics is blocked")
	_expect(owner.update_paddle_effect(0.25), "first resumed gameplay tick should start the pending paddle effect")
	var active_snapshot: Dictionary = owner.get_paddle_effect_snapshot()
	_expect(bool(active_snapshot.get("active", false)), "resumed paddle effect should become active")
	_expect(is_equal_approx(float(active_snapshot.get("remaining_seconds", 0.0)), 3.0), "resume tick should not consume deferred effect time")
	owner.clear_paddle_effect()
	_expect(not bool(owner.get_paddle_effect_snapshot().get("active", true)), "owner clear should stop the paddle effect")

	var runtime := RuntimePerkState.new()
	var runtime_commit: Dictionary = runtime.commit_mystic_dice_roll(roll_payload.get("raw", {}) as Dictionary)
	_expect(bool(runtime_commit.get("accepted", false)) and runtime.get_mystic_dice_raw("player_speed") == 3, "runtime facade should delegate canonical Dice commit/query")
	runtime._mystic_dice_paddle_effect_pending = true
	_expect(bool(runtime.get_mystic_dice_paddle_effect_snapshot().get("pending_start", false)), "compatibility pending setter should route into the owner")
	runtime.update_mystic_dice_paddle_effect(0.1)
	_expect(bool(runtime.get_mystic_dice_paddle_effect_snapshot().get("active", false)), "runtime paddle facade should advance the owner")
	runtime.clear_mystic_dice_paddle_effect()
	_expect(runtime._mystic_dice_modal_flow == null, "fresh runtime should not construct the Dice modal flow eagerly")
	var modal_flow: Object = runtime._get_mystic_dice_modal_flow()
	var modal_input: Object = runtime._get_mystic_dice_modal_input()
	_expect(modal_flow != null and runtime._mystic_dice_modal_flow == modal_flow, "runtime modal-flow seam should expose the owner-held lazy instance")
	_expect(modal_input != null and runtime._mystic_dice_modal_input == modal_input, "runtime modal-input seam should expose the owner-held lazy instance")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
