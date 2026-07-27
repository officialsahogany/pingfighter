extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const BattleUpdateBossAiContextBuilder := preload("res://scripts/core/battle_update_boss_ai_context_builder.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StatusEffectState := preload("res://scripts/status/status_effect_state.gd")

const SKILL_ID := "koyora_doll_curse"
const STATUS_SOURCE := "lingpet_doll_curse"
const DOLL_SHEET_PATH := "res://assets/sprites/lingpet/koyora_doll_curse_wooden_marionette_dance.png"
const DOLL_SHEET_MANIFEST_PATH := "res://assets/sprites/lingpet/koyora_doll_curse_wooden_marionette_dance_manifest.json"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(180.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ball_active := true
	var ball_pos := Vector2(230.0, 624.0)
	var ball_vel := Vector2(0.0, 8.0)
	var ball_size := 20.0


class FakeAudio:
	extends RefCounted

	var launch_count := 0
	var hit_count := 0
	var dollcurse_count := 0

	func play_active_item() -> void:
		launch_count += 1

	func play_lingpet_doll_curse() -> void:
		dollcurse_count += 1

	func play_dragon_breath_ball_hit() -> void:
		hit_count += 1

	func play_wall_hit(_impact_speed: float = 0.0, _source_x: float = 380.0) -> void:
		hit_count += 1


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = null
	var game_audio: Object = null

	func _init(status_state: Object = null, audio: Object = null) -> void:
		status_effect_state = status_state
		game_audio = audio

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "status_effect_state":
			return status_effect_state
		if key == "game_audio":
			return game_audio
		return null


func _init() -> void:
	seed(20260610)
	_verify_dispatcher_catalog_and_source_shape()
	_verify_launch_feedback_uses_ported_dollcurse_sound()
	_verify_wooden_dance_sheet_loads_and_keeps_procedural_fallback()
	_verify_wooden_dance_frame_mapping_uses_full_loop()
	_verify_sky_descent_and_marionette_rigging_contract()
	_verify_beam_sweep_alternates_slow_and_fast_tension()
	_verify_beam_homing_chance_scales_by_level_and_targets_boss()
	_verify_beam_vfx_draw_parameters_match_hit_cone()
	_verify_beam_boss_contact_signal_is_per_doll()
	_verify_emerge_has_no_confusion_or_ball_hit()
	_verify_confusion_applies_only_while_beam_touches_and_preserves_other_sources()
	_verify_beam_cone_edge_epsilon_regression()
	_verify_confusion_reaches_boss_ai_context_builder()
	_verify_ball_hit_destroys_one_doll_and_bounces_downward_ball()
	_verify_both_dolls_destroyed_end_early()
	_verify_ascending_ball_does_not_destroy_dolls()
	_verify_retract_and_reset_cleanup()

	if _failures.is_empty():
		print("lingpet_doll_curse_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_catalog_and_source_shape() -> void:
	_expect(FileAccess.file_exists("res://scripts/lingpet/lingpet_doll_curse_skill.gd"), "Koyora Doll Curse skill module should exist")
	_expect(LingpetSkillDispatcher.is_supported_kind("doll_curse"), "doll_curse should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "koyora_doll_curse should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_doll_curse(SKILL_ID), "dispatcher should expose a Doll Curse helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not skill.is_empty(), "Koyora catalog should expose Doll Curse metadata")
	_expect(str(skill.get("runtime_kind", "")) == "doll_curse", "Doll Curse metadata should use the doll_curse runtime kind")
	_expect(str(skill.get("name", "")) == "인형의 저주", "Doll Curse should use the requested Korean skill name")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 30.0), "Doll Curse should use the requested 30-second cooldown")
	_expect(_active_pool_has(LingpetCatalog.get_active_skill_pool("koyora"), SKILL_ID), "Koyora active pool should include Doll Curse")
	_expect(str(LingpetCatalog.get_active_skill("koyora").get("id", "")) == "koyora_puppet_control", "Koyora default active skill should remain Puppet Control")
	_expect(str(LingpetCatalog.get_active_skill("koyora", SKILL_ID).get("id", "")) == SKILL_ID, "Koyora explicit active loadout should select Doll Curse")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("koyora", SKILL_ID, 1).get("beam_homing_chance_pct", -1.0)), 35.0), "Doll Curse Lv.1 should expose 35% beam homing")
	_expect(is_equal_approx(float(LingpetCatalog.get_active_skill("koyora", SKILL_ID, 5).get("beam_homing_chance_pct", -1.0)), 95.0), "Doll Curse Lv.5 should expose 95% beam homing")

	var src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_skill.gd")
	_expect(src.find("boss-center-in-cone") >= 0 and src.find("_point_in_doll_beam") >= 0, "Doll Curse should name and implement a single beam hit primitive")
	_expect(src.find("owner.set(\"ball_vel\"") >= 0, "Doll Curse should only bounce through the existing ball_vel owner key")
	_expect(src.find("owner.set(\"lingpet") < 0, "Doll Curse should not invent owner lingpet flags for boss scripting")
	_expect(src.find("skip_ball_motion_step") < 0, "Doll Curse should not own the ball or use skip_ball_motion_step")
	_expect(src.find("BEAM_HOMING_CHANCE_PCT_BY_LEVEL") >= 0, "Doll Curse should map Lv.1-Lv.5 to beam homing chance")
	_expect(src.find("BEAM_HOMING_FOCUS_HALF_ANGLE_DEG_BY_LEVEL") >= 0, "Doll Curse should tighten beam focus by level")
	var payload_builder_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")
	_expect(payload_builder_src.find("\"beam_homing_chance_pct\"") >= 0, "Doll Curse level-applied homing chance should be forwarded through the launch payload builder")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate after wiring Doll Curse")


func _verify_launch_feedback_uses_ported_dollcurse_sound() -> void:
	var host := LingpetSkillRuntimeHost.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(StatusEffectState.new(), audio)
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.dollcurse_count == 1, "Doll Curse launch feedback should use the ported dollcurse sound cue")
	_expect(audio.launch_count == 0, "Doll Curse should not fall back to generic active-item audio when dollcurse audio exists")

	var feedback_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_launch_feedback_router.gd")
	_expect(feedback_src.find("play_lingpet_doll_curse") >= 0 and feedback_src.find("play_stage3_dollcurse") >= 0, "Doll Curse feedback router should prefer the lingpet cue and keep the original Stage 3 fallback")
	var audio_src := FileAccess.get_file_as_string("res://scripts/audio/game_audio.gd")
	_expect(audio_src.find("func play_lingpet_doll_curse") >= 0 and audio_src.find("stage3_dollcurse_sfx") >= 0, "game_audio should expose a lingpet Doll Curse method backed by the ported dollcurse.wav player")


func _verify_wooden_dance_sheet_loads_and_keeps_procedural_fallback() -> void:
	_expect(FileAccess.file_exists(DOLL_SHEET_PATH), "Doll Curse wooden marionette dance sheet should exist")
	_expect(FileAccess.file_exists(DOLL_SHEET_MANIFEST_PATH), "Doll Curse wooden marionette manifest should exist")
	var manifest := FileAccess.get_file_as_string(DOLL_SHEET_MANIFEST_PATH)
	_expect(
		manifest.find("\"view\": \"rear\"") >= 0
		and manifest.find("\"style\": \"wooden_carved_marionette\"") >= 0
		and manifest.find("\"dance_loop\": true") >= 0
		and manifest.find("\"active_frame_band\": \"0-15\"") >= 0
		and manifest.find("\"drawn_strings\": false") >= 0
		and manifest.find("\"runtime_strings\": true") >= 0
		and manifest.find("\"runtime_control_bar\": true") >= 0
		and manifest.find("\"entry_motion\": \"descend_from_sky\"") >= 0
		and manifest.find("\"exit_motion\": \"ascend_to_sky\"") >= 0
		and manifest.find("\"drawn_face\": false") >= 0
		and manifest.find("cmq703k0j002k1kos71i32zqg") >= 0,
		"Doll Curse sheet manifest should pin the wooden rear-view dance loop and source provenance"
	)
	var texture := ProjectResourceLoader.load_texture(DOLL_SHEET_PATH)
	_expect(texture != null, "Doll Curse wooden marionette dance sheet should load as a Texture2D")
	if texture != null:
		_expect(texture.get_width() % 4 == 0 and texture.get_height() % 4 == 0, "Doll Curse wooden dance sheet should be a 4x4 grid")
		_expect(texture.get_width() == 512 and texture.get_height() == 512, "Doll Curse wooden dance sheet should use 128px cells")

	var src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_skill.gd")
	var renderer_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_renderer.gd")
	_expect(src.find("DOLL_SHEET_PATH") >= 0 and src.find("koyora_doll_curse_wooden_marionette_dance.png") >= 0, "Doll Curse runtime should reference the wooden marionette dance sheet")
	_expect(renderer_src.find("draw_texture_rect_region") >= 0, "Doll Curse renderer should render sheet cells when the PNG loads")
	_expect(renderer_src.find("_draw_doll_procedural") >= 0, "Doll Curse renderer should keep the procedural doll fallback")

	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	skill.prewarm()
	_expect(bool(skill.get_snapshot().get("doll_curse_doll_sheet_loaded", false)), "Doll Curse prewarm should cache the wooden dance sheet before launch")


func _verify_wooden_dance_frame_mapping_uses_full_loop() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for frame mapping test")

	var emerge_doll := _live_doll_dictionary(skill, 0)
	var emerge_frame := int(skill.get_doll_sheet_frame_for_tests(emerge_doll))
	_expect(emerge_frame >= 0 and emerge_frame <= 3, "sky-descending EMERGE should use the wooden full-body entry band")

	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	var active_frames := {}
	for timer in [0.0, 0.125, 0.25, 0.5, 1.0, 1.875]:
		skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), timer)
		var active_doll := _live_doll_dictionary(skill, 0)
		var active_frame := int(skill.get_doll_sheet_frame_for_tests(active_doll))
		active_frames[active_frame] = true
		_expect(active_frame >= 0 and active_frame <= 15, "ACTIVE should stay inside the wooden marionette 16-frame dance loop")
	_expect(active_frames.size() >= 4, "ACTIVE should advance through multiple wooden dance frames instead of holding one pose")

	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_retract", 3)), 0.5)
	var retract_doll := _live_doll_dictionary(skill, 0)
	var retract_frame := int(skill.get_doll_sheet_frame_for_tests(retract_doll))
	_expect(retract_frame >= 12 and retract_frame <= 15, "sky-retract should use the wooden full-body exit band while moving upward")


func _verify_sky_descent_and_marionette_rigging_contract() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_skill.gd")
	var renderer_src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_renderer.gd")
	_expect(src.find("DOLL_SKY_SPAWN_Y") >= 0, "Doll Curse should name the sky spawn point explicitly")
	_expect(src.find("FIELD_HEIGHT + 48.0") < 0, "Doll Curse should no longer spawn dolls from below the field")
	_expect(renderer_src.find("draw_marionette_rigging") >= 0, "Doll Curse renderer should draw runtime marionette rigging")
	_expect(renderer_src.find("MARIONETTE_CONTROL_BAR") >= 0, "Doll Curse renderer should draw a control bar for the marionette silhouette")

	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for sky descent test")
	var launch_snapshot: Dictionary = skill.get_snapshot()
	_expect(bool(launch_snapshot.get("doll_curse_marionette_rigging", false)), "Doll Curse snapshot should expose runtime marionette rigging")
	_expect(float(launch_snapshot.get("doll_curse_sky_spawn_y", 0.0)) < 0.0, "Doll Curse sky spawn should start above the playfield")
	var launch_dolls: Array = launch_snapshot.get("doll_curse_dolls", []) as Array
	_expect(launch_dolls.size() == 2, "Doll Curse should create two sky-suspended dolls")
	for doll_value in launch_dolls:
		var doll: Dictionary = doll_value as Dictionary
		var spawn_pos: Vector2 = doll.get("spawn_pos", Vector2.ZERO)
		var target_pos: Vector2 = doll.get("target_pos", Vector2.ZERO)
		var pos: Vector2 = doll.get("pos", Vector2.ZERO)
		_expect(bool(doll.get("marionette_rigging", false)), "each Doll Curse doll should carry the marionette rigging contract")
		_expect(spawn_pos.y < 0.0 and spawn_pos.y < target_pos.y, "each Doll Curse doll should descend from the sky toward its target")
		_expect(pos.is_equal_approx(spawn_pos), "each Doll Curse doll should begin at its sky spawn point")

	skill.update(0.5, owner, registry)
	var mid_snapshot: Dictionary = skill.get_snapshot()
	var mid_dolls: Array = mid_snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in mid_dolls:
		var doll: Dictionary = doll_value as Dictionary
		var spawn_pos: Vector2 = doll.get("spawn_pos", Vector2.ZERO)
		var target_pos: Vector2 = doll.get("target_pos", Vector2.ZERO)
		var pos: Vector2 = doll.get("pos", Vector2.ZERO)
		_expect(pos.y > spawn_pos.y and pos.y < target_pos.y, "EMERGE should move dolls downward from sky spawn toward the field")

	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	skill.update(float(skill.get_snapshot().get("doll_curse_active_seconds", 4.0)), owner, registry)
	skill.update(0.5, owner, registry)
	var retract_snapshot: Dictionary = skill.get_snapshot()
	_expect(int(retract_snapshot.get("doll_curse_phase", -1)) == int(retract_snapshot.get("doll_curse_phase_retract", -2)), "sky descent test should enter RETRACT before checking upward exit")
	var retract_dolls: Array = retract_snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in retract_dolls:
		var doll: Dictionary = doll_value as Dictionary
		var spawn_pos: Vector2 = doll.get("spawn_pos", Vector2.ZERO)
		var target_pos: Vector2 = doll.get("target_pos", Vector2.ZERO)
		var pos: Vector2 = doll.get("pos", Vector2.ZERO)
		_expect(pos.y < target_pos.y and pos.y > spawn_pos.y, "RETRACT should pull dolls upward toward the sky spawn point")


func _verify_beam_sweep_alternates_slow_and_fast_tension() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for beam tension test")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	var start_snapshot: Dictionary = skill.get_snapshot()
	var slow_max := float(start_snapshot.get("doll_curse_beam_slow_turn_rate_max", 0.0))
	var fast_min := float(start_snapshot.get("doll_curse_beam_fast_turn_rate_min", 999.0))
	var start_dolls: Array = start_snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in start_dolls:
		var doll: Dictionary = doll_value as Dictionary
		_expect(str(doll.get("beam_sweep_phase", "")) == "slow", "Doll Curse beam should begin in a slow suspense sweep")
		_expect(float(doll.get("beam_turn_rate", 999.0)) <= slow_max, "slow Doll Curse beam sweep should use the slow turn-rate band")

	skill.update(1.30, owner, registry)
	var fast_snapshot: Dictionary = skill.get_snapshot()
	var fast_dolls: Array = fast_snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in fast_dolls:
		var doll: Dictionary = doll_value as Dictionary
		_expect(str(doll.get("beam_sweep_phase", "")) == "fast", "Doll Curse beam should snap into a brief fast sweep after the slow hold")
		_expect(float(doll.get("beam_turn_rate", 0.0)) >= fast_min, "fast Doll Curse beam sweep should use the fast turn-rate band")

	skill.update(0.40, owner, registry)
	var return_snapshot: Dictionary = skill.get_snapshot()
	var return_dolls: Array = return_snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in return_dolls:
		var doll: Dictionary = doll_value as Dictionary
		_expect(str(doll.get("beam_sweep_phase", "")) == "slow", "Doll Curse beam should return to slow suspense after the fast snap")
		_expect(float(doll.get("beam_turn_rate", 999.0)) <= slow_max, "returned Doll Curse beam sweep should restore the slow turn-rate band")


func _verify_beam_homing_chance_scales_by_level_and_targets_boss() -> void:
	var lv1_skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var lv1_owner := FakeOwner.new()
	lv1_owner.ball_active = false
	var lv1_registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(lv1_skill.launch(Vector2(380.0, 600.0), lv1_owner, {"registry": lv1_registry, "active_skill_level": 1})), "Doll Curse should launch at Lv.1")
	var lv1_snapshot: Dictionary = lv1_skill.get_snapshot()
	_expect(int(lv1_snapshot.get("doll_curse_active_skill_level", -1)) == 1, "Doll Curse should retain active skill level 1")
	_expect(is_equal_approx(float(lv1_snapshot.get("doll_curse_beam_homing_chance_pct", -1.0)), 35.0), "Doll Curse Lv.1 runtime homing chance should be 35%")

	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(
		Vector2(380.0, 600.0),
		owner,
		{
			"registry": registry,
			"active_skill_level": 5,
			"beam_homing_chance_pct": 95.0,
		}
	)), "Doll Curse should launch at Lv.5")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	skill.set_beam_homing_rolls_for_tests([true, true])
	skill.update(1.30, owner, registry)
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(int(snapshot.get("doll_curse_active_skill_level", -1)) == 5, "Doll Curse should retain active skill level 5")
	_expect(is_equal_approx(float(snapshot.get("doll_curse_beam_homing_chance_pct", -1.0)), 95.0), "Doll Curse Lv.5 runtime homing chance should be 95%")
	_expect(is_equal_approx(float(snapshot.get("doll_curse_beam_homing_focus_half_angle_deg", -1.0)), 3.0), "Doll Curse Lv.5 should tighten post-homing focus to 3 degrees")
	_expect(int(snapshot.get("doll_curse_beam_homing_attempt_count", -1)) == 2, "Doll Curse should roll homing once per live doll fast-sweep opportunity")
	_expect(int(snapshot.get("doll_curse_beam_homing_success_count", -1)) == 2, "forced successful homing rolls should target both live dolls")
	var dolls: Array = snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in dolls:
		var doll: Dictionary = doll_value as Dictionary
		if not bool(doll.get("alive", false)):
			continue
		_expect(str(doll.get("beam_sweep_phase", "")) == "fast", "homing should trigger on the brief fast sweep")
		_expect(bool(doll.get("beam_homing_targeted", false)), "successful homing roll should mark the beam target as homing")
		var expected_angle := _expected_beam_angle_to_boss(doll, owner)
		var actual_angle := float(doll.get("beam_target_angle", 999.0))
		_expect(_angle_distance(actual_angle, expected_angle) <= 0.001, "successful homing roll should aim the beam target at the boss center")

	skill.update(0.40, owner, registry)
	var focus_snapshot: Dictionary = skill.get_snapshot()
	var focus_dolls: Array = focus_snapshot.get("doll_curse_dolls", []) as Array
	for doll_value in focus_dolls:
		var doll: Dictionary = doll_value as Dictionary
		if not bool(doll.get("alive", false)):
			continue
		_expect(str(doll.get("beam_sweep_phase", "")) == "slow", "after a homing snap, Doll Curse should return to a slow focus sweep")
		_expect(bool(doll.get("beam_homing_focus_active", false)), "successful homing should keep the next slow sweep focused near the boss")
		var expected_angle := _expected_beam_angle_to_boss(doll, owner)
		var actual_angle := float(doll.get("beam_target_angle", 999.0))
		_expect(_angle_distance(actual_angle, expected_angle) <= deg_to_rad(3.1), "Lv.5 focused slow sweep should keep the beam near the boss")


func _verify_beam_vfx_draw_parameters_match_hit_cone() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_doll_curse_skill.gd")
	_expect(src.find("BEAM_OUTER_END_HALF_WIDTH := BEAM_LENGTH * tan(BEAM_HALF_ANGLE)") >= 0, "beam visual envelope should derive from the hit cone")
	_expect(src.find("BEAM_DRAW_END_WIDTH := 82.0") < 0, "beam visual envelope should not keep the old hardcoded 82px endpoint")
	_expect(src.find("get_beam_draw_debug_for_tests") >= 0, "beam VFX should expose draw parameter smoke hooks")
	_expect(src.find("beam_on_boss") >= 0 and src.find("beam_boss_point") >= 0, "beam VFX should carry per-doll boss-contact draw signals")

	var lv1_skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var lv1_owner := FakeOwner.new()
	lv1_owner.ball_active = false
	var lv1_registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(lv1_skill.launch(Vector2(380.0, 600.0), lv1_owner, {"registry": lv1_registry, "active_skill_level": 1})), "Doll Curse should launch at Lv.1 for beam VFX debug")
	lv1_skill.set_phase_for_tests(int(lv1_skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	var base_doll := _live_doll_dictionary(lv1_skill, 0)
	base_doll["wobble"] = 1.25
	base_doll["beam_homing_focus_active"] = false
	base_doll["beam_on_boss"] = false
	base_doll["beam_boss_point"] = Vector2.ZERO
	var lv1_debug: Dictionary = lv1_skill.get_beam_draw_debug_for_tests(base_doll)
	var expected_outer := 700.0 * tan(deg_to_rad(7.0))
	_expect(absf(float(lv1_debug.get("outer_end_half_width", 0.0)) - expected_outer) <= 0.5, "beam outer endpoint half-width should match the 7-degree hit cone")
	_expect(is_equal_approx(float(lv1_debug.get("outer_end_half_width", 0.0)), float(lv1_skill.get_snapshot().get("doll_curse_beam_outer_end_half_width", -1.0))), "snapshot should expose the same derived beam endpoint half-width")
	_expect(int(lv1_debug.get("polygon_layer_count", 0)) >= 5, "beam draw debug should include haze, glow, inner glow, and core polygon layers")
	_expect(int(lv1_debug.get("origin_flare_count", 0)) == 3, "beam draw debug should include the origin flare stack")
	_expect(int(lv1_debug.get("shimmer_count", 0)) == 2, "beam draw debug should keep shimmer as two stable motes")
	_expect(float(lv1_debug.get("mid_glow_end_half_width", 0.0)) > float(lv1_debug.get("inner_glow_end_half_width", 999.0)), "beam glow stack should narrow from mid glow to inner glow")

	var lv5_skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var lv5_owner := FakeOwner.new()
	lv5_owner.ball_active = false
	var lv5_registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(lv5_skill.launch(Vector2(380.0, 600.0), lv5_owner, {"registry": lv5_registry, "active_skill_level": 5})), "Doll Curse should launch at Lv.5 for beam VFX debug")
	lv5_skill.set_phase_for_tests(int(lv5_skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	var lv5_debug: Dictionary = lv5_skill.get_beam_draw_debug_for_tests(base_doll)
	_expect(is_equal_approx(float(lv1_debug.get("outer_end_half_width", 0.0)), float(lv5_debug.get("outer_end_half_width", -1.0))), "skill level should not change the visible outer envelope")
	_expect(float(lv5_debug.get("core_end_half_width", 999.0)) < float(lv1_debug.get("core_end_half_width", 0.0)), "Lv.5 focus should narrow only the inner beam core")
	_expect(float(lv5_debug.get("needle_width", 999.0)) < float(lv1_debug.get("needle_width", 0.0)), "Lv.5 focus should narrow the needle line")

	var normal_debug: Dictionary = lv1_skill.get_beam_draw_debug_for_tests(base_doll)
	var homing_doll := base_doll.duplicate(true)
	homing_doll["beam_homing_focus_active"] = true
	var homing_debug: Dictionary = lv1_skill.get_beam_draw_debug_for_tests(homing_doll)
	_expect(float(homing_debug.get("core_intensity", 0.0)) > float(normal_debug.get("core_intensity", 999.0)), "homing focus should boost beam core intensity")
	_expect(float(homing_debug.get("core_alpha", 0.0)) > float(normal_debug.get("core_alpha", 999.0)), "homing focus should boost beam core alpha")

	var hit_doll := base_doll.duplicate(true)
	var hit_point := Vector2(230.0, 45.0)
	hit_doll["beam_on_boss"] = true
	hit_doll["beam_boss_point"] = hit_point
	var hit_debug: Dictionary = lv1_skill.get_beam_draw_debug_for_tests(hit_doll)
	_expect(bool(hit_debug.get("hit_flash_active", false)), "beam-on-boss should enable the hit flash debug lane")
	_expect(_vector2_near(hit_debug.get("hit_flash_point", Vector2.ZERO), hit_point, 0.01), "beam-on-boss should expose the projected hit flash point")


func _verify_beam_boss_contact_signal_is_per_doll() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for per-doll beam contact test")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	skill.force_beam_angle_for_tests(-PI * 0.5)
	skill.update(1.0 / 60.0, owner, registry)
	var left_snapshot: Dictionary = skill.get_snapshot()
	var left_dolls: Array = left_snapshot.get("doll_curse_dolls", []) as Array
	_expect(left_dolls.size() == 2, "per-doll contact test should keep both dolls alive")
	var left_doll: Dictionary = left_dolls[0] as Dictionary
	var right_doll: Dictionary = left_dolls[1] as Dictionary
	var left_boss_center := owner.boss_pos + Vector2(owner.boss_paddle_width * 0.5, owner.boss_hitbox_height * 0.5)
	_expect(bool(left_doll.get("beam_on_boss", false)), "left doll should mark beam_on_boss when its cone touches the boss center")
	_expect(not bool(right_doll.get("beam_on_boss", false)), "right doll should stay false when only the left beam touches the boss center")
	_expect(_vector2_near(left_doll.get("beam_boss_point", Vector2.ZERO), left_boss_center, 0.05), "left doll should store the projected boss hit point")
	_expect(_vector2_near(right_doll.get("beam_boss_point", Vector2.ZERO), Vector2.ZERO, 0.01), "inactive beam contact should keep a zero hit point")

	owner.boss_pos = Vector2(480.0, 25.0)
	skill.update(1.0 / 60.0, owner, registry)
	var right_snapshot: Dictionary = skill.get_snapshot()
	var right_dolls: Array = right_snapshot.get("doll_curse_dolls", []) as Array
	left_doll = right_dolls[0] as Dictionary
	right_doll = right_dolls[1] as Dictionary
	var right_boss_center := owner.boss_pos + Vector2(owner.boss_paddle_width * 0.5, owner.boss_hitbox_height * 0.5)
	_expect(not bool(left_doll.get("beam_on_boss", false)), "left doll should clear beam_on_boss when the boss moves to the right beam")
	_expect(bool(right_doll.get("beam_on_boss", false)), "right doll should mark beam_on_boss when its cone touches the boss center")
	_expect(_vector2_near(right_doll.get("beam_boss_point", Vector2.ZERO), right_boss_center, 0.05), "right doll should store the projected boss hit point")


func _verify_emerge_has_no_confusion_or_ball_hit() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var status_state := StatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch")
	skill.force_beam_angle_for_tests(-PI * 0.5)
	skill.update(0.5, owner, registry)
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(int(snapshot.get("doll_curse_phase", -1)) == int(snapshot.get("doll_curse_phase_emerge", -2)), "first 1s should be the EMERGE phase")
	_expect(status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "EMERGE should not apply confusion")
	_expect(int(snapshot.get("doll_curse_doll_destroyed_count", -1)) == 0, "EMERGE should not let the ball destroy dolls")


func _verify_confusion_applies_only_while_beam_touches_and_preserves_other_sources() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var status_state := StatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new())
	status_state.apply_status("boss", "confusion", 60.0, {"visual": "flare"}, "flare_x")
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for confusion test")
	skill.force_beam_angle_for_tests(-PI * 0.5)
	skill.update(1.0, owner, registry)
	skill.update(1.0 / 60.0, owner, registry)
	_expect(not status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "ACTIVE beam contact should apply Doll Curse confusion")
	_expect(int(skill.get_confusion_apply_count_for_tests()) >= 1, "beam contact should count a confusion refresh")
	_expect(not status_state.get_status_source("boss", "confusion", "flare_x").is_empty(), "Doll Curse apply should preserve a pre-existing flare confusion source")

	owner.boss_pos = Vector2(300.0, 25.0)
	skill.update(1.0 / 60.0, owner, registry)
	_expect(status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "leaving the beam should clear only Doll Curse confusion immediately")
	_expect(not status_state.get_status_source("boss", "confusion", "flare_x").is_empty(), "source-scoped clear must not erase flare confusion")


func _verify_beam_cone_edge_epsilon_regression() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var status_state := StatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for cone edge test")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	skill.force_beam_angle_for_tests(-PI * 0.5)
	var left_pos: Vector2 = _live_doll_dictionary(skill, 0).get("pos", Vector2.ZERO)
	var beam_origin := left_pos + Vector2(0.0, -32.0 * 0.70)
	var boss_center_y := 45.0
	var dy := beam_origin.y - boss_center_y

	var inside_dx := dy * tan(deg_to_rad(6.0))
	owner.boss_pos = Vector2(
		left_pos.x + inside_dx - owner.boss_paddle_width * 0.5,
		boss_center_y - owner.boss_hitbox_height * 0.5
	)
	skill.update(1.0 / 60.0, owner, registry)
	_expect(not status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "boss center just inside the 7-degree hit cone should receive Doll Curse confusion")

	var outside_dx := dy * tan(deg_to_rad(8.0))
	owner.boss_pos = Vector2(
		left_pos.x + outside_dx - owner.boss_paddle_width * 0.5,
		boss_center_y - owner.boss_hitbox_height * 0.5
	)
	skill.update(1.0 / 60.0, owner, registry)
	_expect(status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "boss center just outside the cone half-angle (+epsilon) should clear confusion on the next frame")


func _verify_confusion_reaches_boss_ai_context_builder() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var status_state := StatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new())
	var context_builder := BattleUpdateBossAiContextBuilder.new()
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for boss AI context test")
	skill.force_beam_angle_for_tests(-PI * 0.5)
	skill.update(1.0, owner, registry)
	skill.update(1.0 / 60.0, owner, registry)
	var ai_context: Dictionary = context_builder.build_context(owner, registry)
	_expect(bool(ai_context.get("status_boss_confusion_active", false)), "Doll Curse confusion should reach the boss AI context as a status flag")
	_expect(bool(ai_context.get("active_item_flare_confusion_active", false)), "Doll Curse confusion should reach the legacy flare confusion boss AI flag")

	owner.boss_pos = Vector2(300.0, 25.0)
	skill.update(1.0 / 60.0, owner, registry)
	ai_context = context_builder.build_context(owner, registry)
	_expect(not bool(ai_context.get("status_boss_confusion_active", false)), "leaving the Doll Curse beam should remove the boss AI status confusion flag")
	_expect(not bool(ai_context.get("active_item_flare_confusion_active", false)), "leaving the Doll Curse beam should remove the legacy flare confusion boss AI flag")


func _verify_ball_hit_destroys_one_doll_and_bounces_downward_ball() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(StatusEffectState.new(), audio)
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for ball hit test")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	var first_doll := _live_doll_at(skill, 0)
	owner.ball_pos = first_doll
	owner.ball_vel = Vector2(0.0, 8.0)
	skill.update(1.0 / 60.0, owner, registry)
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(int(snapshot.get("doll_curse_doll_destroyed_count", -1)) == 1, "a downward ball should destroy exactly one touched doll")
	_expect(int(snapshot.get("doll_curse_doll_count", -1)) == 1, "destroying one doll should leave the other alive")
	_expect(owner.ball_vel.y < 0.0, "a destroyed doll should bounce the downward ball upward")
	_expect(int(skill.get_ball_bounce_count_for_tests()) == 1, "Doll Curse should count one ball bounce")
	_expect(audio.hit_count == 1, "destroying a doll should play one hit feedback sound")


func _verify_both_dolls_destroyed_end_early() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for early-end test")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	owner.ball_pos = _live_doll_at(skill, 0)
	owner.ball_vel = Vector2(0.0, 8.0)
	skill.update(1.0 / 60.0, owner, registry)
	owner.ball_pos = _live_doll_at(skill, 0)
	owner.ball_vel = Vector2(0.0, 8.0)
	skill.update(1.0 / 60.0, owner, registry)
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(int(snapshot.get("doll_curse_doll_destroyed_count", -1)) == 2, "two downward ball hits should destroy both dolls")
	_expect(not bool(snapshot.get("doll_curse_active", true)), "destroying both dolls should end Doll Curse early instead of retracting empty dolls")


func _verify_ascending_ball_does_not_destroy_dolls() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for ascending-ball test")
	skill.set_phase_for_tests(int(skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	owner.ball_pos = _live_doll_at(skill, 0)
	owner.ball_vel = Vector2(0.0, -8.0)
	skill.update(1.0 / 60.0, owner, registry)
	var snapshot: Dictionary = skill.get_snapshot()
	_expect(int(snapshot.get("doll_curse_doll_destroyed_count", -1)) == 0, "an ascending ball should not destroy guardian dolls")
	_expect(int(snapshot.get("doll_curse_doll_count", -1)) == 2, "ascending-ball overlap should leave both dolls alive")


func _verify_retract_and_reset_cleanup() -> void:
	var skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_active = false
	var status_state := StatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new())
	_expect(bool(skill.launch(Vector2(380.0, 600.0), owner, {"registry": registry})), "Doll Curse should launch for cleanup test")
	skill.force_beam_angle_for_tests(-PI * 0.5)
	skill.update(1.0, owner, registry)
	skill.update(1.0 / 60.0, owner, registry)
	_expect(not status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "cleanup test should first apply Doll Curse confusion")
	skill.reset()
	_expect(status_state.get_status_source("boss", "confusion", STATUS_SOURCE).is_empty(), "registry-cached reset should clear Doll Curse confusion without an explicit registry argument")
	_expect(not bool(skill.get_snapshot().get("doll_curse_active", true)), "reset should end the skill")

	var retract_skill: Object = load("res://scripts/lingpet/lingpet_doll_curse_skill.gd").new()
	var retract_owner := FakeOwner.new()
	var retract_registry := FakeRegistry.new(StatusEffectState.new(), FakeAudio.new())
	_expect(bool(retract_skill.launch(Vector2(380.0, 600.0), retract_owner, {"registry": retract_registry})), "Doll Curse should launch for retract test")
	retract_skill.set_phase_for_tests(int(retract_skill.get_snapshot().get("doll_curse_phase_active", 2)), 0.0)
	retract_owner.boss_pos = Vector2(300.0, 25.0)
	retract_skill.update(float(retract_skill.get_snapshot().get("doll_curse_active_seconds", 4.0)), retract_owner, retract_registry)
	var retract_snapshot: Dictionary = retract_skill.get_snapshot()
	_expect(int(retract_snapshot.get("doll_curse_phase", -1)) == int(retract_snapshot.get("doll_curse_phase_retract", -2)), "surviving dolls should enter RETRACT when active time ends")
	retract_skill.update(float(retract_snapshot.get("doll_curse_retract_seconds", 1.0)), retract_owner, retract_registry)
	_expect(not bool(retract_skill.get_snapshot().get("doll_curse_active", true)), "RETRACT should finish after 1s")


func _live_doll_at(skill: Object, live_index: int) -> Vector2:
	return _live_doll_dictionary(skill, live_index).get("pos", Vector2.ZERO)


func _live_doll_dictionary(skill: Object, live_index: int) -> Dictionary:
	var snapshot: Dictionary = skill.get_snapshot()
	var dolls: Array = snapshot.get("doll_curse_dolls", []) as Array
	var live_seen := 0
	for doll_value in dolls:
		var doll: Dictionary = doll_value as Dictionary
		if not bool(doll.get("alive", false)):
			continue
		if live_seen == live_index:
			return doll
		live_seen += 1
	return {}


func _active_pool_has(pool: Array[Dictionary], skill_id: String) -> bool:
	for skill in pool:
		if str(skill.get("id", "")) == skill_id:
			return true
	return false


func _expected_beam_angle_to_boss(doll: Dictionary, owner: FakeOwner) -> float:
	var doll_pos: Vector2 = doll.get("pos", Vector2.ZERO)
	var origin := doll_pos + Vector2(0.0, -32.0 * 0.70)
	var boss_center := owner.boss_pos + Vector2(owner.boss_paddle_width * 0.5, owner.boss_hitbox_height * 0.5)
	return clampf((boss_center - origin).angle(), -PI * 0.5 - deg_to_rad(35.0), -PI * 0.5 + deg_to_rad(35.0))


func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


func _vector2_near(value: Variant, expected: Vector2, tolerance: float) -> bool:
	if not (value is Vector2):
		return false
	return (value as Vector2).distance_to(expected) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
